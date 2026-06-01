# kAir Super App Architecture v1

Status: architecture blueprint, comment-only, no production implementation implied.
Last updated: 2026-05-30.
Owner: reviewer / architecture loop.

This document defines the target engineering shape for kAir as an
all-in-one super app. It is intentionally written as implementation
comments and contracts that future coding agents can follow without
guessing product intent.

## 0. Scope

This v1 architecture covers:

- App shell and execution-surface architecture.
- Capability routing across maps, health, store, search, music, video,
  social, food, local services, and future verticals.
- Local-first AI model routing and model download settings.
- Paid market model option reserved behind StoreKit and server-side
  provider gateways.
- Provider routing for maps, search, crawlers, MCP tools, membership
  tiers, and cost-aware API selection.
- Local memory, semantic retrieval, privacy boundaries, and test gates.
- File architecture and module ownership rules.

This v1 architecture does not implement code. It only gives comments,
file placement, contracts, and acceptance gates for the next coding
agent pass.

## 1. Research Basis

Primary sources checked in this round:

| Area | Source | Architecture implication for kAir |
|---|---|---|
| iOS system actions | Apple App Intents documentation | kAir must expose high-value actions and content through a narrow App Intents layer instead of trying to mirror every screen or silently control other apps. |
| On-device LLM | Apple Foundation Models documentation | Prefer typed structured output and tool calling for routing/planning when available; keep a runtime abstraction because availability and OS support may vary. |
| Dynamic local models | Apple Core ML model download/compile documentation | Model download must be an explicit lifecycle with catalog, disk budget, compile/install status, and uninstall. |
| Paid model access | Apple StoreKit In-App Purchase documentation | Paid digital model access must be gated by StoreKit entitlements; server-side validation remains the cleanest path for expensive provider access. |
| SwiftUI state | Apple SwiftUI model data and NavigationStack docs | Keep model data separated from views, use `@Observable` where appropriate, and own navigation in typed routes rather than free-form screen mutation. |
| Modular iOS | Tuist The Modular Architecture | Split future large features into Source / Interface / Tests / Testing / Example modules; current repo can remain single-target until module pressure appears. |
| State architecture | Point-Free TCA | Borrow unidirectional, testable feature boundaries; do not import TCA unless the team explicitly chooses that dependency. |
| Local persistence | GRDB / SQLite docs | Use SQLite as the durable local substrate for memory, model catalog, and audit logs when JSON stops scaling. |
| Vector memory | sqlite-vec | Candidate for local semantic retrieval inside SQLite; keep behind `VectorIndex` abstraction because it is pre-v1 and may break. |
| Apple Silicon ML | MLX | Good research/training and Apple Silicon local inference candidate; keep experimental and abstracted. |
| Edge ML runtime | ExecuTorch | Candidate for non-generative classifiers, rerankers, and edge inference; not the first chat/runtime choice. |
| Super app platforms | Weixin/Tencent mini program framework | The reusable lesson is host shell + logic/view separation + controlled native capability APIs, not copying web mini-app runtime into iOS v1. |
| Super app platform | Alipay+ Mini Program Platform | The market pattern is marketplace + ISV/service templates + approval lifecycle; kAir should model future vertical services as capability packages with review gates. |
| Super app competitor | Grab Superapp | Daily services are grouped around deliveries, mobility, finance, and merchant tools; kAir should optimize command-to-service completion rather than a decorative app grid. |
| Agent architecture | Agentic AI taxonomy and autonomous-agent review | The product should be a typed control loop: structured intent, plan validation, tool/provider policy, adapter execution, projection, and evaluation trace. |
| Agent memory | MemX plus memory survey work | Memory must be local-first, searchable, explainable, scoped, auditable, and rejection-capable; raw transcript retrieval alone is not enough. |
| Model routing | RouteLLM / route-selection research plus Apple Foundation Models | Paid/large model selection should be policy-driven by cost, confidence, task class, user entitlement, and privacy, not hardcoded to one provider. |
| UI agents | Mobile-Agent-v3/v3.5, MARVIS-style market positioning | GUI/screen agents are a useful research signal, but kAir v1 constrains production actions through adapters, App Intents, public APIs, and confirmations. |
| MCP security | MCP spec, SMCP, MCP threat-model papers | MCP runtime is reserved until allowlists, descriptor trust, OAuth/consent, sandboxing, prompt-injection tests, and Health-blocking tests exist. |
| Provider routing / MCP / crawler-safe search | `Docs/research/2026-agent-market-ui-provider-research.md` | Provider choice must be explicit and cost/privacy/membership aware; Google/Gaode/search/crawler upgrades require a server/provider envelope before runtime. |
| Market/paper fit audit | `Docs/architecture/kair-agent-market-fit-audit-v1.md` | Current architecture matches the research direction when the model remains a constrained planner, provider metadata stays traceable, and GUI-agent automation is reserved rather than shipped as hidden control. |

