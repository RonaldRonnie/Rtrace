#' Trace Platform unified scoring system
#'
#' Every Trace Platform module produces a `trace_score` -- a 0-100 integer
#' derived from a weighted combination of rule violations and their
#' severities. This file defines the shared computation contract and
#' convenience constructors used by all modules.
#'
#' @name scoring
NULL

# ---------------------------------------------------------------------------
# Score computation
# ---------------------------------------------------------------------------

#' Compute a 0-100 quality score from a diagnostic set
#'
#' The scoring model:
#' - Start at 100 (perfect).
#' - Subtract `error_penalty` per `error`-severity diagnostic (default 10).
#' - Subtract `warning_penalty` per `warning`-severity diagnostic (default 3).
#' - Subtract `info_penalty` per `info`-severity diagnostic (default 1).
#' - Clamp to \[0, 100\].
#'
#' The penalties are intentionally modest defaults so that one error does not
#' collapse a score to zero on a large project. Pass custom penalties to tune
#' the scoring model for a specific module's domain.
#'
#' @param diagnostics An `rtrace_diagnostic_set`.
#' @param error_penalty Numeric, score deducted per error.
#' @param warning_penalty Numeric, score deducted per warning.
#' @param info_penalty Numeric, score deducted per info.
#' @param baseline Numeric, starting score (default 100).
#' @return A `trace_score` object.
#' @export
compute_score <- function(diagnostics,
                           error_penalty   = 10,
                           warning_penalty = 3,
                           info_penalty    = 1,
                           baseline        = 100) {
  stopifnot(inherits(diagnostics, "rtrace_diagnostic_set"))

  s     <- summary(diagnostics)
  deduction <- s[["error"]]   * error_penalty +
               s[["warning"]] * warning_penalty +
               s[["info"]]    * info_penalty

  score <- max(0L, min(100L, as.integer(round(baseline - deduction))))

  new_trace_score(
    score     = score,
    breakdown = list(
      errors   = unname(s[["error"]]),
      warnings = unname(s[["warning"]]),
      infos    = unname(s[["info"]]),
      error_penalty   = error_penalty,
      warning_penalty = warning_penalty,
      info_penalty    = info_penalty
    )
  )
}

# ---------------------------------------------------------------------------
# trace_score object
# ---------------------------------------------------------------------------

#' Construct a trace_score object
#'
#' @param score Integer 0-100.
#' @param label Optional character scalar label (derived from score if
#'   `NULL`).
#' @param breakdown Named list of breakdown details.
#' @param module_id Optional character scalar identifying which module the
#'   score belongs to.
#' @return A `trace_score` object.
#' @export
new_trace_score <- function(score,
                              label      = NULL,
                              breakdown  = list(),
                              module_id  = NULL) {
  score <- as.integer(score)
  if (is.null(label)) label <- score_label(score)
  structure(
    list(
      score     = score,
      label     = label,
      breakdown = breakdown,
      module_id = module_id
    ),
    class = "trace_score"
  )
}

#' @export
print.trace_score <- function(x, ...) {
  cat(sprintf("<trace_score> %d/100 -- %s\n", x$score, x$label))
  if (!is.null(x$module_id)) cat(sprintf("  module: %s\n", x$module_id))
  bd <- x$breakdown
  if (length(bd) > 0 && !is.null(bd$errors)) {
    cat(sprintf(
      "  violations: %d error(s), %d warning(s), %d info\n",
      bd$errors %||% 0L, bd$warnings %||% 0L, bd$infos %||% 0L
    ))
  }
  invisible(x)
}

#' Convert a numeric score to a human-readable label
#'
#' @param score Integer 0-100.
#' @return Character scalar label.
#' @export
score_label <- function(score) {
  score <- as.integer(score)
  if      (score >= 90) "Excellent"
  else if (score >= 75) "Good"
  else if (score >= 60) "Acceptable"
  else if (score >= 40) "Needs Attention"
  else                  "Critical"
}

#' Score colour for HTML/dashboard rendering
#'
#' Returns a CSS hex colour appropriate for the score range.
#'
#' @param score Integer 0-100.
#' @return Character scalar CSS colour.
#' @export
score_colour <- function(score) {
  score <- as.integer(score)
  if      (score >= 90) "#1a7f37"   # green
  else if (score >= 75) "#0969da"   # blue
  else if (score >= 60) "#9a6700"   # amber
  else if (score >= 40) "#bc4c00"   # orange
  else                  "#cf222e"   # red
}

# ---------------------------------------------------------------------------
# Platform aggregate score
# ---------------------------------------------------------------------------

#' Aggregate multiple trace_score objects into a single platform score
#'
#' Takes a named list of `trace_score` objects (one per module) and computes
#' the weighted mean, defaulting to equal weights.
#'
#' @param scores Named list of `trace_score` objects.
#' @param weights Named numeric vector of weights (names match `scores`).
#'   Defaults to equal weights.
#' @return A `trace_score` object with `module_id = "platform"`.
#' @export
aggregate_scores <- function(scores, weights = NULL) {
  if (length(scores) == 0) return(new_trace_score(100L, module_id = "platform"))

  ids <- names(scores)
  if (is.null(weights)) {
    weights <- stats::setNames(rep(1.0, length(ids)), ids)
  }

  effective_weights <- stats::setNames(
    vapply(ids, function(id) if (id %in% names(weights)) weights[[id]] else 1.0, numeric(1)),
    ids
  )

  total_weight <- sum(effective_weights)
  if (total_weight == 0) total_weight <- 1.0

  weighted_sum <- sum(vapply(ids, function(id) {
    sc <- scores[[id]]
    (sc$score %||% 0L) * effective_weights[[id]]
  }, numeric(1)))

  aggregate_score <- as.integer(round(weighted_sum / total_weight))
  aggregate_score <- max(0L, min(100L, aggregate_score))

  new_trace_score(
    score     = aggregate_score,
    breakdown = list(
      module_scores = lapply(scores, function(s) list(score = s$score, label = s$label)),
      weights       = effective_weights
    ),
    module_id = "platform"
  )
}

# ---------------------------------------------------------------------------
# Score report data frame
# ---------------------------------------------------------------------------

#' Flatten a named list of trace_scores into a data frame
#'
#' Useful for feeding into reporters or the REST API.
#'
#' @param scores Named list of `trace_score` objects.
#' @return A `data.frame` with columns `module`, `score`, `label`.
#' @export
scores_as_data_frame <- function(scores) {
  if (length(scores) == 0) {
    return(data.frame(module = character(0), score = integer(0),
                      label = character(0), stringsAsFactors = FALSE))
  }
  data.frame(
    module = names(scores),
    score  = vapply(scores, function(s) s$score %||% 0L, integer(1)),
    label  = vapply(scores, function(s) s$label %||% "", character(1)),
    stringsAsFactors = FALSE,
    row.names = NULL
  )
}
