# RTrace Roadmap

This roadmap distinguishes what ships in the 0.1.0 core-engine release from
what is designed-for but deliberately deferred, per [ADR 0001](adr/0001-rtrace-scope-and-positioning.md)
and [ADR 0002](adr/0002-core-architecture.md). Deferred items have a stable
extension point already in place (a reporter function signature, a rule
interface, a plugin registration hook) — they are sequencing decisions, not
architectural gaps.

## 0.1.0 — Core engine (this release)

- Config loader + schema validation (`rtrace.yml`)
- Project scanner / file walker with ignore-pattern support
- Base-R AST parser wrapper
- Dependency graph (package-level and layer-level) with cycle detection
- Rule engine + plugin registration hook (`register_rule()`)
- Diagnostics model (`Diagnostic`, `DiagnosticSet`)
- Reporters: console (colored), JSON, Markdown
- CLI: `scan`, `init`, `validate`, `list-rules`, `describe-rule`, `config`,
  `version`, `help`
- Built-in rules: required project structure, forbidden/required
  dependencies, circular dependency detection, cyclomatic complexity,
  function length, file length, `<<-` usage, `assign()` usage, `setwd()`
  usage, hardcoded absolute paths, missing roxygen2 documentation on
  exported functions
- Example project with intentional violations + integration tests
- Quick start, configuration reference, rule authoring guide, CLI reference

## 0.1.x — Reporting & rule expansion (shipped)

- SARIF 2.1.0 reporter (`--format sarif`), for GitHub code-scanning upload
  and other SARIF-consuming dashboards
- `testing.missingTests` rule: flags top-level functions never referenced
  by name under `tests/` (a cheap static heuristic, not a substitute for
  `covr`'s runtime coverage measurement)
- `package.deprecatedApi` rule: flags calls to project-configured
  deprecated functions (bare or namespace-qualified), with a suggested
  replacement
- `find_qualified_calls()` parser primitive for detecting `pkg::fn` /
  `pkg:::fn` call sites generally
- HTML reporter (`--format html`): standalone, dependency-free report
  (inline CSS, no JS) grouping diagnostics by file with severity coloring;
  escapes all scanned-content fields before embedding (see
  [SECURITY.md](../SECURITY.md))
- CSV reporter (`--format csv`) and XML reporter (`--format xml`, requires
  the `xml2` package — the only reporter with a non-base dependency)

## 0.2.0 — Ecosystem awareness + richer HTML

- HTML report enhancement: dependency-graph/architecture-overview
  visualization (the 0.1.x HTML reporter is a flat diagnostic list; this
  adds a rendered layer graph)
- Ecosystem-aware layer presets: Shiny app structure (`ui.R`/`server.R`/
  `app.R` conventions), `targets`/`drake` pipeline structure, `plumber` API
  structure, RStudio Project detection
- Incremental scanning: cache parsed ASTs and per-file diagnostics keyed on
  file hash, invalidate only changed files

## 0.3.0 — Plugin discovery + IDE integration

- Plugin discovery convention: scan installed packages for an
  `rtrace.plugins` field in `DESCRIPTION` and auto-register their rules,
  instead of requiring `.onLoad()` registration
- VS Code extension: run `rtrace scan --format json` on save, surface
  diagnostics via the Problems panel (Language Server Protocol-style
  diagnostics publishing)
- RStudio Addin: "Run RTrace Scan" command + Markers pane integration
- `rtrace doctor` command: environment/setup diagnostics (R version, missing
  suggested packages, config schema drift)
- `rtrace benchmark` command: timing breakdown per rule/per file for large
  repositories

## 0.4.0 — Performance at scale

- Parallel per-file parsing and rule evaluation (`parallel`/`future`)
- Memory profiling and streaming diagnostics output for very large
  monorepos (avoid holding every AST in memory simultaneously)
- Benchmark suite against synthetic 1k/10k-file repositories, published in
  `dev/benchmarks.md`

## Beyond 0.4 — exploratory, not committed

- Bioconductor-specific rule pack (`BiocCheck`-complementary, not
  duplicative — see ADR 0001)
- Quarto/R Markdown-aware scanning (extract and analyze embedded R chunks)
- Symbolic resolution of dynamically constructed `source()`/`library()`
  calls (known limitation, see ADR 0002 consequences)
- Hosted/SaaS dashboard for organization-wide architecture trend tracking

## Explicitly out of scope

- Reimplementing style/token linting that `lintr` already owns (ADR 0001)
- Code formatting (owned by `styler`)
- Test execution or coverage measurement (owned by `testthat`/`covr`)
- Dependency/environment locking (owned by `renv`)
