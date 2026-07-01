#' Build a project dependency graph
#'
#' Produces two graphs from a set of parsed files: a package-level graph
#' (which CRAN/Bioconductor packages each file imports) and a layer-level
#' graph (which configured layers reference which other layers, derived
#' from `source()` calls whose target resolves to a file in a different
#' layer). See ADR 0002 in `dev/adr/` in the package source for the
#' resolution heuristics and known limitations.
#'
#' @param files A `data.frame` as returned by [scan_files()] (`path`,
#'   `rel_path`, `layer`).
#' @param asts A named list of `rtrace_file_ast`, keyed by `path`, one entry
#'   per row of `files`.
#' @param root Character scalar, the project root `source()` arguments are
#'   tried against first (the dominant convention: analysis scripts are run
#'   from the project root and `source()` project-root-relative paths).
#'   Falls back to resolving relative to the sourcing file's own directory
#'   if no project-root-relative match exists.
#' @return A list with `package_imports` (named list: `rel_path` ->
#'   character vector of imported package names) and `layer_graph` (named
#'   list: layer name -> character vector of layer names it references).
#' @export
build_dependency_graph <- function(files, asts, root = NULL) {
  package_imports <- list()
  layer_edges <- list()

  fwd <- function(p) gsub("\\\\", "/", normalizePath(p, mustWork = FALSE))
  path_to_layer <- as.list(stats::setNames(files$layer, fwd(files$path)))
  rel_to_abs <- stats::setNames(files$path, files$rel_path)

  for (i in seq_len(nrow(files))) {
    path <- files$path[i]
    rel_path <- files$rel_path[i]
    layer <- files$layer[i]
    ast <- asts[[path]]
    if (is.null(ast) || is.null(ast$parse_data)) next

    pkgs <- extract_package_imports(ast)
    package_imports[[rel_path]] <- pkgs

    targets <- extract_source_targets(ast, base_dir = dirname(path), root = root)
    for (target in targets) {
      target_layer <- path_to_layer[[fwd(target)]]
      if (is.null(target_layer) || is.na(target_layer) || identical(target_layer, layer)) next
      layer_edges[[layer]] <- union(layer_edges[[layer]] %||% character(0), target_layer)
    }
  }

  list(package_imports = package_imports, layer_graph = layer_edges)
}

#' Extract package names imported by a file
#'
#' Looks for `library(pkg)`, `require(pkg)`, `requireNamespace("pkg")`, and
#' `pkg::fn` / `pkg:::fn` usages.
#'
#' @param ast An `rtrace_file_ast`.
#' @return Character vector of unique package names.
#' @export
extract_package_imports <- function(ast) {
  stopifnot(inherits(ast, "rtrace_file_ast"))
  if (is.null(ast$parse_data)) return(character(0))
  pd <- ast$parse_data

  pkgs <- character(0)

  for (fn in c("library", "require", "requireNamespace", "loadNamespace")) {
    calls <- find_calls(ast, fn)
    if (nrow(calls) == 0) next
    if (is.null(ast$expr)) next
    for (e in all_calls_named(ast$expr, fn)) {
      if (length(e) >= 2) {
        arg <- e[[2]]
        nm <- if (is.symbol(arg)) as.character(arg) else if (is.character(arg)) arg else NA_character_
        if (!is.na(nm)) pkgs <- c(pkgs, nm)
      }
    }
  }

  ns_tokens <- pd[pd$token %in% c("SYMBOL_PACKAGE"), , drop = FALSE]
  if (nrow(ns_tokens) > 0) pkgs <- c(pkgs, ns_tokens$text)

  unique(pkgs)
}

