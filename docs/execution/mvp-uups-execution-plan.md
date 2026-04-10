# MVP UUPS Execution Plan (Ralphy Loop)

Status: In progress
Owner: Claudy
Source spec: PRD.md (single production architecture)

## Acceptance Criteria (Stage Gates)

### Gate A — Architecture + interfaces frozen
- UUPS upgrade strategy defined for:
  - EASClaimVerifier
  - EASTrustedIssuersAdapter
  - EASIdentityProxy
- Initializer-based deployment path documented
- Storage layout compatibility explicitly reviewed

### Gate B — Implementation complete
- Upgradeable variants implemented (UUPS + OwnableUpgradeable)
- Initializers replace constructors
- Access control preserved

### Gate C — Deployment path complete
- Scripts deploy proxies (not direct implementations)
- Testnet + mainnet script paths aligned to proxy deployment model
- Audit gate in DeployMainnet remains enforced

### Gate D — Verification + demo ready
- Unit/integration tests green
- CI green
- Preview/demo deployment URL available
- Validation script and short demo script updated

### Gate E — Human validation stop
- PR summary includes:
  - live demo URL
  - test summary
  - changelog
  - merge recommendation
- Stop and wait for explicit human approval

## Ordered Sub-Tasks
1. Create upgradeable contract variants and shared initializer strategy
2. Update deployment scripts to deploy proxies
3. Add/adjust tests for initialization + ownership + upgrade constraints
4. Update docs and demo/validation flow
5. Run CI, fix failures, prepare final handoff

## Non-Negotiable Constraints
- No merge without explicit Redwan approval
- No bypass of failing checks
- No skipping preview deployment
