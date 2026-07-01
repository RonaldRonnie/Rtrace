# RTrace: Trace Platform — Architecture Governance and Quality Analysis for R

The Trace Platform is a comprehensive software quality and architecture
governance system for R projects and packages. RTrace is the platform's
founding module: it scans R codebases for structural and architectural
problems that style checkers and linters do not address, including
layer/dependency-direction violations, circular module dependencies,
project structure conventions, complexity hotspots, and common
anti-patterns ('\<\<-', 'assign()', 'setwd()', hardcoded paths).
Additional platform modules cover reproducibility hygiene, data quality
(DataTrace), documentation quality (DocsTrace), and package metadata
completeness (PackageQA). Rules are declared in a versioned YAML
configuration file and evaluated by an extensible rule engine, producing
diagnostics rendered as colored console output, 'JSON', 'Markdown',
'HTML', 'CSV', 'XML', or 'SARIF'. A unified scoring system aggregates
findings from all modules into 0-100 health scores per module and for
the platform as a whole. A provider-agnostic AI recommendation engine
explains every violation with context, impact, and fix guidance. An
optional REST API (requires 'plumber') exposes all functionality over
HTTP for SaaS and CI/CD integration.

## See also

Useful links:

- <https://github.com/rtrace-dev/rtrace>

- Report bugs at <https://github.com/rtrace-dev/rtrace/issues>

## Author

**Maintainer**: RTrace Contributors <maintainers@rtrace.dev>

Authors:

- RTrace Contributors <maintainers@rtrace.dev>
