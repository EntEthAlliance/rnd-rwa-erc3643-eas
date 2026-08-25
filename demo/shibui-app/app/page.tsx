import Link from "next/link";

export default function LandingPage() {
  return (
    <div className="space-y-10 py-8">
      <section className="space-y-4 max-w-2xl">
        <h1 className="text-3xl font-semibold tracking-tight">Shibui</h1>
        <p className="text-slate-700 text-lg leading-relaxed">
          Open-source investor-eligibility middleware for ERC-3643 tokens. Shibui
          wires{" "}
          <a
            href="https://attest.org"
            target="_blank"
            rel="noreferrer"
            className="text-shibui-accent hover:underline"
          >
            Ethereum Attestation Service
          </a>{" "}
          to the ERC-3643 compliance layer so that KYC / AML attestations issued
          off-chain by authorized providers can gate on-chain token transfers with
          a single{" "}
          <code className="font-mono text-sm">isVerified(wallet) → bool</code>{" "}
          call.
        </p>
        <p className="text-slate-600">
          Built by the{" "}
          <a
            href="https://entethalliance.org"
            target="_blank"
            rel="noreferrer"
            className="text-shibui-accent hover:underline"
          >
            Enterprise Ethereum Alliance
          </a>
          . Deployed on Sepolia testnet.
        </p>
      </section>

      <section>
        <Link
          href="/demo"
          className="inline-flex items-center gap-2 bg-shibui-accent px-6 py-3 text-white font-medium hover:bg-shibui-accentDeep transition"
        >
          Open the live demo →
        </Link>
        <p className="mt-3 text-sm text-slate-500">
          Walk through schema registration, attester authorization, attestation
          issuance, and real-time eligibility checks — all against live Sepolia
          contracts.
        </p>
      </section>

      <section className="grid grid-cols-1 gap-4 md:grid-cols-3 max-w-4xl">
        {[
          {
            title: "EAS-native",
            body: "Attestations are standard EAS schemas — no proprietary data format, auditable on-chain, revocable.",
          },
          {
            title: "Policy-driven",
            body: "Each claim topic (KYC, AML, accreditation, sanctions…) maps to a composable on-chain policy contract.",
          },
          {
            title: "ERC-3643 ready",
            body: "Plugs directly into the ERC-3643 compliance module as a drop-in IIdentityRegistry adapter.",
          },
        ].map((f) => (
          <div key={f.title} className="card space-y-2">
            <h3 className="font-semibold">{f.title}</h3>
            <p className="text-sm text-slate-700">{f.body}</p>
          </div>
        ))}
      </section>
    </div>
  );
}
