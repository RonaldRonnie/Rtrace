#' Trace Platform Dashboard Reporter
#'
#' Produces a modern, multi-section HTML dashboard showing all platform
#' module scores, violation breakdowns, architecture visualization, dependency
#' graphs, and historical trend stubs. Designed for enterprise teams and
#' research organizations.
#'
#' Extends the existing [reporter_html()] (single-module, diagnostics only)
#' to a full platform health view. Self-contained — no external CSS/JS
#' dependencies.
#'
#' @name reporter-dashboard
NULL

#' Render the Trace Platform dashboard as a standalone HTML document
#'
#' @param platform_result A `trace_platform_result` from [platform_scan()],
#'   or a named list of `trace_platform_result`-compatible objects.
#' @param diagnostics An optional `rtrace_diagnostic_set` to include in the
#'   violation explorer section (typically `platform_result$all_diagnostics`).
#' @param layers Optional character vector of layer names for the
#'   architecture visualization.
#' @param layer_graph Optional named list (layer -> character vector of layers
#'   it depends on) for the architecture SVG.
#' @param title Character scalar dashboard heading.
#' @param include_recommendations Logical; if `TRUE` and the
#'   recommendation engine is configured, annotate each violation with its
#'   built-in recommendation. Default `TRUE`.
#' @return Character scalar containing a full HTML document.
#' @export
reporter_dashboard <- function(platform_result   = NULL,
                                diagnostics        = NULL,
                                layers             = NULL,
                                layer_graph        = list(),
                                title              = "Trace Platform Dashboard",
                                include_recommendations = TRUE) {
  # Resolve inputs
  scores  <- if (!is.null(platform_result)) platform_result$scores  else list()
  modules <- if (!is.null(platform_result)) platform_result$modules else character(0)
  ts      <- if (!is.null(platform_result)) format(platform_result$timestamp, "%Y-%m-%d %H:%M:%S UTC") else format(Sys.time(), "%Y-%m-%d %H:%M:%S UTC")

  if (is.null(diagnostics) && !is.null(platform_result)) {
    diagnostics <- platform_result$all_diagnostics
  }
  if (is.null(diagnostics)) diagnostics <- new_diagnostic_set()

  # Aggregate platform score
  platform_score <- if (length(scores) > 0) {
    aggregate_scores(scores)
  } else {
    compute_score(diagnostics)
  }

  # --- CSS ---
  css <- dashboard_css()

  # --- Sections ---
  header_html  <- dashboard_header(title, ts, platform_score)
  scores_html  <- dashboard_scores_section(scores, modules)
  arch_html    <- dashboard_architecture_section(layers, layer_graph)
  viols_html   <- dashboard_violations_section(diagnostics, include_recommendations)
  rules_html   <- dashboard_rules_section()
  footer_html  <- dashboard_footer()

  sprintf(
    paste(
      "<!DOCTYPE html>",
      '<html lang="en">',
      "<head>",
      '<meta charset="utf-8">',
      '<meta name="viewport" content="width=device-width, initial-scale=1">',
      "<title>%s</title>",
      "<style>%s</style>",
      "</head>",
      "<body>",
      "%s",
      '<main class="main-content">',
      "%s",
      "%s",
      "%s",
      "%s",
      "</main>",
      "%s",
      "</body>",
      "</html>",
      sep = "\n"
    ),
    html_escape(title), css,
    header_html,
    scores_html,
    arch_html,
    viols_html,
    rules_html,
    footer_html
  )
}

# ---------------------------------------------------------------------------
# Dashboard CSS
# ---------------------------------------------------------------------------

