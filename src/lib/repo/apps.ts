import { db } from "../db";
import { newAppId, newAppSecret } from "../crypto";
import type { App } from "../types";

export function getAppById(id: string): App | null {
  return (db.prepare("SELECT * FROM apps WHERE id = ?").get(id) as App) ?? null;
}

/** Fetch an app that belongs to a specific seller (ownership check). */
export function getOwnedApp(appId: string, sellerId: string): App | null {
  return (
    (db.prepare("SELECT * FROM apps WHERE id = ? AND seller_id = ?").get(appId, sellerId) as App) ??
    null
  );
}

export function listAppsBySeller(sellerId: string): App[] {
  return db
    .prepare("SELECT * FROM apps WHERE seller_id = ? ORDER BY created_at DESC")
    .all(sellerId) as App[];
}

export function createApp(input: { sellerId: string; name: string; version?: string }): App {
  const id = newAppId();
  const now = Date.now();
  db.prepare(
    `INSERT INTO apps (id, seller_id, name, secret, version, status, hwid_lock, hwid_reset_cost, download_url, created_at)
     VALUES (?, ?, ?, ?, ?, 'active', 1, 0, NULL, ?)`,
  ).run(id, input.sellerId, input.name, newAppSecret(), input.version || "1.0", now);
  return getAppById(id)!;
}

export function updateApp(
  appId: string,
  fields: Partial<Pick<App, "name" | "version" | "status" | "hwid_lock" | "download_url">>,
): void {
  const sets: string[] = [];
  const values: unknown[] = [];
  for (const [key, value] of Object.entries(fields)) {
    if (value === undefined) continue;
    sets.push(`${key} = ?`);
    values.push(value);
  }
  if (sets.length === 0) return;
  values.push(appId);
  db.prepare(`UPDATE apps SET ${sets.join(", ")} WHERE id = ?`).run(...values);
}

/** Rotate the client-embedded secret; returns the new secret. */
export function rotateAppSecret(appId: string): string {
  const secret = newAppSecret();
  db.prepare("UPDATE apps SET secret = ? WHERE id = ?").run(secret, appId);
  return secret;
}

export function deleteApp(appId: string): void {
  db.prepare("DELETE FROM apps WHERE id = ?").run(appId);
}
