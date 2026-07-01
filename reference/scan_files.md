# Walk a project directory for R source files

Discovers `.R`/`.r` files under `root`, skipping
[`default_excludes()`](https://ronaldronnie.github.io/Rtrace/reference/default_excludes.md)
plus any patterns declared in `config$exclude`, then assigns each
surviving file to a configured layer via longest-glob-prefix match
against `config$layers`.

## Usage

``` r
scan_files(root, config = default_config())
```

## Arguments

- root:

  Character scalar, path to the project root.

- config:

  An `rtrace_config` object (see
  [`read_config()`](https://ronaldronnie.github.io/Rtrace/reference/read_config.md)).

## Value

A `data.frame` with columns `path` (absolute), `rel_path` (POSIX-style,
relative to `root`), and `layer` (character; `"(unassigned)"` if no
configured layer matches).
