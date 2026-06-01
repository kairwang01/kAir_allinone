# kAir Agent Market Fit Audit v1

Status: architecture audit and adoption decision log.
Last updated: 2026-06-01.
Owner: reviewer / architecture loop.

This audit checks whether the current kAir documentation, UI contracts,
and reserved interfaces match current agent-system research and market
competitors. It is not a new product direction. It is a gate that says
which advanced patterns kAir should adopt now, reserve, or reject.

## 1. Evidence Checked

| Evidence | Link | kAir implication |
|---|---|---|
| Agent taxonomy | https://arxiv.org/abs/2601.12560 | Keep explicit perception/context, planning, action, tool-use, collaboration, evaluation, and failure handling. |
| Agent review / benchmarks | https://arxiv.org/abs/2504.19678 | Tool-use and search agents need benchmarked reliability, protocol safety, and integrated evaluation, not just demos. |
| Decoupled planning/execution | https://arxiv.org/abs/2507.02652 | Hierarchical search-agent work supports keeping planning, execution, source integration, and status composition separated. |
| Local-first memory | https://arxiv.org/abs/2603.16171 | Start with local, inspectable, searchable memory and rejection paths before adding vector complexity. |
| Mobile GUI agents | https://arxiv.org/abs/2508.15144 and https://github.com/X-PLUG/MobileAgent | GUI agents are useful research signals, but production iOS should prefer typed adapters, App Intents, public APIs, and confirmations. |
| Verifier-driven mobile agents | https://arxiv.org/abs/2503.15937 | Candidate actions need verification before execution; provider status must not imply external action before the gate passes. |
| MCP specification | https://modelcontextprotocol.io/specification/2025-11-25/ | MCP tools, resources, prompts, elicitation, auth, and lifecycle require consent, allowlists, descriptor trust, and audit records. |
| MCP security | https://arxiv.org/abs/2602.01129 and https://arxiv.org/abs/2603.22489 | Tool poisoning, prompt injection, privilege escalation, and client-side trust risks block any default MCP runtime. |
| MCP formal security update | https://arxiv.org/abs/2604.05969 | Newer MCP work reinforces capability-based access control, trust-boundary modeling, attestation, information-flow tracking, and runtime policy enforcement before connector execution. |
| MCP empirical scan | https://arxiv.org/abs/2506.13538 | MCP servers need registry scanning, governance, and maintainability checks before runtime integration. |
| Runtime agent security | https://arxiv.org/abs/2604.17562 | Multi-step agents need stateful runtime protection over trajectories; request construction, policy authorization, and execution should remain separate audit points. |
| ChatGPT Apps / connectors | https://help.openai.com/en/articles/11487775-apps-in-chatgpt | Market agents are moving toward explicit app/tool directories and connector setup; kAir should keep app-root composition and visible source/status surfaces. |
| Claude remote MCP connectors | https://support.claude.com/en/articles/11175166-get-started-with-custom-connectors-using-remote-mcp | Remote MCP connectors are account/cloud mediated, separate from local desktop MCP; kAir should not treat MCP as a default local runtime. |
| Computer-use safety model | https://platform.openai.com/docs/guides/tools-computer-use | GUI control requires explicit oversight and safety checks; kAir v1 should prefer typed App Intents/adapters and confirmation gates. |
| Tencent Yuanbao / Hy3 | https://www.tencent.com/en-us/articles/2202320.html | Useful consumer agents are product-co-designed, evaluated against real tasks, and optimized for cost and latency. |
| Meituan LongCat | https://tech.meituan.com/2026/01/20/longcat-flash-thinking-2601.html | Life-service agents need strong search/tool-use generalization and robustness to API failure, not fake booking/order completions. |
| MARVIS-style assistant | https://marvis-ai.com/ | Market promise is screen understanding and app navigation; kAir should differentiate with safer iOS-native execution boundaries. |
| Mobile-Agent-v3.5 / GUI-Owl | https://arxiv.org/abs/2602.16855 | Mobile GUI-agent progress is real, but benchmark-driven GUI control strengthens the case for verifier and typed-adapter gates before any open-ended app navigation. |
| Apple App Intents | https://developer.apple.com/documentation/appintents/making-actions-and-content-discoverable-and-widely-available/ | kAir-owned actions should be exposed through App Intents rather than hidden third-party app control. |
| Apple Foundation Models | https://developer.apple.com/documentation/foundationmodels/ | Structured output and tool calling fit kAir's local-router role, but availability must remain abstracted behind `ModelProvider`. |
| Core ML dynamic model install | https://developer.apple.com/documentation/coreml/downloading-and-compiling-a-model-on-the-user-s-device | Model downloads need explicit download, verify, compile, install, failure, and uninstall states. |
| Google Maps / Places | https://mapsplatform.google.com/pricing/ and https://developers.google.com/maps/documentation/places/web-service/policies | Google Maps/Places/Routes must stay cost-gated, attribution-aware, cache-policy-aware, and server-mediated. |
| Gaode Open Platform | https://lbs.amap.com/pages/base_service_price and https://lbs.amap.com/api/ios-sdk/summary | Gaode is a China-first map/search/route provider with quota, key, pricing, and privacy-compliance requirements. |
| Search API market | https://exa.ai/pricing/api, https://brave.com/search/api, and https://docs.tavily.com/documentation/api-reference/endpoint/search | Search APIs are the lowest-risk first provider-specific contract target because they are read-only, source/citation oriented, and useful across life-service surfaces. |
| Robots Exclusion Protocol | https://www.ietf.org/rfc/rfc9309.html | Crawlers must be server-side, robots-aware, cited, rate-limited, and disabled by default. |

## 2. Overall Verdict

Current kAir architecture is aligned with the 2026 market/research
direction after A85.

The latest spot-check on 2026 MCP and mobile-agent work does not change the
ordering. It strengthens the current choice: access profile and request creation
are deterministic inputs, search/MCP policies remain the authorization layer,
and runtime execution stays behind separate transport/readiness/audit gates.

The strongest match is the separation of:

```text
IntentDraft
  -> ActionPlan
  -> PlanValidator
  -> CapabilityRouter
  -> ProviderRoutingPolicy
  -> SearchProviderPolicy / MCPGatewayPolicy
  -> ResultProjector
  -> ProjectedRecommendationProvider
  -> ProviderStatusPresentation
```

This matches current research because the model proposes structured
actions, policy decides, adapters execute, and UI receives traceable
metadata. It also matches market agents because cost, latency, privacy,
source provenance, and failure recovery are treated as product features,
not backend details.

## 3. Current Repo Match Map

