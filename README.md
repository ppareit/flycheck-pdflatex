# Flycheck-pdflatex

`flycheck-pdflatex` is a Flycheck checker for TeX/LaTeX files using the `pdflatex` compiler. It adds some extra functionality that only works with `pdflatex`, such as improved error messages and warnings.

## Installation

Assuming you are using `use-package` and `straight.el`, add the following code to your `.emacs`:

```elisp
(use-package flycheck-pdflatex
  :straight (:package "flycheck-pdflatex"
              :host github
              :repo "ppareit/flycheck-pdflatex"))
```

If this package gets updated, you then can pull in the latest changes with `M-x straight-pull-all` or `M-x straight-pull-package` and restart emacs.

## Usage

To use `flycheck-pdflatex`, simply open a TeX/LaTeX file in Emacs and start Flycheck mode. `flycheck-pdflatex` will automatically be used to check the syntax of your file.

## Features

- Runs `pdflatex` on your TeX/LaTeX file and reports any errors or warnings.
- Keeps the source directory clean: the `.aux`, `.log` and helper files (such as the `.asy` files of the `asymptote` package) go to a separate output directory.
- Keeps the `.aux` file between checks, so references resolve like in a real build. When there is no `.aux` file yet, `pdflatex` runs one extra pass first.
- Reports LaTeX, package, class and font warnings on the line they belong to, and points at the key of an undefined `\ref` or `\cite`.
- Leaves out warnings you cannot act on while checking, such as `Rerun to get cross-references right` or undefined labels of packages like `mdframed`.
- Formats error messages for fatal errors to make them shorter and more readable.
- Fixes some common errors and warnings reported by `pdflatex`, such as undefined control sequences and missing `\item` errors.
- Works with `use-package` and `straight.el` for easy installation and management.

## Customization

- `flycheck-pdflatex-output-directory`: root of the directories where `pdflatex` writes its files, one per source directory. Defaults to `temporary-file-directory`.
- `flycheck-pdflatex-report-boxes`: when non-nil, overfull and underfull boxes are reported as info. Defaults to nil.
- `flycheck-pdflatex-ignored-warnings`: regexps for warnings that are not reported.

The checker runs `pdflatex` through `sh`, so it needs a POSIX shell.

## Troubleshooting

- Check to see if the file is in you load path:  `M-: (locate-library "flycheck-pdflatex") RET`.
- Check to see if the file is loaded: `M-: (featurep 'flycheck-pdflatex) RET`.
- Check if pdflatex is registered in flycheck: `M-: (memq 'pdflatex flycheck-checkers) RET`
- Open an `.tex`-file and run `M-x flycheck-verify-setup RET`


## License

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

## Programming

Pieter Pareit
