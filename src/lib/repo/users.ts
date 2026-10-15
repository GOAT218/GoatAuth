import { db } from "../db";
import { newId } from "../crypto";
import type { AppUser } from "../types";

export function getUserById(id: string): AppUser | null {
  return (db.prepare("SELECT * FROM app_users WHERE id = ?").get(id) as AppUser) ?? null;
}

export function getUserByUsername(appId: string, username: string): AppUser | null {
  return (
    (db
      .prepare("SELECT * FROM app_users WHERE app_id = ? AND username = ? COLLATE NOCASE")
      .get(appId, username) as AppUser) ?? null
  );
}

export function listUsersByApp(appId: string, limit = 500): AppUser[] {
  return db
    .prepare("SELECT * FROM app_users WHERE app_id = ? ORDER BY created_at DESC LIMIT ?")
    .all(appId, limit) as AppUser[];
}

export function countUsersByApp(appId: string): number {
  return (
    db.prepare("SELECT COUNT(*) AS c FROM app_users WHERE app_id = ?").get(appId) as { c: number }
  ).c;
}

export interface CreateUserInput {
  appId: string;
  username: string;
  passwordHash?: string | null;
  email?: string | null;
  hwid?: string | null;
  ip?: string | null;
  level: number;
  expiresAt: number | null;
}

export function createUser(input: CreateUserInput): AppUser {
  const id = newId("usr");
  const now = Date.now();
  db.prepare(
    `INSERT INTO app_users
       (id, app_id, username, password_hash, email, hwid, ip, level, expires_at, banned, ban_reason, created_at, last_login_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0, NULL, ?, NULL)`,
  ).run(
    id,
    input.appId,
    input.username,
    input.passwordHash ?? null,
    input.email ?? null,
    input.hwid ?? null,
    input.ip ?? null,
    input.level,
    input.expiresAt,
    now,
  );
  return getUserById(id)!;
}

export function setUserHwid(id: string, hwid: string | null): void {
  db.prepare("UPDATE app_users SET hwid = ? WHERE id = ?").run(hwid, id);
}

export function touchUserLogin(id: string, ip: string | null): void {
  db.prepare("UPDATE app_users SET last_login_at = ?, ip = ? WHERE id = ?").run(Date.now(), ip, id);
}

export function setUserBan(id: string, banned: boolean, reason?: string | null): void {
  db.prepare("UPDATE app_users SET banned = ?, ban_reason = ? WHERE id = ?").run(
    banned ? 1 : 0,
    banned ? reason ?? null : null,
    id,
  );
}

export function setUserSubscription(id: string, level: number, expiresAt: number | null): void {
  db.prepare("UPDATE app_users SET level = ?, expires_at = ? WHERE id = ?").run(level, expiresAt, id);
}

/** Extend (or set) a user's subscription by a number of days from the later of now/current expiry. */
export function extendUserSubscription(id: string, days: number, level?: number): void {
  const user = getUserById(id);
  if (!user) return;
  const base = Math.max(Date.now(), user.expires_at ?? 0);
  const expiresAt = days === 0 ? null : base + days * 86_400_000;
  const lvl = level ?? user.level;
  db.prepare("UPDATE app_users SET expires_at = ?, level = ? WHERE id = ?").run(expiresAt, lvl, id);
}

export function updateUserExpiry(id: string, expiresAt: number | null): void {
  db.prepare("UPDATE app_users SET expires_at = ? WHERE id = ?").run(expiresAt, id);
}

export function deleteUser(id: string): void {
  db.prepare("DELETE FROM app_users WHERE id = ?").run(id);
}

export function isExpired(user: AppUser): boolean {
  if (user.expires_at === null) return false; // lifetime
  return user.expires_at <= Date.now();
}
