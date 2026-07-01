import { Router, Request, Response, NextFunction } from "express";
import bcrypt from "bcryptjs";
import { createHash, randomBytes } from "crypto";
import { z } from "zod";
import { prisma } from "../lib/prisma";
import {
  signAccessToken,
  signRefreshToken,
  verifyRefreshToken,
  refreshTokenExpiryDate,
} from "../lib/jwt";
import { validate } from "../middleware/validate";
import { requireAuth, AuthRequest } from "../middleware/auth";
import { AppError } from "../middleware/error";

const router = Router();

const registerSchema = z.object({
  email: z.string().email(),
  name: z.string().min(2).max(80),
  password: z.string().min(8),
});

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string(),
});

function setRefreshCookie(res: Response, token: string) {
  res.cookie("refresh_token", token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    maxAge: 7 * 24 * 60 * 60 * 1000,
    path: "/api/v1/auth",
  });
}

function clearRefreshCookie(res: Response) {
  res.clearCookie("refresh_token", { path: "/api/v1/auth" });
}

// POST /api/v1/auth/register
router.post("/register", validate(registerSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { email, name, password } = req.body as z.infer<typeof registerSchema>;

    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) throw new AppError(409, "An account with that email already exists");

    const passwordHash = await bcrypt.hash(password, 12);
    const user = await prisma.user.create({
      data: { email, name, passwordHash },
      select: { id: true, email: true, name: true, createdAt: true },
    });

    const tokenId = randomBytes(16).toString("hex");
    const refreshToken = signRefreshToken({ sub: user.id, jti: tokenId });
    const tokenHash = createHash("sha256").update(refreshToken).digest("hex");

    await prisma.refreshToken.create({
      data: {
        id: tokenId,
        tokenHash,
        userId: user.id,
        expiresAt: refreshTokenExpiryDate(),
      },
    });

    const accessToken = signAccessToken({ sub: user.id, email: user.email });
    setRefreshCookie(res, refreshToken);

    res.status(201).json({ user, accessToken });
  } catch (err) {
    next(err);
  }
});

// POST /api/v1/auth/login
router.post("/login", validate(loginSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { email, password } = req.body as z.infer<typeof loginSchema>;

    const user = await prisma.user.findUnique({ where: { email } });
    if (!user || !(await bcrypt.compare(password, user.passwordHash))) {
      throw new AppError(401, "Invalid email or password");
    }

    const tokenId = randomBytes(16).toString("hex");
    const refreshToken = signRefreshToken({ sub: user.id, jti: tokenId });
    const tokenHash = createHash("sha256").update(refreshToken).digest("hex");

    await prisma.refreshToken.create({
      data: {
        id: tokenId,
        tokenHash,
        userId: user.id,
        expiresAt: refreshTokenExpiryDate(),
      },
    });

    const accessToken = signAccessToken({ sub: user.id, email: user.email });
    setRefreshCookie(res, refreshToken);

    res.json({
      user: { id: user.id, email: user.email, name: user.name },
      accessToken,
    });
  } catch (err) {
    next(err);
  }
});

// POST /api/v1/auth/refresh
router.post("/refresh", async (req: Request, res: Response, next: NextFunction) => {
  try {
    const raw: string | undefined = req.cookies?.refresh_token;
    if (!raw) throw new AppError(401, "No refresh token");

    const payload = verifyRefreshToken(raw);
    const tokenHash = createHash("sha256").update(raw).digest("hex");
    const stored = await prisma.refreshToken.findUnique({ where: { tokenHash } });

    if (!stored || stored.userId !== payload.sub || stored.expiresAt < new Date()) {
      throw new AppError(401, "Invalid or expired refresh token");
    }

    const user = await prisma.user.findUnique({
      where: { id: payload.sub },
      select: { id: true, email: true, name: true },
    });
    if (!user) throw new AppError(401, "User not found");

    // Rotate refresh token
    await prisma.refreshToken.delete({ where: { id: stored.id } });

    const newTokenId = randomBytes(16).toString("hex");
    const newRefreshToken = signRefreshToken({ sub: user.id, jti: newTokenId });
    const newTokenHash = createHash("sha256").update(newRefreshToken).digest("hex");
    await prisma.refreshToken.create({
      data: {
        id: newTokenId,
        tokenHash: newTokenHash,
        userId: user.id,
        expiresAt: refreshTokenExpiryDate(),
      },
    });

    const accessToken = signAccessToken({ sub: user.id, email: user.email });
    setRefreshCookie(res, newRefreshToken);
    res.json({ accessToken });
  } catch (err) {
    next(err);
  }
});

// POST /api/v1/auth/logout
router.post("/logout", requireAuth, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const raw: string | undefined = req.cookies?.refresh_token;
    if (raw) {
      const tokenHash = createHash("sha256").update(raw).digest("hex");
      await prisma.refreshToken.deleteMany({ where: { tokenHash } }).catch(() => {});
    }
    clearRefreshCookie(res);
    res.json({ ok: true });
  } catch (err) {
    next(err);
  }
});

// GET /api/v1/auth/me
router.get("/me", requireAuth, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.userId },
      select: {
        id: true, email: true, name: true, avatarUrl: true, createdAt: true,
        memberships: {
          include: { org: { select: { id: true, name: true, slug: true, plan: true } } },
        },
      },
    });
    if (!user) throw new AppError(404, "User not found");
    res.json({ user });
  } catch (err) {
    next(err);
  }
});

// POST /api/v1/auth/api-keys
router.post("/api-keys", requireAuth, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { name } = z.object({ name: z.string().min(1).max(80) }).parse(req.body);
    const { nanoid } = await import("nanoid");
    const rawKey = `tc_${nanoid(40)}`;
    const keyHash = createHash("sha256").update(rawKey).digest("hex");
    const keyPrefix = rawKey.slice(0, 10);

    const apiKey = await prisma.apiKey.create({
      data: { name, keyHash, keyPrefix, userId: req.userId! },
      select: { id: true, name: true, keyPrefix: true, createdAt: true },
    });

    res.status(201).json({ apiKey, key: rawKey });
  } catch (err) {
    next(err);
  }
});

// GET /api/v1/auth/api-keys
router.get("/api-keys", requireAuth, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const keys = await prisma.apiKey.findMany({
      where: { userId: req.userId },
      select: { id: true, name: true, keyPrefix: true, lastUsedAt: true, expiresAt: true, createdAt: true },
      orderBy: { createdAt: "desc" },
    });
    res.json({ apiKeys: keys });
  } catch (err) {
    next(err);
  }
});

// DELETE /api/v1/auth/api-keys/:id
router.delete("/api-keys/:id", requireAuth, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    await prisma.apiKey.deleteMany({ where: { id: req.params.id, userId: req.userId } });
    res.json({ ok: true });
  } catch (err) {
    next(err);
  }
});

export default router;
