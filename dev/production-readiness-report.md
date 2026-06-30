# RTrace 0.1.0.9000 — Production Readiness Report

**Date:** 2026-06-30  
**R CMD check:** `0 errors, 0 warnings, 0 notes`  
**Tests:** 168 `test_that` blocks, 319 expectations, 0 failures  
**Commits:** 11  
**Tracked files:** 140

---

## Executive Summary

RTrace is a functional, tested, and well-documented architecture-governance
and static-analysis platform for R. Starting from an empty repository, this
session built it to a state where:

- `R CMD check` passes cleanly on R 4.6.0/Linux with no errors, warnings,
  or notes.
- 168 test cases covering every module and all 16 built-in rules pass.
- All seven reporter formats (console, JSON, Markdown, SARIF, HTML, CSV,
  XML) produce correct, well-formed output verified manually and
  automatically.
- A real security vulnerability (CSV formula injection) was found and fixed
  during a dedicated security review pass.
- The `pkgdown` documentation website builds correctly and its CI workflow
  deploys it automatically via GitHub Actions.

The package is genuinely usable today for R projects that need architecture
enforcement, dependency-direction governance, anti-pattern detection, and
reproducibility checks. It is not yet CRAN-ready in the sense of having a
real GitHub remote (all `github.com/rtrace-dev/rtrace` URLs are
placeholders; the repo has not been created), but the code, tests, and
documentation are in a state appropriate for a public pre-release on GitHub.

---

## What Was Built

### Core Engine

| Component | File(s) | Status |
|---|---|---|
| Config loader / YAML schema validator | `R/config.R` | Complete |
| Project file walker with ignore-pattern support | `R/walker.R` | Complete |
| Base-R AST parser wrapper | `R/parser.R` | Complete |
| Dependency graph (package + layer levels) with cycle detection | `R/dependency_graph.R` | Complete |
| R6-based rule engine + plugin registration hook | `R/rule.R`, `R/rule_engine.R` | Complete |
| Diagnostics model (Diagnostic, DiagnosticSet) | `R/diagnostic.R` | Complete |
| Opt-in AST parse cache | `R/cache.R` | Complete |
| Rule context bundler | `R/context.R` | Complete |

### Built-in Rules (16)

| Category | Rules |
|---|---|
| Structure | `structure.requiredDirs` |
| Dependency | `dependency.forbidden`, `dependency.circular` |
| Complexity | `complexity.cyclomatic`, `complexity.functionLength`, `complexity.fileLength` |
| Anti-patterns | `antipattern.globalAssign` (`<<-`), `antipattern.assign`, `antipattern.setwd`, `antipattern.hardcodedPath` |
| Documentation | `documentation.missing` |
| Testing | `testing.missingTests` |
| Package policy | `package.deprecatedApi` |
| Ecosystem | `ecosystem.shinyStructure`, `ecosystem.targetsStructure`, `ecosystem.plumberStructure` |

### Reporters (7)

`console` (colored, default), `json` (machine-readable/CI), `markdown`
(PR comments), `sarif` (GitHub code-scanning / SARIF 2.1.0), `html`
(standalone file with inline SVG architecture-overview diagram), `csv`,
`xml` (requires `xml2`).

### CLI (10 commands)

`scan`, `init`, `validate`, `list-rules`, `describe-rule`, `config`,
`doctor`, `benchmark`, `version`, `help`.

### Other deliverables

- RStudio Addin ("RTrace: Scan Project" via `inst/rstudio/addins.dcf`)
- `pkgdown` site config (`_pkgdown.yml`) with organized reference index;
  CI workflow deploys to GitHub Pages
- 3 Architecture Decision Records (`dev/adr/`)
- Prose documentation: quick start, configuration reference, rules
  reference, rule-authoring guide, CLI reference, roadmap, CONTRIBUTING
- 1 fully-annotated example project (`inst/examples/research-pipeline`)
  demonstrating every rule

---

## Testing Report

### Automated test suite

- **Test files:** 13 (`tests/testthat/test-*.R`)
- **test_that blocks:** 168
- **Expectations:** 319
- **Failures:** 0

Coverage by module (rule-file coverage has a known tooling artifact — see
below):

| Module | Coverage |
|---|---|
| Core engine (config, walker, parser, dep. graph, context, rule engine) | 89–96% |
| Diagnostics | 89% |
| Reporters (all 7) | 96–100% |
| CLI (commands + arg parser) | 91% |
| Cache | 100% |
| Rule R6 class + registry | 100% |
| Addin helpers | 63% |
| **Overall (covr)** | **65.7%** |

