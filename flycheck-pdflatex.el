;;; flycheck-pdflatex.el --- LaTeX flycheck checker with pdflatex compiler  -*- lexical-binding: t; -*-

;; Copyright (C) 2023 Pieter Pareit

;; Author: Pieter Pareit <pieter.pareit@gmail.com>
;; Homepage:
;; Created: 7 Mars 2023
;; Package-Requires: ((emacs "27.0"))
;; Keywords: emacs mode tex latex pdflatex flycheck

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Use this flycheck checker when you want to let LaTeX files be checked
;; by the pdflatex compiler.
;; Other tools for checking TeX/LaTeX files also exists, but this checker
;; tries to add some extra functionallity that only works with pdflatex
;; This tool has just been written (2023), so I might nog yet handle all
;; use cases.  Let me know, for example by adding a minimal .tex file and
;; some instructions what you would expect.

;;; Installation

;; Assuming you are using use-package and straight, add the following code
;; to your .emacs
;;
;; (use-package flycheck-pdflatex
;;   :straight (:package "flycheck-pdflatex"
;; 		      :host github
;; 		      :repo "ppareit/flycheck-pdflatex"))

;;; Code:

(require 'flycheck)
(require 'cl-lib)
(require 'seq)

(defgroup flycheck-pdflatex nil
  "Flycheck checker for LaTeX files using pdflatex."
  :group 'flycheck
  :prefix "flycheck-pdflatex-")

(defcustom flycheck-pdflatex-output-directory temporary-file-directory
  "Root directory for the files pdflatex writes while checking.
Each source directory gets its own subdirectory here, so the
.aux, .log and helper files (for example the .asy files of the
asymptote package) never clutter the source directory, and the
.aux file survives between checks.  When nil, do not pass an
explicit output directory and let `pdflatex' use its default
behavior."
  :type '(choice (directory :tag "Directory")
                 (const :tag "Use pdflatex default" nil)))

(defcustom flycheck-pdflatex-report-boxes nil
  "When non-nil, report overfull and underfull boxes as info."
  :type 'boolean)

(defcustom flycheck-pdflatex-ignored-warnings
  '(;; Summaries, the individual warnings are reported themselves
    "\\`There were undefined references"
    "\\`There were multiply-defined labels"
    ;; A check is a single pass, the aux file from the previous check
    ;; resolves these on the next one
    "Rerun to get"
    "\\`Label(s) may have changed"
    ;; Labels of packages (mdframed, hyperref, ...), not of the author
    "\\`\\(?:Reference\\|Label\\) `[^']*@[^']*'"
    ;; The checker never runs asy, so the figures are always missing
    "\\`file `[^']*' not found"
    ;; A class file is checked as a copy with another name
    "\\`You have requested document class `[^']*flycheck_")
  "Regexps for warnings that are not reported.
A warning is dropped when one of these regexps matches its
message."
  :type '(repeat regexp))

(defun flycheck-pdflatex--output-directory ()
  "Return the output directory for the current buffer, creating it.
Return nil when `flycheck-pdflatex-output-directory' is nil."
  (when flycheck-pdflatex-output-directory
    (let ((dir (expand-file-name
              (md5 (expand-file-name default-directory))
              (expand-file-name
               (format "flycheck-pdflatex-%s" (user-uid))
               flycheck-pdflatex-output-directory))))
      (make-directory dir t)
      dir)))

(defun flycheck-pdflatex--source (source)
  "Return the input that `pdflatex' should check for SOURCE.
SOURCE is the temporary copy of the current buffer.  Class files are
loaded from a minimal document because they cannot be compiled as
standalone LaTeX documents."
  (if (and buffer-file-name
	   (string-equal (downcase (or (file-name-extension buffer-file-name) ""))
			 "cls"))
      (format "\\documentclass{%s}\\begin{document}\\end{document}"
	      (file-name-sans-extension source))
    source))

(defun flycheck-pdflatex--arguments ()
  "Return the job name, the output directory and the input for `pdflatex'.
The job name is that of the temporary copy, also for a class file,
so the script can find the .aux file of the previous check."
  (let ((source (flycheck-save-buffer-to-temp #'flycheck-temp-file-inplace)))
    (list (file-name-base source)
          (or (flycheck-pdflatex--output-directory) "")
          (flycheck-pdflatex--source source))))

(defconst flycheck-pdflatex--script
  "job=$1; out=$2; src=$3
aux=${out:-.}/$job.aux
# -shell-escape allows the nested pdflatex calls of tikz externalization
set -- -cnf-line=max_print_line=1024 -file-line-error -draftmode \\
    -interaction=nonstopmode -shell-escape -jobname=\"$job\" \\
    ${out:+\"-output-directory=$out\"} \"$src\"
# Without an aux file every reference is undefined: prime it first
[ -f \"$aux\" ] || pdflatex \"$@\" >/dev/null 2>&1
exec pdflatex \"$@\""
  "Shell script that runs pdflatex, twice when there is no aux file yet.")

(defun flycheck-pdflatex--column-of (err regexp)
  "Return the column of REGEXP on the line of ERR, or nil."
  (let ((line (flycheck-error-line err)))
    (when (and line (> line 0))
      (with-current-buffer (flycheck-error-buffer err)
        (save-excursion
          (save-restriction
            (widen)
            (goto-char (point-min))
            (forward-line (1- line))
            (when (re-search-forward regexp (line-end-position) t)
              (1+ (- (match-beginning 0) (line-beginning-position))))))))))

(defun flycheck-pdflatex--mark (err regexp)
  "Point ERR at the first match of REGEXP on its line."
  (let ((column (flycheck-pdflatex--column-of err regexp)))
    (when column
      (setf (flycheck-error-column err) column)
      (setf (flycheck-error-end-column err)
            (+ column (- (match-end 0) (match-beginning 0)))))))

(defun flycheck-pdflatex--line-of (err regexp &optional last)
  "Put ERR on the first line matching REGEXP in its buffer.
With LAST, use the last matching line instead."
  (with-current-buffer (flycheck-error-buffer err)
    (save-excursion
      (save-restriction
        (widen)
        (goto-char (if last (point-max) (point-min)))
        (when (if last
                  (re-search-backward regexp nil t)
                (re-search-forward regexp nil t))
          (setf (flycheck-error-line err) (line-number-at-pos))
          (setf (flycheck-error-column err)
                (1+ (- (match-beginning 0) (line-beginning-position))))
          (setf (flycheck-error-end-column err)
                (+ (flycheck-error-column err)
                   (- (match-end 0) (match-beginning 0)))))))))

(defun flycheck-pdflatex--fix-errors (err)
  "Fix pdflatex errors, ERR, to easier to read erros."
  (let ((errmsg (flycheck-error-message err)))
    ;; Join the continuation lines of package warnings, "(pkg)   more"
    (setq errmsg (replace-regexp-in-string "\n([^)\n]*) *" " " errmsg))
    (setf (flycheck-error-message err) errmsg)
    (pcase errmsg
      ;; Make long string for fatal error short
      (" ==> Fatal error occurred"
       (setf (flycheck-error-message err) "Fatal Error."))
      ;; Seems like \item is missing
      ("Something's wrong--perhaps a missing \\item."
       (setf (flycheck-error-message err) "Missing \\item."))
      ;; Undefined control sequence extraction
      ((pred (string-prefix-p "Undefined control sequence."))
       (when (string-match ".*\n.*\\\\\\([[:alpha:]@]+\\)" errmsg)
         (let ((sequence (match-string 1 errmsg)))
           (setf (flycheck-error-message err)
                 (format "Undefined control sequence: \\%s" sequence))
           (flycheck-pdflatex--mark
            err (concat "\\\\" (regexp-quote sequence) "\\b")))))
      ;; Undefined reference or citation, point at the key
      ((rx bos (or "Reference" "Citation") " `" (let key (+ (not "'"))) "'")
       (flycheck-pdflatex--mark err (regexp-quote key)))
      ;; A duplicate label has no line number, find the last \label
      ((rx bos "Label `" (let key (+ (not "'"))) "' multiply defined")
       (unless (and (flycheck-error-line err) (> (flycheck-error-line err) 0))
         (flycheck-pdflatex--line-of
          err (concat "\\\\label{" (regexp-quote key) "}") t)))
      ;; This warning has no line number, but belongs to \maketitle
      ("No \\author given."
       (flycheck-pdflatex--line-of err "\\\\maketitle")))
    err))

(defun flycheck-pdflatex--ignored-p (err)
  "Return non-nil when ERR should not be reported."
  (let ((msg (or (flycheck-error-message err) "")))
    (or (and (eq (flycheck-error-level err) 'info)
             (not flycheck-pdflatex-report-boxes))
        (and (eq (flycheck-error-level err) 'warning)
             (seq-some (lambda (re) (string-match-p re msg))
                       flycheck-pdflatex-ignored-warnings)))))

(flycheck-define-checker pdflatex
  "A LaTeX syntax and checker using pdflatex.

The files pdflatex writes go to a directory under
`flycheck-pdflatex-output-directory'.  The .aux file stays there
between checks, so references resolve like in a real build."
  :command ("sh" "-c" (eval flycheck-pdflatex--script) "sh"
            (eval (flycheck-pdflatex--arguments)))
  :error-patterns
  (;; Emergency stop, ignore error, the Fatal error will handle this
   (error line-start (file-name) ":" line ": Emergency stop." line-end)
   ;; Fatal error, flycheck-pdflatex--fix-error will imrpove message
   (error line-start (file-name) ":" line ": "
          (message " ==> Fatal error occurred") (one-or-more not-newline)
          line-end)
   ;; Undefined control sequence, reed extra line te extract sequence
   (error line-start (file-name) ":" line ": "
          (message "Undefined control sequence.\n" (one-or-more not-newline)) line-end)
   ;; Specifiek error message, is generic, keep last
   (error line-start (file-name) ":" line ": LaTeX Error: " (message) line-end)
   ;; Most generic error messages, keep last
   (error line-start (file-name) ":" line ": " (message) line-end)
   ;; LaTeX, font, package and class warnings with a line number,
   ;; possibly spread over continuation lines "(pkg)   ..."
   (warning line-start
            (or "LaTeX" (seq (or "Package" "Class") " " (+ (not (any " \n")))))
            (? " Font") " Warning: "
            (message (+? not-newline)
                     (*? "\n(" (+ (not (any ")\n"))) ")" (* not-newline)))
            (+ " ") "on input line " line "." line-end)
   ;; The same warnings without a line number
   (warning line-start
            (or "LaTeX" (seq (or "Package" "Class") " " (+ (not (any " \n")))))
            (? " Font") " Warning: "
            (message (+ not-newline)
                     (* "\n(" (+ (not (any ")\n"))) ")" (+ not-newline)))
            line-end)
   ;; Overfull and underfull boxes, only with `flycheck-pdflatex-report-boxes'
   (info line-start
         (message (or "Overfull" "Underfull") " \\" (any "hv") "box ("
                  (+ (not (any ")\n"))) ")")
         " in " (or "paragraph" "alignment") " at lines " line "--" end-line
         line-end)
   (info line-start
         (message (or "Overfull" "Underfull") " \\" (any "hv") "box ("
                  (+ (not (any ")\n"))) ")")
         " detected at line " line line-end))
  :error-filter (lambda (errors)
                  (seq-do #'flycheck-pdflatex--fix-errors errors)
                  (flycheck-fill-empty-line-numbers
                   (seq-remove #'flycheck-pdflatex--ignored-p errors)))
  :modes (LaTeX-mode latex-mode tex-mode plain-tex-mode))

(add-to-list 'flycheck-checkers 'pdflatex)

(provide 'flycheck-pdflatex)
;;; flycheck-pdflatex.el ends here
