# Build a project dependency graph

Produces two graphs from a set of parsed files: a package-level graph
(which CRAN/Bioconductor packages each file imports) and a layer-level
graph (which configured layers reference which other layers, derived
from [`source()`](https://rdrr.io/r/base/source.html) calls whose target
resolves to a file in a different layer). See ADR 0002 in `dev/adr/` in
the package source for the resolution heuristics and known limitations.

## Usage

``` r
build_dependency_graph(files, asts, root = NULL)
```

## Arguments

- files:

  A `data.frame` as returned by
  [`scan_files()`](https://ronaldronnie.github.io/Rtrace/reference/scan_files.md)
  (`path`, `rel_path`, `layer`).

- asts:

  A named list of `rtrace_file_ast`, keyed by `path`, one entry per row
  of `files`.

- root:

  Character scalar, the project root
  [`source()`](https://rdrr.io/r/base/source.html) arguments are tried
  against first (the dominant convention: analysis scripts are run from
  the project root and [`source()`](https://rdrr.io/r/base/source.html)
  project-root-relative paths). Falls back to resolving relative to the
  sourcing file's own directory if no project-root-relative match
  exists.

## Value

A list with `package_imports` (named list: `rel_path` -\> character
vector of imported package names) and `layer_graph` (named list: layer
name -\> character vector of layer names it references).
