import { requireSeller } from "@/lib/seller-session";
import { ok, created, fail, notFound, handler, readJson } from "@/lib/api";
import { createKeysSchema } from "@/lib/validation";
import { getOwnedApp } from "@/lib/repo/apps";
import { listKeysByApp, createKeys, deleteUnusedKeys } from "@/lib/repo/keys";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export const GET = handler(async (req) => {
  const seller = await requireSeller();
  const appId = new URL(req.url).searchParams.get("app");
  if (!appId || !getOwnedApp(appId, seller.id)) return notFound();
  return ok(listKeysByApp(appId));
});

export const POST = handler(async (req) => {
  const seller = await requireSeller();
  const body = createKeysSchema.parse(await readJson(req));
  if (!getOwnedApp(body.app_id, seller.id)) return notFound();

  const keys = createKeys({
    appId: body.app_id,
    amount: body.amount,
    durationDays: body.duration_days,
    level: body.level,
    maxUses: body.max_uses,
    note: body.note,
    createdBy: seller.id,
    format: { mask: body.mask, prefix: body.prefix },
  });
  return created(keys);
});

export const DELETE = handler(async (req) => {
  const seller = await requireSeller();
  const url = new URL(req.url);
  const appId = url.searchParams.get("app");
  if (!appId || !getOwnedApp(appId, seller.id)) return notFound();
  if (url.searchParams.get("unused") === "1") {
    const n = deleteUnusedKeys(appId);
    return ok({ deleted: n });
  }
  return fail("Specify unused=1 to bulk delete", 400);
});
