# Get a recommendation for a diagnostic

Dispatches to the active provider to generate a `trace_recommendation`
for a single diagnostic.

## Usage

``` r
get_recommendation(diagnostic, context_hint = NULL)
```

## Arguments

- diagnostic:

  An `rtrace_diagnostic` object.

- context_hint:

  Optional character scalar; additional context to pass to the provider
  (e.g. the file contents at the diagnostic location).

## Value

A `trace_recommendation`.
