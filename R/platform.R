#' Trace Platform — metadata, module registry, and environment
#'
#' The Trace Platform treats RTrace as its first module. Additional modules
#' (DataTrace, DocsTrace, PackageQA, future language modules) register here
#' at load time via [register_module()], giving the platform a unified view of
#' every installed capability.
#'
#' @name trace-platform
NULL

# ---------------------------------------------------------------------------
# Module registry
# ---------------------------------------------------------------------------

#' Register a Trace Platform module
#'
#' Called at package-load time by RTrace itself and by any future sibling
#' module (DataTrace, DocsTrace, PackageQA, etc.) that wants the platform to
#' know it is present.
#'
#' @param module A named list with at minimum:
#'   - `id`          Character scalar. Unique module id (e.g. `"rtrace"`).
#'   - `name`        Character scalar. Human-readable name.
#'   - `version`     Character scalar. Module version string.
#'   - `description` Character scalar. One-line description.
#'   - `scan_fn`     Optional function `function(root, config)` that the
#'                   platform's `platform_scan()` calls to run the module.
#'   - `score_fn`    Optional function `function(diagnostics)` returning a
#'                   named list `list(score=, label=, breakdown=)`.
#' @return Invisibly the module id.
#' @export
register_module <- function(module) {
  required <- c("id", "name", "version", "description")
  missing_fields <- setdiff(required, names(module))
  if (length(missing_fields) > 0) {
    rlang::abort(sprintf(
      "Module registration missing required field(s): %s",
      paste(missing_fields, collapse = ", ")
    ))
  }
  if (!is.null(rtrace_env$platform_modules[[module$id]])) {
    rlang::warn(sprintf("Platform module '%s' is already registered; overwriting.", module$id))
  }
  rtrace_env$platform_modules[[module$id]] <- module
  invisible(module$id)
}

#' List registered Trace Platform modules
#'
#' @return A named list of module registration records.
#' @export
list_modules <- function() {
  rtrace_env$platform_modules
}

#' Get a registered module by id
#'
#' @param id Character scalar module id.
#' @return A module list, or `NULL` if not registered.
#' @export
get_module <- function(id) {
  rtrace_env$platform_modules[[id]]
}

# ---------------------------------------------------------------------------
# Platform-wide scan
# ---------------------------------------------------------------------------

#' Run a full Trace Platform scan across all registered modules
#'
#' Calls each registered module's `scan_fn(root, config)` in sequence,
#' collects all diagnostics and scores, and returns a `trace_platform_result`.
#'
#' @param root Character scalar project root.
#' @param config An `rtrace_config` object. Defaults to [default_config()].
#' @param use_cache Logical; passed to RTrace's `build_context()`. Default
#'   `FALSE`.
#' @param modules Character vector of module ids to run. Default `NULL`
#'   (run all registered modules).
#' @return A `trace_platform_result` object.
#' @export
platform_scan <- function(root = ".",
                           config = default_config(),
                           use_cache = FALSE,
                           modules = NULL) {
  root <- normalizePath(root, mustWork = TRUE)
  all_modules <- list_modules()

  if (length(all_modules) == 0) {
    rlang::warn(paste(
      "platform_scan(): no platform modules are registered.",
      "This usually means RTrace's .onLoad() did not run (e.g. functions",
      "were sourced individually instead of loading the package).",
      "The result will contain zero modules and zero diagnostics."
    ))
  }

  if (!is.null(modules)) {
    unknown <- setdiff(modules, names(all_modules))
    if (length(unknown) > 0) {
      rlang::warn(sprintf("Unknown module id(s) ignored: %s", paste(unknown, collapse = ", ")))
    }
    all_modules <- all_modules[intersect(modules, names(all_modules))]
    if (length(all_modules) == 0 && length(unknown) < length(modules)) {
      # All requested ids were valid but resolved to nothing (e.g. `modules`
      # was a zero-length vector) -- the unknown-id warning above already
      # covers the "all ids were unknown" case, so don't double-warn.
      rlang::warn("platform_scan(): the requested `modules` filter matched zero registered modules.")
    }
  }

  results  <- list()
  scores   <- list()
  all_diag <- new_diagnostic_set()

  for (mod_id in names(all_modules)) {
    mod <- all_modules[[mod_id]]

    if (!is.null(mod$scan_fn) && is.function(mod$scan_fn)) {
      diags <- tryCatch(
        mod$scan_fn(root, config),
        error = function(e) {
          rlang::warn(sprintf("Module '%s' scan_fn errored: %s", mod_id, conditionMessage(e)))
          new_diagnostic_set()
        }
      )
      if (!inherits(diags, "rtrace_diagnostic_set")) diags <- new_diagnostic_set()
    } else {
      diags <- new_diagnostic_set()
    }

    results[[mod_id]]  <- diags
    all_diag           <- c(all_diag, diags)

    if (!is.null(mod$score_fn) && is.function(mod$score_fn)) {
      score_result <- tryCatch(
        mod$score_fn(diags),
        error = function(e) list(score = 0L, label = "Error", breakdown = list())
      )
      scores[[mod_id]] <- score_result
    }
  }

  structure(
    list(
      root    = root,
      modules = names(all_modules),
      results = results,
      scores  = scores,
      all_diagnostics = all_diag,
      timestamp = Sys.time()
    ),
    class = "trace_platform_result"
  )
}

#' @export
print.trace_platform_result <- function(x, ...) {
  cat(sprintf("<trace_platform_result>\n"))
  cat(sprintf("  root:      %s\n", x$root))
  cat(sprintf("  modules:   %s\n", paste(x$modules, collapse = ", ")))
  cat(sprintf("  timestamp: %s\n", format(x$timestamp, "%Y-%m-%d %H:%M:%S")))
  cat(sprintf("  total diagnostics: %d\n", length(x$all_diagnostics)))
  if (length(x$scores) > 0) {
    cat("  scores:\n")
    for (nm in names(x$scores)) {
      sc <- x$scores[[nm]]
      cat(sprintf("    %-20s %3d  (%s)\n", nm, sc$score %||% 0L, sc$label %||% ""))
    }
  }
  invisible(x)
}

#' Return the Trace Platform version string
#' @return Character scalar.
#' @export
platform_version <- function() {
  rtrace_env$platform_version
}

#' Return the Trace Platform name
#' @return Character scalar.
#' @export
platform_name <- function() {
  rtrace_env$platform_name
}
