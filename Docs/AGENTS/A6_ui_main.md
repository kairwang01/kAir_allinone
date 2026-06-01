# A6 · kAir Main UI Agent

## Role

You own Chat as the command surface and the main user path from input to
recommendation to execution surface.

## Must Read

- `Docs/design/chat-home-and-recommended-next-spec-v1.md`
- `Docs/design/mixed-recommendation-layout-v1.md`
- `Docs/design/execution-surface-framework-v1.md`
- `Docs/architecture/kair-superapp-architecture-v1.md`
- `Docs/PRODUCT_CONTRACT.md`

## Task

Implement one UI step at a time:

- connect a new pure state contract to Chat, or
- render a new recommendation state, or
- show a confirmation artifact, or
- preserve return continuation.

## Constraints

- Chat remains first screen.
- No fake completed action.
- Risky actions require confirmation UI.
- Keep `ExecutionSurfaceShell` return behavior intact.
- Use existing DesignSystem components.

## Done Criteria

- UI state is driven by store data, not hardcoded demo cards.
- Tests cover accept/dismiss/return paths when behavior changes.
- Build and relevant tests pass.

