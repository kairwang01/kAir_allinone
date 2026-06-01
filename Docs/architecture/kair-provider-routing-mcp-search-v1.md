# kAir Provider Routing, MCP, Search, and Life-Service Architecture v1

Status: architecture blueprint, comment-first.
Last updated: 2026-06-01.

This document extends the base super-app architecture with provider
routing, map/search provider switching, membership/cost policy, MCP
interface reservation, and life-service public-information retrieval.

## 1. Why This Exists

kAir must support multiple service providers without hardcoding one
vendor into the product:

- iOS local/default path: Apple frameworks and on-device models.
- Premium maps/search path: Gaode, Google, or future partners.
- Premium model path: server-gated market models.
- Research/search path: search APIs, crawlers, MCP tools.

The provider decision must be explicit because provider choice affects:

- cost,
- privacy,
- region quality,
- freshness,
- terms of service,
- user entitlement,
- execution trust.

## 2. Core Abstractions

```text
ProviderRouter
  input: ProviderRequest
  reads: ProviderRegistry, MembershipState, CostPolicy, PrivacyGuard
  output: ProviderSelection

ProviderRegistry
  owns: descriptors for AppleLocal, Gaode, Google, SearchAPI, Crawler, MCP

CostPolicy
  owns: free/included/premium/metered budgets and fallback order

ProviderAdapter
  owns: one provider's typed API surface and normalized result mapping

ProviderTrace
  records: selected provider, skipped providers, cost reason, privacy reason
```

Provider routing is not the same as capability routing:

- `CapabilityRouter`: routePlanning, placeSearch, webSearch,
  localServiceSearch, etc.
- `ProviderRouter`: Apple MapKit vs Gaode vs Google vs cache vs search API.

## 2.1 Current Pure Contract Status

As of 2026-05-31, the contract-first implementation exists through the
projection/status side channel:

