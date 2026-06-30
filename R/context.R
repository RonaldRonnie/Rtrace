#' Build a rule evaluation context
#'
#' Bundles everything a [Rule] needs so rules never re-walk the filesystem
#' or re-parse files themselves (see ADR 0002).
#'
#' @param root Character scalar, project root (absolute, normalized).
#' @param config An `rtrace_config` object.
#' @param files A `data.frame` as returned by [scan_files()].
#' @param asts A named list of `rtrace_file_ast`, keyed by absolute path.
#' @param dependency_graph A list as returned by [build_dependency_graph()].
#' @return An object of class `rtrace_context`.
#' @export
new_context <- function(root, config, files, asts, dependency_graph) {
  structure(
    list(
      root = root,
      config = config,
      files = files,
      asts = asts,
      dependency_graph = dependency_graph
    ),
    class = "rtrace_context"
  )
}

#' Build a full rule-evaluation context for a project directory
#'
#' Orchestrates [scan_files()], [parse_file()] (one call per discovered
#' file), and [build_dependency_graph()] into a single [new_context()].
#' This is the function the CLI's `scan` command and [run_scan()] call;
#' most users will not call it directly.
#'
#' @param root Character scalar path to the project root.
#' @param config An `rtrace_config` object.
#' @return An `rtrace_context` object.
#' @export
build_context <- function(root, config) {
  root <- normalizePath(root, mustWork = TRUE)
  files <- scan_files(root, config)

  asts <- stats::setNames(
    lapply(files$path, parse_file),
    files$path
  )

  dependency_graph <- build_dependency_graph(files, asts, root = root)

  new_context(root, config, files, asts, dependency_graph)
}

#' Convert an absolute path to a project-relative path, for diagnostics
#' @param context An `rtrace_context`.
#' @param path Character scalar absolute path.
#' @return Character scalar relative path.
#' @export
relative_path <- function(context, path) {
  idx <- match(path, context$files$path)
  if (!is.na(idx)) return(context$files$rel_path[idx])
  rel <- sub(paste0("^", gsub("([.()+^$|*?\\\\])", "\\\\\\1", context$root), "/?"), "", path)
  rel
}
