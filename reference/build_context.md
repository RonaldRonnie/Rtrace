# Build a full rule-evaluation context for a project directory

Orchestrates
[`scan_files()`](https://rtrace-dev.github.io/rtrace/reference/scan_files.md),
parsing (one call per discovered file, via
[`parse_files_cached()`](https://rtrace-dev.github.io/rtrace/reference/parse_files_cached.md)),
and
[`build_dependency_graph()`](https://rtrace-dev.github.io/rtrace/reference/build_dependency_graph.md)
into a single
[`new_context()`](https://rtrace-dev.github.io/rtrace/reference/new_context.md).
This is the function the CLI's `scan` command and
[`run_scan()`](https://rtrace-dev.github.io/rtrace/reference/run_scan.md)
call; most users will not call it directly.

## Usage

``` r
build_context(root, config, use_cache = FALSE)
```

## Arguments

- root:

  Character scalar path to the project root.

- config:

  An `rtrace_config` object.

- use_cache:

  Logical; reuse a `.rtrace_cache/` AST cache from a previous run where
  file content hashes match, instead of re-parsing every file. Default
  `FALSE` — see
  [ast-cache](https://rtrace-dev.github.io/rtrace/reference/ast-cache.md)
  for why this is opt-in. Only the parse step is cached; diagnostics are
  always recomputed.

## Value

An `rtrace_context` object.
