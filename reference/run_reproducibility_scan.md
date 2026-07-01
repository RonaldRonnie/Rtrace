# Run the reproducibility engine against a project

Builds a reproducibility context, evaluates all registered
`reproducibility.*` rules, and returns both the diagnostic set and a
`trace_score`.

## Usage

``` r
run_reproducibility_scan(
  root = ".",
  config = default_config(),
  use_cache = FALSE
)
```

## Arguments

- root:

  Character scalar project root.

- config:

  An `rtrace_config` object. Defaults to
  [`default_config()`](https://ronaldronnie.github.io/Rtrace/reference/default_config.md).

- use_cache:

  Logical; passed to
  [`build_context()`](https://ronaldronnie.github.io/Rtrace/reference/build_context.md).
  Default `FALSE`.

## Value

A list with `diagnostics` (an `rtrace_diagnostic_set`) and `score` (a
`trace_score`).
