import * as React from "react";
import { cn } from "@/lib/cn";

type Tone = "neutral" | "success" | "warning" | "danger" | "info" | "brand";

const tones: Record<Tone, string> = {
  neutral: "bg-white/5 text-white/70 border-white/10",
  success: "bg-brand-500/15 text-brand-300 border-brand-500/30",
  warning: "bg-amber-500/15 text-amber-300 border-amber-500/30",
  danger: "bg-red-500/15 text-red-300 border-red-500/30",
  info: "bg-accent/15 text-accent border-accent/30",
  brand: "bg-brand-500/15 text-brand-300 border-brand-500/30",
};

export function Badge({
  tone = "neutral",
  className,
  ...props
}: React.HTMLAttributes<HTMLSpanElement> & { tone?: Tone }) {
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1 rounded-full border px-2 py-0.5 text-[11px] font-medium",
        tones[tone],
        className,
      )}
      {...props}
    />
  );
}
