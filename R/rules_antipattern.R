#' Rule: global superassignment (`<<-`)
#'
#' Flags use of `<<-`, which mutates state outside a function's local
#' scope and is a common source of hard-to-trace bugs and hidden coupling
#' between functions.
#'
#' Config: `type: antipattern.globalAssign`, no parameters.
#'
#' @return A [Rule] instance.
#' @keywords internal
#' @noRd
rule_antipattern_global_assign <- function() {
  Rule$new(
    id = "antipattern.globalAssign",
    description = "Flags use of `<<-` (superassignment).",
    default_severity = "warning",
    default_params = list(),
    check_fn = function(context, params) {
      diags <- list()
      for (i in seq_len(nrow(context$files))) {
        path <- context$files$path[i]
        ast <- context$asts[[path]]
        if (is.null(ast)) next
        hits <- find_superassignments(ast)
        for (j in seq_len(nrow(hits))) {
          diags[[length(diags) + 1]] <- new_diagnostic(
            rule_id = "antipattern.globalAssign",
            severity = "warning",
            file = context$files$rel_path[i],
            line = hits$line1[j],
            column = hits$col1[j],
            message = "Use of `<<-` (superassignment) mutates state outside the current scope.",
            suggestion = "Return the value and assign it explicitly in the caller instead."
          )
        }
      }
      diags
    }
  )
}

#' Rule: `assign()` usage
#'
#' Flags calls to `assign()`, which can create variables under
#' dynamically-constructed names that are difficult to trace statically.
#'
#' Config: `type: antipattern.assign`, no parameters.
#'
#' @return A [Rule] instance.
#' @keywords internal
#' @noRd
rule_antipattern_assign <- function() {
  Rule$new(
    id = "antipattern.assign",
    description = "Flags use of `assign()`.",
    default_severity = "info",
    default_params = list(),
    check_fn = function(context, params) {
      diags <- list()
      for (i in seq_len(nrow(context$files))) {
        path <- context$files$path[i]
        ast <- context$asts[[path]]
        if (is.null(ast)) next
        hits <- find_calls(ast, "assign")
        for (j in seq_len(nrow(hits))) {
          diags[[length(diags) + 1]] <- new_diagnostic(
            rule_id = "antipattern.assign",
            severity = "info",
            file = context$files$rel_path[i],
            line = hits$line1[j],
            column = hits$col1[j],
            message = "Use of `assign()` creates variables that are hard to trace statically.",
            suggestion = "Prefer direct `<-` assignment where the variable name is known."
          )
        }
      }
      diags
    }
  )
}

#' Rule: `setwd()` usage
#'
#' Flags calls to `setwd()`, which breaks reproducibility by mutating
#' process-global working directory state.
#'
#' Config: `type: antipattern.setwd`, no parameters.
#'
#' @return A [Rule] instance.
#' @keywords internal
#' @noRd
rule_antipattern_setwd <- function() {
  Rule$new(
    id = "antipattern.setwd",
    description = "Flags use of `setwd()`.",
    default_severity = "error",
    default_params = list(),
    check_fn = function(context, params) {
      diags <- list()
      for (i in seq_len(nrow(context$files))) {
        path <- context$files$path[i]
        ast <- context$asts[[path]]
        if (is.null(ast)) next
        hits <- find_calls(ast, "setwd")
        for (j in seq_len(nrow(hits))) {
          diags[[length(diags) + 1]] <- new_diagnostic(
            rule_id = "antipattern.setwd",
            severity = "error",
            file = context$files$rel_path[i],
            line = hits$line1[j],
            column = hits$col1[j],
            message = "Use of `setwd()` mutates global working-directory state and breaks reproducibility.",
            suggestion = "Use here::here(), relative paths from the project root, or an explicit `path` argument instead."
          )
        }
      }
      diags
    }
  )
}

#' Rule: hardcoded local filesystem paths
#'
#' Flags string literals that look like hardcoded absolute local paths
#' (`/home/...`, `/Users/...`, `~/...`, `C:\...`), which break portability
#' across machines and CI.
#'
#' Config: `type: antipattern.hardcodedPath`, no parameters.
#'
#' @return A [Rule] instance.
#' @keywords internal
#' @noRd
rule_antipattern_hardcoded_path <- function() {
  Rule$new(
    id = "antipattern.hardcodedPath",
    description = "Flags hardcoded absolute local filesystem paths in string literals.",
    default_severity = "warning",
    default_params = list(),
    check_fn = function(context, params) {
      pattern <- "^[\"'](?:/home/|/Users/|~/|[A-Za-z]:[\\\\/])"
      diags <- list()
      for (i in seq_len(nrow(context$files))) {
        path <- context$files$path[i]
        ast <- context$asts[[path]]
        if (is.null(ast) || is.null(ast$parse_data)) next
        pd <- ast$parse_data
        str_tokens <- pd[pd$token == "STR_CONST", , drop = FALSE]
        if (nrow(str_tokens) == 0) next
        hits <- str_tokens[grepl(pattern, str_tokens$text, perl = TRUE), , drop = FALSE]
        for (j in seq_len(nrow(hits))) {
          diags[[length(diags) + 1]] <- new_diagnostic(
            rule_id = "antipattern.hardcodedPath",
            severity = "warning",
            file = context$files$rel_path[i],
            line = hits$line1[j],
            column = hits$col1[j],
            message = sprintf("Hardcoded local filesystem path: %s", hits$text[j]),
            suggestion = "Use a relative path, here::here(), or a configurable option instead."
          )
        }
      }
      diags
    }
  )
}
