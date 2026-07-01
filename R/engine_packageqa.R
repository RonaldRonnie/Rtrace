#' Package QA Engine
#'
#' Evaluates an R package's metadata quality: DESCRIPTION completeness,
#' NAMESPACE hygiene, NEWS.md/ChangeLog, LICENSE presence, test coverage
#' scaffolding, and CRAN/Bioconductor convention compliance.
#'
#' Only meaningful when run against an R package (a directory containing a
#' DESCRIPTION file). Non-package projects are skipped silently.
#'
#' @name packageqa-engine
NULL

#' Run the Package QA engine against a project
#'
#' @param root Character scalar project root.
#' @return A list with `is_package` (logical), `diagnostics` (an
#'   `rtrace_diagnostic_set`), and `score` (a `trace_score`).
#' @export
run_packageqa_scan <- function(root = ".") {
  root       <- normalizePath(root, mustWork = TRUE)
  is_package <- file.exists(file.path(root, "DESCRIPTION"))

  packageqa_rules <- Filter(
    function(r) startsWith(r$id, "packageqa."),
    as.list(list_rules())
  )

  diags <- new_diagnostic_set()

  for (rule in packageqa_rules) {
    result <- tryCatch(
      rule$domain_fns$check_packageqa(root),
      error = function(e) {
        list(new_diagnostic(
          rule_id = "rule-error", severity = "error", file = "(packageqa-engine)",
          message = sprintf("PackageQA rule '%s' errored: %s", rule$id, conditionMessage(e))
        ))
      }
    )
    if (length(result) > 0) {
      if (inherits(result, "rtrace_diagnostic")) result <- list(result)
      diags <- c(diags, new_diagnostic_set(result))
    }
  }

  score <- compute_score(
    diags,
    error_penalty   = 12,
    warning_penalty = 5,
    info_penalty    = 1
  )
  score$module_id <- "packageqa"

  list(is_package = is_package, diagnostics = diags, score = score)
}

# ---------------------------------------------------------------------------
# PackageQA Rule base constructor
# ---------------------------------------------------------------------------

#' Construct a PackageQA-aware rule
#'
#' @param id,description,default_severity,default_params Standard Rule fields.
#' @param packageqa_fn A function `function(root, params)` returning a list
#'   of `rtrace_diagnostic` objects.
#' @return A [Rule] instance with an additional `check_packageqa` method.
#' @keywords internal
#' @noRd
packageqa_rule <- function(id, description, packageqa_fn,
                             default_severity = "info",
                             default_params   = list()) {
  rule <- Rule$new(
    id               = id,
    description      = description,
    default_severity = default_severity,
    default_params   = default_params,
    check_fn         = function(context, params) list()
  )
  params_captured <- default_params
  fn_captured     <- packageqa_fn
  rule$domain_fns$check_packageqa <- function(root, params = params_captured) {
    fn_captured(root, params)
  }
  rule
}

#' Parse a DESCRIPTION file into a named list
#'
#' @param path Character scalar path to the DESCRIPTION file.
#' @return Named list of field values, or an empty list on error.
#' @keywords internal
#' @noRd
parse_description <- function(path) {
  if (!file.exists(path)) return(list())
  tryCatch({
    lines   <- readLines(path, warn = FALSE, encoding = "UTF-8")
    result  <- list()
    current_key <- NULL
    current_val <- character(0)

    for (line in lines) {
      if (grepl("^[A-Za-z][A-Za-z0-9.@]*:", line)) {
        if (!is.null(current_key)) {
          result[[current_key]] <- trimws(paste(current_val, collapse = " "))
        }
        parts       <- strsplit(line, ":", fixed = TRUE)[[1]]
        current_key <- trimws(parts[1])
        current_val <- paste(parts[-1], collapse = ":")[1]
      } else if (!is.null(current_key) && grepl("^\\s+", line)) {
        current_val <- c(current_val, trimws(line))
      }
    }
    if (!is.null(current_key)) {
      result[[current_key]] <- trimws(paste(current_val, collapse = " "))
    }
    result
  }, error = function(e) list())
}
