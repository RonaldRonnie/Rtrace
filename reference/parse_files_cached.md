# Parse a set of files, reusing cached ASTs where the content hash matches

Parse a set of files, reusing cached ASTs where the content hash matches

## Usage

``` r
parse_files_cached(paths, root, use_cache = FALSE)
```

## Arguments

- paths:

  Character vector of absolute file paths.

- root:

  Character scalar project root (used to locate the cache file).

- use_cache:

  Logical; if `FALSE`, parses every file fresh and doesn't touch the
  cache file at all (the default, non-caching, path).

## Value

A named list of `rtrace_file_ast`, keyed by absolute path — same shape
as parsing every file directly with
[`parse_file()`](https://ronaldronnie.github.io/Rtrace/reference/parse_file.md).
