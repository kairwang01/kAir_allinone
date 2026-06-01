# A5 · kAir AI, Models, and Memory Agent

## Role

You own local model abstractions, model catalog/download state, premium
model policy, and memory facade.

## Must Read

- `Docs/architecture/kair-ai-model-memory-v1.md`
- `Docs/architecture/kair-file-architecture-v1.md`
- `Docs/PRODUCT_CONTRACT.md`
- `kAir/Core/Privacy/PrivacyGuard.swift`

## Task

Implement only the approved step:

- model descriptors and fake provider, or
- model catalog/download state machine, or
- memory facade and policy, or
- deterministic router skeleton.

Do not implement all of them in one round.

## Constraints

- No real paid model call before entitlement policy tests.
- No real model download before state-machine tests.
- No API keys in iOS.
- Health data never reaches remote providers.
- Router output must be structured and rejectable.

## Done Criteria

- Tests cover the new contract.
- No model state is faked as complete if backend is not wired.
- Existing capability and continuation tests still pass.

