# 2026 Agent, Market, UI, Provider Research for kAir

Status: A181 research refresh; informational, not runtime code.
Last updated: 2026-06-01.

This note records current public evidence used to decide the next kAir cut
after A138. It separates sourced facts from kAir product judgment, then maps
the evidence to mobile-agent architecture, life-service search, UI handoff,
provider routing, MCP reservation, and cost-aware API planning.

## 1. Sources Verified

Access date for web sources: 2026-05-31.

| Area | Source | Date signal | Public evidence | kAir judgment |
|---|---|---:|---|---|
| Agent architecture taxonomy | https://arxiv.org/abs/2601.12560 | 2026-01 | Agent surveys continue to frame agents as perception/state, reasoning/planning, memory, tool/action, collaboration, and evaluation systems. | Keep model output as typed drafts/plans; policy and adapters execute, not raw prompts. |
| Autonomous-agent review | https://arxiv.org/abs/2504.19678 | revised 2026 | Reviews frameworks, tool integration, search, collaboration protocols, and security issues. | Keep trace-first evaluation and explicit provider/source/cost metadata before runtime providers. |
| Agent memory | https://arxiv.org/abs/2603.07670 | 2026-03 | Memory surveys separate write, manage, and read stages, with privacy, contradiction, retrieval, and latency risks. | Preserve local-first memory governance; no Health/private data to remote providers or MCP. |
| Budgeted/tool agents | https://arxiv.org/abs/2602.11541 | 2026-02 | Budget-constrained agent work treats costly tool/model calls as plan inputs that must be selected under explicit constraints. | Add vendor/cost policy before any live Search API call; avoid hidden metered calls. |
| Web/GUI agents | https://arxiv.org/abs/2603.12710 and https://arxiv.org/abs/2602.16855 | 2026 | Web/GUI agent work emphasizes planning, environment feedback, grounding, and tool execution, but also reveals brittleness and safety concerns. | Use GUI-agent ideas for evaluation and test automation; production iOS should use public APIs/App Intents. |
| Tool-use survey | https://arxiv.org/abs/2604.00835 | 2026-04 | Tool-use research stresses tool discovery, selection, invocation, feedback, and evaluation as separate problems. | Keep descriptor discovery, access filtering, invocation gate, and result receipts separate. |
| MCP latest spec | https://modelcontextprotocol.io/specification/2025-11-25/changelog | latest listed 2025-11-25 | MCP evolves authorization, tool/resource/prompt metadata, elicitation, and durable-task semantics. | Reserve MCP descriptors/prompts/resources, disabled by default, with scopes and consent before runtime. |
| MCP security | https://arxiv.org/abs/2603.22489 | 2026-03 | MCP threat models highlight tool poisoning through metadata, auth boundaries, and external-data risks. | Treat MCP metadata as hostile until verified; prompts cannot be trusted as access control. |
| MCP access control | https://arxiv.org/abs/2605.18414 | 2026-05 | ABAC-style MCP proxy work hides unauthorized tools at discovery and blocks calls again at invocation. | kAir needs descriptor filtering plus call-time gates before exposing runtime MCP. |
| Tencent Yuanbao / Hy3 | https://www.tencent.com/en-us/articles/2202320.html | 2026-04 | Tencent describes product co-design, real-world evaluation, cost-efficient inference, Yuanbao integration, MCP orchestration, and long workflows. | Compete through product-specific eval, cost-aware routing, and reliable receipts, not only model quality. |
| Meituan LongCat | https://tech.meituan.com/2026/01/20/longcat-flash-thinking-2601.html and https://arxiv.org/abs/2601.16725 | 2026-01 | LongCat emphasizes agentic search, tool use, noisy real-world environments, and thinking/tool-interaction training. | Life-service quality depends on robust search/tool traces, source quality, and error recovery. |
| Life-service benchmark | https://arxiv.org/abs/2507.08709 | 2025 | VitaBench models interactive daily-life tasks with multiple tools and realistic scenarios. | kAir should evaluate life-service flows as multi-step search/compare/open/save tasks before writes. |
| MARVIS-style mobile assistant | https://marvis-ai.com/ | checked 2026-05-31 | Public positioning centers screen understanding, app navigation, intervention, and confirmation for mobile tasks. | kAir should offer safer iOS-native action surfaces and transparent status receipts, not hidden universal tapping. |
| Apple App Intents | https://developer.apple.com/documentation/appintents | checked 2026-05-31 | Apple's supported action/entity surface for Shortcuts, Siri, Spotlight, and Apple Intelligence. | Keep system entry through kAir-owned App Intents and surface routing. |
| Apple Foundation Models | https://developer.apple.com/documentation/foundationmodels/ | checked 2026-05-31 | Apple positions on-device language understanding, guided generation, structured output, and tool calling. | Keep local model/provider abstraction; do not assume every device supports the same model/tool surface. |
| Apple location privacy | https://developer.apple.com/documentation/corelocation/configuring-your-app-to-use-location-services | checked 2026-05-31 | Location use requires purpose clarity and careful handling of stored/sent location data. | Maps remain local-first; remote map/search path must be explicit and member-gated. |
| Google Maps / Places policy | https://developers.google.com/maps/documentation/places/web-service/policies and https://mapsplatform.google.com/pricing/ | checked 2026-05-31 | Google Maps/Places has SKU-sensitive pricing and policy requirements around attribution, caching/storage, and Terms/Privacy. | Defer live Google Maps/Places until quota, attribution, caching, and map-display contracts are explicit. |
| Gaode / AMap policy | https://lbs.amap.com/pages/base_service_price and https://lbs.amap.com/api/compliance-center/protocols/privacy_202410 | checked 2026-05-31 | Gaode documents service quotas/QPS and privacy/compliance duties for developers. | Defer Gaode runtime until region, consent, server-key, quota/QPS, and China preference policy are explicit. |
| Search API vendors | https://exa.ai/pricing/api, https://brave.com/search/api, https://docs.tavily.com/documentation/api-reference/endpoint/search, https://docs.perplexity.ai/guides/pricing | checked 2026-05-31 | Search vendors expose different pricing, result payloads, raw-content controls, latency, QPS, model/search coupling, and AI-use semantics. | A105-A115 correctly stayed value-only; before live transport, kAir needs a normalized server-side entitlement/budget ledger. |
| Crawler policy | https://www.rfc-editor.org/rfc/rfc9309 | RFC 9309, 2022 | Robots Exclusion Protocol defines crawler access rules; it is not auth but is a required policy input. | Keep crawler runtime disabled until robots, source allow/deny, rate, retention, and audit gates exist. |

## 2. Confirmed Market Pattern

Sourced fact: current public agent systems are moving toward product-specific
agent loops with explicit tool/search capability, cost controls, and evaluation.

```text
intent
  -> structured draft / plan
  -> capability selection
  -> provider or tool candidate
  -> policy gate: privacy, cost, entitlement, source, terms, confirmation
  -> adapter execution or safe fallback
  -> cited/provenance-rich result
  -> memory candidate
  -> evaluation trace
```

Inference for kAir: the winning consumer-life pattern is not maximum autonomy.
It is reliable public-info search, explainable provider status, local-first
privacy, and selective premium/provider upgrades only when cost and policy are
visible to the user.

## 3. Adopt / Reserve / Reject

| Topic | Adopt now | Reserve | Reject for v1 |
|---|---|---|---|
| Agent loop | Typed `IntentDraft`, `ActionPlan`, `PlanValidator`, `CapabilityRouter`, provider policy, result projection, receipts. | Multi-step search/tool planning behind budget and latency gates. | Raw model text that directly calls every tool. |
| Evaluation | Product-specific traces for search/compare/open/save, status-copy checks, no-fake-completion tests. | Life-service benchmark fixtures after provider contracts mature. | Generic chat-only eval as proof of agent usefulness. |
| Memory | Local-first scoped records, retrieval reason, write policy, delete/export/pause. | Vector retrieval and learned forgetting after durable store proves stable. | Cloud-first unbounded memory or Health/private remote memory. |
| UI agents | Use GUI/web-agent research for testing and replay only. | Explicit assistive/test screen context with user-visible boundaries. | Hidden cross-app taps, private APIs, or fake completion. |
| MCP | Descriptor contracts, allowlists, scopes, prompt/resource/tool policy, audit. | Runtime MCP proxy after auth, sandbox, descriptor verification, prompt-injection tests, and consent. | Auto-discovered MCP servers or prompt descriptors inserted into model context. |
| Maps | Apple/local first, provider trace, future Google/Gaode membership upgrade. | Server-mediated Google/Gaode after attribution/cache/quota/privacy contracts. | API keys in iOS, direct SwiftUI provider calls, silent premium routing. |
| Search API | Provider-neutral contract exists through A115. | A117 metered entitlement ledger, then a single server-mediated vendor adapter. | Uncited public facts, hidden metered calls, raw provider payloads in UI. |
| Crawler | Policy-only, disabled by default. | Server crawler after RFC 9309/source/rate/retention/audit gates. | On-device scraping, paywall/login bypass, or uncited life-service facts. |
| Life services | Search, compare, summarize, save, open/deeplink. | Merchant APIs for reserve/order/pay after partner contracts and confirmations. | Claiming booked/ordered/paid/completed without verified receipt. |

## 4. Historical A104 Architecture Judgment

A86-A103 now prove a provider-neutral Search API contract pipeline:

- request/result receipts are value-only;
- cost, entitlement, source, citation, freshness, and content failures stay
  explicit;
- status copy reaches AppBootstrap and ChatStore only by rendered
  recommendation id;
- hidden ids, query text, raw page content, endpoints, credentials, SDK handles,
  and execution claims do not leak into status.

Decision: continue Search API, but do **not** add runtime network calls next.
The next missing contract is a **Search API vendor policy matrix**.

Why A105 should be vendor policy:

- Search vendors differ materially in pricing, quota/QPS, raw-content controls,
  source/citation payloads, freshness semantics, and allowed uses.
- Budgeted-agent research and provider docs both require cost/retention/source
  policy before invocation.
- Google/Gaode runtime remains higher-risk because map/display, caching,
  location privacy, and provider-specific terms must be solved before calls.
- MCP and crawler runtime remain higher-risk because tool metadata and crawled
  pages are adversarial inputs without strong discovery/invocation gates.

## 5. Target Architecture After A116

```text
ConversationEngine
  -> IntentDraft
  -> ActionPlan
  -> PlanValidator
  -> CapabilityRouter
  -> ProviderAccessProfile / ServerProviderQuotaSnapshot
  -> ProviderRoutingPolicy / SearchProviderPolicy / MCPGatewayPolicy
  -> ServerProviderEnvelopeFactory
  -> ServerProviderExecutionGate
  -> runtime manifest / connector planning / connector receipt
  -> Search API adapter contract
  -> Search API vendor policy matrix
  -> server-provider metered entitlement ledger
  -> vendor-specific server adapter only after policy passes
  -> UI-safe receipt/status source
  -> ProjectedRecommendationProvider / ExecutionSurfaceShell / Memory candidate
  -> EvaluationTrace
```

Rules:

- The model proposes structured data.
- Policy decides whether data can execute.
- Vendor policy decides whether a specific API/vendor can be used.
- UI renders provider, cost, freshness, source, and limitation status truthfully.
- Memory stores only policy-approved candidate facts/events.
- Prompt text, raw source content, Health data, endpoint URLs, API keys, OAuth
  secrets, SDK handles, merchant-write payloads, and provider raw responses do
  not cross into UI status or local memory.

## 6. Historical A116 Interface Reservation Matrix

| Future interface | Current state after A115 | Required gates before runtime | A116 decision, now historical |
|---|---|---|---|
| Apple/local maps | Local-first path remains the default. | Location purpose/privacy review and local UI validation. | Keep default. |
| Google Maps/Places/Routes | Provider family and cost/entitlement seams exist. | Server key, SKU quota, caching/attribution, display/terms, membership entitlement, metered ledger. | Defer until A117-style budget state and attribution/cache policy are explicit. |
| Gaode maps/search/route | Provider family and China preference seams exist. | Region gate, privacy consent, server key, quota/QPS, China provider preference, metered ledger. | Defer until consent, quota copy, and regional budget state are explicit. |
| Search API | Provider-neutral request/result/status pipeline exists through A115. | Server-side metered entitlement ledger, result retention/raw-content policy, cost tier, source/citation requirements. | **Implemented by A117.** Add value-only metered entitlement ledger. |
| Crawler | Policy-only, disabled by default. | RFC 9309, source allow/deny, rate limit, retention, audit, sandbox. | Defer; Search API covers v1 public info first. |
| MCP tools/resources/prompts | Descriptor and policy reservation only. | Descriptor verification, scopes, discovery filter, invocation gate, sandbox, prompt-injection tests, consent. | Defer; do not expose MCP prompts to model context yet. |
| Remote model gateway | Model/provider contracts only. | StoreKit entitlement, server validation, privacy screen, budget, eval. | Defer; local model/provider abstraction remains enough for next cut. |
| Life-service writes | Read-only search/open/deeplink only. | Partner contracts, auth, confirmation artifacts, receipts, cancellation/refund/error policy. | Defer writes. |

## 7. Prompt And MCP Audit

Current prompt/interface reservations are still safe if the next agent preserves
these boundaries:

- Model prompts: no production prompt registry exists; keep model output as typed
  drafts/plans, not executable strings.
- Provider prompts: provider adapters should consume typed query/context values,
  privacy class, quota, source policy, and vendor policy, not raw prompt text.
- MCP prompts: descriptors may exist only as allowlisted metadata; they must not
  enter model context before descriptor verification and scope filtering.
- Search/crawler prompts: Search API gets query/result/vendor-policy contracts;
  crawler remains disabled and robots-aware.
- Connector receipts: UI status can show receipt metadata, but never raw provider
  payloads, endpoint URLs, credentials, prompt text, or raw page bodies.

## 8. Evaluation Gates For A105+

Before real Search API execution, add tests or fixtures for:

- vendor policy cases for Exa/Brave/Tavily-like shapes without naming a winner
  in runtime code;
- pricing/cost class, quota, freshness, raw-content, and source/citation policy
  per vendor;
