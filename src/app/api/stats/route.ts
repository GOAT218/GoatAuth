import { ok, notFound, handler } from "@/lib/api";
import { requireSeller } from "@/lib/seller-session";
import { getOwnedApp } from "@/lib/repo/apps";
import { statsForApp, statsForSeller } from "@/lib/repo/stats";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export const GET = handler(async (req) => {
  const seller = await requireSeller();
  const appId = new URL(req.url).searchParams.get("app");
  if (appId) {
    if (!getOwnedApp(appId, seller.id)) return notFound();
    return ok(statsForApp(appId));
  }
  return ok(statsForSeller(seller.id));
});
