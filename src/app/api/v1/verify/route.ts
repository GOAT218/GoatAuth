import { handler, ok, readJson, clientIp, tooMany } from "@/lib/api";
import { rateLimit } from "@/lib/ratelimit";
import { clientVerifySchema } from "@/lib/validation";
import { authApp, verifyFlow } from "@/lib/auth-service";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export const POST = handler(async (req) => {
  const ip = clientIp(req);
  const ctx = { ip };

  const limit = rateLimit("v1:verify:" + ip, 120, 60000);
  if (!limit.allowed) return tooMany();

  const body = clientVerifySchema.parse(await readJson(req));
  const app = authApp(body.app_id, body.secret);

  const result = await verifyFlow(app, { token: body.token, hwid: body.hwid }, ctx);
  return ok(undefined, result);
});
