# Scan data files in a project root

Finds all CSV, TSV, and (optionally) Excel files under `root`, skipping
hidden directories and common generated-output directories, and returns
a `data.frame` describing every discovered data file.

## Usage

``` r
scan_data_files(root, max_rows = 1000L)
```

## Arguments

- root:

  Character scalar project root.

- max_rows:

  Integer; maximum rows to read from each file for quality checks
  (default 1000, to keep scanning fast).

## Value

A `data.frame` with columns `path`, `rel_path`, `type` (`"csv"`,
`"tsv"`, `"excel"`), `size_bytes`, `n_cols`, `n_rows_sample`,
`col_names`, `has_header`, `encoding_ok`, `read_error`.
