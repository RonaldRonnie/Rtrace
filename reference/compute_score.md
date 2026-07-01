# Compute a 0-100 quality score from a diagnostic set

The scoring model:

- Start at 100 (perfect).

- Subtract `error_penalty` per `error`-severity diagnostic (default 10).

- Subtract `warning_penalty` per `warning`-severity diagnostic (default
  3).

- Subtract `info_penalty` per `info`-severity diagnostic (default 1).

- Clamp to \[0, 100\].

## Usage

``` r
compute_score(
  diagnostics,
  error_penalty = 10,
  warning_penalty = 3,
  info_penalty = 1,
  baseline = 100
)
```

## Arguments

- diagnostics:

  An `rtrace_diagnostic_set`.

- error_penalty:

  Numeric, score deducted per error.

- warning_penalty:

  Numeric, score deducted per warning.

- info_penalty:

  Numeric, score deducted per info.

- baseline:

  Numeric, starting score (default 100).

## Value

A `trace_score` object.

## Details

The penalties are intentionally modest defaults so that one error does
not collapse a score to zero on a large project. Pass custom penalties
to tune the scoring model for a specific module's domain.
