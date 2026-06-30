#' Run the configured rule set against a context
#'
#' Resolves the active rule set from `context$config$rules`, evaluates each
#' enabled rule's [Rule]`$check()`, tags every diagnostic with the rule's
#' *configured* severity (falling back to the rule's default severity), and
#' collects results into a single `rtrace_diagnostic_set`.
#'
#' A rule that errors during evaluation does not abort the scan: its error
#' is captured and surfaced as a single `rule-error` diagnostic so the rest
#' of the rule set still runs.
#'
#' @param context An `rtrace_context` (see [build_context()]).
#' @return An `rtrace_diagnostic_set`.
#' @export
run_rules <- function(context) {
  config <- context$config
  all_diagnostics <- list()

  for (spec in config$rules) {
    if (!isTRUE(spec$enabled)) next

    rule <- get_rule(spec$type)
    if (is.null(rule)) {
      all_diagnostics[[length(all_diagnostics) + 1]] <- new_diagnostic(
        rule_id = "rule-error", severity = "error", file = "(config)",
        message = sprintf("Unknown rule type '%s' is enabled in configuration but not registered.", spec$type)
      )
      next
    }

    severity <- if (!is.na(spec$severity)) spec$severity else rule$default_severity
    params <- utils::modifyList(rule$default_params, spec$params %||% list())

    diags <- tryCatch(
      rule$check(context, params),
      error = function(e) {
        list(new_diagnostic(
          rule_id = "rule-error", severity = "error", file = "(engine)",
          message = sprintf("Rule '%s' raised an error during evaluation: %s", rule$id, conditionMessage(e))
        ))
      }
    )

    if (length(diags) == 0) next
    if (inherits(diags, "rtrace_diagnostic")) diags <- list(diags)

    diags <- lapply(diags, function(d) {
      d$severity <- severity
      d
    })

    all_diagnostics <- c(all_diagnostics, diags)
  }

  new_diagnostic_set(all_diagnostics)
}

#' Run a full RTrace scan over a project directory
#'
#' Convenience wrapper combining [build_context()] and [run_rules()] — the
#' top-level entry point used by the CLI's `scan` command and by R scripts
#' that want to run RTrace programmatically.
#'
#' @param root Character scalar path to the project root.
#' @param config An `rtrace_config` object. Defaults to [default_config()].
#' @return An `rtrace_diagnostic_set`.
#' @export
run_scan <- function(root = ".", config = default_config()) {
  context <- build_context(root, config)
  run_rules(context)
}