| Agent requirement | Current kAir artifact | Status |
|---|---|---|
| Structured router output | `IntentDraft`, `IntentConfidence`, `ActionRisk` | Present and testable. |
| Plan before execution | `ActionPlan`, `PlanValidator` | Present as pure value/policy layer. |
| Capability routing | `CapabilityKind`, `CapabilityRouter` | Present. |
| Tool boundary | `ToolRegistry` comments, `CapabilityAdapter` contract | Reserved; runtime execution still pending. |
| Provider routing | `ProviderRoutingPolicy`, `MapProviderDescriptor` | Present; no real provider calls. |
| Search/crawler provenance | `SearchResultEnvelope`, `SearchProviderPolicy`, `SearchCapabilityAdapter` | Present; read-only, source-cited, policy-only crawler path. |
| MCP tools/resources/prompts | `MCPGatewayPolicy`, descriptors for tool/resource/prompt | Present as authorization policy only; still no runtime. |
| Result projection | `ResultProjector`, `ProjectedProviderResult` | Present; provider metadata survives projection. |
| Recommendation handoff | `ProjectedRecommendationProvider` | Present; resolved Search can now route to `.search`. |
| Provider status UI seam | `ProviderStatusPresentation`, `ProviderStatusProviding`, `ChatStore.providerStatusPresentation(for:)` | Present; non-invasive side channel. |
| System entry points | `SurfaceRouter`, `OpenKAirSurfaceIntent`, `ContinueChatIntent`, `KAirIntentEntity`, `KAirAppShortcutsProvider` | Present for kAir-owned surfaces only; unknown/unbuilt identifiers fall back to Chat, Health is local-only sensitive, and Search is routable after A9. |
| Execution surface design | `ExecutionSurfaceShell`, design docs | Present; Maps, AI, Store, Health, and narrower read-only Search are shell callers. |
| Memory policy | `MemoryStore`, `MemoryWritePolicy`, architecture docs | Present in contract form; durable store/vector index deferred. |
| Server provider envelope | `ServerProviderEnvelope`, `ServerProviderEnvelopeValidator`, `MockServerTransport`, `ServerTransportEnvelopeTests` | Present after A11; still fixture-only and no real provider calls. |
| Server provider envelope factory | `ServerProviderEnvelopeFactory`, `ServerProviderQuotaSnapshot` | Present after A12; policy decisions become executable envelopes only after quota, entitlement, source, confirmation, privacy, and validator gates pass. |
| Provider dry-run evaluator | `ServerProviderDryRunEvaluator` | Present after A13; candidate envelopes become an audit-only selected/blocked/fallback report without transport execution. |
| Provider dry-run presentation | `ServerProviderDryRunPresentationProjector` | Present after A14; dry-run reports become advisory UI-safe copy and badge metadata without claiming execution. |
| Provider dry-run status bridge | `ProviderStatusBadgeResolver.presentation(recommendationID:for:)` | Present after A15; dry-run presentation metadata can use the existing provider status side channel without changing rail or trust-pill contracts. |
| Server provider execution gate | `ServerProviderExecutionGate` | Present after A16; envelope factory results become local-only, server-ready, confirmation-required, or blocked decisions before any transport runtime can exist. |
| Server provider runtime registry | `ServerProviderRuntimeRegistry` | Present after A17; server-ready decisions can resolve metadata-only descriptors for remote providers while local-only, blocked, and confirmation-required decisions resolve none. |
| Server provider invocation plan | `ServerProviderRuntimeInvocationPlanner` | Present after A18; readiness plus descriptor lookup becomes a value-only plan without carrying runtime objects, sensitive content, or execution claims. |
| Server provider dispatch boundary | `ServerProviderRuntimeDispatcher` | Present after A19; only well-formed planned metadata can become a prepared dispatch-boundary value, and all other states remain non-executing. |
| Server provider adapter protocol | `ServerProviderRuntimeAdapter` | Present after A20; prepared boundaries can produce fixture-only adapter results while non-prepared, malformed, and provider-mismatched boundaries remain non-executing. |
| Server provider adapter selection | `ServerProviderRuntimeAdapterRegistry` | Present after A21; prepared boundaries select fixture adapters by provider family, while local-only, blocked, confirmation, malformed, and unregistered paths stay non-executing. |
| Runtime receipt projection | `ServerProviderRuntimeReceiptProjector` | Present after A22; adapter results become UI/audit-safe receipts without exposing prompts, raw source content, Health data, endpoints, credentials, or merchant-write instructions. |
| Runtime receipt status bridge | `ProviderStatusBadgeResolver.presentation(recommendationID:for:)` | Present after A23; runtime receipts adapt into provider-status presentations without changing frozen rail, object-kind, or trust-pill contracts. |
| Runtime receipt status lookup | `RuntimeReceiptProviderStatusStore` | Present after A24; receipts can be queried by recommendation id through `ProviderStatusProviding`. |
| Provider status source composition | `ProviderStatusSourceMultiplexer` | Present after A25; ordered provider-status sources can prefer receipt-derived status and fall back to projected status deterministically. |
| Chat provider status source injection | `ChatStore.init(providerStatusProvider:)` | Present after A26; explicit provider-status sources override fallback while lookup stays filtered to currently rendered recommendation ids. |
| App composition provider status wiring | `AppBootstrap.providerStatusProvider`, `ChatHomeView.init(bootstrap:)` | Present after A27; the app root can carry the status source and pass it into `ChatStore` without UI layout or provider-runtime changes. |
| Chat provider status UI binding | `ProviderStatusCompactCellDisplay`, `RecommendedNextConsole`, `RecommendedNextCell` | Present after A28; compact Recommended Next cells render optional provider-status badges/status copy while nil status preserves the prior UI. |
| App recommendation source wiring | `AppBootstrap.recommendationProvider`, `ChatHomeView.init(bootstrap:)` | Present after A29; recommendation source composition is owned by the app root so projected recommendation ids can line up with provider-status lookup. |
| App status-source assembly | `AppBootstrap.providerStatusSources`, `ProviderStatusSourceMultiplexer` | Present after A30; ordered status sources can be assembled at the app root with first-source-wins semantics while direct source injection stays identity-preserving. |
| Provider access profile | `ProviderAccessProfile` | Present after A31; membership tier, provider preference, metered entitlements, experimental enablement, unavailable providers, region, and cache fallback are centralized before provider routing. |
| Provider access request bridge | `ProviderAccessProfile.searchProviderRequest`, `ProviderAccessProfile.mcpGatewayRequest` | Present after A32; search/crawler and MCP request reservations inherit access defaults while source/robots and confirmation inputs stay explicit. |
| App/search intent access wiring | `AppBootstrap.providerAccessProfile`, `SearchIntent.providerRequest(providerAccessProfile:)` | Present after A33; app composition can carry the access profile, and SearchIntent can lower through it without hiding source mode, privacy, robots, freshness, result, cache, or timestamp inputs. |
| Search adapter access profile configuration | `SearchCapabilityAdapter.Configuration.providerAccessProfile` | Present after A34; Search adapter decisions use the same profile-based lowering path while keeping privacy, source mode, freshness, robots, fixtures, cache, registry, and timestamp explicit. |
| Reserved Search adapter factory | `DefaultCapabilityRegistry.makeReservedSearchConfiguration` | Present after A35; profile-aware Search configuration can be constructed at the composition seam while `.webSearch` stays absent from the default shipped registry. |
| Reserved Search registry composition | `DefaultCapabilityRegistry.makeWithShippedStubs(reservedSearchAdapter:)` | Present after A36; `.webSearch` can be installed only through an explicit caller-built Search adapter while the default registry stays local-only. |
| App-bootstrap reserved Search opt-in | `AppBootstrap.init(reservedSearchAdapter:reservedSearchConfiguration:)` | Present after A37; app bootstrap can assemble reserved Search only when explicitly supplied while default, preview, and direct custom-registry injection remain default-preserving. |
| Chat Search availability propagation | `ChatStore.capabilityAvailability` | Present after A38; bootstrap-composed Search availability reaches ChatStore snapshots for enabled and disabled Search configs without transcript or recommendation mutations. |
| Chat Search availability presentation | `ChatStore.searchAvailabilityState` | Present after A39; ChatStore exposes a pure not-in-build / registered-unavailable / available Search state with factual copy and no execution side effects. |
| Chat Search availability display model | `ChatStore.searchAvailabilityDisplay` | Present after A40; Search availability maps to stable icon/tone/title/status/accessibility copy without visible UI, routing, or execution. |
| Chat Search availability UI binding | `SearchAvailabilityIndicator` | Present after A41; Chat chrome can show non-interactive Search boundary status only when Search is explicitly registered, while default not-in-build renders nothing. |
| Server-provider runtime pipeline | `ServerProviderRuntimePipeline` | Present after A42; readiness, descriptor lookup, invocation planning, dispatch, fixture-adapter registry, and receipt projection compose into one non-network receipt path. |
| Pipeline receipt status source | `RuntimeReceiptProviderStatusStore` + `ProviderStatusSourceMultiplexer` | Present after A43; pipeline-generated receipts can feed provider-status presentation and compact-cell display by recommendation id while preserving distinct non-executing states. |
| App-root pipeline receipt status composition | `AppBootstrap.providerStatusSources` | Present after A44; precomputed pipeline receipt status stores can be installed at the app root and consumed by ChatStore only for rendered recommendation ids without view-time pipeline execution. |
| Provider access quota snapshot bridge | `ServerProviderQuotaSnapshot.init(providerAccessProfile:...)` | Present after A45; profile membership, metered entitlements, unavailable providers, and experimental intent can be lowered into explicit quota snapshots without granting remote provider access by membership alone. |
| App-root provider quota snapshot composition | `AppBootstrap.providerQuotaSnapshot` | Present after A46; the app root owns a value-only quota snapshot, derives the default from `providerAccessProfile`, and preserves explicit package/cost injection without executing provider work. |
| Search adapter quota snapshot configuration | `SearchCapabilityAdapter.Configuration.providerQuotaSnapshot` | Present after A47; reserved Search carries the same quota snapshot boundary, defaults it through the A45 bridge, and can receive app-root quota only through explicit Search opt-in. |
| Search dry-run envelope preview | `SearchCapabilityAdapter.dryRunPreview(...)` | Present after A48; Search can explain quota/cost envelope readiness from stored configuration without calling Search resolve, transport, crawler/MCP, or provider runtime. |
| Search dry-run presentation projection | `SearchCapabilityAdapter.dryRunPresentation(...)` | Present after A49; Search dry-run reports can become UI-safe advisory presentation values while preserving provider, cost, freshness, source, and factory-rejection metadata without UI binding. |
| Search dry-run provider status source | `SearchDryRunProviderStatusStore` | Present after A50; precomputed Search dry-run presentations can feed `ProviderStatusProviding` by recommendation id with deterministic lookup and advisory copy, without Chat/UI wiring or Search execution. |
| App-root Search dry-run status composition | `AppBootstrap.providerStatusSources` | Present after A51; app-root callers can install precomputed Search dry-run status stores and ChatStore consumes them only for rendered recommendation ids without app/view dry-run generation. |
| Search dry-run status source builder | `SearchCapabilityAdapter.dryRunProviderStatusSource(...)` | Present after A52; Search adapter callers can package intent/report/presentation dry-run output into a status source for an explicit recommendation id without app/UI wiring or Search execution. |
| Batch Search dry-run status source builder | `SearchCapabilityAdapter.dryRunProviderStatusSource(presentations:/reports:)` | Present after A53; Search adapter callers can package multiple explicit recommendation ids with precomputed presentations/reports into one deterministic status source while preserving sorted ids, missing-id nil lookup, first-entry duplicate behavior, and no app/UI/Search execution. |
| Search dry-run status source handoff contract | `Contracts/search-capability-contract-v1.md` | Present after A54; adapter helpers are value-packaging seams, recommendation ids are caller-owned, only recommendation/search composition code or tests may produce stores, and app/root/view layers consume `ProviderStatusProviding` without generating dry-runs. |
| Search dry-run status source producer skeleton | `SearchDryRunStatusSourceProducer` | Present after A55; Search composition code has a pure producer that packages explicit recommendation ids with precomputed reports/presentations into `SearchDryRunProviderStatusStore` without id inference, `MatchingObject` mutation, Search execution, or app/root/view/runtime wiring. |
| Producer source app-root handoff proof | `AppBootstrapTests` | Present after A56; producer-built Search dry-run status sources pass through `AppBootstrap(providerStatusSources:)` and are consumed by ChatStore only for rendered recommendation ids without app/root/view layers generating dry-runs. |
| Rendered Search status source guard | `SearchRenderedDryRunStatusSource` | Present after A57; producer-built Search dry-run stores can be wrapped behind explicit rendered recommendation ids before app-root injection, so hidden store ids return nil without relying only on ChatStore's rendered-card guard. |
| Guarded source app-root handoff proof | `AppBootstrapTests` | Present after A58; guarded producer-built Search dry-run sources pass through `AppBootstrap(providerStatusSources:)`, preserve selected/blocked rendered-id status, and keep hidden wrapped-store ids nil before and after ChatStore composition. |
| Runtime adapter injection set | `ServerProviderRuntimeAdapterSet` | Present after A59; future real provider adapters can be supplied explicitly by server/composition code while the default static registry remains fixture-only and non-network. |
| Runtime pipeline adapter-set handoff proof | `ServerProviderRuntimePipeline` | Present after A60; the value-only pipeline can consume explicit adapter sets for prepared Search receipts while default fixture-only and non-prepared receipt semantics remain unchanged. |
| Injected pipeline receipt status source proof | `RuntimeReceiptProviderStatusStore` + `ProviderStatusSourceMultiplexer` | Present after A61; receipts produced through injected-adapter pipeline paths can feed provider-status presentation by explicit recommendation id with deterministic missing-id and source-order behavior. |
| Runtime pipeline status source producer skeleton | `ServerProviderRuntimeStatusSourceProducer` | Present after A62; runtime/provider composition code can package explicit recommendation ids with precomputed or injected-pipeline receipts into `RuntimeReceiptProviderStatusStore` without app/root/view generation. |
| Producer runtime source app-root handoff proof | `AppBootstrapTests` | Present after A63; producer-built runtime status sources pass through `AppBootstrap(providerStatusSources:)` and ChatStore consumes them only for rendered recommendation ids while hidden ids stay nil. |
| Rendered runtime status source guard | `ServerProviderRenderedRuntimeStatusSource` | Present after A64; producer-built runtime status can be wrapped behind explicit rendered recommendation ids before app-root injection, with hidden wrapped-store ids returning nil. |
| Guarded runtime source app-root handoff proof | `AppBootstrapTests` | Present after A65; guarded producer-built runtime status sources pass through `AppBootstrap(providerStatusSources:)` while hidden wrapped-store ids stay nil before app-root injection, at app-root lookup, and after ChatStore composition. |
| Real-provider adapter readiness matrix | `ServerProviderRuntimeAdapterReadinessMatrix` | Present after A66; every provider family has a value-only readiness report, remote providers need all family-specific gates before future server-side adapter readiness, and Apple/cache remain local/no-server-adapter paths. |
| Readiness-gated adapter installation proof | `ServerProviderRuntimeAdapterInstallationGate` | Present after A67; future injected server-side adapter families are installable only with same-family ready reports, while missing reports, non-ready reports, mismatches, Apple local, and cache are rejected deterministically. |
| Readiness-gated adapter set validation proof | `ServerProviderRuntimeAdapterSetReadinessValidator` | Present after A68; already-created injected adapter sets are validated by registered provider family against installable decisions before any future set-use authorization, without resolving adapters or running provider code. |
| Adapter set use authorization proof | `ServerProviderRuntimeAdapterSetUseGate` | Present after A69; each future injected-adapter use can now be authorized by requested provider family against an accepted set validation before any resolve path is allowed. |
| Authorized adapter set pipeline handoff proof | `ServerProviderRuntimePipeline` | Present after A70; validation-taking injected-adapter pipeline overloads now run A69 authorization before `ServerProviderRuntimeAdapterSet.resolve`, projecting unauthorized attempts as non-success receipts without provider metadata. |
| Authorized runtime status source producer proof | `ServerProviderRuntimeStatusSourceProducer` | Present after A71; runtime/provider composition can package authorized injected-pipeline receipts by explicit recommendation id through the validation-taking pipeline path before app-root handoff. |
| Authorized runtime status app-root handoff proof | `AppBootstrapTests` | Present after A72; authorized producer-built runtime status sources can pass through `AppBootstrap(providerStatusSources:)`, remain rendered-id scoped before ChatStore consumption, and preserve rejected-validation advisory status without production app/root/view runtime generation. |
| Runtime adapter manifest catalog proof | `ServerProviderRuntimeAdapterManifestCatalog` | Present after A73; future real-provider adapter families are explicit value-only manifests that mirror readiness matrix gates, exclude Apple/cache installable entries, and avoid sensitive runtime fields. |
| Manifest-backed adapter installation proof | `ServerProviderRuntimeAdapterManifestInstallationPlanner` | Present after A74; future adapter installation must first pass the A73 manifest catalog, then readiness-report validation, before preserving A67 installation semantics. |
| Manifest-backed adapter set validation proof | `ServerProviderRuntimeAdapterManifestSetValidator` | Present after A75; already-created injected adapter sets validate only from manifest-backed installation decisions before A68 readiness-set validation and future set-use authorization. |
| Manifest-backed adapter set use authorization proof | `ServerProviderRuntimeAdapterManifestSetUseGate` | Present after A76; future injected-adapter use authorization must consume accepted manifest-backed set validation and embedded A68/A69 authorization before any resolve-capable pipeline path. |
| Manifest-backed runtime pipeline handoff proof | `ServerProviderRuntimePipeline` | Present after A77; injected-adapter pipeline entry can now require A76 manifest-backed authorization before any adapter-set resolve path while preserving default and A70 validation overloads. |
| Manifest-backed runtime status source producer proof | `ServerProviderRuntimeStatusSourceProducer` | Present after A78; runtime/provider composition can package A77 manifest-backed injected-pipeline receipts by explicit recommendation id while preserving advisory copy, duplicate-id behavior, and older producer overloads. |
| Manifest-backed runtime status app-root handoff proof | `AppBootstrapTests` | Present after A79; manifest-backed producer-built runtime status sources can pass through app-root provider-status composition, remain rendered-id scoped, and preserve accepted/rejected A76 advisory status without production app/root/view runtime generation. |
| Real provider connector boundary skeleton | `ServerProviderRuntimeConnector` | Present after A80; future remote provider adapters have a value-only connector request/result boundary and remote-family eligibility catalog before any provider-specific runtime or transport exists. |
| Connector request planner proof | `ServerProviderRuntimeConnectorPlanner` | Present after A81; prepared dispatch boundaries, A73 manifests, and A76 manifest-backed authorization can now derive value-only connector requests before any connector or transport runs. |
| Connector invocation receipt proof | `ServerProviderRuntimeConnectorInvoker` | Present after A82; accepted connector requests can flow through an injected connector boundary into value-only receipts, while rejected planning and family mismatch paths remain advisory and metadata-only. |
| Connector receipt status source proof | `ServerProviderRuntimeConnectorStatusSourceProducer` | Present after A83; connector invocation receipts can be packaged by explicit recommendation id into rendered-id scoped advisory provider-status presentations before app-root handoff. |
| Connector receipt status app-root handoff proof | `AppBootstrapTests` | Present after A84; connector receipt status sources can pass through app-root provider-status composition and ChatStore lookup while hidden ids stay nil and copy stays advisory. |
| Research, market, and interface cut-plan refresh | `2026-agent-market-ui-provider-research.md`, architecture docs | Present after A85; current papers/specs/vendor docs/competitor docs select Search API as the first provider-specific contract-only cut while deferring Google/Gaode, crawler, MCP, and remote-model runtime. |
| Search API server adapter contract proof | `ServerProviderSearchAPIAdapterContract` | Present after A86; Search API now has value-only request/result/receipt contracts that consume approved envelope and connector metadata while preserving citation, quota, privacy, source, freshness, and advisory-copy gates without network execution. |
| Search API adapter receipt status source proof | `SearchAPIAdapterProviderStatusStore` | Present after A87; A86 request decisions and result receipts can be exposed through `ProviderStatusProviding` by explicit recommendation id with advisory prepared/normalized/rejected status, first-wins duplicates, and missing-id nil lookup. |
| Search API adapter status app-root handoff proof | `AppBootstrapTests` | Present after A88; A87 status sources pass through app-root provider-status composition and ChatStore lookup for rendered ids while hidden ids stay nil, rejected values remain non-success, and source order stays first-wins. |
| Search API adapter status source producer guard | `ServerProviderSearchAPIAdapterStatusSourceProducer` | Present after A89; typed request-decision/result-receipt inputs are packaged into an A87 status store and wrapped behind explicit rendered recommendation ids before app-root injection, preserving hidden-id nil lookup, first-wins duplicates, and advisory copy. |
| Search API adapter producer guard app-root handoff proof | `AppBootstrapTests` | Present after A90; A89 producer-built guarded status sources pass through app-root provider-status composition and ChatStore lookup while remaining rendered-id scoped and preserving hidden-id nil, rejected advisory status, and source-order first-wins. |
| Search API adapter dispatch and lease pipeline | A91-A115 networking contracts and `AppBootstrapTests` | Present after A115; payloads, dispatch eligibility, vendor authorization, transport lease budget guards, status sources, app-root handoff, and cross-stage composition are proven as value-only, rendered-id scoped, and execution-free. |
| Provider cut-plan refresh | `2026-agent-market-ui-provider-research.md`, architecture docs | Present after A116; current paper/vendor/competitor evidence says live Search API transport remains premature until server-side metered entitlement status is explicit. |
| Server-provider metered entitlement ledger | `ServerProviderMeteredEntitlementLedger` | Present after A117; server-verified provider/vendor budget snapshots can accept or reject usage by membership, entitlement, quota period, units, privacy, freshness, and provider/vendor/capability match without StoreKit or provider execution. |
| Server-provider metered entitlement status source | `ServerProviderMeteredEntitlementStatusSourceProducer` | Present after A118; accepted included/metered and rejected budget decisions can be exposed through rendered-id scoped provider-status copy with hidden/missing nil lookup and duplicate first-wins behavior. |
| Server-provider metered entitlement status app-root handoff | `AppBootstrapTests` | Present after A119; metered entitlement status sources pass through app-root provider-status composition and ChatStore lookup for rendered ids only while preserving hidden/missing nil and first-wins behavior. |
| Server-provider metered entitlement cross-stage status composition | `AppBootstrapTests` | Present after A120; metered entitlement, vendor policy, payload dispatch, dispatch authorization, and transport lease status sources compose deterministically through app-root provider-status composition and ChatStore lookup while preserving first-wins ordering, hidden/missing nil lookup, and no stale detail mixing. |
| Metered-stack research/provider cut-plan refresh | `2026-agent-market-ui-provider-research`, `2026-agent-architecture-deep-dive-v1`, architecture docs | Present after A121; current external evidence keeps live providers blocked and selects an A122 Search API metered-entitlement transport lease handoff proof as the next gate. |
| Search API metered-entitlement transport lease handoff | `ServerProviderSearchAPITransportLease`, `ServerProviderMeteredEntitlementLedger`, `ServerProviderSearchAPITransportLeaseTests` | Present after A122; A112 transport leases require A117 metered decision metadata and reject generic, rejected, or mismatched budget contexts before any transport/provider runtime can exist. |
| Metered-entitlement transport lease status handoff | `ServerProviderSearchAPITransportLeaseStatusSourceProducerTests`, `AppBootstrapTests` | Present after A123; A122 leases package into provider-status copy and pass through app-root/ChatStore lookup with hidden/missing nil behavior, new rejection copy, and first-wins source ordering. |
| Metered-entitlement transport lease cross-stage composition | `AppBootstrapTests` | Present after A124; A123 lease status composes deterministically with metered entitlement, vendor policy, payload dispatch, and dispatch authorization status while preserving first-wins ordering, hidden/missing nil lookup, and no stale detail mixing. |
| Post-A124 research/provider cut-plan refresh | Research docs and architecture docs | Present after A125; current evidence keeps live provider runtime deferred and selects a value-only Search API transport request contract as the next gate. |
| Search API transport request contract | `ServerProviderSearchAPITransportRequest`, `ServerProviderSearchAPITransportRequestTests` | Present after A126; issued metered-entitlement leases can prepare metadata-only transport request decisions only when the full request/payload/dispatch/vendor/authorization/lease/budget/source/citation/cost/freshness chain still matches. |
| Search API transport request status source | `ServerProviderSearchAPITransportRequestStatusSourceProducer`, `ServerProviderSearchAPITransportRequestStatusSourceProducerTests` | Present after A127; A126 prepared/rejected request decisions package into rendered-id scoped provider-status copy with safe badges/card hints, nested rejection reasons, duplicate first-wins behavior, hidden/missing nil lookup, and no raw query/source-host/runtime leakage. |
| Search API transport request status app-root handoff | `AppBootstrapTests` | Present after A128; A127 request status sources pass through app-root provider-status composition and ChatStore lookup for rendered ids only while preserving prepared/rejected copy, hidden/missing nil lookup, and source-order first-wins without stale request/vendor/lease/budget/metered detail mixing. |
| Search API transport request cross-stage status composition | `AppBootstrapTests` | Present after A129; request status composes with metered entitlement, vendor policy, payload dispatch, dispatch authorization, and transport lease status while preserving first-wins ordering, hidden/missing nil lookup, and no stale upstream detail mixing. |
| Post-A129 research/provider cut-plan refresh | Research docs and architecture docs | Present after A130; current external evidence still blocks live provider runtime and selects a value-only Search API transport response receipt contract as the next gate. |
| Search API transport response receipt contract | `ServerProviderSearchAPITransportResponse`, `ServerProviderSearchAPITransportResponseTests` | Present after A131; normalized/cited adapter result receipts can be accepted only when bound to the prepared A126 transport request and its metered, vendor, lease, source, citation, cost, freshness, and result-limit metadata. |
| Search API transport response status source | `ServerProviderSearchAPITransportResponseStatusSourceProducer`, `ServerProviderSearchAPITransportResponseStatusSourceProducerTests` | Present after A132; accepted/rejected response decisions package into rendered-id scoped provider-status copy with safe result/citation count summary, nested request/result rejection reasons, duplicate first-wins behavior, hidden/missing nil lookup, and no raw query/citation URL/source-host/runtime leakage. |
| Search API transport response status app-root handoff | `AppBootstrapTests` | Present after A133; A132 response status sources pass through app-root provider-status composition and ChatStore lookup for rendered ids only while preserving accepted/rejected copy, hidden/missing nil lookup, and source-order first-wins without stale response/request/result/vendor/lease/budget/metered detail mixing. |
| Live vendor selection and A154 research refresh | `ServerProviderSearchAPILiveVendorSelection`, `AppBootstrapTests`, research docs | Present after A154; A150-A153 prove value-only live-vendor selection, rendered-id status, app-root handoff, and cross-stage composition. A154 selects an A155 server adapter interface comment-programming proof instead of runtime networking. |

