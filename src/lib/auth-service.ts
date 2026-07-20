// Core business logic for the client authentication API (/api/v1/*).
// Route handlers stay thin: parse input, call one of these functions, return.

import { ApiError } from "./api";
import { DUMMY_PASSWORD_HASH, hashPassword, safeEqual, verifyPassword } from "./crypto";
import { getAppById } from "./repo/apps";
import { addLog } from "./repo/logs";
import { addBlacklist, isBlacklisted } from "./repo/blacklist";
import { consumeKey, getKeyByValue } from "./repo/keys";
import { getVariable } from "./repo/variables";
import {
  createSession,
  getSessionById,
  isSessionActive,
  killSession,
} from "./repo/sessions";
import {
  createUser,
  extendUserSubscription,
  getUserById,
  getUserByUsername,
  isExpired,
  setUserHwid,
  touchUserLogin,
} from "./repo/users";
import { signAppToken, verifyAppToken } from "./app-session";
import type { App, AppUser } from "./types";

export interface ClientCtx {
  ip: string;
}

// --- App authentication -----------------------------------------------------

export function authApp(appId: string, secret: string): App {
  const app = getAppById(appId);
  if (!app) throw new ApiError("Application not found", 404, "app_not_found");
  if (!safeEqual(app.secret, secret)) {
    throw new ApiError("Invalid application secret", 403, "bad_secret");
  }
  if (app.status !== "active") {
    throw new ApiError("This application is currently paused", 403, "app_paused");
  }
  return app;
}

export interface VersionInfo {
  outdated: boolean;
  latest: string;
  download_url: string | null;
}

export function versionInfo(app: App, clientVersion?: string): VersionInfo {
  const outdated = !!clientVersion && clientVersion !== app.version;
  return { outdated, latest: app.version, download_url: outdated ? app.download_url : null };
}

export function assertNotBlacklisted(app: App, ip: string | null, hwid?: string | null): void {
  if (isBlacklisted(app.id, "ip", ip)) {
    throw new ApiError("Access denied", 403, "blacklisted");
  }
  if (hwid && isBlacklisted(app.id, "hwid", hwid)) {
    throw new ApiError("Access denied", 403, "blacklisted");
  }
}

// --- Subscription / user payload --------------------------------------------

export interface UserInfoDto {
  username: string;
  level: number;
  expires_at: number | null;
  expires_iso: string | null;
  seconds_remaining: number | null;
  lifetime: boolean;
  created_at: number;
}

export function userInfo(user: AppUser): UserInfoDto {
  const lifetime = user.expires_at === null;
  return {
    username: user.username,
    level: user.level,
    expires_at: user.expires_at,
    expires_iso: user.expires_at ? new Date(user.expires_at).toISOString() : null,
    seconds_remaining: lifetime ? null : Math.max(0, Math.floor((user.expires_at! - Date.now()) / 1000)),
    lifetime,
    created_at: user.created_at,
  };
}

// --- HWID enforcement -------------------------------------------------------

/**
 * Enforce the app's HWID lock for a user.
 * - lock off: no-op.
 * - user has no HWID yet: bind the supplied one.
 * - user HWID matches: ok.
 * - mismatch: reject (client must contact the seller for a reset).
 */
function enforceHwid(app: App, user: AppUser, hwid: string | null | undefined): void {
  if (!app.hwid_lock) return;
  if (!hwid) throw new ApiError("HWID is required for this application", 400, "hwid_required");
  if (!user.hwid) {
    setUserHwid(user.id, hwid);
    user.hwid = hwid;
    return;
  }
  if (!safeEqual(user.hwid, hwid)) {
    throw new ApiError("Hardware ID mismatch — reset required", 403, "hwid_mismatch");
  }
}

function assertUsable(user: AppUser): void {
  if (user.banned) {
    throw new ApiError(user.ban_reason ? `Banned: ${user.ban_reason}` : "This account is banned", 403, "banned");
  }
  if (isExpired(user)) {
    throw new ApiError("Your subscription has expired", 403, "expired");
  }
}

// --- Flows ------------------------------------------------------------------

export interface SessionResult {
  token: string;
  session_id: string;
  user?: UserInfoDto;
  version: VersionInfo;
}

async function issueSession(app: App, user: AppUser | null, ctx: ClientCtx, hwid: string | null) {
  const session = createSession({
    appId: app.id,
    userId: user?.id ?? null,
    hwid,
    ip: ctx.ip,
  });
  const token = await signAppToken({
    sid: session.id,
    app: app.id,
    uid: user?.id ?? null,
    hwid,
  });
  return { session, token };
}

