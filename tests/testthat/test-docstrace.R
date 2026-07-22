test_that("run_docstrace_scan returns expected structure", {
  root <- local_project(list("R/foo.R" = "f <- function(x) x"))
  result <- run_docstrace_scan(root)
  expect_named(result, c("diagnostics", "score"))
  expect_s3_class(result$diagnostics, "rtrace_diagnostic_set")
  expect_s3_class(result$score, "trace_score")
  expect_equal(result$score$module_id, "docstrace")
})

test_that("docstrace.readme fires when README is absent", {
  root <- local_project(list("R/foo.R" = "f <- function(x) x"))
  result <- run_docstrace_scan(root)
  diag_ids <- vapply(result$diagnostics$diagnostics, function(d) d$rule_id, character(1))
  expect_true("docstrace.readme" %in% diag_ids)
})

test_that("docstrace.readme is silent when README.md exists", {
  root <- local_project(list(
    "README.md" = "# My Package\n\nA useful package.",
    "R/foo.R"   = "f <- function(x) x"
  ))
  result <- run_docstrace_scan(root)
  diag_ids <- vapply(result$diagnostics$diagnostics, function(d) d$rule_id, character(1))
  expect_false("docstrace.readme" %in% diag_ids)
})

test_that("docstrace.readme is silent when README.Rmd exists", {
  root <- local_project(list(
    "README.Rmd" = "---\ntitle: Test\n---\n# Package",
    "R/foo.R"    = "f <- function(x) x"
  ))
  result <- run_docstrace_scan(root)
  diag_ids <- vapply(result$diagnostics$diagnostics, function(d) d$rule_id, character(1))
  expect_false("docstrace.readme" %in% diag_ids)
})

test_that("docstrace.readmeQuality fires for thin README", {
  root <- local_project(list(
    "README.md" = "# My Package\nHello.",
    "R/foo.R"   = "f <- function(x) x"
  ))
  result <- run_docstrace_scan(root)
  diag_ids <- vapply(result$diagnostics$diagnostics, function(d) d$rule_id, character(1))
  expect_true("docstrace.readmeQuality" %in% diag_ids)
})

test_that("docstrace.readmeQuality is silent for comprehensive README", {
  # Enough words + the three required heading sections
  readme_content <- paste(
    "# My Biostatistics Package",
    "",
    "## About",
    paste(rep("This package provides advanced tools for biostatistical analysis.", 4), collapse = " "),
    "It supports longitudinal models, survival analysis, and mixed-effects regression.",
    "",
    "## Installation",
    "Install the stable release from CRAN using the standard install command.",
    "Development versions are available on GitHub via the remotes package.",
    "",
    "## Usage",
    "Load the package with library and call the main analysis function.",
    "Pass your cleaned data frame and specify the outcome column name.",
    "Results are returned as a list with model summaries and diagnostics.",
    "",
    "## License",
    "This package is released under the MIT license. See LICENSE for details.",
    sep = "\n"
  )
  root <- local_project(list(
    "README.md" = readme_content,
    "R/foo.R"   = "f <- function(x) x"
  ))
  result <- run_docstrace_scan(root)
  diag_ids <- vapply(result$diagnostics$diagnostics, function(d) d$rule_id, character(1))
  expect_false("docstrace.readmeQuality" %in% diag_ids)
})

test_that("docstrace.vignettes fires for package without vignettes", {
  root <- local_project(list(
    "DESCRIPTION" = "Package: mypkg\nVersion: 0.1.0\nTitle: My Pkg\n",
    "R/foo.R"     = "f <- function(x) x"
  ))
  result <- run_docstrace_scan(root)
  diag_ids <- vapply(result$diagnostics$diagnostics, function(d) d$rule_id, character(1))
  expect_true("docstrace.vignettes" %in% diag_ids)
})

test_that("docstrace.vignettes is silent when vignettes exist", {
  root <- local_project(list(
    "DESCRIPTION"                = "Package: mypkg\nVersion: 0.1.0\nTitle: My Pkg\n",
    "vignettes/introduction.Rmd" = "---\ntitle: Intro\nvignette: >\\n  %\\VignetteIndexEntry{Intro}\\n---\n# Intro"
  ))
  result <- run_docstrace_scan(root)
  diag_ids <- vapply(result$diagnostics$diagnostics, function(d) d$rule_id, character(1))
  expect_false("docstrace.vignettes" %in% diag_ids)
})

test_that("docstrace.changelogPresent fires when NEWS.md is absent from package", {
  root <- local_project(list(
    "DESCRIPTION" = "Package: mypkg\nVersion: 0.1.0\nTitle: My Pkg\n",
    "R/foo.R"     = "f <- function(x) x"
  ))
  result <- run_docstrace_scan(root)
  diag_ids <- vapply(result$diagnostics$diagnostics, function(d) d$rule_id, character(1))
  expect_true("docstrace.changelogPresent" %in% diag_ids)
})

test_that("docstrace.changelogPresent is silent when NEWS.md exists", {
  root <- local_project(list(
    "DESCRIPTION" = "Package: mypkg\nVersion: 0.1.0\nTitle: My Pkg\n",
    "NEWS.md"     = "# mypkg 0.1.0\n* Initial release"
  ))
  result <- run_docstrace_scan(root)
  diag_ids <- vapply(result$diagnostics$diagnostics, function(d) d$rule_id, character(1))
  expect_false("docstrace.changelogPresent" %in% diag_ids)
})

