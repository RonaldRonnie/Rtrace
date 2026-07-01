# RTrace CLI entry point

Dispatches a parsed command line to the matching `cmd_*` function. Used
by the `inst/rtrace` executable; callable directly for testing.

## Usage

``` r
rtrace_cli(argv = commandArgs(trailingOnly = TRUE))
```

## Arguments

- argv:

  Character vector of command-line arguments (as from
  `commandArgs(trailingOnly = TRUE)`).

## Value

Integer exit status (0 = success, 1 = failure).
