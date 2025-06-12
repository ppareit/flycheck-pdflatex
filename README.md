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
- Formats error messages for fatal errors to make them shorter and more readable.
- Fixes some common errors and warnings reported by `pdflatex`, such as undefined control sequences and missing `\item` errors.
- Works with `use-package` and `straight.el` for easy installation and management.

## Troubleshooting

- Check to see if the file is in you load path:  `M-: (locate-library "flycheck-pdflatex") RET`.
- Check to see if the file is loaded: `M-: (featurep 'flycheck-pdflatex) RET`.
- Check if pdflatex is registered in flycheck: `M-: (memq 'pdflatex flycheck-checkers) RET`
- Open an `.tex`-file and run `M-x flycheck-verify-setup RET`


## License

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

## Programming

Pieter Pareit
