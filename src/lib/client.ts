"use client";

// Tiny fetch wrapper used by dashboard client components to talk to the
// dashboard API. Throws `ApiClientError` on any non-success response.

export class ApiClientError extends Error {
  status: number;
  code?: string;
  constructor(message: string, status: number, code?: string) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

async function request<T>(method: string, url: string, body?: unknown): Promise<T> {
  const res = await fetch(url, {
    method,
    headers: body !== undefined ? { "Content-Type": "application/json" } : undefined,
    body: body !== undefined ? JSON.stringify(body) : undefined,
    cache: "no-store",
  });

  let json: any = null;
  try {
    json = await res.json();
  } catch {
    /* empty / non-json body */
  }

  if (!res.ok || (json && json.success === false)) {
    const message = json?.message || `Request failed (${res.status})`;
    throw new ApiClientError(message, res.status, json?.code);
  }
  return (json?.data ?? json) as T;
}

export const api = {
  get: <T>(url: string) => request<T>("GET", url),
  post: <T>(url: string, body?: unknown) => request<T>("POST", url, body),
  patch: <T>(url: string, body?: unknown) => request<T>("PATCH", url, body),
  del: <T>(url: string, body?: unknown) => request<T>("DELETE", url, body),
};
