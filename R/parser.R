#' Parse an R source file
#'
#' Wraps base R's `parse(keep.source = TRUE)` and `utils::getParseData()`.
#' Deliberately depends on no third-party AST representation (see ADR 0001
#' in `dev/adr/` in the package source) so RTrace can be used alongside
#' `lintr` without internal coupling.
#'
#' Syntax errors are captured rather than raised: the returned object's
#' `error` field is non-`NULL` and `expr`/`parse_data` are `NULL`, so a
#' single broken file does not abort a project-wide scan.
#'
#' @param path Character scalar path to an R source file.
#' @return An object of class `rtrace_file_ast` with fields `path`, `expr`
#'   (the parsed `expression` object, or `NULL`), `parse_data` (a
#'   `data.frame` from `getParseData()`, or `NULL`), `lines` (character
#'   vector of source lines), and `error` (a condition object, or `NULL`).
#' @export
parse_file <- function(path) {
  lines <- tryCatch(
    readLines(path, warn = FALSE, encoding = "UTF-8"),
    error = function(e) character(0)
  )

  parsed <- tryCatch(
    parse(path, keep.source = TRUE),
    error = function(e) e
  )

  if (inherits(parsed, "error") || inherits(parsed, "condition")) {
    return(structure(
      list(path = path, expr = NULL, parse_data = NULL, lines = lines, error = parsed),
      class = "rtrace_file_ast"
    ))
  }

  parse_data <- tryCatch(utils::getParseData(parsed), error = function(e) NULL)

  structure(
    list(path = path, expr = parsed, parse_data = parse_data, lines = lines, error = NULL),
    class = "rtrace_file_ast"
  )
}

#' Number of lines in a parsed file
#' @param ast An `rtrace_file_ast`.
#' @return Integer scalar.
#' @export
ast_line_count <- function(ast) {
  stopifnot(inherits(ast, "rtrace_file_ast"))
  length(ast$lines)
}

#' Find all calls to a given function name in a parsed file
#'
#' @param ast An `rtrace_file_ast`.
#' @param fn_name Character scalar function name (e.g. `"setwd"`).
#' @return A `data.frame` with columns `line1`, `col1`, `text` (the call
#'   site's source text where available), one row per call site. Zero rows
#'   if the file failed to parse or contains no such calls.
#' @export
find_calls <- function(ast, fn_name) {
  stopifnot(inherits(ast, "rtrace_file_ast"))
  empty <- data.frame(line1 = integer(0), col1 = integer(0), text = character(0),
                       stringsAsFactors = FALSE)
  if (is.null(ast$parse_data)) return(empty)

  pd <- ast$parse_data
  call_tokens <- pd[pd$token == "SYMBOL_FUNCTION_CALL" & pd$text == fn_name, , drop = FALSE]
  if (nrow(call_tokens) == 0) return(empty)

  data.frame(
    line1 = call_tokens$line1,
    col1 = call_tokens$col1,
    text = call_tokens$text,
    stringsAsFactors = FALSE
  )
}

#' Find all namespace-qualified calls to a given `pkg::fn` (or `pkg:::fn`)
#'
#' @param ast An `rtrace_file_ast`.
#' @param pkg Character scalar package name (e.g. `"reshape2"`).
#' @param fn_name Character scalar function name (e.g. `"melt"`).
#' @return A `data.frame` with columns `line1`, `col1` (position of the
#'   `pkg` token), one row per call site. Zero rows if the file failed to
#'   parse or contains no such calls.
#' @export
find_qualified_calls <- function(ast, pkg, fn_name) {
  stopifnot(inherits(ast, "rtrace_file_ast"))
  empty <- data.frame(line1 = integer(0), col1 = integer(0))
  if (is.null(ast$parse_data)) return(empty)

  pd <- ast$parse_data
  pd <- pd[as.logical(pd$terminal), , drop = FALSE]
  pd <- pd[order(pd$line1, pd$col1), , drop = FALSE]
  n <- nrow(pd)
  if (n < 3) return(empty)

  hits_idx <- integer(0)
  for (i in seq_len(n - 2)) {
    if (pd$token[i] == "SYMBOL_PACKAGE" && pd$text[i] == pkg &&
        pd$token[i + 1] %in% c("NS_GET", "NS_GET_INT") &&
        pd$token[i + 2] == "SYMBOL_FUNCTION_CALL" && pd$text[i + 2] == fn_name) {
      hits_idx <- c(hits_idx, i)
    }
  }
  if (length(hits_idx) == 0) return(empty)

  data.frame(line1 = pd$line1[hits_idx], col1 = pd$col1[hits_idx])
}