## 4. Adopt Now

- Keep the planner/executor split. A model may produce `IntentDraft` and
  later `ActionPlan`; it must not call adapters directly.
- Keep provider routing as a policy layer independent of capability
  routing.
- Preserve provider metadata through every projection so UI can show
  provider, freshness, cost, blocked reason, and limitations.
- Treat MCP prompts like MCP tools/resources: allowlisted descriptors,
  domain policy, optional user review, and audit trace.
- Keep search and crawler output cited and read-only until legal/product
  review creates write/action contracts.
- Add trace-first evaluation before real provider integrations: success,
  cost, latency, fallback, privacy block, and confirmation correctness.
- Keep the A11-A153 envelope, dry-run, readiness, fixture-adapter, receipt,
  status-source, and composition wiring path as the mandatory gate before any
  real Google/Gaode/Search/MCP/remote-model runtime code.

## 5. Reserve

- GUI-agent screen control: reserve for assistive context or testing
  tools only. Do not ship hidden production automation.
- Tree-search / deep-reasoning loops: reserve for high-risk or hard
  tasks under a strict budget; do not use by default for every prompt.
- Multi-agent self-evolution and RL: reserve for offline evaluation and
  training-data generation. Runtime app behavior must remain deterministic
  enough to test.
- MCP runtime: reserve until server allowlist, descriptor trust, OAuth,
  sandboxing, prompt-injection tests, and Health-blocking tests are present.
