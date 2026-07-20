import { ok, handler, readJson, clientIp, tooMany, ApiError } from "@/lib/api";
import { loginSellerSchema } from "@/lib/validation";
import { getSellerByUsername, touchSellerLogin } from "@/lib/repo/sellers";
import { createSellerSession } from "@/lib/seller-session";
import { DUMMY_PASSWORD_HASH, verifyPassword } from "@/lib/crypto";
import { rateLimit } from "@/lib/ratelimit";
import { toPublicSeller } from "@/lib/types";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export const POST = handler(async (req) => {
  const { username, password } = loginSellerSchema.parse(await readJson(req));

  const limit = rateLimit("seller-login:" + clientIp(req), 10, 60000);
  if (!limit.allowed) return tooMany();

  const seller = getSellerByUsername(username);
  // Always run a real bcrypt comparison (against a dummy hash when the account
  // is missing) so response time can't reveal whether a username exists.
  const valid = await verifyPassword(password, seller?.password_hash ?? DUMMY_PASSWORD_HASH);
  if (!seller || !valid) {
    throw new ApiError("Invalid username or password", 401, "bad_credentials");
  }

  touchSellerLogin(seller.id);
  await createSellerSession(seller);

  return ok(toPublicSeller(seller));
});
