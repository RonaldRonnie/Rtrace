#' Reproducibility Engine
#'
#' Evaluates how reproducible an R project is, producing a 0–100 score and
#' a set of diagnostics. The engine inspects both the static code (via the
#' existing `rtrace_context` AST analysis) and the project's file system
#' (renv.lock presence, DESCRIPTION fields, etc.).
#'
#' The score is intended to be complementary to the architecture score
#' produced by the core RTrace engine: both live on the same 0–100 scale and
#' both feed into the Trace Platform's overall platform health score.
#'
#' @name reproducibility-engine
NULL

#' Run the reproducibility engine against a project
#'
#' Builds a reproducibility context, evaluates all registered
#' `reproducibility.*` rules, and returns both the diagnostic set and a
#' `trace_score`.
#'
#' @param root Character scalar project root.
#' @param config An `rtrace_config` object. Defaults to [default_config()].
#' @param use_cache Logical; passed to [build_context()]. Default `FALSE`.
#' @return A list with `diagnostics` (an `rtrace_diagnostic_set`) and
#'   `score` (a `trace_score`).
#' @export
run_reproducibility_scan <- function(root = ".",
                                      config = default_config(),
                                      use_cache = FALSE) {
  context <- build_context(root, config, use_cache = use_cache)

  repro_rules <- Filter(
    function(r) startsWith(r$id, "reproducibility."),
    as.list(list_rules())
  )

  diags <- new_diagnostic_set()

  for (rule in repro_rules) {
    spec <- find_rule_spec(config, rule$id)
    if (!is.null(spec) && !isTRUE(spec$enabled)) next

    # Only override severity when the user has explicitly configured one for
    # this rule -- a blanket override would collapse rules that legitimately
    # emit diagnostics at more than one severity.
    override_severity <- if (!is.null(spec) && !is.na(spec$severity %||% NA_character_)) {
      spec$severity
    } else {
      NULL
    }
    params <- if (!is.null(spec)) {
      utils::modifyList(rule$default_params, spec$params %||% list())
    } else {
      rule$default_params
    }

    result <- tryCatch(
      rule$check(context, params),
      error = function(e) {
        list(new_diagnostic(
          rule_id = "rule-error", severity = "error", file = "(engine)",
          message = sprintf("Reproducibility rule '%s' errored: %s",
                            rule$id, conditionMessage(e))
        ))
      }
    )

    if (length(result) > 0) {
      if (inherits(result, "rtrace_diagnostic")) result <- list(result)
      if (!is.null(override_severity)) {
        result <- lapply(result, function(d) { d$severity <- override_severity; d })
      }
      diags  <- c(diags, new_diagnostic_set(result))
    }
  }

  score <- compute_score(
    diags,
    error_penalty   = 15,   # reproducibility failures are high-impact
    warning_penalty = 5,
    info_penalty    = 1
  )
  score$module_id <- "reproducibility"

  list(diagnostics = diags, score = score)
}

#' Build the reproducibility context
#'
#' Returns a list extending the standard `rtrace_context` with
#' reproducibility-specific fields (renv.lock presence, DESCRIPTION content,
#' etc.) derived from the project root's file system.
#'
#' @param root Character scalar project root.
#' @return A named list of reproducibility metadata.
#' @export
build_reproducibility_context <- function(root) {
  root <- normalizePath(root, mustWork = TRUE)

  renv_lock      <- file.path(root, "renv.lock")
  packrat_dir    <- file.path(root, "packrat")
  desc_file      <- file.path(root, "DESCRIPTION")
  renv_dir       <- file.path(root, "renv")
  session_info_f <- file.path(root, "session_info.txt")

  list(
    root                  = root,
    has_renv_lock         = file.exists(renv_lock),
    has_packrat           = dir.exists(packrat_dir),
    has_renv_dir          = dir.exists(renv_dir),
    has_description       = file.exists(desc_file),
    has_session_info_file = file.exists(session_info_f),
    renv_lock_path        = renv_lock,
    description_path      = desc_file
  )
}
