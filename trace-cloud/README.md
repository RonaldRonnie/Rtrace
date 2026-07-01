# Trace Cloud

Web platform for managing RTrace scans, projects, organizations, dashboards, and historical reports.

## Stack

| Layer | Technology |
|---|---|
| API | Node.js 20 + Express + TypeScript + Prisma (PostgreSQL) |
| Queue | BullMQ + Redis |
| Auth | JWT (access 15 min / refresh 7 d) + API keys |
| Frontend | React 18 + Vite + Tailwind CSS + TanStack Query v5 |
| R engine | rocker/r-ver:4.4 + plumber (primary) / Rscript fallback |
| Infra | Docker Compose |

## Quick start (development)

### Prerequisites
- Docker & Docker Compose v2
- Node.js 20+

### 1. Configure environment

```bash
cp .env.example .env
# Edit .env — set strong values for JWT_ACCESS_SECRET and JWT_REFRESH_SECRET
```

### 2. Start services

```bash
docker compose up -d postgres redis
```

### 3. Run the API

```bash
cd apps/api
npm install
npx prisma migrate dev
npx prisma db seed
npm run dev
```

### 4. Run the frontend

```bash
cd apps/web
npm install
npm run dev
```

Open http://localhost:5173 and sign in with:
- **Email:** demo@tracecloud.dev
- **Password:** password123

## Full Docker Compose (all services)

```bash
docker compose up --build
```

Open http://localhost:3001 (web) and http://localhost:3000 (API).

## Production deployment

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

Set `POSTGRES_PASSWORD` and `REDIS_PASSWORD` in your environment before running.

## REST API overview

All endpoints require `Authorization: Bearer <jwt>` or `X-API-Key: tc_<key>`.

| Method | Path | Description |
|---|---|---|
| POST | `/auth/register` | Create account |
| POST | `/auth/login` | Login, get JWT |
| POST | `/auth/refresh` | Rotate refresh token |
| GET | `/auth/me` | Current user |
| GET/POST | `/auth/api-keys` | List/create API keys |
| GET/POST | `/orgs` | List/create organizations |
| GET/PATCH | `/orgs/:slug` | Get/update org |
| GET/POST | `/orgs/:slug/projects` | List/create projects |
| GET/PATCH | `/orgs/:slug/projects/:slug` | Get/update project |
| GET | `/orgs/:slug/projects/:slug/score-history` | Score trend data |
| GET/POST | `/orgs/:slug/projects/:slug/scans` | List scans / trigger scan |
| GET | `/orgs/:slug/projects/:slug/scans/:id` | Get scan detail |
| GET | `/orgs/:slug/projects/:slug/scans/:id/diagnostics` | Paginated diagnostics |
| GET | `/orgs/:slug/projects/:slug/scans/:id/report` | HTML report (proxied from R engine) |
| DELETE | `/orgs/:slug/projects/:slug/scans/:id` | Delete scan |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Browser (React)                                            │
│  Login → Dashboard → Org → Project → Scan detail           │
└────────────────────┬────────────────────────────────────────┘
                     │ HTTP (JWT / API key)
┌────────────────────▼────────────────────────────────────────┐
│  API server (Express + TypeScript)                          │
│  auth · orgs · projects · scans                             │
└───────┬─────────────────────────┬───────────────────────────┘
        │ BullMQ                  │ Prisma ORM
┌───────▼─────────┐    ┌──────────▼──────────────────────────┐
│  Scan worker    │    │  PostgreSQL                         │
│  (BullMQ)       │    │  users · orgs · projects · scans    │
└───────┬─────────┘    └─────────────────────────────────────┘
        │ HTTP (plumber) / Rscript fallback
┌───────▼─────────────────────────────────────────────────────┐
│  R engine (rocker/r-ver:4.4)                                │
│  RTrace package + plumber API                               │
└─────────────────────────────────────────────────────────────┘
```

## Project structure

```
trace-cloud/
├── apps/
│   ├── api/              # Express API + Prisma + BullMQ worker
│   │   ├── prisma/       # schema.prisma, migrations, seed.ts
│   │   └── src/
│   │       ├── lib/      # prisma client, jwt helpers, queue
│   │       ├── middleware/  # auth, error handling
│   │       ├── routes/   # auth, orgs, projects, scans
│   │       ├── services/ # scanner (HTTP + Rscript fallback)
│   │       └── workers/  # scan.worker.ts (BullMQ)
│   └── web/              # React + Vite frontend
│       └── src/
│           ├── api/      # typed API clients
│           ├── components/  # ScoreRing, ScoreChart, DiagnosticsTable…
│           ├── pages/    # one file per route
│           └── stores/   # Zustand auth store
├── docker-compose.yml
├── docker-compose.prod.yml
└── .env.example
```