- no private/Health query to remote search;
- no metered Search API call without entitlement/quota;
- citations/source hosts required for every public-info result;
- no raw prompt, raw page body, credential, endpoint, OAuth token, SDK handle, or
  provider payload in encoded/status/debug text;
- no booking/order/payment/completion wording for read-only life-service results;
- deterministic fallback when a vendor is disabled, over budget, or missing
  source/citation support.

## 9. Historical A104 Coding Cut

A105 Search API Vendor Policy Matrix Proof has since been implemented, and the
Search API value-only path has advanced through A115.

A105-A115 now cover vendor policy, provider-status packaging, app-root
handoff, payload dispatch, dispatch authorization, transport lease, lease status
packaging, and cross-stage status composition. The A104 conclusion was still
directionally correct: Search API should advance before crawler/MCP/maps
runtime, but only after cost, policy, and status gates are explicit.

## 10. A116 Refresh After A115

Current project state from repo inspection:

- Search API has a provider-neutral request/result/status path through A115.
- `ToolRegistry` and `AgentRegistry` remain comment-first reservations; no
  production prompt registry or arbitrary tool executor exists.
- `PlanValidator` remains a pure value gate; model output cannot directly call
  Swift, providers, MCP, crawler, payment, or external apps.
- `MCPGateway` already reserves tools, resources, and prompts with allowlists,
  trust state, confirmation, and Health blocking, but it still contains no MCP
  client/runtime.
- `ProviderAccessProfile`, `ServerProviderQuotaSnapshot`, A105 vendor policy,
  and A112 transport lease prove cost can be represented, but no durable
  server-side entitlement/usage ledger exists yet.

### A116 Evidence Delta

| Evidence | Direct signal | A116 inference for kAir |
|---|---|---|
| Agentic AI architecture survey | Modern agents are decomposed into perception, planning, action, tool use, collaboration, and evaluation, with prompt injection and hallucinated action as open risks. | kAir's typed plan -> policy -> adapter -> receipt stack is aligned; do not collapse it into prompt-driven provider calls. |
| Agent memory survey | Memory quality depends on write/manage/read policy, contradiction handling, latency budgets, and privacy governance. | Public search results can become memory candidates only after citation/source and privacy policy pass; Health/private data remains excluded. |
| MCP spec and MCP threat-model papers | MCP expands tool/resource/prompt access but treats user consent, tool safety, and untrusted metadata as core safety concerns; tool poisoning is a concrete client-side risk. | Keep MCP runtime disabled; next MCP work should be descriptor filtering/call-time gate hardening, not server connection. |
| LongCat / Meituan-style agentic search | Life-service agent quality depends on robust tool interaction under noisy real-world conditions, not only chat response quality. | kAir needs traceable search/citation/error-recovery fixtures before claiming life-service execution. |
| Tencent Yuanbao-style market pattern | Current consumer assistants compete on product-integrated workflows, retrieval/search, cost-efficient inference, and long-task orchestration. | kAir should differentiate through local-first control, transparent receipts, and cost-aware provider routing rather than universal hidden automation. |
| MARVIS-style mobile agent pattern | Public positioning for mobile agents emphasizes screen understanding, app navigation, intervention, and user confirmation. | kAir can learn from the UX expectation, but production should still use App Intents, public APIs, typed adapters, and visible receipts instead of hidden cross-app tapping. |
| Open-source method scan | Existing kAir research already mapped Spezi, Foundation Models, Spec-Kit, FluentUI Apple tokens, MLX, ExecuTorch, Core ML, and LongCat-like open reports as architecture patterns, not dependencies. | Continue borrowing modularity/eval/local-runtime methods behind explicit gates; do not add a dependency or runtime just because a project is open source. |
| Search vendors | Exa, Brave, Tavily, and Perplexity expose materially different search, content extraction, pricing, request, and answer/citation semantics. | Live Search API cannot be chosen safely from a static vendor enum alone; it needs normalized budget units and server-verified entitlement state. |
| Google/Gaode map providers | Google Places has policy/billing/attribution surfaces; Gaode publishes quotas/QPS/pricing and privacy/compliance duties. | Maps should stay Apple/local by default; Google/Gaode routes need the same cost ledger plus region, attribution, and consent gates before membership upgrades. |
| Apple iOS docs | App Intents expose app actions/content through system surfaces; Foundation Models emphasize on-device structured output/tool calling; location services require explicit preparation and privacy purpose. | iOS-side kAir should keep local planning and public action surfaces; provider keys and metered usage belong server-side. |
| RFC 9309 | Robots rules are a required crawler policy input, not a user-auth bypass. | Crawler remains lower priority than Search API; when resumed, it must be robots/source/rate/retention/audit first. |

### A116 Decision

Do **not** start live Search API transport next.

The next smallest safe implementation gate is:

**A117 Server Provider Metered Entitlement Ledger Proof**

Why this outranks live Search API:

- A115 proves status composition, but live vendors still need server-side
  accounting for membership, quota period, remaining budget, unit price, and
  provider-family/vendor-specific metering before any endpoint is safe.
- Search API vendors price and shape results differently; kAir needs a
  normalized cost/entitlement decision that can feed A105 vendor policy and
  A112 transport lease without embedding live pricing in UI, prompts, or iOS.
- Google/Gaode membership routing needs the same ledger abstraction later, so
  this gate improves both Search API and map-provider upgrade paths.
- MCP/crawler risks are still more adversarial than Search API; they should
  wait until descriptor/crawler policy gates are reinforced.

### A117 Comment-Programming Frame

Allowed implementation files for A117:

- `kAir/Core/Networking/ServerProviderMeteredEntitlementLedger.swift`
- `kAirTests/Networking/ServerProviderMeteredEntitlementLedgerTests.swift`
- `Docs/architecture/kair-provider-routing-mcp-search-v1.md`
- `Docs/architecture/kair-agent-market-fit-audit-v1.md`
- `Docs/architecture/kair-next-agent-prompts-v1.md`

A117 should add pure value contracts only:

- `ServerProviderMeteredEntitlementSnapshot`: provider family/vendor id,
  membership tier, quota period id, included units, used units, reserved units,
  remaining units, currency/unit label, and source timestamp.
- `ServerProviderMeteredUsageRequest`: trace id, provider family/vendor id,
  capability, estimated unit count, cost class, privacy class, freshness, and
  user-facing reason.
- `ServerProviderMeteredUsageDecision`: accepted/rejected, denial reason,
  remaining/reserved units, audit copy, and status-safe summary.
- Rejection reasons: missing snapshot, vendor disabled, membership missing,
  privacy blocked, Health/private context, over quota, stale snapshot,
  currency/unit mismatch, capability mismatch, and already reserved budget.

Acceptance for A117:

- Tests prove included quota, metered entitlement, over-budget, stale snapshot,
  provider mismatch, capability mismatch, privacy/Health block, and duplicate
  request behavior.
- Encoded/debug/status copy contains no endpoint URL, API key, OAuth token,
  SDK/client handle, raw query, raw page/provider payload, payment/order data,
  or execution claim.
- The ledger decision can be consumed by A105 vendor policy and A112 transport
  lease as a value input, but A117 does not wire production runtime, network
  transport, StoreKit, AppBootstrap defaults, ChatStore behavior, SwiftUI, MCP,
  crawler, Google/Gaode SDKs, or real provider calls.

## 11. A121 Refresh After A120

Current project state from repo inspection:

- A117 now provides `ServerProviderMeteredUsageDecision` values and can lower an
  accepted decision into `ServerProviderSearchAPITransportBudgetContext`.
- A118-A120 prove accepted/blocked metered entitlement status reaches
  AppBootstrap and ChatStore and composes deterministically with vendor policy,
  payload dispatch, dispatch authorization, and transport lease status.
- A112 transport lease still accepts an explicit budget context; there is not
  yet a dedicated gate proving that a live-provider lease can be issued only
  from an accepted A117 metered entitlement decision and rejected otherwise.
- No live Search API, crawler, MCP client, Google/Gaode SDK, StoreKit payment,
  AppBootstrap default, ChatStore behavior, or SwiftUI provider runtime exists.

### A121 Evidence Delta

| Evidence | Current public signal | A121 inference for kAir |
|---|---|---|
| Cost-aware LLM routing: FrugalGPT, RouteLLM, LLMCompiler | Current agent systems reduce cost by making model/tool choice an explicit planning and dispatch decision, often by routing to cheaper paths or compiling tool-call DAGs before execution. | Provider/runtime calls should consume typed cost and entitlement decisions before any connector path, not rely on hidden runtime fallback. |
| MCP spec and security work | MCP exposes tools, resources, prompts, authorization, elicitation, and sampling surfaces; security papers and guidance keep emphasizing tool metadata, prompt injection, authorization, and call-time enforcement. | MCP remains reserved. A live MCP client is still riskier than hardening provider budget/lease handoff. |
| Apple App Intents, Foundation Models, and Core Location docs | iOS offers public app/action surfaces, on-device model surfaces, and privacy-sensitive location APIs. | kAir should keep the default iOS path local and public-surface based; remote provider keys and metered use remain server-side. |
| Google Maps/Places official policy/pricing | Google provider paths are SKU/cost, attribution, caching/storage, and privacy/terms sensitive. | Google Maps/Places runtime is still blocked until the same metered entitlement and display/attribution contracts are tied to the lease path. |
| Gaode/AMap official quota/pricing/privacy material | Gaode provider paths need regional preference, quota/QPS, server-key, and privacy/compliance handling. | Gaode runtime should follow the same accepted metered entitlement -> lease -> receipt path, plus region and consent gates. |
| Search API vendors: Exa, Brave, Tavily, Perplexity | Search vendors differ in pricing, raw-content controls, citation/source shape, latency, and answer/search coupling. | Search API remains the best first runtime family, but only after A112 lease issuance is proven to depend on A117 accepted budget decisions. |
| Life-service agent research and LongCat/VitaBench-style benchmarks | Public life-service agents stress multi-turn search/tool traces, spatiotemporal context, noisy tool output, and verified actions. | kAir should continue read-only public-info search with citations before bookings/orders/payments; no fake completion wording. |
| RFC 9309 and crawler practice | Robots rules are a crawler policy input, not authorization to bypass source or retention policy. | Crawler runtime remains later than Search API because it needs source/rate/retention/audit gates in addition to cost. |

Sources rechecked for this A121 pass:

- FrugalGPT: https://arxiv.org/abs/2305.05176
- RouteLLM: https://arxiv.org/abs/2406.18665
- LLMCompiler: https://arxiv.org/abs/2312.04511
- MCP specification: https://modelcontextprotocol.io/specification/2025-11-25
- MCP security landscape: https://arxiv.org/abs/2503.23278
- Apple App Intents: https://developer.apple.com/documentation/appintents
- Apple Foundation Models: https://developer.apple.com/documentation/foundationmodels/
- Apple Core Location privacy setup: https://developer.apple.com/documentation/corelocation/configuring-your-app-to-use-location-services
- Google Places policies: https://developers.google.com/maps/documentation/places/web-service/policies
- Google Maps Platform pricing: https://mapsplatform.google.com/pricing/
- Gaode pricing/quota surface: https://lbs.amap.com/pages/base_service_price
- Gaode privacy/compliance surface: https://lbs.amap.com/api/compliance-center/protocols/privacy_202410
- Exa API pricing: https://exa.ai/pricing/api
- Brave Search API pricing: https://brave.com/search/api
- Tavily Search API docs: https://docs.tavily.com/documentation/api-reference/endpoint/search
- Perplexity API pricing: https://docs.perplexity.ai/guides/pricing
- Tencent Hy3/Yuanbao public note: https://www.tencent.com/en-us/articles/2202320.html
- Meituan LongCat Flash: https://tech.meituan.com/2026/01/20/longcat-flash-thinking-2601.html
- VitaBench: https://arxiv.org/abs/2509.26490
- LocalSearchBench: https://arxiv.org/abs/2512.07436
- Robots Exclusion Protocol: https://www.rfc-editor.org/rfc/rfc9309

### A121 Decision

Do **not** start live Search API, Google/Gaode, crawler, MCP, payment, booking,
or remote model runtime next.

The next safe implementation gate is:

**A122 Search API Metered Entitlement Transport Lease Handoff Proof**

Why this outranks live provider runtime:

- A120 proves the UI/status side channel is deterministic, but it does not prove
  that A112 transport leases are actually derived from accepted A117 metered
  entitlement decisions.
- Search API is still the lowest-risk first remote family because it is
  read-only and citation/source oriented, but the last pre-runtime gap is the
  budget handoff into the lease gate.
- Google/Gaode provider upgrades need the same pattern later: accepted member
  entitlement and quota state must authorize a lease before any provider key,
  SDK, or server adapter is considered.
- MCP and crawler remain more adversarial because tool descriptors and crawled
  pages are untrusted inputs; they should wait until search-provider cost and
  lease composition is locked.

### A122 Comment-Programming Frame

Allowed implementation files for A122:

- `kAirTests/Networking/ServerProviderSearchAPITransportLeaseTests.swift`
- `Docs/architecture/kair-provider-routing-mcp-search-v1.md`
- `Docs/architecture/kair-agent-market-fit-audit-v1.md`
- `Docs/architecture/kair-next-agent-prompts-v1.md`

A122 should add tests only unless a minimal production helper is proven missing:

- Build an accepted A117 metered entitlement decision and pass
  `decision.transportBudgetContext(...)` into the A112 transport lease gate.
- Prove included-quota and metered-premium accepted decisions issue leases only
  when payload, dispatch receipt, vendor authorization, provider family,
  capability, cost class, freshness, result shape, source policy, and citation
  policy all match.
- Prove rejected A117 decisions return nil budget context and cannot issue a
  lease.
- Prove mismatched provider family, cost class, vendor, or missing entitlement
  remains blocked without silently falling back to generic quota snapshots.

Acceptance for A122:

- Tests prove A112 lease issuance can be driven by A117 accepted metered
  entitlement budget contexts for both included-quota and metered-premium cases.
- Rejected entitlement decisions, hidden generic quota snapshots, and mismatched
  budget metadata do not issue a lease.
