"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { ConnectButton } from "@rainbow-me/rainbowkit";

const ROUTES = [
  { href: "/", label: "Overview" },
  { href: "/admin", label: "Admin" },
  { href: "/attester", label: "Attester" },
  { href: "/transfer", label: "Transfer" },
];

export function Nav() {
  const pathname = usePathname();
  return (
    <header className="border-b border-slate-200 bg-white">
      <div className="mx-auto flex max-w-6xl items-center justify-between px-6 py-4">
        <div className="flex items-center gap-8">
          <Link href="/" className="flex items-center gap-2">
            <span className="text-lg font-semibold tracking-tight">Shibui</span>
            <span className="rounded bg-slate-100 px-2 py-0.5 text-xs text-slate-600">
              Demo · Sepolia
            </span>
          </Link>
          <nav className="flex items-center gap-1">
            {ROUTES.map((r) => {
              const active =
                r.href === "/" ? pathname === "/" : pathname?.startsWith(r.href);
              return (
                <Link
                  key={r.href}
                  href={r.href}
                  className={
                    "rounded-md px-3 py-1.5 text-sm font-medium transition-colors " +
                    (active
                      ? "bg-slate-100 text-shibui-ink"
                      : "text-slate-600 hover:text-shibui-ink")
                  }
                >
                  {r.label}
                </Link>
              );
            })}
          </nav>
        </div>
        <ConnectButton chainStatus="icon" showBalance={false} />
      </div>
    </header>
  );
}
