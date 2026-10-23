import { ok, handler } from "@/lib/api";
import { destroySellerSession } from "@/lib/seller-session";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export const POST = handler(async () => {
  destroySellerSession();
  return ok({});
});
