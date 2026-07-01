# Find all `<<-` (superassignment) usages in a parsed file

Find all `<<-` (superassignment) usages in a parsed file

## Usage

``` r
find_superassignments(ast)
```

## Arguments

- ast:

  An `rtrace_file_ast`.

## Value

A `data.frame` with columns `line1`, `col1`.
