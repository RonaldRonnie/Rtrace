#' DataTrace rules
#'
#' Rules for evaluating research dataset quality. All are prefixed
#' `datatrace.*`. They differ from the code-analysis rules in that their
#' `check_fn` receives a `data_files` data frame from [scan_data_files()]
#' rather than an `rtrace_context` -- they are run by the DataTrace engine,
#' not the standard rule engine.
#'
#' For compatibility with the standard rule engine interface (which passes
#' an `rtrace_context`), DataTrace rules implement an additional
#' `check_datatrace(data_files, root)` method on the Rule object. The
#' standard `check(context, params)` is a no-op so that the rule can be
#' registered in the global registry without interfering with standard scans.
#'
#' @name datatrace-rules
NULL

# ---------------------------------------------------------------------------
# DataTrace Rule base constructor
# ---------------------------------------------------------------------------

#' Construct a DataTrace-aware rule
#'
#' Creates a [Rule] instance whose `check_fn` is a no-op (so it is safe to
#' register in the global rule registry and be silently skipped during
#' standard scans), while exposing a `check_datatrace(data_files, root)`
#' function for the DataTrace engine.
#'
#' @param id,description,default_severity,default_params Standard Rule fields.
#' @param datatrace_fn A function `function(data_files, root, params)`
#'   returning a list of `rtrace_diagnostic` objects.
#' @return A [Rule] instance with an additional `check_datatrace` method.
#' @keywords internal
#' @noRd
datatrace_rule <- function(id, description, datatrace_fn,
                             default_severity = "info",
                             default_params   = list()) {
  rule <- Rule$new(
    id               = id,
    description      = description,
    default_severity = default_severity,
    default_params   = default_params,
    check_fn         = function(context, params) list()  # no-op in standard scans
  )
  params_captured <- default_params
  fn_captured     <- datatrace_fn
  rule$domain_fns$check_datatrace <- function(data_files, root,
                                               params = params_captured) {
    fn_captured(data_files, root, params)
  }
  rule
}

# ---------------------------------------------------------------------------
# datatrace.readError
# ---------------------------------------------------------------------------

rule_datatrace_read_error <- function() {
  datatrace_rule(
    id               = "datatrace.readError",
    description      = "Flags data files that cannot be parsed as CSV/TSV.",
    default_severity = "error",
    default_params   = list(),
    datatrace_fn = function(data_files, root, params) {
      if (nrow(data_files) == 0) return(list())
      broken <- data_files[!is.na(data_files$read_error) & nchar(data_files$read_error) > 0, ]
      if (nrow(broken) == 0) return(list())
      lapply(seq_len(nrow(broken)), function(i) {
        new_diagnostic(
          rule_id    = "datatrace.readError",
          severity   = "error",
          file       = broken$rel_path[i],
          message    = sprintf("Data file cannot be parsed: %s", broken$read_error[i]),
          suggestion = "Check the file for encoding issues, mixed delimiters, or truncation."
        )
      })
    }
  )
}

# ---------------------------------------------------------------------------
# datatrace.missingHeader
# ---------------------------------------------------------------------------

rule_datatrace_missing_header <- function() {
  datatrace_rule(
    id               = "datatrace.missingHeader",
    description      = "Flags CSV/TSV files with no header row (no column names).",
    default_severity = "warning",
    default_params   = list(),
    datatrace_fn = function(data_files, root, params) {
      if (nrow(data_files) == 0) return(list())
      no_header <- data_files[!is.na(data_files$has_header) &
                                !isTRUE(data_files$has_header), ]
      if (nrow(no_header) == 0) return(list())
      lapply(seq_len(nrow(no_header)), function(i) {
        new_diagnostic(
          rule_id    = "datatrace.missingHeader",
          severity   = "warning",
          file       = no_header$rel_path[i],
          message    = "Data file appears to have no header row; column semantics are ambiguous.",
          suggestion = "Add a header row with descriptive column names to make the dataset self-documenting."
        )
      })
    }
  )
}

# ---------------------------------------------------------------------------
# datatrace.encodingIssue
# ---------------------------------------------------------------------------

