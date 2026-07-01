# Trace Platform — 5-Year Technical Roadmap

**Starting point:** Trace Platform 0.2.0 (2026-07-01)  
**Horizon:** 2031

---

## Guiding Principles

1. **Ship vertically, not horizontally** — each release should work end-to-end
   for a narrow audience, not add 10 half-finished features.
2. **R-ecosystem first** — 80% of the user base will be R users for the
   foreseeable future. Multi-language adds value but should not fracture focus.
3. **CLI and API are forever** — every automation-facing interface is a
   long-term contract. Breaking changes require a major version bump and a
   migration guide.
4. **Diagnostics model is the foundation** — all new modules speak the same
   `rtrace_diagnostic` language. If it can't be expressed as a diagnostic, it
   doesn't belong in the platform.

---

## 2026 — Consolidation (0.2.x → 0.3.x)

**Theme:** Stabilise the platform foundation; fill the most important gaps.

### Q1 2026 (0.2.x patch releases)

- R CMD check clean pass; CRAN re-submission
- Fix any edge cases found in the 47-rule scan engine
- Write tests for all new platform code (scoring, engines, dashboard, API)
- Update pkgdown site with new platform documentation

### Q2 2026 (0.3.0)

- **WorkflowTrace** — Makefile / `targets` / Snakemake workflow analysis
  - Detects un-connected targets, missing phony declarations, hard-coded paths
  - Works in both `Pattern A` (shell tool wrapper) and `Pattern C` (native R)
- **Scan history store** — SQLite-backed; `rtrace history` CLI command
  - Store per-scan scores by module, timestamp, git hash
  - Trend line in dashboard (score over last N scans)
- **GitHub Actions action.yml** — standalone `rtrace/scan-action` for users
- **Docker image** — `rocker/r-ver`-based; exposes the plumber API
- **Reporter: JUnit XML** — for CI test results integration (IntelliJ, etc.)

### Q3 2026 (0.3.1)

- **Async API jobs** — `POST /scan/async` → `{"job_id": "..."}`;
  `GET /jobs/:id` polls status; webhook on completion
- **Reproducibility improvements** — Docker / container detection;
  `{renv}` snapshot validation (compare lock file to installed library)
- **DataTrace: Excel support** — `readxl` backend (Suggests guard)
- **DataTrace: duplicate row detection** — configurable threshold
- **Rule severity override in config** — allow `severity: info` →
  `severity: error` per rule in `rtrace.yml`

### Q4 2026 (0.3.2 / 0.4.0-rc)

- **PyTrace alpha** — Python static analysis via `ruff` CLI wrapper
  - Supports: import cycle detection, anti-patterns, docstring coverage
- **JTrace alpha** — Java / Kotlin via Checkstyle / PMD
- **Recommendation engine: Claude adapter** (separate package `rtrace.ai`)
  - `register_recommendation_provider()` calling Claude claude-sonnet-4-6
  - Context-aware: passes violating code snippet to the LLM
- **API authentication** — Bearer token middleware; `rtrace token create`

---

## 2027 — Multi-Language Platform (0.4.x → 0.5.x)

**Theme:** Extend beyond R; launch hosted platform beta.

### Q1 2027 (0.4.0)

- **PyTrace stable** — Full Python analysis module; pip-installable companion
- **JTrace stable** — Maven / Gradle project support
- **Plugin test framework** — `expect_rule_fires()`, `expect_score_above()`
  test helpers so plugin authors can write unit tests for their rules
- **Rule deprecation API** — `deprecate_rule(id, replaced_by)` so plugins
  can evolve without breaking consumers

### Q2 2027 (0.4.1)

- **TSTrace alpha** — TypeScript / JavaScript via ESLint + ts-morph
- **Multi-project aggregate scan** — `platform_scan(roots = c(...))` with
  portfolio-level dashboard
- **Scan comparison** — `diff_scans(scan_a, scan_b)` shows regressions and
  improvements between two scan results
- **SBOM output** — `reporter_sbom()` producing CycloneDX or SPDX
  for software composition analysis workflows

### Q3 2027 (0.5.0)

- **Hosted platform public beta** — cloud-hosted; GitHub App integration;
  automatic scan on PR; score badge generation
- **Organization model** — teams, projects, shared rule configs
- **SSO (SAML / OIDC)** — enterprise authentication
- **Custom rule marketplace** — community plugins listed at tracehq.dev

### Q4 2027 (0.5.1)

- **JuliaTrace alpha** — Julia static analysis via JuliaCall
- **RustTrace alpha** — Rust code via `cargo clippy` wrapper
- **Ownership rules** — file → team mapping; alert when out-of-bounds
  dependency crosses team boundaries
- **API v2** — breaking-change release; versioned at `/v2/`; v1 deprecated
  with 12-month sunset

---

## 2028 — Intelligence Layer (0.6.x)

