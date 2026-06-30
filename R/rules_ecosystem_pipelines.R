#' Rule: `targets` pipeline entrypoint
#'
#' Flags a project that imports the `targets` package but has no
#' `_targets.R` pipeline definition at the project root — the file
#' `targets::tar_make()` and friends require to exist. Self-gated on actual
#' `targets` usage, like `ecosystem.shinyStructure`.
#'
#' `drake` (the package `targets` superseded) is deliberately not covered
#' here: unlike `targets`, it has no single fixed conventional entrypoint
#' filename, so a presence check would be a guess rather than a real
#' structural convention.
#'
#' Config: `type: ecosystem.targetsStructure`, no parameters.
#'
#' @return A [Rule] instance.
#' @keywords internal
#' @noRd
rule_ecosystem_targets_structure <- function() {
  Rule$new(
    id = "ecosystem.targetsStructure",
    description = "Flags a targets pipeline project with no _targets.R at the project root.",
    default_severity = "warning",
    default_params = list(),
    check_fn = function(context, params) {
      uses_targets <- any(vapply(
        context$dependency_graph$package_imports, function(pkgs) "targets" %in% pkgs, logical(1)
      ))
      if (!uses_targets) return(list())

      has_targets_file <- "_targets.R" %in% context$files$rel_path
      if (has_targets_file) return(list())

      list(new_diagnostic(
        rule_id = "ecosystem.targetsStructure",
        severity = "warning",
        file = "(project)",
        message = "The targets package is used, but no _targets.R pipeline definition was found at the project root.",
        suggestion = "Add a _targets.R file defining the pipeline with targets::tar_target(), or run targets::use_targets()."
      ))
    }
  )
}

#' Rule: `plumber` API route annotations
#'
#' Flags a project that imports the `plumber` package but has no `#*`
#' route annotation comments (e.g. `#* @get /path`) anywhere — plumber
#' APIs are defined entirely through these annotations, so their absence
#' means `plumber::plumb()` would find no routes. Self-gated on actual
#' `plumber` usage.
#'
#' Config: `type: ecosystem.plumberStructure`, no parameters.
#'
#' @return A [Rule] instance.
#' @keywords internal
#' @noRd
rule_ecosystem_plumber_structure <- function() {
  Rule$new(
    id = "ecosystem.plumberStructure",
    description = "Flags a plumber API project with no #* route annotations anywhere.",
    default_severity = "warning",
    default_params = list(),
    check_fn = function(context, params) {
      uses_plumber <- any(vapply(
        context$dependency_graph$package_imports, function(pkgs) "plumber" %in% pkgs, logical(1)
      ))
      if (!uses_plumber) return(list())

      route_pattern <- "^#\\*\\s*@(get|post|put|delete|patch|head|options)\\b"
      has_route <- FALSE
      for (path in context$files$path) {
        ast <- context$asts[[path]]
        if (is.null(ast) || is.null(ast$parse_data)) next
        pd <- ast$parse_data
        comments <- pd$text[pd$token == "COMMENT"]
        if (any(grepl(route_pattern, comments, ignore.case = TRUE))) {
          has_route <- TRUE
          break
        }
      }
      if (has_route) return(list())

      list(new_diagnostic(
        rule_id = "ecosystem.plumberStructure",
        severity = "warning",
        file = "(project)",
        message = "The plumber package is used, but no #* route annotations (e.g. '#* @get /path') were found anywhere in the project.",
        suggestion = "Add #* @get/@post/etc. annotation comments above the functions that should be exposed as API routes."
      ))
    }
  )
}