- Encoded/debug/status copy contains no endpoint URL, API key, OAuth token,
  SDK/client handle, raw query, raw page/provider payload, payment/order data,
  crawler/MCP metadata, maps SDK metadata, or execution claim.
- A122 does not change production AppBootstrap, ChatStore, SwiftUI, runtime
  transport, StoreKit, crawler, MCP client, Google/Gaode SDK, memory, telemetry,
  transcript, payment, booking, or real provider behavior.

## 12. A125 Refresh After A124

Current project state from repo inspection:

- A122 proves issued Search API transport leases can be derived from accepted
  A117 metered entitlement budget contexts, and rejected/generic/mismatched
  budget contexts cannot issue leases.
- A123-A124 prove those lease statuses reach provider-status copy and compose
  through AppBootstrap/ChatStore with metered entitlement, vendor policy,
  payload dispatch, and dispatch authorization status.
- There is still no Search API live transport, endpoint URL, API key, OAuth
  token, URLSession, server adapter, crawler runtime, MCP client, Google/Gaode
  SDK, StoreKit payment, AppBootstrap default, ChatStore behavior, or SwiftUI
  runtime provider wiring.
- The concrete remaining gap is earlier than "call a provider": no contract yet
  binds an issued A122 lease back to the exact A86/A91/A92/A105/A108 request
  metadata as a server-side Search API transport request.

### A125 Evidence Delta

| Evidence | Current public signal | A125 inference for kAir |
|---|---|---|
| Cost-aware routing papers: FrugalGPT, RouteLLM, LLMCompiler | Current cost-aware systems route or compile calls before execution and treat cost/latency/quality as dispatch inputs, not hidden runtime side effects. | A124 is necessary but not sufficient for live calls; the next request object must prove it consumes the accepted budget/lease path. |
| MCP spec and security/access-control work | MCP keeps expanding tools/resources/prompts/authorization/elicitation surfaces; security work highlights poisoned descriptors, prompt injection, and call-time authorization risk. | MCP runtime stays disabled. A future MCP gate should mirror the same descriptor-filter plus invocation-request proof, not auto-discover servers. |
| Apple App Intents, Foundation Models, Core Location | Apple-supported iOS automation remains structured and privacy-explicit; location data requires purpose strings and care around stored/sent data. | kAir should keep Apple/local maps as the default and treat remote provider requests as explicit, server-side, auditable contracts. |
| Google Maps/Places official policy/pricing | Google provider paths are SKU, attribution, display, storage/caching, privacy, and Terms-sensitive. | Google/Gaode upgrade cannot be a simple client-side provider switch; it needs the same lease-to-request contract plus map display/cache policy. |
| Gaode/AMap pricing/quota/privacy docs | Gaode provider paths carry quota/QPS, regional, key-management, and privacy/compliance constraints. | Gaode should remain a later provider-specific runtime after region/consent/quota/request contracts are explicit. |
| Search API vendors: Exa, Brave, Tavily, Perplexity | Vendors differ in pricing, result shape, raw-content controls, citation/source fields, answer generation, and rate/latency semantics. | Search API is still the narrowest first remote family, but A126 must normalize a vendor request before any endpoint or key exists. |
| Tencent Yuanbao/Hy3 and Meituan LongCat/life-service signals | Public agent products emphasize product-specific search/tool traces, long-task orchestration, cost-efficient inference, and noisy real-world evaluation. | kAir should keep visible receipts and read-only search/compare/open/save first; no booking/order/payment/completion claim without a verified receipt. |
| MARVIS-style mobile assistant positioning | Mobile-assistant expectations include screen understanding, app navigation, intervention, and confirmation. | kAir can learn the UX expectation, but production should stay on App Intents, typed adapters, and visible provider receipts rather than hidden tapping. |
| RFC 9309 and crawler practice | Robots policy is necessary but not sufficient; crawler output is untrusted source data. | Crawler runtime remains behind Search API because it needs source, robots, rate, retention, sandbox, and audit gates in addition to cost. |

Sources rechecked for this A125 pass:

- Agent/cost routing: https://arxiv.org/abs/2305.05176,
  https://arxiv.org/abs/2406.18665, https://arxiv.org/abs/2312.04511
- MCP specification and security: https://modelcontextprotocol.io/specification/2025-11-25,
  https://modelcontextprotocol.io/specification/2025-11-25/changelog,
  https://arxiv.org/abs/2503.23278, https://arxiv.org/abs/2604.05969
- Apple platform: https://developer.apple.com/documentation/appintents,
  https://developer.apple.com/documentation/foundationmodels/,
  https://developer.apple.com/documentation/corelocation/configuring-your-app-to-use-location-services
- Google Maps/Places: https://developers.google.com/maps/documentation/places/web-service/policies,
  https://mapsplatform.google.com/pricing/
- Gaode/AMap: https://lbs.amap.com/pages/base_service_price,
  https://lbs.amap.com/api/compliance-center/protocols/privacy_202410
- Search vendors: https://exa.ai/pricing/api, https://brave.com/search/api,
  https://docs.tavily.com/documentation/api-reference/endpoint/search,
  https://docs.perplexity.ai/guides/pricing
- Competitor/life-service signals: https://www.tencent.com/en-us/articles/2202320.html,
  https://tech.meituan.com/2026/01/20/longcat-flash-thinking-2601.html,
  https://arxiv.org/abs/2509.26490, https://arxiv.org/abs/2512.07436,
  https://marvis-ai.com/
- Crawler policy: https://www.rfc-editor.org/rfc/rfc9309

### A125 Decision

Do **not** start live Search API, Google/Gaode, crawler, MCP, payment, booking,
or remote model runtime next.

The next safe implementation gate is:

**A126 Search API Transport Request Contract Proof**

Why this outranks live provider runtime:

- A124 proves presentation composition, not an executable server request.
- A112/A122 prove a lease can be issued, but no value object yet proves an
  issued lease still matches the exact prepared request, transport payload,
  dispatch receipt, vendor decision, dispatch authorization, result shape,
  source policy, citation policy, cost class, freshness, and metered budget
  context at the moment a future server adapter would be selected.
- Search vendors differ materially in request/response shape, raw-content
  controls, attribution, and pricing. A provider-specific endpoint must not be
  chosen until the normalized request contract can reject stale or mixed
  metadata without leaking endpoint, credential, or raw query copy into UI.
- Google/Gaode and MCP need the same pattern later: a server-side request
  contract bound to entitlement, region/consent, policy, and receipt metadata
  before any runtime client is introduced.

## 13. A130 Refresh After A129

Current project state from repo inspection:

- A126 added the lease-bound, value-only Search API transport request contract
  selected by A125.
- A127 packaged A126 prepared/rejected request decisions into rendered-id
  scoped provider-status copy.
- A128 proved that request-status source passes through
  `AppBootstrap(providerStatusSources:)` and ChatStore lookup for rendered ids
  only.
- A129 proved the request-status layer composes with metered entitlement,
  vendor policy, payload dispatch, dispatch authorization, and transport lease
  status without stale detail mixing.
- There is still no live Search API transport, endpoint URL, API key, OAuth
  token, URLSession, server adapter runtime, crawler runtime, MCP client,
  Google/Gaode SDK, StoreKit payment, AppBootstrap production default,
  ChatStore behavior, SwiftUI runtime provider wiring, booking, or provider
  execution.
- The concrete remaining gap is now after "prepare request" but before "call a
  provider": no value object yet binds a normalized/cited Search API result
  receipt back to the exact A126 transport request and upstream metered,
  vendor, lease, source, citation, and cost chain.

### A130 Evidence Delta

| Evidence | Current public signal | A130 inference for kAir |
|---|---|---|
| Cost-aware routing papers: FrugalGPT, RouteLLM, LLMCompiler, BaRP, budget-aware routing | Current systems continue to treat cost, latency, preference, and dispatch strategy as explicit policy inputs before execution. Newer routing work frames deployment as an online tradeoff, not a hidden side effect. | A129 is not enough to execute. The next object should prove response/receipt acceptance against the prepared request and cost chain before any transport runtime exists. |
| Search API vendors: Brave, Tavily, Exa, Perplexity | Vendor surfaces differ on result vs answer products, source URLs, snippet/content chunks, raw-content toggles, citation-token/search-query billing, latency/search-depth controls, and AI-optimized context. | Search API is still the narrowest remote provider family, but the next safe gate is response normalization/receipt binding. Do not choose a vendor endpoint until response shape, citation, source, cost, and freshness handling are typed. |
| Google Maps/Places official policy/pricing | Google Maps Platform moved to SKU categories/free usage caps; Places policies require attribution, Terms/Privacy, strict caching rules, map/display constraints, and special disclosure for AI summaries. | Google/Gaode escalation still cannot be a client-side provider switch. Map providers need provider-specific display/cache/attribution contracts after the generic Search API response receipt pattern is proven. |
| Gaode/AMap official pricing, key, privacy, and terms pages | Gaode has account-tier monthly quota, QPS, paid traffic-pack behavior, key-management requirements, privacy/compliance obligations, and regional/service-use limits. | Gaode remains a later China/provider-specific runtime. Region, consent, account tier, quota, QPS, privacy disclosure, and terms gates must precede any SDK/API integration. |
| MCP specification and security work | The official security guidance, MCP safety papers, and newer MCP cryptography/access-control work emphasize authorization, descriptor/tool trust, prompt-injection risk, credential handling, attestation, and runtime policy. | MCP stays reserved and disabled by default. kAir should not auto-discover or call MCP servers until descriptors, consent, auth scope, sandboxing, and call-time policy are proven in value-only gates. |
| Apple App Intents, Foundation Models, and Core Location | Apple continues to favor structured App Intents, on-device Foundation Models, and explicit location authorization/privacy policy handling. | The default product path should remain local-first iOS with visible outcomes. Health/local contexts stay local-only; remote requests require server-side metadata receipts. |
| Mobile GUI-agent papers and MARVIS-style assistants | Mobile-Agent-v3.5, AppAgent/OS-Copilot, and public MARVIS-style products show market demand for screen/app navigation and cross-device control, but they rely on broad GUI automation, tool execution, and sandbox assumptions. | kAir can learn the UX expectation of a conversational task surface, but hidden third-party app control remains a non-goal. Use App Intents, typed adapters, and explicit receipts instead of invisible tapping. |
| Tencent Hy3/Yuanbao and Meituan LongCat/life-service signals | Public signals emphasize long multi-step agent workflows, MCP/tool orchestration, cost-efficient inference, domain-specific local-life evaluation, and cited/retrievable public information. | Keep the product contract around transparent search/compare/open/save first. No booking, ordering, payment, or completion claim should appear before verified provider receipts and user confirmation gates exist. |
| Robots/crawler policy | RFC 9309 is a crawler baseline, while vendor/search docs expose paid, normalized, source-attributed alternatives for public web information. | Crawler runtime remains behind Search API. A crawler later needs robots, source, rate, retention, sandbox, and audit gates in addition to the same response-receipt contract. |

Sources rechecked for this A130 pass:

- Cost/routing and agent dispatch: https://arxiv.org/abs/2305.05176,
  https://arxiv.org/abs/2406.18665, https://arxiv.org/abs/2312.04511,
  https://arxiv.org/abs/2510.07429, https://arxiv.org/abs/2602.21227
- MCP specification/security: https://modelcontextprotocol.io/specification/2025-06-18/basic/index,
  https://modelcontextprotocol.io/specification/2025-06-18/basic/security_best_practices,
  https://arxiv.org/abs/2503.23278, https://arxiv.org/abs/2504.03767,
  https://arxiv.org/abs/2512.03775, https://arxiv.org/abs/2604.05969
- Apple platform: https://developer.apple.com/documentation/appintents,
  https://developer.apple.com/documentation/foundationmodels/,
  https://developer.apple.com/apple-intelligence/,
  https://developer.apple.com/documentation/corelocation/configuring-your-app-to-use-location-services
- Google Maps/Places: https://developers.google.com/maps/billing-and-pricing/march-2025,
  https://developers.google.com/maps/documentation/places/web-service/policies,
  https://cloud.google.com/maps-platform/terms,
  https://mapsplatform.google.com/pricing/
- Gaode/AMap: https://lbs.amap.com/pages/base_service_price,
  https://lbs.amap.com/upgrade,
  https://lbs.amap.com/api/webservice/create-project-and-key,
  https://lbs.amap.com/api/compliance-center/protocols/privacy_202410,
  https://lbs.amap.com/pages/terms/
- Search vendors: https://brave.com/search/api/,
  https://docs.tavily.com/documentation/api-reference/endpoint/search,
  https://exa.ai/pricing/api, https://exa.ai/docs/reference/contents-retrieval,
  https://docs.perplexity.ai/docs/getting-started/pricing
- Competitor/life-service/mobile-agent signals:
  https://www.tencent.com/en-us/articles/2202320.html,
  https://tech.meituan.com/2026/01/20/longcat-flash-thinking-2601.html,
  https://arxiv.org/abs/2601.16725, https://arxiv.org/abs/2512.07436,
  https://arxiv.org/abs/2602.16855, https://appagent-official.github.io/,
  https://marvis-ai.com/
- Crawler policy: https://www.rfc-editor.org/rfc/rfc9309

### A130 Decision

Do **not** start live Search API, Google/Gaode SDK/API runtime, crawler runtime,
MCP client runtime, payment, booking, remote model runtime, or hidden
third-party app control next.

The next safe implementation gate is:

**A131 Search API Transport Response Receipt Contract Proof**

Why this outranks live provider runtime:

- A126 proves a prepared server-side transport request; it does not prove that a
  normalized/cited result receipt belongs to that exact request.
- A127-A129 prove request-status presentation and composition; they do not
  accept, reject, or bind response/result metadata.
- Existing A86 adapter result receipts already normalize cited result metadata,
  but they are earlier than the metered lease/request stack. A131 should bridge
  that normalized result receipt to the A126 transport request without
  executing transport.
- Search vendors differ materially on answer vs result products, citation
  semantics, snippet/raw-content controls, search-depth cost, and latency. kAir
  needs a provider-neutral response receipt before choosing any endpoint or SDK.
- Google/Gaode, crawler, and MCP can reuse the same pattern later: every
  provider response must bind to an authorized request and preserve source,
  attribution, cost, privacy, and status-safe copy before user-facing actions.

