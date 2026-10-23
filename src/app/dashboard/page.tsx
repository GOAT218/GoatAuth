"use client";

import * as React from "react";
import Link from "next/link";
import {
  Boxes,
  Users,
  KeyRound,
  Ticket,
  MonitorSmartphone,
  Ban,
  Activity,
} from "lucide-react";
import { api, ApiClientError } from "@/lib/client";
import { useToast } from "@/components/ui/Toast";
import { Card, CardHeader, CardTitle, CardBody } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Badge } from "@/components/ui/Badge";
import { Spinner, EmptyState } from "@/components/ui/Misc";
import { StatCard } from "@/components/dashboard/StatCard";
import { relativeTime } from "@/lib/format";
import type { LogEntry, LogAction } from "@/lib/types";

interface Stats {
  apps: number;
  users: number;
  keys: number;
  unusedKeys: number;
  activeSessions: number;
  bannedUsers: number;
}

const actionTone: Record<LogAction, Parameters<typeof Badge>[0]["tone"]> = {
  init: "neutral",
  register: "info",
  login: "success",
  license: "brand",
  verify: "info",
  upgrade: "brand",
  log: "neutral",
  ban: "danger",
  blacklist: "warning",
  error: "danger",
};

export default function OverviewPage() {
  const { error: toastError } = useToast();
  const [loading, setLoading] = React.useState(true);
  const [stats, setStats] = React.useState<Stats | null>(null);
  const [logs, setLogs] = React.useState<LogEntry[]>([]);

  React.useEffect(() => {
    let active = true;
    (async () => {
      try {
        const [s, l] = await Promise.all([
          api.get<Stats>("/api/stats"),
          api.get<LogEntry[]>("/api/logs"),
        ]);
        if (!active) return;
        setStats(s);
        setLogs(l);
      } catch (err) {
        if (!active) return;
        const message =
          err instanceof ApiClientError ? err.message : "Failed to load overview";
        toastError(message);
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [toastError]);

  if (loading) {
    return (
      <div className="flex min-h-[60vh] items-center justify-center">
        <Spinner className="h-6 w-6" />
      </div>
    );
  }

  const cards = stats
    ? [
        { label: "Applications", value: stats.apps, icon: <Boxes className="h-5 w-5" /> },
        { label: "Users", value: stats.users, icon: <Users className="h-5 w-5" /> },
        { label: "License keys", value: stats.keys, icon: <KeyRound className="h-5 w-5" /> },
        { label: "Unused keys", value: stats.unusedKeys, icon: <Ticket className="h-5 w-5" /> },
        {
          label: "Active sessions",
          value: stats.activeSessions,
          icon: <MonitorSmartphone className="h-5 w-5" />,
        },
        { label: "Banned users", value: stats.bannedUsers, icon: <Ban className="h-5 w-5" /> },
      ]
    : [];

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-2xl font-bold tracking-tight text-white">Overview</h1>
        <p className="mt-1 text-sm text-white/50">
          A snapshot of your applications and recent activity.
        </p>
      </div>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {cards.map((c) => (
          <StatCard key={c.label} label={c.label} value={c.value} icon={c.icon} />
        ))}
      </div>

      {stats && stats.apps === 0 && (
        <Card>
          <CardBody className="flex flex-col items-start gap-4 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <p className="text-sm font-semibold text-white">
                Create your first application
              </p>
              <p className="mt-1 text-sm text-white/50">
                Applications hold your license keys, users, and API settings. Create one to
                get started.
              </p>
            </div>
            <Link href="/dashboard/apps">
              <Button>Create application</Button>
            </Link>
          </CardBody>
        </Card>
      )}

      <Card>
        <CardHeader>
          <CardTitle>Recent activity</CardTitle>
        </CardHeader>
        {logs.length === 0 ? (
          <EmptyState
            icon={<Activity className="h-8 w-8" />}
            title="No activity yet"
            description="Events from your applications will show up here."
          />
        ) : (
          <ul className="divide-y divide-border">
            {logs.map((log) => (
              <li key={log.id} className="flex items-start gap-3 px-5 py-3">
                <Badge tone={actionTone[log.action] ?? "neutral"} className="mt-0.5 shrink-0">
                  {log.action}
                </Badge>
                <p className="min-w-0 flex-1 break-words text-sm text-white/80">
                  {log.message}
                </p>
                <span className="shrink-0 whitespace-nowrap text-xs text-white/40">
                  {relativeTime(log.created_at)}
                </span>
              </li>
            ))}
          </ul>
        )}
      </Card>
    </div>
  );
}
