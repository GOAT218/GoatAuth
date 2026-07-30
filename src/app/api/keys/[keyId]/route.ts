import { requireSeller } from "@/lib/seller-session";
import { ok, notFound, handler, readJson } from "@/lib/api";
import { getOwnedApp } from "@/lib/repo/apps";
import { getKeyById, setKeyStatus, deleteKey } from "@/lib/repo/keys";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export const PATCH = handler(async (req, { params }) => {
  const seller = await requireSeller();
  const k = getKeyById(params.keyId);
  if (!k || !getOwnedApp(k.app_id, seller.id)) return notFound();
  const body = await readJson<{ status?: "unused" | "used" | "banned" }>(req);
  if (body.status) setKeyStatus(k.id, body.status);
  return ok(getKeyById(k.id));
});

export const DELETE = handler(async (req, { params }) => {
  const seller = await requireSeller();
  const k = getKeyById(params.keyId);
  if (!k || !getOwnedApp(k.app_id, seller.id)) return notFound();
  deleteKey(k.id);
  return ok({});
});