rule_datatrace_encoding_issue <- function() {
  datatrace_rule(
    id               = "datatrace.encodingIssue",
    description      = "Flags data files with non-UTF-8 encoding that triggers warnings on read.",
    default_severity = "warning",
    default_params   = list(),
    datatrace_fn = function(data_files, root, params) {
      if (nrow(data_files) == 0) return(list())
      bad_enc <- data_files[!is.na(data_files$encoding_ok) &
                              !isTRUE(data_files$encoding_ok), ]
      if (nrow(bad_enc) == 0) return(list())
      lapply(seq_len(nrow(bad_enc)), function(i) {
        new_diagnostic(
          rule_id    = "datatrace.encodingIssue",
          severity   = "warning",
          file       = bad_enc$rel_path[i],
          message    = "Data file produced encoding warnings when read as UTF-8.",
          suggestion = "Re-save the file as UTF-8 (use `readr::read_csv()` with `locale = locale(encoding = ...)` to detect and convert)."
        )
      })
    }
  )
}

# ---------------------------------------------------------------------------
# datatrace.noDataFiles
# ---------------------------------------------------------------------------

rule_datatrace_no_data_files <- function() {
  datatrace_rule(
    id               = "datatrace.noDataFiles",
    description      = "Flags analysis projects with no data files in any standard data/ directory.",
    default_severity = "info",
    default_params   = list(),
    datatrace_fn = function(data_files, root, params) {
      data_dirs <- c("data", "Data", "data-raw", "extdata", "inst/extdata")
      has_data_dir <- any(vapply(data_dirs, function(d) {
        dir.exists(file.path(root, d))
      }, logical(1)))

      if (!has_data_dir) return(list())
      if (nrow(data_files) > 0) return(list())

      list(new_diagnostic(
        rule_id    = "datatrace.noDataFiles",
        severity   = "info",
        file       = "(project)",
        message    = "Project has a data/ directory but no CSV/TSV data files were found.",
        suggestion = "Ensure data files are present and named with .csv or .tsv extensions."
      ))
    }
  )
}

# ---------------------------------------------------------------------------
# datatrace.largeCsvNoCompression
# ---------------------------------------------------------------------------

rule_datatrace_large_csv_no_compression <- function() {
  datatrace_rule(
    id               = "datatrace.largeCsvNoCompression",
    description      = "Flags CSV/TSV files larger than 10 MB that are stored uncompressed.",
    default_severity = "info",
    default_params   = list(threshold_mb = 10L),
    datatrace_fn = function(data_files, root, params) {
      if (nrow(data_files) == 0) return(list())
      threshold_bytes <- (params$threshold_mb %||% 10L) * 1024L * 1024L
      large <- data_files[!is.na(data_files$size_bytes) &
                            data_files$size_bytes > threshold_bytes, ]
      if (nrow(large) == 0) return(list())
      lapply(seq_len(nrow(large)), function(i) {
        size_mb <- round(large$size_bytes[i] / 1024 / 1024, 1)
        new_diagnostic(
          rule_id    = "datatrace.largeCsvNoCompression",
          severity   = "info",
          file       = large$rel_path[i],
          message    = sprintf(
            "Data file is %.1f MB. Consider compressing or using a more efficient format.", size_mb
          ),
          suggestion = "Save as .csv.gz (write with `readr::write_csv()` then `gzip`) or use `arrow::write_parquet()` for better performance."
        )
      })
    }
  )
}

# ---------------------------------------------------------------------------
# datatrace.schemaDocumentation
# ---------------------------------------------------------------------------

rule_datatrace_schema_documentation <- function() {
  datatrace_rule(
    id               = "datatrace.schemaDocumentation",
    description      = "Flags datasets with no accompanying data dictionary or schema file.",
    default_severity = "info",
    default_params   = list(),
    datatrace_fn = function(data_files, root, params) {
      if (nrow(data_files) == 0) return(list())

      schema_files <- list.files(root,
        pattern    = "(data.?dict|schema|codebook|README)(\\.(md|txt|csv|json|yaml|yml))?$",
        recursive  = TRUE, full.names = FALSE, ignore.case = TRUE
      )

      if (length(schema_files) > 0) return(list())

      list(new_diagnostic(
        rule_id    = "datatrace.schemaDocumentation",
        severity   = "info",
        file       = "(project)",
        message    = sprintf(
          "Project contains %d data file(s) but no data dictionary, schema file, or codebook was found.",
          nrow(data_files)
        ),
        suggestion = paste(
          "Create a data dictionary (e.g. data/README.md or data/codebook.csv) documenting",
          "each column's name, type, units, and valid values."
        )
      ))
    }
  )
}

# ---------------------------------------------------------------------------
# datatrace.fairFindable
# ---------------------------------------------------------------------------

