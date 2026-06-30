#' Render a diagnostic set as JSON
#'
#' Output schema:
#' ```json
#' {
#'   "schema_version": 1,
#'   "summary": {"error": 0, "warning": 2, "info": 1},
#'   "diagnostics": [
#'     {"rule_id": "...", "severity": "...", "file": "...", "line": 1,
#'      "column": null, "message": "...", "suggestion": null, "doc_url": null}
#'   ]
#' }
#' ```
#'
#' @param diagnostics An `rtrace_diagnostic_set`.
#' @param pretty Logical; pretty-print the JSON. Default `TRUE`.
#' @return Character scalar JSON string.
#' @export
reporter_json <- function(diagnostics, pretty = TRUE) {
  stopifnot(inherits(diagnostics, "rtrace_diagnostic_set"))

  payload <- list(
    schema_version = 1L,
    summary = as.list(summary(diagnostics)),
    diagnostics = lapply(diagnostics$diagnostics, function(d) {
      list(
        rule_id = d$rule_id,
        severity = d$severity,
        file = d$file,
        line = if (is.na(d$line)) NULL else d$line,
        column = if (is.na(d$column)) NULL else d$column,
        message = d$message,
        suggestion = d$suggestion,
        doc_url = d$doc_url
      )
    })
  )

  jsonlite::toJSON(payload, auto_unbox = TRUE, null = "null", pretty = pretty)
}
