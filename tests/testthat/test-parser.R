test_that("parse_file parses valid R source", {
  root <- local_project(c("ok.R" = "x <- 1\ny <- x + 1"))
  ast <- parse_file(file.path(root, "ok.R"))
  expect_s3_class(ast, "rtrace_file_ast")
  expect_null(ast$error)
  expect_false(is.null(ast$expr))
  expect_equal(ast_line_count(ast), 2)
})

test_that("parse_file captures syntax errors instead of raising", {
  root <- local_project(c("bad.R" = "x <- function( {"))
  ast <- parse_file(file.path(root, "bad.R"))
  expect_s3_class(ast, "rtrace_file_ast")
  expect_false(is.null(ast$error))
  expect_null(ast$expr)
})

test_that("find_calls locates calls to a named function", {
  root <- local_project(c("f.R" = "setwd('/tmp')\nx <- 1\nsetwd('/var')"))
  ast <- parse_file(file.path(root, "f.R"))
  hits <- find_calls(ast, "setwd")
  expect_equal(nrow(hits), 2)
  expect_equal(hits$line1, c(1, 3))
})

test_that("find_calls returns zero rows when there are no matches", {
  root <- local_project(c("f.R" = "x <- 1"))
  ast <- parse_file(file.path(root, "f.R"))
  expect_equal(nrow(find_calls(ast, "setwd")), 0)
})

test_that("find_superassignments locates <<- usage", {
  root <- local_project(c("f.R" = "f <- function() {\n  x <<- 1\n}"))
  ast <- parse_file(file.path(root, "f.R"))
  hits <- find_superassignments(ast)
  expect_equal(nrow(hits), 1)
  expect_equal(hits$line1, 2)
})

test_that("top_level_functions reports name and accurate line span", {
  root <- local_project(c("f.R" = paste(
    "foo <- function(x) {",
    "  x + 1",
    "}",
    "",
    "bar <- 1",
    sep = "\n"
  )))
  ast <- parse_file(file.path(root, "f.R"))
  fns <- top_level_functions(ast)
  expect_length(fns, 1)
  expect_equal(fns[[1]]$name, "foo")
  expect_equal(fns[[1]]$line1, 1)
  expect_equal(fns[[1]]$line2, 3)
  expect_equal(fns[[1]]$n_lines, 3)
})

test_that("top_level_functions ignores non-function assignments", {
  root <- local_project(c("f.R" = "x <- 1\ny <- 2"))
  ast <- parse_file(file.path(root, "f.R"))
  expect_length(top_level_functions(ast), 0)
})

test_that("cyclomatic_complexity counts decision points plus one", {
  f <- function(x) {
    if (x > 0) {
      1
    } else {
      2
    }
  }
  expect_equal(cyclomatic_complexity(body(f)), 2)

  g <- function(x) {
    1
  }
  expect_equal(cyclomatic_complexity(body(g)), 1)

  h <- function(x) {
    if (x > 0 && x < 10) {
      for (i in 1:x) {
        if (i %% 2 == 0) 1 else 2
      }
    }
  }
  # base(1) + if + && + for + if = 5
  expect_equal(cyclomatic_complexity(body(h)), 5)
})

test_that("cyclomatic_complexity counts switch branches", {
  f <- function(x) {
    switch(x, a = 1, b = 2, c = 3)
  }
  # base(1) + 3 branches = 4
  expect_equal(cyclomatic_complexity(body(f)), 4)
})

test_that("find_qualified_calls locates pkg::fn call sites", {
  root <- local_project(c("f.R" = "x <- reshape2::melt(df)\ny <- dplyr::filter(df)"))
  ast <- parse_file(file.path(root, "f.R"))
  hits <- find_qualified_calls(ast, "reshape2", "melt")
  expect_equal(nrow(hits), 1)
  expect_equal(hits$line1, 1)
})

test_that("find_qualified_calls does not match a different package with the same function name", {
  root <- local_project(c("f.R" = "x <- dplyr::melt(df)"))
  ast <- parse_file(file.path(root, "f.R"))
  expect_equal(nrow(find_qualified_calls(ast, "reshape2", "melt")), 0)
})

test_that("find_qualified_calls handles ::: as well as ::", {
  root <- local_project(c("f.R" = "x <- pkg:::internal_fn()"))
  ast <- parse_file(file.path(root, "f.R"))
  expect_equal(nrow(find_qualified_calls(ast, "pkg", "internal_fn")), 1)
})
