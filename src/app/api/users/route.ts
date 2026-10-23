import { requireSeller } from "@/lib/seller-session";
import { handler, ok, notFound } from "@/lib/api";
import { getOwnedApp } from "@/lib/repo/apps";
import { listUsersByApp } from "@/lib/repo/users";
import { toPublicAppUser } from "@/lib/types";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export const GET = handler(async (req) => {
  const seller = await requireSeller();
  const appId = new URL(req.url).searchParams.get("app");
  if (!appId || !getOwnedApp(appId, seller.id)) return notFound();
  // Strip password hashes before sending user rows to the browser.
  return ok(listUsersByApp(appId).map(toPublicAppUser));
});
