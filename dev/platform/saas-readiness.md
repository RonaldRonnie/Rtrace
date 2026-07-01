# Trace Platform — SaaS Readiness Assessment

**Assessment Date:** 2026-07-01  
**Platform Version:** 0.2.0.dev  
**Scope:** What would need to be added to ship Trace Platform as a
multi-tenant SaaS product (cloud-hosted, subscription billing, team
management, web UI).

---

## TL;DR

The platform's **R-package core is SaaS-capable**: the API server, scoring
system, diagnostics model, and recommendation engine all work as
microservice components today. The missing pieces are **infrastructure**
(auth, multi-tenancy, job queuing) and **frontend** (the self-contained HTML
dashboard replaces the SPA but doesn't have login, project management, or
organization views).

**Estimated effort to MVP SaaS:** 3–6 months for a small team (2 backend,
1 frontend, 0.5 devops).

---

## What Is Already SaaS-Ready

### 1. REST API (score: 8/10)

`R/api.R` exposes all necessary scan operations over HTTP. The plumber
server can run in a Docker container today.

**Gaps before SaaS:**
- No authentication middleware (API keys / Bearer tokens)
- No rate limiting
- No per-tenant scan isolation
- No async job support (long scans block the HTTP thread)

### 2. Scoring System (score: 10/10)

`compute_score()` and `aggregate_scores()` are stateless, pure functions.
They can run inside an API handler, a background job, or a serverless
function with no changes.

### 3. Recommendation Engine (score: 9/10)

Provider-agnostic design means you can plug in an external LLM (Claude API,
OpenAI) without changing any core code. The `register_recommendation_provider()`
hook is the correct interface for this.

**Gap:** No HTTP adapter for LLM providers is shipped yet (planned).

### 4. Diagnostics Model (score: 10/10)

`rtrace_diagnostic` is a language-agnostic, JSON-serializable record. No
SaaS-specific changes needed.

### 5. Dashboard Reporter (score: 7/10)

`reporter_dashboard()` produces a self-contained HTML file that works as a
per-scan artifact (email attachment, CI artifact, static hosting). For SaaS,
you'd want an interactive React/Vue SPA that fetches from the API instead of
a static HTML file — but the HTML output remains useful as a shareable
report format.

---

## Gaps and Required Work

### Gap 1: Authentication & Authorization

| Item | Effort | Priority |
|------|--------|----------|
| API key generation and validation | M | Critical |
| Bearer token middleware (plumber filter) | S | Critical |
| Role-based access (admin / member / viewer) | M | High |
| SSO / SAML (enterprise tier) | L | Medium |
| Audit log of who ran which scan | M | Medium |

**Implementation path:**
```r
# plumber filter in R/api.R
pr$filter("auth", function(req, res) {
  token <- req$HTTP_AUTHORIZATION
  if (!is_valid_token(token)) {
    res$status <- 401
    return(list(error = "Unauthorized"))
  }
  plumber::forward()
})
```

### Gap 2: Multi-Tenancy

| Item | Effort | Priority |
|------|--------|----------|
| Organization model (org → projects → scans) | L | Critical |
| Tenant-scoped data isolation | M | Critical |
| Per-tenant rule overrides / config | M | High |
| Billing / subscription tracking | L | Medium |

**Implementation path:** Introduce a lightweight database (SQLite for dev,
Postgres for prod) to store organizations, projects, and scan history.
The scan engine itself is stateless — only the persistence layer changes.

### Gap 3: Async Job Queue

Long scans (large monorepos) can take 10–60 seconds. HTTP requests should not
block that long.

| Item | Effort | Priority |
|------|--------|----------|
| Background job queue (Redis + later callr) | M | High |
| Job status polling endpoint (`GET /jobs/:id`) | S | High |
| Webhook on job completion | M | Medium |

### Gap 4: Scan History & Trend Tracking

| Item | Effort | Priority |
|------|--------|----------|
| Store scan results in database | M | High |
| Historical score trends per project | M | High |
| Regression alerting (score dropped > X) | M | Medium |
| Branch-level comparisons | L | Low |