### A126 Comment-Programming Frame

Allowed implementation files for A126:

- `kAir/Core/Networking/ServerProviderSearchAPITransportRequest.swift`
- `kAirTests/Networking/ServerProviderSearchAPITransportRequestTests.swift`
- `Docs/architecture/kair-provider-routing-mcp-search-v1.md`
- `Docs/architecture/kair-agent-market-fit-audit-v1.md`
- `Docs/architecture/kair-next-agent-prompts-v1.md`

A126 should add pure value contracts only:

- `ServerProviderSearchAPITransportRequest`: a metadata-only server-side Search
  API request prepared from an issued A122 lease and the matching A86/A91/A92/
  A105/A108 chain.
- `ServerProviderSearchAPITransportRequestDecision`: prepared/rejected state,
  rejection reason, request id, lease id, payload id, dispatch receipt id,
  authorization id, vendor decision id, metered decision id, provider/vendor,
  capability, cost class, freshness, result shape, result limit, source/citation
  policy summary, and status-safe copy.
- Rejection reasons: missing/rejected lease, missing payload, missing request,
  missing dispatch, missing vendor decision, missing authorization, lease-payload
  mismatch, lease-dispatch mismatch, lease-authorization mismatch, vendor
  mismatch, provider/capability/cost/freshness/result-shape mismatch,
  source-policy mismatch, citation-policy mismatch, result-limit mismatch, and
  missing metered decision id.

Acceptance for A126:

- Tests prove an issued metered-entitlement Search API lease can prepare a
  transport request only when every upstream id and safe metadata field matches.
- Tests prove rejected leases, generic budget leases, stale payload/dispatch/
  authorization/vendor metadata, mismatched result shape, missing citation
  policy, and missing metered decision id all reject deterministically.
- Encoded/debug/status copy contains no endpoint URL, API key, OAuth token,
  SDK/client handle, raw query, raw page/provider payload, payment/order data,
  crawler/MCP metadata, maps SDK metadata, or execution claim.
- A126 does not add URLSession, provider endpoints, credentials, runtime
  transport, StoreKit, AppBootstrap defaults, ChatStore behavior, SwiftUI, MCP,
  crawler, Google/Gaode SDKs, memory, telemetry, transcript, payment, booking,
  or real provider behavior.

## 14. A139 Refresh After External Provider Status Composition

A131-A138 closed the status/composition path that was still open after A130:
Search API response receipt status, generic external-provider adapter preflight
status, app-root handoff, ChatStore lookup, and cross-stage first-wins
composition are now proven as value-only contracts. That changes the next
question from "can status be represented" to "what must be audited before any
future provider attempt is allowed to exist."

Current repo state at this refresh:

- Done: metered entitlement, vendor policy, payload dispatch, dispatch
  authorization, transport lease, transport request, transport response, and
  external provider preflight status all compose for rendered ids without stale
  detail mixing.
- Still absent by design: live Search API calls, Google/Gaode SDK/API calls,
  crawler runtime, MCP client/runtime, URLSession transport, endpoint URLs,
  credentials, OAuth, remote model runtime, StoreKit/payment/booking/order
  flows, production AppBootstrap defaults, ChatStore production behavior,
  SwiftUI provider UI, raw page ingestion, hidden third-party app control, and
  real provider execution.

### A139 Evidence Delta

| Area | Source fact refreshed | kAir judgment |
|---|---|---|
| Agent architecture, routing, and evaluation | Cost-aware and tool-agent work still treats cost, quality, latency, planning, and tool traces as explicit policy/evaluation inputs before execution: FrugalGPT, RouteLLM, LLMCompiler, BaRP, xRouter, LocalSearchBench/VitaBench-style task evaluation. | A138 status composition is necessary but not enough. The next value object should record what would be audited and evaluated for a provider attempt before any live call exists. |
| MCP spec and governance | The current MCP specification has continued to add protocol structure around authorization, elicitation, tasks, and tool/resource/prompt behavior, while MCP security papers continue to focus on tool poisoning, prompt injection, descriptor trust, parameter visibility, credential handling, and call-time access control. | Keep MCP reserved and disabled. kAir should model MCP as a future provider family in an audit/evaluation contract, not as an auto-discovered runtime. |
| Apple public iOS surfaces | App Intents, Foundation Models, Core ML, and Core Location continue to push structured, user-visible, permissioned, local-first capabilities. Public APIs do not justify hidden universal app control. | Preserve the local-first iOS default. Provider traces may mention Apple/local capability families, but remote provider attempts remain policy gated and receipt-backed. |
| Google Maps/Places | Google Maps Platform policy/pricing separates SKU/capability behavior and constrains attribution, Terms/Privacy display, caching/storage, map/display use, and AI-summary disclosure. | Google is not a generic "maps provider switch." A future Google attempt needs an audit trace that records attribution/cache/privacy/source policy before any SDK/API integration. |
| Gaode/AMap | Gaode public pages expose account tiers, quota/QPS, paid traffic behavior, key setup, privacy/compliance, and terms constraints. | Gaode remains region/account/privacy gated. A future attempt needs explicit region, quota, QPS, privacy, and attribution policy fields before runtime. |
| Search API vendors | Brave, Exa, Tavily, Perplexity, and similar search providers differ on answer-vs-results surfaces, raw content, source URLs, citation/search-query billing, context retrieval, search depth, and pricing. | Do not pick a vendor endpoint next. Add a provider-neutral audit/evaluation trace that can represent cost class, source/citation policy, privacy class, latency/cost/evidence expectations, and rejection reasons. |
| Crawler legality | RFC 9309 remains the robots exclusion baseline, but crawler behavior also needs rate, retention, source, sandbox, privacy, and attribution policy beyond robots parsing. | Crawler stays behind Search API. Treat crawler as a disabled provider family whose audit trace can explain why it is reserved. |
| Competitor and market signals | Marvis-style mobile agents, Tencent Yuanbao/Hy3, and Meituan LongCat/life-service references raise user expectations for multi-step help, tool orchestration, visible sources, and cost-efficient execution. | kAir should adopt the UX expectation of traceable recommendations and handoff, but reject unsupported booking, payment, ordering, or hidden app-control claims. |

Sources rechecked for this A139 pass:

- Agent routing/evaluation and tool traces: https://arxiv.org/abs/2305.05176,
  https://arxiv.org/abs/2406.18665, https://arxiv.org/abs/2312.04511,
  https://arxiv.org/abs/2510.07429, https://arxiv.org/abs/2602.21227,
  https://arxiv.org/abs/2601.16725, https://arxiv.org/abs/2602.16855
- MCP specification/security: https://modelcontextprotocol.io/specification/2025-11-25,
  https://modelcontextprotocol.io/specification/2025-11-25/changelog,
  https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization,
  https://modelcontextprotocol.io/specification/2025-11-25/basic/security_best_practices,
  https://arxiv.org/abs/2503.23278, https://arxiv.org/abs/2504.03767,
  https://arxiv.org/abs/2512.03775, https://arxiv.org/abs/2604.05969,
  https://arxiv.org/abs/2605.18414
- Apple platform: https://developer.apple.com/documentation/appintents,
  https://developer.apple.com/documentation/foundationmodels/,
  https://developer.apple.com/documentation/coreml/downloading-and-compiling-a-model-on-the-user-s-device,
  https://developer.apple.com/documentation/corelocation/configuring-your-app-to-use-location-services
- Google Maps/Places: https://developers.google.com/maps/billing-and-pricing/march-2025,
  https://developers.google.com/maps/documentation/places/web-service/policies,
  https://cloud.google.com/maps-platform/terms,
  https://mapsplatform.google.com/pricing/
- Gaode/AMap: https://lbs.amap.com/pages/base_service_price,
  https://lbs.amap.com/upgrade,
  https://lbs.amap.com/api/webservice/create-project-and-key,
  https://lbs.amap.com/api/compliance-center/protocols/privacy_202410,
  https://lbs.amap.com/pages/terms/
- Search vendors: https://brave.com/search/api/,
  https://docs.tavily.com/documentation/api-reference/endpoint/search,
  https://exa.ai/pricing/api, https://exa.ai/docs/reference/contents-retrieval,
  https://docs.perplexity.ai/guides/pricing
- Competitor/life-service/mobile-agent signals:
  https://www.tencent.com/en-us/articles/2202320.html,
  https://tech.meituan.com/2026/01/20/longcat-flash-thinking-2601.html,
  https://appagent-official.github.io/, https://marvis-ai.com/
- Crawler policy: https://www.rfc-editor.org/rfc/rfc9309

### A139 Decision

Do **not** start live Search API transport, Google/Gaode SDK/API runtime,
crawler runtime, MCP client runtime, payment/booking/order runtime, remote
model runtime, or hidden app-control next.

The next safe implementation gate is:

**A140 External Provider Transport Audit Trace and Evaluation Contract Proof**

Why this outranks live provider runtime:

- A138 proves provider-status composition, but it does not create a durable
  audit artifact for a future provider attempt.
- Market and research signals keep emphasizing trace quality, cost/latency,
  safe tool invocation, recoverability, citations/sources, and user-visible
  receipts. Those properties should be typed before any network call.
- MCP, crawler, maps, and Search API all need different policy checks, but they
  can share one value-only audit/evaluation envelope.
- A future provider attempt must be explainable without exposing endpoint URLs,
  API keys, OAuth tokens, SDK/client handles, raw queries, raw pages, provider
  payloads, hidden app-control actions, payment/order data, or execution
  claims.

A140 should therefore add a pure value contract that can describe accepted and
rejected future provider attempts across Search API, Google/Gaode maps, crawler,
MCP, and remote model families. It should carry only audit-safe metadata:
provider family, capability, membership tier, cost class, privacy class,
source/citation/attribution policy summary, preflight/status source id, selected
status rank, expected evaluation dimensions, and deterministic rejection
reasons. It should not add runtime transport.

## 15. A149 Refresh After Live-Transport Readiness Composition

Current repo state from A148:

- The value-only Search API stack reaches readiness status and composes through
  `AppBootstrap(providerStatusSources:)` and ChatStore.
- First-source-wins order, hidden/missing nil lookup, and exact selected status
  copy are proven for readiness-first, earlier-stack-first, and fallback-first
  cases.
- Still absent by design: live Search API calls, vendor endpoint selection,
  URLSession, endpoint URLs, API keys, OAuth, SDK/client handles, Google/Gaode
  SDK/API calls, crawler runtime, MCP client/runtime, production AppBootstrap
  defaults, ChatStore behavior changes, SwiftUI provider UI, payment/booking/
  order flows, raw provider/page payloads, hidden app-control, and real provider
  execution.

### A149 evidence delta

| Evidence | Current public signal | A149 inference for kAir |
|---|---|---|
| Agent architecture and memory papers | 2026 agent surveys continue to split agents into state/perception, reasoning/planning, memory, tool/action, collaboration, and evaluation. Memory surveys treat write/manage/read, privacy, contradiction, and latency as separate problems. | kAir's typed draft -> policy -> adapter -> receipt -> status stack remains aligned. The next gap is a typed vendor-selection policy, not live execution. |
| MCP security and access control | MCP threat modeling highlights poisoned tool metadata and external-data risk; ABAC-style MCP proxy work argues for hiding unauthorized tools during discovery and blocking again at invocation. | MCP remains reserved. A Search API vendor selector should mirror the same descriptor-filter/call-time-gate principle before any MCP client is considered. |
| Open-source agent frameworks | LangGraph, AutoGen, and CrewAI all model execution as graph/agent orchestration with persistence, tools, memory, tracing, HITL, testing, or MCP extensions. | Borrow the separation of planning, tools, state, and observability; do not import a framework runtime before kAir's own provider contracts are value-proven. |
| Tencent Yuanbao/Hy3 | Public Tencent material emphasizes product integration, real-world evaluation, cost-efficient inference, long workflows, search execution, and MCP orchestration. | Market pressure favors long tasks and tool traces, but kAir should compete through visible receipts, cost policy, and local-first control. |
| Meituan LongCat | LongCat material emphasizes agentic search, tool use, random complex tasks, noisy tool environments, and open deployment. | Life-service quality depends on robust search/tool traces and recovery. kAir should keep read-only search/compare/open/save before writes. |
| Tencent Marvis | Public Marvis positioning emphasizes local/端云协同, privacy for local files, remote takeover visibility, local knowledge, and system-setting actions. | kAir can adopt the expectation of transparent local/remote status, but should keep iOS actions public/API-owned and avoid hidden takeover. |
| Search providers | Brave, Tavily, Exa, and Perplexity differ on plan tiers, answer vs search products, QPS, citations, raw content, search depth, context size, reasoning/search-query token billing, livecrawl behavior, and retention posture. | A150 must normalize vendor candidates and cost units before a live Search API adapter can be chosen. |
| Google/Gaode maps | Google has SKU categories, Places policies, attribution/cache/Terms requirements, and Maps Grounding Lite as an MCP-oriented offering; Gaode publishes quota/QPS/pricing and privacy/compliance surfaces. | Map upgrades should not precede Search API vendor-selection proof. Google/Gaode need the same region, membership, quota, attribution, cache, and privacy fields later. |
| Crawler policy | RFC 9309 remains only a robots baseline; crawler output is untrusted content with rate, retention, sandbox, and attribution risks. | Crawler stays later than Search API vendor selection. |

Sources rechecked for this A149 pass:

- Agent architecture and memory: https://arxiv.org/abs/2601.12560,
  https://arxiv.org/abs/2603.07670
- MCP security/access control: https://arxiv.org/abs/2603.22489,
  https://arxiv.org/abs/2605.18414,
  https://modelcontextprotocol.io/specification/2025-11-25/changelog,
  https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization
- Open-source architecture references:
  https://docs.langchain.com/oss/python/langgraph/overview,
  https://microsoft.github.io/autogen/stable/,
  https://docs.crewai.com/en/introduction,
  https://openai.github.io/openai-agents-python/,
  IEEE Access DOI 10.1109/ACCESS.2026.3683900
