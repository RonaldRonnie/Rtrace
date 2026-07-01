# Translate a glob pattern to a regular expression

Supports `*` (any characters except `/`), `**` (any characters including
`/`), and `?` (single character). Intentionally small: RTrace globs are
matched against POSIX-style relative paths only.

## Usage

``` r
glob_to_regex(glob)
```

## Arguments

- glob:

  Character scalar glob pattern.

## Value

Character scalar regular expression, anchored at both ends.