### Gap 5: Frontend SPA

The self-contained HTML dashboard is not a replacement for a full web UI.

| Item | Effort | Priority |
|------|--------|----------|
| Project list / dashboard overview page | M | Critical |
| Organization / team management | L | High |
| Scan history view | M | High |
| Rule configuration UI | L | Medium |
| Recommendation review & dismiss | M | Medium |

**Technology recommendation:** React + Vite, hosted as a static site, talking
to the plumber API. No R knowledge required for frontend development.

### Gap 6: Infrastructure

| Item | Effort | Priority |
|------|--------|----------|
| Docker image (`rocker/r-ver` base) | S | Critical |
| Docker Compose (API + Postgres + Redis) | S | Critical |
| Kubernetes Helm chart | L | Medium |
| Health check + readiness probe | S | High |
| Secrets management (Vault / AWS Secrets Manager) | M | Medium |
| Horizontal scaling (stateless API ✅, job workers ✅) | S | Medium |

The API server is stateless and can be horizontally scaled today. The
`rtrace_env` registry is process-local, which is intentional — each worker
process registers the same rules independently on startup.

---

## Deployment Architecture (Target)

```
┌─────────────────────────────────────────────────────┐
│                       Internet                       │
└────────────────────────┬────────────────────────────┘
                         │ HTTPS
                ┌────────▼──────────┐
                │   Load Balancer   │  (nginx / Caddy / ALB)
                └────────┬──────────┘
          ┌──────────────┴──────────────┐
          │                             │
 ┌────────▼──────────┐      ┌───────────▼──────────┐
 │    Frontend SPA    │      │     plumber API       │
 │   (React / CDN)    │      │  (rocker Docker ×N)  │
 └───────────────────┘      └───────────┬──────────┘
                                         │
                     ┌───────────────────┼──────────────────┐
                     │                   │                  │
            ┌────────▼───────┐  ┌────────▼───────┐  ┌──────▼──────┐
            │   PostgreSQL   │  │     Redis      │  │  S3 / GCS   │
            │ (scan history) │  │  (job queue)   │  │  (reports)  │
            └────────────────┘  └────────────────┘  └─────────────┘
```

---

## Pricing Model Recommendation

| Tier | Price | Limits |
|------|-------|--------|
| **Open Source** | Free | Self-hosted; R package only |
| **Developer** | $19/mo | 50 scans/mo; 1 user |
| **Team** | $99/mo | 500 scans/mo; 10 users; scan history |
| **Business** | $499/mo | Unlimited scans; 50 users; SSO; API |
| **Enterprise** | Custom | Self-hosted SaaS; SLAs; custom rules |

---

## Compliance Readiness

| Standard | Status | Gap |
|----------|--------|-----|
| SOC 2 Type I | ❌ | Need audit logging, access controls |
| SOC 2 Type II | ❌ | +6 months continuous monitoring |
| GDPR | 🔶 | Scan paths/filenames may contain PII; need data retention policy |
| ISO 27001 | ❌ | Enterprise tier concern |
| HIPAA | ❌ | Not applicable unless analyzing healthcare research data |

---

## SaaS Readiness Score

| Domain | Score | Notes |
|--------|-------|-------|
| API design | 8/10 | Well-structured; needs auth + async |
| Scoring / analytics | 10/10 | Fully SaaS-ready |
| Recommendation engine | 9/10 | Provider hook ready for LLM integrations |
| Dashboard / reporting | 7/10 | Static HTML ✅; interactive SPA ❌ |
| Authentication | 2/10 | Not yet implemented |
| Multi-tenancy | 1/10 | Not yet implemented |
| Job queue / async | 2/10 | Not yet implemented |
| Scan history | 1/10 | Not yet implemented |
| Infrastructure / Docker | 3/10 | No Dockerfile yet |
| CI/CD for SaaS deploy | 2/10 | Only self-CI exists |
| **Overall** | **4.5/10** | Core is ready; infra layer is the gap |
