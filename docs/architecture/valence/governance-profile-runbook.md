# Valence Governance Profile + Cut Runbook (EPIC #32)

Status: **Draft finalized for Phase 1/2 scaffold** (not yet production-enforced on live verifier path)

## Governance profile (enforceable assumptions in code)

`ValenceEASKernelAdapter` now requires a `GovernanceProfile` at deployment and enforces:

- `cutMultisig != address(0)`
- `minApprovals >= 2`
- `standardCutTimelock >= 24h`
- `emergencyCutTimelock >= 1h`
- `emergencyCutTimelock <= standardCutTimelock`

These assumptions are validated by constructor guardrails and fail deployment if violated.

## Profile values (default recommended)

- **Cut executor:** dedicated multisig (`cutMultisig`)
- **Minimum approvals:** `2` (raise to 3+ for production)
- **Standard module cut delay:** `24h` minimum
- **Emergency cut delay:** `1h` minimum

## Cut policy

### Standard cut (default path)
Use for adding/replacing selector routes where no critical incident is active.

Required controls:
1. Multisig proposal created with full route diff
2. Timelock queued for `>= 24h`
3. CI + test evidence attached before execution
4. Execute `applyRoutesToKernel(kernel)` from kernel owner path

### Emergency cut (exception path)
Use only for active exploit/critical outage response.

Required controls:
1. Incident declared and logged
2. Emergency delay `>= 1h`
3. Scoped selector change only (no broad refactors)
4. Post-incident follow-up with full standard cut if needed

## Operator runbook

1. **Prepare route plan**
   - Read `exportedRouteBindings()` and verify expected selector→orbital mapping
   - Confirm `hasSelectorCollisions() == false`

2. **Pre-flight verification**
   - Run `forge build`
   - Run `forge test --match-contract ValenceEASKernelAdapterTest`

3. **Queue cut via governance**
   - Standard: queue with 24h delay
   - Emergency: queue with 1h+ delay and incident link

4. **Execute cut**
   - Call `applyRoutesToKernel(kernel)` from authorized owner context
   - Verify kernel route count/entries against exported payload

5. **Post-cut checks**
   - Re-run parity tests and verification orbital tests
   - Update parity matrix table and EPIC #32 progress notes

## Out of scope (remaining)

- On-chain timelock contract integration for the adapter itself (currently assumptions + off-chain governance process)
- Automatic rollback script generation
- Production cutover authorization wiring to live verifier path
