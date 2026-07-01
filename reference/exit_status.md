# Determine the process exit status implied by a diagnostic set

Determine the process exit status implied by a diagnostic set

## Usage

``` r
exit_status(x, fail_on = c("error", "warning"))
```

## Arguments

- x:

  An `rtrace_diagnostic_set`.

- fail_on:

  Severity threshold that causes a nonzero exit status: `"error"`
  (default) or `"warning"`.

## Value

Integer `0` or `1`.
