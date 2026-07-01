# Trace Platform — REST API Reference

**Version:** 0.2.0  
**Default Base URL:** `http://127.0.0.1:8394`

Start the server with `rtrace api` or `RTrace::start_api()`.

---

## Authentication

The 0.2.0 API has no authentication (localhost only). SaaS deployments
should add an API gateway (nginx, Caddy) or use `plumber`'s `filter`
middleware to add Bearer token authentication.

---

## Endpoints

### `GET /health`

Returns platform version, registered modules, and rule counts.

**Response**
```json
{
  "status": "ok",
  "platform": "Trace Platform",
  "version": "0.2.0.dev",
  "rtrace_version": "0.2.0.9000",
  "modules": ["rtrace", "reproducibility", "datatrace", "docstrace", "packageqa"],
  "rules_registered": 47,
  "timestamp": "2026-07-01T12:00:00Z"
}
```

---

### `GET /rules`

Returns all registered rules.

**Response** — array of rule objects:
```json
[
  {
    "id": "antipattern.setwd",
    "description": "Flags use of setwd().",
    "default_severity": "error",
    "default_params": {}
  },
  ...
]
```

---

### `GET /modules`

Returns all registered platform modules.

**Response** — array of module objects:
```json
[
  {
    "id": "rtrace",
    "name": "Architecture Governance (R)",
    "version": "0.2.0.dev",
    "description": "Static analysis and architecture governance for R projects."
  }
]
```

---

### `POST /scan`

Runs an architecture scan (RTrace core engine only) on a project root.

**Request Body**
```json
{
  "root": "/path/to/project",
  "format": "summary",
  "use_cache": false
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `root` | string | yes | Absolute path to project root |
| `format` | string | no | `"summary"` (default) or `"json"` (includes diagnostics array) |
| `use_cache` | boolean | no | Reuse AST cache (default false) |

**Response**
```json
{
  "root": "/path/to/project",
  "timestamp": "2026-07-01T12:00:00Z",
  "summary": {
    "error": 2,
    "warning": 5,
    "info": 3
  },
  "score": {
    "value": 72,
    "label": "Acceptable"
  },
  "diagnostics": null
}
```

With `"format": "json"`, `diagnostics` contains the full array:
```json
{
  "diagnostics": [
    {
      "rule_id": "antipattern.setwd",
      "severity": "error",
      "file": "analysis/run.R",
      "line": 12,
      "column": 1,
      "message": "Use of setwd() mutates global working-directory state...",
      "suggestion": "Use here::here() instead."
    }
  ]
}
```

---

### `POST /scan/full`

Runs all registered platform modules and returns an aggregate result.

**Request Body**
```json
{
  "root": "/path/to/project",
  "use_cache": false
}
```

**Response**
```json
{
  "root": "/path/to/project",
  "timestamp": "2026-07-01T12:00:00Z",
  "modules": ["rtrace", "reproducibility", "datatrace", "docstrace", "packageqa"],
  "scores": {
    "rtrace": { "score": 85, "label": "Good" },
    "reproducibility": { "score": 70, "label": "Acceptable" },
    "datatrace": { "score": 95, "label": "Excellent" },
    "docstrace": { "score": 60, "label": "Acceptable" },
    "packageqa": { "score": 80, "label": "Good" }
  },
  "total_violations": 18,
  "summary": {
    "error": 2,
    "warning": 8,
    "info": 8
  }
}
```

---

### `GET /report/html?root=...`

Generates and returns an HTML platform dashboard for the given project root.

**Query Parameters**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `root` | yes | Path to project root |

**Response** — HTML document (`Content-Type: text/html`)

---

## Error Responses

| HTTP Status | Meaning |
|-------------|---------|
| 200 | Success |
| 400 | Invalid request (bad root path, missing fields) |
| 500 | Internal server error |

Error body:
```json
{ "error": "Project root does not exist: /bad/path" }
```

---

## Client Examples

### curl

```bash
# Health
curl -s http://127.0.0.1:8394/health | jq .

# Scan
curl -s -X POST http://127.0.0.1:8394/scan \
  -H 'Content-Type: application/json' \
  -d '{"root": ".", "format": "summary"}' | jq .

# Full platform scan
curl -s -X POST http://127.0.0.1:8394/scan/full \
  -H 'Content-Type: application/json' \
  -d '{"root": "."}' | jq .scores

# HTML report
curl -s 'http://127.0.0.1:8394/report/html?root=.' > report.html
```

Or use `RTrace::api_curl_examples()` to print all examples.

### R httr2

```r
library(httr2)

req <- request("http://127.0.0.1:8394")

# Scan
resp <- req |>
  req_url_path("/scan") |>
  req_method("POST") |>
  req_body_json(list(root = ".", format = "json")) |>
  req_perform()

result <- resp_body_json(resp)
cat("Score:", result$score$value, "/", result$score$label)
```

### GitHub Actions

```yaml
- name: Trace Platform Scan
  run: |
    Rscript -e "
      library(RTrace)
      result <- run_scan('.')
      cat(reporter_sarif(result))
    " > trace-report.sarif

- name: Upload SARIF
  uses: github/codeql-action/upload-sarif@v3
  with:
    sarif_file: trace-report.sarif
```

---

## Starting the API

```r
# From R
library(RTrace)
start_api(host = "127.0.0.1", port = 8394)

# From CLI
rtrace api --port 8394

# Custom host (for Docker / container)
start_api(host = "0.0.0.0", port = 8394)
```

The Swagger UI (auto-generated by plumber) is available at
`http://127.0.0.1:8394/__docs__/` when `docs = TRUE` (the default).
