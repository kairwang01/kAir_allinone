# kAir Architecture Analysis & Redesign v2

Status: redesign blueprint, comment-first (pass 1). Synthesizes the kernel
track, the provider track, and 2026 external research into one forward
architecture and an ordered implementation cut-plan.
Last updated: 2026-05-31.

This document does **not** change runtime behavior. It is the "注释编程" pass:
it maps the current system, names the genuine gaps against the product goal,
and reserves the next interfaces so a later pass can implement them behind the
same merge-gated, privacy-first, cost-explicit discipline the project already
uses.

It extends, and does not replace:
- `kair-superapp-architecture-v1.md` (base layering),
- `kair-ai-model-memory-v1.md` (model roles + memory),
- `kair-provider-routing-mcp-search-v1.md` (provider/maps/search/MCP/cost),
- `kair-agent-market-fit-audit-v1.md` (market positioning),
- `kair-next-agent-prompts-v1.md` (Round A1–A8 kernel cuts).

---

## 1. Two Tracks, One System

kAir has advanced as two parallel contract-first tracks. The redesign's first
job is to state how they converge.

| Track | Source doc | Numbering | State (2026-06-01) |
|---|---|---|---|
| **Kernel** (agent loop) | `kair-next-agent-prompts-v1.md` | Round A1–A8 | A1–A5 done (comments, value contracts, model catalog, memory facade, ConversationEngine skeleton); reserved interfaces R1–R6 implemented. A6–A8 PM-owned. |
| **Provider** (routing/transport) | `kair-provider-routing-mcp-search-v1.md` | A5b–A174+ | Through ~A174 (PM-driven; status-stack composition + metered entitlement ledger). All value-only; no live provider runtime. |

The two tracks meet at the **Conversation Engine** (kernel A5). The engine is
the single place that routes a typed `IntentDraft` to a capability
(`CapabilityRouter`), builds an `ActionPlan`, validates it (`PlanValidator` +
`PrivacyGuard`), and — when a capability needs an external service — hands
off to the provider track (`ProviderRoutingPolicy` / `SearchProviderPolicy` /
`MCPGatewayPolicy` → `ServerProviderEnvelopeFactory`). Memory (kernel A4)
records only policy-approved candidates.

```text
user text
  -> IntentDraft            (kernel A2, typed, Codable)
  -> CapabilityRouter       (kernel A2: capability -> surface)
  -> ActionPlan             (kernel A2, typed capability + surface)
  -> PlanValidator          (kernel A2: privacy > confidence > slots > confirm)
  -> [needs a service?]
       no  -> local adapter (CapabilityRegistry, kernel A8)
       yes -> ProviderAccessProfile / QuotaSnapshot
            -> ProviderRoutingPolicy | SearchProviderPolicy | MCPGatewayPolicy
            -> ServerProviderEnvelopeFactory -> ExecutionGate -> (deferred runtime)
  -> ResultProjector        (provider track)
  -> MemoryStore candidate  (kernel A4, scoped + health-isolated)
  -> ProviderTrace / Telemetry
```

This pipeline exists as types, and **`ConversationEngine.resolve` now composes
them end-to-end** (kernel A5, `Core/AI/ConversationEngine.swift`): route → build
plan → validate → a terminal `ConversationOutcome`. Model invocation (step 4),
dispatch (step 9), and projection (step 10) remain seams.

---

## 2. Canonical Layer Model

The redesign freezes ten layers. Each new interface must declare which layer it
belongs to; cross-layer shortcuts (e.g. SwiftUI calling a provider) stay
forbidden.

| # | Layer | Owns | Examples (existing) |
|---|---|---|---|
| L0 | Design system | Tokens, primitives | `AppTheme`, `ActionCardShell`, `ExecutionSurfaceShell` |
| L1 | Surface / UI | Screens, state owners | `ChatHomeView`, `ModelLibraryStore`, `RecommendedNextConsole` |
| L2 | Orchestration | The agent loop | `ConversationEngine` (A5), `ContinuationRuntime`, `FeedbackRuntime` |
| L3 | Value contracts | Typed drafts/plans/results | `IntentDraft`, `ActionPlan`, `NormalizedResult`, `MatchingObject` |
| L4 | Policy gates | Allow/deny/route decisions | `PlanValidator`, `PrivacyGuard`, `ProviderRoutingPolicy`, `CostPolicy`, `MemoryWritePolicy`, `MCPGatewayPolicy` |
| L5 | Capability adapters | One capability's typed surface | `CapabilityRegistry`, `Stub*Adapter`, `SearchCapabilityAdapter` |
| L6 | Providers | One vendor/source family | `MapProviderDescriptor`, `SearchProvider`, `MCPGateway`, **`ResearchProvider` (new)** |
| L7 | Transport | Server-mediated execution | `ServerProvider*` envelope/runtime suite (deferred) |
| L8 | Memory | Scoped local records | `MemoryStore`, `MemoryWritePolicy` |
| L9 | Telemetry | Non-PII traces | `ProviderTrace`, `TelemetryEmitter` |

Cross-cutting (touch every layer, never bypass it): **PrivacyGuard** (L4) and
**Membership/Cost** (`ProviderAccessProfile`, metered entitlement ledger).

---

## 3. External Research Synthesis (2026)

Fresh deep-dives (this redesign) plus the standing
`2026-agent-market-ui-provider-research.md` evidence. Sourced fact is separated
from kAir judgment.

### 3.1 Agent-architecture papers

