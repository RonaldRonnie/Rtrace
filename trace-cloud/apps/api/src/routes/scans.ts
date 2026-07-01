import { Router, Response, NextFunction } from "express";
import { z } from "zod";
import { prisma } from "../lib/prisma";
import { requireAuth, AuthRequest } from "../middleware/auth";
import { AppError } from "../middleware/error";
import { enqueueScan } from "../lib/queue";
import { metrics } from "../lib/metrics";

const router = Router({ mergeParams: true });

async function resolveProject(orgSlug: string, projectSlug: string, userId: string) {
  const membership = await prisma.orgMember.findFirst({
    where: { org: { slug: orgSlug }, userId },
  });
  if (!membership) throw new AppError(404, "Organization not found");

  const project = await prisma.project.findFirst({
    where: { org: { slug: orgSlug }, slug: projectSlug },
  });
  if (!project) throw new AppError(404, "Project not found");

  return { project, role: membership.role };
}

// GET /api/v1/orgs/:orgSlug/projects/:projectSlug/scans
router.get("/", requireAuth, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { project } = await resolveProject(req.params.orgSlug, req.params.projectSlug, req.userId!);

    const page = Math.max(1, Number(req.query.page ?? 1));
    const limit = Math.min(50, Number(req.query.limit ?? 20));
    const skip = (page - 1) * limit;

    const [scans, total] = await Promise.all([
      prisma.scan.findMany({
        where: { projectId: project.id },
        orderBy: { createdAt: "desc" },
        skip,
        take: limit,
        include: {
          moduleScores: true,
          _count: { select: { diagnostics: true } },
        },
      }),
      prisma.scan.count({ where: { projectId: project.id } }),
    ]);

    res.json({ scans, pagination: { page, limit, total, pages: Math.ceil(total / limit) } });
  } catch (err) {
    next(err);
  }
});

// POST /api/v1/orgs/:orgSlug/projects/:projectSlug/scans  — trigger scan
router.post("/", requireAuth, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { project, role } = await resolveProject(req.params.orgSlug, req.params.projectSlug, req.userId!);
    if (role === "VIEWER") throw new AppError(403, "Viewers cannot trigger scans");

    const { branch, modules } = z.object({
      branch: z.string().optional(),
      modules: z.array(z.string()).default(["rtrace", "reproducibility", "datatrace", "docstrace", "packageqa"]),
    }).parse(req.body);

    const scan = await prisma.scan.create({
      data: {
        projectId: project.id,
        userId: req.userId,
        branch: branch ?? project.defaultBranch,
        triggeredBy: "manual",
        status: "PENDING",
      },
    });

    await enqueueScan({
      scanId: scan.id,
      projectId: project.id,
      scanRoot: project.scanRoot,
      modules,
    });

    metrics.scansTriggered.inc();
    res.status(202).json({ scan });
  } catch (err) {
    next(err);
  }
});

// GET /api/v1/orgs/:orgSlug/projects/:projectSlug/scans/:scanId
router.get("/:scanId", requireAuth, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { project } = await resolveProject(req.params.orgSlug, req.params.projectSlug, req.userId!);

    const scan = await prisma.scan.findFirst({
      where: { id: req.params.scanId, projectId: project.id },
      include: {
        moduleScores: true,
        _count: { select: { diagnostics: true } },
      },
    });
    if (!scan) throw new AppError(404, "Scan not found");
    res.json({ scan });
  } catch (err) {
    next(err);
  }
});

// GET /api/v1/orgs/:orgSlug/projects/:projectSlug/scans/:scanId/diagnostics
router.get("/:scanId/diagnostics", requireAuth, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { project } = await resolveProject(req.params.orgSlug, req.params.projectSlug, req.userId!);

    const scan = await prisma.scan.findFirst({ where: { id: req.params.scanId, projectId: project.id } });
    if (!scan) throw new AppError(404, "Scan not found");

    const severity = req.query.severity as string | undefined;
    const moduleId = req.query.module as string | undefined;
    const page = Math.max(1, Number(req.query.page ?? 1));
    const limit = Math.min(200, Number(req.query.limit ?? 50));

    const [diagnostics, total] = await Promise.all([
      prisma.diagnostic.findMany({
        where: {
          scanId: scan.id,
          ...(severity ? { severity } : {}),
          ...(moduleId ? { moduleId } : {}),
        },
        orderBy: [{ severity: "asc" }, { file: "asc" }, { line: "asc" }],
        skip: (page - 1) * limit,
        take: limit,
      }),
      prisma.diagnostic.count({
        where: {
          scanId: scan.id,
          ...(severity ? { severity } : {}),
          ...(moduleId ? { moduleId } : {}),
        },
      }),
    ]);

    res.json({ diagnostics, pagination: { page, limit, total, pages: Math.ceil(total / limit) } });
  } catch (err) {
    next(err);
  }
});

// GET /api/v1/orgs/:orgSlug/projects/:projectSlug/scans/:scanId/report
router.get("/:scanId/report", requireAuth, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { project } = await resolveProject(req.params.orgSlug, req.params.projectSlug, req.userId!);

    const scan = await prisma.scan.findFirst({ where: { id: req.params.scanId, projectId: project.id } });
    if (!scan) throw new AppError(404, "Scan not found");

    // Proxy the HTML report from the R engine
    const rtraceUrl = process.env.RTRACE_API_URL ?? "http://localhost:8394";
    try {
      const resp = await fetch(`${rtraceUrl}/report/html?root=${encodeURIComponent(project.scanRoot)}`);
      res.setHeader("Content-Type", "text/html; charset=utf-8");
      res.send(await resp.text());
    } catch {
      res.status(503).json({ error: "RTrace engine unavailable" });
    }
  } catch (err) {
    next(err);
  }
});

// DELETE /api/v1/orgs/:orgSlug/projects/:projectSlug/scans/:scanId
router.delete("/:scanId", requireAuth, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { project, role } = await resolveProject(req.params.orgSlug, req.params.projectSlug, req.userId!);
    if (!["OWNER", "ADMIN"].includes(role)) throw new AppError(403, "Insufficient permissions");

    await prisma.scan.deleteMany({ where: { id: req.params.scanId, projectId: project.id } });
    res.json({ ok: true });
  } catch (err) {
    next(err);
  }
});

export default router;
