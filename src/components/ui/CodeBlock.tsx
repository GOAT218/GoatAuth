"use client";

import * as React from "react";
import { CopyButton } from "./Misc";
import { cn } from "@/lib/cn";

export function CodeBlock({
  code,
  language,
  className,
}: {
  code: string;
  language?: string;
  className?: string;
}) {
  return (
    <div className={cn("group relative overflow-hidden rounded-xl border border-border bg-[#0c0c13]", className)}>
      <div className="flex items-center justify-between border-b border-border/60 px-4 py-2">
        <span className="font-mono text-[11px] uppercase tracking-wider text-white/35">
          {language ?? "code"}
        </span>
        <CopyButton value={code} />
      </div>
      <pre className="overflow-x-auto p-4 text-[13px] leading-relaxed">
        <code className="font-mono text-white/85">{code}</code>
      </pre>
    </div>
  );
}
