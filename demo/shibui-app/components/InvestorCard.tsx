"use client";

import Link from "next/link";
import { useReadContract } from "wagmi";
import { etherscanAddress } from "@/lib/format";
import { getContracts } from "@/lib/contracts";
import { StatusBadge } from "./StatusBadge";
import type { InvestorKey } from "@/lib/deployments";

export type InvestorCardProps = {
  name: string;
  role: InvestorKey;
  wallet: `0x${string}`;
  description: string;
  children?: React.ReactNode;
};

export function InvestorCard({
  name,
  role,
  wallet,
  description,
  children,
}: InvestorCardProps) {
  const { claimVerifier } = getContracts();
  const { data: isVerified, isLoading, refetch } = useReadContract({
    address: claimVerifier.address,
    abi: claimVerifier.abi,
    functionName: "isVerified",
    args: [wallet],
    query: {
      refetchInterval: 8_000,
    },
  });

  const tone = isLoading ? "neutral" : isVerified ? "ok" : "err";
  const label = isLoading
    ? "Checking…"
    : isVerified
      ? "isVerified = true"
      : "isVerified = false";

  return (
    <div className="card space-y-3">
      <div className="flex items-start justify-between gap-3">
        <div>
          <h3 className="text-lg font-semibold">{name}</h3>
          <p className="text-xs uppercase tracking-wide text-slate-500">
            {role}
          </p>
        </div>
        <StatusBadge tone={tone}>{label}</StatusBadge>
      </div>
      <p className="text-sm text-slate-700">{description}</p>
      <Link
        href={etherscanAddress(wallet)}
        target="_blank"
        rel="noreferrer"
        className="code text-shibui-accent hover:underline"
      >
        {wallet}
      </Link>
      <div className="pt-2 border-t border-slate-100 space-y-2">{children}</div>
      <button
        onClick={() => refetch()}
        className="text-xs text-slate-500 hover:text-slate-800"
      >
        ↻ Refresh verification state
      </button>
    </div>
  );
}
