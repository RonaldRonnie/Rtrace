# Render a diagnostic set as CSV

One row per diagnostic, columns
`rule_id, severity, file, line, column, message, suggestion, doc_url`
(see
[`as.data.frame.rtrace_diagnostic_set()`](https://rtrace-dev.github.io/rtrace/reference/as.data.frame.rtrace_diagnostic_set.md)).
Missing values are written as empty fields, not the string `"NA"`.

## Usage

``` r
reporter_csv(diagnostics)
```

## Arguments

- diagnostics:

  An `rtrace_diagnostic_set`.

## Value

Character scalar CSV text (including a header row).
