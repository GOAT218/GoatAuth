import * as React from "react";
import Link from "next/link";
import { ArrowRight, BookOpen, Code2, KeyRound, Terminal, Zap } from "lucide-react";
import { Nav } from "@/components/marketing/Nav";
import { Footer } from "@/components/marketing/Footer";
import { Card, CardHeader, CardTitle, CardBody } from "@/components/ui/Card";
import { Badge } from "@/components/ui/Badge";
import { CodeBlock } from "@/components/ui/CodeBlock";
import { Table, THead, TBody, TR, TH, TD } from "@/components/ui/Table";

export const metadata = {
  title: "API Documentation — GoatAuth",
  description:
    "Integrate GoatAuth into your software: authenticate users, validate license keys, and manage sessions through a simple JSON REST API.",
};

const BASE = "https://your-domain";

// --- Types ------------------------------------------------------------------

type Field = {
  name: string;
  type: string;
  required: boolean;
  desc: string;
};

type EndpointDef = {
  id: string;
  method: string;
  path: string;
  title: string;
  description: string;
  fields: Field[];
  request: string;
  response: string;
  note?: string;
};

// --- Reusable field / session snippets --------------------------------------

const AUTH_FIELDS: Field[] = [
  { name: "app_id", type: "string", required: true, desc: "Your application's public ID." },
  { name: "secret", type: "string", required: true, desc: "Your application's secret (server-side / obfuscated in your client)." },
];

const SESSION_RESPONSE = `{
  "success": true,
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "session_id": "ses_7c6b5a4d",
  "user": {
    "username": "player_one",
    "level": 1,
    "expires_at": 1789200000000,
    "expires_iso": "2026-09-13T00:00:00.000Z",
    "seconds_remaining": 2592000,
    "lifetime": false,
    "created_at": 1786608000000
  },
  "version": { "outdated": false, "latest": "1.0.0", "download_url": null }
}`;

// --- Endpoint definitions ---------------------------------------------------