dashboard_css <- function() {
  paste(
    ":root{--blue:#0969da;--green:#1a7f37;--amber:#9a6700;--orange:#bc4c00;",
    "--red:#cf222e;--gray:#57606a;--bg:#f6f8fa;--border:#d0d7de;",
    "--card-bg:#ffffff;--text:#1b1f23;}",
    "*{box-sizing:border-box;margin:0;padding:0;}",
    "body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif;",
    "background:var(--bg);color:var(--text);min-height:100vh;}",
    ".topbar{background:#24292f;color:#f0f6fc;padding:.75rem 1.5rem;",
    "display:flex;align-items:center;justify-content:space-between;}",
    ".topbar-brand{font-size:1.1rem;font-weight:700;letter-spacing:.02em;}",
    ".topbar-meta{font-size:.8rem;color:#8b949e;}",
    ".main-content{max-width:1200px;margin:0 auto;padding:1.5rem 1rem 3rem;}",
    "h1{font-size:1.4rem;margin-bottom:.25rem;}",
    "h2{font-size:1.1rem;color:var(--text);margin:0 0 .75rem;}",
    "h3{font-size:.95rem;color:var(--gray);margin:.5rem 0;}",
    ".hero{padding:1.5rem 0 1rem;}",
    ".hero-title{font-size:1.6rem;font-weight:700;}",
    ".hero-subtitle{color:var(--gray);font-size:.9rem;margin-top:.25rem;}",
    ".score-hero{display:inline-flex;align-items:center;gap:.75rem;",
    "background:var(--card-bg);border:2px solid var(--border);",
    "border-radius:12px;padding:.75rem 1.5rem;margin-top:1rem;}",
    ".score-hero .big-number{font-size:2.5rem;font-weight:800;line-height:1;}",
    ".score-hero .score-meta{font-size:.85rem;color:var(--gray);}",
    ".score-hero .score-label{font-size:1rem;font-weight:600;}",
    ".section{margin:2rem 0;}",
    ".section-header{display:flex;align-items:center;gap:.5rem;",
    "border-bottom:2px solid var(--border);padding-bottom:.5rem;margin-bottom:1rem;}",
    ".section-header h2{margin:0;}",
    ".cards{display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:1rem;}",
    ".card{background:var(--card-bg);border:1px solid var(--border);",
    "border-radius:8px;padding:1rem;position:relative;overflow:hidden;}",
    ".card-score{font-size:2rem;font-weight:800;margin:.25rem 0;}",
    ".card-label{font-size:.75rem;font-weight:600;text-transform:uppercase;",
    "letter-spacing:.06em;}",
    ".card-name{font-size:.85rem;color:var(--gray);}",
    ".card-bar{position:absolute;bottom:0;left:0;height:4px;transition:width .3s;}",
    ".badge{display:inline-block;font-size:.7rem;font-weight:700;",
    "padding:.15rem .45rem;border-radius:4px;text-align:center;min-width:4.5rem;}",
    ".badge-error{background:var(--red);color:#fff;}",
    ".badge-warning{background:var(--amber);color:#fff;}",
    ".badge-info{background:var(--blue);color:#fff;}",
    ".violations-table{width:100%;border-collapse:collapse;font-size:.85rem;}",
    ".violations-table th{background:var(--bg);padding:.5rem .75rem;",
    "text-align:left;font-weight:600;border-bottom:2px solid var(--border);}",
    ".violations-table td{padding:.5rem .75rem;border-bottom:1px solid var(--border);",
    "vertical-align:top;}",
    ".violations-table tr:hover td{background:#f0f3f6;}",
    ".code{font-family:monospace;font-size:.82em;background:var(--bg);",
    "padding:.1rem .3rem;border-radius:4px;}",
    ".suggestion{color:var(--gray);font-size:.82em;margin-top:.2rem;}",
    ".recommendation-box{background:#ddf4ff;border-left:3px solid var(--blue);",
    "padding:.5rem .75rem;margin-top:.4rem;font-size:.82em;border-radius:0 4px 4px 0;}",
    ".rules-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:.5rem;}",
    ".rule-card{background:var(--card-bg);border:1px solid var(--border);",
    "border-radius:6px;padding:.6rem .75rem;font-size:.82em;}",
    ".rule-id{font-family:monospace;font-weight:600;color:var(--blue);}",
    ".rule-sev{font-size:.7rem;font-weight:600;border-radius:3px;",
    "padding:.1rem .3rem;margin-left:.3rem;}",
    ".sev-error{background:var(--red);color:#fff;}",
    ".sev-warning{background:var(--amber);color:#fff;}",
    ".sev-info{background:var(--blue);color:#fff;}",
    ".arch-svg-wrap{text-align:center;margin:1rem 0;",
    "border:1px solid var(--border);border-radius:8px;padding:.5rem;",
    "background:var(--card-bg);}",
    ".footer{text-align:center;color:var(--gray);font-size:.78rem;",
    "padding:1.5rem;border-top:1px solid var(--border);margin-top:2rem;}",
    ".empty-state{color:var(--gray);font-style:italic;padding:1rem 0;}",
    ".clean-badge{display:inline-block;background:#d0ffd6;color:var(--green);",
    "font-weight:700;padding:.3rem .8rem;border-radius:6px;}",
    sep = "\n"
  )
}

