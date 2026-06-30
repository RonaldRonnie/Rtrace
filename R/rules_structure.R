#' Rule: required project-structure directories
#'
#' Flags missing directories that a project's policy requires (e.g. every
#' package should have `R/` and `tests/`).
#'
#' Config: `type: structure.requiredDirs`, param `dirs` (character vector
#' of paths relative to the project root, default `c("R", "tests")`).
#'
#' @return A [Rule] instance.
#' @keywords internal
#' @noRd
rule_structure_required_dirs <- function() {
  Rule$new(
    id = "structure.requiredDirs",
    description = "Flags required project directories that are missing.",
    default_severity = "warning",
    default_params = list(dirs = c("R", "tests")),
    check_fn = function(context, params) {
      diags <- list()
      for (d in params$dirs) {
        full <- file.path(context$root, d)
        if (!dir.exists(full)) {
          diags[[length(diags) + 1]] <- new_diagnostic(
            rule_id = "structure.requiredDirs",
            severity = "warning",
            file = d,
            message = sprintf("Required directory '%s' is missing.", d),
            suggestion = sprintf("Create the '%s' directory.", d)
          )
        }
      }
      diags
    }
  )
}