test_that("docstrace.contributingGuide fires when CONTRIBUTING file is absent", {
  root <- local_project(list(
    "DESCRIPTION" = "Package: mypkg\nVersion: 0.1.0\n",
    "README.md"   = "# mypkg"
  ))
  result <- run_docstrace_scan(root)
  diag_ids <- vapply(result$diagnostics$diagnostics, function(d) d$rule_id, character(1))
  expect_true("docstrace.contributingGuide" %in% diag_ids)
})

test_that("docstrace.contributingGuide is silent when CONTRIBUTING.md exists", {
  root <- local_project(list(
    "DESCRIPTION"     = "Package: mypkg\nVersion: 0.1.0\n",
    "CONTRIBUTING.md" = "# Contributing\n\nPull requests welcome!"
  ))
  result <- run_docstrace_scan(root)
  diag_ids <- vapply(result$diagnostics$diagnostics, function(d) d$rule_id, character(1))
  expect_false("docstrace.contributingGuide" %in% diag_ids)
})

test_that("docstrace.citationFile fires for package without CITATION", {
  root <- local_project(list(
    "DESCRIPTION" = "Package: mypkg\nVersion: 0.1.0\nTitle: My Pkg\n",
    "R/foo.R"     = "f <- function(x) x"
  ))
  result <- run_docstrace_scan(root)
  diag_ids <- vapply(result$diagnostics$diagnostics, function(d) d$rule_id, character(1))
  expect_true("docstrace.citationFile" %in% diag_ids)
})

test_that("docstrace.citationFile is silent when inst/CITATION exists", {
  root <- local_project(list(
    "DESCRIPTION"   = "Package: mypkg\nVersion: 0.1.0\nTitle: My Pkg\n",
    "inst/CITATION" = "bibentry('Manual', title='mypkg', author='Me', year=2024)"
  ))
  result <- run_docstrace_scan(root)
  diag_ids <- vapply(result$diagnostics$diagnostics, function(d) d$rule_id, character(1))
  expect_false("docstrace.citationFile" %in% diag_ids)
})

# Regression test for Issue #10: a `[^}]*}`-style regex truncates at the
# *first* closing brace, so a substantive \examples block that opens with
# any short bracketed token (e.g. `\x{}`) was wrongly flagged as trivial.
test_that("docstrace.examplesQuality does not fire for a real example block containing nested braces", {
  rd <- paste(
    "\\name{add}",
    "\\title{Add two numbers}",
    "\\examples{",
    "\\x{}",
    "result <- add(1, 2)",
    "print(result)",
    "stopifnot(result == 3)",
    "cat(\"This is a long, real, substantive example block.\\n\")",
    "}",
    sep = "\n"
  )
  root <- local_project(list(
    "DESCRIPTION" = "Package: mypkg\nVersion: 0.1.0\nTitle: My Pkg\n",
    "man/add.Rd"  = rd
  ))
  result <- run_docstrace_scan(root)
  diag_ids <- vapply(result$diagnostics$diagnostics, function(d) d$rule_id, character(1))
  expect_false("docstrace.examplesQuality" %in% diag_ids)
})

test_that("docstrace.examplesQuality fires for a genuinely empty examples block", {
  rd <- paste(
    "\\name{add}",
    "\\title{Add two numbers}",
    "\\examples{}",
    sep = "\n"
  )
  root <- local_project(list(
    "DESCRIPTION" = "Package: mypkg\nVersion: 0.1.0\nTitle: My Pkg\n",
    "man/add.Rd"  = rd
  ))
  result <- run_docstrace_scan(root)
  diag_ids <- vapply(result$diagnostics$diagnostics, function(d) d$rule_id, character(1))
  expect_true("docstrace.examplesQuality" %in% diag_ids)
})

test_that("run_docstrace_scan produces high score for a well-documented package", {
  readme_content <- paste(
    "# bestpkg",
    "",
    "## About",
    "A comprehensive package for biostatistical analysis.",
    "",
    "## Installation",
    "```r",
    "install.packages('bestpkg')",
    "```",
    "",
    "## Usage",
    "```r",
    "library(bestpkg)",
    "bestpkg::analyze(data = df)",
    "```",
    "",
    "## License",
    "MIT",
    sep = "\n"
  )
  root <- local_project(list(
    "DESCRIPTION"               = "Package: bestpkg\nVersion: 1.0.0\nTitle: Best Package\n",
    "README.md"                 = readme_content,
    "NEWS.md"                   = "# bestpkg 1.0.0\n* Initial release",
    "CONTRIBUTING.md"           = "# Contributing\nPull requests welcome!",
    "inst/CITATION"             = "bibentry('Manual', title='bestpkg', year=2024)",
    "vignettes/intro.Rmd"       = "---\ntitle: Intro\n---\n# Introduction",
    "_pkgdown.yml"              = "url: https://example.com/bestpkg\n",
    "R/main.R"                  = "#' @examples\n#' f(1)\n#' @export\nf <- function(x) x^2"
  ))
  result <- run_docstrace_scan(root)
  expect_gte(result$score$score, 80L)
})
