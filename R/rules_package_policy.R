#' Rule: deprecated API usage
#'
#' Flags calls to project-configured deprecated functions, either bare
#' (`"melt"`) or namespace-qualified (`"reshape2::melt"`). Deliberately
#' configuration-driven rather than shipping a fixed list: "deprecated" is
#' project- and ecosystem-specific (a Bioconductor project's deprecated API
#' surface looks nothing like a Shiny app's).
#'
#' Config: `type: package.deprecatedApi`, param `functions` — a mapping of
#' deprecated identifier to suggested replacement text:
#' ```yaml
#' - type: package.deprecatedApi
#'   functions:
#'     "reshape2::melt": "tidyr::pivot_longer()"
#'     "plyr::ddply": "dplyr::group_by() + dplyr::summarise()"
#' ```
#' With no `functions` configured, this rule is a no-op.
#'
#' @return A [Rule] instance.
#' @keywords internal
#' @noRd
rule_package_deprecated_api <- function() {
  Rule$new(
    id = "package.deprecatedApi",
    description = "Flags calls to project-configured deprecated functions.",
    default_severity = "warning",
    default_params = list(functions = list()),
    check_fn = function(context, params) {
      functions <- params$functions
      if (length(functions) == 0) return(list())

      diags <- list()
      for (identifier in names(functions)) {
        replacement <- functions[[identifier]]
        is_qualified <- grepl("::", identifier, fixed = TRUE)
        if (is_qualified) {
          parts <- strsplit(identifier, "::", fixed = TRUE)[[1]]
          pkg <- parts[1]
          fn_name <- parts[2]
        } else {
          fn_name <- identifier
        }

        for (i in seq_len(nrow(context$files))) {
          path <- context$files$path[i]
          ast <- context$asts[[path]]
          if (is.null(ast)) next

          hits <- if (is_qualified) find_qualified_calls(ast, pkg, fn_name) else find_calls(ast, fn_name)
          for (j in seq_len(nrow(hits))) {
            diags[[length(diags) + 1]] <- new_diagnostic(
              rule_id = "package.deprecatedApi",
              severity = "warning",
              file = context$files$rel_path[i],
              line = hits$line1[j],
              column = hits$col1[j],
              message = sprintf("Use of deprecated API '%s'.", identifier),
              suggestion = if (!is.null(replacement) && nzchar(replacement)) {
                sprintf("Use '%s' instead.", replacement)
              } else {
                NULL
              }
            )
          }
        }
      }
      diags
    }
  )
}
