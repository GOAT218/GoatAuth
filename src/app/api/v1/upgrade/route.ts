import { handler, ok, readJson, clientIp, tooMany } from "@/lib/api";
import { rateLimit } from "@/lib/ratelimit";
import { clientUpgradeSchema } from "@/lib/validation";
import { authApp, upgradeFlow } from "@/lib/auth-service";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export const POST = handler(async (req) => {
  const ip = clientIp(req);
  const ctx = { ip };

  const limit = rateLimit("v1:upgrade:" + ip, 10, 60000);
  if (!limit.allowed) return tooMany();

  const body = clientUpgradeSchema.parse(await readJson(req));
  const app = authApp(body.app_id, body.secret);

  const result = upgradeFlow(app, { username: body.username, key: body.key }, ctx);
  return ok(undefined, result);
});
