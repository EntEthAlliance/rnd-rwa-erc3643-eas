import type { Metadata } from "next";
import type { ReactNode } from "react";
import "./globals.css";
import { Providers } from "./providers";
import { Nav } from "@/components/Nav";

export const metadata: Metadata = {
  title: "Shibui Demo — Attestation lifecycle on Sepolia",
  description:
    "Walk through schema registration, attester authorization, attestation issuance, and compliance-gated transfers for ERC-3643 tokens on Sepolia.",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body>
        <Providers>
          <Nav />
          <main className="mx-auto max-w-6xl px-6 py-10">{children}</main>
          <footer className="border-t border-slate-200 bg-white">
            <div className="mx-auto max-w-6xl px-6 py-6 text-xs text-slate-500">
              Testnet only · Sepolia · Shibui is an open-source project by the{" "}
              <a
                href="https://entethalliance.org"
                target="_blank"
                rel="noreferrer"
                className="text-shibui-accent hover:underline"
              >
                Enterprise Ethereum Alliance
              </a>
              .
            </div>
          </footer>
        </Providers>
      </body>
    </html>
  );
}
