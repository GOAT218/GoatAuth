import { NextResponse } from "next/server";
import { ZodError } from "zod";

// Consistent JSON response envelope for both the dashboard API and the
// client authentication API (/api/v1/*).

export interface ApiOk<T = unknown> {
  success: true;
  message?: string;
  data?: T;
  [key: string]: unknown;
}

export interface ApiErr {
  success: false;
  message: string;
  code?: string;
}

export function ok<T>(data?: T, extra: object = {}): NextResponse {
  const body: ApiOk<T> = { success: true, ...extra };
  if (data !== undefined) body.data = data;
  return NextResponse.json(body, { status: 200 });
}

export function created<T>(data?: T, extra: object = {}): NextResponse {
  const body: ApiOk<T> = { success: true, ...extra };
  if (data !== undefined) body.data = data;
  return NextResponse.json(body, { status: 201 });
}

export function fail(message: string, status = 400, code?: string): NextResponse {
  const body: ApiErr = { success: false, message };
  if (code) body.code = code;
  return NextResponse.json(body, { status });
}

export const unauthorized = (m = "Not authenticated") => fail(m, 401, "unauthorized");
export const forbidden = (m = "Forbidden") => fail(m, 403, "forbidden");
export const notFound = (m = "Not found") => fail(m, 404, "not_found");
export const tooMany = (m = "Rate limit exceeded") => fail(m, 429, "rate_limited");

/** Wrap a route handler with uniform error handling. */
// `ctx` is typed loosely so Next.js's generated route type-checks accept the
// wrapped export for both static and dynamic ([param]) route segments.
export function handler(
  fn: (req: Request, ctx: { params: Record<string, string> }) => Promise<NextResponse>,
) {
  return async (req: Request, ctx: any): Promise<NextResponse> => {
    try {
      return await fn(req, { params: ctx?.params ?? {} });
    } catch (err) {
      if (err instanceof ZodError) {
        const first = err.errors[0];
        return fail(first ? `${first.path.join(".")}: ${first.message}` : "Invalid request", 422, "validation");
      }
      if (err instanceof ApiError) {
        return fail(err.message, err.status, err.code);
      }
      console.error("[api] unhandled error:", err);
      return fail("Internal server error", 500, "internal");
    }
  };
}

/** Throwable error that `handler` converts into a JSON response. */
export class ApiError extends Error {
  status: number;
  code?: string;
  constructor(message: string, status = 400, code?: string) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

/** Parse a JSON body, tolerating empty bodies. */
export async function readJson<T = Record<string, unknown>>(req: Request): Promise<T> {
  try {
    const text = await req.text();
    if (!text) return {} as T;
    return JSON.parse(text) as T;
  } catch {
    throw new ApiError("Malformed JSON body", 400, "bad_json");
  }
}

/**
 * Client IP extraction for security-sensitive use (rate limiting, blacklist).
 *
 * X-Forwarded-For is a comma-separated list where each proxy APPENDS the address
 * it received the request from. The leftmost entry is therefore client-supplied
 * and trivially spoofable; only the entries appended by our own trusted proxies
 * can be relied on. We take the address `GOATAUTH_TRUSTED_PROXY_HOPS` positions
 * from the right (default 1 = a single reverse proxy in front of the app), which
 * ignores any values the client injected further left.
 */
export function clientIp(req: Request): string {
  const hops = Math.max(0, Number.parseInt(process.env.GOATAUTH_TRUSTED_PROXY_HOPS ?? "1", 10) || 0);
  const xff = req.headers.get("x-forwarded-for");
  if (xff) {
    const list = xff
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean);
    if (list.length > 0) {
      const idx = Math.min(Math.max(list.length - hops, 0), list.length - 1);
      return list[idx];
    }
  }
  return req.headers.get("x-real-ip") || req.headers.get("cf-connecting-ip") || "0.0.0.0";
}
