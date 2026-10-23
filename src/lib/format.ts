// Formatting helpers shared by server and client components.

export function formatDate(ms: number | null | undefined): string {
  if (!ms) return "—";
  return new Date(ms).toLocaleDateString("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

export function formatDateTime(ms: number | null | undefined): string {
  if (!ms) return "—";
  return new Date(ms).toLocaleString("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function formatExpiry(ms: number | null): string {
  if (ms === null) return "Lifetime";
  if (ms <= Date.now()) return "Expired";
  return formatDate(ms);
}

export function relativeTime(ms: number | null | undefined): string {
  if (!ms) return "never";
  const diff = ms - Date.now();
  const abs = Math.abs(diff);
  const units: [number, Intl.RelativeTimeFormatUnit][] = [
    [86_400_000, "day"],
    [3_600_000, "hour"],
    [60_000, "minute"],
    [1000, "second"],
  ];
  const rtf = new Intl.RelativeTimeFormat("en", { numeric: "auto" });
  for (const [unitMs, unit] of units) {
    if (abs >= unitMs || unit === "second") {
      return rtf.format(Math.round(diff / unitMs), unit);
    }
  }
  return "just now";
}

export function humanDuration(days: number): string {
  if (days === 0) return "Lifetime";
  if (days % 365 === 0) return `${days / 365} year${days / 365 > 1 ? "s" : ""}`;
  if (days % 30 === 0) return `${days / 30} month${days / 30 > 1 ? "s" : ""}`;
  if (days % 7 === 0) return `${days / 7} week${days / 7 > 1 ? "s" : ""}`;
  return `${days} day${days > 1 ? "s" : ""}`;
}
