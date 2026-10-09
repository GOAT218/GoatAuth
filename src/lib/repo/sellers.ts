import { db } from "../db";
import { newId, hashPassword } from "../crypto";
import type { Seller, SellerRole } from "../types";

export function getSellerById(id: string): Seller | null {
  return (db.prepare("SELECT * FROM sellers WHERE id = ?").get(id) as Seller) ?? null;
}

export function getSellerByUsername(username: string): Seller | null {
  return (
    (db.prepare("SELECT * FROM sellers WHERE username = ? COLLATE NOCASE").get(username) as Seller) ??
    null
  );
}

export function getSellerByEmail(email: string): Seller | null {
  return (
    (db.prepare("SELECT * FROM sellers WHERE email = ? COLLATE NOCASE").get(email) as Seller) ?? null
  );
}

export function countSellers(): number {
  return (db.prepare("SELECT COUNT(*) AS c FROM sellers").get() as { c: number }).c;
}

export async function createSeller(input: {
  username: string;
  email: string;
  password: string;
  role?: SellerRole;
}): Promise<Seller> {
  const id = newId("slr");
  const now = Date.now();
  const password_hash = await hashPassword(input.password);
  // The very first seller to register becomes the owner.
  const role: SellerRole = input.role ?? (countSellers() === 0 ? "owner" : "seller");
  db.prepare(
    `INSERT INTO sellers (id, username, email, password_hash, role, created_at, last_login_at)
     VALUES (?, ?, ?, ?, ?, ?, NULL)`,
  ).run(id, input.username, input.email.toLowerCase(), password_hash, role, now);
  return getSellerById(id)!;
}

export function touchSellerLogin(id: string): void {
  db.prepare("UPDATE sellers SET last_login_at = ? WHERE id = ?").run(Date.now(), id);
}
