# Start the Trace Platform REST API server

Requires the `plumber` package (`install.packages("plumber")`).

## Usage

``` r
start_api(host = "127.0.0.1", port = 8394L, docs = TRUE)
```

## Arguments

- host:

  Character scalar. Interface to listen on. Default `"127.0.0.1"`.

- port:

  Integer. Port number. Default `8394`.

- docs:

  Logical. If `TRUE` (default), mounts the Swagger UI at `/`.

## Value

Invisibly, the `plumber` router object (so callers can modify it before
`$run()` if needed). Blocks if the server is started interactively.