export function initFlow(app: App, ctx: ClientCtx, clientVersion?: string) {
  assertNotBlacklisted(app, ctx.ip);
  addLog({ appId: app.id, action: "init", message: `init from ${ctx.ip}`, ip: ctx.ip });
  return {
    app: { name: app.name, version: app.version },
    version: versionInfo(app, clientVersion),
  };
}

export async function registerFlow(
  app: App,
  input: { username: string; password: string; key: string; email?: string; hwid?: string },
  ctx: ClientCtx,
): Promise<SessionResult> {
  assertNotBlacklisted(app, ctx.ip, input.hwid);

  if (getUserByUsername(app.id, input.username)) {
    throw new ApiError("Username is already taken", 409, "username_taken");
  }
  if (app.hwid_lock && !input.hwid) {
    throw new ApiError("HWID is required for this application", 400, "hwid_required");
  }

  const key = consumeKey(app.id, input.key);
  if (!key) throw new ApiError("Invalid or already-used license key", 403, "bad_key");

  const expiresAt = key.duration_days === 0 ? null : Date.now() + key.duration_days * 86_400_000;
  const user = createUser({
    appId: app.id,
    username: input.username,
    passwordHash: await hashPassword(input.password),
    email: input.email ?? null,
    hwid: input.hwid ?? null,
    ip: ctx.ip,
    level: key.level,
    expiresAt,
  });

  addLog({
    appId: app.id,
    userId: user.id,
    action: "register",
    message: `registered '${input.username}' with key ${input.key}`,
    ip: ctx.ip,
    hwid: input.hwid ?? null,
  });

  const { session, token } = await issueSession(app, user, ctx, input.hwid ?? null);
  return { token, session_id: session.id, user: userInfo(user), version: versionInfo(app) };
}

export async function loginFlow(
  app: App,
  input: { username: string; password: string; hwid?: string },
  ctx: ClientCtx,
): Promise<SessionResult> {
  assertNotBlacklisted(app, ctx.ip, input.hwid);

  const user = getUserByUsername(app.id, input.username);
  if (!user || !user.password_hash) {
    // Run a dummy comparison so a missing account takes the same time as a
    // real password check (prevents username-existence timing enumeration).
    await verifyPassword(input.password, DUMMY_PASSWORD_HASH);
    throw new ApiError("Invalid username or password", 401, "bad_credentials");
  }
  const okPassword = await verifyPassword(input.password, user.password_hash);
  if (!okPassword) {
    addLog({
      appId: app.id,
      userId: user.id,
      action: "login",
      message: `failed login for '${input.username}'`,
      ip: ctx.ip,
      hwid: input.hwid ?? null,
    });
    throw new ApiError("Invalid username or password", 401, "bad_credentials");
  }

  assertUsable(user);
  enforceHwid(app, user, input.hwid);
  touchUserLogin(user.id, ctx.ip);

  addLog({
    appId: app.id,
    userId: user.id,
    action: "login",
    message: `login '${input.username}'`,
    ip: ctx.ip,
    hwid: input.hwid ?? null,
  });

  const { session, token } = await issueSession(app, user, ctx, input.hwid ?? null);
  return { token, session_id: session.id, user: userInfo(user), version: versionInfo(app) };
}

/**
 * License-only authentication: the license key itself is the credential.
 * On first use the key is consumed and an implicit user (username = key) is
 * created, so HWID locking and expiry still apply.
 */
