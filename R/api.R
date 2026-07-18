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
#' ## Authentication
#'
#' Every endpoint requires a bearer token when one is configured (via the
#' `token` argument or the `RTRACE_API_TOKEN` environment variable):
#' `Authorization: Bearer <token>`. If no token is configured, [start_api()]
#' refuses to bind to any host other than loopback (`127.0.0.1`,
#' `localhost`, `::1`) -- an unauthenticated API may only ever be reachable
#' from the local machine.
#'
#' ## Path containment
#'
#' `root` (request body for `/scan` and `/scan/full`, query string for
#' `/report/html`) must resolve to one of `allowed_roots` (the server's
#' configured project directories, default: the working directory the
#' server was started in) or a descendant of one. This applies regardless
#' of authentication -- it also blocks path traversal (`..`) from a
#' request that is otherwise authenticated.
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

#' Constant-time string comparison
#'
#' Compares two strings without leaking their length-conditional runtime for
#' equal-length inputs, to avoid timing side-channels when checking a
#' caller-supplied token against the configured secret.
#'
#' @param a,b Character scalars.
#' @return Logical scalar.
#' @keywords internal
#' @noRd
secure_compare <- function(a, b) {
  a <- charToRaw(a %||% "")
  b <- charToRaw(b %||% "")
  if (length(a) != length(b)) return(FALSE)
  if (length(a) == 0) return(TRUE)
  sum(as.integer(a) != as.integer(b)) == 0L
}

#' Resolve a request-supplied project root against the server's allowlist
#'
#' Rejects paths that don't exist and paths that resolve (after following
#' `..` and symlinks via [normalizePath()]) outside every entry in
#' `allowed_roots`. This is the sole path-containment check for the API --
#' every handler that accepts a `root` must route it through here before
#' using it.
#'
#' @param root Character scalar, the requested path.
#' @param allowed_roots Character vector of permitted base directories.
#' @return A list with `ok` (logical); on success also `root` (the
#'   normalized absolute path), on failure also `status` (integer HTTP
#'   status) and `error` (character message).
#' @keywords internal
#' @noRd
resolve_scan_root <- function(root, allowed_roots) {
  if (!is.character(root) || length(root) != 1 || !nzchar(root)) {
    return(list(ok = FALSE, status = 400L, error = "Missing project root"))
  }
  if (!dir.exists(root)) {
    return(list(ok = FALSE, status = 400L,
                error = sprintf("Project root does not exist: %s", root)))
  }

  candidate <- tryCatch(
    normalizePath(root, winslash = "/", mustWork = TRUE),
    error = function(e) NA_character_
  )
  if (is.na(candidate)) {
    return(list(ok = FALSE, status = 400L,
                error = sprintf("Project root does not exist: %s", root)))
  }

  bases <- vapply(allowed_roots, function(b) {
    tryCatch(normalizePath(b, winslash = "/", mustWork = TRUE), error = function(e) NA_character_)
  }, character(1))
  bases <- bases[!is.na(bases)]

  contained <- length(bases) > 0 && any(vapply(bases, function(b) {
    identical(candidate, b) || startsWith(candidate, paste0(b, "/"))
  }, logical(1)))

  if (!contained) {
    return(list(ok = FALSE, status = 403L,
                error = "Project root is outside the server's allowed root(s)"))
  }

  list(ok = TRUE, root = candidate)
}

