import { clientIp, handler, ok, readJson, tooMany } from "@/lib/api";
import { rateLimit } from "@/lib/ratelimit";
import { clientLicenseSchema } from "@/lib/validation";
import { authApp, licenseFlow } from "@/lib/auth-service";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export const POST = handler(async (req) => {
  const ip = clientIp(req);
  const rl = rateLimit("v1:license:" + ip, 20, 60000);
  if (!rl.allowed) return tooMany();

  const body = clientLicenseSchema.parse(await readJson(req));
  const app = authApp(body.app_id, body.secret);
  const ctx = { ip };

  const result = await licenseFlow(
    app,
    {
      key: body.key,
      hwid: body.hwid,
    },
    ctx,
  );
  return ok(undefined, result);
});
