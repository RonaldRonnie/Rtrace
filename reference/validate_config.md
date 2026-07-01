# Validate an RTrace configuration

Checks structural validity and that every declared rule `type` is known.
Called automatically by
[`read_config()`](https://ronaldronnie.github.io/Rtrace/reference/read_config.md);
exposed separately so the CLI's `validate` command can run it without
triggering a scan.

## Usage

``` r
validate_config(config)
```

## Arguments

- config:

  An `rtrace_config` object.

## Value

Invisibly, `TRUE` if valid. Raises an error (via
[`rlang::abort`](https://rlang.r-lib.org/reference/abort.html))
describing every problem found if not.
