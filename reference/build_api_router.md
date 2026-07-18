# Build the plumber router without starting it

Useful for testing, embedding in a larger plumber app, or customizing
routes before calling `$run()`.

## Usage

``` r
build_api_router(
  token = Sys.getenv("RTRACE_API_TOKEN", ""),
  allowed_roots = getwd()
)
```

## Arguments

- token:

  Character scalar. Bearer token required on every request via
  `Authorization: Bearer <token>`. Default: the `RTRACE_API_TOKEN`
  environment variable. If empty (the default when the variable is
  unset), no authentication is enforced – callers embedding the router
  directly are responsible for exposure control in that case.

- allowed_roots:

  Character vector of directories that `root` request parameters are
  allowed to resolve within (self or descendant). Default: the current
  working directory.

## Value

A [`plumber::Plumber`](https://www.rplumber.io/reference/Plumber.html)
router object.
