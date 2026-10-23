import { NextResponse, type NextRequest } from "next/server";
import { verifySellerToken, SELLER_COOKIE } from "@/lib/seller-token";

// Protects /dashboard/* — unauthenticated visitors are redirected to /login.
// Runs on the Edge runtime, so it only uses jose (no better-sqlite3 imports).

export async function middleware(req: NextRequest) {
  const token = req.cookies.get(SELLER_COOKIE)?.value;
  const valid = token ? await verifySellerToken(token) : null;

  if (!valid) {
    const url = req.nextUrl.clone();
    url.pathname = "/login";
    url.searchParams.set("next", req.nextUrl.pathname);
    return NextResponse.redirect(url);
  }
  return NextResponse.next();
}

export const config = {
  matcher: ["/dashboard/:path*"],
};
