#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @importFrom R6 R6Class
#' @importFrom rlang abort warn %||%
## usethis namespace: end
NULL

#' RTrace package-level environment
#'
#' Holds the rule registry and other process-local state. Not exported.
#' @keywords internal
#' @noRd
rtrace_env <- new.env(parent = emptyenv())
rtrace_env$rule_registry <- list()
