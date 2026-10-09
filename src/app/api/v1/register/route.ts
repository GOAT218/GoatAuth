import { clientIp, handler, ok, readJson, tooMany } from "@/lib/api";
import { rateLimit } from "@/lib/ratelimit";
import { clientRegisterSchema } from "@/lib/validation";
import { authApp, registerFlow } from "@/lib/auth-service";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export const POST = handler(async (req) => {
  const ip = clientIp(req);
  const rl = rateLimit("v1:register:" + ip, 10, 60000);
  if (!rl.allowed) return tooMany();

  const body = clientRegisterSchema.parse(await readJson(req));
  const app = authApp(body.app_id, body.secret);
  const ctx = { ip };

  const result = await registerFlow(
    app,
    {
      username: body.username,
      password: body.password,
      key: body.key,
      email: body.email,
      hwid: body.hwid,
    },
    ctx,
  );
  return ok(undefined, result);
});
