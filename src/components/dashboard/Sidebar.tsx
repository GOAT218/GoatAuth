"use client";

import * as React from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import {
  LayoutDashboard,
  Boxes,
  KeyRound,
  Users,
  MonitorSmartphone,
  ShieldBan,
  Settings,
  LogOut,
  BookText,
} from "lucide-react";
import { Logo } from "@/components/Logo";
import { cn } from "@/lib/cn";
import { api } from "@/lib/client";

const nav = [
  { href: "/dashboard", label: "Overview", icon: LayoutDashboard, exact: true },
  { href: "/dashboard/apps", label: "Applications", icon: Boxes },
  { href: "/dashboard/keys", label: "License Keys", icon: KeyRound },
  { href: "/dashboard/users", label: "Users", icon: Users },
  { href: "/dashboard/sessions", label: "Sessions", icon: MonitorSmartphone },
  { href: "/dashboard/blacklist", label: "Blacklist", icon: ShieldBan },
  { href: "/dashboard/settings", label: "Settings", icon: Settings },
];

export function Sidebar({ username }: { username: string }) {
  const pathname = usePathname();
  const router = useRouter();
  const [loggingOut, setLoggingOut] = React.useState(false);

  const logout = async () => {
    setLoggingOut(true);
    try {
      await api.post("/api/auth/logout");
    } catch {
      /* ignore */
    }
    router.push("/login");
    router.refresh();
  };

  return (
    <aside className="flex h-full w-64 shrink-0 flex-col border-r border-border bg-bg-soft">
      <div className="flex h-16 items-center border-b border-border px-5">
        <Link href="/dashboard">
          <Logo />
        </Link>
      </div>

      <nav className="flex-1 space-y-1 overflow-y-auto px-3 py-4">
        {nav.map((item) => {
          const active = item.exact ? pathname === item.href : pathname.startsWith(item.href);
          const Icon = item.icon;
          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                "flex items-center gap-3 rounded-lg px-3 py-2 text-sm transition-colors",
                active
                  ? "bg-brand-500/15 font-medium text-brand-300"
                  : "text-white/60 hover:bg-bg-elevated hover:text-white",
              )}
            >
              <Icon className="h-4 w-4" />
              {item.label}
            </Link>
          );
        })}

        <div className="my-3 border-t border-border/60" />
        <Link
          href="/docs"
          target="_blank"
          className="flex items-center gap-3 rounded-lg px-3 py-2 text-sm text-white/60 transition-colors hover:bg-bg-elevated hover:text-white"
        >
          <BookText className="h-4 w-4" />
          API Docs
        </Link>
      </nav>

      <div className="border-t border-border p-3">
        <div className="mb-2 flex items-center gap-3 rounded-lg px-3 py-2">
          <div className="flex h-8 w-8 items-center justify-center rounded-full bg-brand-500/20 text-sm font-semibold text-brand-300">
            {username.charAt(0).toUpperCase()}
          </div>
          <div className="min-w-0">
            <p className="truncate text-sm font-medium text-white">{username}</p>
            <p className="text-xs text-white/40">Seller</p>
          </div>
        </div>
        <button
          onClick={logout}
          disabled={loggingOut}
          className="flex w-full items-center gap-3 rounded-lg px-3 py-2 text-sm text-white/60 transition-colors hover:bg-bg-elevated hover:text-red-300 disabled:opacity-50"
        >
          <LogOut className="h-4 w-4" />
          {loggingOut ? "Signing out…" : "Sign out"}
        </button>
      </div>
    </aside>
  );
}
