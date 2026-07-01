# Register a recommendation provider

A provider is any function `function(diagnostic, context_hint)` that
returns a `trace_recommendation` object (see
[`new_recommendation()`](https://ronaldronnie.github.io/Rtrace/reference/new_recommendation.md)).
Providers can call external AI APIs, a local model endpoint, or use any
other strategy.

## Usage

``` r
register_recommendation_provider(id, provider_fn, description = "")
```

## Arguments

- id:

  Character scalar provider id (e.g. `"claude"`, `"openai"`).

- provider_fn:

  A function `function(diagnostic, context_hint=NULL)` returning a
  `trace_recommendation`.

- description:

  One-line description of the provider.

## Value

Invisibly, the provider id.
