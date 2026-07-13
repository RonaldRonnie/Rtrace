json_after_status_line <- function(out) {
  jsonlite::fromJSON(sub("^.*?\\n(?=\\{)", "", out, perl = TRUE), simplifyVector = FALSE)
}

test_that("rtrace_cli platform-scan --format json includes every registered module", {
  # Regression test for Issue #1: the CLI used to manually invoke each
  # engine's run_*_scan() function directly, independent of the module
  # registry, so it happened to show every module while the API (iterating
  # the registry) showed only "rtrace". Both must now agree.
  root <- local_project(c("f.R" = "x <- 1"))
  out <- testthat::capture_output(rtrace_cli(c("platform-scan", root, "--format", "json")))
  payload <- json_after_status_line(out)

  expect_setequal(unlist(payload$modules), names(list_modules()))
})

test_that("CLI platform-scan and platform_scan() report identical violation counts", {
  root <- local_project(c("f.R" = "setwd('/tmp')"))

  direct <- platform_scan(root)

  out <- testthat::capture_output(rtrace_cli(c("platform-scan", root, "--format", "json")))
  payload <- json_after_status_line(out)

  expect_equal(payload$total_violations, length(direct$all_diagnostics))
  expect_setequal(unlist(payload$modules), direct$modules)
})

test_that("a newly registered module automatically appears in the CLI's platform-scan output", {
  register_module(list(
    id = "test.cli_future_module", name = "Future CLI Module", version = "0.0.1",
    description = "Simulates adding a future module like SecurityTrace.",
    scan_fn = function(root, config) {
      new_diagnostic_set(list(new_diagnostic("test.rule", "info", "(test)", message = "hit")))
    },
    score_fn = function(diags) list(score = 42L, label = "OK", breakdown = list())
  ))
  on.exit(rtrace_env$platform_modules[["test.cli_future_module"]] <- NULL, add = TRUE)

  root <- local_project(c("f.R" = "x <- 1"))
  out <- testthat::capture_output(rtrace_cli(c("platform-scan", root, "--format", "json")))
  payload <- json_after_status_line(out)

  expect_true("test.cli_future_module" %in% unlist(payload$modules))
  expect_equal(payload$scores$test.cli_future_module$score, 42L)
})

test_that("rtrace_cli platform-scan --format dashboard writes an HTML report covering every module", {
  root <- local_project(c("f.R" = "x <- 1"))
  out_file <- withr::local_tempfile(fileext = ".html")

  out <- testthat::capture_output(
    status <- rtrace_cli(c("platform-scan", root, "--format", "dashboard", "--output", out_file))
  )
  expect_true(file.exists(out_file))
  html <- paste(readLines(out_file, warn = FALSE), collapse = "\n")
  expect_match(html, "Module Scores", fixed = TRUE)
  # One score "card" per registered module (regression check for Issue #1:
  # the dashboard used to render at most one module's score).
  expect_equal(lengths(regmatches(html, gregexpr('class="card-name"', html))), length(list_modules()))
})