- Durable vector memory: reserve behind `VectorIndex`; start with local
  records, FTS, explicit retrieval reasons, and user deletion.
- Google/Gaode/search/crawler runtime: reserve until server envelope,
  entitlement, quota, attribution, retention, and privacy tests pass.

## 6. Reject for v1

- Hidden cross-app tap automation as a product promise.
- Raw on-device crawling.
- Remote Health prompt/model/tool routing.
- Fake life-service order, booking, payment, or merchant completion.
- Silent premium provider calls.
- UI claims like "completed" when kAir only prepared or opened a handoff.
- A single omnipotent agent role with all tools and all memory domains.
- API keys in the iOS app bundle.

## 7. Prompt and Interface Audit

The prompt surfaces now have three distinct meanings:

1. **Router prompt output**: represented by `IntentDraft` JSON and
   rejected if free-form or low-confidence.
2. **Coding-agent prompts**: owned by
   `Docs/architecture/kair-next-agent-prompts-v1.md`; these drive one
   implementation gate at a time.
3. **MCP prompt templates**: reserved by `MCPPromptDescriptor` and
   `MCPGatewayOperation.prompt`, allowlisted per server, domain-scoped,
   and optionally review-gated. They do not execute or sample in v1.

Missing or unsafe prompt paths after A10:

- No production prompt registry exists yet. That is correct until
  `ToolRegistry` has pure declarations and tests.
- No MCP prompt runtime exists yet. That is correct until MCP server
  transport, descriptor verification, OAuth, sandboxing, and
  prompt-injection tests are designed.
- No chain-of-thought or hidden routing prompt should be user-visible.

## 8. A10 Architecture Redesign Decision

The redesign is an ordering decision, not a wholesale rewrite:

```text
current A6-A90 baseline
  -> typed server/provider transport envelope
  -> provider envelope adapters and quota snapshot
  -> dry-run evaluation traces and quota/cost simulation
  -> UI-safe dry-run presentation projection
  -> provider status bridge for dry-run UI metadata
  -> execution-readiness gate before server transport
  -> runtime adapter registry contract
  -> runtime invocation plan contract
  -> provider status source injection and app-root composition
  -> provider status UI binding
  -> app-root recommendation source composition
  -> app-root provider status source assembly
  -> provider access profile for membership/cost defaults
  -> app-root and SearchIntent access-profile lowering
  -> Search adapter access-profile configuration
  -> reserved Search adapter factory seam
  -> then add one real provider at a time
```

