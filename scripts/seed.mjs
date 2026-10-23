// Seed the GoatAuth database with a demo seller, application, and license keys.
// Usage: npm run seed
import Database from "better-sqlite3";
import bcrypt from "bcryptjs";
import { customAlphabet, nanoid } from "nanoid";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const DB_PATH = process.env.GOATAUTH_DB_PATH || "./data/goatauth.db";
const abs = path.resolve(process.cwd(), DB_PATH);
fs.mkdirSync(path.dirname(abs), { recursive: true });

const db = new Database(abs);
db.pragma("journal_mode = WAL");
db.pragma("foreign_keys = ON");
db.exec(fs.readFileSync(path.resolve(process.cwd(), "src/lib/schema.sql"), "utf8"));

const keyAlphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const seg = customAlphabet(keyAlphabet, 5);
const appIdGen = customAlphabet("abcdefghijklmnopqrstuvwxyz0123456789", 12);
const now = Date.now();

const DEMO_USER = "demo";
const DEMO_PASS = "demo1234";

// Reset any previous demo data so the seed is idempotent.
const existing = db.prepare("SELECT id FROM sellers WHERE username = ?").get(DEMO_USER);
if (existing) {
  db.prepare("DELETE FROM sellers WHERE id = ?").run(existing.id); // cascades
  console.log("• Removed previous demo seller (cascade).");
}

const sellerId = "slr_" + nanoid(16);
db.prepare(
  `INSERT INTO sellers (id, username, email, password_hash, role, created_at, last_login_at)
   VALUES (?, ?, ?, ?, 'owner', ?, NULL)`,
).run(sellerId, DEMO_USER, "demo@goatauth.local", bcrypt.hashSync(DEMO_PASS, 12), now);

const appId = appIdGen();
const appSecret = crypto.randomBytes(32).toString("hex");
db.prepare(
  `INSERT INTO apps (id, seller_id, name, secret, version, status, hwid_lock, hwid_reset_cost, download_url, created_at)
   VALUES (?, ?, ?, ?, '1.0', 'active', 1, 0, ?, ?)`,
).run(appId, sellerId, "Demo Loader", appSecret, "https://example.com/download", now);

const insertKey = db.prepare(
  `INSERT INTO license_keys (id, app_id, key, duration_days, level, max_uses, uses, status, note, created_by, created_at, used_at)
   VALUES (?, ?, ?, ?, ?, ?, 0, 'unused', ?, ?, ?, NULL)`,
);
const durations = [1, 7, 30, 0];
const sampleKeys = [];
for (let i = 0; i < 5; i++) {
  const key = "GOAT-" + [seg(), seg(), seg(), seg()].join("-");
  const dur = durations[i % durations.length];
  insertKey.run("key_" + nanoid(16), appId, key, dur, 1, 1, `seed key ${i + 1}`, sellerId, now);
  sampleKeys.push({ key, dur });
}

console.log("\n✔ GoatAuth demo data seeded\n");
console.log("  Dashboard login");
console.log("    username: " + DEMO_USER);
console.log("    password: " + DEMO_PASS);
console.log("\n  Application");
console.log("    name:     Demo Loader");
console.log("    app_id:   " + appId);
console.log("    secret:   " + appSecret);
console.log("\n  License keys (duration in days, 0 = lifetime):");
for (const k of sampleKeys) console.log(`    ${k.key}  (${k.dur === 0 ? "lifetime" : k.dur + "d"})`);
console.log("\nStart the app with `npm run dev` and sign in at http://localhost:3000/login\n");

db.close();
