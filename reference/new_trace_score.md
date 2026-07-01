# Construct a trace_score object

Construct a trace_score object

## Usage

``` r
new_trace_score(score, label = NULL, breakdown = list(), module_id = NULL)
```

## Arguments

- score:

  Integer 0-100.

- label:

  Optional character scalar label (derived from score if `NULL`).

- breakdown:

  Named list of breakdown details.

- module_id:

  Optional character scalar identifying which module the score belongs
  to.

## Value

A `trace_score` object.