Do not jump straight to Google/Gaode SDKs, crawler runtime, or MCP
runtime. A12 now proves that every resolved provider/search/MCP policy
decision can be translated into the shared envelope without bypassing
trace, quota, entitlement, source, privacy, or confirmation gates. A13 now
compares candidate envelopes and records cost/quota/fallback reasoning
before anything can execute. A14 now explains this dry-run state through
UI-safe advisory rows and badges without claiming a provider was called.
A15 now bridges that presentation into the existing
`ProviderStatusPresentation` side channel without changing rail layout or
executing providers. A16 now adds the final readiness gate that separates
local-only routes, server-ready routes, confirmation-required routes, and
blocked routes before any transport runtime can be introduced. A17 now adds
the value-only runtime descriptor registry contract that lets server-ready
decisions resolve provider-specific adapter metadata without endpoints,
SDKs, credentials, crawler runtime, MCP client runtime, or transport
execution. A18 now adds a non-executing invocation plan that combines
readiness and descriptor metadata without carrying prompts, raw source
content, Health data, credentials, or merchant-write instructions. A19 now
adds a dispatch boundary that can prepare future adapter dispatch from a plan
without executing a provider. A20 now adds the adapter protocol/result
contract that future Google, Gaode, search, crawler, and MCP adapters can
conform to without introducing network or provider-specific implementation.
A21 now adds the registry/selection contract that maps prepared boundaries to
registered fixture adapters by provider family while preserving non-executing
states for local-only, blocked, confirmation, malformed, and unregistered
routes. A22 now projects those adapter results into UI/audit-safe runtime
receipts without exposing prompts, raw source content, Health data, endpoints,
transport payloads, provider credentials, or merchant-write instructions. A23
now bridges runtime receipts into the existing provider-status side channel
without changing rail layout, recommendation object kinds, or trust-pill
vocabulary. A24 now adds a receipt-status lookup/store so UI stores can query
receipt-derived provider status by recommendation id through
`ProviderStatusProviding` without mutating recommendation cards or claiming real
provider execution. A25 now adds a source multiplexer that can prefer
receipt-derived status and fall back to projected recommendation status without
the caller knowing which source answered. A26 lets the chat store receive the
composed status source explicitly while still suppressing status for ids not
currently rendered in the rail. A27 wires that source through the app composition
root: `AppBootstrap` can carry an explicit `ProviderStatusProviding` source and
`ChatHomeView` passes it into `ChatStore` without adding UI layout or provider
runtime behavior. A28 binds those presentations into Chat's compact Recommended
Next UI through a pure display model; nil status keeps the previous compact-cell
behavior, and rendered copy still cannot claim booking/order/payment/provider
contact. A29 moves recommendation-source composition to the app root:
`AppBootstrap` can carry a `RecommendationProvider`, and `ChatHomeView` passes it
into `ChatStore`, so projected recommendation ids can match provider-status
lookups. A30 adds the app-root status-source assembly path:
`AppBootstrap` can now compose ordered `ProviderStatusProviding` sources through
`ProviderStatusSourceMultiplexer` while preserving nil default status and direct
source identity. A31 adds a pure `ProviderAccessProfile` so membership tier,
preferred provider, metered entitlements, experimental enablement, unavailable
providers, region, and cache fallback can be converted into `ProviderRequest`
values before `ProviderRoutingPolicy` runs. A32 extends that same access profile
to build `SearchProviderRequest` and `MCPGatewayRequest` values without weakening
robots/source, privacy, allowlist, Health, or confirmation gates. A33 lets
`AppBootstrap` carry that profile and lets `SearchIntent` lower through it while
source mode, privacy, freshness, robots, result drafts, cached results, and
timestamps stay explicit. A34 moves `SearchCapabilityAdapter.Configuration` onto
the same profile-backed lowering path while preserving explicit privacy, robots,
source mode, fixture result, cache, registry, and timestamp inputs. A35 adds the
reserved factory seam that can construct profile-aware Search adapter
configuration while leaving `.webSearch` out of the default shipped registry. A36
adds the explicit registry composition path: `.webSearch` is installed only when
the caller supplies a Search adapter, and the default local-only registry remains
unchanged. A37 adds the bootstrap composition hook: bootstrap can assemble a reserved
Search adapter/configuration only when explicitly supplied, while default,
preview, and direct custom-registry injection stay default-preserving. A38 proves
that bootstrap-composed Search availability reaches ChatStore through the same
composition path as ChatHome without creating transcript or recommendation side
effects. A39 adds the pure chat-side Search availability state, so later UI can
explain the Search boundary without executing Search or implying provider contact.
The A42 runtime pipeline now proves the existing readiness, descriptor,
invocation-plan, dispatch, fixture-adapter, and receipt layers compose without
calling real transport. A43 now proves pipeline-generated receipts feed the
already-built provider-status side channel and compact-cell display by
recommendation id without changing Recommended Next layout or executing
providers. The next missing invariant is app-root composition: precomputed
pipeline receipt stores must pass through `AppBootstrap.providerStatusSources`
without making AppBootstrap, ChatStore, or views execute the pipeline. A44 now
proves that app-root composition seam. A45 now adds the pure profile-to-quota
bridge so future membership packages can assemble Google, Gaode, Search,
Crawler, and MCP allowance snapshots before any real transport or SDK work
exists. A46 now proves app-root ownership of that quota snapshot without making
`AppBootstrap` execute providers. The next missing invariant is Search adapter
configuration carrying the same snapshot while remaining non-network and
default-preserving. A47 now proves that configuration seam. The next missing
invariant is a non-executing Search dry-run preview that uses the stored quota
snapshot to show whether Search would be allowed before any real provider call.
A48 now proves that advisory envelope preview path. The next missing invariant
is UI-safe presentation projection for those Search dry-run reports, so cost and
source readiness can be explained without claiming real Search execution.
A49 now proves that projection path. A50 now bridges precomputed Search dry-run
presentations into the existing provider-status side channel by recommendation
id, still without Chat UI wiring or provider execution. A51 now proves app-root
composition: callers can install that precomputed Search dry-run status source
through `AppBootstrap` without making AppBootstrap, ChatStore, or views generate
dry-runs. A52 now adds adapter-owned packaging, so callers can ask the Search
adapter for a ready-to-install status source instead of duplicating
report-to-presentation-to-source assembly. A53 extends that helper to multiple
explicit recommendation ids and precomputed reports/presentations while preserving
sorted lookup, missing-id nil behavior, and first-entry duplicate handling. The
handoff contract now makes that boundary normative: composition/recommendation
source code may precompute these stores, while app/view layers consume only
`ProviderStatusProviding`. The next missing invariant is a tiny value-only
producer skeleton that encodes the allowed composition seam without app/root/view
wiring. A55 adds that producer and locks selected/blocked report packaging,
presentation packaging, duplicate ids, missing ids, and advisory copy. The next
missing invariant is an app-root handoff proof that the producer-built source is
created outside `AppBootstrap` and only passed through the existing
`providerStatusSources` path. A56 proves that handoff. The next missing
invariant is a rendered-id guard source so producer-built Search status can be
restricted before app-root injection, rather than relying only on ChatStore's
rendered-card guard. A57 adds that pure guard, and A58 proves the guarded source
survives app-root handoff while hidden wrapped-store ids stay nil before and
after ChatStore composition. A59 adds an injection set for runtime adapters, so
future real provider adapters can be installed explicitly without replacing the
default fixture-only non-network path. A60 proves injected adapter sets can be
consumed by the value-only runtime pipeline without changing the default path.
A61 proves receipts from that injected-adapter pipeline can feed the existing
provider-status side channel by explicit recommendation id. A62 adds a pure
producer skeleton so recommendation/provider composition code can package
precomputed or injected-pipeline receipts into a status source without making
app/root/view layers generate runtime receipts. A63 proves the producer-built
runtime status source can pass through `AppBootstrap(providerStatusSources:)`
and remain rendered-id scoped in ChatStore. The next missing invariant is a
rendered-id guard source for runtime status, so composition code can restrict
producer-built runtime status before app-root injection instead of relying only
on ChatStore's rendered-card filter. A64 adds that pure guard. A65 proves the
guarded producer-built runtime source remains hidden-id safe before app-root
injection, at app-root lookup, and after ChatStore composition. The next missing
invariant is a real-provider adapter readiness matrix, so
Google/Gaode/Search/Crawler/MCP can be evaluated against explicit cost, privacy,
source, robots, MCP, redaction, credential, and security gates before any real
runtime implementation is introduced. A66 adds that matrix. A67 adds an
installation gate that consumes readiness reports before any future injected
server-side adapter family can be selected. A68 adds a set-level validator that
checks already-created injected adapter sets by registered provider family
against installable decisions before any set can be used. The next missing
invariant is a per-use authorization gate, so future runtime handoff can verify
the requested provider family against accepted set validation before any resolve
path is entered. A69 adds that use gate. The next missing invariant is a
pipeline handoff proof that runs the A69 authorization before the injected
adapter-set pipeline path can enter `ServerProviderRuntimeAdapterSet.resolve`.
A70 adds that handoff proof while preserving default and unvalidated overload
behavior. The next missing invariant is a status-source producer overload that
uses the authorized pipeline path before packaging runtime receipts for explicit
recommendation ids. A71 adds that producer overload while preserving the older
precomputed and unvalidated producer paths. The next missing invariant is an
app-root handoff proof that authorized producer-built status sources remain
rendered-id scoped before ChatStore consumption. A72 proves that handoff through
`AppBootstrap(providerStatusSources:)`, including rejected-validation advisory
status and hidden producer ids. The next missing invariant is a manifest catalog
that names which future real-provider adapter families can ever be installed and
keeps their capability, cost, membership, source, MCP, and readiness prerequisites
aligned with the readiness matrix before any provider implementation exists. A73
adds that manifest catalog. The next missing invariant is an installation planner
that refuses to consume readiness reports until the requested provider family has
a manifest. A74 adds that manifest-backed installation proof while preserving
A67 installation semantics after manifest validation. The next missing invariant
is a manifest-backed adapter-set validator that refuses to delegate to A68 until
every registered adapter family has an installable A74 decision. A75 adds that
manifest-backed set validation while preserving A68 duplicate first-family and
accepted-family behavior. The next missing invariant is manifest-backed set-use
authorization that refuses to delegate to A69 until A75 is accepted and carries
embedded A68 validation. A76 adds that use authorization proof while preserving
A69 authorization output. The next missing invariant is a pipeline handoff that
refuses to reach injected adapter-set `resolve(_:)` until A76 authorization is
same-family and carries authorized A69 output. A77 adds that manifest-backed
pipeline handoff while preserving default and A70 validation-taking paths. The
next missing invariant is a runtime-status source producer that packages those
A77 manifest-backed pipeline receipts by explicit recommendation id. A78 adds
that producer handoff while preserving precomputed, unvalidated, and A70
validation-taking producer paths. The next missing invariant is an app-root
handoff proof that manifest-backed producer-built status sources remain
rendered-id scoped before ChatStore consumption. A79 proves that handoff for
accepted and rejected A76 status while preserving source order. A80 adds a
value-only connector boundary, limits eligibility to remote families, and keeps
Apple/cache local-only. A81 proves prepared dispatch boundaries can derive
same-family manifest-backed connector requests before any connector runs. A82
proves accepted connector requests can flow through an injected connector
boundary into value-only receipts while rejected planning avoids connector calls
and family mismatches strip provider metadata. A83 packages those receipts into
rendered-id scoped advisory provider-status presentations. A84 proves that those
sources survive app-root provider-status composition and ChatStore lookup while
hidden ids stay nil and source order remains deterministic. A85 refreshed the
external research/market/interface audit and chose Search API as the first
provider-specific contract proof because it is read-only, citation-oriented, and
can exercise reusable quota/privacy/source/status gates before higher-risk
Google/Gaode, crawler, MCP, or remote-model runtime work. A86 adds that Search
API contract as value-only request/result/receipt metadata with strict rejection
for unsafe provider, privacy, quota, source, citation, connector, and freshness
paths.
A87 packages those Search API adapter values into the existing provider-status
side channel by explicit recommendation id, preserving advisory prepared,
normalized, and blocked status without UI wiring or provider execution.
A88 proves those Search API adapter status sources survive app-root
`providerStatusSources` composition and ChatStore lookup for rendered
recommendation ids, while hidden ids stay nil, rejected A86 values stay
non-success/advisory, and source order remains first-wins.
A89 adds a typed value-only producer for Search API adapter status inputs and
wraps the resulting A87 store behind explicit rendered recommendation ids before
app-root injection.
A90 proves that A89 producer-built guarded source survives app-root
`providerStatusSources` composition and ChatStore lookup while hidden supplied
ids stay nil and rejected values remain non-success/advisory.
A91 adds a value-only Search API adapter transport payload boundary that derives
outbound-safe payload metadata from prepared A86 requests, rejects rejected or
unsafe request metadata, and keeps encoded/debug/status copy advisory without
endpoints, credentials, SDKs, raw provider content, private/Health data,
commerce fields, or provider execution claims.
A92 adds a value-only Search API adapter payload dispatch gate that marks only
prepared A91 payloads matching their original A86 request metadata as
dispatch-eligible, while blocking rejected, missing, mismatched, or unsafe
request metadata without transport execution or provider claims.
A93 packages A92 payload dispatch receipts into the rendered-id scoped
provider-status side channel, showing dispatch-eligible receipts as advisory
dispatch-ready metadata and blocked receipts as non-success/advisory status
without leaking query text or implying provider contact.
A94 proves that A93 dispatch status sources pass through app-root
`providerStatusSources` composition and ChatStore lookup for rendered
recommendation ids only, while hidden ids remain nil, blocked receipts stay
disabled/advisory, and source order remains first-wins.
A95 proves that A89/A90 Search API adapter request/result status and A93 payload
dispatch status compose deterministically through app-root
`providerStatusSources` and ChatStore lookup. Request/result status wins when it
is first, dispatch status wins when it is first, hidden ids from both sources
stay nil at source/root/store lookup, and selected advisory copy does not merge
stale details from the second source.
A96 adds a value-only Search API adapter fixture bridge after A92 dispatch. It
accepts only prepared request metadata, prepared payload metadata, eligible
dispatch metadata, matching ids/trace/capability/cost/freshness/source policy,
general privacy, allowed quota, and citation policy, then emits fixture audit
metadata only. Rejected request, rejected payload, blocked dispatch, and
mismatched metadata stay non-success with deterministic reasons, without
endpoints, credentials, SDKs, crawler/MCP, UI/root wiring, or provider execution.
A97 packages A96 fixture bridge responses into the rendered-id scoped
provider-status side channel. Ready bridge responses show advisory fixture/audit
metadata with remote/cost/freshness/source context, rejected responses show
disabled non-success reason chains, hidden ids stay nil, duplicate ids keep the
first response, and status copy avoids query text and execution claims.
A98 proves those A97 fixture bridge status sources survive app-root composition
and ChatStore lookup for rendered ids only. Ready and rejected fixture status is
unchanged from source to root to store, hidden ids stay nil at every lookup
layer, and source order remains first-wins when composed with another
provider-status source.
A99 proves A97 fixture bridge status composes with the earlier A89/A90
request/result and A93 dispatch status sources through app-root and ChatStore
lookup. Fixture-first keeps fixture audit copy, adapter-first keeps
request/result copy, dispatch-first keeps dispatch copy, hidden ids from all
three sources stay nil, and selected text does not mix query, hidden host, or
execution claims from lower-priority sources.
A100 proves Search API adapter cost and entitlement outcomes remain explicit
across A86 request decisions, A91 payloads, A92 dispatch receipts, A96 fixture
bridge responses, and A97 status copy. Included-quota and metered-premium paths
remain distinct, while missing-entitlement, blocked-cost, private-privacy, and
free-local paths stay non-success and never create fixture-ready, dispatch
eligible, or premium-metered status.
A101 proves Search API adapter source, citation, and attribution outcomes stay
explicit across A86 request/result metadata, A91 payloads, A92 dispatch
receipts, A96 fixture bridge responses, and A97/A87 status copy. Accepted
source metadata preserves the selected source host plus citation-required
context, while source-policy blocked, citation-policy missing, result citation
missing, and result citation source mismatch paths stay non-success without
hidden host, query, raw page, or provider-execution leakage.
A102 proves Search API adapter result freshness, content, and limitations stay
explicit across A86 result receipts and A87 status copy. Live-preferred and
cached-ok result receipts preserve distinct freshness status, live-required
stale and missing-content receipts remain rejected/non-success, and limitation
metadata does not leak hidden hosts, query text, raw page content, or
provider-execution claims.
A103 proves the A102 result status matrix survives app-root provider-status
composition and ChatStore lookup for rendered recommendation ids only. Fresh,
cached, stale-live-required, and missing-content status copy remains unchanged
from source to root to store, hidden ids stay nil, and first-wins composition
with existing status sources remains deterministic without production
provider/runtime wiring.
A104 refreshes the research, market, UI, provider-policy, and interface cut
plan against current public papers, product docs, provider policies, and Search
API vendor docs. The selected next slice is a value-only Search API vendor
policy matrix because vendor pricing, quota, raw-content, citation/source,
freshness, and result-shape differences must be explicit before any live
provider call.
A105 adds that value-only Search API vendor policy matrix. It accepts or
rejects vendor metadata by enabled state, provider family, capability, privacy,
cost/quota/entitlement, freshness, citation/source/attribution, page-body,
retention, and result-shape requirements before any live provider call. The
next slice should expose those accepted/blocked decisions through the existing
provider-status side channel before any app-root or runtime integration.
A106 packages A105 vendor policy decisions into rendered-id scoped
provider-status copy. Accepted decisions show safe vendor/cost/freshness/result
metadata; blocked decisions preserve explicit rejection reasons; duplicate ids
keep the first decision; hidden and missing ids return nil. The next slice is an
app-root handoff proof so this status source can be consumed by ChatStore
without app/root/view generation or provider execution.
A107 proves that handoff. Vendor policy status sources now pass through
`AppBootstrap(providerStatusSources:)` and ChatStore lookup for rendered ids
only; accepted/rejected copy is unchanged from source to root to store; hidden
ids stay nil; source order remains first-wins. The next slice should make the
vendor decision an explicit dispatch authorization gate before any future
transport call.
A108 adds that gate. A92 dispatch receipts are authorized only when paired with
an accepted A105 vendor policy decision and matching provider, capability, cost,
freshness, and result-shape metadata. Missing dispatch, blocked dispatch,
missing vendor policy, rejected vendor policy, metadata mismatches, and result
shape mismatches stay rejected before any transport call. The next slice should
publish these authorization results through the existing rendered-id scoped
provider-status channel.
A109 publishes those authorization results through the existing provider-status
channel. Authorized results expose safe dispatch/vendor metadata copy; rejected
results preserve explicit authorization, dispatch, and vendor-policy reasons;
duplicate ids keep the first authorization; hidden and missing ids return nil.
The next slice is an app-root handoff proof so this status source can be
consumed by ChatStore without root/view generation or provider execution.
A110 proves that handoff. Dispatch authorization status sources now pass
through `AppBootstrap(providerStatusSources:)` and ChatStore lookup for
rendered ids only; authorized/rejected copy remains unchanged from source to
root to store; hidden and missing ids return nil; source order remains
first-wins. The next slice should prove the vendor policy, payload dispatch,
and dispatch authorization status layers compose without stale detail mixing.
A111 proves that cross-stage composition. A106 vendor policy status, A93
payload dispatch status, and A109 dispatch authorization status now compose
deterministically through app-root and ChatStore lookup; vendor-first,
dispatch-first, and authorization-first ordering all select the first source
exactly; hidden ids stay nil; selected copy does not mix later vendor,
dispatch, authorization, query, source-host, or execution detail. The next
slice introduced a value-only transport lease and cost-budget guard before any
future Search API endpoint can be considered.
A112 adds that lease gate. A91 payload metadata, A92 dispatch receipts, A108
dispatch authorization, and an explicit budget context now issue or reject a
safe Search API transport lease. Missing/rejected payloads, missing/blocked
dispatch, missing/rejected authorization, metadata mismatch, source/citation
policy failure, entitlement denial, included-quota exhaustion, metered
eligibility absence, and explicit cost-class budget denial all stop before any
endpoint, credential, transport, crawler/MCP runtime, or provider execution.
The next slice should publish those lease results through the existing
rendered-id scoped provider-status channel.
A113 publishes those lease results. Issued leases expose safe lease, vendor,
budget, provider, capability, cost, freshness, result-shape, result-limit,
source-state, and citation-required metadata as advisory status copy. Rejected
leases preserve explicit lease rejection plus nested payload, dispatch, and
authorization reasons; hidden and missing rendered ids return nil; duplicate
ids keep the first lease; copy does not expose query text, source host,
endpoint, credentials, raw provider/page content, or execution claims. The next
slice should prove this status source survives the app-root and ChatStore
handoff unchanged.
A114 proves that handoff. A113 transport lease status sources now pass through
`AppBootstrap(providerStatusSources:)` and ChatStore lookup for rendered ids
only; issued/rejected copy remains unchanged from source to root to store;
hidden and missing ids return nil; source order remains first-wins. The next
slice should prove vendor policy, payload dispatch, dispatch authorization, and
transport lease status layers compose without stale detail mixing.
A115 proves that cross-stage composition. A106 vendor policy status, A93
payload dispatch status, A109 dispatch authorization status, and A113 transport
lease status now compose deterministically through app-root and ChatStore
lookup; vendor-first, dispatch-first, authorization-first, and lease-first
orders all select the first source exactly; hidden ids stay nil; selected copy
does not mix later vendor, dispatch, authorization, lease, budget, query,
source-host, or execution detail. The next slice should refresh the external
research/market/provider cut-plan before deciding whether any live Search API
provider runtime can be introduced safely.
A116 completes that refresh. Current agent papers, MCP threat work, Search API
vendor docs, Google/Gaode policy surfaces, and iOS local-first constraints all
point to the same next prerequisite: do not start live Search API transport
until kAir has a value-only server-provider metered entitlement ledger that can
normalize membership, quota period, unit accounting, and provider/vendor budget
state before any endpoint or SDK exists.
A117 adds that ledger. kAir can now evaluate server-verified provider/vendor
budget snapshots and usage requests by membership, entitlement, quota period,
unit/currency, cost class, privacy/Health context, freshness, provider/vendor/
capability match, disabled vendor, stale snapshot, duplicate reservation, and
over-budget state. The next slice should expose those accepted/blocked budget
decisions through the existing provider-status side channel before app-root or
runtime wiring.
A118 exposes those decisions through the existing provider-status side channel.
Accepted included-quota and metered decisions now produce rendered-id scoped
budget-ready copy with safe provider/vendor/quota/unit/cost/freshness metadata.
Rejected decisions expose the explicit A117 denial reason without hidden budget
internals. Hidden and missing ids return nil, duplicate ids keep the first
decision, and no app-root, ChatStore, UI, StoreKit, transport, MCP/crawler,
Google/Gaode SDK, memory, or provider execution behavior changed. The next
slice should prove this source survives app-root and ChatStore handoff unchanged.
A119 proves that handoff. A118 status sources now pass through
`AppBootstrap(providerStatusSources:)` and ChatStore lookup for rendered ids
only. Accepted included-quota and metered copy, rejected over-budget/privacy/
provider-mismatch copy, hidden/missing nil lookup, and source-order first-wins
remain stable from source to app root to ChatStore. The next slice should prove
metered entitlement status composes with the already-built vendor, dispatch,
authorization, and lease status layers without stale detail mixing.
A120 proves that composition. A118 metered entitlement status, A106 vendor
policy status, A93 payload dispatch status, A109 dispatch authorization status,
and A113 transport lease status now compose through
`AppBootstrap(providerStatusSources:)` and ChatStore lookup in multiple source
orders. The first source wins exactly for ready and blocked rendered ids,
hidden/missing ids stay nil, and selected copy does not mix stale budget,
vendor, dispatch, authorization, lease, query, source-host, or execution detail.
The next slice should refresh the external research, market, provider, MCP, and
agent-architecture evidence before deciding whether any real-provider runtime
precursor can move beyond value-only gates.
A121 completes that refresh. Current cost-aware agent research, MCP
spec/security work, Apple iOS docs, Search API vendor docs, Google/Gaode
provider policy surfaces, crawler policy, and life-service agent evidence all
point to the same next prerequisite: do not start live provider runtime yet.
First prove A112 transport lease issuance can be driven by accepted A117
metered entitlement budget contexts, and that rejected or mismatched entitlement
decisions cannot issue leases.
A122 proves that handoff. A112 budget contexts now carry A117 metered decision
metadata, and the lease gate rejects missing/generic budget contexts plus
provider, vendor, capability, cost-class, and freshness mismatches before lease
issuance. Accepted included-quota and metered-premium decisions can issue leases
only when payload, dispatch, vendor authorization, source, citation, and budget
metadata all match. The next slice should prove those metered-derived issued and
rejected leases package into provider-status copy and survive app-root/ChatStore
handoff.
A123 proves that status handoff. A122 issued included-quota and metered-premium
leases, plus rejected `meteredEntitlementMissing` and `vendorMismatch` leases,
now package into provider-status copy and pass through app-root/ChatStore lookup
without hidden/missing id leakage. Source order remains first-wins against a
lower-priority fallback lease source. The next slice should prove this
metered-derived lease status composes with the other status layers without stale
detail mixing.
A124 proves that composition. A123 metered-entitlement transport lease status
now composes with A118 metered entitlement, A106 vendor policy, A93 payload
dispatch, and A109 dispatch authorization status through app-root/ChatStore
lookup. The selected first source wins for both ready and blocked
recommendations, hidden/missing ids remain nil, and lower-priority
budget/vendor/dispatch/authorization/lease details do not bleed into selected
copy. The next slice should refresh the research and provider cut-plan against
this completed metered lease composition stack before any live runtime decision.
A125 refreshed that decision. Current papers, MCP/security direction, Apple
platform docs, Google/Gaode/Search provider policy, and competitor signals still
do not justify live provider runtime from iOS. The next missing proof is a
metadata-only Search API transport request contract that binds an issued A122
lease to the exact upstream request/payload/dispatch/vendor/authorization/source/
citation/cost/freshness/metered-decision chain.
A126 adds that request contract. Issued metered-entitlement Search API leases
can now prepare request decisions only when upstream ids and typed metadata
still match; rejected leases, generic budget contexts, stale metadata, missing
metered decision ids, source/citation drift, and result-shape/cost/freshness
mismatches reject before runtime. The next slice should package those decisions
into rendered-id scoped provider-status copy before app-root handoff.
A127 adds that status source. Prepared and rejected A126 request decisions now
project into rendered-id scoped provider-status copy with stable badges/card
hints, duplicate first-wins behavior, hidden/missing nil lookup, nested
rejection reasons, and safe source/citation summary copy. The next slice should
prove that A127 source passes through the app composition root and ChatStore
lookup unchanged before any cross-stage composition or live provider work.
A128 adds that handoff proof. Request-status sources now pass through
`AppBootstrap(providerStatusSources:)` and ChatStore lookup unchanged for
rendered ids only; hidden/missing ids stay nil, source order stays first-wins,
and selected copy does not mix later request/vendor/lease/budget/metered or
rejection details. The next slice should compose request status with the
existing metered entitlement, vendor policy, payload dispatch, dispatch
authorization, and lease status layers.
A129 adds that composition proof. Request status now composes with metered
entitlement, vendor policy, payload dispatch, dispatch authorization, and
transport lease status through app-root/ChatStore lookup without stale detail
mixing. The next slice should refresh external research and provider policy
evidence before selecting any runtime-adjacent code gate.
A130 completes that refresh. Current cost-aware routing papers, MCP/security
work, Apple platform docs, Google/Gaode policy surfaces, Search API vendor
docs, crawler/robots policy, and public competitor/life-service signals still
do not justify live provider runtime, maps SDK/runtime, MCP/crawler runtime,
payment/booking, remote model runtime, or hidden third-party app control. The
next missing proof is a response receipt that binds normalized/cited Search API
result metadata to the exact A126 transport request and its metered, vendor,
lease, source, citation, cost, and freshness chain.
A131 adds that response receipt contract. Accepted response decisions now bind
normalized/cited adapter result receipts to the prepared transport request and
reject missing/rejected request or result decisions, request/provider/
capability/cost/freshness mismatches, result-limit overflow, source/citation
drift, normalized-content gaps, and missing vendor/lease/budget/metered
metadata before any live transport or provider execution. The next slice should
package those decisions into rendered-id scoped provider-status copy.
A132 adds that status source. Accepted and rejected response decisions now
project into rendered-id scoped provider-status copy with stable badges/card
hints, duplicate first-wins behavior, hidden/missing nil lookup, nested request
and result rejection reasons, and safe result/citation count summary copy. The
next slice should prove that A132 source passes through the app composition root
and ChatStore lookup unchanged before any cross-stage composition or live
provider work.
A133 adds that handoff proof. Response-status sources now pass through
`AppBootstrap(providerStatusSources:)` and ChatStore lookup unchanged for
rendered ids only; hidden/missing ids stay nil, source order stays first-wins,
and selected copy does not mix later response/request/result/vendor/lease/
budget/metered or rejection details. The next slice should compose response
status with the existing metered entitlement, vendor policy, payload dispatch,
dispatch authorization, lease, and request status layers.
A134 adds that composition proof. Response status now composes with metered
entitlement, vendor policy, payload dispatch, dispatch authorization, transport
lease, and transport request status through app-root/ChatStore lookup without
hidden-id leakage or stale detail mixing. The next slice should add a
value-only external provider transport adapter interface preflight so future
Search API, Google/Gaode maps, crawler, and MCP paths can share explicit cost,
membership, entitlement, source, attribution, privacy, and UI-safe status gates
before any live provider runtime.
A135 adds that preflight interface. `ServerProviderTransportAdapter` descriptors
now cover future Search API, Google/Gaode maps, crawler, and MCP paths with
explicit provider family, capability, membership, cost, entitlement, source/
attribution, privacy, disabled-by-default, confirmation, metered decision, and
lease requirements. The preflight decisions stay value-only and deterministic;
tests cover accepted metadata paths plus membership, entitlement, privacy,
source, attribution, disabled crawler/MCP, unsupported capability, blocked
cost, stale budget, and lease mismatch rejection. The next slice should project
those decisions into rendered-id scoped provider-status copy before any
app-root handoff or live provider runtime.

