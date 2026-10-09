import { ok, notFound, handler } from "@/lib/api";
import { requireSeller } from "@/lib/seller-session";
import { getOwnedApp } from "@/lib/repo/apps";
import { listSessionsByApp, pruneSessions } from "@/lib/repo/sessions";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export const GET = handler(async (req) => {
  const seller = await requireSeller();
  const appId = new URL(req.url).searchParams.get("app");
  if (!appId || !getOwnedApp(appId, seller.id)) return notFound();
  return ok(listSessionsByApp(appId));
});

export const DELETE = handler(async (req) => {
  const seller = await requireSeller();
  const appId = new URL(req.url).searchParams.get("app");
  if (!appId || !getOwnedApp(appId, seller.id)) return notFound();
  const n = pruneSessions(appId);
  return ok({ pruned: n });
});
