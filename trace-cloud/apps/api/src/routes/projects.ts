import { Router, Response, NextFunction } from "express";
import slugify from "slugify";
import crypto from "crypto";
import { z } from "zod";
import { prisma } from "../lib/prisma";
import { requireAuth, AuthRequest } from "../middleware/auth";
import { validate } from "../middleware/validate";
import { AppError } from "../middleware/error";
import { setProjectSchedule } from "../services/scheduler";

const router = Router({ mergeParams: true });

const createProjectSchema = z.object({
  name: z.string().min(2).max(80),
  description: z.string().max(500).optional(),
  repoUrl: z.string().url().optional(),
  scanRoot: z.string().default("."),
  defaultBranch: z.string().default("main"),
  slug: z.string().regex(/^[a-z0-9-]+$/).min(2).max(50).optional(),
});

const updateProjectSchema = createProjectSchema.partial();

async function getOrgForCaller(orgSlug: string, userId: string) {
  const membership = await prisma.orgMember.findFirst({
    where: { org: { slug: orgSlug }, userId },
    include: { org: true },
  });
  if (!membership) throw new AppError(404, "Organization not found");
  return { org: membership.org, role: membership.role };
}

// GET /api/v1/orgs/:orgSlug/projects
router.get("/", requireAuth, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { org } = await getOrgForCaller(req.params.orgSlug, req.userId!);
    const projects = await prisma.project.findMany({
      where: { orgId: org.id },
      include: {
        _count: { select: { scans: true } },
        scans: {
          where: { status: "SUCCEEDED" },
          orderBy: { createdAt: "desc" },
          take: 1,
          select: { id: true, overallScore: true, overallLabel: true, createdAt: true },
        },
      },
      orderBy: { createdAt: "desc" },
    });
    res.json({ projects });
  } catch (err) {
    next(err);
  }
});

// POST /api/v1/orgs/:orgSlug/projects
router.post("/", requireAuth, validate(createProjectSchema), async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { org, role } = await getOrgForCaller(req.params.orgSlug, req.userId!);
    if (!["OWNER", "ADMIN"].includes(role)) throw new AppError(403, "Insufficient permissions");

    const body = req.body as z.infer<typeof createProjectSchema>;
    const slug = body.slug ?? slugify(body.name, { lower: true, strict: true });

    const project = await prisma.project.create({
      data: { ...body, slug, orgId: org.id },
    });
    res.status(201).json({ project });
  } catch (err) {
    next(err);
  }
});

// GET /api/v1/orgs/:orgSlug/projects/:projectSlug
router.get("/:projectSlug", requireAuth, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { org } = await getOrgForCaller(req.params.orgSlug, req.userId!);
    const project = await prisma.project.findUnique({
      where: { orgId_slug: { orgId: org.id, slug: req.params.projectSlug } },
      include: { _count: { select: { scans: true } } },
    });
    if (!project) throw new AppError(404, "Project not found");
    res.json({ project });
  } catch (err) {
    next(err);
  }
});

// PATCH /api/v1/orgs/:orgSlug/projects/:projectSlug
router.patch("/:projectSlug", requireAuth, validate(updateProjectSchema), async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { org, role } = await getOrgForCaller(req.params.orgSlug, req.userId!);
    if (!["OWNER", "ADMIN"].includes(role)) throw new AppError(403, "Insufficient permissions");

    const project = await prisma.project.update({
      where: { orgId_slug: { orgId: org.id, slug: req.params.projectSlug } },
      data: req.body,
    });
    res.json({ project });
  } catch (err) {
    next(err);
  }
});

// DELETE /api/v1/orgs/:orgSlug/projects/:projectSlug
router.delete("/:projectSlug", requireAuth, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { org, role } = await getOrgForCaller(req.params.orgSlug, req.userId!);
    if (!["OWNER", "ADMIN"].includes(role)) throw new AppError(403, "Insufficient permissions");

    await prisma.project.delete({
      where: { orgId_slug: { orgId: org.id, slug: req.params.projectSlug } },
    });
    res.json({ ok: true });
  } catch (err) {
    next(err);
  }
});

// GET /api/v1/orgs/:orgSlug/projects/:projectSlug/score-history
router.get("/:projectSlug/score-history", requireAuth, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { org } = await getOrgForCaller(req.params.orgSlug, req.userId!);
    const project = await prisma.project.findUnique({
      where: { orgId_slug: { orgId: org.id, slug: req.params.projectSlug } },
    });
    if (!project) throw new AppError(404, "Project not found");

    const limit = Math.min(Number(req.query.limit ?? 30), 100);
    const scans = await prisma.scan.findMany({
      where: { projectId: project.id, status: "SUCCEEDED" },
      orderBy: { createdAt: "asc" },
      take: limit,
      select: {
        id: true,
        overallScore: true,
        overallLabel: true,
        createdAt: true,
        branch: true,
        moduleScores: { select: { moduleId: true, score: true, label: true } },
      },
    });
    res.json({ history: scans });
  } catch (err) {
    next(err);
  }
});

