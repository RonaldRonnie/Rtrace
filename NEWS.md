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

## Documentation

* Architecture Decision Records for ecosystem positioning and core
  architecture.
* Quick start, configuration reference, rule authoring guide, and CLI
  reference.
