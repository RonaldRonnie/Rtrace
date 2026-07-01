# Extract package names imported by a file

Looks for [`library(pkg)`](https://rdrr.io/r/base/library.html),
[`require(pkg)`](https://rdrr.io/r/base/library.html),
[`requireNamespace("pkg")`](https://rdrr.io/r/base/ns-load.html), and
`pkg::fn` / `pkg:::fn` usages.

## Usage

``` r
extract_package_imports(ast)
```

## Arguments

- ast:

  An `rtrace_file_ast`.

## Value

Character vector of unique package names.
