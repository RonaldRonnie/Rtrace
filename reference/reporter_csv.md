# Render a diagnostic set as CSV

One row per diagnostic, columns
`rule_id, severity, file, line, column, message, suggestion, doc_url`
(see
[`as.data.frame.rtrace_diagnostic_set()`](https://ronaldronnie.github.io/Rtrace/reference/as.data.frame.rtrace_diagnostic_set.md)).
Missing values are written as empty fields, not the string `"NA"`. The
`file`, `message`, and `suggestion` columns are sanitized against CSV
formula injection (see `sanitize_csv_field()`) since they can echo
scanned, potentially untrusted source content.

## Usage

``` r
reporter_csv(diagnostics)
```

## Arguments

- diagnostics:

  An `rtrace_diagnostic_set`.

## Value

Character scalar CSV text (including a header row).
