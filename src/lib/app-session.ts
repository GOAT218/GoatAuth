import { SignJWT, jwtVerify } from "jose";

// Session tokens issued by the client authentication API (/api/v1/*).
// The token is opaque to the client; it carries the session id which is also
// tracked server-side (in `app_sessions`) so it can be revoked.

const APP_SESSION_SECONDS = 60 * 60 * 24; // 24h default session lifetime

function secretKey(): Uint8Array {
  const secret =
    process.env.GOATAUTH_APP_TOKEN_SECRET ||
    "goatauth-dev-app-token-secret-change-me-in-production-please";
  return new TextEncoder().encode(secret);
}

export interface AppTokenPayload {
  sid: string; // app_sessions.id
  app: string; // app id
  uid: string | null; // app_users.id (null for license-only sessions)
  hwid: string | null;
}

export function appSessionLifetimeSeconds(): number {
  return APP_SESSION_SECONDS;
}

export async function signAppToken(payload: AppTokenPayload): Promise<string> {
  return new SignJWT({ app: payload.app, uid: payload.uid, hwid: payload.hwid })
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(payload.sid)
    .setIssuedAt()
    .setExpirationTime(`${APP_SESSION_SECONDS}s`)
    .sign(secretKey());
}

export async function verifyAppToken(token: string): Promise<AppTokenPayload | null> {
  try {
    const { payload } = await jwtVerify(token, secretKey());
    if (!payload.sub) return null;
    return {
      sid: payload.sub,
      app: String(payload.app ?? ""),
      uid: (payload.uid as string | null) ?? null,
      hwid: (payload.hwid as string | null) ?? null,
    };
  } catch {
    return null;
  }
}
