# Build the plumber router without starting it

Useful for testing, embedding in a larger plumber app, or customizing
routes before calling `$run()`.

## Usage

``` r
build_api_router()
```

## Value

A [`plumber::Plumber`](https://www.rplumber.io/reference/Plumber.html)
router object.
