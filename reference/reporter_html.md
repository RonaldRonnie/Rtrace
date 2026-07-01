# Render a diagnostic set as a standalone HTML report

Produces a single self-contained HTML file (inline CSS, no external
assets or JavaScript dependencies) grouping diagnostics by file, with a
summary panel and per-severity color coding. Suitable for attaching as a
CI artifact or opening directly in a browser.

## Usage

``` r
reporter_html(
  diagnostics,
  title = "RTrace Scan Report",
  layers = NULL,
  layer_graph = list()
)
```

## Arguments

- diagnostics:

  An `rtrace_diagnostic_set`.

- title:

  Character scalar report heading.

- layers:

  Optional character vector of configured layer names (e.g.
  `setdiff(unique(context$files$layer), "(unassigned)")`). When
  non-empty, an "Architecture Overview" section is rendered above the
  diagnostics list via
  [`render_layer_graph_svg()`](https://ronaldronnie.github.io/Rtrace/reference/render_layer_graph_svg.md).
  Omit (the default) for a diagnostics-only report — `reporter_html()`'s
  primary contract is still just `diagnostics`, like every other
  reporter (see ADR 0002).

- layer_graph:

  Optional named list, `context$dependency_graph$layer_graph`. Ignored
  if `layers` is empty.

## Value

Character scalar containing a full HTML document.
