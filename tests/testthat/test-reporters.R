sample_diagnostics <- function() {
  new_diagnostic_set(list(
    new_diagnostic("rule.a", "error", "f.R", line = 1, column = 2, message = "bad thing",
                    suggestion = "fix it"),
    new_diagnostic("rule.b", "warning", "g.R", message = "another thing")
  ))
}

test_that("reporter_console writes a colorless summary and returns it invisibly", {
  out <- testthat::capture_output(result <- reporter_console(sample_diagnostics(), use_color = FALSE))
  expect_match(out, "bad thing")
  expect_match(out, "1 error\\(s\\), 1 warning\\(s\\), 0 info")
  expect_match(result, "bad thing")
})

test_that("reporter_console handles an empty diagnostic set", {
  out <- testthat::capture_output(reporter_console(new_diagnostic_set(list()), use_color = FALSE))
  expect_match(out, "0 error\\(s\\), 0 warning\\(s\\), 0 info")
})

test_that("reporter_json produces valid, schema-conformant JSON", {
  json <- reporter_json(sample_diagnostics())
  parsed <- jsonlite::fromJSON(json, simplifyVector = FALSE)
  expect_equal(parsed$schema_version, 1)
  expect_equal(length(parsed$diagnostics), 2)
  expect_equal(parsed$diagnostics[[1]]$rule_id, "rule.a")
  expect_equal(parsed$summary$error, 1)
})

test_that("reporter_json represents missing line/column as JSON null", {
  json <- reporter_json(sample_diagnostics())
  parsed <- jsonlite::fromJSON(json, simplifyVector = FALSE)
  expect_null(parsed$diagnostics[[2]]$line)
})

test_that("reporter_markdown renders a table with one row per diagnostic", {
  md <- reporter_markdown(sample_diagnostics())
  expect_match(md, "# RTrace Scan Report")
  expect_match(md, "rule.a")
  expect_match(md, "rule.b")
  expect_equal(length(gregexpr("\n", md)[[1]]) >= 2, TRUE)
})

test_that("reporter_markdown handles an empty diagnostic set", {
  md <- reporter_markdown(new_diagnostic_set(list()))
  expect_match(md, "No issues found")
})

test_that("reporter_markdown escapes pipe characters in messages", {
  set <- new_diagnostic_set(list(new_diagnostic("r", "error", "f.R", message = "a | b")))
  md <- reporter_markdown(set)
  expect_match(md, "a \\\\\\| b")
})

test_that("reporter_sarif produces a valid SARIF 2.1.0 log", {
  sarif <- reporter_sarif(sample_diagnostics())
  parsed <- jsonlite::fromJSON(sarif, simplifyVector = FALSE)

  expect_equal(parsed$version, "2.1.0")
  expect_equal(parsed$runs[[1]]$tool$driver$name, "RTrace")

  results <- parsed$runs[[1]]$results
  expect_equal(length(results), 2)
  expect_equal(results[[1]]$ruleId, "rule.a")
  expect_equal(results[[1]]$level, "error")
  expect_equal(results[[2]]$level, "warning")
})

test_that("reporter_sarif maps info severity to the SARIF 'note' level", {
  set <- new_diagnostic_set(list(new_diagnostic("r", "info", "f.R", message = "m")))
  parsed <- jsonlite::fromJSON(reporter_sarif(set), simplifyVector = FALSE)
  expect_equal(parsed$runs[[1]]$results[[1]]$level, "note")
})

test_that("reporter_sarif includes a region only when a line number is known", {
  set <- new_diagnostic_set(list(
    new_diagnostic("r", "error", "f.R", line = 5, column = 2, message = "m"),
    new_diagnostic("r", "error", "g.R", message = "m")
  ))
  parsed <- jsonlite::fromJSON(reporter_sarif(set), simplifyVector = FALSE)
  loc1 <- parsed$runs[[1]]$results[[1]]$locations[[1]]$physicalLocation
  loc2 <- parsed$runs[[1]]$results[[2]]$locations[[1]]$physicalLocation
  expect_equal(loc1$region$startLine, 5)
  expect_null(loc2$region)
})

test_that("reporter_sarif lists each distinct rule once in the tool driver", {
  set <- new_diagnostic_set(list(
    new_diagnostic("antipattern.setwd", "error", "f.R", message = "m1"),
    new_diagnostic("antipattern.setwd", "error", "g.R", message = "m2")
  ))
  parsed <- jsonlite::fromJSON(reporter_sarif(set), simplifyVector = FALSE)
  rule_ids <- vapply(parsed$runs[[1]]$tool$driver$rules, function(r) r$id, character(1))
  expect_equal(rule_ids, "antipattern.setwd")
})