A136 adds that status projection. External provider transport adapter preflight
decisions now package into rendered-id scoped provider-status copy for future
Search API, Google/Gaode maps, crawler, and MCP paths. The copy is advisory,
accepted/rejected, badge/card-hint stable, hidden-id safe, and free of endpoint,
credential, SDK, URLSession, crawler/MCP runtime, maps SDK, payment, booking,
hidden app-control, completion, or execution claims. The next slice should prove
that this new status source survives app-root composition and ChatStore lookup
with rendered-id filtering and source-order first-wins before any live provider
runtime.

A137 adds that app-root handoff proof. The external provider transport adapter
status source now survives `AppBootstrap(providerStatusSources:)` and ChatStore
lookup for rendered ids only across accepted/rejected Search API, Google/Gaode
maps, crawler, and MCP decisions. Hidden/unrendered and missing ids remain nil,
exact source-to-root-to-store copy is preserved, and source-order first-wins
prevents stale later-source provider/capability/cost/metered/lease details from
mixing into selected copy. The next slice should compose this preflight status
with the existing metered/vendor/dispatch/authorization/lease/request/response
status stack before any live provider runtime.

A138 adds that cross-stage composition proof. External provider transport
adapter preflight status now composes with Search API metered entitlement,
vendor policy, payload dispatch, dispatch authorization, transport lease,
transport request, transport response, and generic fallback status sources
through AppBootstrap and ChatStore. It also covers a non-Search Gaode preflight
source with fallback ordering. The status stack remains first-source-wins,
hidden/missing nil safe, and free of stale provider/cost/source/metered/lease/
request/response/preflight/fallback detail mixing. The next slice should refresh
current research and market evidence before choosing whether A140 can safely
widen toward real provider transport.

