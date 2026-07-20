import { SignJWT, jwtVerify } from "jose";

// Edge-safe seller session token helpers. This module MUST NOT import the
// database or `next/headers` so it can be used from Edge middleware.

export const SELLER_COOKIE = "goatauth_session";
export const SELLER_MAX_AGE_SECONDS = 60 * 60 * 24 * 7; // 7 days

function secretKey(): Uint8Array {
  const secret =
    process.env.GOATAUTH_SESSION_SECRET ||
    "goatauth-dev-session-secret-change-me-in-production-please";
  return new TextEncoder().encode(secret);
}

export interface SellerTokenPayload {
  sub: string; // seller id
  username: string;
}

export async function signSellerToken(payload: SellerTokenPayload): Promise<string> {
  return new SignJWT({ username: payload.username })
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(payload.sub)
    .setIssuedAt()
    .setExpirationTime(`${SELLER_MAX_AGE_SECONDS}s`)
    .sign(secretKey());
}

export async function verifySellerToken(token: string): Promise<SellerTokenPayload | null> {
  try {
    const { payload } = await jwtVerify(token, secretKey());
    if (!payload.sub) return null;
    return { sub: payload.sub, username: String(payload.username ?? "") };
  } catch {
    return null;
  }
}
