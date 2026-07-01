# RTrace Release Notes

## v1.0.0 — Trace Platform v1 (2026-07-01)

### What’s in v1.0

This is the first stable release of RTrace — a static-analysis and
quality-audit platform for R projects. It ships four domain engines, a
rule registry, a multi-format reporter suite, an incremental parse
cache, a CLI, an RStudio Addin, and the scaffolding for Trace Cloud (the
hosted SaaS layer).

------------------------------------------------------------------------

### Core engine

| Component                                                      | Status    |
|----------------------------------------------------------------|-----------|
| `Rule` R6 class with `domain_fns` extension point              | ✅ Stable |
| Rule registry (`register_rule`, `get_rule`, `list_rules`)      | ✅ Stable |
| `rtrace_config` — YAML-driven, per-rule severity overrides     | ✅ Stable |
| `build_context` — file walker, AST parser, dependency graph    | ✅ Stable |
| `build_dependency_graph` — package imports + layer-level edges | ✅ Stable |
| Incremental AST parse cache (opt-in, SHA-256 keyed)            | ✅ Stable |
| Scoring system — 0–100 per module, weighted aggregate          | ✅ Stable |
| `new_diagnostic` / `rtrace_diagnostic_set`                     | ✅ Stable |

------------------------------------------------------------------------

### Domain engines (new in v1.0)

#### DataTrace

- `datatrace.missingHeader` — detects CSV files without column headers
- `datatrace.readError` — flags files that cannot be parsed
- `datatrace.schemaDocumentation` — requires a data dictionary /
  codebook
- `datatrace.noDataFiles` — warns when a data/ directory has no CSV/TSV
- `datatrace.largeCsvNoCompression` — suggests compression for files \>
  50 MB
- `datatrace.fairFindable` — checks data is stored in standard
  directories
- `datatrace.fairAccessible` — checks for DOI / access statement in
  README
- `datatrace.fairInteroperable` — flags proprietary formats (.xls, .sav,
  .dta)
- `datatrace.fairReusable` — checks for PROVENANCE / datapackage.json
- `datatrace.missingValues` — warns when \> 20% of values in a CSV
  column are NA
- `datatrace.duplicateRows` — flags exact duplicate rows in CSV files
- `datatrace.jsonDataset` — validates JSON data files

#### DocsTrace

- `docstrace.readme` — README.md / README.Rmd must exist
- `docstrace.readmeQuality` — README must have ≥ 50 words and key
  sections
- `docstrace.vignettes` — R packages should have at least one vignette
- `docstrace.changelogPresent` — NEWS.md / NEWS must exist
- `docstrace.contributingGuide` — CONTRIBUTING.md should exist
- `docstrace.citationFile` — inst/CITATION should exist
- `docstrace.pkgdownSite` — \_pkgdown.yml encourages a documentation
  site

#### PackageQA

- `packageqa.descriptionComplete` — all required DESCRIPTION fields
  present
- `packageqa.descriptionTitle` — title must not end with period or be
  all-lowercase
- `packageqa.licensePresent` — LICENSE file required when DESCRIPTION
  says `+ file LICENSE`
- `packageqa.versionFormat` — version must follow X.Y.Z or X.Y.Z.Z
  convention
- `packageqa.namespaceHygiene` — NAMESPACE must have exports; no
  `import(*)`
- `packageqa.newsFormat` — NEWS.md must use standard version-header
  format
- `packageqa.testCoverage` — warns when no tests/ directory exists

#### Reproducibility

- `reproducibility.renvLock` — renv.lock should exist for dependency
  locking
