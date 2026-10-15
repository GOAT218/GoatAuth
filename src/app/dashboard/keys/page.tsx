"use client";

import * as React from "react";
import { Plus, Trash2, Ban, ShieldCheck, KeyRound } from "lucide-react";
import { api, ApiClientError } from "@/lib/client";
import { AppScope } from "@/components/dashboard/AppScope";
import { useToast } from "@/components/ui/Toast";
import { Card, CardHeader, CardTitle, CardBody } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Badge } from "@/components/ui/Badge";
import { Input, Textarea, Select, Field } from "@/components/ui/Input";
import { Modal } from "@/components/ui/Modal";
import { Table, THead, TBody, TR, TH, TD } from "@/components/ui/Table";
import { Spinner, EmptyState, CopyButton } from "@/components/ui/Misc";
import { humanDuration, formatDate } from "@/lib/format";
import type { LicenseKey, LicenseStatus } from "@/lib/types";

const DURATION_OPTIONS: { value: number; label: string }[] = [
  { value: 1, label: "1 day" },
  { value: 7, label: "1 week" },
  { value: 30, label: "1 month" },
  { value: 90, label: "3 months" },
  { value: 365, label: "1 year" },
  { value: 0, label: "Lifetime" },
];

function statusTone(status: LicenseStatus): "info" | "neutral" | "danger" {
  if (status === "unused") return "info";
  if (status === "banned") return "danger";
  return "neutral";
}

export default function KeysPage() {
  return (
    <AppScope
      title="License Keys"
      description="Generate and manage license keys for your application."
    >
      {(appId) => <KeysPanel appId={appId} />}
    </AppScope>
  );
}

