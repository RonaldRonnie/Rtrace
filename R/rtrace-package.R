#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @importFrom R6 R6Class
#' @importFrom rlang abort warn %||%
## usethis namespace: end
NULL

#' RTrace / Trace Platform package-level environment
#'
#' Holds the rule registry, module registry, recommendation providers, and
#' other process-local state. Not exported.
#' @keywords internal
#' @noRd
rtrace_env <- new.env(parent = emptyenv())
rtrace_env$rule_registry             <- list()
rtrace_env$platform_modules          <- list()
rtrace_env$platform_version          <- "0.2.0.dev"
rtrace_env$platform_name             <- "Trace Platform"
rtrace_env$recommendation_providers  <- list()
rtrace_env$active_provider           <- "builtin"

# NULL-coalescing fallback (also imported from rlang but defined here so
# internal helpers can use it before the import is resolved at build time)
`%||%` <- function(x, y) if (!is.null(x)) x else y
