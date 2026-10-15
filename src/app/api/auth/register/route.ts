import { created, handler, readJson, ApiError } from "@/lib/api";
import { registerSellerSchema } from "@/lib/validation";
import { getSellerByUsername, getSellerByEmail, createSeller } from "@/lib/repo/sellers";
import { createSellerSession } from "@/lib/seller-session";
import { toPublicSeller } from "@/lib/types";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export const POST = handler(async (req) => {
  const { username, email, password } = registerSellerSchema.parse(await readJson(req));

  if (getSellerByUsername(username)) {
    throw new ApiError("Username already taken", 409, "username_taken");
  }
  if (getSellerByEmail(email)) {
    throw new ApiError("Email already registered", 409, "email_taken");
  }

  const seller = await createSeller({ username, email, password });
  await createSellerSession(seller);

  return created(toPublicSeller(seller));
});
