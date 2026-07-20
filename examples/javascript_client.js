// =============================================================================
// GoatAuth — JavaScript / Node.js example client (Node 18+, global fetch)
// =============================================================================
//
// This is an EXAMPLE showing how to authenticate YOUR OWN software against a
// GoatAuth server. Drop this kind of logic into the Node/Electron client you
// distribute; it talks to the GoatAuth client API at /api/v1/*.
//
// Every endpoint is a POST with a JSON body that always includes your app_id
// and secret (from your app's dashboard page), plus endpoint-specific fields.
//
// Every response is JSON with a boolean "success" flag:
//   * On success  -> { success: true, ...fields }
//   * On failure  -> { success: false, message: "...", code: "..." }
//
// The important response fields:
//   token   : opaque session token; store it and pass it back to verify()
//   user    : {
//               username:          string,
//               level:             number,          // subscription tier
//               expires_at:        number | null,   // epoch MILLISECONDS, null = lifetime
//               expires_iso:       string | null,   // ISO-8601 timestamp, null = lifetime
//               seconds_remaining: number | null,   // null = lifetime
//               lifetime:          boolean,
//               created_at:        number           // epoch MILLISECONDS
//             }
//   version : {
//               outdated:     boolean,              // true if your version !== latest
//               latest:       string,               // newest published version
//               download_url: string | null         // where to grab the update
//             }
//
// NOTE: Anything you ship can be reverse-engineered, so do not treat the
// client-side "secret" as truly secret. GoatAuth's real protection is
// server-side (key consumption, HWID locking, bans, expiry). The secret lives
// in this file purely for a clear, self-contained example.
//
// Requires Node 18+ (for the built-in global `fetch`). Run with:
//   node examples/javascript_client.js
// =============================================================================

import crypto from "node:crypto";
import os from "node:os";

// --- Configuration -----------------------------------------------------------
// Point this at your GoatAuth server. In production use https://your-domain.
const BASE_URL = "http://localhost:3000";

// Replace these with the values shown on your app's dashboard page.
const APP_ID = "your-app-id-here";
const SECRET = "your-app-secret-here";

// The version string of THIS build of your software. The server compares it
// against the latest published version to tell you when an update is available.
const APP_VERSION = "1.0";

// --- Hardware ID -------------------------------------------------------------
/**
 * Compute a stable-ish hardware identifier for this machine.
 *
 * We hash a mix of the hostname and the current OS user so we never send raw
 * machine details over the wire. This is 'good enough' for a demo; production
 * clients usually mix in more entropy (disk serials, MAC, machine GUID, etc.).
 *
 * @returns {string} lowercase hex SHA-256 digest
 */
export function getHwid() {
  const user = os.userInfo();
  const raw = [
    os.hostname(),
    user.username,
    os.platform(), // e.g. "win32" / "linux" / "darwin"
    os.arch(), // e.g. "x64"
  ].join("|");
  return crypto.createHash("sha256").update(raw).digest("hex");
}

// --- Low-level HTTP helper ---------------------------------------------------
/**
 * POST a JSON body to /api/v1/<endpoint> and return the decoded JSON object.
 *
 * Always injects app_id + secret. Parses the response as JSON regardless of
 * HTTP status (GoatAuth returns a JSON error envelope on failures too), so
 * callers can rely on the `success` flag rather than catching thrown errors.
 *
 * @param {string} endpoint  e.g. "login"
 * @param {object} payload   endpoint-specific fields
 * @returns {Promise<object>}
 */
async function post(endpoint, payload) {
  const body = JSON.stringify({ app_id: APP_ID, secret: SECRET, ...payload });

  try {
    const resp = await fetch(`${BASE_URL}/api/v1/${endpoint}`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body,
    });
    // GoatAuth sends a JSON body on both success and error responses.
    return await resp.json();
  } catch (err) {
    return {
      success: false,
      message: `Network error: ${err instanceof Error ? err.message : String(err)}`,
      code: "network_error",
    };
  }
}

// --- Public API --------------------------------------------------------------

/**
 * Handshake with the server. Returns app info + version details (whether this
 * build is outdated and where to download the latest). Call this at startup.
 */
export async function init() {
  return post("init", { version: APP_VERSION });
}

/** Create a new user, consuming a license key. Returns a session on success. */
export async function register(username, password, key, hwid) {
  return post("register", { username, password, key, hwid });
}

/** Authenticate an existing username/password. Returns a session on success. */
export async function login(username, password, hwid) {
  return post("login", { username, password, hwid });
}

/**
 * License-only authentication: the key itself is the credential (no username or
 * password). Returns a session on success.
 */
export async function license(key, hwid) {
  return post("license", { key, hwid });
}

/**
 * Re-check a previously issued token (e.g. periodically, or on next launch) to
 * confirm the session is still valid and the user is not banned/expired.
 */
export async function verify(token, hwid) {
  return post("verify", { token, hwid });
}

// --- Helpers -----------------------------------------------------------------
/** Pretty-print the subscription info from a `user` payload. */
function printUser(user) {
  if (!user) {
    console.log("  (no user attached to this session)");
    return;
  }
  console.log(`  username          : ${user.username}`);
  console.log(`  level             : ${user.level}`);
  if (user.lifetime) {
    console.log("  subscription      : LIFETIME (never expires)");
  } else {
    console.log(`  expires (iso)     : ${user.expires_iso}`);
    console.log(`  seconds remaining : ${user.seconds_remaining}`);
  }
}

// --- Demo --------------------------------------------------------------------
async function main() {
  const hwid = getHwid();
  console.log(`HWID: ${hwid}\n`);

  // 1) Handshake + update check.
  console.log("== init ==");
  let res = await init();
  if (!res.success) {
    console.log(`init failed: ${res.message} (code=${res.code})`);
    process.exit(1);
  }
  const { version } = res;
  console.log(`  latest version    : ${version.latest}`);
  console.log(`  outdated          : ${version.outdated}`);
  if (version.outdated) {
    console.log(`  download update   : ${version.download_url}`);
  }
  console.log();

  // 2) Log in with sample credentials (swap for real ones / a UI prompt).
  console.log("== login ==");
  res = await login("sample_user", "sample_password", hwid);
  if (!res.success) {
    console.log(`login failed: ${res.message} (code=${res.code})`);
    process.exit(1);
  }
  const token = res.token;
  console.log("  login OK, subscription:");
  printUser(res.user);
  console.log();

  // 3) Verify the token we just received.
  console.log("== verify ==");
  res = await verify(token, hwid);
  if (!res.success) {
    console.log(`verify failed: ${res.message} (code=${res.code})`);
    process.exit(1);
  }
  console.log("  token is valid, subscription:");
  printUser(res.user);
}

// Run the demo when this file is executed directly (not when imported as a
// module). Any unexpected error is logged instead of crashing silently.
main().catch((err) => console.error(err));
