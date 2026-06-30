test_that("register_rule and get_rule round-trip", {
  rule <- Rule$new(
    id = "test.always",
    description = "Always fires once.",
    check_fn = function(context, params) {
      list(new_diagnostic("test.always", "info", "(test)", message = "hit"))
    }
  )
  register_rule(rule)
  on.exit(rtrace_env$rule_registry[["test.always"]] <- NULL, add = TRUE)

  expect_identical(get_rule("test.always"), rule)
  expect_true("test.always" %in% names(list_rules()))
})

test_that("register_rule warns when overwriting an existing id", {
  rule <- Rule$new("test.dup", "x", function(context, params) list())
  register_rule(rule)
  on.exit(rtrace_env$rule_registry[["test.dup"]] <- NULL, add = TRUE)
  expect_warning(register_rule(rule), "already registered")
})

test_that("run_rules only evaluates enabled rules", {
  hits <- 0
  rule <- Rule$new("test.counter", "x", function(context, params) {
    hits <<- hits + 1
    list()
  })
  register_rule(rule)
  on.exit(rtrace_env$rule_registry[["test.counter"]] <- NULL, add = TRUE)

  config <- new_config(rules = list(
    list(type = "test.counter", enabled = FALSE, severity = NA, params = list())
  ))
  context <- new_context(".", config, data.frame(), list(), list(package_imports = list(), layer_graph = list()))
  run_rules(context)
  expect_equal(hits, 0)
})

test_that("run_rules tags diagnostics with the configured severity, not the rule default", {
  rule <- Rule$new(
    "test.sev", "x", default_severity = "info",
    check_fn = function(context, params) list(new_diagnostic("test.sev", "info", "f", message = "m"))
  )
  register_rule(rule)
  on.exit(rtrace_env$rule_registry[["test.sev"]] <- NULL, add = TRUE)

  config <- new_config(rules = list(
    list(type = "test.sev", enabled = TRUE, severity = "error", params = list())
  ))
  context <- new_context(".", config, data.frame(), list(), list(package_imports = list(), layer_graph = list()))
  diags <- run_rules(context)
  expect_equal(diags$diagnostics[[1]]$severity, "error")
})

test_that("run_rules surfaces an unknown rule type as a diagnostic, not an error", {
  config <- new_config(rules = list(
    list(type = "no.such.rule", enabled = TRUE, severity = NA, params = list())
  ))
  context <- new_context(".", config, data.frame(), list(), list(package_imports = list(), layer_graph = list()))
  diags <- run_rules(context)
  expect_equal(diags$diagnostics[[1]]$rule_id, "rule-error")
})

test_that("run_rules captures a rule that errors during evaluation", {
  rule <- Rule$new("test.boom", "x", function(context, params) stop("kaboom"))
  register_rule(rule)
  on.exit(rtrace_env$rule_registry[["test.boom"]] <- NULL, add = TRUE)

  config <- new_config(rules = list(
    list(type = "test.boom", enabled = TRUE, severity = NA, params = list())
  ))
  context <- new_context(".", config, data.frame(), list(), list(package_imports = list(), layer_graph = list()))
  diags <- run_rules(context)
  expect_equal(diags$diagnostics[[1]]$rule_id, "rule-error")
  expect_match(diags$diagnostics[[1]]$message, "kaboom")
})

test_that("run_scan runs end-to-end over a project directory", {
  root <- local_project(c("f.R" = "setwd('/tmp')"))
  config <- new_config(rules = list(
    list(type = "antipattern.setwd", enabled = TRUE, severity = NA, params = list())
  ))
  diags <- run_scan(root, config)
  expect_length(diags, 1)
  expect_equal(diags$diagnostics[[1]]$rule_id, "antipattern.setwd")
})
