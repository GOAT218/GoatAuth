import Database from "better-sqlite3";
import fs from "node:fs";
import path from "node:path";

// Force this module (and anything importing it) onto the Node.js runtime.
// better-sqlite3 is a native module and cannot run on the Edge runtime.

const DB_PATH = process.env.GOATAUTH_DB_PATH || "./data/goatauth.db";

function loadSchema(): string {
  return fs.readFileSync(path.resolve(process.cwd(), "src/lib/schema.sql"), "utf8");
}

function createConnection(): Database.Database {
  const abs = path.resolve(process.cwd(), DB_PATH);
  fs.mkdirSync(path.dirname(abs), { recursive: true });

  const conn = new Database(abs);
  conn.pragma("journal_mode = WAL");
  conn.pragma("foreign_keys = ON");
  conn.pragma("busy_timeout = 5000");
  conn.exec(loadSchema());
  return conn;
}

// Cache the connection across hot reloads in development to avoid exhausting
// file handles / re-running the schema on every request.
const globalForDb = globalThis as unknown as { __goatauthDb?: Database.Database };

export const db: Database.Database = globalForDb.__goatauthDb ?? createConnection();

if (process.env.NODE_ENV !== "production") {
  globalForDb.__goatauthDb = db;
}
