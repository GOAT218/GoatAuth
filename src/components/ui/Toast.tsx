"use client";

import * as React from "react";
import { CheckCircle2, XCircle, Info } from "lucide-react";
import { cn } from "@/lib/cn";

type ToastKind = "success" | "error" | "info";
interface Toast {
  id: number;
  kind: ToastKind;
  message: string;
}

interface ToastCtx {
  toast: (message: string, kind?: ToastKind) => void;
  success: (message: string) => void;
  error: (message: string) => void;
}

const Ctx = React.createContext<ToastCtx | null>(null);

export function useToast(): ToastCtx {
  const ctx = React.useContext(Ctx);
  if (!ctx) throw new Error("useToast must be used inside <ToastProvider>");
  return ctx;
}

let counter = 0;

export function ToastProvider({ children }: { children: React.ReactNode }) {
  const [toasts, setToasts] = React.useState<Toast[]>([]);

  const push = React.useCallback((message: string, kind: ToastKind = "info") => {
    const id = ++counter;
    setToasts((t) => [...t, { id, kind, message }]);
    setTimeout(() => setToasts((t) => t.filter((x) => x.id !== id)), 4000);
  }, []);

  const value = React.useMemo<ToastCtx>(
    () => ({
      toast: push,
      success: (m: string) => push(m, "success"),
      error: (m: string) => push(m, "error"),
    }),
    [push],
  );

  return (
    <Ctx.Provider value={value}>
      {children}
      <div className="pointer-events-none fixed bottom-4 right-4 z-[60] flex w-full max-w-sm flex-col gap-2">
        {toasts.map((t) => (
          <div
            key={t.id}
            className={cn(
              "pointer-events-auto flex items-center gap-3 rounded-lg border px-4 py-3 text-sm shadow-card animate-fade-up",
              t.kind === "success" && "border-brand-500/40 bg-bg-elevated text-brand-200",
              t.kind === "error" && "border-red-500/40 bg-bg-elevated text-red-200",
              t.kind === "info" && "border-border bg-bg-elevated text-white/80",
            )}
          >
            {t.kind === "success" && <CheckCircle2 className="h-4 w-4 shrink-0" />}
            {t.kind === "error" && <XCircle className="h-4 w-4 shrink-0" />}
            {t.kind === "info" && <Info className="h-4 w-4 shrink-0" />}
            <span>{t.message}</span>
          </div>
        ))}
      </div>
    </Ctx.Provider>
  );
}
