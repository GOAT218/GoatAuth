-- GoatAuth database schema. Loaded by src/lib/db.ts and scripts/seed.mjs.

CREATE TABLE IF NOT EXISTS sellers (
  id            TEXT PRIMARY KEY,
  username      TEXT NOT NULL UNIQUE,
  email         TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  role          TEXT NOT NULL DEFAULT 'seller',
  created_at    INTEGER NOT NULL,
  last_login_at INTEGER
);

CREATE TABLE IF NOT EXISTS apps (
  id              TEXT PRIMARY KEY,
  seller_id       TEXT NOT NULL,
  name            TEXT NOT NULL,
  secret          TEXT NOT NULL,
  version         TEXT NOT NULL DEFAULT '1.0',
  status          TEXT NOT NULL DEFAULT 'active',
  hwid_lock       INTEGER NOT NULL DEFAULT 1,
  hwid_reset_cost INTEGER NOT NULL DEFAULT 0,
  download_url    TEXT,
  created_at      INTEGER NOT NULL,
  FOREIGN KEY (seller_id) REFERENCES sellers(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_apps_seller ON apps(seller_id);

CREATE TABLE IF NOT EXISTS license_keys (
  id            TEXT PRIMARY KEY,
  app_id        TEXT NOT NULL,
  key           TEXT NOT NULL UNIQUE,
  duration_days INTEGER NOT NULL DEFAULT 30,
  level         INTEGER NOT NULL DEFAULT 1,
  max_uses      INTEGER NOT NULL DEFAULT 1,
  uses          INTEGER NOT NULL DEFAULT 0,
  status        TEXT NOT NULL DEFAULT 'unused',
  note          TEXT,
  created_by    TEXT,
  created_at    INTEGER NOT NULL,
  used_at       INTEGER,
  FOREIGN KEY (app_id) REFERENCES apps(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_keys_app ON license_keys(app_id);
CREATE INDEX IF NOT EXISTS idx_keys_key ON license_keys(key);

CREATE TABLE IF NOT EXISTS app_users (
  id            TEXT PRIMARY KEY,
  app_id        TEXT NOT NULL,
  username      TEXT NOT NULL,
  password_hash TEXT,
  email         TEXT,
  hwid          TEXT,
  ip            TEXT,
  level         INTEGER NOT NULL DEFAULT 1,
  expires_at    INTEGER,
  banned        INTEGER NOT NULL DEFAULT 0,
  ban_reason    TEXT,
  created_at    INTEGER NOT NULL,
  last_login_at INTEGER,
  FOREIGN KEY (app_id) REFERENCES apps(id) ON DELETE CASCADE,
  UNIQUE (app_id, username)
);
CREATE INDEX IF NOT EXISTS idx_users_app ON app_users(app_id);

CREATE TABLE IF NOT EXISTS app_sessions (
  id         TEXT PRIMARY KEY,
  app_id     TEXT NOT NULL,
  user_id    TEXT,
  hwid       TEXT,
  ip         TEXT,
  valid      INTEGER NOT NULL DEFAULT 1,
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  FOREIGN KEY (app_id) REFERENCES apps(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES app_users(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_sessions_app ON app_sessions(app_id);
CREATE INDEX IF NOT EXISTS idx_sessions_user ON app_sessions(user_id);

CREATE TABLE IF NOT EXISTS blacklist (
  id         TEXT PRIMARY KEY,
  app_id     TEXT NOT NULL,
  type       TEXT NOT NULL,
  value      TEXT NOT NULL,
  reason     TEXT,
  created_at INTEGER NOT NULL,
  FOREIGN KEY (app_id) REFERENCES apps(id) ON DELETE CASCADE,
  UNIQUE (app_id, type, value)
);
CREATE INDEX IF NOT EXISTS idx_blacklist_app ON blacklist(app_id);

CREATE TABLE IF NOT EXISTS app_variables (
  id         TEXT PRIMARY KEY,
  app_id     TEXT NOT NULL,
  name       TEXT NOT NULL,
  value      TEXT NOT NULL,
  secret     INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  FOREIGN KEY (app_id) REFERENCES apps(id) ON DELETE CASCADE,
  UNIQUE (app_id, name)
);
CREATE INDEX IF NOT EXISTS idx_vars_app ON app_variables(app_id);

CREATE TABLE IF NOT EXISTS logs (
  id         TEXT PRIMARY KEY,
  app_id     TEXT NOT NULL,
  user_id    TEXT,
  action     TEXT NOT NULL,
  message    TEXT NOT NULL,
  ip         TEXT,
  hwid       TEXT,
  created_at INTEGER NOT NULL,
  FOREIGN KEY (app_id) REFERENCES apps(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_logs_app ON logs(app_id);
CREATE INDEX IF NOT EXISTS idx_logs_created ON logs(created_at);
