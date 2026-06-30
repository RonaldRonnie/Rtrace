#' Rule: Shiny app entrypoint structure
#'
#' Flags two structural problems specific to Shiny apps, but only when the
#' project actually imports `shiny` somewhere (so this rule is a no-op, not
#' a noisy default, for non-Shiny projects):
#'
#' 1. A directory has *both* an `app.R` and a `ui.R`/`server.R` pair — Shiny
#'    only recognizes one entrypoint convention per app directory, and
#'    having both is a conflicting, easy-to-miss configuration mistake.
#' 2. The project uses `shiny` but no directory has either a valid `app.R`
#'    or a `ui.R`+`server.R` pair at all — `shiny::runApp()` would have
#'    nothing to find.
#'
#' Config: `type: ecosystem.shinyStructure`, no parameters.
#'
#' @return A [Rule] instance.
#' @keywords internal
#' @noRd
rule_ecosystem_shiny_structure <- function() {
  Rule$new(
    id = "ecosystem.shinyStructure",
    description = "Flags missing or conflicting Shiny app entrypoint conventions (app.R vs ui.R+server.R).",
    default_severity = "warning",
    default_params = list(),
    check_fn = function(context, params) {
      uses_shiny <- any(vapply(
        context$dependency_graph$package_imports, function(pkgs) "shiny" %in% pkgs, logical(1)
      ))
      if (!uses_shiny) return(list())

      basenames <- basename(context$files$rel_path)
      dirs <- dirname(context$files$rel_path)
      dirs[dirs == "."] <- "(root)"

      has_app <- tapply(basenames == "app.R", dirs, any)
      has_ui <- tapply(basenames == "ui.R", dirs, any)
      has_server <- tapply(basenames == "server.R", dirs, any)
      all_dirs <- unique(dirs)

      diags <- list()
      found_valid_entrypoint <- FALSE

      for (d in all_dirs) {
        app_here <- isTRUE(has_app[[d]])
        pair_here <- isTRUE(has_ui[[d]]) && isTRUE(has_server[[d]])

        if (app_here && pair_here) {
          diags[[length(diags) + 1]] <- new_diagnostic(
            rule_id = "ecosystem.shinyStructure",
            severity = "warning",
            file = if (d == "(root)") "app.R" else file.path(d, "app.R"),
            message = sprintf(
              "Directory '%s' has both an app.R and a ui.R/server.R pair; Shiny only recognizes one entrypoint convention per app.",
              d
            ),
            suggestion = "Pick one Shiny entrypoint convention: a single app.R, or a ui.R + server.R pair, not both."
          )
        }
        if (app_here || pair_here) found_valid_entrypoint <- TRUE
      }

      if (!found_valid_entrypoint) {
        diags[[length(diags) + 1]] <- new_diagnostic(
          rule_id = "ecosystem.shinyStructure",
          severity = "warning",
          file = "(project)",
          message = "The shiny package is used, but no app.R or ui.R+server.R entrypoint was found.",
          suggestion = "Add an app.R (or a ui.R + server.R pair) so the app can be run with shiny::runApp()."
        )
      }

      diags
    }
  )
}
