test_that("aggregate_scores() computes a simple equal-weighted average", {
  sc <- list(
    rtrace    = new_trace_score(90, module_id = "rtrace"),
    docstrace = new_trace_score(80, module_id = "docstrace")
  )

  result <- aggregate_scores(sc)

  expect_equal(result$score, 85L)
  expect_equal(result$module_id, "platform")
})

test_that("aggregate_scores() applies custom weights", {
  sc <- list(
    rtrace    = new_trace_score(90, module_id = "rtrace"),
    docstrace = new_trace_score(80, module_id = "docstrace")
  )

  result <- aggregate_scores(sc, weights = c(rtrace = 3, docstrace = 1))

  expect_equal(result$score, 88L)
})

# Regression test for Issue #6: weights[[id]] on a partial (named) weights
# vector raised "subscript out of bounds" for any module id missing from
# weights, instead of falling back to the documented default weight of 1.0.
test_that("aggregate_scores() falls back to weight 1.0 for modules missing from weights", {
  sc <- list(
    rtrace    = new_trace_score(90, module_id = "rtrace"),
    docstrace = new_trace_score(80, module_id = "docstrace")
  )

  expect_no_error(result <- aggregate_scores(sc, weights = c(rtrace = 2)))

  # rtrace: 90 * 2 = 180, docstrace: 80 * 1 = 80, total weight = 3
  expect_equal(result$score, as.integer(round((180 + 80) / 3)))
  expect_equal(unname(result$breakdown$weights[["docstrace"]]), 1.0)
})

test_that("aggregate_scores() returns a perfect score for an empty scores list", {
  result <- aggregate_scores(list())
  expect_equal(result$score, 100L)
})
