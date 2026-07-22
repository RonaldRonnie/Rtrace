#' Plugin Discovery System
#'
#' Automatic plugin discovery was deferred from the 0.1.0 release (noted in
#' ADR 0002 and the roadmap). This module implements it, on demand via
#' [discover_plugins()] -- it is **not** run automatically at package load
#' time (`.onLoad()` never calls it): the discovery system scans every
#' installed package for a `Config/rtrace/plugin` field in its DESCRIPTION
#' file. A package merely setting that field is not sufficient to get its
#' code run, though -- [discover_plugins()] only calls `requireNamespace()`
#' (which triggers the package's own `.onLoad()` to self-register its rules
#' via `RTrace::register_rule()`) for packages the caller has explicitly
#' allowlisted via [plugin_allowlist()]. Self-declaration alone is treated as
#' untrusted, since any locally installed package could otherwise get
#' arbitrary code executed just by adding one DESCRIPTION field.
#'
#' The same field name convention also applies to platform modules: a package
#' with `Config/rtrace/platform-module: true` in DESCRIPTION will have its
#' `register_platform_module()` (or equivalent) function called.
#'
#' @name plugin-discovery
NULL

#' Resolve the RTrace plugin allowlist
#'
#' [discover_plugins()] never trusts a package's own self-declaration alone
#' -- it only calls `requireNamespace()` (and therefore only runs
#' `.onLoad()`) for packages named in this allowlist, even if other
#' installed packages also set `Config/rtrace/plugin: true`.
#'
#' Precedence: the `rtrace.plugin.allowlist` R option, then the
#' `RTRACE_PLUGIN_ALLOWLIST` environment variable (comma-separated package
#' names), then an empty allowlist (nothing is loaded automatically).
#'
#' @return Character vector of allowlisted package names.
#' @export
plugin_allowlist <- function() {
  opt <- getOption("rtrace.plugin.allowlist")
  if (!is.null(opt)) return(as.character(opt))

  env <- Sys.getenv("RTRACE_PLUGIN_ALLOWLIST", "")
  if (nzchar(env)) return(trimws(strsplit(env, ",", fixed = TRUE)[[1]]))

  character(0)
}

#' Discover and load installed RTrace plugin packages
#'
#' Scans every installed package in [.libPaths()] for the
#' `Config/rtrace/plugin` DESCRIPTION field. A package with this field set
#' to `"true"` (case-insensitive) is only loaded with [requireNamespace()]
#' (which triggers the package's `.onLoad()` to self-register its rules) if
#' it also appears in `allowlist` -- self-declaration in DESCRIPTION is not,
#' by itself, treated as authorization to run the package's code (Issue
#' #13). Packages found but not allowlisted are reported via `verbose`
#' messages, not loaded.
#'
#' Safe to call multiple times — already-registered rules are not
#' double-registered (they produce a warning and overwrite, per
#' [register_rule()]).
#'
#' @param lib_paths Character vector of library paths to scan. Defaults to
#'   [.libPaths()].
#' @param allowlist Character vector of package names permitted to be
#'   loaded. Defaults to [plugin_allowlist()]. A self-declared plugin
#'   package not in this vector is skipped.
#' @param verbose Logical; if `TRUE`, prints a line for each plugin found,
#'   loaded, or skipped. Default `FALSE`.
#' @return Invisibly, a character vector of plugin package names that were
#'   loaded.
#' @export
discover_plugins <- function(lib_paths = .libPaths(),
                              allowlist = plugin_allowlist(),
                              verbose = FALSE) {
  plugin_pkgs  <- character(0)
  skipped_pkgs <- character(0)

  for (lib in lib_paths) {
    if (!dir.exists(lib)) next

    pkg_dirs <- list.dirs(lib, recursive = FALSE, full.names = FALSE)

    for (pkg in pkg_dirs) {
      desc_path <- file.path(lib, pkg, "DESCRIPTION")
      if (!file.exists(desc_path)) next

      field <- read_description_field(desc_path, "Config/rtrace/plugin")
      if (is.null(field) || !isTRUE(tolower(trimws(field)) == "true")) next

      if (!(pkg %in% allowlist)) {
        skipped_pkgs <- c(skipped_pkgs, pkg)
        if (verbose) {
          message(sprintf(
            paste(
              "[RTrace plugin discovery] '%s' declares itself a plugin but",
              "is not on the allowlist; skipping. Trust it by adding it to",
              "options(rtrace.plugin.allowlist = ...) or the",
              "RTRACE_PLUGIN_ALLOWLIST environment variable."
            ),
            pkg
          ))
        }
        next
      }

      plugin_pkgs <- c(plugin_pkgs, pkg)

      loaded <- tryCatch({
        requireNamespace(pkg, quietly = TRUE)
        if (verbose) {
          message(sprintf("[RTrace plugin] Loaded '%s'", pkg))
        }
        TRUE
      }, error = function(e) {
        rlang::warn(sprintf(
          "RTrace plugin '%s' found but could not be loaded: %s", pkg, conditionMessage(e)
        ))
        FALSE
      })
    }
  }

  if (verbose && length(plugin_pkgs) == 0 && length(skipped_pkgs) == 0) {
    message("[RTrace plugin discovery] No plugin packages found.")
  }

  invisible(plugin_pkgs)
}