rule_datatrace_fair_findable <- function() {
  datatrace_rule(
    id               = "datatrace.fairFindable",
    description      = "FAIR check: Findable -- flags data files not in a standard data/ directory.",
    default_severity = "info",
    default_params   = list(),
    datatrace_fn = function(data_files, root, params) {
      if (nrow(data_files) == 0) return(list())

      standard_data_dirs <- c("^data/", "^Data/", "^data-raw/",
                               "^inst/extdata/", "^extdata/")

      not_in_data <- data_files[!vapply(data_files$rel_path, function(r) {
        any(vapply(standard_data_dirs, function(p) grepl(p, r), logical(1)))
      }, logical(1)), ]

      if (nrow(not_in_data) == 0) return(list())

      lapply(seq_len(nrow(not_in_data)), function(i) {
        new_diagnostic(
          rule_id    = "datatrace.fairFindable",
          severity   = "info",
          file       = not_in_data$rel_path[i],
          message    = "Data file is not in a standard data/ directory (FAIR: Findable).",
          suggestion = "Move data files to data/, data-raw/, or inst/extdata/ so they are consistently findable."
        )
      })
    }
  )
}

# ---------------------------------------------------------------------------
# datatrace.fairAccessible
# ---------------------------------------------------------------------------

rule_datatrace_fair_accessible <- function() {
  datatrace_rule(
    id               = "datatrace.fairAccessible",
    description      = "FAIR check: Accessible -- flags projects with no open access or license statement for data.",
    default_severity = "info",
    default_params   = list(),
    datatrace_fn = function(data_files, root, params) {
      if (nrow(data_files) == 0) return(list())

      # Look for any data license / access statement
      access_patterns <- c("LICENSE", "DATA_LICENSE", "data-license", "ACCESS",
                            "access", "zenodo", "doi", "figshare", "dryad")
      found_access <- any(vapply(access_patterns, function(p) {
        length(list.files(root, pattern = p, recursive = FALSE, ignore.case = TRUE)) > 0
      }, logical(1)))

      if (found_access) return(list())

      # Check README for DOI / access info
      readme_files <- list.files(root, pattern = "^README\\.(md|txt|Rmd)$",
                                  ignore.case = TRUE, full.names = TRUE)
      if (length(readme_files) > 0) {
        readme_text <- tryCatch(
          paste(readLines(readme_files[1], warn = FALSE), collapse = " "),
          error = function(e) ""
        )
        if (grepl("doi|zenodo|figshare|dryad|data access|open data", readme_text, ignore.case = TRUE)) {
          return(list())
        }
      }

      list(new_diagnostic(
        rule_id    = "datatrace.fairAccessible",
        severity   = "info",
        file       = "(project)",
        message    = "No data access statement, DOI, or data license was found (FAIR: Accessible).",
        suggestion = paste(
          "Add a data access statement to your README, or deposit data in a public repository",
          "(Zenodo, Figshare, Dryad) and include the DOI."
        )
      ))
    }
  )
}

# ---------------------------------------------------------------------------
# datatrace.fairInteroperable
# ---------------------------------------------------------------------------

rule_datatrace_fair_interoperable <- function() {
  datatrace_rule(
    id               = "datatrace.fairInteroperable",
    description      = "FAIR check: Interoperable -- prefers open, non-proprietary data formats.",
    default_severity = "info",
    default_params   = list(),
    datatrace_fn = function(data_files, root, params) {
      # Look for proprietary format files (.xls, .xlsx, .sav, .dta, .sas7bdat)
      proprietary_exts <- c("xls", "xlsx", "sav", "dta", "sas7bdat", "mdb", "accdb")
      pattern <- paste0("\\.(", paste(proprietary_exts, collapse = "|"), ")$")

      prop_files <- list.files(root, pattern = pattern,
                                recursive = TRUE, full.names = FALSE,
                                ignore.case = TRUE)

      # Exclude renv/node_modules
      prop_files <- prop_files[!grepl("^(renv|node_modules|\\.git)/", prop_files)]

      if (length(prop_files) == 0) return(list())

      lapply(prop_files, function(f) {
        ext <- tolower(tools::file_ext(f))
        new_diagnostic(
          rule_id    = "datatrace.fairInteroperable",
          severity   = "info",
          file       = f,
          message    = sprintf(
            "Data file uses proprietary format (.%s) which limits interoperability (FAIR: Interoperable).", ext
          ),
          suggestion = paste(
            "Export to an open format (CSV for tabular data, Parquet for large datasets,",
            "JSON-LD for linked data) alongside or instead of the proprietary format."
          )
        )
      })
    }
  )
}

