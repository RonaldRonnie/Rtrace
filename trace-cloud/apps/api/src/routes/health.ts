import { Router } from "express";
import { prisma } from "../lib/prisma";
import { redis } from "../lib/queue";
import { renderMetrics } from "../lib/metrics";
import { config } from "../config";

const router = Router();

/** GET /health — liveness + readiness probe */
router.get("/health", async (_req, res) => {
  const start = Date.now();

  // Database check
  let dbOk = false;
  let dbMs = -1;
  try {
    const t0 = Date.now();
    await prisma.$queryRaw`SELECT 1`;
    dbMs = Date.now() - t0;
    dbOk = true;
  } catch {}

  // Redis check
  let redisOk = false;
  let redisMs = -1;
  try {
    const t0 = Date.now();
    await redis.ping();
    redisMs = Date.now() - t0;
    redisOk = true;
  } catch {}

  const healthy = dbOk && redisOk;
  const totalMs = Date.now() - start;

  const body = {
    status: healthy ? "ok" : "degraded",
    version: process.env.npm_package_version ?? "unknown",
    env: config.NODE_ENV,
    uptime: Math.round(process.uptime()),
    checks: {
      database: { ok: dbOk,    latencyMs: dbMs    },
      redis:    { ok: redisOk, latencyMs: redisMs },
    },
    responseMs: totalMs,
    timestamp: new Date().toISOString(),
  };

  res.status(healthy ? 200 : 503).json(body);
});

/** GET /ready — Kubernetes readiness probe (fast, DB + Redis required) */
router.get("/ready", async (_req, res) => {
  try {
    await Promise.all([
      prisma.$queryRaw`SELECT 1`,
      redis.ping(),
    ]);
    res.status(200).json({ ready: true });
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    res.status(503).json({ ready: false, error: msg });
  }
});

/** GET /live — Kubernetes liveness probe (no I/O required) */
router.get("/live", (_req, res) => {
  res.status(200).json({ alive: true });
});

/** GET /metrics — Prometheus text format */
router.get("/metrics", (_req, res) => {
  res.set("Content-Type", "text/plain; version=0.0.4; charset=utf-8");
  res.send(renderMetrics());
});

export default router;