**Coverage caveat — this is important to understand:** The 65.7% overall
number substantially undercounts true coverage due to a known `covr`
interaction with the `Rule$new(check_fn = function(context, params) {...})`
pattern: anonymous closures passed as named arguments within `Rule$new()`
constructor calls do not get correctly traced by `covr`'s instrumentation,
even when those closures are freshly constructed and immediately invoked
(confirmed experimentally: bypassing the `.onLoad()`-time rule registry
entirely still produces 0% for the closure body lines). Every rule file
(`rules_*.R`) and `zzz.R` therefore show 0%, not because they aren't
exercised by tests, but because the measurement tool cannot attach trace
counters to this specific code shape. **Excluding** the 249 mismeasured
expressions in `rules_*.R`/`zzz.R`, coverage of the remaining 792
expressions (the engine, reporters, CLI, cache, and addin) is **91.2%** —
an accurate figure for the parts covr can measure.

The rule logic is genuinely exercised: every one of the 16 rules has
dedicated positive and negative fixtures in `test-rules-builtin.R`, and
the integration test in `test-integration-research-pipeline.R` verifies
end-to-end that every registered rule fires at least once against the
example project.

A future refactor could improve covr visibility by extracting each rule's
`check_fn` logic into a named top-level helper function (called by the
constructor rather than defined inline), which covr instruments correctly.
This is a covr-measurement ergonomics change, not a correctness or
behavioral change. Tracked in the roadmap.

---

## Security Review

### Attack surface

RTrace parses and statically analyzes R source files; it never executes the
code it scans (confirmed: `parse()` is called, not `eval()`; no `source()`
or `eval()` on scanned content anywhere in the engine).

### Controls verified

| Claim | Verified |
|---|---|
| `yaml::read_yaml(path, eval.expr = FALSE)` prevents `!expr` tag execution | Manually tested: YAML embedding `!expr "system(...)"` reads as string, file not created |
| HTML reporter escapes `& < > " '` before embedding scanned content | Tested via XSS-style fixture in `test-reporters.R` |
| XML reporter uses `xml2::xml_set_text()` (auto-escaping) | `xml2` handles entity escaping, verified via roundtrip parse test |
| SARIF reporter uses `jsonlite::toJSON()` (auto-escaping JSON) | Standard JSON library, no manual string interpolation |
| CSV reporter guards against formula injection | Fixed during this review pass (see below) |

### Vulnerability found and fixed: CSV formula injection

**Finding:** `reporter_csv()` echoed scanned content (file paths, diagnostic
messages) verbatim into CSV cells without checking whether the leading
character would trigger formula evaluation (`=`, `+`, `-`, `@`, tab, CR)
when the file is opened in Excel/LibreOffice/Sheets. A repository with a
file literally named `=HYPERLINK("http://evil.com","click").R` could
execute that formula when a CI engineer opens the scan report.

**Fix:** `sanitize_csv_field()` prepends a single quote `'` to any such
field value, the standard OWASP-recommended CSV injection mitigation
("force text" interpretation). Applied to the `file`, `message`, and
`suggestion` columns, which are the only fields that can carry
attacker-influenced content.

**Commit:** `3d6bab1`  
**Test added:** `test-reporters.R` — "reporter_csv neutralizes CSV formula
injection in file and message fields"

### Residual known limitations (not vulnerabilities)

- `source()` path resolution is heuristic (string-literal targets only;
  dynamically-constructed paths like `source(file.path(...))` are not
  resolved). Documented in ADR 0002 and the rules reference.
- Markdown and console reporters do not escape content for rendering in
  arbitrary contexts — they produce output for terminal/text display, not
  browser embedding. If these outputs are piped into a context that
  renders them as HTML (e.g., a CI system that renders Markdown PR
  comments via a third-party integration), that system's own escaping is
  responsible. Consider using `--format html` (which escapes) for
  browser-displayed output.

---

## R CMD Check

Tested on R 4.6.0 (2026-04-24), Ubuntu 24.04.4 LTS,
`x86_64-pc-linux-gnu`.

```
Status: OK

0 errors ✔ | 0 warnings ✔ | 0 notes ✔
Duration: 14–18 s
```

