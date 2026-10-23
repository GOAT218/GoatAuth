"use client";

import * as React from "react";
import { Check, Copy, Loader2 } from "lucide-react";
import { cn } from "@/lib/cn";

export function Spinner({ className }: { className?: string }) {
  return <Loader2 className={cn("h-5 w-5 animate-spin text-white/50", className)} />;
}

export function CopyButton({
  value,
  className,
  label,
}: {
  value: string;
  className?: string;
  label?: string;
}) {
  const [copied, setCopied] = React.useState(false);
  return (
    <button
      type="button"
      onClick={async () => {
        try {
          await navigator.clipboard.writeText(value);
          setCopied(true);
          setTimeout(() => setCopied(false), 1500);
        } catch {
          /* clipboard unavailable */
        }
      }}
      className={cn(
        "inline-flex items-center gap-1.5 rounded-md border border-border px-2 py-1 text-xs text-white/70 transition-colors hover:bg-bg-elevated hover:text-white",
        className,
      )}
    >
      {copied ? <Check className="h-3.5 w-3.5 text-brand-400" /> : <Copy className="h-3.5 w-3.5" />}
      {label ?? (copied ? "Copied" : "Copy")}
    </button>
  );
}

export function CopyField({ value, className }: { value: string; className?: string }) {
  return (
    <div
      className={cn(
        "flex items-center justify-between gap-2 rounded-lg border border-border bg-bg-soft px-3 py-2",
        className,
      )}
    >
      <code className="truncate font-mono text-xs text-white/80">{value}</code>
      <CopyButton value={value} />
    </div>
  );
}

export function EmptyState({
  icon,
  title,
  description,
  action,
}: {
  icon?: React.ReactNode;
  title: string;
  description?: string;
  action?: React.ReactNode;
}) {
  return (
    <div className="flex flex-col items-center justify-center gap-3 px-6 py-16 text-center">
      {icon && <div className="text-white/25">{icon}</div>}
      <div>
        <p className="text-sm font-medium text-white">{title}</p>
        {description && <p className="mt-1 text-sm text-white/45">{description}</p>}
      </div>
      {action}
    </div>
  );
}
