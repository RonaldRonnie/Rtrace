#' DataTrace Engine
#'
#' Evaluates the quality and FAIR-compliance of research datasets stored in a
#' project. Scans for CSV, TSV, and Excel files, inspects their headers,
#' checks for schema consistency across multiple files of the same type,
#' detects missing metadata, and assesses FAIR (Findable, Accessible,
#' Interoperable, Reusable) readiness.
#'
#' Unlike the code-centric engines, DataTrace operates on tabular data files
#' rather than R source files — it uses only base R's `read.csv()` for CSV
#' handling to avoid introducing heavy data-package dependencies.
#'
#' @name datatrace-engine
NULL

#' Scan data files in a project root
#'
#' Finds all CSV, TSV, and (optionally) Excel files under `root`, skipping
#' hidden directories and common generated-output directories, and returns a
#' `data.frame` describing every discovered data file.
#'
#' @param root Character scalar project root.
#' @param max_rows Integer; maximum rows to read from each file for quality
#'   checks (default 1000, to keep scanning fast).
#' @return A `data.frame` with columns `path`, `rel_path`, `type`
#'   (`"csv"`, `"tsv"`, `"excel"`), `size_bytes`, `n_cols`, `n_rows_sample`,
#'   `col_names`, `has_header`, `encoding_ok`, `read_error`.
#' @export
scan_data_files <- function(root, max_rows = 1000L) {
  root <- normalizePath(root, mustWork = TRUE)

  skip_dirs  <- c(".git", "renv", "packrat", ".Rproj.user",
                  ".rtrace_cache", "node_modules", ".venv")
  csv_files  <- list.files(root, pattern = "\\.csv$",
                            recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
  tsv_files  <- list.files(root, pattern = "\\.tsv$",
                            recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
  txt_tab    <- list.files(root, pattern = "\\.txt$",
                            recursive = TRUE, full.names = TRUE, ignore.case = TRUE)

  all_files <- unique(c(csv_files, tsv_files, txt_tab))

  rel_fn <- function(p) {
    rel <- sub(paste0("^", gsub("([.()+^$|*?\\\\])", "\\\\\\1", root), "/?"), "", p)
    gsub("\\\\", "/", rel)
  }

  all_rel <- rel_fn(all_files)

  # Filter out files in skip directories
  in_skip <- vapply(all_rel, function(r) {
    any(vapply(skip_dirs, function(d) grepl(paste0("^", d, "/"), r), logical(1)))
  }, logical(1))

  all_files <- all_files[!in_skip]
  all_rel   <- all_rel[!in_skip]

  if (length(all_files) == 0) {
    return(data.frame(
      path = character(0), rel_path = character(0), type = character(0),
      size_bytes = integer(0), n_cols = integer(0), n_rows_sample = integer(0),
      col_names = character(0), has_header = logical(0),
      encoding_ok = logical(0), read_error = character(0),
      stringsAsFactors = FALSE
    ))
  }

  rows <- lapply(seq_along(all_files), function(i) {
    p   <- all_files[i]
    rel <- all_rel[i]
    ext <- tolower(tools::file_ext(p))
    type <- if (ext == "tsv") "tsv" else if (ext %in% c("csv", "txt")) "csv" else "unknown"

    size <- tryCatch(file.info(p)$size, error = function(e) NA_integer_)

    read_result <- tryCatch({
      sep <- if (type == "tsv") "\t" else ","
      # "incomplete final line" is emitted for any file not ending in a
      # newline -- extremely common and not a real parse/encoding problem
      # (Issue #8), so it is muffled here rather than propagating to the
      # warning handler below, which treats warnings as read failures.
      df  <- withCallingHandlers(
        utils::read.table(p, header = TRUE, sep = sep, nrows = max_rows,
                           stringsAsFactors = FALSE, fill = TRUE,
                           comment.char = "", quote = "\"",
                           fileEncoding = "UTF-8"),
        warning = function(w) {
          if (grepl("incomplete final line", conditionMessage(w), fixed = TRUE)) {
            invokeRestart("muffleWarning")
          }
        }
      )
      list(
        n_cols        = ncol(df),
        n_rows_sample = nrow(df),
        col_names     = paste(colnames(df), collapse = "|"),
        has_header    = TRUE,
        encoding_ok   = TRUE,
        read_error    = NA_character_
      )
    }, warning = function(w) {
      list(n_cols = NA_integer_, n_rows_sample = NA_integer_,
           col_names = NA_character_, has_header = NA,
           encoding_ok = FALSE, read_error = conditionMessage(w))
    }, error = function(e) {
      list(n_cols = NA_integer_, n_rows_sample = NA_integer_,
           col_names = NA_character_, has_header = NA,
           encoding_ok = FALSE, read_error = conditionMessage(e))
    })

    data.frame(
      path          = p,
      rel_path      = rel,
      type          = type,
      size_bytes    = as.integer(size),
      n_cols        = as.integer(read_result$n_cols),
      n_rows_sample = as.integer(read_result$n_rows_sample),
      col_names     = as.character(read_result$col_names %||% NA_character_),
      has_header    = as.logical(read_result$has_header),
      encoding_ok   = as.logical(read_result$encoding_ok),
      read_error    = as.character(read_result$read_error %||% NA_character_),
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, rows)
}

#' Run the DataTrace engine against a project
#'
#' @param root Character scalar project root.
#' @param config An `rtrace_config` object. Defaults to [default_config()].
#'   Every registered `datatrace.*` rule runs by default; a `config$rules`
#'   entry for a rule's id overrides its `enabled`/`severity`/`params`
#'   (Issue #11).
#' @return A list with `data_files` (the scan data frame from
#'   [scan_data_files()]), `diagnostics` (an `rtrace_diagnostic_set`),
#'   and `score` (a `trace_score`).
#' @export
run_datatrace_scan <- function(root = ".", config = default_config()) {
  root       <- normalizePath(root, mustWork = TRUE)
  data_files <- scan_data_files(root)

  datatrace_rules <- Filter(
    function(r) startsWith(r$id, "datatrace."),
    as.list(list_rules())
  )

  diags <- new_diagnostic_set()

  for (rule in datatrace_rules) {
    spec <- find_rule_spec(config, rule$id)
    if (!is.null(spec) && !isTRUE(spec$enabled)) next

    # Only override severity when the user has explicitly configured one for
    # this rule -- some rules emit diagnostics at multiple severities
    # (e.g. datatrace.jsonDataset), which a blanket override would collapse.
    override_severity <- if (!is.null(spec) && !is.na(spec$severity %||% NA_character_)) {
      spec$severity
    } else {
      NULL
    }
    params <- if (!is.null(spec)) {
      utils::modifyList(rule$default_params, spec$params %||% list())
    } else {
      rule$default_params
    }

    result <- tryCatch(
      rule$domain_fns$check_datatrace(data_files, root, params),
      error = function(e) {
        list(new_diagnostic(
          rule_id = "rule-error", severity = "error", file = "(datatrace-engine)",
          message = sprintf("DataTrace rule '%s' errored: %s", rule$id, conditionMessage(e))
        ))
      }
    )
    if (length(result) > 0) {
      if (inherits(result, "rtrace_diagnostic")) result <- list(result)
      if (!is.null(override_severity)) {
        result <- lapply(result, function(d) { d$severity <- override_severity; d })
      }
      diags  <- c(diags, new_diagnostic_set(result))
    }
  }

  score <- compute_score(
    diags,
    error_penalty   = 8,
    warning_penalty = 3,
    info_penalty    = 1
  )
  score$module_id <- "datatrace"

  list(data_files = data_files, diagnostics = diags, score = score)
}
