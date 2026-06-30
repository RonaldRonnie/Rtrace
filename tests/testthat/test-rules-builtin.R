scan_with_rule <- function(files, rule_type, params = list(), layers = list()) {
  root <- local_project(files)
  config <- new_config(
    layers = layers,
    rules = list(list(type = rule_type, enabled = TRUE, severity = NA, params = params))
  )
  run_scan(root, config)
}

test_that("structure.requiredDirs flags missing directories", {
  diags <- scan_with_rule(c("R/foo.R" = "1"), "structure.requiredDirs", params = list(dirs = c("R", "tests")))
  expect_equal(length(diags), 1)
  expect_equal(diags$diagnostics[[1]]$file, "tests")
})

test_that("structure.requiredDirs is silent when all directories exist", {
  diags <- scan_with_rule(c("R/foo.R" = "1", "tests/test-foo.R" = "1"), "structure.requiredDirs",
    params = list(dirs = c("R", "tests")))
  expect_length(diags, 0)
})

test_that("dependency.forbidden flags a configured forbidden edge", {
  diags <- scan_with_rule(
    c("analysis/a.R" = "source('shiny/b.R')", "shiny/b.R" = "1"),
    "dependency.forbidden",
    params = list(from = "analysis", to = "shiny"),
    layers = list(analysis = "analysis/**", shiny = "shiny/**")
  )
  expect_length(diags, 1)
  expect_equal(diags$diagnostics[[1]]$rule_id, "dependency.forbidden")
})

test_that("dependency.forbidden is silent when the edge does not exist", {
  diags <- scan_with_rule(
    c("analysis/a.R" = "1", "shiny/b.R" = "1"),
    "dependency.forbidden",
    params = list(from = "analysis", to = "shiny"),
    layers = list(analysis = "analysis/**", shiny = "shiny/**")
  )
  expect_length(diags, 0)
})

test_that("dependency.circular flags a cycle between layers", {
  diags <- scan_with_rule(
    c("a/x.R" = "source('b/y.R')", "b/y.R" = "source('a/x.R')"),
    "dependency.circular",
    layers = list(a = "a/**", b = "b/**")
  )
  expect_length(diags, 1)
  expect_match(diags$diagnostics[[1]]$message, "a -> b -> a")
})

test_that("complexity.cyclomatic flags functions above the threshold", {
  code <- paste(
    "f <- function(x) {", "if (x > 0) { if (x > 1) { for (i in 1:x) { 1 } } }", "}",
    sep = "\n"
  )
  diags <- scan_with_rule(c("f.R" = code), "complexity.cyclomatic", params = list(max = 2))
  expect_length(diags, 1)
})

test_that("complexity.functionLength flags long functions", {
  body_lines <- paste(rep("  1", 20), collapse = "\n")
  code <- paste0("f <- function() {\n", body_lines, "\n}")
  diags <- scan_with_rule(c("f.R" = code), "complexity.functionLength", params = list(max = 5))
  expect_length(diags, 1)
})

test_that("complexity.fileLength flags long files", {
  code <- paste(rep("x <- 1", 30), collapse = "\n")
  diags <- scan_with_rule(c("f.R" = code), "complexity.fileLength", params = list(max = 10))
  expect_length(diags, 1)
})

test_that("antipattern.globalAssign flags <<- usage", {
  diags <- scan_with_rule(c("f.R" = "f <- function() { x <<- 1 }"), "antipattern.globalAssign")
  expect_length(diags, 1)
})

test_that("antipattern.assign flags assign() calls", {
  diags <- scan_with_rule(c("f.R" = "assign('x', 1)"), "antipattern.assign")
  expect_length(diags, 1)
})

test_that("antipattern.setwd flags setwd() calls", {
  diags <- scan_with_rule(c("f.R" = "setwd('/tmp')"), "antipattern.setwd")
  expect_length(diags, 1)
})

test_that("antipattern.hardcodedPath flags absolute local paths", {
  diags <- scan_with_rule(c("f.R" = "p <- '/home/user/data.csv'"), "antipattern.hardcodedPath")
  expect_length(diags, 1)
})

test_that("antipattern.hardcodedPath ignores ordinary strings", {
  diags <- scan_with_rule(c("f.R" = "p <- 'data.csv'"), "antipattern.hardcodedPath")
  expect_length(diags, 0)
})

test_that("documentation.missing flags undocumented top-level functions", {
  diags <- scan_with_rule(c("f.R" = "foo <- function() 1"), "documentation.missing")
  expect_length(diags, 1)
})

test_that("documentation.missing is silent when a roxygen block is present", {
  code <- paste("#' Title", "#'", "#' @return one", "foo <- function() 1", sep = "\n")
  diags <- scan_with_rule(c("f.R" = code), "documentation.missing")
  expect_length(diags, 0)
})

