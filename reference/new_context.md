# Build a rule evaluation context

Bundles everything a
[Rule](https://rtrace-dev.github.io/rtrace/reference/Rule.md) needs so
rules never re-walk the filesystem or re-parse files themselves (see ADR
0002).

## Usage

``` r
new_context(root, config, files, asts, dependency_graph)
```

## Arguments

- root:

  Character scalar, project root (absolute, normalized).

- config:

  An `rtrace_config` object.

- files:

  A `data.frame` as returned by
  [`scan_files()`](https://rtrace-dev.github.io/rtrace/reference/scan_files.md).

- asts:

  A named list of `rtrace_file_ast`, keyed by absolute path.

- dependency_graph:

  A list as returned by
  [`build_dependency_graph()`](https://rtrace-dev.github.io/rtrace/reference/build_dependency_graph.md).

## Value

An object of class `rtrace_context`.
