#' Build a minimal Rook-compliant mock request for `pr$call()`.
#'
#' plumber's body-parsing filter runs for every request, regardless of verb,
#' and unconditionally calls `req$rook.input$read()` / `$read_lines()` /
#' `$rewind()` -- so even a GET request needs a working `rook.input`. `req`
#' itself must be an environment (not a list): plumber populates
#' `req$postBody` via `delayedAssign(..., assign.env = req)`, which requires
#' an environment target.
mock_plumber_request <- function(method, path, query = "", body_raw = raw(0), headers = list()) {
  con <- rawConnection(body_raw, "rb")
  rook_input <- list(
    read       = function(...) readBin(con, "raw", n = max(length(body_raw), 1)),
    read_lines = function(...) readLines(con, warn = FALSE),
    rewind     = function() seek(con, 0)
  )

  req <- new.env()
  req$REQUEST_METHOD <- method
  req$PATH_INFO       <- path
  req$QUERY_STRING    <- query
  req$rook.input      <- rook_input
  req$.mock_con       <- con  # closed by call_mock_plumber_request()
  for (nm in names(headers)) assign(nm, headers[[nm]], envir = req)
  req
}

#' Call a plumber router with a mock request, closing the mock connection afterwards.
call_mock_plumber_request <- function(pr, ...) {
  req <- mock_plumber_request(...)
  on.exit(close(req$.mock_con), add = TRUE)
  pr$call(req)
}

test_that("build_api_router() builds successfully", {
  testthat::skip_if_not_installed("plumber")

  pr <- build_api_router()
  expect_s3_class(pr, "Plumber")
})

test_that("GET /health reports every registered module", {
  testthat::skip_if_not_installed("plumber")

  pr  <- build_api_router()
  res <- call_mock_plumber_request(pr, "GET", "/health")
  body <- jsonlite::fromJSON(res$body, simplifyVector = TRUE)

  # Regression test for Issue #1: /health used to report only "rtrace"
  # because it was the only registered module.
  expect_setequal(body$modules, names(list_modules()))
})

test_that("GET /modules returns every registered platform module", {
  testthat::skip_if_not_installed("plumber")

  pr  <- build_api_router()
  res <- call_mock_plumber_request(pr, "GET", "/modules")
  body <- jsonlite::fromJSON(res$body, simplifyVector = FALSE)
  ids  <- vapply(body, function(m) m$id[[1]], character(1))

  expect_setequal(ids, names(list_modules()))
})

test_that("POST /scan/full returns identical module results to platform_scan()", {
  # Regression test for Issue #1: /scan/full iterates the module registry via
  # platform_scan(), so once every built-in module is registered, the REST
  # API and the CLI's platform-scan command must agree exactly.
  testthat::skip_if_not_installed("plumber")

  root   <- local_project(c("f.R" = "setwd('/tmp')"))
  direct <- platform_scan(root)

  pr  <- build_api_router()
  res <- call_mock_plumber_request(
    pr, "POST", "/scan/full",
    body_raw = charToRaw(jsonlite::toJSON(list(root = root), auto_unbox = TRUE)),
    headers  = list(HTTP_CONTENT_TYPE = "application/json")
  )
  body <- jsonlite::fromJSON(res$body, simplifyVector = TRUE)

  expect_setequal(body$modules, direct$modules)
  expect_equal(body$total_violations, length(direct$all_diagnostics))
})

test_that("POST /scan (single-module) delegates to platform_scan() and matches its rtrace-only result", {
  testthat::skip_if_not_installed("plumber")

  root   <- local_project(c("f.R" = "setwd('/tmp')"))
  direct <- platform_scan(root, modules = "rtrace")

  pr  <- build_api_router()
  res <- call_mock_plumber_request(
    pr, "POST", "/scan",
    body_raw = charToRaw(jsonlite::toJSON(list(root = root), auto_unbox = TRUE)),
    headers  = list(HTTP_CONTENT_TYPE = "application/json")
  )
  body <- jsonlite::fromJSON(res$body, simplifyVector = TRUE)

  expect_equal(body$score$value, direct$scores[["rtrace"]]$score)
  expect_equal(sum(unlist(body$summary)), length(direct$all_diagnostics))
})
