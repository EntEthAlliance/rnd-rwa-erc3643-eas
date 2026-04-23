// Minimal ABIs for the Shibui contracts, pared down to only the functions the
// demo UI actually touches. These mirror the canonical Solidity interfaces in
// contracts/interfaces/; when those change, regenerate from `out/*.json` via
// `forge build` and update here.

export const easClaimVerifierAbi = [
  {
    type: "function",
    name: "isVerified",
    stateMutability: "view",
    inputs: [{ name: "userAddress", type: "address" }],
    outputs: [{ name: "", type: "bool" }],
  },
  {
    type: "function",
    name: "registerAttestation",
    stateMutability: "nonpayable",
    inputs: [
      { name: "identity", type: "address" },
      { name: "claimTopic", type: "uint256" },
      { name: "attestationUID", type: "bytes32" },
    ],
    outputs: [],
  },
  {
    type: "function",
    name: "getRegisteredAttestation",
    stateMutability: "view",
    inputs: [
      { name: "identity", type: "address" },
      { name: "claimTopic", type: "uint256" },
      { name: "attester", type: "address" },
    ],
    outputs: [{ name: "", type: "bytes32" }],
  },
  {
    type: "function",
    name: "getSchemaUID",
    stateMutability: "view",
    inputs: [{ name: "claimTopic", type: "uint256" }],
    outputs: [{ name: "", type: "bytes32" }],
  },
] as const;

export const easTrustedIssuersAdapterAbi = [
  {
    type: "function",
    name: "addTrustedAttester",
    stateMutability: "nonpayable",
    inputs: [
      { name: "attester", type: "address" },
      { name: "claimTopics", type: "uint256[]" },
      { name: "authUID", type: "bytes32" },
    ],
    outputs: [],
  },
  {
    type: "function",
    name: "removeTrustedAttester",
    stateMutability: "nonpayable",
    inputs: [{ name: "attester", type: "address" }],
    outputs: [],
  },
  {
    type: "function",
    name: "isAttesterTrusted",
    stateMutability: "view",
    inputs: [
      { name: "attester", type: "address" },
      { name: "claimTopic", type: "uint256" },
    ],
    outputs: [{ name: "", type: "bool" }],
  },
  {
    type: "function",
    name: "getTrustedAttesters",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "address[]" }],
  },
  {
    type: "function",
    name: "getAttesterTopics",
    stateMutability: "view",
    inputs: [{ name: "attester", type: "address" }],
    outputs: [{ name: "", type: "uint256[]" }],
  },
] as const;

export const easIdentityProxyAbi = [
  {
    type: "function",
    name: "registerWallet",
    stateMutability: "nonpayable",
    inputs: [
      { name: "wallet", type: "address" },
      { name: "identity", type: "address" },
    ],
    outputs: [],
  },
  {
    type: "function",
    name: "getIdentity",
    stateMutability: "view",
    inputs: [{ name: "wallet", type: "address" }],
    outputs: [{ name: "", type: "address" }],
  },
  {
    type: "function",
    name: "isRegistered",
    stateMutability: "view",
    inputs: [{ name: "wallet", type: "address" }],
    outputs: [{ name: "", type: "bool" }],
  },
] as const;

// EAS core: just the two functions the UI calls directly (besides what the SDK
// emits under the hood). We use the SDK for signing/building, but the revoke
// and attestation-read calls are easier as raw ABI.
export const easAbi = [
  {
    type: "function",
    name: "getAttestation",
    stateMutability: "view",
    inputs: [{ name: "uid", type: "bytes32" }],
    outputs: [
      {
        type: "tuple",
        components: [
          { name: "uid", type: "bytes32" },
          { name: "schema", type: "bytes32" },
          { name: "time", type: "uint64" },
          { name: "expirationTime", type: "uint64" },
          { name: "revocationTime", type: "uint64" },
          { name: "refUID", type: "bytes32" },
          { name: "recipient", type: "address" },
          { name: "attester", type: "address" },
          { name: "revocable", type: "bool" },
          { name: "data", type: "bytes" },
        ],
      },
    ],
  },
] as const;

export const schemaRegistryAbi = [
  {
    type: "function",
    name: "register",
    stateMutability: "nonpayable",
    inputs: [
      { name: "schema", type: "string" },
      { name: "resolver", type: "address" },
      { name: "revocable", type: "bool" },
    ],
    outputs: [{ name: "", type: "bytes32" }],
  },
  {
    type: "function",
    name: "getSchema",
    stateMutability: "view",
    inputs: [{ name: "uid", type: "bytes32" }],
    outputs: [
      {
        type: "tuple",
        components: [
          { name: "uid", type: "bytes32" },
          { name: "resolver", type: "address" },
          { name: "revocable", type: "bool" },
          { name: "schema", type: "string" },
        ],
      },
    ],
  },
] as const;

// Demo ERC-3643 token — only the surface the reviewer needs.
export const demoTokenAbi = [
  {
    type: "function",
    name: "transfer",
    stateMutability: "nonpayable",
    inputs: [
      { name: "to", type: "address" },
      { name: "amount", type: "uint256" },
    ],
    outputs: [{ name: "", type: "bool" }],
  },
  {
    type: "function",
    name: "balanceOf",
    stateMutability: "view",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    type: "function",
    name: "decimals",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "uint8" }],
  },
  {
    type: "function",
    name: "symbol",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "string" }],
  },
  {
    type: "function",
    name: "mint",
    stateMutability: "nonpayable",
    inputs: [
      { name: "to", type: "address" },
      { name: "amount", type: "uint256" },
    ],
    outputs: [],
  },
] as const;
