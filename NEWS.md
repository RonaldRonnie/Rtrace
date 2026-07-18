# RTrace 0.1.0.9000

## New features

* Initial scaffold of RTrace: configuration loader, project scanner, base-R
  parser wrapper, dependency graph builder, extensible rule engine,
  diagnostics model, and console/JSON/Markdown reporters.
* Built-in rules: `structure.requiredDirs`, `dependency.forbidden`,
  `dependency.circular`, `complexity.cyclomatic`, `complexity.functionLength`,
  `complexity.fileLength`, `antipattern.globalAssign`, `antipattern.assign`,
  `antipattern.setwd`, `antipattern.hardcodedPath`, `documentation.missing`.
* CLI commands: `scan`, `init`, `validate`, `list-rules`, `describe-rule`,
  `config`, `version`, `help`.
* SARIF 2.1.0 reporter (`--format sarif`) for GitHub code-scanning upload.
* `testing.missingTests` rule: flags functions never referenced under
  `tests/` (disabled by default; complements, not replaces, `covr`).
* `package.deprecatedApi` rule: flags calls to project-configured
  deprecated functions, bare or namespace-qualified.
* HTML reporter (`--format html`): standalone, dependency-free report with
  inline CSS and escaped diagnostic content.
* CSV reporter (`--format csv`) and XML reporter (`--format xml`, requires
  the `xml2` package).
* `ecosystem.shinyStructure` rule: flags conflicting (`app.R` plus
  `ui.R`/`server.R`) or missing Shiny entrypoints. Self-gated on the
  project actually importing `shiny`, so it's enabled by default.
* Incremental scanning: an opt-in (`--cache` / `use_cache = TRUE`)
  content-hash-keyed AST parse cache (`.rtrace_cache/ast-cache.rds`).
  Diagnostics are always recomputed for the full project, so results are
  identical with or without caching — see ADR 0003.
* `ecosystem.targetsStructure` rule: flags `targets` usage with no
  `_targets.R` at the project root.
* `ecosystem.plumberStructure` rule: flags `plumber` usage with no `#*`
  route annotations anywhere in the project.
* `rtrace doctor` CLI command: environment and project setup diagnostics
  (R/RTrace versions, suggested-package availability, `rtrace.yml`
  validity, RStudio Project detection, AST cache state) without running a
  scan.
* The HTML reporter now renders an "Architecture Overview" section: an
  inline SVG diagram of the configured `layers:` dependency graph, with
  cyclic edges drawn in red. Pure SVG, no external JS/CSS — still a single
  standalone file. `reporter_html()` gained optional `layers`/
  `layer_graph` parameters (default empty, so its primary `diagnostics`-only
  contract is unchanged).
* `rtrace benchmark` CLI command: times each scan phase (file walk,
  parsing, dependency graph construction) and each enabled rule's
  evaluation, printing a slowest-first breakdown. Supports `--cache`.
* RStudio Addin ("RTrace: Scan Project"): scans the active project and
  opens an HTML report (including the architecture diagram) in the
  Viewer pane. `rstudioapi` added to `Suggests`.

## Bug fixes

* The Trace Platform REST API (`start_api()`/`build_api_router()`, `rtrace
  api`) had no authentication and no path restriction: any caller could
  scan or generate an HTML report for an arbitrary filesystem path (e.g.
  `/etc`), and `start_api()` accepted any `host` including `0.0.0.0` with
  no way to require a credential. Every endpoint now enforces an optional
  bearer token (`token=`/`RTRACE_API_TOKEN`, `Authorization: Bearer`) and
  a mandatory allowlist (`allowed_roots=`/`--allowed-root`, default the
  working directory) that request `root` paths must resolve within;
  `start_api()` refuses to bind a non-loopback host unless a token is
  configured (#4).

## Documentation

* Architecture Decision Records for ecosystem positioning, core
  architecture, and incremental AST caching.
* Quick start, configuration reference, rule authoring guide, and CLI
  reference.
