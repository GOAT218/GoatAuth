import * as React from "react";
import { Card } from "@/components/ui/Card";
import { cn } from "@/lib/cn";

export function StatCard({
  label,
  value,
  icon,
  hint,
  className,
}: {
  label: string;
  value: React.ReactNode;
  icon?: React.ReactNode;
  hint?: string;
  className?: string;
}) {
  return (
    <Card className={cn("p-5", className)}>
      <div className="flex items-start justify-between">
        <div>
          <p className="text-xs font-medium uppercase tracking-wide text-white/40">{label}</p>
          <p className="mt-2 text-3xl font-bold tracking-tight text-white">{value}</p>
          {hint && <p className="mt-1 text-xs text-white/40">{hint}</p>}
        </div>
        {icon && (
          <div className="rounded-lg border border-border bg-bg-soft p-2 text-brand-400">{icon}</div>
        )}
      </div>
    </Card>
  );
}
