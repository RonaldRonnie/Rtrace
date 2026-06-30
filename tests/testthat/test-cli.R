test_that("parse_cli_args separates command, flags, and positionals", {
  parsed <- parse_cli_args(c("scan", "myproj", "--format", "json", "--output", "out.json"))
  expect_equal(parsed$command, "scan")
  expect_equal(parsed$positional, "myproj")
  expect_equal(parsed$options$format, "json")
  expect_equal(parsed$options$output, "out.json")
})

test_that("parse_cli_args treats a flag with no following value as boolean TRUE", {
  parsed <- parse_cli_args(c("init", "--force"))
  expect_true(parsed$options$force)
})

test_that("parse_cli_args supports --flag=value syntax", {
  parsed <- parse_cli_args(c("scan", "--format=markdown"))
  expect_equal(parsed$options$format, "markdown")
})

test_that("parse_cli_args handles an empty argument vector", {
  parsed <- parse_cli_args(character(0))
  expect_true(is.na(parsed$command))
  expect_length(parsed$positional, 0)
})

test_that("rtrace_cli help/version/list-rules/describe-rule commands succeed", {
  run <- function(...) {
    status <- NA_integer_
    out <- testthat::capture_output(status <- rtrace_cli(c(...)))
    list(status = status, out = out)
  }

  expect_equal(run(character(0))$status, 0L)
  expect_equal(run("version")$status, 0L)
  expect_equal(run("list-rules")$status, 0L)
  expect_equal(run("describe-rule", "antipattern.setwd")$status, 0L)
})

test_that("rtrace_cli describe-rule returns 1 for an unknown rule", {
  status <- testthat::capture_output(s <- rtrace_cli(c("describe-rule", "no.such.rule")))
  expect_equal(s, 1L)
})

test_that("rtrace_cli returns 1 and prints usage for an unknown command", {
  out <- testthat::capture_output(status <- rtrace_cli("frobnicate"))
  expect_equal(status, 1L)
  expect_match(out, "Unknown command")
})

test_that("rtrace_cli scan command runs end-to-end and reflects exit status", {
  root <- local_project(c("f.R" = "setwd('/tmp')"))
  writeLines(c(
    "version: 1",
    "rules:",
    "  - type: antipattern.setwd",
    "    severity: error"
  ), file.path(root, "rtrace.yml"))

  out <- testthat::capture_output(status <- rtrace_cli(c("scan", root)))
  expect_equal(status, 1L)
  expect_match(out, "antipattern.setwd")
})

test_that("rtrace_cli scan --format json writes parseable JSON to stdout", {
  root <- local_project(c("f.R" = "x <- 1"))
  out <- testthat::capture_output(status <- rtrace_cli(c("scan", root, "--format", "json")))
  parsed <- jsonlite::fromJSON(out, simplifyVector = FALSE)
  expect_equal(parsed$schema_version, 1)
})

test_that("rtrace_cli scan rejects an unknown --format", {
  root <- local_project(c("f.R" = "x <- 1"))
  out <- testthat::capture_output(status <- rtrace_cli(c("scan", root, "--format", "yaml")))
  expect_equal(status, 1L)
  expect_match(out, "Unknown --format")
})

test_that("rtrace_cli init writes a starter rtrace.yml and refuses to overwrite without --force", {
  root <- local_project(list())
  out1 <- testthat::capture_output(s1 <- rtrace_cli(c("init", root)))
  expect_equal(s1, 0L)
  expect_true(file.exists(file.path(root, "rtrace.yml")))

  out2 <- testthat::capture_output(s2 <- rtrace_cli(c("init", root)))
  expect_equal(s2, 1L)
  expect_match(out2, "already exists")

  out3 <- testthat::capture_output(s3 <- rtrace_cli(c("init", root, "--force")))
  expect_equal(s3, 0L)
})

test_that("rtrace_cli validate reports invalid configuration", {
  root <- local_project(c("rtrace.yml" = "version: 1\nrules:\n  - type: not.a.real.rule\n"))
  out <- testthat::capture_output(status <- rtrace_cli(c("validate", root)))
  expect_equal(status, 1L)
  expect_match(out, "INVALID")
})

test_that("rtrace_cli config prints the resolved configuration", {
  root <- local_project(list())
  out <- testthat::capture_output(status <- rtrace_cli(c("config", root)))
  expect_equal(status, 0L)
  expect_match(out, "rtrace_config")
})
