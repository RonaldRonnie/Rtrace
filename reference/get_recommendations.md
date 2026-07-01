# Get recommendations for all diagnostics in a set

Get recommendations for all diagnostics in a set

## Usage

``` r
get_recommendations(diagnostics, context_hint = NULL)
```

## Arguments

- diagnostics:

  An `rtrace_diagnostic_set`.

- context_hint:

  Optional character scalar.

## Value

A named list of `trace_recommendation` objects, one per unique `rule_id`
encountered.
