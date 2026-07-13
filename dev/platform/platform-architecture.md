# Trace Platform — Architecture Guide

**Version:** 0.2.0.dev  
**Date:** 2026-07-01

---

## Overview

The Trace Platform is a modular software quality and architecture governance
system. RTrace (the founding module) established the core engine in 0.1.0;
version 0.2.0 lifts it into a multi-module platform with a shared rule
engine, scoring system, recommendation engine, REST API, and modern
dashboard.

```
┌────────────────────────────────────────────────────────────────────┐
│                        TRACE PLATFORM                              │
├──────────┬──────────────┬───────────┬───────────┬─────────────────┤
│  RTrace  │ Reproducibility │ DataTrace │ DocsTrace │  PackageQA    │
│ (Arch.)  │  (Engine)    │ (Module)  │ (Module)  │  (Module)      │
└────┬─────┴──────┬───────┴─────┬─────┴─────┬─────┴──────┬──────────┘
     │            │             │           │            │
     └────────────┴─────────────┴───────────┴────────────┘
                                    │
              ┌─────────────────────┼─────────────────────┐
              │                     │                     │
     ┌────────▼──────┐   ┌──────────▼───────┐   ┌────────▼──────────┐
     │  Rule Engine   │   │ Scoring System   │   │ Recommendation    │
     │  (Shared)      │   │  (0–100 scores)  │   │ Engine (AI-ready) │
     └────────┬──────┘   └──────────┬───────┘   └────────┬──────────┘
              │                     │                     │
     ┌────────▼─────────────────────▼─────────────────────▼──────────┐
     │                     Diagnostics Model                          │
     │   rtrace_diagnostic / rtrace_diagnostic_set                   │
     └───────────────────────────────────────────────────────────────┘
                                    │
              ┌─────────────────────┴──────────────────────┐
              │                                            │
     ┌────────▼──────────┐                    ┌────────────▼──────┐
     │   Reporters (7)   │                    │   REST API        │
     │ console JSON HTML │                    │  (plumber-based)  │
     │ Markdown SARIF   │                    │  /scan /rules /   │
     │ CSV XML Dashboard │                    │  /health /report  │
     └───────────────────┘                    └───────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    │          CLI (17 commands)     │
                    │  scan platform-scan datatrace  │
                    │  docstrace pkgqa health api    │
                    │  [+ 10 core RTrace commands]   │
                    └───────────────────────────────┘
```

---

## Module Dependency Diagram

```
platform_scan()
    │
    ├── rtrace module
    │   ├── build_context()
    │   │   ├── scan_files()           [walker.R]
    │   │   ├── parse_files_cached()   [parser.R + cache.R]
    │   │   └── build_dependency_graph() [dependency_graph.R]
    │   └── run_rules()                [rule_engine.R]
    │
    ├── reproducibility module
    │   ├── build_context()            [reuses rtrace engine]
    │   └── run reproducibility.* rules
    │
    ├── datatrace module
    │   ├── scan_data_files()          [engine_datatrace.R]
    │   └── run datatrace.* rules
    │
    ├── docstrace module
    │   └── run docstrace.* rules      [engine_docstrace.R]
    │
    └── packageqa module
        └── run packageqa.* rules      [engine_packageqa.R]
                │
                └── compute_score() for each module [scoring.R]
                        │
                        └── aggregate_scores() → platform score
                                │
                                ├── reporter_dashboard() [reporter_dashboard.R]
                                │       (full HTML platform dashboard)
                                └── reporter_html() / reporter_json() / etc.
```

---

## Core Architectural Decisions

### 1. Everything is a diagnostic

All modules (code analysis, data quality, documentation, package metadata)
produce `rtrace_diagnostic` objects. This means:

- All reporters work with all modules
- The scoring system is universal
- The recommendation engine maps `rule_id → recommendation`
- The REST API has a single response schema

### 2. Rule registration is the extension point

Adding capability to the platform = implementing `Rule$new()` or an
engine-specific rule constructor (`datatrace_rule()`, `docstrace_rule()`,
`packageqa_rule()`) and calling `register_rule()`. No engine code needs to
change.

### 3. Module registration enables multi-language

