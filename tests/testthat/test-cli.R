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

test_that("rtrace_cli scan --cache writes a .rtrace_cache directory and scan still works", {
  root <- local_project(c("f.R" = "setwd('/tmp')"))
  writeLines(c(
    "version: 1",
    "rules:",
    "  - type: antipattern.setwd",
    "    severity: error"
  ), file.path(root, "rtrace.yml"))

  out <- testthat::capture_output(status <- rtrace_cli(c("scan", root, "--cache")))
  expect_equal(status, 1L)
  expect_match(out, "antipattern.setwd")
  expect_true(file.exists(cache_path(root)))
})

test_that("rtrace_cli scan without --cache never creates a .rtrace_cache directory", {
  root <- local_project(c("f.R" = "x <- 1"))
  testthat::capture_output(rtrace_cli(c("scan", root)))
  expect_false(file.exists(cache_path(root)))
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

test_that("rtrace_cli doctor reports a clean bill of health for a valid project", {
  root <- local_project(c("rtrace.yml" = "version: 1\nrules: []\n"))
  out <- testthat::capture_output(status <- rtrace_cli(c("doctor", root)))
  expect_equal(status, 0L)
  expect_match(out, "RTrace doctor")
  expect_match(out, "R version:")
  expect_match(out, "No problems found")
})

test_that("rtrace_cli doctor flags an invalid rtrace.yml and returns exit status 1", {
  root <- local_project(c("rtrace.yml" = "version: 1\nrules:\n  - type: not.a.real.rule\n"))
  out <- testthat::capture_output(status <- rtrace_cli(c("doctor", root)))
  expect_equal(status, 1L)
  expect_match(out, "\\[FAIL\\]")
  expect_match(out, "problem\\(s\\) found")
})

test_that("rtrace_cli doctor warns (not fails) when no rtrace.yml is present", {
  root <- local_project(list())
  out <- testthat::capture_output(status <- rtrace_cli(c("doctor", root)))
  expect_equal(status, 0L)
  expect_match(out, "\\[WARN\\] No rtrace.yml found")
})

test_that("rtrace_cli doctor reports an .Rproj file when present", {
  root <- local_project(c("myproj.Rproj" = "Version: 1.0"))
  out <- testthat::capture_output(status <- rtrace_cli(c("doctor", root)))
  expect_match(out, "RStudio Project detected \\(myproj.Rproj\\)")
})

test_that("rtrace_cli doctor reports cache state after a cached scan", {
  root <- local_project(c("f.R" = "x <- 1"))
  testthat::capture_output(rtrace_cli(c("scan", root, "--cache")))
  out <- testthat::capture_output(status <- rtrace_cli(c("doctor", root)))
  expect_match(out, "ast-cache.rds present \\(1 cached file")
})

test_that("rtrace_cli doctor fails cleanly for a nonexistent project directory", {
  out <- testthat::capture_output(status <- rtrace_cli(c("doctor", "/no/such/project/dir")))
  expect_equal(status, 1L)
  expect_match(out, "does not exist")
})

test_that("rtrace_cli benchmark reports phase and rule timings and always exits 0", {
  root <- local_project(c("f.R" = "setwd('/tmp')"))
  writeLines(c(
    "version: 1",
    "rules:",
    "  - type: antipattern.setwd",
    "    severity: error"
  ), file.path(root, "rtrace.yml"))

  out <- testthat::capture_output(status <- rtrace_cli(c("benchmark", root)))
  expect_equal(status, 0L)
  expect_match(out, "RTrace benchmark:")
  expect_match(out, "Phase timings:")
  expect_match(out, "file walk")
  expect_match(out, "parsing")
  expect_match(out, "dependency graph")
  expect_match(out, "antipattern.setwd")
})

test_that("rtrace_cli benchmark reports no rules to time when none are enabled", {
  root <- local_project(c("f.R" = "x <- 1", "rtrace.yml" = "version: 1\nrules: []\n"))
  out <- testthat::capture_output(status <- rtrace_cli(c("benchmark", root)))
  expect_equal(status, 0L)
  expect_match(out, "No enabled rules to time")
})

test_that("rtrace_cli benchmark still reports a timing for a rule that errors", {
  rule <- Rule$new("test.boom", "x", function(context, params) stop("kaboom"))
  register_rule(rule)
  on.exit(rtrace_env$rule_registry[["test.boom"]] <- NULL, add = TRUE)

  root <- local_project(c(
    "f.R" = "x <- 1",
    "rtrace.yml" = "version: 1\nrules:\n  - type: test.boom\n"
  ))
  out <- testthat::capture_output(status <- rtrace_cli(c("benchmark", root)))
  expect_equal(status, 0L)
  expect_match(out, "test.boom")
})

test_that("rtrace_cli benchmark supports --cache", {
  root <- local_project(c("f.R" = "x <- 1"))
  out <- testthat::capture_output(status <- rtrace_cli(c("benchmark", root, "--cache")))
  expect_equal(status, 0L)
  expect_true(file.exists(cache_path(root)))
})
