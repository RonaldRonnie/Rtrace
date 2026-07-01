#' Neutralize CSV formula-injection-risk field values
#'
#' Diagnostic `file`, `message`, and `suggestion` fields can echo content
#' from the *scanned* source tree (file names, quoted string literals) —
#' content RTrace does not control, e.g. when scanning a third party's pull
#' request. A field value starting with `=`, `+`, `-`, `@`, a tab, or a
#' carriage return is interpreted as a formula by Excel/Sheets/LibreOffice
#' when the CSV is opened, which is a known CSV-injection vector. Prefixing
#' such values with a single quote forces spreadsheet applications to treat
#' them as plain text, the standard mitigation (OWASP CSV Injection
#' cheatsheet).
#'
#' @param x Character vector.
#' @return Character vector, with risky leading characters neutralized.
#' @keywords internal
#' @noRd
sanitize_csv_field <- function(x) {
  risky <- grepl("^[-=+@\t\r]", x)
  x[risky] <- paste0("'", x[risky])
  x
}

#' Render a diagnostic set as CSV
#'
#' One row per diagnostic, columns `rule_id, severity, file, line, column,
#' message, suggestion, doc_url` (see [as.data.frame.rtrace_diagnostic_set()]).
#' Missing values are written as empty fields, not the string `"NA"`. The
#' `file`, `message`, and `suggestion` columns are sanitized against CSV
#' formula injection (see `sanitize_csv_field()`) since they can echo
#' scanned, potentially untrusted source content.
#'
#' @param diagnostics An `rtrace_diagnostic_set`.
#' @return Character scalar CSV text (including a header row).
#' @export
reporter_csv <- function(diagnostics) {
  stopifnot(inherits(diagnostics, "rtrace_diagnostic_set"))

  df <- as.data.frame(diagnostics)
  for (col in c("file", "message", "suggestion")) {
    df[[col]] <- sanitize_csv_field(df[[col]])
  }

  lines <- utils::capture.output(utils::write.csv(df, row.names = FALSE, na = ""))

  paste(lines, collapse = "\n")
}
