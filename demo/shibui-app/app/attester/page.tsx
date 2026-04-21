"use client";

import { useMemo, useState } from "react";
import {
  useAccount,
  usePublicClient,
  useWriteContract,
} from "wagmi";
import { decodeEventLog, isAddress, type Hex } from "viem";
import { ConfigurationGate } from "@/components/ConfigurationGate";
import { StatusBadge } from "@/components/StatusBadge";
import { TxFeedback, type TxState } from "@/components/TxFeedback";
import { getContracts } from "@/lib/contracts";
import {
  ACCREDITATION_TYPE,
  AML_STATUS,
  COUNTRY_USA,
  KYC_STATUS,
  SANCTIONS_STATUS,
  SOURCE_OF_FUNDS,
  TOPIC_LABEL,
  VERIFICATION_METHOD,
} from "@/lib/constants";
import { deployment } from "@/lib/deployments";
import { buildInvestorEligibilityData } from "@/lib/eas";
import { evidenceHash } from "@/lib/schemas";

const ONE_YEAR = 365 * 24 * 60 * 60;

type Form = {
  identity: string;
  kycStatus: number;
  amlStatus: number;
  sanctionsStatus: number;
  sourceOfFundsStatus: number;
  accreditationType: number;
  countryCode: number;
  expirationDays: number;
  evidenceSource: string;
  verificationMethod: number;
  claimTopic: number;
};

const DEFAULT_FORM: Form = {
  identity: "",
  kycStatus: KYC_STATUS.VERIFIED,
  amlStatus: AML_STATUS.CLEAR,
  sanctionsStatus: SANCTIONS_STATUS.CLEAR,
  sourceOfFundsStatus: SOURCE_OF_FUNDS.VERIFIED,
  accreditationType: ACCREDITATION_TYPE.ACCREDITED,
  countryCode: COUNTRY_USA,
  expirationDays: 365,
  evidenceSource: "dossier-2026-Q2-001",
  verificationMethod: VERIFICATION_METHOD.THIRD_PARTY_REVIEWED,
  claimTopic: 1,
};

export default function AttesterPage() {
  return (
    <ConfigurationGate required={["verifier", "schemas"]}>
      <div className="space-y-6">
        <header className="space-y-2">
          <h1 className="text-2xl font-semibold">Attester · KYC operator</h1>
          <p className="text-slate-700">
            Issue a Shibui-compatible Investor Eligibility v2 attestation, then
            register it against the investor's identity. Field values map{" "}
            <em>exactly</em> to the schema — no hidden transforms.
          </p>
        </header>
        <AttesterForm />
      </div>
    </ConfigurationGate>
  );
}

