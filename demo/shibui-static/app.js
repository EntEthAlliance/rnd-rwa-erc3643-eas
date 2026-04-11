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
    tokens: [{ name: "Private Credit", key: "A", required: [1, 7] }],
  });

  function mkInvestor(name, wallet, identity) {
    return {
      name,
      wallet,
      identity,
      attestations: {
        1: { status: "none", attester: null, uid: null },
        7: { status: "none", attester: null, uid: null },
      },
      notes: "",
    };
  }

  function clone(v) {
    return JSON.parse(JSON.stringify(v));
  }

  function uid(label) {
    return "0x" + label.replace(/[^a-z0-9]/gi, "").toLowerCase().padEnd(8, "0") + Math.random().toString(16).slice(2, 10);
  }

  function short(addr) {
    return addr ? addr.slice(0, 8) + "..." : "—";
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

  function topicName(id) {
    return id === 1 ? "KYC" : "ACCRED";
  }

  function setAtt(state, investorName, topic, attester, status = "active", customUid) {
    const inv = state.investors.find((i) => i.name === investorName);
    inv.attestations[topic] = { status, attester, uid: customUid || uid(`${investorName}-${topic}-${attester}`) };
  }

  function mkCalls(lines) {
    return lines.join("\n");
  }

  const screens = [
    {
      title: "SCREEN 1 — Title",
      subtitle: "Shibui: Modular Identity for Tokenized Assets",
      narrative: `<p>Scenario: Meridian issues a €50M tokenized private credit note. We follow 5 investors across 3 identity authorities through onboarding, trust changes, revocation, and recovery.</p>`,
      calls: mkCalls(["// No state changes on title screen"]),
      mutate: () => [],
    },
    {
      title: "SCREEN 2 — Deploy Contracts",
      subtitle: "Deploying Shibui identity stack",
      narrative: `<p>Four contracts come online: verifier, adapter, proxy, and claim topics registry.</p>`,
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
        return [ev("create", "Deployed verifier, adapter, proxy, topics registry")];
      },
    },
    {
      title: "SCREEN 3 — Configure Compliance Requirements",
      subtitle: "Required topics: KYC + ACCREDITATION",
      narrative: `<p>Meridian sets required claims to KYC (1) and ACCREDITATION (7), mapped to the same eligibility schema.</p>`,
      calls: mkCalls([
        "topicsRegistry.addClaimTopic(1)",
        "topicsRegistry.addClaimTopic(7)",
        "verifier.setTopicSchemaMapping(1, SCHEMA_UID)",
        "verifier.setTopicSchemaMapping(7, SCHEMA_UID)",
      ]),
      mutate: (s) => {
        s.topics = [1, 7];
        return [ev("add", "Required topics set: KYC (1), ACCREDITATION (7)")];
      },
    },
    {
      title: "SCREEN 4 — Register Trusted Attesters",
      subtitle: "Granular trust by topic",
      narrative: `<p>Meridian trusts itself for KYC + ACCRED, and trusts Alpine for KYC only.</p>`,
      calls: mkCalls([
        "adapter.addTrustedAttester(MERIDIAN_ADDR, [1, 7])",
        "adapter.addTrustedAttester(ALPINE_ADDR, [1])",
      ]),
      mutate: (s) => {
        s.trustedAttesters[ATT.MERIDIAN] = { topics: [1, 7], active: true };
        s.trustedAttesters[ATT.ALPINE] = { topics: [1], active: true };
        return [ev("add", "Trusted: Meridian for [1,7]"), ev("add", "Trusted: Alpine for [1]")];
      },
    },
    {
      title: "SCREEN 5 — Onboard Alice (Meridian Client)",
      subtitle: "Wallet→identity, then KYC + ACCRED attestations",
      narrative: `<p>Alice gets KYC and accreditation attestations from Meridian. Verification returns TRUE.</p>`,
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
        return [ev("add", "Alice KYC attested by Meridian"), ev("add", "Alice ACCRED attested by Meridian"), ev("ok", "isVerified(Alice) = TRUE")];
      },
    },
    {
      title: "SCREEN 6 — Onboard Bob (Alpine Client)",
      subtitle: "Partial then complete eligibility",
      narrative: `<p>Bob already has Alpine KYC. First check fails (no trusted ACCRED). Meridian then issues ACCRED; Bob becomes eligible.</p>`,
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
          ev("add", "Bob KYC attested by Alpine"),
          ev("warn", `isVerified(Bob) = FALSE (${first.reason})`),
          ev("add", "Bob ACCRED attested by Meridian"),
          ev("ok", `isVerified(Bob) = ${second.ok ? "TRUE" : "FALSE"}`),
        ];
      },
    },
    {
      title: "SCREEN 7 — Diana Rejected",
      subtitle: "No attestations",
      narrative: `<p>Diana tries to invest with no attestations. Verification fails immediately.</p>`,
      calls: mkCalls(["verifier.isVerified(0xD1) // FALSE"]),
      mutate: (s) => {
        const inv = s.investors.find((i) => i.name === "Diana");
        const r = investorEligibility(s, inv, s.tokens[0]);
        return [ev("warn", `isVerified(Diana) = FALSE (${r.reason})`)];
      },
    },
    {
      title: "SCREEN 8 — Cross-Bank Trust (Add Vega)",
      subtitle: "Correspondent-style trust extension",
      narrative: `<p>Meridian adds Vega as trusted for KYC. Carlos (Vega KYC + Meridian ACCRED) becomes eligible.</p>`,
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
        return [ev("add", "Trusted: Vega for [1]"), ev("add", "Carlos KYC by Vega"), ev("add", "Carlos ACCRED by Meridian"), ev("ok", "isVerified(Carlos) = TRUE")];
      },
    },
    {
      title: "SCREEN 9 — Identity Reuse (Token B)",
      subtitle: "Second token, zero repeated KYC operations",
      narrative: `<p>Meridian launches Token B with the same requirements. Verified investors remain verified using existing attestations.</p>`,
      calls: mkCalls([
        "// Token B requirements mirror Token A",
        "verifier.isVerified(Alice/Bob/Carlos/Diana/Eve)",
      ]),
      mutate: (s) => {
        s.tokens.push({ name: "Treasury Fund", key: "B", required: [1, 7] });
        // Eve exists as already-attested Meridian client entering this product context
        setAtt(s, "Eve", 1, ATT.MERIDIAN, "active", "uid_eve_kyc_v1");
        setAtt(s, "Eve", 7, ATT.MERIDIAN, "active", "uid_eve_accred_v1");
        return [
          ev("create", "Token B deployed with same requirements [KYC, ACCRED]"),
          ev("add", "Eve baseline attestations loaded (Meridian KYC + ACCRED)"),
          ev("ok", "Identity layer reused across Token A + Token B"),
        ];
      },
    },
    {
      title: "SCREEN 10 — Compliance Event (Revoke Eve)",
      subtitle: "Immediate block across both tokens",
      narrative: `<p>Eve is AML-flagged. Meridian revokes Eve’s KYC. She becomes blocked on Token A and Token B immediately.</p>`,
      calls: mkCalls(["EAS.revoke(uid_eve_kyc_v1)", "verifier.isVerified(0xE5) // FALSE"]),
      mutate: (s) => {
        const eve = s.investors.find((i) => i.name === "Eve");
        eve.attestations[1].status = "revoked";
        eve.attestations[1].uid = "uid_eve_kyc_v1";
        eve.notes = "AML review triggered; KYC revoked";
        return [ev("remove", "Revoked Eve KYC attestation uid_eve_kyc_v1"), ev("warn", "Eve blocked on Token A + Token B")];
      },
    },
    {
      title: "SCREEN 11 — Remove Trusted Attester (Alpine)",
      subtitle: "Attestation remains on-chain but no longer counts",
      narrative: `<p>Alpine loses license; Meridian removes Alpine from trusted attesters. Bob’s Alpine KYC no longer satisfies requirements.</p>`,
      calls: mkCalls(["adapter.removeTrustedAttester(ALPINE_ADDR)", "verifier.isVerified(0xB0) // FALSE"]),
      mutate: (s) => {
        s.trustedAttesters[ATT.ALPINE] = { topics: [], active: false };
        return [ev("remove", "Removed Alpine from trusted attesters"), ev("warn", "Bob now blocked (KYC attester removed)")];
      },
    },
    {
      title: "SCREEN 12 — Recovery (Bob + Eve)",
      subtitle: "Re-attestation restores eligibility",
      narrative: `<p>Bob receives fresh KYC from Meridian. Eve clears AML and gets a new KYC attestation. Both return to eligible.</p>`,
      calls: mkCalls([
        "EAS.attest(Bob, KYC, VERIFIED) → uid_bob_kyc_new",
        "verifier.registerAttestation(Bob, 1, uid_bob_kyc_new)",
        "EAS.attest(Eve, KYC, VERIFIED) → uid_eve_kyc_v2",
        "verifier.registerAttestation(Eve, 1, uid_eve_kyc_v2)",
      ]),
      mutate: (s) => {
        setAtt(s, "Bob", 1, ATT.MERIDIAN, "active", "uid_bob_kyc_new");
        setAtt(s, "Eve", 1, ATT.MERIDIAN, "active", "uid_eve_kyc_v2");
        const eve = s.investors.find((i) => i.name === "Eve");
        eve.notes = "Re-attested after AML remediation";
        return [ev("add", "Bob KYC re-issued by Meridian"), ev("add", "Eve KYC re-issued by Meridian"), ev("ok", "Bob + Eve restored to eligible")];
      },
    },
    {
      title: "SCREEN 13 — Audit View",
      subtitle: "Regulator-readable compliance state",
      narrative: `<p>Read-only regulator snapshot: who attested what, current trust graph, and eligibility outcomes per investor.</p>`,
      calls: mkCalls(["// No mutations; pure audit observation"]),
      mutate: () => [],
    },
    {
      title: "SCREEN 14 — Close",
      subtitle: "Lifecycle complete: create → verify → revoke → restore",
      narrative: `<p>Shibui demonstrates reusable identity infrastructure for tokenized products with on-chain auditability and immediate policy enforcement.</p>`,
      calls: mkCalls(["// End of demo"]),
      mutate: () => [],
    },
  ];

  function ev(kind, msg) {
    return { kind, msg, t: new Date().toISOString().replace("T", " ").slice(0, 19) + " UTC" };
  }

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

  function attBadge(att, topicId) {
    if (!att || att.status === "none") return badge("—", "warn");
    if (att.status === "revoked") return badge(`${topicName(topicId)} REVOKED`, "bad");
    return badge(`${topicName(topicId)} ✓ ${att.attester}`, "good");
  }

  function renderState() {
    const contractRows = Object.entries(state.contracts)
      .map(([k, v]) => `<div><b>${k}</b>: <code class="addr">${v || "—"}</code></div>`)
      .join("");

    const topicRows = state.topics.length
      ? state.topics.map((t) => `<div>${badge(topicName(t) + ` (${t})`, "good")}</div>`).join("")
      : `<div class="muted">—</div>`;

    const attRows = Object.entries(state.trustedAttesters)
      .filter(([, v]) => v.active)
      .map(([name, v]) => `<div><b>${name}</b>: ${v.topics.map((t) => badge(topicName(t), "good")).join(" ")}</div>`)
      .join("") || `<div class="muted">—</div>`;

    const tokenRows = state.tokens
      .map((t) => `<div><b>Token ${t.key}</b> ${t.name}: ${t.required.map((r) => topicName(r)).join(" + ")}</div>`)
      .join("");

    const invRows = state.investors
      .map((inv) => {
        const checks = state.tokens
          .map((t) => {
            const r = investorEligibility(state, inv, t);
            return `<span>${t.key}: ${r.ok ? badge("ALLOW", "good") : badge("BLOCK", "bad")}</span>`;
          })
          .join(" ");

        return `
          <div class="inv-row">
            <div><b>${inv.name}</b> <code class="addr">${inv.wallet}</code> → <code class="addr">${inv.identity}</code></div>
            <div>KYC: ${attBadge(inv.attestations[1], 1)} &nbsp; ACCRED: ${attBadge(inv.attestations[7], 7)}</div>
            <div>${checks}</div>
            ${inv.notes ? `<div class="muted">${inv.notes}</div>` : ""}
          </div>
        `;
      })
      .join("");

    $("state").innerHTML = `
      <h4>CONTRACTS</h4>${contractRows}
      <h4>REQUIRED TOPICS</h4>${topicRows}
      <h4>TRUSTED ATTESTERS</h4>${attRows}
      <h4>TOKENS</h4>${tokenRows}
      <h4>INVESTORS</h4>${invRows}
    `;
  }

  function renderLog() {
    $("log").innerHTML = log
      .map((e) => `<div class="log-item ${e.kind}"><span class="muted">${e.t}</span><br/>${e.msg}</div>`)
      .join("");
  }

  function renderScreen() {
    const s = screens[i];
    $("screenTitle").textContent = s.title;
    $("screenStep").textContent = `Screen ${i + 1} of ${screens.length}`;
    $("narrative").innerHTML = `<h3>${s.subtitle}</h3>${s.narrative}`;
    $("calls").textContent = s.calls;
    $("callouts").innerHTML = "";

    renderState();
    renderLog();

    $("btnBack").disabled = i === 0;
    $("btnNext").disabled = i >= screens.length - 1;
    $("btnStart").disabled = false;
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
