# Locate top-level function definitions in a parsed file

Locate top-level function definitions in a parsed file

## Usage

``` r
top_level_functions(ast)
```

## Arguments

- ast:

  An `rtrace_file_ast`.

## Value

A list of `list(name=, line1=, line2=, n_lines=, expr=)`, one entry per
top-level `name <- function(...) ...` or `name = function(...) ...`
assignment. Anonymous/nested functions are not included (top-level only,
matching how rule authors typically reason about "a function" in a
project).
