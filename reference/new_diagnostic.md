# Create a diagnostic

A `Diagnostic` is the atomic unit of output produced by a rule: a single
finding at a single location.

## Usage

``` r
new_diagnostic(
  rule_id,
  severity = c("error", "warning", "info"),
  file,
  line = NA_integer_,
  column = NA_integer_,
  message,
  suggestion = NULL,
  doc_url = NULL
)
```

## Arguments

- rule_id:

  Character scalar. The id of the rule that produced this diagnostic
  (e.g. `"complexity.cyclomatic"`).

- severity:

  One of `"error"`, `"warning"`, `"info"`.

- file:

  Character scalar. Path to the file the diagnostic refers to, relative
  to the project root where possible.

- line:

  Integer scalar or `NA_integer_`. 1-indexed line number.

- column:

  Integer scalar or `NA_integer_`. 1-indexed column number.

- message:

  Character scalar. Human-readable description of the problem.

- suggestion:

  Character scalar or `NULL`. An actionable fix suggestion.

- doc_url:

  Character scalar or `NULL`. A link to rule documentation.

## Value

An object of class `rtrace_diagnostic`.
