# ADR 0001: RTrace Scope and Positioning in the R Tooling Ecosystem

- Status: Accepted
- Date: 2026-06-30

## Context

The R ecosystem has mature, widely-adopted tools for several quality
concerns, but no tool focused on **architecture governance**: the structural
relationships between modules/files/layers in a project, and whether those
relationships stay consistent over time as the project grows.

Survey of the existing landscape:

| Tool | Focus | What it does NOT do |
|---|---|---|
| **lintr** | Token/AST-level style and correctness linting per file (line length, `T`/`F`, unused objects, etc.) | Has no concept of project-wide structure, layers, or module dependency direction. Operates file-by-file with no cross-file model. |
| **styler** | Reformats code to a style guide (whitespace, indentation) | Purely cosmetic; does not evaluate semantics or structure at all. |
| **goodpractice** | Runs a fixed bundle of checks (lintr + cyclocomp + covr + R CMD check) for CRAN-style "good practice" | Package-only (assumes `DESCRIPTION`/`NAMESPACE`), fixed rule set, not configurable per-project, no architecture/dependency-direction concept, no plugin model. |
| **covr** | Test coverage measurement | Coverage only; not a static analyzer. |
| **testthat** | Test execution framework | Not a static analysis tool. |
| **renv** | Dependency/environment reproducibility (lockfiles) | Manages *which package versions* are installed, not *which modules may depend on which* within a project. |
| **roxygen2 / pkgdown** | Documentation generation | Generates docs; does not enforce that docs exist or audit doc quality at scale. |
| **Bioconductor tooling (`BiocCheck`)** | Bioconductor-specific submission policy checks | Bioconductor-only, fixed rule set, not extensible by end users, no general architecture rules. |

**The gap**: none of these tools let a team declare "module A may not depend
on module B", detect circular dependencies between files/modules, enforce
project layout conventions, flag complexity/size hotspots with
project-specific thresholds, or treat all of the above as **configurable,
versioned policy** that evolves with the codebase and is enforceable in CI.
This is the same gap that tools like architecture-fitness-function frameworks
fill in other ecosystems (dependency-direction rules, layered-architecture
enforcement, ArchUnit-style tests) — R has no equivalent.

Several existing tools (`lintr`, `cyclocomp`, `goodpractice`) already do
token-level linting and complexity metrics well. Reimplementing them would
fragment the ecosystem and add maintenance burden without adding value.

## Decision

1. **RTrace is an architecture and structure governance tool, not a style
   linter.** It does not reimplement token-level style rules that `lintr`
   and `styler` already own. Where RTrace needs token/line-level facts (line
   length of a function, presence of a call like `setwd()`), it builds them
   from base R's own parser (`parse()` + `utils::getParseData()`) rather than
   depending on `lintr` internals, so RTrace has no hard dependency on
   `lintr` and the two tools can be run side by side without conflict.

2. **RTrace operates on a project-wide dependency graph**, built by parsing
   every R file's `library()`/`require()`/`::`/`source()` calls and mapping
   files into user-declared "layers" (e.g. `R/`, `analysis/`, `shiny/`,
   `data-raw/`). This graph is the foundation for dependency-direction,
   forbidden-dependency, and circular-dependency rules — capabilities none
   of the surveyed tools provide.

3. **RTrace complements, not replaces**, `lintr`/`styler`/`goodpractice`.
   The README and documentation explicitly recommend running RTrace
   alongside these tools in CI rather than as a replacement.

4. **RTrace targets both R packages and non-package R projects**
   (data-analysis repos, Shiny apps, Bioconductor-style projects, `targets`
   pipelines) because architecture drift is at least as common in
   non-package analysis repos as in packages, and `goodpractice`/`BiocCheck`
   already cover the package/Bioconductor-submission case narrowly.

5. **Rules are config-driven and the rule engine is a plugin system**, not a
   fixed bundle (unlike `goodpractice`). A project declares which rules are
   active, with what severity and parameters, in a single `rtrace.yml` file.
   Third parties can register additional rules without forking RTrace.

## Consequences

- RTrace's first release deliberately ships a **smaller, deeper** rule set
  (project structure, dependency direction, circular dependencies, layer
  enforcement, complexity/size hotspots, a curated set of anti-pattern
  checks) rather than a wide shallow set, so that every shipped rule is
  fully implemented, tested, and documented rather than stubbed.
- Reporting formats ship incrementally: console (interactive use) and JSON
  (machine-readable/CI) are in the 0.1.0 core; Markdown follows immediately
  after. SARIF, HTML, CSV, and XML reporters are designed for in the
  reporter interface (see ADR 0002) but are roadmap items, not blocking the
  0.1.0 core-engine release — see [docs/roadmap.md](../roadmap.md).
- Because RTrace does not depend on `lintr`, it has a light dependency
  footprint (`cli`, `jsonlite`, `R6`, `rlang`, `yaml`, base `tools`/`utils`),
  which keeps it easy to install in CI and on locked-down enterprise/HPC
  environments.