The `--as-cran` (CRAN submission mode) check adds one NOTE about the
GitHub URLs referenced in README badges and DESCRIPTION (`rtrace-dev/rtrace`
does not exist yet — it's a placeholder org). This NOTE will resolve once
the repository is published on GitHub. Everything else passes cleanly.

---

## Performance

`rtrace benchmark` results against the 5-file `research-pipeline` example
project (typical small project, 16 rules enabled):

```
Phase timings:
  file walk              0.009 s
  parsing                0.011 s
  dependency graph       0.055 s

Rule timings (slowest first):
  complexity.cyclomatic          0.034 s
  package.deprecatedApi          0.016 s
  dependency.circular            0.007 s
  documentation.missing          0.005 s
  (remaining 12 rules)           < 0.003 s each
```

The AST parse cache (`--cache` / `use_cache = TRUE`) reduces the parsing
phase on repeated scans of unchanged files to essentially zero (MD5 hash
check + RDS read replaces per-file `parse()`). Diagnostic evaluation always
runs fully — see [ADR 0003](adr/0003-incremental-ast-caching.md).

For large repositories (thousands of files), parallel parsing and rule
evaluation remain roadmap items (0.4.0). The cache already provides the
largest leverage on repeated CI runs where most files haven't changed
between commits.

---

## Deliverables Completed vs. Not Completed

### Completed

- [x] Core engine (all phases 1–7)
- [x] All 16 built-in rules
- [x] 10 CLI commands
- [x] 7 reporters (console/JSON/Markdown/SARIF/HTML/CSV/XML)
- [x] Opt-in incremental AST cache
- [x] RStudio Addin
- [x] pkgdown documentation website config + CI workflow
- [x] 3 Architecture Decision Records
- [x] Quick start, configuration reference, rules reference, rule-authoring
  guide, CLI reference, roadmap
- [x] 1 example project demonstrating every rule
- [x] CONTRIBUTING, CODE_OF_CONDUCT, SECURITY, LICENSE
- [x] GitHub issue templates, PR template, 3 CI workflows
- [x] Security review with one real finding fixed

### Not completed (deferred or out of scope for this session)

| Item | Reason |
|---|---|
| PowerPoint presentation | No headless PowerPoint generation without system GUI/LibreOffice/pptx toolchain available; the required content (problem statement, ecosystem gap, architecture, demo, roadmap) exists in dev/ docs — commands to create a slide deck from it are documented below |
| Architecture / workflow / component diagrams (static images) | ADR 0002 has ASCII art; the HTML reporter generates a live per-project layer graph SVG; a static RTrace-architecture diagram could be added as `dev/diagrams/` — requires a tool like `mermaid`, `graphviz`, or similar not available in this sandbox |
| Screenshots of CLI / reports | No display/GUI available in this environment. Required commands: `rtrace scan inst/examples/research-pipeline` (console output), `rtrace scan ... --format html --output report.html` then open in browser |
| Multiple ecosystem example projects (Shiny, Bioconductor, data science, enterprise) | Phase 14 called for several; only the research-pipeline example was built (it triggers every rule). Additional examples remain roadmap work |
| Bioconductor-specific rule pack | Intentionally not built (ADR 0001: RTrace complements `BiocCheck`, not reimplement it; beyond 0.4 roadmap) |
| CRAN submission | Requires a real GitHub remote (for URL verification), a human maintainer email, and rcmdcheck with `--as-cran` producing 0 notes on the placeholder URL before submitting |
| VS Code extension | Separate TypeScript/npm project, different toolchain, separate repo |

### PowerPoint / Screenshot capture plan

To create presentation assets:

```sh
# 1. Generate all report formats from the example project
rtrace scan inst/examples/research-pipeline               # capture terminal
rtrace scan inst/examples/research-pipeline --format json --output /tmp/example.json
rtrace scan inst/examples/research-pipeline --format html --output /tmp/example.html
# 2. Open example.html in a browser and screenshot each section
# 3. Run rtrace doctor . and rtrace benchmark . and screenshot each
# 4. Build slides from content in dev/*.md using any Markdown→PPT tool,
#    or use marp (https://marp.app) or rmarkdown::render(..., "powerpoint")
```

---

## Quality Assessment

Scored 0–100 against the criteria from the original specification.

| Category | Score | Notes |
|---|---|---|
| **Architecture** | **93** | ADR-documented, modular, narrow interfaces, no circular deps, plugin hook, cache design documented in ADR 0003, reporter contract specified; would earn 95+ once multiple downstream consumers exist to validate extension points |
| **Rule Engine** | **91** | 16 real, well-tested rules across 7 categories; self-gated ecosystem rules; configurable per rule (severity, params); plugin hook tested; would earn higher once plugin discovery is implemented |
| **Performance** | **62** | AST caching ships; benchmark command exists; no parallel evaluation; no large-repo measurement; performance at scale is acknowledged roadmap work rather than solved |
| **Documentation** | **88** | ADRs, 5 prose guides, CLI reference, pkgdown API site, roadmap, CONTRIBUTING updated; gaps: missing multiple ecosystem example projects, no vignettes, no formal demo video/screenshots |
| **Testing** | **85** | 168 test_that / 319 expectations / 0 failures; positive + negative fixtures for every rule; integration test; real security review; the covr-measurement artifact (0% on rules_*.R due to closure instrumentation) means the raw coverage number is misleading — actual coverage is ~91% for the measurable modules |
| **Extensibility** | **92** | register_rule() plugin hook works and is tested; reporter function contract holds for all 7 formats; RStudio addin; SARIF for tool integration; cache designed with future rule-scope model in mind (ADR 0003); the plugin discovery convention (scanning .libPaths) is deferred |
| **Developer Experience** | **87** | Clean R CMD check; rtrace doctor; rtrace benchmark; CONTRIBUTING accurate (devtools-alternative workflow documented); rtrace init + template; colorized console output; 0-config scan works; pkgdown site; could improve with a `withr`-style `with_rtrace_config()` helper for test setup |
| **Open Source Readiness** | **76** | All standard community files present; CI workflows; issue templates; security policy; CHANGELOG → NEWS pointer; pkgdown CI; but: no real GitHub remote yet, CRAN submission needs real maintainer contact + URL resolution, no version 1.0 governance model yet |
| **Research Applicability** | **78** | Catches the R reproducibility and portability anti-patterns most common in research code (`setwd`, hardcoded paths, `<<-`, `assign`); targets/plumber support; documentation.missing; missing Bioconductor rules, Quarto/Rmd scanning, and multi-file narrative-style examples |
| **Enterprise Readiness** | **71** | SARIF + HTML + CSV + XML reporters cover enterprise reporting; rtrace doctor for environment/setup debugging; SECURITY.md; CSV injection patched; incremental scanning for CI efficiency; missing: parallel evaluation for large monorepos, formal SLA/support process, multi-project dashboard, organizational-wide config inheritance |
| **Overall Production Readiness** | **82** | The core engine, rule set, reporters, and CLI are genuinely production-ready for their stated scope: static architecture enforcement for R projects in CI or developer workflows. The package cannot be called "1.0" given the placeholder GitHub URL, absent CRAN submission, and unresolved deferred roadmap items — but "pre-release public alpha" is a completely accurate, honest characterization and the package is ready for that milestone today. |

---

## Answering the Final Questions

> Would experienced R developers trust this project?

**Yes**, with the following conditions: the `R CMD check` is clean, the
documentation is honest about limitations (especially the `source()` path
resolution heuristic and the covr measurement artifact), and the code is
readable and well-structured. The ADRs are particularly strong signals for
experienced developers that design decisions were made deliberately rather
than accidentally. The main reservation would be: the package is not yet
on CRAN and the GitHub placeholder URLs would be immediately visible.

> Would research laboratories adopt it?

**Probably**, specifically for the reproducibility-hygiene rules (`setwd`,
hardcoded paths, `<<-`) and the `targets` pipeline structure check. Less
certain for Bioconductor-focused labs until the Bioconductor rule pack
lands. The documentation quality is high enough that a technical lead could
evaluate and adopt it without needing support.

> Would enterprise analytics teams use it?

**Possibly**, for the SARIF/CI integration and the dependency-direction
enforcement. The main gaps for enterprise are: no parallel evaluation for
large repos, no organizational-wide config inheritance model, and no
formal support pathway. The CI integration story (SARIF + exit status) is
solid.

> Would the architecture support five years of future development?

**Yes**, with two caveats: (1) the `Rule`'s current `check_fn(context,
params)` contract is project-wide, which defers per-file diagnostic caching
to a future extension (ADR 0003) — this won't cause problems for years,
but it's a known design ceiling; (2) the `.onLoad()`-time rule registration
pattern has an unexpected side effect on `covr` coverage reporting that
should eventually be refactored for measurement ergonomics.

---

## Future Roadmap

See [dev/roadmap.md](roadmap.md) for the complete, versioned roadmap.
Highest-priority remaining items by value/risk:

1. Create a real GitHub remote at `rtrace-dev/rtrace` (all workflows and
   pkgdown CI are ready to wire up; this is the immediate next step for
   publication).
2. Write a `vignette("rtrace")` so pkgdown Articles tab is populated
   (requires `knitr` in Suggests + `VignetteBuilder: knitr` in DESCRIPTION
   — both were removed when rmarkdown was blocked; now that rmarkdown
   installs cleanly, these can be restored).
3. Per-rule `scope: "file" | "project"` on the `Rule` interface (needed
   for correct per-file diagnostic caching — ADR 0003).
4. Plugin discovery convention (scan `.libPaths()` for `Config/rtrace/plugin`
   DESCRIPTION field, call `requireNamespace()` on found packages to
   trigger their `.onLoad()` self-registration).
5. Additional ecosystem example projects (Shiny, Bioconductor, enterprise).
