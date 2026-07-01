test_that("run_reproducibility_scan returns expected structure", {
  root <- local_project(list("R/analysis.R" = "x <- 1"))
  result <- run_reproducibility_scan(root)
  expect_named(result, c("diagnostics", "score"))
  expect_s3_class(result$diagnostics, "rtrace_diagnostic_set")
  expect_s3_class(result$score, "trace_score")
  expect_equal(result$score$module_id, "reproducibility")
})

test_that("reproducibility.renvLock fires when renv.lock is absent", {
  root <- local_project(list("R/analysis.R" = "library(dplyr)\nx <- 1"))
  result <- run_reproducibility_scan(root)
  diag_ids <- vapply(result$diagnostics$diagnostics, function(d) d$rule_id, character(1))
  expect_true("reproducibility.renvLock" %in% diag_ids)
})

test_that("reproducibility.renvLock is silent when renv.lock exists", {
  root <- local_project(list(
    "R/analysis.R" = "library(dplyr)\nx <- 1",
    "renv.lock"    = '{"R":{"Version":"4.3.0"},"Packages":{}}'
  ))
  result <- run_reproducibility_scan(root)
  diag_ids <- vapply(result$diagnostics$diagnostics, function(d) d$rule_id, character(1))
  expect_false("reproducibility.renvLock" %in% diag_ids)
})

test_that("reproducibility.randomSeed fires when set.seed is absent with random calls", {
  root <- local_project(list(
    "R/sim.R" = paste(
      "n <- 1000",
      "samples <- rnorm(n)",
      "result  <- sample(1:100, 10)",
      sep = "\n"
    )
  ))
  result <- run_reproducibility_scan(root)
  diag_ids <- vapply(result$diagnostics$diagnostics, function(d) d$rule_id, character(1))
  expect_true("reproducibility.randomSeed" %in% diag_ids)
})

test_that("reproducibility.randomSeed is silent when set.seed is present", {
  root <- local_project(list(
    "R/sim.R" = paste(
      "set.seed(42)",
      "samples <- rnorm(1000)",
      sep = "\n"
    )
  ))
  result <- run_reproducibility_scan(root)
  diag_ids <- vapply(result$diagnostics$diagnostics, function(d) d$rule_id, character(1))
  expect_false("reproducibility.randomSeed" %in% diag_ids)
})

test_that("reproducibility.externalDownload fires for download.file calls", {
  root <- local_project(list(
    "R/get_data.R" = paste(
      "url <- 'https://example.com/data.csv'",
      "download.file(url, 'data/raw.csv')",
      sep = "\n"
    )
  ))
  result <- run_reproducibility_scan(root)
  diag_ids <- vapply(result$diagnostics$diagnostics, function(d) d$rule_id, character(1))
  expect_true("reproducibility.externalDownload" %in% diag_ids)
})

test_that("reproducibility.portablePaths fires for bare filenames without path separators", {
  # Rule flags bare filenames (no / separator) passed to I/O functions — they
  # depend on the current working directory and break on other machines.
  root <- local_project(list(
    "R/analysis.R" = 'data <- read.csv("analysis_data.csv")'
  ))
  result <- run_reproducibility_scan(root)
  diag_ids <- vapply(result$diagnostics$diagnostics, function(d) d$rule_id, character(1))
  expect_true("reproducibility.portablePaths" %in% diag_ids)
})

test_that("reproducibility.portablePaths is silent for paths with directory separators", {
  root <- local_project(list(
    "R/analysis.R" = 'data <- read.csv("data/cohort.csv")'
  ))
  result <- run_reproducibility_scan(root)
  diag_ids <- vapply(result$diagnostics$diagnostics, function(d) d$rule_id, character(1))
  expect_false("reproducibility.portablePaths" %in% diag_ids)
})

test_that("reproducibility.environmentVariables fires when Sys.getenv is used", {
  root <- local_project(list(
    "R/config.R" = 'api_key <- Sys.getenv("MY_API_KEY")'
  ))
  result <- run_reproducibility_scan(root)
  diag_ids <- vapply(result$diagnostics$diagnostics, function(d) d$rule_id, character(1))
  expect_true("reproducibility.environmentVariables" %in% diag_ids)
})

test_that("reproducibility.tempFiles fires when tempfile() is used without cleanup", {
  root <- local_project(list(
    "R/process.R" = paste(
      "tmp <- tempfile()",
      "write.csv(data, tmp)",
      "result <- process(tmp)",
      sep = "\n"
    )
  ))
  result <- run_reproducibility_scan(root)
  diag_ids <- vapply(result$diagnostics$diagnostics, function(d) d$rule_id, character(1))
  expect_true("reproducibility.tempFiles" %in% diag_ids)
})

test_that("reproducibility.sessionInfo fires when sessionInfo is absent from analysis project", {
  # Must import an analysis package so the rule activates
  root <- local_project(list(
    "R/analysis.R" = paste(
      "library(ggplot2)",
      "model <- lm(y ~ x, data = df)",
      "summary(model)",
      sep = "\n"
    )
  ))
  result <- run_reproducibility_scan(root)
  diag_ids <- vapply(result$diagnostics$diagnostics, function(d) d$rule_id, character(1))
  expect_true("reproducibility.sessionInfo" %in% diag_ids)
})

test_that("reproducibility.sessionInfo is silent when sessionInfo() is called", {
  root <- local_project(list(
    "R/analysis.R" = paste(
      "library(ggplot2)",
      "model <- lm(y ~ x, data = df)",
      "sessionInfo()",
      sep = "\n"
    )
  ))
  result <- run_reproducibility_scan(root)
  diag_ids <- vapply(result$diagnostics$diagnostics, function(d) d$rule_id, character(1))
  expect_false("reproducibility.sessionInfo" %in% diag_ids)
})

test_that("run_reproducibility_scan score is 0-100", {
  root <- local_project(list(
    "R/bad.R" = paste(
      "download.file('http://example.com/data.csv', '/tmp/data.csv')",
      "data <- read.csv('/home/user/hardcoded/path.csv')",
      "set.seed(NULL)",
      "rnorm(100)",
      sep = "\n"
    )
  ))
  result <- run_reproducibility_scan(root)
  expect_gte(result$score$score, 0L)
  expect_lte(result$score$score, 100L)
})

test_that("reproducibility.reproducibleReports fires when Rmd has no seed/opts", {
  root <- local_project(list(
    "analysis/report.Rmd" = paste(
      "---",
      "title: My Report",
      "---",
      "",
      "```{r}",
      "plot(1:10)",
      "```",
      sep = "\n"
    )
  ))
  result <- run_reproducibility_scan(root)
  diag_ids <- vapply(result$diagnostics$diagnostics, function(d) d$rule_id, character(1))
  expect_true("reproducibility.reproducibleReports" %in% diag_ids)
})

test_that("run_reproducibility_scan handles a reasonably clean project", {
  root <- local_project(list(
    "R/analysis.R" = paste(
      "set.seed(123)",
      "data <- read.csv('data/cohort.csv')",
      "model <- lm(y ~ x, data = data)",
      "sessionInfo()",
      sep = "\n"
    ),
    "renv.lock" = '{"R":{"Version":"4.3.0"},"Packages":{}}',
    "data/cohort.csv" = "x,y\n1,2\n3,4"
  ))
  result <- run_reproducibility_scan(root)
  expect_gte(result$score$score, 60L)
})
