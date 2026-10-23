import { ok, created, notFound, handler, readJson } from "@/lib/api";
import { requireSeller } from "@/lib/seller-session";
import { getOwnedApp } from "@/lib/repo/apps";
import { listVariablesByApp, upsertVariable } from "@/lib/repo/variables";
import { createVariableSchema } from "@/lib/validation";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export const GET = handler(async (req) => {
  const seller = await requireSeller();
  const appId = new URL(req.url).searchParams.get("app");
  if (!appId || !getOwnedApp(appId, seller.id)) return notFound();
  return ok(listVariablesByApp(appId));
});

export const POST = handler(async (req) => {
  const seller = await requireSeller();
  const body = createVariableSchema.parse(await readJson(req));
  if (!getOwnedApp(body.app_id, seller.id)) return notFound();
  const variable = upsertVariable({
    appId: body.app_id,
    name: body.name,
    value: body.value,
    secret: body.secret,
  });
  return created(variable);
});
