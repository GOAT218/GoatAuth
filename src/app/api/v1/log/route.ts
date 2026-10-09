import { handler, ok, readJson, clientIp, tooMany } from "@/lib/api";
import { rateLimit } from "@/lib/ratelimit";
import { clientLogSchema } from "@/lib/validation";
import { authApp, logMessage } from "@/lib/auth-service";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export const POST = handler(async (req) => {
  const ip = clientIp(req);
  const ctx = { ip };

  const limit = rateLimit("v1:log:" + ip, 60, 60000);
  if (!limit.allowed) return tooMany();

  const body = clientLogSchema.parse(await readJson(req));
  const app = authApp(body.app_id, body.secret);

  logMessage(app, body.message, ctx, body.username);
  return ok(undefined, { logged: true });
});