## 2. Product Thesis

kAir is a chat-first command surface that can route a user's intent to
the right vertical surface. The user should not need to remember which
tab or app owns a task. They type or speak an instruction; kAir parses
intent, checks permission, selects a capability, asks for confirmation
when needed, executes through an adapter, and returns the user to a
clear result surface.

The self-developed lightweight model is not the product's "big brain" in
v1. Its first job is:

1. Parse user instruction into a structured intent.
2. Select a target capability or app framework.
3. Build a safe execution plan.
4. Call approved local tools or system integrations.
5. Explain the result briefly.

Large market models are optional accelerators. They must be selectable,
priced, entitlement-gated, and routed only when the privacy policy allows
the requested context to leave the device.

Provider-backed services follow the same rule. Apple/local providers are
the default path; Gaode, Google, search APIs, crawlers, MCP tools, and
partner APIs are selected only when region, membership, cost, privacy,
and terms policy allow them.

## 3. Architectural Principles

1. Chat is the command surface; verticals are execution surfaces.
2. Every vertical capability is behind a typed adapter.
3. The AI runtime proposes plans; adapters execute plans.
4. No hidden third-party app control. External actions use public APIs:
   App Intents, URL schemes, universal links, ShareSheet, system
   frameworks, or user-confirmed partner SDK calls.
5. Health data is isolated and local-only unless a future legal review
   changes the policy.
6. Memory is partitioned by domain and purpose. There is no single
   unbounded global memory store.
7. Paid/large model access is a marketplace entitlement, not a hardcoded
   provider dependency.
8. Provider choice is policy-driven. Capability routing decides the task;
   provider routing decides Apple/local vs Gaode vs Google vs search API
   vs crawler vs MCP vs cache.
9. Feature growth uses capability packages, not duplicated screen
   silos.
10. The current single Xcode target can stay until build and ownership
   pressure justifies modularization.
11. Contract tests must lock vocabulary, routing, privacy, provider cost,
    source provenance, and UI state
    before visual polish work starts.

## 4. Current Repo Reading

The repo already has the right direction:

- `kAir/App/Navigation` owns the chat-first shell and presented surfaces.
- `kAir/Core/Capability` owns `CapabilityKind`, adapters, registry, and
  normalized results.
- `kAir/Core/AI`, `kAir/Core/Memory`, and `kAir/Core/Models` now contain
  the first pure contracts for intent drafts, action plans, validation,
  projection, model catalog state, and memory policy.
- `kAir/Core/Providers`, `kAir/Core/Search`, and
  `kAir/Core/SystemBridge` contain provider-routing, search/crawler, and
  MCP reservation contracts.
- `kAir/Features/Models` has a Model Library shell but not a real catalog
  or download manager.
- `PrivacyGuard` already encodes strict HealthKit and model boundaries.
- `ExecutionSurfaceShell` has started unifying vertical surface layout.

The immediate architecture gap is not lack of screens. The gap is the
missing orchestration layer between chat input, local planner model,
capability registry, permission gates, and memory.

## 5. Target Runtime Flow

The canonical command flow:

```text
User input
  -> ChatStore accepts prompt and issues TraceID
  -> PrivacyGuard classifies sensitive context
  -> ConversationEngine builds a minimal context packet
  -> IntentParser returns IntentDraft
  -> CapabilityRouter selects CapabilityKind and target SurfaceKind
  -> ProviderRouter selects local/provider/cache path when the capability needs one
  -> PlanValidator checks permissions, entitlement, risk, and confirmation need
  -> User confirmation gate if action writes, pays, posts, shares, or opens external app
  -> CapabilityAdapter.resolve(...)
  -> NormalizedResult
  -> ResultProjector writes transcript block, recommendation, memory candidate, or execution surface session
  -> ExecutionSurfaceShell displays status and return outcome
```

