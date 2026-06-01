# kAir Docs Index

Status: project-specific docs index.
Last updated: 2026-05-30.

This folder is no longer a generic iOS multi-agent template. It is the
working documentation set for kAir, a chat-first all-in-one super app
with local-first AI routing, capability adapters, execution surfaces,
model downloads, paid model options, and domain-scoped memory.

## Read Order for Any Agent

1. `Docs/PROJECT_BRIEF.md`
2. `Docs/PRODUCT_CONTRACT.md`
3. `Docs/architecture/kair-superapp-architecture-v1.md`
4. `Docs/architecture/kair-file-architecture-v1.md`
5. `Docs/architecture/kair-ai-model-memory-v1.md`
6. `Docs/architecture/kair-provider-routing-mcp-search-v1.md`
7. `Docs/architecture/kair-agent-market-fit-audit-v1.md`
8. `Docs/architecture/kair-next-agent-prompts-v1.md`
9. Relevant `Contracts/*` and `Docs/design/*` for the specific surface.

## Canonical Architecture Docs

| File | Purpose |
|---|---|
| `Docs/architecture/kair-superapp-architecture-v1.md` | Product and software architecture for the super app direction. |
| `Docs/architecture/kair-file-architecture-v1.md` | Target directory tree, module boundaries, and dependency direction. |
| `Docs/architecture/kair-ai-model-memory-v1.md` | Local model, paid model, routing, download, and memory architecture. |
| `Docs/architecture/kair-provider-routing-mcp-search-v1.md` | Provider routing, map/search provider switching, MCP reservation, crawler-safe public information retrieval. |
| `Docs/architecture/kair-agent-market-fit-audit-v1.md` | Research/market fit audit mapping current agent papers, competitors, and official platform constraints to kAir modules and adoption decisions. |
| `Docs/architecture/kair-next-agent-prompts-v1.md` | Ready-to-paste prompts for coding agents and reviewer loop. |

## Research Notes

| File | Purpose |
|---|---|
| `Docs/research/2026-agent-market-ui-provider-research.md` | Current agent papers, Marvis/Yuanbao/Meituan market signals, provider/API/crawler/MCP implications. |
| `Docs/research/2026-open-source-methods-kair-mapping.md` | Earlier open-source methods mapping. |

## Existing Contract Families

| Folder | Authority |
|---|---|
| `Contracts/UX` | Continuation, feedback, rail, and post-return UX contracts. |
| `Contracts/Design` | Design-system token and component rules. |
| `Contracts/AIProviders` | Older local model provider vocabulary; superseded for planning by `kair-ai-model-memory-v1.md` until canonicalized. |
| `Contracts/capability-registry-and-adapter-contract-v1.md` | Capability vocabulary, adapter protocol, registry, normalized result. |
| `Contracts/telemetry-contract-v1.md` | Telemetry identifiers, events, propagation rules. |

## Current Collaboration Rule

Every coding-agent result is treated as an untrusted report. The review
agent must inspect actual diffs, patch contract drift, run the relevant
gates, and issue the next exact prompt. Do not stage, commit, merge, or
cross steps automatically.

## Minimum Gate Before Handing Back

- `git status --short` inspected.
- Relevant diffs reviewed against architecture and contracts.
- `git diff --check` clean.
- `xcodebuild build/test` run when Swift compile surface or behavior
  changed.
- Final response names exact files changed, gate results, and the next
  implementation point.
