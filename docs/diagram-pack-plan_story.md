# Diagram Pack Plan — Shibui “Read full story” page

Goal: add a **visual beat per section** using the same clean SVG style as the existing Shibui diagrams, anchored in the **passport analogy**.

## Principles
- Each diagram should answer one reader question.
- Keep labels human-readable (avoid overly technical terms).
- Reinforce the scope boundary: Shibui standardizes the *passport format + verification*, not the issuance lifecycle.

---

## Section-by-section plan

### 1) Problem: Identity is re-done N times
**Diagram:** “Identity silos → duplicated verification”
- Left: multiple institutions repeating checks
- Right: one passport stamp used across many tokens/chains

**Caption (draft):**
“Today, the same investor is verified over and over. Shibui makes one verification portable.”

---

### 2) The Passport System (roles)
**Diagram:** “Passport roles mapped to Shibui roles”
- Issuer/Verifier (institution)
- Passport format (schemas)
- Border gate (token/venue)
- Scanner (on-chain check)
- Revocation (issuer-controlled)

**Caption:**
“Passports work because everyone agrees on the format and how to scan it.”

---

### 3) What Shibui standardizes
**Diagram:** “Inside Shibui vs outside Shibui” (scope boundary)
- Inside: schemas, verification rules, revocation lookup
- Outside: onboarding, renewals, lost passport, liability

**Caption:**
“Shibui standardizes the passport format — not the operational process behind it.”

---

### 4) Passport Format v0.1 (EAS schemas)
**Diagram:** “Two passports” layout
- Holder Passport Stamp (portable)
- Asset Passport Profile (asset/regime-specific)

**Caption:**
“Two standardized documents: one about the holder, one about the asset’s border rules.”

---

### 5) The Stamp (what institutions issue)
**Diagram:** “Institution stamp card”
- Issuer, subject, validity, scope, revocation reference
- A small ‘machine-readable core’ block (ICAO analogy)

**Caption:**
“A stamp is portable proof — it’s not the whole KYC process.”

---

### 6) Border check (enforcement)
**Diagram:** “Gate decision”
- Input: token profile + holder stamp
- Output: allow/deny + reason code

**Caption:**
“Tokens can enforce transfer rules deterministically by scanning the passport.”

---

## Asset-specific passports (reader explanation)
Add a short callout near the format section:

**Callout text (draft):**
“Some assets require different border rules (jurisdiction, regime, investor type). That’s why Shibui uses an asset passport profile alongside the holder passport stamp.”

---

## Deliverables (files)
- `diagrams/story_01_problem.svg`
- `diagrams/story_02_roles.svg`
- `diagrams/story_03_scope_boundary.svg`
- `diagrams/story_04_two_passports.svg`
- `diagrams/story_05_stamp_card.svg`
- `diagrams/story_06_border_check.svg`

(Each exported as SVG; optional PNG fallbacks.)
