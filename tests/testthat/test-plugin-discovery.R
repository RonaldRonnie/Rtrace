test_that("plugin_allowlist() defaults to empty when no option or env var is set", {
  withr::local_options(rtrace.plugin.allowlist = NULL)
  withr::local_envvar(RTRACE_PLUGIN_ALLOWLIST = "")
  expect_equal(plugin_allowlist(), character(0))
})

test_that("plugin_allowlist() reads the rtrace.plugin.allowlist option", {
  withr::local_options(rtrace.plugin.allowlist = c("pkgA", "pkgB"))
  expect_equal(plugin_allowlist(), c("pkgA", "pkgB"))
})

test_that("plugin_allowlist() reads RTRACE_PLUGIN_ALLOWLIST when the option is unset", {
  withr::local_options(rtrace.plugin.allowlist = NULL)
  withr::local_envvar(RTRACE_PLUGIN_ALLOWLIST = "pkgA, pkgB")
  expect_equal(plugin_allowlist(), c("pkgA", "pkgB"))
})

# Regression test for Issue #13: a package merely self-declaring
# Config/rtrace/plugin: true in DESCRIPTION must not be loaded (and hence
# must not get its .onLoad() executed) unless explicitly allowlisted.
test_that("discover_plugins() does not load a self-declared plugin that is not allowlisted", {
  lib     <- withr::local_tempdir()
  pkg_dir <- file.path(lib, "notarealpkg")
  dir.create(pkg_dir)
  writeLines(
    c("Package: notarealpkg", "Version: 0.1.0", "Config/rtrace/plugin: true"),
    file.path(pkg_dir, "DESCRIPTION")
  )

  loaded <- discover_plugins(lib_paths = lib, allowlist = character(0))
  expect_false("notarealpkg" %in% loaded)
})

test_that("discover_plugins() skips packages without the Config/rtrace/plugin field regardless of allowlist", {
  lib     <- withr::local_tempdir()
  pkg_dir <- file.path(lib, "unrelatedpkg")
  dir.create(pkg_dir)
  writeLines(c("Package: unrelatedpkg", "Version: 0.1.0"), file.path(pkg_dir, "DESCRIPTION"))

  loaded <- discover_plugins(lib_paths = lib, allowlist = "unrelatedpkg")
  expect_false("unrelatedpkg" %in% loaded)
})
