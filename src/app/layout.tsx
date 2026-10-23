import type { Metadata } from "next";
import "./globals.css";
import { ToastProvider } from "@/components/ui/Toast";

export const metadata: Metadata = {
  title: {
    default: "GoatAuth — Authentication & Licensing for Developers",
    template: "%s · GoatAuth",
  },
  description:
    "GoatAuth is an authentication and licensing platform for software developers. Protect your applications, sell license keys, and manage users with a simple REST API.",
  keywords: ["authentication", "licensing", "license keys", "software protection", "HWID", "API"],
  openGraph: {
    title: "GoatAuth — Authentication & Licensing for Developers",
    description:
      "Protect your applications, sell license keys, and manage users with a simple REST API.",
    type: "website",
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <ToastProvider>{children}</ToastProvider>
      </body>
    </html>
  );
}