# ---------------------------------------------------------------------------
# datatrace.fairReusable
# ---------------------------------------------------------------------------

rule_datatrace_fair_reusable <- function() {
  datatrace_rule(
    id               = "datatrace.fairReusable",
    description      = "FAIR check: Reusable -- flags datasets lacking provenance or rich metadata.",
    default_severity = "info",
    default_params   = list(),
    datatrace_fn = function(data_files, root, params) {
      if (nrow(data_files) == 0) return(list())

      # FAIR Reusable: look for provenance markers
      provenance_files <- c("PROVENANCE", "provenance", "MANIFEST", "manifest",
                             "metadata.json", "metadata.yaml", "metadata.yml",
                             "datapackage.json")
      has_provenance <- any(vapply(provenance_files, function(f) {
        file.exists(file.path(root, f)) ||
          file.exists(file.path(root, "data", f))
      }, logical(1)))

      if (has_provenance) return(list())

      # Check if data README mentions provenance/collection methodology
      readme_files <- c(
        file.path(root, "data", "README.md"),
        file.path(root, "data", "README.txt"),
        list.files(root, pattern = "^README\\.", full.names = TRUE, ignore.case = TRUE)
      )
      has_prov_text <- any(vapply(readme_files[file.exists(readme_files)], function(f) {
        txt <- tryCatch(paste(readLines(f, warn = FALSE), collapse = " "), error = function(e) "")
        grepl("collected|provenance|source|methodology|acquisition|created by|generated",
              txt, ignore.case = TRUE)
      }, logical(1)))

      if (has_prov_text) return(list())

      list(new_diagnostic(
        rule_id    = "datatrace.fairReusable",
        severity   = "info",
        file       = "(project)",
        message    = "No data provenance file (PROVENANCE, datapackage.json, metadata.yaml) found (FAIR: Reusable).",
        suggestion = paste(
          "Add a PROVENANCE file or datapackage.json describing data origin, collection methodology,",
          "and contact information. Consider the Frictionless Data specification."
        )
      ))
    }
  )
}

# ---------------------------------------------------------------------------
# datatrace.missingValues
# ---------------------------------------------------------------------------

rule_datatrace_missing_values <- function() {
  datatrace_rule(
    id               = "datatrace.missingValues",
    description      = "Flags columns with a high proportion of missing values (NA, empty) in tabular data files.",
    default_severity = "warning",
    default_params   = list(threshold = 0.2),  # 20% missing triggers warning
    datatrace_fn = function(data_files, root, params) {
      if (nrow(data_files) == 0) return(list())
      threshold <- params$threshold %||% 0.2

      diags <- list()
      for (i in seq_len(nrow(data_files))) {
        f   <- data_files$path[i]
        rel <- data_files$rel_path[i]
        if (!is.na(data_files$read_error[i]) && nchar(data_files$read_error[i]) > 0) next

        df <- tryCatch({
          sep <- if (data_files$type[i] == "tsv") "\t" else ","
          utils::read.table(f, header = TRUE, sep = sep, nrows = 2000L,
                             stringsAsFactors = FALSE, fill = TRUE,
                             comment.char = "", quote = "\"",
                             fileEncoding = "UTF-8")
        }, error = function(e) NULL)

        if (is.null(df) || nrow(df) == 0) next

        for (col in colnames(df)) {
          vals    <- df[[col]]
          n_total <- length(vals)
          n_miss  <- sum(is.na(vals) | trimws(as.character(vals)) == "")
          miss_pct <- n_miss / n_total
          if (miss_pct >= threshold) {
            diags <- c(diags, list(new_diagnostic(
              rule_id    = "datatrace.missingValues",
              severity   = "warning",
              file       = rel,
              message    = sprintf(
                "Column '%s' has %.0f%% missing values (%d/%d rows).",
                col, miss_pct * 100, n_miss, n_total
              ),
              suggestion = paste(
                "Investigate the cause of missing data. Document missing value codes in your data dictionary.",
                "Consider imputation strategies if appropriate."
              )
            )))
          }
        }
      }
      diags
    }
  )
}

# ---------------------------------------------------------------------------
# datatrace.duplicateRows
# ---------------------------------------------------------------------------

