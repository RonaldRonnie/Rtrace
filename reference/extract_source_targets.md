# Extract `source()` target file paths, resolved to absolute paths

Only string-literal `source("...")` targets are resolved; dynamically
constructed paths (e.g. `source(file.path(...))`) are skipped, a
documented limitation (see ADR 0002).

## Usage

``` r
extract_source_targets(ast, base_dir, root = NULL)
```

## Arguments

- ast:

  An `rtrace_file_ast`.

- base_dir:

  Fallback directory the relative
  [`source()`](https://rdrr.io/r/base/source.html) argument is resolved
  against (the sourcing file's own directory) when a
  project-root-relative match does not exist.

- root:

  Optional project root, tried first (see
  [`build_dependency_graph()`](https://rtrace-dev.github.io/rtrace/reference/build_dependency_graph.md)).

## Value

Character vector of normalized absolute paths (only for targets that
exist on disk).
