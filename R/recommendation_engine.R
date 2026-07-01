#' AI Recommendation Engine
#'
#' Provider-agnostic recommendation layer that enriches diagnostics with
#' contextual explanations, impact assessments, and actionable fix
#' suggestions. The engine is designed so that the underlying AI provider
#' (Claude, GPT-4, a local model, or a deterministic rule-lookup table) can
#' be swapped without changing the recommendation API contract.
#'
#' Today's implementation uses a comprehensive deterministic rule-lookup
#' table (no network calls, no API keys required) that covers all 16+
#' built-in rules plus the new platform module rules. Future provider
#' adapters can be registered via [register_recommendation_provider()].
#'
#' @name recommendation-engine
NULL

# ---------------------------------------------------------------------------
# Provider registry
# ---------------------------------------------------------------------------

#' Register a recommendation provider
#'
#' A provider is any function `function(diagnostic, context_hint)` that
#' returns a `trace_recommendation` object (see [new_recommendation()]).
#' Providers can call external AI APIs, a local model endpoint, or use any
#' other strategy.
#'
#' @param id Character scalar provider id (e.g. `"claude"`, `"openai"`).
#' @param provider_fn A function `function(diagnostic, context_hint=NULL)`
#'   returning a `trace_recommendation`.
#' @param description One-line description of the provider.
#' @return Invisibly, the provider id.
#' @export
register_recommendation_provider <- function(id, provider_fn, description = "") {
  stopifnot(is.character(id), length(id) == 1, is.function(provider_fn))
  rtrace_env$recommendation_providers[[id]] <- list(
    id          = id,
    fn          = provider_fn,
    description = description
  )
  invisible(id)
}

#' Set the active recommendation provider
#'
#' @param id Character scalar provider id. Use `"builtin"` for the
#'   deterministic built-in provider (the default).
#' @return Invisibly, the previous active provider id.
#' @export
set_recommendation_provider <- function(id) {
  if (id != "builtin" && is.null(rtrace_env$recommendation_providers[[id]])) {
    rlang::abort(sprintf("Unknown recommendation provider: '%s'", id))
  }
  prev <- rtrace_env$active_provider
  rtrace_env$active_provider <- id
  invisible(prev)
}

#' Return the active recommendation provider id
#' @return Character scalar provider id (e.g. `"builtin"`).
#' @export
get_active_provider <- function() rtrace_env$active_provider

# ---------------------------------------------------------------------------
# trace_recommendation object
# ---------------------------------------------------------------------------

#' Construct a trace_recommendation
#'
#' @param rule_id Character scalar rule id.
#' @param why Character scalar; why this violation matters.
#' @param impact Character scalar; what can go wrong if ignored.
#' @param fix Character scalar; recommended remediation.
#' @param examples Character vector; one or more concrete code examples.
#' @param references Character vector; URLs to documentation or best-practice
#'   guides.
#' @param priority One of `"critical"`, `"high"`, `"medium"`, `"low"`.
#' @param provider Character scalar; which provider generated this.
#' @return A `trace_recommendation` object.
#' @export
new_recommendation <- function(rule_id,
                                 why        = NULL,
                                 impact     = NULL,
                                 fix        = NULL,
                                 examples   = character(0),
                                 references = character(0),
                                 priority   = c("medium", "high", "critical", "low"),
                                 provider   = "builtin") {
  priority <- match.arg(priority)
  structure(
    list(
      rule_id    = rule_id,
      why        = why,
      impact     = impact,
      fix        = fix,
      examples   = examples,
      references = references,
      priority   = priority,
      provider   = provider
    ),
    class = "trace_recommendation"
  )
}

#' @export
print.trace_recommendation <- function(x, ...) {
  cat(sprintf("<trace_recommendation> rule=%s priority=%s provider=%s\n",
              x$rule_id, x$priority, x$provider))
  if (!is.null(x$why))    cat(sprintf("  Why:    %s\n", x$why))
  if (!is.null(x$impact)) cat(sprintf("  Impact: %s\n", x$impact))
  if (!is.null(x$fix))    cat(sprintf("  Fix:    %s\n", x$fix))
  invisible(x)
}

