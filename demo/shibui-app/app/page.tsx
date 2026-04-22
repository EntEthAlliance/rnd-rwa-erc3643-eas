import Link from "next/link";
import { deployment, deploymentGaps } from "@/lib/deployments";
import { StatusBadge } from "@/components/StatusBadge";

const SCREENS = [
  {
    href: "/admin",
    title: "1. Admin",
    actor: "Issuer · EEA compliance staff",
    body: "Register the two EAS schemas and authorize a KYC provider as a trusted attester. Without this, the token has no compliance layer.",
  },
  {
    href: "/attester",
    title: "2. Attester",
    actor: "KYC / AML provider",
    body: "Fill in the Investor Eligibility form, sign the EAS attestation, and register it against the investor's identity in Shibui.",
  },
  {
    href: "/transfer",
    title: "3. Transfer",
    actor: "Reviewer",
    body: "Watch three pre-seeded investors transfer the demo ERC-3643 token — Alice succeeds, Bob reverts, Carol flips after a revoke.",
  },
];

export default function Home() {
  const gaps = deploymentGaps();
  const allDeployed = gaps.length === 0;

  return (
    <div className="space-y-10">
      <section className="space-y-3">
        <div className="flex items-center gap-3">
          <h1 className="text-3xl font-semibold tracking-tight">
            Shibui compliance demo
          </h1>
          <StatusBadge tone={allDeployed ? "ok" : "warn"}>
            {allDeployed ? "Sepolia ready" : "Needs deployment"}
          </StatusBadge>
        </div>
        <p className="max-w-3xl text-slate-700">
          Three screens, one decision surface. Institutions evaluating Shibui
          want to see who authorizes attesters, what fields an attestation
          carries, and how revocation resolves in real time. This demo renders
          those moments directly against the canonical contracts on Sepolia —
          no mocks in the happy path.
        </p>
      </section>

      <section className="grid grid-cols-1 gap-4 md:grid-cols-3">
        {SCREENS.map((s) => (
          <Link
            key={s.href}
            href={s.href}
            className="card hover:border-shibui-accent hover:shadow-md transition"
          >
            <div className="text-xs uppercase tracking-wide text-slate-500">
              {s.actor}
            </div>
            <h2 className="mt-1 text-xl font-semibold">{s.title}</h2>
            <p className="mt-2 text-sm text-slate-700">{s.body}</p>
            <div className="mt-4 text-sm font-medium text-shibui-accent">
              Open →
            </div>
          </Link>
        ))}
      </section>

      <section className="card space-y-3">
        <h2 className="text-lg font-semibold">Deployment status</h2>
        <p className="text-sm text-slate-700">
          The UI resolves every contract address from{" "}
          <code className="font-mono">deployments/sepolia.json</code> at the
          repo root. Populate that file with the output of{" "}
          <code className="font-mono">
            script/DeployTestnet.s.sol
          </code>{" "}
          before driving the flow.
        </p>
        {allDeployed ? (
          <div className="flex items-center gap-2">
            <StatusBadge tone="ok">All addresses set</StatusBadge>
            <span className="text-sm text-slate-600">
              Last updated:{" "}
              <span className="font-mono">
                {deployment.lastUpdated ?? "n/a"}
              </span>
            </span>
          </div>
        ) : (
          <ul className="ml-5 list-disc text-sm font-mono text-slate-800">
            {gaps.map((g) => (
              <li key={g.path}>
                {g.label} <span className="text-slate-500">({g.path})</span>
              </li>
            ))}
          </ul>
        )}
      </section>

      <section className="card space-y-3">
        <h2 className="text-lg font-semibold">Architecture at a glance</h2>
        <p className="text-sm text-slate-700">
          Shibui answers a single question from the ERC-3643 token's compliance
          hook:
        </p>
        <pre className="rounded-md bg-slate-900 p-4 text-sm text-slate-100">
{`EASClaimVerifier.isVerified(wallet) → bool`}
        </pre>
        <p className="text-sm text-slate-700">
          It resolves the wallet to an identity, fetches EAS attestations for
          every required claim topic, checks the attester is currently
          authorized for that topic, validates the payload against the on-chain
          policy, and only returns true if every topic passes.
        </p>
      </section>
    </div>
  );
}
