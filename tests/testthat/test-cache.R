test_that("cache_path points at .rtrace_cache/ast-cache.rds under the project root", {
  expect_equal(cache_path("/proj"), "/proj/.rtrace_cache/ast-cache.rds")
})

test_that("read_ast_cache returns an empty list when no cache file exists", {
  root <- local_project(list())
  expect_equal(read_ast_cache(root), list())
})

test_that("read_ast_cache returns an empty list for a corrupt cache file, not an error", {
  root <- local_project(list())
  dir.create(file.path(root, ".rtrace_cache"))
  writeLines("not a valid RDS file", file.path(root, ".rtrace_cache", "ast-cache.rds"))
  expect_equal(read_ast_cache(root), list())
})

test_that("write_ast_cache then read_ast_cache round-trips", {
  root <- local_project(list())
  cache <- list(a = list(hash = "deadbeef", ast = "placeholder"))
  write_ast_cache(root, cache)
  expect_equal(read_ast_cache(root), cache)
})

test_that("file_hash changes when file content changes and is stable otherwise", {
  root <- local_project(c("f.R" = "x <- 1"))
  path <- file.path(root, "f.R")
  h1 <- file_hash(path)
  h2 <- file_hash(path)
  expect_equal(h1, h2)

  writeLines("x <- 2", path)
  h3 <- file_hash(path)
  expect_false(identical(h1, h3))
})

test_that("file_hash returns NA for a nonexistent file", {
  expect_true(is.na(file_hash("/no/such/file.R")))
})

test_that("parse_files_cached with use_cache = FALSE never touches the cache file", {
  root <- local_project(c("f.R" = "x <- 1"))
  parse_files_cached(file.path(root, "f.R"), root, use_cache = FALSE)
  expect_false(file.exists(cache_path(root)))
})

test_that("parse_files_cached writes a cache file on first run with use_cache = TRUE", {
  root <- local_project(c("f.R" = "x <- 1"))
  path <- file.path(root, "f.R")
  parse_files_cached(path, root, use_cache = TRUE)
  expect_true(file.exists(cache_path(root)))

  cache <- read_ast_cache(root)
  expect_equal(names(cache), path)
  expect_s3_class(cache[[path]]$ast, "rtrace_file_ast")
})

test_that("parse_files_cached reuses a cached AST object when the hash matches", {
  root <- local_project(c("f.R" = "x <- 1"))
  path <- file.path(root, "f.R")

  sentinel_ast <- structure(list(path = path, expr = NULL, parse_data = NULL, lines = "SENTINEL", error = NULL),
                             class = "rtrace_file_ast")
  write_ast_cache(root, stats::setNames(list(list(hash = file_hash(path), ast = sentinel_ast)), path))

  asts <- parse_files_cached(path, root, use_cache = TRUE)
  expect_identical(asts[[path]]$lines, "SENTINEL")
})

test_that("parse_files_cached re-parses when the cached hash no longer matches", {
  root <- local_project(c("f.R" = "x <- 1"))
  path <- file.path(root, "f.R")

  stale_ast <- structure(list(path = path, expr = NULL, parse_data = NULL, lines = "STALE", error = NULL),
                          class = "rtrace_file_ast")
  write_ast_cache(root, stats::setNames(list(list(hash = "not-the-real-hash", ast = stale_ast)), path))

  asts <- parse_files_cached(path, root, use_cache = TRUE)
  expect_false(identical(asts[[path]]$lines, "STALE"))
  expect_equal(asts[[path]]$lines, "x <- 1")
})

test_that("parse_files_cached prunes cache entries for files no longer scanned", {
  root <- local_project(c("a.R" = "x <- 1", "b.R" = "y <- 2"))
  paths <- file.path(root, c("a.R", "b.R"))
  parse_files_cached(paths, root, use_cache = TRUE)
  expect_equal(length(read_ast_cache(root)), 2)

  # Re-run with only one file: the other's cache entry should be dropped.
  parse_files_cached(paths[1], root, use_cache = TRUE)
  expect_equal(names(read_ast_cache(root)), paths[1])
})

test_that("run_scan with use_cache = TRUE produces identical diagnostics to use_cache = FALSE", {
  root <- local_project(c("f.R" = "setwd('/tmp')"))
  config <- new_config(rules = list(
    list(type = "antipattern.setwd", enabled = TRUE, severity = NA, params = list())
  ))
  uncached <- run_scan(root, config, use_cache = FALSE)
  cached <- run_scan(root, config, use_cache = TRUE)
  expect_equal(summary(uncached), summary(cached))
})

test_that("run_scan with use_cache = TRUE picks up a change on a subsequent scan", {
  root <- local_project(c("f.R" = "x <- 1"))
  config <- new_config(rules = list(
    list(type = "antipattern.setwd", enabled = TRUE, severity = NA, params = list())
  ))
  expect_length(run_scan(root, config, use_cache = TRUE), 0)

  writeLines("setwd('/tmp')", file.path(root, "f.R"))
  expect_length(run_scan(root, config, use_cache = TRUE), 1)
})