- Competitor/market references:
  https://www.tencent.com/en-us/articles/2202320.html,
  https://tech.meituan.com/2026/01/20/longcat-flash-thinking-2601.html,
  https://marvis.qq.com/
- Search vendors:
  https://brave.com/search/api/,
  https://docs.tavily.com/documentation/api-reference/endpoint/search,
  https://exa.ai/pricing,
  https://docs.perplexity.ai/docs/getting-started/pricing
- Maps providers and crawler policy:
  https://developers.google.com/maps/billing-and-pricing/march-2025,
  https://developers.google.com/maps/documentation/places/web-service/policies,
  https://mapsplatform.google.com/pricing/,
  https://lbs.amap.com/pages/base_service_price,
  https://lbs.amap.com/api/compliance-center/protocols/privacy_202410,
  https://www.rfc-editor.org/rfc/rfc9309

### A149 decision

Do **not** start live Search API transport in A150.

The next safe implementation gate is:

**A150 Search API Live Vendor Candidate Selection and Cost Policy Matrix Proof**

Why this outranks live provider runtime:

- A148 proves the provider-status side channel and readiness composition, but it
  does not decide which vendor candidate is safe to attempt under mutable
  pricing, quota, QPS, source/citation, raw-content, retention, region, and
  latency constraints.
- Search providers expose different cost units and result semantics. A live
  adapter selected from only `providerFamily == .searchAPI` would either hide
  cost/policy decisions or leak vendor-specific detail into UI.
- Google/Gaode membership routing will need the same idea later: a candidate
  selection decision that can reject provider families before any key, SDK,
  endpoint, or live request exists.
- MCP and crawler are more adversarial. The selector should reserve them as
  disabled families, not make them runtime alternatives.

### A150 comment-programming frame

Allowed implementation files for A150:

- `kAir/Core/Networking/ServerProviderSearchAPILiveVendorSelection.swift`
- `kAirTests/Networking/ServerProviderSearchAPILiveVendorSelectionTests.swift`
- `Docs/architecture/kair-provider-routing-mcp-search-v1.md`
- `Docs/architecture/kair-next-agent-prompts-v1.md`
- `Docs/architecture/kair-agent-market-fit-audit-v1.md`

A150 should add pure value contracts only:

- `ServerProviderSearchAPILiveVendorCandidate`: id, display name, provider
  family, capability, supported result shapes, freshness, citation/source
  support, raw-content mode, retention level, cost unit, estimated unit price,
  quota/QPS class, allowed regions, latency class, answer-generation support,
  and disabled/reason fields.
- `ServerProviderSearchAPILiveVendorSelectionRequest`: desired capability,
  result shape, freshness, privacy class, cost class, membership tier, region,
  source/citation policy, max unit price, quota snapshot, and user-facing
  purpose.
- `ServerProviderSearchAPILiveVendorSelectionDecision`: selected/rejected state,
  selected candidate id, ordered safe candidate summaries, deterministic
  rejection reasons, and UI-safe status copy.

Acceptance for A150:

- Tests prove candidate acceptance only when capability, freshness, result
  shape, citation/source support, raw-content/retention policy, privacy class,
  region, quota/QPS, and max cost all pass.
- Tests prove disabled vendor, over-budget, missing citation/source support,
  raw-content policy mismatch, unsupported region, privacy/Health block,
  unsupported freshness/result shape, missing quota, and duplicate candidate ids
  reject deterministically or keep first valid candidate.
- Encoded/debug/status copy contains no endpoint URL, API key, OAuth token,
  SDK/client handle, URLSession, raw query, raw page/provider payload, crawler/
  MCP runtime detail, maps SDK detail, payment/booking/order data, hidden
  app-control action, or execution/completion claim.
- A150 does not change AppBootstrap defaults, ChatStore behavior, SwiftUI,
  URLSession/networking, provider runtime, StoreKit, crawler, MCP client,
  Google/Gaode SDK, memory, telemetry, transcript, payment, booking, order, or
  real provider behavior.

## 16. A154 Refresh After Live Vendor Selection Cross-Stage Composition

A150-A153 closed the live-vendor selection status stack that A149 selected:
vendor candidates can be selected/rejected as value-only metadata, packaged into
rendered-id scoped provider status, handed through `AppBootstrap`, and composed
with metered entitlement, vendor policy, dispatch, authorization, lease,
request, response, preflight, audit, and fallback sources without stale detail
mixing.

Current repo state at this refresh:

- Done: Search API vendor candidate selection, vendor-selection status source,
  app-root handoff, and cross-stage first-source-wins composition.
- Still absent by design: live Search API URLSession calls, endpoint URLs, API
  keys, OAuth tokens, SDK/client handles, Google/Gaode SDK/API calls, crawler
  runtime, MCP client/runtime, StoreKit/payment, booking/order runtime,
  production AppBootstrap defaults, ChatStore production behavior, SwiftUI
  provider UI, raw query/page/provider payload ingestion, hidden third-party app
  control, and real provider execution.
- Existing code already has a generic metadata-only connector boundary and an
  A144 Search API live-transport planning boundary. The remaining gap is not
  status rendering; it is a provider-specific **server adapter interface**
  contract that can prove what a future Search API remote hop would be allowed
  to receive and return before any network client exists.

### A154 Evidence Delta

| Area | Current public signal | A154 inference for kAir |
|---|---|---|
| Agent orchestration frameworks | LangGraph emphasizes durable execution, persistence, HITL, memory, tracing, and observability; OpenAI Agents SDK exposes agents, handoffs, guardrails, tools, MCP integration, sessions, HITL, tracing, and sandbox agents; AutoGen separates AgentChat/Core/Extensions; CrewAI separates Flows from autonomous Crews; smolagents supports code agents but requires sandbox execution for safety. | kAir should keep its own typed plan -> policy -> adapter -> receipt chain. Borrow graph/state/trace patterns, but do not import a framework runtime or let model-generated code/tool calls bypass Swift value gates. |
| Cost-aware and compiled tool dispatch | RouteLLM frames model choice as a performance/cost tradeoff; LLMCompiler turns tool calls into a planned DAG with parallel dispatch, latency improvement, and cost savings. | A155 should expose a typed server adapter interface that consumes accepted vendor/cost/lease/request metadata. It should not hide provider choice inside a runtime call. |
| Mobile/GUI agents | Mobile-Agent-v3.5/GUI-Owl-1.5 targets desktop/mobile/browser GUI environments and reports GUI automation, grounding, OSWorld/WebArena, tool/MCP, memory, and multi-agent benchmarks. | Use GUI-agent research for evaluation and UI test ideas only. Production kAir should stay on App Intents, public APIs, typed adapters, and visible receipts, not hidden cross-app tapping. |
| Tencent Yuanbao / Hy3 | Tencent says Hy3 is integrated into Yuanbao and related products, supports long-context, tool use, authentic evaluation, product co-design, cost efficiency, MCP orchestration, search execution, and complex workflows up to 495 steps. | kAir should compete on reliable workflow state, transparent receipts, and cost-aware routing. Long workflows require durable traces and interruption/resume state before real execution claims. |
| Meituan LongCat / life-service agents | LongCat-Flash-Thinking-2601 emphasizes agentic search, tool use, tool-integrated reasoning, random complex tool tasks, noisy real-world environments, and strong open-source benchmark results. | Life-service quality depends on robust search/tool traces and failure handling. kAir should keep read-only search/compare/open/save first; booking/order/payment needs partner receipts and confirmation gates later. |
| Marvis-style local/remote assistant UX | Tencent Marvis publicly positions local model mode with zero file upload, cloud/local switching, remote task takeover visibility, file search/organization, system-setting help, and multi-device control. | Adopt the UX expectation of visible local/remote mode and takeover/confirmation affordances. Reject hidden iOS app control; kAir should expose provider status, consent, and receipts. |
| MCP spec and security | MCP 2025-11-25 adds authorization discovery, incremental scope consent, icons metadata, elicitation updates, tool calling in sampling, OAuth client metadata, and experimental durable tasks. Security guidance flags confused-deputy, token passthrough, SSRF, session hijack, local server compromise, and scope minimization. | MCP remains disabled by default. Future MCP reservation must filter discovery, bind per-client consent/scopes, avoid token passthrough, block SSRF-style metadata fetches, and re-check at invocation. |
| Search API vendors | Brave separates Search and Answers with different QPS/cost/grounding; Tavily exposes `search_depth`, `include_answer`, `include_raw_content`, country boost, usage credits, and latency/relevance tradeoffs; Exa separates Search, Deep Search, Agent, Contents, monitors, livecrawl policies, endpoint pricing, and ZDR enterprise terms; Perplexity separates raw Search API request pricing from Sonar token/request/search-context/citation/search-query costs. | A155 cannot pick one provider by enum alone. The adapter interface needs cost unit, search depth/context class, raw-content mode, citation/source guarantee, retention policy, rate/QPS class, and vendor id as typed metadata. |
| Maps providers | Google Maps Platform pricing now uses Essentials/Pro/Enterprise categories and SKU free caps; Places policy requires Terms/Privacy, caching limits, Google Maps attribution, map/display constraints, and third-party attribution. Google also lists Maps Grounding Lite as an MCP-oriented fresh Maps data surface. Gaode publishes account-tier quota/QPS for base LBS services. | Google/Gaode remain later provider-specific adapters. Membership-based map upgrades need region, consent, attribution, caching/display, quota/QPS, and server-key policy before SDK/API runtime. |
| Crawler policy | RFC 9309 defines robots.txt access behavior and says robots rules are not access authorization. Crawler implementations must also treat robots content as untrusted. | Crawler remains behind Search API. A later crawler gate needs robots/source/rate/retention/sandbox/audit in addition to the same adapter-interface pattern. |

Sources rechecked for this A154 pass:

- Agent frameworks and orchestration:
  https://docs.langchain.com/oss/python/langgraph/overview,
  https://openai.github.io/openai-agents-python/,
  https://microsoft.github.io/autogen/stable/,
  https://docs.crewai.com/en/introduction,
  https://huggingface.co/docs/smolagents/index
- Cost/tool dispatch papers:
  https://arxiv.org/abs/2406.18665,
  https://arxiv.org/abs/2312.04511
- Mobile/life-service/competitor signals:
  https://arxiv.org/abs/2602.16855,
  https://www.tencent.com/en-us/articles/2202320.html,
  https://tech.meituan.com/2026/01/20/longcat-flash-thinking-2601.html,
  https://arxiv.org/abs/2601.16725,
  https://marvis.qq.com/
- MCP specification and security:
  https://modelcontextprotocol.io/specification/2025-11-25/changelog,
  https://modelcontextprotocol.io/specification/2025-11-25/basic/security_best_practices
- Apple local/public iOS surfaces:
  https://developer.apple.com/documentation/appintents,
  https://developer.apple.com/documentation/foundationmodels/,
  https://developer.apple.com/documentation/corelocation/configuring-your-app-to-use-location-services
- Search vendors:
  https://brave.com/search/api/,
  https://docs.tavily.com/documentation/api-reference/endpoint/search,
  https://exa.ai/pricing/api,
  https://exa.ai/docs/reference/contents-retrieval,
  https://docs.perplexity.ai/guides/pricing
- Maps providers and crawler policy:
  https://developers.google.com/maps/billing-and-pricing/march-2025,
  https://developers.google.com/maps/documentation/places/web-service/policies,
  https://mapsplatform.google.com/pricing/,
  https://lbs.amap.com/pages/base_service_price,
  https://www.rfc-editor.org/rfc/rfc9309

### A154 Decision

A155 can start a **narrow live-transport proof**, but only as comment-programming
and a value-only server adapter interface. It must not introduce URLSession,
endpoint URLs, credentials, OAuth, SDK/client handles, live provider calls,
production AppBootstrap defaults, ChatStore behavior, SwiftUI provider UI,
crawler/MCP runtime, Google/Gaode SDKs, payment/booking/order runtime, raw
payload ingestion, hidden app-control, or execution/completion claims.

The next safe implementation gate is:

**A155 Search API Live Transport Server Adapter Interface Comment-Programming
Proof**

Why this is the right next gate:

- A153 proves provider status composition; it does not prove what a future
  server adapter is allowed to receive, reject, or return.
- Existing generic metadata-only connectors are provider-family wide. Search
  API now needs a provider-specific interface that binds A150 vendor selection,
  A117 metered entitlement, A122 lease, A126 request, A131 response-receipt
  rules, A140 audit, A144 boundary readiness, and A153 status composition.
- Search vendors differ in result/answer shape, cost unit, search depth/context,
  raw content, citation/source guarantees, retention, and QPS. The interface
  must encode those as value metadata before any vendor implementation.
- Google/Gaode, crawler, and MCP can reuse the same pattern later: server-owned
  adapter interface first, runtime client only after policy, audit, and
  status-safe copy are proven.

### A155 Comment-Programming Frame

Allowed implementation files for A155:

- `kAir/Core/Networking/ServerProviderSearchAPILiveTransportAdapterInterface.swift`
- `kAirTests/Networking/ServerProviderSearchAPILiveTransportAdapterInterfaceTests.swift`
- `Docs/architecture/kair-provider-routing-mcp-search-v1.md`
- `Docs/architecture/kair-next-agent-prompts-v1.md`
- `Docs/architecture/kair-agent-market-fit-audit-v1.md`

A155 should add pure value/comment-programming contracts only:

- `ServerProviderSearchAPILiveTransportAdapterDescriptor`: adapter id, vendor id,
  provider family, capability, supported result shapes/freshness, cost unit,
  search depth/context class, raw-content mode, retention class, citation/source
  support, QPS/rate class, region set, kill-switch id, retry policy id, and
  server-owned secret mode.
- `ServerProviderSearchAPILiveTransportAdapterInterfaceRequest`: selected A150
  vendor decision id, metered decision id, lease id, transport request id,
  audit trace id, boundary id, expected result shape/freshness/cost class,
  privacy class, source/citation/attribution requirements, and user-facing
  purpose. It must not carry raw query text or page/provider payload.
- `ServerProviderSearchAPILiveTransportAdapterInterfaceDecision`: accepted or
  rejected metadata-only state, deterministic rejection reason, safe descriptor
  summary, and `isRuntimeCallable == false`.
