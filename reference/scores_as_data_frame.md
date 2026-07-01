# Flatten a named list of trace_scores into a data frame

Useful for feeding into reporters or the REST API.

## Usage

``` r
scores_as_data_frame(scores)
```

## Arguments

- scores:

  Named list of `trace_score` objects.

## Value

A `data.frame` with columns `module`, `score`, `label`.
