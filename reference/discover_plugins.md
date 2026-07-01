# Discover and load installed RTrace plugin packages

Scans every installed package in
[`.libPaths()`](https://rdrr.io/r/base/libPaths.html) for the
`Config/rtrace/plugin` DESCRIPTION field. Any package with this field
set to `"true"` (case-insensitive) is loaded with
[`requireNamespace()`](https://rdrr.io/r/base/ns-load.html), which
triggers the package's `.onLoad()` to self-register its rules.

## Usage

``` r
discover_plugins(lib_paths = .libPaths(), verbose = FALSE)
```

## Arguments

- lib_paths:

  Character vector of library paths to scan. Defaults to
  [`.libPaths()`](https://rdrr.io/r/base/libPaths.html).

- verbose:

  Logical; if `TRUE`, prints a line for each plugin found or skipped.
  Default `FALSE`.

## Value

Invisibly, a character vector of plugin package names that were loaded.

## Details

Safe to call multiple times — already-registered rules are not
double-registered (they produce a warning and overwrite, per
[`register_rule()`](https://ronaldronnie.github.io/Rtrace/reference/register_rule.md)).
