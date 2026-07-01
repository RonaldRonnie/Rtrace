# Run the configured rule set against a context

Resolves the active rule set from `context$config$rules`, evaluates each
enabled rule's
[Rule](https://rtrace-dev.github.io/rtrace/reference/Rule.md)`$check()`,
tags every diagnostic with the rule's *configured* severity (falling
back to the rule's default severity), and collects results into a single
`rtrace_diagnostic_set`.

## Usage

``` r
run_rules(context)
```

## Arguments

- context:

  An `rtrace_context` (see
  [`build_context()`](https://rtrace-dev.github.io/rtrace/reference/build_context.md)).

## Value

An `rtrace_diagnostic_set`.

## Details

A rule that errors during evaluation does not abort the scan: its error
is captured and surfaced as a single `rule-error` diagnostic so the rest
of the rule set still runs.