Remote/provider extension point:

```text
ProviderRouter selects non-local provider
  -> ServerProviderRequest envelope
  -> ServerProviderValidator
  -> mock/fixture transport in tests
  -> real server endpoint only in a later gate
```

Rules:

- The model never calls arbitrary Swift code directly.
- The model can only request tools registered in `ToolRegistry`.
- `ToolRegistry` tools map to `CapabilityAdapter` or internal read-only
  services.
- A write/payment/post/share action must produce a visible confirmation
  artifact before execution.
- A metered/premium provider call must pass membership and cost policy.
- A remote/provider call must carry trace, privacy, membership, cost,
  source, freshness, and entitlement fields before any endpoint exists.
- If the route is uncertain, return a recommendation rail item instead
  of executing.

## 6. Capability Package Model

Every vertical domain should eventually look like this:

```text
FeatureName/
  Domain/
    FeatureIntent.swift              // value-only intent shape
    FeatureModels.swift              // Codable, Sendable domain values
    FeaturePermissions.swift         // explicit permission model
  Data/
    FeatureAdapter.swift             // conforms to CapabilityAdapter
    FeatureRepository.swift          // persistence or partner client
  Presentation/
    FeatureHomeView.swift            // ExecutionSurfaceShell caller
  Contracts/
    feature-capability-contract-v1.md // optional when behavior is complex
  Tests/
    FeatureAdapterTests.swift
    FeatureRoutingTests.swift
```

Do not create a new tab just because a new vertical exists. A vertical
becomes a visible `AppSection` only when it has enough user-facing state
to deserve an execution surface.

## 7. Vertical Roadmap

| Vertical | v1 status | Target capability shape |
|---|---|---|
| Chat | main command surface | `threadLookup`, transcript, recommendation rail, continuation |
| Health | sensitive workspace | `healthRead`, `healthWrite`, local-only model, no remote context |
| AI | model/status workspace | model selection, local runtime status, paid model entitlement |
| Maps | execution surface | place search, route planning, external map handoff |
| Store | curated catalog shell | app/service/model catalog, entitlement state, disabled CTA until wired |
| Social/Friends | future | friend lookup, invite, chat handoff, no Health data |
| Food/Local Services | future | restaurant search, menu/order deep links, partner-backed adapters |
| Music | reserved | MusicKit or partner deep link; no fake playback result |
| Movies/Video | reserved | search/watchlist/deep link; rights/availability must be honest |
| Search/Web | reserved | web search and source cards, privacy-reviewed remote call |
| MCP Tools | reserved | allowlisted external tools/resources/prompts, disabled by default |

## 8. External App Calling Policy

kAir can "call other apps" only through allowed public paths:

- App Intents for kAir-owned actions and system surfaces.
- Shortcuts integration for user-created cross-app workflows.
- Universal links and URL schemes for partner apps that expose them.
- ShareSheet for explicit user export.
- System frameworks such as MapKit, HealthKit, MusicKit, EventKit, and
  Contacts when permissions and App Review rules allow.
- Server-side partner APIs when the user has authenticated and the
  action is within the provider terms.
- MCP servers only after allowlisting, descriptor verification, consent,
  and risk mapping.

kAir must not:

- Use private APIs to inspect or control other apps.
- Screen-scrape third-party apps in production.
- Simulate taps in other apps as a background automation product.
- Claim that an external action completed unless a public API or user
  confirmation gives a trustworthy receipt.
- Crawl public pages without robots/source policy, rate limits,
  attribution, and server-side controls.

## 8.1 Provider Routing Policy

kAir uses a two-stage route:

```text
CapabilityRouter -> ProviderRouter -> ProviderAdapter
```

ProviderRouter considers:

- capability,
- region,
- membership tier,
- user provider preference,
- cost budget,
- privacy class,
- freshness requirement,
- provider availability,
- terms/source policy.

Default path:

- Free/local: Apple frameworks, on-device model, local cache.
- Member/premium: Gaode or Google maps/search when enabled and allowed.
- Metered/research: search APIs, crawlers, premium model gateway.
- Disabled-by-default: MCP and destructive external tools.

