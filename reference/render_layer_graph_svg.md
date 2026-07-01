# Render a layer dependency graph as an inline SVG diagram

A simple, dependency-free circular layout (nodes placed evenly around a
circle): not a general graph-layout algorithm, and edge/label overlap is
not optimized away, but it's legible for the small-to-moderate layer
counts (well under 15) typical of an RTrace `layers:` configuration. No
external JS/CSS — pure inline SVG, consistent with
[`reporter_html()`](https://rtrace-dev.github.io/rtrace/reference/reporter_html.md)
being a single standalone file.

## Usage

``` r
render_layer_graph_svg(layers, layer_graph = list(), width = 560, height = 420)
```

## Arguments

- layers:

  Character vector of layer names to draw as nodes. Returns `NULL` if
  empty.

- layer_graph:

  A named list as in `context$dependency_graph$layer_graph` (layer name
  -\> character vector of layer names it depends on).

- width, height:

  Integer pixel dimensions of the SVG viewport.

## Value

Character scalar `<svg>...</svg>` markup, or `NULL` if `layers` is
empty.

## Details

Edges that participate in a cycle (per
[`find_cycles()`](https://rtrace-dev.github.io/rtrace/reference/find_cycles.md))
are drawn in red; all other edges are drawn in gray.
