#' Default directories/files RTrace never scans
#'
#' @return Character vector of glob patterns, relative to the project root.
#' @export
default_excludes <- function() {
  c(
    ".git/**", ".Rproj.user/**", "renv/**", "renv.lock", "packrat/**",
    "man/**", "*.Rcheck/**", "docs/**", "_book/**", ".rtrace_cache/**"
  )
}

#' Translate a glob pattern to a regular expression
#'
#' Supports `*` (any characters except `/`), `**` (any characters including
#' `/`), and `?` (single character). Intentionally small: RTrace globs are
#' matched against POSIX-style relative paths only.
#'
#' @param glob Character scalar glob pattern.
#' @return Character scalar regular expression, anchored at both ends.
#' @export
glob_to_regex <- function(glob) {
  glob <- gsub("([.()+^$|])", "\\\\\\1", glob)
  glob <- gsub("**", "GLOBSTAR_PLACEHOLDER", glob, fixed = TRUE)
  glob <- gsub("*", "[^/]*", glob, fixed = TRUE)
  glob <- gsub("?", "[^/]", glob, fixed = TRUE)
  glob <- gsub("GLOBSTAR_PLACEHOLDER", ".*", glob, fixed = TRUE)
  paste0("^", glob, "$")
}

#' Test whether a relative path matches any of a set of glob patterns
#'
#' @param rel_path Character scalar, POSIX-style relative path.
#' @param globs Character vector of glob patterns.
#' @return Logical scalar.
#' @export
path_matches_any_glob <- function(rel_path, globs) {
  if (length(globs) == 0) return(FALSE)
  any(vapply(globs, function(g) grepl(glob_to_regex(g), rel_path), logical(1)))
}

#' Walk a project directory for R source files
#'
#' Discovers `.R`/`.r` files under `root`, skipping [default_excludes()]
#' plus any patterns declared in `config$exclude`, then assigns each
#' surviving file to a configured layer via longest-glob-prefix match
#' against `config$layers`.
#'
#' @param root Character scalar, path to the project root.
#' @param config An `rtrace_config` object (see [read_config()]).
#' @return A `data.frame` with columns `path` (absolute), `rel_path`
#'   (POSIX-style, relative to `root`), and `layer` (character;
#'   `"(unassigned)"` if no configured layer matches).
#' @export
scan_files <- function(root, config = default_config()) {
  root <- gsub("\\\\", "/", normalizePath(root, mustWork = TRUE))
  all_files <- list.files(
    root, pattern = "\\.[Rr]$", recursive = TRUE, full.names = TRUE,
    all.files = FALSE, no.. = TRUE
  )
  all_files <- gsub("\\\\", "/", normalizePath(all_files, mustWork = TRUE))
  if (length(all_files) == 0) {
    return(data.frame(
      path = character(0), rel_path = character(0), layer = character(0),
      stringsAsFactors = FALSE
    ))
  }

  rel_paths <- gsub("^/+", "", substring(all_files, nchar(root) + 1))
  rel_paths <- gsub("\\\\", "/", rel_paths)

  excludes <- c(default_excludes(), config$exclude)
  keep <- !vapply(rel_paths, path_matches_any_glob, logical(1), globs = excludes)

  all_files <- all_files[keep]
  rel_paths <- rel_paths[keep]

  layer_names <- names(config$layers)
  layer_for <- function(rp) {
    if (length(layer_names) == 0) return("(unassigned)")
    matches <- vapply(layer_names, function(ln) {
      path_matches_any_glob(rp, config$layers[[ln]])
    }, logical(1))
    if (!any(matches)) return("(unassigned)")
    # Longest pattern string wins on ambiguity (more specific match).
    candidates <- layer_names[matches]
    pattern_lens <- vapply(candidates, function(ln) max(nchar(config$layers[[ln]])), integer(1))
    candidates[[which.max(pattern_lens)]]
  }

  data.frame(
    path = all_files,
    rel_path = rel_paths,
    layer = vapply(rel_paths, layer_for, character(1)),
    stringsAsFactors = FALSE,
    row.names = NULL
  )
}