const ENDPOINTS: EndpointDef[] = [
  {
    id: "init",
    method: "POST",
    path: "/api/v1/init",
    title: "Initialize",
    description:
      "Verify the app_id / secret pair, confirm the app is active, and check whether the caller is running the latest version. Call this once when your software starts.",
    fields: [
      ...AUTH_FIELDS,
      { name: "version", type: "string", required: false, desc: "The client's current version. When it differs from the app's version the response is flagged as outdated." },
    ],
    request: `{
  "app_id": "app_1a2b3c4d",
  "secret": "sk_live_9f8e7d6c5b4a",
  "version": "1.0.0"
}`,
    response: `{
  "success": true,
  "app": { "name": "My Cool App", "version": "1.0.0" },
  "version": {
    "outdated": false,
    "latest": "1.0.0",
    "download_url": null
  }
}`,
  },
  {
    id: "register",
    method: "POST",
    path: "/api/v1/register",
    title: "Register",
    description:
      "Create a new user by consuming a license key. The key determines the user's level and subscription length. On success a session token is issued immediately.",
    fields: [
      ...AUTH_FIELDS,
      { name: "username", type: "string", required: true, desc: "Desired username, unique within the app." },
      { name: "password", type: "string", required: true, desc: "The user's chosen password." },
      { name: "key", type: "string", required: true, desc: "An unused license key to redeem." },
      { name: "email", type: "string", required: false, desc: "Optional email address to store on the account." },
      { name: "hwid", type: "string", required: false, desc: "Hardware ID. Required when the app has HWID locking enabled; it becomes bound to the account." },
    ],
    request: `{
  "app_id": "app_1a2b3c4d",
  "secret": "sk_live_9f8e7d6c5b4a",
  "username": "player_one",
  "password": "s3cret-pass",
  "key": "AAAA-BBBB-CCCC-DDDD",
  "email": "user@example.com",
  "hwid": "8F3B-2C91-DE45"
}`,
    response: SESSION_RESPONSE,
  },
  {
    id: "login",
    method: "POST",
    path: "/api/v1/login",
    title: "Login",
    description:
      "Authenticate an existing user with their username and password. Returns a fresh session token plus the user's current subscription details. Bans, expiry, and HWID locking are all enforced here.",
    fields: [
      ...AUTH_FIELDS,
      { name: "username", type: "string", required: true, desc: "The user's username." },
      { name: "password", type: "string", required: true, desc: "The user's password." },
      { name: "hwid", type: "string", required: false, desc: "Hardware ID. Checked against the bound HWID when locking is enabled; bound on first login if not yet set." },
    ],
    request: `{
  "app_id": "app_1a2b3c4d",
  "secret": "sk_live_9f8e7d6c5b4a",
  "username": "player_one",
  "password": "s3cret-pass",
  "hwid": "8F3B-2C91-DE45"
}`,
    response: SESSION_RESPONSE,
  },
  {
    id: "license",
    method: "POST",
    path: "/api/v1/license",
    title: "License-only auth",
    description:
      "Authenticate using only a license key — no separate username or password. The key itself is the credential: on first use it is consumed and an implicit account is created, so HWID locking and expiry still apply on later calls.",
    fields: [
      ...AUTH_FIELDS,
      { name: "key", type: "string", required: true, desc: "The license key used as the sole credential." },
      { name: "hwid", type: "string", required: false, desc: "Hardware ID. Required when the app has HWID locking enabled." },
    ],
    request: `{
  "app_id": "app_1a2b3c4d",
  "secret": "sk_live_9f8e7d6c5b4a",
  "key": "AAAA-BBBB-CCCC-DDDD",
  "hwid": "8F3B-2C91-DE45"
}`,
    response: `{
  "success": true,
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "session_id": "ses_7c6b5a4d",
  "user": {
    "username": "AAAA-BBBB-CCCC-DDDD",
    "level": 1,
    "expires_at": 1789200000000,
    "expires_iso": "2026-09-13T00:00:00.000Z",
    "seconds_remaining": 2592000,
    "lifetime": false,
    "created_at": 1786608000000
  },
  "version": { "outdated": false, "latest": "1.0.0", "download_url": null }
}`,
  },
  {
    id: "verify",
    method: "POST",
    path: "/api/v1/verify",
    title: "Verify session",
    description:
      "Validate a previously issued session token — call this on subsequent launches to confirm the session is still active without asking for credentials again. Returns the user when the token is tied to one.",
    fields: [
      ...AUTH_FIELDS,
      { name: "token", type: "string", required: true, desc: "A session token returned by register, login, or license." },
      { name: "hwid", type: "string", required: false, desc: "Hardware ID. Re-checked against the bound HWID when locking is enabled." },
    ],
    request: `{
  "app_id": "app_1a2b3c4d",
  "secret": "sk_live_9f8e7d6c5b4a",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "hwid": "8F3B-2C91-DE45"
}`,
    response: `{
  "success": true,
  "session_id": "ses_7c6b5a4d",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "username": "player_one",
    "level": 1,
    "expires_at": 1789200000000,
    "expires_iso": "2026-09-13T00:00:00.000Z",
    "seconds_remaining": 2591990,
    "lifetime": false,
    "created_at": 1786608000000
  },
  "version": { "outdated": false, "latest": "1.0.0", "download_url": null }
}`,
    note: "Anonymous sessions created by /init have no user attached, so the user field is omitted for those tokens.",
  },
  {
    id: "upgrade",
    method: "POST",
    path: "/api/v1/upgrade",
    title: "Upgrade / extend",
    description:
      "Redeem another license key against an existing user to extend their subscription and raise their level. Useful for renewals and tier upgrades without creating a new account.",
    fields: [
      ...AUTH_FIELDS,
      { name: "username", type: "string", required: true, desc: "The existing user to upgrade." },
      { name: "key", type: "string", required: true, desc: "An unused license key to apply to the account." },
    ],
    request: `{
  "app_id": "app_1a2b3c4d",
  "secret": "sk_live_9f8e7d6c5b4a",
  "username": "player_one",
  "key": "EEEE-FFFF-GGGG-HHHH"
}`,
    response: `{
  "success": true,
  "user": {
    "username": "player_one",
    "level": 2,
    "expires_at": 1791792000000,
    "expires_iso": "2026-10-13T00:00:00.000Z",
    "seconds_remaining": 5184000,
    "lifetime": false,
    "created_at": 1786608000000
  }
}`,
  },
  {
    id: "var",
    method: "POST",
    path: "/api/v1/var",
    title: "Read variable",
    description:
      "Fetch a server-stored variable by name. Use variables for values you want to change remotely — download URLs, feature flags, or endpoints — without shipping a new build.",
    fields: [
      ...AUTH_FIELDS,
      { name: "name", type: "string", required: true, desc: "The variable name to read." },
      { name: "token", type: "string", required: false, desc: "A valid session token. Required only when reading a variable marked as secret." },
    ],
    request: `{
  "app_id": "app_1a2b3c4d",
  "secret": "sk_live_9f8e7d6c5b4a",
  "name": "config_url",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}`,
    response: `{
  "success": true,
  "name": "config_url",
  "value": "https://cdn.example.com/config.json"
}`,
    note: "Secret variables require a valid authenticated session token; public variables can be read with just app_id and secret.",
  },
  {
    id: "log",
    method: "POST",
    path: "/api/v1/log",
    title: "Write log",
    description:
      "Record a custom log line against your app. Everything shows up in the dashboard's activity feed — handy for tracking launches, errors, or anti-tamper events.",
    fields: [
      ...AUTH_FIELDS,
      { name: "message", type: "string", required: true, desc: "The log message to record." },
      { name: "username", type: "string", required: false, desc: "Associate the log entry with a specific user." },
      { name: "token", type: "string", required: false, desc: "Optional session token for authenticated logging." },
    ],
    request: `{
  "app_id": "app_1a2b3c4d",
  "secret": "sk_live_9f8e7d6c5b4a",
  "message": "Loader launched successfully",
  "username": "player_one"
}`,
    response: `{
  "success": true,
  "logged": true
}`,
  },
];