# ---------------------------------------------------------------------------
# Main recommendation entry point
# ---------------------------------------------------------------------------

#' Get a recommendation for a diagnostic
#'
#' Dispatches to the active provider to generate a `trace_recommendation`
#' for a single diagnostic.
#'
#' @param diagnostic An `rtrace_diagnostic` object.
#' @param context_hint Optional character scalar; additional context to pass
#'   to the provider (e.g. the file contents at the diagnostic location).
#' @return A `trace_recommendation`.
#' @export
get_recommendation <- function(diagnostic, context_hint = NULL) {
  stopifnot(inherits(diagnostic, "rtrace_diagnostic"))

  provider_id <- rtrace_env$active_provider

  if (provider_id == "builtin" || is.null(rtrace_env$recommendation_providers[[provider_id]])) {
    return(builtin_recommendation(diagnostic))
  }

  provider <- rtrace_env$recommendation_providers[[provider_id]]
  tryCatch(
    provider$fn(diagnostic, context_hint),
    error = function(e) {
      rlang::warn(sprintf("Provider '%s' failed: %s. Falling back to builtin.", provider_id, conditionMessage(e)))
      builtin_recommendation(diagnostic)
    }
  )
}

#' Get recommendations for all diagnostics in a set
#'
#' @param diagnostics An `rtrace_diagnostic_set`.
#' @param context_hint Optional character scalar.
#' @return A named list of `trace_recommendation` objects, one per unique
#'   `rule_id` encountered.
#' @export
get_recommendations <- function(diagnostics, context_hint = NULL) {
  stopifnot(inherits(diagnostics, "rtrace_diagnostic_set"))
  if (length(diagnostics) == 0) return(list())

  unique_rules <- unique(vapply(diagnostics$diagnostics, function(d) d$rule_id, character(1)))
  recs <- lapply(unique_rules, function(rid) {
    d <- diagnostics$diagnostics[[
      which(vapply(diagnostics$diagnostics, function(d) d$rule_id == rid, logical(1)))[1]
    ]]
    get_recommendation(d, context_hint)
  })
  names(recs) <- unique_rules
  recs
}

# ---------------------------------------------------------------------------
# Built-in deterministic recommendation table
# ---------------------------------------------------------------------------

builtin_recommendation <- function(diagnostic) {
  rule_id <- diagnostic$rule_id
  sev     <- diagnostic$severity

  priority <- switch(sev,
    error   = "critical",
    warning = "high",
    info    = "medium",
    "low"
  )

  entry <- BUILTIN_RECOMMENDATIONS[[rule_id]]

  if (is.null(entry)) {
    return(new_recommendation(
      rule_id  = rule_id,
      why      = "This rule flagged a potential quality issue in your project.",
      impact   = "Unaddressed issues may reduce maintainability or reproducibility.",
      fix      = diagnostic$suggestion %||% "Review the diagnostic and apply the suggested fix.",
      priority = priority
    ))
  }

  new_recommendation(
    rule_id    = rule_id,
    why        = entry$why,
    impact     = entry$impact,
    fix        = entry$fix %||% diagnostic$suggestion,
    examples   = entry$examples   %||% character(0),
    references = entry$references %||% character(0),
    priority   = priority,
    provider   = "builtin"
  )
}

# ---------------------------------------------------------------------------
# Built-in recommendation table (deterministic, all rules covered)
# ---------------------------------------------------------------------------

