# Shibui Passport Format v0.1 (EAS Schemas)

## What this is
Shibui is about **agreement on the passport format** — the Ethereum-native equivalent of what ICAO standardized for physical passports: a **simple, machine-readable core** that any border gate (token) can scan the same way.

In practice, that means:
- a small set of **canonical EAS schemas** (the “passport format”)
- clear **versioning rules**
- clear **required fields** (so verification is interoperable)

## What this is NOT
Shibui does **not** standardize the operational lifecycle:
- how an institution performs KYC/KYB
- renewals / re-issuance / “lost passport” handling
- who holds legal liability

Those remain the responsibility of the institution that issues the stamp.

---

## Design principles
1. **Machine-readable first**: the core must be unambiguous and easy to validate in code.
2. **Portable across assets/chains**: stamps can be scoped, but the format stays stable.
3. **Minimal required fields**: extensions are allowed, but the core is consistent.
4. **Issuer accountability**: every stamp says who issued it and under what scope.

---

## Canonical schemas (v0.1)
We standardize **two** EAS schemas:

1) **Holder Passport Stamp** — facts about the holder (person/entity)
2) **Asset Passport Profile** — what rules apply to a given asset (token/regime)

### 1) Holder Passport Stamp (v0.1)
**Intent:** “What is true about this holder, as asserted by an institution?”

**Recommended schema name:**
`shibui.holder_passport_stamp.v0_1`

**Required fields (canonical):**
- `subject` (bytes32 or address): the holder identifier (wallet, DID hash, or entity ref)
- `issuer` (address): the institution/authority issuing the stamp
- `jurisdiction` (bytes2 or string): ISO country code (or equivalent)
- `holder_type` (uint8): natural person / legal entity / other
- `kyc_tier` (uint8): tiered level (0..n)
- `investor_category` (uint8): e.g., retail / professional / accredited / eligible counterparty
- `issued_at` (uint64): unix time
- `expires_at` (uint64): unix time
- `revocable` (bool)
- `revocation_ref` (bytes32): pointer for revocation lookup / reason code

**Optional extensions (non-canonical, allowed):**
- `risk_band` (uint8)
- `evidence_ref` (bytes32) — hash/pointer to off-chain evidence
- `sanctions_screened` (bool)

**Notes:**
- This stamp is **portable**: it can be used across many assets, subject to each asset’s profile.

---

### 2) Asset Passport Profile (v0.1)
**Intent:** “What does this asset require at the border?”

**Recommended schema name:**
`shibui.asset_passport_profile.v0_1`

**Required fields (canonical):**
- `asset_id` (bytes32): canonical identifier (recommended: keccak256(chain_id, token_address))
- `chain_id` (uint64)
- `token` (address)
- `regime` (uint16): a small registry-backed code (e.g., 0=unknown, 1=US_REG_D, 2=EU_PROSPECTUS, ...)
- `required_kyc_tier` (uint8)
- `allowed_investor_categories` (uint256 bitset)
- `issued_at` (uint64)
- `expires_at` (uint64)
- `issuer` (address): who defined/maintains this profile (issuer/TA/administrator)
- `revocable` (bool)
- `revocation_ref` (bytes32)

**Optional extensions (allowed):**
- `transfer_restrictions_ref` (bytes32) — pointer to detailed rule set (off-chain or on-chain)

**Notes:**
- This profile is typically **asset-specific** (and may vary by jurisdiction/regime).

---

## Versioning rules (must-follow)
We use an explicit version in the schema name: `vMAJOR_MINOR` (example: `v0_1`).

Rules:
1. **Never mutate a published schema** (even if EAS allows it). Publish a new version.
2. **MAJOR** bumps when a verifier would have to change logic.
3. **MINOR** bumps when adding optional fields only.
4. Required fields list and order are part of the contract.
5. Maintain a `SCHEMA_REGISTRY.md` mapping:
   - schema name → EAS schema UID
   - version → previous version
   - change summary

---

## “ICAO-style machine-readable block” (reader-friendly explanation)
Physical passports work globally because ICAO standardized a **small machine-readable core** that scanners understand everywhere.

Shibui’s equivalent is:
- a small set of **EAS schemas** with
- a stable **required-field core**

So any token, venue, or compliance contract can “scan the passport” the same way.

---

## Open questions to confirm (v0.2 candidates)
- Do we standardize `subject` as an **address** (simple) or **bytes32** (flexible for DID/entity refs)?
- Do we encode jurisdiction as ISO-3166-1 alpha-2 (`US`, `FR`) or a numeric code?
- Do we publish a registry for `regime` codes and `investor_category` enums?
