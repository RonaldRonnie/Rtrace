test_that("glob_to_regex translates *, **, and ? correctly", {
  expect_true(grepl(glob_to_regex("R/*.R"), "R/foo.R"))
  expect_false(grepl(glob_to_regex("R/*.R"), "R/sub/foo.R"))
  expect_true(grepl(glob_to_regex("R/**"), "R/sub/foo.R"))
  expect_true(grepl(glob_to_regex("a?.R"), "ab.R"))
  expect_false(grepl(glob_to_regex("a?.R"), "abc.R"))
})

test_that("glob_to_regex escapes regex metacharacters", {
  expect_true(grepl(glob_to_regex("*.Rcheck/**"), "pkg.Rcheck/00install.log"))
  expect_false(grepl(glob_to_regex("*.Rcheck/**"), "pkgXRcheck/00install.log"))
})

test_that("path_matches_any_glob matches across multiple patterns", {
  expect_true(path_matches_any_glob("renv/activate.R", c("man/**", "renv/**")))
  expect_false(path_matches_any_glob("R/foo.R", c("man/**", "renv/**")))
  expect_false(path_matches_any_glob("R/foo.R", character(0)))
})

test_that("scan_files discovers .R files and excludes defaults", {
  root <- local_project(c(
    "R/foo.R" = "foo <- function() 1",
    "renv/activate.R" = "# renv",
    "man/foo.Rd" = "not r code",
    "analysis/script.R" = "1 + 1"
  ))
  files <- scan_files(root, default_config())
  expect_setequal(files$rel_path, c("R/foo.R", "analysis/script.R"))
})

test_that("scan_files assigns files to configured layers via longest-match", {
  root <- local_project(c(
    "analysis/core/script.R" = "1",
    "analysis/script.R" = "1"
  ))
  config <- new_config(layers = list(
    analysis = "analysis/**",
    analysis_core = "analysis/core/**"
  ))
  files <- scan_files(root, config)
  layer_for <- stats::setNames(files$layer, files$rel_path)
  expect_equal(layer_for[["analysis/core/script.R"]], "analysis_core")
  expect_equal(layer_for[["analysis/script.R"]], "analysis")
})

test_that("scan_files assigns (unassigned) when no layer matches", {
  root <- local_project(c("scripts/run.R" = "1"))
  files <- scan_files(root, new_config(layers = list(analysis = "analysis/**")))
  expect_equal(files$layer, "(unassigned)")
})

test_that("scan_files returns an empty data frame for a directory with no R files", {
  root <- local_project(c("README.md" = "hello"))
  files <- scan_files(root, default_config())
  expect_equal(nrow(files), 0)
})
