# Read an RTrace configuration file

Read an RTrace configuration file

## Usage

``` r
read_config(path)
```

## Arguments

- path:

  Path to a YAML configuration file.

## Value

An `rtrace_config` object, validated via
[`validate_config()`](https://rtrace-dev.github.io/rtrace/reference/validate_config.md).
