import { ok, handler, unauthorized } from "@/lib/api";
import { getSeller } from "@/lib/seller-session";
import { toPublicSeller } from "@/lib/types";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export const GET = handler(async () => {
  const s = await getSeller();
  if (!s) return unauthorized();
  return ok(toPublicSeller(s));
});
