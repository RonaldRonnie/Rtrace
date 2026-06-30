# ADR 0003: Incremental Scanning Caches Parsed ASTs, Not Diagnostics

- Status: Accepted
- Date: 2026-06-30
- Depends on: [ADR 0002](0002-core-architecture.md)

## Context

[dev/roadmap.md](../roadmap.md) committed to "incremental scanning: cache
parsed ASTs and per-file diagnostics keyed on file hash, invalidate only
changed files" for performance on repeated scans (interactive iteration,
CI runs across nearby commits).

Caching the *parse* step (`parse_file()`) is unambiguously safe: an AST is
a pure function of file content, so a content-hash-keyed cache can never
return a stale parse result.

Caching *diagnostics* per file is not safe with the current rule engine
contract. A [`Rule`](../../R/rule.R)'s `check_fn(context, params)` is
called once per scan with the *entire* project context, and most built-in
rules read cross-file state:

- `dependency.forbidden` / `dependency.circular` read the whole layer
  graph.
- `testing.missingTests` reads every file under `tests/` to build the set
  of referenced symbols, regardless of which file defines the function
  being checked.
- `ecosystem.shinyStructure` reads every file's package imports and every
  file's basename across the whole project.
- Even `package.deprecatedApi`, which only reports per-file call sites, is
  *implemented* as a single project-wide loop, not a per-file callback.

A diagnostic cache keyed only on "did this one file's content change"
would silently miss a new violation introduced by a *different* file
changing (e.g. file A's diagnostics depend on file B, B changes, A's cache
entry is still considered valid). Building a correct per-file diagnostic
cache would require the rule engine to know, per rule, whether it is
`scope: "file"` (depends only on the file being checked) or `scope:
"project"` (depends on the full context) — a real interface change to
[`Rule`](../../R/rule.R), not just a caching layer bolted on top.

## Decision

1. **0.1.x ships an AST-only cache** ([`R/cache.R`](../../R/cache.R)):
   `.rtrace_cache/ast-cache.rds`, a single RDS file mapping absolute path
   to `list(hash =, ast =)`, keyed by MD5 content hash
   (`tools::md5sum()`). On each cached scan, a file whose hash matches the
   cache entry reuses the cached `rtrace_file_ast`; otherwise it's parsed
   fresh and the cache entry is replaced. Entries for files no longer
   present in the scan are pruned, so the cache doesn't grow unboundedly
   as a project's files are renamed or removed.
2. **Diagnostics are always recomputed for the full project on every
   scan**, cached or not. This guarantees `run_scan(root, config, use_cache
   = TRUE)` and `run_scan(root, config, use_cache = FALSE)` produce
   *identical* `rtrace_diagnostic_set` results — caching is purely a
   parse-step performance optimization, never a correctness trade-off.
3. **Caching is opt-in** (`use_cache = FALSE` by default in
   [`build_context()`](../../R/context.R)/[`run_scan()`](../../R/rule_engine.R);
   `--cache` on the CLI, off by default). `RTrace::run_scan()` called from
   an arbitrary R script, or from the package's own test suite, must never
   write files to disk as a side effect unless the caller explicitly asks
   for that.
4. **A per-rule `scope` capability (file vs. project) is deferred**, not
   designed away. If/when it's built, file-scoped rules could additionally
   cache their diagnostics per file using the same hash already computed
   for the AST cache — the hash-keying mechanism in `R/cache.R` already
   generalizes to that case. Tracked in
   [dev/roadmap.md](../roadmap.md).

## Consequences

- The roadmap entry is corrected from "cache... per-file diagnostics" to
  the narrower, honestly-scoped "cache parsed ASTs" — the original wording
  overclaimed before this ADR examined the rule engine's actual contract.
- Repeated scans of a large, mostly-unchanged project skip the parse step
  (file I/O + R's `parse()`) for unchanged files, which is the dominant
  cost for projects with many small/medium files; rule evaluation itself
  is not sped up by caching, since it always runs against the full,
  current context.
- `.rtrace_cache/` was already anticipated in
  [`default_excludes()`](../../R/walker.R) and `.gitignore` from the
  0.1.0 scaffold, so no changes were needed there.
