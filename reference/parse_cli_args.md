# Parse RTrace CLI arguments

A small, dependency-free `--flag value` parser (see ADR 0002 for why no
CLI-parsing package is used). Not a general-purpose parser: it is scoped
exactly to RTrace's own command set.

## Usage

``` r
parse_cli_args(argv)
```

## Arguments

- argv:

  Character vector, as returned by `commandArgs(trailingOnly = TRUE)`.

## Value

A list with `command` (character scalar or `NA`), `options` (named list
of flag values; boolean flags get `TRUE`), and `positional` (character
vector of non-flag, non-command arguments).
