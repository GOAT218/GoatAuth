"use client";

import * as React from "react";
import Link from "next/link";
import { Menu, X } from "lucide-react";
import { Logo } from "@/components/Logo";
import { Button } from "@/components/ui/Button";

const links = [
  { href: "/#features", label: "Features" },
  { href: "/#pricing", label: "Pricing" },
  { href: "/docs", label: "Docs" },
];

export function Nav() {
  const [open, setOpen] = React.useState(false);
  return (
    <header className="sticky top-0 z-40 border-b border-border/60 bg-bg/70 backdrop-blur-xl">
      <div className="mx-auto flex h-16 max-w-6xl items-center justify-between px-4 sm:px-6">
        <Link href="/" className="shrink-0">
          <Logo />
        </Link>

        <nav className="hidden items-center gap-8 md:flex">
          {links.map((l) => (
            <Link
              key={l.href}
              href={l.href}
              className="text-sm text-white/60 transition-colors hover:text-white"
            >
              {l.label}
            </Link>
          ))}
        </nav>

        <div className="hidden items-center gap-2 md:flex">
          <Link href="/login">
            <Button variant="ghost" size="sm">
              Sign in
            </Button>
          </Link>
          <Link href="/register">
            <Button size="sm">Get started</Button>
          </Link>
        </div>

        <button
          className="rounded-md p-2 text-white/70 md:hidden"
          onClick={() => setOpen((o) => !o)}
          aria-label="Toggle menu"
        >
          {open ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
        </button>
      </div>

      {open && (
        <div className="border-t border-border/60 bg-bg-soft px-4 py-4 md:hidden">
          <nav className="flex flex-col gap-3">
            {links.map((l) => (
              <Link
                key={l.href}
                href={l.href}
                onClick={() => setOpen(false)}
                className="text-sm text-white/70"
              >
                {l.label}
              </Link>
            ))}
            <div className="mt-2 flex gap-2">
              <Link href="/login" className="flex-1">
                <Button variant="outline" size="sm" className="w-full">
                  Sign in
                </Button>
              </Link>
              <Link href="/register" className="flex-1">
                <Button size="sm" className="w-full">
                  Get started
                </Button>
              </Link>
            </div>
          </nav>
        </div>
      )}
    </header>
  );
}