#' Start the Trace Platform REST API server
#'
#' Requires the `plumber` package (`install.packages("plumber")`).
#'
#' @param host Character scalar. Interface to listen on. Default `"127.0.0.1"`.
#' @param port Integer. Port number. Default `8394`.
#' @param docs Logical. If `TRUE` (default), mounts the Swagger UI at `/`.
#' @param token Character scalar. Bearer token required on every request
#'   (`Authorization: Bearer <token>`). Defaults to the `RTRACE_API_TOKEN`
#'   environment variable. If empty, the API is unauthenticated and `host`
#'   must be a loopback address.
#' @param allowed_roots Character vector of directories that `root` request
#'   parameters are allowed to resolve within. Default: the working
#'   directory the server was started in.
#' @return Invisibly, the `plumber` router object (so callers can modify it
#'   before `$run()` if needed). Blocks if the server is started interactively.
#' @export
start_api <- function(host = "127.0.0.1", port = 8394L, docs = TRUE,
                       token = Sys.getenv("RTRACE_API_TOKEN", ""),
                       allowed_roots = getwd()) {
  if (!requireNamespace("plumber", quietly = TRUE)) {
    rlang::abort(
      "The 'plumber' package is required to start the Trace Platform API.",
      "Install it with: install.packages('plumber')"
    )
  }

  loopback_hosts <- c("127.0.0.1", "localhost", "::1")
  if (!nzchar(token) && !(host %in% loopback_hosts)) {
    rlang::abort(paste(
      sprintf("Refusing to bind to '%s' without an API token.", host),
      "Set the RTRACE_API_TOKEN environment variable (or pass token=) before",
      "exposing this API beyond localhost, or start it on host='127.0.0.1'.",
      sep = "\n"
    ))
  }

  router <- build_api_router(token = token, allowed_roots = allowed_roots)

  if (!nzchar(token)) {
    message("[Trace Platform API] WARNING: no token configured -- API is unauthenticated (loopback only).")
  }
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
#' @param token Character scalar. Bearer token required on every request via
#'   `Authorization: Bearer <token>`. Default: the `RTRACE_API_TOKEN`
#'   environment variable. If empty (the default when the variable is
#'   unset), no authentication is enforced -- callers embedding the router
#'   directly are responsible for exposure control in that case.
#' @param allowed_roots Character vector of directories that `root` request
#'   parameters are allowed to resolve within (self or descendant). Default:
#'   the current working directory.
#' @return A `plumber::Plumber` router object.
#' @export
build_api_router <- function(token = Sys.getenv("RTRACE_API_TOKEN", ""),
                              allowed_roots = getwd()) {
  if (!requireNamespace("plumber", quietly = TRUE)) {
    rlang::abort("plumber is required. Install with: install.packages('plumber')")
  }

  pr <- plumber::Plumber$new()

  # --- Auth filter: applies to every route below, regardless of registration
  # order (plumber runs all filters before dispatching to a matching
  # endpoint). No-op when `token` is empty.
  pr$filter("auth", function(req, res) {
    if (nzchar(token)) {
      supplied <- sub("^(?i)Bearer\\s+", "", req$HTTP_AUTHORIZATION %||% "", perl = TRUE)
      if (!secure_compare(supplied, token)) {
        res$status <- 401L
        return(list(error = "Unauthorized: missing or invalid bearer token"))
      }
    }
    plumber::forward()
  })

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

    use_cache <- isTRUE(body$use_cache)
    fmt       <- body$format    %||% "summary"

    resolved <- resolve_scan_root(body$root %||% ".", allowed_roots)
    if (!resolved$ok) {
      res$status <- resolved$status
      return(list(error = resolved$error))
    }
    root <- resolved$root

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
    use_cache <- isTRUE(body$use_cache)

    resolved <- resolve_scan_root(body$root %||% ".", allowed_roots)
    if (!resolved$ok) {
      res$status <- resolved$status
      return(list(error = resolved$error))
    }
    root <- resolved$root

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
    resolved <- resolve_scan_root(req$argsQuery$root %||% ".", allowed_roots)
    if (!resolved$ok) {
      res$status <- resolved$status
      res$setHeader("Content-Type", "application/json")
      return(list(error = resolved$error))
    }
    root <- resolved$root

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
#' @param token Character scalar. If non-empty, examples include the
#'   `Authorization: Bearer` header. Default: the `RTRACE_API_TOKEN`
#'   environment variable.
#' @return Invisibly, a character vector of curl commands.
#' @export
api_curl_examples <- function(host = "127.0.0.1", port = 8394L,
                               token = Sys.getenv("RTRACE_API_TOKEN", "")) {
  base <- sprintf("http://%s:%d", host, port)
  auth_flag <- if (nzchar(token)) sprintf(" \\\n  -H 'Authorization: Bearer %s'", token) else ""

  examples <- c(
    sprintf("# Health check\ncurl -s%s \\\n  %s/health | jq .", auth_flag, base),
    sprintf("# List rules\ncurl -s%s \\\n  %s/rules | jq 'length'", auth_flag, base),
    sprintf("# Scan current directory\ncurl -s -X POST %s/scan%s \\\n  -H 'Content-Type: application/json' \\\n  -d '{\"root\": \".\", \"format\": \"summary\"}' | jq .", base, auth_flag),
    sprintf("# Full platform scan\ncurl -s -X POST %s/scan/full%s \\\n  -H 'Content-Type: application/json' \\\n  -d '{\"root\": \".\"}' | jq .", base, auth_flag),
    sprintf("# HTML dashboard\ncurl -s%s \\\n  '%s/report/html?root=.' > report.html && open report.html", auth_flag, base)
  )
  cat(paste(examples, collapse = "\n\n"), "\n")
  invisible(examples)
}