// --- Error codes ------------------------------------------------------------

const ERRORS: { code: string; status: number; meaning: string }[] = [
  { code: "bad_secret", status: 403, meaning: "The app_id / secret pair is invalid." },
  { code: "app_paused", status: 403, meaning: "The application is currently paused in the dashboard." },
  { code: "bad_key", status: 403, meaning: "The license key is invalid or has already been used." },
  { code: "bad_credentials", status: 401, meaning: "The username or password is incorrect." },
  { code: "banned", status: 403, meaning: "The user account has been banned." },
  { code: "expired", status: 403, meaning: "The user's subscription has expired." },
  { code: "hwid_mismatch", status: 403, meaning: "The supplied HWID does not match the one bound to the account." },
  { code: "rate_limited", status: 429, meaning: "Too many requests — slow down and retry later." },
  { code: "validation", status: 422, meaning: "The request body failed validation." },
];

// --- Code samples -----------------------------------------------------------

const CURL_INIT = `curl -X POST ${BASE}/api/v1/init \\
  -H "Content-Type: application/json" \\
  -d '{
    "app_id": "app_1a2b3c4d",
    "secret": "sk_live_9f8e7d6c5b4a",
    "version": "1.0.0"
  }'`;

const JS_LOGIN = `const BASE = "${BASE}";

async function login(username, password) {
  const res = await fetch(BASE + "/api/v1/login", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      app_id: "app_1a2b3c4d",
      secret: "sk_live_9f8e7d6c5b4a",
      username,
      password,
    }),
  });

  const data = await res.json();
  if (!data.success) throw new Error(data.message);

  // Persist data.token and pass it to /api/v1/verify on later launches.
  return data;
}`;

