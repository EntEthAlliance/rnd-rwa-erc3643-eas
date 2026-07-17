"use client";

import { useState } from "react";
import {
  useAccount,
  usePublicClient,
  useReadContract,
  useWriteContract,
} from "wagmi";
import { parseUnits } from "viem";
import { ConfigurationGate } from "@/components/ConfigurationGate";
import { InvestorCard } from "@/components/InvestorCard";
import { StatusBadge } from "@/components/StatusBadge";
import { TxFeedback, type TxState } from "@/components/TxFeedback";
import { getContracts } from "@/lib/contracts";
import { deployment, type InvestorKey } from "@/lib/deployments";
import { decodeTransferRevert } from "@/lib/format";

export default function TransferPage() {
  return (
    <ConfigurationGate required={["verifier", "token"]}>
      <div className="space-y-6">
        <header className="space-y-2">
          <h1 className="text-2xl font-semibold">Transfer · eligibility outcomes</h1>
          <p className="max-w-3xl text-slate-700">
            Three pre-seeded investors with different eligibility states. Every card reads <code className="font-mono">isVerified()</code> directly from Sepolia. Use the transfer action to test whether the demo ERC-3643 token accepts or rejects the transfer in real time.
          </p>
        </header>

        <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
          <InvestorPanel id="alice" name="Alice" />
          <InvestorPanel id="bob" name="Bob" />
          <InvestorPanel id="carol" name="Carol" />
        </div>

        <TokenBalanceRow />
        <ScenarioHints />
      </div>
    </ConfigurationGate>
  );
}

function InvestorPanel({ id, name }: { id: InvestorKey; name: string }) {
  const info = deployment.demo.investors[id];
  const { demoToken } = getContracts();
  const { address: connected } = useAccount();
  const { writeContractAsync } = useWriteContract();
  const publicClient = usePublicClient();
  const [tx, setTx] = useState<TxState>({});

  async function transferTo() {
    if (!connected) return;
    setTx({ pending: true });
    try {
      const hash = await writeContractAsync({
        address: demoToken.address,
        abi: demoToken.abi,
        functionName: "transfer",
        args: [info.wallet, parseUnits("1", 18)],
      });
      setTx({ hash, pending: true });
      await publicClient!.waitForTransactionReceipt({ hash });
      setTx({ hash, confirmed: true });
    } catch (e) {
      setTx({ error: decodeTransferRevert(e) });
    }
  }

  return (
    <InvestorCard
      name={name}
      role={id}
      wallet={info.wallet}
      description={info.description}
    >
      <button
        className="btn-primary w-full"
        onClick={transferTo}
        disabled={!connected || tx.pending}
      >
        {tx.pending ? "Submitting…" : `Transfer 1 token to  ${name}`}
      </button>
      <TxFeedback state={tx} />
      {id === "carol" ? <RevokeCarolControl /> : null}
    </InvestorCard>
  );
}

function RevokeCarolControl() {
  const { eas } = getContracts();
  const { writeContractAsync } = useWriteContract();
  const publicClient = usePublicClient();
  const [tx, setTx] = useState<TxState>({});
  const carolUID = deployment.demo.attestations.carolKYC;
  const schemaUID = deployment.schemas.investorEligibility;
  const ready =
    carolUID !==
      "0x0000000000000000000000000000000000000000000000000000000000000000" &&
    schemaUID !==
      "0x0000000000000000000000000000000000000000000000000000000000000000";

  async function revoke() {
    setTx({ pending: true });
    try {
      const hash = await writeContractAsync({
        address: eas.address,
        abi: eas.abi,
        functionName: "revoke",
        args: [
          {
            schema: schemaUID,
            data: { uid: carolUID, value: 0n },
          },
        ],
      });
      setTx({ hash, pending: true });
      await publicClient!.waitForTransactionReceipt({ hash });
      setTx({ hash, confirmed: true });
    } catch (e) {
      setTx({ error: (e as Error).message.slice(0, 200) });
    }
  }

  return (
    <div className="mt-2 space-y-1">
      <button
        className="btn-danger w-full"
        onClick={revoke}
        disabled={!ready || tx.pending}
      >
        {tx.pending ? "Revoking…" : "Revoke Carol's attestation"}
      </button>
      {!ready ? (
        <p className="text-xs text-amber-700">
          Seed Carol's attestation first (set{" "}
          <code className="font-mono">demo.attestations.carolKYC</code> in
          deployments).
        </p>
      ) : null}
      <TxFeedback state={tx} />
    </div>
  );
}

function TokenBalanceRow() {
  const { demoToken } = getContracts();
  const { address } = useAccount();
  const { data: sym } = useReadContract({
    address: demoToken.address,
    abi: demoToken.abi,
    functionName: "symbol",
  });
  const { data: balance } = useReadContract({
    address: demoToken.address,
    abi: demoToken.abi,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
    query: { enabled: !!address, refetchInterval: 10_000 },
  });

  return (
    <div className="card flex items-center justify-between">
      <div>
        <div className="text-xs uppercase tracking-wide text-slate-500">
          Connected wallet balance
        </div>
        <div className="mt-1 text-lg font-semibold">
          {balance !== undefined
            ? `${Number(balance) / 1e18} ${sym ?? "DEMO"}`
            : "—"}
        </div>
        <div className="code text-xs text-slate-500">
          {demoToken.address}
        </div>
      </div>
      <StatusBadge tone="info">Demo ERC-3643 · testnet only</StatusBadge>
    </div>
  );
}

function ScenarioHints() {
  return (
    <div className="card space-y-2 bg-slate-50">
      <h3 className="text-sm font-semibold">Expected outcomes</h3>
      <ul className="ml-5 list-disc space-y-1 text-sm text-slate-700">
        <li>
          <strong>Alice</strong> — all topics satisfied. Transfer lands, tx hash
          linked to Etherscan.
        </li>
        <li>
          <strong>Bob</strong> — fails the accreditation requirement, so{" "}
          <code className="font-mono">isVerified</code> returns false and the
          token compliance check reverts the transfer with a decoded reason.
        </li>
        <li>
          <strong>Carol</strong> — starts verified. Click "Revoke Carol's attestation"
          and within one poll the card flips to{" "}
          <code className="font-mono">isVerified = false</code>; any subsequent
          transfer reverts.
        </li>
      </ul>
    </div>
  );
}
