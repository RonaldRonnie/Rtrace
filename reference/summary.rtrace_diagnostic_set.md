# Summarize a diagnostic set by severity

Summarize a diagnostic set by severity

## Usage

``` r
# S3 method for class 'rtrace_diagnostic_set'
summary(object, ...)
```

## Arguments

- object:

  An `rtrace_diagnostic_set`.

- ...:

  Unused.

## Value

A named integer vector with counts per severity level (`error`,
`warning`, `info`).
