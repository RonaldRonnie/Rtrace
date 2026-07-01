/**
 * Inbound webhook endpoint — receives push events from GitHub (and future VCS
 * providers) and enqueues a scan job. The signature is verified with HMAC-SHA256
 * using a per-project webhook secret stored in the database.
 *
 * GitHub sends:
 *   X-Hub-Signature-256: sha256=<hex>
 *   X-GitHub-Event:       push | pull_request | ...
 *   X-GitHub-Delivery:    <uuid>
 */
import { Router, Request, Response } from "express";
import crypto from "crypto";
import { prisma } from "../lib/prisma";
import { enqueueScan } from "../lib/queue";
import { logger } from "../lib/logger";
import { metrics } from "../lib/metrics";

const router = Router();

function verifyGitHubSignature(rawBody: Buffer, secret: string, sig256: string): boolean {
  const expected = "sha256=" + crypto.createHmac("sha256", secret).update(rawBody).digest("hex");
  try {
    return crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(sig256));
  } catch {
    return false;
  }
}

/** POST /webhooks/github/:projectId */
router.post(
  "/github/:projectId",
  // Raw body needed for signature verification — bodyParser must run BEFORE this
  async (req: Request, res: Response) => {
    const { projectId } = req.params;
    const event    = req.headers["x-github-event"] as string | undefined;
    const delivery = req.headers["x-github-delivery"] as string | undefined;
    const sig256   = req.headers["x-hub-signature-256"] as string | undefined;

    metrics.webhooksReceived.inc();

    // --- Find project and its webhook secret ---
    const project = await prisma.project.findUnique({
      where: { id: projectId },
      select: { id: true, orgId: true, slug: true, scanRoot: true, webhookSecret: true },
    }).catch(() => null);

    if (!project) {
      return res.status(404).json({ error: "Project not found" });
    }

    // --- Signature verification ---
    if (project.webhookSecret) {
      if (!sig256) {
        logger.warn("Webhook rejected: missing signature", { projectId, delivery });
        return res.status(401).json({ error: "Missing X-Hub-Signature-256 header" });
      }
      const rawBody = (req as Request & { rawBody?: Buffer }).rawBody;
      if (!rawBody) {
        return res.status(400).json({ error: "Raw body unavailable for signature verification" });
      }
      if (!verifyGitHubSignature(rawBody, project.webhookSecret, sig256)) {
        logger.warn("Webhook rejected: invalid signature", { projectId, delivery });
        return res.status(401).json({ error: "Invalid signature" });
      }
    }

    // --- Handle event ---
    const payload = req.body as Record<string, unknown>;

    if (event === "push") {
      const branch = (payload.ref as string | undefined)?.replace("refs/heads/", "") ?? "unknown";
      const sha    = (payload.after as string | undefined) ?? undefined;
      const defaultBranch = (payload.repository as { default_branch?: string } | undefined)?.default_branch;

      // Only scan default branch on push by default
      if (defaultBranch && branch !== defaultBranch) {
        logger.info("Webhook push: skipping non-default branch", { projectId, branch, defaultBranch });
        return res.json({ received: true, queued: false, reason: "non-default branch" });
      }

      const scan = await prisma.scan.create({
        data: {
          projectId:   project.id,
          status:      "PENDING",
          branch,
          commitSha:   sha,
          triggeredBy: "webhook:github",
        },
      });

      await enqueueScan({
        scanId:   scan.id,
        projectId: project.id,
        scanRoot: project.scanRoot,
        modules:  [],
      });

      metrics.scansTriggered.inc();
      logger.info("Webhook triggered scan", { scanId: scan.id, projectId, branch, delivery });

      return res.json({ received: true, queued: true, scanId: scan.id });
    }

    if (event === "ping") {
      logger.info("Webhook ping received", { projectId, delivery });
      return res.json({ received: true, queued: false, reason: "ping" });
    }

    logger.debug("Webhook event ignored", { projectId, event, delivery });
    return res.json({ received: true, queued: false, reason: `event '${event}' not handled` });
  }
);

export default router;
