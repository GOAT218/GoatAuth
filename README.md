# GoatAuth

**GoatAuth** is a self-hostable authentication & licensing platform for software
developers — think KeyAuth or Luarmor, but yours. Create an application, generate
license keys, and let your client software authenticate end users through a simple
REST API. GoatAuth handles user accounts, HWID (hardware-id) locking, timed
subscriptions and levels, active-session tracking, IP/HWID blacklisting, remote
variables, and an activity log — all managed from a modern dashboard.

> **Use responsibly.** GoatAuth is intended only to protect and license software
> that **you own or are explicitly authorized to protect**. Do not use it to gate,
> obfuscate, or distribute software you do not have the rights to.

---

## Features

- **Multi-app** — one seller account can host many independent applications, each with its own embedded secret.
- **License keys** — bulk-generate keys with configurable duration (or lifetime), level, max-uses, custom prefix/mask, and notes.
- **User accounts** — username/password registration gated by a license key, plus license-only (keyless) authentication.
- **HWID locking** — bind each user to a single machine; reset HWIDs from the dashboard.
- **Subscriptions & levels** — timed access (epoch-ms expiry, `null` = lifetime) and numeric permission levels; extend or upgrade with new keys.
- **Sessions** — issued as signed JWTs, tracked server-side, verifiable and individually killable.
- **Blacklisting** — block abusive IPs or HWIDs per app.
- **Remote variables** — store server-controlled config/strings; mark them `secret` so only authenticated sessions may read them.
- **Activity logs** — every client action (init/register/login/license/verify/upgrade/log/ban/blacklist/error) is recorded per app.
- **Rate limiting** — built-in per-IP throttling on the public client API.
- **REST API** — clean, versioned `/api/v1/*` endpoints with a consistent JSON envelope.
- **Dashboard** — dark, responsive UI for managing everything above.

---

## Tech stack

