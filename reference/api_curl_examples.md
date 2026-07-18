# Generate a `curl` example for the Trace Platform API

Prints the `curl` commands for each endpoint, useful for onboarding and
documentation.

## Usage

``` r
api_curl_examples(
  host = "127.0.0.1",
  port = 8394L,
  token = Sys.getenv("RTRACE_API_TOKEN", "")
)
```

## Arguments

- host:

  Character scalar. Default `"127.0.0.1"`.

- port:

  Integer. Default `8394L`.

- token:

  Character scalar. If non-empty, examples include the
  `Authorization: Bearer` header. Default: the `RTRACE_API_TOKEN`
  environment variable.

## Value

Invisibly, a character vector of curl commands.
