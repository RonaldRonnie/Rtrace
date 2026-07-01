# Generate a `curl` example for the Trace Platform API

Prints the `curl` commands for each endpoint, useful for onboarding and
documentation.

## Usage

``` r
api_curl_examples(host = "127.0.0.1", port = 8394L)
```

## Arguments

- host:

  Character scalar. Default `"127.0.0.1"`.

- port:

  Integer. Default `8394L`.

## Value

Invisibly, a character vector of curl commands.
