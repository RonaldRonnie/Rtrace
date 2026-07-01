# RTrace — Trace Platform Module 1

**Architecture Governance and Static Analysis for R**

RTrace is the founding module of the Trace Platform. It provides static
analysis and architecture governance for R projects: dependency direction
enforcement, cycle detection, complexity analysis, anti-pattern detection,
ecosystem-specific structural checks, and reproducibility hygiene rules.

## Role in the Platform

```
Trace Platform
├── RTrace        ← THIS MODULE (Architecture, Code Quality, Reproducibility)
├── DataTrace     (Data Quality, FAIR Compliance)
├── DocsTrace     (Documentation Quality)
├── PackageQA     (Package Metadata, CRAN/Bioconductor Conventions)
└── [future modules]
```

## Key Capabilities

- 16+ built-in rules across 7 categories
- 7 report formats (console, JSON, Markdown, SARIF, HTML, CSV, XML)
- 10 CLI commands (`scan`, `init`, `validate`, `doctor`, `benchmark`, ...)
- Plugin API for custom rules (`register_rule()`)
- Opt-in AST parse cache for large repos

## Module Registration

RTrace self-registers as a platform module at load time:

```r
RTrace::list_modules()
# $rtrace
# $rtrace$id: "rtrace"
# $rtrace$name: "Architecture Governance (R)"
# $rtrace$version: "0.1.0.9000"
# ...
```

## Source

Implementation lives in the R package at the repository root:
- `R/` — source code
- `tests/` — test suite
- `man/` — documentation
- `dev/` — architecture docs, ADRs, guides
