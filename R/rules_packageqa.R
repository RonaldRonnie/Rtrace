#' Package QA rules
#'
#' Rules for evaluating R package metadata completeness and convention
#' compliance. All are prefixed `packageqa.*` and run through the Package
#' QA engine.
#'
#' @name packageqa-rules
NULL

# ---------------------------------------------------------------------------
# packageqa.descriptionComplete
# ---------------------------------------------------------------------------

rule_packageqa_description_complete <- function() {
  required_fields <- c("Package", "Title", "Version", "Authors@R",
                        "Description", "License", "Encoding")
  recommended_fields <- c("URL", "BugReports")

  packageqa_rule(
    id               = "packageqa.descriptionComplete",
    description      = "Flags missing required or recommended DESCRIPTION fields.",
    default_severity = "warning",
    default_params   = list(),
    packageqa_fn = function(root, params) {
      desc_path <- file.path(root, "DESCRIPTION")
      if (!file.exists(desc_path)) return(list())

      desc  <- parse_description(desc_path)
      diags <- list()

      for (field in required_fields) {
        if (is.null(desc[[field]]) || !nzchar(trimws(desc[[field]] %||% ""))) {
          diags[[length(diags) + 1]] <- new_diagnostic(
            rule_id    = "packageqa.descriptionComplete",
            severity   = "warning",
            file       = "DESCRIPTION",
            message    = sprintf("Required DESCRIPTION field '%s' is missing or empty.", field),
            suggestion = sprintf("Add a '%s:' field to DESCRIPTION.", field)
          )
        }
      }

      for (field in recommended_fields) {
        if (is.null(desc[[field]]) || !nzchar(trimws(desc[[field]] %||% ""))) {
          diags[[length(diags) + 1]] <- new_diagnostic(
            rule_id    = "packageqa.descriptionComplete",
            severity   = "info",
            file       = "DESCRIPTION",
            message    = sprintf("Recommended DESCRIPTION field '%s' is missing.", field),
            suggestion = sprintf("Add '%s:' to DESCRIPTION to improve discoverability.", field)
          )
        }
      }
      diags
    }
  )
}

# ---------------------------------------------------------------------------
# packageqa.descriptionTitle
# ---------------------------------------------------------------------------

rule_packageqa_description_title <- function() {
  packageqa_rule(
    id               = "packageqa.descriptionTitle",
    description      = "Flags DESCRIPTION titles that end in a period or are in Title Case.",
    default_severity = "info",
    default_params   = list(),
    packageqa_fn = function(root, params) {
      desc_path <- file.path(root, "DESCRIPTION")
      if (!file.exists(desc_path)) return(list())
      desc  <- parse_description(desc_path)
      title <- desc[["Title"]] %||% ""
      if (!nzchar(title)) return(list())

      diags <- list()
      if (grepl("\\.$", title)) {
        diags[[length(diags) + 1]] <- new_diagnostic(
          rule_id    = "packageqa.descriptionTitle",
          severity   = "info",
          file       = "DESCRIPTION",
          message    = "DESCRIPTION Title ends with a period (CRAN policy: titles should not end with a full stop).",
          suggestion = "Remove the trailing period from the Title field."
        )
      }
      words      <- strsplit(title, "\\s+")[[1]]
      all_lower  <- sum(grepl("^[a-z]", words)) == length(words)
      if (length(words) >= 4 && all_lower) {
        diags[[length(diags) + 1]] <- new_diagnostic(
          rule_id    = "packageqa.descriptionTitle",
          severity   = "info",
          file       = "DESCRIPTION",
          message    = "DESCRIPTION Title appears to be all lowercase. Titles are typically in Title Case.",
          suggestion = "Use Title Case for the DESCRIPTION Title field."
        )
      }
      diags
    }
  )
}

# ---------------------------------------------------------------------------
# packageqa.namespaceHygiene
# ---------------------------------------------------------------------------

