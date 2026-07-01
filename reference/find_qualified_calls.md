# Find all namespace-qualified calls to a given `pkg::fn` (or `pkg:::fn`)

Find all namespace-qualified calls to a given `pkg::fn` (or `pkg:::fn`)

## Usage

``` r
find_qualified_calls(ast, pkg, fn_name)
```

## Arguments

- ast:

  An `rtrace_file_ast`.

- pkg:

  Character scalar package name (e.g. `"reshape2"`).

- fn_name:

  Character scalar function name (e.g. `"melt"`).

## Value

A `data.frame` with columns `line1`, `col1` (position of the `pkg`
token), one row per call site. Zero rows if the file failed to parse or
contains no such calls.
