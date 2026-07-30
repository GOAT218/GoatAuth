import { handler, ok, readJson, clientIp, tooMany } from "@/lib/api";
import { rateLimit } from "@/lib/ratelimit";
import { clientVarSchema } from "@/lib/validation";
import { authApp, readVariable } from "@/lib/auth-service";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export const POST = handler(async (req) => {
  const ip = clientIp(req);
  const ctx = { ip };
  void ctx;

  const limit = rateLimit("v1:var:" + ip, 120, 60000);
  if (!limit.allowed) return tooMany();

  const body = clientVarSchema.parse(await readJson(req));
  const app = authApp(body.app_id, body.secret);

  const value = await readVariable(app, { name: body.name, token: body.token });
  return ok(undefined, { name: body.name, value });
});
