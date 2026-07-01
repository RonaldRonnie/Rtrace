# Compute the cyclomatic complexity of a function body

Counts decision points (`if`, `for`, `while`, `repeat`, `&&`, `||`,
`case_when`-style nested `ifelse`, and each
[`switch()`](https://rdrr.io/r/base/switch.html) branch) plus one, the
standard McCabe formulation.

## Usage

``` r
cyclomatic_complexity(fn_expr)
```

## Arguments

- fn_expr:

  A function expression (the value returned in the `expr` field of
  [`top_level_functions()`](https://ronaldronnie.github.io/Rtrace/reference/top_level_functions.md)
  entries).

## Value

Integer scalar complexity score.
