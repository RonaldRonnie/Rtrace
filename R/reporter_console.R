#' Render a diagnostic set as colored console output
#'
#' @param diagnostics An `rtrace_diagnostic_set`.
#' @param use_color Logical; whether to use ANSI color. Defaults to
#'   `cli::num_ansi_colors() > 1`.
#' @return Invisibly, the character string written to the console.
#' @export
reporter_console <- function(diagnostics, use_color = cli::num_ansi_colors() > 1) {
  stopifnot(inherits(diagnostics, "rtrace_diagnostic_set"))

  lines <- character(0)
  severity_style <- list(
    error = function(x) if (use_color) cli::col_red(cli::style_bold(x)) else x,
    warning = function(x) if (use_color) cli::col_yellow(x) else x,
    info = function(x) if (use_color) cli::col_blue(x) else x
  )

  by_file <- if (length(diagnostics) > 0) {
    split(diagnostics$diagnostics, vapply(diagnostics$diagnostics, function(d) d$file, character(1)))
  } else {
    list()
  }

  for (file in names(by_file)) {
    lines <- c(lines, if (use_color) cli::style_underline(file) else file)
    for (d in by_file[[file]]) {
      loc <- if (!is.na(d$line)) {
        if (!is.na(d$column)) sprintf("%d:%d", d$line, d$column) else sprintf("%d", d$line)
      } else {
        ""
      }
      sev_label <- severity_style[[d$severity]](sprintf("%-7s", toupper(d$severity)))
      lines <- c(lines, sprintf("  %s %-10s %s [%s]", sev_label, loc, d$message, d$rule_id))
      if (!is.null(d$suggestion)) {
        lines <- c(lines, sprintf("           %s %s", if (use_color) cli::col_grey("\u2192") else "->", d$suggestion))
      }
    }
  }

  s <- summary(diagnostics)
  summary_line <- sprintf(
    "%d error(s), %d warning(s), %d info",
    s[["error"]], s[["warning"]], s[["info"]]
  )
  lines <- c(lines, "", summary_line)

  out <- paste(lines, collapse = "\n")
  cat(out, "\n", sep = "")
  invisible(out)
}
