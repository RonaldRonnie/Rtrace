# Build the reproducibility context

Returns a list extending the standard `rtrace_context` with
reproducibility-specific fields (renv.lock presence, DESCRIPTION
content, etc.) derived from the project root's file system.

## Usage

``` r
build_reproducibility_context(root)
```

## Arguments

- root:

  Character scalar project root.

## Value

A named list of reproducibility metadata.