See `Docs/architecture/kair-provider-routing-mcp-search-v1.md`.

## 9. Model Strategy

The model stack has three tiers:

| Tier | Purpose | Default policy |
|---|---|---|
| `local-router` | intent parsing, tool selection, structured plan | self-developed lightweight fine-tuned model; local-only |
| `local-specialist` | health summaries, reranking, embeddings, classification | per-domain local model, never mixed with general chat without policy |
| `market-large-model` | hard reasoning, long content, optional premium tasks | paid, user-selected, server-gated, privacy-screened |

The router model should output structured JSON or Swift-decoded shapes,
not free-form prose. If the runtime cannot enforce structured output,
the plan must pass a strict parser and rejection path before execution.

## 10. Memory Strategy

Memory uses a write-manage-read loop:

1. Write candidates from transcript, completed actions, user settings,
   and explicit saves.
2. Filter through policy: domain, sensitivity, retention, user consent.
3. Distill raw events into compact facts, preferences, and task state.
4. Index through FTS5 and optional local vectors.
5. Retrieve with domain scope and latency budget.
6. Render only the minimum memory context needed for the current plan.
7. Expose delete/export/pause controls.

Memory stores are separate:

- `ChatMemoryStore`: conversation summaries, preferences, task state.
- `HealthMemoryStore`: health summaries and coverage; local-only DB.
- `ModelMemoryStore`: model downloads, benchmarks, runtime telemetry.
- `CapabilityAuditStore`: receipts of executed actions and errors.

No memory write is automatic just because the model generated text. The
write path must be policy-gated and testable.

## 11. Engineering Architecture

Recommended near-term architecture:

- SwiftUI + Observation for UI state.
- Swift Concurrency and actors for service work.
- Composition root remains `AppBootstrap` until `AppContainer` is
  introduced.
- `CapabilityRegistry` remains the single adapter lookup surface.
- `ConversationEngine` becomes the orchestrator for intent and tool
  planning.
- `ModelProvider` hides Foundation Models, Core ML, MLX, llama.cpp, or
  remote providers behind one request/response contract.
- `MemoryStore` hides storage and retrieval.
- `ServerTransport` remains optional and never directly called from UI.
- A11 defines value-only server/provider request, response, validation,
  audit, and mock transport envelopes without URLSession or endpoints.
- The next ServerTransport step is still value-only: adapt provider,
  search, and MCP policy decisions plus quota snapshot into
  `ServerProviderEnvelope` values without executing them.

Future modularization:

- Keep single app target while velocity matters.
- When compile/test cycles become painful, split modules using a Tuist
  style `Feature`, `FeatureInterface`, `FeatureTesting`, `FeatureTests`,
  and optional `FeatureExample` graph.
- The interface target owns public models and protocols; implementation
  targets must not leak into other features.

## 12. Security, Privacy, and App Review

Release-blocking rules:

- No API key in app bundle.
- No HealthKit raw or derived data to remote AI in v1.
- No health memory mixed with chat/social memory.
- No paid model access without StoreKit entitlement.
- No external execution without public API, partner agreement, or user
  confirmation.
- No hidden "AI decided to buy/order/post/send" path.
- No model output claiming medical diagnosis or treatment.
- No model download that can fill disk without quota and user-visible
  uninstall path.

## 13. Test Gates

Minimum tests before implementation is considered usable:

- Capability vocabulary frozen tests.
- Intent parser structured-output rejection tests.
- Router tests from prompt -> capability -> surface.
- PrivacyGuard tests for every sensitive context route.
- Model entitlement tests for free/local/paid/expired states.
- Model download state-machine tests.
- Memory write/read/delete/pause tests.
- Health isolation tests.
- App Intents compile tests for first exposed actions.
- ExecutionSurfaceShell visual/state regression tests.

## 14. Definition of Usable

kAir is "usable" for the all-in-one direction when:

1. A user can type one instruction in Chat and receive a correct
   recommended action or surface route.
2. The route is backed by a capability adapter, not a hardcoded view hack.
3. Risky actions require confirmation.
4. The return path records a continuation outcome.
5. Memory can improve the next suggestion without leaking sensitive data.
6. The Model Library truthfully shows installed, downloadable, paid,
   unavailable, and active model states.
7. The app remains smooth under missing network, missing permission,
   missing model, and empty data.
