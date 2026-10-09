"use client";

import * as React from "react";
import { Activity, Ban, Trash2 } from "lucide-react";
import { api, ApiClientError } from "@/lib/client";
import { useToast } from "@/components/ui/Toast";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Badge } from "@/components/ui/Badge";
import { Spinner, EmptyState } from "@/components/ui/Misc";
import { Table, THead, TBody, TR, TH, TD } from "@/components/ui/Table";
import { AppScope } from "@/components/dashboard/AppScope";
import { formatDateTime, relativeTime } from "@/lib/format";
import type { AppSession } from "@/lib/types";

export default function SessionsPage() {
  return (
    <AppScope
      title="Sessions"
      description="Live and recent authentication sessions."
    >
      {(appId) => <SessionsPanel appId={appId} />}
    </AppScope>
  );
}

function errMessage(err: unknown, fallback: string): string {
  return err instanceof ApiClientError ? err.message : fallback;
}

function truncate(value: string, max = 12): string {
  return value.length > max ? value.slice(0, max) + "…" : value;
}

function isActive(session: AppSession): boolean {
  return session.valid === 1 && session.expires_at > Date.now();
}

function SessionsPanel({ appId }: { appId: string }) {
  const { success, error: toastError } = useToast();

  const [loading, setLoading] = React.useState(true);
  const [sessions, setSessions] = React.useState<AppSession[]>([]);
  const [pruning, setPruning] = React.useState(false);
  const [busyId, setBusyId] = React.useState<string | null>(null);

  const load = React.useCallback(async () => {
    setLoading(true);
    try {
      const list = await api.get<AppSession[]>("/api/sessions?app=" + appId);
      setSessions(list);
    } catch (err) {
      toastError(errMessage(err, "Failed to load sessions"));
    } finally {
      setLoading(false);
    }
  }, [appId, toastError]);

  React.useEffect(() => {
    let active = true;
    setLoading(true);
    (async () => {
      try {
        const list = await api.get<AppSession[]>("/api/sessions?app=" + appId);
        if (!active) return;
        setSessions(list);
      } catch (err) {
        if (!active) return;
        toastError(errMessage(err, "Failed to load sessions"));
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [appId, toastError]);

  async function handleKill(session: AppSession) {
    setBusyId(session.id);
    try {
      await api.del("/api/sessions/" + session.id);
      setSessions((prev) =>
        prev.map((s) => (s.id === session.id ? { ...s, valid: 0 } : s)),
      );
      success("Session killed");
    } catch (err) {
      toastError(errMessage(err, "Failed to kill session"));
    } finally {
      setBusyId(null);
    }
  }

  async function handlePrune() {
    setPruning(true);
    try {
      await api.del("/api/sessions?app=" + appId);
      success("Ended sessions pruned");
      await load();
    } catch (err) {
      toastError(errMessage(err, "Failed to prune sessions"));
    } finally {
      setPruning(false);
    }
  }

  if (loading) {
    return (
      <div className="flex min-h-[40vh] items-center justify-center">
        <Spinner className="h-6 w-6" />
      </div>
    );
  }

  const activeCount = sessions.filter(isActive).length;

  return (
    <div className="space-y-5">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <p className="text-xs text-white/40">
          {activeCount} active {activeCount === 1 ? "session" : "sessions"} of {sessions.length}
        </p>
        <Button
          variant="outline"
          size="sm"
          loading={pruning}
          disabled={sessions.length === 0}
          onClick={handlePrune}
        >
          <Trash2 className="h-4 w-4" />
          Prune ended
        </Button>
      </div>

      <Card>
        {sessions.length === 0 ? (
          <EmptyState
            icon={<Activity className="h-10 w-10" />}
            title="No sessions yet"
            description="Sessions appear here when clients authenticate against your application."
          />
        ) : (
          <Table>
            <THead>
              <TR>
                <TH>Session</TH>
                <TH>User</TH>
                <TH>IP</TH>
                <TH>HWID</TH>
                <TH>Status</TH>
                <TH>Started</TH>
                <TH>Expires</TH>
                <TH className="text-right">Actions</TH>
              </TR>
            </THead>
            <TBody>
              {sessions.map((session) => {
                const active = isActive(session);
                return (
                  <TR key={session.id}>
                    <TD>
                      <code className="font-mono text-xs text-white/70" title={session.id}>
                        {truncate(session.id)}
                      </code>
                    </TD>
                    <TD>
                      {session.user_id ? (
                        <code className="font-mono text-xs text-white/70" title={session.user_id}>
                          {truncate(session.user_id)}
                        </code>
                      ) : (
                        <span className="text-white/40">license/anon</span>
                      )}
                    </TD>
                    <TD className="whitespace-nowrap text-white/70">{session.ip ?? "—"}</TD>
                    <TD>
                      {session.hwid ? (
                        <code
                          className="max-w-[8rem] truncate font-mono text-xs text-white/70"
                          title={session.hwid}
                        >
                          {truncate(session.hwid)}
                        </code>
                      ) : (
                        <span className="text-white/30">—</span>
                      )}
                    </TD>
                    <TD>
                      {active ? (
                        <Badge tone="success">Active</Badge>
                      ) : (
                        <Badge tone="neutral">Ended</Badge>
                      )}
                    </TD>
                    <TD className="whitespace-nowrap text-white/60">
                      {relativeTime(session.created_at)}
                    </TD>
                    <TD className="whitespace-nowrap text-white/60">
                      {formatDateTime(session.expires_at)}
                    </TD>
                    <TD className="text-right">
                      {active ? (
                        <Button
                          variant="danger"
                          size="sm"
                          loading={busyId === session.id}
                          onClick={() => handleKill(session)}
                        >
                          <Ban className="h-3.5 w-3.5" />
                          Kill
                        </Button>
                      ) : (
                        <span className="text-white/30">—</span>
                      )}
                    </TD>
                  </TR>
                );
              })}
            </TBody>
          </Table>
        )}
      </Card>
    </div>
  );
}
