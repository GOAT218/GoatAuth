import { clientIp, handler, ok, readJson, tooMany } from "@/lib/api";
import { rateLimit } from "@/lib/ratelimit";
import { clientLoginSchema } from "@/lib/validation";
import { authApp, loginFlow } from "@/lib/auth-service";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export const POST = handler(async (req) => {
  const ip = clientIp(req);
  const rl = rateLimit("v1:login:" + ip, 20, 60000);
  if (!rl.allowed) return tooMany();

  const body = clientLoginSchema.parse(await readJson(req));
  const app = authApp(body.app_id, body.secret);
  const ctx = { ip };

  const result = await loginFlow(
    app,
    {
      username: body.username,
      password: body.password,
      hwid: body.hwid,
    },
    ctx,
  );
  return ok(undefined, result);
});
