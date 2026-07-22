#' DocsTrace rules
#'
#' Rules for evaluating documentation quality. All are prefixed
#' `docstrace.*` and are run by the DocsTrace engine, not the standard rule
#' engine.
#'
#' @name docstrace-rules
NULL

#' Extract the content of a brace-delimited Rd macro, honoring nesting
#'
#' Finds the first `\tag{...}` in `content` and returns everything between
#' its opening and matching closing brace, correctly skipping over any
#' nested `{...}` groups (e.g. `\dontrun{}`, `\code{}` inside `\examples{}`).
#' A single-`[^}]*`-style regex cannot do this: it stops at the *first*
#' closing brace it sees, truncating the match as soon as any nested group
#' appears.
#'
#' @param content Character scalar, the full Rd file text.
#' @param tag Character scalar, the macro name without the leading backslash
#'   (e.g. `"examples"`).
#' @return Character scalar with the block's inner content, or `NA` if the
#'   tag is absent or its braces are unbalanced.
#' @keywords internal
#' @noRd
extract_braced_block <- function(content, tag) {
  start <- regexpr(paste0("\\\\", tag, "\\{"), content)
  if (start[1] == -1) return(NA_character_)

  open_pos <- start[1] + attr(start, "match.length") - 1L  # position of '{'
  n        <- nchar(content)
  depth    <- 1L
  pos      <- open_pos + 1L

  while (pos <= n && depth > 0L) {
    ch <- substr(content, pos, pos)
    if (ch == "{")      depth <- depth + 1L
    else if (ch == "}") depth <- depth - 1L
    pos <- pos + 1L
  }

  if (depth != 0L) return(NA_character_)
  substr(content, open_pos + 1L, pos - 2L)
}

# ---------------------------------------------------------------------------
# docstrace.readme
# ---------------------------------------------------------------------------

rule_docstrace_readme <- function() {
  docstrace_rule(
    id               = "docstrace.readme",
    description      = "Flags projects with no README.md or README.Rmd at the project root.",
    default_severity = "warning",
    default_params   = list(),
    docstrace_fn = function(root, params) {
      candidates <- c("README.md", "README.Rmd", "README.rst", "README.txt", "README")
      has_readme <- any(vapply(candidates, function(f) {
        file.exists(file.path(root, f))
      }, logical(1)))
      if (has_readme) return(list())
      list(new_diagnostic(
        rule_id    = "docstrace.readme",
        severity   = "warning",
        file       = "(project)",
        message    = "No README file found at the project root.",
        suggestion = "Add a README.md describing the project's purpose, installation, and usage."
      ))
    }
  )
}

# ---------------------------------------------------------------------------
# docstrace.readmeQuality
# ---------------------------------------------------------------------------

rule_docstrace_readme_quality <- function() {
  required_sections <- c(
    installation = "install",
    usage        = "usage|example|quick.?start|getting.?started",
    description  = "overview|about|description|what.?is"
  )

  docstrace_rule(
    id               = "docstrace.readmeQuality",
    description      = "Flags READMEs missing installation, usage, or description sections.",
    default_severity = "info",
    default_params   = list(min_words = 50L),
    docstrace_fn = function(root, params) {
      readme_path <- NULL
      for (f in c("README.md", "README.Rmd", "README.rst")) {
        fp <- file.path(root, f)
        if (file.exists(fp)) { readme_path <- fp; break }
      }
      if (is.null(readme_path)) return(list())

      lines <- tryCatch(
        readLines(readme_path, warn = FALSE, encoding = "UTF-8"),
        error = function(e) character(0)
      )
      if (length(lines) == 0) return(list())

      content <- paste(lines, collapse = "\n")
      word_count <- length(strsplit(content, "\\s+")[[1]])

      diags <- list()

      if (word_count < (params$min_words %||% 50L)) {
        diags[[length(diags) + 1]] <- new_diagnostic(
          rule_id    = "docstrace.readmeQuality",
          severity   = "info",
          file       = basename(readme_path),
          message    = sprintf("README has only %d word(s). A good README typically has at least %d words.",
                               word_count, params$min_words %||% 50L),
          suggestion = "Expand the README to include at minimum: purpose, installation steps, and a usage example."
        )
      }

      headings <- grep("^#{1,3}\\s", lines, value = TRUE, perl = TRUE)
      heading_text <- paste(tolower(headings), collapse = "\n")

      for (section in names(required_sections)) {
        pattern <- required_sections[[section]]
        if (!grepl(pattern, heading_text, perl = TRUE, ignore.case = TRUE)) {
          diags[[length(diags) + 1]] <- new_diagnostic(
            rule_id    = "docstrace.readmeQuality",
            severity   = "info",
            file       = basename(readme_path),
            message    = sprintf("README appears to be missing a '%s' section.", section),
            suggestion = sprintf("Add a ## %s section to the README.",
                                  tools::toTitleCase(section))
          )
        }
      }
      diags
    }
  )
}

