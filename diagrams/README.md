# Diagrams

Mermaid source files (`.mmd`) explaining Shibui's current architecture (post audit refactor, v0.4.x).

The diagrams are rendered inline below. Source `.mmd` files live in this directory.

---

## Architecture — what lives where and who controls it

### Architecture overview

Full component + control plane (token, verifier, policies × 8, adapter, resolver, proxy, multisig). Source: [`architecture-overview.mmd`](architecture-overview.mmd).

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryColor': '#f0f0f0', 'primaryTextColor': '#333', 'primaryBorderColor': '#666', 'lineColor': '#666', 'secondaryColor': '#e0e0e0', 'tertiaryColor': '#fff'}}}%%
flowchart TB
    %% Shibui v0.4 architecture — payload-aware verifier wired behind an
    %% ERC-3643 Identity Registry via the IIdentityVerifier extension point
    %% (ERC-3643/ERC-3643 PR #98). Backend is total, not hybrid: when the
    %% Identity Registry has a verifier set, the built-in ONCHAINID path is
    %% skipped entirely. Only one backend is active at a time.

    subgraph TokenLayer["ERC-3643 Token Layer"]
        Token["Token Contract"]
        Compliance["Compliance Module(s)"]
        IR["Identity Registry\n(IIdentityVerifier extension point)"]
    end

    subgraph ShibuiLayer["Shibui Identity Verifier (backend)"]
        ECV["EASClaimVerifier\n(payload-aware)"]
        TIA["EASTrustedIssuersAdapter\n(Schema-2-gated trust)"]
        EIP["EASIdentityProxy\n(wallet↔identity, AGENT_ROLE)"]
        CTR["Claim Topics Registry"]

        subgraph Policies["ITopicPolicy × 8"]
            KYC["KYCStatusPolicy"]
            AML["AMLPolicy"]
            COUNTRY["CountryAllowListPolicy"]
            ACC["AccreditationPolicy"]
            PRO["ProfessionalInvestor"]
            INST["InstitutionalInvestor"]
            SANC["SanctionsPolicy"]
            SOF["SourceOfFundsPolicy"]
        end
    end

    subgraph EASLayer["EAS Protocol"]
        EAS["EAS.sol"]
        SR["Schema Registry"]
        Resolver["TrustedIssuerResolver\n(gates Schema-2 writes)"]
    end

    subgraph Admin["Control plane"]
        Multisig["Compliance Multisig\n(DEFAULT_ADMIN_ROLE)"]
        Op["Operators\n(OPERATOR_ROLE)"]
        Agent["Agents\n(AGENT_ROLE)"]
    end

    Token -->|canTransfer| Compliance
    Compliance -->|isVerified| IR
    IR -->|delegates| ECV

    ECV -->|resolve identity| EIP
    ECV -->|required topics| CTR
    ECV -->|trusted attesters| TIA
    ECV -->|fetch attestation| EAS
    ECV -->|validate payload| Policies

    TIA -.->|authUID→Schema 2| EAS
    EAS -.->|gate Schema-2 writes| Resolver
    EAS --> SR

    Multisig -.->|admin| ECV
    Multisig -.->|admin| TIA
    Multisig -.->|admin| EIP
    Multisig -.->|owner| Resolver
    Op -.->|day-to-day| ECV
    Op -.->|day-to-day| TIA
    Agent -.->|wallet bindings| EIP

    style Token fill:#e3f2fd
    style Compliance fill:#e3f2fd
    style IR fill:#e3f2fd

    style ECV fill:#c8e6c9
    style TIA fill:#c8e6c9
    style EIP fill:#c8e6c9
    style CTR fill:#c8e6c9
    style Policies fill:#dcedc8

    style EAS fill:#fff3e0
    style SR fill:#fff3e0
    style Resolver fill:#fff3e0

    style Multisig fill:#fce4ec
    style Op fill:#fce4ec
    style Agent fill:#fce4ec
```

### Pluggable backend verification

`IIdentityVerifier` extension point in the ERC-3643 Identity Registry: either the default ONCHAINID path runs, or Shibui runs. Delegation is total, not hybrid. Source: [`pluggable-backend-verification.mmd`](pluggable-backend-verification.mmd).

```mermaid
flowchart TD
    %% Shibui v0.4 + upstream ERC-3643/ERC-3643 PR #98:
    %% the Identity Registry holds an optional _identityVerifier slot.
    %% When set (non-zero), isVerified delegates entirely to that backend.
    %% When zero, the built-in ONCHAINID flow runs. This is NOT dual-mode —
    %% only one backend ever executes per call.

    Start([Token Transfer Request])
    IR{"Identity Registry\n_identityVerifier set?"}

    subgraph BuiltIn["Default path (no external verifier)"]
        direction TB
        OCID_Check{"ONCHAINID registered\nfor wallet?"}
        IRS["IdentityRegistryStorage"]
        OCID["IIdentity Contract (ONCHAINID)"]
        CI["IClaimIssuer.isClaimValid"]
        OCID_Valid{"Required claims\nall valid?"}
    end

    subgraph Shibui["External Shibui verifier"]
        direction TB
        ECV["EASClaimVerifier.isVerified"]
        EIP["EASIdentityProxy\n(resolve wallet→identity)"]
        TIA["EASTrustedIssuersAdapter\n(per-topic trusted list)"]
        EAS["EAS.sol"]
        POL["ITopicPolicy\n(payload predicate per topic)"]
        EAS_Valid{"All required topics\npass policy?"}
    end

    Verified([Verification Passed])
    NotVerified([Verification Failed])

    Start --> IR

    IR -->|"_identityVerifier == 0"| OCID_Check
    OCID_Check -->|Yes| IRS --> OCID --> CI --> OCID_Valid
    OCID_Valid -->|Yes| Verified
    OCID_Valid -->|No| NotVerified
    OCID_Check -->|No| NotVerified

    IR -->|"_identityVerifier != 0"| ECV
    ECV --> EIP
    ECV --> TIA
    TIA --> EAS
    ECV --> POL
    POL --> EAS_Valid
    EAS_Valid -->|Yes| Verified
    EAS_Valid -->|No| NotVerified

    style Verified fill:#c8e6c9,stroke:#2e7d32
    style NotVerified fill:#ffcdd2,stroke:#c62828
    style ECV fill:#bbdefb,stroke:#1976d2
    style POL fill:#dcedc8,stroke:#558b2f
    style OCID fill:#e1bee7,stroke:#7b1fa2
```

### Shibui — before / after

Single-vendor identity stack vs. pluggable backend with payload-aware verification. Source: [`shibui-before-after.mmd`](shibui-before-after.mmd).

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryColor': '#f0f0f0', 'primaryTextColor': '#333', 'primaryBorderColor': '#666', 'lineColor': '#444'}}}%%
flowchart LR
    subgraph Before["BEFORE: Single-vendor identity stack"]
        direction TB
        B_Investor["👤 Investor"]
        B_Provider["ONCHAINID-compatible<br/>KYC Provider"]
        B_Identity["ONCHAINID Contract<br/>(deployed per investor)"]
        B_Token["ERC-3643 Token"]
        B_IR["Identity Registry<br/>(reads ERC-735 claims directly)"]

        B_Investor -->|"KYC"| B_Provider
        B_Provider -->|"ERC-735 claim"| B_Identity
        B_Identity -->|"queried by"| B_IR
        B_IR -->|"isVerified"| B_Token
    end

    subgraph After["AFTER: Pluggable backend + payload-aware verifier"]
        direction TB
        A_Investor["👤 Investor"]
        A_Provider1["KYC Provider A"]
        A_Provider2["KYC Provider B"]
        A_Provider3["AML / Sanctions Screener"]
        A_EAS["EAS<br/>(Ethereum Attestation Service)"]
        A_Shibui["EASClaimVerifier<br/>+ 8 ITopicPolicy modules"]
        A_IR["Identity Registry<br/>(IIdentityVerifier extension point)"]
        A_Token["ERC-3643 Token"]

        A_Investor -->|"one KYC"| A_Provider1
        A_Investor -.->|"or"| A_Provider2
        A_Provider3 -.->|"screens separately"| A_Investor
        A_Provider1 -->|"Investor Eligibility attestation"| A_EAS
        A_Provider2 -->|"Investor Eligibility attestation"| A_EAS
        A_Provider3 -->|"sanctions attestation"| A_EAS
        A_EAS -->|"read by"| A_Shibui
        A_Shibui -->|"setIdentityVerifier(shibui)"| A_IR
        A_IR -->|"isVerified"| A_Token
    end

    Before ~~~ After

    style Before fill:#fee2e2,stroke:#dc2626
    style After fill:#dcfce7,stroke:#16a34a
    style A_EAS fill:#dbeafe,stroke:#2563eb
    style A_Shibui fill:#fef3c7,stroke:#d97706
```

---

## Behavioural flows — what happens on a transfer / revocation

### Transfer verification flow

Sequence from `token.transfer` through compliance → Identity Registry → `EASClaimVerifier` → per-topic `ITopicPolicy.validate`. Source: [`transfer-verification-flow.mmd`](transfer-verification-flow.mmd).

```mermaid
sequenceDiagram
    %% Shibui v0.4 verification flow: token → compliance → Identity Registry
    %% → IIdentityVerifier (Shibui backend) → payload-aware policy dispatch.
    participant User
    participant Token as Token Core (ERC-3643)
    participant Compliance as Compliance Module(s)
    participant IR as Identity Registry (IIdentityVerifier)
    participant Verifier as EASClaimVerifier
    participant EIP as EASIdentityProxy
    participant CTR as Claim Topics Registry
    participant TIA as EASTrustedIssuersAdapter
    participant EAS as EAS.sol
    participant Policy as ITopicPolicy (per topic)

    User->>Token: transfer(to, amount)
    Token->>Compliance: canTransfer(from, to, amount)

    Compliance->>IR: isVerified(to)

    Note over IR,Verifier: Extension point (ERC-3643/ERC-3643 #98):<br/>IR delegates to Shibui when _identityVerifier != 0
    IR->>Verifier: isVerified(userAddress)

    Verifier->>EIP: getIdentity(userAddress)
    EIP-->>Verifier: identityAddress

    Verifier->>CTR: getClaimTopics()
    CTR-->>Verifier: [topic1, topic2, ...]

    loop For each required claim topic
        Verifier->>Verifier: lookup _topicToPolicy[topic]<br/>(reverts if unset — PolicyNotConfiguredForTopic)
        Verifier->>Verifier: lookup _topicToSchema[topic]
        Verifier->>TIA: getTrustedAttestersForTopic(topic)
        TIA-->>Verifier: [attester1, ... attesterN] (N ≤ MAX_ATTESTERS_PER_TOPIC=5)

        loop For each trusted attester (short-circuit on first pass)
            Verifier->>Verifier: uid = _registeredAttestations[id][topic][attester]
            alt uid != 0
                Verifier->>EAS: getAttestation(uid)
                EAS-->>Verifier: Attestation{schema, data, revocationTime, expirationTime, attester}

                Verifier->>Verifier: schema match? not revoked?<br/>not expired? attester still trusted?

                alt structural checks pass
                    Verifier->>Policy: validate(attestation)
                    Note over Policy: decodes Investor Eligibility payload<br/>enforces topic rule<br/>(kycStatus, country, accreditation, ...)
                    Policy-->>Verifier: true/false
                    alt policy returns true
                        Note over Verifier: Topic satisfied — break inner loop
                    end
                end
            end
        end
    end

    Verifier-->>IR: true / false
    IR-->>Compliance: verified / not verified
    Compliance-->>Token: canTransfer result

    alt Transfer allowed
        Token->>Token: execute transfer
        Token-->>User: success
    else Transfer blocked
        Token-->>User: revert ("Transfer not possible")
    end
```

### Revocation flow

Attester revokes on EAS → next `isVerified` returns false → transfer blocked. Source: [`revocation-flow.mmd`](revocation-flow.mmd).

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryColor': '#f0f0f0', 'primaryTextColor': '#333', 'primaryBorderColor': '#666', 'lineColor': '#444'}}}%%
sequenceDiagram
    participant CO as ⚖️ Compliance Officer
    participant KYC as 🔍 KYC Provider
    participant EAS as 📋 EAS Contract
    participant Shibui as 🔒 Shibui Verifier
    participant Token as 📜 ERC-3643 Token
    participant Bob as 👤 Bob (Investor)

    Note over CO,Bob: Bob is currently ELIGIBLE — holds tokens, can trade

    CO->>KYC: Bob failed AML re-check
    KYC->>EAS: revoke(bob's attestation UID)
    EAS-->>EAS: attestation.revocationTime = now

    Note over EAS: Attestation is now REVOKED on-chain

    Bob->>Token: transfer(alice, 100 tokens)
    Token->>Shibui: isVerified(bob)?
    Shibui->>EAS: getAttestation(uid)
    EAS-->>Shibui: attestation (revocationTime ≠ 0)
    Shibui-->>Token: FALSE ❌
    Token-->>Bob: TRANSFER BLOCKED

    Note over CO,Bob: Bob cannot trade until re-verified with a new attestation

    rect rgb(254, 243, 199)
        Note over KYC,EAS: Alternative: Issuer removes trust in the entire provider
        Note over KYC,EAS: adapter.removeTrustedAttester(provider)
        Note over KYC,EAS: ALL attestations from that provider become invalid instantly
    end
```

### Attestation lifecycle

State machine from unverified → active → revoked / expired → renewed. Includes Investor Eligibility payload fields. Source: [`attestation-lifecycle.mmd`](attestation-lifecycle.mmd).

```mermaid
stateDiagram-v2
    [*] --> Unverified: Investor onboards

    state KYCProcess {
        OffchainKYC: Offchain KYC
        KYCApproved: KYC Approved
        KYCRejected: KYC Rejected
    }

    Unverified --> OffchainKYC: Submit documents
    OffchainKYC --> KYCApproved: Documents verified
    OffchainKYC --> KYCRejected: Documents rejected

    state EASAttestation {
        Creating: Creating Attestation
        Registering: Registering in Verifier
        Active: Attestation Active
    }

    KYCApproved --> Creating: KYC provider calls EAS.attest()
    Creating --> Registering: registerAttestation()
    Registering --> Active: Attestation registered

    state Verified {
        CanTransfer: Can Transfer Tokens
        CanHold: Can Hold Tokens
    }

    Active --> CanTransfer: isVerified() = true
    Active --> CanHold

    state Revoked {
        AttestationRevoked: Attestation Revoked
    }

    Active --> AttestationRevoked: attester.revoke()
    AttestationRevoked --> Unverified: isVerified() = false

    state Expired {
        AttestationExpired: Attestation Expired
    }

    Active --> AttestationExpired: Time passes
    AttestationExpired --> Unverified: isVerified() = false

    state Renewal {
        NewKYC: New KYC Process
        NewAttestation: New Attestation
    }

    AttestationExpired --> NewKYC: Investor re-verifies
    Unverified --> NewKYC: Investor re-applies
    NewKYC --> NewAttestation: KYC approved again
    NewAttestation --> Active: New attestation active

    KYCRejected --> [*]: Exit

    note right of Active
        Investor Eligibility payload fields:
        - identity, kycStatus, amlStatus
        - sanctionsStatus, sourceOfFundsStatus
        - accreditationType, countryCode
        - expirationTimestamp
        - evidenceHash, verificationMethod

        isVerified() also runs the topic's
        ITopicPolicy against this payload —
        e.g. kycStatus == VERIFIED,
        countryCode in allow-list,
        accreditationType in allowed-set.
        Existence alone is not sufficient.
    end note

    note right of AttestationRevoked
        Revocation reasons:
        - Compliance violation
        - Fraud detected
        - User request
    end note
```

### Wallet ↔ identity mapping

How multiple wallets resolve to a single identity in `EASIdentityProxy`. Source: [`wallet-identity-mapping.mmd`](wallet-identity-mapping.mmd).

```mermaid
flowchart LR
    subgraph Wallets["User Wallets"]
        W1[Wallet 1\n0xAAA...111]
        W2[Wallet 2\n0xAAA...222]
        W3[Wallet 3\n0xAAA...333]
    end

    subgraph EASIdentityProxy["EAS Identity Proxy"]
        direction TB
        Mapping["_walletToIdentity mapping"]
        Resolve["getIdentity(wallet)"]
    end

    subgraph Identities["Identity Addresses"]
        I1[Identity A\n0xBBB...111]
        I2[Identity B\n0xBBB...222]
    end

    subgraph EASAttestations["EAS Attestations (Investor Eligibility)"]
        A1["Attestation 1\nrecipient: Identity A\ntopic: KYC\nkycStatus: VERIFIED\nevidenceHash: 0x…\nverificationMethod: third-party"]
        A2["Attestation 2\nrecipient: Identity A\ntopic: ACCREDITATION\naccreditationType: ACCREDITED"]
        A3["Attestation 3\nrecipient: Identity B\ntopic: KYC\nkycStatus: VERIFIED"]
    end

    W1 -->|registered to| Mapping
    W2 -->|registered to| Mapping
    W3 -->|registered to| Mapping

    Mapping -->|maps to| I1
    Mapping -->|maps to| I2

    W1 -.->|resolves to| I1
    W2 -.->|resolves to| I1
    W3 -.->|resolves to| I2

    I1 -->|has| A1
    I1 -->|has| A2
    I2 -->|has| A3

    subgraph Verification["Verification Flow"]
        V1["isVerified(Wallet 1)"]
        V2["getIdentity(Wallet 1) → Identity A"]
        V3["Check attestations for Identity A"]
        V4["KYC ✓ ACCREDITATION ✓"]
        V5["Return: true"]

        V1 --> V2 --> V3 --> V4 --> V5
    end

    style W1 fill:#e3f2fd
    style W2 fill:#e3f2fd
    style W3 fill:#e3f2fd
    style I1 fill:#fff3e0
    style I2 fill:#fff3e0
    style A1 fill:#c8e6c9
    style A2 fill:#c8e6c9
    style A3 fill:#c8e6c9
    style V5 fill:#c8e6c9,stroke:#2e7d32
```

---

## People / roles

### Stakeholder interactions

Token issuer, compliance multisig (DEFAULT_ADMIN_ROLE), operators (OPERATOR_ROLE), agents (AGENT_ROLE), KYC providers, investors, token contract. Source: [`stakeholder-interactions.mmd`](stakeholder-interactions.mmd).

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryColor': '#f0f0f0', 'primaryTextColor': '#333', 'primaryBorderColor': '#666', 'lineColor': '#444'}}}%%
flowchart TB
    subgraph Stakeholders["Who does what in a Shibui-backed deployment"]
        direction TB

        subgraph IssuerOrg["🏢 Token Issuer"]
            I1["Deploy the Shibui stack<br/>(verifier + adapter + proxy + policies + resolver)"]
            I2["Choose required topics<br/>(KYC, accreditation, country, sanctions, ...)"]
            I3["Call setIdentityVerifier(shibui)<br/>on the ERC-3643 Identity Registry"]
        end

        subgraph Multisig["⚖️ Compliance Multisig (DEFAULT_ADMIN_ROLE)"]
            M1["Curate the Schema-2 authorizer set<br/>(resolver.addAuthorizer)"]
            M2["Grant / revoke OPERATOR_ROLE,<br/>AGENT_ROLE"]
            M3["Emergency response:<br/>remove trusted attester, flip policies"]
        end

        subgraph Operator["🛠️ Operators (OPERATOR_ROLE)"]
            O1["Day-to-day topic-schema wiring"]
            O2["Bind topics to policies"]
            O3["Add trusted attesters with authUID"]
        end

        subgraph KYCProvider["🔍 KYC / Compliance Provider"]
            K1["Verify investor off-chain<br/>(KYC, AML, accreditation, sanctions)"]
            K2["Attest on EAS under Investor Eligibility"]
            K3["Revoke attestation when needed"]
        end

        subgraph InvestorRole["👤 Investor"]
            INV1["Complete KYC with a trusted provider"]
            INV2["Receive an EAS attestation"]
            INV3["No per-investor contract deployed"]
        end

        subgraph TokenContract["📜 ERC-3643 Token"]
            T1["Transfer hook calls isVerified()<br/>on the Identity Registry"]
            T2["Block on false — no custom integration needed<br/>beyond the setIdentityVerifier call"]
        end
    end

    IssuerOrg -->|"hands admin to"| Multisig
    Multisig -->|"delegates day-to-day to"| Operator
    Operator -->|"configures"| TokenContract
    Multisig -->|"approves authorizers who in turn trust"| KYCProvider
    KYCProvider -->|"attests"| InvestorRole
    InvestorRole -->|"verified by"| TokenContract

    style IssuerOrg fill:#dbeafe,stroke:#2563eb
    style Multisig fill:#fce4ec,stroke:#c2185b
    style Operator fill:#fce4ec,stroke:#ad1457
    style KYCProvider fill:#fef3c7,stroke:#d97706
    style InvestorRole fill:#dcfce7,stroke:#16a34a
    style TokenContract fill:#f1f5f9,stroke:#475569
```

---

## Legacy baseline (for contrast)

### Current ERC-3643 identity

How ERC-3643 identity works with ONCHAINID alone, which pain points Shibui addresses, and which it explicitly does not. Source: [`current-erc3643-identity.mmd`](current-erc3643-identity.mmd).

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryColor': '#fee2e2', 'primaryTextColor': '#333', 'primaryBorderColor': '#dc2626', 'lineColor': '#666', 'secondaryColor': '#fef3c7', 'tertiaryColor': '#fff'}}}%%
flowchart TB
    subgraph Today["How ERC-3643 Identity Works Today"]
        direction TB

        subgraph InvestorSide["Investor Onboarding"]
            Investor[👤 Investor]
            KYC_Process["KYC Process<br/>(documents, AML checks)"]
            OCID_Deploy["Deploy ONCHAINID<br/>Identity Contract<br/>(per investor, per chain)"]
        end

        subgraph ProviderSide["KYC Provider"]
            Provider["ONCHAINID-Compatible<br/>KYC Provider"]
            Claims["Issue ERC-735 Claims<br/>(proprietary format)"]
        end

        subgraph TokenSide["Token Compliance"]
            Token["ERC-3643<br/>Security Token"]
            IR["Identity Registry"]
            IRS["Identity Registry<br/>Storage"]
            CTRS["Claim Topics<br/>Registry"]
            TIR["Trusted Issuers<br/>Registry"]
            OCID_Contract["ONCHAINID<br/>Identity Contract"]
        end

        Investor -->|1. Submit docs| KYC_Process
        KYC_Process -->|2. Verify| Provider
        Provider -->|3. Issue claims| Claims
        Claims -->|4. Write to| OCID_Deploy
        OCID_Deploy -->|5. Register| IRS

        Token -->|"transfer()"| IR
        IR -->|"check"| IRS
        IRS -->|"lookup"| OCID_Contract
        OCID_Contract -->|"validate claims"| TIR
        IR -->|"required topics"| CTRS
    end

    subgraph Problems["❌ Pain points Shibui addresses"]
        P1["Single vendor ecosystem<br/>(only ONCHAINID-compatible providers)"]
        P2["Per-investor contract deployment<br/>(expensive, slow)"]
        P3["No on-chain payload enforcement<br/>(claim existence ≠ claim correctness)"]
        P4["No auditable trust-change trail<br/>(who authorised this KYC provider?)"]
    end

    subgraph NotAddressed["⏳ Out of scope today (see enforcement-boundary.md)"]
        N1["Cross-chain attestation portability<br/>(per-chain today; V2 roadmap)"]
        N2["Forced transfer, freeze, recovery<br/>(ERC-3643 token contract's responsibility)"]
    end

    Today ~~~ Problems
    Problems ~~~ NotAddressed

    style Problems fill:#fee2e2,stroke:#dc2626
    style P1 fill:#fee2e2,stroke:#dc2626
    style P2 fill:#fee2e2,stroke:#dc2626
    style P3 fill:#fee2e2,stroke:#dc2626
    style P4 fill:#fee2e2,stroke:#dc2626
    style NotAddressed fill:#fff7ed,stroke:#ea580c
    style N1 fill:#fff7ed,stroke:#ea580c
    style N2 fill:#fff7ed,stroke:#ea580c
```

---

## Rendering

GitHub renders the `mermaid` code blocks above inline. To edit the raw sources, open the linked `.mmd` files directly — viewers such as [Mermaid Live Editor](https://mermaid.live/) or the VS Code *Mermaid Preview* extension render them standalone.

## Scope note

Diagrams match the **v0.4** production path. The core is targeted at EthTrust SL Level 2 (see `AUDIT.md`); the Path-B wrapper under `contracts/compat/` is Level 1 and not the subject of these diagrams. Older exploratory Valence/Diamond work is archived on branch `research/valence-spike`.
