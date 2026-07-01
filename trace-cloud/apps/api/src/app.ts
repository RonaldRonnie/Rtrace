import express, { Request, Response, NextFunction } from "express";
import cors from "cors";
import helmet from "helmet";
import compression from "compression";
import cookieParser from "cookie-parser";
import rateLimit from "express-rate-limit";
import crypto from "crypto";
import { config } from "./config";
import apiRouter from "./routes";
import { errorHandler } from "./middleware/error";
import { logger } from "./lib/logger";
import { metrics } from "./lib/metrics";

const app = express();

// ── Security headers ──────────────────────────────────────────────────────────
app.use(helmet({ contentSecurityPolicy: false }));
app.use(cors({
  origin: config.CORS_ORIGIN,
  credentials: true,
  methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
}));

// ── Rate limiting ─────────────────────────────────────────────────────────────
app.use("/api/v1/auth", rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 30,
  message: { error: "Too many requests" },
  standardHeaders: true,
  legacyHeaders: false,
}));

app.use(rateLimit({
  windowMs: 60 * 1000,
  max: 200,
  standardHeaders: true,
  legacyHeaders: false,
}));

// ── Raw body capture for webhook signature verification ───────────────────────
app.use(
  express.json({
    limit: "10mb",
    verify: (req: Request & { rawBody?: Buffer }, _res, buf) => {
      req.rawBody = buf;
    },
  })
);
app.use(compression());
app.use(cookieParser());

// ── Request correlation ID ────────────────────────────────────────────────────
app.use((req: Request & { id?: string }, _res: Response, next: NextFunction) => {
  req.id = (req.headers["x-request-id"] as string | undefined) ?? crypto.randomUUID();
  next();
});

// ── Structured request logging ────────────────────────────────────────────────
if (config.NODE_ENV !== "test") {
  app.use((req: Request & { id?: string }, res: Response, next: NextFunction) => {
    const start = Date.now();
    res.on("finish", () => {
      const ms = Date.now() - start;
      const level = res.statusCode >= 500 ? "error"
                  : res.statusCode >= 400 ? "warn"
                  : "info";
      logger[level](`${req.method} ${req.path}`, {
        status: res.statusCode,
        ms,
        requestId: (req as { id?: string }).id,
        ip: req.ip,
      });
      metrics.httpRequests.inc();
      if (res.statusCode >= 400) metrics.httpErrors.inc();
    });
    next();
  });
}

// ── Routes ────────────────────────────────────────────────────────────────────
app.use("/api/v1", apiRouter);

// ── 404 ───────────────────────────────────────────────────────────────────────
app.use((_req, res) => res.status(404).json({ error: "Not found" }));

// ── Error handler (must be last) ──────────────────────────────────────────────
app.use(errorHandler);

export default app;
