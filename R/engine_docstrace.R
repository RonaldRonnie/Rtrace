#' DocsTrace Engine
#'
#' Evaluates documentation quality for an R project or package. Goes beyond
#' the existing `documentation.missing` rule (which only checks whether a
#' roxygen2 block exists above each function) to assess README completeness,
#' vignette coverage, pkgdown configuration, and the quality of examples.
#'
#' @name docstrace-engine
NULL

#' Run the DocsTrace engine against a project
#'
#' @param root Character scalar project root.
#' @param config An `rtrace_config` object. Defaults to [default_config()].
#'   Every registered `docstrace.*` rule runs by default; a `config$rules`
#'   entry for a rule's id overrides its `enabled`/`severity`/`params`
#'   (Issue #11).
#' @return A list with `diagnostics` (an `rtrace_diagnostic_set`) and
#'   `score` (a `trace_score`).
#' @export
run_docstrace_scan <- function(root = ".", config = default_config()) {
  root <- normalizePath(root, mustWork = TRUE)

  docstrace_rules <- Filter(
    function(r) startsWith(r$id, "docstrace."),
    as.list(list_rules())
  )

  diags <- new_diagnostic_set()

  for (rule in docstrace_rules) {
    spec <- find_rule_spec(config, rule$id)
    if (!is.null(spec) && !isTRUE(spec$enabled)) next

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
      rule$domain_fns$check_docstrace(root, params),
      error = function(e) {
        list(new_diagnostic(
          rule_id = "rule-error", severity = "error", file = "(docstrace-engine)",
          message = sprintf("DocsTrace rule '%s' errored: %s", rule$id, conditionMessage(e))
        ))
      }
    )
    if (length(result) > 0) {
      if (inherits(result, "rtrace_diagnostic")) result <- list(result)
      if (!is.null(override_severity)) {
        result <- lapply(result, function(d) { d$severity <- override_severity; d })
      }
      diags <- c(diags, new_diagnostic_set(result))
    }
  }

  score <- compute_score(
    diags,
    error_penalty   = 12,
    warning_penalty = 4,
    info_penalty    = 1
  )
  score$module_id <- "docstrace"

  list(diagnostics = diags, score = score)
}

# ---------------------------------------------------------------------------
# DocsTrace Rule base constructor (analogous to datatrace_rule)
# ---------------------------------------------------------------------------

#' Construct a DocsTrace-aware rule
#'
#' DocsTrace rules operate on the project file system rather than parsed
#' ASTs. The standard `check(context, params)` is a no-op; the engine calls
#' `check_docstrace(root)` directly.
#'
#' @param id,description,default_severity,default_params Standard Rule fields.
#' @param docstrace_fn A function `function(root, params)` returning a list
#'   of `rtrace_diagnostic` objects.
#' @return A [Rule] instance with an additional `check_docstrace` method.
#' @keywords internal
#' @noRd
docstrace_rule <- function(id, description, docstrace_fn,
                             default_severity = "info",
                             default_params   = list()) {
  rule <- Rule$new(
    id               = id,
    description      = description,
    default_severity = default_severity,
    default_params   = default_params,
    check_fn         = function(context, params) list()
  )
  params_captured <- default_params
  fn_captured     <- docstrace_fn
  rule$domain_fns$check_docstrace <- function(root, params = params_captured) {
    fn_captured(root, params)
  }
  rule
}