A139 performs that research/market/provider refresh. Current agent, MCP, Apple,
Google/Gaode, Search API, crawler, and visible life-service-agent evidence does
not justify live provider transport yet. The right next slice is a value-only
external provider transport audit trace and evaluation contract: future Search
API, Google/Gaode, crawler, MCP, and remote model attempts need typed audit-safe
metadata for cost, privacy, source/citation/attribution, membership,
status-source selection, user confirmation, rejection reasons, and evaluation
dimensions before any endpoint, SDK, URLSession, crawler/MCP runtime, payment,
booking, hidden app control, or real execution exists.

A140 adds that value-only audit trace/evaluation contract. The new
`ServerProviderTransportAuditTrace` / `ServerProviderTransportAuditEvent`
contract represents accepted and rejected future provider attempts across
Search API, Google/Gaode maps, crawler, MCP, and remote model families without
transport. Tests cover accepted families, missing policy inputs, unsupported
capability, blocked cost/privacy, disabled crawler/MCP, missing confirmation,
missing evaluation dimensions, unsafe runtime material, deterministic safe-copy
encoding, and explicit evaluation labels. The next slice should project these
events into rendered-id scoped provider-status copy before any app-root
composition or live provider transport.

A141 adds that status projection. A140 audit events now package into
rendered-id scoped provider-status copy with accepted/rejected status lines,
provider/cost/evaluation badges, disabled rejection hints, duplicate
first-wins behavior, hidden/missing nil lookup, and no stale provider/cost/
privacy/status-source/evaluation detail mixing. The next slice should prove
that this optional source survives AppBootstrap injection and ChatStore lookup
before composing it with the full status stack.

A142 adds that app-root handoff proof. The A141 audit-event status source now
passes through `AppBootstrap(providerStatusSources:)` and ChatStore lookup for
rendered ids only. Tests cover accepted Search API audit status, accepted
remote-model audit status, rejected privacy-blocked audit status, hidden/missing
nil lookup, exact source-to-root-to-store copy, and fallback source-order
first-wins without changing production defaults.

A143 adds cross-stage composition. A141 audit-event status now composes with
metered entitlement, vendor policy, payload dispatch, dispatch authorization,
transport lease, transport request, transport response, transport adapter
preflight, and fallback status sources through AppBootstrap and ChatStore.
Source-order first-wins holds when audit is first, when an existing Search API
status-stack source is first, and when fallback is first; non-Search remote
model audit status also composes with fallback ordering. The next slice can
start the live-transport cut-plan, but it should begin as comment-programming
and readiness proof, not a network call.

A144 adds that live-transport boundary comment-programming artifact. The
Search API live-transport boundary is now a compile-safe, value-only planning
document with the required upstream chain, runtime readiness checklist, nil
runtime entry point, non-callable state, deterministic safe copy, and forbidden
material tests. It still performs no network call and does not wire provider
runtime, AppBootstrap defaults, ChatStore behavior, SwiftUI, telemetry, raw
payload ingestion, payment/booking/order flow, hidden app-control, or real
provider execution.

A145 adds the readiness gate for that boundary. The gate consumes the A144
boundary document and explicit safe evidence ids, accepts only when every
upstream checkpoint and readiness item is covered, rejects missing evidence,
duplicate evidence ids, unknown targets, callable runtime entrypoints, stale
boundary ids, unsafe material markers, and live-provider-path enablement, and
keeps safe copy planning-only with no live transport material.

A146 adds the rendered-id scoped provider-status projection for that readiness
gate. Accepted readiness becomes advisory planning-evidence status with the
provider path still disabled; rejected readiness becomes stable disabled/warning
badge copy. Duplicate ids keep the first input, hidden/missing ids return nil,
and the status copy does not carry raw evidence, unsafe markers, provider
runtime details, or live transport material.

A147 adds the app-root handoff proof for that readiness status. The A146 status
source now passes through `AppBootstrap(providerStatusSources:)` and ChatStore
lookup for rendered ids only. Accepted and rejected status copy is identical
from source to root to store, hidden/missing ids stay nil, and fallback
source-order first-wins remains deterministic without changing production
defaults.

A148 composes that readiness status with the earlier Search API status stack
inside `AppBootstrap(providerStatusSources:)` and ChatStore. Readiness-first,
earlier-stack-first, and fallback-first source orders now preserve first-wins
selection, exact root-to-store copy, hidden/missing nil lookup, and selected
copy isolation from stale readiness, fallback, metered, vendor, dispatch,
authorization, lease, request, response, preflight, audit, endpoint,
credential, SDK/client, crawler/MCP, maps runtime, raw payload,
payment/booking/order, hidden app-control, or provider execution details.

A149 refreshes current market, paper, open-source-agent, MCP, Search API, maps,
and crawler evidence after A148. The decision is explicit: **A150 should not
start live Search API transport**. Current sources show that vendors differ too
much on pricing units, QPS/quota, answer-vs-result shape, citation/source
support, raw-content controls, retention, latency, region, and enterprise terms
to pick an endpoint safely from the existing generic Search API family. The
next missing proof is a value-only vendor candidate selection and cost-policy
matrix.

A150 adds that value-only vendor candidate selection and cost-policy matrix.
It models Search API live vendor candidates, selection requests, selected/
rejected decisions, duplicate-id first-wins, ordered safe candidate summaries,
deterministic rejection reasons, and safe copy. Tests cover capability,
freshness, result shape, citation/source support, page-body and retention
policy, privacy, region, quota/QPS, max cost, disabled vendors, missing quota,
Health/private blocks, duplicate ids, empty lists, Codable/Hashable/Sendable
behavior, and safe-copy forbidden-fragment checks without introducing any
runtime networking, endpoint, credential, provider adapter, AppBootstrap,
ChatStore, SwiftUI, payment, booking, order, hidden app-control, or real
provider behavior.