const SUCCESS_SHAPE = `{ "success": true,  /* ...extra fields... */ }`;
const ERROR_SHAPE = `{ "success": false, "message": "Human readable reason", "code": "bad_secret" }`;

// --- Small presentational helpers -------------------------------------------

function MethodBadge({ method }: { method: string }) {
  return (
    <Badge tone="info" className="font-mono uppercase tracking-wider">
      {method}
    </Badge>
  );
}

function FieldTable({ fields }: { fields: Field[] }) {
  return (
    <Table>
      <THead>
        <TR>
          <TH>Field</TH>
          <TH>Type</TH>
          <TH>Required</TH>
          <TH className="w-1/2">Description</TH>
        </TR>
      </THead>
      <TBody>
        {fields.map((f) => (
          <TR key={f.name}>
            <TD className="font-mono text-white/90">{f.name}</TD>
            <TD className="font-mono text-white/50">{f.type}</TD>
            <TD>
              {f.required ? (
                <Badge tone="brand">required</Badge>
              ) : (
                <Badge tone="neutral">optional</Badge>
              )}
            </TD>
            <TD className="text-white/60">{f.desc}</TD>
          </TR>
        ))}
      </TBody>
    </Table>
  );
}

function EndpointCard({ ep }: { ep: EndpointDef }) {
  return (
    <Card id={ep.id} className="scroll-mt-24">
      <CardHeader className="flex-col items-start gap-2 sm:flex-row sm:items-center">
        <div className="flex items-center gap-3">
          <MethodBadge method={ep.method} />
          <code className="font-mono text-sm text-white/90">{ep.path}</code>
        </div>
        <CardTitle className="text-white/50">{ep.title}</CardTitle>
      </CardHeader>
      <CardBody className="space-y-5">
        <p className="text-sm leading-relaxed text-white/60">{ep.description}</p>

        <div>
          <h4 className="mb-2 text-xs font-semibold uppercase tracking-wider text-white/40">
            Request fields
          </h4>
          <div className="overflow-hidden rounded-xl border border-border">
            <FieldTable fields={ep.fields} />
          </div>
        </div>

        <div className="grid gap-4 lg:grid-cols-2">
          <div className="space-y-2">
            <h4 className="text-xs font-semibold uppercase tracking-wider text-white/40">
              Example request
            </h4>
            <CodeBlock language="json" code={ep.request} />
          </div>
          <div className="space-y-2">
            <h4 className="text-xs font-semibold uppercase tracking-wider text-white/40">
              Example response
            </h4>
            <CodeBlock language="json" code={ep.response} />
          </div>
        </div>

        {ep.note && (
          <p className="rounded-lg border border-border-soft bg-bg-soft px-4 py-3 text-sm text-white/55">
            <span className="font-semibold text-white/70">Note: </span>
            {ep.note}
          </p>
        )}
      </CardBody>
    </Card>
  );
}

// --- Page -------------------------------------------------------------------

