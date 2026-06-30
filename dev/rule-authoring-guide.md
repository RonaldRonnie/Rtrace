# Rule Authoring Guide

A rule is an instance of the [`Rule`](../R/rule.R) `R6` class: an id, a
description, default severity/parameters, and a `check(context, params)`
function that inspects an [`rtrace_context`](../R/context.R) and returns a
list of [`rtrace_diagnostic`](../R/diagnostic.R) objects.

## The `rtrace_context` object

Every rule receives the same fully-built context — rules never re-walk the
filesystem or re-parse files:

| Field | Type | Description |
|---|---|---|
| `root` | character scalar | Absolute, normalized project root. |
| `config` | `rtrace_config` | The resolved configuration. |
| `files` | data.frame | `path` (absolute), `rel_path`, `layer` — one row per scanned file. |
| `asts` | named list | `rtrace_file_ast` per file, keyed by absolute path. |
| `dependency_graph` | list | `package_imports` (rel_path -> package names) and `layer_graph` (layer -> layers it depends on). |

Useful helpers when writing a `check_fn`:

* [`top_level_functions(ast)`](../R/parser.R) — name, line span, and body
  expression of each top-level `name <- function(...) ...`.
* [`find_calls(ast, "fn_name")`](../R/parser.R) — every call site of a
  named function, with line/column.
* [`find_superassignments(ast)`](../R/parser.R) — every `<<-` site.
* [`cyclomatic_complexity(fn_expr)`](../R/parser.R) — McCabe complexity of
  a function body expression.
* `ast$parse_data` — the raw `utils::getParseData()` data frame, for
  token-level checks (see `antipattern.hardcodedPath`'s `STR_CONST` scan
  for an example).

## A minimal rule

```r
library(R6)

rule_no_print <- function() {
  Rule$new(
    id = "antipattern.print",
    description = "Flags use of print() in package R/ files.",
    default_severity = "info",
    default_params = list(),
    check_fn = function(context, params) {
      diags <- list()
      for (i in seq_len(nrow(context$files))) {
        path <- context$files$path[i]
        ast <- context$asts[[path]]
        if (is.null(ast)) next
        hits <- find_calls(ast, "print")
        for (j in seq_len(nrow(hits))) {
          diags[[length(diags) + 1]] <- new_diagnostic(
            rule_id = "antipattern.print",
            severity = "info",
            file = context$files$rel_path[i],
            line = hits$line1[j],
            column = hits$col1[j],
            message = "Use of print() in package code; consider message()/cat() or removing debug output.",
            suggestion = "Remove debug print() calls before committing."
          )
        }
      }
      diags
    }
  )
}
```

## Registering a built-in rule

Built-in rules are registered in [`R/zzz.R`](../R/zzz.R)'s `.onLoad()`,
*not* via top-level `register_rule()` calls in the rule's own file — this
avoids depending on file-sourcing order during package installation. If
you're contributing a built-in rule:

1. Add `R/rules_<category>.R` with a `rule_<name>()` constructor function
   (returns a `Rule`, does **not** call `register_rule()` itself).
2. Add a `register_rule(rule_<name>())` line to `.onLoad()` in `R/zzz.R`.
3. Add it to [`inst/templates/rtrace.yml`](../inst/templates/rtrace.yml)
   and document it in [rules-reference.md](rules-reference.md).
4. Add `tests/testthat/test-rules-builtin.R` cases: one fixture that should
   trigger the rule, one that should not.

## Registering a third-party rule (plugin)

Third-party packages don't need to fork RTrace. Call the exported
`register_rule()` from your own package's `.onLoad()`:

```r
.onLoad <- function(libname, pkgname) {
  RTrace::register_rule(mypkg_rule_no_print())
}
```

Once your package is loaded (e.g. via `library(mypkg)`), its rules are
available under their `id` in `rtrace.yml` exactly like built-in rules.

A convention-based discovery mechanism (RTrace scanning installed packages
for an `rtrace.plugins` field, rather than requiring `.onLoad()`) is
planned for a later release — see [dev/roadmap.md](roadmap.md).

## Returning diagnostics

* Return `list()` (or `NULL`/zero-length) for "no problems found" — don't
  return a "clean" diagnostic.
* `severity` you set in `new_diagnostic()` is only the rule's *default*;
  the engine overrides it with whatever severity the project's
  `rtrace.yml` configured for this rule, so don't rely on the severity
  your `check_fn` set being what's actually reported.
* Always set `file` to a project-relative path
  (`context$files$rel_path[i]`), not an absolute path — diagnostics should
  be portable across machines and CI runners. For project-wide findings
  with no single file (e.g. circular dependencies), use a synthetic
  marker like `"(project)"`.
* A rule that throws is caught by the engine and surfaced as a single
  `rule-error` diagnostic — you don't need defensive `tryCatch()` inside
  your own `check_fn` for this purpose, though you should still validate
  required `params` explicitly (see `dependency.forbidden`'s `from`/`to`
  check) so misconfiguration produces a clear message.