A151 adds the rendered-id scoped status-source projection for A150 decisions.
Selected live vendor choices now render advisory warning copy with Search API,
candidate-policy, and cost badges; rejected choices render disabled warning copy
with stable rejection badges. The source preserves duplicate recommendation-id
first-wins, hidden/missing nil lookup, safe-copy only status text, and no live
transport/provider behavior.

A152 adds the app-root handoff proof for A151. Focused AppBootstrap tests now
prove selected/rejected live vendor selection status passes through
`AppBootstrap(providerStatusSources:)` and ChatStore lookup exactly, preserves
hidden/missing nil lookup, and keeps fallback source-order first-wins from
leaking stale fallback detail into selected status copy.

A153 adds the cross-stage composition proof for A151. Focused AppBootstrap
coverage now composes live vendor selection with the Search API status stack
through root and ChatStore lookup. Live vendor selection, metered entitlement,
vendor policy, dispatch, authorization, lease, request, response, preflight,
audit, and fallback sources are each tested as the first source. Root and store
copy stay identical, hidden/missing ids stay nil, and later source markers do
not leak into the selected presentation.

A154 refreshes market, UI, paper, open-source-agent, MCP/search/crawler, maps,
Search API vendor, and provider-constraint evidence after A153. The decision is
not to add runtime networking yet. A155 may start a narrow live-transport proof
only as a comment-programming/value-only server adapter interface that binds the
existing vendor, cost, lease, request, response, audit, boundary, and status
contracts without becoming runtime-callable.

A155 adds that Search API live transport server adapter interface proof. The
new metadata-only descriptor, request, summary, decision, and safe-copy values
bind selected vendor, metered entitlement, lease, transport request, audit,
boundary, readiness, result/freshness/cost/source requirements, region,
kill-switch, retry policy, and server-owned secret mode while keeping
`isRuntimeCallable == false`. Focused tests cover accepted matching descriptors,
deterministic rejection reasons, duplicate descriptor first-wins, Codable/
Hashable/Sendable behavior, and forbidden-fragment copy checks without runtime
networking or provider execution.

A156 packages those accepted/rejected adapter interface decisions into a
rendered-id scoped provider-status source. Accepted copy is advisory and names
Search API interface, candidate adapter policy, cost, and source-state metadata;
rejected copy is disabled with stable privacy, cost/quota, terms/source,
readiness, or unavailable badges. Duplicate recommendation ids remain
first-wins, hidden/missing ids stay nil, and the status copy preserves
`isRuntimeCallable false` without widening into AppBootstrap, ChatStore, UI,
networking, or provider runtime behavior.

A157 proves that A156 status source passes through the composition root and
ChatStore lookup. Accepted and rejected copy stays identical from source to root
to store, hidden/missing ids stay nil, and source-order first-wins against
fallback provider status prevents stale fallback copy from leaking into the
selected A156 presentation.

A158 composes the A156 adapter interface status source with the existing Search
API status stack. Adapter interface, live vendor selection, readiness, metered
entitlement, vendor policy, dispatch authorization, lease, request, response,
preflight, audit, and fallback sources are each tested as first source through
AppBootstrap and ChatStore lookup. Root/store copy stays identical,
hidden/missing ids stay nil, and later-source markers do not leak into the
selected presentation.

A159 refreshed the current paper/product/provider evidence after A158. The
result does not justify direct live Search API transport yet. It selects a
server-side invocation preflight contract as the next narrow proof: accepted
adapter interface, selected vendor, metered entitlement, lease, transport
request, boundary/readiness, source policy, budget, region, and audit metadata
must join into one non-callable receipt before any real provider path exists.

A160 adds that value-only invocation preflight proof. Accepted decisions require
adapter-interface, selected vendor, metered entitlement, lease, request, audit,
boundary/readiness, cost, source, region, privacy, retention, server-secret,
budget, and purpose metadata to match. Rejected paths cover runtime-callable
flags, unsupported provider families, upstream id mismatch, stale readiness,
expired leases, source/citation/attribution gaps, privacy/Health blocks,
duplicate preflight ids, and policy conflicts. The receipt remains non-callable
and does not add runtime transport, AppBootstrap defaults, UI, crawler/MCP,
maps SDK, payment/booking/order, hidden app-control, or execution claims.

A161 packages A160 preflight decisions into rendered-id scoped provider status.
Accepted copy is advisory only and exposes Search API preflight, descriptor/
vendor, cost, source, region, budget, and `isRuntimeCallable false`; rejected
copy is disabled with stable privacy, cost, readiness, source/terms, region,
duplicate, and unavailable badge mappings. Duplicate recommendation ids keep
first-wins and hidden/missing rendered ids return nil. No AppBootstrap handoff,
UI, networking, crawler/MCP, maps SDK, payment/booking/order, hidden
app-control, provider call, or execution claim was added.

A162 proves the A161 preflight status source can pass through
`AppBootstrap(providerStatusSources:)` and ChatStore rendered-id lookup.
Accepted/rejected copy stays identical from source to root to store,
hidden/missing ids stay nil, and both direct `providerStatusProvider` plus
ordered `providerStatusSources` keep first-wins against fallback status. The
selected copy remains advisory with `isRuntimeCallable false`; no production
AppBootstrap defaults, ChatStore behavior, UI, networking, crawler/MCP,
Google/Gaode SDK, payment/booking/order, hidden app-control, provider call, or
execution claim was added.

A163 proves A161 preflight status can compose with the existing Search API
status stack through AppBootstrap and ChatStore. Invocation preflight, adapter
interface, live vendor selection, readiness, metered entitlement, vendor policy,
dispatch, authorization, lease, request, response, transport preflight, audit,
and fallback sources are each tested as first source. Root/store copy stays
identical to the selected source, hidden/missing ids stay nil, and later source
markers do not leak into selected copy. The proof is still test-only and does
not add production root/UI/runtime/provider behavior.

## 9. Next Direct Coding Point

A183 added a pure `ServerProviderServiceCutPlanStatusSourceProducer` and
focused tests. It packages A182 decisions into rendered-id scoped
`ProviderStatusPresentation` copy with stable badges, card hints, first visible
input wins, hidden/missing nil lookup, and value-only status text. It proves
local, Google/Gaode, Search API, crawler, MCP, privacy-blocked, and unsupported
decisions remain `isRuntimeCallable false` and `isExecutable false`. A183 still
does not add production defaults, UI, networking, provider adapters,
crawler/MCP runtime, maps SDK runtime, Search API calls, provider calls,
execution claims, or completion claims.

Start **A184 Provider Service Cut-Plan Status App-Root Handoff** next.

```text
Task: Implement A184 as a test-only app-root handoff proof for the A183 provider
service cut-plan status source. Treat prior agent reports as untrusted. Compose
A183 sources through `AppBootstrap(providerStatusSources:)`, then prove
`ChatStore` reads the same rendered-id scoped `ProviderStatusPresentation` copy.

Hard non-goals:
- Do not add or change production AppBootstrap defaults, ChatStore behavior,
  recommendation ranking, SwiftUI/UI, navigation, telemetry emit sites,
  transcript writes, memory writes, provider adapters, URLSession/networking,
  endpoint URLs, API keys, OAuth tokens, bearer tokens, credentials, SDK/client
  handles, StoreKit/payment, booking/order flows, crawler runtime, MCP client
  runtime, Google/Gaode SDKs, Search API calls, remote model runtime, concrete
  vendor selection, provider calls, execution claims, or completion claims.
- Do not expose raw query text, raw page/provider payloads, source bodies,
  private Health/location data, prompt text, credentials, endpoint URLs,
  crawler payloads, MCP descriptors, maps SDK details, payment/order data, or
  hidden app-control state in status/debug/encoded copy.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Read first:
- kAir/Core/Networking/ServerProviderServiceCutPlan.swift
- kAir/Core/Networking/ServerProviderServiceCutPlanStatusSourceProducer.swift
- kAirTests/Networking/ServerProviderServiceCutPlanStatusSourceProducerTests.swift
- kAir/App/AppEntry/AppBootstrap.swift
- kAir/Features/Chat/Data/ChatStore.swift
- Existing provider-status AppBootstrap tests in `kAirTests/App/AppBootstrapTests.swift`

Implementation frame:
- Add focused A184 tests in `AppBootstrapTests.swift`; production Swift code
  should stay unchanged unless a compile-only access issue is discovered.
- Build local-ready, server-reserved, blocked, and unsupported A182 decisions
  with the existing `ServerProviderServiceCutPlanner` helpers or equivalent
  value-only fixtures inside the test file.
- Build an A183 source with `ServerProviderServiceCutPlanStatusSourceProducer`
  and pass it through `AppBootstrap(providerStatusSources:)`.
- Construct `ChatStore` the same way existing app-root handoff tests do, using
  `bootstrap.recommendationProvider`, `bootstrap.providerStatusProvider`, and
  the existing bootstrap dependencies.
- Add only short test comments around the new A184 block to explain the
  app-root handoff proof; do not add production comments.

Acceptance:
- Tests prove source -> AppBootstrap -> ChatStore copy equality for local-ready,
  server-reserved, blocked, and unsupported decisions.
- Tests prove first-source-wins order against a fallback/lower-priority status
  source and prove no fallback marker leaks when the A183 source is first.
- Tests prove duplicate recommendation ids keep the first visible input, hidden
  inputs and missing ids return nil, and rendered-id scoping survives through
  AppBootstrap and ChatStore.
- Tests prove selected copy contains lane, service intent, provider family,
  capability, membership tier, region, privacy class, cost class, required gate
  ids, block reason ids, status source id/rank, `isRuntimeCallable false`, and
  `isExecutable false`.
- Tests prove status/debug/encoded copy contains no endpoint URL, API key,
  OAuth token, bearer token, credential, URLSession, URLRequest, SDK/client
  handle, raw query, raw page/provider payload, crawler/MCP runtime detail,
  maps SDK detail, StoreKit/payment/order/booking data, hidden app-control,
  provider call, execution claim, or completion claim.
- A184 does not change production AppBootstrap defaults, ChatStore behavior,
  UI, telemetry, transcript, memory-code, provider adapter, networking,
  crawler/MCP, maps SDK, payment, booking/order, remote model runtime, concrete
  vendor selection, or real provider behavior.

Verification:
- Run focused `AppBootstrapTests` for the new A184 tests.
- Run full `test_sim`.
- Run forbidden-fragment scan for touched Swift diffs.
- Run touched-file trailing-whitespace scan.
- Run A183/A184 doc consistency scan.
- Run `git diff --check`.
- Run `git status --short` and confirm A184 touched only the allowed test file
  and architecture docs.
```
