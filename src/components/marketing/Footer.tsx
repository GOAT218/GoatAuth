import Link from "next/link";
import { Logo } from "@/components/Logo";

export function Footer() {
  return (
    <footer className="border-t border-border/60 bg-bg-soft">
      <div className="mx-auto max-w-6xl px-4 py-12 sm:px-6">
        <div className="flex flex-col justify-between gap-8 md:flex-row">
          <div className="max-w-xs">
            <Logo />
            <p className="mt-3 text-sm text-white/45">
              Authentication and licensing infrastructure for software developers. Protect your
              apps, sell licenses, and manage users in minutes.
            </p>
          </div>
          <div className="grid grid-cols-2 gap-10 sm:grid-cols-3">
            <div>
              <h4 className="mb-3 text-xs font-semibold uppercase tracking-wider text-white/40">
                Product
              </h4>
              <ul className="space-y-2 text-sm text-white/60">
                <li><Link href="/#features" className="hover:text-white">Features</Link></li>
                <li><Link href="/#pricing" className="hover:text-white">Pricing</Link></li>
                <li><Link href="/docs" className="hover:text-white">Documentation</Link></li>
              </ul>
            </div>
            <div>
              <h4 className="mb-3 text-xs font-semibold uppercase tracking-wider text-white/40">
                Account
              </h4>
              <ul className="space-y-2 text-sm text-white/60">
                <li><Link href="/login" className="hover:text-white">Sign in</Link></li>
                <li><Link href="/register" className="hover:text-white">Create account</Link></li>
                <li><Link href="/dashboard" className="hover:text-white">Dashboard</Link></li>
              </ul>
            </div>
            <div>
              <h4 className="mb-3 text-xs font-semibold uppercase tracking-wider text-white/40">
                Developers
              </h4>
              <ul className="space-y-2 text-sm text-white/60">
                <li><Link href="/docs#api" className="hover:text-white">API reference</Link></li>
                <li><Link href="/docs#sdks" className="hover:text-white">SDK examples</Link></li>
                <li><Link href="/docs#quickstart" className="hover:text-white">Quickstart</Link></li>
              </ul>
            </div>
          </div>
        </div>
        <div className="mt-10 flex flex-col items-center justify-between gap-3 border-t border-border/60 pt-6 text-xs text-white/35 sm:flex-row">
          <p>© {new Date().getFullYear()} GoatAuth. Built for demonstration purposes.</p>
          <p>Use responsibly and only for software you own or are authorized to protect.</p>
        </div>
      </div>
    </footer>
  );
}
