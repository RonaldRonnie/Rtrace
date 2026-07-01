# Render a diagnostic set as SARIF 2.1.0

Produces a minimal, valid [SARIF
2.1.0](https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.html)
log with a single run, suitable for upload to GitHub code scanning
(`github/codeql-action/upload-sarif`) or any other SARIF-consuming
dashboard.

## Usage

``` r
reporter_sarif(diagnostics, pretty = TRUE)
```

## Arguments

- diagnostics:

  An `rtrace_diagnostic_set`.

- pretty:

  Logical; pretty-print the JSON. Default `TRUE`.

## Value

Character scalar SARIF (JSON) string.

## Details

RTrace severities map to SARIF levels as `error` -\> `error`, `warning`
-\> `warning`, `info` -\> `note` (SARIF has no `info` level).
