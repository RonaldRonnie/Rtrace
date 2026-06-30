#' Resolve the configuration for a CLI invocation
#'
#' Looks for `--config <path>`, else `rtrace.yml` in `root`, else falls
#' back to [default_config()].
#' @param root Character scalar project root.
#' @param options CLI options list (see [parse_cli_args()]).
#' @return An `rtrace_config` object.
#' @keywords internal
#' @noRd
resolve_config <- function(root, options) {
  if (!is.null(options$config)) {
    return(read_config(options$config))
  }
  default_path <- file.path(root, "rtrace.yml")
  if (file.exists(default_path)) {
    return(read_config(default_path))
  }
  default_config()
}

#' `rtrace scan` command
#' @param options,positional See [parse_cli_args()].
#' @return Integer exit status.
#' @keywords internal
#' @noRd
cmd_scan <- function(options, positional) {
  root <- if (length(positional) > 0) positional[1] else "."
  config <- resolve_config(root, options)
  context <- build_context(root, config, use_cache = isTRUE(options$cache))
  diagnostics <- run_rules(context)

  format <- options$format %||% "console"
  rendered <- switch(format,
    console = NULL,
    json = reporter_json(diagnostics),
    markdown = reporter_markdown(diagnostics),
    sarif = reporter_sarif(diagnostics),
    html = reporter_html(
      diagnostics,
      layers = setdiff(unique(context$files$layer), "(unassigned)"),
      layer_graph = context$dependency_graph$layer_graph
    ),
    csv = reporter_csv(diagnostics),
    xml = reporter_xml(diagnostics),
    rlang::abort(sprintf(
      "Unknown --format '%s'. Supported: console, json, markdown, sarif, html, csv, xml.", format
    ))
  )

  if (format == "console") {
    reporter_console(diagnostics)
  } else if (!is.null(options$output)) {
    writeLines(rendered, options$output)
    cat(sprintf("Report written to %s\n", options$output))
  } else {
    cat(rendered, "\n", sep = "")
  }

  fail_on <- options$`fail-on` %||% "error"
  exit_status(diagnostics, fail_on = fail_on)
}

#' `rtrace init` command
#' @param options,positional See [parse_cli_args()].
#' @return Integer exit status.
#' @keywords internal
#' @noRd
cmd_init <- function(options, positional) {
  root <- if (length(positional) > 0) positional[1] else "."
  target <- file.path(root, "rtrace.yml")

  if (file.exists(target) && !isTRUE(options$force)) {
    cat(sprintf("%s already exists. Use --force to overwrite.\n", target))
    return(1L)
  }

  template <- system.file("templates", "rtrace.yml", package = "RTrace")
  if (!nzchar(template)) {
    rlang::abort("Could not locate the bundled rtrace.yml template.")
  }
  file.copy(template, target, overwrite = TRUE)
  cat(sprintf("Created %s\n", target))
  0L
}

#' `rtrace validate` command
#' @param options,positional See [parse_cli_args()].
#' @return Integer exit status.
#' @keywords internal
#' @noRd
cmd_validate <- function(options, positional) {
  root <- if (length(positional) > 0) positional[1] else "."
  result <- tryCatch({
    config <- resolve_config(root, options)
    validate_config(config)
    config
  }, error = function(e) e)

  if (inherits(result, "error")) {
    cat("Configuration is INVALID:\n")
    cat(paste(" -", conditionMessage(result)), sep = "\n")
    return(1L)
  }

  cat("Configuration is valid.\n")
  print(result)
  0L
}

#' `rtrace list-rules` command
#' @param options,positional See [parse_cli_args()].
#' @return Integer exit status.
#' @keywords internal
#' @noRd
cmd_list_rules <- function(options, positional) {
  rules <- list_rules()
  if (length(rules) == 0) {
    cat("No rules registered.\n")
    return(0L)
  }
  ids <- names(rules)[order(names(rules))]
  for (id in ids) {
    r <- rules[[id]]
    cat(sprintf("%-32s [%-7s] %s\n", r$id, r$default_severity, r$description))
  }
  0L
}

