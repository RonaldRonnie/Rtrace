# Quick Start

## Install

RTrace is not yet on CRAN.

```r
# install.packages("pak")
pak::pak("rtrace-dev/rtrace")
```

## Scan a project with zero configuration

```r
RTrace::run_scan(".")
```

This uses [`default_config()`](configuration-reference.md#defaults): a
sensible baseline (required `R/`/`tests/` directories, circular-dependency
detection, complexity thresholds, and the four anti-pattern rules) with no
layers configured, so layer-based rules (`dependency.forbidden`) are
effectively inactive until you declare layers.

## Add a project configuration

```sh
Rscript -e 'RTrace::rtrace_cli(commandArgs(TRUE))' init .
```

This writes `rtrace.yml` to the current directory from
[`inst/templates/rtrace.yml`](../inst/templates/rtrace.yml). Edit it to
match your project: declare your layers, tune complexity thresholds, and
enable/disable rules. See the [Configuration Reference](configuration-reference.md).

## Run from the command line

Once installed so `rtrace` is on `PATH` (or via
`Rscript inst/rtrace` from a package checkout):

```sh
rtrace scan .                          # console output, default
rtrace scan . --format json            # machine-readable, for CI
rtrace scan . --format markdown --output report.md
rtrace validate .                       # check rtrace.yml without scanning
rtrace list-rules                       # see every registered rule
rtrace describe-rule complexity.cyclomatic
```

`rtrace scan` exits nonzero if any diagnostic at or above the
`--fail-on` threshold (default `error`) was found — wire it into CI as a
gate:

```yaml
# example GitHub Actions step
- name: RTrace
  run: Rscript -e 'RTrace::rtrace_cli(commandArgs(TRUE))' scan . --format json --output rtrace-report.json
```

## See it catch real violations

[`inst/examples/research-pipeline`](../inst/examples/research-pipeline) is a
small example project with one deliberate violation per built-in rule, plus
a `rtrace.yml`. Run:

```r
RTrace::run_scan(system.file("examples", "research-pipeline", package = "RTrace"))
```

and compare against the expected output documented in that example's
[README](../inst/examples/research-pipeline/README.md).

## Next steps

* [Configuration Reference](configuration-reference.md) — every config key
* [Rules Reference](rules-reference.md) — every built-in rule, its
  parameters, and what it catches
* [Rule Authoring Guide](rule-authoring-guide.md) — write your own rule
* [CLI Reference](cli-reference.md) — every command and flag
