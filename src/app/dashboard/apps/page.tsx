"use client";

import * as React from "react";
import Link from "next/link";
import { Plus, Trash2, Boxes, Settings } from "lucide-react";
import { api, ApiClientError } from "@/lib/client";
import { useToast } from "@/components/ui/Toast";
import { Card, CardBody } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Badge } from "@/components/ui/Badge";
import { Input, Field } from "@/components/ui/Input";
import { Label } from "@/components/ui/Input";
import { Modal } from "@/components/ui/Modal";
import { Spinner, EmptyState, CopyField } from "@/components/ui/Misc";
import { formatDate } from "@/lib/format";
import type { App } from "@/lib/types";

export default function AppsPage() {
  const { success, error: toastError } = useToast();

  const [loading, setLoading] = React.useState(true);
  const [apps, setApps] = React.useState<App[]>([]);

  // Create modal state
  const [createOpen, setCreateOpen] = React.useState(false);
  const [creating, setCreating] = React.useState(false);
  const [name, setName] = React.useState("");
  const [version, setVersion] = React.useState("1.0");

  // Delete modal state
  const [deleteTarget, setDeleteTarget] = React.useState<App | null>(null);
  const [deleting, setDeleting] = React.useState(false);

  React.useEffect(() => {
    let active = true;
    (async () => {
      try {
        const list = await api.get<App[]>("/api/apps");
        if (!active) return;
        setApps(list);
      } catch (err) {
        if (!active) return;
        const message =
          err instanceof ApiClientError ? err.message : "Failed to load applications";
        toastError(message);
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [toastError]);

  function openCreate() {
    setName("");
    setVersion("1.0");
    setCreateOpen(true);
  }

  async function handleCreate(e: React.FormEvent) {
    e.preventDefault();
    const trimmedName = name.trim();
    if (!trimmedName) {
      toastError("Application name is required");
      return;
    }
    setCreating(true);
    try {
      const created = await api.post<App>("/api/apps", {
        name: trimmedName,
        version: version.trim() || "1.0",
      });
      setApps((prev) => [created, ...prev]);
      setCreateOpen(false);
      success("Application created");
    } catch (err) {
      const message =
        err instanceof ApiClientError ? err.message : "Failed to create application";
      toastError(message);
    } finally {
      setCreating(false);
    }
  }

  async function handleDelete() {
    if (!deleteTarget) return;
    setDeleting(true);
    try {
      await api.del("/api/apps/" + deleteTarget.id);
      setApps((prev) => prev.filter((a) => a.id !== deleteTarget.id));
      success("Application deleted");
      setDeleteTarget(null);
    } catch (err) {
      const message =
        err instanceof ApiClientError ? err.message : "Failed to delete application";
      toastError(message);
    } finally {
      setDeleting(false);
    }
  }

  return (
    <div className="space-y-8">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-white">Applications</h1>
          <p className="mt-1 text-sm text-white/50">
            Manage the applications your client software authenticates against.
          </p>
        </div>
        <Button onClick={openCreate} className="shrink-0">
          <Plus className="h-4 w-4" />
          New application
        </Button>
      </div>

      {loading ? (
        <div className="flex min-h-[40vh] items-center justify-center">
          <Spinner className="h-6 w-6" />
        </div>
      ) : apps.length === 0 ? (
        <Card>
          <EmptyState
            icon={<Boxes className="h-10 w-10" />}
            title="No applications yet"
            description="Create your first application to start issuing license keys and authenticating users."
            action={
              <Button onClick={openCreate}>
                <Plus className="h-4 w-4" />
                New application
              </Button>
            }
          />
        </Card>
      ) : (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          {apps.map((app) => (
            <Card key={app.id}>
              <CardBody className="space-y-4">
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0">
                    <p className="truncate text-base font-bold text-white">{app.name}</p>
                    <p className="mt-0.5 text-xs text-white/40">
                      Created {formatDate(app.created_at)}
                    </p>
                  </div>
                  <Badge tone={app.status === "active" ? "success" : "warning"}>
                    {app.status}
                  </Badge>
                </div>

                <div className="space-y-3">
                  <div>
                    <Label>App ID</Label>
                    <CopyField value={app.id} />
                  </div>
                  <div>
                    <Label>Secret</Label>
                    <CopyField value={app.secret} />
                  </div>
                  <p className="text-xs text-white/40">
                    Embed these in your client software.
                  </p>
                </div>

                <div className="flex items-center justify-between gap-2 border-t border-border pt-4">
                  <Link href="/dashboard/settings">
                    <Button variant="outline" size="sm">
                      <Settings className="h-4 w-4" />
                      Manage
                    </Button>
                  </Link>
                  <Button
                    variant="danger"
                    size="sm"
                    onClick={() => setDeleteTarget(app)}
                  >
                    <Trash2 className="h-4 w-4" />
                    Delete
                  </Button>
                </div>
              </CardBody>
            </Card>
          ))}
        </div>
      )}

      {/* Create application modal */}
      <Modal
        open={createOpen}
        onClose={() => setCreateOpen(false)}
        title="New application"
        description="Applications hold your license keys, users, and API settings."
      >
        <form onSubmit={handleCreate} className="space-y-4">
          <Field label="Application name">
            <Input
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="My Awesome App"
              autoFocus
            />
          </Field>
          <Field label="Version" hint="Defaults to 1.0 if left blank.">
            <Input
              value={version}
              onChange={(e) => setVersion(e.target.value)}
              placeholder="1.0"
            />
          </Field>
          <div className="flex justify-end gap-2 pt-1">
            <Button
              type="button"
              variant="ghost"
              onClick={() => setCreateOpen(false)}
              disabled={creating}
            >
              Cancel
            </Button>
            <Button type="submit" loading={creating}>
              Create application
            </Button>
          </div>
        </form>
      </Modal>

      {/* Delete confirmation modal */}
      <Modal
        open={deleteTarget !== null}
        onClose={() => setDeleteTarget(null)}
        title="Delete application"
        description={
          deleteTarget
            ? `This permanently deletes "${deleteTarget.name}" along with its keys, users, and sessions. This cannot be undone.`
            : undefined
        }
      >
        <div className="flex justify-end gap-2">
          <Button
            variant="ghost"
            onClick={() => setDeleteTarget(null)}
            disabled={deleting}
          >
            Cancel
          </Button>
          <Button variant="danger" loading={deleting} onClick={handleDelete}>
            <Trash2 className="h-4 w-4" />
            Delete application
          </Button>
        </div>
      </Modal>
    </div>
  );
}