- `reproducibility.randomSeed` —
  [`set.seed()`](https://rdrr.io/r/base/Random.html) required when
  random functions used
- `reproducibility.externalDownload` — flags
  [`download.file()`](https://rdrr.io/r/utils/download.file.html) calls
  without caching
- `reproducibility.portablePaths` — flags bare filenames (no path
  separator)
- `reproducibility.environmentVariables` — warns on undocumented
  `Sys.getenv` use
- `reproducibility.tempFiles` —
  [`tempfile()`](https://rdrr.io/r/base/tempfile.html) without
  `on.exit(unlink(...))` cleanup
- `reproducibility.sessionInfo` — analysis projects should call
  [`sessionInfo()`](https://rdrr.io/r/utils/sessionInfo.html)
- `reproducibility.reproducibleReports` — Rmd reports should set seed /
  chunk options

------------------------------------------------------------------------

### Built-in rules (inherited from pre-1.0 core)

`structure.requiredDirs`, `antipattern.setwd`,
`antipattern.hardcodedPath`, `antipattern.browserCall`,
`dependency.forbidden`, `dependency.circular`, `complexity.cyclomatic`,
`style.functionLength`, `style.variableNaming`,
`documentation.functionDocs`, `security.credentialExposure`,
`testing.noTestsDirectory`, `shiny.reactiveComplexity`,
`targets.missingPlan`, `plumber.noApiDocs`

------------------------------------------------------------------------

### Reporters

| Format | Function | Notes |
|----|----|----|
| Console | [`reporter_console()`](https://ronaldronnie.github.io/Rtrace/reference/reporter_console.md) | Colour-coded, severity icons |
| HTML | [`reporter_html()`](https://ronaldronnie.github.io/Rtrace/reference/reporter_html.md) | Self-contained, JavaScript-free |
| Markdown | [`reporter_markdown()`](https://ronaldronnie.github.io/Rtrace/reference/reporter_markdown.md) | GitHub-compatible |
| JSON | [`reporter_json()`](https://ronaldronnie.github.io/Rtrace/reference/reporter_json.md) | Machine-readable |
| CSV | [`reporter_csv()`](https://ronaldronnie.github.io/Rtrace/reference/reporter_csv.md) | Formula-injection safe |
| XML | [`reporter_xml()`](https://ronaldronnie.github.io/Rtrace/reference/reporter_xml.md) | CI-tool compatible |
| SARIF | [`reporter_sarif()`](https://ronaldronnie.github.io/Rtrace/reference/reporter_sarif.md) | GitHub Code Scanning |
| Dashboard | [`reporter_dashboard()`](https://ronaldronnie.github.io/Rtrace/reference/reporter_dashboard.md) | Score ring + module breakdown |

------------------------------------------------------------------------

### CLI

    rtrace scan [--config <file>] [--format <fmt>] [--output <file>] [<dir>]
    rtrace check [--strict] [<dir>]
    rtrace rules
    rtrace doctor
    rtrace benchmark

------------------------------------------------------------------------

### Trace Cloud (scaffolded, not production-ready)

The `trace-cloud/` directory contains a full TypeScript monorepo: -
**API** — Express + Prisma + BullMQ, JWT auth,
orgs/projects/scans/webhooks - **Worker** — BullMQ scan worker calling
the RTrace HTTP API - **Web** — React + Vite + Tailwind frontend (Login,
Dashboard, Org, Project, Scan, Settings) - **Observability** —
structured JSON logging, Prometheus metrics, `/health` + `/metrics`
endpoints - **Scheduling** — BullMQ repeatable jobs via cron, GitHub
webhook integration

> Trace Cloud is provided as a starting point. It is not yet recommended
> for production use without additional security hardening.

------------------------------------------------------------------------

### Tests

170+ tests, all passing on Linux, macOS, and Windows (R 4.1+).

------------------------------------------------------------------------

### Breaking changes from pre-1.0

None. v1.0.0 is the first tagged stable release.

------------------------------------------------------------------------

### Known limitations

- `parse_description` cannot parse multi-value DESCRIPTION fields
  (continuation lines are collapsed into a single string — adequate for
  most uses).
- The `reproducibility.portablePaths` rule flags bare filenames without
  path separators; it does not currently flag Windows-absolute paths.
- Trace Cloud requires manual infrastructure setup (PostgreSQL, Redis,
  Docker).

------------------------------------------------------------------------

## Roadmap to v2.0

| Priority | Feature | Rationale |
|----|----|----|
| 1 | GitHub App integration (PR annotations) | Highest-signal integration point |
| 2 | Auto-fix suggestions (`rtrace fix`) | Reduces friction to act on findings |
| 3 | Plugin SDK stable API + registry | Enables community rule contributions |
| 4 | AI recommendation engine (LLM-backed) | Context-aware “how to fix” guidance |
| 5 | Multi-language support (Python JTrace stub) | Expand beyond R |
| 6 | Team collaboration — audit logs, role-based access | Enterprise readiness |
| 7 | Enterprise SSO / OIDC | Large-org adoption |
| 8 | PDF report export | Regulatory / compliance contexts |

See `dev/platform/five-year-roadmap.md` for the full roadmap.
