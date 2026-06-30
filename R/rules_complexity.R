#' Rule: cyclomatic complexity
#'
#' Flags top-level functions whose McCabe cyclomatic complexity exceeds
#' `max` (see [cyclomatic_complexity()]).
#'
#' Config: `type: complexity.cyclomatic`, param `max` (default `15`).
#'
#' @return A [Rule] instance.
#' @keywords internal
#' @noRd
rule_complexity_cyclomatic <- function() {
  Rule$new(
    id = "complexity.cyclomatic",
    description = "Flags functions whose cyclomatic complexity exceeds a threshold.",
    default_severity = "warning",
    default_params = list(max = 15L),
    check_fn = function(context, params) {
      diags <- list()
      for (i in seq_len(nrow(context$files))) {
        path <- context$files$path[i]
        ast <- context$asts[[path]]
        if (is.null(ast) || is.null(ast$expr)) next
        for (fn in top_level_functions(ast)) {
          score <- cyclomatic_complexity(fn$expr)
          if (score > params$max) {
            diags[[length(diags) + 1]] <- new_diagnostic(
              rule_id = "complexity.cyclomatic",
              severity = "warning",
              file = context$files$rel_path[i],
              line = fn$line1,
              message = sprintf(
                "Function '%s' has cyclomatic complexity %d (max %d).",
                fn$name %||% "<anonymous>", score, params$max
              ),
              suggestion = "Extract branches into smaller helper functions."
            )
          }
        }
      }
      diags
    }
  )
}

#' Rule: function length
#'
#' Flags top-level functions whose line count exceeds `max`.
#'
#' Config: `type: complexity.functionLength`, param `max` (default `60`).
#'
#' @return A [Rule] instance.
#' @keywords internal
#' @noRd
rule_complexity_function_length <- function() {
  Rule$new(
    id = "complexity.functionLength",
    description = "Flags functions that exceed a maximum line count.",
    default_severity = "warning",
    default_params = list(max = 60L),
    check_fn = function(context, params) {
      diags <- list()
      for (i in seq_len(nrow(context$files))) {
        path <- context$files$path[i]
        ast <- context$asts[[path]]
        if (is.null(ast) || is.null(ast$expr)) next
        for (fn in top_level_functions(ast)) {
          if (!is.na(fn$n_lines) && fn$n_lines > params$max) {
            diags[[length(diags) + 1]] <- new_diagnostic(
              rule_id = "complexity.functionLength",
              severity = "warning",
              file = context$files$rel_path[i],
              line = fn$line1,
              message = sprintf(
                "Function '%s' is %d lines long (max %d).",
                fn$name %||% "<anonymous>", fn$n_lines, params$max
              ),
              suggestion = "Split this function into smaller, single-purpose functions."
            )
          }
        }
      }
      diags
    }
  )
}

#' Rule: file length
#'
#' Flags files whose line count exceeds `max`.
#'
#' Config: `type: complexity.fileLength`, param `max` (default `500`).
#'
#' @return A [Rule] instance.
#' @keywords internal
#' @noRd
rule_complexity_file_length <- function() {
  Rule$new(
    id = "complexity.fileLength",
    description = "Flags files that exceed a maximum line count.",
    default_severity = "warning",
    default_params = list(max = 500L),
    check_fn = function(context, params) {
      diags <- list()
      for (i in seq_len(nrow(context$files))) {
        path <- context$files$path[i]
        ast <- context$asts[[path]]
        if (is.null(ast)) next
        n <- ast_line_count(ast)
        if (n > params$max) {
          diags[[length(diags) + 1]] <- new_diagnostic(
            rule_id = "complexity.fileLength",
            severity = "warning",
            file = context$files$rel_path[i],
            line = 1L,
            message = sprintf("File is %d lines long (max %d).", n, params$max),
            suggestion = "Split this file into multiple, more focused files."
          )
        }
      }
      diags
    }
  )
}
