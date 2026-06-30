#' Create a temporary project directory populated with the given files
#'
#' @param files Named character vector or list: name is the relative path,
#'   value is the file content.
#' @param env Environment the temp dir's lifetime is tied to (test scope by
#'   default).
#' @return Character scalar, the temp directory path.
local_project <- function(files, env = parent.frame()) {
  root <- withr::local_tempdir(.local_envir = env)
  for (rel_path in names(files)) {
    full <- file.path(root, rel_path)
    dir.create(dirname(full), recursive = TRUE, showWarnings = FALSE)
    writeLines(files[[rel_path]], full)
  }
  root
}
