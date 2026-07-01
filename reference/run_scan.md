# Run a full RTrace scan over a project directory

Convenience wrapper combining
[`build_context()`](https://rtrace-dev.github.io/rtrace/reference/build_context.md)
and
[`run_rules()`](https://rtrace-dev.github.io/rtrace/reference/run_rules.md)
— the top-level entry point used by the CLI's `scan` command and by R
scripts that want to run RTrace programmatically.

## Usage

``` r
run_scan(root = ".", config = default_config(), use_cache = FALSE)
```

## Arguments

- root:

  Character scalar path to the project root.

- config:

  An `rtrace_config` object. Defaults to
  [`default_config()`](https://rtrace-dev.github.io/rtrace/reference/default_config.md).

- use_cache:

  Logical, passed through to
  [`build_context()`](https://rtrace-dev.github.io/rtrace/reference/build_context.md).
  Default `FALSE`.

## Value

An `rtrace_diagnostic_set`.
