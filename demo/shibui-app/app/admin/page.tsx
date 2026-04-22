"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import {
  useAccount,
  usePublicClient,
  useReadContract,
  useWriteContract,
} from "wagmi";
import { decodeEventLog, isAddress, zeroAddress, type Hex } from "viem";
import { ConfigurationGate } from "@/components/ConfigurationGate";
import { StatusBadge } from "@/components/StatusBadge";
import { TxFeedback, type TxState } from "@/components/TxFeedback";
import { getContracts } from "@/lib/contracts";
import {
  INVESTOR_ELIGIBILITY_SCHEMA,
  ISSUER_AUTHORIZATION_SCHEMA,
  DEFAULT_REQUIRED_TOPICS,
  TOPIC_LABEL,
} from "@/lib/constants";
import { deployment } from "@/lib/deployments";
import { buildIssuerAuthorizationData } from "@/lib/eas";
import { easscanSchema } from "@/lib/format";

type Panel = "schemas" | "attester";

export default function AdminPage() {
  const [panel, setPanel] = useState<Panel>("schemas");
  return (
    <ConfigurationGate required={["adapter"]}>
      <div className="space-y-6">
        <header className="space-y-2">
          <h1 className="text-2xl font-semibold">Admin · issuer console</h1>
          <p className="text-slate-700">
            Bootstrap the compliance layer: register the two EAS schemas, then
            authorize KYC providers as trusted attesters. Every action is a
            normal Sepolia transaction signed by your connected wallet.
          </p>
        </header>

        <div className="flex gap-2 border-b border-slate-200">
          <TabButton active={panel === "schemas"} onClick={() => setPanel("schemas")}>
            1. Register schemas
          </TabButton>
          <TabButton active={panel === "attester"} onClick={() => setPanel("attester")}>
            2. Authorize attester
          </TabButton>
        </div>

        {panel === "schemas" ? <RegisterSchemasPanel /> : <AttesterPanel />}
      </div>
    </ConfigurationGate>
  );
}

function TabButton({
  active,
  onClick,
  children,
}: {
  active: boolean;
  onClick: () => void;
  children: React.ReactNode;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={
        "rounded-t-md px-4 py-2 text-sm font-medium transition-colors " +
        (active
          ? "bg-white text-shibui-ink border border-slate-200 border-b-white -mb-px"
          : "text-slate-500 hover:text-shibui-ink")
      }
    >
      {children}
    </button>
  );
}

