# Rules Reference

Run `rtrace list-rules` for the live list (this file documents the same
rules shipped in 0.1.0, with more detail and examples). `rtrace
describe-rule <id>` prints a single rule's defaults at any time.

## structure.requiredDirs

* **Default severity:** `warning`
* **Params:** `dirs` (character vector, default `["R", "tests"]`)
* **Detects:** configured directories that do not exist under the project
  root.
* **Example:**
  ```yaml
  - type: structure.requiredDirs
    dirs: ["R", "tests", "man"]
  ```

## dependency.forbidden

* **Default severity:** `error`
* **Params:** `from`, `to` (layer names declared under `layers:`) — both
  required
* **Detects:** a `source()`-derived dependency edge from layer `from` to
  layer `to`. One entry expresses one forbidden pair; declare it multiple
  times for multiple pairs.
* **Known limitation:** only resolves string-literal `source()` arguments
  (first tried relative to the project root, then to the sourcing file's
  own directory); dynamically constructed paths
  (`source(file.path(...))`) are not resolved. See
  [ADR 0002](adr/0002-core-architecture.md).
* **Example:**
  ```yaml
  - type: dependency.forbidden
    from: analysis
    to: shiny
  ```

## dependency.circular

* **Default severity:** `error`
* **Params:** none
* **Detects:** cycles in the layer-level dependency graph (same `source()`
  resolution as `dependency.forbidden`). Reports each cycle as a single
  diagnostic listing the layer sequence, e.g.
  `analysis -> shiny -> analysis`.

## complexity.cyclomatic

* **Default severity:** `warning`
* **Params:** `max` (integer, default `15`)
* **Detects:** top-level functions whose McCabe cyclomatic complexity
  (decision points + 1: `if`, `for`, `while`, `repeat`, `&&`, `||`, and each
  `switch()` branch) exceeds `max`.

## complexity.functionLength

* **Default severity:** `warning`
* **Params:** `max` (integer, default `60`)
* **Detects:** top-level functions spanning more than `max` source lines.

## complexity.fileLength

* **Default severity:** `warning`
* **Params:** `max` (integer, default `500`)
* **Detects:** files with more than `max` lines.

## antipattern.globalAssign

* **Default severity:** `warning`
* **Params:** none
* **Detects:** use of `<<-` (superassignment), which mutates state outside
  a function's local scope.

## antipattern.assign

* **Default severity:** `info`
* **Params:** none
* **Detects:** calls to `assign()`, which can create variables under
  dynamically-constructed names that are hard to trace statically.

## antipattern.setwd

* **Default severity:** `error`
* **Params:** none
* **Detects:** calls to `setwd()`, which mutates global working-directory
  state and breaks reproducibility across machines/CI.

## antipattern.hardcodedPath

* **Default severity:** `warning`
* **Params:** none
* **Detects:** string literals that look like hardcoded absolute local
  filesystem paths (`/home/...`, `/Users/...`, `~/...`, `C:\...`), which
  break portability.

## documentation.missing

* **Default severity:** `info`
* **Disabled by default** in [`default_config()`](../R/config.R) — not
  every project intends every top-level function to be documented. Enable
  it for package projects where all top-level `R/` functions are public
  API.
* **Params:** none
* **Detects:** top-level functions (excluding dot-prefixed, conventionally
  internal functions) with no `#'` roxygen2 comment block immediately
  above their definition.

## testing.missingTests

* **Default severity:** `info`
* **Disabled by default**, like `documentation.missing` — it's a
  heuristic with real false positives (functions only invoked indirectly,
  S3/S4 methods invoked by generic dispatch, etc.).
* **Params:** none
* **Detects:** top-level functions (excluding dot-prefixed internal
  functions) whose name never appears as a token anywhere under `tests/`.
  This is a cheap static check, not runtime coverage measurement — for
  that, use [`covr`](https://covr.r-lib.org/) (see
  [ADR 0001](adr/0001-rtrace-scope-and-positioning.md)). Silent when the
  project has no `tests/` files at all, so it doesn't duplicate
  `structure.requiredDirs`'s "no tests directory" complaint.

## package.deprecatedApi

* **Default severity:** `warning`
* **Params:** `functions` — a mapping of deprecated identifier (bare
  `"old_fn"` or namespace-qualified `"pkg::old_fn"`) to suggested
  replacement text. No-op with an empty/unset `functions` map.
* **Detects:** calls to any configured deprecated function. Deliberately
  has no built-in deprecated-API list — "deprecated" is project- and
  ecosystem-specific.
* **Example:**

  ```yaml
  - type: package.deprecatedApi
    functions:
      "reshape2::melt": "tidyr::pivot_longer()"
      "plyr::ddply": "dplyr::group_by() + dplyr::summarise()"
  ```

## ecosystem.shinyStructure

* **Default severity:** `warning`
* **Enabled by default** — unlike the other opt-in/heuristic rules, this
  one is self-gated: it only evaluates anything if the project imports
  `shiny` somewhere, so it adds zero noise to non-Shiny projects.
* **Params:** none
* **Detects:** two Shiny-specific structural problems:
  1. A directory containing *both* an `app.R` and a `ui.R`/`server.R`
     pair — Shiny only recognizes one entrypoint convention per app
     directory.
  2. The project imports `shiny` but no directory has a valid `app.R` or
     `ui.R`+`server.R` entrypoint at all.

## ecosystem.targetsStructure

* **Default severity:** `warning`
* **Enabled by default** — self-gated like `ecosystem.shinyStructure`,
  on the project importing `targets`.
* **Params:** none
* **Detects:** the project imports `targets` but has no `_targets.R`
  pipeline definition at the project root (the file `targets::tar_make()`
  and friends require). `drake` (the package `targets` superseded) is
  deliberately not covered — it has no single fixed conventional
  entrypoint filename, so a presence check would be a guess.

## ecosystem.plumberStructure

* **Default severity:** `warning`
* **Enabled by default** — self-gated like `ecosystem.shinyStructure`,
  on the project importing `plumber`.
* **Params:** none
* **Detects:** the project imports `plumber` but has no `#*` route
  annotation comments (e.g. `#* @get /path`) anywhere — plumber APIs are
  defined entirely through these annotations.

## Writing your own rule

See the [Rule Authoring Guide](rule-authoring-guide.md).
