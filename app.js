(function () {
  const $ = (id) => document.getElementById(id);

  const TOPICS = {
    KYC: { id: 1, name: "KYC" },
    ACCRED: { id: 7, name: "ACCREDITATION" },
  };

  const ATT = {
    MERIDIAN: "Meridian Bank",
    ALPINE: "Alpine KYC",
    VEGA: "Vega Capital",
  };

  const baseState = () => ({
    contracts: {
      verifier: null,
      adapter: null,
      proxy: null,
      registry: null,
    },
    topics: [],
    trustedAttesters: {
      [ATT.MERIDIAN]: { topics: [], active: false },
      [ATT.ALPINE]: { topics: [], active: false },
      [ATT.VEGA]: { topics: [], active: false },
    },
    investors: [
      mkInvestor("Alice", "0xA1", "0xA1id"),
      mkInvestor("Bob", "0xB0", "0xB0id"),
      mkInvestor("Carlos", "0xC4", "0xC4id"),
      mkInvestor("Diana", "0xD1", "0xD1id"),
      mkInvestor("Eve", "0xE5", "0xE5id"),
    ],
    tokens: [{ name: "Private Credit", key: "A", required: [TOPICS.KYC.id, TOPICS.ACCRED.id] }],
  });

  function mkInvestor(name, wallet, identity) {
    return {
      name,
      wallet,
      identity,
      attestations: {
        [TOPICS.KYC.id]: { status: "none", attester: null, uid: null },
        [TOPICS.ACCRED.id]: { status: "none", attester: null, uid: null },
      },
      notes: "",
    };
  }

  function uid(label) {
    return (
      "0x" +
      label
        .replace(/[^a-z0-9]/gi, "")
        .toLowerCase()
        .padEnd(8, "0") +
      Math.random().toString(16).slice(2, 10)
    );
  }

  function topicName(id) {
    return id === TOPICS.KYC.id ? "KYC" : "ACCRED";
  }

  function isTrusted(state, attester, topic) {
    const row = state.trustedAttesters[attester];
    return !!(row && row.active && row.topics.includes(topic));
  }

  function investorEligibility(state, inv, token) {
    for (const topic of token.required) {
      const at = inv.attestations[topic];
      if (!at || at.status === "none") return { ok: false, reason: `missing ${topicName(topic)}` };
      if (at.status === "revoked") return { ok: false, reason: `${topicName(topic)} revoked` };
      if (!isTrusted(state, at.attester, topic)) return { ok: false, reason: `${at.attester} not trusted for ${topicName(topic)}` };
    }
    return { ok: true, reason: "eligible" };
  }

  function setAtt(state, investorName, topic, attester, status = "active", customUid) {
    const inv = state.investors.find((i) => i.name === investorName);
    inv.attestations[topic] = { status, attester, uid: customUid || uid(`${investorName}-${topic}-${attester}`) };
  }

  function mkCalls(lines) {
    return lines.join("\n");
  }

  function ev(kind, msg) {
    return { kind, msg, t: new Date().toISOString().replace("T", " ").slice(0, 19) + " UTC" };
  }

  // Story-first scenes (14) — keep logic, move tech behind collapsible details.
  const screens = [
    {
      title: "Scene 1 — The business problem",
      subtitle: "A tokenized note needs compliance that is reusable, enforceable, and auditable",
      story: [
        "Meridian issues a €50M tokenized private credit note.",
        "We follow 5 investors and 3 identity authorities through onboarding, trust changes, revocation, and recovery.",
      ],
      businessValue: [
        "One identity layer reused across products (no repeated onboarding).",
        "Instant policy enforcement (block/unblock) without manual freeze workflows.",
        "Audit-ready trail of who asserted what, and when.",
      ],
      takeaway: "Treat identity as shared infrastructure, not a per-product spreadsheet.",
      technicalHint: "No state changes on the title screen.",
      calls: mkCalls(["// No state changes on title screen"]),
      mutate: () => [],
    },
    {
      title: "Scene 2 — Bring the compliance rails online",
      subtitle: "Meridian activates the Shibui identity stack (simulation)",
      story: [
        "Think of this as the ‘compliance adapter’ that token transfers consult before allowing an investor to receive tokens.",
        "The issuer defines the rules once, then each transfer enforces them automatically.",
      ],
      businessValue: [
        "Fewer bespoke integrations per product.",
        "Consistent enforcement across desks, systems, and partners.",
      ],
      takeaway: "Set up once; reuse everywhere.",
      technicalHint: "Illustrative deployment + wiring (verifier, trusted-issuer adapter, identity proxy, topics registry).",
      calls: mkCalls([
        "verifier.setEASAddress(EAS_ADDRESS)",
        "verifier.setTrustedIssuersAdapter(adapter)",
        "verifier.setIdentityProxy(proxy)",
        "verifier.setClaimTopicsRegistry(registry)",
      ]),
      mutate: (s) => {
        s.contracts.verifier = "0x1a2b...";
        s.contracts.adapter = "0x3c4d...";
        s.contracts.proxy = "0x5e6f...";
        s.contracts.registry = "0x7a8b...";
        return [ev("create", "Compliance rails activated (verifier + adapter + proxy + registry)")];
      },
    },
    {
      title: "Scene 3 — Define the policy",
      subtitle: "This product requires: KYC + Accreditation",
      story: [
        "Meridian defines what evidence is required before anyone can receive tokens.",
        "In this demo: investors must have BOTH KYC and ACCREDITATION credentials.",
      ],
      businessValue: [
        "Policy is explicit, versionable, and enforceable — not tribal knowledge.",
        "Same rule can be applied to multiple tokenized products.",
      ],
      takeaway: "Make eligibility rules a first-class control.",
      technicalHint: "Topics 1 (KYC) and 7 (ACCRED) are registered; both map to the same attestation schema.",
      calls: mkCalls([
        "topicsRegistry.addClaimTopic(1)",
        "topicsRegistry.addClaimTopic(7)",
        "verifier.setTopicSchemaMapping(1, SCHEMA_UID)",
        "verifier.setTopicSchemaMapping(7, SCHEMA_UID)",
      ]),
      mutate: (s) => {
        s.topics = [TOPICS.KYC.id, TOPICS.ACCRED.id];
        return [ev("add", "Eligibility policy set: KYC + ACCRED")];
      },
    },
    {
      title: "Scene 4 — Set who you trust (by topic)",
      subtitle: "Trust can be granular: per authority, per topic",
      story: [
        "Meridian trusts itself for KYC + ACCRED.",
        "Meridian also trusts Alpine to issue KYC (but not accreditation).",
      ],
      businessValue: [
        "Cross-organization trust without giving away full control.",
        "Easy to expand or revoke trust without reissuing every credential.",
      ],
      takeaway: "Trust is configurable and reversible.",
      technicalHint: "Trusted attesters are registered with topic scopes.",
      calls: mkCalls(["adapter.addTrustedAttester(MERIDIAN_ADDR, [1, 7])", "adapter.addTrustedAttester(ALPINE_ADDR, [1])"]),
      mutate: (s) => {
        s.trustedAttesters[ATT.MERIDIAN] = { topics: [1, 7], active: true };
        s.trustedAttesters[ATT.ALPINE] = { topics: [1], active: true };
        return [ev("add", "Trusted: Meridian (KYC, ACCRED)"), ev("add", "Trusted: Alpine (KYC only)")];
      },
    },
    {
      title: "Scene 5 — Alice invests (Meridian client)",
      subtitle: "Credentials are presented once; eligibility is computed automatically",
      story: [
        "Alice receives KYC + ACCRED from Meridian.",
        "The system marks her as Eligible for Token A.",
      ],
      businessValue: [
        "No manual review loop per subscription.",
        "Eligibility can be checked in real time at transfer time.",
      ],
      takeaway: "Eligibility becomes a deterministic check.",
      technicalHint: "Wallet→identity link + EAS attestations registered into the verifier.",
      calls: mkCalls([
        "identityProxy.registerWallet(0xA1, 0xA1id)",
        "EAS.attest(...) → uid_alice_kyc",
        "verifier.registerAttestation(0xA1id, 1, uid_alice_kyc)",
        "EAS.attest(...) → uid_alice_accred",
        "verifier.registerAttestation(0xA1id, 7, uid_alice_accred)",
        "verifier.isVerified(0xA1) // TRUE",
      ]),
      mutate: (s) => {
        setAtt(s, "Alice", 1, ATT.MERIDIAN, "active", "uid_alice_kyc");
        setAtt(s, "Alice", 7, ATT.MERIDIAN, "active", "uid_alice_accred");
        return [ev("add", "Alice: KYC issued by Meridian"), ev("add", "Alice: ACCRED issued by Meridian"), ev("ok", "Alice is Eligible")];
      },
    },
    {
      title: "Scene 6 — Bob is partially eligible, then becomes eligible",
      subtitle: "Missing evidence blocks automatically — no exceptions",
      story: [
        "Bob has KYC from Alpine (trusted for KYC).",
        "He is still Blocked until ACCRED is issued by a trusted authority.",
        "Meridian issues ACCRED → Bob becomes Eligible.",
      ],
      businessValue: [
        "Reduced operational risk: you cannot ‘forget’ a requirement.",
        "Faster onboarding: different parties can provide different parts of the evidence.",
      ],
      takeaway: "Partial compliance is visible; full compliance is automatic.",
      technicalHint: "First check fails due to missing trusted ACCRED; second passes.",
      calls: mkCalls([
        "EAS.attest(...) // Bob KYC by Alpine",
        "verifier.isVerified(0xB0) // FALSE",
        "EAS.attest(...) // Bob ACCRED by Meridian",
        "verifier.isVerified(0xB0) // TRUE",
      ]),
      mutate: (s) => {
        setAtt(s, "Bob", 1, ATT.ALPINE, "active", "uid_bob_kyc_alpine");
        const inv = s.investors.find((i) => i.name === "Bob");
        const first = investorEligibility(s, inv, s.tokens[0]);
        setAtt(s, "Bob", 7, ATT.MERIDIAN, "active", "uid_bob_accred_meridian");
        const second = investorEligibility(s, inv, s.tokens[0]);
        return [
          ev("add", "Bob: KYC issued by Alpine"),
          ev("warn", `Bob is Blocked (${first.reason})`),
          ev("add", "Bob: ACCRED issued by Meridian"),
          ev("ok", `Bob is ${second.ok ? "Eligible" : "Blocked"}`),
        ];
      },
    },
    {
      title: "Scene 7 — Diana is blocked",
      subtitle: "If there is no evidence, there is no transfer",
      story: ["Diana attempts to invest with no credentials.", "The system blocks her automatically."],
      businessValue: ["Clear control: no credential, no access.", "No manual override needed to be safe-by-default."],
      takeaway: "Default posture is ‘Block until proven Eligible’.",
      technicalHint: "Eligibility check returns FALSE immediately.",
      calls: mkCalls(["verifier.isVerified(0xD1) // FALSE"]),
      mutate: (s) => {
        const inv = s.investors.find((i) => i.name === "Diana");
        const r = investorEligibility(s, inv, s.tokens[0]);
        return [ev("warn", `Diana is Blocked (${r.reason})`)];
      },
    },
    {
      title: "Scene 8 — Cross-bank trust",
      subtitle: "Meridian extends trust to Vega for KYC",
      story: [
        "Meridian adds Vega as a trusted KYC provider.",
        "Carlos brings Vega KYC + Meridian ACCRED → he becomes Eligible.",
      ],
      businessValue: [
        "Enables correspondent-style models: partners can onboard clients while the issuer keeps the rulebook.",
        "Faster distribution: broaden reach without lowering standards.",
      ],
      takeaway: "Trust networks can scale distribution safely.",
      technicalHint: "Vega is trusted for topic 1 only; Carlos mixes sources across topics.",
      calls: mkCalls([
        "adapter.addTrustedAttester(VEGA_ADDR, [1])",
        "EAS.attest(...) // Carlos KYC by Vega",
        "EAS.attest(...) // Carlos ACCRED by Meridian",
        "verifier.isVerified(0xC4) // TRUE",
      ]),
      mutate: (s) => {
        s.trustedAttesters[ATT.VEGA] = { topics: [1], active: true };
        setAtt(s, "Carlos", 1, ATT.VEGA, "active", "uid_carlos_kyc_vega");
        setAtt(s, "Carlos", 7, ATT.MERIDIAN, "active", "uid_carlos_accred_meridian");
        return [
          ev("add", "Trusted: Vega (KYC)"),
          ev("add", "Carlos: KYC issued by Vega"),
          ev("add", "Carlos: ACCRED issued by Meridian"),
          ev("ok", "Carlos is Eligible"),
        ];
      },
    },
    {
      title: "Scene 9 — Reuse across products",
      subtitle: "Token B launches with the same eligibility policy",
      story: [
        "Meridian launches Token B with the same KYC + ACCRED requirements.",
        "Existing verified investors remain Eligible without repeating KYC operations.",
      ],
      businessValue: [
        "Time/cost reduction: onboarding is amortized across products.",
        "Lower friction for repeat investors.",
      ],
      takeaway: "Identity becomes shared infrastructure across product lines.",
      technicalHint: "Token B is added; existing attestations are re-used. (Eve is loaded as a pre-attested investor.)",
      calls: mkCalls(["// Token B requirements mirror Token A", "verifier.isVerified(Alice/Bob/Carlos/Diana/Eve)"]),
      mutate: (s) => {
        s.tokens.push({ name: "Treasury Fund", key: "B", required: [1, 7] });
        setAtt(s, "Eve", 1, ATT.MERIDIAN, "active", "uid_eve_kyc_v1");
        setAtt(s, "Eve", 7, ATT.MERIDIAN, "active", "uid_eve_accred_v1");
        return [
          ev("create", "Token B launched (same policy: KYC + ACCRED)"),
          ev("add", "Eve: baseline credentials loaded"),
          ev("ok", "Reuse: investors don’t re-do onboarding for Token B"),
        ];
      },
    },
    {
      title: "Scene 10 — Instant enforcement (revocation)",
      subtitle: "One revocation blocks across every product using the same identity layer",
      story: [
        "Eve is AML-flagged.",
        "Meridian revokes Eve’s KYC credential → she becomes Blocked for Token A and Token B immediately.",
      ],
      businessValue: [
        "Immediate risk response without waiting for off-chain reconciliation.",
        "Single control point that affects multiple products.",
      ],
      takeaway: "Revocation is not a memo — it is an enforceable action.",
      technicalHint: "EAS revoke + eligibility check returns FALSE.",
      calls: mkCalls(["EAS.revoke(uid_eve_kyc_v1)", "verifier.isVerified(0xE5) // FALSE"]),
      mutate: (s) => {
        const eve = s.investors.find((i) => i.name === "Eve");
        eve.attestations[1].status = "revoked";
        eve.attestations[1].uid = "uid_eve_kyc_v1";
        eve.notes = "AML review triggered; KYC revoked";
        return [ev("remove", "Eve: KYC revoked"), ev("warn", "Eve is Blocked (Token A + Token B)")];
      },
    },
    {
      title: "Scene 11 — Trust is reversible",
      subtitle: "An authority can be removed; its past credentials stop counting",
      story: [
        "Alpine loses its license.",
        "Meridian removes Alpine from the trusted list.",
        "Bob’s Alpine KYC still exists, but it no longer counts → Bob becomes Blocked until re-attested.",
      ],
      businessValue: [
        "Fast containment: remove a compromised provider instantly.",
        "Clear governance: trust is a policy decision, not a permanent relationship.",
      ],
      takeaway: "Past data can remain, but policy decides what counts today.",
      technicalHint: "Trusted attester removed; eligibility check fails due to untrusted KYC issuer.",
      calls: mkCalls(["adapter.removeTrustedAttester(ALPINE_ADDR)", "verifier.isVerified(0xB0) // FALSE"]),
      mutate: (s) => {
        s.trustedAttesters[ATT.ALPINE] = { topics: [], active: false };
        return [ev("remove", "Removed trust in Alpine"), ev("warn", "Bob is Blocked (KYC issuer no longer trusted)")];
      },
    },
    {
      title: "Scene 12 — Recovery",
      subtitle: "Re-attestation restores eligibility (with a clean audit trail)",
      story: [
        "Bob receives fresh KYC from Meridian.",
        "Eve clears AML and receives a new KYC credential.",
        "Both become Eligible again.",
      ],
      businessValue: [
        "Smooth remediation: regain access without rebuilding accounts.",
        "Auditability: the old revoked credential remains visible; the new one replaces it in policy.",
      ],
      takeaway: "Recovery is as operationally simple as issuance.",
      technicalHint: "New attestations are issued and registered.",
      calls: mkCalls([
        "EAS.attest(Bob, KYC) → uid_bob_kyc_new",
        "verifier.registerAttestation(Bob, 1, uid_bob_kyc_new)",
        "EAS.attest(Eve, KYC) → uid_eve_kyc_v2",
        "verifier.registerAttestation(Eve, 1, uid_eve_kyc_v2)",
      ]),
      mutate: (s) => {
        setAtt(s, "Bob", 1, ATT.MERIDIAN, "active", "uid_bob_kyc_new");
        setAtt(s, "Eve", 1, ATT.MERIDIAN, "active", "uid_eve_kyc_v2");
        const eve = s.investors.find((i) => i.name === "Eve");
        eve.notes = "Re-attested after AML remediation";
        return [ev("add", "Bob: KYC re-issued by Meridian"), ev("add", "Eve: KYC re-issued by Meridian"), ev("ok", "Bob + Eve are Eligible again")];
      },
    },
    {
      title: "Scene 13 — Audit view",
      subtitle: "A regulator can read the state without trusting anyone’s spreadsheet",
      story: [
        "This snapshot shows: (1) the eligibility policy, (2) who is trusted for what, (3) which credentials each investor presents, and (4) who is Eligible/Blocked.",
        "No private data is shown here — just the existence/status of credentials.",
      ],
      businessValue: [
        "Auditability: clear provenance of credentials and governance changes.",
        "Reduced dispute surface: the same facts are visible to all parties.",
      ],
      takeaway: "Compliance becomes observable, not arguable.",
      technicalHint: "No mutations; this scene is read-only.",
      calls: mkCalls(["// No mutations; pure audit observation"]),
      mutate: () => [],
    },
    {
      title: "Scene 14 — What this enables",
      subtitle: "Reusable identity for tokenized assets",
      story: [
        "You can launch multiple products with the same controls.",
        "You can extend distribution through trusted partners.",
        "You can enforce and audit policies instantly.",
      ],
      businessValue: [
        "Cost/time reduction through reuse.",
        "Cross-bank trust with issuer-controlled governance.",
        "Instant enforcement (revocation/trust changes) across all products.",
        "Audit-ready evidence trail.",
      ],
      takeaway: "The core idea: identity is infrastructure.",
      technicalHint: "End of demo.",
      calls: mkCalls(["// End of demo"]),
      mutate: () => [],
    },
  ];

  let state = baseState();
  let log = [];
  let i = 0;

  function replay(target) {
    state = baseState();
    log = [];
    for (let x = 0; x <= target; x++) {
      const entries = screens[x].mutate(state) || [];
      log.push(...entries);
    }
  }

  function badge(txt, cls) {
    return `<span class="pill ${cls}">● ${txt}</span>`;
  }

  function eligibleBadge(ok) {
    return ok ? badge("Eligible", "good") : badge("Blocked", "bad");
  }

  function trustBadge(active) {
    return active ? badge("Trusted", "good") : badge("Not trusted", "warn");
  }

  function attBadge(att, topicId) {
    if (!att || att.status === "none") return badge("Missing", "warn");
    if (att.status === "revoked") return badge(`${topicName(topicId)} revoked`, "bad");
    return badge(`${topicName(topicId)} ✓`, "good");
  }

  function renderState() {
    // Policy summary
    const topicRows = state.topics.length
      ? state.topics.map((t) => `<span class="pill good">● ${topicName(t)}</span>`).join(" ")
      : `<span class="muted">—</span>`;

    const trustRows = Object.entries(state.trustedAttesters)
      .map(([name, v]) => {
        const topics = v.topics.length ? v.topics.map((t) => topicName(t)).join(", ") : "—";
        return `
          <div class="inv-row">
            <div><b>${name}</b> ${trustBadge(v.active)}</div>
            <div class="muted">Topics: ${topics}</div>
          </div>
        `;
      })
      .join("");

    // Investor outcomes
    const invRows = state.investors
      .map((inv) => {
        const byToken = state.tokens
          .map((t) => {
            const r = investorEligibility(state, inv, t);
            return `<span class="small"><b>${t.key}</b>: ${eligibleBadge(r.ok)}</span>`;
          })
          .join(" ");

        return `
          <div class="inv-row">
            <div><b>${inv.name}</b> <span class="muted">${inv.wallet} → ${inv.identity}</span></div>
            <div class="small">KYC: ${attBadge(inv.attestations[1], 1)} &nbsp; ACCRED: ${attBadge(inv.attestations[7], 7)}</div>
            <div style="margin-top:6px">${byToken}</div>
            ${inv.notes ? `<div class="muted" style="margin-top:6px">${inv.notes}</div>` : ""}
          </div>
        `;
      })
      .join("");

    const tokenRows = state.tokens
      .map((t) => `<div class="small"><b>Token ${t.key}</b>: ${t.name} (${t.required.map((r) => topicName(r)).join(" + ")})</div>`)
      .join("");

    $("state").innerHTML = `
      <div class="section">
        <div class="section-title">Eligibility policy (this demo)</div>
        <div>${topicRows}</div>
        <div class="muted" style="margin-top:6px">Rule: all required topics must be present, active, and issued by a trusted authority.</div>
      </div>

      <div class="section">
        <div class="section-title">Trusted authorities</div>
        ${trustRows}
      </div>

      <div class="section">
        <div class="section-title">Tokens</div>
        ${tokenRows}
      </div>

      <div class="section">
        <div class="section-title">Investors (outcomes)</div>
        ${invRows}
      </div>
    `;
  }

  function renderLog() {
    $("log").innerHTML = log
      .map((e) => `<div class="log-item ${e.kind}"><div class="t">${e.t}</div><div class="m">${e.msg}</div></div>`)
      .join("");
  }

  function esc(s) {
    return String(s)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;");
  }

  function renderScreen() {
    const s = screens[i];

    $("screenTitle").textContent = s.title;
    $("screenStep").textContent = `Scene ${i + 1} of ${screens.length}`;

    const storyLines = (s.story || []).map((t) => `<div>${esc(t)}</div>`).join("");
    const biz = (s.businessValue || []).map((t) => `<li>${esc(t)}</li>`).join("");

    $("story").innerHTML = `
      <div class="story-header">
        <h3>${esc(s.subtitle)}</h3>
        <div class="sub">${esc(s.takeaway || "")}</div>
      </div>

      <div class="story-body">
        <div class="block">
          <div class="label">What happens in this scene</div>
          <div class="value">${storyLines}</div>
        </div>

        <div class="kpi">
          <div class="kpi-card">
            <div class="kpi-title">Business impact</div>
            <div class="kpi-value">${esc((s.businessValue && s.businessValue[0]) || "")}</div>
          </div>
          <div class="kpi-card">
            <div class="kpi-title">Why it matters</div>
            <div class="kpi-value">${esc(s.takeaway || "")}</div>
          </div>
        </div>

        <div class="block">
          <div class="label">Business value (high level)</div>
          <div class="value"><ul>${biz}</ul></div>
        </div>

        <details class="tech">
          <summary>Show technical details</summary>
          <div class="muted">${esc(s.technicalHint || "Illustrative only — simplified for demo.")}</div>
          <pre class="code">${esc(s.calls || "")}</pre>
        </details>
      </div>
    `;

    $("callouts").innerHTML = "";

    renderState();
    renderLog();

    $("btnBack").disabled = i === 0;
    $("btnNext").disabled = i >= screens.length - 1;
  }

  function go(n) {
    i = Math.max(0, Math.min(screens.length - 1, n));
    replay(i);
    renderScreen();
  }

  $("btnStart").addEventListener("click", () => go(0));
  $("btnBack").addEventListener("click", () => go(i - 1));
  $("btnNext").addEventListener("click", () => go(i + 1));

  document.addEventListener("keydown", (e) => {
    if (e.key === "ArrowRight") go(i + 1);
    if (e.key === "ArrowLeft") go(i - 1);
  });

  go(0);
})();