#' Recursively collect all calls to a given function name from an
#' expression vector, returning the call objects themselves (not just
#' locations).
#' @param expr A parsed `expression` object or call.
#' @param fn_name Character scalar function name.
#' @return A list of call objects.
#' @keywords internal
#' @noRd
all_calls_named <- function(expr, fn_name) {
  out <- list()
  walk <- function(e) {
    if (is.call(e)) {
      head <- tryCatch(as.character(e[[1]]), error = function(err) "")
      if (length(head) == 1 && head == fn_name) {
        out[[length(out) + 1]] <<- e
      }
      for (i in seq_along(e)) walk(e[[i]])
    } else if (is.pairlist(e)) {
      for (i in seq_along(e)) walk(e[[i]])
    }
  }
  for (e in as.list(expr)) walk(e)
  out
}

#' Extract `source()` target file paths, resolved to absolute paths
#'
#' Only string-literal `source("...")` targets are resolved; dynamically
#' constructed paths (e.g. `source(file.path(...))`) are skipped, a
#' documented limitation (see ADR 0002).
#'
#' @param ast An `rtrace_file_ast`.
#' @param base_dir Fallback directory the relative `source()` argument is
#'   resolved against (the sourcing file's own directory) when a
#'   project-root-relative match does not exist.
#' @param root Optional project root, tried first (see [build_dependency_graph()]).
#' @return Character vector of normalized absolute paths (only for targets
#'   that exist on disk).
#' @export
extract_source_targets <- function(ast, base_dir, root = NULL) {
  stopifnot(inherits(ast, "rtrace_file_ast"))
  if (is.null(ast$expr)) return(character(0))

  targets <- character(0)
  for (e in all_calls_named(ast$expr, "source")) {
    if (length(e) < 2) next
    arg <- e[[2]]
    if (!is.character(arg)) next

    if (isAbsolutePath(arg)) {
      candidate <- arg
    } else {
      root_candidate <- if (!is.null(root)) file.path(root, arg) else NA_character_
      candidate <- if (!is.na(root_candidate) && file.exists(root_candidate)) {
        root_candidate
      } else {
        file.path(base_dir, arg)
      }
    }

    if (file.exists(candidate)) {
      targets <- c(targets, normalizePath(candidate, mustWork = FALSE))
    }
  }
  unique(targets)
}

#' Test whether a path is absolute (POSIX or Windows style)
#' @param path Character scalar.
#' @return Logical scalar.
#' @keywords internal
#' @noRd
isAbsolutePath <- function(path) {
  grepl("^(/|[A-Za-z]:[\\\\/])", path)
}

#' Find cycles in a directed graph
#'
#' DFS-based cycle detection over an adjacency-list graph, used for the
#' `dependency.circular` rule over the layer-level dependency graph.
#'
#' @param graph A named list: node name -> character vector of node names
#'   it points to.
#' @return A list of character vectors, each one a cycle expressed as a
#'   sequence of node names (first element repeated as the last to show
#'   closure). Empty list if the graph is acyclic.
#' @export
find_cycles <- function(graph) {
  cycles <- list()
  visited <- character(0)
  stack <- character(0)

  visit <- function(node) {
    if (node %in% stack) {
      cycle_start <- which(stack == node)
      cycle <- c(stack[cycle_start:length(stack)], node)
      cycles[[length(cycles) + 1]] <<- cycle
      return(invisible())
    }
    if (node %in% visited) return(invisible())

    stack <<- c(stack, node)
    for (neighbor in graph[[node]] %||% character(0)) {
      visit(neighbor)
    }
    stack <<- stack[-length(stack)]
    visited <<- c(visited, node)
  }

  for (node in names(graph)) visit(node)

  # De-duplicate cycles that are rotations of each other.
  canon <- function(cycle) {
    body <- cycle[-length(cycle)]
    rotations <- lapply(seq_along(body), function(i) {
      c(body[i:length(body)], body[seq_len(i - 1)])
    })
    rotation_keys <- vapply(rotations, paste, character(1), collapse = "|")
    min(rotation_keys)
  }
  if (length(cycles) > 0) {
    keys <- vapply(cycles, canon, character(1))
    cycles <- cycles[!duplicated(keys)]
  }
  cycles
}
