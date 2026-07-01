import jwt from "jsonwebtoken";
import { config } from "../config";

export interface AccessTokenPayload {
  sub: string;   // userId
  email: string;
}

export interface RefreshTokenPayload {
  sub: string;   // userId
  jti: string;   // token id (matches RefreshToken.id)
}

const ACCESS_EXPIRY = "15m";
const REFRESH_EXPIRY = "7d";
const REFRESH_EXPIRY_MS = 7 * 24 * 60 * 60 * 1000;

export function signAccessToken(payload: AccessTokenPayload): string {
  return jwt.sign(payload, config.JWT_ACCESS_SECRET, { expiresIn: ACCESS_EXPIRY });
}

export function signRefreshToken(payload: RefreshTokenPayload): string {
  return jwt.sign(payload, config.JWT_REFRESH_SECRET, { expiresIn: REFRESH_EXPIRY });
}

export function verifyAccessToken(token: string): AccessTokenPayload {
  return jwt.verify(token, config.JWT_ACCESS_SECRET) as AccessTokenPayload;
}

export function verifyRefreshToken(token: string): RefreshTokenPayload {
  return jwt.verify(token, config.JWT_REFRESH_SECRET) as RefreshTokenPayload;
}

export function refreshTokenExpiryDate(): Date {
  return new Date(Date.now() + REFRESH_EXPIRY_MS);
}