| Gate | Files | Status |
|---|---|---|
| A5b provider routing | `ProviderRoutingPolicy.swift`, `MapProviderDescriptor.swift` | Pure value contracts and tests; no SDK/network/API key. |
| A5c search/MCP reservation | `SearchProvider.swift`, `MCPGateway.swift` | Search/crawler/MCP policy contracts and tests; no runtime. |
| A5d result projection | `ResultProjector.swift` | Provider/search/MCP decisions normalize into projection envelopes. |
| A5e recommendation bridge | `ProjectedRecommendation.swift` | Projected results adapt to `MatchingObject` while preserving metadata out of band. |
| A5f/A5g status seam | `ProviderStatusBadgeModel.swift`, `ChatStore.providerStatusPresentation(for:)` | Provider/cost/freshness status is available as a side channel without changing the frozen card model. |
| A11 transport envelope | `ServerTransport.swift`, `ServerTransportEnvelopeTests.swift` | Server-provider envelopes, validation, audit records, and mock transport exist as pure contracts; no runtime provider call. |
| A12 envelope factory | `ServerProviderEnvelopeFactory.swift`, `ServerProviderEnvelopeFactoryTests.swift` | Provider/search/MCP policy decisions become executable envelopes only after quota, entitlement, source, confirmation, privacy, and validator gates pass. |
| A13 dry-run evaluator | `ServerProviderDryRunEvaluator.swift`, `ServerProviderDryRunEvaluatorTests.swift` | Candidate envelopes produce audit-only selected/blocked/fallback traces without executing transport. |
| A14 dry-run presentation | `ServerProviderDryRunPresentation.swift`, `ServerProviderDryRunPresentationTests.swift` | Dry-run reports project into UI-safe advisory rows and badges while preserving cost, freshness, source, privacy, rejection, and fallback metadata. |
| A15 dry-run status bridge | `ProviderStatusBadgeModel.swift`, `ProviderStatusBadgeModelTests.swift` | Dry-run presentations adapt into `ProviderStatusPresentation` without changing rail layout, matching object kinds, or trust-pill vocabulary. |
| A16 execution readiness | `ServerProviderExecutionGate.swift`, `ServerProviderExecutionGateTests.swift` | Envelope factory results become local-only, server-ready, confirmation-required, or blocked decisions before any transport runtime can exist. |
| A17 runtime registry | `ServerProviderRuntimeRegistry.swift`, `ServerProviderRuntimeRegistryTests.swift` | Server-ready decisions can resolve metadata-only runtime descriptors for remote providers; local-only, blocked, and confirmation-required decisions resolve none. |
| A18 invocation plan | `ServerProviderRuntimeInvocationPlan.swift`, `ServerProviderRuntimeInvocationPlanTests.swift` | Readiness plus descriptor lookup becomes a value-only invocation plan; local-only, blocked, confirmation-required, and descriptor-missing decisions remain non-executing. |
| A19 dispatch boundary | `ServerProviderRuntimeDispatch.swift`, `ServerProviderRuntimeDispatchTests.swift` | Planned invocation metadata becomes a prepared dispatch-boundary value only when plan metadata is well-formed; all other states remain non-executing. |
| A20 adapter protocol/result | `ServerProviderRuntimeAdapter.swift`, `ServerProviderRuntimeAdapterTests.swift` | Prepared dispatch boundaries can produce fixture-only adapter results; malformed, non-prepared, and provider-mismatched boundaries remain non-executing. |
| A21 adapter registry/selection | `ServerProviderRuntimeAdapterRegistry.swift`, `ServerProviderRuntimeAdapterRegistryTests.swift` | Prepared boundaries select registered fixture adapters by provider family; local-only, blocked, confirmation-required, malformed, and unregistered-provider boundaries remain non-executing. |
| A22 runtime receipt projection | `ServerProviderRuntimeReceipt.swift`, `ServerProviderRuntimeReceiptTests.swift` | Adapter results project into UI/audit-safe receipts; fixture, local-only, blocked, confirmation, descriptor, plan, malformed, and unavailable states remain truthful and non-executing. |
| A23 receipt status bridge | `ProviderStatusBadgeModel.swift`, `ProviderStatusBadgeModelTests.swift` | Runtime receipts adapt into the existing provider-status side channel without changing rail layout, object kinds, trust-pill vocabulary, or claiming execution. |
| A24 receipt status lookup | `ProviderStatusBadgeModel.swift`, `ProviderStatusBadgeModelTests.swift` | Runtime receipts can be stored by recommendation id and exposed through `ProviderStatusProviding` without mutating `MatchingObject` or claiming execution. |
| A25 provider status multiplexer | `ProviderStatusBadgeModel.swift`, `ProviderStatusBadgeModelTests.swift` | Ordered `ProviderStatusProviding` sources can compose receipt-derived and projected status deterministically without knowing source internals. |
| A26 ChatStore status injection | `ChatStore.swift`, `ProviderStatusLookupTests.swift` | ChatStore accepts an explicit provider-status source, preserves fallback behavior, and filters status to currently rendered recommendation ids. |
| A27 app status wiring | `AppBootstrap.swift`, `ChatHomeView.swift`, `AppBootstrapTests.swift` | AppBootstrap can carry an explicit `ProviderStatusProviding` source and ChatHomeView passes it into ChatStore without UI or provider-runtime changes. |
| A28 Chat status UI binding | `ChatHomeView.swift`, `ProviderStatusBadgeModel.swift`, `ProviderStatusBadgeModelTests.swift` | Chat Recommended Next cells can render optional provider-status badges and status lines through a pure display binding, while nil status preserves the prior UI. |
| A29 app recommendation provider wiring | `AppBootstrap.swift`, `ChatHomeView.swift`, `AppBootstrapTests.swift` | AppBootstrap carries a default-preserving `RecommendationProvider` and ChatHomeView passes it into ChatStore so projected provider ids can align with provider-status lookup without runtime changes. |
| A30 app status-source assembly | `AppBootstrap.swift`, `AppBootstrapTests.swift` | AppBootstrap can compose ordered `ProviderStatusProviding` sources with `ProviderStatusSourceMultiplexer` while preserving nil default/preview status and direct source identity. |
| A31 provider access profile | `ProviderAccessProfile.swift`, `ProviderAccessProfileTests.swift` | Membership tier, provider preference, metered entitlements, experimental enablement, unavailable providers, region, and cache-fallback defaults are centralized before `ProviderRequest` creation. |
| A32 provider access request bridge | `ProviderAccessProfile.swift`, `ProviderAccessProfileTests.swift` | The same access profile can now build `SearchProviderRequest` and `MCPGatewayRequest` values while keeping search source/robots and MCP confirmation inputs explicit. |
| A33 app/search intent access wiring | `AppBootstrap.swift`, `SearchIntent.swift`, `AppBootstrapTests.swift`, `SearchIntentTests.swift` | App composition can now carry a default-preserving `ProviderAccessProfile`, and SearchIntent can lower through that profile while keeping source mode, privacy, robots, freshness, result, cache, and timestamp explicit. |
| A34 search adapter access profile configuration | `SearchCapabilityAdapter.swift`, `SearchCapabilityAdapterTests.swift` | Search adapter configuration now carries `ProviderAccessProfile`, and adapter decisions lower through the same profile-based SearchIntent request path. |
| A35 reserved search adapter factory | `DefaultCapabilityRegistry.swift`, `DefaultCapabilityRegistryTests.swift` | A reserved factory can build profile-aware Search adapter configuration while the default shipped registry still leaves `.webSearch` unregistered. |
| A36 explicit reserved search registry composition | `DefaultCapabilityRegistry.swift`, `DefaultCapabilityRegistryTests.swift` | The shipped registry can opt into a caller-built `SearchCapabilityAdapter` and register `.webSearch` only when supplied, while the default registry remains local-only. |
| A37 app-bootstrap reserved search opt-in | `AppBootstrap.swift`, `AppBootstrapTests.swift` | AppBootstrap can assemble a reserved Search adapter/configuration only through explicit opt-in while default, preview, and direct custom-registry injection stay local-only/default-preserving. |
| A38 chat Search availability propagation | `ChatStoreCapabilityConsumerTests.swift` | Search availability assembled by AppBootstrap reaches ChatStore capability snapshots, including enabled and disabled Search configs, without transcript or recommendation mutations. |
| A39 chat Search availability presentation | `ChatStore.swift`, `ChatStoreCapabilityConsumerTests.swift` | ChatStore exposes a pure three-state Search availability value derived only from `.webSearch` availability, with factual copy and no execution side effects. |
| A40 chat Search availability display model | `ChatStore.swift`, `ChatStoreCapabilityConsumerTests.swift` | ChatStore maps the Search state to stable icon/tone/accessibility copy for future UI binding without rendering UI or executing Search. |
| A41 chat Search availability UI binding | `ChatHomeView.swift`, `ChatStoreCapabilityConsumerTests.swift` | Chat chrome consumes the Search display model through a non-interactive indicator that is hidden by default and visible only for explicit Search registration. |
| A42 server-provider runtime pipeline | `ServerProviderRuntimePipeline.swift`, `ServerProviderRuntimePipelineTests.swift` | A single value-only pipeline composes readiness, descriptor lookup, invocation planning, dispatch, fixture-adapter registry, and receipt projection without calling transport. |
| A43 pipeline receipt status source | `ProviderStatusBadgeModelTests.swift` | Pipeline-generated runtime receipts feed `RuntimeReceiptProviderStatusStore`, `ProviderStatusSourceMultiplexer`, and compact-cell display by recommendation id without layout or execution changes. |
| A44 app-bootstrap pipeline receipt status composition | `AppBootstrapTests.swift` | App-root callers can install precomputed pipeline receipt status stores through `AppBootstrap.providerStatusSources`; ChatStore/ChatHome composition consumes them by rendered recommendation id without executing the pipeline in app or view code. |
| A45 provider access quota snapshot bridge | `ServerProviderEnvelopeFactory.swift`, `ServerProviderEnvelopeFactoryTests.swift` | `ProviderAccessProfile` can lower into an explicit `ServerProviderQuotaSnapshot` without granting remote access from membership alone; metered, included-quota, disabled, and experimental gates remain explicit. |
| A46 app-bootstrap provider quota snapshot composition | `AppBootstrap.swift`, `AppBootstrapTests.swift` | `AppBootstrap` carries a value-only `ServerProviderQuotaSnapshot`, defaulting from `providerAccessProfile` through the A45 bridge while preserving explicit injection and avoiding provider execution. |
| A47 search adapter quota snapshot configuration | `SearchCapabilityAdapter.swift`, `DefaultCapabilityRegistry.swift`, `AppBootstrap.swift`, related tests | Reserved Search configuration carries `ServerProviderQuotaSnapshot`, defaults it through the A45 bridge, preserves explicit quota injection, and receives app-root quota only through explicit Search opt-in without executing Search. |
| A48 search dry-run envelope preview | `SearchCapabilityAdapter.swift`, `SearchCapabilityAdapterTests.swift` | Search can produce an advisory `ServerProviderDryRunReport` from its policy decision and stored quota snapshot, showing quota/cost blocks or selected envelopes without calling `resolve`, transport, crawler, MCP, or runtime pipeline. |
| A49 search dry-run presentation projection | `SearchCapabilityAdapter.swift`, `SearchCapabilityAdapterTests.swift` | Search dry-run reports can project into existing advisory `ServerProviderDryRunPresentation` copy while preserving provider, cost, freshness, source, and factory-rejection metadata without rendering UI or implying execution. |
| A50 search dry-run provider status source | `ProviderStatusBadgeModel.swift`, `ProviderStatusBadgeModelTests.swift` | Precomputed Search dry-run presentations can be exposed through `ProviderStatusProviding` by recommendation id, preserving selected/blocked provider status, deterministic lookup, and advisory copy without Chat/UI wiring or Search execution. |
| A51 app-root Search dry-run status composition | `AppBootstrapTests.swift` | App-root callers can install a precomputed `SearchDryRunProviderStatusStore` through `AppBootstrap.providerStatusSources`; ChatStore/ChatHome composition consumes it only for rendered recommendation ids without app/view dry-run generation or Search execution. |
| A52 search dry-run status source builder | `SearchCapabilityAdapter.swift`, `SearchCapabilityAdapterTests.swift` | Search adapter callers can package intent/report/presentation dry-run output into a `SearchDryRunProviderStatusStore` for an explicit recommendation id without mutating `MatchingObject`, wiring app/UI, or executing Search. |
| A53 batch Search dry-run status source builder | `SearchCapabilityAdapter.swift`, `SearchCapabilityAdapterTests.swift` | Search adapter callers can package multiple explicit recommendation ids with precomputed dry-run presentations/reports into one deterministic `SearchDryRunProviderStatusStore`, preserving sorted ids, missing-id nil lookup, and first-entry duplicate behavior without app/UI wiring or Search execution. |
| A54 Search dry-run status source handoff contract | `Contracts/search-capability-contract-v1.md`, architecture docs | The Search contract now names `SearchCapabilityAdapter.dryRunProviderStatusSource(...)` as a value-packaging seam, allows only recommendation/search composition code or tests to produce stores, and requires app/root/view layers to consume `ProviderStatusProviding` without generating dry-runs. |
| A55 Search dry-run status source producer skeleton | `SearchDryRunStatusSourceProducer.swift`, `SearchDryRunStatusSourceProducerTests.swift` | The Search feature now has a pure producer skeleton that accepts explicit recommendation ids plus precomputed dry-run reports/presentations and returns `SearchDryRunProviderStatusStore`, preserving first-entry duplicate behavior, missing-id nil lookup, and advisory copy without app/root/view/runtime wiring. |
| A56 producer source app-root handoff proof | `AppBootstrapTests.swift` | A producer-built `SearchDryRunProviderStatusStore` can pass through `AppBootstrap(providerStatusSources:)` and be consumed by ChatStore by rendered recommendation id, without app/root/view layers constructing the producer or generating Search dry-runs. |
| A57 rendered Search status source guard | `SearchRenderedDryRunStatusSource.swift`, `SearchRenderedDryRunStatusSourceTests.swift` | Producer-built Search dry-run status can now be wrapped behind explicit rendered recommendation ids before app-root injection, returning nil for hidden store ids and preserving selected/blocked status without id inference or runtime wiring. |
| A58 guarded source app-root handoff proof | `AppBootstrapTests.swift` | A guarded producer-built Search dry-run source can pass through `AppBootstrap(providerStatusSources:)`, preserve selected/blocked status, and return nil for hidden wrapped-store ids both before and after ChatStore composition without production app/root/view runtime changes. |
| A59 runtime adapter injection set | `ServerProviderRuntimeAdapterRegistry.swift`, `ServerProviderRuntimeAdapterRegistryTests.swift` | Future real provider adapters can now be supplied through an explicit value-only `ServerProviderRuntimeAdapterSet`; the static registry remains fixture-only, duplicates are deterministic, missing families are rejected, and non-prepared boundaries stay non-executing. |
| A60 runtime pipeline adapter-set handoff proof | `ServerProviderRuntimePipeline.swift`, `ServerProviderRuntimePipelineTests.swift` | The value-only runtime pipeline can now consume an explicit adapter set for prepared Search receipts while the existing default fixture-only path and all non-prepared receipt semantics remain unchanged. |
| A61 injected pipeline receipt status source proof | `ProviderStatusBadgeModelTests.swift` | Receipts produced through the injected-adapter pipeline path can now feed `RuntimeReceiptProviderStatusStore` and `ProviderStatusSourceMultiplexer` by explicit recommendation id while missing ids, source order, and advisory non-executing copy stay deterministic. |
| A62 runtime pipeline status source producer skeleton | `ServerProviderRuntimeStatusSourceProducer.swift`, `ServerProviderRuntimeStatusSourceProducerTests.swift` | Runtime/provider composition code now has a value-only producer that packages explicit recommendation ids with precomputed or injected-pipeline receipts into `RuntimeReceiptProviderStatusStore`, preserving sorted ids, missing-id nil lookup, first-entry duplicate behavior, and advisory copy without app/root/view generation. |
| A63 producer runtime source app-root handoff proof | `AppBootstrapTests.swift` | Producer-built runtime status sources can now pass through `AppBootstrap(providerStatusSources:)` and be consumed by ChatStore only for rendered recommendation ids, while hidden ids stay nil and source order remains deterministic without app/root/view runtime generation. |
| A64 rendered runtime status source guard | `ServerProviderRenderedRuntimeStatusSource.swift`, `ServerProviderRenderedRuntimeStatusSourceTests.swift` | Producer-built runtime status can now be wrapped behind explicit rendered recommendation ids before app-root injection, returning nil for hidden wrapped-store ids and preserving sorted rendered ids without id inference, UI wiring, or provider execution. |
| A65 guarded runtime source app-root handoff proof | `AppBootstrapTests.swift` | Guarded producer-built runtime status sources can pass through `AppBootstrap(providerStatusSources:)` and remain hidden-id safe before app-root injection, at app-root lookup, and after ChatStore composition while preserving source-order determinism and advisory copy. |
| A66 real-provider adapter readiness matrix | `ServerProviderRuntimeAdapterReadiness.swift`, `ServerProviderRuntimeAdapterReadinessTests.swift` | Every provider family now has a value-only readiness report that keeps Apple/cache local, blocks remote adapter readiness until all family-specific gates are explicitly satisfied, and avoids storing endpoint, key, token, prompt, raw source, health, merchant, booking, order, or payment fields. |
| A67 readiness-gated adapter installation proof | `ServerProviderRuntimeAdapterReadinessGate.swift`, `ServerProviderRuntimeAdapterReadinessGateTests.swift` | Future injected server-side adapter families now have a value-only installation gate: remote families are installable only with same-family ready reports, while missing reports, non-ready reports, mismatches, Apple local, and cache are rejected deterministically. |
| A68 readiness-gated adapter set validation proof | `ServerProviderRuntimeAdapterSetReadinessValidation.swift`, `ServerProviderRuntimeAdapterSetReadinessValidationTests.swift` | Already-created injected adapter sets now have a value-only validation result over registered provider families: only same-family installable decisions are accepted, while missing decisions, rejected decisions, local/cache families, and mismatches are rejected before set use. |
| A69 adapter set use authorization proof | `ServerProviderRuntimeAdapterSetUseGate.swift`, `ServerProviderRuntimeAdapterSetUseGateTests.swift` | Future injected adapter-set use now has a value-only authorization result over one requested provider family and an accepted set validation; nil, local/cache, unregistered, validation-rejected, and not-accepted families are rejected before any resolve path. |
| A70 authorized adapter set pipeline handoff proof | `ServerProviderRuntimePipeline.swift`, `ServerProviderRuntimePipelineTests.swift` | The injected-adapter pipeline now has explicit validation-taking overloads that run A69 use authorization before entering `ServerProviderRuntimeAdapterSet.resolve`; unauthorized paths project non-success receipts without provider metadata or injected adapter calls. |
| A71 authorized runtime status source producer proof | `ServerProviderRuntimeStatusSourceProducer.swift`, `ServerProviderRuntimeStatusSourceProducerTests.swift` | Runtime/provider composition can now package authorized injected-pipeline receipts by explicit recommendation id through the A70 validation-taking pipeline path while preserving advisory copy, duplicate-id behavior, and the older unvalidated producer overload. |
| A72 authorized runtime status app-root handoff proof | `AppBootstrapTests.swift` | Authorized producer-built runtime status sources can now pass through `AppBootstrap(providerStatusSources:)`, remain rendered-id scoped before ChatStore consumption, preserve hidden-id nil lookup, carry rejected-validation advisory status, and keep source order deterministic without production app/root/view runtime generation. |
| A73 runtime adapter manifest catalog proof | `ServerProviderRuntimeAdapterManifest.swift`, `ServerProviderRuntimeAdapterManifestTests.swift` | Future real-provider adapter families now have a value-only manifest catalog for Google Maps, Gaode, Search API, crawler, and MCP; manifests mirror readiness matrix metadata/gates, exclude Apple/cache installable entries, and preserve deterministic lookup without endpoints, SDKs, credentials, or runtime execution. |
| A74 manifest-backed adapter installation proof | `ServerProviderRuntimeAdapterManifestInstallation.swift`, `ServerProviderRuntimeAdapterManifestInstallationTests.swift` | Future adapter installation decisions now require an A73 manifest before consuming readiness reports; manifest/readiness mismatch and gate drift are rejected before delegating to the existing A67 installation gate, preserving value-only installability semantics. |
| A75 manifest-backed adapter set validation proof | `ServerProviderRuntimeAdapterManifestSetValidation.swift`, `ServerProviderRuntimeAdapterManifestSetValidationTests.swift` | Already-created injected adapter sets now validate only from A74 manifest-backed installation decisions before delegating to A68 set validation, preserving duplicate first-family behavior and preventing missing/local/non-installable/mismatched manifest decisions from reaching set use. |
| A76 manifest-backed adapter set use authorization proof | `ServerProviderRuntimeAdapterManifestSetUseGate.swift`, `ServerProviderRuntimeAdapterManifestSetUseGateTests.swift` | Future injected adapter-set use authorization now requires accepted A75 manifest-backed set validation plus embedded A68 validation before delegating to A69 use authorization, keeping nil/local/rejected/not-accepted/missing-readiness/A69-rejected paths distinct. |
| A77 manifest-backed runtime pipeline handoff proof | `ServerProviderRuntimePipeline.swift`, `ServerProviderRuntimePipelineTests.swift` | The injected-adapter pipeline now has explicit A76 authorization-taking overloads that block before `ServerProviderRuntimeAdapterSet.resolve` unless manifest-backed use authorization, requested provider family, and embedded A69 authorization all match. |
| A78 manifest-backed runtime status source producer proof | `ServerProviderRuntimeStatusSourceProducer.swift`, `ServerProviderRuntimeStatusSourceProducerTests.swift` | Runtime/provider composition can now package manifest-backed A77 authorization-taking injected-pipeline receipts by explicit recommendation id while preserving advisory copy, duplicate-id behavior, and the older precomputed/unvalidated/A70 producer overloads. |
| A79 manifest-backed runtime status app-root handoff proof | `AppBootstrapTests.swift` | Manifest-backed producer-built runtime status sources can now pass through `AppBootstrap(providerStatusSources:)`, remain rendered-id scoped before ChatStore consumption, preserve accepted/rejected A76 advisory status, and keep source order deterministic without production app/root/view runtime generation. |
| A80 real provider connector boundary skeleton | `ServerProviderRuntimeConnector.swift`, `ServerProviderRuntimeConnectorTests.swift` | Future remote provider adapters now have a value-only connector boundary with request/result metadata, remote-family eligibility, a connector protocol, and metadata-only connector double, while Apple/cache remain no-connector paths and no transport/provider execution exists. |
| A81 connector request planner proof | `ServerProviderRuntimeConnectorPlanner.swift`, `ServerProviderRuntimeConnectorPlannerTests.swift` | Runtime/provider composition can now derive value-only connector requests from prepared dispatch boundaries, A73 manifests, and A76 authorization before any connector runs, preserving deterministic rejection reasons and advisory-only encoded output. |
| A82 connector invocation receipt proof | `ServerProviderRuntimeConnectorInvocation.swift`, `ServerProviderRuntimeConnectorInvocationTests.swift` | Accepted A81 connector requests can now flow through an injected connector boundary into value-only invocation receipts, while rejected planning avoids connector calls and family mismatches preserve rejected result metadata without provider payloads. |
| A83 connector receipt status source proof | `ServerProviderRuntimeConnectorStatusSourceProducer.swift`, `ServerProviderRuntimeConnectorStatusSourceProducerTests.swift` | A82 connector invocation receipts can now package explicit recommendation-id scoped advisory provider-status presentations while preserving rendered-id filtering, duplicate first-wins behavior, and non-success rejection copy without provider metadata leakage. |
| A84 connector receipt status app-root handoff proof | `AppBootstrapTests.swift` | A83 connector receipt status sources can now pass through `AppBootstrap(providerStatusSources:)` and ChatStore lookup while remaining rendered-id scoped, preserving hidden-id nil lookup, source order, and advisory accepted/rejected copy. |
| A85 research/market/interface cut-plan refresh | `2026-agent-market-ui-provider-research.md`, architecture docs | Current papers/specs/vendor docs/competitor docs were rechecked; Search API is selected as the first provider-specific contract-only cut, while Google/Gaode runtime, crawler runtime, MCP runtime, and remote model gateway remain deferred. |
| A86 Search API server adapter contract proof | `ServerProviderSearchAPIAdapterContract.swift`, `ServerProviderSearchAPIAdapterContractTests.swift` | Search API now has value-only query, quota/access/source, request decision, citation, result, and result receipt contracts that consume approved envelope/connector metadata and reject unsafe provider, privacy, quota, source, citation, connector, and freshness paths without runtime execution. |
| A87 Search API adapter receipt status source proof | `ProviderStatusBadgeModel.swift`, `ProviderStatusBadgeModelTests.swift` | A86 request decisions and result receipts can now be packaged by explicit recommendation id through `ProviderStatusProviding`, preserving prepared/normalized/rejected advisory status, duplicate first-wins behavior, missing-id nil lookup, and no provider execution claims. |
| A88 Search API adapter status app-root handoff proof | `AppBootstrapTests.swift` | A87 Search API adapter status sources can pass through `AppBootstrap(providerStatusSources:)` and ChatStore lookup for rendered recommendation ids, while hidden ids stay nil, rejected A86 values remain non-success/advisory, and source order remains first-wins without production runtime wiring. |
| A89 Search API adapter status source producer guard | `ServerProviderSearchAPIAdapterStatusSourceProducer.swift`, `ServerProviderSearchAPIAdapterStatusSourceProducerTests.swift` | Search API adapter request decisions and result receipts can now be packaged by typed producer inputs into an A87 status store wrapped by explicit rendered recommendation ids before app-root injection, preserving hidden-id nil lookup, duplicate first-wins, and advisory copy. |
| A90 Search API adapter producer guard app-root handoff proof | `AppBootstrapTests.swift` | A89 producer-built guarded Search API adapter status sources can pass through `AppBootstrap(providerStatusSources:)` and ChatStore lookup while remaining rendered-id scoped, preserving hidden supplied-id nil lookup, rejected non-success/advisory copy, and source-order first-wins without production runtime wiring. |
| A91 Search API adapter payload boundary | `ServerProviderSearchAPIAdapterPayload.swift`, `ServerProviderSearchAPIAdapterPayloadTests.swift` | Prepared A86 request metadata can derive outbound-safe payload values without endpoints, credentials, SDKs, network execution, raw provider content, or provider claims. |
| A92 Search API adapter payload dispatch gate | `ServerProviderSearchAPIAdapterPayloadDispatchGate.swift`, `ServerProviderSearchAPIAdapterPayloadDispatchGateTests.swift` | A91 payloads become dispatch-eligible only when they still match their original A86 request metadata; rejected, missing, mismatched, and unsafe inputs stay blocked without provider execution. |
| A93 Search API adapter dispatch status source | `ServerProviderSearchAPIAdapterPayloadDispatchStatusSourceProducer.swift`, `ServerProviderSearchAPIAdapterPayloadDispatchStatusSourceProducerTests.swift` | A92 dispatch receipts can be packaged into a rendered-id scoped provider-status source with advisory dispatch-ready or disabled blocked copy and no query leakage. |
| A94 Search API adapter dispatch app-root handoff proof | `AppBootstrapTests.swift` | A93 dispatch status sources pass through `AppBootstrap(providerStatusSources:)` and ChatStore lookup for rendered ids only, while hidden ids stay nil and source order remains first-wins. |
| A95 Search API adapter cross-stage status composition | `AppBootstrapTests.swift` | A89/A90 request/result status and A93 dispatch status compose deterministically through app-root and ChatStore lookup with first-wins ordering and no stale detail mixing. |
| A96 Search API adapter fixture transport bridge | `ServerProviderSearchAPIAdapterFixtureTransportBridge.swift`, `ServerProviderSearchAPIAdapterFixtureTransportBridgeTests.swift` | Eligible A86/A91/A92 metadata can become a fixture audit response through a value-only bridge; rejected request, rejected payload, blocked dispatch, and mismatched metadata stay non-success without endpoints, credentials, SDKs, crawler/MCP, UI, app-root wiring, or provider execution. |
| A97 Search API adapter fixture bridge status source | `ServerProviderSearchAPIAdapterFixtureTransportStatusSourceProducer.swift`, `ServerProviderSearchAPIAdapterFixtureTransportStatusSourceProducerTests.swift` | A96 fixture bridge responses can now be packaged into a rendered-id scoped provider-status source with advisory ready/rejected copy, duplicate first-wins behavior, hidden-id nil lookup, and no query leakage or provider execution claims. |
| A98 Search API adapter fixture bridge status app-root handoff proof | `AppBootstrapTests.swift` | A97 fixture bridge status sources now pass through `AppBootstrap(providerStatusSources:)` and ChatStore lookup for rendered ids only, preserving ready/rejected advisory copy, hidden-id nil lookup, and source-order first-wins without production root/UI/runtime wiring. |
| A99 Search API adapter fixture bridge cross-stage status composition | `AppBootstrapTests.swift` | A97 fixture bridge status now composes deterministically with A89/A90 request/result and A93 dispatch status at app-root and ChatStore lookup, preserving first-wins ordering, hidden-id nil lookup, and no stale detail/query/execution-copy mixing. |
| A100 Search API adapter cost and entitlement status matrix | `ServerProviderSearchAPIAdapterFixtureTransportStatusSourceProducerTests.swift` | Search API adapter cost and entitlement outcomes now stay explicit across A86/A91/A92/A96/A97, preserving included-quota vs metered-premium status and keeping missing-entitlement, blocked-cost, private-privacy, and free-local paths non-success without silent premium fallback. |
| A101 Search API adapter source/citation/attribution status matrix | `ServerProviderSearchAPIAdapterFixtureTransportStatusSourceProducerTests.swift` | Search API adapter source, citation, and attribution outcomes now stay explicit across A86/A91/A92/A96/A97; accepted source metadata preserves selected host/citation context, while source-policy, citation-policy, missing-citation, and mismatched-citation paths stay non-success without hidden host/query/raw-page leakage. |
| A102 Search API adapter result freshness/content/limitation status matrix | `ServerProviderSearchAPIAdapterFixtureTransportStatusSourceProducerTests.swift` | Search API adapter result freshness, content, and limitation outcomes now stay explicit across A86 result receipts and A87 status copy; fresh/cached accepted results remain distinct, stale live-required and missing-content paths stay non-success, and limitation metadata does not leak hidden host/query/raw-page/execution claims. |
| A103 Search API adapter result status app-root handoff proof | `AppBootstrapTests.swift` | A102 result freshness/content/limitation status sources now pass through `AppBootstrap(providerStatusSources:)` and ChatStore lookup for rendered ids only, preserving hidden-id nil lookup, exact status/badge/card copy, and source-order first-wins without production provider/runtime changes. |
| A104 research/market/provider cut-plan refresh | `2026-agent-market-ui-provider-research.md`, architecture docs | Current public papers, product docs, provider policies, and Search API vendor docs were rechecked; the next implementation slice is a value-only Search API vendor policy matrix, not live Google/Gaode/Search/crawler/MCP runtime. |
| A105 Search API vendor policy matrix | `ServerProviderSearchAPIVendorPolicy.swift`, `ServerProviderSearchAPIVendorPolicyTests.swift` | Search API vendors can now be accepted or rejected by enabled state, provider family, capability, privacy, cost/quota/entitlement, freshness, citation/source/attribution, page-body, retention, and result-shape metadata before any live provider call. |
| A106 Search API vendor policy status source | `ProviderStatusBadgeModel.swift`, `ServerProviderSearchAPIVendorPolicyStatusSourceProducer.swift`, `ServerProviderSearchAPIVendorPolicyStatusSourceProducerTests.swift` | A105 vendor policy decisions can now be packaged into rendered-id scoped provider-status copy with accepted/blocked status, duplicate first-wins behavior, missing-id nil lookup, and hidden-id filtering without app-root generation or provider execution. |
| A107 Search API vendor policy status app-root handoff | `AppBootstrapTests.swift` | A106 vendor policy status sources now pass through `AppBootstrap(providerStatusSources:)` and ChatStore lookup for rendered ids only, preserving accepted/rejected copy, hidden-id nil lookup, missing-id nil lookup, and source-order first-wins without production root/UI/runtime changes. |
| A108 Search API vendor policy dispatch authorization | `ServerProviderSearchAPIVendorPolicyDispatchAuthorization.swift`, `ServerProviderSearchAPIVendorPolicyDispatchAuthorizationTests.swift` | A92 dispatch receipts now require an accepted A105 vendor policy decision with matching provider, capability, cost, freshness, and result-shape metadata before any future transport call can be considered. |
| A109 Search API vendor policy dispatch authorization status source | `ProviderStatusBadgeModel.swift`, `ServerProviderSearchAPIVendorPolicyDispatchAuthorizationStatusSourceProducer.swift`, `ServerProviderSearchAPIVendorPolicyDispatchAuthorizationStatusSourceProducerTests.swift` | A108 dispatch authorization results can now be packaged into rendered-id scoped provider-status copy, preserving authorized/blocked presentations, nested dispatch/vendor reasons, duplicate first-wins behavior, and hidden/missing nil lookup without app-root generation or provider execution. |
| A110 Search API vendor policy dispatch authorization status app-root handoff | `AppBootstrapTests.swift` | A109 dispatch authorization status sources now pass through `AppBootstrap(providerStatusSources:)` and ChatStore lookup for rendered ids only, preserving authorized/rejected copy, hidden-id nil lookup, missing-id nil lookup, and source-order first-wins without production root/UI/runtime changes. |
| A111 Search API vendor dispatch cross-stage status composition | `AppBootstrapTests.swift` | A106 vendor policy status, A93 payload dispatch status, and A109 dispatch authorization status now compose deterministically through app-root and ChatStore lookup, preserving first-wins ordering, hidden-id nil lookup, and no stale vendor/dispatch/authorization/query/execution-copy mixing. |
| A112 Search API vendor-authorized transport lease budget guard | `ServerProviderSearchAPITransportLease.swift`, `ServerProviderSearchAPITransportLeaseTests.swift` | A91 payload metadata, A92 dispatch receipts, A108 dispatch authorizations, and explicit budget context now issue or reject value-only Search API transport leases before any endpoint, credential, network transport, crawler/MCP runtime, or provider execution can be considered. |
| A113 Search API transport lease status source | `ServerProviderSearchAPITransportLeaseStatusSourceProducer.swift`, `ServerProviderSearchAPITransportLeaseStatusSourceProducerTests.swift` | A112 issued/rejected transport leases can now be packaged into rendered-id scoped provider-status copy, preserving advisory lease-ready or blocked status, nested payload/dispatch/authorization/budget reasons, duplicate first-wins behavior, hidden/missing nil lookup, and no source-host/query/runtime leakage. |
| A114 Search API transport lease status app-root handoff | `AppBootstrapTests.swift` | A113 transport lease status sources now pass through `AppBootstrap(providerStatusSources:)` and ChatStore lookup for rendered ids only, preserving issued/rejected copy, hidden-id nil lookup, missing-id nil lookup, and source-order first-wins without production root/UI/runtime changes. |
| A115 Search API transport lease cross-stage status composition | `AppBootstrapTests.swift` | A106 vendor policy status, A93 payload dispatch status, A109 dispatch authorization status, and A113 transport lease status now compose deterministically through app-root and ChatStore lookup, preserving first-wins ordering, hidden-id nil lookup, and no stale vendor/dispatch/authorization/lease/budget/query/execution-copy mixing. |
| A116 research/market/provider cut-plan refresh | `2026-agent-market-ui-provider-research.md`, architecture docs | Current external evidence was rechecked after A115; live Search API transport remains premature, and the next selected gate is a server-provider metered entitlement ledger. |
| A117 server-provider metered entitlement ledger | `ServerProviderMeteredEntitlementLedger.swift`, `ServerProviderMeteredEntitlementLedgerTests.swift` | Server-verified provider/vendor budget snapshots can now accept or reject usage requests by membership, entitlement, quota period, units, cost class, privacy, freshness, provider/vendor/capability match, stale snapshot, disabled vendor, and over-budget state without StoreKit, transport, UI, MCP/crawler, maps SDKs, or provider execution. |
| A118 server-provider metered entitlement status source | `ServerProviderMeteredEntitlementStatusSourceProducer.swift`, `ServerProviderMeteredEntitlementStatusSourceProducerTests.swift` | A117 usage decisions can now be packaged into rendered-id scoped provider-status copy with accepted included/metered budget status, blocked denial reasons, duplicate first-wins behavior, and hidden/missing nil lookup without app-root, ChatStore, UI, transport, StoreKit, MCP/crawler, maps SDK, or provider execution changes. |
| A119 server-provider metered entitlement status app-root handoff | `AppBootstrapTests.swift` | A118 status sources now pass through `AppBootstrap(providerStatusSources:)` and ChatStore lookup for rendered ids only, preserving accepted/rejected budget copy, hidden/missing nil lookup, and source-order first-wins without production root/UI/runtime/provider changes. |
| A120 server-provider metered entitlement cross-stage status composition | `AppBootstrapTests.swift` | A118 metered entitlement, A106 vendor policy, A93 payload dispatch, A109 dispatch authorization, and A113 transport lease status now compose deterministically through app-root and ChatStore lookup, preserving first-wins ordering, hidden/missing nil lookup, and no stale budget/vendor/dispatch/authorization/lease/query/execution-copy mixing. |
| A121 research/market/provider cut-plan refresh after metered stack | `2026-agent-market-ui-provider-research.md`, `2026-agent-architecture-deep-dive-v1.md`, architecture docs | Current research/vendor/competitor evidence was rechecked after A120; live providers remain premature, and the next selected gate is an A122 Search API metered-entitlement transport lease handoff proof. |
| A122 Search API metered-entitlement transport lease handoff | `ServerProviderSearchAPITransportLease.swift`, `ServerProviderMeteredEntitlementLedger.swift`, `ServerProviderSearchAPITransportLeaseTests.swift` | A112 transport leases now require metered entitlement metadata on their budget context and can be issued from accepted A117 included-quota or metered-premium decisions only when provider, vendor, capability, cost class, freshness, source, citation, dispatch, and authorization metadata all match. |
| A123 metered-entitlement transport lease status handoff | `ServerProviderSearchAPITransportLeaseStatusSourceProducerTests.swift`, `AppBootstrapTests.swift` | A122 issued/rejected leases now package into A113 provider-status copy and pass through AppBootstrap/ChatStore lookup, covering metered entitlement missing and vendor mismatch copy, hidden/missing nil lookup, and first-wins source ordering without runtime execution. |
| A124 metered-entitlement transport lease cross-stage status composition | `AppBootstrapTests.swift` | A123 metered-entitlement transport lease status now composes deterministically with A118 metered entitlement, A106 vendor policy, A93 payload dispatch, and A109 dispatch authorization status through AppBootstrap/ChatStore lookup, preserving first-wins ordering, hidden/missing nil lookup, and no stale budget/vendor/dispatch/authorization/lease detail mixing. |
| A125 research/market/provider cut-plan refresh after metered lease composition | `2026-agent-market-ui-provider-research.md`, `2026-agent-architecture-deep-dive-v1.md`, architecture docs | Current research, provider docs, MCP/security direction, and competitor signals were rechecked after A124; live providers remain premature, and the next selected gate is an A126 Search API transport request contract proof. |
| A126 Search API transport request contract | `ServerProviderSearchAPITransportRequest.swift`, `ServerProviderSearchAPITransportRequestTests.swift` | Issued A122 metered-entitlement leases can now prepare value-only Search API transport request decisions only when the request, payload, dispatch, vendor policy, authorization, lease, budget, result-shape, source/citation, freshness, cost, and metered decision metadata all match, without endpoint, credential, URLSession, SDK, crawler/MCP, maps, or provider execution. |
| A127 Search API transport request status source | `ServerProviderSearchAPITransportRequestStatusSourceProducer.swift`, `ServerProviderSearchAPITransportRequestStatusSourceProducerTests.swift` | A126 prepared/rejected transport request decisions can now be packaged into rendered-id scoped provider-status copy with stable badges/card hints, duplicate first-wins behavior, hidden/missing nil lookup, safe source/citation summary copy, and no raw query, source-host, endpoint, credential, SDK, crawler/MCP, maps, payment, booking, or execution leakage. |
| A128 Search API transport request status app-root handoff | `AppBootstrapTests.swift` | A127 request status sources now pass through `AppBootstrap(providerStatusSources:)` and ChatStore lookup for rendered ids only, preserving prepared/rejected copy, hidden/missing nil lookup, source-order first-wins, and no stale request/vendor/lease/budget/metered/rejection detail mixing without production root, UI, or runtime behavior changes. |
| A129 Search API transport request cross-stage status composition | `AppBootstrapTests.swift` | A127 request status now composes deterministically with A118 metered entitlement, A106 vendor policy, A93 payload dispatch, A109 dispatch authorization, and A113 transport lease status through app-root and ChatStore lookup, preserving first-wins ordering, hidden/missing nil lookup, and no stale metered/vendor/dispatch/authorization/lease/request detail mixing. |
| A130 research/market/provider cut-plan refresh after request status composition | `2026-agent-market-ui-provider-research.md`, `2026-agent-architecture-deep-dive-v1.md`, architecture docs | Current research, provider policy, MCP/security, Apple platform, maps/Search API vendor, crawler, and competitor evidence was rechecked after A129; live providers remain premature, and the next selected gate is an A131 Search API transport response receipt contract proof. |
| A131 Search API transport response receipt contract | `ServerProviderSearchAPITransportResponse.swift`, `ServerProviderSearchAPITransportResponseTests.swift` | A normalized/cited A86 adapter result receipt can now be accepted as a value-only transport response receipt only when it belongs to the prepared A126 transport request and matching request/payload/dispatch/vendor/authorization/lease/budget/metered/source/citation/cost/freshness chain, without endpoint, credential, URLSession, SDK, crawler/MCP, maps, payment, booking, hidden app control, or provider execution. |
| A132 Search API transport response status source | `ServerProviderSearchAPITransportResponseStatusSourceProducer.swift`, `ServerProviderSearchAPITransportResponseStatusSourceProducerTests.swift` | A131 accepted/rejected response decisions can now be packaged into rendered-id scoped provider-status copy with stable badges/card hints, duplicate first-wins behavior, hidden/missing nil lookup, safe result/citation count summary copy, nested request/result rejection reasons, and no raw query, citation URL, source-host value, endpoint, credential, SDK, crawler/MCP, maps, payment, booking, hidden app-control, or execution leakage. |
| A133 Search API transport response status app-root handoff | `AppBootstrapTests.swift` | A132 response status sources now pass through `AppBootstrap(providerStatusSources:)` and ChatStore lookup for rendered ids only, preserving accepted/rejected copy, hidden/missing nil lookup, source-order first-wins, and no stale response/request/result/vendor/lease/budget/metered/rejection detail mixing without production root, UI, or runtime behavior changes. |

