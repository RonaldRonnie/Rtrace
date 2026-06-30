test_that("the research-pipeline example trips every built-in rule", {
  example_dir <- system.file("examples", "research-pipeline", package = "RTrace")
  if (!nzchar(example_dir)) {
    example_dir <- testthat::test_path("..", "..", "inst", "examples", "research-pipeline")
  }
  skip_if_not(dir.exists(example_dir), "example project not found")

  config <- read_config(file.path(example_dir, "rtrace.yml"))
  diags <- run_scan(example_dir, config)

  rule_ids <- vapply(diags$diagnostics, function(d) d$rule_id, character(1))

  expect_true(all(known_rule_types() %in% rule_ids))
  expect_equal(exit_status(diags), 1L)

  s <- summary(diags)
  expect_true(s[["error"]] >= 3)
  expect_true(s[["warning"]] >= 6)
  expect_true(s[["info"]] >= 2)
})

test_that("R/utils.R in the example project triggers no diagnostics on its own", {
  example_dir <- system.file("examples", "research-pipeline", package = "RTrace")
  if (!nzchar(example_dir)) {
    example_dir <- testthat::test_path("..", "..", "inst", "examples", "research-pipeline")
  }
  skip_if_not(dir.exists(example_dir), "example project not found")

  config <- read_config(file.path(example_dir, "rtrace.yml"))
  diags <- run_scan(example_dir, config)
  utils_diags <- filter_diagnostics(diags, file = "R/utils.R")
  expect_length(utils_diags, 0)
})
