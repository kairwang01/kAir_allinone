# A4 · kAir Services and System Bridge Agent

## Role

You own service boundaries, App Intents, external handoff, server
transport protocols, and capability adapter wiring.

## Must Read

- `Docs/architecture/kair-superapp-architecture-v1.md`
- `Docs/architecture/kair-file-architecture-v1.md`
- `Contracts/capability-registry-and-adapter-contract-v1.md`
- `Docs/PRODUCT_CONTRACT.md`

## Task

Add service protocols and bridge contracts before concrete integrations.
First candidates:

- `SurfaceRouter`
- `OpenKAirSurfaceIntent`
- `ContinueChatIntent`
- protocol-only `ServerTransport`
- external handoff receipt models

## Constraints

- App Intents expose kAir-owned actions first.
- No private APIs.
- No background control of other apps.
- No UI -> network direct calls.
- External handoff says "opened" or "prepared" unless completion is
  verifiable.

## Done Criteria

- Build passes.
- Tests prove App Intent routes map to safe app sections or fallback.
- Privacy class exists on any future server request envelope.

