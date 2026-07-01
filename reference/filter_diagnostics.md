# Filter a diagnostic set

Filter a diagnostic set

## Usage

``` r
filter_diagnostics(x, severity = NULL, rule_id = NULL, file = NULL)
```

## Arguments

- x:

  An `rtrace_diagnostic_set`.

- severity:

  Optional character vector of severities to keep.

- rule_id:

  Optional character vector of rule ids to keep.

- file:

  Optional character vector of file paths to keep.

## Value

A filtered `rtrace_diagnostic_set`.
