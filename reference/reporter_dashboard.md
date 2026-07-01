# Render the Trace Platform dashboard as a standalone HTML document

Render the Trace Platform dashboard as a standalone HTML document

## Usage

``` r
reporter_dashboard(
  platform_result = NULL,
  diagnostics = NULL,
  layers = NULL,
  layer_graph = list(),
  title = "Trace Platform Dashboard",
  include_recommendations = TRUE
)
```

## Arguments

- platform_result:

  A `trace_platform_result` from
  [`platform_scan()`](https://ronaldronnie.github.io/Rtrace/reference/platform_scan.md),
  or a named list of `trace_platform_result`-compatible objects.

- diagnostics:

  An optional `rtrace_diagnostic_set` to include in the violation
  explorer section (typically `platform_result$all_diagnostics`).

- layers:

  Optional character vector of layer names for the architecture
  visualization.

- layer_graph:

  Optional named list (layer -\> character vector of layers it depends
  on) for the architecture SVG.

- title:

  Character scalar dashboard heading.

- include_recommendations:

  Logical; if `TRUE` and the recommendation engine is configured,
  annotate each violation with its built-in recommendation. Default
  `TRUE`.

## Value

Character scalar containing a full HTML document.