rule_packageqa_namespace_hygiene <- function() {
  packageqa_rule(
    id               = "packageqa.namespaceHygiene",
    description      = "Flags NAMESPACE issues: no exports, bare importFrom(*), or missing imports.",
    default_severity = "warning",
    default_params   = list(),
    packageqa_fn = function(root, params) {
      ns_path <- file.path(root, "NAMESPACE")
      if (!file.exists(ns_path)) return(list())

      lines  <- readLines(ns_path, warn = FALSE)
      diags  <- list()

      exports <- grep("^export\\(", lines, value = TRUE)
      if (length(exports) == 0 && file.exists(file.path(root, "DESCRIPTION"))) {
        diags[[length(diags) + 1]] <- new_diagnostic(
          rule_id    = "packageqa.namespaceHygiene",
          severity   = "info",
          file       = "NAMESPACE",
          message    = "NAMESPACE has no export() directives. Package exports nothing.",
          suggestion = "Add @export to functions you want users to call, then run `devtools::document()`."
        )
      }

      # Warn about import(*) — importing all of a package's namespace
      star_imports <- grep("^import\\(", lines, value = TRUE)
      if (length(star_imports) > 0) {
        for (imp in star_imports) {
          pkg_match <- regmatches(imp, regexpr("import\\(([^)]+)\\)", imp))
          pkg_name  <- if (length(pkg_match) > 0) {
            gsub("import\\(([^)]+)\\)", "\\1", pkg_match)
          } else "(unknown)"
          diags[[length(diags) + 1]] <- new_diagnostic(
            rule_id    = "packageqa.namespaceHygiene",
            severity   = "warning",
            file       = "NAMESPACE",
            message    = sprintf("NAMESPACE imports all of '%s' with import(). This pollutes the package namespace.", pkg_name),
            suggestion = sprintf("Use importFrom(%s, fn1, fn2) to import only the functions you need.", pkg_name)
          )
        }
      }
      diags
    }
  )
}

# ---------------------------------------------------------------------------
# packageqa.testCoverage
# ---------------------------------------------------------------------------

rule_packageqa_test_coverage <- function() {
  packageqa_rule(
    id               = "packageqa.testCoverage",
    description      = "Flags R packages with no test suite or a very thin test suite.",
    default_severity = "warning",
    default_params   = list(min_test_files = 1L),
    packageqa_fn = function(root, params) {
      if (!file.exists(file.path(root, "DESCRIPTION"))) return(list())

      tests_dir <- file.path(root, "tests")
      if (!dir.exists(tests_dir)) {
        return(list(new_diagnostic(
          rule_id    = "packageqa.testCoverage",
          severity   = "warning",
          file       = "(project)",
          message    = "R package has no tests/ directory.",
          suggestion = "Add a test suite with `usethis::use_testthat()`."
        )))
      }

      test_files <- list.files(tests_dir, pattern = "^test.*\\.[Rr]$",
                                recursive = TRUE, full.names = FALSE)
      min_files  <- params$min_test_files %||% 1L

      if (length(test_files) < min_files) {
        return(list(new_diagnostic(
          rule_id    = "packageqa.testCoverage",
          severity   = "warning",
          file       = "tests/",
          message    = sprintf("Package has %d test file(s) (minimum recommended: %d).",
                               length(test_files), min_files),
          suggestion = "Add test files under tests/testthat/ for every module."
        )))
      }
      list()
    }
  )
}

# ---------------------------------------------------------------------------
# packageqa.licensePresent
# ---------------------------------------------------------------------------

rule_packageqa_license <- function() {
  packageqa_rule(
    id               = "packageqa.licensePresent",
    description      = "Flags projects with no LICENSE or LICENSE.md file.",
    default_severity = "warning",
    default_params   = list(),
    packageqa_fn = function(root, params) {
      candidates <- c("LICENSE", "LICENSE.md", "LICENSE.txt",
                       "LICENCE", "LICENCE.md")
      has_license <- any(vapply(candidates, function(f) {
        file.exists(file.path(root, f))
      }, logical(1)))
      if (has_license) return(list())
      list(new_diagnostic(
        rule_id    = "packageqa.licensePresent",
        severity   = "warning",
        file       = "(project)",
        message    = "No LICENSE file found. Without a license, the work is legally 'all rights reserved'.",
        suggestion = "Add an open-source license with `usethis::use_mit_license()` or another appropriate license."
      ))
    }
  )
}

