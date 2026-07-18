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

  pr  <- build_api_router(allowed_roots = root)
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

  pr  <- build_api_router(allowed_roots = root)
  res <- call_mock_plumber_request(
    pr, "POST", "/scan",
    body_raw = charToRaw(jsonlite::toJSON(list(root = root), auto_unbox = TRUE)),
    headers  = list(HTTP_CONTENT_TYPE = "application/json")
  )
  body <- jsonlite::fromJSON(res$body, simplifyVector = TRUE)

  expect_equal(body$score$value, direct$scores[["rtrace"]]$score)
  expect_equal(sum(unlist(body$summary)), length(direct$all_diagnostics))
})

# --- Issue #4: authentication -----------------------------------------------

test_that("requests are rejected without a token when one is configured", {
  testthat::skip_if_not_installed("plumber")

  root <- local_project(c("f.R" = "x <- 1"))
  pr   <- build_api_router(token = "s3cr3t", allowed_roots = root)

  res <- call_mock_plumber_request(pr, "GET", "/health")

  expect_equal(res$status, 401L)
})

test_that("requests are rejected with a wrong token", {
  testthat::skip_if_not_installed("plumber")

  root <- local_project(c("f.R" = "x <- 1"))
  pr   <- build_api_router(token = "s3cr3t", allowed_roots = root)

  res <- call_mock_plumber_request(
    pr, "GET", "/health",
    headers = list(HTTP_AUTHORIZATION = "Bearer wrong-token")
  )

  expect_equal(res$status, 401L)
})

test_that("requests succeed with the correct bearer token", {
  testthat::skip_if_not_installed("plumber")

  root <- local_project(c("f.R" = "x <- 1"))
  pr   <- build_api_router(token = "s3cr3t", allowed_roots = root)

  res <- call_mock_plumber_request(
    pr, "GET", "/health",
    headers = list(HTTP_AUTHORIZATION = "Bearer s3cr3t")
  )

  expect_equal(res$status, 200L)
})

test_that("auth is a no-op when no token is configured", {
  testthat::skip_if_not_installed("plumber")

  pr  <- build_api_router(token = "", allowed_roots = getwd())
  res <- call_mock_plumber_request(pr, "GET", "/health")

  expect_equal(res$status, 200L)
})

test_that("start_api() refuses a non-loopback host without a token", {
  testthat::skip_if_not_installed("plumber")

  expect_error(
    start_api(host = "0.0.0.0", token = ""),
    "Refusing to bind"
  )
})

test_that("start_api() does not require a token on loopback hosts", {
  testthat::skip_if_not_installed("plumber")

  # No error should be raised before the (blocking) router$run() call --
  # i.e. the loopback exemption from the token requirement is honored. We
  # can't call $run() in a test, so intercept it via a mocked router.
  local_mocked_bindings(
    build_api_router = function(...) {
      list(run = function(...) invisible(NULL))
    }
  )

  expect_no_error(start_api(host = "127.0.0.1", token = ""))
  expect_no_error(start_api(host = "localhost", token = ""))
})

# --- Issue #4: path containment ---------------------------------------------

test_that("a root outside allowed_roots is rejected with 403", {
  testthat::skip_if_not_installed("plumber")

  project_root <- local_project(c("f.R" = "x <- 1"))
  outside_root <- local_project(c("g.R" = "y <- 2"))  # sibling tempdir, not a descendant

  pr  <- build_api_router(allowed_roots = project_root)
  res <- call_mock_plumber_request(
    pr, "POST", "/scan",
    body_raw = charToRaw(jsonlite::toJSON(list(root = outside_root), auto_unbox = TRUE)),
    headers  = list(HTTP_CONTENT_TYPE = "application/json")
  )

  expect_equal(res$status, 403L)
})

test_that("a path-traversal root ('..') resolving outside allowed_roots is rejected", {
  testthat::skip_if_not_installed("plumber")

  project_root <- local_project(c("sub/f.R" = "x <- 1"))
  traversal    <- file.path(project_root, "..")  # escapes to the parent tempdir

  pr  <- build_api_router(allowed_roots = project_root)
  res <- call_mock_plumber_request(
    pr, "POST", "/scan",
    body_raw = charToRaw(jsonlite::toJSON(list(root = traversal), auto_unbox = TRUE)),
    headers  = list(HTTP_CONTENT_TYPE = "application/json")
  )

  expect_equal(res$status, 403L)
})

test_that("a descendant of allowed_roots is accepted", {
  testthat::skip_if_not_installed("plumber")

  project_root <- local_project(c("sub/f.R" = "x <- 1"))
  descendant   <- file.path(project_root, "sub")

  pr  <- build_api_router(allowed_roots = project_root)
  res <- call_mock_plumber_request(
    pr, "POST", "/scan",
    body_raw = charToRaw(jsonlite::toJSON(list(root = descendant), auto_unbox = TRUE)),
    headers  = list(HTTP_CONTENT_TYPE = "application/json")
  )

  expect_equal(res$status, 200L)
})

test_that("a nonexistent root is rejected with 400, not 403", {
  testthat::skip_if_not_installed("plumber")

  project_root <- local_project(c("f.R" = "x <- 1"))
  missing_root <- file.path(project_root, "does-not-exist")

  pr  <- build_api_router(allowed_roots = project_root)
  res <- call_mock_plumber_request(
    pr, "POST", "/scan",
    body_raw = charToRaw(jsonlite::toJSON(list(root = missing_root), auto_unbox = TRUE)),
    headers  = list(HTTP_CONTENT_TYPE = "application/json")
  )

  expect_equal(res$status, 400L)
})

test_that("GET /report/html enforces path containment on the query-string root", {
  testthat::skip_if_not_installed("plumber")

  project_root <- local_project(c("f.R" = "x <- 1"))
  outside_root <- local_project(c("g.R" = "y <- 2"))

  pr  <- build_api_router(allowed_roots = project_root)
  res <- call_mock_plumber_request(
    pr, "GET", "/report/html",
    query = paste0("root=", utils::URLencode(outside_root, reserved = TRUE))
  )

  expect_equal(res$status, 403L)
})

# --- secure_compare() / resolve_scan_root() unit tests ----------------------

test_that("secure_compare() matches identical strings and rejects mismatches", {
  expect_true(secure_compare("abc123", "abc123"))
  expect_false(secure_compare("abc123", "abc124"))
  expect_false(secure_compare("abc123", "abc12"))
  expect_false(secure_compare("abc123", ""))
  expect_true(secure_compare("", ""))
})

test_that("resolve_scan_root() reports distinct statuses for missing vs. disallowed paths", {
  project_root <- local_project(c("f.R" = "x <- 1"))

  ok <- resolve_scan_root(project_root, project_root)
  expect_true(ok$ok)
  expect_equal(ok$root, normalizePath(project_root, winslash = "/", mustWork = TRUE))

  missing <- resolve_scan_root(file.path(project_root, "nope"), project_root)
  expect_false(missing$ok)
  expect_equal(missing$status, 400L)

  outside_root <- local_project(c("g.R" = "y <- 2"))
  disallowed <- resolve_scan_root(outside_root, project_root)
  expect_false(disallowed$ok)
  expect_equal(disallowed$status, 403L)
})