| Theme | Key sources | kAir implication |
|---|---|---|
| Tiered memory | MemGPT (arXiv:2310.08560); Generative Agents (arXiv:2304.03442) | `MemoryStore` is the context-"RAM"; domain vector stores are "disk". Keep retrieval reason + provenance (already done). |
| Co-evolving memory | A-MEM (arXiv:2502.12110); AgeMem (arXiv:2601.01885) | Memory should support **update-existing-note**, not only append. Health observations update a baseline note. Expose memory ops as typed capabilities. |
| Planning / parallel tool-use | ReAct (2210.03629); Reflexion (2303.11366); LLMCompiler (2312.04511); Plan-and-Solve (2305.04091) | Planner should emit a **typed DAG** (`PlanGraph`), executed with independent branches in parallel. Add a Reflexion-style failure note at the engine layer. |
| Cost-aware routing | FrugalGPT (2305.05176); RouteLLM (2406.18665); xRouter (2510.08439) | Model selection is a **cascade**: local small → local specialist → paid remote, escalating only on low confidence. Reward = quality − λ·cost, λ = plan tier. |
| MCP security | MCP Landscape (2503.23278); MCP Safety Audit (2504.03767, "no single defense >34%"); MCPSHIELD (2604.05969) | Treat MCP metadata as hostile. Capability-based access control + attestation + runtime policy. kAir's `CapabilityRegistry` is the local MCP trust boundary. |
| On-device SLMs | MobileLLM (2402.14905); TinyLLM (2511.22138); PhoneLM (2411.05046); MEI survey (2407.18921) | Router/planner/embedder viable ≤1.5B. **Health-specialist needs ≥1B** (sub-1B fails multi-turn). Architecture-search for Neural Engine before fine-tune. |

**Top design implications adopted:**
1. **Hard domain gate before cost gate.** Health = local-only is a non-negotiable predicate evaluated *before* any cost/quality cascade. (Already true: `PlanValidator` runs the privacy gate first; carry it into model routing.)
2. **Health-specialist ≥1B params**; reflect this in `ModelCatalogEntry` minimum-class metadata.
3. **Co-evolving, tiered memory** — reserve `MemoryConsolidationPolicy`.
4. **Memory ops as typed capabilities** — future `CapabilityKind` cases behind the registry.
5. **Planner emits a typed DAG** — reserve `PlanGraph`.
6. **Train the router on logged preference data** post-launch; design the trace pipeline now (`ProviderTrace` already non-PII).
7. **Capability adapter layer = MCP trust boundary** — every adapter declares allowed domains, remote-escape, read/write scope.

### 3.2 On-device runtime (Marvis / MLX)

"Marvis" is a TTS model family (Apache-2.0, MLX, CSM-1B distillation), **not** a
full voice agent — useful as an on-device runtime reference, not an agent
blueprint.

- **MLX is the Apple-Silicon path for generative inference** (streaming, dynamic
  shapes); Core ML stays best for classifiers/embedders. → `ModelRuntimeFamily`
  already enumerates both; reserve a `ModelRuntime` protocol so a role can bind
  to MLX vs Core ML vs Foundation Models without the catalog knowing the SDK.
- **Size-tier per role; stream, don't chunk; cap prefill (~512 tok); 3-tier
  context (frozen system / compressed summary / recent buffer)** to bound KV
  cache when several local models run at once.
- **Licensing is a release gate** — model weights' license (Apache-2.0 vs
  non-commercial upstream) must be a `ModelCatalogEntry` field consulted before
  bundling. (`license` field already exists — make it policy-checked.)

### 3.3 Market agents — Tencent Yuanbao (deep-dive)

