# rtrace_addin_scan() itself opens an RStudio Viewer / browser tab and so
# requires an interactive session; only its non-interactive helper
# functions are unit-tested here (see R/addin.R's documentation).

test_that("addin_scan_root falls back to the working directory outside RStudio", {
  expect_equal(addin_scan_root(), getwd())
})

test_that("addin_report_path returns an .html path that does not yet exist", {
  path <- addin_report_path()
  expect_match(path, "\\.html$")
  expect_false(file.exists(path))
})

test_that("addin_report_path returns a fresh path on each call", {
  expect_false(identical(addin_report_path(), addin_report_path()))
})

test_that("generate_html_report writes a valid HTML report using default_config when no rtrace.yml exists", {
  root <- local_project(c("f.R" = "setwd('/tmp')"))
  report_path <- withr::local_tempfile(fileext = ".html")

  diags <- generate_html_report(root, report_path)
  expect_s3_class(diags, "rtrace_diagnostic_set")
  expect_true(file.exists(report_path))

  html <- paste(readLines(report_path), collapse = "\n")
  expect_match(html, "<!DOCTYPE html>", fixed = TRUE)
  expect_match(html, "antipattern.setwd")
})

test_that("generate_html_report uses rtrace.yml when present", {
  root <- local_project(c(
    "f.R" = "assign('x', 1)",
    "rtrace.yml" = "version: 1\nrules:\n  - type: antipattern.assign\n    severity: error\n"
  ))
  report_path <- withr::local_tempfile(fileext = ".html")

  diags <- generate_html_report(root, report_path)
  expect_length(diags, 1)
  expect_equal(diags$diagnostics[[1]]$rule_id, "antipattern.assign")
  expect_equal(diags$diagnostics[[1]]$severity, "error")
})

test_that("generate_html_report includes an architecture section when layers are configured", {
  root <- local_project(c(
    "analysis/a.R" = "source('shiny/b.R')",
    "shiny/b.R" = "1",
    "rtrace.yml" = paste(
      "version: 1",
      "layers:",
      "  analysis: [\"analysis/**\"]",
      "  shiny: [\"shiny/**\"]",
      "rules: []",
      sep = "\n"
    )
  ))
  report_path <- withr::local_tempfile(fileext = ".html")

  generate_html_report(root, report_path)
  html <- paste(readLines(report_path), collapse = "\n")
  expect_match(html, "Architecture Overview")
})