rule_datatrace_duplicate_rows <- function() {
  datatrace_rule(
    id               = "datatrace.duplicateRows",
    description      = "Flags CSV/TSV files that contain exact duplicate rows, which may indicate data entry errors.",
    default_severity = "warning",
    default_params   = list(max_rows = 5000L),
    datatrace_fn = function(data_files, root, params) {
      if (nrow(data_files) == 0) return(list())
      max_rows <- params$max_rows %||% 5000L

      diags <- list()
      for (i in seq_len(nrow(data_files))) {
        f   <- data_files$path[i]
        rel <- data_files$rel_path[i]
        if (!is.na(data_files$read_error[i]) && nchar(data_files$read_error[i]) > 0) next
        if (!is.na(data_files$n_rows_sample[i]) && data_files$n_rows_sample[i] == 0) next

        df <- tryCatch({
          sep <- if (data_files$type[i] == "tsv") "\t" else ","
          utils::read.table(f, header = TRUE, sep = sep, nrows = max_rows,
                             stringsAsFactors = FALSE, fill = TRUE,
                             comment.char = "", quote = "\"",
                             fileEncoding = "UTF-8")
        }, error = function(e) NULL)

        if (is.null(df) || nrow(df) < 2) next

        n_dup <- sum(duplicated(df))
        if (n_dup > 0) {
          diags <- c(diags, list(new_diagnostic(
            rule_id    = "datatrace.duplicateRows",
            severity   = "warning",
            file       = rel,
            message    = sprintf(
              "Data file contains %d exact duplicate row%s.", n_dup, if (n_dup == 1) "" else "s"
            ),
            suggestion = paste(
              "Use `dplyr::distinct()` or `unique()` to identify and remove duplicate records.",
              "Investigate whether duplicates represent real observations or data entry errors."
            )
          )))
        }
      }
      diags
    }
  )
}

# ---------------------------------------------------------------------------
# datatrace.jsonDataset
# ---------------------------------------------------------------------------

rule_datatrace_json_dataset <- function() {
  datatrace_rule(
    id               = "datatrace.jsonDataset",
    description      = "Validates JSON data files: checks parsability and flags non-array/non-object top-level structure.",
    default_severity = "warning",
    default_params   = list(),
    datatrace_fn = function(data_files, root, params) {
      # Scan for JSON files in data directories
      json_files <- list.files(root,
        pattern   = "\\.json$",
        recursive = TRUE, full.names = TRUE, ignore.case = TRUE
      )

      skip_dirs <- c(".git", "renv", "packrat", ".Rproj.user", "node_modules",
                     ".rtrace_cache", ".venv")
      rel_fn <- function(p) {
        rel <- sub(paste0("^", gsub("([.()+^$|*?\\\\])", "\\\\\\1", root), "/?"), "", p)
        gsub("\\\\", "/", rel)
      }
      all_rel <- rel_fn(json_files)
      in_skip <- vapply(all_rel, function(r) {
        any(vapply(skip_dirs, function(d) grepl(paste0("^", d, "/"), r), logical(1)))
      }, logical(1))
      json_files <- json_files[!in_skip]
      all_rel    <- all_rel[!in_skip]

      if (length(json_files) == 0) return(list())

      diags <- list()
      for (i in seq_along(json_files)) {
        f   <- json_files[i]
        rel <- all_rel[i]

        parsed <- tryCatch(
          jsonlite::fromJSON(f, simplifyVector = FALSE),
          error = function(e) structure(list(error = conditionMessage(e)), class = "json_parse_error")
        )

        if (inherits(parsed, "json_parse_error")) {
          diags <- c(diags, list(new_diagnostic(
            rule_id    = "datatrace.jsonDataset",
            severity   = "warning",
            file       = rel,
            message    = sprintf("JSON file failed to parse: %s", parsed$error),
            suggestion = "Validate the JSON with a linter (e.g., `jsonlite::validate()`) and correct syntax errors."
          )))
          next
        }

        # Warn if top-level is neither an array nor an object
        if (!is.list(parsed) && !is.data.frame(parsed)) {
          diags <- c(diags, list(new_diagnostic(
            rule_id    = "datatrace.jsonDataset",
            severity   = "info",
            file       = rel,
            message    = "JSON data file has unexpected top-level structure (expected object or array).",
            suggestion = "Ensure JSON datasets follow a consistent structure: an array of records or an object with metadata."
          )))
        }
      }
      diags
    }
  )
}
