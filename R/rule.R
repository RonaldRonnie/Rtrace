#' Rule base class
#'
#' Every built-in and third-party RTrace rule is an instance of this `R6`
#' class. See `vignette("rule-authoring-guide")` or
#' `dev/rule-authoring-guide.md` for a full walkthrough of writing a new
#' rule.
#'
#' @field id Character scalar, unique rule identifier (e.g.
#'   `"complexity.cyclomatic"`). Used as the `type` key in `rtrace.yml`.
#' @field description Character scalar, one-line human-readable summary
#'   shown by `rtrace describe-rule`.
#' @field default_severity One of `"error"`, `"warning"`, `"info"`.
#' @field default_params Named list of default parameter values.
#'
#' @export
Rule <- R6::R6Class("Rule",
  public = list(
    id = NULL,
    description = NULL,
    default_severity = "warning",
    default_params = list(),
    # Mutable environment for engine-specific check functions (datatrace,
    # docstrace, packageqa).  Stored as an environment so it can be mutated
    # even after R6 locks the public binding.
    domain_fns = NULL,

    #' @param id Rule id.
    #' @param description One-line description.
    #' @param default_severity Default severity.
    #' @param default_params Default parameters.
    #' @param check_fn A function `function(context, params)` returning a
    #'   list of `rtrace_diagnostic` objects.
    initialize = function(id, description, check_fn,
                           default_severity = "warning",
                           default_params = list()) {
      stopifnot(is.character(id), length(id) == 1)
      stopifnot(is.function(check_fn))
      self$id <- id
      self$description <- description
      self$default_severity <- default_severity
      self$default_params <- default_params
      self$domain_fns <- new.env(parent = emptyenv())
      private$check_fn <- check_fn
    },

    #' Evaluate this rule against a context
    #' @param context An `rtrace_context`.
    #' @param params Named list of resolved parameters (defaults merged
    #'   with any user overrides).
    #' @return A list of `rtrace_diagnostic` objects.
    check = function(context, params = self$default_params) {
      private$check_fn(context, params)
    }
  ),
  private = list(
    check_fn = NULL
  )
)

#' Register a rule in the global rule registry
#'
#' Built-in rules call this at package load time. Third-party packages may
#' call the exported `RTrace::register_rule()` from their own `.onLoad()`
#' to add rules without forking RTrace (see ADR 0002's plugin-system
#' section).
#'
#' @param rule A [Rule] instance.
#' @return Invisibly, the rule id.
#' @export
register_rule <- function(rule) {
  stopifnot(inherits(rule, "Rule"))
  if (!is.null(rtrace_env$rule_registry[[rule$id]])) {
    rlang::warn(sprintf("Rule '%s' is already registered; overwriting.", rule$id))
  }
  rtrace_env$rule_registry[[rule$id]] <- rule
  invisible(rule$id)
}

#' Look up a registered rule by id
#' @param id Character scalar rule id.
#' @return A [Rule] instance, or `NULL` if not registered.
#' @export
get_rule <- function(id) {
  rtrace_env$rule_registry[[id]]
}

#' List all registered rules
#' @return A list of [Rule] instances.
#' @export
list_rules <- function() {
  rtrace_env$rule_registry
}
