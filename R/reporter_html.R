#' Escape text for safe embedding in HTML
#'
#' Diagnostic `file`, `message`, and `suggestion` fields originate from
#' scanned source code (file paths, string literals quoted back into
#' messages), so they must be escaped before being embedded in a generated
#' HTML report — see [SECURITY.md](https://github.com/RonaldRonnie/Rtrace/blob/main/SECURITY.md).
#'
#' @param x Character vector.
#' @return Character vector with `& < > " '` replaced by HTML entities.
#' @export
html_escape <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub("\"", "&quot;", x, fixed = TRUE)
  x <- gsub("'", "&#39;", x, fixed = TRUE)
  x
}

#' Render a layer dependency graph as an inline SVG diagram
#'
#' A simple, dependency-free circular layout (nodes placed evenly around a
#' circle): not a general graph-layout algorithm, and edge/label overlap is
#' not optimized away, but it's legible for the small-to-moderate layer
#' counts (well under 15) typical of an RTrace `layers:` configuration. No
#' external JS/CSS — pure inline SVG, consistent with [reporter_html()]
#' being a single standalone file.
#'
#' Edges that participate in a cycle (per [find_cycles()]) are drawn in
#' red; all other edges are drawn in gray.
#'
#' @param layers Character vector of layer names to draw as nodes. Returns
#'   `NULL` if empty.
#' @param layer_graph A named list as in
#'   `context$dependency_graph$layer_graph` (layer name -> character
#'   vector of layer names it depends on).
#' @param width,height Integer pixel dimensions of the SVG viewport.
#' @return Character scalar `<svg>...</svg>` markup, or `NULL` if `layers`
#'   is empty.
#' @export
render_layer_graph_svg <- function(layers, layer_graph = list(), width = 560, height = 420) {
  layers <- unique(layers)
  n <- length(layers)
  if (n == 0) return(NULL)

  cx <- width / 2
  cy <- height / 2
  radius <- min(width, height) / 2 - 60
  node_r <- 28

  if (n == 1) {
    positions <- list(c(cx, cy))
  } else {
    angles <- seq(-pi / 2, -pi / 2 + 2 * pi, length.out = n + 1)[seq_len(n)]
    positions <- lapply(angles, function(a) c(cx + radius * cos(a), cy + radius * sin(a)))
  }
  names(positions) <- layers

  cycles <- find_cycles(layer_graph)
  cycle_edges <- unlist(lapply(cycles, function(cyc) {
    if (length(cyc) < 2) return(character(0))
    paste(cyc[-length(cyc)], cyc[-1], sep = "->")
  }))

  edge_svg <- character(0)
  for (from in intersect(names(layer_graph), layers)) {
    for (to in intersect(layer_graph[[from]], layers)) {
      p1 <- positions[[from]]
      p2 <- positions[[to]]
      dx <- p2[1] - p1[1]
      dy <- p2[2] - p1[2]
      dist <- sqrt(dx^2 + dy^2)
      if (dist < 1e-6) next
      ux <- dx / dist
      uy <- dy / dist
      is_cycle <- paste(from, to, sep = "->") %in% cycle_edges
      marker <- if (is_cycle) "arrow-cycle" else "arrow"
      color <- if (is_cycle) "#cf222e" else "#8c959f"
      edge_svg <- c(edge_svg, sprintf(
        '<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="2" marker-end="url(#%s)" />',
        p1[1] + ux * node_r, p1[2] + uy * node_r, p2[1] - ux * node_r, p2[2] - uy * node_r,
        color, marker
      ))
    }
  }

  node_svg <- vapply(layers, function(layer) {
    p <- positions[[layer]]
    sprintf(
      paste0(
        '<circle cx="%.1f" cy="%.1f" r="%d" fill="#ddf4ff" stroke="#0969da" stroke-width="2" />',
        '<text x="%.1f" y="%.1f" text-anchor="middle" dominant-baseline="middle" font-size="11" font-family="monospace">%s</text>'
      ),
      p[1], p[2], node_r, p[1], p[2], html_escape(layer)
    )
  }, character(1))

  sprintf(
    paste(
      '<svg width="%d" height="%d" viewBox="0 0 %d %d" xmlns="http://www.w3.org/2000/svg">',
      "<defs>",
      '<marker id="arrow" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="#8c959f" /></marker>',
      '<marker id="arrow-cycle" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="#cf222e" /></marker>',
      "</defs>",
      "%s",
      "%s",
      "</svg>",
      sep = "\n"
    ),
    width, height, width, height,
    paste(edge_svg, collapse = "\n"),
    paste(node_svg, collapse = "\n")
  )
}

