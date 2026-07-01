# Render a diagnostic set as JSON

Output schema:

    {
      "schema_version": 1,
      "summary": {"error": 0, "warning": 2, "info": 1},
      "diagnostics": [
        {"rule_id": "...", "severity": "...", "file": "...", "line": 1,
         "column": null, "message": "...", "suggestion": null, "doc_url": null}
      ]
    }

## Usage

``` r
reporter_json(diagnostics, pretty = TRUE)
```

## Arguments

- diagnostics:

  An `rtrace_diagnostic_set`.

- pretty:

  Logical; pretty-print the JSON. Default `TRUE`.

## Value

Character scalar JSON string.
