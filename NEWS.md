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

## Documentation

* Architecture Decision Records for ecosystem positioning and core
  architecture.
* Quick start, configuration reference, rule authoring guide, and CLI
  reference.