#' Render a diagnostic set as a standalone HTML report
#'
#' Produces a single self-contained HTML file (inline CSS, no external
#' assets or JavaScript dependencies) grouping diagnostics by file, with a
#' summary panel and per-severity color coding. Suitable for attaching as a
#' CI artifact or opening directly in a browser.
#'
#' @param diagnostics An `rtrace_diagnostic_set`.
#' @param title Character scalar report heading.
#' @param layers Optional character vector of configured layer names (e.g.
#'   `setdiff(unique(context$files$layer), "(unassigned)")`). When
#'   non-empty, an "Architecture Overview" section is rendered above the
#'   diagnostics list via [render_layer_graph_svg()]. Omit (the default)
#'   for a diagnostics-only report — `reporter_html()`'s primary contract
#'   is still just `diagnostics`, like every other reporter (see ADR 0002).
#' @param layer_graph Optional named list, `context$dependency_graph$layer_graph`.
#'   Ignored if `layers` is empty.
#' @return Character scalar containing a full HTML document.
#' @export
reporter_html <- function(diagnostics, title = "RTrace Scan Report", layers = NULL, layer_graph = list()) {
  stopifnot(inherits(diagnostics, "rtrace_diagnostic_set"))

  s <- summary(diagnostics)

  by_file <- if (length(diagnostics) > 0) {
    split(diagnostics$diagnostics, vapply(diagnostics$diagnostics, function(d) d$file, character(1)))
  } else {
    list()
  }

  severity_class <- c(error = "sev-error", warning = "sev-warning", info = "sev-info")

  file_sections <- vapply(names(by_file), function(file) {
    rows <- vapply(by_file[[file]], function(d) {
      loc <- if (!is.na(d$line)) {
        if (!is.na(d$column)) sprintf("%d:%d", d$line, d$column) else sprintf("%d", d$line)
      } else {
        ""
      }
      suggestion_html <- if (!is.null(d$suggestion) && nzchar(d$suggestion)) {
        sprintf('<div class="suggestion">&rarr; %s</div>', html_escape(d$suggestion))
      } else {
        ""
      }
      sprintf(
        '<li class="%s"><span class="badge">%s</span> <span class="loc">%s</span> %s <code class="rule">%s</code>%s</li>',
        severity_class[[d$severity]], toupper(d$severity), html_escape(loc),
        html_escape(d$message), html_escape(d$rule_id), suggestion_html
      )
    }, character(1))

    sprintf('<section class="file"><h2>%s</h2><ul>%s</ul></section>',
            html_escape(file), paste(rows, collapse = "\n"))
  }, character(1))

  architecture_section <- if (!is.null(layers) && length(layers) > 0) {
    svg <- render_layer_graph_svg(layers, layer_graph)
    sprintf('<section class="architecture"><h2>Architecture Overview</h2>%s</section>', svg)
  } else {
    ""
  }

  diagnostics_body <- if (length(diagnostics) == 0) {
    '<p class="clean">No issues found.</p>'
  } else {
    paste(file_sections, collapse = "\n")
  }
  body <- paste(architecture_section, diagnostics_body, sep = "\n")

  css <- paste(
    "body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif;",
    "max-width:960px;margin:2rem auto;padding:0 1rem;color:#1b1f23;}",
    "h1{font-size:1.5rem;} h2{font-size:1.05rem;margin-top:2rem;font-family:monospace;}",
    ".architecture{margin-bottom:2rem;}",
    ".architecture h2{font-family:inherit;font-size:1.2rem;}",
    ".architecture svg{border:1px solid #eaecef;border-radius:6px;display:block;margin:0 auto;}",
    ".summary{display:flex;gap:1rem;margin:1rem 0 2rem;}",
    ".summary .stat{padding:.5rem 1rem;border-radius:6px;font-weight:600;}",
    ".summary .error{background:#ffeef0;color:#86181d;}",
    ".summary .warning{background:#fff8c5;color:#735c0f;}",
    ".summary .info{background:#ddf4ff;color:#0969da;}",
    "ul{list-style:none;padding-left:0;}",
    "li{padding:.5rem 0;border-bottom:1px solid #eaecef;}",
    ".badge{display:inline-block;min-width:4.5rem;font-size:.75rem;font-weight:700;",
    "padding:.1rem .4rem;border-radius:4px;text-align:center;}",
    ".sev-error .badge{background:#cf222e;color:#fff;}",
    ".sev-warning .badge{background:#9a6700;color:#fff;}",
    ".sev-info .badge{background:#0969da;color:#fff;}",
    ".loc{font-family:monospace;color:#57606a;}",
    "code.rule{background:#f6f8fa;padding:.1rem .3rem;border-radius:4px;font-size:.85em;}",
    ".suggestion{color:#57606a;font-size:.9em;margin-top:.2rem;margin-left:5.2rem;}",
    ".clean{color:#1a7f37;font-weight:600;}",
    sep = "\n"
  )

  sprintf(
    paste(
      "<!DOCTYPE html>",
      '<html lang="en">',
      "<head>",
      '<meta charset="utf-8">',
      "<title>%s</title>",
      "<style>%s</style>",
      "</head>",
      "<body>",
      "<h1>%s</h1>",
      '<div class="summary">',
      '<span class="stat error">%d error(s)</span>',
      '<span class="stat warning">%d warning(s)</span>',
      '<span class="stat info">%d info</span>',
      "</div>",
      "%s",
      "</body>",
      "</html>",
      sep = "\n"
    ),
    html_escape(title), css, html_escape(title),
    s[["error"]], s[["warning"]], s[["info"]],
    body
  )
}
