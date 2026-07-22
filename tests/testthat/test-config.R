test_that("default_config produces a valid configuration", {
  config <- default_config()
  expect_s3_class(config, "rtrace_config")
  expect_true(validate_config(config))
})

test_that("parse_config applies defaults for missing keys", {
  config <- parse_config(list(version = 1))
  expect_equal(config$version, 1L)
  expect_equal(config$layers, list())
  expect_equal(config$exclude, character(0))
  expect_equal(config$rules, list())
})

test_that("parse_config warns on unknown top-level keys", {
  expect_warning(parse_config(list(version = 1, bogus = "x")), "Ignoring unknown")
})

test_that("parse_config requires a `type` for every rule entry", {
  expect_error(parse_config(list(rules = list(list(severity = "error")))), "type")
})

test_that("parse_config defaults rule `enabled` to TRUE", {
  config <- parse_config(list(rules = list(list(type = "antipattern.setwd"))))
  expect_true(config$rules[[1]]$enabled)
})

test_that("validate_config rejects unknown rule types", {
  config <- new_config(rules = list(list(type = "not.a.real.rule", enabled = TRUE, severity = NA, params = list())))
  expect_error(validate_config(config), class = "rtrace_config_error")
})

test_that("validate_config rejects invalid severities", {
  config <- new_config(rules = list(list(type = "antipattern.setwd", enabled = TRUE, severity = "fatal", params = list())))
  expect_error(validate_config(config), "severity")
})

test_that("validate_config rejects unnamed layers", {
  config <- new_config(layers = list("R/**"))
  expect_error(validate_config(config), "layers")
})

test_that("read_config reads, parses, and validates a YAML file", {
  root <- local_project(c(
    "rtrace.yml" = paste(
      "version: 1",
      "project: demo",
      "rules:",
      "  - type: antipattern.setwd",
      "    severity: error",
      sep = "\n"
    )
  ))
  config <- read_config(file.path(root, "rtrace.yml"))
  expect_equal(config$project, "demo")
  expect_equal(config$rules[[1]]$type, "antipattern.setwd")
  expect_equal(config$rules[[1]]$severity, "error")
})

test_that("read_config errors on a missing file", {
  expect_error(read_config("/no/such/file/rtrace.yml"), "not found")
})

test_that("known_rule_types reflects the registered rules", {
  expect_true("antipattern.setwd" %in% known_rule_types())
  expect_true("complexity.cyclomatic" %in% known_rule_types())
})

# Regression test for Issue #11: domain-specific rules (reproducibility.*,
# datatrace.*, docstrace.*, packageqa.*) were excluded from
# known_rule_types(), so referencing one in rtrace.yml was a hard
# validate_config() error even though the domain engines run every
# registered rule of their prefix and treat a config entry as an opt-out
# override.
test_that("known_rule_types includes domain-specific rule types", {
  types <- known_rule_types()
  expect_true("reproducibility.externalDownload" %in% types)
  expect_true("datatrace.readError" %in% types)
  expect_true("docstrace.examplesQuality" %in% types)
  expect_true("packageqa.testCoverage" %in% types)
})

test_that("validate_config accepts a domain-specific rule type", {
  config <- new_config(rules = list(
    list(type = "reproducibility.externalDownload", enabled = FALSE,
         severity = NA, params = list())
  ))
  expect_true(validate_config(config))
})
