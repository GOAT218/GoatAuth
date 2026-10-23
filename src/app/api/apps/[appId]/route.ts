import { ok, notFound, handler, readJson } from "@/lib/api";
import { requireSeller } from "@/lib/seller-session";
import { updateAppSchema } from "@/lib/validation";
import { getAppById, getOwnedApp, updateApp, deleteApp } from "@/lib/repo/apps";
import type { App } from "@/lib/types";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export const GET = handler(async (_req, { params }) => {
  const seller = await requireSeller();
  const app = getOwnedApp(params.appId, seller.id);
  if (!app) return notFound();
  return ok(app);
});

export const PATCH = handler(async (req, { params }) => {
  const seller = await requireSeller();
  const owned = getOwnedApp(params.appId, seller.id);
  if (!owned) return notFound();

  const body = updateAppSchema.parse(await readJson(req));

  const fields: Partial<Pick<App, "name" | "version" | "status" | "hwid_lock" | "download_url">> = {};
  if (body.name !== undefined) fields.name = body.name;
  if (body.version !== undefined) fields.version = body.version;
  if (body.status !== undefined) fields.status = body.status;
  if (body.hwid_lock !== undefined) fields.hwid_lock = body.hwid_lock ? 1 : 0;
  if (body.download_url !== undefined) fields.download_url = body.download_url;

  updateApp(params.appId, fields);
  return ok(getAppById(params.appId));
});

export const DELETE = handler(async (_req, { params }) => {
  const seller = await requireSeller();
  const owned = getOwnedApp(params.appId, seller.id);
  if (!owned) return notFound();
  deleteApp(params.appId);
  return ok({});
});