// POST /api/v1/orgs/:orgSlug/projects/:projectSlug/schedule
router.post("/:projectSlug/schedule", requireAuth, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { org, role } = await getOrgForCaller(req.params.orgSlug, req.userId!);
    if (role === "VIEWER" || role === "MEMBER") throw new AppError(403, "Admin or Owner required");

    const { cron } = z.object({
      cron: z.string().nullable(),
    }).parse(req.body);

    const project = await prisma.project.findFirst({
      where: { org: { slug: req.params.orgSlug }, slug: req.params.projectSlug },
    });
    if (!project) throw new AppError(404, "Project not found");

    await setProjectSchedule(project.id, cron);
    res.json({ scheduled: !!cron, cron });
  } catch (err) {
    next(err);
  }
});

// POST /api/v1/orgs/:orgSlug/projects/:projectSlug/webhook  — rotate webhook secret
router.post("/:projectSlug/webhook", requireAuth, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { org, role } = await getOrgForCaller(req.params.orgSlug, req.userId!);
    if (role === "VIEWER" || role === "MEMBER") throw new AppError(403, "Admin or Owner required");

    const project = await prisma.project.findFirst({
      where: { org: { slug: req.params.orgSlug }, slug: req.params.projectSlug },
    });
    if (!project) throw new AppError(404, "Project not found");

    const secret = crypto.randomBytes(32).toString("hex");
    await prisma.project.update({
      where: { id: project.id },
      data: { webhookSecret: secret },
    });

    res.json({
      webhookUrl: `/api/v1/webhooks/github/${project.id}`,
      secret,
      note: "Store this secret securely — it will not be shown again.",
    });
  } catch (err) {
    next(err);
  }
});

// GET /api/v1/badge/:badgeToken/svg  — public badge endpoint
router.get("/badge/:badgeToken/svg", async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const project = await prisma.project.findUnique({
      where: { badgeToken: req.params.badgeToken },
      include: {
        scans: {
          where: { status: "SUCCEEDED" },
          orderBy: { createdAt: "desc" },
          take: 1,
          select: { overallScore: true, overallLabel: true },
        },
      },
    });

    const scan = project?.scans[0];
    const score = scan?.overallScore ?? "?";
    const label = scan?.overallLabel ?? "unknown";
    const color = scoreColor(scan?.overallScore);

    res.setHeader("Content-Type", "image/svg+xml");
    res.setHeader("Cache-Control", "no-cache, max-age=0");
    res.send(makeBadgeSvg(`trace ${label}`, String(score), color));
  } catch (err) {
    next(err);
  }
});

function scoreColor(score: number | undefined): string {
  if (score === undefined) return "#9ca3af";
  if (score >= 90) return "#16a34a";
  if (score >= 75) return "#2563eb";
  if (score >= 60) return "#d97706";
  if (score >= 40) return "#dc2626";
  return "#7c3aed";
}

function makeBadgeSvg(left: string, right: string, color: string): string {
  const lw = left.length * 6.5 + 10;
  const rw = right.length * 7 + 10;
  const w = lw + rw;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="20" role="img" aria-label="${left}: ${right}">
  <linearGradient id="s" x2="0" y2="100%">
    <stop offset="0" stop-color="#bbb" stop-opacity=".1"/>
    <stop offset="1" stop-opacity=".1"/>
  </linearGradient>
  <clipPath id="r"><rect width="${w}" height="20" rx="3" fill="#fff"/></clipPath>
  <g clip-path="url(#r)">
    <rect width="${lw}" height="20" fill="#555"/>
    <rect x="${lw}" width="${rw}" height="20" fill="${color}"/>
    <rect width="${w}" height="20" fill="url(#s)"/>
  </g>
  <g fill="#fff" text-anchor="middle" font-family="DejaVu Sans,Verdana,Geneva,sans-serif" font-size="110">
    <text x="${(lw / 2 + 1) * 10}" y="150" fill="#010101" fill-opacity=".3" transform="scale(.1)">${left}</text>
    <text x="${(lw / 2) * 10}" y="140" transform="scale(.1)">${left}</text>
    <text x="${(lw + rw / 2 + 1) * 10}" y="150" fill="#010101" fill-opacity=".3" transform="scale(.1)">${right}</text>
    <text x="${(lw + rw / 2) * 10}" y="140" transform="scale(.1)">${right}</text>
  </g>
</svg>`;
}

export default router;
