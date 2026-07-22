#' @noRd
.onLoad <- function(libname, pkgname) {

  # --- Core architecture rules (RTrace 0.1.0) ---
  register_rule(rule_structure_required_dirs())
  register_rule(rule_dependency_forbidden())
  register_rule(rule_dependency_circular())
  register_rule(rule_complexity_cyclomatic())
  register_rule(rule_complexity_function_length())
  register_rule(rule_complexity_file_length())
  register_rule(rule_antipattern_global_assign())
  register_rule(rule_antipattern_assign())
  register_rule(rule_antipattern_setwd())
  register_rule(rule_antipattern_hardcoded_path())
  register_rule(rule_documentation_missing())
  register_rule(rule_testing_missing_tests())
  register_rule(rule_package_deprecated_api())
  register_rule(rule_ecosystem_shiny_structure())
  register_rule(rule_ecosystem_targets_structure())
  register_rule(rule_ecosystem_plumber_structure())

  # --- Reproducibility rules (Trace Platform 0.2.0) ---
  register_rule(rule_reproducibility_renv_lock())
  register_rule(rule_reproducibility_random_seed())
  register_rule(rule_reproducibility_temp_files())
  register_rule(rule_reproducibility_external_download())
  register_rule(rule_reproducibility_env_vars())
  register_rule(rule_reproducibility_session_info())
  register_rule(rule_reproducibility_portable_paths())
  register_rule(rule_reproducibility_reproducible_reports())

  # --- DataTrace rules (Trace Platform 0.2.0 + 0.3.0) ---
  register_rule(rule_datatrace_read_error())
  register_rule(rule_datatrace_missing_header())
  register_rule(rule_datatrace_encoding_issue())
  register_rule(rule_datatrace_no_data_files())
  register_rule(rule_datatrace_large_csv_no_compression())
  register_rule(rule_datatrace_schema_documentation())
  register_rule(rule_datatrace_fair_findable())
  register_rule(rule_datatrace_fair_accessible())
  register_rule(rule_datatrace_fair_interoperable())
  register_rule(rule_datatrace_fair_reusable())
  register_rule(rule_datatrace_missing_values())
  register_rule(rule_datatrace_duplicate_rows())
  register_rule(rule_datatrace_json_dataset())

  # --- DocsTrace rules (Trace Platform 0.2.0) ---
  register_rule(rule_docstrace_readme())
  register_rule(rule_docstrace_readme_quality())
  register_rule(rule_docstrace_vignettes())
  register_rule(rule_docstrace_pkgdown())
  register_rule(rule_docstrace_examples_quality())
  register_rule(rule_docstrace_changelog())
  register_rule(rule_docstrace_contributing())
  register_rule(rule_docstrace_citation())

  # --- Package QA rules (Trace Platform 0.2.0) ---
  register_rule(rule_packageqa_description_complete())
  register_rule(rule_packageqa_description_title())
  register_rule(rule_packageqa_namespace_hygiene())
  register_rule(rule_packageqa_test_coverage())
  register_rule(rule_packageqa_license())
  register_rule(rule_packageqa_version_format())
  register_rule(rule_packageqa_maintainer_contact())
  register_rule(rule_packageqa_news_format())

  # --- Register built-in Trace Platform modules ---
  #
  # This is the single place built-in modules are registered. platform_scan(),
  # the CLI's `platform-scan` command, and the REST API's `/scan/full`
  # endpoint all execute exactly the modules registered here (via
  # register_module()) -- there is no separate "run every module" code path
  # anywhere else. Adding a new built-in module means adding one
  # register_module() call here; no CLI, API, or platform_scan() changes are
  # required.
  pkg_version <- tryCatch(
    as.character(utils::packageVersion("RTrace")),
    error = function(e) "0.2.0.dev"
  )
  rtrace_env$platform_version <- pkg_version

  register_module(list(
    id          = "rtrace",
    name        = "Architecture Governance (R)",
    version     = pkg_version,
    description = "Static analysis and architecture governance for R projects.",
    languages   = "R",
    scan_fn     = function(root, config) {
      ctx <- build_context(root, config %||% default_config())
      run_rules(ctx)
    },
    score_fn    = function(diags) {
      s <- compute_score(diags, error_penalty = 10, warning_penalty = 3, info_penalty = 1)
      s$module_id <- "rtrace"
      s
    }
  ))

  register_module(list(
    id          = "reproducibility",
    name        = "Reproducibility",
    version     = pkg_version,
    description = "Checks lockfiles, seeds, and reproducibility hygiene.",
    languages   = "R",
    scan_fn     = function(root, config) {
      run_reproducibility_scan(root, config %||% default_config())$diagnostics
    },
    score_fn    = function(diags) {
      s <- compute_score(diags, error_penalty = 15, warning_penalty = 5, info_penalty = 1)
      s$module_id <- "reproducibility"
      s
    }
  ))

  register_module(list(
    id          = "docstrace",
    name        = "DocsTrace",
    version     = pkg_version,
    description = "Evaluates documentation completeness and quality.",
    languages   = "R",
    scan_fn     = function(root, config) {
      run_docstrace_scan(root, config %||% default_config())$diagnostics
    },
    score_fn    = function(diags) {
      s <- compute_score(diags, error_penalty = 12, warning_penalty = 4, info_penalty = 1)
      s$module_id <- "docstrace"
      s
    }
  ))

  register_module(list(
    id          = "packageqa",
    name        = "Package QA",
    version     = pkg_version,
    description = "Evaluates R package metadata and CRAN convention compliance.",
    languages   = "R",
    scan_fn     = function(root, config) {
      run_packageqa_scan(root, config %||% default_config())$diagnostics
    },
    score_fn    = function(diags) {
      s <- compute_score(diags, error_penalty = 12, warning_penalty = 5, info_penalty = 1)
      s$module_id <- "packageqa"
      s
    }
  ))

  register_module(list(
    id          = "datatrace",
    name        = "DataTrace",
    version     = pkg_version,
    description = "Evaluates quality and FAIR-compliance of research data files.",
    languages   = "data",
    scan_fn     = function(root, config) {
      run_datatrace_scan(root, config %||% default_config())$diagnostics
    },
    score_fn    = function(diags) {
      s <- compute_score(diags, error_penalty = 8, warning_penalty = 3, info_penalty = 1)
      s$module_id <- "datatrace"
      s
    }
  ))

  invisible()
}
