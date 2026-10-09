"use client";

import * as React from "react";
import Link from "next/link";
import { Boxes, ChevronDown } from "lucide-react";
import { api } from "@/lib/client";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { EmptyState, Spinner } from "@/components/ui/Misc";
import type { App } from "@/lib/types";

const STORAGE_KEY = "goatauth.selectedApp";

/**
 * Wraps app-scoped dashboard pages. Loads the seller's apps, renders an app
 * picker, persists the selection, and calls `children(appId, app)` once an app
 * is chosen. Shows a friendly empty state when the seller has no apps yet.
 */
export function AppScope({
  title,
  description,
  actions,
  children,
}: {
  title: string;
  description?: string;
  actions?: (appId: string, app: App) => React.ReactNode;
  children: (appId: string, app: App) => React.ReactNode;
}) {
  const [apps, setApps] = React.useState<App[] | null>(null);
  const [selected, setSelected] = React.useState<string>("");
  const [error, setError] = React.useState<string | null>(null);

  React.useEffect(() => {
    api
      .get<App[]>("/api/apps")
      .then((list) => {
        setApps(list);
        const stored = typeof window !== "undefined" ? localStorage.getItem(STORAGE_KEY) : null;
        const initial = list.find((a) => a.id === stored)?.id ?? list[0]?.id ?? "";
        setSelected(initial);
      })
      .catch((e) => setError(e.message));
  }, []);

  const choose = (id: string) => {
    setSelected(id);
    try {
      localStorage.setItem(STORAGE_KEY, id);
    } catch {
      /* ignore */
    }
  };

  if (error) {
    return <Card className="p-6 text-sm text-red-300">Failed to load applications: {error}</Card>;
  }

  if (apps === null) {
    return (
      <div className="flex justify-center py-20">
        <Spinner />
      </div>
    );
  }

  if (apps.length === 0) {
    return (
      <Card>
        <EmptyState
          icon={<Boxes className="h-10 w-10" />}
          title="No applications yet"
          description="Create your first application to start generating license keys and managing users."
          action={
            <Link href="/dashboard/apps">
              <Button>Create an application</Button>
            </Link>
          }
        />
      </Card>
    );
  }

  const app = apps.find((a) => a.id === selected) ?? apps[0];

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-xl font-bold text-white">{title}</h1>
          {description && <p className="mt-1 text-sm text-white/50">{description}</p>}
        </div>
        <div className="flex items-center gap-3">
          {actions?.(app.id, app)}
          <div className="relative">
            <select
              value={app.id}
              onChange={(e) => choose(e.target.value)}
              className="h-10 cursor-pointer appearance-none rounded-lg border border-border bg-bg-soft py-2 pl-3 pr-9 text-sm text-white focus:border-brand-500 focus:outline-none"
            >
              {apps.map((a) => (
                <option key={a.id} value={a.id}>
                  {a.name}
                </option>
              ))}
            </select>
            <ChevronDown className="pointer-events-none absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 text-white/40" />
          </div>
        </div>
      </div>

      <div key={app.id}>{children(app.id, app)}</div>
    </div>
  );
}