These are foundations only. Real Google/Gaode/search/crawler/MCP
runtime work remains blocked until server transport, entitlement,
security, and policy gates are added.

## 2.2 A10 Research Update

A10 checked 2026 agent papers, MCP security work, mobile GUI-agent
projects, Apple App Intents/Foundation Models/Core ML docs, Google Maps
pricing/policies, Gaode pricing/privacy/key docs, Tencent Yuanbao/Hy3,
Meituan LongCat, MARVIS-style mobile-assistant positioning, and RFC 9309.

The update strengthens the implementation order:

```text
local iOS/default path
  -> typed provider/search/MCP policy contracts
  -> typed server/provider transport envelope
  -> quota/entitlement/privacy evaluation
  -> one real provider at a time
```

Skipping the envelope and jumping straight to Google/Gaode/search/MCP
runtime would leave provider cost, attribution, source retention,
privacy class, and confirmation state without one enforcement point.

## 2.3 A85 Research Refresh

A85 rechecked 2026 agent architecture and memory papers, mobile/GUI-agent
projects, MCP spec/security/access-control work, Apple App Intents/Foundation
Models/Core Location docs, Google Places policy/pricing, Gaode quota/privacy
docs, Search API vendor docs, Robots Exclusion Protocol, and current market
signals from Tencent Yuanbao/Hy3, Meituan LongCat, and MARVIS-style assistants.