function KeysPanel({ appId }: { appId: string }) {
  const { success, error: toastError } = useToast();

  const [keys, setKeys] = React.useState<LicenseKey[] | null>(null);

  // Create modal + form state
  const [createOpen, setCreateOpen] = React.useState(false);
  const [creating, setCreating] = React.useState(false);
  const [amount, setAmount] = React.useState("1");
  const [durationDays, setDurationDays] = React.useState("30");
  const [level, setLevel] = React.useState("1");
  const [maxUses, setMaxUses] = React.useState("1");
  const [prefix, setPrefix] = React.useState("");
  const [note, setNote] = React.useState("");
  const [generated, setGenerated] = React.useState<LicenseKey[] | null>(null);

  // Row / bulk action state
  const [actionId, setActionId] = React.useState<string | null>(null);
  const [deleteTarget, setDeleteTarget] = React.useState<LicenseKey | null>(null);
  const [deleting, setDeleting] = React.useState(false);
  const [purging, setPurging] = React.useState(false);

  const load = React.useCallback(async () => {
    setKeys(null);
    try {
      const list = await api.get<LicenseKey[]>("/api/keys?app=" + appId);
      setKeys(list);
    } catch (err) {
      const message = err instanceof ApiClientError ? err.message : "Failed to load license keys";
      toastError(message);
      setKeys([]);
    }
  }, [appId, toastError]);

  React.useEffect(() => {
    void load();
  }, [load]);

  function openCreate() {
    setAmount("1");
    setDurationDays("30");
    setLevel("1");
    setMaxUses("1");
    setPrefix("");
    setNote("");
    setGenerated(null);
    setCreateOpen(true);
  }

  function closeCreate() {
    setCreateOpen(false);
    setGenerated(null);
  }

  async function handleCreate(e: React.FormEvent) {
    e.preventDefault();
    const amountNum = Number(amount);
    if (!Number.isFinite(amountNum) || amountNum < 1 || amountNum > 1000) {
      toastError("Amount must be between 1 and 1000");
      return;
    }
    setCreating(true);
    try {
      const results = await api.post<LicenseKey[]>("/api/keys", {
        app_id: appId,
        amount: amountNum,
        duration_days: Number(durationDays),
        level: Number(level),
        max_uses: Number(maxUses),
        prefix: prefix.trim() || undefined,
        note: note.trim() || undefined,
      });
      setKeys((prev) => [...results, ...(prev ?? [])]);
      setGenerated(results);
      success(`Generated ${results.length} key${results.length === 1 ? "" : "s"}`);
    } catch (err) {
      const message = err instanceof ApiClientError ? err.message : "Failed to generate keys";
      toastError(message);
    } finally {
      setCreating(false);
    }
  }

  async function handleToggleBan(key: LicenseKey) {
    const target: LicenseStatus =
      key.status === "banned" ? (key.uses > 0 ? "used" : "unused") : "banned";
    setActionId(key.id);
    try {
      await api.patch("/api/keys/" + key.id, { status: target });
      setKeys((prev) =>
        (prev ?? []).map((k) => (k.id === key.id ? { ...k, status: target } : k)),
      );
      success(target === "banned" ? "Key banned" : "Key unbanned");
    } catch (err) {
      const message = err instanceof ApiClientError ? err.message : "Failed to update key";
      toastError(message);
    } finally {
      setActionId(null);
    }
  }

  async function handleDelete() {
    if (!deleteTarget) return;
    setDeleting(true);
    try {
      await api.del("/api/keys/" + deleteTarget.id);
      setKeys((prev) => (prev ?? []).filter((k) => k.id !== deleteTarget.id));
      success("Key deleted");
      setDeleteTarget(null);
    } catch (err) {
      const message = err instanceof ApiClientError ? err.message : "Failed to delete key";
      toastError(message);
    } finally {
      setDeleting(false);
    }
  }

  async function handleDeleteUnused() {
    setPurging(true);
    try {
      await api.del("/api/keys?app=" + appId + "&unused=1");
      success("Deleted unused keys");
      await load();
    } catch (err) {
      const message = err instanceof ApiClientError ? err.message : "Failed to delete unused keys";
      toastError(message);
    } finally {
      setPurging(false);
    }
  }

  const generatedText = generated ? generated.map((k) => k.key).join("\n") : "";

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <p className="text-sm text-white/50">
          {keys === null
            ? "Loading keys…"
            : `${keys.length} key${keys.length === 1 ? "" : "s"} total`}
        </p>
        <div className="flex flex-wrap items-center gap-2">
          <Button
            variant="outline"
            onClick={handleDeleteUnused}
            loading={purging}
            disabled={keys === null || keys.length === 0}
          >
            <Trash2 className="h-4 w-4" />
            Delete unused
          </Button>
          <Button onClick={openCreate}>
            <Plus className="h-4 w-4" />
            Generate keys
          </Button>
        </div>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>License keys</CardTitle>
        </CardHeader>
        {keys === null ? (
          <div className="flex justify-center py-16">
            <Spinner className="h-6 w-6" />
          </div>
        ) : keys.length === 0 ? (
          <EmptyState
            icon={<KeyRound className="h-10 w-10" />}
            title="No license keys yet"
            description="Generate a batch of keys to distribute to your users."
            action={
              <Button onClick={openCreate}>
                <Plus className="h-4 w-4" />
                Generate keys
              </Button>
            }
          />
        ) : (
          <Table>
            <THead>
              <TR>
                <TH>Key</TH>
                <TH>Duration</TH>
                <TH>Level</TH>
                <TH>Uses</TH>
                <TH>Status</TH>
                <TH>Created</TH>
                <TH className="text-right">Actions</TH>
              </TR>
            </THead>
            <TBody>
              {keys.map((k) => (
                <TR key={k.id}>
                  <TD>
                    <div className="flex items-center gap-2">
                      <span className="font-mono text-xs text-white/90">{k.key}</span>
                      <CopyButton value={k.key} />
                    </div>
                  </TD>
                  <TD>{humanDuration(k.duration_days)}</TD>
                  <TD>{k.level}</TD>
                  <TD>
                    {k.uses}/{k.max_uses}
                  </TD>
                  <TD>
                    <Badge tone={statusTone(k.status)}>{k.status}</Badge>
                  </TD>
                  <TD className="whitespace-nowrap text-white/60">{formatDate(k.created_at)}</TD>
                  <TD>
                    <div className="flex items-center justify-end gap-2">
                      <Button
                        variant="outline"
                        size="sm"
                        loading={actionId === k.id}
                        onClick={() => handleToggleBan(k)}
                      >
                        {k.status === "banned" ? (
                          <>
                            <ShieldCheck className="h-3.5 w-3.5" />
                            Unban
                          </>
                        ) : (
                          <>
                            <Ban className="h-3.5 w-3.5" />
                            Ban
                          </>
                        )}
                      </Button>
                      <Button
                        variant="danger"
                        size="sm"
                        onClick={() => setDeleteTarget(k)}
                      >
                        <Trash2 className="h-3.5 w-3.5" />
                        Delete
                      </Button>
                    </div>
                  </TD>
                </TR>
              ))}
            </TBody>
          </Table>
        )}
      </Card>

      {/* Generate keys modal */}
      <Modal
        open={createOpen}
        onClose={closeCreate}
        title={generated ? "Keys generated" : "Generate license keys"}
        description={
          generated
            ? "Copy these keys now — you can also find them in the table below."
            : "Create a batch of license keys for your application."
        }
      >
        {generated ? (
          <div className="space-y-4">
            <Field label={`${generated.length} new key${generated.length === 1 ? "" : "s"}`}>
              <Textarea
                readOnly
                value={generatedText}
                rows={Math.min(Math.max(generated.length, 3), 12)}
                className="font-mono text-xs"
                onFocus={(e) => e.currentTarget.select()}
              />
            </Field>
            <div className="flex items-center justify-between gap-2">
              <CopyButton value={generatedText} label="Copy all" />
              <div className="flex gap-2">
                <Button variant="ghost" onClick={openCreate}>
                  Generate more
                </Button>
                <Button onClick={closeCreate}>Done</Button>
              </div>
            </div>
          </div>
        ) : (
          <form onSubmit={handleCreate} className="space-y-4">
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <Field label="Amount" hint="1 – 1000 keys">
                <Input
                  type="number"
                  min={1}
                  max={1000}
                  value={amount}
                  onChange={(e) => setAmount(e.target.value)}
                  autoFocus
                />
              </Field>
              <Field label="Duration">
                <Select value={durationDays} onChange={(e) => setDurationDays(e.target.value)}>
                  {DURATION_OPTIONS.map((opt) => (
                    <option key={opt.value} value={opt.value}>
                      {opt.label}
                    </option>
                  ))}
                </Select>
              </Field>
              <Field label="Level">
                <Input
                  type="number"
                  min={1}
                  value={level}
                  onChange={(e) => setLevel(e.target.value)}
                />
              </Field>
              <Field label="Max uses" hint="Redemptions allowed per key">
                <Input
                  type="number"
                  min={1}
                  value={maxUses}
                  onChange={(e) => setMaxUses(e.target.value)}
                />
              </Field>
            </div>
            <Field label="Prefix" hint="Optional. Prepended to each key.">
              <Input
                value={prefix}
                onChange={(e) => setPrefix(e.target.value)}
                placeholder="MYAPP"
              />
            </Field>
            <Field label="Note" hint="Optional. Internal reference only.">
              <Input
                value={note}
                onChange={(e) => setNote(e.target.value)}
                placeholder="Batch for launch giveaway"
              />
            </Field>
            <div className="flex justify-end gap-2 pt-1">
              <Button type="button" variant="ghost" onClick={closeCreate} disabled={creating}>
                Cancel
              </Button>
              <Button type="submit" loading={creating}>
                <Plus className="h-4 w-4" />
                Generate
              </Button>
            </div>
          </form>
        )}
      </Modal>

      {/* Delete confirmation modal */}
      <Modal
        open={deleteTarget !== null}
        onClose={() => setDeleteTarget(null)}
        title="Delete license key"
        description={
          deleteTarget
            ? `This permanently deletes the key "${deleteTarget.key}". This cannot be undone.`
            : undefined
        }
      >
        <div className="flex justify-end gap-2">
          <Button variant="ghost" onClick={() => setDeleteTarget(null)} disabled={deleting}>
            Cancel
          </Button>
          <Button variant="danger" loading={deleting} onClick={handleDelete}>
            <Trash2 className="h-4 w-4" />
            Delete key
          </Button>
        </div>
      </Modal>
    </div>
  );
}
