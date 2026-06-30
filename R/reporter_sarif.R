#' Render a diagnostic set as SARIF 2.1.0
#'
#' Produces a minimal, valid [SARIF 2.1.0](https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.html)
#' log with a single run, suitable for upload to GitHub code scanning
#' (`github/codeql-action/upload-sarif`) or any other SARIF-consuming
#' dashboard.
#'
#' RTrace severities map to SARIF levels as `error` -> `error`, `warning`
#' -> `warning`, `info` -> `note` (SARIF has no `info` level).
#'
#' @param diagnostics An `rtrace_diagnostic_set`.
#' @param pretty Logical; pretty-print the JSON. Default `TRUE`.
#' @return Character scalar SARIF (JSON) string.
#' @export
reporter_sarif <- function(diagnostics, pretty = TRUE) {
  stopifnot(inherits(diagnostics, "rtrace_diagnostic_set"))

  level_for <- function(severity) {
    switch(severity, error = "error", warning = "warning", info = "note", "warning")
  }

  rule_ids <- unique(vapply(diagnostics$diagnostics, function(d) d$rule_id, character(1)))
  rules_meta <- lapply(rule_ids, function(id) {
    rule <- get_rule(id)
    entry <- list(id = id)
    entry$shortDescription <- list(text = if (!is.null(rule)) rule$description else id)
    if (!is.null(rule)) {
      entry$defaultConfiguration <- list(level = level_for(rule$default_severity))
    }
    entry
  })

  results <- lapply(diagnostics$diagnostics, function(d) {
    region <- if (!is.na(d$line)) {
      r <- list(startLine = d$line)
      if (!is.na(d$column)) r$startColumn <- d$column
      r
    } else {
      NULL
    }

    location <- list(
      physicalLocation = list(
        artifactLocation = list(uri = d$file)
      )
    )
    if (!is.null(region)) {
      location$physicalLocation$region <- region
    }

    result <- list(
      ruleId = d$rule_id,
      level = level_for(d$severity),
      message = list(text = d$message)
    )
    if (!is.null(d$suggestion)) {
      result$message$text <- paste0(d$message, " Suggestion: ", d$suggestion)
    }
    result$locations <- list(location)
    result
  })

  payload <- list(
    `$schema` = "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json",
    version = "2.1.0",
    runs = list(list(
      tool = list(
        driver = list(
          name = "RTrace",
          informationUri = "https://github.com/rtrace-dev/rtrace",
          version = tryCatch(as.character(utils::packageVersion("RTrace")), error = function(e) "0.0.0.dev"),
          rules = rules_meta
        )
      ),
      results = results
    ))
  )

  jsonlite::toJSON(payload, auto_unbox = TRUE, null = "null", pretty = pretty)
}