#' `rtrace describe-rule <id>` command
#' @param options,positional See [parse_cli_args()].
#' @return Integer exit status.
#' @keywords internal
#' @noRd
cmd_describe_rule <- function(options, positional) {
  if (length(positional) == 0) {
    cat("Usage: rtrace describe-rule <rule-id>\n")
    return(1L)
  }
  rule <- get_rule(positional[1])
  if (is.null(rule)) {
    cat(sprintf("Unknown rule: %s\n", positional[1]))
    return(1L)
  }
  cat(sprintf("id:               %s\n", rule$id))
  cat(sprintf("description:      %s\n", rule$description))
  cat(sprintf("default_severity: %s\n", rule$default_severity))
  cat("default_params:\n")
  if (length(rule$default_params) == 0) {
    cat("  (none)\n")
  } else {
    for (n in names(rule$default_params)) {
      cat(sprintf("  %s: %s\n", n, paste(rule$default_params[[n]], collapse = ", ")))
    }
  }
  0L
}

#' `rtrace config` command
#' @param options,positional See [parse_cli_args()].
#' @return Integer exit status.
#' @keywords internal
#' @noRd
cmd_config <- function(options, positional) {
  root <- if (length(positional) > 0) positional[1] else "."
  config <- resolve_config(root, options)
  print(config)
  for (spec in config$rules) {
    cat(sprintf(
      "  - %-32s enabled=%-5s severity=%s\n",
      spec$type, spec$enabled, if (is.na(spec$severity)) "(default)" else spec$severity
    ))
  }
  0L
}

#' `rtrace doctor` command
#'
#' Environment and project setup diagnostics: R version, suggested-package
#' availability, `rtrace.yml` presence/validity, RStudio Project detection,
#' and AST cache state. Does not run a scan.
#'
#' @param options,positional See [parse_cli_args()].
#' @return Integer exit status (`1` if any `[FAIL]` line was printed).
#' @keywords internal
#' @noRd
cmd_doctor <- function(options, positional) {
  root <- if (length(positional) > 0) positional[1] else "."
  problems <- 0L

  report <- function(level, msg) {
    cat(sprintf("  [%s] %s\n", level, msg))
  }

  cat("RTrace doctor\n\n")
  cat("Environment:\n")
  cat(sprintf("  R version:      %s\n", R.version.string))
  rtrace_version <- tryCatch(as.character(utils::packageVersion("RTrace")), error = function(e) NA_character_)
  cat(sprintf("  RTrace version: %s\n", if (is.na(rtrace_version)) "(running from source, not installed)" else rtrace_version))

  if (getRversion() >= "4.1.0") {
    report("OK", sprintf("R %s meets the minimum supported version (>= 4.1.0).", getRversion()))
  } else {
    report("FAIL", sprintf("R %s is older than the minimum supported version (>= 4.1.0).", getRversion()))
    problems <- problems + 1L
  }

  if (requireNamespace("xml2", quietly = TRUE)) {
    report("OK", "Suggested package 'xml2' is installed (enables --format xml).")
  } else {
    report("WARN", "Suggested package 'xml2' is not installed; --format xml will error until it is.")
  }

  cat("\n")
  cat(sprintf("Project: %s\n", root))

  if (!dir.exists(root)) {
    report("FAIL", "Project directory does not exist.")
    cat("\n1 problem(s) found.\n")
    return(1L)
  }

  config_path <- file.path(root, "rtrace.yml")
  if (file.exists(config_path)) {
    result <- tryCatch({
      validate_config(read_config(config_path))
      NULL
    }, error = function(e) e)

    if (is.null(result)) {
      report("OK", sprintf("%s is present and valid.", config_path))
    } else {
      report("FAIL", sprintf("%s is present but invalid: %s", config_path, conditionMessage(result)))
      problems <- problems + 1L
    }
  } else {
    report("WARN", sprintf(
      "No rtrace.yml found at %s; `rtrace scan` will use built-in defaults. Run `rtrace init` to create one.",
      root
    ))
  }

  rproj_files <- list.files(root, pattern = "\\.Rproj$")
  if (length(rproj_files) > 0) {
    report("OK", sprintf("RStudio Project detected (%s).", paste(rproj_files, collapse = ", ")))
  } else {
    report("INFO", "No .Rproj file found (not an RStudio Project; fine for non-RStudio workflows).")
  }

  if (file.exists(cache_path(root))) {
    cache <- read_ast_cache(root)
    report("OK", sprintf(".rtrace_cache/ast-cache.rds present (%d cached file(s)).", length(cache)))
  } else {
    report("INFO", "No AST cache present (use `rtrace scan --cache` to enable incremental scanning).")
  }

  cat("\n")
  if (problems == 0) {
    cat("No problems found.\n")
  } else {
    cat(sprintf("%d problem(s) found.\n", problems))
  }

  if (problems > 0) 1L else 0L
}

