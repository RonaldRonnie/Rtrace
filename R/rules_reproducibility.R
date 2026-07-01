#' Reproducibility rules
#'
#' Eight rules that catch the most common R reproducibility hazards. All are
#' prefixed `reproducibility.*` so the reproducibility engine can batch-run
#' them. Each is also independently usable in a standard `rtrace.yml`.
#'
#' Existing anti-pattern rules (`antipattern.setwd`, `antipattern.hardcodedPath`,
#' `antipattern.globalAssign`) already cover some reproducibility concerns;
#' these rules address the remaining surface: dependency locking, random
#' seeds, temp-file hygiene, external downloads, environment variables, and
#' session information.
#'
#' @name reproducibility-rules
NULL

# ---------------------------------------------------------------------------
# reproducibility.renvLock
# ---------------------------------------------------------------------------

#' Rule: missing renv.lock (or packrat)
#'
#' A project that imports external packages but has no `renv.lock` (or
#' legacy `packrat/packrat.lock`) cannot be reliably reproduced in another
#' environment: a fresh `install.packages()` may fetch a different version
#' of any dependency.
#'
#' Config: `type: reproducibility.renvLock`, no parameters.
#'
#' @return A [Rule] instance.
#' @keywords internal
#' @noRd
rule_reproducibility_renv_lock <- function() {
  Rule$new(
    id = "reproducibility.renvLock",
    description = "Flags projects that import external packages but have no renv.lock or packrat lock.",
    default_severity = "warning",
    default_params  = list(),
    check_fn = function(context, params) {
      root <- context$root
      has_renv    <- file.exists(file.path(root, "renv.lock"))
      has_packrat <- file.exists(file.path(root, "packrat", "packrat.lock"))
      if (has_renv || has_packrat) return(list())

      all_imports <- unlist(context$dependency_graph$package_imports)
      base_pkgs   <- c("base", "utils", "stats", "methods", "grDevices",
                        "graphics", "datasets", "tools")
      external_imports <- setdiff(unique(all_imports), c(base_pkgs, NA))
      if (length(external_imports) == 0) return(list())

      list(new_diagnostic(
        rule_id    = "reproducibility.renvLock",
        severity   = "warning",
        file       = "(project)",
        message    = sprintf(
          "Project imports %d external package(s) (%s%s) but has no renv.lock or packrat lock.",
          length(external_imports),
          paste(utils::head(external_imports, 3), collapse = ", "),
          if (length(external_imports) > 3) ", ..." else ""
        ),
        suggestion = "Run `renv::init()` or `renv::snapshot()` to create a reproducible dependency lock file."
      ))
    }
  )
}

# ---------------------------------------------------------------------------
# reproducibility.randomSeed
# ---------------------------------------------------------------------------

#' Rule: missing random seed
#'
#' Flags scripts that call random-number-generating functions without a
#' preceding `set.seed()` call in the same file — a common cause of
#' non-reproducible statistical results.
#'
#' Config: `type: reproducibility.randomSeed`, no parameters.
#'
#' @return A [Rule] instance.
#' @keywords internal
#' @noRd
rule_reproducibility_random_seed <- function() {
  rng_fns <- c(
    "sample", "runif", "rnorm", "rbinom", "rpois", "rexp",
    "rgamma", "rbeta", "rlnorm", "rt", "rf", "rchisq",
    "rmultinom", "rgeom", "rhyper", "rnbinom", "rweibull",
    "rcauchy", "rlogis", "rwilcox", "rsignrank"
  )

  Rule$new(
    id = "reproducibility.randomSeed",
    description = "Flags files that use random-number functions without a set.seed() call.",
    default_severity = "info",
    default_params   = list(),
    check_fn = function(context, params) {
      diags <- list()
      for (i in seq_len(nrow(context$files))) {
        path <- context$files$path[i]
        ast  <- context$asts[[path]]
        if (is.null(ast) || is.null(ast$parse_data)) next

        has_seed <- nrow(find_calls(ast, "set.seed")) > 0
        if (has_seed) next

        uses_rng <- any(vapply(rng_fns, function(fn) {
          nrow(find_calls(ast, fn)) > 0
        }, logical(1)))

        if (!uses_rng) next

        diags[[length(diags) + 1]] <- new_diagnostic(
          rule_id    = "reproducibility.randomSeed",
          severity   = "info",
          file       = context$files$rel_path[i],
          message    = "File uses random-number functions but has no set.seed() call.",
          suggestion = "Add `set.seed(<integer>)` before the first random-number call to make results reproducible."
        )
      }
      diags
    }
  )
}

