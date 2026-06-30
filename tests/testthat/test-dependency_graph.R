test_that("extract_package_imports finds library/require/:: usage", {
  root <- local_project(c("f.R" = paste(
    "library(dplyr)",
    "require(ggplot2)",
    "x <- purrr::map(1:3, identity)",
    sep = "\n"
  )))
  ast <- parse_file(file.path(root, "f.R"))
  pkgs <- extract_package_imports(ast)
  expect_setequal(pkgs, c("dplyr", "ggplot2", "purrr"))
})

test_that("extract_source_targets resolves project-root-relative paths first", {
  root <- local_project(c(
    "analysis/run.R" = "source('shiny/helpers.R')",
    "shiny/helpers.R" = "1"
  ))
  ast <- parse_file(file.path(root, "analysis/run.R"))
  targets <- extract_source_targets(ast, base_dir = file.path(root, "analysis"), root = root)
  expect_equal(targets, normalizePath(file.path(root, "shiny/helpers.R")))
})

test_that("extract_source_targets falls back to the sourcing file's directory", {
  root <- local_project(c(
    "analysis/run.R" = "source('helper.R')",
    "analysis/helper.R" = "1"
  ))
  ast <- parse_file(file.path(root, "analysis/run.R"))
  targets <- extract_source_targets(ast, base_dir = file.path(root, "analysis"), root = root)
  expect_equal(targets, normalizePath(file.path(root, "analysis/helper.R")))
})

test_that("extract_source_targets ignores dynamically-constructed paths", {
  root <- local_project(c("f.R" = "source(file.path('a', 'b.R'))"))
  ast <- parse_file(file.path(root, "f.R"))
  expect_length(extract_source_targets(ast, base_dir = root, root = root), 0)
})

test_that("build_dependency_graph builds a layer-level edge from source() calls", {
  root <- local_project(c(
    "analysis/run.R" = "source('shiny/helpers.R')",
    "shiny/helpers.R" = "1"
  ))
  config <- new_config(layers = list(analysis = "analysis/**", shiny = "shiny/**"))
  files <- scan_files(root, config)
  asts <- stats::setNames(lapply(files$path, parse_file), files$path)
  graph <- build_dependency_graph(files, asts, root = root)
  expect_equal(graph$layer_graph$analysis, "shiny")
})

test_that("find_cycles detects a simple two-node cycle", {
  graph <- list(a = "b", b = "a")
  cycles <- find_cycles(graph)
  expect_length(cycles, 1)
})

test_that("find_cycles returns no cycles for an acyclic graph", {
  graph <- list(a = "b", b = "c", c = character(0))
  expect_length(find_cycles(graph), 0)
})

test_that("find_cycles de-duplicates rotations of the same cycle", {
  graph <- list(a = "b", b = "c", c = "a")
  cycles <- find_cycles(graph)
  expect_length(cycles, 1)
})

test_that("find_cycles handles an empty graph", {
  expect_length(find_cycles(list()), 0)
})
