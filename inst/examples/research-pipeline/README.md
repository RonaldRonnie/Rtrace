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
├── R/utils.R                        # clean, documented helpers (no violations)
├── analysis/clean_data.R            # most of the intentional violations
└── shiny_dashboard/helpers.R        # completes a circular layer dependency
```

## Violations and the rule that catches them

| File | Violation | Rule |
|---|---|---|
| (project root) | no `tests/` directory | `structure.requiredDirs` |
| `analysis/clean_data.R` | `source("shiny_dashboard/helpers.R")` | `dependency.forbidden` (`analysis` -> `shiny_dashboard`) |
| `analysis/clean_data.R` + `shiny_dashboard/helpers.R` | the two files `source()` each other | `dependency.circular` |
| `analysis/clean_data.R` | `clean_and_summarize()` has 7 decision points | `complexity.cyclomatic` (max 5 in this demo config) |
| `analysis/clean_data.R` | `clean_and_summarize()` is 24 lines | `complexity.functionLength` (max 15 in this demo config) |
| `analysis/clean_data.R` | file is 28 lines | `complexity.fileLength` (max 20 in this demo config) |
| `analysis/clean_data.R` | `total_rows <<- nrow(df)` | `antipattern.globalAssign` |
| `analysis/clean_data.R` | `assign("last_run_timestamp", ...)` | `antipattern.assign` |
| `analysis/clean_data.R` | `setwd("/home/researcher/...")` | `antipattern.setwd` |
| `analysis/clean_data.R` | hardcoded `"/Users/researcher/..."` and `"/home/researcher/..."` paths | `antipattern.hardcodedPath` |
| `analysis/clean_data.R`, `shiny_dashboard/helpers.R` | functions with no roxygen2 block | `documentation.missing` |

`R/utils.R` is included as a contrast: fully documented, no anti-patterns,
demonstrating that RTrace only flags what actually violates policy.

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