# ---------------------------------------------------------------------------
# reproducibility.tempFiles
# ---------------------------------------------------------------------------

#' Rule: temp file usage without cleanup
#'
#' Flags calls to `tempfile()` that are not paired with an `on.exit()` or
#' `withr::*` cleanup call in the same function scope. Temp files left
#' behind across sessions can cause cross-run contamination.
#'
#' Config: `type: reproducibility.tempFiles`, no parameters.
#'
#' @return A [Rule] instance.
#' @keywords internal
#' @noRd
rule_reproducibility_temp_files <- function() {
  Rule$new(
    id = "reproducibility.tempFiles",
    description = "Flags tempfile() calls not accompanied by on.exit() or withr cleanup.",
    default_severity = "info",
    default_params   = list(),
    check_fn = function(context, params) {
      diags <- list()
      for (i in seq_len(nrow(context$files))) {
        path <- context$files$path[i]
        ast  <- context$asts[[path]]
        if (is.null(ast) || is.null(ast$parse_data)) next

        temp_calls <- find_calls(ast, "tempfile")
        if (nrow(temp_calls) == 0) next

        has_cleanup <- nrow(find_calls(ast, "on.exit"))   > 0 ||
                       nrow(find_calls(ast, "unlink"))    > 0 ||
                       nrow(find_calls(ast, "file.remove")) > 0

        if (has_cleanup) next

        for (j in seq_len(nrow(temp_calls))) {
          diags[[length(diags) + 1]] <- new_diagnostic(
            rule_id    = "reproducibility.tempFiles",
            severity   = "info",
            file       = context$files$rel_path[i],
            line       = temp_calls$line1[j],
            column     = temp_calls$col1[j],
            message    = "tempfile() called without a corresponding on.exit() / unlink() cleanup.",
            suggestion = "Use `withr::local_tempfile()` or add `on.exit(unlink(tmp), add = TRUE)` to ensure temp files are removed."
          )
        }
      }
      diags
    }
  )
}

# ---------------------------------------------------------------------------
# reproducibility.externalDownload
# ---------------------------------------------------------------------------

#' Rule: external data downloads
#'
#' Flags calls to `download.file()`, `httr::GET()`, `curl::curl_download()`,
#' and similar network-fetch functions. External downloads are brittle:
#' URLs change, servers go down, and the data may silently change between
#' runs. Reproducible research should cache or bundle external data.
#'
#' Config: `type: reproducibility.externalDownload`, no parameters.
#'
#' @return A [Rule] instance.
#' @keywords internal
#' @noRd
rule_reproducibility_external_download <- function() {
  download_fns <- c("download.file", "url", "readLines")

  Rule$new(
    id = "reproducibility.externalDownload",
    description = "Flags external data download calls that create run-to-run brittleness.",
    default_severity = "warning",
    default_params   = list(),
    check_fn = function(context, params) {
      diags <- list()

      qualified_fns <- list(
        list(pkg = "httr",    fn = "GET"),
        list(pkg = "httr",    fn = "POST"),
        list(pkg = "httr2",   fn = "request"),
        list(pkg = "curl",    fn = "curl_download"),
        list(pkg = "RCurl",   fn = "getURL"),
        list(pkg = "rvest",   fn = "read_html")
      )

      for (i in seq_len(nrow(context$files))) {
        path <- context$files$path[i]
        ast  <- context$asts[[path]]
        if (is.null(ast)) next

        hits <- list()

        for (fn in download_fns) {
          rows <- find_calls(ast, fn)
          if (nrow(rows) > 0) {
            for (j in seq_len(nrow(rows))) {
              hits[[length(hits) + 1]] <- list(
                line = rows$line1[j], col = rows$col1[j], label = fn
              )
            }
          }
        }

        for (qf in qualified_fns) {
          rows <- find_qualified_calls(ast, qf$pkg, qf$fn)
          if (nrow(rows) > 0) {
            for (j in seq_len(nrow(rows))) {
              hits[[length(hits) + 1]] <- list(
                line = rows$line1[j], col = rows$col1[j],
                label = sprintf("%s::%s", qf$pkg, qf$fn)
              )
            }
          }
        }

        for (h in hits) {
          diags[[length(diags) + 1]] <- new_diagnostic(
            rule_id    = "reproducibility.externalDownload",
            severity   = "warning",
            file       = context$files$rel_path[i],
            line       = h$line,
            column     = h$col,
            message    = sprintf(
              "External download call `%s()` introduces run-to-run dependency on network availability.",
              h$label
            ),
            suggestion = "Cache the downloaded data and load from the local copy, or use a content-hash verified download."
          )
        }
      }
      diags
    }
  )
}

