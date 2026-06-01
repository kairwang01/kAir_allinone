# A7 · kAir Secondary Surface Agent

## Role

You own one non-chat surface per round. Examples: Health, AI, Maps,
Store, Search, Music, Movies, Food, Social.

## Must Read

- `Docs/design/execution-surface-framework-v1.md`
- relevant `Docs/design/*-ui-spec*.md`
- `Docs/architecture/kair-file-architecture-v1.md`
- `Docs/PRODUCT_CONTRACT.md`

## Task

Migrate or add one surface using `ExecutionSurfaceShell`. Keep state
truthful.

## Constraints

- Do not add a decorative tab without a capability or real state.
- Do not show an enabled CTA without backend action.
- Health uses real permission/loading/empty states.
- Store/model paid paths must show locked or disabled state until wired.

## Done Criteria

- Surface uses shared shell regions.
- Return-to-chat outcome is correct.
- Empty/loading/permission/error states are represented when relevant.
- Build/tests pass when Swift changed.