Sourced (2026): Yuanbao runs a **2×2 model grid** — speed×depth × provider
(Hunyuan Turbo S / T1 × DeepSeek V3 / R1) — with **user-controlled** selection,
not silent auto-routing. Search is an **Agentic RAG / DeepSearch** loop
(planning → search → reading → reflection); thousands of plugin APIs are
vectorized and selected top-k → rank → top-n within a token budget; production
rankers are distilled to 0.5B INT8 students. Production memory is deliberately
**shallow**: "Favorites" is a user-curated scrapbook recalled by @-mention, not
ambient auto-memory (the deeper MemOS layered memory remains research). New
agent/social features (PAI / Groups) debut in a **sandbox** surface before any
WeChat rollout. Hy3 (295B/21B MoE "agent foundation model", MCP orchestration,
≤495 steps) is led by the ReAct author.
Sources: [Tencent Hy3](https://www.tencent.com/en-us/articles/2202320.html),
[Yuanbao search stack](https://cloud.tencent.com/developer/article/2556938),
[Favorites](https://www.aibase.com/news/16855).

kAir judgment:
- **Model choice is user-visible, not hidden.** `ModelTierRouter` (R2) picks a
  *default* tier and must surface the choice + cost/latency; never silently move
  a user to a paid model (already an invariant).
- **Explicit-save-first memory** validates `MemoryWritePolicy` (top allowed
  source = explicit user save); ambient auto-memory stays opt-in / deferred.
- **Sandbox new capabilities** in an experimental surface before the main chat
  (kAir Spaces / a "Lab" section), behind the same capability-contract review.

### 3.4 Market agents — Meituan LongCat / life-services (deep-dive)

Sourced (2026): LongCat-Flash (560B MoE, ~27B active, MIT) trains on **agentic
tasks** (80k mock tools / 1600 apps / 40 domains; VitaBench: 30+ tools, 60+
rounds). Two public life-service benchmarks are highly actionable:
- **LocalSearchBench** (arXiv:2512.07436): optimal **N≈5 tool-call rounds**
  (beyond ~5, long-context noise degrades correctness); top failure modes are
  **unstable tool strategy (38.6%)** and **missing explicit planning (30.9%)** —
  agents that retrieve before planning fail.
- **LocalEval / LocalGPT** (arXiv:2506.02720): "service-with-spatiotemporal-
  context" is its own task category; a **7B model instruction-tuned** on domain
  data ≈ 72B; **city-specified prompts** fix cross-region transfer.
- **MTGR** (arXiv:2505.18654, production ranker): the LLM emits structured
  **feature tags**; a separate efficient ranker scores at scale — not end-to-end
  LLM ranking.

kAir judgment:
- **Bound the agent loop at N≈5 with a mandatory planning step first.** Reinforces
  `PlanGraph` (R4): emit a typed plan (steps / tools / constraints) *before* any
  tool chain; cap rounds; keep a `(sub-question, evidence)` trajectory.
- **Spatiotemporal context is a required slot** for life-service capabilities —
  reserve `SpatiotemporalContext` ({time, day, location, region, weather})
  injected into every maps / local-search adapter call (R6 below).
- **LLM-as-feature-generator + simple ranker** for the recommendation surface,
  not LLM-as-ranker; start rule-based, keep the LLM producing typed tags.
- **Local-first 7B is viable** for life-service tasks → fits on-device
  `ModelRuntime` (R3) + catalog roles; inject `{city, locale}` per call.
- **MARVIS-class** mobile assistants confirm the UX expectation (screen-aware
  task help + confirmation), but kAir keeps App Intents + typed adapters +
  visible receipts over hidden cross-app tapping.

---

## 4. Gap Analysis vs the Product Goal

The goal asks for: local-first maps with membership upgrade to Gaode/Google; a
search/crawler path for public life-service info; an academic-research path
(Google Scholar, IEEE, …); MCP reservation + invocation; cost-driven API
switching; and an architecture learned from current agents/papers.

| Goal capability | Current state | Gap | Redesign action |
|---|---|---|---|
| Maps tiering (Apple → Gaode/Google by membership) | **Designed** (provider §5, `MapProviderDescriptor`, readiness/manifest A66/A73) | None in contract; runtime deferred. | Keep; no new contract. |
| Search + crawler (public life info, robots/RFC 9309) | **Designed** (provider §6, `SearchProvider`, Search-API pipeline A86–A119) | None in contract. | Keep. |
| MCP reservation + invocation | **Designed** (provider §7, `MCPGateway`, disabled-by-default) | Runtime + invocation gates deferred (correctly). | Keep; harden discovery/call-time gates per MCPSHIELD before any runtime. |
| Membership / cost-driven API switching | **Designed** (membership tiers, budget classes, `ProviderAccessProfile`, metered ledger A117) | Covers **provider** cost; **model-tier** cost routing not yet a contract. | **New:** `ModelTierRouter` (cost-aware model cascade). |
| Academic research (Scholar / IEEE / arXiv …) | **Missing** | No academic-source provider; web `searchAPI` ≠ scholarly search. | **New:** `ResearchProvider` family (L6). |
| On-device model runtime (MLX/Core ML) | Enum only (`ModelRuntimeFamily`) | No runtime-binding contract. | **New:** `ModelRuntime` protocol reservation. |
| Multi-step task decomposition | `ActionPlan` is single-capability | No typed multi-step plan. | **New:** `PlanGraph` reservation (LLMCompiler-style DAG). |
| Conversation orchestration | **Composed** by `ConversationEngine.resolve` | — | **Kernel A5** done (skeleton + tests). |
| Co-evolving / tiered memory | Append + isolate (A4) | No consolidation/reflection. | **New:** `MemoryConsolidationPolicy` reservation. |
| Life-service time/place grounding | `ActionPlan` has no spatiotemporal slot | No grounding value / loop budget. | **New:** `SpatiotemporalContext` + `AgentLoopBudget` (R6). |

Six reserved interfaces (R1–R6) → **all implemented** as pure value contracts +
tests, plus the kernel A5 convergence (done). None required touching the
PM-owned shared provider vocabulary.

---

## 5. Reserved Interfaces (comment-first, pass 1)

Each reservation is value-only: no SDK, no network, no API key, no live
provider call. Each declares its layer and the gates required before any
runtime.

### 5.1 `ResearchProvider` — academic / scholarly sources (L6)

New file: `kAir/Core/Research/ResearchProvider.swift` (+ tests). Self-contained
vocabulary (`ResearchSource`, `ResearchCapability`) that **reuses** the shared
currency types (`MembershipTier`, `ProviderCostClass`, `ProviderPrivacyClass`,
`ProviderFreshness`, `ProviderRegion`) but does **not** modify
`ProviderFamily`/`ProviderCapability` (CaseIterable, heavily tested, PM-owned).

Academic sources differ from web search in access reality and citation
semantics:

| Source | Official API? | Access reality | Default tier |
|---|---|---|---|
| arXiv | Yes (export.arxiv.org) | Free, rate-limited, liberal terms | included/free |
| OpenAlex | Yes (api.openalex.org) | Free, "polite pool" (email) | included/free |
| Crossref | Yes (api.crossref.org) | Free DOI metadata | included/free |
| Semantic Scholar | Yes (api.semanticscholar.org) | Free; key for higher limits | included/metered |
| PubMed / NCBI | Yes (E-utilities) | Free; **health-adjacent → privacy class** | metered + privacy-gated |
| IEEE Xplore | Yes (developer.ieee.org) | Metadata API w/ key; full-text paywalled | metered premium |
| Google Scholar | **No official API; ToS forbids scraping** | Only via compliant paid proxy | **disabled by default**, compliance review |

Contract shape (mirrors `SearchProvider`):
```text
ResearchSource          enum: arxiv, openAlex, crossref, semanticScholar,
                              pubmed, ieee, googleScholar, cache
ResearchCapability      enum: scholarlySearch, citationLookup, paperMetadata,
                              abstractFetch
ResearchSourceDescriptor  source, displayName, minimumMembership, costClass,
                              hasOfficialAPI, requiresComplianceReview,
                              fullTextPaywalled, privacyClass, priority
ResearchRequest         traceID, query, capability, privacyClass, membership,
                              preferredSource, meteredEntitlements,
                              enabledExperimentalSources, freshness, now
ResearchCitation        title, authors, venue, year, doi/url, sourceID,
                              isPeerReviewed, isOpenAccess, abstractAvailable
ResearchDecision        selectedSource?, citation?, skipped[], failureReason?, trace
ResearchProviderPolicy  pure evaluate(request, registry) -> ResearchDecision
```
Hard rules: read-only; **every result carries a citation** (DOI/URL + venue);
no full-text redistribution when `fullTextPaywalled`; Google Scholar stays
disabled until a compliant access path + ToS review exist; PubMed queries are
`.private`-classed (health-adjacent) and never auto-escalate to a remote model;
no API keys in the iOS envelope (server-mediated, like all remote providers).

### 5.2 `ModelTierRouter` — cost-aware model cascade (L4)

New file: `kAir/Core/AI/ModelTierRouter.swift` (+ tests). The provider track
prices **services**; this prices **models**. A FrugalGPT/RouteLLM cascade over
the A3 catalog roles, with the health gate first.

```text
ModelTier               enum: localRouter, localPlanner, localSpecialist,
                              paidRemote
ModelTierRequest        capability, confidence (IntentConfidence), privacyClass,
                              membershipTier, paidRemoteEntitled
ModelTierDecision       tier, escalatedToPaid: Bool, reason (ModelTierReason)
ModelTierRouter.route   pure; order:
  1. health -> always localSpecialist (hard gate, before cost/confidence)
  2. non-general (private) -> covering local tier (no remote)
  3. confident + general -> cheapest covering local tier
  4. low confidence + general + paidRemoteEntitled -> paidRemote (escalated)
  5. otherwise -> localSpecialist fallback (no silent paid escalation)
```
Reward framing (quality − λ·cost, λ = membership tier) documented; the v1
contract is deterministic rules, not a learned router. Logged
decisions feed a future preference-trained classifier (RouteLLM).

### 5.3 `ModelRuntime` — on-device runtime binding (L6)

New file: `kAir/Core/Models/ModelRuntime.swift` (protocol + comment + value
status only). Lets a role bind to MLX / Core ML / Foundation Models without the
catalog knowing the SDK. Reserves: `load/unload`, streaming token iterator,
prefill-chunk hint, KV-budget hint, `license`-gated availability. No SDK import;
a fixture conformer only.

### 5.4 `PlanGraph` — multi-step typed plan (L3)

New file: `kAir/Core/AI/PlanGraph.swift` (+ tests). An LLMCompiler-style DAG of
`ActionPlan` nodes with dependency edges, so "find a route near my gym **and**
add a reminder" is one validated plan with parallelizable branches. v1 = the
value type + topological validation + per-node `PlanValidator` reuse; no
executor.

### 5.5 `MemoryConsolidationPolicy` — reflection / co-evolution (L8)

New file: `kAir/Core/Memory/MemoryConsolidationPolicy.swift` (+ tests). A-MEM /
Generative-Agents reflection: pure rules deciding when stored records should be
**summarized**, **superseded** (update existing note id), or **decayed**
(MemoryBank forgetting). Stays domain-isolated (health consolidation never
reads non-health). No background scheduler in v1 — a pure function the store can
call.

> **Research validation (2026-06-01, `Docs/research/2026-agent-memory-deep-dive-v1.md`).**
> A verified deep-dive (24/25 claims 3-vote-confirmed) confirms this design:
> hierarchical summarization (MemoryBank/RMM) and Ebbinghaus decay
> (`R = e^(−t/S)`; FadeMem importance-weighting) are the highest-certainty,
> most on-device-portable mechanisms, and a 2026 survey frames forgetting as
> "a feature, not a bug." Conversely a knowledge graph is **not** a free
> on-device win (Mem0^g: ~+2% overall, a multi-hop regression, higher latency) —
> reserve a `MemoryGraph` facade **last and gated**, temporal-only. The ranked
> memory-v2 plan + CI gate (recall@k · p95 latency · storage-growth, measured
> on-device first) live in `kair-ai-model-memory-v1.md` §13.1. Not ratified (flagged).

### 5.6 `SpatiotemporalContext` + agent loop budget — life-services grounding (L3/L2)

New file: `kAir/Core/AI/SpatiotemporalContext.swift` (+ tests). Meituan's
LocalEval shows time/place grounding is a *required* input, not enrichment, and
LocalSearchBench shows correctness peaks at **N≈5 tool rounds** after an explicit
plan. Reserve:
- `SpatiotemporalContext` — `{timestamp, dayOfWeek, coarseLocation, region,
  locale, weatherSignal?}`, a value every life-service capability request
  carries. Coarse location only (privacy); never raw precise coordinates in
  memory/telemetry.
- `AgentLoopBudget` — `{maxToolRounds (default 5), requirePlanFirst: true,
  maxTokens}`, consumed by the future `PlanGraph` executor so a life-service
  turn cannot retrieve before planning or exceed the noise threshold.

These are value-only; no clock/location/weather SDK is called (the caller
injects them, matching the `MemoryStore`/`SearchProvider` `now:`-injection
pattern, so tests stay deterministic).

---

## 6. Forward Implementation Cut-Plan

Ordered, merge-gated, allowed-files-scoped, full-suite-green per cut. Kernel
finishes before the new reservations are implemented.

```text
Kernel convergence
  A5  Conversation Engine skeleton (compose A2 types end-to-end; no model runtime) [DONE]
  A6  App Intents first pass (kAir-owned actions; already scaffolded)
  A7  Model Library UI truthfulness (PM in progress)
  A8  First vertical adapter (read-only, behind CapabilityRegistry)

Redesign reservations (each: comment-first pass 1 -> value+tests pass 2)
  R1  ResearchProvider               (gap: academic sources)            [DONE: pure value + tests]
  R2  ModelTierRouter                (gap: model cost cascade)           [DONE: pure value + tests]
  R3  ModelRuntime protocol          (gap: on-device runtime binding)      [DONE: protocol + policy + tests]
  R4  PlanGraph                      (gap: multi-step plans; N<=5 loop budget) [DONE: DAG + topo validation + tests]
  R5  MemoryConsolidationPolicy      (gap: co-evolving memory)              [DONE: pure rules + tests]
  R6  SpatiotemporalContext          (gap: life-service time/place grounding) [DONE: value + loop budget + tests]

Runtime (still deferred, one provider at a time, server-mediated)
  provider track A120+ -> first real Search API vendor -> maps -> research -> MCP
```

---

## 7. Non-Negotiable Invariants (carried forward)

These survive the redesign unchanged; any new interface must honor them:

- **Privacy first.** Health/private context never reaches a remote model,
  friend transport, search, crawler, MCP, or research source. `PrivacyGuard` is
  the single policy surface; the health gate runs *before* cost/confidence.
- **No fake success.** No faked download/purchase/booking/completion; UI shows
  truthful provider/cost/freshness/source status or a disabled premium CTA.
- **No secrets on device.** No API key, OAuth token, bearer, or provider secret
  in any iOS-side value, telemetry, or memory record. Remote calls are
  server-mediated.
- **Cost is explicit.** Never silently switch a free user to a metered provider
  or a paid model. Budget class is on every request; membership is a routing
  constraint, not a feature flag.
- **Typed data, not prompt strings.** The model proposes structured drafts/
  plans; policy decides execution; adapters execute. Free text is never an
  execution plan.
- **Read-only life services in v1.** Search/compare/summarize/save/open only;
  order/reserve/pay/message are separate, confirmation-gated, deferred
  contracts.
- **Citations required.** Every public-info and research result carries source
  URL/DOI, timestamp, and confidence; low-quality sources summarize, never act.
- **Health AI disclosure (release-blocking).** Any health-surface model output
  identifies itself as AI-generated, stays non-diagnostic (never diagnose /
  prescribe / claim a license), and shows limitations + a clinician CTA
  (CA AB 3030 / AB 489, TX SB 1188; EU AI Act Annex III treats health analysis
  as high-risk from Aug 2026). Extends
  `PrivacyGuard.modelOutputsMustRemainNonDiagnostic` /
  `modelOutputsMustShowLimitations` (§9.4).
- **Data locality (PIPL / CAC).** Personal data stays on device by default;
  cross-border transfer is blocked without explicit consent + a CAC assessment;
  any AI feature exposed to China users needs a CAC algorithm filing before
  ship. The China/global provider split (Gaode / Google) is a first-class
  architectural decision, not an afterthought (§10.5).

> **Policy-surface anchoring (reserved).** `PrivacyGuard.RuleID` already encodes
> health-to-remote, store-separation, and non-diagnostic rules. Four invariants
> above — **no silent paid escalation**, **no secrets on device**, **health AI
> authorship disclosure**, **data locality** — are currently enforced only in
> scattered provider types and comments. A future doc-only + Swift gate should
> add matching release-blocking `RuleID` cases so every invariant lives in the
> single policy surface. (Not done in this pass — flagged.)

---

## 8. Open Questions for PM 判断

1. Cut ordering — finish kernel A5–A8 first (as written), or interleave R1
   ResearchProvider now since it is a clean, self-contained gap-fill?
2. `ResearchProvider` source set — start with the four free official-API sources
   (arXiv, OpenAlex, Crossref, Semantic Scholar) and reserve IEEE/PubMed/Scholar
   behind compliance + membership, or reserve all seven from the start (current
   draft does the latter, descriptor-only)?
3. `ModelTierRouter` vs the provider track's metered ledger — keep model cost and
   service cost as two routers sharing `MembershipTier`/cost classes (current
   plan), or unify later?

---

## 9. UI / UX Design Synthesis (ui 设计调研)

kAir's visual system is **frozen at v1** (`Docs/design/super-app-visual-system-v1.md`):
three layers (Chat Home, Recommended Next, Execution Surface), one card primitive
(`ActionCardShell`), one shell per vertical (`ExecutionSurfaceShell`), one bottom
tray (`RecommendedNextConsole`), and a single floating composer. The freeze rule
is explicit: *if a pattern needs structure not in the doc, the visual system bumps
to v2 first.* This section maps 2026 agent-UI research onto those primitives and
**flags every pattern that would require a v2 bump** — none are added silently.

### 9.1 Principles adopted (from the 2026 deep-dives)

| # | Principle | Source | kAir primitive | Status |
|---|---|---|---|---|
| 1 | **User-visible model/provider choice; never silent paid escalation** | Yuanbao 2×2 grid | provider-status badge side channel + a model/provider chooser | badge built; chooser = **v2** |
| 2 | **Confirm risky/pay/external actions, showing what will happen** | §9 confirmation gate; MCP consent | `ActionCardShell` confirmation gate (Pending/DirectSubmit) | built |
| 3 | **Cite-first; show cost / freshness / source** | Meituan life-services; Search API | provider-status badges (free-local / included / metered), citations, staleness | contracts built |
| 4 | **Proactive next-step without spam** | recommendation UX | `RecommendedNextConsole` (collapsed "{N} ready", horizontal rail, dismiss/feedback) | built |
| 5 | **Single composer; stream; card-vs-message rendering** | chat-first apps | `FloatingAskComposer` + `MessageBubble` + `ActionCardShell` | built |
| 6 | **App Intents + typed adapters + visible receipts over hidden cross-app tapping** | MARVIS-class critique | `ExecutionSurfaceShell` + `Core/SystemBridge/AppIntents` | built |
| 7 | **Spatiotemporal + city/locale grounding shown honestly** | Meituan LocalEval | `SpatiotemporalContext` (R6) surfaced in the surface header | type reserved; **display = v2** |
| 8 | **Explicit-save-first, user-managed memory** | Yuanbao Favorites | `MemoryStore` (inspectable) → a memory-management screen | store built; **screen = v2 surface** |
| 9 | **Trust: limitations disclosure, non-diagnostic health copy, honest empty/permission states** | PrivacyGuard; Apple HIG | `ExecutionSurfaceShell` 5 states (ready/loading/empty/error/permission) + copy rules | built |

### 9.2 What is already covered vs. what needs a v2 bump

- **Covered by v1 primitives (no new structure):** confirmation gate, recommendation
  tray, single composer + streaming, provider/cost/freshness badges (side channel,
  not in `MatchingObject`), execution-surface states, App-Intents entry. The
  contract-first provider-status side channel (provider track A23–A174) is exactly
  the non-invasive seam these badges bind to without touching the frozen card model.
- **Requires a visual-system v2 bump (flag, do not add silently):**
  1. **Model/provider chooser** — a user-visible affordance to pick local vs paid-remote
     (Yuanbao 2×2) and a preferred map/search provider, surfacing cost + latency. Today
     only the *status* of a choice is shown, not a *picker*.
  2. **Memory-management screen** — a surface to view/pause/delete `MemoryStore` records
     by domain (health isolated). New Execution Surface.
  3. **Spatiotemporal grounding header** — showing the coarse `{city · time · weather}`
     context a life-service answer used, honestly and editably.
  4. **Unified "+" tool sheet** (R1) — no bottom-sheet primitive exists in v1.
  5. **Multi-card result carousel** (R2) — distinct from the one-card RecommendationRail.
  6. **Undo snackbar / toast** (R3) — v1 constraints explicitly forbid toast.
  7. **Premium-upgrade chip** (R6) — an 8th trust-pill kind; v1 freezes exactly 7.
  8. **Haptics + Arc-style step-list** (R7) / **clarify chips** (R8) — out of scope in v1 §13.

### 9.3 Reference-app UI observations (2026 deep-dive)

| App | Observable UX signal | Source |
|---|---|---|
| Tencent Yuanbao | User-selectable dual model (Hunyuan + DeepSeek); all models web-search | [AIBase](https://www.aibase.com/news/15428) |
| Meituan Xiaomei | Vertical chat-first agent; voice+text; surfaces restaurant options + budget filter before completing a transaction | [Bloomberg](https://www.bloomberg.com/news/articles/2025-09-12/meituan-launches-ai-agent-to-boost-food-delivery-business) |
| ChatGPT mobile | Model-name pill in composer; suggestion chips above composer; plan preview before operator actions | [OpenAI UI Guidelines](https://developers.openai.com/apps-sdk/concepts/ui-guidelines) |
| Perplexity | Numbered **inline citations** on every claim; Ask/Pro/Voice modes; freshness filters | [UX Design Institute](https://www.uxdesigninstitute.com/blog/perplexity-ai-and-design-process/) |
| Gemini (2025–26) | Unified **"+" tools** bottom sheet (haptic); sidebar model picker; Daily Brief proactive digest; non-dismissible "agent running" chip; suggestions fade on typing | [9to5Google](https://9to5google.com/2025/09/15/gemini-tools-redesign-android-ios/) |
| Arc Search | "Browse for Me": 3-step **process animation** (searching→reading→building) + haptic tick + slow reveal + inline citations | [Arc blog](https://arc.net/blog/arc-search) |
| Apple Intelligence | On-device vs Private Cloud Compute distinction surfaced in Settings (not inline); proactive Calendar/app suggestions | [Apple Intelligence](https://www.apple.com/apple-intelligence/) |

The winning consumer pattern is **not maximum autonomy** — it is reliable
public-info search, explainable provider status, local-first privacy, and
selective premium upgrades *only when cost and policy are visible*. kAir's frozen
primitives encode these *principles*; but several §9.4 recommendations introduce
net-new structure (the "+" sheet, result carousel, undo toast, upgrade chip,
haptics) — all enumerated as v2-bump items in §9.2, none added silently.

### 9.4 UI recommendations mapped to kAir primitives

| # | Recommendation | kAir primitive | v2-bump? |
|---|---|---|---|
| R1 | **Dock the composer** (no float-over-content); unify voice/attachments/shortcuts under one "+" sheet; **Stop button visible during streaming**; move model choice to a secondary chevron | single composer | **v2** ("+" sheet) |
| R2 | **Carousel vs single card by intent**: carousel (3–8 cards, ≤3 metadata lines, **1 CTA each, no internal scroll**) for "choose options"; single card for confirm/receipt | `ActionCardShell` 7 states (`empty`/`loading`/`error`/`permission` map to no-results/skeleton/inline-failure/permission) | **v2** (multi-card carousel) |
| R3 | **3-option Intent Preview** (Proceed / Edit / Handle it myself) for every pay/external action, showing scope in plain language; immediate-execute + timed **undo snackbar** for reversible low-stakes; post-action **receipt** | confirmation gate | **v2** (undo toast) |
| R4 | **Disclosure-first `permission` state**: why the surface needs it, what stays on-device, grant CTA, "Learn more"; **distinct error states** (provider outage / rate limit / network / policy) with preserved input | `ExecutionSurfaceShell` 5 states | no |
| R5 | **Cap RecommendedNext at ~4, dismissible, fade on typing**; thumbs feedback to learn; show only when query is exploratory / intent is uncertain | `RecommendedNextConsole` | no |
| R6 | **Three-tier provider badges** — Local (green shield "Private") / Included (neutral) / Premium (amber + cost); relative **freshness** timestamp; inline "premium available" **upgrade chip** (not a modal) | provider-status side channel | **v2** (8th pill) |
| R7 | **Arc-style process step-list** (searching→reading→building, check-off + haptic) for agent tasks >2 s — not a spinner; blinking caret reserved for prose streaming | `ExecutionSurfaceShell` loading state | **v2** (haptics) |
| R8 | Reusable **"I need more info" escalation** (what was tried / what's missing / 2–3 clarify chips); health queries → **"Talk to your doctor" primary CTA** | error state + confirmation gate | no |

**Regulatory note (health surfaces):** CA AB 3030 (2025) requires AI-authorship
disclosure + "contact a licensed provider" in clinical communications; CA AB 489
(2026) bars implying the AI holds a license; TX SB 1188 (2025) requires diagnostic
disclosure. These reinforce `PrivacyGuard.modelOutputsMustRemainNonDiagnostic` /
`modelOutputsMustShowLimitations` — non-diagnostic copy and a clinician CTA are
**release-blocking**, not polish.
[Fenwick](https://www.fenwick.com/insights/publications/the-new-regulatory-reality-for-ai-in-healthcare-how-certain-states-are-reshaping-compliance)

---

## 10. Market Positioning & Monetization (市场调研)

### 10.1 Market size (2026)

- AI assistant software: ~$9.8B (2025) → ~$35.7B (2033), CAGR 17.5% ([Grand View](https://www.grandviewresearch.com/industry-analysis/ai-assistant-software-market-report)).
- On-device AI: ~$17.6B (2025) → ~$185B (2035), CAGR ~27% ([SNS Insider](https://www.globenewswire.com/news-release/2026/05/26/3301200/0/en/On-Device-AI-Market-Size-to-Hit-USD-185-23-Billion-by-2035-Research-by-SNS-Insider.html)).
- China O2O local services: ~$150B (2024) → ~$300B (2033) ([Verified Market](https://www.verifiedmarketreports.com/product/online-to-offline-o2o-local-services-market-size-and-forecast/)).
- **Health & Wellness and Lifestyle/Services were the two fastest-growing AI prompt categories** 2024→2025 ([Sensor Tower](https://sensortower.com/blog/state-of-ai-apps-report-2025)).

→ kAir's verticals (life-services + health, on-device-first) sit on the fastest-growing curves.

### 10.2 Monetization model (research-validated)

- Anchor price is **$20/mo** (ChatGPT Plus, Perplexity Pro); ChatGPT adding an $8 "Go" tier; Doubao testing RMB 68/200/500.
- RevenueCat 2026: **trial-to-paid 42.5% median** (vs cold freemium 2.1% by D35); AI apps earn **+41% revenue/payer but churn 30% faster** ([RevenueCat](https://www.revenuecat.com/state-of-subscription-apps/)).

→ kAir: **trial-first, single all-inclusive membership ≈ $9.99–14.99/mo (~$99/yr)**, priced *below* the $20 anchor. Membership unlocks (a) premium maps (Gaode/Google by region), (b) metered search/research API, (c) a paid remote-model tier — all gated by `MembershipTier` + the A117 metered-entitlement ledger, **never silently**. On-device default = **unlimited at ~zero marginal cost** (Apple Foundation Models, free/offline); free-tier remote-model calls capped (e.g. ~5/day).

### 10.3 Competitive positioning

| Competitor | Strength | Gap kAir exploits |
|---|---|---|
| ByteDance Doubao (345M MAU) | organic distribution, agentic commerce via Douyin | general-purpose, not privacy-first |
| Tencent Yuanbao (114M MAU) | WeChat ecosystem, dual-model | indirect monetization, no local-first |
| Meituan Xiaomei / LongCat | deep life-services + merchant graph | **platform-dependent, China-only, no privacy controls** |
| Apple/Google platform AI | on-device substrate, distribution | not a life-services super-app |
| Perplexity ($500M ARR) | citations, search | not local-services |

**No incumbent occupies privacy-first + local-first + transparent cost-explicit premium upgrades, cross-market (China Gaode / global Google).** That is kAir's position. (81% of consumers fear AI data access; only 18% trust AI with their data; 57% cite privacy as the #1 assistant-trust driver — [PPC.land](https://ppc.land/81-of-consumers-fear-ai-data-access-but-daily-use-keeps-climbing/), [Zendesk](https://www.zendesk.com/newsroom/press-releases/global-survey-reveals-growing-consumer-trust-in-personal-ai-assistants/).)

### 10.4 Provider economics → membership-gating is structurally required

- **Google Maps**: Place Details $17 / 1k, Directions $5 / 1k, Geocoding $5 / 1k → ≈ **$2,549/mo at 100K MAU** (≈ linear per-MAU) ([MapAtlas](https://mapatlas.eu/blog/google-maps-api-pricing-2026)). **Gaode**: 2k req/day free, then commercial.
- **Search**: Serper $0.30–1 / 1k · Brave ~$5/mo · Exa $1–5 / 1k · Tavily $8 / 1k ([Awesome Agents](https://awesomeagents.ai/pricing/search-api-pricing/)).
- **LLM**: DeepSeek V3.2 **$0.14 / $0.28 per 1M tokens** (cheapest competitive); prices fell ~80% in 2025 ([Featherless](https://featherless.ai/blog/llm-api-pricing-comparison-2026-complete-guide-inference-costs)).

→ Free-tier premium maps/search/remote-model is **economically untenable at scale** — this *validates* the provider track's membership + metered-entitlement design. A $99/yr membership comfortably absorbs per-member provider cost — maps + metered search + a capped remote-model tier stay well under net membership revenue after the platform cut; the exact gross margin depends on the usage mix and free/paid split and belongs in a financial model, not asserted here. The provider abstraction (swap vendors without UI change) is a structural moat.

### 10.5 Risks (carry into the cut-plan)

- **Apple 30% IAP commission** (15% after year 1) on membership.
- **China**: local legal entity + CAC algorithm filing required for any AI feature exposed to CN users; Google Maps unavailable in China — the **China/global dual-provider split is a first-class architectural decision** (Gaode in CN, Google globally), not an afterthought.
- **Google Maps ToS**: no caching of Place Details > 30 days; use restricted to Maps context.
- **Remote-model cost at scale**: even at DeepSeek pricing, ~1M moderate free users ≈ $14k/mo → remote calls **must** stay behind the paywall (Doubao's 120T-tokens/day paywall trajectory confirms this).
- **AI-app churn 30% faster** → the antidote is **persistent offline daily utility** (on-device routing, on-device health, cached results), which kAir's local-first default already provides.
- **EU AI Act (Aug 2026)**: health-analysis surfaces may fall under Annex III high-risk (conformity assessment, technical docs, human oversight, logging); the EU region needs this gate before any health-facing remote inference (see the §7 health-AI-disclosure invariant).

### 10.6 Architecture alignment

Every monetization lever maps to an **existing** kAir seam — no new monetization infrastructure is required:

| Lever | kAir seam |
|---|---|
| Membership tiers (free/plus/pro) | `MembershipTier` + `ProviderAccessProfile` |
| Metered premium provider calls | A117 `ServerProviderMeteredEntitlementLedger` |
| Maps tiering (local → Gaode/Google) | provider track §5 + `MapProviderDescriptor` |
| Search/research metering | `SearchProvider` + `ResearchProvider` (R1) |
| Local → paid-remote model cascade | `ModelTierRouter` (R2) |
| On-device zero-marginal-cost default | `ModelRuntime` (R3) + Apple Foundation Models |
| Privacy/PIPL/health isolation | `PrivacyGuard` + `MemoryStore` domain isolation |

The contract-first provider track already encodes the economics; the redesign's job is to keep them **visible and never silent** (§7 invariants, §9.4 R6).

---

## 11. Review & Open Items

This redesign was independently reviewed on 2026-06-01 by a 5-perspective
multi-agent pass (architecture coherence · UI-freeze compliance · market
soundness · privacy/cost invariants · goal coverage; 55 findings synthesized).
High-confidence findings were applied inline:

- §1 / §4 / §6 status refreshed (A5 + R1–R6 done) and the §1 pipeline reordered to
  match `ConversationEngine.swift` (route → plan → validate).
- §2 split `MCPGatewayPolicy` (L4) from `MCPGateway` (L6/L7) — was double-assigned.
- §5.2 `ModelTierRequest` / `ModelTierDecision` corrected to the implemented struct.
- §9.2 / §9.4 v2-bump flags corrected — the "+" sheet, multi-card carousel, undo
  toast, premium-upgrade chip (8th pill), and haptics are **net-new structure**
  requiring a visual-system v2 bump; the false "only net-new surfaces" claim fixed.
- §10.4 removed an unsupported 54% margin figure.
- §7 added **health-AI-disclosure** and **data-locality (PIPL/CAC)** invariants +
  EU AI Act; §10.5 added the EU AI Act risk.

**Open items (reserved — not done in this doc pass):**
1. **PrivacyGuard anchoring gate** — add release-blocking `RuleID` cases
   (`noSilentPaidEscalation`, `noSecretsOnDevice`, `modelOutputsMustDiscloseAIAuthorship`,
   `dataLocalityPIPL`) so every §7 invariant lives in the single policy surface
   (Swift gate + tests).
2. **Visual-system v2 bump** — `super-app-visual-system-v1.md` → v2 must precede
   shipping any §9.2 net-new UI surface.
3. **EU AI Act health-high-risk conformity gate** (EU region) before health-facing
   remote inference.
4. **Kernel A6–A8** (PM-owned) and **provider track A175+** continue under the
   established merge-gated workflow.
