BUILTIN_MODULE_IDS <- c("rtrace", "reproducibility", "docstrace", "packageqa", "datatrace")

test_that("package startup registers every built-in module", {
  # Regression test for Issue #1: only "rtrace" used to be registered in
  # .onLoad(), so platform_scan() silently ran a single module.
  expect_setequal(names(list_modules()), BUILTIN_MODULE_IDS)
})

test_that("registered module count is correct", {
  expect_length(list_modules(), length(BUILTIN_MODULE_IDS))
})

test_that("registration order is stable and execution order is deterministic", {
  expect_identical(names(list_modules()), BUILTIN_MODULE_IDS)

  root <- local_project(c("f.R" = "x <- 1"))
  first  <- platform_scan(root)
  second <- platform_scan(root)
  expect_identical(first$modules, BUILTIN_MODULE_IDS)
  expect_identical(second$modules, BUILTIN_MODULE_IDS)
})

test_that("platform_scan() executes every registered module", {
  root <- local_project(c("f.R" = "x <- 1"))
  result <- platform_scan(root)

  expect_s3_class(result, "trace_platform_result")
  expect_setequal(result$modules, names(list_modules()))
  expect_setequal(names(result$results), names(list_modules()))
  expect_setequal(names(result$scores), names(list_modules()))
})

test_that("register_module requires all mandatory fields", {
  expect_error(
    register_module(list(id = "incomplete")),
    "missing required field"
  )
})

test_that("register_module warns and overwrites on duplicate id", {
  mod <- list(id = "test.module", name = "Test", version = "0.0.1", description = "x")
  register_module(mod)
  on.exit(rtrace_env$platform_modules[["test.module"]] <- NULL, add = TRUE)

  expect_warning(register_module(mod), "already registered")
  expect_identical(get_module("test.module")$id, "test.module")
})

test_that("adding a new module automatically appears in platform_scan() with no orchestration changes", {
  hits <- 0
  register_module(list(
    id = "test.future_module", name = "Future Module", version = "0.0.1",
    description = "A hypothetical future module (e.g. SecurityTrace).",
    scan_fn = function(root, config) {
      hits <<- hits + 1
      new_diagnostic_set(list(new_diagnostic("test.rule", "info", "(test)", message = "hit")))
    },
    score_fn = function(diags) list(score = 99L, label = "Great", breakdown = list())
  ))
  on.exit(rtrace_env$platform_modules[["test.future_module"]] <- NULL, add = TRUE)

  root <- local_project(c("f.R" = "x <- 1"))
  result <- platform_scan(root)

  expect_true("test.future_module" %in% result$modules)
  expect_equal(hits, 1)
  expect_length(result$results[["test.future_module"]], 1)
  expect_equal(result$scores[["test.future_module"]]$score, 99L)
})

test_that("a failing module's scan_fn does not abort the platform scan", {
  register_module(list(
    id = "test.boom_module", name = "Boom Module", version = "0.0.1",
    description = "Always errors.",
    scan_fn = function(root, config) stop("kaboom"),
    score_fn = function(diags) list(score = 0L, label = "Error", breakdown = list())
  ))
  on.exit(rtrace_env$platform_modules[["test.boom_module"]] <- NULL, add = TRUE)

  root <- local_project(c("f.R" = "x <- 1"))
  expect_warning(
    result <- platform_scan(root),
    "kaboom"
  )

  expect_true("test.boom_module" %in% result$modules)
  expect_length(result$results[["test.boom_module"]], 0)
  # Other modules still ran despite the failure.
  expect_true("rtrace" %in% result$modules)
  expect_gte(length(result$results), length(BUILTIN_MODULE_IDS))
})

test_that("a failing module's score_fn does not abort the platform scan", {
  register_module(list(
    id = "test.boom_score", name = "Boom Score", version = "0.0.1",
    description = "Scan succeeds, scoring errors.",
    scan_fn = function(root, config) new_diagnostic_set(),
    score_fn = function(diags) stop("score kaboom")
  ))
  on.exit(rtrace_env$platform_modules[["test.boom_score"]] <- NULL, add = TRUE)

  root <- local_project(c("f.R" = "x <- 1"))
  result <- platform_scan(root)
  expect_equal(result$scores[["test.boom_score"]]$score, 0L)
})

test_that("platform_scan() warns and returns an empty result when no modules are registered", {
  saved <- rtrace_env$platform_modules
  rtrace_env$platform_modules <- list()
  on.exit(rtrace_env$platform_modules <- saved, add = TRUE)

  root <- local_project(c("f.R" = "x <- 1"))
  expect_warning(result <- platform_scan(root), "no platform modules are registered")
  expect_length(result$modules, 0)
  expect_length(result$all_diagnostics, 0)
})

test_that("platform_scan(modules=) filters to the requested subset", {
  root <- local_project(c("f.R" = "x <- 1"))
  result <- platform_scan(root, modules = "rtrace")
  expect_identical(result$modules, "rtrace")
})

test_that("platform_scan(modules=) warns on unknown module ids", {
  root <- local_project(c("f.R" = "x <- 1"))
  expect_warning(platform_scan(root, modules = "no.such.module"), "Unknown module")
})
