# Incremental scanning: AST parse cache

Caches parsed `rtrace_file_ast` objects (see
[`parse_file()`](https://rtrace-dev.github.io/rtrace/reference/parse_file.md))
on disk, keyed by an MD5 content hash per file, so repeated scans of a
project (interactive iteration, or CI runs across nearby commits) skip
re-parsing files whose content hasn't changed. This caches the *parse*
step only — diagnostics are always recomputed for the full project on
every scan, because most built-in rules read cross-file state (the
dependency graph, all test files for `testing.missingTests`, etc.) and a
stale per-file diagnostic cache could silently miss a violation
introduced by a *different* file changing. See
[dev/roadmap.md](https://github.com/rtrace-dev/rtrace/blob/main/dev/roadmap.md)
for the rule-scope model a future per-rule diagnostic cache would need.

## Details

Caching is opt-in (`use_cache = TRUE` to
[`build_context()`](https://rtrace-dev.github.io/rtrace/reference/build_context.md)/[`run_scan()`](https://rtrace-dev.github.io/rtrace/reference/run_scan.md),
or `--cache` on the CLI), not a silent default, so calling RTrace from
an R script or test never writes files to disk unless asked.
