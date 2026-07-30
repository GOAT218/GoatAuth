import { ok, notFound, handler } from "@/lib/api";
import { requireSeller } from "@/lib/seller-session";
import { getOwnedApp } from "@/lib/repo/apps";
import { getSessionById, killSession } from "@/lib/repo/sessions";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export const DELETE = handler(async (req, { params }) => {
  const seller = await requireSeller();
  const s = getSessionById(params.sessionId);
  if (!s || !getOwnedApp(s.app_id, seller.id)) return notFound();
  killSession(s.id);
  return ok({});
});
