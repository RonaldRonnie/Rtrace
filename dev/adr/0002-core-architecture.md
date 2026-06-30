# ADR 0002: Core Architecture

- Status: Accepted
- Date: 2026-06-30
- Depends on: [ADR 0001](0001-rtrace-scope-and-positioning.md)

## Context

RTrace needs an architecture that lets new rules, reporters, and ecosystem
integrations be added without modifying the engine, while staying simple
enough to install in CI with no system dependencies beyond R itself.

## Decision

### Module boundaries

```
rtrace.yml config file
        |
        v
+------------------+      +------------------+
|  Config Loader   | ---> |  Project Scanner  |
|  (R/config.R)    |      |  (R/walker.R)     |
+------------------+      +------------------+
                                    |
                                    v
                           +------------------+
                           |     Parser       |
                           |  (R/parser.R)     |
                           +------------------+
                                    |
                     +--------------+--------------+
                     v                              v
          +------------------+          +-----------------------+
          | Dependency Graph |          |   Rule Context object  |
          | (R/dependency_   |--------->|   (R/context.R)        |
          |  graph.R)        |          +-----------------------+
          +------------------+                      |
                                                      v
                                          +------------------------+
                                          |      Rule Engine        |
                                          |  (R/rule_engine.R,      |
                                          |   R/rule.R)              |
                                          +------------------------+
                                                      |
                                                      v
                                          +------------------------+
                                          |  Diagnostics (R/        |
                                          |  diagnostic.R)           |
                                          +------------------------+
                                                      |
                                                      v
                                          +------------------------+
                                          |   Reporters (R/         |
                                          |   reporter_*.R)          |
                                          +------------------------+
                                                      |
                                                      v
                                          +------------------------+
                                          |   CLI (inst/rtrace,     |
                                          |   R/cli.R)               |
                                          +------------------------+
```

Each box is a separate file/unit with a narrow, testable interface and no
upward dependencies (e.g. `R/rule.R` never sources `R/cli.R`). This lets
every module be unit-tested in isolation with synthetic inputs.

### Config Loader (`R/config.R`)

- Reads `rtrace.yml` (or a path given via `--config`) using the `yaml`
  package and validates it against a known schema (required keys, allowed
  rule `type` values, type-checking of rule parameters).
- Produces an `rtrace_config` object: project metadata, the list of layers
  (named directory globs), and a list of `rule_spec` entries
  (`type`, `enabled`, `severity`, arbitrary rule-specific parameters).
- Unknown keys produce a warning, not a hard error (forward compatibility);
  unknown `type` values are a hard error at validation time, not at scan
  time, so misconfiguration is caught immediately by `rtrace validate`.
- `rtrace_default_config()` supplies sensible defaults so a project can run
  `rtrace scan` with zero configuration.

### Project Scanner (`R/walker.R`)

- Walks the project directory, respecting `.Rbuildignore`-style regex
  ignore patterns plus a built-in default ignore list (`.git`, `renv`,
  `packrat`, generated `man/`, etc.) and any `exclude` globs in the config.
- Returns a flat character vector of absolute file paths plus an assignment
  of each file to a configured "layer" (longest-prefix match against the
  config's `layers` map; files matching no layer go in a synthetic
  `"(unassigned)"` layer).

### Parser (`R/parser.R`)

- Wraps `parse(keep.source = TRUE)` + `utils::getParseData()`. Deliberately
  uses only base R so RTrace has no dependency on `lintr`'s or any other
  package's internal AST representation (see ADR 0001).
- Produces an `rtrace_file_ast` object per file: the parsed expression, the
  flat token data frame (with line/column ranges), and convenience
  extractors (`find_calls(ast, "setwd")`, `top_level_functions(ast)`,
  `line_count(ast)`).
- Parse failures (syntax errors) are captured as a diagnostic with a
  dedicated `parse-error` rule id rather than aborting the whole scan, so
  one broken file doesn't block analysis of the rest of the project.

### Dependency Graph (`R/dependency_graph.R`)

