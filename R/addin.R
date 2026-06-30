#' Determine the project root for the RStudio Addin
#'
#' Uses `rstudioapi::getActiveProject()` when running inside RStudio with
#' an open project; falls back to the current working directory otherwise
#' (e.g. RStudio with no `.Rproj` open, or no RStudio at all).
#'
#' @return Character scalar path.
#' @keywords internal
#' @noRd
addin_scan_root <- function() {
  if (requireNamespace("rstudioapi", quietly = TRUE) && isTRUE(rstudioapi::isAvailable())) {
    project <- tryCatch(rstudioapi::getActiveProject(), error = function(e) NULL)
    if (!is.null(project) && !is.na(project)) return(project)
  }
  getwd()
}

#' Pick a temp file path for the addin's generated HTML report
#' @return Character scalar path.
#' @keywords internal
#' @noRd
addin_report_path <- function() {
  tempfile("rtrace-report-", fileext = ".html")
}

#' Run a scan against `root` and write an HTML report to `report_path`
#'
#' Resolves `<root>/rtrace.yml` if present, else [default_config()] — same
#' resolution rule as [resolve_config()] used by the CLI's `scan` command.
#'
#' @param root Character scalar project root.
#' @param report_path Character scalar output HTML file path.
#' @return Invisibly, the `rtrace_diagnostic_set`.
#' @keywords internal
#' @noRd
generate_html_report <- function(root, report_path) {
  config_path <- file.path(root, "rtrace.yml")
  config <- if (file.exists(config_path)) read_config(config_path) else default_config()

  context <- build_context(root, config)
  diagnostics <- run_rules(context)

  html <- reporter_html(
    diagnostics,
    title = sprintf("RTrace Scan: %s", basename(root)),
    layers = setdiff(unique(context$files$layer), "(unassigned)"),
    layer_graph = context$dependency_graph$layer_graph
  )
  writeLines(html, report_path)
  invisible(diagnostics)
}

#' RStudio Addin: scan the active project and view an HTML report
#'
#' Detects the current RStudio project, runs a scan, writes an HTML report
#' (see [reporter_html()]) to a temp file, and opens it in the RStudio
#' Viewer pane — or the default browser outside RStudio. Registered via
#' `inst/rstudio/addins.dcf` as "RTrace: Scan Project" in RStudio's Addins
#' menu.
#'
#' The logic that matters (project-root detection, report-path selection,
#' running the scan and writing the report) is factored out into
#' independently-testable internal helpers in `R/addin.R`; this function
#' itself is a thin wrapper around them plus the final
#' `rstudioapi::viewer()`/`browseURL()` call, which requires an
#' interactive session and isn't exercised by the automated test suite.
#'
#' @return Invisibly, the path to the generated HTML report.
#' @export
rtrace_addin_scan <- function() {
  root <- addin_scan_root()
  report_path <- addin_report_path()
  generate_html_report(root, report_path)

  if (requireNamespace("rstudioapi", quietly = TRUE) && isTRUE(rstudioapi::isAvailable())) {
    rstudioapi::viewer(report_path)
  } else {
    utils::browseURL(report_path)
  }

  invisible(report_path)
}