# ---------------------------------------------------------------------------
# docstrace.vignettes
# ---------------------------------------------------------------------------

rule_docstrace_vignettes <- function() {
  docstrace_rule(
    id               = "docstrace.vignettes",
    description      = "Flags packages with no vignettes (no vignettes/ directory or no .Rmd/.qmd).",
    default_severity = "info",
    default_params   = list(),
    docstrace_fn = function(root, params) {
      is_package <- file.exists(file.path(root, "DESCRIPTION"))
      if (!is_package) return(list())

      vig_dir <- file.path(root, "vignettes")
      if (!dir.exists(vig_dir)) {
        return(list(new_diagnostic(
          rule_id    = "docstrace.vignettes",
          severity   = "info",
          file       = "(project)",
          message    = "R package has no vignettes/ directory.",
          suggestion = "Add at least one vignette with `usethis::use_vignette()` to demonstrate package usage."
        )))
      }

      vig_files <- list.files(vig_dir, pattern = "\\.(Rmd|qmd|rnw)$",
                               recursive = TRUE, ignore.case = TRUE)
      if (length(vig_files) == 0) {
        return(list(new_diagnostic(
          rule_id    = "docstrace.vignettes",
          severity   = "info",
          file       = "vignettes/",
          message    = "vignettes/ directory exists but contains no .Rmd/.qmd vignette files.",
          suggestion = "Add a vignette with `usethis::use_vignette('getting-started')`."
        )))
      }
      list()
    }
  )
}

# ---------------------------------------------------------------------------
# docstrace.pkgdown
# ---------------------------------------------------------------------------

rule_docstrace_pkgdown <- function() {
  docstrace_rule(
    id               = "docstrace.pkgdown",
    description      = "Flags packages without a _pkgdown.yml configuration for documentation website.",
    default_severity = "info",
    default_params   = list(),
    docstrace_fn = function(root, params) {
      is_package <- file.exists(file.path(root, "DESCRIPTION"))
      if (!is_package) return(list())

      has_pkgdown <- file.exists(file.path(root, "_pkgdown.yml")) ||
                     file.exists(file.path(root, "_pkgdown.yaml")) ||
                     file.exists(file.path(root, "pkgdown", "_pkgdown.yml"))
      if (has_pkgdown) return(list())

      list(new_diagnostic(
        rule_id    = "docstrace.pkgdown",
        severity   = "info",
        file       = "(project)",
        message    = "No _pkgdown.yml configuration found; the package lacks a documentation website setup.",
        suggestion = "Run `usethis::use_pkgdown()` to initialize a pkgdown site and GitHub Pages deployment."
      ))
    }
  )
}

# ---------------------------------------------------------------------------
# docstrace.examplesQuality
# ---------------------------------------------------------------------------

rule_docstrace_examples_quality <- function() {
  docstrace_rule(
    id               = "docstrace.examplesQuality",
    description      = "Flags man/ files (exported functions) with missing or empty @examples sections.",
    default_severity = "info",
    default_params   = list(),
    docstrace_fn = function(root, params) {
      man_dir <- file.path(root, "man")
      if (!dir.exists(man_dir)) return(list())

      rd_files <- list.files(man_dir, pattern = "\\.Rd$", full.names = TRUE)
      if (length(rd_files) == 0) return(list())

      diags <- list()
      for (rd in rd_files) {
        lines   <- tryCatch(readLines(rd, warn = FALSE), error = function(e) character(0))
        content <- paste(lines, collapse = "\n")

        has_examples <- grepl("\\\\examples\\{", content, fixed = FALSE)
        if (has_examples) {
          # Check that the examples block is non-empty (Issue #10: must
          # honor brace nesting, not stop at the first '}' encountered).
          ex_content <- extract_braced_block(content, "examples")
          if (!is.na(ex_content) && nchar(trimws(ex_content)) < 20) {
            diags[[length(diags) + 1]] <- new_diagnostic(
              rule_id    = "docstrace.examplesQuality",
              severity   = "info",
              file       = file.path("man", basename(rd)),
              message    = sprintf("Man page '%s' has an empty or trivial \\examples block.", basename(rd)),
              suggestion = "Add a runnable example demonstrating the function's primary use case."
            )
          }
        } else {
          # Only flag exported (non-internal) pages
          is_internal <- grepl("\\\\keyword\\{internal\\}", content) ||
                         grepl("@noRd", content)
          if (!is_internal) {
            diags[[length(diags) + 1]] <- new_diagnostic(
              rule_id    = "docstrace.examplesQuality",
              severity   = "info",
              file       = file.path("man", basename(rd)),
              message    = sprintf("Man page '%s' has no \\examples section.", basename(rd)),
              suggestion = "Add an \\examples{} section with at least one runnable example."
            )
          }
        }
      }
      diags
    }
  )
}

