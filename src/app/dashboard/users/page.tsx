"use client";

import * as React from "react";
import {
  Search,
  MoreHorizontal,
  Ban,
  ShieldCheck,
  Trash2,
  RefreshCw,
  Users,
} from "lucide-react";
import { api, ApiClientError } from "@/lib/client";
import { useToast } from "@/components/ui/Toast";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Badge } from "@/components/ui/Badge";
import { Input, Field, Textarea } from "@/components/ui/Input";
import { Modal } from "@/components/ui/Modal";
import { Spinner, EmptyState } from "@/components/ui/Misc";
import { Table, THead, TBody, TR, TH, TD } from "@/components/ui/Table";
import { AppScope } from "@/components/dashboard/AppScope";
import { formatExpiry, relativeTime } from "@/lib/format";
import type { AppUser } from "@/lib/types";

export default function UsersPage() {
  return (
    <AppScope
      title="Users"
      description="People who have registered or activated a license in your application."
    >
      {(appId) => <UsersPanel appId={appId} />}
    </AppScope>
  );
}

function errMessage(err: unknown, fallback: string): string {
  return err instanceof ApiClientError ? err.message : fallback;
}

function SubscriptionCell({ user }: { user: AppUser }) {
  if (user.expires_at === null) {
    return <Badge tone="success">Lifetime</Badge>;
  }
  if (user.expires_at <= Date.now()) {
    return <Badge tone="danger">Expired</Badge>;
  }
  return <span className="text-white/80">{formatExpiry(user.expires_at)}</span>;
}

