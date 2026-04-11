# Shibui Demo — Static Interactive Walkthrough

This folder contains a **single-page static demo** that follows the full Shibui story arc from the spec:

1. Title
2. Deploy contracts
3. Configure KYC + ACCRED topics
4. Register trusted attesters (Meridian, Alpine)
5. Onboard Alice
6. Onboard Bob (partial → eligible)
7. Diana rejected
8. Add Vega (cross-bank trust) + onboard Carlos
9. Deploy Token B (identity reuse)
10. Revoke Eve (instant block)
11. Remove Alpine (Bob blocked)
12. Recovery (Bob + Eve re-attested)
13. Audit view
14. Close

## Run

### Option A — open directly
Open `index.html` in a browser.

### Option B — local server
```bash
cd demo/shibui-static
python3 -m http.server 8000
```
Then open <http://127.0.0.1:8000/>.

## Characteristics

- No wallet connection
- No RPC / chain calls
- Pure visual state machine simulation
- Persistent state panel (contracts, topics, trusted attesters, investors, tokens)
- Event log with step-by-step state transitions
- Dark UI with monospace call/address rendering and red/yellow/green compliance statuses
