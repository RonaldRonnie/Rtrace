# Trace Platform REST API

Provider-level REST API built on the `plumber` package (listed in
Suggests). When `plumber` is available,
[`start_api()`](https://ronaldronnie.github.io/Rtrace/reference/start_api.md)
launches a local HTTP server that exposes the Trace Platform's full
functionality over JSON endpoints suitable for SaaS integration, CI
webhooks, and dashboard frontends.

## Details

If `plumber` is not installed, all functions in this file emit an
informative error rather than failing silently.

### Endpoints

|        |              |                                                |
|--------|--------------|------------------------------------------------|
| Method | Path         | Description                                    |
| GET    | /health      | Platform health and version                    |
| POST   | /scan        | Run a full platform scan                       |
| GET    | /rules       | List all registered rules                      |
| GET    | /modules     | List registered platform modules               |
| GET    | /score       | Compute score for a previously scanned project |
| GET    | /report/html | Generate an HTML dashboard report              |