The ordering remains contract-first, but the next provider-specific cut is now
explicit:

```text
local iOS/default path
  -> typed provider/search/MCP policy contracts
  -> typed server/provider transport envelope
  -> quota/entitlement/privacy/source evaluation
  -> connector receipt/status handoff
  -> Search API adapter contract only
  -> one real provider runtime later
```

Search API is the first provider-specific contract because it is read-only,
source/citation oriented, useful across Maps/Store/AI/life-service surfaces, and
exercises reusable quota, privacy, freshness, source-retention, and UI-status
gates before higher-risk Google/Gaode SDK/runtime, crawler, MCP, or remote-model
work.

## 2.4 A121 Research Refresh

A121 rechecked cost-aware agent routing papers, MCP specification/security work,
Apple App Intents/Foundation Models/Core Location docs, Google Places policy and
pricing, Gaode quota/privacy surfaces, Search API vendor docs, RFC 9309,
Tencent Yuanbao/Hy3, Meituan LongCat/VitaBench-style life-service signals, and
MARVIS-style mobile-assistant positioning against the completed A120 metered
entitlement status stack.

The ordering remains provider-runtime cautious:

```text
local iOS/default path
  -> typed provider/search/MCP policy contracts
  -> typed server/provider transport envelope
  -> quota/entitlement/privacy/source evaluation
  -> connector receipt/status handoff
  -> Search API adapter, vendor policy, dispatch authorization, transport lease
  -> server-provider metered entitlement ledger and status composition
  -> A122: prove accepted metered entitlement decisions drive transport leases
  -> one real provider runtime later
```

The next cut is **not** live Search API, Google/Gaode, crawler, MCP, payment, or
remote model runtime. The remaining pre-runtime gap is that A112 transport lease
issuance still accepts an explicit budget context; A122 should prove leases can
be issued from accepted A117 metered entitlement decisions and cannot be issued
from rejected or mismatched budget decisions.

## 2.5 A130 Research Refresh

A130 rechecked cost-aware routing and agent dispatch papers, MCP
specification/security work, Apple App Intents/Foundation Models/Core Location
docs, Google Places policy/pricing/terms, Gaode quota/privacy/key/terms
surfaces, Search API vendor docs, RFC 9309, Tencent Hy3/Yuanbao, Meituan
LongCat/life-service work, MARVIS-style assistant positioning, and current
mobile GUI-agent papers against the completed A129 request-status composition
stack.

The ordering remains provider-runtime cautious:

```text
local iOS/default path
  -> typed provider/search/MCP policy contracts
  -> typed server/provider transport envelope
  -> quota/entitlement/privacy/source evaluation
  -> connector receipt/status handoff
  -> Search API adapter, vendor policy, dispatch authorization, transport lease
  -> server-provider metered entitlement ledger and status composition
  -> lease-bound Search API transport request and request-status composition
  -> A131: bind normalized/cited Search API response receipts to the request
  -> one real provider runtime later
```

The next cut is **not** live Search API, Google/Gaode SDK/API runtime, crawler
runtime, MCP client runtime, payment, booking, remote model runtime, or hidden
third-party app control. The remaining pre-runtime gap is that existing
normalized Search API result receipts are earlier than the metered
lease/request stack. A131 should prove a response receipt can be accepted only
when it belongs to the exact A126 transport request and preserves the full
request/payload/dispatch/vendor/authorization/lease/budget/metered/source/
citation/cost/freshness chain.

## 3. Provider Families

| Provider family | Default tier | Example capabilities | Notes |
|---|---|---|---|
| `appleLocal` | free/default | map display, location, local route handoff, system search where available | iOS-native, privacy-friendly, limited POI richness in some regions |
| `gaode` | member/premium, China-first | POI search, route planning, URI handoff, navigation, local services | needs Gaode key/server mediation and region gating |
| `googleMaps` | member/premium, global | Places, Routes, details, ratings/photos where allowed | cost/SKU sensitive; server-side quota and caching policy needed |
| `searchAPI` | member/metered | public web search, citations, recent local info | Exa/Tavily/etc. through server-side adapters |
| `crawler` | restricted/metered | allowed public pages with robots compliance | server-side only, rate-limited, source-policy checked |
| `mcp` | disabled by default | external tools/resources/prompts | allowlisted tool descriptors, sandboxing, no sensitive auto-share |
| `cache` | free fallback | recent safe results and user-saved places | must expose freshness and stale limits |

## 4. Membership and Cost Policy

Membership should not be just "free vs paid". It should be a routing
constraint:

```text
free
  -> local Apple/system provider
  -> cache
  -> disabled premium affordance

plus
  -> limited Gaode or Google provider calls
  -> limited search API calls
  -> no paid remote model unless included

pro
  -> higher provider quotas
  -> premium model access
  -> deeper search/research calls
  -> provider preference setting

developer/internal
  -> provider diagnostics
  -> fake fixtures
  -> quota simulation
```

Every provider request gets a budget class:

- `freeLocal`
- `includedQuota`
- `meteredPremium`
- `blockedByCost`
- `blockedByPrivacy`
- `blockedByTerms`

Rules:

- Never silently switch a free user into a metered premium provider.
- Never call Google/Gaode/search/crawler directly from SwiftUI.
- Never store provider API keys in iOS.
- Never let an iOS request envelope contain an API key, bearer token, or
  provider secret.
- Server validates entitlements and applies quotas for remote providers.
- If a provider is skipped because of cost, the UI can show "premium
  provider available" but not fake the result.

## 5. Maps Provider Strategy

Default map behavior:

```text
route planning request
  -> Apple/local provider if sufficient
  -> membership/region/provider preference check
  -> Gaode for China-first or member-selected China provider
  -> Google for global premium detail/routing where allowed
  -> external handoff if app-specific navigation is needed
```

Provider outputs normalize into:

```text
MapProviderResult
  providerID
  capability
  source
  freshness
  confidence
  costClass
  place candidates / route summary
  external handoff target
  attribution
  limitations
```

UI rules:

- Always show provider badge when non-local provider is used.
- Show "opened" or "prepared" for external map app handoff unless a
  provider API confirms completion.
- If Google/Gaode is locked by membership, show a disabled premium CTA.
- Cache/fallback results must show freshness.
- Google Places-derived data must honor Google's caching/storage and
  attribution policies.
- Gaode SDK/API use must pass privacy-consent, region, quota/QPS, and
  key-binding checks.

## 6. Search and Crawler Strategy

Search is read-only in v1.

Search provider pipeline:

```text
query
  -> PrivacyGuard classification
  -> CostPolicy
  -> SearchProviderAdapter
  -> SearchResultEnvelope
  -> ResultProjector with citations/freshness
```

Crawler pipeline:

```text
candidate URL
  -> source allowlist / denylist
  -> robots.txt check per RFC 9309
  -> rate-limit check
  -> fetch server-side
  -> parse public structured info
  -> cite URL and timestamp
  -> cache under retention policy
```

Crawler rules:

- No on-device scraping in v1.
- No scraping Apple sites or stores.
- No bypass of robots.txt, paywalls, logins, anti-bot controls, or terms.
- No collection of personal data without product/legal review.
- Public life-service info must be cited with URL, timestamp, provider,
  and confidence.
- If source quality is low, return best-effort summary, not a booking or
  ordering action.
- `robots.txt` is a crawl permission signal, not authentication. A
  crawler also needs source allowlist/denylist, rate limit, user-agent
  identity, content retention, and legal/product review.

## 7. MCP Interface Reservation

MCP is a future bridge, not a default runtime.

Reserved shape:

```text
MCPGateway
  registry: allowed MCP servers
  descriptor verifier: signed/known tool descriptors
  permission mapper: MCP tool annotations -> kAir risk class
  resource reader: explicit user consent for resources
  tool caller: read-only first
  audit logger: provider trace + memory provenance
```

MCP features to reserve:

- tools,
- resources,
- prompts,
- completion,
- elicitation/user confirmation,
- OAuth/server auth,
- tool annotations such as read-only/destructive/idempotent/external.

Prompt-template reservation:

- `MCPPromptDescriptor` models a server-owned prompt template id,
  display name, argument names, domain, and review requirement.
- `MCPServerDescriptor.allowedPromptIDs` is the allowlist.
- `MCPGatewayOperation.prompt` can be authorized, blocked, or marked as
  needing user review.
- Health-domain prompts are blocked in v1.
- Authorization only records an audit decision. It does not render,
  sample, forward, or execute the prompt.

Security rules:

- MCP servers are disabled by default.
- Only allowlisted servers can be registered.
- Tool descriptors need stable IDs and signed/known provenance.
- Destructive/external tools require confirmation.
- MCP resources cannot be forwarded to remote models without consent.
- Health memory cannot be exposed to MCP in v1.
- Prompt injection and tool poisoning are treated as first-class threat
  model items.
- MCP descriptor text, prompt templates, tool annotations, and resource
  metadata are untrusted input until allowlisted and verified.
- STDIO/local-process MCP transports are not inherently safe; process
  launch and filesystem access require sandboxing and explicit user or
  developer approval.

## 7.1 Server Provider Transport Envelope

A11 implements the first runtime-adjacent contract without adding a real
network client. The current shape is a pure envelope, validator, audit
record, and fixture transport:

```text
ServerProviderEnvelope
  traceID
  capability
  providerFamily
  privacyClass
  membershipTier
  costClass
  freshness
  sourcePolicy
  confirmationState
  meteredProviderEntitlements
  enabledExperimentalProviders

ServerProviderEnvelopeValidator
  allowed | blocked(reason)

ServerProviderAuditRecord
  ProviderTrace
  providerFamily
  sourcePolicy
  confirmationState
  denialReason

MockServerTransport
  acceptedFixture | blocked

ServerProviderEnvelopeFactory
  ProviderSelection + quota snapshot -> envelope | blocked
  SearchProviderDecision + quota snapshot -> envelope | blocked
  MCPGatewayDecision + quota snapshot -> envelope | blocked

ServerProviderDryRunEvaluator
  candidate envelopes -> selected | all blocked | freshness unsatisfied
```

The envelope exists so every future server-mediated provider call can be
tested before any endpoint exists. It must explicitly block:

- Health/private context to remote providers;
- Google/Gaode/search/crawler/MCP without matching entitlement;
- crawler without robots/source pass;
- MCP unless explicitly enabled;
- destructive/write/payment/merchant actions without confirmation;
- provider auth material fields in client-visible value types.

A12 adds `ServerProviderQuotaSnapshot` and
`ServerProviderEnvelopeFactory`. The factory is still a dry adapter: it
does not send the envelope, it does not fetch sources, and it does not run
MCP. It only proves that an upstream provider/search/MCP policy decision
can survive quota, entitlement, source, confirmation, and A11 validator
checks.

A13 adds `ServerProviderDryRunEvaluator`. It compares factory results and
produces an audit-only plan with selected/blocked traces. It still does
not execute transport and does not claim a provider was called.

## 8. Life-Service Provider Strategy

Life-service categories:

- food/restaurants,
- cafes,
- movies/events,
- local shopping,
- travel/hotels,
- errands,
- social/friends recommendations.

