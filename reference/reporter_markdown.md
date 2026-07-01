# Render a diagnostic set as a Markdown report

Suitable for posting as a CI pull-request comment or writing to a
standalone `.md` file.

## Usage

``` r
reporter_markdown(diagnostics, title = "RTrace Scan Report")
```

## Arguments

- diagnostics:

  An `rtrace_diagnostic_set`.

- title:

  Character scalar heading for the report.

## Value

Character scalar Markdown string.
