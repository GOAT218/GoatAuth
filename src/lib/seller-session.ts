import { cookies } from "next/headers";
import { ApiError } from "./api";
import { db } from "./db";
import type { Seller } from "./types";
import {
  SELLER_COOKIE,
  SELLER_MAX_AGE_SECONDS,
  signSellerToken,
  verifySellerToken,
} from "./seller-token";

export { SELLER_COOKIE, signSellerToken, verifySellerToken };

/** Establish a session cookie for a seller (call from a route handler). */
export async function createSellerSession(seller: Seller): Promise<void> {
  const token = await signSellerToken({ sub: seller.id, username: seller.username });
  cookies().set(SELLER_COOKIE, token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: SELLER_MAX_AGE_SECONDS,
  });
}

export function destroySellerSession(): void {
  cookies().set(SELLER_COOKIE, "", { httpOnly: true, path: "/", maxAge: 0 });
}

/** Read the current seller from the session cookie, or null. */
export async function getSeller(): Promise<Seller | null> {
  const token = cookies().get(SELLER_COOKIE)?.value;
  if (!token) return null;
  const payload = await verifySellerToken(token);
  if (!payload) return null;
  const seller = db
    .prepare("SELECT * FROM sellers WHERE id = ?")
    .get(payload.sub) as Seller | undefined;
  return seller ?? null;
}

/** Require an authenticated seller or throw a 401. */
export async function requireSeller(): Promise<Seller> {
  const seller = await getSeller();
  if (!seller) throw new ApiError("Not authenticated", 401, "unauthorized");
  return seller;
}
