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

### Authentication

Every endpoint requires a bearer token when one is configured (via the
`token` argument or the `RTRACE_API_TOKEN` environment variable):
`Authorization: Bearer <token>`. If no token is configured,
[`start_api()`](https://ronaldronnie.github.io/Rtrace/reference/start_api.md)
refuses to bind to any host other than loopback (`127.0.0.1`,
`localhost`, `::1`) – an unauthenticated API may only ever be reachable
from the local machine.

### Path containment

`root` (request body for `/scan` and `/scan/full`, query string for
`/report/html`) must resolve to one of `allowed_roots` (the server's
configured project directories, default: the working directory the
server was started in) or a descendant of one. This applies regardless
of authentication – it also blocks path traversal (`..`) from a request
that is otherwise authenticated.

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
