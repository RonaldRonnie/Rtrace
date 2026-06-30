#' Incremental scanning: AST parse cache
#'
#' Caches parsed `rtrace_file_ast` objects (see [parse_file()]) on disk, keyed by an MD5
#' content hash per file, so repeated scans of a project (interactive
#' iteration, or CI runs across nearby commits) skip re-parsing files whose
#' content hasn't changed. This caches the *parse* step only — diagnostics
#' are always recomputed for the full project on every scan, because most
#' built-in rules read cross-file state (the dependency graph, all test
#' files for `testing.missingTests`, etc.) and a stale per-file diagnostic
#' cache could silently miss a violation introduced by a *different* file
#' changing. See [dev/roadmap.md](https://github.com/rtrace-dev/rtrace/blob/main/dev/roadmap.md)
#' for the rule-scope model a future per-rule diagnostic cache would need.
#'
#' Caching is opt-in (`use_cache = TRUE` to [build_context()]/[run_scan()],
#' or `--cache` on the CLI), not a silent default, so calling RTrace from
#' an R script or test never writes files to disk unless asked.
#'
#' @name ast-cache
NULL

#' Path to a project's AST cache file
#' @param root Character scalar project root.
#' @return Character scalar path (the file need not exist yet).
#' @export
cache_path <- function(root) {
  file.path(root, ".rtrace_cache", "ast-cache.rds")
}

#' Read a project's AST cache from disk
#'
#' @param root Character scalar project root.
#' @return A named list (absolute path -> `list(hash=, ast=)`). Empty list
#'   if no cache file exists, or if it exists but can't be read (corrupt
#'   cache files are treated as a cold cache, not an error).
#' @export
read_ast_cache <- function(root) {
  path <- cache_path(root)
  if (!file.exists(path)) return(list())
  tryCatch(readRDS(path), error = function(e) list())
}

#' Write a project's AST cache to disk
#'
#' @param root Character scalar project root.
#' @param cache A named list as returned by [read_ast_cache()].
#' @return Invisibly, `TRUE`.
#' @export
write_ast_cache <- function(root, cache) {
  path <- cache_path(root)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  saveRDS(cache, path)
  invisible(TRUE)
}

#' Compute a file's content hash
#' @param path Character scalar file path.
#' @return Character scalar MD5 hash, or `NA_character_` if the file
#'   doesn't exist.
#' @export
file_hash <- function(path) {
  unname(tools::md5sum(path))
}

#' Parse a set of files, reusing cached ASTs where the content hash matches
#'
#' @param paths Character vector of absolute file paths.
#' @param root Character scalar project root (used to locate the cache
#'   file).
#' @param use_cache Logical; if `FALSE`, parses every file fresh and
#'   doesn't touch the cache file at all (the default, non-caching, path).
#' @return A named list of `rtrace_file_ast`, keyed by absolute path —
#'   same shape as parsing every file directly with [parse_file()].
#' @export
parse_files_cached <- function(paths, root, use_cache = FALSE) {
  if (!use_cache) {
    return(stats::setNames(lapply(paths, parse_file), paths))
  }

  cache <- read_ast_cache(root)
  hashes <- stats::setNames(vapply(paths, file_hash, character(1)), paths)

  asts <- stats::setNames(vector("list", length(paths)), paths)
  for (path in paths) {
    cached <- cache[[path]]
    if (!is.null(cached) && identical(cached$hash, hashes[[path]]) && !is.na(hashes[[path]])) {
      asts[[path]] <- cached$ast
    } else {
      asts[[path]] <- parse_file(path)
    }
  }

  # Prune entries for files no longer present, so the cache doesn't grow
  # without bound as a project's files are renamed/removed over time.
  new_cache <- stats::setNames(
    lapply(paths, function(p) list(hash = hashes[[p]], ast = asts[[p]])),
    paths
  )
  write_ast_cache(root, new_cache)

  asts
}
