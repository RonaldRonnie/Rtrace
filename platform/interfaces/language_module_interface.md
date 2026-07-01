# Trace Platform — Language Module Interface Contract

This document defines the interface every language module (RTrace, JTrace,
PyTrace, WorkflowTrace, etc.) must implement. Modules that honour this
contract can be registered with [register_module()] and will automatically
participate in [platform_scan()], the REST API, and the dashboard.

---

## Required Module Fields

Every module registration list must include:

| Field | Type | Description |
|-------|------|-------------|
| `id` | character | Unique module id, lowercase (`"rtrace"`, `"jtrace"`) |
| `name` | character | Human-readable name (`"Architecture Governance (R)"`) |
| `version` | character | Semantic version string (`"1.0.0"`) |
| `description` | character | One-line description |

## Optional Module Fields

| Field | Type | Description |
|-------|------|-------------|
| `scan_fn` | function | `function(root, config)` → `rtrace_diagnostic_set` |
| `score_fn` | function | `function(diagnostics)` → `trace_score` |
| `languages` | character vector | Languages this module analyses (`c("R")`) |
| `requires` | character vector | Other module ids this module depends on |

## scan_fn Contract

```r
scan_fn <- function(root, config) {
  # root:   normalized absolute path to project root
  # config: an rtrace_config object (may be NULL for non-R modules)
  #
  # Returns: an rtrace_diagnostic_set
  #
  # Must NOT:
  #   - Call stop() / rlang::abort() for non-fatal issues (use diagnostics instead)
  #   - Write to disk outside of an optional cache directory
  #   - Require user interaction
}
```

## score_fn Contract

```r
score_fn <- function(diagnostics) {
  # diagnostics: an rtrace_diagnostic_set
  #
  # Returns: a trace_score object (use new_trace_score() or compute_score())
  #
  # Sensible defaults: use compute_score(diagnostics) with module-appropriate
  # penalty weights.
}
```

---

## Implementing a New Language Module

### Step 1 — Choose a package name

Convention: `{language}trace` (e.g. `jtrace`, `pytrace`, `scalatrace`).

### Step 2 — Add DESCRIPTION fields

```
Config/rtrace/plugin: true
Config/rtrace/module-id: jtrace
```

### Step 3 — Register in .onLoad()

```r
.onLoad <- function(libname, pkgname) {
  RTrace::register_module(list(
    id          = "jtrace",
    name        = "Architecture Governance (Java)",
    version     = as.character(utils::packageVersion("jtrace")),
    description = "Static analysis and architecture governance for Java projects.",
    languages   = c("java", "kotlin"),
    scan_fn     = jtrace::run_jtrace_scan,
    score_fn    = function(d) RTrace::compute_score(d, error_penalty = 10)
  ))
}
```

### Step 4 — Implement scan_fn

The `scan_fn` must parse the target language's source files and return an
`rtrace_diagnostic_set`. The diagnostics model is language-agnostic: every
diagnostic has `rule_id`, `severity`, `file`, `line`, `column`, `message`,
and optional `suggestion`.

For Java, this could mean:
- Running a Java static analysis tool (Checkstyle, SpotBugs, PMD)
- Parsing their XML output
- Converting each finding to an `rtrace_diagnostic`

### Step 5 — Test with the platform

```r
library(jtrace)  # triggers .onLoad() → register_module()
RTrace::list_modules()  # should include "jtrace"
result <- RTrace::platform_scan("path/to/java/project")
print(result)
```

---

## AST Interface

For language modules that parse source code directly (as opposed to wrapping
external tools), the shared AST interface is:

| Class | Purpose |
|-------|---------|
| `rtrace_file_ast` | Per-file parse result (path, lines, tokens, errors) |
| `rtrace_context` | Project-wide analysis context |
| `rtrace_diagnostic` | Single finding |
| `rtrace_diagnostic_set` | Collection of findings |

Language-specific AST classes can extend `rtrace_file_ast` by adding
language-specific fields (e.g. `java_imports`, `class_hierarchy`).

---

## Future Language Modules Planned

| Module | Language(s) | Status |
|--------|------------|--------|
| `rtrace` | R | Shipped v0.1.0 |
| `pytrace` | Python | Planned |
| `jtrace` | Java, Kotlin | Planned |
| `scalatrace` | Scala | Planned |
| `rustrace` | Rust | Planned |
| `tstrace` | TypeScript, JavaScript | Planned |
| `juliatrace` | Julia | Planned |
| `workflowtrace` | Any (CI/CD, Makefiles, targets) | Planned |
| `datatrace` | CSV, TSV, Excel, Parquet | Shipped v0.2.0 |
| `docstrace` | Markdown, Quarto, Rmd | Shipped v0.2.0 |
