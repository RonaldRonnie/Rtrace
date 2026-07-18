# Start the Trace Platform REST API server

Requires the `plumber` package (`install.packages("plumber")`).

## Usage

``` r
start_api(
  host = "127.0.0.1",
  port = 8394L,
  docs = TRUE,
  token = Sys.getenv("RTRACE_API_TOKEN", ""),
  allowed_roots = getwd()
)
```

## Arguments

- host:

  Character scalar. Interface to listen on. Default `"127.0.0.1"`.

- port:

  Integer. Port number. Default `8394`.

- docs:

  Logical. If `TRUE` (default), mounts the Swagger UI at `/`.

- token:

  Character scalar. Bearer token required on every request
  (`Authorization: Bearer <token>`). Defaults to the `RTRACE_API_TOKEN`
  environment variable. If empty, the API is unauthenticated and `host`
  must be a loopback address.

- allowed_roots:

  Character vector of directories that `root` request parameters are
  allowed to resolve within. Default: the working directory the server
  was started in.

## Value

Invisibly, the `plumber` router object (so callers can modify it before
`$run()` if needed). Blocks if the server is started interactively.
