# Package index

## Scanning

Top-level entry points for running a scan

- [`run_scan()`](https://ronaldronnie.github.io/Rtrace/reference/run_scan.md)
  : Run a full RTrace scan over a project directory
- [`build_context()`](https://ronaldronnie.github.io/Rtrace/reference/build_context.md)
  : Build a full rule-evaluation context for a project directory
- [`run_rules()`](https://ronaldronnie.github.io/Rtrace/reference/run_rules.md)
  : Run the configured rule set against a context
- [`new_context()`](https://ronaldronnie.github.io/Rtrace/reference/new_context.md)
  : Build a rule evaluation context
- [`relative_path()`](https://ronaldronnie.github.io/Rtrace/reference/relative_path.md)
  : Convert an absolute path to a project-relative path, for diagnostics

## Configuration

Loading, validating, and constructing rtrace.yml configuration

- [`default_config()`](https://ronaldronnie.github.io/Rtrace/reference/default_config.md)
  : Build the default RTrace configuration

- [`new_config()`](https://ronaldronnie.github.io/Rtrace/reference/new_config.md)
  : Construct an RTrace configuration object

- [`read_config()`](https://ronaldronnie.github.io/Rtrace/reference/read_config.md)
  : Read an RTrace configuration file

- [`parse_config()`](https://ronaldronnie.github.io/Rtrace/reference/parse_config.md)
  :

  Parse a raw (already YAML-decoded) configuration list into an
  `rtrace_config`, applying defaults for missing keys.

- [`validate_config()`](https://ronaldronnie.github.io/Rtrace/reference/validate_config.md)
  : Validate an RTrace configuration

- [`known_rule_types()`](https://ronaldronnie.github.io/Rtrace/reference/known_rule_types.md)
  : Known rule type identifiers

## Rule engine

The Rule class and the rule registry

- [`Rule`](https://ronaldronnie.github.io/Rtrace/reference/Rule.md) :
  Rule base class
- [`register_rule()`](https://ronaldronnie.github.io/Rtrace/reference/register_rule.md)
  : Register a rule in the global rule registry
- [`get_rule()`](https://ronaldronnie.github.io/Rtrace/reference/get_rule.md)
  : Look up a registered rule by id
- [`list_rules()`](https://ronaldronnie.github.io/Rtrace/reference/list_rules.md)
  : List all registered rules

## Diagnostics

The Diagnostic and DiagnosticSet model

- [`new_diagnostic()`](https://ronaldronnie.github.io/Rtrace/reference/new_diagnostic.md)
  : Create a diagnostic
- [`new_diagnostic_set()`](https://ronaldronnie.github.io/Rtrace/reference/new_diagnostic_set.md)
  : Construct a set of diagnostics
- [`filter_diagnostics()`](https://ronaldronnie.github.io/Rtrace/reference/filter_diagnostics.md)
  : Filter a diagnostic set
- [`exit_status()`](https://ronaldronnie.github.io/Rtrace/reference/exit_status.md)
  : Determine the process exit status implied by a diagnostic set
- [`summary(`*`<rtrace_diagnostic_set>`*`)`](https://ronaldronnie.github.io/Rtrace/reference/summary.rtrace_diagnostic_set.md)
  : Summarize a diagnostic set by severity
- [`as.data.frame(`*`<rtrace_diagnostic_set>`*`)`](https://ronaldronnie.github.io/Rtrace/reference/as.data.frame.rtrace_diagnostic_set.md)
  : Convert a diagnostic set to a data frame
- [`c(`*`<rtrace_diagnostic_set>`*`)`](https://ronaldronnie.github.io/Rtrace/reference/c.rtrace_diagnostic_set.md)
  : Combine diagnostic sets

## Reporters

Rendering a diagnostic set into a report format

- [`reporter_console()`](https://ronaldronnie.github.io/Rtrace/reference/reporter_console.md)
  : Render a diagnostic set as colored console output
- [`reporter_json()`](https://ronaldronnie.github.io/Rtrace/reference/reporter_json.md)
  : Render a diagnostic set as JSON
- [`reporter_markdown()`](https://ronaldronnie.github.io/Rtrace/reference/reporter_markdown.md)
  : Render a diagnostic set as a Markdown report
- [`reporter_sarif()`](https://ronaldronnie.github.io/Rtrace/reference/reporter_sarif.md)
  : Render a diagnostic set as SARIF 2.1.0
- [`reporter_html()`](https://ronaldronnie.github.io/Rtrace/reference/reporter_html.md)
  : Render a diagnostic set as a standalone HTML report
- [`reporter_csv()`](https://ronaldronnie.github.io/Rtrace/reference/reporter_csv.md)
  : Render a diagnostic set as CSV
- [`reporter_xml()`](https://ronaldronnie.github.io/Rtrace/reference/reporter_xml.md)
  : Render a diagnostic set as XML
- [`render_layer_graph_svg()`](https://ronaldronnie.github.io/Rtrace/reference/render_layer_graph_svg.md)
  : Render a layer dependency graph as an inline SVG diagram
- [`html_escape()`](https://ronaldronnie.github.io/Rtrace/reference/html_escape.md)
  : Escape text for safe embedding in HTML

## Project scanning internals

File walking, parsing, and dependency graph construction

- [`scan_files()`](https://ronaldronnie.github.io/Rtrace/reference/scan_files.md)
  : Walk a project directory for R source files

- [`default_excludes()`](https://ronaldronnie.github.io/Rtrace/reference/default_excludes.md)
  : Default directories/files RTrace never scans

- [`glob_to_regex()`](https://ronaldronnie.github.io/Rtrace/reference/glob_to_regex.md)
  : Translate a glob pattern to a regular expression

- [`path_matches_any_glob()`](https://ronaldronnie.github.io/Rtrace/reference/path_matches_any_glob.md)
  : Test whether a relative path matches any of a set of glob patterns

- [`parse_file()`](https://ronaldronnie.github.io/Rtrace/reference/parse_file.md)
  : Parse an R source file

- [`ast_line_count()`](https://ronaldronnie.github.io/Rtrace/reference/ast_line_count.md)
  : Number of lines in a parsed file

- [`find_calls()`](https://ronaldronnie.github.io/Rtrace/reference/find_calls.md)
  : Find all calls to a given function name in a parsed file

- [`find_qualified_calls()`](https://ronaldronnie.github.io/Rtrace/reference/find_qualified_calls.md)
  :

  Find all namespace-qualified calls to a given `pkg::fn` (or
  `pkg:::fn`)

- [`find_superassignments()`](https://ronaldronnie.github.io/Rtrace/reference/find_superassignments.md)
  :

  Find all `<<-` (superassignment) usages in a parsed file

- [`top_level_functions()`](https://ronaldronnie.github.io/Rtrace/reference/top_level_functions.md)
  : Locate top-level function definitions in a parsed file

- [`cyclomatic_complexity()`](https://ronaldronnie.github.io/Rtrace/reference/cyclomatic_complexity.md)
  : Compute the cyclomatic complexity of a function body

- [`build_dependency_graph()`](https://ronaldronnie.github.io/Rtrace/reference/build_dependency_graph.md)
  : Build a project dependency graph

- [`extract_package_imports()`](https://ronaldronnie.github.io/Rtrace/reference/extract_package_imports.md)
  : Extract package names imported by a file

- [`extract_source_targets()`](https://ronaldronnie.github.io/Rtrace/reference/extract_source_targets.md)
  :

  Extract [`source()`](https://rdrr.io/r/base/source.html) target file
  paths, resolved to absolute paths

- [`find_cycles()`](https://ronaldronnie.github.io/Rtrace/reference/find_cycles.md)
  : Find cycles in a directed graph

## Incremental scanning (cache)

Opt-in AST parse cache (see ADR 0003)

- [`ast-cache`](https://ronaldronnie.github.io/Rtrace/reference/ast-cache.md)
  : Incremental scanning: AST parse cache
- [`cache_path()`](https://ronaldronnie.github.io/Rtrace/reference/cache_path.md)
  : Path to a project's AST cache file
- [`read_ast_cache()`](https://ronaldronnie.github.io/Rtrace/reference/read_ast_cache.md)
  : Read a project's AST cache from disk
- [`write_ast_cache()`](https://ronaldronnie.github.io/Rtrace/reference/write_ast_cache.md)
  : Write a project's AST cache to disk
- [`file_hash()`](https://ronaldronnie.github.io/Rtrace/reference/file_hash.md)
  : Compute a file's content hash
- [`parse_files_cached()`](https://ronaldronnie.github.io/Rtrace/reference/parse_files_cached.md)
  : Parse a set of files, reusing cached ASTs where the content hash
  matches

## CLI

- [`rtrace_cli()`](https://ronaldronnie.github.io/Rtrace/reference/rtrace_cli.md)
  : RTrace CLI entry point
- [`parse_cli_args()`](https://ronaldronnie.github.io/Rtrace/reference/parse_cli_args.md)
  : Parse RTrace CLI arguments

## RStudio

- [`rtrace_addin_scan()`](https://ronaldronnie.github.io/Rtrace/reference/rtrace_addin_scan.md)
  : RStudio Addin: scan the active project and view an HTML report

## Reporters (dashboard)

HTML dashboard reporter added in V2

- [`reporter-dashboard`](https://ronaldronnie.github.io/Rtrace/reference/reporter-dashboard.md)
  : Trace Platform Dashboard Reporter
- [`reporter_dashboard()`](https://ronaldronnie.github.io/Rtrace/reference/reporter_dashboard.md)
  : Render the Trace Platform dashboard as a standalone HTML document

## Scoring

Score computation and aggregation utilities

- [`scoring`](https://ronaldronnie.github.io/Rtrace/reference/scoring.md)
  : Trace Platform unified scoring system
- [`new_trace_score()`](https://ronaldronnie.github.io/Rtrace/reference/new_trace_score.md)
  : Construct a trace_score object
- [`compute_score()`](https://ronaldronnie.github.io/Rtrace/reference/compute_score.md)
  : Compute a 0-100 quality score from a diagnostic set
- [`aggregate_scores()`](https://ronaldronnie.github.io/Rtrace/reference/aggregate_scores.md)
  : Aggregate multiple trace_score objects into a single platform score
- [`score_colour()`](https://ronaldronnie.github.io/Rtrace/reference/score_colour.md)
  : Score colour for HTML/dashboard rendering
- [`score_label()`](https://ronaldronnie.github.io/Rtrace/reference/score_label.md)
  : Convert a numeric score to a human-readable label
- [`scores_as_data_frame()`](https://ronaldronnie.github.io/Rtrace/reference/scores_as_data_frame.md)
  : Flatten a named list of trace_scores into a data frame

## Domain engine — DataTrace

Rules and engine for data-file quality and FAIR-compliance checks

- [`datatrace-engine`](https://ronaldronnie.github.io/Rtrace/reference/datatrace-engine.md)
  : DataTrace Engine
- [`datatrace-rules`](https://ronaldronnie.github.io/Rtrace/reference/datatrace-rules.md)
  : DataTrace rules
- [`run_datatrace_scan()`](https://ronaldronnie.github.io/Rtrace/reference/run_datatrace_scan.md)
  : Run the DataTrace engine against a project
- [`scan_data_files()`](https://ronaldronnie.github.io/Rtrace/reference/scan_data_files.md)
  : Scan data files in a project root

## Domain engine — DocsTrace

Rules and engine for documentation completeness checks

- [`docstrace-engine`](https://ronaldronnie.github.io/Rtrace/reference/docstrace-engine.md)
  : DocsTrace Engine
- [`docstrace-rules`](https://ronaldronnie.github.io/Rtrace/reference/docstrace-rules.md)
  : DocsTrace rules
- [`run_docstrace_scan()`](https://ronaldronnie.github.io/Rtrace/reference/run_docstrace_scan.md)
  : Run the DocsTrace engine against a project

## Domain engine — PackageQA

Rules and engine for R package metadata and convention checks

- [`packageqa-engine`](https://ronaldronnie.github.io/Rtrace/reference/packageqa-engine.md)
  : Package QA Engine
- [`packageqa-rules`](https://ronaldronnie.github.io/Rtrace/reference/packageqa-rules.md)
  : Package QA rules
- [`run_packageqa_scan()`](https://ronaldronnie.github.io/Rtrace/reference/run_packageqa_scan.md)
  : Run the Package QA engine against a project

## Domain engine — Reproducibility

Rules and engine for reproducibility anti-pattern detection

- [`reproducibility-engine`](https://ronaldronnie.github.io/Rtrace/reference/reproducibility-engine.md)
  : Reproducibility Engine
- [`reproducibility-rules`](https://ronaldronnie.github.io/Rtrace/reference/reproducibility-rules.md)
  : Reproducibility rules
- [`run_reproducibility_scan()`](https://ronaldronnie.github.io/Rtrace/reference/run_reproducibility_scan.md)
  : Run the reproducibility engine against a project
- [`build_reproducibility_context()`](https://ronaldronnie.github.io/Rtrace/reference/build_reproducibility_context.md)
  : Build the reproducibility context

## Recommendation engine

Provider-based recommendation layer built on scan diagnostics

- [`recommendation-engine`](https://ronaldronnie.github.io/Rtrace/reference/recommendation-engine.md)
  : AI Recommendation Engine
- [`new_recommendation()`](https://ronaldronnie.github.io/Rtrace/reference/new_recommendation.md)
  : Construct a trace_recommendation
- [`get_recommendation()`](https://ronaldronnie.github.io/Rtrace/reference/get_recommendation.md)
  : Get a recommendation for a diagnostic
- [`get_recommendations()`](https://ronaldronnie.github.io/Rtrace/reference/get_recommendations.md)
  : Get recommendations for all diagnostics in a set
- [`get_active_provider()`](https://ronaldronnie.github.io/Rtrace/reference/get_active_provider.md)
  : Return the active recommendation provider id
- [`set_recommendation_provider()`](https://ronaldronnie.github.io/Rtrace/reference/set_recommendation_provider.md)
  : Set the active recommendation provider
- [`register_recommendation_provider()`](https://ronaldronnie.github.io/Rtrace/reference/register_recommendation_provider.md)
  : Register a recommendation provider

## Plugin discovery

Runtime discovery of third-party RTrace plugin packages

- [`plugin-discovery`](https://ronaldronnie.github.io/Rtrace/reference/plugin-discovery.md)
  : Plugin Discovery System
- [`discover_plugins()`](https://ronaldronnie.github.io/Rtrace/reference/discover_plugins.md)
  : Discover and load installed RTrace plugin packages
- [`is_rtrace_plugin()`](https://ronaldronnie.github.io/Rtrace/reference/is_rtrace_plugin.md)
  : Check whether a package is an RTrace plugin
- [`list_plugin_packages()`](https://ronaldronnie.github.io/Rtrace/reference/list_plugin_packages.md)
  : List all installed RTrace plugin packages
- [`plugin_description_snippet()`](https://ronaldronnie.github.io/Rtrace/reference/plugin_description_snippet.md)
  : Generate a DESCRIPTION snippet for a plugin package

## Trace Platform

Multi-engine platform orchestration and module registry

- [`trace-platform`](https://ronaldronnie.github.io/Rtrace/reference/trace-platform.md)
  : Trace Platform — metadata, module registry, and environment
- [`platform_name()`](https://ronaldronnie.github.io/Rtrace/reference/platform_name.md)
  : Return the Trace Platform name
- [`platform_version()`](https://ronaldronnie.github.io/Rtrace/reference/platform_version.md)
  : Return the Trace Platform version string
- [`platform_scan()`](https://ronaldronnie.github.io/Rtrace/reference/platform_scan.md)
  : Run a full Trace Platform scan across all registered modules
- [`list_modules()`](https://ronaldronnie.github.io/Rtrace/reference/list_modules.md)
  : List registered Trace Platform modules
- [`register_module()`](https://ronaldronnie.github.io/Rtrace/reference/register_module.md)
  : Register a Trace Platform module
- [`get_module()`](https://ronaldronnie.github.io/Rtrace/reference/get_module.md)
  : Get a registered module by id

## REST API

Plumber-based HTTP API for running scans programmatically

- [`api`](https://ronaldronnie.github.io/Rtrace/reference/api.md) :
  Trace Platform REST API

- [`api_curl_examples()`](https://ronaldronnie.github.io/Rtrace/reference/api_curl_examples.md)
  :

  Generate a `curl` example for the Trace Platform API

- [`build_api_router()`](https://ronaldronnie.github.io/Rtrace/reference/build_api_router.md)
  : Build the plumber router without starting it

- [`start_api()`](https://ronaldronnie.github.io/Rtrace/reference/start_api.md)
  : Start the Trace Platform REST API server