V1 capabilities:

- search,
- compare,
- summarize,
- save,
- open/deeplink,
- ask clarification.

Deferred capabilities:

- order,
- reserve,
- pay,
- cancel,
- refund,
- message merchant,
- submit review.

Deferred actions require separate contracts because they involve payment,
account state, merchant systems, and legal obligations.

## 9. Telemetry and Evaluation

Every provider route should produce an internal trace:

```text
ProviderTrace
  traceID
  capability
  selectedProvider
  skippedProviders[]
  costClass
  privacyClass
  membershipTier
  freshness
  latencyMs
  resultCount
  failureReason
```

No raw health data, prompt text, provider API key, or personal secret goes
into telemetry.

Evaluation gates:

- correct provider selection by region/membership,
- no metered call without entitlement,
- no health/private context to remote provider,
- no crawler call without robots/source pass,
- no external action without confirmation,
- graceful fallback if provider unavailable.
- no server/provider envelope missing trace/cost/privacy/source fields,
- no API key or provider secret exposed in the iOS-side envelope.

## 9.1 Provider Status Composition Contract

Provider status is intentionally not stored inside `MatchingObject`.
The frozen recommendation card model remains the rail payload, while
provider/cost/freshness metadata is exposed through a side channel:

```text
ProjectedProviderResult
  -> ProjectedRecommendation
  -> ProjectedRecommendationProvider
  -> ProviderStatusProviding
  -> ChatStore.providerStatusPresentation(for:)

ServerProviderRuntimeReceipt
  -> RuntimeReceiptProviderStatusStore
  -> ProviderStatusProviding
  -> ChatStore.providerStatusPresentation(for:)

RuntimeReceiptProviderStatusStore
  + ProjectedRecommendationProvider
  -> ProviderStatusSourceMultiplexer
  -> ProviderStatusProviding
  -> ChatStore.providerStatusPresentation(for:)
```

Rules:

- `MatchingObject` vocabulary does not grow for provider badges.
- Default stub recommendations return no fake provider status.
- A projected recommendation can expose:
  - provider family/id,
  - cost class,
  - freshness,
  - stale-cache limitation,
  - blocked privacy/cost/terms reason,
  - card hint (`normal`, `warning`, `disabled`).
- The UI may later bind this side channel into a provider badge row, but
  must not change `ActionCardShell` layout without a visual contract
  update.
- Runtime receipts may be looked up by recommendation id through the same
  side channel, but must not be copied into `MatchingObject`.
- Multiple provider-status sources may be composed by explicit priority order.
  The composition layer returns the first available status and must not know
  whether a source is receipt-backed, projection-backed, or future runtime-backed.
- `ChatStore.providerStatusPresentation(for:)` filters by the current
  `recommendedMatches` ids before consulting the side channel, so stale receipt
  or provider status cannot surface for non-rendered cards.

## 10. Next Implementation Order

1. Done: add comment-only provider routing scaffolds.
2. Done: add pure value contracts for provider descriptors, membership
   tier, cost policy, provider request/selection, and trace.
3. Done: add tests for provider choice, search/crawler blocks, and MCP
   allowlist/confirmation/resource gates.
4. Done: add deterministic fixture projection via `ResultProjector`.
5. Done: bind provider/cost/freshness status as a non-invasive side
   channel.
6. Done: add first App Intents bridge for kAir-owned actions only.
7. Done: replace Model Library hardcoded cards with truthful
   catalog/download/entitlement-driven state.
8. Done: add a read-only Search vertical adapter that consumes the
   reserved search policy/result envelope without implementing raw
   in-app crawling.
9. Done: wire Search into app-owned navigation/App Intents while
   preserving read-only provider/crawler boundaries.
10. Done: refresh the research/market architecture audit and interface
   reservation matrix before any server-side provider envelope lands.
11. Done: add a pure server/provider transport envelope, validator,
   audit record, mock transport, and focused tests; no network runtime.
12. Done: add a pure adapter/fixture layer that converts existing
   provider/search/MCP policy decisions plus quota snapshot into
   `ServerProviderEnvelope` values; still no endpoint, crawler runtime,
   provider SDK, MCP client, booking, order, or payment path.
13. Done: add a pure dry-run evaluation report that compares candidate
   envelopes, records quota/cost/fallback reasons, and produces an
   audit-only provider plan without executing it.
14. Done: add pure presentation projection for dry-run reports so UI can
   show provider/cost/freshness/source status without claiming execution.
15. Done: bridge dry-run presentation into the existing
   `ProviderStatusPresentation` side channel without changing rail layout
   or executing providers.
16. Done: add a pure server-provider execution-readiness gate so future
   runtime work has one last explicit local-only/server-ready/blocked
   decision before any transport can be called.
17. Done: add a protocol/value runtime registry contract so future
   server-ready decisions can resolve a provider adapter descriptor without
   endpoints, SDKs, credentials, crawler runtime, MCP client runtime, or
   transport execution.
18. Done: add a pure runtime invocation-plan contract that combines A16
   readiness and A17 descriptor lookup into a non-executing plan while
   preserving local-only, blocked, confirmation, and descriptor-missing
   reasons.
19. Done: add a pure runtime dispatch-boundary contract that consumes A18
   plans and prepares future adapter dispatch without executing providers.
20. Done: add a pure runtime adapter protocol/result contract that consumes
   prepared A19 boundaries and returns fixture-only adapter results without
   contacting providers.
21. Done: add a pure runtime adapter registry/selection contract that maps
   prepared A19 boundaries to fixture adapters by provider family without
   contacting providers.
22. Done: add a pure runtime receipt/projection contract that converts A21
   adapter results into UI/audit-safe receipts without adding endpoints,
   SDKs, crawler runtime, MCP clients, payment/order/booking writes, or
   transport execution.
23. Done: bridge runtime receipts into the existing provider status side
    channel so UI can display fixture/local/blocked/confirmation/cost/source
    state without changing rail layout or claiming execution.
24. Done: add a pure runtime receipt status lookup/provider contract that
   stores receipts by recommendation id and conforms to the existing
   provider-status side channel without mutating recommendation cards.
25. Done: add a pure provider-status source multiplexer that queries receipt
   status first and falls back to projected recommendation status without UI,
   ChatStore, or provider-runtime changes.
26. Done: add explicit ChatStore provider-status source injection so the app
   can pass the A25 multiplexer while preserving default no-fake-status
   behavior and hiding statuses for non-rendered recommendation ids.
27. Done: wire the app composition root so `AppBootstrap` can carry an explicit
   provider-status source and `ChatHomeView` passes it into `ChatStore` without
   changing UI layout or adding provider runtime calls.
28. Done: render provider-status presentations in the Chat Recommended Next UI
   through the existing side channel, without mutating `MatchingObject`, changing
   trust-pill vocabulary, or claiming provider execution.
29. Done: wire the app composition root so `AppBootstrap` can carry an explicit
   `RecommendationProvider` and `ChatHomeView` passes it into `ChatStore`, allowing
   projected recommendation providers to line up card ids with provider status.
30. Done: assemble the app-root provider-status source composition so explicit
   receipt-derived status can be prioritized ahead of projected recommendation
   fallback without `ChatStore` inferring source order or executing providers.
31. Done: add a pure provider-access profile that centralizes membership tier,
   preferred provider, metered entitlements, experimental enablement, region, and
   cache-fallback defaults before provider requests are built.
32. Done: extend the provider-access profile to build search/crawler and MCP
   requests so those reserved interfaces inherit the same membership, privacy,
   entitlement, experimental-enable, and confirmation inputs without runtime calls.
33. Done: thread the provider-access profile through app composition and
   search-intent request lowering so membership/cost defaults are not duplicated
   by vertical fixtures.
34. Done: thread the provider-access profile into the Search capability adapter
   configuration so fixture adapter decisions use the same profile path as
   app-root and intent lowering.
35. Done: add an explicit reserved Search adapter factory seam that can build a
   profile-aware search adapter without registering `.webSearch` in the default
   shipped registry.
36. Done: add explicit registry composition for an already-built Search adapter
   so `.webSearch` can be installed only by opt-in callers while the default
   shipped registry remains unchanged.
37. Done: wire app-bootstrap opt-in for the reserved Search adapter so
   membership/profile-driven Search can be assembled by the composition root
   without changing the default local-only registry.
38. Done: prove reserved Search capability availability propagates from
   AppBootstrap into ChatStore/ChatHome composition without triggering provider
   runtime, crawler, MCP, or network behavior.
39. Done: add a pure Chat Search availability presentation/state mapping so the
   chat layer can distinguish not-in-build, registered-unavailable, and
   registered-available Search without executing Search.
40. Done: add a non-executing Chat Search availability display model that maps
   the A39 state to stable icon/tone/accessibility copy without adding visible
   UI or calling Search.
41. Done: bind the Search availability display into a non-interactive Chat UI
   affordance, visible only when Search is explicitly registered, without adding
   a Search action or provider execution.
42. Done: add a single non-network server-provider runtime pipeline that
   composes readiness, descriptor lookup, invocation planning, dispatch,
   fixture-adapter resolution, and receipt projection without calling
   `ServerTransport.send`.
43. Done: prove pipeline-generated receipts can feed the existing
   `RuntimeReceiptProviderStatusStore` / `ProviderStatusSourceMultiplexer`
   path by recommendation id, preserving distinct fixture, local-only, blocked,
   confirmation, descriptor-unavailable, plan-rejected, and unavailable status
   presentations without adding app runtime execution.
44. Done: prove an app-root caller can supply a precomputed
   `RuntimeReceiptProviderStatusStore` through `AppBootstrap.providerStatusSources`
   so ChatStore/ChatHome composition can consume pipeline-derived status without
   making AppBootstrap or views execute the pipeline.
45. Done: add a pure bridge from `ProviderAccessProfile` into
   `ServerProviderQuotaSnapshot` so membership, metered entitlements,
   unavailable providers, experimental enablement, and explicit quota inputs can
   be assembled before any real Google/Gaode/Search/Crawler/MCP transport exists.
46. Done: wire the app composition root so `AppBootstrap` can carry an explicit
   `ServerProviderQuotaSnapshot`, defaulting to the local-only snapshot derived
   from `providerAccessProfile`, without using it to execute providers yet.
47. Done: thread provider quota snapshots into reserved Search adapter
   configuration while keeping adapter resolution non-network and
   default/legacy behavior preserved.
48. Done: build a non-executing Search dry-run envelope preview from Search
   decisions plus the stored quota snapshot, without calling `resolve`,
   transport, crawler, MCP, or runtime pipeline.
49. Done: project the Search dry-run report into UI-safe advisory presentation
   copy using existing dry-run presentation contracts, without rendering UI or
   implying a provider was called.
50. Done: bridge Search dry-run presentations into a provider-status source by
   recommendation id, without wiring Chat UI, executing Search, or mutating
   recommendation cards.
51. Done: prove app-root callers can install a precomputed
   `SearchDryRunProviderStatusStore` through `AppBootstrap.providerStatusSources`
   so ChatStore/ChatHome composition can consume Search dry-run status by rendered
   recommendation id without making AppBootstrap or views generate Search dry-runs.
52. Done: add a Search adapter-owned value helper that packages a
   precomputed Search dry-run presentation/report into a
   `SearchDryRunProviderStatusStore` for a caller-supplied recommendation id,
   without wiring AppBootstrap, ChatStore, views, Search execution, transport, or
   runtime pipeline.
53. Done: add a batch value helper that packages multiple caller-supplied
   recommendation ids with precomputed Search dry-run presentations into one
   deterministic `SearchDryRunProviderStatusStore`, preserving first-entry
   duplicate behavior and missing-id nil lookup without app/UI or Search runtime.
54. Done: document the Search dry-run status source handoff contract so only
   composition/recommendation-source layers precompute sources, while app/view
   layers consume `ProviderStatusProviding` without generating dry-runs.
55. Done: add a value-only Search dry-run status source producer skeleton for the
   recommendation/search composition layer, backed by tests and explicit
   recommendation ids, without AppBootstrap, ChatStore, views, transport,
   crawler/MCP, provider runtime, telemetry, or navigation changes.
56. Done: prove a producer-built `SearchDryRunProviderStatusStore` can be passed
   through the existing app-root `providerStatusSources` path and consumed by
   ChatStore for rendered recommendation ids, without making app/root/view layers
   instantiate the producer or generate dry-runs.
57. Done: add a value-only rendered-id guard source for producer-built Search
   dry-run status, so composition code can expose `ProviderStatusProviding` only
   for explicit rendered recommendation ids before app-root injection.
58. Done: prove a guarded producer-built Search dry-run source can pass through
   `AppBootstrap(providerStatusSources:)` and remain hidden-id safe before and
   after ChatStore composition, without app/root/view layers generating dry-runs.
59. Done: add a value-only runtime adapter injection set so future real provider
   adapters can be installed by server/composition code while the default path
   remains fixture-only and non-network.
60. Done: prove the runtime pipeline can consume an explicit adapter set while
   preserving the default fixture-only pipeline path and all non-prepared
   boundary semantics.
61. Done: prove receipts produced through the injected adapter-set pipeline can
   feed `RuntimeReceiptProviderStatusStore` / `ProviderStatusSourceMultiplexer`
   by explicit recommendation id without app/root/view runtime execution.
62. Done: add a value-only runtime pipeline status source producer skeleton that
   packages explicit recommendation ids with injected-pipeline receipts into
   `RuntimeReceiptProviderStatusStore`, without app/root/view generation,
   network, provider SDKs, crawler/MCP runtime, payment, or real provider calls.
63. Done: prove the producer-built runtime status source can pass through the
   existing app-root provider-status source path and be consumed by ChatStore for
   rendered recommendation ids without app/root/view layers generating runtime
   receipts.
64. Done: add a value-only rendered-id guard source for producer-built runtime
   status so composition code can expose `ProviderStatusProviding` only for
   explicit rendered recommendation ids before app-root injection.
65. Done: prove the guarded producer-built runtime source can pass through the
   existing app-root provider-status source path and remain hidden-id safe before
   and after ChatStore composition.
66. Done: add a value-only real-provider adapter readiness matrix before any
   Google/Gaode/Search/Crawler/MCP runtime implementation can be installed.
67. Done: add a value-only readiness gate for injected adapter installation so
   future real provider adapters cannot be selected unless their family report is
   ready.
68. Done: validate already-created injected adapter sets by registered provider
   families against readiness-installation decisions before any set can be used.