Adding a language = implementing `scan_fn()` and `score_fn()` and calling
`register_module()`. The platform's `platform_scan()`, REST API, and
dashboard automatically include the new language.

### 4. Backwards compatibility is inviolable

The 0.1.0 API (`run_scan()`, `reporter_json()`, `rtrace_cli()`, etc.) is
completely unchanged. 0.2.0 adds new functions; it does not remove or break
any existing ones.

### 5. No forced runtime dependencies

New modules that require heavy packages (`readxl`, `arrow`, `plumber`) use
`requireNamespace()` guards with informative errors. Plumber is in
`Suggests`, not `Imports`.

---

## File-to-Concept Mapping

| Concept | File(s) |
|---------|---------|
| Platform registry | `R/platform.R` |
| Scoring | `R/scoring.R` |
| Plugin discovery | `R/plugin_discovery.R` |
| AI recommendations | `R/recommendation_engine.R` |
| REST API | `R/api.R` |
| Platform dashboard | `R/reporter_dashboard.R` |
| Platform CLI | `R/cli_platform.R` |
| Reproducibility engine | `R/engine_reproducibility.R` |
| Reproducibility rules | `R/rules_reproducibility.R` |
| DataTrace engine | `R/engine_datatrace.R` |
| DataTrace rules | `R/rules_datatrace.R` |
| DocsTrace engine | `R/engine_docstrace.R` |
| DocsTrace rules | `R/rules_docstrace.R` |
| Package QA engine | `R/engine_packageqa.R` |
| Package QA rules | `R/rules_packageqa.R` |

---

## Data Flow: Scan Request to Dashboard

There is exactly **one** orchestration path. `cmd_platform_scan()` (CLI) and
the `/scan/full` REST handler never invoke a module's scan function
themselves -- both call `platform_scan()`, which is the only code in the
platform that iterates the module registry and runs `scan_fn()`/`score_fn()`
for each entry. This was not always true: prior to the module-registration
fix, `cmd_platform_scan()` hard-coded calls to each engine's
`run_*_scan()` function while `platform_scan()` only iterated
`list_modules()` -- and only `"rtrace"` was ever registered at load time, so
the two interfaces silently diverged (Issue #1). Every built-in module is
now registered in `.onLoad()` (`R/zzz.R`), which closes that gap structurally
rather than patching either call site individually.

```
1. User runs: rtrace platform-scan path/to/project
   (or: POST /scan/full with {"root": "path/to/project"})

2. cmd_platform_scan() / API handler
   │
   └── platform_scan(root, config)
         │
         └── for each module in list_modules():   # registered in .onLoad()
               ├── rtrace            → build_context() + run_rules()
               ├── reproducibility   → run_reproducibility_scan()
               ├── docstrace         → run_docstrace_scan()
               ├── packageqa         → run_packageqa_scan()
               └── datatrace         → run_datatrace_scan()

3. score_fn(diagnostics) per module → N × trace_score
   (a module that throws during scan_fn/score_fn is caught, logged as a
   warning, and contributes an empty diagnostic set / zero score rather
   than aborting the whole scan)

4. aggregate_scores() → 1 platform trace_score

5. get_recommendations(all_diags) → recommendations per rule

6. reporter_dashboard(platform_result, recommendations)
   → single self-contained HTML document

7. Opened in browser / RStudio Viewer / saved as CI artifact
```

Single-module entry points (`POST /scan`, `GET /report/html`, `rtrace
docstrace`, `rtrace pkgqa`, etc.) also route through `platform_scan()`
(scoped via the `modules = "<id>"` argument) or call one module's own
`run_*_scan()` directly when they are intentionally single-module commands
-- neither rebuilds the orchestration loop above.

---

## Extension Points

| Extension Type | How |
|---------------|-----|
| New rule | `Rule$new() + register_rule()` |
| New language module | `register_module()` in `.onLoad()` |
| New reporter format | Function `function(diagnostics, ...) → character` |
| New recommendation provider | `register_recommendation_provider()` |
| New CLI command | `cmd_*()` function + add to `rtrace_cli()` switch |
| New API endpoint | `pr$handle()` in `build_api_router()` |
| Custom scoring | `compute_score(error_penalty=, warning_penalty=)` |
