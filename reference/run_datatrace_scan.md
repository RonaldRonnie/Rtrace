# Run the DataTrace engine against a project

Run the DataTrace engine against a project

## Usage

``` r
run_datatrace_scan(root = ".")
```

## Arguments

- root:

  Character scalar project root.

## Value

A list with `data_files` (the scan data frame from
[`scan_data_files()`](https://ronaldronnie.github.io/Rtrace/reference/scan_data_files.md)),
`diagnostics` (an `rtrace_diagnostic_set`), and `score` (a
`trace_score`).