function RegisterSchemasPanel() {
  const { schemaRegistry } = getContracts();
  const { isConnected } = useAccount();
  const [invEligState, setInvEligState] = useState<TxState>({});
  const [issuerAuthState, setIssuerAuthState] = useState<TxState>({});
  const [invEligUID, setInvEligUID] = useState<Hex | null>(
    deployment.schemas.investorEligibility !==
      "0x0000000000000000000000000000000000000000000000000000000000000000"
      ? deployment.schemas.investorEligibility
      : null,
  );
  const [issuerAuthUID, setIssuerAuthUID] = useState<Hex | null>(
    deployment.schemas.issuerAuthorization !==
      "0x0000000000000000000000000000000000000000000000000000000000000000"
      ? deployment.schemas.issuerAuthorization
      : null,
  );
  const { writeContractAsync } = useWriteContract();
  const publicClient = usePublicClient();

  async function register(
    schema: string,
    resolver: `0x${string}`,
    revocable: boolean,
    setState: (s: TxState) => void,
    setUid: (uid: Hex) => void,
  ) {
    setState({ pending: true });
    try {
      const hash = await writeContractAsync({
        address: schemaRegistry.address,
        abi: schemaRegistry.abi,
        functionName: "register",
        args: [schema, resolver, revocable],
      });
      setState({ hash, pending: true });
      const receipt = await publicClient!.waitForTransactionReceipt({ hash });
      // The Registered event logs the uid; simplest path is to read the return
      // value via call simulation, but we can also pull from the tx receipt.
      // SchemaRegistry emits: Registered(bytes32 indexed uid, address registerer)
      const registered = receipt.logs
        .map((l) => {
          try {
            return decodeEventLog({
              abi: [
                {
                  type: "event",
                  name: "Registered",
                  inputs: [
                    { name: "uid", type: "bytes32", indexed: true },
                    { name: "registerer", type: "address", indexed: false },
                  ],
                  anonymous: false,
                },
              ],
              data: l.data,
              topics: l.topics,
            });
          } catch {
            return null;
          }
        })
        .find((x) => x && x.eventName === "Registered");
      const uid = (registered?.args as { uid?: Hex } | undefined)?.uid;
      if (uid) setUid(uid);
      setState({ hash, confirmed: true });
    } catch (e) {
      setState({ error: (e as Error).message.slice(0, 200) });
    }
  }

  return (
    <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
      <SchemaCard
        title="Investor Eligibility"
        schema={INVESTOR_ELIGIBILITY_SCHEMA}
        uid={invEligUID}
        onRegister={() =>
          register(
            INVESTOR_ELIGIBILITY_SCHEMA,
            zeroAddress,
            true,
            setInvEligState,
            setInvEligUID,
          )
        }
        state={invEligState}
        disabled={!isConnected}
        resolverHint="No resolver — policies enforce at verify time"
      />
      <SchemaCard
        title="Issuer Authorization"
        schema={ISSUER_AUTHORIZATION_SCHEMA}
        uid={issuerAuthUID}
        onRegister={() =>
          register(
            ISSUER_AUTHORIZATION_SCHEMA,
            deployment.shibui.TrustedIssuerResolver,
            true,
            setIssuerAuthState,
            setIssuerAuthUID,
          )
        }
        state={issuerAuthState}
        disabled={!isConnected || deployment.shibui.TrustedIssuerResolver ===
          "0x0000000000000000000000000000000000000000"}
        resolverHint={
          deployment.shibui.TrustedIssuerResolver ===
          "0x0000000000000000000000000000000000000000"
            ? "Deploy TrustedIssuerResolver first"
            : "Resolver gates Issuer Authorization writes to admin-curated authorizers"
        }
      />
      <div className="md:col-span-2 card bg-slate-50">
        <h3 className="text-sm font-semibold">After registering</h3>
        <p className="mt-1 text-sm text-slate-700">
          Copy each UID above into{" "}
          <code className="font-mono">deployments/sepolia.json</code> under{" "}
          <code className="font-mono">schemas.investorEligibility</code> and{" "}
          <code className="font-mono">schemas.issuerAuthorization</code>, then
          wire the topic-to-schema mappings with{" "}
          <code className="font-mono">
            EASClaimVerifier.setTopicSchemaMapping(topic, uid)
          </code>
          .
        </p>
      </div>
    </div>
  );
}

function SchemaCard({
  title,
  schema,
  uid,
  onRegister,
  state,
  disabled,
  resolverHint,
}: {
  title: string;
  schema: string;
  uid: Hex | null;
  onRegister: () => void;
  state: TxState;
  disabled: boolean;
  resolverHint: string;
}) {
  return (
    <div className="card space-y-3">
      <div className="flex items-center justify-between">
        <h3 className="text-lg font-semibold">{title}</h3>
        {uid ? (
          <StatusBadge tone="ok">Registered</StatusBadge>
        ) : (
          <StatusBadge tone="neutral">Not yet registered</StatusBadge>
        )}
      </div>
      <pre className="overflow-auto rounded bg-slate-900 p-3 text-xs text-slate-100">
        {schema}
      </pre>
      <p className="text-xs text-slate-600">{resolverHint}</p>
      {uid ? (
        <div className="space-y-1">
          <div className="label">Schema UID</div>
          <Link
            href={easscanSchema(uid)}
            target="_blank"
            rel="noreferrer"
            className="code text-shibui-accent hover:underline"
          >
            {uid}
          </Link>
        </div>
      ) : null}
      <button
        onClick={onRegister}
        disabled={disabled || state.pending}
        className="btn-primary"
      >
        {state.pending ? "Submitting…" : uid ? "Re-register" : "Register"}
      </button>
      <TxFeedback state={state} />
    </div>
  );
}

