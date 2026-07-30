import { db } from "../db";
import { newId, generateLicenseString, type LicenseKeyFormat } from "../crypto";
import type { LicenseKey } from "../types";

export function getKeyById(id: string): LicenseKey | null {
  return (db.prepare("SELECT * FROM license_keys WHERE id = ?").get(id) as LicenseKey) ?? null;
}

export function getKeyByValue(appId: string, key: string): LicenseKey | null {
  return (
    (db
      .prepare("SELECT * FROM license_keys WHERE app_id = ? AND key = ?")
      .get(appId, key) as LicenseKey) ?? null
  );
}

export function listKeysByApp(appId: string, limit = 500): LicenseKey[] {
  return db
    .prepare("SELECT * FROM license_keys WHERE app_id = ? ORDER BY created_at DESC LIMIT ?")
    .all(appId, limit) as LicenseKey[];
}

export function countKeysByApp(appId: string): number {
  return (
    db.prepare("SELECT COUNT(*) AS c FROM license_keys WHERE app_id = ?").get(appId) as {
      c: number;
    }
  ).c;
}

export interface CreateKeysInput {
  appId: string;
  amount: number;
  durationDays: number;
  level: number;
  maxUses: number;
  note?: string;
  createdBy?: string;
  format?: LicenseKeyFormat;
}

/** Bulk-generate license keys in a single transaction. */
export function createKeys(input: CreateKeysInput): LicenseKey[] {
  const now = Date.now();
  const insert = db.prepare(
    `INSERT INTO license_keys
       (id, app_id, key, duration_days, level, max_uses, uses, status, note, created_by, created_at, used_at)
     VALUES (?, ?, ?, ?, ?, ?, 0, 'unused', ?, ?, ?, NULL)`,
  );

  const createBatch = db.transaction((count: number) => {
    const rows: LicenseKey[] = [];
    for (let i = 0; i < count; i++) {
      // Retry on the rare chance of a collision on the unique `key` column.
      let attempts = 0;
      while (true) {
        const keyStr = generateLicenseString(input.format);
        try {
          const id = newId("key");
          insert.run(
            id,
            input.appId,
            keyStr,
            input.durationDays,
            input.level,
            input.maxUses,
            input.note ?? null,
            input.createdBy ?? null,
            now,
          );
          rows.push(getKeyById(id)!);
          break;
        } catch (err) {
          attempts++;
          if (attempts > 5) throw err;
        }
      }
    }
    return rows;
  });

  return createBatch(input.amount);
}

export function deleteKey(id: string): void {
  db.prepare("DELETE FROM license_keys WHERE id = ?").run(id);
}

export function deleteUnusedKeys(appId: string): number {
  const info = db
    .prepare("DELETE FROM license_keys WHERE app_id = ? AND status = 'unused'")
    .run(appId);
  return info.changes;
}

export function setKeyStatus(id: string, status: LicenseKey["status"]): void {
  db.prepare("UPDATE license_keys SET status = ? WHERE id = ?").run(status, id);
}

/**
 * Atomically consume one use of a key if it is redeemable.
 * Returns the (updated) key when consumed, or null when it cannot be used.
 */
export function consumeKey(appId: string, key: string): LicenseKey | null {
  const consume = db.transaction((): LicenseKey | null => {
    const row = getKeyByValue(appId, key);
    if (!row) return null;
    if (row.status === "banned") return null;
    if (row.uses >= row.max_uses) return null;

    const uses = row.uses + 1;
    const status = uses >= row.max_uses ? "used" : "unused";
    db.prepare(
      "UPDATE license_keys SET uses = ?, status = ?, used_at = COALESCE(used_at, ?) WHERE id = ?",
    ).run(uses, status, Date.now(), row.id);
    return getKeyById(row.id);
  });
  return consume();
}
