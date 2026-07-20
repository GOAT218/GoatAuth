import { db } from "../db";
import { newId } from "../crypto";
import type { AppSession } from "../types";
import { appSessionLifetimeSeconds } from "../app-session";

export function getSessionById(id: string): AppSession | null {
  return (db.prepare("SELECT * FROM app_sessions WHERE id = ?").get(id) as AppSession) ?? null;
}

export function createSession(input: {
  appId: string;
  userId: string | null;
  hwid: string | null;
  ip: string | null;
}): AppSession {
  const id = newId("sess");
  const now = Date.now();
  const expiresAt = now + appSessionLifetimeSeconds() * 1000;
  db.prepare(
    `INSERT INTO app_sessions (id, app_id, user_id, hwid, ip, valid, created_at, expires_at)
     VALUES (?, ?, ?, ?, ?, 1, ?, ?)`,
  ).run(id, input.appId, input.userId, input.hwid, input.ip, now, expiresAt);
  return getSessionById(id)!;
}

/** A session is usable when it exists, is flagged valid, and has not expired. */
export function isSessionActive(session: AppSession | null): boolean {
  if (!session) return false;
  if (!session.valid) return false;
  return session.expires_at > Date.now();
}

export function killSession(id: string): void {
  db.prepare("UPDATE app_sessions SET valid = 0 WHERE id = ?").run(id);
}

export function listSessionsByApp(appId: string, limit = 200): AppSession[] {
  return db
    .prepare(
      "SELECT * FROM app_sessions WHERE app_id = ? ORDER BY created_at DESC LIMIT ?",
    )
    .all(appId, limit) as AppSession[];
}

export function countActiveSessionsByApp(appId: string): number {
  return (
    db
      .prepare(
        "SELECT COUNT(*) AS c FROM app_sessions WHERE app_id = ? AND valid = 1 AND expires_at > ?",
      )
      .get(appId, Date.now()) as { c: number }
  ).c;
}

/** Delete expired/invalid sessions; returns rows removed. */
export function pruneSessions(appId: string): number {
  return db
    .prepare("DELETE FROM app_sessions WHERE app_id = ? AND (valid = 0 OR expires_at <= ?)")
    .run(appId, Date.now()).changes;
}
