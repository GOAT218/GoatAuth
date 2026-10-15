import { ok, created, notFound, handler, readJson } from "@/lib/api";
import { requireSeller } from "@/lib/seller-session";
import { getOwnedApp } from "@/lib/repo/apps";
import { listBlacklistByApp, addBlacklist } from "@/lib/repo/blacklist";
import { createBlacklistSchema } from "@/lib/validation";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export const GET = handler(async (req) => {
  const seller = await requireSeller();
  const appId = new URL(req.url).searchParams.get("app");
  if (!appId || !getOwnedApp(appId, seller.id)) return notFound();
  return ok(listBlacklistByApp(appId));
});

export const POST = handler(async (req) => {
  const seller = await requireSeller();
  const body = createBlacklistSchema.parse(await readJson(req));
  if (!getOwnedApp(body.app_id, seller.id)) return notFound();
  const entry = addBlacklist({
    appId: body.app_id,
    type: body.type,
    value: body.value,
    reason: body.reason,
  });
  return created(entry);
});
