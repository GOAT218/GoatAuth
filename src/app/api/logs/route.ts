import { ok, notFound, handler } from "@/lib/api";
import { requireSeller } from "@/lib/seller-session";
import { getOwnedApp } from "@/lib/repo/apps";
import { listLogsByApp, listRecentLogsBySeller } from "@/lib/repo/logs";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export const GET = handler(async (req) => {
  const seller = await requireSeller();
  const appId = new URL(req.url).searchParams.get("app");
  if (appId) {
    if (!getOwnedApp(appId, seller.id)) return notFound();
    return ok(listLogsByApp(appId));
  }
  return ok(listRecentLogsBySeller(seller.id, 20));
});
