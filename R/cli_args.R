#' Parse RTrace CLI arguments
#'
#' A small, dependency-free `--flag value` parser (see ADR 0002 for why no
#' CLI-parsing package is used). Not a general-purpose parser: it is scoped
#' exactly to RTrace's own command set.
#'
#' @param argv Character vector, as returned by `commandArgs(trailingOnly = TRUE)`.
#' @return A list with `command` (character scalar or `NA`), `options`
#'   (named list of flag values; boolean flags get `TRUE`), and
#'   `positional` (character vector of non-flag, non-command arguments).
#' @export
parse_cli_args <- function(argv) {
  if (length(argv) == 0) {
    return(list(command = NA_character_, options = list(), positional = character(0)))
  }

  command <- argv[1]
  rest <- argv[-1]

  options <- list()
  positional <- character(0)

  i <- 1
  while (i <= length(rest)) {
    arg <- rest[i]
    if (startsWith(arg, "--")) {
      name <- sub("^--", "", arg)
      if (grepl("=", name, fixed = TRUE)) {
        parts <- strsplit(name, "=", fixed = TRUE)[[1]]
        options[[parts[1]]] <- paste(parts[-1], collapse = "=")
        i <- i + 1
      } else if (i < length(rest) && !startsWith(rest[i + 1], "--")) {
        options[[name]] <- rest[i + 1]
        i <- i + 2
      } else {
        options[[name]] <- TRUE
        i <- i + 1
      }
    } else {
      positional <- c(positional, arg)
      i <- i + 1
    }
  }

  list(command = command, options = options, positional = positional)
}
