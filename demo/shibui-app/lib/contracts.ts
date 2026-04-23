// Typed contract handles, generated from deployments/sepolia.json + abis.ts.
// Call `getContracts()` from a client component to get a bag of { address, abi }
// pairs ready to hand to wagmi's useReadContract / useWriteContract.

import {
  easAbi,
  easClaimVerifierAbi,
  easIdentityProxyAbi,
  easTrustedIssuersAdapterAbi,
  demoTokenAbi,
  schemaRegistryAbi,
} from "./abis";
import { easAttestRevokeAbi } from "./eas";
import { deployment } from "./deployments";

export function getContracts() {
  return {
    eas: {
      address: deployment.eas.EAS,
      abi: [...easAbi, ...easAttestRevokeAbi] as const,
    },
    schemaRegistry: {
      address: deployment.eas.SchemaRegistry,
      abi: schemaRegistryAbi,
    },
    claimVerifier: {
      address: deployment.shibui.EASClaimVerifier,
      abi: easClaimVerifierAbi,
    },
    trustedIssuersAdapter: {
      address: deployment.shibui.EASTrustedIssuersAdapter,
      abi: easTrustedIssuersAdapterAbi,
    },
    identityProxy: {
      address: deployment.shibui.EASIdentityProxy,
      abi: easIdentityProxyAbi,
    },
    demoToken: {
      address: deployment.demo.DemoERC3643Token,
      abi: demoTokenAbi,
    },
  } as const;
}
