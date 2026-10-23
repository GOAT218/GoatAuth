// Delete the local SQLite database files. Usage: npm run db:reset
import fs from "node:fs";
import path from "node:path";

const DB_PATH = process.env.GOATAUTH_DB_PATH || "./data/goatauth.db";
const abs = path.resolve(process.cwd(), DB_PATH);

for (const suffix of ["", "-wal", "-shm"]) {
  const file = abs + suffix;
  if (fs.existsSync(file)) {
    fs.rmSync(file);
    console.log("removed", file);
  }
}
console.log("Database reset. Run `npm run seed` to re-seed demo data.");
