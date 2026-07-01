# Parse a raw (already YAML-decoded) configuration list into an `rtrace_config`, applying defaults for missing keys.

Parse a raw (already YAML-decoded) configuration list into an
`rtrace_config`, applying defaults for missing keys.

## Usage

``` r
parse_config(raw)
```

## Arguments

- raw:

  A list as returned by
  [`yaml::read_yaml()`](https://yaml.r-lib.org/reference/read_yaml.html).

## Value

An `rtrace_config` object (not yet validated).