#' `rtrace version` command
#' @param options,positional See [parse_cli_args()].
#' @return Integer exit status.
#' @keywords internal
#' @noRd
cmd_version <- function(options, positional) {
  version <- tryCatch(as.character(utils::packageVersion("RTrace")), error = function(e) "0.0.0.dev (not installed)")
  cat(sprintf("RTrace %s\n", version))
  cat(sprintf("R %s\n", R.version.string))
  0L
}

#' `rtrace help` command
#' @param options,positional See [parse_cli_args()].
#' @return Integer exit status.
#' @keywords internal
#' @noRd
cmd_help <- function(options, positional) {
  cat(rtrace_help_text())
  0L
}

#' RTrace CLI usage text
#' @return Character scalar.
#' @keywords internal
#' @noRd
rtrace_help_text <- function() {
  paste(
    "RTrace - Architecture governance and static analysis for R projects",
    "",
    "USAGE:",
    "  rtrace <command> [path] [--flag value ...]",
    "",
    "COMMANDS:",
    "  scan [path]            Scan a project and report diagnostics",
    "                            --format console|json|markdown|sarif|html|csv|xml (default: console)",
    "                            --output <file>    write the report to a file",
    "                            --config <file>     use a specific config file",
    "                            --fail-on error|warning   exit-status threshold (default: error)",
    "                            --cache             reuse a .rtrace_cache/ AST cache from a prior run",
    "  init [path]            Create a starter rtrace.yml (--force to overwrite)",
    "  validate [path]        Validate a project's configuration without scanning",
    "  list-rules              List all registered rules",
    "  describe-rule <id>      Show details for a single rule",
    "  config [path]           Print the resolved configuration",
    "  doctor [path]           Check environment and project setup (no scan)",
    "  version                  Print the RTrace and R version",
    "  help                     Show this message",
    "",
    sep = "\n"
  )
}

#' RTrace CLI entry point
#'
#' Dispatches a parsed command line to the matching `cmd_*` function. Used
#' by the `inst/rtrace` executable; callable directly for testing.
#'
#' @param argv Character vector of command-line arguments (as from
#'   `commandArgs(trailingOnly = TRUE)`).
#' @return Integer exit status (0 = success, 1 = failure).
#' @export
rtrace_cli <- function(argv = commandArgs(trailingOnly = TRUE)) {
  parsed <- parse_cli_args(argv)

  if (is.na(parsed$command) || parsed$command %in% c("help", "-h", "--help")) {
    return(cmd_help(parsed$options, parsed$positional))
  }

  handler <- switch(parsed$command,
    scan = cmd_scan,
    init = cmd_init,
    validate = cmd_validate,
    `list-rules` = cmd_list_rules,
    `describe-rule` = cmd_describe_rule,
    config = cmd_config,
    doctor = cmd_doctor,
    version = cmd_version,
    NULL
  )

  if (is.null(handler)) {
    cat(sprintf("Unknown command: %s\n\n", parsed$command))
    cat(rtrace_help_text())
    return(1L)
  }

  status <- tryCatch(
    handler(parsed$options, parsed$positional),
    error = function(e) {
      cat(sprintf("Error: %s\n", conditionMessage(e)))
      1L
    }
  )
  as.integer(status)
}
