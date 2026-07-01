import { Request, Response, NextFunction } from "express";
import { verifyAccessToken } from "../lib/jwt";
import { prisma } from "../lib/prisma";

export interface AuthRequest extends Request {
  userId?: string;
  userEmail?: string;
}

export async function requireAuth(
  req: AuthRequest,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authHeader = req.headers.authorization;
    const cookieToken = req.cookies?.access_token as string | undefined;

    const raw = authHeader?.startsWith("Bearer ")
      ? authHeader.slice(7)
      : cookieToken;

    if (!raw) {
      res.status(401).json({ error: "Authentication required" });
      return;
    }

    // Check Bearer token — could be a JWT or an API key
    if (raw.startsWith("tc_")) {
      // API key path
      const prefix = raw.slice(0, 10);
      const { createHash } = await import("crypto");
      const keyHash = createHash("sha256").update(raw).digest("hex");
      const apiKey = await prisma.apiKey.findFirst({
        where: { keyHash, keyPrefix: prefix },
        include: { user: { select: { id: true, email: true } } },
      });
      if (!apiKey || (apiKey.expiresAt && apiKey.expiresAt < new Date())) {
        res.status(401).json({ error: "Invalid or expired API key" });
        return;
      }
      await prisma.apiKey.update({
        where: { id: apiKey.id },
        data: { lastUsedAt: new Date() },
      });
      req.userId = apiKey.user.id;
      req.userEmail = apiKey.user.email;
      next();
      return;
    }

    // JWT path
    const payload = verifyAccessToken(raw);
    req.userId = payload.sub;
    req.userEmail = payload.email;
    next();
  } catch {
    res.status(401).json({ error: "Invalid or expired token" });
  }
}

export async function requireOrgRole(
  roles: Array<"OWNER" | "ADMIN" | "MEMBER" | "VIEWER">
) {
  return async (
    req: AuthRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    const orgSlug = req.params.orgSlug;
    if (!orgSlug || !req.userId) {
      res.status(403).json({ error: "Forbidden" });
      return;
    }
    const member = await prisma.orgMember.findFirst({
      where: {
        org: { slug: orgSlug },
        userId: req.userId,
        role: { in: roles },
      },
    });
    if (!member) {
      res.status(403).json({ error: "Insufficient permissions for this organization" });
      return;
    }
    next();
  };
}