export default function DocsPage() {
  return (
    <div className="flex min-h-screen flex-col bg-bg">
      <Nav />

      <main className="mx-auto w-full max-w-5xl flex-1 px-4 py-12 sm:px-6 sm:py-16">
        {/* Intro */}
        <section id="top" className="scroll-mt-24">
          <div className="mb-4 inline-flex items-center gap-2 rounded-full border border-border bg-bg-soft px-3 py-1 text-xs text-white/50">
            <BookOpen className="h-3.5 w-3.5 text-brand-400" />
            Developer documentation
          </div>
          <h1 className="text-3xl font-bold tracking-tight text-white sm:text-4xl">
            GoatAuth API
          </h1>
          <p className="mt-4 max-w-3xl text-base leading-relaxed text-white/60">
            GoatAuth is an authentication and licensing API for software developers. Create an app in
            the dashboard, hand out license keys, and let your software authenticate users, validate
            licenses, and manage sessions through a handful of simple REST calls.
          </p>

          <div className="mt-6 space-y-4">
            <p className="text-sm leading-relaxed text-white/60">
              Every client endpoint lives under{" "}
              <code className="rounded bg-bg-elevated px-1.5 py-0.5 font-mono text-white/80">
                /api/v1/*
              </code>{" "}
              and accepts a <span className="text-white/80">POST</span> request with a JSON body and{" "}
              <code className="rounded bg-bg-elevated px-1.5 py-0.5 font-mono text-white/80">
                Content-Type: application/json
              </code>
              . Every request must include your{" "}
              <code className="rounded bg-bg-elevated px-1.5 py-0.5 font-mono text-white/80">
                app_id
              </code>{" "}
              and{" "}
              <code className="rounded bg-bg-elevated px-1.5 py-0.5 font-mono text-white/80">
                secret
              </code>
              . All timestamps are epoch milliseconds, and{" "}
              <code className="rounded bg-bg-elevated px-1.5 py-0.5 font-mono text-white/80">
                expires_at: null
              </code>{" "}
              means a lifetime subscription.
            </p>
            <p className="text-sm leading-relaxed text-white/60">
              Responses are always JSON with a boolean{" "}
              <code className="rounded bg-bg-elevated px-1.5 py-0.5 font-mono text-white/80">
                success
              </code>{" "}
              field. On success the relevant data is merged into the top level of the object; on
              failure you get a message and a machine-readable code.
            </p>
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <h4 className="text-xs font-semibold uppercase tracking-wider text-brand-300">
                  Success
                </h4>
                <CodeBlock language="json" code={SUCCESS_SHAPE} />
              </div>
              <div className="space-y-2">
                <h4 className="text-xs font-semibold uppercase tracking-wider text-red-300">
                  Error
                </h4>
                <CodeBlock language="json" code={ERROR_SHAPE} />
              </div>
            </div>
          </div>

          {/* Base URL */}
          <div className="mt-6 space-y-2">
            <h4 className="text-xs font-semibold uppercase tracking-wider text-white/40">
              Base URL
            </h4>
            <CodeBlock language="text" code={`${BASE}/api/v1`} />
            <p className="text-xs text-white/40">
              Replace <code className="font-mono text-white/60">{BASE}</code> with the domain where
              your GoatAuth instance is hosted.
            </p>
          </div>
        </section>

        {/* Contents */}
        <nav aria-label="Contents" className="mt-12">
          <Card>
            <CardHeader>
              <CardTitle>On this page</CardTitle>
            </CardHeader>
            <CardBody>
              <ul className="grid gap-3 sm:grid-cols-2">
                <li>
                  <a
                    href="#quickstart"
                    className="group flex items-center gap-3 rounded-lg border border-border-soft bg-bg-soft px-4 py-3 transition-colors hover:border-brand-500/40 hover:bg-bg-elevated"
                  >
                    <Zap className="h-4 w-4 text-brand-400" />
                    <span className="text-sm font-medium text-white/80 group-hover:text-white">
                      Quickstart
                    </span>
                    <ArrowRight className="ml-auto h-4 w-4 text-white/25 transition-colors group-hover:text-white/60" />
                  </a>
                </li>
                <li>
                  <a
                    href="#api"
                    className="group flex items-center gap-3 rounded-lg border border-border-soft bg-bg-soft px-4 py-3 transition-colors hover:border-brand-500/40 hover:bg-bg-elevated"
                  >
                    <Code2 className="h-4 w-4 text-accent" />
                    <span className="text-sm font-medium text-white/80 group-hover:text-white">
                      API reference
                    </span>
                    <ArrowRight className="ml-auto h-4 w-4 text-white/25 transition-colors group-hover:text-white/60" />
                  </a>
                </li>
                <li>
                  <a
                    href="#errors"
                    className="group flex items-center gap-3 rounded-lg border border-border-soft bg-bg-soft px-4 py-3 transition-colors hover:border-brand-500/40 hover:bg-bg-elevated"
                  >
                    <KeyRound className="h-4 w-4 text-amber-400" />
                    <span className="text-sm font-medium text-white/80 group-hover:text-white">
                      Error codes
                    </span>
                    <ArrowRight className="ml-auto h-4 w-4 text-white/25 transition-colors group-hover:text-white/60" />
                  </a>
                </li>
                <li>
                  <a
                    href="#sdks"
                    className="group flex items-center gap-3 rounded-lg border border-border-soft bg-bg-soft px-4 py-3 transition-colors hover:border-brand-500/40 hover:bg-bg-elevated"
                  >
                    <Terminal className="h-4 w-4 text-brand-400" />
                    <span className="text-sm font-medium text-white/80 group-hover:text-white">
                      SDKs &amp; examples
                    </span>
                    <ArrowRight className="ml-auto h-4 w-4 text-white/25 transition-colors group-hover:text-white/60" />
                  </a>
                </li>
              </ul>
            </CardBody>
          </Card>
        </nav>

        {/* Quickstart */}
        <section id="quickstart" className="mt-16 scroll-mt-24">
          <h2 className="text-2xl font-bold tracking-tight text-white">Quickstart</h2>
          <p className="mt-2 max-w-3xl text-sm leading-relaxed text-white/60">
            Go from zero to your first authenticated request in four steps.
          </p>

          <ol className="mt-6 space-y-4">
            {[
              {
                title: "Create an account and an app",
                body: (
                  <>
                    <Link href="/register" className="text-brand-400 hover:text-brand-300">
                      Register
                    </Link>{" "}
                    for a seller account, then create your first application from the dashboard.
                  </>
                ),
              },
              {
                title: "Copy your app_id and secret",
                body: (
                  <>
                    Open the app's settings to grab its{" "}
                    <code className="font-mono text-white/80">app_id</code> and{" "}
                    <code className="font-mono text-white/80">secret</code>. Keep the secret out of
                    plain sight in your distributed client.
                  </>
                ),
              },
              {
                title: "Generate license keys",
                body: (
                  <>
                    Use the Keys page to generate one or more license keys, choosing their level and
                    duration. These are what your users redeem to register.
                  </>
                ),
              },
              {
                title: "Call the API from your software",
                body: <>Start by calling <code className="font-mono text-white/80">/api/v1/init</code> when your app launches.</>,
              },
            ].map((step, i) => (
              <li key={i} className="flex gap-4">
                <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full border border-brand-500/40 bg-brand-500/10 text-sm font-semibold text-brand-300">
                  {i + 1}
                </span>
                <div className="pt-1">
                  <h3 className="text-sm font-semibold text-white">{step.title}</h3>
                  <p className="mt-1 text-sm leading-relaxed text-white/60">{step.body}</p>
                </div>
              </li>
            ))}
          </ol>

          <div className="mt-8 space-y-2">
            <h3 className="text-sm font-semibold text-white">Your first request</h3>
            <p className="text-sm text-white/60">
              A simple <code className="font-mono text-white/80">init</code> call with{" "}
              <code className="font-mono text-white/80">curl</code>:
            </p>
            <CodeBlock language="bash" code={CURL_INIT} />
          </div>
        </section>

        {/* API reference */}
        <section id="api" className="mt-16 scroll-mt-24">
          <h2 className="text-2xl font-bold tracking-tight text-white">API reference</h2>
          <p className="mt-2 max-w-3xl text-sm leading-relaxed text-white/60">
            All endpoints are <span className="text-white/80">POST</span> and return JSON. The token
            returned by register, login, and license is what you replay to{" "}
            <code className="font-mono text-white/80">/api/v1/verify</code> on subsequent launches.
          </p>

          <div className="mt-6 space-y-8">
            {ENDPOINTS.map((ep) => (
              <EndpointCard key={ep.id} ep={ep} />
            ))}
          </div>
        </section>

        {/* Errors */}
        <section id="errors" className="mt-16 scroll-mt-24">
          <h2 className="text-2xl font-bold tracking-tight text-white">Error codes</h2>
          <p className="mt-2 max-w-3xl text-sm leading-relaxed text-white/60">
            When <code className="font-mono text-white/80">success</code> is{" "}
            <code className="font-mono text-white/80">false</code>, the{" "}
            <code className="font-mono text-white/80">code</code> field tells you exactly what went
            wrong so your client can react appropriately.
          </p>

          <Card className="mt-6">
            <CardBody className="p-0">
              <Table>
                <THead>
                  <TR>
                    <TH>Code</TH>
                    <TH>HTTP</TH>
                    <TH className="w-2/3">Meaning</TH>
                  </TR>
                </THead>
                <TBody>
                  {ERRORS.map((e) => (
                    <TR key={e.code}>
                      <TD className="font-mono text-white/90">{e.code}</TD>
                      <TD>
                        <Badge
                          tone={e.status === 429 ? "warning" : e.status === 422 ? "info" : "danger"}
                        >
                          {e.status}
                        </Badge>
                      </TD>
                      <TD className="text-white/60">{e.meaning}</TD>
                    </TR>
                  ))}
                </TBody>
              </Table>
            </CardBody>
          </Card>
        </section>

        {/* SDKs */}
        <section id="sdks" className="mt-16 scroll-mt-24">
          <h2 className="text-2xl font-bold tracking-tight text-white">SDKs &amp; examples</h2>
          <p className="mt-2 max-w-3xl text-sm leading-relaxed text-white/60">
            Because the API is plain JSON over HTTPS, you can call it from any language. Ready-made
            example clients live in the{" "}
            <code className="font-mono text-white/80">examples/</code> folder of the project:
          </p>

          <div className="mt-6 grid gap-4 sm:grid-cols-3">
            {[
              { lang: "Python", file: "examples/python", desc: "A requests-based client." },
              { lang: "JavaScript", file: "examples/javascript", desc: "A fetch-based client for Node or the browser." },
              { lang: "C#", file: "examples/csharp", desc: "An HttpClient-based client for .NET loaders." },
            ].map((s) => (
              <Card key={s.lang}>
                <CardBody>
                  <div className="flex items-center gap-2">
                    <Code2 className="h-4 w-4 text-brand-400" />
                    <h3 className="text-sm font-semibold text-white">{s.lang}</h3>
                  </div>
                  <p className="mt-2 font-mono text-xs text-white/40">{s.file}</p>
                  <p className="mt-2 text-sm text-white/60">{s.desc}</p>
                </CardBody>
              </Card>
            ))}
          </div>

          <div className="mt-8 space-y-2">
            <h3 className="text-sm font-semibold text-white">JavaScript: logging in</h3>
            <p className="text-sm text-white/60">
              A minimal <code className="font-mono text-white/80">fetch</code> call to authenticate a
              user and capture their session token:
            </p>
            <CodeBlock language="javascript" code={JS_LOGIN} />
          </div>

          <div className="mt-10 flex flex-col items-start gap-3 rounded-xl border border-border bg-bg-soft px-6 py-6 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <h3 className="text-base font-semibold text-white">Ready to build?</h3>
              <p className="mt-1 text-sm text-white/60">
                Create your first app and start issuing license keys in minutes.
              </p>
            </div>
            <Link
              href="/register"
              className="inline-flex items-center gap-2 rounded-lg bg-brand-500 px-4 py-2 text-sm font-semibold text-black transition-colors hover:bg-brand-400"
            >
              Get started
              <ArrowRight className="h-4 w-4" />
            </Link>
          </div>
        </section>
      </main>

      <Footer />
    </div>
  );
}
