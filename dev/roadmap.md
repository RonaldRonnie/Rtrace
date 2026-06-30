# RTrace Roadmap

This roadmap distinguishes what ships in the 0.1.0 core-engine release from
what is designed-for but deliberately deferred, per [ADR 0001](adr/0001-rtrace-scope-and-positioning.md),
[ADR 0002](adr/0002-core-architecture.md), and [ADR 0003](adr/0003-incremental-ast-caching.md).
Deferred items have a stable extension point already in place (a reporter
function signature, a rule interface, a plugin registration hook) — they
are sequencing decisions, not architectural gaps.

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

## 0.1.x — Ecosystem awareness (shipped)

- `ecosystem.shinyStructure` rule: flags a directory with conflicting
  `app.R` + `ui.R`/`server.R` entrypoints, or a project that imports
  `shiny` with no recognized entrypoint at all. Self-gated on actual
  `shiny` usage (zero cost/noise for non-Shiny projects), so it's enabled
  by default unlike the other opt-in rules.

## 0.1.x — Incremental scanning (shipped, narrower scope than originally planned)

- AST parse cache (`R/cache.R`, `--cache` on `rtrace scan`,
  `use_cache = TRUE` on `build_context()`/`run_scan()`): content-hash-keyed
  `.rtrace_cache/ast-cache.rds`, opt-in, off by default. Caches the parse
  step only — diagnostics are always recomputed for the full project on
  every scan, by design. See [ADR 0003](adr/0003-incremental-ast-caching.md)
  for why per-file *diagnostic* caching (the original wording in this
  roadmap) needs a rule-scope capability model that doesn't exist yet, and
  is deferred rather than built unsafely.

## 0.1.x — Further ecosystem presets + doctor command (shipped)

- `ecosystem.targetsStructure` rule: flags `targets` usage with no
  `_targets.R` at the project root. `drake` is deliberately not covered —
  no fixed conventional entrypoint filename to check for.
- `ecosystem.plumberStructure` rule: flags `plumber` usage with no `#*`
  route annotation comments anywhere in the project.
- `rtrace doctor` command: environment/setup diagnostics — R/RTrace
  versions, suggested-package availability (`xml2`), `rtrace.yml`
  presence/validity, RStudio Project detection (`.Rproj` file), and AST
  cache state. Pulled forward from 0.3.0 since it had no dependency on the
  plugin/IDE work also originally grouped there.

## 0.1.x — HTML architecture visualization (shipped)

- `render_layer_graph_svg()`: a simple, dependency-free circular-layout SVG
  renderer for the layer dependency graph (no JS, no external graph-layout
  library — legible for the small-to-moderate layer counts typical of a
  `layers:` config, not a general graph-layout algorithm). Cyclic edges
  (per [find_cycles()]) are drawn in red.
- `reporter_html()` gained optional `layers`/`layer_graph` parameters
  that, when supplied, render an "Architecture Overview" section above the
  diagnostics list. Both default to empty, so the reporter's primary
  contract (`diagnostics` alone, like every other reporter — ADR 0002) is
  unchanged for existing callers.
- `cmd_scan` now builds the context explicitly (`build_context()` +
  `run_rules()`, rather than the `run_scan()` convenience wrapper) so it
  has the layer graph on hand to pass through for `--format html`.

## 0.2.0 — Rule-scope capability

- Per-rule `scope: "file" | "project"` capability on the `Rule` interface,
  enabling a correct per-file diagnostic cache for file-scoped rules (see
  [ADR 0003](adr/0003-incremental-ast-caching.md))

## 0.1.x — RStudio Addin + benchmark command (shipped)

- `rtrace_addin_scan()` / "RTrace: Scan Project" (`inst/rstudio/addins.dcf`):
  scans the active RStudio project (`rstudioapi::getActiveProject()`,
  falling back to the working directory) and opens an HTML report
  (architecture diagram included) in the Viewer pane, or the default
  browser outside RStudio. `rstudioapi` added to `Suggests`, guarded with
  `requireNamespace()` like `xml2`/`reporter_xml()`. The project-root
  detection, report-path selection, and scan-and-render logic are factored
  into separately-testable internal helpers; only the final
  `viewer()`/`browseURL()` call needs an interactive session and isn't
  unit-tested.
- `rtrace benchmark [path]`: times each scan phase (file walk, parsing,
  dependency graph construction) and each enabled rule's evaluation,
  printing a slowest-first breakdown. Supports `--cache`. Always exits
  `0` — a rule erroring during evaluation is timed and reported, not
  treated as a benchmark failure.

## 0.3.0 — Plugin discovery + VS Code

- Plugin discovery convention: scan installed packages for an
  `rtrace.plugins` field in `DESCRIPTION` and auto-register their rules,
  instead of requiring `.onLoad()` registration
- VS Code extension: run `rtrace scan --format json` on save, surface
  diagnostics via the Problems panel (Language Server Protocol-style
  diagnostics publishing). Unlike the RStudio Addin (pure R, lives in this
  package), a VS Code extension is a separate TypeScript/`package.json`
  project with its own toolchain (`npm`, the VS Code extension API,
  `.vsix` packaging) — out of scope for this repo until that toolchain is
  set up, likely as a sibling repo rather than a subdirectory here.

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
