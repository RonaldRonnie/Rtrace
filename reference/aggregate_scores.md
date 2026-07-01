# Aggregate multiple trace_score objects into a single platform score

Takes a named list of `trace_score` objects (one per module) and
computes the weighted mean, defaulting to equal weights.

## Usage

``` r
aggregate_scores(scores, weights = NULL)
```

## Arguments

- scores:

  Named list of `trace_score` objects.

- weights:

  Named numeric vector of weights (names match `scores`). Defaults to
  equal weights.

## Value

A `trace_score` object with `module_id = "platform"`.