69. Done: authorize each future adapter-set use by requested provider family
   against the accepted set validation before any resolve path can be entered.
70. Done: prove the runtime pipeline injected-adapter overload can require A69
   authorization before entering the existing adapter-set resolve path.
71. Done: let runtime status-source producer callers package authorized
   injected-pipeline receipts with A68 validation instead of the older
   unvalidated adapter-set path.
72. Done: prove authorized producer-built runtime status sources can pass
   through app-root provider-status composition and remain rendered-id scoped.
73. Done: add a value-only runtime adapter manifest catalog so future real
   provider adapters have typed capability, cost, region, privacy, source, MCP,
   and readiness prerequisites before any provider implementation or endpoint
   exists.
74. Done: prove future adapter installation decisions must be manifest-backed
   before consuming readiness reports, so no provider family can bypass the A73
   catalog.
75. Done: prove already-created adapter-set validation can consume only
   manifest-backed installation decisions before delegating to A68 set validation.
76. Done: prove adapter-set use authorization can consume only manifest-backed
   set validation before delegating to A69 use authorization.
77. Done: prove the injected-adapter pipeline can consume manifest-backed use
   authorization before any adapter-set resolve path.
78. Done: prove runtime-status source production can package manifest-backed
   injected-pipeline receipts by explicit recommendation id.
79. Done: prove manifest-backed runtime-status sources can pass through app-root
   provider-status composition and remain rendered-id scoped.
80. Done: add the smallest value-only real-provider connector boundary before
   any actual Google/Gaode/Search/crawler/MCP runtime integration.
81. Done: prove prepared dispatch boundaries can derive value-only connector
   requests from A73 manifests and A76 authorization before connector execution.
82. Done: prove A81 connector requests can produce value-only connector
   invocation receipts through an injected connector boundary.
83. Done: prove A82 connector invocation receipts can package rendered-id scoped
   advisory provider-status sources.
84. Done: prove A83 connector receipt status sources can pass through app-root
   provider-status composition while remaining rendered-id scoped.
85. Done: refresh the research, market, prompt/interface, and provider cut plan
   from current sources; select Search API as the first provider-specific
   contract-only cut.
86. Done: add the value-only Search API server adapter contract proof without
   network, endpoint, SDK, credential, crawler, MCP, UI, or provider execution.
87. Done: package A86 Search API adapter request/result receipts into the
   existing provider-status side channel by explicit recommendation id.
88. Done: prove A87 Search API adapter status sources pass through app-root
   provider-status composition while remaining rendered-id scoped.
89. Done: add a value-only Search API adapter status source producer that filters
   caller-supplied A86/A87 values to explicit rendered recommendation ids before
   app-root injection.
90. Done: prove the A89 producer-built guarded Search API adapter status source
   passes through app-root provider-status composition and ChatStore lookup while
   remaining rendered-id scoped.
91. Done: add a value-only Search API adapter transport payload boundary that
   derives an outbound-safe request payload from prepared A86 metadata without
   endpoints, credentials, SDKs, network execution, or provider claims.
92. Done: add a value-only Search API adapter payload dispatch gate that proves
   only prepared A91 payloads matching their A86 request metadata can become
   dispatch-eligible, still without network execution or provider claims.
93. Done: package A92 Search API adapter payload dispatch receipts into the
   rendered-id scoped provider-status side channel without provider execution,
   endpoint, credential, SDK, crawler, MCP, UI, or root runtime changes.
94. Done: prove the A93 dispatch status source can pass through app-root
   provider-status composition and ChatStore lookup while remaining
   rendered-id scoped, advisory, and execution-free.
95. Done: prove A93 payload dispatch status composes deterministically with
   earlier Search API adapter request/result status sources at app-root and
   ChatStore lookup, with first-wins ordering and no runtime execution.
96. Done: add a value-only Search API adapter fixture transport bridge contract
   that consumes only eligible A91/A92 metadata and emits audit-only fixture
   responses without endpoints, credentials, SDKs, crawler/MCP, or provider
   execution.
97. Done: package A96 fixture bridge responses into the rendered-id scoped
   provider-status side channel with advisory ready/rejected copy, no query
   leakage, no app-root/UI wiring, and no provider execution.
98. Done: prove A97 fixture bridge status sources pass through app-root
   provider-status composition and ChatStore lookup while remaining rendered-id
   scoped, advisory, and execution-free.
99. Done: prove A97 fixture bridge status composes deterministically with
   earlier A89/A90 request/result status and A93 dispatch status at app-root
   and ChatStore lookup, with first-wins ordering and no stale detail mixing.
100. Done: prove Search API adapter cost and entitlement outcomes remain
   explicit across A86 request decisions, A91 payloads, A92 dispatch receipts,
   A96 fixture bridge responses, and A97 status copy, without silent premium
   fallback or provider execution.
101. Done: prove Search API adapter source, citation, and attribution outcomes
   remain explicit across A86 request decisions, A91 payloads, A92 dispatch
   receipts, A96 fixture bridge responses, and A97 status copy, without hidden
   source-host leakage or provider execution.
102. Done: prove Search API adapter result freshness, content, and limitation
   outcomes remain explicit across A86 result receipts and status copy, without
   stale live-required results, empty content, query leakage, raw page content,
   or provider execution.
103. Done: prove A102 result freshness/content/limitation status sources pass
   through app-root provider-status composition and ChatStore lookup while
   remaining rendered-id scoped, advisory, and execution-free.
104. Done: refresh the research/market/provider cut plan against current
   public agent, life-service, tool-use, and provider-policy evidence before
   choosing the first real-provider integration slice.
105. Done: add a value-only Search API vendor policy matrix that can select or
   reject Search API vendors by cost, quota, freshness, source/citation,
   raw-content/retention, and result-shape requirements without provider
   execution.
106. Done: package A105 vendor policy decisions into rendered-id scoped
   provider-status copy, preserving accepted/blocked status and safe rejection
   reasons without app-root generation or provider execution.
107. Done: prove A106 vendor policy status sources pass through
   `AppBootstrap(providerStatusSources:)` and ChatStore lookup for rendered
   recommendation ids only, with accepted/rejected copy and source-order
   first-wins behavior preserved.
108. Done: add a value-only Search API vendor policy dispatch authorization
   gate that combines A92 dispatch receipts with A105 vendor decisions and
   rejects missing, rejected, non-dispatch, provider/capability/cost/freshness
   mismatch, and result-shape mismatch paths before any transport call.
109. Done: package A108 dispatch authorization results into rendered-id scoped
   provider-status copy, preserving authorized/blocked status, nested dispatch
   and vendor reasons, hidden-id nil lookup, missing-id nil lookup, and
   duplicate first-wins behavior.
110. Done: prove A109 dispatch authorization status sources pass through
   `AppBootstrap(providerStatusSources:)` and ChatStore lookup for rendered
   recommendation ids only, preserving authorized/blocked copy, hidden-id nil
   lookup, missing-id nil lookup, and source-order first-wins behavior.
111. Done: prove A106 vendor policy status, A93 payload dispatch status, and
   A109 dispatch authorization status compose deterministically through
   `AppBootstrap(providerStatusSources:)` and ChatStore lookup, preserving
   first-wins ordering, hidden-id nil lookup, and no stale detail/query/
   execution-copy mixing.
112. Done: add a value-only Search API vendor-authorized transport lease and
   cost-budget guard that consumes A91/A92/A108 metadata, rejects missing or
   over-budget paths, and emits safe lease copy without endpoint, credential,
   network transport, crawler/MCP runtime, or provider execution.
113. Done: package A112 transport lease results into rendered-id scoped
   provider-status copy, preserving issued/rejected lease and nested payload/
   dispatch/authorization/budget reasons without app-root, ChatStore, UI,
   transport, endpoint, crawler/MCP runtime, or provider execution changes.
114. Done: prove A113 transport lease status sources pass through
   `AppBootstrap(providerStatusSources:)` and ChatStore lookup for rendered
   recommendation ids only, preserving issued/rejected copy, hidden-id nil
   lookup, missing-id nil lookup, and source-order first-wins without
   production root, UI, transport, endpoint, crawler/MCP runtime, or provider
   execution changes.
115. Done: prove A106 vendor policy status, A93 payload dispatch status, A109
   dispatch authorization status, and A113 transport lease status compose
   deterministically through app-root and ChatStore lookup, preserving
   first-wins ordering, hidden-id nil lookup, and no stale vendor/dispatch/
   authorization/lease/budget/query/execution-copy mixing.
116. Done: re-run the current research/market/provider cut-plan against
   the completed Search API value-only pipeline. Current paper/vendor/
   competitor evidence says not to start live Search API transport yet; the
   next safe gate is a server-provider metered entitlement ledger that can
   normalize membership, quota period, used/reserved/remaining units, and
   vendor-family budget decisions before any endpoint exists.
117. Done: add a value-only Server Provider Metered Entitlement Ledger proof
   that can feed Search API vendor policy and transport lease decisions with
   server-verified budget/entitlement state, without StoreKit, endpoint URLs,
   API keys, SDK clients, network transport, crawler/MCP runtime, Google/Gaode
   SDKs, UI, ChatStore, AppBootstrap production defaults, or provider calls.
118. Done: package A117 metered entitlement usage decisions into rendered-id
   scoped provider-status copy by explicit recommendation id, preserving
   accepted/blocked budget copy, duplicate first-wins behavior, hidden/missing
   nil lookup, and no app-root generation, runtime, transport, provider, MCP,
   crawler, StoreKit, Google/Gaode SDK, UI, or memory changes.
119. Done: prove A118 metered entitlement status sources pass through
   `AppBootstrap(providerStatusSources:)` and ChatStore lookup for rendered
   recommendation ids only, preserving accepted/rejected budget copy,
   hidden/missing nil lookup, and source-order first-wins without production
   root, UI, runtime, transport, provider, MCP, crawler, StoreKit,
   Google/Gaode SDK, or memory changes.
120. Done: prove A118 metered entitlement status composes deterministically
   with A106 vendor policy status, A93 payload dispatch status, A109 dispatch
   authorization status, and A113 transport lease status through app-root and
   ChatStore lookup, preserving first-wins ordering, hidden-id nil lookup, and
   no stale budget/vendor/dispatch/authorization/lease/query/execution-copy
   mixing.
121. Done: re-run the current research/market/provider cut-plan against the
   completed metered entitlement status stack. Current evidence says live
   provider runtime remains premature; first prove that accepted A117 metered
   entitlement decisions drive A112 transport leases.
122. Done: prove A112 Search API transport lease issuance can be driven by
   accepted A117 metered entitlement budget contexts, while rejected or
   mismatched entitlement decisions cannot issue leases.
123. Done: prove A122 metered-entitlement transport leases package into A113
   provider-status copy and pass through app-root and ChatStore lookup with
   hidden/missing nil behavior, new metered-entitlement rejection copy, and
   source-order determinism.
124. Done: prove A123 metered-entitlement transport lease status composes
   deterministically with A118 metered entitlement, A106 vendor policy, A93
   payload dispatch, and A109 dispatch authorization status through app-root and
   ChatStore lookup, preserving first-wins ordering and no stale
   budget/vendor/dispatch/authorization/lease detail mixing.
125. Done: re-run the current research, market, and provider cut-plan against
   the completed A124 metered-entitlement transport lease status composition
   stack, including current agent papers, MCP/security work, mobile GUI-agent
   research, Apple/Google/Gaode/Search provider docs, and competitor signals
   before selecting the next code gate.
126. Done: add a value-only Search API transport request contract that can be
   prepared only from an issued A122 metered-entitlement lease and matching
   request, payload, dispatch, vendor policy, authorization, result-shape,
   source, citation, freshness, cost, and metered decision metadata. Do not add
   endpoints, credentials, URLSession, crawler/MCP, Google/Gaode SDKs, or live
   provider execution.
127. Done: package A126 transport request decisions into a rendered-id scoped
   provider-status source, preserving prepared/rejected advisory copy,
   duplicate first-wins behavior, hidden/missing nil lookup, and no raw query,
   source-host, endpoint, credential, SDK, crawler/MCP, maps, or execution
   leakage.
128. Done: prove A127 transport request status sources pass through
   `AppBootstrap(providerStatusSources:)` and ChatStore lookup for rendered ids
   only, preserving prepared/rejected copy, hidden/missing nil lookup,
   source-order first-wins, and no stale request/vendor/lease/budget/metered
   detail mixing.
129. Done: compose A127 transport request status with A118 metered entitlement,
   A106 vendor policy, A93 payload dispatch, A109 dispatch authorization, and
   A113 transport lease status through app-root and ChatStore lookup,
   preserving first-wins ordering, hidden/missing nil lookup, and no stale
   upstream detail mixing.
130. Done: refresh research, market, provider-policy, UI, MCP, crawler, maps,
   and cost-aware routing evidence after A129. Current evidence still rejects
   live provider runtime and selects a value-only A131 Search API transport
   response receipt contract proof as the next code gate.
131. Done: add a value-only Search API transport response receipt contract that
   binds a normalized/cited adapter result receipt to the prepared A126
   transport request and rejects stale or mismatched request, result, source,
   citation, cost, freshness, vendor, lease, budget, and metered metadata before
   any endpoint, credential, URLSession, SDK, crawler/MCP, Google/Gaode,
   payment, booking, hidden app control, or provider execution exists.
132. Done: package A131 transport response decisions into a rendered-id scoped
   provider-status source, preserving accepted/rejected advisory copy,
   duplicate first-wins behavior, hidden/missing nil lookup, safe citation/
   result-count summary copy, and no raw query, citation URL, source-host
   value, endpoint, credential, SDK, crawler/MCP, maps, payment, booking,
   hidden app-control, or execution leakage.
133. Done: prove A132 transport response status sources pass through
   `AppBootstrap(providerStatusSources:)` and ChatStore lookup for rendered ids
   only, preserving accepted/rejected copy, hidden/missing nil lookup,
   source-order first-wins, and no stale response/request/result/vendor/lease/
   budget/metered detail mixing without production root, UI, or runtime changes.
134. Done: compose A132 transport response status with A118 metered entitlement,
   A106 vendor policy, A93 payload dispatch, A109 dispatch authorization, A113
   transport lease status, and A127 transport request status through app-root
   and ChatStore lookup, preserving first-wins ordering, hidden/missing nil
   lookup, and no stale response/request/result/vendor/dispatch/authorization/
   lease/budget/metered detail mixing.
