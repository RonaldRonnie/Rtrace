# RTrace

<!-- badges: start -->
[![R-CMD-check](https://github.com/RonaldRonnie/Rtrace/actions/workflows/R-CMD-check.yml/badge.svg)](https://github.com/RonaldRonnie/Rtrace/actions/workflows/R-CMD-check.yml)
[![Codecov test coverage](https://app.codecov.io/gh/RonaldRonnie/Rtrace/branch/main/graph/badge.svg)](https://app.codecov.io/gh/RonaldRonnie/Rtrace)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

**RTrace is an architecture governance and static analysis platform for R
projects and packages.** It scans R codebases for structural problems that
style linters and CRAN checks do not look for: dependency-direction
violations, circular module dependencies, project structure drift,
complexity hotspots, and common reproducibility anti-patterns.

RTrace is **not** a style linter or formatter — it is designed to complement
[`lintr`](https://lintr.r-lib.org/), [`styler`](https://styler.r-lib.org/),
[`goodpractice`](https://github.com/ropensci-review-tools/goodpractice), and
[`renv`](https://rstudio.github.io/renv/), not replace them. See
[ADR 0001](dev/adr/0001-rtrace-scope-and-positioning.md) for the full
positioning rationale.

## Installation

RTrace is not yet on CRAN. Install the development version:

```r
# install.packages("pak")
pak::pak("RonaldRonnie/Rtrace")
```

## Quick start

```r
RTrace::run_scan(".")
```

or from a shell, once the package is installed:

```sh
Rscript -e 'RTrace::rtrace_cli(commandArgs(TRUE))' scan .
```

Create a starter configuration:

```sh
Rscript -e 'RTrace::rtrace_cli(commandArgs(TRUE))' init .
```

This writes `rtrace.yml` to the project root. See the
[configuration reference](dev/configuration-reference.md) for every rule and
parameter.

## Example

Given a project where an `analysis/` script `source()`s a `shiny/` helper
(a forbidden dependency direction in this project's policy) and uses
`setwd()`:

```
$ rtrace scan .
(layer:analysis)
  ERROR              Layer 'analysis' depends on layer 'shiny', which is a forbidden dependency direction. [dependency.forbidden]
           -> Remove or invert the source()/dependency from 'analysis' to 'shiny'.
analysis/clean_data.R
  ERROR   6:3        Use of `setwd()` mutates global working-directory state and breaks reproducibility. [antipattern.setwd]
           -> Use here::here(), relative paths from the project root, or an explicit `path` argument instead.

2 error(s), 0 warning(s), 0 info
```

A full worked example with every built-in rule triggered, plus the expected
output, lives in
[inst/examples/research-pipeline](inst/examples/research-pipeline).

## What RTrace checks

| Category | Rules |
|---|---|
| Project structure | `structure.requiredDirs` |
| Dependency direction | `dependency.forbidden`, `dependency.circular` |
| Complexity | `complexity.cyclomatic`, `complexity.functionLength`, `complexity.fileLength` |
| Reproducibility / anti-patterns | `antipattern.globalAssign` (`<<-`), `antipattern.assign`, `antipattern.setwd`, `antipattern.hardcodedPath` |
| Documentation | `documentation.missing` |
| Testing | `testing.missingTests` |
| Package policy | `package.deprecatedApi` |
| Ecosystem-specific | `ecosystem.shinyStructure`, `ecosystem.targetsStructure`, `ecosystem.plumberStructure` |

Run `rtrace list-rules` for the full, current list with default severities,
or see [dev/rules-reference.md](dev/rules-reference.md) for parameters and
examples of each.

## RStudio

RTrace ships an RStudio Addin ("RTrace: Scan Project" in the Addins menu)
that scans the active project and opens an HTML report — including the
architecture-overview diagram — in the Viewer pane.

## Documentation

* [Quick Start](dev/quick-start.md)
* [Configuration Reference](dev/configuration-reference.md)
* [Rules Reference](dev/rules-reference.md)
* [Rule Authoring Guide](dev/rule-authoring-guide.md)
* [CLI Reference](dev/cli-reference.md)
* [Architecture Decision Records](dev/adr/)
* [Roadmap](dev/roadmap.md)

## Status

RTrace shipped its first stable release, 1.0.0, and is under active
development on top of it (`main` is currently at 1.0.0.9000). Beyond the
0.1.0-era core engine (16 built-in rules, rule engine, 10 CLI commands,
an RStudio Addin, seven reporters, an opt-in AST parse cache), the Trace
Platform layer adds four domain modules (Reproducibility, DataTrace,
DocsTrace, PackageQA — 37 rules total), a unified scoring system, an
optional REST API, seven more CLI commands, and an allowlist-gated plugin
discovery system. See [NEWS.md](NEWS.md) for the full changelog and
[dev/roadmap.md](dev/roadmap.md) for what's planned next (a per-rule
diagnostic cache, a VS Code extension).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). This project follows the
[Contributor Covenant](CODE_OF_CONDUCT.md).

## License

MIT © RTrace Contributors. See [LICENSE.md](LICENSE.md).