**Theme:** AI-powered recommendations; architectural intelligence.

### Q1 2028 (0.6.0)

- **AI code review integration** — `rtrace review` command runs a scan and
  posts inline suggestions to a GitHub / GitLab PR via API
- **Architectural metrics** — coupling, cohesion, instability index per module
- **Quality gates** — configurable score thresholds per module;
  `platform_scan()` returns `$passed` boolean for CI gating

### Q2 2028 (0.6.1)

- **Predictive analysis** — given current trend data, predict when project
  score will drop below a threshold
- **AI-generated fix suggestions** — LLM provider produces a unified diff
  to fix a violation; user can apply directly from CLI
- **Language: ScalaTrace, GoTrace**

### Q3–Q4 2028 (0.7.0)

- **IDE extension** — VS Code extension (separate repo) with:
  - Inline diagnostic annotations
  - Hover to see recommendation
  - Run scan from editor
- **Shiny dashboard** — interactive alternative to static HTML; auto-refresh
- **GraphQL API** — alongside REST; better for frontend query flexibility

---

## 2029 — Enterprise Grade (0.8.x → 1.0.0-rc)

**Theme:** Reliability, compliance, enterprise features.

### H1 2029 (0.8.x)

- **SOC 2 Type I audit** (hosted platform)
- **Self-hosted enterprise edition** — Docker Compose + Helm chart +
  enterprise license; full feature parity with hosted
- **Audit log** — every scan, config change, and user action is logged
- **Data retention policies** — configurable per organization
- **SBOM in CI** — automated software composition report on every merge

### H2 2029 (0.9.0)

- **Marketplace GA** — official curated plugin registry
- **Multi-region hosting** — EU data residency; GDPR compliance
- **Rule fine-tuning** — use accepted/dismissed recommendations to train
  organization-specific rule weighting (on-prem LLM fine-tuning)
- **Benchmark database** — anonymised, opt-in aggregate scores across
  projects to give "you score better than 78% of similar R packages"

---

## 2030 — Platform Maturity (1.0.0 GA)

**Theme:** Stable, trusted, widely adopted.

### H1 2030 (1.0.0-rc → 1.0.0)

- **1.0.0 API stability guarantee** — no breaking changes without major bump
- **CRAN submission of full platform** (or CRAN + Bioconductor)
- **Certification program** — "Trace Platform Verified" badge for packages
  that pass all QA gates
- **Academic publication** — paper on the platform's approach to research
  software governance

### H2 2030 (1.1.x)

- **Natural language rule authoring** — describe a rule in plain English;
  LLM generates the `check_fn`; human reviews and approves
- **Dependency risk scoring** — license compatibility, known vulnerabilities
  (via OSV database), maintenance status
- **Notebook analysis** — Jupyter / Quarto notebook linting
  (cell order, hidden state, reproducibility)

---

## 2031 — Ecosystem Leadership

- **Trace Protocol** — open specification for code quality diagnostics;
  language-agnostic JSON schema that any tool can emit and any reporter
  can consume (think LSP but for quality)
- **Federated plugin registry** — any organization can host a private
  registry; plugins discovered across registries
- **AI governance layer** — track AI-generated code; flag AI-authored
  sections that lack human review; integration with GitHub Copilot metadata
- **Research integrity module** — specialized for academic R/Python projects:
  p-hacking detection (statistical anti-pattern rules), data dredging
  flags, pre-registration consistency checks

---

## Version Summary

| Version | Year | Theme |
|---------|------|-------|
| 0.1.0 | 2025 | Architecture governance for R (baseline) |
| 0.2.0 | 2026 | Multi-module platform foundation |
| 0.3.0 | 2026 | WorkflowTrace, scan history, Docker |
| 0.4.0 | 2027 | PyTrace, JTrace, plugin test framework |
| 0.5.0 | 2027 | Hosted platform beta, organizations |
| 0.6.0 | 2028 | AI code review, architectural metrics |
| 0.7.0 | 2028 | IDE extension, Shiny dashboard |
| 0.8.0 | 2029 | Enterprise, SOC 2, self-hosted |
| 1.0.0 | 2030 | Stable API, CRAN, certification |
| 1.1.0 | 2030 | Natural language rules, notebook analysis |
| 2.0.0 | 2031 | Trace Protocol, research integrity module |

---

## Resource Requirements (To Execute Roadmap)

| Phase | Team | Notes |
|-------|------|-------|
| 2026 (0.2–0.3) | 1–2 engineers (maintainers) | Primarily OSS effort |
| 2027 H1 (0.4) | 2–3 engineers | PyTrace + JTrace need dedicated time |
| 2027 H2 (0.5) | 4–6 engineers + 1 infra | Hosted platform requires full-time ops |
| 2028–2029 | 6–10 engineers | Enterprise features, compliance |
| 2030+ | 10–20 engineers | Ecosystem leadership, protocol work |