# ---------------------------------------------------------------------------
# packageqa.versionFormat
# ---------------------------------------------------------------------------

rule_packageqa_version_format <- function() {
  packageqa_rule(
    id               = "packageqa.versionFormat",
    description      = "Flags DESCRIPTION Version fields that do not follow MAJOR.MINOR.PATCH[-dev] convention.",
    default_severity = "info",
    default_params   = list(),
    packageqa_fn = function(root, params) {
      desc_path <- file.path(root, "DESCRIPTION")
      if (!file.exists(desc_path)) return(list())
      desc    <- parse_description(desc_path)
      version <- desc[["Version"]] %||% ""
      if (!nzchar(version)) return(list())

      # Accept x.y, x.y.z, x.y.z.w (for CRAN dev versions like 0.1.0.9000)
      ok <- grepl("^[0-9]+\\.[0-9]+(\\.[0-9]+)*(\\.[0-9]+)?(-[a-zA-Z0-9.]+)?$", version)
      if (ok) return(list())

      list(new_diagnostic(
        rule_id    = "packageqa.versionFormat",
        severity   = "info",
        file       = "DESCRIPTION",
        message    = sprintf("DESCRIPTION Version '%s' does not follow the recommended MAJOR.MINOR.PATCH format.", version),
        suggestion = "Use semantic versioning: MAJOR.MINOR.PATCH (e.g. 1.0.0, or 0.1.0.9000 for development)."
      ))
    }
  )
}

# ---------------------------------------------------------------------------
# packageqa.maintainerContact
# ---------------------------------------------------------------------------

rule_packageqa_maintainer_contact <- function() {
  packageqa_rule(
    id               = "packageqa.maintainerContact",
    description      = "Flags DESCRIPTION with no Maintainer or Authors@R email address.",
    default_severity = "warning",
    default_params   = list(),
    packageqa_fn = function(root, params) {
      desc_path <- file.path(root, "DESCRIPTION")
      if (!file.exists(desc_path)) return(list())
      desc      <- parse_description(desc_path)
      authors   <- desc[["Authors@R"]]  %||% ""
      maintainer <- desc[["Maintainer"]] %||% ""

      has_email <- grepl("@", authors) || grepl("@", maintainer)
      if (has_email) return(list())

      list(new_diagnostic(
        rule_id    = "packageqa.maintainerContact",
        severity   = "warning",
        file       = "DESCRIPTION",
        message    = "DESCRIPTION does not contain a maintainer email address.",
        suggestion = "Ensure Authors@R includes `role = c('cre')` with a valid email in person()."
      ))
    }
  )
}

# ---------------------------------------------------------------------------
# packageqa.newsFormat
# ---------------------------------------------------------------------------

rule_packageqa_news_format <- function() {
  packageqa_rule(
    id               = "packageqa.newsFormat",
    description      = "Flags NEWS.md that does not follow the standard R NEWS.md format.",
    default_severity = "info",
    default_params   = list(),
    packageqa_fn = function(root, params) {
      news_path <- NULL
      for (f in c("NEWS.md", "NEWS")) {
        fp <- file.path(root, f)
        if (file.exists(fp)) { news_path <- fp; break }
      }
      if (is.null(news_path)) return(list())

      lines   <- tryCatch(readLines(news_path, warn = FALSE), error = function(e) character(0))
      content <- paste(lines, collapse = "\n")

      # Standard R NEWS.md format: "# PackageName X.Y.Z" or "## Changes in version X"
      has_version_header <- grepl("^#+ .*(\\d+\\.\\d+)", content, perl = TRUE)

      if (!has_version_header) {
        return(list(new_diagnostic(
          rule_id    = "packageqa.newsFormat",
          severity   = "info",
          file       = basename(news_path),
          message    = "NEWS.md does not appear to follow the standard version-header format.",
          suggestion = "Use `# PackageName X.Y.Z` headers in NEWS.md so `news()` can parse it correctly."
        )))
      }
      list()
    }
  )
}
