import { ETHERSCAN_SEPOLIA, EAS_SCAN_SEPOLIA } from "./constants";

export function shortAddr(a?: string): string {
  if (!a) return "—";
  if (a.length < 10) return a;
  return `${a.slice(0, 6)}…${a.slice(-4)}`;
}

export function etherscanTx(hash: string): string {
  return `${ETHERSCAN_SEPOLIA}/tx/${hash}`;
}

export function etherscanAddress(addr: string): string {
  return `${ETHERSCAN_SEPOLIA}/address/${addr}`;
}

export function easscanAttestation(uid: string): string {
  return `${EAS_SCAN_SEPOLIA}/attestation/view/${uid}`;
}

export function easscanSchema(uid: string): string {
  return `${EAS_SCAN_SEPOLIA}/schema/view/${uid}`;
}

// Best-effort decoding of compliance reverts. ERC-3643 tokens typically bubble
// up a string revert from the compliance module ("Compliance not followed").
// Shibui's EASClaimVerifier returns `false` from isVerified() rather than
// reverting, so the token's own `canTransfer` check is what surfaces here.
export function decodeTransferRevert(err: unknown): string {
  const msg = (err as { shortMessage?: string; message?: string })?.shortMessage
    ?? (err as { message?: string })?.message
    ?? String(err);
  if (/compliance/i.test(msg)) return "Compliance blocked this transfer";
  if (/identity/i.test(msg)) return "Identity not registered for recipient";
  if (/frozen/i.test(msg)) return "Sender or recipient is frozen";
  return msg.length > 180 ? msg.slice(0, 177) + "…" : msg;
}
