#' Render a diagnostic set as a Markdown report
#'
#' Suitable for posting as a CI pull-request comment or writing to a
#' standalone `.md` file.
#'
#' @param diagnostics An `rtrace_diagnostic_set`.
#' @param title Character scalar heading for the report.
#' @return Character scalar Markdown string.
#' @export
reporter_markdown <- function(diagnostics, title = "RTrace Scan Report") {
  stopifnot(inherits(diagnostics, "rtrace_diagnostic_set"))

  s <- summary(diagnostics)
  lines <- c(
    sprintf("# %s", title),
    "",
    sprintf("**%d error(s)**, **%d warning(s)**, %d info", s[["error"]], s[["warning"]], s[["info"]]),
    ""
  )

  if (length(diagnostics) == 0) {
    lines <- c(lines, "No issues found.")
    return(paste(lines, collapse = "\n"))
  }

  lines <- c(lines, "| Severity | File | Location | Rule | Message | Suggestion |",
                    "|---|---|---|---|---|---|")

  for (d in diagnostics$diagnostics) {
    loc <- if (!is.na(d$line)) {
      if (!is.na(d$column)) sprintf("%d:%d", d$line, d$column) else sprintf("%d", d$line)
    } else {
      ""
    }
    badge <- switch(d$severity, error = "\U0001F534 error", warning = "\U0001F7E1 warning", info = "\U0001F535 info")
    lines <- c(lines, sprintf(
      "| %s | `%s` | %s | `%s` | %s | %s |",
      badge, d$file, loc, d$rule_id,
      gsub("\\|", "\\\\|", d$message),
      gsub("\\|", "\\\\|", d$suggestion %||% "")
    ))
  }

  paste(lines, collapse = "\n")
}