#' Find all `<<-` (superassignment) usages in a parsed file
#'
#' @param ast An `rtrace_file_ast`.
#' @return A `data.frame` with columns `line1`, `col1`.
#' @export
find_superassignments <- function(ast) {
  stopifnot(inherits(ast, "rtrace_file_ast"))
  empty <- data.frame(line1 = integer(0), col1 = integer(0))
  if (is.null(ast$parse_data)) return(empty)
  pd <- ast$parse_data
  hits <- pd[pd$token == "LEFT_ASSIGN" & pd$text == "<<-", , drop = FALSE]
  if (nrow(hits) == 0) return(empty)
  data.frame(line1 = hits$line1, col1 = hits$col1)
}

#' Locate top-level function definitions in a parsed file
#'
#' @param ast An `rtrace_file_ast`.
#' @return A list of `list(name=, line1=, line2=, n_lines=, expr=)`, one
#'   entry per top-level `name <- function(...) ...` or
#'   `name = function(...) ...` assignment. Anonymous/nested functions are
#'   not included (top-level only, matching how rule authors typically
#'   reason about "a function" in a project).
#' @export
top_level_functions <- function(ast) {
  stopifnot(inherits(ast, "rtrace_file_ast"))
  if (is.null(ast$expr)) return(list())

  out <- list()
  top_level <- as.list(ast$expr)
  srcrefs <- attr(ast$expr, "srcref")

  for (idx in seq_along(top_level)) {
    e <- top_level[[idx]]
    is_assign <- is.call(e) && length(e) >= 3 &&
      as.character(e[[1]]) %in% c("<-", "=", "<<-")
    if (!is_assign) next
    rhs <- e[[3]]
    if (!(is.call(rhs) && identical(rhs[[1]], as.name("function")))) next

    name <- tryCatch(as.character(e[[2]]), error = function(err) NA_character_)
    srcref <- if (!is.null(srcrefs)) srcrefs[[idx]] else NULL
    if (!is.null(srcref)) {
      line1 <- srcref[1]
      line2 <- srcref[3]
    } else {
      line1 <- NA_integer_
      line2 <- NA_integer_
    }

    out[[length(out) + 1]] <- list(
      name = name, line1 = line1, line2 = line2,
      n_lines = if (!is.na(line1)) line2 - line1 + 1 else NA_integer_,
      expr = rhs
    )
  }
  out
}

#' Compute the cyclomatic complexity of a function body
#'
#' Counts decision points (`if`, `for`, `while`, `repeat`, `&&`, `||`,
#' `case_when`-style nested `ifelse`, and each `switch()` branch) plus one,
#' the standard McCabe formulation.
#'
#' @param fn_expr A function expression (the value returned in the `expr`
#'   field of [top_level_functions()] entries).
#' @return Integer scalar complexity score.
#' @export
cyclomatic_complexity <- function(fn_expr) {
  count <- 1L
  decision_calls <- c("if", "for", "while", "repeat", "&&", "||")

  walk <- function(e) {
    if (is.call(e)) {
      head <- tryCatch(as.character(e[[1]]), error = function(err) "")
      if (length(head) == 1 && head %in% decision_calls) {
        count <<- count + 1L
      }
      if (length(head) == 1 && head == "switch") {
        # Each additional switch argument beyond the subject is a branch.
        count <<- count + max(0L, length(e) - 2L)
      }
      for (i in seq_along(e)) {
        if (i == 1) next
        walk(e[[i]])
      }
    } else if (is.pairlist(e)) {
      for (i in seq_along(e)) walk(e[[i]])
    }
  }

  walk(fn_expr)
  count
}