- Built from every file's `library()`/`require()`/`requireNamespace()`/
  `::`/`:::`/`source()` calls (extracted via the parser's `find_calls`).
- Two graph levels are built:
  1. **Package-level**: which CRAN/Bioconductor packages each file imports
     (feeds forbidden/required/deprecated-package rules).
  2. **Layer-level**: which configured layers reference which other layers,
     derived from `source()` targets and from intra-project `::` calls
     resolved via the package's own `DESCRIPTION`/`NAMESPACE` when scanning
     a package. This feeds dependency-direction and circular-dependency
     rules.
- Implemented as an adjacency list (named list of character vectors) plus
  `find_cycles()` (DFS-based cycle detection) rather than taking a
  dependency on a graph package, keeping the dependency footprint light.

### Rule Engine (`R/rule.R`, `R/rule_engine.R`)

- A rule is an `R6` object (`Rule`) with: `id`, `description`,
  `default_severity`, `default_params`, and a `check(context, params)`
  function that returns a list of `Diagnostic` objects.
- `context` (`R/context.R`) bundles everything a rule might need: the file
  list, per-file AST, the dependency graph, and the resolved config — so
  rules never re-walk the filesystem or re-parse files themselves.
- Built-in rules self-register into a package-level `rule_registry`
  environment at package load time via `register_rule()`. Third-party
  packages can call the exported `rtrace::register_rule()` in their own
  `.onLoad()` to add rules without forking RTrace — this is the plugin
  mechanism for 0.1.0 (a discovery mechanism that scans installed packages
  for an `rtrace.plugins` convention is the natural 0.2 extension, recorded
  in the roadmap rather than built speculatively now).
- `run_rules(context, config)` resolves the active rule set from
  `config$rules`, calls each rule's `check()`, tags every diagnostic with
  the rule id and the *configured* (not just default) severity, and
  collects results — a single rule erroring out is caught and reported as a
  `rule-error` diagnostic rather than aborting the scan.

### Diagnostics (`R/diagnostic.R`)

- A `Diagnostic` is a plain list with a constructor and validator:
  `rule_id`, `severity` (`"error" | "warning" | "info"`), `file`, `line`,
  `column`, `message`, `suggestion` (optional), `doc_url` (optional).
- A `DiagnosticSet` (thin wrapper over a list of `Diagnostic`) provides
  `summary()`, filtering by severity/rule/file, and `exit_status()` (used by
  the CLI to decide the process exit code: nonzero if any `error`-severity
  diagnostic exists).

### Reporters (`R/reporter_*.R`)

- A reporter is a function `function(diagnostic_set, ...) -> character(1)`
  (or, for console, a function with a side effect of writing to stdout).
  All reporters share one input type (`DiagnosticSet`), so adding a new
  format never touches the engine.
- 0.1.0 ships `reporter_console` (colored via `cli`, default), `reporter_json`
  (machine-readable, schema documented in
  [docs/configuration.md](../configuration.md)), and `reporter_markdown`
  (for PR comments / human-readable file output).
- SARIF/HTML/CSV/XML are designed against the same interface but are
  post-0.1.0 work (tracked in [docs/roadmap.md](../roadmap.md)) so the
  shipped reporters are complete rather than partial.

### CLI (`R/cli_commands.R`, `inst/rtrace`)

- A single executable shell wrapper (`inst/rtrace`, installed onto `PATH`
  via `Rscript -e 'cat(system.file("rtrace", package = "rtrace"))'` or run
  directly with `Rscript -e 'rtrace::rtrace_cli()'`) dispatches to one
  function per subcommand (`cmd_scan`, `cmd_init`, `cmd_validate`,
  `cmd_list_rules`, `cmd_describe_rule`, `cmd_config`, `cmd_doctor`,
  `cmd_version`, `cmd_help`). No CLI-parsing dependency is introduced; argument parsing is
  intentionally minimal (subcommand + `--flag value` pairs) and lives in
  `R/cli_args.R`, independently unit-testable from the commands themselves.
- The CLI is a thin layer: every command composes the same library calls
  (`load_config()`, `scan_project()`, `run_rules()`, a reporter) that are
  exported and independently usable from R scripts — "the CLI has no logic
  the R API doesn't also expose."

### Testing strategy

- Every module above has its own `tests/testthat/test-*.R` file using
  synthetic fixtures (small in-memory strings parsed via `parse(text = ...)`
  or temp directories via `withr::local_tempdir()`), not the example
  projects — unit tests must not depend on `inst/examples` so they stay fast
  and independent of documentation content.
- `inst/examples/*` (intentionally-violating sample projects, see Phase 14)
  are exercised by *integration* tests (`test-integration-*.R`) that run a
  full `scan_project()` end-to-end and assert on the resulting
  `DiagnosticSet`, catching regressions in how modules compose.
- `R CMD check` (via `rcmdcheck`) and `testthat::test_check()` both run in
  CI (`.github/workflows/R-CMD-check.yml`) on every push/PR.

## Consequences

- New rules require zero engine changes — implement `Rule$check()` and
  call `register_rule()`.
- New reporters require zero engine changes — implement the reporter
  function signature and add it to `R/cli_commands.R`'s `--format` switch.
- The architecture has a downside: the layer-level dependency graph relies
  on `source()`/`::` calls and configured layer globs, which is a heuristic,
  not a guarantee — dynamically constructed `source()` paths
  (`source(paste0(...))`) will not be resolved. This is documented as a
  known limitation rather than solved with deep symbolic execution, which is
  out of scope (see [docs/roadmap.md](../roadmap.md)).
