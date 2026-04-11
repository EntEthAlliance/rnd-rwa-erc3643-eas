# Shibui — Story-First Static Demo (ERC-3643 × EAS)

This folder contains a **single-page static demo** designed to be readable by **executives, compliance teams, and regulators**.

- It tells the Shibui story as **14 business-first scenes**.
- **Technical details are available per scene** under a collapsible “Show technical details”.
- The right panel keeps a **live simplified state** (Trusted/Not trusted; Eligible/Blocked) plus an action log.

## Run

### Option A — open directly
Open `index.html` in a browser.

### Option B — local server
```bash
cd demo/shibui-static
python3 -m http.server 8000
```
Then open <http://127.0.0.1:8000/>.

## Story arc (14 scenes)

1. The business problem
2. Bring the compliance rails online
3. Define the policy (KYC + ACCRED)
4. Set who you trust (by topic)
5. Alice invests (Meridian client)
6. Bob: partial → eligible
7. Diana blocked (no evidence)
8. Cross-bank trust (add Vega) + Carlos eligible
9. Reuse across products (Token B)
10. Instant enforcement (revoke Eve)
11. Trust is reversible (remove Alpine)
12. Recovery (re-attest Bob + Eve)
13. Audit view
14. What this enables

## Characteristics

- Static HTML/CSS/JS only
- No wallet connection
- No RPC / chain calls
- Pure visual state machine simulation
- Designed for non-engineers by default (with optional technical details)