135. Done: add a value-only external provider transport adapter interface
   preflight contract for future Search API, Google/Gaode maps, crawler, and
   MCP paths. The contract must preserve server-side cost, membership,
   entitlement, source, attribution, privacy, and UI-safe status gates while
   still rejecting live endpoints, API keys, SDK clients, URLSession, crawler
   runtime, MCP runtime, payment/booking, hidden app control, and provider
   execution.
136. Done: package A135 external provider transport adapter preflight decisions
   into rendered-id scoped provider-status copy for Search API, Google/Gaode
   maps, crawler, and MCP paths, preserving accepted/rejected advisory text,
   duplicate first-wins behavior, hidden/missing nil lookup, and no endpoint,
   credential, SDK, URLSession, crawler/MCP runtime, maps SDK, payment,
   booking, hidden app-control, or execution leakage.
137. Done: prove A136 external provider transport adapter status sources pass
   through `AppBootstrap(providerStatusSources:)` and ChatStore lookup for
   rendered ids only, preserving accepted/rejected copy, hidden/missing nil
   lookup, source-order first-wins, and no stale provider/runtime or unsafe
   endpoint/credential/SDK detail mixing.
138. Done: compose A136 external provider transport adapter preflight status
   with existing provider-status sources through `AppBootstrap` and ChatStore,
   proving first-source-wins selection across Search API metered/vendor/
   dispatch/authorization/lease/request/response stages and generic fallback
   sources, while hidden/missing ids stay nil and selected copy does not mix
   stale provider, cost, source, metered, lease, request, response, or preflight
   details.
139. Done: refreshed current research, market, provider-policy, MCP, crawler,
   and iOS platform evidence after the A138 status stack. The refreshed cut
   plan keeps live provider transport blocked and selects a value-only audit
   trace/evaluation contract as the next gate, because Search API, Google/
   Gaode, crawler, MCP, and remote model attempts still need explicit cost,
   source, attribution, privacy, membership, status-source, and evaluation
   metadata before runtime execution.
140. Done: added a value-only external provider transport audit trace and
   evaluation contract proof. The contract covers Search API, Google/Gaode
   maps, crawler, MCP, and remote model families; preserves rendered id,
   provider family, capability, membership, cost, privacy, source/citation/
   attribution policy, status-source rank, confirmation state, and evaluation
   dimensions; and rejects missing policy, unsupported capability, blocked
   cost/privacy, disabled crawler/MCP, missing confirmation, missing evaluation
   dimensions, or unsafe runtime material without adding transport.
141. Done: projected A140 audit events into rendered-id scoped
   provider-status copy. The projection follows the existing status-source
   pattern, preserves accepted/rejected audit copy, duplicate first-wins
   behavior, hidden/missing nil lookup, safe badges/card hints, and no stale
   provider/cost/privacy/status-source/evaluation detail mixing without
   AppBootstrap, ChatStore, SwiftUI, live transport, endpoint, credential,
   SDK/client, crawler/MCP runtime, maps runtime, raw payload,
   payment/booking/order, hidden app-control, or real provider execution.
142. Done: proved the A141 audit-event status source passes through
   `AppBootstrap(providerStatusSources:)` and ChatStore lookup for rendered ids
   only. Tests cover accepted Search API audit status, accepted remote-model
   audit status, rejected privacy-blocked audit status, hidden/missing nil
   lookup, exact source-to-root-to-store copy, and source-order first-wins
   against fallback status without production defaults, SwiftUI, navigation,
   live transport, endpoints, credentials, SDK/client handles, crawler/MCP
   runtime, maps runtime, raw payloads, payment/booking/order, hidden app-control,
   or real provider execution.
143. Done: composed A141 audit-event status with the earlier Search API,
   metered, vendor, dispatch, authorization, lease, request, response, preflight,
   and generic fallback status sources through AppBootstrap and ChatStore. Tests
   prove source-order first-wins when audit status is first, when existing
   status-stack sources are first, and when fallback is first; they also prove a
   non-Search remote-model audit status composes with fallback ordering, while
   hidden/missing ids stay nil and selected copy does not mix stale provider,
   cost, privacy, status-source, policy, metered, vendor, dispatch,
   authorization, lease, request, response, preflight, audit, fallback, or
   evaluation detail.
144. Done: added the Search API live-transport boundary comment-programming
   artifact. The boundary is a compile-safe value-only planning document that
   pins the upstream chain, readiness checklist, safe status/debug copy, and
   non-callable A144 state without endpoint URLs, keys, OAuth tokens, URLSession,
   SDK/client handles, crawler/MCP runtime, maps runtime, production
   AppBootstrap defaults, ChatStore behavior changes, SwiftUI changes, raw
   payload ingestion, payment/booking/order flows, hidden app-control, or real
   provider execution.
145. Done: turned the A144 boundary comments into a value-only readiness gate.
   The gate consumes the A144 boundary document and explicit safe evidence ids,
   accepts only when every upstream checkpoint and runtime checklist item is
   covered, and rejects missing evidence, duplicate evidence ids, unknown
   evidence targets, callable runtime entrypoints, stale boundary ids, unsafe
   material markers, or live-provider-path enablement. It remains non-callable
   and planning-only.
146. Done: packaged the A145 readiness decision into rendered-id scoped
   provider-status copy. The source exposes planning evidence as advisory
   visible-card status only, marks the provider path disabled, maps rejected
   decisions to stable advisory badges, preserves duplicate first-wins and
   hidden/missing nil lookup, and keeps selected copy free of stale boundary,
   readiness, unsafe-material, live-path, endpoint, credential, SDK/client,
   crawler/MCP, maps runtime, payload, payment/booking/order, hidden
   app-control, or real provider execution details.
147. Done: proved the A146 readiness status source passes through
   `AppBootstrap(providerStatusSources:)` and ChatStore lookup for rendered ids
   only. Tests cover accepted and rejected readiness status, hidden/missing nil
   lookup before and after app-root composition, exact source-to-root-to-store
   copy, and first-wins ordering against fallback status without production
   default, ChatStore behavior, SwiftUI, navigation, networking, or provider
   runtime changes.
148. Done: composed the A146 readiness status source with the earlier Search
   API status stack through `AppBootstrap(providerStatusSources:)` and
   ChatStore. Tests cover readiness-first, earlier-stack-first, and
   fallback-first ordering, exact root-to-store selected copy, hidden/missing
   nil lookup, and no stale readiness, fallback, metered, vendor, dispatch,
   authorization, lease, request, response, preflight, audit, endpoint,
   credential, SDK/client, crawler/MCP, maps runtime, raw payload,
   payment/booking/order, hidden app-control, or real provider execution detail
   leaking into the selected copy.
149. Done: refreshed market, paper, open-source-agent, MCP, Search API, maps,
   and crawler evidence after A148. Decision: A150 must not start live Search
   API transport. The missing proof is a value-only live vendor candidate
   selection and cost-policy matrix that can reject unsafe Search API vendors
   by capability, freshness, result shape, citation/source support, raw-content
   and retention policy, privacy, region, quota/QPS, and max cost before any
   endpoint, credential, URLSession, SDK/client, crawler/MCP runtime, map SDK,
   or provider execution exists.
150. Done: added `ServerProviderSearchAPILiveVendorSelection` as a pure value
   candidate-selection and cost-policy matrix. It models live Search API vendor
   candidates, selection requests, selected/rejected decisions, duplicate-id
   first-wins, ordered safe candidate summaries, deterministic rejection
   reasons, and status-safe copy. Tests cover capability, freshness, result
   shape, citation/source support, page-body and retention policy, privacy,
   region, quota/QPS, max cost, disabled vendors, missing quota, Health blocks,
   duplicate ids, empty lists, Codable/Hashable/Sendable behavior, and no
   endpoint, credential, URLSession, SDK/client, raw query/page/provider
   payload, crawler/MCP runtime, map SDK, payment/booking/order, hidden
   app-control, or execution/completion detail in safe copy.
151. Done: added
   `ServerProviderSearchAPILiveVendorSelectionStatusSourceProducer` and focused
   tests. A150 selected/rejected live vendor selection decisions now package into
   rendered-id scoped provider-status copy, duplicate recommendation ids keep the
   first input, hidden/missing ids return nil, selected decisions render advisory
   warning copy with Search API/candidate/cost badges, and rejected decisions
   render disabled warning copy with stable rejection badges. Status text and
   encoded safe copy carry only A150 metadata and no endpoint, credential,
   URLSession, SDK/client, raw query/page/provider payload, crawler/MCP runtime,
   map SDK, payment/booking/order, hidden app-control, or execution/completion
   detail.
152. Done: added focused AppBootstrap tests proving the A151 live vendor
   selection status source passes through `AppBootstrap(providerStatusSources:)`
   and ChatStore lookup for rendered ids only. Selected/rejected copy is
   identical from source to root to store, hidden/missing ids stay nil, and
   fallback source-order first-wins does not leak stale fallback detail into the
   selected live vendor selection status. This did not add live transport,
   endpoints, credentials, URLSession, provider adapters, crawler/MCP runtime,
   Google/Gaode SDK, StoreKit/payment, SwiftUI, memory, telemetry, transcript,
   booking/order, hidden app-control, or real provider execution.
153. Done: added a cross-stage AppBootstrap composition test for the A151 live
   vendor selection status source plus the existing Search API status stack.
   Live vendor selection, metered entitlement, vendor policy, dispatch,
   authorization, lease, request, response, preflight, audit, and fallback
   sources are each tested as the first source. Root and ChatStore lookup return
   identical selected copy, hidden/missing ids stay nil, and later source
   markers do not leak into the selected presentation. This remains status-only:
   no live transport, endpoint, credential, URLSession, SDK/client, crawler/MCP
   runtime, Google/Gaode SDK, StoreKit/payment, SwiftUI, memory, telemetry,
   transcript, raw payload, booking/order, hidden app-control, or real provider
   execution was added.
154. Done: refreshed market, UI, paper, open-source-agent, MCP/search/crawler,
   maps, Search API vendor, and provider-constraint evidence after A153. The
   decision is that A155 may start a narrow live-transport proof only as
   comment-programming/value-only server adapter interface work. It must still
   avoid URLSession, endpoint URLs, credentials, OAuth, SDK/client handles, live
   provider calls, Google/Gaode SDK/API calls, crawler/MCP runtime, production
   AppBootstrap defaults, ChatStore behavior, SwiftUI provider UI, payment/
   booking/order runtime, raw payload ingestion, hidden app-control, and
   execution/completion claims.
155. Done: added a Search API live transport server adapter interface proof.
   The new metadata-only descriptor, request, summary, decision, and safe-copy
   values bind selected vendor, metered entitlement, lease, transport request,
   audit, boundary, readiness, result/freshness/cost/source requirements, region,
   kill-switch, retry policy, and server-owned secret mode without making any
   path runtime-callable. Focused tests cover accepted matching descriptors,
   deterministic rejection reasons, duplicate descriptor first-wins, Codable/
   Hashable/Sendable behavior, and forbidden-fragment copy checks without
   URLSession, endpoints, credentials, SDK/client handles, provider calls,
   crawler/MCP runtime, Google/Gaode SDK, payment/booking/order, hidden
   app-control, or execution/completion claims.
156. Done: added
   `ServerProviderSearchAPILiveTransportAdapterInterfaceStatusSourceProducer`
   and focused status-source tests. A155 accepted/rejected adapter interface
   decisions now package into rendered-id scoped provider status with advisory
   accepted copy, disabled rejected copy, stable badges/card hints, duplicate
   recommendation-id first-wins, hidden/missing nil lookup, and
   `isRuntimeCallable false` wording. The copy exposes only safe descriptor
   summary metadata and does not add AppBootstrap defaults, ChatStore behavior,
   SwiftUI, networking, provider runtime, endpoints, credentials, SDK/client
   handles, crawler/MCP runtime, maps runtime, payment/booking/order flows,
   hidden app-control, provider calls, or execution/completion claims.
157. Done: added focused AppBootstrap tests proving the A156 adapter interface
   status source passes through `AppBootstrap(providerStatusSources:)` and
   ChatStore lookup for rendered ids only. Accepted and rejected status copy is
   identical from source to root to store, hidden/missing ids stay nil, and
   source-order first-wins against fallback status prevents stale fallback
   detail from leaking into the selected presentation. This did not change
   production AppBootstrap defaults, ChatStore behavior, SwiftUI, networking,
   provider runtime, endpoints, credentials, SDK/client handles, crawler/MCP
   runtime, maps runtime, payment/booking/order flows, hidden app-control,
   provider calls, or execution/completion claims.
158. Done: added a cross-stage AppBootstrap composition test for the A156
   adapter interface status source plus the existing Search API status stack.
   Adapter interface, live vendor selection, readiness, metered entitlement,
   vendor policy, dispatch authorization, lease, request, response, preflight,
   audit, and fallback sources are each tested as the first source through root
   and ChatStore lookup. Root/store copy stays identical, hidden/missing ids
   stay nil, and later source markers do not leak into the selected
   presentation. This remains status-only: no live transport, endpoint,
   credential, URLSession, SDK/client, crawler/MCP runtime, maps runtime,
   payment/booking/order, hidden app-control, provider call, or execution/
   completion claim was added.
159. Done: refreshed research and cut-plan constraints after the A158
   composition stack. Current paper, product, Search API, MCP/crawler, maps,
   Apple local-first, and cost-routing evidence still rejects direct live
   URLSession/provider integration. The next safe slice is a metadata-only
   server-side invocation preflight contract that joins accepted adapter
   interface, vendor, entitlement, lease, request, boundary, source policy,
   budget, region, and audit metadata before any remote path is callable.
160. Done: added `ServerProviderSearchAPILiveProviderInvocationPreflight` as a
   value-only proof. Accepted decisions require the A155 adapter interface,
   selected vendor, metered entitlement id, lease, request, audit, boundary,
   readiness, cost, source, region, privacy, retention, server-secret, and
   budget metadata to match. Rejected paths cover runtime-callable flags,
   unsupported provider families, mismatched upstream ids, stale readiness,
   expired leases, missing source/citation/attribution, privacy/Health blocks,
   duplicate preflight ids, and policy conflicts. The decision remains
   `isRuntimeCallable false` and adds no endpoint, credential, URLSession,
   SDK/client, crawler/MCP runtime, maps runtime, payment/booking/order, hidden
   app-control, provider call, or execution/completion claim.
