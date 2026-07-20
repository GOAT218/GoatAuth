import { cn } from "@/lib/cn";

export function Logo({ className, showText = true }: { className?: string; showText?: boolean }) {
  return (
    <span className={cn("inline-flex items-center gap-2", className)}>
      <span className="relative inline-flex h-8 w-8 items-center justify-center rounded-lg bg-gradient-to-br from-brand-400 to-brand-600 shadow-glow">
        <svg viewBox="0 0 24 24" className="h-5 w-5 text-white" fill="none" aria-hidden>
          <path
            d="M12 2 4 6v6c0 4.4 3.2 7.6 8 9 4.8-1.4 8-4.6 8-9V6l-8-4Z"
            fill="currentColor"
            fillOpacity="0.25"
          />
          <path
            d="M12 2 4 6v6c0 4.4 3.2 7.6 8 9 4.8-1.4 8-4.6 8-9V6l-8-4Z"
            stroke="currentColor"
            strokeWidth="1.5"
            strokeLinejoin="round"
          />
          <path
            d="m8.5 12 2.4 2.4L15.5 9.8"
            stroke="currentColor"
            strokeWidth="1.8"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
      </span>
      {showText && (
        <span className="text-lg font-bold tracking-tight text-white">
          Goat<span className="text-brand-400">Auth</span>
        </span>
      )}
    </span>
  );
}
