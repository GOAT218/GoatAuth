import { db } from "../db";

export interface SellerStats {
  apps: number;
  users: number;
  keys: number;
  unusedKeys: number;
  activeSessions: number;
  bannedUsers: number;
}

export function statsForSeller(sellerId: string): SellerStats {
  const now = Date.now();
  const appIdsRows = db
    .prepare("SELECT id FROM apps WHERE seller_id = ?")
    .all(sellerId) as { id: string }[];
  const appIds = appIdsRows.map((r) => r.id);

  if (appIds.length === 0) {
    return { apps: 0, users: 0, keys: 0, unusedKeys: 0, activeSessions: 0, bannedUsers: 0 };
  }

  const placeholders = appIds.map(() => "?").join(",");
  const count = (sql: string, ...extra: unknown[]): number =>
    (db.prepare(sql).get(...appIds, ...extra) as { c: number }).c;

  return {
    apps: appIds.length,
    users: count(`SELECT COUNT(*) AS c FROM app_users WHERE app_id IN (${placeholders})`),
    keys: count(`SELECT COUNT(*) AS c FROM license_keys WHERE app_id IN (${placeholders})`),
    unusedKeys: count(
      `SELECT COUNT(*) AS c FROM license_keys WHERE app_id IN (${placeholders}) AND status = 'unused'`,
    ),
    activeSessions: count(
      `SELECT COUNT(*) AS c FROM app_sessions WHERE app_id IN (${placeholders}) AND valid = 1 AND expires_at > ?`,
      now,
    ),
    bannedUsers: count(
      `SELECT COUNT(*) AS c FROM app_users WHERE app_id IN (${placeholders}) AND banned = 1`,
    ),
  };
}

export interface AppStats {
  users: number;
  keys: number;
  unusedKeys: number;
  activeSessions: number;
  bannedUsers: number;
}

export function statsForApp(appId: string): AppStats {
  const now = Date.now();
  const get = (sql: string, ...args: unknown[]): number =>
    (db.prepare(sql).get(appId, ...args) as { c: number }).c;
  return {
    users: get("SELECT COUNT(*) AS c FROM app_users WHERE app_id = ?"),
    keys: get("SELECT COUNT(*) AS c FROM license_keys WHERE app_id = ?"),
    unusedKeys: get("SELECT COUNT(*) AS c FROM license_keys WHERE app_id = ? AND status = 'unused'"),
    activeSessions: get(
      "SELECT COUNT(*) AS c FROM app_sessions WHERE app_id = ? AND valid = 1 AND expires_at > ?",
      now,
    ),
    bannedUsers: get("SELECT COUNT(*) AS c FROM app_users WHERE app_id = ? AND banned = 1"),
  };
}