- Rejection reasons: provider family mismatch, vendor mismatch, unsupported
  capability/result shape/freshness, cost unit mismatch, raw-content policy
  conflict, retention conflict, missing citation/source support, region blocked,
  quota/QPS class unavailable, kill switch active, missing upstream id,
  privacy/Health blocked, stale boundary/readiness, and server secret mode not
  server-owned.

Acceptance for A155:

- Tests prove only a matching Search API descriptor and matching upstream ids can
  create an accepted interface decision.
- Tests prove every mismatch/rejection reason is deterministic and value-only.
- Tests prove duplicate descriptors keep first-wins or reject deterministically
  according to the local pattern.
- Encoded/debug/status copy contains no endpoint URL, API key, OAuth token,
  bearer token, credential, URLSession, URLRequest, SDK/client handle, raw query,
  raw page/provider payload, StoreKit/payment/order/booking data, crawler/MCP
  runtime detail, maps SDK detail, hidden app-control, provider call, or
  execution/completion claim.
- A155 does not change production AppBootstrap defaults, ChatStore behavior,
  SwiftUI/UI, navigation, telemetry, memory writes, transcript mutation,
  URLSession/networking, crawler/MCP client, Google/Gaode SDK, StoreKit/payment,
  booking/order, remote model runtime, or real provider behavior.

## 17. A159 Refresh After Adapter Interface Status Composition

A155-A158 closed the Search API live-transport adapter-interface status stack:
a metadata-only adapter interface can accept/reject descriptors, project the
decision into rendered-id scoped provider status, pass through `AppBootstrap`,
and compose with the existing Search API status stack without stale detail
mixing.

Current repo state at this refresh:

- Done: Search API vendor selection, readiness, metered entitlement, vendor
  policy, dispatch authorization, lease, request, response, preflight, audit,
  fallback, adapter interface, adapter-interface status projection, app-root
  handoff, and cross-stage status composition.
- Still absent by design: URLSession calls, endpoint URLs, API keys, OAuth,
  SDK/client handles, production provider runtime, crawler/MCP runtime,
  Google/Gaode SDK/API calls, StoreKit/payment, booking/order runtime, raw
  query/page/provider payload ingestion, hidden app control, and execution
  claims.
- The remaining gap is not status copy. The next useful gap is a server-side
  **invocation preflight** contract that proves an accepted adapter interface
  can be joined with upstream vendor, cost, lease, request, boundary, and audit
  decisions before any live transport is callable.

### A159 Evidence Delta

| Area | Current public signal | A159 inference for kAir |
|---|---|---|
| Agent orchestration frameworks | LangGraph emphasizes durable long-running state, persistence, HITL, memory, tracing, evaluation, and deployment; OpenAI Agents SDK exposes agents, handoffs, guardrails, MCP, sessions, HITL, tracing, and sandbox agents; AutoGen, CrewAI, and smolagents keep tool/runtime concerns separated from orchestration. | Keep kAir's own typed Swift plan -> policy -> adapter -> receipt chain. Borrow durable traces, resumable state, and guardrail vocabulary, but do not import an agent runtime or let model-generated tool calls bypass value gates. |
| Cost-aware tool routing papers | Switchcraft was submitted on 2026-05-08 and routes agentic tool-calling workloads to lower-cost models while preserving correctness; Budget-Constrained Agentic LLMs formalizes strict monetary budgets with stochastic tool execution and hard budget feasibility; RouteLLM and LLMCompiler continue to support model/tool routing and parallel tool planning as cost/latency controls. | A160 should bind each invocation attempt to a budget snapshot, selected vendor, cost unit, search context, and non-callable preflight receipt. Cost must stay a hard precondition, not UI copy added after planning. |
| Agent training and observability | Agent Lightning decouples agent execution from RL training through a unified trace interface and training-agent disaggregation. | kAir should keep preflight/audit records structured enough to evaluate future live-provider attempts without coupling production code to a training framework. |
| Product/UI market signals | Marvis advertises local mode with zero file upload, local/remote switching, remote takeover visibility, and local file search; Tencent Hy3/Yuanbao public material emphasizes product integration, search execution, MCP toolchain orchestration, long workflows up to 495 steps, and cost-efficient inference; Meituan LongCat emphasizes agentic search, tool use, noisy tool environments, and multi-environment RL. | kAir's UI should surface local/remote/provider mode and receipts before action. Life-service strength comes from searchable, cited, failure-tolerant traces, not hidden app takeover or write-side booking/payment. |
| MCP and crawler policy | The 2025-11-25 MCP spec remains the current final spec as of 2026-06-01, while a 2026-07-28 release candidate is public. The final spec adds stronger authorization discovery, incremental scope consent, tool/resource metadata, and experimental tasks. MCP security guidance highlights confused deputy, token passthrough, SSRF, session hijacking, local server compromise, and scope minimization. RFC 9309 still says robots rules are not access authorization and robots content is untrusted. | MCP/crawler stay disabled by default. A160 should not create MCP or crawler clients; it should reserve source, attribution, retention, and SSRF-safe server preflight fields for later gates. |
| Search API vendors | Brave separates Search and Answers, with different request/token pricing and QPS; Tavily exposes `search_depth`, `include_answer`, `include_raw_content`, `include_usage`, country/topic/time controls, and credit usage; Exa separates Search, Deep Search, Agent, Contents, Monitors, livecrawl policies, endpoint pricing, and ZDR enterprise options; Perplexity separates Search API request pricing from Sonar model/tool/search-context pricing. | A160 must not assume a single "search request" shape. The preflight should include vendor id, result shape, search context/depth, raw-content mode, source/citation/attribution requirement, retention class, QPS/rate class, and cost unit. |
| Maps providers | Google Maps Platform is on Essentials/Pro/Enterprise SKU categories with per-SKU free calls and Places attribution/caching/display requirements. Gaode publishes quota/QPS by certification tier for routing, geocoding, search, and location services. Apple App Intents/Core Location keep iOS paths public, consented, and local-first. | Google/Gaode map upgrades remain later provider adapters. Membership packages need the same preflight vocabulary: entitlement, region, quota/QPS, attribution, cache/display policy, and server-owned keys before any SDK/API runtime. |

Sources rechecked for this A159 pass:

- Agent frameworks and orchestration:
  https://docs.langchain.com/oss/python/langgraph/overview,
  https://openai.github.io/openai-agents-python/,
  https://microsoft.github.io/autogen/stable/,
  https://docs.crewai.com/en/introduction,
  https://huggingface.co/docs/smolagents/index
- Cost, routing, and agent-training papers:
  https://arxiv.org/abs/2605.07112,
  https://arxiv.org/abs/2602.11541,
  https://arxiv.org/abs/2508.03680,
  https://arxiv.org/abs/2406.18665,
  https://arxiv.org/abs/2312.04511
- Mobile/life-service/competitor signals:
  https://marvis.qq.com/,
  https://www.tencent.com/en-us/articles/2202320.html,
  https://tech.meituan.com/2026/01/20/longcat-flash-thinking-2601.html
- MCP specification, release process, and security:
  https://modelcontextprotocol.io/specification/2025-11-25/changelog,
  https://modelcontextprotocol.io/specification/2025-11-25/basic/security_best_practices,
  https://blog.modelcontextprotocol.io/posts/
- Search vendors:
  https://brave.com/search/api/,
  https://docs.tavily.com/documentation/api-reference/endpoint/search,
  https://exa.ai/pricing/api,
  https://docs.perplexity.ai/guides/pricing
- Maps providers and crawler policy:
  https://developers.google.com/maps/billing-and-pricing/march-2025,
  https://developers.google.com/maps/documentation/places/web-service/policies,
  https://mapsplatform.google.com/pricing/,
  https://lbs.amap.com/pages/base_service_price,
  https://www.rfc-editor.org/rfc/rfc9309

### A159 Decision

A160 can start a narrow server-side live-provider proof, but only as a
metadata-only **invocation preflight contract**. It must prove that all upstream
Search API decisions can be joined into one auditable, UI-safe, non-callable
preflight receipt. It must not introduce URLSession, endpoints, credentials,
OAuth, SDK/client handles, real provider calls, production AppBootstrap
defaults, ChatStore behavior, SwiftUI/UI, telemetry, transcript mutation,
memory writes, crawler/MCP runtime, Google/Gaode SDKs, StoreKit/payment,
booking/order runtime, hidden app control, raw provider payload ingestion, or
execution/completion claims.

The next safe implementation gate is:

**A160 Search API Live Provider Invocation Preflight Contract**

Why this follows from A158:

- A158 proves status composition and rendered-id safety; it does not prove that
  an accepted adapter interface can be joined with the selected vendor,
  entitlement, lease, request, boundary readiness, source policy, and audit
  trace as one server-owned preflight.
- Current vendor and paper evidence makes cost and tool correctness hard
  preconditions. A preflight receipt lets kAir reject stale budget, expired
  lease, mismatched vendor, missing attribution, blocked privacy, or unsupported
  region before any remote execution path exists.
- MCP/crawler/maps still need separate future adapters. A160 should reserve
  shared preflight vocabulary for source, retention, attribution, rate, region,
  and server-owned secret handling without enabling those families.

### A160 Comment-Programming Frame

Allowed implementation files for A160:

- `kAir/Core/Networking/ServerProviderSearchAPILiveProviderInvocationPreflight.swift`
- `kAirTests/Networking/ServerProviderSearchAPILiveProviderInvocationPreflightTests.swift`
- `Docs/architecture/kair-provider-routing-mcp-search-v1.md`
- `Docs/architecture/kair-next-agent-prompts-v1.md`
- `Docs/architecture/kair-agent-market-fit-audit-v1.md`

A160 should add pure value/comment-programming contracts only:

- `ServerProviderSearchAPILiveProviderInvocationPreflightInput`: accepted A155
  adapter-interface decision, selected descriptor id, selected A150 vendor
  decision id, A117/A118 metered decision id, A122 lease id, A126 transport
  request id, A140 audit trace id, A144/A145 boundary/readiness ids, expected
  provider family/capability/result shape/freshness/cost class/cost unit,
  search-context class, raw-content requirement, retention class, citation,
  source-host, attribution, region, membership tier, budget snapshot id, and
  user-facing purpose. It must not carry raw query text, endpoint URL, API key,
  token, or provider payload.
- `ServerProviderSearchAPILiveProviderInvocationPreflightDecision`: accepted or
  rejected metadata-only state, deterministic rejection reasons, safe summary,
  non-callable flag, and stable audit/preflight id.
- Rejection reasons: adapter interface not accepted, runtime callable flag true,
  provider family mismatch, vendor/descriptor mismatch, missing upstream id,
  metered decision mismatch, lease mismatch or expired lease, transport request
  mismatch, stale boundary/readiness, cost unit/class mismatch, missing budget
  snapshot, region blocked, privacy/Health blocked, source/citation/attribution
  missing, raw-content policy conflict, retention conflict, server secret mode
  not server-owned, unsupported maps/crawler/MCP family, and duplicate preflight
  id.

Acceptance for A160:

- Tests prove accepted preflight only when adapter interface, vendor decision,
  entitlement, lease, transport request, boundary/readiness, source policy,
  region, cost, and audit metadata all match.
- Tests prove every rejection reason is deterministic, value-only, and keeps
  first-wins or explicit duplicate-id rejection according to the local pattern.
- Tests prove `isRuntimeCallable` / equivalent remains false and encoded,
  debug, and status-safe copy contains no endpoint URL, API key, OAuth token,
  bearer token, credential, URLSession, URLRequest, SDK/client handle, raw
  query, raw page/provider payload, crawler/MCP runtime detail, maps SDK detail,
  StoreKit/payment/order/booking data, hidden app-control, provider call, or
  execution/completion claim.
- A160 does not change production AppBootstrap defaults, ChatStore behavior,
  SwiftUI/UI, navigation, telemetry, memory writes, transcript mutation,
  URLSession/networking, crawler/MCP client, Google/Gaode SDK, StoreKit/payment,
  booking/order, remote model runtime, or real provider behavior.

## 18. A164 Refresh After Invocation Preflight Composition

A160-A163 closed the current invocation-preflight status loop. kAir now has a
metadata-only live-provider preflight, status projection, app-root handoff, and
cross-stage first-source-wins proof against the existing Search API stack. The
proof is still intentionally non-callable.

Current repo state at this refresh:

- Done: Search API vendor policy, dispatch authorization, lease, request,
  response, external-provider audit, live-transport boundary, readiness,
  vendor selection, adapter interface, invocation preflight, status-source,
  app-root handoff, and cross-stage status composition.
- Still absent by design: URLSession calls, endpoint URLs, API keys, OAuth,
  SDK/client handles, production provider runtime, crawler/MCP runtime,
  Google/Gaode SDK/API calls, StoreKit/payment, booking/order runtime, raw
  query/page/provider payload ingestion, hidden app control, and execution
  claims.
- The remaining gap is no longer "can preflight state be shown." The next
  useful gap is an auditable server-owned invocation **envelope contract** that
  packages an accepted preflight into a prepared-only provider attempt shape
  without enabling a provider call.

Sources rechecked for this A164 pass on 2026-06-01:

- Agent frameworks and orchestration:
  https://docs.langchain.com/oss/python/langgraph/overview,
  https://openai.github.io/openai-agents-python/,
  https://microsoft.github.io/autogen/stable/,
  https://docs.crewai.com/en/introduction,
  https://huggingface.co/docs/smolagents/index
- Agent architecture, cost, and trace papers:
  https://arxiv.org/abs/2601.12560,
  https://arxiv.org/abs/2504.19678,
  https://arxiv.org/abs/2603.07670,
  https://arxiv.org/abs/2602.11541,
  https://arxiv.org/abs/2605.07112,
  https://arxiv.org/abs/2508.03680,
  https://arxiv.org/abs/2406.18665,
  https://arxiv.org/abs/2312.04511
- Market and UI signals:
  https://marvis.qq.com/,
  https://www.tencent.com/en-us/articles/2202320.html,
  https://tech.meituan.com/2026/01/20/longcat-flash-thinking-2601.html
