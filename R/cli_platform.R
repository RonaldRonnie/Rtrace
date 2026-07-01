#' Trace Platform CLI commands
#'
#' Extends the existing RTrace CLI with platform-level commands that run
#' module-specific scans, generate platform dashboards, and expose the REST
#' API. All new commands follow the same `cmd_*` pattern as the existing
#' commands in `R/cli_commands.R` and are wired into [rtrace_cli()] in
#' `R/zzz.R`.

# ---------------------------------------------------------------------------
# cmd_platform_scan
# ---------------------------------------------------------------------------

#' `rtrace platform-scan [path]` command
#'
#' Runs all registered platform modules and renders a full dashboard report.
#'
#' @param options,positional See [parse_cli_args()].
#' @return Integer exit status.
#' @keywords internal
#' @noRd
cmd_platform_scan <- function(options, positional) {
  root   <- if (length(positional) > 0) positional[1] else "."
  config <- resolve_config(root, options)
  format <- options$format %||% "dashboard"

  cat(sprintf("Running Trace Platform scan on: %s\n", root))

  context <- tryCatch(
    build_context(root, config, use_cache = isTRUE(options$cache)),
    error = function(e) {
      cat(sprintf("Error building context: %s\n", conditionMessage(e)))
      return(NULL)
    }
  )
  if (is.null(context)) return(1L)

  diags <- run_rules(context)

  # Run optional module scans
  repro_result  <- tryCatch(run_reproducibility_scan(root, config), error = function(e) NULL)
  docs_result   <- tryCatch(run_docstrace_scan(root), error = function(e) NULL)
  pkgqa_result  <- tryCatch(run_packageqa_scan(root), error = function(e) NULL)
  data_result   <- tryCatch(run_datatrace_scan(root), error = function(e) NULL)

  all_diags <- diags
  scores    <- list()

  arch_score       <- compute_score(diags); arch_score$module_id <- "rtrace"
  scores[["rtrace"]] <- arch_score

  if (!is.null(repro_result)) {
    all_diags             <- c(all_diags, repro_result$diagnostics)
    scores[["reproducibility"]] <- repro_result$score
  }
  if (!is.null(docs_result)) {
    all_diags            <- c(all_diags, docs_result$diagnostics)
    scores[["docstrace"]] <- docs_result$score
  }
  if (!is.null(pkgqa_result)) {
    all_diags             <- c(all_diags, pkgqa_result$diagnostics)
    scores[["packageqa"]] <- pkgqa_result$score
  }
  if (!is.null(data_result)) {
    all_diags             <- c(all_diags, data_result$diagnostics)
    scores[["datatrace"]] <- data_result$score
  }

  platform_result <- list(
    root            = normalizePath(root, mustWork = TRUE),
    modules         = names(scores),
    results         = list(),
    scores          = scores,
    all_diagnostics = all_diags,
    timestamp       = Sys.time()
  )
  class(platform_result) <- "trace_platform_result"

  if (format == "dashboard") {
    layers <- setdiff(unique(context$files$layer), "(unassigned)")
    html   <- reporter_dashboard(
      platform_result = platform_result,
      layers          = layers,
      layer_graph     = context$dependency_graph$layer_graph,
      title           = sprintf("Trace Platform: %s", basename(root))
    )
    if (!is.null(options$output)) {
      writeLines(html, options$output)
      cat(sprintf("Dashboard written to: %s\n", options$output))
    } else {
      tmp <- tempfile("trace-dashboard-", fileext = ".html")
      writeLines(html, tmp)
      cat(sprintf("Dashboard written to: %s\n", tmp))
      if (requireNamespace("rstudioapi", quietly = TRUE) && isTRUE(rstudioapi::isAvailable())) {
        rstudioapi::viewer(tmp)
      } else {
        utils::browseURL(tmp)
      }
    }
  } else if (format == "json") {
    payload <- list(
      timestamp       = format(platform_result$timestamp, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      root            = platform_result$root,
      modules         = platform_result$modules,
      scores          = lapply(scores, function(s) list(score = s$score, label = s$label)),
      total_violations = length(all_diags),
      summary         = as.list(summary(all_diags))
    )
    cat(jsonlite::toJSON(payload, auto_unbox = TRUE, pretty = TRUE), "\n")
  } else {
    print(platform_result)
  }

  exit_status(all_diags, fail_on = options$`fail-on` %||% "error")
}

# ---------------------------------------------------------------------------
# cmd_datatrace
# ---------------------------------------------------------------------------

#' `rtrace datatrace [path]` command
#' @param options,positional See [parse_cli_args()].
#' @return Integer exit status.
#' @keywords internal
#' @noRd
cmd_datatrace <- function(options, positional) {
  root   <- if (length(positional) > 0) positional[1] else "."
  result <- run_datatrace_scan(root)

  cat(sprintf("DataTrace scan: %s\n", root))
  cat(sprintf("Data files found: %d\n", nrow(result$data_files)))
  print(result$score)

  if (length(result$diagnostics) > 0) {
    cat("\nFindings:\n")
    reporter_console(result$diagnostics)
  } else {
    cat("No data quality issues found.\n")
  }

  exit_status(result$diagnostics, fail_on = options$`fail-on` %||% "error")
}

# ---------------------------------------------------------------------------
# cmd_docstrace
# ---------------------------------------------------------------------------

#' `rtrace docstrace [path]` command
#' @param options,positional See [parse_cli_args()].
#' @return Integer exit status.
#' @keywords internal
#' @noRd
cmd_docstrace <- function(options, positional) {
  root   <- if (length(positional) > 0) positional[1] else "."
  result <- run_docstrace_scan(root)

  cat(sprintf("DocsTrace scan: %s\n", root))
  print(result$score)

  if (length(result$diagnostics) > 0) {
    cat("\nFindings:\n")
    reporter_console(result$diagnostics)
  } else {
    cat("No documentation issues found.\n")
  }

  exit_status(result$diagnostics, fail_on = options$`fail-on` %||% "error")
}

# ---------------------------------------------------------------------------
# cmd_pkgqa
# ---------------------------------------------------------------------------

#' `rtrace pkgqa [path]` command
#' @param options,positional See [parse_cli_args()].
#' @return Integer exit status.
#' @keywords internal
#' @noRd
cmd_pkgqa <- function(options, positional) {
  root   <- if (length(positional) > 0) positional[1] else "."
  result <- run_packageqa_scan(root)

  if (!result$is_package) {
    cat(sprintf("pkgqa: '%s' is not an R package (no DESCRIPTION file).\n", root))
    return(0L)
  }

  cat(sprintf("Package QA scan: %s\n", root))
  print(result$score)

  if (length(result$diagnostics) > 0) {
    cat("\nFindings:\n")
    reporter_console(result$diagnostics)
  } else {
    cat("No package QA issues found.\n")
  }

  exit_status(result$diagnostics, fail_on = options$`fail-on` %||% "error")
}

# ---------------------------------------------------------------------------
# cmd_health (platform health summary)
# ---------------------------------------------------------------------------

#' `rtrace health [path]` command
#' @param options,positional See [parse_cli_args()].
#' @return Integer exit status.
#' @keywords internal
#' @noRd
cmd_health <- function(options, positional) {
  root <- if (length(positional) > 0) positional[1] else "."

  cat(sprintf("%s v%s\n", platform_name(), platform_version()))
  cat(sprintf("Project: %s\n\n", root))

  cat("Registered modules:\n")
  mods <- list_modules()
  if (length(mods) == 0) {
    cat("  (none -- run discover_plugins() to load installed plugins)\n")
  } else {
    for (m in mods) {
      cat(sprintf("  %-24s v%-10s %s\n", m$name, m$version, m$description))
    }
  }

  cat(sprintf("\nRegistered rules: %d\n", length(list_rules())))
  cat(sprintf("Active recommendation provider: %s\n", get_active_provider()))

  plugins <- list_plugin_packages()
  if (length(plugins) > 0) {
    cat(sprintf("Installed plugins: %s\n", paste(plugins, collapse = ", ")))
  }

  0L
}

# ---------------------------------------------------------------------------
# cmd_api (start the REST API)
# ---------------------------------------------------------------------------

#' `rtrace api` command
#' @param options,positional See [parse_cli_args()].
#' @return Integer exit status.
#' @keywords internal
#' @noRd
cmd_api <- function(options, positional) {
  host <- options$host %||% "127.0.0.1"
  port <- as.integer(options$port %||% 8394L)

  tryCatch({
    start_api(host = host, port = port)
    0L
  }, error = function(e) {
    cat(sprintf("Error starting API: %s\n", conditionMessage(e)))
    1L
  })
}

# ---------------------------------------------------------------------------
# cmd_reproducibility
# ---------------------------------------------------------------------------

#' `rtrace reproducibility [path]` command
#' @param options,positional See [parse_cli_args()].
#' @return Integer exit status.
#' @keywords internal
#' @noRd
cmd_reproducibility <- function(options, positional) {
  root   <- if (length(positional) > 0) positional[1] else "."
  config <- resolve_config(root, options)
  result <- run_reproducibility_scan(root, config)

  cat(sprintf("Reproducibility scan: %s\n", root))
  print(result$score)

  if (length(result$diagnostics) > 0) {
    cat("\nFindings:\n")
    reporter_console(result$diagnostics)
  } else {
    cat("No reproducibility issues found.\n")
  }

  exit_status(result$diagnostics, fail_on = options$`fail-on` %||% "error")
}
