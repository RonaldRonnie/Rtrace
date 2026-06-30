#' Rule: missing roxygen2 documentation
#'
#' Flags top-level functions (excluding dot-prefixed, conventionally
#' internal functions) with no roxygen2 (`#'`) comment block immediately
#' above their definition.
#'
#' Config: `type: documentation.missing`, no parameters. Disabled by
#' default ([default_config()]) because not every project intends every
#' top-level function to be documented; enable it for package projects
#' where all top-level `R/` functions are part of the public API.
#'
#' @return A [Rule] instance.
#' @keywords internal
#' @noRd
rule_documentation_missing <- function() {
  Rule$new(
    id = "documentation.missing",
    description = "Flags top-level functions with no roxygen2 documentation block.",
    default_severity = "info",
    default_params = list(),
    check_fn = function(context, params) {
      diags <- list()
      for (i in seq_len(nrow(context$files))) {
        path <- context$files$path[i]
        ast <- context$asts[[path]]
        if (is.null(ast) || is.null(ast$expr)) next

        for (fn in top_level_functions(ast)) {
          if (is.na(fn$name) || startsWith(fn$name, ".")) next
          if (is.na(fn$line1)) next
          if (has_roxygen_block_above(ast$lines, fn$line1)) next

          diags[[length(diags) + 1]] <- new_diagnostic(
            rule_id = "documentation.missing",
            severity = "info",
            file = context$files$rel_path[i],
            line = fn$line1,
            message = sprintf("Function '%s' has no roxygen2 documentation block.", fn$name),
            suggestion = "Add a `#'` roxygen2 comment block above the function definition."
          )
        }
      }
      diags
    }
  )
}

#' Test whether a roxygen2 comment block immediately precedes a line
#' @param lines Character vector of source lines.
#' @param line1 Integer scalar, 1-indexed line the function definition
#'   starts on.
#' @return Logical scalar.
#' @keywords internal
#' @noRd
has_roxygen_block_above <- function(lines, line1) {
  i <- line1 - 1L
  found <- FALSE
  while (i >= 1L) {
    line <- trimws(lines[i])
    if (grepl("^#'", line)) {
      found <- TRUE
      i <- i - 1L
    } else if (line == "") {
      i <- i - 1L
      break
    } else {
      break
    }
  }
  found
}
