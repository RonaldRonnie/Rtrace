# Parse an R source file

Wraps base R's `parse(keep.source = TRUE)` and
[`utils::getParseData()`](https://rdrr.io/r/utils/getParseData.html).
Deliberately depends on no third-party AST representation (see ADR 0001
in `dev/adr/` in the package source) so RTrace can be used alongside
`lintr` without internal coupling.

## Usage

``` r
parse_file(path)
```

## Arguments

- path:

  Character scalar path to an R source file.

## Value

An object of class `rtrace_file_ast` with fields `path`, `expr` (the
parsed `expression` object, or `NULL`), `parse_data` (a `data.frame`
from [`getParseData()`](https://rdrr.io/r/utils/getParseData.html), or
`NULL`), `lines` (character vector of source lines), and `error` (a
condition object, or `NULL`).

## Details

Syntax errors are captured rather than raised: the returned object's
`error` field is non-`NULL` and `expr`/`parse_data` are `NULL`, so a
single broken file does not abort a project-wide scan.