export async function licenseFlow(
  app: App,
  input: { key: string; hwid?: string },
  ctx: ClientCtx,
): Promise<SessionResult> {
  assertNotBlacklisted(app, ctx.ip, input.hwid);

  let user = getUserByUsername(app.id, input.key);

  if (!user) {
    const key = getKeyByValue(app.id, input.key);
    if (!key) throw new ApiError("Invalid license key", 403, "bad_key");
    if (app.hwid_lock && !input.hwid) {
      throw new ApiError("HWID is required for this application", 400, "hwid_required");
    }
    const consumed = consumeKey(app.id, input.key);
    if (!consumed) throw new ApiError("License key has already been used up", 403, "key_exhausted");

    const expiresAt =
      consumed.duration_days === 0 ? null : Date.now() + consumed.duration_days * 86_400_000;
    user = createUser({
      appId: app.id,
      username: input.key,
      passwordHash: null,
      email: null,
      hwid: input.hwid ?? null,
      ip: ctx.ip,
      level: consumed.level,
      expiresAt,
    });
    addLog({
      appId: app.id,
      userId: user.id,
      action: "license",
      message: `license activated ${input.key}`,
      ip: ctx.ip,
      hwid: input.hwid ?? null,
    });
  } else {
    assertUsable(user);
    enforceHwid(app, user, input.hwid);
    touchUserLogin(user.id, ctx.ip);
    addLog({
      appId: app.id,
      userId: user.id,
      action: "license",
      message: `license login ${input.key}`,
      ip: ctx.ip,
      hwid: input.hwid ?? null,
    });
  }

  const { session, token } = await issueSession(app, user, ctx, input.hwid ?? null);
  return { token, session_id: session.id, user: userInfo(user), version: versionInfo(app) };
}

export async function verifyFlow(
  app: App,
  input: { token: string; hwid?: string },
  ctx: ClientCtx,
): Promise<SessionResult> {
  const payload = await verifyAppToken(input.token);
  if (!payload || payload.app !== app.id) {
    throw new ApiError("Invalid session token", 401, "bad_token");
  }
  const session = getSessionById(payload.sid);
  // Also confirm the server-side session is bound to this app, not just the JWT.
  if (!isSessionActive(session) || session!.app_id !== app.id) {
    throw new ApiError("Session expired or revoked", 401, "session_invalid");
  }

  if (!payload.uid) {
    // Anonymous (init) session — valid but no user attached.
    return { token: input.token, session_id: payload.sid, version: versionInfo(app) };
  }

  const user = getUserById(payload.uid);
  if (!user || user.app_id !== app.id) {
    throw new ApiError("Account no longer exists", 401, "no_user");
  }

  assertUsable(user);
  // Enforce the HWID lock on revalidation: when the lock is on and the user is
  // bound to a machine, the client MUST present a matching HWID. Omitting it is
  // rejected (otherwise a stolen token could be replayed from another machine).
  if (app.hwid_lock && user.hwid) {
    if (!input.hwid || !safeEqual(user.hwid, input.hwid)) {
      killSession(payload.sid);
      throw new ApiError("Hardware ID mismatch — reset required", 403, "hwid_mismatch");
    }
  }

  return { token: input.token, session_id: payload.sid, user: userInfo(user), version: versionInfo(app) };
}

export function upgradeFlow(app: App, input: { username: string; key: string }, ctx: ClientCtx) {
  const user = getUserByUsername(app.id, input.username);
  if (!user) throw new ApiError("User not found", 404, "no_user");

  const consumed = consumeKey(app.id, input.key);
  if (!consumed) throw new ApiError("Invalid or already-used license key", 403, "bad_key");

  extendUserSubscription(user.id, consumed.duration_days, consumed.level);
  addLog({
    appId: app.id,
    userId: user.id,
    action: "upgrade",
    message: `upgraded '${input.username}' with key ${input.key}`,
    ip: ctx.ip,
  });
  const updated = getUserById(user.id)!;
  return { user: userInfo(updated) };
}

export async function readVariable(
  app: App,
  input: { name: string; token?: string },
): Promise<string> {
  const v = getVariable(app.id, input.name);
  if (!v) throw new ApiError("Variable not found", 404, "no_var");
  if (v.secret) {
    const payload = input.token ? await verifyAppToken(input.token) : null;
    const session = payload ? getSessionById(payload.sid) : null;
    if (
      !payload ||
      payload.app !== app.id ||
      !isSessionActive(session) ||
      session!.app_id !== app.id ||
      !payload.uid
    ) {
      throw new ApiError("A valid authenticated session is required", 401, "auth_required");
    }
    // Re-check the account is still allowed — sessions outlive ban/expiry.
    const user = getUserById(payload.uid);
    if (!user || user.app_id !== app.id) {
      throw new ApiError("A valid authenticated session is required", 401, "auth_required");
    }
    assertUsable(user); // throws for banned or expired users
  }
  return v.value;
}

export function logMessage(app: App, message: string, ctx: ClientCtx, username?: string): void {
  const user = username ? getUserByUsername(app.id, username) : null;
  addLog({ appId: app.id, userId: user?.id ?? null, action: "log", message, ip: ctx.ip });
}

// Re-exported for admin/ban flows that also want to blacklist.
export { addBlacklist };
