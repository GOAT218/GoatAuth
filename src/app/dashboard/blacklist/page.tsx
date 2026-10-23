"use client";

import * as React from "react";
import { Plus, ShieldBan, Trash2 } from "lucide-react";
import { api, ApiClientError } from "@/lib/client";
import { useToast } from "@/components/ui/Toast";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Badge } from "@/components/ui/Badge";
import { Input, Textarea, Select, Field } from "@/components/ui/Input";
import { Modal } from "@/components/ui/Modal";
import { Spinner, EmptyState } from "@/components/ui/Misc";
import { Table, THead, TBody, TR, TH, TD } from "@/components/ui/Table";
import { AppScope } from "@/components/dashboard/AppScope";
import { formatDate } from "@/lib/format";
import type { BlacklistEntry, BlacklistType } from "@/lib/types";

export default function BlacklistPage() {
  return (
    <AppScope
      title="Blacklist"
      description="Block specific IP addresses or hardware IDs from authenticating."
    >
      {(appId) => <BlacklistPanel appId={appId} />}
    </AppScope>
  );
}

function errMessage(err: unknown, fallback: string): string {
  return err instanceof ApiClientError ? err.message : fallback;
}

function BlacklistPanel({ appId }: { appId: string }) {
  const { success, error: toastError } = useToast();

  const [loading, setLoading] = React.useState(true);
  const [entries, setEntries] = React.useState<BlacklistEntry[]>([]);

  // Add modal state
  const [addOpen, setAddOpen] = React.useState(false);
  const [type, setType] = React.useState<BlacklistType>("ip");
  const [value, setValue] = React.useState("");
  const [reason, setReason] = React.useState("");
  const [saving, setSaving] = React.useState(false);

  // Delete state
  const [deleteTarget, setDeleteTarget] = React.useState<BlacklistEntry | null>(null);
  const [deleting, setDeleting] = React.useState(false);

  React.useEffect(() => {
    let active = true;
    setLoading(true);
    (async () => {
      try {
        const list = await api.get<BlacklistEntry[]>("/api/blacklist?app=" + appId);
        if (!active) return;
        setEntries(list);
      } catch (err) {
        if (!active) return;
        toastError(errMessage(err, "Failed to load blacklist"));
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [appId, toastError]);

  function openAdd() {
    setType("ip");
    setValue("");
    setReason("");
    setAddOpen(true);
  }

  async function handleAdd(e: React.FormEvent) {
    e.preventDefault();
    const trimmedValue = value.trim();
    if (!trimmedValue) {
      toastError("A value is required");
      return;
    }
    setSaving(true);
    const trimmedReason = reason.trim();
    try {
      const entry = await api.post<BlacklistEntry>("/api/blacklist", {
        app_id: appId,
        type,
        value: trimmedValue,
        reason: trimmedReason || undefined,
      });
      setEntries((prev) => [entry, ...prev]);
      success("Entry added to blacklist");
      setAddOpen(false);
    } catch (err) {
      toastError(errMessage(err, "Failed to add entry"));
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete() {
    if (!deleteTarget) return;
    setDeleting(true);
    try {
      await api.del("/api/blacklist/" + deleteTarget.id);
      setEntries((prev) => prev.filter((entry) => entry.id !== deleteTarget.id));
      success("Entry removed");
      setDeleteTarget(null);
    } catch (err) {
      toastError(errMessage(err, "Failed to remove entry"));
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
        <p className="text-xs text-white/40">
          {entries.length} {entries.length === 1 ? "entry" : "entries"}
        </p>
        <Button size="sm" onClick={openAdd}>
          <Plus className="h-4 w-4" />
          Add entry
        </Button>
      </div>

      <Card>
        {entries.length === 0 ? (
          <EmptyState
            icon={<ShieldBan className="h-10 w-10" />}
            title="Nothing blacklisted"
            description="Add an IP address or hardware ID to block it from authenticating in your application."
            action={
              <Button size="sm" onClick={openAdd}>
                <Plus className="h-4 w-4" />
                Add entry
              </Button>
            }
          />
        ) : (
          <Table>
            <THead>
              <TR>
                <TH>Type</TH>
                <TH>Value</TH>
                <TH>Reason</TH>
                <TH>Added</TH>
                <TH className="text-right">Actions</TH>
              </TR>
            </THead>
            <TBody>
              {entries.map((entry) => (
                <TR key={entry.id}>
                  <TD>
                    <Badge tone={entry.type === "ip" ? "info" : "warning"}>
                      {entry.type.toUpperCase()}
                    </Badge>
                  </TD>
                  <TD>
                    <code
                      className="max-w-[16rem] truncate font-mono text-xs text-white/80"
                      title={entry.value}
                    >
                      {entry.value}
                    </code>
                  </TD>
                  <TD className="text-white/70">
                    {entry.reason ? entry.reason : <span className="text-white/30">—</span>}
                  </TD>
                  <TD className="whitespace-nowrap text-white/60">{formatDate(entry.created_at)}</TD>
                  <TD className="text-right">
                    <Button
                      variant="danger"
                      size="sm"
                      onClick={() => setDeleteTarget(entry)}
                    >
                      <Trash2 className="h-3.5 w-3.5" />
                      Delete
                    </Button>
                  </TD>
                </TR>
              ))}
            </TBody>
          </Table>
        )}
      </Card>

      {/* Add entry modal */}
      <Modal
        open={addOpen}
        onClose={() => setAddOpen(false)}
        title="Add blacklist entry"
        description="Blocked IPs and HWIDs are rejected during authentication."
      >
        <form onSubmit={handleAdd} className="space-y-4">
          <Field label="Type">
            <Select value={type} onChange={(e) => setType(e.target.value as BlacklistType)}>
              <option value="ip">IP address</option>
              <option value="hwid">Hardware ID (HWID)</option>
            </Select>
          </Field>
          <Field label="Value" hint={type === "ip" ? "e.g. 203.0.113.42" : "The hardware identifier to block."}>
            <Input
              value={value}
              onChange={(e) => setValue(e.target.value)}
              placeholder={type === "ip" ? "203.0.113.42" : "HWID string…"}
              autoFocus
            />
          </Field>
          <Field label="Reason" hint="Optional — shown in your logs.">
            <Textarea
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              placeholder="e.g. Fraud, abuse, chargeback…"
            />
          </Field>
          <div className="flex justify-end gap-2 pt-1">
            <Button type="button" variant="ghost" onClick={() => setAddOpen(false)} disabled={saving}>
              Cancel
            </Button>
            <Button type="submit" loading={saving}>
              <Plus className="h-4 w-4" />
              Add entry
            </Button>
          </div>
        </form>
      </Modal>

      {/* Delete confirmation modal */}
      <Modal
        open={deleteTarget !== null}
        onClose={() => setDeleteTarget(null)}
        title="Remove blacklist entry"
        description={
          deleteTarget
            ? `This will allow "${deleteTarget.value}" to authenticate again. This cannot be undone.`
            : undefined
        }
      >
        <div className="flex justify-end gap-2">
          <Button variant="ghost" onClick={() => setDeleteTarget(null)} disabled={deleting}>
            Cancel
          </Button>
          <Button variant="danger" loading={deleting} onClick={handleDelete}>
            <Trash2 className="h-4 w-4" />
            Remove entry
          </Button>
        </div>
      </Modal>
    </div>
  );
}
