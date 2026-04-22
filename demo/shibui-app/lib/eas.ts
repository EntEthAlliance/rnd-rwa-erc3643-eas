// Wrappers around @ethereum-attestation-service/eas-sdk — scoped to the two
// things the UI actually does: build a SchemaEncoder for each schema, and
// construct attest/revoke request payloads. Actual transaction submission runs
// through wagmi's useWriteContract so the UX stays consistent with the rest of
// the app (same connector, same status hooks).

import { SchemaEncoder } from "@ethereum-attestation-service/eas-sdk";
import type { Hex } from "viem";
import {
  INVESTOR_ELIGIBILITY_SCHEMA,
  ISSUER_AUTHORIZATION_SCHEMA,
} from "./constants";
import type {
  InvestorEligibility,
  IssuerAuthorization,
} from "./schemas";

export function buildInvestorEligibilityData(e: InvestorEligibility): Hex {
  const encoder = new SchemaEncoder(INVESTOR_ELIGIBILITY_SCHEMA);
  return encoder.encodeData([
    { name: "identity", value: e.identity, type: "address" },
    { name: "kycStatus", value: e.kycStatus, type: "uint8" },
    { name: "amlStatus", value: e.amlStatus, type: "uint8" },
    { name: "sanctionsStatus", value: e.sanctionsStatus, type: "uint8" },
    {
      name: "sourceOfFundsStatus",
      value: e.sourceOfFundsStatus,
      type: "uint8",
    },
    { name: "accreditationType", value: e.accreditationType, type: "uint8" },
    { name: "countryCode", value: e.countryCode, type: "uint16" },
    {
      name: "expirationTimestamp",
      value: e.expirationTimestamp,
      type: "uint64",
    },
    { name: "evidenceHash", value: e.evidenceHash, type: "bytes32" },
    {
      name: "verificationMethod",
      value: e.verificationMethod,
      type: "uint8",
    },
  ]) as Hex;
}

export function buildIssuerAuthorizationData(a: IssuerAuthorization): Hex {
  const encoder = new SchemaEncoder(ISSUER_AUTHORIZATION_SCHEMA);
  return encoder.encodeData([
    { name: "issuerAddress", value: a.issuerAddress, type: "address" },
    {
      name: "authorizedTopics",
      value: a.authorizedTopics,
      type: "uint256[]",
    },
    { name: "issuerName", value: a.issuerName, type: "string" },
  ]) as Hex;
}

// Minimal EAS ABI surface for attest() + revoke() — the shape of the request
// struct per @eas/IEAS.sol. We inline it here so we don't need the SDK's
// provider/signer plumbing for the actual tx send.

export const easAttestRevokeAbi = [
  {
    type: "function",
    name: "attest",
    stateMutability: "payable",
    inputs: [
      {
        name: "request",
        type: "tuple",
        components: [
          { name: "schema", type: "bytes32" },
          {
            name: "data",
            type: "tuple",
            components: [
              { name: "recipient", type: "address" },
              { name: "expirationTime", type: "uint64" },
              { name: "revocable", type: "bool" },
              { name: "refUID", type: "bytes32" },
              { name: "data", type: "bytes" },
              { name: "value", type: "uint256" },
            ],
          },
        ],
      },
    ],
    outputs: [{ name: "", type: "bytes32" }],
  },
  {
    type: "function",
    name: "revoke",
    stateMutability: "payable",
    inputs: [
      {
        name: "request",
        type: "tuple",
        components: [
          { name: "schema", type: "bytes32" },
          {
            name: "data",
            type: "tuple",
            components: [
              { name: "uid", type: "bytes32" },
              { name: "value", type: "uint256" },
            ],
          },
        ],
      },
    ],
    outputs: [],
  },
  {
    type: "event",
    name: "Attested",
    inputs: [
      { name: "recipient", type: "address", indexed: true },
      { name: "attester", type: "address", indexed: true },
      { name: "uid", type: "bytes32", indexed: false },
      { name: "schemaUID", type: "bytes32", indexed: true },
    ],
    anonymous: false,
  },
] as const;
