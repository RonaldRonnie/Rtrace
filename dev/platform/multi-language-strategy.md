# Trace Platform — Multi-Language Support Strategy

**Version:** 0.2.0  
**Status:** Interface designed; R module shipped; others planned.

---

## Design Goals

1. **No redesign needed to add a language** — implementing `scan_fn()` and
   calling `register_module()` is the entire integration path.
2. **Shared diagnostics model** — every language's findings are
   `rtrace_diagnostic` objects so all reporters and the dashboard work
   without language-specific code.
3. **Shared scoring** — `compute_score()` works on any diagnostic set.
4. **Shared recommendation engine** — rule IDs are strings; the recommendation
   lookup table is language-agnostic.
5. **No coupling between language modules** — a JTrace bug cannot break RTrace.

---

## Interface Contract

See `platform/interfaces/language_module_interface.md` for the complete
technical specification. Summary:

```r
# Implement in your language module package's .onLoad()
RTrace::register_module(list(
  id          = "jtrace",                      # unique module id
  name        = "Architecture Governance (Java/Kotlin)",
  version     = as.character(utils::packageVersion("jtrace")),
  description = "...",
  languages   = c("java", "kotlin"),

  # Returns an rtrace_diagnostic_set
  scan_fn     = function(root, config) { ... },

  # Returns a trace_score
  score_fn    = function(diags) RTrace::compute_score(diags)
))
```

---

## Implementation Patterns for Non-R Languages

There are three patterns for implementing a language module:

### Pattern A: Wrap an existing CLI tool

Best for: languages with mature static analysis tooling (Java/Checkstyle,
Python/pylint, TypeScript/ESLint).

```r
# jtrace/R/scan.R
run_jtrace_scan <- function(root, config = NULL) {
  result_xml <- system2("checkstyle", c("-f", "xml", root), stdout = TRUE)
  parse_checkstyle_xml(result_xml)  # → rtrace_diagnostic_set
}
```

**Advantages:** Leverages existing analysis depth; minimal new code.  
**Disadvantages:** Requires the external tool to be installed; output format
changes between tool versions may need adapter updates.

### Pattern B: Call a language-native package via reticulate/rJava

Best for: Python (`reticulate`) and Java/Kotlin (`rJava`).

```r
# pytrace/R/scan.R
run_pytrace_scan <- function(root, config = NULL) {
  py <- reticulate::import("pytrace_core")  # a Python package you wrote
  findings <- py$analyze(root)
  convert_pytrace_findings(findings)  # → rtrace_diagnostic_set
}
```

**Advantages:** Full access to the language's native AST and tooling.  
**Disadvantages:** Requires the bridging package to be installed.

### Pattern C: Native R implementation

Best for: simple text-based analysis (Makefiles, YAML, Markdown, CSV).

```r
# workflowtrace/R/scan.R
run_workflowtrace_scan <- function(root, config = NULL) {
  makefiles <- list.files(root, pattern = "^Makefile", recursive = TRUE)
  # Analyse Makefile structure and return diagnostics
  ...
}
```

**Advantages:** No external dependencies; fastest startup.  
**Disadvantages:** Building a real AST parser for a general-purpose language
in pure R is impractical; only suitable for simple pattern matching.

---

## Planned Module Roadmap

| Module | Language(s) | Approach | Est. Timeline |
|--------|------------|----------|---------------|
| **RTrace** | R | Native (shipped) | ✅ 0.1.0 |
| **DataTrace** | CSV, TSV, Excel | Native R (shipped) | ✅ 0.2.0 |
| **DocsTrace** | Markdown, Quarto | Native R (shipped) | ✅ 0.2.0 |
| **PackageQA** | R packages | Native R (shipped) | ✅ 0.2.0 |
| **WorkflowTrace** | Makefile, targets, snakemake | Pattern A + C | 0.3.0 |
| **PyTrace** | Python | Pattern A (pylint/ruff) | 0.4.0 |
| **JTrace** | Java, Kotlin | Pattern A (Checkstyle) | 0.4.0 |
| **TSTrace** | TypeScript, JS | Pattern A (ESLint) | 0.5.0 |
| **JuliaTrace** | Julia | Pattern B (via JuliaCall) | 0.5.0 |
| **ScalaTrace** | Scala | Pattern A (Scalastyle) | 0.6.0 |
| **RustTrace** | Rust | Pattern A (clippy) | 0.6.0 |

---

## AST Abstraction

The current `rtrace_file_ast` class is R-specific (it stores R's parse data
frames). For non-R languages, modules should define their own AST wrapper
class that still exposes the fields the recommendation engine and reporters
need:

```
field        type         purpose
──────────── ──────────── ──────────────────────────────────────
path         character    absolute path to the source file
lines        character[]  source file lines (for context display)
error        condition    parse error if the file could not be parsed
```

Language-specific fields can be added freely.

---

## Avoiding Language Assumptions in Shared Code

The platform's shared components (`scoring.R`, `reporter_dashboard.R`,
`api.R`, `recommendation_engine.R`) are designed to be language-agnostic:

| Shared component | Language-specific assumption? | How avoided |
|-----------------|-------------------------------|-------------|
| `compute_score()` | None — operates on diagnostic counts | ✅ |
| `aggregate_scores()` | None — operates on score objects | ✅ |
| `reporter_dashboard()` | None — renders scores and diagnostics | ✅ |
| REST API | None — JSON in/out | ✅ |
| Recommendation engine | `rule_id` string → recommendation | ✅ |
| `rtrace_diagnostic` | `file` is a string (works for any language) | ✅ |
| `rtrace_context` | R-specific (ASTs, dependency graph) | ⚠️ Only passed to R rules |

The key invariant: **language modules receive their own context (the result
of their own `scan_fn`), never the `rtrace_context` (which is R-specific).**
