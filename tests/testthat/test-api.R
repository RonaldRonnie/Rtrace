# NOTE: `POST /scan` and `POST /scan/full` are not exercised here via a
# simulated HTTP request. Both handlers are thin wrappers that call
# platform_scan() directly and return its result (see R/api.R) -- they
# contain no scanning logic of their own. That shared logic is already
# covered exhaustively by test-platform.R (module registration,
# platform_scan() behavior) and test-cli-platform.R (CLI/API agreement via
# platform_scan()). Simulating plumber's internal Rook request-body parsing
# for a POST body would test plumber's HTTP plumbing, not RTrace's, and its
# internals are not part of plumber's stable public API.

test_that("build_api_router() builds successfully", {
  testthat::skip_if_not_installed("plumber")

  pr <- build_api_router()
  expect_s3_class(pr, "Plumber")
})

test_that("GET /modules returns every registered platform module", {
  testthat::skip_if_not_installed("plumber")

  pr  <- build_api_router()
  req <- list(REQUEST_METHOD = "GET", PATH_INFO = "/modules", QUERY_STRING = "", HTTP_ACCEPT = "application/json")
  res <- pr$call(req)

  body <- jsonlite::fromJSON(rawToChar(res$body), simplifyVector = FALSE)
  ids  <- vapply(body, function(m) m$id, character(1))

  # Regression test for Issue #1: /health and /modules used to report only
  # "rtrace" because it was the only registered module.
  expect_setequal(ids, names(list_modules()))
})

test_that("GET /health reports every registered module", {
  testthat::skip_if_not_installed("plumber")

  pr  <- build_api_router()
  req <- list(REQUEST_METHOD = "GET", PATH_INFO = "/health", QUERY_STRING = "", HTTP_ACCEPT = "application/json")
  res <- pr$call(req)

  body <- jsonlite::fromJSON(rawToChar(res$body), simplifyVector = FALSE)
  expect_setequal(unlist(body$modules), names(list_modules()))
})
