export const runtime = "nodejs";
export const dynamic = "force-dynamic";

import { redirect } from "next/navigation";
import { getSeller } from "@/lib/seller-session";
import { Sidebar } from "@/components/dashboard/Sidebar";

export default async function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const seller = await getSeller();
  if (!seller) redirect("/login");

  return (
    <div className="flex h-screen bg-bg">
      <Sidebar username={seller.username} />
      <main className="flex-1 overflow-y-auto">
        <div className="mx-auto max-w-6xl px-4 py-8 sm:px-6">{children}</div>
      </main>
    </div>
  );
}
