# Package index

## Scanning

Top-level entry points for running a scan

- [`run_scan()`](https://rtrace-dev.github.io/rtrace/reference/run_scan.md)
  : Run a full RTrace scan over a project directory
- [`build_context()`](https://rtrace-dev.github.io/rtrace/reference/build_context.md)
  : Build a full rule-evaluation context for a project directory
- [`run_rules()`](https://rtrace-dev.github.io/rtrace/reference/run_rules.md)
  : Run the configured rule set against a context
- [`new_context()`](https://rtrace-dev.github.io/rtrace/reference/new_context.md)
  : Build a rule evaluation context
- [`relative_path()`](https://rtrace-dev.github.io/rtrace/reference/relative_path.md)
  : Convert an absolute path to a project-relative path, for diagnostics

## Configuration

Loading, validating, and constructing rtrace.yml configuration

- [`default_config()`](https://rtrace-dev.github.io/rtrace/reference/default_config.md)
  : Build the default RTrace configuration

- [`new_config()`](https://rtrace-dev.github.io/rtrace/reference/new_config.md)
  : Construct an RTrace configuration object

- [`read_config()`](https://rtrace-dev.github.io/rtrace/reference/read_config.md)
  : Read an RTrace configuration file

- [`parse_config()`](https://rtrace-dev.github.io/rtrace/reference/parse_config.md)
  :

  Parse a raw (already YAML-decoded) configuration list into an
  `rtrace_config`, applying defaults for missing keys.

- [`validate_config()`](https://rtrace-dev.github.io/rtrace/reference/validate_config.md)
  : Validate an RTrace configuration

- [`known_rule_types()`](https://rtrace-dev.github.io/rtrace/reference/known_rule_types.md)
  : Known rule type identifiers

## Rule engine

The Rule class and the rule registry

- [`Rule`](https://rtrace-dev.github.io/rtrace/reference/Rule.md) : Rule
  base class
- [`register_rule()`](https://rtrace-dev.github.io/rtrace/reference/register_rule.md)
  : Register a rule in the global rule registry
- [`get_rule()`](https://rtrace-dev.github.io/rtrace/reference/get_rule.md)
  : Look up a registered rule by id
- [`list_rules()`](https://rtrace-dev.github.io/rtrace/reference/list_rules.md)
  : List all registered rules

## Diagnostics

The Diagnostic and DiagnosticSet model

- [`new_diagnostic()`](https://rtrace-dev.github.io/rtrace/reference/new_diagnostic.md)
  : Create a diagnostic
- [`new_diagnostic_set()`](https://rtrace-dev.github.io/rtrace/reference/new_diagnostic_set.md)
  : Construct a set of diagnostics
- [`filter_diagnostics()`](https://rtrace-dev.github.io/rtrace/reference/filter_diagnostics.md)
  : Filter a diagnostic set
- [`exit_status()`](https://rtrace-dev.github.io/rtrace/reference/exit_status.md)
  : Determine the process exit status implied by a diagnostic set
- [`summary(`*`<rtrace_diagnostic_set>`*`)`](https://rtrace-dev.github.io/rtrace/reference/summary.rtrace_diagnostic_set.md)
  : Summarize a diagnostic set by severity
- [`as.data.frame(`*`<rtrace_diagnostic_set>`*`)`](https://rtrace-dev.github.io/rtrace/reference/as.data.frame.rtrace_diagnostic_set.md)
  : Convert a diagnostic set to a data frame
- [`c(`*`<rtrace_diagnostic_set>`*`)`](https://rtrace-dev.github.io/rtrace/reference/c.rtrace_diagnostic_set.md)
  : Combine diagnostic sets

## Reporters

Rendering a diagnostic set into a report format

- [`reporter_console()`](https://rtrace-dev.github.io/rtrace/reference/reporter_console.md)
  : Render a diagnostic set as colored console output
- [`reporter_json()`](https://rtrace-dev.github.io/rtrace/reference/reporter_json.md)
  : Render a diagnostic set as JSON
- [`reporter_markdown()`](https://rtrace-dev.github.io/rtrace/reference/reporter_markdown.md)
  : Render a diagnostic set as a Markdown report
- [`reporter_sarif()`](https://rtrace-dev.github.io/rtrace/reference/reporter_sarif.md)
  : Render a diagnostic set as SARIF 2.1.0
- [`reporter_html()`](https://rtrace-dev.github.io/rtrace/reference/reporter_html.md)
  : Render a diagnostic set as a standalone HTML report
- [`reporter_csv()`](https://rtrace-dev.github.io/rtrace/reference/reporter_csv.md)
  : Render a diagnostic set as CSV
- [`reporter_xml()`](https://rtrace-dev.github.io/rtrace/reference/reporter_xml.md)
  : Render a diagnostic set as XML
- [`render_layer_graph_svg()`](https://rtrace-dev.github.io/rtrace/reference/render_layer_graph_svg.md)
  : Render a layer dependency graph as an inline SVG diagram
- [`html_escape()`](https://rtrace-dev.github.io/rtrace/reference/html_escape.md)
  : Escape text for safe embedding in HTML

## Project scanning internals

File walking, parsing, and dependency graph construction

- [`scan_files()`](https://rtrace-dev.github.io/rtrace/reference/scan_files.md)
  : Walk a project directory for R source files

- [`default_excludes()`](https://rtrace-dev.github.io/rtrace/reference/default_excludes.md)
  : Default directories/files RTrace never scans

- [`glob_to_regex()`](https://rtrace-dev.github.io/rtrace/reference/glob_to_regex.md)
  : Translate a glob pattern to a regular expression

- [`path_matches_any_glob()`](https://rtrace-dev.github.io/rtrace/reference/path_matches_any_glob.md)
  : Test whether a relative path matches any of a set of glob patterns

- [`parse_file()`](https://rtrace-dev.github.io/rtrace/reference/parse_file.md)
  : Parse an R source file

- [`ast_line_count()`](https://rtrace-dev.github.io/rtrace/reference/ast_line_count.md)
  : Number of lines in a parsed file

- [`find_calls()`](https://rtrace-dev.github.io/rtrace/reference/find_calls.md)
  : Find all calls to a given function name in a parsed file

- [`find_qualified_calls()`](https://rtrace-dev.github.io/rtrace/reference/find_qualified_calls.md)
  :

  Find all namespace-qualified calls to a given `pkg::fn` (or
  `pkg:::fn`)

- [`find_superassignments()`](https://rtrace-dev.github.io/rtrace/reference/find_superassignments.md)
  :

  Find all `<<-` (superassignment) usages in a parsed file

- [`top_level_functions()`](https://rtrace-dev.github.io/rtrace/reference/top_level_functions.md)
  : Locate top-level function definitions in a parsed file

- [`cyclomatic_complexity()`](https://rtrace-dev.github.io/rtrace/reference/cyclomatic_complexity.md)
  : Compute the cyclomatic complexity of a function body

- [`build_dependency_graph()`](https://rtrace-dev.github.io/rtrace/reference/build_dependency_graph.md)
  : Build a project dependency graph

- [`extract_package_imports()`](https://rtrace-dev.github.io/rtrace/reference/extract_package_imports.md)
  : Extract package names imported by a file

- [`extract_source_targets()`](https://rtrace-dev.github.io/rtrace/reference/extract_source_targets.md)
  :

  Extract [`source()`](https://rdrr.io/r/base/source.html) target file
  paths, resolved to absolute paths

- [`find_cycles()`](https://rtrace-dev.github.io/rtrace/reference/find_cycles.md)
  : Find cycles in a directed graph

## Incremental scanning (cache)

Opt-in AST parse cache (see ADR 0003)

- [`ast-cache`](https://rtrace-dev.github.io/rtrace/reference/ast-cache.md)
  : Incremental scanning: AST parse cache
- [`cache_path()`](https://rtrace-dev.github.io/rtrace/reference/cache_path.md)
  : Path to a project's AST cache file
- [`read_ast_cache()`](https://rtrace-dev.github.io/rtrace/reference/read_ast_cache.md)
  : Read a project's AST cache from disk
- [`write_ast_cache()`](https://rtrace-dev.github.io/rtrace/reference/write_ast_cache.md)
  : Write a project's AST cache to disk
- [`file_hash()`](https://rtrace-dev.github.io/rtrace/reference/file_hash.md)
  : Compute a file's content hash
- [`parse_files_cached()`](https://rtrace-dev.github.io/rtrace/reference/parse_files_cached.md)
  : Parse a set of files, reusing cached ASTs where the content hash
  matches

## CLI

- [`rtrace_cli()`](https://rtrace-dev.github.io/rtrace/reference/rtrace_cli.md)
  : RTrace CLI entry point
- [`parse_cli_args()`](https://rtrace-dev.github.io/rtrace/reference/parse_cli_args.md)
  : Parse RTrace CLI arguments

## RStudio

- [`rtrace_addin_scan()`](https://rtrace-dev.github.io/rtrace/reference/rtrace_addin_scan.md)
  : RStudio Addin: scan the active project and view an HTML report
