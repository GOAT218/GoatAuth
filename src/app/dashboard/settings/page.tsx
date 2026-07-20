"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import {
  Plus,
  Trash2,
  RefreshCw,
  Save,
  Variable,
  LogOut,
  Lock,
} from "lucide-react";
import { api, ApiClientError } from "@/lib/client";
import { AppScope } from "@/components/dashboard/AppScope";
import { useToast } from "@/components/ui/Toast";
import { Card, CardHeader, CardTitle, CardBody } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Badge } from "@/components/ui/Badge";
import { Input, Select, Field, Label } from "@/components/ui/Input";
import { Modal } from "@/components/ui/Modal";
import { Table, THead, TBody, TR, TH, TD } from "@/components/ui/Table";
import { Spinner, EmptyState, CopyField, CopyButton } from "@/components/ui/Misc";
import type { App, AppVariable, AppStatus } from "@/lib/types";

export default function SettingsPage() {
  return (
    <AppScope title="Settings" description="Configure your application and account.">
      {(appId, app) => <SettingsPanel key={appId} app={app} />}
    </AppScope>
  );
}

function SettingsPanel({ app }: { app: App }) {
  const router = useRouter();
  const { success, error: toastError } = useToast();

  // ---- Section A: application ------------------------------------------------
  const [name, setName] = React.useState(app.name);
  const [version, setVersion] = React.useState(app.version);
  const [status, setStatus] = React.useState<AppStatus>(app.status);
  const [downloadUrl, setDownloadUrl] = React.useState(app.download_url ?? "");
  const [hwidLock, setHwidLock] = React.useState(app.hwid_lock === 1);
  const [saving, setSaving] = React.useState(false);

  const [secret, setSecret] = React.useState(app.secret);
  const [rotateOpen, setRotateOpen] = React.useState(false);
  const [rotating, setRotating] = React.useState(false);

  // ---- Section B: variables --------------------------------------------------
  const [variables, setVariables] = React.useState<AppVariable[] | null>(null);
  const [addOpen, setAddOpen] = React.useState(false);
  const [adding, setAdding] = React.useState(false);
  const [varName, setVarName] = React.useState("");
  const [varValue, setVarValue] = React.useState("");
  const [varSecret, setVarSecret] = React.useState(false);
  const [deleteTarget, setDeleteTarget] = React.useState<AppVariable | null>(null);
  const [deleting, setDeleting] = React.useState(false);

  // ---- Section C: account ----------------------------------------------------
  const [signingOut, setSigningOut] = React.useState(false);

  const loadVariables = React.useCallback(async () => {
    setVariables(null);
    try {
      const list = await api.get<AppVariable[]>("/api/variables?app=" + app.id);
      setVariables(list);
    } catch (err) {
      const message =
        err instanceof ApiClientError ? err.message : "Failed to load server variables";
      toastError(message);
      setVariables([]);
    }
  }, [app.id, toastError]);

  React.useEffect(() => {
    void loadVariables();
  }, [loadVariables]);

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    const trimmedName = name.trim();
    if (trimmedName.length < 2) {
      toastError("Application name must be at least 2 characters");
      return;
    }
    setSaving(true);
    try {
      const updated = await api.patch<App>("/api/apps/" + app.id, {
        name: trimmedName,
        version: version.trim(),
        status,
        download_url: downloadUrl.trim() || null,
        hwid_lock: hwidLock,
      });
      setName(updated.name);
      setVersion(updated.version);
      setStatus(updated.status);
      setDownloadUrl(updated.download_url ?? "");
      setHwidLock(updated.hwid_lock === 1);
      success("Application settings saved");
    } catch (err) {
      const message =
        err instanceof ApiClientError ? err.message : "Failed to save application settings";
      toastError(message);
    } finally {
      setSaving(false);
    }
  }

  async function handleRotate() {
    setRotating(true);
    try {
      const res = await api.post<{ secret: string }>("/api/apps/" + app.id + "/rotate");
      setSecret(res.secret);
      setRotateOpen(false);
      success("Secret rotated — update your clients with the new secret");
    } catch (err) {
      const message =
        err instanceof ApiClientError ? err.message : "Failed to rotate secret";
      toastError(message);
    } finally {
      setRotating(false);
    }
  }

  function openAdd() {
    setVarName("");
    setVarValue("");
    setVarSecret(false);
    setAddOpen(true);
  }

  async function handleAddVariable(e: React.FormEvent) {
    e.preventDefault();
    const trimmedName = varName.trim();
    if (!trimmedName) {
      toastError("Variable name is required");
      return;
    }
    setAdding(true);
    try {
      const variable = await api.post<AppVariable>("/api/variables", {
        app_id: app.id,
        name: trimmedName,
        value: varValue,
        secret: varSecret,
      });
      setVariables((prev) => {
        const rest = (prev ?? []).filter((v) => v.name !== variable.name);
        return [variable, ...rest];
      });
      setAddOpen(false);
      success("Variable saved");
    } catch (err) {
      const message =
        err instanceof ApiClientError ? err.message : "Failed to save variable";
      toastError(message);
    } finally {
      setAdding(false);
    }
  }

  async function handleDeleteVariable() {
    if (!deleteTarget) return;
    setDeleting(true);
    try {
      await api.del("/api/variables/" + deleteTarget.id);
      setVariables((prev) => (prev ?? []).filter((v) => v.id !== deleteTarget.id));
      success("Variable deleted");
      setDeleteTarget(null);
    } catch (err) {
      const message =
        err instanceof ApiClientError ? err.message : "Failed to delete variable";
      toastError(message);
    } finally {
      setDeleting(false);
    }
  }

  async function handleSignOut() {
    setSigningOut(true);
    try {
      await api.post("/api/auth/logout");
      router.push("/login");
    } catch (err) {
      const message = err instanceof ApiClientError ? err.message : "Failed to sign out";
      toastError(message);
      setSigningOut(false);
    }
  }

  return (
    <div className="space-y-6">
      {/* Section A — Application */}
      <Card>
        <CardHeader>
          <CardTitle>Application</CardTitle>
          <Badge tone={status === "active" ? "success" : "warning"}>{status}</Badge>
        </CardHeader>
        <CardBody className="space-y-6">
          <form onSubmit={handleSave} className="space-y-5">
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <Field label="Name">
                <Input
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="My Awesome App"
                />
              </Field>
              <Field label="Version" hint="Clients below this version get the download URL.">
                <Input
                  value={version}
                  onChange={(e) => setVersion(e.target.value)}
                  placeholder="1.0"
                />
              </Field>
              <Field label="Status" hint="Paused apps reject all client authentication.">
                <Select
                  value={status}
                  onChange={(e) => setStatus(e.target.value as AppStatus)}
                >
                  <option value="active">Active</option>
                  <option value="paused">Paused</option>
                </Select>
              </Field>
              <Field
                label="Download URL"
                hint="Optional. Returned to out-of-date clients."
              >
                <Input
                  type="url"
                  value={downloadUrl}
                  onChange={(e) => setDownloadUrl(e.target.value)}
                  placeholder="https://example.com/download"
                />
              </Field>
            </div>

            <label className="flex cursor-pointer items-start gap-3 rounded-lg border border-border bg-bg-soft p-4">
              <input
                type="checkbox"
                checked={hwidLock}
                onChange={(e) => setHwidLock(e.target.checked)}
                className="mt-0.5 h-4 w-4 shrink-0 cursor-pointer accent-brand-500"
              />
              <span>
                <span className="flex items-center gap-1.5 text-sm font-medium text-white">
                  <Lock className="h-3.5 w-3.5 text-white/60" />
                  HWID lock
                </span>
                <span className="mt-0.5 block text-xs text-white/45">
                  Bind each user to a single hardware ID. New logins from another
                  machine are rejected until the HWID is reset.
                </span>
              </span>
            </label>

            <div className="flex justify-end">
              <Button type="submit" loading={saving}>
                <Save className="h-4 w-4" />
                Save changes
              </Button>
            </div>
          </form>

          <div className="space-y-3 border-t border-border pt-6">
            <div>
              <Label>App ID</Label>
              <CopyField value={app.id} />
            </div>
            <div>
              <Label>Secret</Label>
              <CopyField value={secret} />
              <p className="mt-1 text-xs text-white/40">
                Embed the App ID and Secret in your client software. Keep the secret
                private.
              </p>
            </div>
            <div className="flex justify-end">
              <Button variant="outline" onClick={() => setRotateOpen(true)}>
                <RefreshCw className="h-4 w-4" />
                Rotate secret
              </Button>
            </div>
          </div>
        </CardBody>
      </Card>

      {/* Section B — Server variables */}
      <Card>
        <CardHeader>
          <CardTitle>Server variables</CardTitle>
          <Button size="sm" onClick={openAdd}>
            <Plus className="h-4 w-4" />
            Add variable
          </Button>
        </CardHeader>
        <CardBody className="space-y-4">
          <p className="text-sm text-white/50">
            Store values your client software can fetch at runtime via{" "}
            <code className="rounded bg-bg-soft px-1.5 py-0.5 font-mono text-xs text-white/80">
              /api/v1/var
            </code>
            . Mark a variable as <span className="text-white/70">secret</span> to require
            an authenticated session before it can be read.
          </p>

          {variables === null ? (
            <div className="flex justify-center py-12">
              <Spinner className="h-6 w-6" />
            </div>
          ) : variables.length === 0 ? (
            <EmptyState
              icon={<Variable className="h-10 w-10" />}
              title="No server variables yet"
              description="Add a variable to serve dynamic values to your client software."
              action={
                <Button onClick={openAdd}>
                  <Plus className="h-4 w-4" />
                  Add variable
                </Button>
              }
            />
          ) : (
            <Table>
              <THead>
                <TR>
                  <TH>Name</TH>
                  <TH>Value</TH>
                  <TH className="text-right">Actions</TH>
                </TR>
              </THead>
              <TBody>
                {variables.map((v) => (
                  <TR key={v.id}>
                    <TD>
                      <span className="font-mono text-xs text-white/90">{v.name}</span>
                    </TD>
                    <TD>
                      {v.secret === 1 ? (
                        <div className="flex items-center gap-2">
                          <span className="font-mono text-xs text-white/40">••••••••</span>
                          <Badge tone="warning">secret</Badge>
                        </div>
                      ) : (
                        <div className="flex items-center gap-2">
                          <span className="max-w-[24rem] truncate font-mono text-xs text-white/90">
                            {v.value}
                          </span>
                          <CopyButton value={v.value} />
                        </div>
                      )}
                    </TD>
                    <TD>
                      <div className="flex items-center justify-end">
                        <Button
                          variant="danger"
                          size="sm"
                          onClick={() => setDeleteTarget(v)}
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
        </CardBody>
      </Card>

      {/* Section C — Account */}
      <Card>
        <CardHeader>
          <CardTitle>Account</CardTitle>
        </CardHeader>
        <CardBody className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <p className="text-sm text-white/50">
            Sign out of the GoatAuth dashboard on this device.
          </p>
          <Button variant="outline" onClick={handleSignOut} loading={signingOut}>
            <LogOut className="h-4 w-4" />
            Sign out
          </Button>
        </CardBody>
      </Card>

      {/* Rotate secret confirmation */}
      <Modal
        open={rotateOpen}
        onClose={() => setRotateOpen(false)}
        title="Rotate application secret"
        description="A new secret will be generated immediately. Any client software using the current secret will stop authenticating until you update it."
      >
        <div className="flex justify-end gap-2">
          <Button variant="ghost" onClick={() => setRotateOpen(false)} disabled={rotating}>
            Cancel
          </Button>
          <Button variant="danger" loading={rotating} onClick={handleRotate}>
            <RefreshCw className="h-4 w-4" />
            Rotate secret
          </Button>
        </div>
      </Modal>

      {/* Add variable modal */}
      <Modal
        open={addOpen}
        onClose={() => setAddOpen(false)}
        title="Add server variable"
        description="Reusing an existing name overwrites its value."
      >
        <form onSubmit={handleAddVariable} className="space-y-4">
          <Field label="Name">
            <Input
              value={varName}
              onChange={(e) => setVarName(e.target.value)}
              placeholder="discord_invite"
              autoFocus
            />
          </Field>
          <Field label="Value">
            <Input
              value={varValue}
              onChange={(e) => setVarValue(e.target.value)}
              placeholder="https://discord.gg/example"
            />
          </Field>
          <label className="flex cursor-pointer items-start gap-3 rounded-lg border border-border bg-bg-soft p-3">
            <input
              type="checkbox"
              checked={varSecret}
              onChange={(e) => setVarSecret(e.target.checked)}
              className="mt-0.5 h-4 w-4 shrink-0 cursor-pointer accent-brand-500"
            />
            <span>
              <span className="text-sm font-medium text-white">Secret variable</span>
              <span className="mt-0.5 block text-xs text-white/45">
                Only clients with a valid authenticated session can read this value.
              </span>
            </span>
          </label>
          <div className="flex justify-end gap-2 pt-1">
            <Button
              type="button"
              variant="ghost"
              onClick={() => setAddOpen(false)}
              disabled={adding}
            >
              Cancel
            </Button>
            <Button type="submit" loading={adding}>
              <Plus className="h-4 w-4" />
              Save variable
            </Button>
          </div>
        </form>
      </Modal>

      {/* Delete variable confirmation */}
      <Modal
        open={deleteTarget !== null}
        onClose={() => setDeleteTarget(null)}
        title="Delete server variable"
        description={
          deleteTarget
            ? `This permanently deletes "${deleteTarget.name}". Clients requesting it will receive an error. This cannot be undone.`
            : undefined
        }
      >
        <div className="flex justify-end gap-2">
          <Button variant="ghost" onClick={() => setDeleteTarget(null)} disabled={deleting}>
            Cancel
          </Button>
          <Button variant="danger" loading={deleting} onClick={handleDeleteVariable}>
            <Trash2 className="h-4 w-4" />
            Delete variable
          </Button>
        </div>
      </Modal>
    </div>
  );
}
