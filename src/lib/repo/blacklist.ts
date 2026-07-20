import { db } from "../db";
import { newId } from "../crypto";
import type { BlacklistEntry, BlacklistType } from "../types";

export function listBlacklistByApp(appId: string): BlacklistEntry[] {
  return db
    .prepare("SELECT * FROM blacklist WHERE app_id = ? ORDER BY created_at DESC")
    .all(appId) as BlacklistEntry[];
}

export function isBlacklisted(appId: string, type: BlacklistType, value: string | null): boolean {
  if (!value) return false;
  const row = db
    .prepare("SELECT 1 FROM blacklist WHERE app_id = ? AND type = ? AND value = ?")
    .get(appId, type, value);
  return !!row;
}

export function addBlacklist(input: {
  appId: string;
  type: BlacklistType;
  value: string;
  reason?: string | null;
}): BlacklistEntry {
  const id = newId("bl");
  const now = Date.now();
  db.prepare(
    `INSERT OR IGNORE INTO blacklist (id, app_id, type, value, reason, created_at)
     VALUES (?, ?, ?, ?, ?, ?)`,
  ).run(id, input.appId, input.type, input.value, input.reason ?? null, now);
  return (
    (db
      .prepare("SELECT * FROM blacklist WHERE app_id = ? AND type = ? AND value = ?")
      .get(input.appId, input.type, input.value) as BlacklistEntry) ?? null
  );
}

export function removeBlacklist(id: string): void {
  db.prepare("DELETE FROM blacklist WHERE id = ?").run(id);
}
