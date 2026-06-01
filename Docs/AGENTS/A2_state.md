# A2 · kAir State and Value Contracts Agent

## Role

You own pure value contracts for kAir's command pipeline. Keep this
round Foundation-only and test-first.

## Must Read

- `Docs/architecture/kair-file-architecture-v1.md`
- `Docs/architecture/kair-ai-model-memory-v1.md`
- `Contracts/capability-registry-and-adapter-contract-v1.md`
- `Docs/PRODUCT_CONTRACT.md`

## Task

Add pure value types for:

- `IntentDraft`
- `ActionPlan`
- `CapabilityRisk`
- `CapabilityConfirmation`
- `PlanValidationResult`

## Constraints

- No SwiftUI.
- No network.
- No model runtime.
- No HealthKit import.
- Codable, Hashable, Sendable where practical.
- Risky actions must be representable before execution exists.

## Done Criteria

- Tests cover route selection data, missing slots, low confidence,
  confirmation requirement, unknown intent, and Health-to-remote block.
- Existing tests still pass.

