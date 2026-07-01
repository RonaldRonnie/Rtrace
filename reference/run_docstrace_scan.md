# Run the DocsTrace engine against a project

Run the DocsTrace engine against a project

## Usage

``` r
run_docstrace_scan(root = ".")
```

## Arguments

- root:

  Character scalar project root.

## Value

A list with `diagnostics` (an `rtrace_diagnostic_set`) and `score` (a
`trace_score`).