#' Check whether a package is an RTrace plugin
#'
#' @param pkg Character scalar package name.
#' @return Logical scalar.
#' @export
is_rtrace_plugin <- function(pkg) {
  desc_path <- system.file("DESCRIPTION", package = pkg)
  if (!nzchar(desc_path)) return(FALSE)
  field <- read_description_field(desc_path, "Config/rtrace/plugin")
  isTRUE(tolower(trimws(field %||% "")) == "true")
}

#' List all installed RTrace plugin packages
#'
#' @param lib_paths Character vector of library paths. Defaults to
#'   [.libPaths()].
#' @return Character vector of package names.
#' @export
list_plugin_packages <- function(lib_paths = .libPaths()) {
  plugins <- character(0)
  for (lib in lib_paths) {
    if (!dir.exists(lib)) next
    for (pkg in list.dirs(lib, recursive = FALSE, full.names = FALSE)) {
      desc_path <- file.path(lib, pkg, "DESCRIPTION")
      if (!file.exists(desc_path)) next
      field <- read_description_field(desc_path, "Config/rtrace/plugin")
      if (isTRUE(tolower(trimws(field %||% "")) == "true")) {
        plugins <- c(plugins, pkg)
      }
    }
  }
  plugins
}

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

#' Read a single field from a DESCRIPTION file without parsing the whole file
#'
#' @param desc_path Character scalar path to DESCRIPTION.
#' @param field Character scalar field name (e.g. `"Config/rtrace/plugin"`).
#' @return Character scalar field value, or `NULL` if not found.
#' @keywords internal
#' @noRd
read_description_field <- function(desc_path, field) {
  lines <- tryCatch(
    readLines(desc_path, warn = FALSE),
    error = function(e) character(0)
  )
  if (length(lines) == 0) return(NULL)

  pattern <- paste0("^", gsub(".", "\\.", field, fixed = TRUE), ":\\s*(.*)$")
  hits    <- regmatches(lines, regexec(pattern, lines))
  matches <- Filter(function(m) length(m) >= 2, hits)

  if (length(matches) == 0) return(NULL)
  trimws(matches[[1]][2])
}

#' Generate a DESCRIPTION snippet for a plugin package
#'
#' Helper for plugin package authors: returns the DESCRIPTION field lines
#' that register a package as an RTrace plugin.
#'
#' @param module_id Optional character scalar; if provided, also registers as
#'   a platform module with this id.
#' @return Character scalar of DESCRIPTION lines to add.
#' @export
plugin_description_snippet <- function(module_id = NULL) {
  lines <- "Config/rtrace/plugin: true"
  if (!is.null(module_id)) {
    lines <- c(lines, sprintf("Config/rtrace/module-id: %s", module_id))
  }
  paste(lines, collapse = "\n")
}
