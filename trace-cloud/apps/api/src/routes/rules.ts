import { Router, Request, Response, NextFunction } from "express";
import { config } from "../config";

const router = Router();

// GET /api/v1/rules  — proxy to the RTrace engine
router.get("/", async (_req: Request, res: Response, next: NextFunction) => {
  try {
    const rtraceUrl = config.RTRACE_API_URL ?? "http://localhost:8394";
    const resp = await fetch(`${rtraceUrl}/rules`);
    const data = await resp.json();
    res.json(data);
  } catch (err) {
    next(err);
  }
});

// GET /api/v1/modules
router.get("/modules", async (_req: Request, res: Response, next: NextFunction) => {
  try {
    const rtraceUrl = config.RTRACE_API_URL ?? "http://localhost:8394";
    const resp = await fetch(`${rtraceUrl}/modules`);
    const data = await resp.json();
    res.json(data);
  } catch (err) {
    next(err);
  }
});

// GET /api/v1/health
router.get("/health", (_req: Request, res: Response) => {
  res.json({
    status: "ok",
    service: "trace-cloud-api",
    version: "0.1.0",
    timestamp: new Date().toISOString(),
  });
});

export default router;