function AttesterForm() {
  const { eas, claimVerifier } = getContracts();
  const { isConnected } = useAccount();
  const [form, setForm] = useState<Form>(DEFAULT_FORM);
  const [attestState, setAttestState] = useState<TxState>({});
  const [registerState, setRegisterState] = useState<TxState>({});
  const [revokeState, setRevokeState] = useState<TxState>({});
  const [uid, setUid] = useState<Hex | null>(null);
  const publicClient = usePublicClient();
  const { writeContractAsync } = useWriteContract();

  const schemaUID = deployment.schemas.investorEligibilityV2;
  const addressOk = isAddress(form.identity);

  const evidence = useMemo(
    () => evidenceHash(form.evidenceSource),
    [form.evidenceSource],
  );

  const update = <K extends keyof Form>(k: K, v: Form[K]) =>
    setForm((f) => ({ ...f, [k]: v }));

  async function sign() {
    if (!addressOk) return;
    setAttestState({ pending: true });
    try {
      const data = buildInvestorEligibilityData({
        identity: form.identity as `0x${string}`,
        kycStatus: form.kycStatus,
        amlStatus: form.amlStatus,
        sanctionsStatus: form.sanctionsStatus,
        sourceOfFundsStatus: form.sourceOfFundsStatus,
        accreditationType: form.accreditationType,
        countryCode: form.countryCode,
        expirationTimestamp: BigInt(
          Math.floor(Date.now() / 1000) + form.expirationDays * 86400,
        ),
        evidenceHash: evidence,
        verificationMethod: form.verificationMethod,
      });
      const hash = await writeContractAsync({
        address: eas.address,
        abi: eas.abi,
        functionName: "attest",
        args: [
          {
            schema: schemaUID,
            data: {
              recipient: form.identity as `0x${string}`,
              expirationTime: BigInt(
                Math.floor(Date.now() / 1000) + form.expirationDays * 86400,
              ),
              revocable: true,
              refUID:
                "0x0000000000000000000000000000000000000000000000000000000000000000",
              data,
              value: 0n,
            },
          },
        ],
      });
      setAttestState({ hash, pending: true });
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
      const newUid = (attested?.args as { uid?: Hex } | undefined)?.uid;
      if (newUid) setUid(newUid);
      setAttestState({ hash, confirmed: true });
    } catch (e) {
      setAttestState({ error: (e as Error).message.slice(0, 200) });
    }
  }

  async function register() {
    if (!uid || !addressOk) return;
    setRegisterState({ pending: true });
    try {
      const hash = await writeContractAsync({
        address: claimVerifier.address,
        abi: claimVerifier.abi,
        functionName: "registerAttestation",
        args: [form.identity as `0x${string}`, BigInt(form.claimTopic), uid],
      });
      setRegisterState({ hash, pending: true });
      await publicClient!.waitForTransactionReceipt({ hash });
      setRegisterState({ hash, confirmed: true });
    } catch (e) {
      setRegisterState({ error: (e as Error).message.slice(0, 200) });
    }
  }

  async function revoke() {
    if (!uid) return;
    setRevokeState({ pending: true });
    try {
      const hash = await writeContractAsync({
        address: eas.address,
        abi: eas.abi,
        functionName: "revoke",
        args: [
          {
            schema: schemaUID,
            data: { uid, value: 0n },
          },
        ],
      });
      setRevokeState({ hash, pending: true });
      await publicClient!.waitForTransactionReceipt({ hash });
      setRevokeState({ hash, confirmed: true });
    } catch (e) {
      setRevokeState({ error: (e as Error).message.slice(0, 200) });
    }
  }

  return (
    <div className="grid grid-cols-1 gap-6 md:grid-cols-2">
      <div className="card space-y-3">
        <h3 className="text-lg font-semibold">Investor Eligibility v2</h3>
        <div>
          <label className="label">Identity address (recipient)</label>
          <input
            className="input"
            placeholder="0x…"
            value={form.identity}
            onChange={(e) => update("identity", e.target.value)}
          />
        </div>
        <SelectField
          label="KYC status"
          value={form.kycStatus}
          options={[
            [KYC_STATUS.NOT_VERIFIED, "NOT_VERIFIED (0)"],
            [KYC_STATUS.VERIFIED, "VERIFIED (1)"],
            [KYC_STATUS.EXPIRED, "EXPIRED (2)"],
            [KYC_STATUS.REVOKED, "REVOKED (3)"],
            [KYC_STATUS.PENDING, "PENDING (4)"],
          ]}
          onChange={(v) => update("kycStatus", v)}
        />
        <SelectField
          label="AML status"
          value={form.amlStatus}
          options={[
            [AML_STATUS.CLEAR, "CLEAR (0)"],
            [AML_STATUS.FLAGGED, "FLAGGED (1)"],
          ]}
          onChange={(v) => update("amlStatus", v)}
        />
        <SelectField
          label="Sanctions status"
          value={form.sanctionsStatus}
          options={[
            [SANCTIONS_STATUS.CLEAR, "CLEAR (0)"],
            [SANCTIONS_STATUS.HIT, "HIT (1)"],
          ]}
          onChange={(v) => update("sanctionsStatus", v)}
        />
        <SelectField
          label="Source of funds"
          value={form.sourceOfFundsStatus}
          options={[
            [SOURCE_OF_FUNDS.NOT_VERIFIED, "NOT_VERIFIED (0)"],
            [SOURCE_OF_FUNDS.VERIFIED, "VERIFIED (1)"],
          ]}
          onChange={(v) => update("sourceOfFundsStatus", v)}
        />
        <SelectField
          label="Accreditation"
          value={form.accreditationType}
          options={[
            [ACCREDITATION_TYPE.NONE, "NONE (0)"],
            [ACCREDITATION_TYPE.RETAIL_QUALIFIED, "RETAIL_QUALIFIED (1)"],
            [ACCREDITATION_TYPE.ACCREDITED, "ACCREDITED (2)"],
            [ACCREDITATION_TYPE.QUALIFIED_PURCHASER, "QUALIFIED_PURCHASER (3)"],
            [ACCREDITATION_TYPE.INSTITUTIONAL, "INSTITUTIONAL (4)"],
          ]}
          onChange={(v) => update("accreditationType", v)}
        />
        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="label">Country (ISO 3166-1)</label>
            <input
              className="input"
              type="number"
              value={form.countryCode}
              onChange={(e) =>
                update("countryCode", Number(e.target.value) || 0)
              }
            />
          </div>
          <div>
            <label className="label">Expiration (days)</label>
            <input
              className="input"
              type="number"
              value={form.expirationDays}
              onChange={(e) =>
                update("expirationDays", Number(e.target.value) || 0)
              }
            />
          </div>
        </div>
        <SelectField
          label="Verification method"
          value={form.verificationMethod}
          options={[
            [VERIFICATION_METHOD.SELF_ATTESTED, "SELF_ATTESTED (1)"],
            [
              VERIFICATION_METHOD.THIRD_PARTY_REVIEWED,
              "THIRD_PARTY_REVIEWED (2)",
            ],
            [
              VERIFICATION_METHOD.PROFESSIONAL_LETTER,
              "PROFESSIONAL_LETTER (3)",
            ],
            [
              VERIFICATION_METHOD.BROKER_DEALER_FILE,
              "BROKER_DEALER_FILE (4)",
            ],
          ]}
          onChange={(v) => update("verificationMethod", v)}
        />
        <div>
          <label className="label">Evidence source (keccak256 → evidenceHash)</label>
          <input
            className="input"
            value={form.evidenceSource}
            onChange={(e) => update("evidenceSource", e.target.value)}
          />
          <p className="mt-1 code text-xs text-slate-500">{evidence}</p>
        </div>
      </div>

      <div className="space-y-4">
        <div className="card space-y-3">
          <div className="flex items-center justify-between">
            <h3 className="text-lg font-semibold">Step 1. Sign & issue</h3>
            {uid ? <StatusBadge tone="ok">Issued</StatusBadge> : null}
          </div>
          <p className="text-sm text-slate-700">
            Wallet signs an <code className="font-mono">attest()</code> on EAS
            using the encoded Investor Eligibility v2 payload above.
          </p>
          <button
            disabled={!isConnected || !addressOk || attestState.pending}
            onClick={sign}
            className="btn-primary"
          >
            {attestState.pending ? "Signing…" : "Sign & issue"}
          </button>
          <TxFeedback state={attestState} />
          {uid ? (
            <div className="code text-slate-600">UID: {uid}</div>
          ) : null}
        </div>

        <div className="card space-y-3">
          <div className="flex items-center justify-between">
            <h3 className="text-lg font-semibold">
              Step 2. Register in Shibui
            </h3>
          </div>
          <p className="text-sm text-slate-700">
            Binds this attestation to a specific claim topic for this identity.
            Shibui's verifier can now find it.
          </p>
          <SelectField
            label="Claim topic"
            value={form.claimTopic}
            options={Object.entries(TOPIC_LABEL).map(
              ([id, label]) =>
                [Number(id), `${label} (topic ${id})`] as [number, string],
            )}
            onChange={(v) => update("claimTopic", v)}
          />
          <button
            disabled={!uid || registerState.pending}
            onClick={register}
            className="btn-primary"
          >
            {registerState.pending ? "Registering…" : "Register attestation"}
          </button>
          <TxFeedback state={registerState} />
        </div>

        <div className="card space-y-3">
          <div className="flex items-center justify-between">
            <h3 className="text-lg font-semibold">Revoke</h3>
          </div>
          <p className="text-sm text-slate-700">
            Revocation takes effect immediately — the next{" "}
            <code className="font-mono">isVerified()</code> read will see it.
          </p>
          <button
            disabled={!uid || revokeState.pending}
            onClick={revoke}
            className="btn-danger"
          >
            {revokeState.pending ? "Revoking…" : "Revoke attestation"}
          </button>
          <TxFeedback state={revokeState} />
        </div>
      </div>
    </div>
  );
}

function SelectField({
  label,
  value,
  options,
  onChange,
}: {
  label: string;
  value: number;
  options: Array<[number, string]>;
  onChange: (n: number) => void;
}) {
  return (
    <div>
      <label className="label">{label}</label>
      <select
        className="input"
        value={value}
        onChange={(e) => onChange(Number(e.target.value))}
      >
        {options.map(([v, l]) => (
          <option key={v} value={v}>
            {l}
          </option>
        ))}
      </select>
    </div>
  );
}
