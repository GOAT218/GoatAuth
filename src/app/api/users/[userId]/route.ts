import { requireSeller } from "@/lib/seller-session";
import { handler, ok, notFound, readJson } from "@/lib/api";
import { getOwnedApp } from "@/lib/repo/apps";
import {
  getUserById,
  setUserBan,
  setUserSubscription,
  updateUserExpiry,
  setUserHwid,
  deleteUser,
} from "@/lib/repo/users";
import { updateUserSchema } from "@/lib/validation";
import { toPublicAppUser } from "@/lib/types";
import { killSessionsForUser } from "@/lib/repo/sessions";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export const PATCH = handler(async (req, { params }) => {
  const seller = await requireSeller();
  const u = getUserById(params.userId);
  if (!u || !getOwnedApp(u.app_id, seller.id)) return notFound();

  const body = updateUserSchema.parse(await readJson(req));

  if (body.banned !== undefined) {
    setUserBan(u.id, body.banned, body.ban_reason ?? undefined);
    // Revoke active sessions immediately when banning, so a currently
    // logged-in user loses access without waiting for their token to expire.
    if (body.banned) killSessionsForUser(u.id);
  }
  if (body.level !== undefined) setUserSubscription(u.id, body.level, getUserById(u.id)!.expires_at);
  if (body.expires_at !== undefined) updateUserExpiry(u.id, body.expires_at);
  if (body.reset_hwid) setUserHwid(u.id, null);

  const updated = getUserById(u.id);
  return ok(updated ? toPublicAppUser(updated) : null);
});

export const DELETE = handler(async (req, { params }) => {
  const seller = await requireSeller();
  const u = getUserById(params.userId);
  if (!u || !getOwnedApp(u.app_id, seller.id)) return notFound();
  deleteUser(u.id);
  return ok({});
});
