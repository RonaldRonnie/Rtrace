#' Render a diagnostic set as CSV
#'
#' One row per diagnostic, columns `rule_id, severity, file, line, column,
#' message, suggestion, doc_url` (see [as.data.frame.rtrace_diagnostic_set()]).
#' Missing values are written as empty fields, not the string `"NA"`.
#'
#' @param diagnostics An `rtrace_diagnostic_set`.
#' @return Character scalar CSV text (including a header row).
#' @export
reporter_csv <- function(diagnostics) {
  stopifnot(inherits(diagnostics, "rtrace_diagnostic_set"))

  df <- as.data.frame(diagnostics)
  lines <- utils::capture.output(utils::write.csv(df, row.names = FALSE, na = ""))

  paste(lines, collapse = "\n")
}
