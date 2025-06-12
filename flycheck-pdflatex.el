;;; flycheck-pdflatex.el --- LaTeX flycheck checker with pdflatex compiler

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

(defun flycheck-pdflatex--fix-errors (err)
  "Fix pdflatex errors, ERR, to easier to read erros."
  (let ((errmsg (flycheck-error-message err)))
    (pcase errmsg
      ;; Make long string for fatal error short
      (" ==> Fatal error occurred"
       (setf (flycheck-error-message err) "Fatal Error."))
      ;; Seems like \item is missing
      ("Something's wrong--perhaps a missing \\item."
       (setf (flycheck-error-message err) "Missing \\item."))
      ;; Undefined control sequence extraction
      ((pred (lambda (s) (string-prefix-p "Undefined control sequence." s)))
       (when (string-match ".*\n.*\\\\\\([[:alpha:]]*\\)" errmsg)
	 (let* ((sequence (match-string 1 errmsg))
		(column (with-current-buffer (flycheck-error-buffer err)
			  (save-excursion
			    (goto-char (point-min))
			    (forward-line (1- (flycheck-error-line err)))
			    (string-match sequence (buffer-substring
						    (line-beginning-position)
						    (line-end-position))))))
		(end-column (+ column (length sequence) 1)))
	   (setf (flycheck-error-message err)
		 (format "Undefined control sequence: \\%s" sequence))
	   (setf (flycheck-error-column err) column)
	   (setf (flycheck-error-end-column err) end-column))))
      ;; This warning has no line number, but belongs to \maketitle
      ("No \\author given."
       (let ((line (with-current-buffer (flycheck-error-buffer err)
		     (save-excursion
		       (goto-char (point-min))
		       (search-forward "\\maketitle")
		       (line-number-at-pos)))))
	 (setf (flycheck-error-line err) line))))
    err))

(flycheck-define-checker pdflatex
  "A LaTeX syntax and checker using pdflatex."
  :command ("pdflatex"
	    "-cnf-line=max_print_line=1024" ; Don't wrap errors
	    "-file-line-error"		    ; Show line numbers plz
	    "-draftmode"		    ; Don't generate pdf
	    "-interaction=nonstopmode"	    ; Keep running
	    source-inplace)
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
   ;; Most generic warning messages, keep last
   (warning line-start "LaTeX Warning: " (message) line-end))
  :error-filter (lambda (errors)
		  (seq-do #'flycheck-pdflatex--fix-errors errors)
		  (flycheck-fill-empty-line-numbers errors)
		  errors)
  :modes (LaTeX-mode latex-mode tex-mode plain-tex-mode))

(add-to-list 'flycheck-checkers 'pdflatex)

(provide 'flycheck-pdflatex)
;;; flycheck-pdflatex.el ends here

