#' Rule: forbidden dependency direction
#'
#' Flags a `source()`-derived dependency edge from layer `from` to layer
#' `to`. One rule entry expresses one forbidden pair; declare multiple
#' `dependency.forbidden` entries in `rtrace.yml` for multiple pairs.
#'
#' Config: `type: dependency.forbidden`, params `from`, `to` (layer names
#' as declared in `layers:`).
#'
#' @return A [Rule] instance.
#' @keywords internal
#' @noRd
rule_dependency_forbidden <- function() {
  Rule$new(
    id = "dependency.forbidden",
    description = "Flags a configured forbidden layer-to-layer dependency direction.",
    default_severity = "error",
    default_params = list(from = NULL, to = NULL),
    check_fn = function(context, params) {
      if (is.null(params$from) || is.null(params$to)) {
        rlang::abort("dependency.forbidden requires both `from` and `to` parameters.")
      }
      graph <- context$dependency_graph$layer_graph
      targets <- graph[[params$from]] %||% character(0)
      if (!(params$to %in% targets)) return(list())

      list(new_diagnostic(
        rule_id = "dependency.forbidden",
        severity = "error",
        file = sprintf("(layer:%s)", params$from),
        message = sprintf(
          "Layer '%s' depends on layer '%s', which is a forbidden dependency direction.",
          params$from, params$to
        ),
        suggestion = sprintf(
          "Remove or invert the source()/dependency from '%s' to '%s'.",
          params$from, params$to
        )
      ))
    }
  )
}

#' Rule: circular dependency detection
#'
#' Flags cycles in the layer-level dependency graph (built from `source()`
#' edges, see [build_dependency_graph()]).
#'
#' Config: `type: dependency.circular`, no parameters.
#'
#' @return A [Rule] instance.
#' @keywords internal
#' @noRd
rule_dependency_circular <- function() {
  Rule$new(
    id = "dependency.circular",
    description = "Flags circular dependencies between layers.",
    default_severity = "error",
    default_params = list(),
    check_fn = function(context, params) {
      cycles <- find_cycles(context$dependency_graph$layer_graph)
      if (length(cycles) == 0) return(list())

      lapply(cycles, function(cycle) {
        new_diagnostic(
          rule_id = "dependency.circular",
          severity = "error",
          file = "(project)",
          message = sprintf(
            "Circular dependency detected between layers: %s",
            paste(cycle, collapse = " -> ")
          ),
          suggestion = "Break the cycle by introducing a shared lower-level layer or removing one of the edges."
        )
      })
    }
  )
}
