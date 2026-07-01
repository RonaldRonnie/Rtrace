# Find cycles in a directed graph

DFS-based cycle detection over an adjacency-list graph, used for the
`dependency.circular` rule over the layer-level dependency graph.

## Usage

``` r
find_cycles(graph)
```

## Arguments

- graph:

  A named list: node name -\> character vector of node names it points
  to.

## Value

A list of character vectors, each one a cycle expressed as a sequence of
node names (first element repeated as the last to show closure). Empty
list if the graph is acyclic.