function AttesterPanel() {
  const { trustedIssuersAdapter, eas } = getContracts();
  const { address, isConnected } = useAccount();
  const [attester, setAttester] = useState("");
  const [topicsInput, setTopicsInput] = useState(
    DEFAULT_REQUIRED_TOPICS.join(","),
  );
  const [issuerName, setIssuerName] = useState("Acme KYC Services");
  const [authState, setAuthState] = useState<TxState>({});
  const [addState, setAddState] = useState<TxState>({});
  const [authUID, setAuthUID] = useState<Hex | null>(null);
  const publicClient = usePublicClient();
  const { writeContractAsync } = useWriteContract();

  const topics = useMemo(
    () =>
      topicsInput
        .split(",")
        .map((s) => Number(s.trim()))
        .filter((n) => Number.isFinite(n) && n > 0),
    [topicsInput],
  );

  const schemaUID = deployment.schemas.issuerAuthorization;
  const schemaReady =
    schemaUID !==
    "0x0000000000000000000000000000000000000000000000000000000000000000";

  const addressOk = attester.length > 0 && isAddress(attester);

  const { data: trusted, refetch: refetchTrusted } = useReadContract({
    address: trustedIssuersAdapter.address,
    abi: trustedIssuersAdapter.abi,
    functionName: "getTrustedAttesters",
    query: { refetchInterval: 15_000 },
  });

  async function signAuthAttestation() {
    if (!addressOk || !address) return;
    setAuthState({ pending: true });
    try {
      const data = buildIssuerAuthorizationData({
        issuerAddress: attester as `0x${string}`,
        authorizedTopics: topics.map((t) => BigInt(t)),
        issuerName,
      });
      const hash = await writeContractAsync({
        address: eas.address,
        abi: eas.abi,
        functionName: "attest",
        args: [
          {
            schema: schemaUID,
            data: {
              recipient: attester as `0x${string}`,
              expirationTime: 0n,
              revocable: true,
              refUID:
                "0x0000000000000000000000000000000000000000000000000000000000000000",
              data,
              value: 0n,
            },
          },
        ],
      });
      setAuthState({ hash, pending: true });
      const receipt = await publicClient!.waitForTransactionReceipt({ hash });
      const attested = receipt.logs
        .map((l) => {
          try {
            return decodeEventLog({
              abi: eas.abi,
              data: l.data,
              topics: l.topics,
            });
          } catch {
            return null;
          }
        })
        .find((x) => x && x.eventName === "Attested");
      const uid = (attested?.args as { uid?: Hex } | undefined)?.uid;
      if (uid) setAuthUID(uid);
      setAuthState({ hash, confirmed: true });
    } catch (e) {
      setAuthState({ error: (e as Error).message.slice(0, 200) });
    }
  }

  async function addTrusted() {
    if (!authUID || !addressOk) return;
    setAddState({ pending: true });
    try {
      const hash = await writeContractAsync({
        address: trustedIssuersAdapter.address,
        abi: trustedIssuersAdapter.abi,
        functionName: "addTrustedAttester",
        args: [
          attester as `0x${string}`,
          topics.map((t) => BigInt(t)),
          authUID,
        ],
      });
      setAddState({ hash, pending: true });
      await publicClient!.waitForTransactionReceipt({ hash });
      setAddState({ hash, confirmed: true });
      refetchTrusted();
    } catch (e) {
      setAddState({ error: (e as Error).message.slice(0, 200) });
    }
  }

  return (
    <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
      <div className="card space-y-4">
        <h3 className="text-lg font-semibold">Authorize new attester</h3>
        <p className="text-sm text-slate-700">
          Two steps, two transactions: sign a Schema-2 authorization attestation
          (cryptographic audit trail), then call{" "}
          <code className="font-mono">addTrustedAttester</code> on the adapter
          with that attestation's UID.
        </p>
        <div>
          <label className="label">Attester address</label>
          <input
            className="input"
            placeholder="0x…"
            value={attester}
            onChange={(e) => setAttester(e.target.value)}
          />
        </div>
        <div>
          <label className="label">Issuer name (free-text, recorded in attestation)</label>
          <input
            className="input"
            value={issuerName}
            onChange={(e) => setIssuerName(e.target.value)}
          />
        </div>
        <div>
          <label className="label">Claim topics (comma-separated)</label>
          <input
            className="input"
            value={topicsInput}
            onChange={(e) => setTopicsInput(e.target.value)}
          />
          <p className="mt-1 text-xs text-slate-500">
            {topics
              .map((t) => `${t} (${TOPIC_LABEL[t] ?? "?"})`)
              .join(" · ") || "no valid topics"}
          </p>
        </div>
        <div className="space-y-2 pt-3 border-t border-slate-100">
          <div className="flex items-center justify-between">
            <span className="text-sm font-medium">Step 1. Sign authorization attestation</span>
            {authUID ? <StatusBadge tone="ok">Signed</StatusBadge> : null}
          </div>
          <button
            disabled={!schemaReady || !isConnected || !addressOk || authState.pending}
            onClick={signAuthAttestation}
            className="btn-primary"
          >
            {authState.pending ? "Signing…" : "Sign attestation"}
          </button>
          {!schemaReady ? (
            <p className="text-xs text-amber-700">
              Register Issuer Authorization first (step 1 tab).
            </p>
          ) : null}
          <TxFeedback state={authState} />
          {authUID ? (
            <div className="code text-slate-600">authUID: {authUID}</div>
          ) : null}
        </div>
        <div className="space-y-2 pt-3 border-t border-slate-100">
          <div className="flex items-center justify-between">
            <span className="text-sm font-medium">Step 2. addTrustedAttester</span>
          </div>
          <button
            disabled={!authUID || !isConnected || addState.pending}
            onClick={addTrusted}
            className="btn-primary"
          >
            {addState.pending ? "Submitting…" : "Add to adapter"}
          </button>
          <TxFeedback state={addState} />
        </div>
      </div>

      <div className="card space-y-3">
        <h3 className="text-lg font-semibold">Current trusted attesters</h3>
        {trusted && trusted.length > 0 ? (
          <ul className="divide-y divide-slate-100">
            {trusted.map((a) => (
              <AttesterRow key={a} attester={a as `0x${string}`} />
            ))}
          </ul>
        ) : (
          <p className="text-sm text-slate-600">
            None yet. Authorize one using the form on the left.
          </p>
        )}
        <button
          onClick={() => refetchTrusted()}
          className="text-xs text-slate-500 hover:text-slate-800"
        >
          ↻ Refresh
        </button>
      </div>
    </div>
  );
}

function AttesterRow({ attester }: { attester: `0x${string}` }) {
  const { trustedIssuersAdapter } = getContracts();
  const { data: topics } = useReadContract({
    address: trustedIssuersAdapter.address,
    abi: trustedIssuersAdapter.abi,
    functionName: "getAttesterTopics",
    args: [attester],
  });
  return (
    <li className="py-2">
      <div className="code text-slate-800">{attester}</div>
      <div className="mt-1 flex flex-wrap gap-1 text-xs">
        {(topics as readonly bigint[] | undefined)?.map((t) => (
          <StatusBadge key={String(t)} tone="info">
            {TOPIC_LABEL[Number(t)] ?? `topic ${t}`}
          </StatusBadge>
        ))}
      </div>
    </li>
  );
}
