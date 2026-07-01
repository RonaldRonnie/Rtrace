# Construct an RTrace configuration object

Construct an RTrace configuration object

## Usage

``` r
new_config(
  version = 1L,
  project = NULL,
  layers = list(),
  exclude = character(0),
  rules = list()
)
```

## Arguments

- version:

  Integer config schema version.

- project:

  Optional project name.

- layers:

  Named list mapping layer name to a glob pattern (relative to the
  project root).

- exclude:

  Character vector of glob patterns to exclude from scanning.

- rules:

  List of rule specs, each `list(type=, enabled=, severity=, params=)`.

## Value

An `rtrace_config` object.
