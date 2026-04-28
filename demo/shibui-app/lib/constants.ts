export const SEPOLIA_CHAIN_ID = 11155111;

export const SEPOLIA_EAS = "0xC2679fBD37d54388Ce493F1DB75320D236e1815e" as const;
export const SEPOLIA_SCHEMA_REGISTRY = "0x0a7E2Ff54e76B8E6659aedc9103FB21c038050D0" as const;

export const INVESTOR_ELIGIBILITY_SCHEMA =
  "address identity,uint8 kycStatus,uint8 amlStatus,uint8 sanctionsStatus,uint8 sourceOfFundsStatus,uint8 accreditationType,uint16 countryCode,uint64 expirationTimestamp,bytes32 evidenceHash,uint8 verificationMethod";

export const ISSUER_AUTHORIZATION_SCHEMA =
  "address issuerAddress,uint256[] authorizedTopics,string issuerName";

export const CLAIM_TOPICS = {
  KYC: 1,
  AML: 2,
  COUNTRY: 3,
  ACCREDITATION: 7,
  PROFESSIONAL: 9,
  INSTITUTIONAL: 10,
  SANCTIONS_CHECK: 13,
  SOURCE_OF_FUNDS: 14,
} as const;

export const DEFAULT_REQUIRED_TOPICS: number[] = [
  CLAIM_TOPICS.KYC,
  CLAIM_TOPICS.ACCREDITATION,
  CLAIM_TOPICS.COUNTRY,
];

export const KYC_STATUS = {
  NOT_VERIFIED: 0,
  VERIFIED: 1,
  EXPIRED: 2,
  REVOKED: 3,
  PENDING: 4,
} as const;

export const AML_STATUS = { CLEAR: 0, FLAGGED: 1 } as const;
export const SANCTIONS_STATUS = { CLEAR: 0, HIT: 1 } as const;
export const SOURCE_OF_FUNDS = { NOT_VERIFIED: 0, VERIFIED: 1 } as const;

export const ACCREDITATION_TYPE = {
  NONE: 0,
  RETAIL_QUALIFIED: 1,
  ACCREDITED: 2,
  QUALIFIED_PURCHASER: 3,
  INSTITUTIONAL: 4,
} as const;

export const VERIFICATION_METHOD = {
  SELF_ATTESTED: 1,
  THIRD_PARTY: 2,
  PROFESSIONAL_LETTER: 3,
  BROKER_DEALER_FILE: 4,
} as const;

export const COUNTRY_USA = 840;

export const TOPIC_LABEL: Record<number, string> = {
  1: "KYC",
  2: "AML",
  3: "Country",
  7: "Accreditation",
  9: "Professional",
  10: "Institutional",
  13: "Sanctions check",
  14: "Source of funds",
};

export const ETHERSCAN_SEPOLIA = "https://sepolia.etherscan.io";
export const EAS_SCAN_SEPOLIA = "https://sepolia.easscan.org";
