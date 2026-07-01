import { Router, Response, NextFunction } from "express";
import slugify from "slugify";
import { z } from "zod";
import { prisma } from "../lib/prisma";
import { requireAuth, requireOrgRole, AuthRequest } from "../middleware/auth";
import { validate } from "../middleware/validate";
import { AppError } from "../middleware/error";

const router = Router();

const createOrgSchema = z.object({
  name: z.string().min(2).max(80),
  description: z.string().max(500).optional(),
  slug: z.string().regex(/^[a-z0-9-]+$/).min(2).max(50).optional(),
});

const updateOrgSchema = z.object({
  name: z.string().min(2).max(80).optional(),
  description: z.string().max(500).optional(),
});

// GET /api/v1/orgs  — list orgs the caller belongs to
router.get("/", requireAuth, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const memberships = await prisma.orgMember.findMany({
      where: { userId: req.userId },
      include: {
        org: {
          include: {
            _count: { select: { members: true, projects: true } },
          },
        },
      },
      orderBy: { joinedAt: "asc" },
    });
    res.json({ orgs: memberships.map((m) => ({ ...m.org, role: m.role })) });
  } catch (err) {
    next(err);
  }
});

// POST /api/v1/orgs
router.post("/", requireAuth, validate(createOrgSchema), async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { name, description, slug: rawSlug } = req.body as z.infer<typeof createOrgSchema>;
    const slug = rawSlug ?? slugify(name, { lower: true, strict: true });

    const org = await prisma.$transaction(async (tx) => {
      const o = await tx.organization.create({ data: { name, description, slug } });
      await tx.orgMember.create({ data: { orgId: o.id, userId: req.userId!, role: "OWNER" } });
      return o;
    });

    res.status(201).json({ org });
  } catch (err) {
    next(err);
  }
});

// GET /api/v1/orgs/:orgSlug
router.get("/:orgSlug", requireAuth, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const org = await prisma.organization.findUnique({
      where: { slug: req.params.orgSlug },
      include: {
        _count: { select: { members: true, projects: true } },
        members: {
          where: { userId: req.userId },
          select: { role: true },
        },
      },
    });
    if (!org || org.members.length === 0) throw new AppError(404, "Organization not found");
    const { members, ...rest } = org;
    res.json({ org: { ...rest, role: members[0].role } });
  } catch (err) {
    next(err);
  }
});

// PATCH /api/v1/orgs/:orgSlug
router.patch(
  "/:orgSlug",
  requireAuth,
  async (req, res: Response, next: NextFunction) => {
    await (await requireOrgRole(["OWNER", "ADMIN"]))(req as AuthRequest, res, next);
  },
  validate(updateOrgSchema),
  async (req: AuthRequest, res: Response, next: NextFunction) => {
    try {
      const org = await prisma.organization.update({
        where: { slug: req.params.orgSlug },
        data: req.body,
      });
      res.json({ org });
    } catch (err) {
      next(err);
    }
  }
);

// GET /api/v1/orgs/:orgSlug/members
router.get("/:orgSlug/members", requireAuth, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const org = await prisma.organization.findUnique({
      where: { slug: req.params.orgSlug },
      select: {
        id: true,
        members: {
          include: { user: { select: { id: true, email: true, name: true, avatarUrl: true } } },
          orderBy: { joinedAt: "asc" },
        },
      },
    });
    if (!org) throw new AppError(404, "Organization not found");

    const isMember = org.members.some((m) => m.userId === req.userId);
    if (!isMember) throw new AppError(403, "Forbidden");

    res.json({
      members: org.members.map((m) => ({
        id: m.id,
        role: m.role,
        joinedAt: m.joinedAt,
        user: m.user,
      })),
    });
  } catch (err) {
    next(err);
  }
});

// POST /api/v1/orgs/:orgSlug/members  — invite by email
router.post("/:orgSlug/members", requireAuth, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    await (await requireOrgRole(["OWNER", "ADMIN"]))(req, res, next);
  } catch (err) { next(err); }
},
async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { email, role } = z.object({
      email: z.string().email(),
      role: z.enum(["ADMIN", "MEMBER", "VIEWER"]).default("MEMBER"),
    }).parse(req.body);

    const targetUser = await prisma.user.findUnique({ where: { email } });
    if (!targetUser) throw new AppError(404, "No user with that email address");

    const org = await prisma.organization.findUnique({ where: { slug: req.params.orgSlug } });
    if (!org) throw new AppError(404, "Organization not found");

    const member = await prisma.orgMember.create({
      data: { orgId: org.id, userId: targetUser.id, role },
      include: { user: { select: { id: true, email: true, name: true } } },
    });
    res.status(201).json({ member });
  } catch (err) {
    next(err);
  }
});

export default router;
