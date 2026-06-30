# Example: research-pipeline

A minimal, intentionally-flawed R research project used to exercise every
built-in RTrace rule end-to-end (see
`tests/testthat/test-integration-research-pipeline.R` in the package
source). Do not use this project's code as a style reference — every
violation below is deliberate.

## Layout

```
research-pipeline/
├── rtrace.yml                       # demo config: low thresholds so every rule fires
├── R/utils.R                        # clean, documented, tested helpers (no violations)
├── analysis/clean_data.R            # most of the intentional violations
├── shiny_dashboard/helpers.R        # completes a circular layer dependency
└── tests/testthat/test-utils.R      # covers R/utils.R only, on purpose
```

## Violations and the rule that catches them

| File | Violation | Rule |
|---|---|---|
| (project root) | no `vignettes/` directory | `structure.requiredDirs` |
| `analysis/clean_data.R` | `source("shiny_dashboard/helpers.R")` | `dependency.forbidden` (`analysis` -> `shiny_dashboard`) |
| `analysis/clean_data.R` + `shiny_dashboard/helpers.R` | the two files `source()` each other | `dependency.circular` |
| `analysis/clean_data.R` | `clean_and_summarize()` has 7 decision points | `complexity.cyclomatic` (max 5 in this demo config) |
| `analysis/clean_data.R` | `clean_and_summarize()` is 25 lines | `complexity.functionLength` (max 15 in this demo config) |
| `analysis/clean_data.R` | file is 29 lines | `complexity.fileLength` (max 20 in this demo config) |
| `analysis/clean_data.R` | `total_rows <<- nrow(df)` | `antipattern.globalAssign` |
| `analysis/clean_data.R` | `assign("last_run_timestamp", ...)` | `antipattern.assign` |
| `analysis/clean_data.R` | `setwd("/home/researcher/...")` | `antipattern.setwd` |
| `analysis/clean_data.R` | hardcoded `"/Users/researcher/..."` and `"/home/researcher/..."` paths | `antipattern.hardcodedPath` |
| `analysis/clean_data.R`, `shiny_dashboard/helpers.R` | functions with no roxygen2 block | `documentation.missing` |
| `analysis/clean_data.R`, `shiny_dashboard/helpers.R` | `clean_and_summarize()`/`format_summary_label()` never referenced under `tests/` | `testing.missingTests` |
| `analysis/clean_data.R` | `reshape2::melt(df)`, configured as deprecated in this example's `rtrace.yml` | `package.deprecatedApi` |
| `shiny_dashboard/helpers.R` | `library(shiny)` with no `app.R` or `ui.R`+`server.R` entrypoint anywhere in the project | `ecosystem.shinyStructure` |

`R/utils.R` is included as a contrast: fully documented, no anti-patterns,
and covered by `tests/testthat/test-utils.R` — demonstrating that RTrace
only flags what actually violates policy.

## Running it

```r
RTrace::run_scan(system.file("examples", "research-pipeline", package = "RTrace"))
```

or from a shell with the package installed:

```sh
rtrace scan path/to/RTrace/inst/examples/research-pipeline
```

Expect a nonzero exit status (`antipattern.setwd`, `dependency.forbidden`,
and `dependency.circular` are configured as `error` severity in this
example's `rtrace.yml`).
