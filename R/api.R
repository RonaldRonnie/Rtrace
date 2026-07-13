#' Trace Platform REST API
#'
#' Provider-level REST API built on the `plumber` package (listed in
#' Suggests). When `plumber` is available, `start_api()` launches a local
#' HTTP server that exposes the Trace Platform's full functionality over
#' JSON endpoints suitable for SaaS integration, CI webhooks, and dashboard
#' frontends.
#'
#' If `plumber` is not installed, all functions in this file emit an
#' informative error rather than failing silently.
#'
#' ## Endpoints
#'
#' | Method | Path | Description |
#' |--------|------|-------------|
#' | GET | /health | Platform health and version |
#' | POST | /scan | Run a full platform scan |
#' | GET | /rules | List all registered rules |
#' | GET | /modules | List registered platform modules |
#' | GET | /score | Compute score for a previously scanned project |
#' | GET | /report/html | Generate an HTML dashboard report |
#'
#' @name api
NULL

#' Start the Trace Platform REST API server
#'
#' Requires the `plumber` package (`install.packages("plumber")`).
#'
#' @param host Character scalar. Interface to listen on. Default `"127.0.0.1"`.
#' @param port Integer. Port number. Default `8394`.
#' @param docs Logical. If `TRUE` (default), mounts the Swagger UI at `/`.
#' @return Invisibly, the `plumber` router object (so callers can modify it
#'   before `$run()` if needed). Blocks if the server is started interactively.
#' @export
start_api <- function(host = "127.0.0.1", port = 8394L, docs = TRUE) {
  if (!requireNamespace("plumber", quietly = TRUE)) {
    rlang::abort(
      "The 'plumber' package is required to start the Trace Platform API.",
      "Install it with: install.packages('plumber')"
    )
  }

  router <- build_api_router()

  message(sprintf(
    "[Trace Platform API] Starting on http://%s:%d\n  Health: http://%s:%d/health\n  Docs:   http://%s:%d/__docs__/",
    host, port, host, port, host, port
  ))

  router$run(host = host, port = as.integer(port), swagger = docs)
  invisible(router)
}

