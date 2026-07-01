# RTrace: Architecture Governance and Static Analysis for R Projects

A static analysis and architecture governance platform for R projects
and packages. RTrace scans R codebases for structural and architectural
problems that style checkers and linters do not address, including
layer/dependency-direction violations, circular module dependencies,
project structure conventions, complexity hotspots, and common
anti-patterns ('\<\<-', 'assign()', 'setwd()', hardcoded paths). Rules
are declared in a versioned YAML configuration file and evaluated by an
extensible rule engine, producing diagnostics that can be rendered as
colored console output, 'JSON', 'Markdown', 'HTML', 'CSV', 'XML', or
'SARIF' for use in interactive development and continuous integration.

## See also

Useful links:

- <https://github.com/rtrace-dev/rtrace>

- Report bugs at <https://github.com/rtrace-dev/rtrace/issues>

## Author

**Maintainer**: RTrace Contributors <maintainers@rtrace.dev>

Authors:

- RTrace Contributors <maintainers@rtrace.dev>