# ---------------------------------------------------------------------------
# Dashboard sections
# ---------------------------------------------------------------------------

dashboard_header <- function(title, timestamp, platform_score) {
  score     <- platform_score$score %||% 0L
  label     <- platform_score$label %||% score_label(score)
  color     <- score_colour(score)

  sprintf(
    paste(
      '<header class="topbar">',
      '<span class="topbar-brand">&#9632; Trace Platform</span>',
      '<span class="topbar-meta">Generated %s</span>',
      "</header>",
      '<div class="hero main-content">',
      '<div class="hero-title">%s</div>',
      '<div class="hero-subtitle">Comprehensive project quality assessment</div>',
      '<div class="score-hero">',
      '<div class="big-number" style="color:%s">%d</div>',
      '<div>',
      '<div class="score-label" style="color:%s">%s</div>',
      '<div class="score-meta">Platform Health Score / 100</div>',
      '</div>',
      '</div>',
      '</div>',
      sep = "\n"
    ),
    html_escape(timestamp),
    html_escape(title),
    color, score,
    color, html_escape(label)
  )
}

dashboard_scores_section <- function(scores, modules) {
  if (length(scores) == 0) {
    return(sprintf(
      '<section class="section"><div class="section-header"><h2>Module Scores</h2></div><p class="empty-state">No module scores available. Run platform_scan() to generate scores.</p></section>'
    ))
  }

  module_labels <- c(
    rtrace        = "Architecture",
    reproducibility = "Reproducibility",
    docstrace     = "Documentation",
    packageqa     = "Package QA",
    datatrace     = "Data Quality"
  )

  cards <- vapply(names(scores), function(mod_id) {
    sc     <- scores[[mod_id]]
    score  <- sc$score  %||% 0L
    label  <- sc$label  %||% score_label(score)
    color  <- score_colour(score)
    name   <- module_labels[[mod_id]] %||% tools::toTitleCase(gsub("_", " ", mod_id))

    sprintf(
      paste(
        '<div class="card">',
        '<div class="card-name">%s</div>',
        '<div class="card-score" style="color:%s">%d</div>',
        '<div class="card-label" style="color:%s">%s</div>',
        '<div class="card-bar" style="width:%d%%;background:%s;"></div>',
        '</div>',
        sep = "\n"
      ),
      html_escape(name), color, score, color, html_escape(label),
      score, color
    )
  }, character(1))

  sprintf(
    '<section class="section"><div class="section-header"><h2>Module Scores</h2></div><div class="cards">%s</div></section>',
    paste(cards, collapse = "\n")
  )
}

dashboard_architecture_section <- function(layers, layer_graph) {
  if (is.null(layers) || length(layers) == 0) return("")

  svg <- render_layer_graph_svg(layers, layer_graph, width = 700, height = 420)
  if (is.null(svg)) return("")

  sprintf(
    paste(
      '<section class="section">',
      '<div class="section-header"><h2>Architecture Overview</h2></div>',
      '<div class="arch-svg-wrap">%s</div>',
      '</section>',
      sep = "\n"
    ),
    svg
  )
}