function UsersPanel({ appId }: { appId: string }) {
  const { success, error: toastError } = useToast();

  const [loading, setLoading] = React.useState(true);
  const [users, setUsers] = React.useState<AppUser[]>([]);
  const [query, setQuery] = React.useState("");

  // Ban modal state
  const [banTarget, setBanTarget] = React.useState<AppUser | null>(null);
  const [banReason, setBanReason] = React.useState("");
  const [banning, setBanning] = React.useState(false);

  // Delete modal state
  const [deleteTarget, setDeleteTarget] = React.useState<AppUser | null>(null);
  const [deleting, setDeleting] = React.useState(false);

  // Track in-flight per-row actions (reset hwid, unban) to disable buttons
  const [busyId, setBusyId] = React.useState<string | null>(null);

  React.useEffect(() => {
    let active = true;
    setLoading(true);
    (async () => {
      try {
        const list = await api.get<AppUser[]>("/api/users?app=" + appId);
        if (!active) return;
        setUsers(list);
      } catch (err) {
        if (!active) return;
        toastError(errMessage(err, "Failed to load users"));
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [appId, toastError]);

  const filtered = React.useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return users;
    return users.filter((u) => u.username.toLowerCase().includes(q));
  }, [users, query]);

  function patchLocal(id: string, fields: Partial<AppUser>) {
    setUsers((prev) => prev.map((u) => (u.id === id ? { ...u, ...fields } : u)));
  }

  async function handleResetHwid(user: AppUser) {
    setBusyId(user.id);
    try {
      await api.patch("/api/users/" + user.id, { reset_hwid: true });
      patchLocal(user.id, { hwid: null });
      success("HWID reset");
    } catch (err) {
      toastError(errMessage(err, "Failed to reset HWID"));
    } finally {
      setBusyId(null);
    }
  }

  async function handleUnban(user: AppUser) {
    setBusyId(user.id);
    try {
      await api.patch("/api/users/" + user.id, { banned: false });
      patchLocal(user.id, { banned: 0, ban_reason: null });
      success("User unbanned");
    } catch (err) {
      toastError(errMessage(err, "Failed to unban user"));
    } finally {
      setBusyId(null);
    }
  }

  function openBan(user: AppUser) {
    setBanReason("");
    setBanTarget(user);
  }

  async function handleBan(e: React.FormEvent) {
    e.preventDefault();
    if (!banTarget) return;
    setBanning(true);
    const reason = banReason.trim();
    try {
      await api.patch("/api/users/" + banTarget.id, {
        banned: true,
        ban_reason: reason || undefined,
      });
      patchLocal(banTarget.id, { banned: 1, ban_reason: reason || null });
      success("User banned");
      setBanTarget(null);
    } catch (err) {
      toastError(errMessage(err, "Failed to ban user"));
    } finally {
      setBanning(false);
    }
  }

  async function handleDelete() {
    if (!deleteTarget) return;
    setDeleting(true);
    try {
      await api.del("/api/users/" + deleteTarget.id);
      setUsers((prev) => prev.filter((u) => u.id !== deleteTarget.id));
      success("User deleted");
      setDeleteTarget(null);
    } catch (err) {
      toastError(errMessage(err, "Failed to delete user"));
    } finally {
      setDeleting(false);
    }
  }

  if (loading) {
    return (
      <div className="flex min-h-[40vh] items-center justify-center">
        <Spinner className="h-6 w-6" />
      </div>
    );
  }

  return (
    <div className="space-y-5">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="relative w-full sm:max-w-xs">
          <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-white/40" />
          <Input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search by username…"
            className="pl-9"
          />
        </div>
        <p className="text-xs text-white/40">
          {filtered.length} {filtered.length === 1 ? "user" : "users"}
          {query.trim() && ` of ${users.length}`}
        </p>
      </div>

      <Card>
        {filtered.length === 0 ? (
          <EmptyState
            icon={<Users className="h-10 w-10" />}
            title={users.length === 0 ? "No users yet" : "No matching users"}
            description={
              users.length === 0
                ? "Users appear here once they register or redeem a license in your application."
                : "Try a different search term."
            }
          />
        ) : (
          <Table>
            <THead>
              <TR>
                <TH>Username</TH>
                <TH>Level</TH>
                <TH>Subscription</TH>
                <TH>HWID</TH>
                <TH>Status</TH>
                <TH>Last login</TH>
                <TH className="text-right">Actions</TH>
              </TR>
            </THead>
            <TBody>
              {filtered.map((user) => (
                <TR key={user.id}>
                  <TD>
                    <span className="font-medium text-white">{user.username}</span>
                    {user.email && (
                      <span className="block text-xs text-white/40">{user.email}</span>
                    )}
                  </TD>
                  <TD>
                    <Badge tone="info">Lv {user.level}</Badge>
                  </TD>
                  <TD>
                    <SubscriptionCell user={user} />
                  </TD>
                  <TD>
                    {user.hwid ? (
                      <div className="flex items-center gap-2">
                        <code
                          className="max-w-[8rem] truncate font-mono text-xs text-white/70"
                          title={user.hwid}
                        >
                          {user.hwid}
                        </code>
                        <Button
                          variant="outline"
                          size="sm"
                          loading={busyId === user.id}
                          onClick={() => handleResetHwid(user)}
                        >
                          <RefreshCw className="h-3.5 w-3.5" />
                          Reset
                        </Button>
                      </div>
                    ) : (
                      <span className="text-white/30">—</span>
                    )}
                  </TD>
                  <TD>
                    {user.banned ? (
                      <Badge tone="danger">Banned</Badge>
                    ) : (
                      <Badge tone="success">Active</Badge>
                    )}
                  </TD>
                  <TD className="whitespace-nowrap text-white/60">
                    {relativeTime(user.last_login_at)}
                  </TD>
                  <TD className="text-right">
                    <RowActions
                      user={user}
                      busy={busyId === user.id}
                      onBan={() => openBan(user)}
                      onUnban={() => handleUnban(user)}
                      onDelete={() => setDeleteTarget(user)}
                    />
                  </TD>
                </TR>
              ))}
            </TBody>
          </Table>
        )}
      </Card>

      {/* Ban modal */}
      <Modal
        open={banTarget !== null}
        onClose={() => setBanTarget(null)}
        title="Ban user"
        description={
          banTarget
            ? `Prevent "${banTarget.username}" from authenticating. You can add an optional reason.`
            : undefined
        }
      >
        <form onSubmit={handleBan} className="space-y-4">
          <Field label="Ban reason" hint="Optional — shown in logs and to the banned client.">
            <Textarea
              value={banReason}
              onChange={(e) => setBanReason(e.target.value)}
              placeholder="e.g. Chargeback, abuse, sharing account…"
              autoFocus
            />
          </Field>
          <div className="flex justify-end gap-2 pt-1">
            <Button
              type="button"
              variant="ghost"
              onClick={() => setBanTarget(null)}
              disabled={banning}
            >
              Cancel
            </Button>
            <Button type="submit" variant="danger" loading={banning}>
              <Ban className="h-4 w-4" />
              Ban user
            </Button>
          </div>
        </form>
      </Modal>

      {/* Delete confirmation modal */}
      <Modal
        open={deleteTarget !== null}
        onClose={() => setDeleteTarget(null)}
        title="Delete user"
        description={
          deleteTarget
            ? `This permanently deletes "${deleteTarget.username}" and their sessions. This cannot be undone.`
            : undefined
        }
      >
        <div className="flex justify-end gap-2">
          <Button variant="ghost" onClick={() => setDeleteTarget(null)} disabled={deleting}>
            Cancel
          </Button>
          <Button variant="danger" loading={deleting} onClick={handleDelete}>
            <Trash2 className="h-4 w-4" />
            Delete user
          </Button>
        </div>
      </Modal>
    </div>
  );
}

function RowActions({
  user,
  busy,
  onBan,
  onUnban,
  onDelete,
}: {
  user: AppUser;
  busy: boolean;
  onBan: () => void;
  onUnban: () => void;
  onDelete: () => void;
}) {
  const [open, setOpen] = React.useState(false);
  const ref = React.useRef<HTMLDivElement>(null);

  React.useEffect(() => {
    if (!open) return;
    const onClick = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    };
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && setOpen(false);
    document.addEventListener("mousedown", onClick);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("mousedown", onClick);
      document.removeEventListener("keydown", onKey);
    };
  }, [open]);

  const run = (fn: () => void) => {
    setOpen(false);
    fn();
  };

  return (
    <div ref={ref} className="relative inline-block text-left">
      <Button
        variant="ghost"
        size="sm"
        aria-label="Row actions"
        aria-haspopup="menu"
        aria-expanded={open}
        onClick={() => setOpen((v) => !v)}
      >
        <MoreHorizontal className="h-4 w-4" />
      </Button>
      {open && (
        <div
          role="menu"
          className="absolute right-0 z-20 mt-1 w-40 overflow-hidden rounded-lg border border-border bg-bg-elevated py-1 shadow-card"
        >
          {user.banned ? (
            <button
              role="menuitem"
              type="button"
              disabled={busy}
              onClick={() => run(onUnban)}
              className="flex w-full items-center gap-2 px-3 py-2 text-left text-sm text-white/80 transition-colors hover:bg-bg-soft hover:text-white disabled:opacity-50"
            >
              <ShieldCheck className="h-4 w-4" />
              Unban
            </button>
          ) : (
            <button
              role="menuitem"
              type="button"
              disabled={busy}
              onClick={() => run(onBan)}
              className="flex w-full items-center gap-2 px-3 py-2 text-left text-sm text-white/80 transition-colors hover:bg-bg-soft hover:text-white disabled:opacity-50"
            >
              <Ban className="h-4 w-4" />
              Ban
            </button>
          )}
          <button
            role="menuitem"
            type="button"
            onClick={() => run(onDelete)}
            className="flex w-full items-center gap-2 px-3 py-2 text-left text-sm text-red-300 transition-colors hover:bg-bg-soft hover:text-red-200"
          >
            <Trash2 className="h-4 w-4" />
            Delete
          </button>
        </div>
      )}
    </div>
  );
}
