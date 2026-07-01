# Run a full Trace Platform scan across all registered modules

Calls each registered module's `scan_fn(root, config)` in sequence,
collects all diagnostics and scores, and returns a
`trace_platform_result`.

## Usage

``` r
platform_scan(
  root = ".",
  config = default_config(),
  use_cache = FALSE,
  modules = NULL
)
```

## Arguments

- root:

  Character scalar project root.

- config:

  An `rtrace_config` object. Defaults to
  [`default_config()`](https://ronaldronnie.github.io/Rtrace/reference/default_config.md).

- use_cache:

  Logical; passed to RTrace's
  [`build_context()`](https://ronaldronnie.github.io/Rtrace/reference/build_context.md).
  Default `FALSE`.

- modules:

  Character vector of module ids to run. Default `NULL` (run all
  registered modules).

## Value

A `trace_platform_result` object.
