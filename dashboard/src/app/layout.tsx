import type { Metadata } from "next";
import "./globals.css";
import Link from "next/link";

export const metadata: Metadata = {
  title: "TruckMate Dashboard",
  description: "Admin dashboard for TruckMate trucking management",
};

const navItems = [
  { href: "/dashboard", label: "Dashboard", icon: "📊" },
  { href: "/trips", label: "Trips", icon: "🚛" },
  { href: "/drivers", label: "Drivers", icon: "👤" },
  { href: "/documents/queue", label: "Approvals", icon: "📋" },
  { href: "/invoices", label: "Invoices", icon: "💰" },
  { href: "/settings", label: "Settings", icon: "⚙️" },
];

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="bg-slate-50 min-h-screen">
        <div className="flex min-h-screen">
          {/* Sidebar */}
          <aside className="w-64 bg-slate-900 text-white flex flex-col">
            <div className="p-6 border-b border-slate-700">
              <h1 className="text-2xl font-bold">🚛 TruckMate</h1>
              <p className="text-slate-400 text-sm">ਟਰੱਕਮੇਟ</p>
            </div>
            <nav className="flex-1 p-4">
              <ul className="space-y-2">
                {navItems.map((item) => (
                  <li key={item.href}>
                    <Link
                      href={item.href}
                      className="flex items-center gap-3 px-4 py-3 rounded-lg hover:bg-slate-800 transition-colors"
                    >
                      <span>{item.icon}</span>
                      <span>{item.label}</span>
                    </Link>
                  </li>
                ))}
              </ul>
            </nav>
            <div className="p-4 border-t border-slate-700">
              <p className="text-slate-400 text-sm">Highway Heroes Trucking</p>
            </div>
          </aside>

          {/* Main Content */}
          <main className="flex-1 overflow-auto">{children}</main>
        </div>
      </body>
    </html>
  );
}
