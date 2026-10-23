import { db } from "../db";
import { newId } from "../crypto";
import type { AppVariable } from "../types";

export function listVariablesByApp(appId: string): AppVariable[] {
  return db
    .prepare("SELECT * FROM app_variables WHERE app_id = ? ORDER BY name ASC")
    .all(appId) as AppVariable[];
}

export function getVariable(appId: string, name: string): AppVariable | null {
  return (
    (db
      .prepare("SELECT * FROM app_variables WHERE app_id = ? AND name = ?")
      .get(appId, name) as AppVariable) ?? null
  );
}

export function upsertVariable(input: {
  appId: string;
  name: string;
  value: string;
  secret: boolean;
}): AppVariable {
  const existing = getVariable(input.appId, input.name);
  if (existing) {
    db.prepare("UPDATE app_variables SET value = ?, secret = ? WHERE id = ?").run(
      input.value,
      input.secret ? 1 : 0,
      existing.id,
    );
    return getVariable(input.appId, input.name)!;
  }
  const id = newId("var");
  db.prepare(
    `INSERT INTO app_variables (id, app_id, name, value, secret, created_at)
     VALUES (?, ?, ?, ?, ?, ?)`,
  ).run(id, input.appId, input.name, input.value, input.secret ? 1 : 0, Date.now());
  return getVariable(input.appId, input.name)!;
}

export function deleteVariable(id: string): void {
  db.prepare("DELETE FROM app_variables WHERE id = ?").run(id);
}
