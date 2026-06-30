#' Create a diagnostic
#'
#' A `Diagnostic` is the atomic unit of output produced by a rule: a single
#' finding at a single location.
#'
#' @param rule_id Character scalar. The id of the rule that produced this
#'   diagnostic (e.g. `"complexity.cyclomatic"`).
#' @param severity One of `"error"`, `"warning"`, `"info"`.
#' @param file Character scalar. Path to the file the diagnostic refers to,
#'   relative to the project root where possible.
#' @param line Integer scalar or `NA_integer_`. 1-indexed line number.
#' @param column Integer scalar or `NA_integer_`. 1-indexed column number.
#' @param message Character scalar. Human-readable description of the
#'   problem.
#' @param suggestion Character scalar or `NULL`. An actionable fix
#'   suggestion.
#' @param doc_url Character scalar or `NULL`. A link to rule documentation.
#'
#' @return An object of class `rtrace_diagnostic`.
#' @export
new_diagnostic <- function(rule_id,
                            severity = c("error", "warning", "info"),
                            file,
                            line = NA_integer_,
                            column = NA_integer_,
                            message,
                            suggestion = NULL,
                            doc_url = NULL) {
  severity <- match.arg(severity)

  if (!is.character(rule_id) || length(rule_id) != 1 || is.na(rule_id)) {
    rlang::abort("`rule_id` must be a non-NA character scalar.")
  }
  if (!is.character(file) || length(file) != 1) {
    rlang::abort("`file` must be a character scalar.")
  }
  if (!is.character(message) || length(message) != 1 || is.na(message)) {
    rlang::abort("`message` must be a non-NA character scalar.")
  }

  structure(
    list(
      rule_id = rule_id,
      severity = severity,
      file = file,
      line = as.integer(line),
      column = as.integer(column),
      message = message,
      suggestion = suggestion,
      doc_url = doc_url
    ),
    class = "rtrace_diagnostic"
  )
}

#' @export
format.rtrace_diagnostic <- function(x, ...) {
  loc <- if (!is.na(x$line)) {
    if (!is.na(x$column)) {
      sprintf("%s:%d:%d", x$file, x$line, x$column)
    } else {
      sprintf("%s:%d", x$file, x$line)
    }
  } else {
    x$file
  }
  sprintf("[%s] %s: %s (%s)", toupper(x$severity), loc, x$message, x$rule_id)
}

#' @export
print.rtrace_diagnostic <- function(x, ...) {
  cat(format(x), "\n", sep = "")
  invisible(x)
}

#' Construct a set of diagnostics
#'
#' @param diagnostics A list of `rtrace_diagnostic` objects.
#' @return An object of class `rtrace_diagnostic_set`.
#' @export
new_diagnostic_set <- function(diagnostics = list()) {
  if (length(diagnostics) > 0) {
    is_diag <- vapply(diagnostics, inherits, logical(1), what = "rtrace_diagnostic")
    if (!all(is_diag)) {
      rlang::abort("All elements of `diagnostics` must be `rtrace_diagnostic` objects.")
    }
  }
  structure(list(diagnostics = diagnostics), class = "rtrace_diagnostic_set")
}

#' Combine diagnostic sets
#' @param ... `rtrace_diagnostic_set` objects.
#' @return A single combined `rtrace_diagnostic_set`.
#' @export
c.rtrace_diagnostic_set <- function(...) {
  sets <- list(...)
  all_diags <- unlist(lapply(sets, function(s) s$diagnostics), recursive = FALSE)
  new_diagnostic_set(all_diags)
}

#' @export
length.rtrace_diagnostic_set <- function(x) length(x$diagnostics)

#' @export
print.rtrace_diagnostic_set <- function(x, ...) {
  if (length(x) == 0) {
    cat("<rtrace_diagnostic_set: no diagnostics>\n")
    return(invisible(x))
  }
  for (d in x$diagnostics) print(d)
  invisible(x)
}

#' Filter a diagnostic set
#'
#' @param x An `rtrace_diagnostic_set`.
#' @param severity Optional character vector of severities to keep.
#' @param rule_id Optional character vector of rule ids to keep.
#' @param file Optional character vector of file paths to keep.
#' @return A filtered `rtrace_diagnostic_set`.
#' @export
filter_diagnostics <- function(x, severity = NULL, rule_id = NULL, file = NULL) {
  stopifnot(inherits(x, "rtrace_diagnostic_set"))
  keep <- rep(TRUE, length(x))
  sev <- vapply(x$diagnostics, function(d) d$severity, character(1))
  rid <- vapply(x$diagnostics, function(d) d$rule_id, character(1))
  fil <- vapply(x$diagnostics, function(d) d$file, character(1))

  if (!is.null(severity)) keep <- keep & sev %in% severity
  if (!is.null(rule_id)) keep <- keep & rid %in% rule_id
  if (!is.null(file)) keep <- keep & fil %in% file

  new_diagnostic_set(x$diagnostics[keep])
}

#' Summarize a diagnostic set by severity
#'
#' @param object An `rtrace_diagnostic_set`.
#' @param ... Unused.
#' @return A named integer vector with counts per severity level
#'   (`error`, `warning`, `info`).
#' @export
summary.rtrace_diagnostic_set <- function(object, ...) {
  levels <- c("error", "warning", "info")
  if (length(object) == 0) {
    counts <- stats::setNames(rep(0L, length(levels)), levels)
    return(counts)
  }
  sev <- vapply(object$diagnostics, function(d) d$severity, character(1))
  counts <- vapply(levels, function(l) sum(sev == l), integer(1))
  stats::setNames(counts, levels)
}

#' Determine the process exit status implied by a diagnostic set
#'
#' @param x An `rtrace_diagnostic_set`.
#' @param fail_on Severity threshold that causes a nonzero exit status:
#'   `"error"` (default) or `"warning"`.
#' @return Integer `0` or `1`.
#' @export
exit_status <- function(x, fail_on = c("error", "warning")) {
  stopifnot(inherits(x, "rtrace_diagnostic_set"))
  fail_on <- match.arg(fail_on)
  s <- summary(x)
  if (fail_on == "warning") {
    as.integer(s[["error"]] > 0 || s[["warning"]] > 0)
  } else {
    as.integer(s[["error"]] > 0)
  }
}

#' Convert a diagnostic set to a data frame
#'
#' @param x An `rtrace_diagnostic_set`.
#' @param ... Unused.
#' @return A `data.frame` with one row per diagnostic.
#' @export
as.data.frame.rtrace_diagnostic_set <- function(x, ...) {
  if (length(x) == 0) {
    return(data.frame(
      rule_id = character(0), severity = character(0), file = character(0),
      line = integer(0), column = integer(0), message = character(0),
      suggestion = character(0), doc_url = character(0),
      stringsAsFactors = FALSE
    ))
  }
  rows <- lapply(x$diagnostics, function(d) {
    data.frame(
      rule_id = d$rule_id,
      severity = d$severity,
      file = d$file,
      line = d$line,
      column = d$column,
      message = d$message,
      suggestion = if (is.null(d$suggestion)) NA_character_ else d$suggestion,
      doc_url = if (is.null(d$doc_url)) NA_character_ else d$doc_url,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}