test_that("documentation.missing ignores dot-prefixed internal functions", {
  diags <- scan_with_rule(c("f.R" = ".foo <- function() 1"), "documentation.missing")
  expect_length(diags, 0)
})

test_that("testing.missingTests flags a function never referenced under tests/", {
  diags <- scan_with_rule(c(
    "R/foo.R" = "foo <- function() 1\nbar <- function() 2",
    "tests/testthat/test-foo.R" = "test_that('foo works', { expect_equal(foo(), 1) })"
  ), "testing.missingTests")
  expect_length(diags, 1)
  expect_match(diags$diagnostics[[1]]$message, "bar")
})

test_that("testing.missingTests is silent when the project has no tests/ directory", {
  diags <- scan_with_rule(c("R/foo.R" = "foo <- function() 1"), "testing.missingTests")
  expect_length(diags, 0)
})

test_that("testing.missingTests ignores dot-prefixed internal functions", {
  diags <- scan_with_rule(c(
    "R/foo.R" = ".internal <- function() 1",
    "tests/testthat/test-foo.R" = "1 + 1"
  ), "testing.missingTests")
  expect_length(diags, 0)
})

test_that("testing.missingTests does not flag functions defined inside tests/ itself", {
  diags <- scan_with_rule(c(
    "tests/testthat/helper.R" = "make_fixture <- function() 1"
  ), "testing.missingTests")
  expect_length(diags, 0)
})

test_that("package.deprecatedApi is a no-op with no configured functions", {
  diags <- scan_with_rule(c("f.R" = "reshape2::melt(df)"), "package.deprecatedApi")
  expect_length(diags, 0)
})

test_that("package.deprecatedApi flags a configured bare function name", {
  diags <- scan_with_rule(
    c("f.R" = "x <- old_fn(1)"),
    "package.deprecatedApi",
    params = list(functions = list(old_fn = "new_fn"))
  )
  expect_length(diags, 1)
  expect_match(diags$diagnostics[[1]]$suggestion, "new_fn")
})

test_that("package.deprecatedApi flags a configured namespace-qualified call", {
  diags <- scan_with_rule(
    c("f.R" = "x <- reshape2::melt(df)\ny <- dplyr::filter(df)"),
    "package.deprecatedApi",
    params = list(functions = list("reshape2::melt" = "tidyr::pivot_longer()"))
  )
  expect_length(diags, 1)
  expect_match(diags$diagnostics[[1]]$message, "reshape2::melt")
})

test_that("package.deprecatedApi does not cross-match a bare name against an unrelated package", {
  diags <- scan_with_rule(
    c("f.R" = "x <- dplyr::melt(df)"),
    "package.deprecatedApi",
    params = list(functions = list("reshape2::melt" = "tidyr::pivot_longer()"))
  )
  expect_length(diags, 0)
})

test_that("ecosystem.shinyStructure is silent when the project does not use shiny", {
  diags <- scan_with_rule(c("R/foo.R" = "x <- 1"), "ecosystem.shinyStructure")
  expect_length(diags, 0)
})

test_that("ecosystem.shinyStructure is silent for a valid single app.R entrypoint", {
  diags <- scan_with_rule(c(
    "app.R" = "library(shiny)\nshinyApp(ui = fluidPage(), server = function(input, output) {})"
  ), "ecosystem.shinyStructure")
  expect_length(diags, 0)
})

test_that("ecosystem.shinyStructure is silent for a valid ui.R + server.R pair", {
  diags <- scan_with_rule(c(
    "ui.R" = "library(shiny)\nfluidPage()",
    "server.R" = "function(input, output) {}"
  ), "ecosystem.shinyStructure")
  expect_length(diags, 0)
})

test_that("ecosystem.shinyStructure flags a directory with both app.R and ui.R/server.R", {
  diags <- scan_with_rule(c(
    "app.R" = "library(shiny)",
    "ui.R" = "fluidPage()",
    "server.R" = "function(input, output) {}"
  ), "ecosystem.shinyStructure")
  expect_length(diags, 1)
  expect_match(diags$diagnostics[[1]]$message, "both an app.R and a ui.R/server.R pair")
})

test_that("ecosystem.shinyStructure flags shiny usage with no recognized entrypoint", {
  diags <- scan_with_rule(c(
    "R/helpers.R" = "library(shiny)\nf <- function() 1"
  ), "ecosystem.shinyStructure")
  expect_length(diags, 1)
  expect_match(diags$diagnostics[[1]]$message, "no app.R or ui.R\\+server.R entrypoint")
})

test_that("ecosystem.shinyStructure does not flag a ui.R/server.R pair split across directories", {
  diags <- scan_with_rule(c(
    "ui.R" = "library(shiny)\nfluidPage()",
    "sub/server.R" = "function(input, output) {}"
  ), "ecosystem.shinyStructure")
  expect_length(diags, 1)
  expect_match(diags$diagnostics[[1]]$message, "no app.R or ui.R\\+server.R entrypoint")
})
