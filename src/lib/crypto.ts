import bcrypt from "bcryptjs";
import { customAlphabet, nanoid } from "nanoid";
import crypto from "node:crypto";

// --- Password hashing -------------------------------------------------------

const BCRYPT_ROUNDS = 12;

export async function hashPassword(plain: string): Promise<string> {
  return bcrypt.hash(plain, BCRYPT_ROUNDS);
}

export async function verifyPassword(plain: string, hash: string): Promise<boolean> {
  if (!hash) return false;
  try {
    return await bcrypt.compare(plain, hash);
  } catch {
    return false;
  }
}

// --- Identifiers ------------------------------------------------------------

/** URL-safe unique id for internal records. */
export function newId(prefix = ""): string {
  return prefix ? `${prefix}_${nanoid(16)}` : nanoid(21);
}

// Public application id: short, unambiguous, lowercase.
const appIdAlphabet = "abcdefghijklmnopqrstuvwxyz0123456789";
const appIdGen = customAlphabet(appIdAlphabet, 12);
export function newAppId(): string {
  return appIdGen();
}

/** Long random application secret embedded in client software. */
export function newAppSecret(): string {
  return crypto.randomBytes(32).toString("hex");
}

// --- License keys -----------------------------------------------------------

const keyAlphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // no ambiguous chars
const keyGen = customAlphabet(keyAlphabet, 5);

export interface LicenseKeyFormat {
  mask?: string; // e.g. "XXXXX-XXXXX-XXXXX-XXXXX"; 'X' becomes a random char
  prefix?: string; // prepended, e.g. "GOAT-"
  segments?: number; // used when no mask; number of 5-char groups
}

/** Generate a single formatted license string. */
export function generateLicenseString(fmt: LicenseKeyFormat = {}): string {
  const prefix = fmt.prefix ?? "";
  if (fmt.mask) {
    const chars = fmt.mask.split("").map((c) => {
      if (c === "X" || c === "x") {
        return keyAlphabet[crypto.randomInt(keyAlphabet.length)];
      }
      return c;
    });
    return prefix + chars.join("");
  }
  const segments = Math.min(Math.max(fmt.segments ?? 4, 1), 8);
  const groups: string[] = [];
  for (let i = 0; i < segments; i++) groups.push(keyGen());
  return prefix + groups.join("-");
}

// --- HWID / hashing helpers -------------------------------------------------

/** Deterministic, non-reversible hash for values we want to compare but not store raw. */
export function sha256(value: string): string {
  return crypto.createHash("sha256").update(value).digest("hex");
}

/** Constant-time string comparison. */
export function safeEqual(a: string, b: string): boolean {
  const ba = Buffer.from(a);
  const bb = Buffer.from(b);
  if (ba.length !== bb.length) return false;
  return crypto.timingSafeEqual(ba, bb);
}
