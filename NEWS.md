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

## Documentation

* Architecture Decision Records for ecosystem positioning, core
  architecture, and incremental AST caching.
* Quick start, configuration reference, rule authoring guide, and CLI
  reference.
