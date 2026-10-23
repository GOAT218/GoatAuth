import { clientIp, handler, ok, readJson, tooMany } from "@/lib/api";
import { rateLimit } from "@/lib/ratelimit";
import { clientInitSchema } from "@/lib/validation";
import { authApp, initFlow } from "@/lib/auth-service";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export const POST = handler(async (req) => {
  const ip = clientIp(req);
  const rl = rateLimit("v1:init:" + ip, 60, 60000);
  if (!rl.allowed) return tooMany();

  const body = clientInitSchema.parse(await readJson(req));
  const app = authApp(body.app_id, body.secret);
  const ctx = { ip };

  const result = initFlow(app, ctx, body.version);
  return ok(undefined, result);
});