# ---------------------------------------------------------------------------
# docstrace.changelogPresent
# ---------------------------------------------------------------------------

rule_docstrace_changelog <- function() {
  docstrace_rule(
    id               = "docstrace.changelogPresent",
    description      = "Flags projects with no NEWS.md, CHANGELOG.md, or ChangeLog file.",
    default_severity = "info",
    default_params   = list(),
    docstrace_fn = function(root, params) {
      changelog_candidates <- c("NEWS.md", "NEWS", "CHANGELOG.md", "CHANGELOG",
                                  "ChangeLog", "CHANGES.md", "CHANGES")
      has_changelog <- any(vapply(changelog_candidates, function(f) {
        file.exists(file.path(root, f))
      }, logical(1)))
      if (has_changelog) return(list())
      list(new_diagnostic(
        rule_id    = "docstrace.changelogPresent",
        severity   = "info",
        file       = "(project)",
        message    = "No NEWS.md / CHANGELOG.md found at the project root.",
        suggestion = "Add a NEWS.md to document version history. For R packages use `usethis::use_news_md()`."
      ))
    }
  )
}

# ---------------------------------------------------------------------------
# docstrace.contributingGuide
# ---------------------------------------------------------------------------

rule_docstrace_contributing <- function() {
  docstrace_rule(
    id               = "docstrace.contributingGuide",
    description      = "Flags projects missing a CONTRIBUTING.md guide for external contributors.",
    default_severity = "info",
    default_params   = list(),
    docstrace_fn = function(root, params) {
      contributing_candidates <- c(
        "CONTRIBUTING.md", "CONTRIBUTING",
        ".github/CONTRIBUTING.md", "docs/CONTRIBUTING.md"
      )
      has_contributing <- any(vapply(contributing_candidates, function(f) {
        file.exists(file.path(root, f))
      }, logical(1)))
      if (has_contributing) return(list())
      list(new_diagnostic(
        rule_id    = "docstrace.contributingGuide",
        severity   = "info",
        file       = "(project)",
        message    = "No CONTRIBUTING.md found.",
        suggestion = "Add CONTRIBUTING.md explaining how to report bugs, propose features, and submit pull requests. Use `usethis::use_tidy_contributing()`."
      ))
    }
  )
}

# ---------------------------------------------------------------------------
# docstrace.citationFile
# ---------------------------------------------------------------------------

rule_docstrace_citation <- function() {
  docstrace_rule(
    id               = "docstrace.citationFile",
    description      = "Flags research packages with no CITATION or inst/CITATION file.",
    default_severity = "info",
    default_params   = list(),
    docstrace_fn = function(root, params) {
      citation_candidates <- c(
        "CITATION", "CITATION.cff", "inst/CITATION"
      )
      has_citation <- any(vapply(citation_candidates, function(f) {
        file.exists(file.path(root, f))
      }, logical(1)))
      if (has_citation) return(list())

      # Only flag if it looks like a research/analysis package
      desc_path <- file.path(root, "DESCRIPTION")
      if (!file.exists(desc_path)) return(list())

      list(new_diagnostic(
        rule_id    = "docstrace.citationFile",
        severity   = "info",
        file       = "(project)",
        message    = "No CITATION or CITATION.cff file found. Users cannot easily cite this work.",
        suggestion = "Add a CITATION.cff (GitHub displays it automatically) or use `usethis::use_citation()` for an R package."
      ))
    }
  )
}
