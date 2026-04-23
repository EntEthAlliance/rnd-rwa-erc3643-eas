import { encodeAbiParameters, keccak256, toBytes, type Hex } from "viem";
import {
  INVESTOR_ELIGIBILITY_SCHEMA,
  ISSUER_AUTHORIZATION_SCHEMA,
} from "./constants";

export type InvestorEligibility = {
  identity: `0x${string}`;
  kycStatus: number;
  amlStatus: number;
  sanctionsStatus: number;
  sourceOfFundsStatus: number;
  accreditationType: number;
  countryCode: number;
  expirationTimestamp: bigint;
  evidenceHash: `0x${string}`;
  verificationMethod: number;
};

export function encodeInvestorEligibility(data: InvestorEligibility): Hex {
  return encodeAbiParameters(
    [
      { name: "identity", type: "address" },
      { name: "kycStatus", type: "uint8" },
      { name: "amlStatus", type: "uint8" },
      { name: "sanctionsStatus", type: "uint8" },
      { name: "sourceOfFundsStatus", type: "uint8" },
      { name: "accreditationType", type: "uint8" },
      { name: "countryCode", type: "uint16" },
      { name: "expirationTimestamp", type: "uint64" },
      { name: "evidenceHash", type: "bytes32" },
      { name: "verificationMethod", type: "uint8" },
    ],
    [
      data.identity,
      data.kycStatus,
      data.amlStatus,
      data.sanctionsStatus,
      data.sourceOfFundsStatus,
      data.accreditationType,
      data.countryCode,
      data.expirationTimestamp,
      data.evidenceHash,
      data.verificationMethod,
    ],
  );
}

export type IssuerAuthorization = {
  issuerAddress: `0x${string}`;
  authorizedTopics: bigint[];
  issuerName: string;
};

export function encodeIssuerAuthorization(data: IssuerAuthorization): Hex {
  return encodeAbiParameters(
    [
      { name: "issuerAddress", type: "address" },
      { name: "authorizedTopics", type: "uint256[]" },
      { name: "issuerName", type: "string" },
    ],
    [data.issuerAddress, data.authorizedTopics, data.issuerName],
  );
}

// Convenience: derive a keccak256 evidence hash from a free-text KYC dossier
// reference. This is what a KYC provider would do off-chain; showing it in the
// UI keeps the field explicit rather than a black box.
export function evidenceHash(source: string): Hex {
  return keccak256(toBytes(source));
}

export const SCHEMAS = {
  investorEligibility: INVESTOR_ELIGIBILITY_SCHEMA,
  issuerAuthorization: ISSUER_AUTHORIZATION_SCHEMA,
};
