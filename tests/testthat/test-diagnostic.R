test_that("new_diagnostic validates inputs", {
  d <- new_diagnostic("rule.x", "error", "foo.R", line = 1, column = 2, message = "bad")
  expect_s3_class(d, "rtrace_diagnostic")
  expect_equal(d$severity, "error")

  expect_error(new_diagnostic(rule_id = 1, file = "f", message = "m"), "rule_id")
  expect_error(new_diagnostic(rule_id = "x", file = "f", message = NA_character_), "message")
  expect_error(new_diagnostic(rule_id = "x", file = "f", message = "m", severity = "fatal"))
})

test_that("format.rtrace_diagnostic includes location and rule id", {
  d <- new_diagnostic("rule.x", "warning", "foo.R", line = 3, column = 5, message = "bad thing")
  txt <- format(d)
  expect_match(txt, "foo.R:3:5")
  expect_match(txt, "rule.x")
  expect_match(txt, "WARNING")
})

test_that("new_diagnostic_set rejects non-diagnostic elements", {
  expect_error(new_diagnostic_set(list("not a diagnostic")))
  expect_length(new_diagnostic_set(list()), 0)
})

test_that("c.rtrace_diagnostic_set combines multiple sets", {
  d1 <- new_diagnostic("a", "error", "f1.R", message = "m1")
  d2 <- new_diagnostic("b", "warning", "f2.R", message = "m2")
  combined <- c(new_diagnostic_set(list(d1)), new_diagnostic_set(list(d2)))
  expect_length(combined, 2)
})

test_that("filter_diagnostics filters by severity, rule_id, and file", {
  d1 <- new_diagnostic("a", "error", "f1.R", message = "m1")
  d2 <- new_diagnostic("b", "warning", "f2.R", message = "m2")
  set <- new_diagnostic_set(list(d1, d2))

  expect_length(filter_diagnostics(set, severity = "error"), 1)
  expect_length(filter_diagnostics(set, rule_id = "b"), 1)
  expect_length(filter_diagnostics(set, file = "f1.R"), 1)
  expect_length(filter_diagnostics(set, severity = "info"), 0)
})

test_that("summary.rtrace_diagnostic_set counts by severity", {
  set <- new_diagnostic_set(list(
    new_diagnostic("a", "error", "f.R", message = "m"),
    new_diagnostic("b", "error", "f.R", message = "m"),
    new_diagnostic("c", "warning", "f.R", message = "m")
  ))
  s <- summary(set)
  expect_equal(unname(s["error"]), 2L)
  expect_equal(unname(s["warning"]), 1L)
  expect_equal(unname(s["info"]), 0L)
})

test_that("summary handles an empty set", {
  s <- summary(new_diagnostic_set(list()))
  expect_equal(unname(s), c(0L, 0L, 0L))
})

test_that("exit_status reflects severity threshold", {
  errs <- new_diagnostic_set(list(new_diagnostic("a", "error", "f.R", message = "m")))
  warns <- new_diagnostic_set(list(new_diagnostic("a", "warning", "f.R", message = "m")))
  clean <- new_diagnostic_set(list())

  expect_equal(exit_status(errs), 1L)
  expect_equal(exit_status(warns, fail_on = "error"), 0L)
  expect_equal(exit_status(warns, fail_on = "warning"), 1L)
  expect_equal(exit_status(clean), 0L)
})

test_that("as.data.frame.rtrace_diagnostic_set produces one row per diagnostic", {
  set <- new_diagnostic_set(list(
    new_diagnostic("a", "error", "f.R", line = 1, message = "m1", suggestion = "fix it"),
    new_diagnostic("b", "warning", "g.R", message = "m2")
  ))
  df <- as.data.frame(set)
  expect_equal(nrow(df), 2)
  expect_equal(df$rule_id, c("a", "b"))
  expect_equal(df$suggestion, c("fix it", NA_character_))
})

test_that("as.data.frame handles an empty set", {
  df <- as.data.frame(new_diagnostic_set(list()))
  expect_equal(nrow(df), 0)
  expect_named(df, c("rule_id", "severity", "file", "line", "column", "message", "suggestion", "doc_url"))
})
