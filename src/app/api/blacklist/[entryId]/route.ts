import { ok, notFound, handler } from "@/lib/api";
import { requireSeller } from "@/lib/seller-session";
import { getOwnedApp } from "@/lib/repo/apps";
import { removeBlacklist } from "@/lib/repo/blacklist";
import { db } from "@/lib/db";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export const DELETE = handler(async (req, { params }) => {
  const seller = await requireSeller();
  const row = db
    .prepare("SELECT * FROM blacklist WHERE id = ?")
    .get(params.entryId) as { app_id: string } | undefined;
  if (!row || !getOwnedApp(row.app_id, seller.id)) return notFound();
  removeBlacklist(params.entryId);
  return ok({});
});