dashboard_violations_section <- function(diagnostics, include_recommendations) {
  if (length(diagnostics) == 0) {
    return(sprintf(
      '<section class="section"><div class="section-header"><h2>Violations</h2></div><span class="clean-badge">&#10003; No violations found</span></section>'
    ))
  }

  s <- summary(diagnostics)

  summary_html <- sprintf(
    '<div style="display:flex;gap:.75rem;margin-bottom:1rem;flex-wrap:wrap;">%s</div>',
    paste(
      sprintf('<span class="badge badge-error">%d error(s)</span>', s[["error"]]),
      sprintf('<span class="badge badge-warning">%d warning(s)</span>', s[["warning"]]),
      sprintf('<span class="badge badge-info">%d info</span>', s[["info"]]),
      collapse = " "
    )
  )

  # Build recommendation lookup
  recs <- if (include_recommendations) {
    tryCatch(get_recommendations(diagnostics), error = function(e) list())
  } else list()

  rows <- vapply(diagnostics$diagnostics, function(d) {
    sev_class <- switch(d$severity, error = "badge-error", warning = "badge-warning", "badge-info")
    loc <- if (!is.na(d$line)) {
      if (!is.na(d$column)) sprintf("%d:%d", d$line, d$column) else as.character(d$line)
    } else ""

    sugg_html <- if (!is.null(d$suggestion) && nzchar(d$suggestion)) {
      sprintf('<div class="suggestion">&rarr; %s</div>', html_escape(d$suggestion))
    } else ""

    rec_html <- if (include_recommendations && !is.null(recs[[d$rule_id]])) {
      rec <- recs[[d$rule_id]]
      if (!is.null(rec$why) && nzchar(rec$why)) {
        sprintf(
          '<div class="recommendation-box"><strong>Why:</strong> %s%s</div>',
          html_escape(rec$why),
          if (!is.null(rec$fix) && nzchar(rec$fix)) {
            sprintf(' <strong>Fix:</strong> %s', html_escape(rec$fix))
          } else ""
        )
      } else ""
    } else ""

    sprintf(
      paste(
        "<tr>",
        "<td><span class=\"badge %s\">%s</span></td>",
        "<td><span class=\"code\">%s</span></td>",
        "<td><span class=\"code\">%s</span></td>",
        "<td>%s%s%s</td>",
        "</tr>",
        sep = ""
      ),
      sev_class, toupper(d$severity),
      html_escape(d$file),
      html_escape(loc),
      html_escape(d$message),
      sugg_html,
      rec_html
    )
  }, character(1))

  table_html <- sprintf(
    paste(
      '<div style="overflow-x:auto;">',
      '<table class="violations-table">',
      '<thead><tr><th>Severity</th><th>File</th><th>Location</th><th>Message</th></tr></thead>',
      '<tbody>%s</tbody>',
      '</table>',
      '</div>',
      sep = ""
    ),
    paste(rows, collapse = "\n")
  )

  sprintf(
    '<section class="section"><div class="section-header"><h2>Violations (%d)</h2></div>%s%s</section>',
    length(diagnostics), summary_html, table_html
  )
}

dashboard_rules_section <- function() {
  rules <- list_rules()
  if (length(rules) == 0) return("")

  sorted_ids <- sort(names(rules))
  cards <- vapply(sorted_ids, function(id) {
    r       <- rules[[id]]
    sev_cls <- switch(r$default_severity,
                      error = "sev-error", warning = "sev-warning", "sev-info")
    sprintf(
      paste(
        '<div class="rule-card">',
        '<span class="rule-id">%s</span>',
        '<span class="rule-sev %s">%s</span>',
        '<div style="margin-top:.3rem;color:var(--gray);">%s</div>',
        '</div>',
        sep = "\n"
      ),
      html_escape(r$id),
      sev_cls, toupper(r$default_severity),
      html_escape(r$description)
    )
  }, character(1))

  sprintf(
    '<section class="section"><div class="section-header"><h2>Rule Registry (%d rules)</h2></div><div class="rules-grid">%s</div></section>',
    length(rules), paste(cards, collapse = "\n")
  )
}

dashboard_footer <- function() {
  sprintf(
    '<footer class="footer">Generated by <strong>Trace Platform</strong> v%s &mdash; Powered by RTrace &mdash; %s</footer>',
    platform_version(), format(Sys.time(), "%Y")
  )
}
