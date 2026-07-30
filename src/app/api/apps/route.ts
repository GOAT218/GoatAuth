import { ok, created, handler, readJson } from "@/lib/api";
import { requireSeller } from "@/lib/seller-session";
import { createAppSchema } from "@/lib/validation";
import { createApp, listAppsBySeller } from "@/lib/repo/apps";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export const GET = handler(async () => {
  const seller = await requireSeller();
  return ok(listAppsBySeller(seller.id));
});

export const POST = handler(async (req) => {
  const seller = await requireSeller();
  const body = createAppSchema.parse(await readJson(req));
  const app = createApp({ sellerId: seller.id, name: body.name, version: body.version });
  return created(app);
});
