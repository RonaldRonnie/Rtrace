#' Escape text for safe embedding in HTML
#'
#' Diagnostic `file`, `message`, and `suggestion` fields originate from
#' scanned source code (file paths, string literals quoted back into
#' messages), so they must be escaped before being embedded in a generated
#' HTML report — see [SECURITY.md](https://github.com/rtrace-dev/rtrace/blob/main/SECURITY.md).
#'
#' @param x Character vector.
#' @return Character vector with `& < > " '` replaced by HTML entities.
#' @export
html_escape <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub("\"", "&quot;", x, fixed = TRUE)
  x <- gsub("'", "&#39;", x, fixed = TRUE)
  x
}

#' Render a diagnostic set as a standalone HTML report
#'
#' Produces a single self-contained HTML file (inline CSS, no external
#' assets or JavaScript dependencies) grouping diagnostics by file, with a
#' summary panel and per-severity color coding. Suitable for attaching as a
#' CI artifact or opening directly in a browser.
#'
#' @param diagnostics An `rtrace_diagnostic_set`.
#' @param title Character scalar report heading.
#' @return Character scalar containing a full HTML document.
#' @export
reporter_html <- function(diagnostics, title = "RTrace Scan Report") {
  stopifnot(inherits(diagnostics, "rtrace_diagnostic_set"))

  s <- summary(diagnostics)

  by_file <- if (length(diagnostics) > 0) {
    split(diagnostics$diagnostics, vapply(diagnostics$diagnostics, function(d) d$file, character(1)))
  } else {
    list()
  }

  severity_class <- c(error = "sev-error", warning = "sev-warning", info = "sev-info")

  file_sections <- vapply(names(by_file), function(file) {
    rows <- vapply(by_file[[file]], function(d) {
      loc <- if (!is.na(d$line)) {
        if (!is.na(d$column)) sprintf("%d:%d", d$line, d$column) else sprintf("%d", d$line)
      } else {
        ""
      }
      suggestion_html <- if (!is.null(d$suggestion) && nzchar(d$suggestion)) {
        sprintf('<div class="suggestion">&rarr; %s</div>', html_escape(d$suggestion))
      } else {
        ""
      }
      sprintf(
        '<li class="%s"><span class="badge">%s</span> <span class="loc">%s</span> %s <code class="rule">%s</code>%s</li>',
        severity_class[[d$severity]], toupper(d$severity), html_escape(loc),
        html_escape(d$message), html_escape(d$rule_id), suggestion_html
      )
    }, character(1))

    sprintf('<section class="file"><h2>%s</h2><ul>%s</ul></section>',
            html_escape(file), paste(rows, collapse = "\n"))
  }, character(1))

  body <- if (length(diagnostics) == 0) {
    '<p class="clean">No issues found.</p>'
  } else {
    paste(file_sections, collapse = "\n")
  }

  css <- paste(
    "body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif;",
    "max-width:960px;margin:2rem auto;padding:0 1rem;color:#1b1f23;}",
    "h1{font-size:1.5rem;} h2{font-size:1.05rem;margin-top:2rem;font-family:monospace;}",
    ".summary{display:flex;gap:1rem;margin:1rem 0 2rem;}",
    ".summary .stat{padding:.5rem 1rem;border-radius:6px;font-weight:600;}",
    ".summary .error{background:#ffeef0;color:#86181d;}",
    ".summary .warning{background:#fff8c5;color:#735c0f;}",
    ".summary .info{background:#ddf4ff;color:#0969da;}",
    "ul{list-style:none;padding-left:0;}",
    "li{padding:.5rem 0;border-bottom:1px solid #eaecef;}",
    ".badge{display:inline-block;min-width:4.5rem;font-size:.75rem;font-weight:700;",
    "padding:.1rem .4rem;border-radius:4px;text-align:center;}",
    ".sev-error .badge{background:#cf222e;color:#fff;}",
    ".sev-warning .badge{background:#9a6700;color:#fff;}",
    ".sev-info .badge{background:#0969da;color:#fff;}",
    ".loc{font-family:monospace;color:#57606a;}",
    "code.rule{background:#f6f8fa;padding:.1rem .3rem;border-radius:4px;font-size:.85em;}",
    ".suggestion{color:#57606a;font-size:.9em;margin-top:.2rem;margin-left:5.2rem;}",
    ".clean{color:#1a7f37;font-weight:600;}",
    sep = "\n"
  )

  sprintf(
    paste(
      "<!DOCTYPE html>",
      '<html lang="en">',
      "<head>",
      '<meta charset="utf-8">',
      "<title>%s</title>",
      "<style>%s</style>",
      "</head>",
      "<body>",
      "<h1>%s</h1>",
      '<div class="summary">',
      '<span class="stat error">%d error(s)</span>',
      '<span class="stat warning">%d warning(s)</span>',
      '<span class="stat info">%d info</span>',
      "</div>",
      "%s",
      "</body>",
      "</html>",
      sep = "\n"
    ),
    html_escape(title), css, html_escape(title),
    s[["error"]], s[["warning"]], s[["info"]],
    body
  )
}
