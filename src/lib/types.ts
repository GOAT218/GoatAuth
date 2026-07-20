// Shared domain types for GoatAuth.
// These mirror the SQLite schema defined in `src/lib/db.ts`.

export type SellerRole = "owner" | "admin" | "seller";

export interface Seller {
  id: string;
  username: string;
  email: string;
  password_hash: string;
  role: SellerRole;
  created_at: number;
  last_login_at: number | null;
}

export type AppStatus = "active" | "paused";

export interface App {
  id: string; // public application id, used by clients
  seller_id: string;
  name: string;
  secret: string; // client-embedded shared secret
  version: string;
  status: AppStatus;
  hwid_lock: number; // 0 | 1 — lock each user to one HWID
  hwid_reset_cost: number; // reserved: cost/limit metadata
  download_url: string | null; // returned when client version is out of date
  created_at: number;
}

export type LicenseStatus = "unused" | "used" | "banned";

export interface LicenseKey {
  id: string;
  app_id: string;
  key: string; // the license string a user redeems
  duration_days: number; // subscription length granted on redeem; 0 = lifetime
  level: number; // subscription level granted
  max_uses: number; // how many redemptions allowed
  uses: number; // redemptions so far
  status: LicenseStatus;
  note: string | null;
  created_by: string | null; // seller id
  created_at: number;
  used_at: number | null;
}

export interface AppUser {
  id: string;
  app_id: string;
  username: string;
  password_hash: string | null; // null for license-only users
  email: string | null;
  hwid: string | null; // locked hardware id
  ip: string | null; // last seen ip
  level: number;
  expires_at: number | null; // subscription expiry (ms epoch); null = lifetime
  banned: number; // 0 | 1
  ban_reason: string | null;
  created_at: number;
  last_login_at: number | null;
}

export interface AppSession {
  id: string; // session token id
  app_id: string;
  user_id: string | null;
  hwid: string | null;
  ip: string | null;
  valid: number; // 0 | 1 — set to 0 to kill the session
  created_at: number;
  expires_at: number;
}

export type BlacklistType = "ip" | "hwid";

export interface BlacklistEntry {
  id: string;
  app_id: string;
  type: BlacklistType;
  value: string;
  reason: string | null;
  created_at: number;
}

export interface AppVariable {
  id: string;
  app_id: string;
  name: string;
  value: string;
  secret: number; // 0 | 1 — if 1, only authenticated sessions may read
  created_at: number;
}

export type LogAction =
  | "init"
  | "register"
  | "login"
  | "license"
  | "verify"
  | "upgrade"
  | "log"
  | "ban"
  | "blacklist"
  | "error";

export interface LogEntry {
  id: string;
  app_id: string;
  user_id: string | null;
  action: LogAction;
  message: string;
  ip: string | null;
  hwid: string | null;
  created_at: number;
}

// Public projections (safe to send to the dashboard client) ------------------

export interface PublicSeller {
  id: string;
  username: string;
  email: string;
  role: SellerRole;
  created_at: number;
  last_login_at: number | null;
}

export function toPublicSeller(s: Seller): PublicSeller {
  return {
    id: s.id,
    username: s.username,
    email: s.email,
    role: s.role,
    created_at: s.created_at,
    last_login_at: s.last_login_at,
  };
}
