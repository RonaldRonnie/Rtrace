# Run the Package QA engine against a project

Run the Package QA engine against a project

## Usage

``` r
run_packageqa_scan(root = ".")
```

## Arguments

- root:

  Character scalar project root.

## Value

A list with `is_package` (logical), `diagnostics` (an
`rtrace_diagnostic_set`), and `score` (a `trace_score`).
