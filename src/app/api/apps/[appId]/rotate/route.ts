import { ok, notFound, handler } from "@/lib/api";
import { requireSeller } from "@/lib/seller-session";
import { getOwnedApp, rotateAppSecret } from "@/lib/repo/apps";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export const POST = handler(async (_req, { params }) => {
  const seller = await requireSeller();
  if (!getOwnedApp(params.appId, seller.id)) return notFound();
  const secret = rotateAppSecret(params.appId);
  return ok({ secret });
});