# ---------------------------------------------------------------------------
# reproducibility.environmentVariables
# ---------------------------------------------------------------------------

#' Rule: undocumented environment variable dependencies
#'
#' Flags calls to `Sys.getenv()` whose variable names are not documented in a
#' README, `.env.example`, or similar file. An undocumented `Sys.getenv()`
#' call makes a project's execution environment opaque to collaborators.
#'
#' Config: `type: reproducibility.environmentVariables`, no parameters.
#'
#' @return A [Rule] instance.
#' @keywords internal
#' @noRd
rule_reproducibility_env_vars <- function() {
  Rule$new(
    id = "reproducibility.environmentVariables",
    description = "Flags Sys.getenv() calls that create undocumented environment-variable dependencies.",
    default_severity = "info",
    default_params   = list(),
    check_fn = function(context, params) {
      diags <- list()
      root  <- context$root

      # A .env.example or .Renviron in the project root signals that env vars are documented.
      env_documented <- file.exists(file.path(root, ".env.example")) ||
                        file.exists(file.path(root, ".Renviron"))     ||
                        file.exists(file.path(root, ".env"))

      for (i in seq_len(nrow(context$files))) {
        path <- context$files$path[i]
        ast  <- context$asts[[path]]
        if (is.null(ast)) next

        hits <- find_calls(ast, "Sys.getenv")
        if (nrow(hits) == 0) next

        for (j in seq_len(nrow(hits))) {
          diags[[length(diags) + 1]] <- new_diagnostic(
            rule_id    = "reproducibility.environmentVariables",
            severity   = "info",
            file       = context$files$rel_path[i],
            line       = hits$line1[j],
            column     = hits$col1[j],
            message    = "Sys.getenv() creates an environment-variable dependency; ensure the variable is documented.",
            suggestion = if (!env_documented) {
              "Add a .env.example or .Renviron file listing the required environment variables."
            } else {
              "Verify this variable is listed in your .env.example / .Renviron documentation."
            }
          )
        }
      }
      diags
    }
  )
}

# ---------------------------------------------------------------------------
# reproducibility.sessionInfo
# ---------------------------------------------------------------------------

#' Rule: no session info capture
#'
#' Flags projects that run statistical analyses but never call
#' `sessionInfo()` or `sessioninfo::session_info()` — a best practice for
#' capturing the exact R and package versions used in a run.
#'
#' Config: `type: reproducibility.sessionInfo`, no parameters.
#'
#' @return A [Rule] instance.
#' @keywords internal
#' @noRd
rule_reproducibility_session_info <- function() {
  Rule$new(
    id = "reproducibility.sessionInfo",
    description = "Flags projects with no sessionInfo() or session_info() call anywhere.",
    default_severity = "info",
    default_params   = list(),
    check_fn = function(context, params) {
      has_call <- FALSE
      for (path in context$files$path) {
        ast <- context$asts[[path]]
        if (is.null(ast)) next
        if (nrow(find_calls(ast, "sessionInfo")) > 0 ||
            nrow(find_calls(ast, "session_info")) > 0) {
          has_call <- TRUE
          break
        }
      }
      if (has_call) return(list())

      all_imports <- unique(unlist(context$dependency_graph$package_imports))
      analysis_pkgs <- c("ggplot2", "dplyr", "tidyr", "data.table", "lme4",
                          "survival", "caret", "randomForest", "xgboost",
                          "Seurat", "DESeq2", "edgeR", "brms", "stan",
                          "targets", "plumber")
      if (!any(analysis_pkgs %in% all_imports)) return(list())

      list(new_diagnostic(
        rule_id    = "reproducibility.sessionInfo",
        severity   = "info",
        file       = "(project)",
        message    = "Project performs analysis but never calls sessionInfo() or session_info().",
        suggestion = "Add `sessioninfo::session_info()` (or base `sessionInfo()`) at the end of analysis scripts to capture the runtime environment."
      ))
    }
  )
}

