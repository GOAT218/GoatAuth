import Link from "next/link";
import { Logo } from "@/components/Logo";
import { Button } from "@/components/ui/Button";

export default function NotFound() {
  return (
    <main className="grid-bg flex min-h-screen flex-col items-center justify-center px-4 text-center">
      <Link href="/" className="mb-8">
        <Logo />
      </Link>
      <p className="text-7xl font-bold text-gradient">404</p>
      <h1 className="mt-4 text-xl font-semibold text-white">Page not found</h1>
      <p className="mt-2 max-w-sm text-sm text-white/50">
        The page you are looking for doesn&apos;t exist or has been moved.
      </p>
      <div className="mt-6 flex gap-3">
        <Link href="/">
          <Button variant="outline">Go home</Button>
        </Link>
        <Link href="/dashboard">
          <Button>Dashboard</Button>
        </Link>
      </div>
    </main>
  );
}
