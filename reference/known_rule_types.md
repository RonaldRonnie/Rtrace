# Known rule type identifiers

Returns the `type` strings recognized by the built-in rule registry,
used by
[`validate_config()`](https://ronaldronnie.github.io/Rtrace/reference/validate_config.md)
to reject typos in `rtrace.yml` at validation time rather than silently
ignoring them at scan time.

## Usage

``` r
known_rule_types()
```

## Value

Character vector of registered rule ids.