- MCP specification and security:
  https://modelcontextprotocol.io/specification/2025-11-25/changelog,
  https://modelcontextprotocol.io/specification/2025-11-25/basic/security_best_practices,
  https://arxiv.org/abs/2603.22489,
  https://arxiv.org/abs/2605.18414
- Apple local-first surfaces:
  https://developer.apple.com/documentation/appintents,
  https://developer.apple.com/documentation/foundationmodels/,
  https://developer.apple.com/documentation/corelocation/configuring-your-app-to-use-location-services
- Search, maps, and crawler providers:
  https://brave.com/search/api/,
  https://docs.tavily.com/documentation/api-reference/endpoint/search,
  https://exa.ai/pricing,
  https://docs.perplexity.ai/guides/pricing,
  https://developers.google.com/maps/billing-and-pricing/march-2025,
  https://developers.google.com/maps/documentation/places/web-service/policies,
  https://mapsplatform.google.com/pricing/,
  https://lbs.amap.com/pages/base_service_price,
  https://lbs.amap.com/api/compliance-center/protocols/privacy_202410,
  https://www.rfc-editor.org/rfc/rfc9309

### A164 Evidence Delta

| Area | Current public signal | A164 inference for kAir |
|---|---|---|
| Agent frameworks | LangGraph, OpenAI Agents SDK, AutoGen, CrewAI, and smolagents all keep orchestration, tool wiring, memory/state, tracing, and HITL as explicit framework concerns rather than invisible model text. | Continue kAir's typed Swift chain. Do not swap in a generic agent runtime. Use the next gate to make a future provider attempt auditable before execution. |
| Cost-aware routing | Budgeted-agent, RouteLLM, LLMCompiler, and newer tool-routing work keep cost, quality, latency, and tool choice as planning variables. | The next contract must carry cost unit, budget snapshot, entitlement, rate/quota class, and selected vendor id inside the attempt envelope, not only status copy. |
| Agent traces and training | Agent Lightning-style work decouples execution traces from training and analysis. | A165 should create an envelope that can later become evaluation input without coupling kAir to a training stack or logging raw provider payloads. |
| Market/product UX | Marvis-style assistants, Tencent Hy3/Yuanbao, and Meituan LongCat all raise expectations for local/remote mode clarity, long tool workflows, search/tool robustness, and product-specific evaluation. | kAir should surface provider mode, source, freshness, cost, and pending/blocked state. It should not claim booking, payment, third-party app completion, or hidden remote takeover. |
| MCP/crawler | MCP's current spec and security guidance reinforce authorization discovery, scope minimization, token protection, SSRF defenses, local-server risk, and call-time authorization. RFC 9309 remains crawler policy input, not authorization. | Keep MCP/crawler disabled. Reserve envelope fields for source policy, retention, attribution, SSRF posture, and descriptor family, but do not create runtime clients. |
| Apple local-first | App Intents, Foundation Models, and Core Location keep iOS actions structured, user-consented, and availability/permission-sensitive. | The default route stays local/iOS-owned. Provider envelopes must not imply that Apple surfaces or location consent have been bypassed. |
| Search APIs | Brave, Tavily, Exa, and Perplexity still differ on request-vs-answer pricing, raw-content controls, search depth/context, citations, QPS, retention, and agent/search products. | A165 must avoid a single "search call" assumption. It should describe provider family, capability, result shape, citation/source requirements, raw-content policy, retention class, and cost unit. |
| Maps providers | Google Maps uses SKU, attribution, caching/display, and Terms/Privacy constraints; Gaode publishes quota/QPS and privacy/compliance obligations. | Google/Gaode remain future server-mediated provider adapters. Membership packages need region, attribution, quota/QPS, cache/display, privacy, and server-owned-key fields before runtime. |

### A164 Decision

Live provider execution remains blocked. A163 proves the preflight can be
shown and composed, but it does not prove that a future server call would be
packaged with immutable attempt metadata, expiry, source/citation policy,
retention, region, budget, and audit ids before any adapter is allowed to run.

The next safe implementation gate is:

**A165 Search API Live Provider Invocation Envelope Contract**

Why A165, not URLSession or a real vendor adapter:

- The public provider evidence still changes along cost, attribution, raw
  content, retention, region, and rate limits. kAir needs a frozen attempt
  envelope before a transport implementation can be reviewed safely.
- MCP/crawler/maps remain separate provider families. A165 can reserve their
  common policy vocabulary without enabling those runtimes.
- The UI/product need is "prepared, blocked, or ready under policy" rather
  than "provider completed." An envelope lets the shell/status layer stay
  honest about no execution.

### A165 Comment-Programming Frame

Allowed implementation files for A165:

- `kAir/Core/Networking/ServerProviderSearchAPILiveProviderInvocationEnvelope.swift`
- `kAirTests/Networking/ServerProviderSearchAPILiveProviderInvocationEnvelopeTests.swift`
- `Docs/architecture/kair-provider-routing-mcp-search-v1.md`
- `Docs/architecture/kair-next-agent-prompts-v1.md`
- `Docs/architecture/kair-agent-market-fit-audit-v1.md`

A165 should add pure value/comment-programming contracts only:

- `ServerProviderSearchAPILiveProviderInvocationEnvelopeInput`: accepted A160
  preflight id and summary, selected vendor/adapter ids, provider family,
  capability, result shape, freshness class, search-context class, raw-content
  policy, citation/source/attribution requirements, retention class, region,
  membership tier, budget snapshot id, cost unit, quota/rate class, transport
  lease id, request id, audit trace id, server-secret mode, expiry, redaction
  policy, and user-facing purpose. It must not carry raw query text, endpoint
  URL, API key, token, credential, provider payload, map SDK detail, MCP
  descriptor text, crawler payload, payment/order data, or hidden app-control
  state.
- `ServerProviderSearchAPILiveProviderInvocationEnvelopeDecision`: prepared or
  rejected metadata-only state, deterministic rejection reasons, stable
  envelope id, expiry, safe debug summary, safe status summary, and a pinned
  non-executable flag.
- Rejection reasons: preflight not accepted, stale or expired preflight,
  descriptor/vendor/adapter mismatch, provider family mismatch, missing or
  mismatched budget snapshot, cost unit mismatch, missing lease/request/audit
  id, duplicate envelope id, unsafe retention/source/citation/attribution
  policy, unsupported region, client-owned secret mode, runtime callable flag
  true, executable flag true, unsupported maps/crawler/MCP family, payment or
  booking field present, raw payload present, and hidden app-control field
  present.

Acceptance for A165:

- Tests prove a prepared envelope only when the accepted preflight and all
  upstream ids, policy classes, cost fields, region, retention, source/citation
  requirements, lease/request/audit metadata, and server-secret mode match.
- Tests prove rejected envelopes are deterministic and that duplicate ids are
  rejected or first-wins according to the local pattern chosen in the test.
- Tests prove the envelope remains prepared-only: `isExecutable` and
  `isRuntimeCallable` stay false, with no completion/provider-call claim.
- Encoded, debug, and status-safe copy contains no endpoint URL, API key,
  OAuth token, bearer token, credential, URLSession, URLRequest, SDK/client
  handle, raw query, raw page/provider payload, crawler/MCP runtime detail,
  maps SDK detail, StoreKit/payment/order/booking data, hidden app-control,
  provider call, or execution/completion claim.
- A165 does not change production AppBootstrap defaults, ChatStore behavior,
  SwiftUI/UI, navigation, telemetry, memory writes, transcript mutation,
  URLSession/networking, crawler/MCP client, Google/Gaode SDK, StoreKit/payment,
  booking/order, remote model runtime, or real provider behavior.

## 19. A175 Refresh After Routing Status Stack Composition

A165-A174 filled the prepared-envelope, envelope status-source, app-root
handoff, provider-status-stack plan, cost/membership routing plan, routing
decision, routing-decision status-source, root handoff, and full status-stack
composition gaps. The Search API stack can now prove first-wins source order
for routing status and the existing provider-status stack through
`AppBootstrap(providerStatusSources:)` and `ChatStore` lookup.

That is still not enough to start runtime. A174 proves selection order and copy
equality. It does not prove that a cost/membership route is semantically
compatible with later vendor-policy, payload-dispatch, dispatch-authorization,
transport-lease, entitlement, or fallback decisions.

Sources rechecked for this A175 pass on 2026-06-01:

- Agent frameworks and UI surfaces:
  https://docs.langchain.com/oss/python/langgraph/overview,
  https://openai.github.io/openai-agents-python/,
  https://microsoft.github.io/autogen/stable/,
  https://docs.crewai.com/en/introduction,
  https://huggingface.co/docs/smolagents/index,
  https://developers.openai.com/apps-sdk/concepts/ui-guidelines
- Agent cost, routing, planning, and trace papers:
  https://arxiv.org/abs/2305.05176,
  https://arxiv.org/abs/2406.18665,
  https://arxiv.org/abs/2312.04511,
  https://arxiv.org/abs/2601.12560,
  https://arxiv.org/abs/2603.07670,
  https://arxiv.org/abs/2605.07112
- MCP and tool-security evidence:
  https://modelcontextprotocol.io/specification/2025-11-25/changelog,
  https://modelcontextprotocol.io/specification/2025-11-25/basic/security_best_practices,
  https://arxiv.org/abs/2603.22489,
  https://arxiv.org/abs/2605.18414,
  https://arxiv.org/abs/2604.05969
- Market and local-life signals:
  https://marvis.qq.com/,
  https://www.tencent.com/en-us/articles/2202320.html,
  https://tech.meituan.com/2026/01/20/longcat-flash-thinking-2601.html
- Search API providers:
  https://brave.com/search/api/,
  https://docs.tavily.com/documentation/api-reference/endpoint/search,
  https://exa.ai/pricing,
  https://docs.perplexity.ai/guides/pricing
- Maps, crawler, and Apple local-first providers:
  https://developers.google.com/maps/billing-and-pricing/march-2025,
  https://developers.google.com/maps/documentation/places/web-service/policies,
  https://mapsplatform.google.com/pricing/,
  https://lbs.amap.com/pages/base_service_price,
  https://lbs.amap.com/api/compliance-center/protocols/privacy_202410,
  https://www.rfc-editor.org/rfc/rfc9309,
  https://developer.apple.com/documentation/appintents,
  https://developer.apple.com/documentation/foundationmodels/,
  https://developer.apple.com/documentation/corelocation/configuring-your-app-to-use-location-services

### A175 Decision Matrix

| Topic | Adopt now | Monitor | Reject for A176 |
|---|---|---|---|
| Agent architecture | Keep typed value gates for plan, routing, provider policy, status, and audit. Add one more semantic compatibility proof before runtime. | Durable graph runtimes, session memory, hosted tracing, and HITL patterns from LangGraph, OpenAI Agents SDK, AutoGen, CrewAI, and smolagents. | Replacing kAir's Swift gate stack with a generic agent runtime or hidden tool loop. |
| UI and market trust | Keep visible provider mode, cost/membership posture, source/freshness, blocked state, and user receipt constraints. | Marvis-style local/remote controls and Yuanbao/LongCat long-workflow expectations. | Claiming booking, payment, third-party action, remote app takeover, or provider completion without a receipt. |
| Cost and routing papers | Treat cost, quota, latency, tool choice, and traceability as first-class routing variables. | Learned routers and compiler-style parallel tool plans after deterministic policy gates exist. | A single "best provider" path that ignores membership, cost unit, entitlement, or stale lower-priority markers. |
| Search API providers | Preserve vendor differences in pricing unit, raw-content policy, search context, citations, QPS, retention, and answer-vs-result shape. | Server adapters after route-to-policy compatibility is proven. | URLSession, endpoint URLs, API keys, OAuth, SDK/client handles, or provider calls in A176. |
| Maps and local life | Keep Apple/local-first defaults and model Google/Gaode as later server-mediated provider families with region, attribution, cache, privacy, quota, and QPS fields. | Google Maps Grounding and AMap-style provider candidates behind explicit membership and policy gates. | Direct Google/Gaode SDK/API runtime or client-owned provider keys. |
| MCP and crawler | Keep descriptors hostile by default and require discovery filtering, call-time authorization, token protection, SSRF defenses, and source policy before runtime. | MCP descriptor-selection and invocation-gate proofs after Search API policy compatibility. | Runtime MCP/crawler clients, prompt-trusted descriptors, or treating robots.txt as permission to execute. |
| Evaluation and audit | Keep source -> root -> store copy equality and no marker leakage as auditable UI-safe status rules. | Full trace/eval export after real server receipts exist. | Logging raw queries, provider payloads, credentials, private Health/location detail, or unreviewed memory writes. |

Can A176 start live provider/runtime work? **No.**

A174 closes the ordering proof, not the semantic policy proof. Current public
evidence still shows moving provider prices, quota, citation/source obligations,
retention options, region/privacy limits, MCP authorization risks, crawler
policy ambiguity, and maps attribution/cache duties. A live adapter would still
need to know whether an included-quota route is actually compatible with the
selected vendor policy, payload dispatch, authorization posture, transport
lease, and entitlement state before any request could be represented honestly
in UI.

The next safe implementation gate is:

**A176 Search API Cost/Membership Routing Cross-Stage Policy Compatibility
Proof**

Why A176, not provider runtime:

- It tests the exact gap left by A174: not "which source wins," but whether
  the winning copy remains truthful when routing, entitlement, vendor policy,
  dispatch, authorization, lease, and fallback disagree.
- It preserves the current hidden/missing nil, first-wins source order,
  rendered-id scope, value-only copy, `isRuntimeCallable false`, and no stale
  marker leakage constraints.
- It keeps the implementation test-only and avoids production defaults,
  endpoint URLs, API keys, OAuth, SDK/client handles, network calls, maps SDKs,
  crawler/MCP runtime, StoreKit/payment, booking/order flows, remote model
  runtime, or real provider execution.

### A176 Comment-Programming Frame

Allowed implementation files for A176:

- `kAirTests/App/AppBootstrapTests.swift`
- `Docs/architecture/kair-provider-routing-mcp-search-v1.md`
- `Docs/architecture/kair-next-agent-prompts-v1.md`
- `Docs/architecture/kair-agent-market-fit-audit-v1.md`

Read before coding:

