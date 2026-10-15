import { db } from "../db";
import { newId } from "../crypto";
import type { LogAction, LogEntry } from "../types";

export function addLog(input: {
  appId: string;
  action: LogAction;
  message: string;
  userId?: string | null;
  ip?: string | null;
  hwid?: string | null;
}): void {
  db.prepare(
    `INSERT INTO logs (id, app_id, user_id, action, message, ip, hwid, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
  ).run(
    newId("log"),
    input.appId,
    input.userId ?? null,
    input.action,
    input.message,
    input.ip ?? null,
    input.hwid ?? null,
    Date.now(),
  );
}

export function listLogsByApp(appId: string, limit = 200): LogEntry[] {
  return db
    .prepare("SELECT * FROM logs WHERE app_id = ? ORDER BY created_at DESC LIMIT ?")
    .all(appId, limit) as LogEntry[];
}

export function listRecentLogsBySeller(sellerId: string, limit = 15): LogEntry[] {
  return db
    .prepare(
      `SELECT l.* FROM logs l
       JOIN apps a ON a.id = l.app_id
       WHERE a.seller_id = ?
       ORDER BY l.created_at DESC
       LIMIT ?`,
    )
    .all(sellerId, limit) as LogEntry[];
}
