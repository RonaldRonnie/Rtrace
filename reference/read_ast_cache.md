# Read a project's AST cache from disk

Read a project's AST cache from disk

## Usage

``` r
read_ast_cache(root)
```

## Arguments

- root:

  Character scalar project root.

## Value

A named list (absolute path -\> `list(hash=, ast=)`). Empty list if no
cache file exists, or if it exists but can't be read (corrupt cache
files are treated as a cold cache, not an error).
