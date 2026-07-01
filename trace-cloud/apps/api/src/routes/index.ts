import { Router } from "express";
import authRouter from "./auth";
import orgsRouter from "./orgs";
import projectsRouter from "./projects";
import scansRouter from "./scans";
import rulesRouter from "./rules";
import webhooksRouter from "./webhooks";
import healthRouter from "./health";

const router = Router();

// Health & observability (no auth required)
router.use("/", healthRouter);

// VCS provider webhooks (auth via HMAC signature)
router.use("/webhooks", webhooksRouter);

// Authenticated API routes
router.use("/auth", authRouter);
router.use("/orgs", orgsRouter);
router.use("/orgs/:orgSlug/projects", projectsRouter);
router.use("/orgs/:orgSlug/projects/:projectSlug/scans", scansRouter);
router.use("/rules", rulesRouter);

export default router;