| Layer            | Technology                                             |
| ---------------- | ------------------------------------------------------ |
| Framework        | [Next.js 14](https://nextjs.org/) (App Router, `/src`) |
| Language         | TypeScript                                             |
| Styling          | Tailwind CSS                                            |
| Database         | SQLite via [better-sqlite3](https://github.com/WiseLibs/better-sqlite3) |
| Auth tokens      | [jose](https://github.com/panva/jose) (JWT, HS256)     |
| Password hashing | [bcryptjs](https://github.com/dcodeIO/bcrypt.js)       |
| Validation       | [zod](https://zod.dev/)                                |
| Misc             | nanoid (ids), lucide-react (icons), clsx / tailwind-merge |

---

## Quickstart

Requires Node.js 18+.

```bash
# 1. Install dependencies
npm install

# 2. Create your environment file and set the two secrets
cp .env.example .env
#    Edit .env and set strong values for:
#      GOATAUTH_SESSION_SECRET     (signs dashboard session cookies)
#      GOATAUTH_APP_TOKEN_SECRET   (signs client /api/v1 session tokens)
#    Generate each with:  openssl rand -base64 48

# 3. Seed the database with demo data
npm run seed

# 4. Start the dev server
npm run dev
#    -> http://localhost:3000
```

Then sign in at **http://localhost:3000/login**, or start calling the API.

The seed script creates a demo seller, a demo application, and five license keys:

| Field    | Value                     |
| -------- | ------------------------- |
| Username | `demo`                    |
| Password | `demo1234`                |
| App      | `Demo Loader` (v1.0)      |
| Keys     | 5 × `GOAT-XXXXX-…` keys   |

The seed prints the generated `app_id` and app `secret` to the console — you'll
need those to make client API calls.

### Other useful scripts

| Command             | Purpose                                                      |
| ------------------- | ----------------------------------------------------------- |
| `npm run dev`       | Start the development server                                 |
| `npm run build`     | Build for production                                         |
| `npm start`         | Run the production build (`npm run build && npm start`)      |
| `npm run typecheck` | Type-check the project with `tsc --noEmit`                   |
| `npm run seed`      | Seed demo seller + app + keys (idempotent)                  |
| `npm run db:reset`  | Delete the local SQLite database (then re-seed to rebuild)  |
| `npm run lint`      | Run Next.js ESLint                                           |

---

## Project structure

```
GoatAuth/
├─ src/
│  ├─ app/                    Next.js App Router pages & routes
│  │  ├─ (auth)/              Login & register pages for sellers
│  │  ├─ dashboard/           Seller dashboard (apps, keys, users, …)
│  │  ├─ docs/                Full API reference page (/docs)
│  │  └─ api/                 REST API route handlers
│  │     ├─ auth/             Seller session auth (login/logout/me/register)
│  │     ├─ apps/ keys/ users/ sessions/ blacklist/ variables/ logs/ stats/
│  │     │                    Dashboard (ownership-scoped) endpoints
│  │     └─ v1/               Public client authentication API
│  ├─ lib/                    Server & shared logic
│  │  ├─ repo/                Data-access layer (one module per table)
│  │  ├─ db.ts                SQLite connection + schema loader
│  │  ├─ schema.sql           Database schema (DDL)
│  │  ├─ auth-service.ts      Client API business logic (init/login/…)
│  │  ├─ seller-session.ts    Dashboard session helpers
│  │  ├─ app-session.ts       Client JWT sign/verify
│  │  ├─ api.ts               Response envelope + route handler wrapper
│  │  ├─ client.ts            Browser-side typed API client
│  │  ├─ validation.ts        zod schemas for every input
│  │  ├─ crypto.ts            Hashing & constant-time compare
│  │  ├─ ratelimit.ts         In-memory per-key rate limiter
│  │  ├─ format.ts            Date/duration formatting helpers
│  │  └─ types.ts             Shared domain types
│  └─ components/             React UI
│     ├─ ui/                  Reusable primitives (Button, Card, Table, …)
│     ├─ dashboard/           Dashboard-specific components
│     └─ marketing/           Landing-page nav & footer
├─ scripts/                   seed.mjs (demo data) & reset.mjs (drop db)
├─ examples/                  Client SDK examples (Python / JS / C#)
├─ data/                      SQLite database file (git-ignored)
└─ .env.example               Environment variable template
```

---

## Data model overview

All timestamps are **epoch milliseconds** (integers). An `expires_at` of `null`
means **lifetime** access.

| Table            | Description                                                                                     |
| ---------------- | ----------------------------------------------------------------------------------------------- |
| `sellers`        | Dashboard accounts (username, email, bcrypt password hash, role). Owns everything below.        |
| `apps`           | An application: name, version, per-app `secret`, status (active/paused), HWID-lock flag, download URL. |
| `license_keys`   | Redeemable keys: duration (days; `0` = lifetime), level, max-uses/uses, status (unused/used/banned), note. |
| `app_users`      | End users of an app: username, optional password hash, email, HWID, level, subscription expiry, ban flag. |
| `app_sessions`   | Issued client sessions: linked user, HWID, IP, validity flag, expiry — verifiable and killable. |
| `blacklist`      | Blocked `ip` or `hwid` values per app, with an optional reason.                                  |
| `app_variables`  | Server-controlled key/value strings per app; `secret` variables require an authenticated session to read. |
| `logs`           | Per-app activity log: action, message, user, IP, HWID, timestamp.                               |

All child tables cascade-delete with their parent (delete a seller → its apps →
their keys/users/sessions/etc.).

---

## Client API summary

Public endpoints your client software calls. Base path: **`/api/v1`**. All are
`POST` with a JSON body that must include the app identity: `app_id`, `secret`,
and (optionally) `version`.

| Method | Path                | Purpose                                                                  |
| ------ | ------------------- | ------------------------------------------------------------------------ |
| `POST` | `/api/v1/init`      | Handshake / app check; returns app name, version and update info.        |
| `POST` | `/api/v1/register`  | Register a new user (`username`, `password`, `key`) — redeems a license. |
| `POST` | `/api/v1/login`     | Authenticate an existing user (`username`, `password`, optional `hwid`). |
| `POST` | `/api/v1/license`   | Keyless auth: authenticate/redeem directly with a `key` (+ optional `hwid`). |
| `POST` | `/api/v1/verify`    | Validate a previously issued session `token`.                            |
| `POST` | `/api/v1/upgrade`   | Apply another `key` to a `username` to extend/upgrade their subscription. |
| `POST` | `/api/v1/var`       | Read an app variable by `name` (secret vars require a valid `token`).    |
| `POST` | `/api/v1/log`       | Write a message to the app's activity log.                               |

**Response envelope.** Success responses are `{ "success": true, … }` with fields
(e.g. `token`, `user`, `version`) at the top level. Failures return
`{ "success": false, "error": "…", "code": "…" }` with an appropriate HTTP status.

The public client API is rate-limited per IP. See the full, field-by-field
reference — including every request/response shape — at **[`/docs`](http://localhost:3000/docs)**.

### Example: `POST /api/v1/login`

```bash
curl -X POST http://localhost:3000/api/v1/login \
  -H "Content-Type: application/json" \
  -d '{
    "app_id": "YOUR_APP_ID",
    "secret": "YOUR_APP_SECRET",
    "version": "1.0",
    "username": "someuser",
    "password": "theirpassword",
    "hwid": "OPTIONAL-MACHINE-HWID"
  }'
```

A successful response returns a signed session `token` and the authenticated
`user` object; pass the `token` back to `/api/v1/verify` on subsequent runs.

---

## Client SDK examples

Ready-to-adapt integration snippets for common client languages live in the
`examples/` directory:

| Language   | File                             |
| ---------- | -------------------------------- |
| Python     | `examples/python_client.py`      |
| JavaScript | `examples/javascript_client.js`  |
| C#         | `examples/csharp_client.cs`      |

Each demonstrates the typical flow: `init` → `login`/`license` → `verify`, plus
reading variables and writing logs.

---

## Dashboard overview

Once signed in at `/dashboard`, a seller can:

- **Apps** — create applications, edit name/version/status, toggle HWID locking, set a download URL, and rotate the per-app secret.
- **Keys** — bulk-generate license keys (duration, level, max-uses, prefix/mask, note), copy them, ban them, and delete unused keys.
- **Users** — view app users, ban/unban with a reason, change level, adjust subscription expiry, reset HWID, and delete accounts.
- **Sessions** — inspect active sessions (user, IP, HWID, expiry) and kill any of them.
- **Blacklist** — add/remove blocked IPs and HWIDs per app.
- **Variables** — manage remote key/value strings, including `secret` ones.
- **Settings** — manage account details and view API/integration info.

The dashboard also surfaces at-a-glance stats (apps, users, keys, unused keys,
active sessions, banned users) and recent activity.

---

## Security notes

- **Password hashing** — seller and user passwords are hashed with **bcrypt** (cost 12); plaintext is never stored.
- **Signed sessions** — dashboard cookies and client `/api/v1` tokens are **JWTs (HS256)** signed with separate secrets.
- **Per-app secrets** — each application has its own embedded `secret`, compared in constant time and rotatable at any time.
- **HWID locking** — optionally binds each user to a single machine to curb key sharing.
- **Rate limiting** — the public client API is throttled per IP to blunt brute-force and abuse.
- **Ownership enforcement** — every dashboard endpoint verifies the signed-in seller actually owns the app/record being touched.

**In production:**

- Set **strong, unique** values for `GOATAUTH_SESSION_SECRET` and
  `GOATAUTH_APP_TOKEN_SECRET` (e.g. `openssl rand -base64 48`). Never commit `.env`.
- Serve GoatAuth **only over HTTPS/TLS** — app secrets and tokens travel in requests.
- Treat each app `secret` as sensitive; rotate it if it may have leaked. Remember
  that any secret embedded in distributed client software can be extracted, so
  combine it with HWID locking, session verification, and server-side variables.

---

## Environment variables

Copy `.env.example` to `.env` and fill these in:

| Variable                    | Required | Default                 | Description                                                             |
| --------------------------- | -------- | ----------------------- | ----------------------------------------------------------------------- |
| `GOATAUTH_SESSION_SECRET`   | **Yes**  | —                       | Secret used to sign seller dashboard session cookies (JWT). Change it.  |
| `GOATAUTH_APP_TOKEN_SECRET` | **Yes**  | —                       | Secret used to sign client application session tokens from `/api/v1/*`. |
| `GOATAUTH_DB_PATH`          | No       | `./data/goatauth.db`    | Path to the SQLite database file.                                       |
| `NEXT_PUBLIC_APP_URL`       | No       | `http://localhost:3000` | Public base URL of the deployment (used in docs/examples).              |

---

## License & disclaimer

Provided as-is, without warranty of any kind. **You are solely responsible for how
you deploy and use GoatAuth** — use it only to protect software you own or are
authorized to protect, and in compliance with all applicable laws.
