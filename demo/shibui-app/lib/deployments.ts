import sepolia from "./_deployments.generated.json";
import type { Address, Hex } from "viem";

export type InvestorKey = "alice" | "bob" | "carol";

export type Deployment = {
  chainId: number;
  network: string;
  eas: {
    EAS: Address;
    SchemaRegistry: Address;
  };
  shibui: {
    EASClaimVerifier: Address;
    EASTrustedIssuersAdapter: Address;
    EASIdentityProxy: Address;
    ClaimTopicsRegistry: Address;
    TrustedIssuerResolver: Address;
    policies: Record<string, Address>;
  };
  schemas: {
    investorEligibility: Hex;
    issuerAuthorization: Hex;
  };
  demo: {
    DemoERC3643Token: Address;
    investors: Record<
      InvestorKey,
      { wallet: Address; identity: Address; description: string }
    >;
    attestations: Record<string, Hex>;
  };
  lastUpdated: string | null;
  deployer: string | null;
  deploymentBlock: number | null;
};

export const ZERO_ADDRESS =
  "0x0000000000000000000000000000000000000000" as const;
export const ZERO_BYTES32 =
  "0x0000000000000000000000000000000000000000000000000000000000000000" as const;

export const deployment = sepolia as unknown as Deployment;

export function isAddressConfigured(a: string | undefined): boolean {
  return !!a && a.toLowerCase() !== ZERO_ADDRESS;
}

export function isBytes32Configured(b: string | undefined): boolean {
  return !!b && b.toLowerCase() !== ZERO_BYTES32;
}

export type ConfigGap = { label: string; path: string };

export function deploymentGaps(d: Deployment = deployment): ConfigGap[] {
  const gaps: ConfigGap[] = [];
  const push = (label: string, path: string, ok: boolean) => {
    if (!ok) gaps.push({ label, path });
  };
  push(
    "EASClaimVerifier",
    "shibui.EASClaimVerifier",
    isAddressConfigured(d.shibui.EASClaimVerifier),
  );
  push(
    "EASTrustedIssuersAdapter",
    "shibui.EASTrustedIssuersAdapter",
    isAddressConfigured(d.shibui.EASTrustedIssuersAdapter),
  );
  push(
    "EASIdentityProxy",
    "shibui.EASIdentityProxy",
    isAddressConfigured(d.shibui.EASIdentityProxy),
  );
  push(
    "Investor Eligibility schema UID",
    "schemas.investorEligibility",
    isBytes32Configured(d.schemas.investorEligibility),
  );
  push(
    "Issuer Authorization schema UID",
    "schemas.issuerAuthorization",
    isBytes32Configured(d.schemas.issuerAuthorization),
  );
  push(
    "DemoERC3643Token",
    "demo.DemoERC3643Token",
    isAddressConfigured(d.demo.DemoERC3643Token),
  );
  return gaps;
}
