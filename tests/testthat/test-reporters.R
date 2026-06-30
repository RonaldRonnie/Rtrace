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

test_that("html_escape escapes the five HTML special characters", {
  expect_equal(html_escape("<a href=\"x\">Tom & Jerry's</a>"),
               "&lt;a href=&quot;x&quot;&gt;Tom &amp; Jerry&#39;s&lt;/a&gt;")
})

test_that("reporter_html embeds escaped diagnostic content and a summary", {
  set <- new_diagnostic_set(list(
    new_diagnostic("rule.a", "error", "<script>evil.R</script>", message = "bad <b>thing</b>",
                    suggestion = "fix & verify")
  ))
  html <- reporter_html(set)
  expect_match(html, "<!DOCTYPE html>", fixed = TRUE)
  expect_match(html, "1 error\\(s\\)")
  expect_no_match(html, "<script>evil.R</script>", fixed = TRUE)
  expect_match(html, "&lt;script&gt;evil.R&lt;/script&gt;", fixed = TRUE)
  expect_match(html, "bad &lt;b&gt;thing&lt;/b&gt;", fixed = TRUE)
  expect_match(html, "fix &amp; verify", fixed = TRUE)
})

test_that("reporter_html handles an empty diagnostic set", {
  html <- reporter_html(new_diagnostic_set(list()))
  expect_match(html, "No issues found")
  expect_match(html, "0 error\\(s\\)")
})

test_that("reporter_csv produces a header row plus one row per diagnostic", {
  csv <- reporter_csv(sample_diagnostics())
  lines <- strsplit(csv, "\n")[[1]]
  expect_equal(length(lines), 3)
  expect_match(lines[1], "rule_id")
  parsed <- utils::read.csv(text = csv, stringsAsFactors = FALSE)
  expect_equal(nrow(parsed), 2)
  expect_equal(parsed$rule_id, c("rule.a", "rule.b"))
})

test_that("reporter_csv quotes fields containing commas", {
  set <- new_diagnostic_set(list(new_diagnostic("r", "error", "f.R", message = "a, b, c")))
  csv <- reporter_csv(set)
  parsed <- utils::read.csv(text = csv, stringsAsFactors = FALSE)
  expect_equal(parsed$message, "a, b, c")
})

test_that("reporter_xml produces well-formed, schema-conformant XML", {
  skip_if_not_installed("xml2")
  xml <- reporter_xml(sample_diagnostics())
  doc <- xml2::read_xml(xml)
  expect_equal(xml2::xml_name(doc), "rtrace-report")

  summary_node <- xml2::xml_find_first(doc, "//summary")
  expect_equal(xml2::xml_attr(summary_node, "error"), "1")
  expect_equal(xml2::xml_attr(summary_node, "warning"), "1")

  diag_nodes <- xml2::xml_find_all(doc, "//diagnostic")
  expect_equal(length(diag_nodes), 2)
  expect_equal(xml2::xml_attr(diag_nodes[[1]], "ruleId"), "rule.a")
  expect_equal(xml2::xml_text(xml2::xml_find_first(diag_nodes[[1]], "message")), "bad thing")
  expect_equal(xml2::xml_text(xml2::xml_find_first(diag_nodes[[1]], "suggestion")), "fix it")
})

test_that("reporter_xml omits line/column attributes and suggestion element when absent", {
  skip_if_not_installed("xml2")
  set <- new_diagnostic_set(list(new_diagnostic("r", "warning", "f.R", message = "m")))
  doc <- xml2::read_xml(reporter_xml(set))
  node <- xml2::xml_find_first(doc, "//diagnostic")
  expect_true(is.na(xml2::xml_attr(node, "line")))
  expect_equal(length(xml2::xml_find_all(node, "suggestion")), 0)
})

test_that("reporter_xml round-trips special characters safely", {
  skip_if_not_installed("xml2")
  set <- new_diagnostic_set(list(new_diagnostic("r", "error", "f.R", message = "a < b & c > d")))
  doc <- xml2::read_xml(reporter_xml(set))
  expect_equal(xml2::xml_text(xml2::xml_find_first(doc, "//message")), "a < b & c > d")
})
