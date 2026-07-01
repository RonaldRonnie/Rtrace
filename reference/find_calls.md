# Find all calls to a given function name in a parsed file

Find all calls to a given function name in a parsed file

## Usage

``` r
find_calls(ast, fn_name)
```

## Arguments

- ast:

  An `rtrace_file_ast`.

- fn_name:

  Character scalar function name (e.g. `"setwd"`).

## Value

A `data.frame` with columns `line1`, `col1`, `text` (the call site's
source text where available), one row per call site. Zero rows if the
file failed to parse or contains no such calls.