161. Done: packaged A160 preflight decisions into
   `ServerProviderSearchAPILiveProviderInvocationPreflightStatusSourceProducer`
   and a rendered-id scoped status store. Accepted preflight copy is advisory
   only with Search API preflight, descriptor/vendor, cost, source, region,
   budget, and `isRuntimeCallable false` copy; rejected copy is disabled with
   stable privacy, cost, readiness, source/terms, region, duplicate, and
   unavailable badge mappings. Duplicate recommendation ids keep first-wins and
   hidden/missing ids stay nil. No AppBootstrap handoff, SwiftUI, networking,
   crawler/MCP, maps SDK, payment/booking/order, provider call, or execution/
   completion claim was added.
162. Done: proved A161 preflight status sources pass through
   `AppBootstrap(providerStatusSources:)` and `ChatStore` rendered-id lookup.
   Accepted/rejected status copy stays identical from source to root to store,
   hidden/missing ids stay nil, and both direct `providerStatusProvider` and
   ordered `providerStatusSources` preserve first-wins against fallback status.
   No production AppBootstrap defaults, ChatStore behavior, SwiftUI, networking,
   crawler/MCP, maps SDK, payment/booking/order, provider call, or execution/
   completion claim was added.
163. Done: proved the A161 preflight status source composes with the existing
   Search API status stack through `AppBootstrap(providerStatusSources:)` and
   `ChatStore` lookup. Invocation preflight, adapter interface, live vendor
   selection, readiness, metered entitlement, vendor policy, dispatch,
   authorization, lease, request, response, transport preflight, audit, and
   fallback sources are each tested as first source. Selected copy remains
   identical from source to root to store, hidden/missing ids stay nil, and
   later source markers do not leak. No production root/UI/runtime/provider
   behavior changed.
164. Done: refreshed the research, market, UI, provider-policy, MCP/crawler,
   Apple local-first, Google/Gaode, Search API, and cost-aware routing cut-plan
   after the A163 invocation-preflight composition proof. Current evidence
   still blocks live provider execution on iOS or through client-side transport.
   The next safe gate is a prepared-only Search API live-provider invocation
   envelope that freezes accepted preflight, vendor, cost, source, retention,
   region, lease, request, and audit metadata without enabling a provider call.
165. Done: added `ServerProviderSearchAPILiveProviderInvocationEnvelope` as a
   pure value/comment-programming contract with focused tests. It accepts only
   an accepted A160 preflight, produces a non-executable envelope, keeps
   `isRuntimeCallable` and `isExecutable` false, rejects
   stale/mismatched/unsafe metadata, duplicate envelope ids, unsafe source/
   retention/redaction policy, unavailable quota, client-owned secret mode, and
   unsafe material flags. No AppBootstrap default, ChatStore behavior, UI,
   networking, provider runtime, crawler/MCP runtime, maps SDK, payment/booking/
   order flow, hidden app-control, provider call, or completion claim was added.
166. Done: added `ServerProviderSearchAPILiveProviderInvocationEnvelopeStatusSourceProducer`
   as a pure projection layer. It turns prepared/rejected A165 envelope safe
   copies into rendered-id scoped provider status, preserves hidden/missing nil,
   duplicate first-wins, `isRuntimeCallable false`, `isExecutable false`, and
   forbidden-fragment guarantees. No AppBootstrap default, ChatStore behavior,
   UI, networking, provider runtime, crawler/MCP runtime, maps SDK, commerce
   flow, hidden app-control, provider call, or completion claim was added.
167. Done: proved the A166 envelope status source passes through
   `AppBootstrap(providerStatusSources:)` and `ChatStore` rendered-id lookup
   with focused AppBootstrap tests. Direct `providerStatusProvider`, ordered
   source arrays, hidden/missing nil, first-wins/fallback behavior, and
   identical prepared/rejected copy from source to root to store are locked.
   No production default wiring, ChatStore production behavior, UI, networking,
   provider runtime, crawler/MCP runtime, maps SDK, commerce flow, hidden
   app-control, provider call, or completion claim was added.
168. Done: composed the A166 envelope status source with the existing Search
   API status stack through `AppBootstrap(providerStatusSources:)` and
   `ChatStore` lookup. A focused AppBootstrap test now proves envelope,
   invocation preflight, adapter interface, live vendor selection, readiness,
   metered entitlement, vendor policy, dispatch authorization, lease, request,
   response, transport preflight, audit, and fallback each preserve first-wins,
   hidden/missing nil, source -> root -> store copy equality, no cross-source
   leakage, and fallback-after-miss behavior. No production default wiring or
   real provider execution was added.
169. Done: added a pure `ServerProviderSearchAPIProviderStatusStackPlan`
   contract and focused tests. The plan freezes envelope, invocation preflight,
   adapter interface, live vendor selection, readiness, metered entitlement,
   vendor policy, dispatch authorization, lease, request, response, transport
   preflight, audit, and fallback ordering; stage ids/ranks; display/debug
   labels; envelope non-executable marker; validation state/reasons; and
   extension slots for future cost and membership routing. Validation catches
   duplicate ids/kinds/ranks, non-contiguous ranks, envelope/fallback ordering
   drift, stage-order drift, and rank/stage drift. Safe copy remains
   value-only, not runtime-callable, and no production `AppBootstrap`,
   `ChatStore`, UI, networking, provider runtime, or real provider behavior was
   added.
170. Done: added a pure `ServerProviderSearchAPICostMembershipRoutingPlan`
   contract and focused tests. The plan consumes the A169 extension-slot
   vocabulary, freezes local fallback, included-quota preferred, metered
   allowed, region review, and cost-blocked advisory route ordering; locks route
   ids/ranks, membership coverage, quota/cost/region postures, UI labels,
   extension notes, validation state/reasons, and a value-only safe copy.
   Validation catches duplicate ids/kinds/ranks, non-contiguous ranks, misplaced
   local fallback, unsupported route kinds, missing membership coverage, and
   missing/duplicate stack extension slots. No production `AppBootstrap`,
   `ChatStore`, UI, networking, provider runtime, or real provider behavior was
   added.
171. Done: added a pure `ServerProviderSearchAPICostMembershipRoutingDecision`
   contract and focused tests. The decision consumes the A170 plan plus safe
   membership, cost, region, privacy, and quota metadata, then returns an
   advisory route label for local fallback, included quota, metered posture,
   region review, cost block, privacy block, invalid plan, missing quota,
   missing membership coverage, and preferred-route mismatch outcomes. Safe copy
   remains value-only and not runtime-callable. No production `AppBootstrap`,
   `ChatStore`, UI, networking, provider runtime, concrete vendor selection, or
   real provider behavior was added.
172. Done: added a pure
   `ServerProviderSearchAPICostMembershipRoutingDecisionStatusSourceProducer`
   and focused tests. A172 packages A171 decision safe copies into rendered-id
   scoped provider status for accepted local fallback, included-quota, and
   metered advisory routes plus rejected region-review, cost-blocked,
   privacy-blocked, invalid-plan, missing-quota, missing-membership-coverage,
   membership-tier, and preferred-route outcomes. Duplicate recommendation ids
   keep first-wins, hidden/missing ids stay nil, and status copy remains
   value-only and not runtime-callable. No production `AppBootstrap`,
   `ChatStore`, UI, networking, provider runtime, concrete vendor selection, or
   real provider behavior was added.
173. Done: proved the A172 routing-decision status source can pass through
   `AppBootstrap(providerStatusSources:)` and `ChatStore` rendered-id lookup.
   Accepted local/included/metered and rejected region/cost/privacy/invalid/
   quota/coverage/preferred-mismatch status copy stays identical from source to
   app root to store. Hidden/missing ids stay nil, duplicate inputs keep
   first-wins, earlier source wins over fallback, and fallback-after-miss still
   works. No production defaults, root-stack composition, concrete vendor
   selection, or real provider behavior was added.
174. Done: composed the A172 routing-decision status source with the existing
   Search API provider-status stack (envelope, invocation preflight, adapter
   interface, live vendor selection, readiness, metered entitlement, vendor
   policy, dispatch authorization, lease, request, response, transport preflight,
   audit, and fallback) through `AppBootstrap(providerStatusSources:)` and
   `ChatStore` lookup. The routing source can be selected first without leaking
   later-source markers, each existing stack source can still be selected first
   without leaking routing markers, root/store copy stays identical to the
   selected source for ready and blocked/review examples, and hidden/missing ids
   stay nil. Fallback-after-miss remains explicit with the full stack ordered
   ahead of fallback. The proof is test-only in `AppBootstrapTests`; no
   production defaults, concrete vendor selection, or real provider behavior was
   added.
175. Done: refreshed the research/market/provider cut plan against current
   agent frameworks, agent-cost papers, MCP security work, consumer-agent UI
   signals, Search API economics, maps/local-life provider policy, crawler
   policy, and Apple local-first surfaces. Decision: A176 must not start live
   provider/runtime work. A174 proves source-order composition, but it does not
   yet prove that cost/membership routing copy is semantically compatible with
   downstream vendor policy, payload dispatch, dispatch authorization, transport
   lease, entitlement, and fallback decisions.
176. Done: proved **Search API cost/membership routing cross-stage policy
   compatibility** in `AppBootstrapTests` only. A176 composes the A172
   routing-decision status source with representative metered entitlement,
   vendor policy, payload dispatch, dispatch authorization, transport lease,
   and fallback sources. Included-quota and metered routes can be selected
   without stale downstream marker mixing; rejected privacy/cost/region routing
   status does not leak vendor/lease detail; downstream-first order does not
   leak routing route/cost/membership markers; hidden/missing ids stay nil;
   fallback-after-miss remains explicit; root/store copy equality is preserved;
   and every selected copy remains value-only with `isRuntimeCallable false`.
177. Done: added a pure **Search API route-policy compatibility contract**
   that binds A171/A172 cost-membership routing, metered entitlement, vendor
   policy, payload dispatch, dispatch authorization, and transport lease
   metadata into one non-executable compatibility decision. Focused networking
   tests prove included-quota and metered compatible paths, routing/downstream
   blocked rejections, vendor/cost/membership/source/citation/lease mismatches,
   deterministic safe copy, `isRuntimeCallable false`, `isExecutable false`,
   and no runtime/sensitive material leakage.
178. Done: added a pure rendered-id scoped **Search API route-policy
   compatibility status source producer**. A178 packages compatible
   included-quota and metered A177 decisions plus rejected routing/downstream
   and mismatch reasons into stable `ProviderStatusPresentation` copy, preserves
   duplicate first-wins and hidden/missing nil lookup, maps reasons to existing
   badge/card-hint vocabulary, and keeps status/debug/encoded copy value-only
   with `isRuntimeCallable false` and `isExecutable false`.
179. Done: proved **Search API route-policy compatibility status app-root
   handoff** in `AppBootstrapTests` only. A179 passes A178 sources through
   `AppBootstrap(providerStatusSources:)` and ChatStore lookup for rendered ids,
   preserves root/store copy equality, first-wins source ordering,
   fallback-after-miss behavior, duplicate recommendation-id first visible input,
   hidden/missing nil lookup, and prevents lower-priority route-policy/fallback
   markers from leaking into selected copy.
180. Done: proved **Search API route-policy compatibility cross-stage status
   composition** in `AppBootstrapTests` only. A180 composes A178 route-policy
   compatibility status with A172 routing, metered entitlement, vendor policy,
   payload dispatch, dispatch authorization, transport lease, and fallback
   sources through `AppBootstrap(providerStatusSources:)` plus ChatStore lookup.
   Route-policy-first and stage-first orders preserve first-wins, selected copy
   does not mix stale upstream/downstream/fallback markers, fallback-after-miss
   stays explicit, hidden/missing ids stay nil, and selected route-policy copy
   remains value-only with `isRuntimeCallable false` and `isExecutable false`.
181. Done: refreshed the **agent market, paper, and provider cut-plan** after
   A180. Current evidence from agent frameworks, tool/memory/cost papers,
   MCP/security work, Tencent/Meituan/Marvis-style market signals, Apple
   local-first docs, Search API vendor policy, Google/Gaode maps obligations,
   and crawler policy still supports kAir's typed, local-first,
   provider-status architecture. Decision: do not widen runtime yet. The next
   missing artifact is a cross-service cut-plan that distinguishes local iOS,
   server-mediated Google/Gaode/Search, reserved crawler, and reserved MCP lanes
   before any provider call is represented.
182. Done: added the pure **Provider Service Cut-Plan comment contract**.
   `ServerProviderServiceCutPlan` freezes service lane / service intent /
   cut-plan decision vocabulary for local Apple/iOS maps, cache fallback,
   server-mediated Google Maps, server-mediated Gaode, server-mediated Search
   API, reserved crawler, and reserved MCP. Focused tests prove local maps do
   not require remote entitlement; Google/Gaode/Search are server-reserved only
   when membership, region, cost/quota, source/citation, attribution/cache/
   display, raw-content, retention, and server-secret policy are represented;
   crawler and MCP remain gated; private/Health/location-sensitive remote
   requests stay blocked; and every decision is non-callable/non-executable.
183. Done: added the pure **Provider Service Cut-Plan status source**.
   `ServerProviderServiceCutPlanStatusSourceProducer` packages A182 decisions
   into rendered-id scoped `ProviderStatusPresentation` copy with stable
   local/server/reserved/blocked badges, card hints, first-wins duplicate
   behavior, hidden/missing nil lookup, and value-only status text. Focused
   tests prove local, Google/Gaode, Search API, crawler, MCP, privacy-blocked,
   and unsupported decisions remain non-callable/non-executable and do not leak
   lower-priority or runtime/provider fragments.
184. Next: add a test-only **Provider Service Cut-Plan Status App-Root Handoff**
   proof. A184 should compose A183 status sources through
   `AppBootstrap(providerStatusSources:)`, then prove `ChatStore` reads exactly
   the same rendered-id scoped copy for local-ready, server-reserved, blocked,
   and unsupported decisions. It must preserve first-source-wins ordering,
   hidden/missing nil behavior, and value-only copy without adding production
   defaults, UI, runtime adapters, networking, crawler/MCP runtime, maps SDK
   runtime, Search API calls, provider calls, execution claims, or completion
   claims.
185. Later: integrate real providers one at a time only after the selected
   interface, invocation preflight, cross-stage policy compatibility contract,
   status-source handoff, and provider-specific server-side quota, privacy,
   source, attribution, entitlement, audit, evaluation, and UI-safe status gates
   are explicit.
