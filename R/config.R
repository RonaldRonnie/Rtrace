#' Known rule type identifiers
#'
#' Returns the `type` strings recognized by the built-in rule registry, used
#' by [validate_config()] to reject typos in `rtrace.yml` at validation time
#' rather than silently ignoring them at scan time.
#'
#' @return Character vector of registered rule ids.
#' @export
known_rule_types <- function() {
  names(rtrace_env$rule_registry)
}

#' Build the default RTrace configuration
#'
#' Used when no `rtrace.yml` is present, and as the base that a project's
#' config is layered on top of.
#'
#' @return An `rtrace_config` object.
#' @export
default_config <- function() {
  new_config(
    version = 1L,
    project = NULL,
    layers = list(),
    exclude = character(0),
    rules = list(
      list(type = "structure.requiredDirs", enabled = TRUE, severity = "warning",
           params = list(dirs = c("R", "tests"))),
      list(type = "dependency.circular", enabled = TRUE, severity = "error",
           params = list()),
      list(type = "complexity.cyclomatic", enabled = TRUE, severity = "warning",
           params = list(max = 15L)),
      list(type = "complexity.functionLength", enabled = TRUE, severity = "warning",
           params = list(max = 60L)),
      list(type = "complexity.fileLength", enabled = TRUE, severity = "warning",
           params = list(max = 500L)),
      list(type = "antipattern.globalAssign", enabled = TRUE, severity = "warning",
           params = list()),
      list(type = "antipattern.assign", enabled = TRUE, severity = "info",
           params = list()),
      list(type = "antipattern.setwd", enabled = TRUE, severity = "error",
           params = list()),
      list(type = "antipattern.hardcodedPath", enabled = TRUE, severity = "warning",
           params = list()),
      list(type = "documentation.missing", enabled = FALSE, severity = "info",
           params = list()),
      list(type = "ecosystem.shinyStructure", enabled = TRUE, severity = "warning",
           params = list())
    )
  )
}

#' Construct an RTrace configuration object
#'
#' @param version Integer config schema version.
#' @param project Optional project name.
#' @param layers Named list mapping layer name to a glob pattern (relative
#'   to the project root).
#' @param exclude Character vector of glob patterns to exclude from
#'   scanning.
#' @param rules List of rule specs, each `list(type=, enabled=, severity=,
#'   params=)`.
#' @return An `rtrace_config` object.
#' @export
new_config <- function(version = 1L, project = NULL, layers = list(),
                        exclude = character(0), rules = list()) {
  structure(
    list(
      version = version,
      project = project,
      layers = layers,
      exclude = exclude,
      rules = rules
    ),
    class = "rtrace_config"
  )
}

#' Read an RTrace configuration file
#'
#' @param path Path to a YAML configuration file.
#' @return An `rtrace_config` object, validated via [validate_config()].
#' @export
read_config <- function(path) {
  if (!file.exists(path)) {
    rlang::abort(sprintf("Config file not found: %s", path))
  }
  raw <- yaml::read_yaml(path, eval.expr = FALSE)
  config <- parse_config(raw)
  validate_config(config)
  config
}

#' Parse a raw (already YAML-decoded) configuration list into an
#' `rtrace_config`, applying defaults for missing keys.
#'
#' @param raw A list as returned by `yaml::read_yaml()`.
#' @return An `rtrace_config` object (not yet validated).
#' @export
parse_config <- function(raw) {
  if (!is.list(raw)) {
    rlang::abort("Configuration must decode to a YAML mapping.")
  }

  known_keys <- c("version", "project", "layers", "exclude", "rules")
  unknown <- setdiff(names(raw), known_keys)
  if (length(unknown) > 0) {
    rlang::warn(sprintf(
      "Ignoring unknown configuration key(s): %s",
      paste(unknown, collapse = ", ")
    ))
  }

  rules <- lapply(raw$rules %||% list(), function(r) {
    if (is.null(r$type)) {
      rlang::abort("Every entry under `rules:` must declare a `type`.")
    }
    list(
      type = r$type,
      enabled = if (is.null(r$enabled)) TRUE else isTRUE(r$enabled),
      severity = r$severity %||% NA_character_,
      params = r[setdiff(names(r), c("type", "enabled", "severity"))]
    )
  })

  new_config(
    version = as.integer(raw$version %||% 1L),
    project = raw$project,
    layers = raw$layers %||% list(),
    exclude = as.character(raw$exclude %||% character(0)),
    rules = rules
  )
}

#' Validate an RTrace configuration
#'
#' Checks structural validity and that every declared rule `type` is known.
#' Called automatically by [read_config()]; exposed separately so the CLI's
#' `validate` command can run it without triggering a scan.
#'
#' @param config An `rtrace_config` object.
#' @return Invisibly, `TRUE` if valid. Raises an error (via `rlang::abort`)
#'   describing every problem found if not.
#' @export
validate_config <- function(config) {
  stopifnot(inherits(config, "rtrace_config"))
  problems <- character(0)

  if (!is.numeric(config$version) || length(config$version) != 1) {
    problems <- c(problems, "`version` must be a single integer.")
  }

  if (!is.list(config$layers)) {
    problems <- c(problems, "`layers` must be a mapping of layer name to glob pattern.")
  } else if (length(config$layers) > 0 && is.null(names(config$layers))) {
    problems <- c(problems, "`layers` entries must be named (layer name -> glob pattern).")
  }

  known <- known_rule_types()
  for (i in seq_along(config$rules)) {
    r <- config$rules[[i]]
    if (!is.character(r$type) || length(r$type) != 1) {
      problems <- c(problems, sprintf("rules[[%d]]: `type` must be a single string.", i))
      next
    }
    if (length(known) > 0 && !(r$type %in% known)) {
      problems <- c(problems, sprintf(
        "rules[[%d]]: unknown rule type '%s'. Known types: %s",
        i, r$type, paste(known, collapse = ", ")
      ))
    }
    if (!is.na(r$severity) && !(r$severity %in% c("error", "warning", "info"))) {
      problems <- c(problems, sprintf(
        "rules[[%d]] ('%s'): `severity` must be one of error/warning/info, got '%s'.",
        i, r$type, r$severity
      ))
    }
  }

  if (length(problems) > 0) {
    rlang::abort(c("Invalid RTrace configuration:", problems), class = "rtrace_config_error")
  }
  invisible(TRUE)
}

#' @export
print.rtrace_config <- function(x, ...) {
  cat("<rtrace_config>\n")
  cat(sprintf("  version: %s\n", x$version))
  cat(sprintf("  project: %s\n", x$project %||% "(unnamed)"))
  cat(sprintf("  layers: %s\n", if (length(x$layers)) paste(names(x$layers), collapse = ", ") else "(none)"))
  enabled <- vapply(x$rules, function(r) r$enabled, logical(1))
  cat(sprintf("  rules: %d declared, %d enabled\n", length(x$rules), sum(enabled)))
  invisible(x)
}
