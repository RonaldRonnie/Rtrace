#' Rule: missing test references
#'
#' A lightweight static heuristic that flags top-level functions (excluding
#' dot-prefixed, conventionally internal functions) whose name never
#' appears as a token anywhere under `tests/`. This is *not* runtime
#' coverage measurement (that's [`covr`](https://covr.r-lib.org/)'s job,
#' see ADR 0001) — it only checks whether a function is referenced by name
#' in test source at all, catching functions nobody bothered to write a
#' test file for, cheaply and without executing any code.
#'
#' To avoid duplicating `structure.requiredDirs`'s "no tests/ directory"
#' complaint, this rule is silent when the project has no files under
#' `tests/` at all (every function would otherwise be flagged, which adds
#' no information beyond "you have no tests").
#'
#' Config: `type: testing.missingTests`, no parameters. Disabled by default
#' ([default_config()]) — it is a heuristic with real false positives
#' (functions only invoked indirectly through other functions, S3/S4
#' methods invoked by generic dispatch, etc.).
#'
#' @return A [Rule] instance.
#' @keywords internal
#' @noRd
rule_testing_missing_tests <- function() {
  Rule$new(
    id = "testing.missingTests",
    description = "Flags top-level functions never referenced by name under tests/.",
    default_severity = "info",
    default_params = list(),
    check_fn = function(context, params) {
      is_test_file <- grepl("^tests/", context$files$rel_path)
      if (!any(is_test_file)) return(list())

      referenced <- character(0)
      for (path in context$files$path[is_test_file]) {
        ast <- context$asts[[path]]
        if (is.null(ast) || is.null(ast$parse_data)) next
        pd <- ast$parse_data
        referenced <- c(referenced, pd$text[pd$token %in% c("SYMBOL_FUNCTION_CALL", "SYMBOL")])
      }
      referenced <- unique(referenced)

      diags <- list()
      for (i in seq_len(nrow(context$files))) {
        if (is_test_file[i]) next
        path <- context$files$path[i]
        ast <- context$asts[[path]]
        if (is.null(ast) || is.null(ast$expr)) next

        for (fn in top_level_functions(ast)) {
          if (is.na(fn$name) || startsWith(fn$name, ".")) next
          if (fn$name %in% referenced) next

          diags[[length(diags) + 1]] <- new_diagnostic(
            rule_id = "testing.missingTests",
            severity = "info",
            file = context$files$rel_path[i],
            line = fn$line1,
            message = sprintf("Function '%s' is never referenced under tests/.", fn$name),
            suggestion = sprintf("Add a testthat test that calls or references '%s'.", fn$name)
          )
        }
      }
      diags
    }
  )
}