- `kAir/Core/Networking/ServerProviderSearchAPICostMembershipRoutingDecisionStatusSourceProducer.swift`
- `kAir/Core/Networking/ServerProviderSearchAPICostMembershipRoutingPlan.swift`
- `kAir/Core/Networking/ServerProviderSearchAPICostMembershipRoutingDecision.swift`
- `kAir/Core/Networking/ServerProviderMeteredEntitlementStatusSourceProducer.swift`
- `kAir/Core/Networking/ServerProviderSearchAPIVendorPolicyStatusSourceProducer.swift`
- `kAir/Core/Networking/ServerProviderSearchAPIAdapterPayloadDispatchStatusSourceProducer.swift`
- `kAir/Core/Networking/ServerProviderSearchAPIVendorPolicyDispatchAuthorizationStatusSourceProducer.swift`
- `kAir/Core/Networking/ServerProviderSearchAPITransportLeaseStatusSourceProducer.swift`
- `kAirTests/App/AppBootstrapTests.swift`

A176 should add focused AppBootstrap tests only:

- Included-quota route plus compatible downstream metered/vendor/dispatch/
  authorization/lease status can be selected without stale marker mixing.
- Metered route plus overquota or blocked downstream source preserves
  first-wins order but never implies provider runtime, callability, or
  completion.
- Privacy/cost/region rejected routing status does not leak later vendor,
  payload, authorization, lease, request, response, transport, audit, or
  fallback markers.
- Downstream-first order still does not leak routing cost, membership, quota,
  or route markers.
- Hidden/missing rendered ids stay nil, fallback-after-miss still works, and
  root/store selected-copy equality is preserved.

No A176 production `AppBootstrap` defaults, `ChatStore` behavior, SwiftUI/UI,
networking, telemetry, memory writes, transcript mutation, credentials,
endpoint URLs, provider adapters, crawler/MCP clients, Google/Gaode SDKs,
StoreKit/payment, booking/order, remote model runtime, concrete vendor
selection, or real provider execution should be added.

## 20. A181 Refresh After Route-Policy Status Composition

A176-A180 closed the semantic route-policy compatibility loop for the Search
API provider-status stack. The repo can now prove that a route-policy status
source composes with routing, metered entitlement, vendor policy, payload
dispatch, dispatch authorization, transport lease, and fallback sources through
`AppBootstrap(providerStatusSources:)` and ChatStore lookup without stale
marker mixing. That makes the next question product/market rather than
mechanical: whether kAir should widen runtime now or first freeze a
cross-service cut plan for local iOS, maps provider upgrades, Search API,
crawler, and MCP.

Sources rechecked for A181 on 2026-06-01:

- Agent frameworks and UI surfaces:
  [LangGraph](https://docs.langchain.com/oss/python/langgraph/overview),
  [OpenAI Agents SDK](https://openai.github.io/openai-agents-python/),
  [AutoGen](https://microsoft.github.io/autogen/stable/),
  [CrewAI](https://docs.crewai.com/en/introduction),
  [smolagents](https://huggingface.co/docs/smolagents/index), and
  [OpenAI Apps SDK UI guidelines](https://developers.openai.com/apps-sdk/concepts/ui-guidelines).
- Agent architecture, memory, routing, and tool-use papers:
  [Agentic AI taxonomy](https://arxiv.org/abs/2601.12560),
  [Memory for Autonomous LLM Agents](https://arxiv.org/abs/2603.07670),
  [FrugalGPT](https://arxiv.org/abs/2305.05176),
  [RouteLLM](https://arxiv.org/abs/2406.18665),
  [LLMCompiler](https://arxiv.org/abs/2312.04511),
  [SwitchCraft](https://arxiv.org/abs/2605.07112), and
  [tool-use survey](https://arxiv.org/abs/2604.00835).
- MCP/security:
  [MCP 2025-11-25 security guidance](https://modelcontextprotocol.io/specification/2025-11-25/basic/security_best_practices),
  [MCP threat modeling](https://arxiv.org/abs/2603.22489),
  [Prompts Don't Protect](https://arxiv.org/abs/2605.18414), and
  [MCPSHIELD](https://arxiv.org/abs/2604.05969).
- Market/life-service signals:
  [Tencent Hy3/Yuanbao](https://www.tencent.com/en-us/articles/2202320.html),
  [Tencent Marvis](https://marvis.qq.com/),
  [Meituan LongCat-Flash-Thinking-2601](https://tech.meituan.com/2026/01/20/longcat-flash-thinking-2601.html),
  [VitaBench](https://arxiv.org/abs/2507.08709), and
  [LocalSearchBench](https://arxiv.org/html/2512.07436).
- Provider policy:
  [Brave Search API](https://brave.com/search/api/),
  [Tavily Search API](https://docs.tavily.com/documentation/api-reference/endpoint/search),
  [Exa pricing](https://exa.ai/pricing),
  [Perplexity pricing](https://docs.perplexity.ai/guides/pricing),
  [Google Maps March 2025 billing](https://developers.google.com/maps/billing-and-pricing/march-2025),
  [Google Places policies](https://developers.google.com/maps/documentation/places/web-service/policies),
  [Google Maps pricing](https://mapsplatform.google.com/pricing/),
  [Gaode pricing](https://lbs.amap.com/pages/base_service_price),
  [Gaode privacy protocol](https://lbs.amap.com/api/compliance-center/protocols/privacy_202410),
  and [RFC 9309](https://www.rfc-editor.org/rfc/rfc9309).
- Apple/local-first:
  [App Intents](https://developer.apple.com/documentation/appintents),
  [Foundation Models](https://developer.apple.com/documentation/foundationmodels/),
  and [Core Location permissions](https://developer.apple.com/documentation/corelocation/configuring-your-app-to-use-location-services).

### A181 Evidence Delta

| Cluster | Sourced fact | kAir judgment |
|---|---|---|
| Agent frameworks | Current frameworks separate graph state, tools, memory, human review, tracing, deployment, sessions, and MCP/tool extensions instead of hiding everything in one prompt. | kAir should stay framework-agnostic and typed. Use framework patterns as evaluation/design references, not as a runtime replacement for the Swift gate stack. |
| Papers | Agent papers keep converging on explicit planning, tool selection, cost routing, durable memory governance, trace/eval, and environment feedback. | Keep plan/policy/provider/status as first-class values. Do not let raw model text select paid providers, crawl sources, or invoke MCP. |
| UI/product | Apps SDK-style component guidelines and consumer assistants reinforce visible status, clear action boundaries, and mode/source feedback. Tencent/Meituan examples raise expectations for long workflows, search/tool robustness, and life-service relevance. | Provider mode, membership/cost, source/freshness, blocked state, and receipt posture must be visible. No booking/payment/order/completion claim without receipt. |
| Search API | Brave, Tavily, Exa, and Perplexity still differ across answer-vs-result shape, raw-content controls, search depth/context, citation tokens, QPS/credits, retention, and agent-search products. | Search cannot be represented as one generic "call." The next contract must classify service intent, raw-content/citation/retention policy, result shape, cost unit, and membership eligibility. |
| Maps | Google Maps/Places remains SKU, attribution, caching/display, Terms/Privacy, and AI-summary disclosure sensitive. Gaode exposes quota/QPS/pricing and privacy/compliance obligations. | iOS/local maps remain default. Google/Gaode are server-mediated upgrade candidates only after region, consent, attribution, cache/display, quota/QPS, server-key, and membership gates are explicit. |
| MCP/crawler | MCP security guidance and papers keep descriptor poisoning, prompt injection, token theft, SSRF, local-server risk, and missing invocation-time authorization as active risks. Robots policy is policy input, not authorization. | MCP/crawler stay disabled by default. A future plan may reserve descriptor/source fields, but no runtime client, tool call, crawler fetch, or prompt-trusted descriptor should appear next. |
| Memory/privacy | Memory papers support write/manage/read separation, contradiction handling, latency budgets, and privacy governance. Apple location and Health-like contexts remain sensitive. | Private/Health/location-sensitive data must stay local unless a later explicit privacy/consent gate exists. Public search facts become memory candidates only after source/citation/privacy policy passes. |

### A181 Adopt / Reserve / Reject

| Topic | Adopt now | Reserve | Reject for A182 |
|---|---|---|---|
| Architecture | A cross-service, value-only service cut-plan contract that classifies local iOS, server-mediated maps/search, crawler, and MCP before runtime. | Learned routers, graph orchestration, hosted tracing, and long-running workflow engines after deterministic gates and receipts exist. | Generic agent runtime replacement, hidden tool loop, or prompt-driven provider switching. |
| UI logic | Status-copy rules: selected provider family, local/server mode, membership/cost posture, source/freshness/attribution limits, blocked reason, and non-executable flag. | Richer shell visuals after the status vocabulary is frozen. | Marketing-style UI copy that implies provider execution, remote takeover, booking, payment, or completion. |
| Maps | Keep Apple/local as default. Represent Google/Gaode as future server-mediated upgrade lanes with region, membership, quota/QPS, attribution, cache/display, privacy, and server-secret requirements. | Provider-specific map adapters after cut-plan, display/cache policy, and receipt tests exist. | Client-side Google/Gaode keys, direct map SDK/API runtime, or silent premium switching. |
| Search/crawler | Search API may remain the first remote public-info lane, but only through policy-rich service intent and status contracts. | Crawler after robots/source/rate/retention/audit gates and sandboxing. | Raw pages in UI/debug copy, uncited life-service facts, hidden crawler fetches, or paywall/login bypass. |
| MCP | Reserve descriptor family, trust posture, discovery filtering, call-time authorization, consent, and audit fields. | Runtime MCP after descriptor verification, allowlist, sandbox, auth, and prompt-injection tests. | Exposing MCP prompts/resources/tools to model context as trusted text or calling MCP from the client. |
| Membership/cost | Keep cost unit, included quota, metered eligibility, region, and membership tier as route inputs. | Vendor-specific pricing adapters after service cut-plan and provider-specific policy contracts. | One "best API" path that ignores membership package, quota, region, or source policy. |

### A181 Decision

Can A182 start live provider/runtime work? **No.**

A180 proves cross-stage status selection, not a product-level provider service
plan. The current market and paper evidence supports kAir's direction:
chat-first, local-first, typed plans, visible provider status, and explicit
cost/policy gates. It does not justify provider runtime. The missing artifact
is a service cut-plan that says which future service lanes are local, which are
server-mediated, which are disabled/reserved, and which gates must pass before
any Search API, Google/Gaode, crawler, or MCP attempt can even be represented.

The next safe implementation gate is:

**A182 Provider Service Cut-Plan Comment Contract**

Why A182, not live Search API, Google/Gaode, crawler, or MCP:

- It translates the market/research judgment into a code-level contract without
  adding execution.
- It prevents the codebase from treating maps, search, crawler, and MCP as the
  same kind of provider.
- It gives UI/status work a stable vocabulary for local vs server-mediated,
  membership/cost, attribution/cache, source/citation, raw-content, descriptor,
  confirmation, and privacy posture.
- It keeps future implementation aligned with the user's requested direction:
  local iOS by default, membership-based Google/Gaode/Search upgrades, crawler
  reserved for public information, and MCP reserved behind explicit gates.

### A182 Comment-Programming Frame

Allowed implementation files for A182:

- `kAir/Core/Networking/ServerProviderServiceCutPlan.swift`
- `kAirTests/Networking/ServerProviderServiceCutPlanTests.swift`
- `Docs/architecture/kair-provider-routing-mcp-search-v1.md`
- `Docs/architecture/kair-next-agent-prompts-v1.md`
- `Docs/architecture/kair-agent-market-fit-audit-v1.md`

A182 should add a pure value/comment contract only:

- `ServerProviderServiceLane`: local Apple/iOS maps, cache fallback,
  server-mediated Google Maps, server-mediated Gaode, server-mediated Search
  API, reserved crawler, and reserved MCP.
- `ServerProviderServiceIntent`: map display/route/search, public-info search,
  public-source crawl candidate, MCP tool/resource/prompt candidate, and
  life-service read-only lookup.
- `ServerProviderServiceCutPlanInput`: service intent, provider family,
  capability, membership tier, region, privacy class, cost class, quota posture,
  source/citation requirement, raw-content policy, attribution/cache/display
  policy, descriptor-trust posture, confirmation requirement, and server-secret
  posture.
- `ServerProviderServiceCutPlanDecision`: local-ready, server-reserved,
  blocked, or unsupported, with required prior gates, user-facing status line,
  selected lane, and `isRuntimeCallable == false` / `isExecutable == false`.
- Keep all comments explicit that this is a planning/status contract, not a
  provider adapter, network client, MCP client, crawler, payment, booking, or
  UI runtime.

A182 tests should prove:

- Free/local maps choose the Apple/local lane and do not require remote provider
  entitlement.
- Google and Gaode map upgrades are server-reserved only when membership,
  region, attribution/cache/display, quota/QPS, privacy, and server-secret
  posture are represented; they still remain non-executable.
- Search API public-info lookup is server-reserved only when source/citation,
  raw-content, retention, cost unit, and metered entitlement posture are
  represented; it remains non-executable.
- Crawler is blocked unless public source policy, robots posture, rate/retention
  posture, sandbox/audit, and experimental enablement are represented; it still
  remains non-executable.
- MCP is disabled/reserved by default and requires descriptor verification,
  discovery filtering, invocation authorization, consent/confirmation, token
  protection, and audit posture before it can be server-reserved; it still
  remains non-executable.
- Private/Health/location-sensitive remote requests are blocked.
- Encoded/debug/status copy contains no endpoint URL, API key, OAuth token,
  bearer token, credential, URLSession, URLRequest, SDK/client handle, raw
  query, raw page/provider payload, crawler/MCP runtime detail, maps SDK
  detail, StoreKit/payment/order/booking data, hidden app-control, provider
  call, execution claim, or completion claim.

A182 must not change production `AppBootstrap` defaults, `ChatStore` behavior,
SwiftUI/UI, telemetry, transcript, memory-code, provider adapters, networking,
crawler/MCP runtime, maps SDK runtime, StoreKit/payment, booking/order flows,
remote model runtime, concrete vendor selection, provider calls, execution
claims, or completion claims.
