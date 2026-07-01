test_that("build_context assembles files, asts, and a dependency graph", {
  root <- local_project(c(
    "R/foo.R" = "foo <- function() 1"
  ))
  context <- build_context(root, default_config())
  expect_s3_class(context, "rtrace_context")
  expect_equal(nrow(context$files), 1)
  fwd <- function(p) gsub("\\\\", "/", normalizePath(p, mustWork = FALSE))
  expect_true(fwd(file.path(root, "R/foo.R")) %in% vapply(names(context$asts), fwd, character(1)))
})

test_that("relative_path converts an absolute path back to project-relative", {
  root <- local_project(c("R/foo.R" = "1"))
  context <- build_context(root, default_config())
  abs <- context$files$path[1]
  expect_equal(relative_path(context, abs), "R/foo.R")
})