BUILTIN_RECOMMENDATIONS <- list(

  `antipattern.globalAssign` = list(
    why      = "`<<-` mutates an environment outside the current function scope, creating hidden coupling that is invisible at the call site.",
    impact   = "Functions that appear to be pure (taking input and returning output) silently modify shared state, making behaviour hard to reason about, test, and debug across a multi-file project.",
    fix      = "Return the computed value from the function and assign it explicitly in the caller with `<-`.",
    examples = c(
      "# Before\nresult <<- expensive_computation()\n\n# After\nresult <- compute_expensive()\nassign_result <- function() { result <- expensive_computation(); result }"
    ),
    references = c("https://adv-r.hadley.nz/environments.html")
  ),

  `antipattern.setwd` = list(
    why      = "`setwd()` modifies the process-global working directory for the entire R session, affecting every subsequent relative-path operation.",
    impact   = "Scripts break silently when run from any directory other than the one the author used; CI pipelines and collaborators who clone the repo often run from different directories.",
    fix      = "Use `here::here()` to construct paths relative to the project root, or pass an explicit path argument.",
    examples = c(
      "# Before\nsetwd('/home/user/project')\ndf <- read.csv('data/raw.csv')\n\n# After\nlibrary(here)\ndf <- read.csv(here('data', 'raw.csv'))"
    ),
    references = c("https://here.r-lib.org/", "https://rstats.wtf/project-oriented-workflow.html")
  ),

  `antipattern.hardcodedPath` = list(
    why      = "Absolute paths tie the project to the author's specific machine; they cannot be reproduced on any other system.",
    impact   = "Collaborators and CI environments will see file-not-found errors when running the code.",
    fix      = "Replace absolute paths with relative paths built using `here::here()` or `file.path()` from the project root.",
    references = c("https://here.r-lib.org/")
  ),

  `antipattern.assign` = list(
    why      = "`assign()` creates variables under names that are dynamic strings, making it impossible to know statically what names exist in a given environment.",
    impact   = "Downstream code that reads those variables is fragile; IDEs and static analysis tools cannot trace the data flow.",
    fix      = "Use a named list or data frame to hold the collection of values instead of creating dynamic variable names.",
    examples = c(
      "# Before\nfor (i in 1:3) assign(paste0('x', i), i^2)\n\n# After\nx <- setNames(lapply(1:3, function(i) i^2), paste0('x', 1:3))"
    )
  ),

  `dependency.circular` = list(
    why      = "Circular dependencies mean that module A depends on module B, which in turn depends on A. No loading order resolves this cleanly.",
    impact   = "The project becomes impossible to understand incrementally (you must understand everything at once), and refactoring one module forces changes to all others in the cycle.",
    fix      = "Introduce a shared lower-level layer containing the shared functionality, and have both A and B depend on it rather than on each other.",
    references = c("https://en.wikipedia.org/wiki/Circular_dependency")
  ),

  `complexity.cyclomatic` = list(
    why      = "Cyclomatic complexity measures the number of independent paths through a function. High complexity means many things can go wrong.",
    impact   = "Functions with cyclomatic complexity above ~10-15 are statistically harder to test, more likely to contain bugs, and slower to onboard new contributors to.",
    fix      = "Extract each major branch into a smaller, single-purpose helper function with a clear name.",
    references = c("https://en.wikipedia.org/wiki/Cyclomatic_complexity")
  ),

  `complexity.functionLength` = list(
    why      = "Long functions violate the single-responsibility principle -- they typically do several things at once.",
    impact   = "They are harder to test (requiring many test cases to cover all code paths), harder to read, and harder to refactor safely.",
    fix      = "Identify logical phases in the function (input validation, computation, output formatting) and extract each into a named helper."
  ),

  `documentation.missing` = list(
    why      = "Exported functions without documentation cannot be discovered through `?function_name` or the pkgdown site.",
    impact   = "Users and collaborators cannot understand how to call the function without reading the source code.",
    fix      = "Add a roxygen2 `#'` comment block above the function with at minimum `@param`, `@return`, and `@examples`."
  ),

  `reproducibility.renvLock` = list(
    why      = "Without a lock file, `install.packages()` in a fresh environment may install different package versions than those used when the analysis was run.",
    impact   = "Results may change silently across R upgrades or CRAN updates, making it impossible to reproduce published findings.",
    fix      = "Run `renv::init()` to create a project-local library, then `renv::snapshot()` to write renv.lock.",
    references = c("https://rstudio.github.io/renv/")
  ),

  `reproducibility.randomSeed` = list(
    why      = "Without a fixed random seed, any function that uses R's random-number generator produces different results on every run.",
    impact   = "Statistical analyses, train/test splits, bootstraps, and simulations are not reproducible.",
    fix      = "Add `set.seed(<integer>)` before the first random call. Document the seed value in the methods section of any resulting publication.",
    examples = c("set.seed(42)  # chosen arbitrarily; document in methods\nsample(100, 10)")
  ),

  `reproducibility.externalDownload` = list(
    why      = "Downloads depend on network availability and server uptime; the remote data may change or be removed after publication.",
    impact   = "Analyses that re-download data on every run may silently produce different results if upstream data changes.",
    fix      = "Cache the downloaded file locally in `data-raw/` and load from the local copy. Use `tools::md5sum()` to verify the cached file matches the expected hash.",
    references = c("https://r-pkgs.org/data.html#sec-data-raw")
  ),

  `reproducibility.sessionInfo` = list(
    why      = "Session information records the exact R version, OS, and package versions active during an analysis run.",
    impact   = "Without it, debugging reproducibility failures requires guessing which environment produced the original results.",
    fix      = "Add `sessioninfo::session_info()` at the end of your analysis script or report, and commit its output alongside results.",
    examples = c("# At end of analysis script\nsessioninfo::session_info() |> capture.output() |> writeLines('session_info.txt')")
  ),

  `datatrace.readError` = list(
    why      = "A data file that cannot be parsed will silently produce an empty or corrupt data frame, or throw an error that stops the analysis.",
    impact   = "Downstream results are wrong or the pipeline fails; the error may not be caught until a late stage of analysis.",
    fix      = "Open the file in a text editor or hex viewer to identify the encoding or structural issue. Re-export from the source system with consistent UTF-8 encoding and delimiter."
  ),

  `datatrace.schemaDocumentation` = list(
    why      = "Without a data dictionary, the meaning of column names, units, and valid value ranges is ambiguous to anyone not involved in data collection.",
    impact   = "Collaborators and future users (including yourself) misinterpret variables, leading to analytical errors.",
    fix      = "Create a codebook CSV or README.md in the data/ directory documenting each column: name, type, units, valid range, and source.",
    references = c("https://www.go-fair.org/fair-principles/")
  ),

  `docstrace.readme` = list(
    why      = "A README is the first file anyone sees when encountering a project. Without it, there is no discoverable starting point.",
    impact   = "Potential users, contributors, and reviewers cannot quickly assess whether the project meets their needs.",
    fix      = "Create README.md with at minimum: what the project does, installation instructions, and a quick-start example."
  ),

  `packageqa.descriptionComplete` = list(
    why      = "CRAN requires specific DESCRIPTION fields for package submission. Missing fields cause `R CMD check` errors or warnings.",
    impact   = "The package cannot be submitted to CRAN or Bioconductor without all required fields. Incomplete metadata also reduces discoverability.",
    fix      = "Complete all required DESCRIPTION fields. Use `usethis::use_description()` or `devtools::check()` to validate.",
    references = c("https://cran.r-project.org/doc/manuals/R-exts.html#The-DESCRIPTION-file")
  ),

  `packageqa.testCoverage` = list(
    why      = "Without tests, changes to the code cannot be verified not to introduce regressions.",
    impact   = "CRAN packages with zero tests are a signal of poor code quality. Bugs are discovered in production rather than during development.",
    fix      = "Add a test suite with `usethis::use_testthat()` and write at least one test per exported function.",
    references = c("https://r-pkgs.org/testing-basics.html")
  ),

  `packageqa.licensePresent` = list(
    why      = "Without an explicit license, copyright law defaults to 'all rights reserved', meaning no one can legally use, modify, or distribute the code.",
    impact   = "Users and organisations cannot adopt the package without legal risk. CRAN and Bioconductor require an OSI-approved license.",
    fix      = "Add a license with `usethis::use_mit_license()`, `use_apache_license()`, or `use_gpl3_license()` depending on your requirements.",
    references = c("https://choosealicense.com/", "https://r-pkgs.org/license.html")
  )
)
