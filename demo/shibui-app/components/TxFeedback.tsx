"use client";

import Link from "next/link";
import { etherscanTx } from "@/lib/format";
import { StatusBadge } from "./StatusBadge";

export type TxState = {
  hash?: `0x${string}`;
  error?: string;
  pending?: boolean;
  confirmed?: boolean;
  label?: string;
};

export function TxFeedback({ state }: { state: TxState }) {
  if (!state.hash && !state.error && !state.pending) return null;
  return (
    <div className="mt-3 flex flex-wrap items-center gap-2 text-xs">
      {state.label ? (
        <span className="font-medium text-slate-600">{state.label}:</span>
      ) : null}
      {state.pending ? <StatusBadge tone="info">Pending…</StatusBadge> : null}
      {state.confirmed ? <StatusBadge tone="ok">Confirmed</StatusBadge> : null}
      {state.error ? (
        <StatusBadge tone="err">{state.error}</StatusBadge>
      ) : null}
      {state.hash ? (
        <Link
          href={etherscanTx(state.hash)}
          target="_blank"
          rel="noreferrer"
          className="font-mono text-shibui-accent hover:underline"
        >
          {state.hash.slice(0, 10)}…
        </Link>
      ) : null}
    </div>
  );
}