# ---------------------------------------------------------------------------
# reproducibility.portablePaths
# ---------------------------------------------------------------------------

#' Rule: non-portable working-directory assumptions
#'
#' Flags `read.csv()`, `readRDS()`, `load()`, and similar file-input calls
#' that pass bare filenames (no `here::here()`, no `file.path()`, no
#' project-root-relative construction) — a pattern that depends on the
#' current working directory being set correctly, which varies across
#' environments.
#'
#' Config: `type: reproducibility.portablePaths`, no parameters.
#'
#' @return A [Rule] instance.
#' @keywords internal
#' @noRd
rule_reproducibility_portable_paths <- function() {
  bare_io_fns <- c(
    "read.csv", "read.table", "readRDS", "load", "readLines",
    "read_csv", "read_excel", "fread"
  )

  Rule$new(
    id = "reproducibility.portablePaths",
    description = "Flags file-input calls using bare filenames instead of here::here() or file.path().",
    default_severity = "info",
    default_params   = list(),
    check_fn = function(context, params) {
      diags <- list()

      for (i in seq_len(nrow(context$files))) {
        path <- context$files$path[i]
        ast  <- context$asts[[path]]
        if (is.null(ast) || is.null(ast$expr)) next

        for (fn in bare_io_fns) {
          calls_expr <- all_calls_named(ast$expr, fn)
          for (e in calls_expr) {
            if (length(e) < 2) next
            arg <- e[[2]]
            if (!is.character(arg)) next
            val <- as.character(arg)
            if (nchar(val) == 0) next
            # flag bare relative paths (not starting with /, ~, C:, file.path, here)
            is_bare_relative <- !grepl("^[/~]", val) &&
                                !grepl("^[A-Za-z]:", val) &&
                                !grepl("[/\\\\]", val)
            if (!is_bare_relative) next

            hits <- find_calls(ast, fn)
            if (nrow(hits) == 0) next
            diags[[length(diags) + 1]] <- new_diagnostic(
              rule_id    = "reproducibility.portablePaths",
              severity   = "info",
              file       = context$files$rel_path[i],
              line       = hits$line1[1],
              message    = sprintf(
                "`%s(\"%s\")` uses a bare filename that depends on the current working directory.",
                fn, val
              ),
              suggestion = "Use here::here() or construct the path with file.path() from the project root."
            )
          }
        }
      }
      diags
    }
  )
}

# ---------------------------------------------------------------------------
# reproducibility.reproducibleReports
# ---------------------------------------------------------------------------

#' Rule: R Markdown / Quarto outputs not committed
#'
#' Flags projects that contain `.Rmd` or `.qmd` source files where no
#' corresponding rendered output (`.html`, `.pdf`, `.docx`) exists in the
#' same directory — meaning reports may not be reproducible from the
#' committed source alone.
#'
#' Config: `type: reproducibility.reproducibleReports`, no parameters.
#'
#' @return A [Rule] instance.
#' @keywords internal
#' @noRd
rule_reproducibility_reproducible_reports <- function() {
  Rule$new(
    id = "reproducibility.reproducibleReports",
    description = "Flags .Rmd/.qmd source files with no rendered output committed alongside them.",
    default_severity = "info",
    default_params   = list(),
    check_fn = function(context, params) {
      root <- context$root

      rmd_files <- list.files(root, pattern = "\\.(Rmd|qmd)$",
                               recursive = TRUE, full.names = FALSE)
      if (length(rmd_files) == 0) return(list())

      output_exts <- c(".html", ".pdf", ".docx", ".md")

      diags <- list()
      for (src in rmd_files) {
        base   <- tools::file_path_sans_ext(src)
        has_output <- any(vapply(output_exts, function(ext) {
          file.exists(file.path(root, paste0(base, ext)))
        }, logical(1)))

        if (!has_output) {
          diags[[length(diags) + 1]] <- new_diagnostic(
            rule_id    = "reproducibility.reproducibleReports",
            severity   = "info",
            file       = src,
            message    = sprintf("Report source '%s' has no rendered output committed in the repository.", src),
            suggestion = "Render the report and commit the output alongside the source, or document the render step in your CI pipeline."
          )
        }
      }
      diags
    }
  )
}