#' Build the plumber router without starting it
#'
#' Useful for testing, embedding in a larger plumber app, or customizing
#' routes before calling `$run()`.
#'
#' @return A `plumber::Plumber` router object.
#' @export
build_api_router <- function() {
  if (!requireNamespace("plumber", quietly = TRUE)) {
    rlang::abort("plumber is required. Install with: install.packages('plumber')")
  }

  pr <- plumber::Plumber$new()

  # GET /health
  pr$handle("GET", "/health", function(req, res) {
    list(
      status          = "ok",
      platform        = platform_name(),
      version         = platform_version(),
      rtrace_version  = tryCatch(
        as.character(utils::packageVersion("RTrace")), error = function(e) "unknown"
      ),
      modules         = names(list_modules()),
      rules_registered = length(list_rules()),
      timestamp       = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    )
  })

  # GET /rules
  pr$handle("GET", "/rules", function(req, res) {
    rules <- list_rules()
    lapply(names(rules), function(id) {
      r <- rules[[id]]
      list(
        id               = r$id,
        description      = r$description,
        default_severity = r$default_severity,
        default_params   = r$default_params
      )
    })
  })

  # GET /modules
  pr$handle("GET", "/modules", function(req, res) {
    mods <- list_modules()
    lapply(names(mods), function(id) {
      m <- mods[[id]]
      list(
        id          = m$id,
        name        = m$name,
        version     = m$version,
        description = m$description
      )
    })
  })

  # POST /scan
  # Body: { "root": "/path/to/project", "format": "json"|"summary", "use_cache": false }
  pr$handle("POST", "/scan", function(req, res) {
    body <- tryCatch(
      jsonlite::fromJSON(req$postBody, simplifyVector = FALSE),
      error = function(e) list()
    )

    root      <- body$root      %||% "."
    use_cache <- isTRUE(body$use_cache)
    fmt       <- body$format    %||% "summary"

    if (!dir.exists(root)) {
      res$status <- 400L
      return(list(error = sprintf("Project root does not exist: %s", root)))
    }

    result <- tryCatch({
      pr_result  <- platform_scan(root, use_cache = use_cache, modules = "rtrace")
      diags      <- pr_result$all_diagnostics
      arch_score <- pr_result$scores[["rtrace"]]

      list(
        root       = root,
        timestamp  = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
        summary    = as.list(summary(diags)),
        score      = list(
          value = arch_score$score,
          label = arch_score$label
        ),
        diagnostics = if (fmt == "json") {
          lapply(diags$diagnostics, function(d) {
            list(rule_id = d$rule_id, severity = d$severity, file = d$file,
                 line = d$line, column = d$column, message = d$message,
                 suggestion = d$suggestion)
          })
        } else NULL
      )
    }, error = function(e) {
      res$status <- 500L
      list(error = conditionMessage(e))
    })

    result
  })

  # POST /scan/full  (runs all platform modules)
  pr$handle("POST", "/scan/full", function(req, res) {
    body <- tryCatch(
      jsonlite::fromJSON(req$postBody, simplifyVector = FALSE),
      error = function(e) list()
    )
    root      <- body$root %||% "."
    use_cache <- isTRUE(body$use_cache)

    if (!dir.exists(root)) {
      res$status <- 400L
      return(list(error = sprintf("Project root does not exist: %s", root)))
    }

    result <- tryCatch({
      pr_result <- platform_scan(root, use_cache = use_cache)
      list(
        root      = pr_result$root,
        timestamp = format(pr_result$timestamp, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
        modules   = pr_result$modules,
        scores    = lapply(pr_result$scores, function(sc) {
          list(score = sc$score, label = sc$label)
        }),
        total_violations = length(pr_result$all_diagnostics),
        summary = as.list(summary(pr_result$all_diagnostics))
      )
    }, error = function(e) {
      res$status <- 500L
      list(error = conditionMessage(e))
    })
    result
  })

  # GET /report/html?root=...
  pr$handle("GET", "/report/html", function(req, res) {
    root <- req$argsQuery$root %||% "."
    if (!dir.exists(root)) {
      res$status <- 400L
      res$setHeader("Content-Type", "application/json")
      return(list(error = sprintf("Project root does not exist: %s", root)))
    }

    html <- tryCatch({
      config    <- default_config()
      context   <- build_context(root, config)
      pr_result <- platform_scan(root, config, modules = "rtrace")

      reporter_dashboard(
        diagnostics  = pr_result$all_diagnostics,
        layers       = setdiff(unique(context$files$layer), "(unassigned)"),
        layer_graph  = context$dependency_graph$layer_graph,
        title        = sprintf("Trace Platform: %s", basename(root))
      )
    }, error = function(e) {
      sprintf("<html><body><h1>Error</h1><pre>%s</pre></body></html>",
              html_escape(conditionMessage(e)))
    })

    res$setHeader("Content-Type", "text/html; charset=utf-8")
    res$body <- html
    res
  })

  pr
}

#' Generate a `curl` example for the Trace Platform API
#'
#' Prints the `curl` commands for each endpoint, useful for onboarding and
#' documentation.
#'
#' @param host Character scalar. Default `"127.0.0.1"`.
#' @param port Integer. Default `8394L`.
#' @return Invisibly, a character vector of curl commands.
#' @export
api_curl_examples <- function(host = "127.0.0.1", port = 8394L) {
  base <- sprintf("http://%s:%d", host, port)
  examples <- c(
    sprintf("# Health check\ncurl -s %s/health | jq .", base),
    sprintf("# List rules\ncurl -s %s/rules | jq 'length'", base),
    sprintf("# Scan current directory\ncurl -s -X POST %s/scan \\\n  -H 'Content-Type: application/json' \\\n  -d '{\"root\": \".\", \"format\": \"summary\"}' | jq .", base),
    sprintf("# Full platform scan\ncurl -s -X POST %s/scan/full \\\n  -H 'Content-Type: application/json' \\\n  -d '{\"root\": \".\"}' | jq .", base),
    sprintf("# HTML dashboard\ncurl -s '%s/report/html?root=.' > report.html && open report.html", base)
  )
  cat(paste(examples, collapse = "\n\n"), "\n")
  invisible(examples)
}
