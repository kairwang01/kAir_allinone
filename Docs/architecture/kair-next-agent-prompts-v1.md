# kAir Next Agent Prompts v1

Status: prompt framework for coding agents.
Last updated: 2026-06-01.

Use these prompts one round at a time. Each round must stop at the
merge gate. The reviewing agent verifies repo state, patches drift, and
then issues the next round.

## Global Rules for Every Coding Agent

Paste this block at the top of every coding-agent prompt:

```text
You are implementing kAir in /Users/kair/Projects/kAir.

Read first:
- Docs/architecture/kair-superapp-architecture-v1.md
- Docs/architecture/kair-file-architecture-v1.md
- Docs/architecture/kair-ai-model-memory-v1.md
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md
- Docs/research/2026-agent-market-ui-provider-research.md
- Contracts/capability-registry-and-adapter-contract-v1.md
- kAir/Core/Privacy/PrivacyGuard.swift

Rules:
- Do not stage, commit, or merge.
- Keep the change to the requested step only.
- Preserve existing user changes.
- Prefer existing repo patterns over new frameworks.
- No API keys, no private APIs, no hidden third-party app control.
- Health data is local-only in v1.
- Paid/remote model paths must be entitlement-gated and server-side.
- Provider routing must be membership/cost/privacy aware.
- MCP and crawler paths are disabled by default until explicit contracts
  and tests are added.
- If this round is comment-only, do not add runtime behavior.
- Run git diff --check.
- Run xcodebuild build/test only when Swift behavior or compile surface changes.
- End with exact files changed, tests run, and next recommended step.
```

## Current Verified Interface Baseline

As of 2026-05-31, the implementation chain has moved beyond A5c. Treat
the following as the current contract baseline before issuing another
coding prompt:

- A2: `IntentDraft`, `ActionPlan`, `CapabilityRouter`, and
  `PlanValidator` exist as pure Swift contracts.
- A3: model catalog, entitlement, runtime-family, and download-state
  contracts exist; real downloads remain deferred.
- A4: memory domain/record/write-policy contracts exist; durable
  storage/vector search remain deferred.
- A5b: `ProviderRoutingPolicy` and `MapProviderDescriptor` exist;
  provider routing is cost/membership/privacy aware.
- A5c: `SearchProviderPolicy` and `MCPGatewayPolicy` exist; search,
  crawler, and MCP are reservation contracts only.
- A5d: `ResultProjector` preserves provider metadata through normalized
  projection.
- A5e: `ProjectedRecommendationProvider` adapts projected results into
  the frozen `MatchingObject` rail without losing out-of-band metadata.
- A5f/A5g: `ProviderStatusPresentation` and
  `ChatStore.providerStatusPresentation(for:)` expose provider status as
  a non-invasive side channel.
- A5h/A85: market/research audit is current in
  `kair-agent-market-fit-audit-v1.md` and
  `2026-agent-market-ui-provider-research.md`; MCP prompt templates remain
  reserved by descriptor/allowlist policy only, with no runtime execution.
- A6: first App Intents pass exists behind `SurfaceRouter`, with
  `OpenKAirSurfaceIntent`, `ContinueChatIntent`,
  `KAirIntentEntity`, and `KAirAppShortcutsProvider`. The router opens
  only built kAir-owned sections, falls back to Chat for unknown/unbuilt
  identifiers, and marks Health as local-only sensitive.
- A7: `ModelLibraryView` is backed by `ModelLibraryStore.Row`
  presentation state derived from `ModelCatalog`, entitlement, and
  backend snapshots. The UI no longer owns hardcoded model cards, shows
  paid/installed/active/failed/unavailable/download-placeholder states,
  and keeps actions disabled while model backends are not wired.
- A8: Search exists as a read-only, contract-first future vertical:
  `SearchIntent`, `SearchCapabilityAdapter`, `SearchHomeView`, and
  `Contracts/search-capability-contract-v1.md`. It consumes
  `SearchProviderPolicy`, preserves source/cost/freshness/confidence
  metadata, blocks private remote search, keeps crawler mode policy-only,
  and does not implement booking, ordering, payment, or raw in-app
  crawling.
- A9: Search is wired as a kAir-owned read-only surface route:
  `AppSection.search`, `RootShellView` presentation, `SurfaceRouter`
  resolution/apply, App Intent entity suggestions, and resolved search
  recommendation handoff all point to Search without adding provider SDKs,
  web fetch, crawler runtime, API keys, booking, order, payment, or
  merchant-write behavior.
- A10: research-backed architecture audit is refreshed from current
  agent papers, MCP security work, Apple docs, provider docs, and public
  market references. It confirms the next implementation should be a
  pure server/provider transport envelope before any real Google/Gaode,
  search API, crawler, MCP, or remote-model runtime.
- A11: `ServerTransport` now has a pure `ServerProviderEnvelope`,
  validator, audit record, and `MockServerTransport`. Tests lock local
  allowed, Google/Gaode/search entitlement gates, Health/private remote
  blocks, crawler source/robots blocks, MCP disabled-by-default, and no
  credential fields in the encoded envelope.
- A12: `ServerProviderEnvelopeFactory` now converts resolved
  provider/search/MCP policy decisions plus `ServerProviderQuotaSnapshot`
  into executable envelopes only when quota, entitlement, source,
  confirmation, privacy, and A11 validation still pass.
- A13: `ServerProviderDryRunEvaluator` now compares candidate factory
  results into an audit-only provider plan. It preserves selected/blocked
  trace metadata, rejects stale cache for live-required work, prefers
  included quota over metered premium at equal freshness, and still does
  not execute any transport.
- A14: `ServerProviderDryRunPresentationProjector` now turns dry-run
  reports into UI-safe advisory copy and badge metadata. It preserves
  cost, freshness, source, privacy, validator denial, factory rejection,
  and fallback reason without saying a provider was contacted or an action
  was finished.
- A15: `ProviderStatusBadgeResolver` now bridges
  `ServerProviderDryRunPresentation` into the existing
  `ProviderStatusPresentation` side channel. It keeps dry-run local
  fallback, included quota, metered premium, stale cache rejection,
  all-blocked, and Health/private privacy-block states visible without
  changing frozen rail or trust-pill vocabularies.
- A16: `ServerProviderExecutionGate` now converts
  `ServerProviderEnvelopeFactoryResult` into explicit local-only,
  server-ready, confirmation-required, or blocked decisions. Local
  Apple/cache routes never expose send-ready envelopes, and remote routes
  only become server-ready after factory and validator gates pass.
- A17: `ServerProviderRuntimeRegistry` now provides metadata-only runtime
  descriptors for Google Maps, Gaode, Search API, Crawler, and MCP, and
  resolves descriptors only from A16 `.serverReady` decisions. Local-only,
  blocked, and confirmation-required decisions return no runtime descriptor.
- A18: `ServerProviderRuntimeInvocationPlanner` now combines A16 readiness
  with A17 descriptor lookup into a value-only invocation plan. It produces
  `.planned` only for server-ready decisions with a matching descriptor and
  preserves local-only, blocked, confirmation-required, and descriptor-missing
  reasons without carrying provider runtime objects or sensitive content.
- A19: `ServerProviderRuntimeDispatcher` now consumes A18 plans and produces
  a value-only dispatch boundary. It prepares only well-formed `.planned`
  metadata and keeps local-only, blocked, confirmation-required,
  descriptor-unavailable, and malformed plans non-executing.
- A20: `FixtureServerProviderRuntimeAdapter` now defines the pure adapter
  protocol/result contract. Prepared A19 boundaries can produce fixture-only
  adapter results, while local-only, blocked, confirmation-required,
  descriptor-unavailable, plan-rejected, malformed, or provider-mismatched
  boundaries remain non-executing.
- A21: `ServerProviderRuntimeAdapterRegistry` now selects fixture adapters by
  provider family for prepared boundaries and preserves non-executing states
  for every missing, local-only, blocked, confirmation, malformed, or
  unregistered path.
- A22: `ServerProviderRuntimeReceiptProjector` now projects adapter results into
  UI/audit-safe receipts without exposing prompts, raw source content, Health
  data, endpoints, credentials, merchant-write instructions, or transport
  payloads.
- A23: `ProviderStatusBadgeResolver` now bridges runtime receipts into existing
  provider-status presentations without changing frozen rail, object-kind, or
  trust-pill contracts.
- A24: `RuntimeReceiptProviderStatusStore` now stores runtime receipts by
  recommendation id and exposes receipt-derived status through
  `ProviderStatusProviding` without mutating `MatchingObject` or claiming
  provider execution.
- A25: `ProviderStatusSourceMultiplexer` now composes ordered
  `ProviderStatusProviding` sources so receipt-derived status can override
  projected recommendation status without UI, ChatStore, or provider-runtime
  coupling.
- A26: `ChatStore` now accepts an explicit provider-status source, preserves
  projected-provider fallback when none is supplied, and filters status lookup
  to ids currently present in `recommendedMatches`.
- A27: `AppBootstrap` now carries an optional explicit
  `ProviderStatusProviding` source and `ChatHomeView` passes it into
  `ChatStore` at the composition seam, while default/preview bootstrap remains
  nil and provider execution remains absent.
- A28: Chat's compact Recommended Next cells now receive optional
  `ProviderStatusPresentation` values through a pure
  `ProviderStatusCompactCellDisplay` binding and render provider-status badges
  plus status copy without mutating recommendation schemas or claiming provider
  execution.
- A29: `AppBootstrap` now carries a default-preserving
  `RecommendationProvider` and `ChatHomeView` passes it into `ChatStore`, so
  projected recommendation ids can line up with provider-status lookup while
  default/preview bootstraps keep the existing stub triple slate.
- A30: `AppBootstrap` now accepts ordered provider-status sources and composes
  them with `ProviderStatusSourceMultiplexer` at the app root while preserving
  nil default/preview behavior and direct source identity.
- A31: `ProviderAccessProfile` now centralizes provider request defaults for
  membership tier, region, preferred provider, metered entitlements,
  experimental provider enablement, unavailable providers, and cache fallback
  before `ProviderRoutingPolicy` evaluates a `ProviderRequest`.
- A32: `ProviderAccessProfile` now builds `SearchProviderRequest` and
  `MCPGatewayRequest` values from the same access defaults while keeping search
  robots/source inputs and MCP confirmation artifacts explicit at each call
  site.
- A33: `AppBootstrap` now carries a default-preserving
  `providerAccessProfile`, and `SearchIntent` can lower through that profile
  while source mode, privacy, freshness, robots, result drafts, cached results,
  and timestamps stay explicit.
- A34: `SearchCapabilityAdapter.Configuration` now carries
  `ProviderAccessProfile`, and adapter decisions call
  `SearchIntent.providerRequest(providerAccessProfile:)` while keeping privacy,
  source mode, freshness, robots, fixtures, cache, registry, and timestamp
  explicit.
- A35: `DefaultCapabilityRegistry` now exposes
  `makeReservedSearchConfiguration(...)` for building profile-aware Search
  adapter configuration without registering `.webSearch` in the default shipped
  registry.
- A36: `DefaultCapabilityRegistry.makeWithShippedStubs(reservedSearchAdapter:)`
  can compose a caller-built Search adapter into the shipped registry only when
  the caller opts in; the zero-argument default registry remains local-only.
- A37: `AppBootstrap` accepts explicit reserved Search adapter/configuration
  opt-in while default bootstrap, preview bootstrap, and direct custom-registry
  injection keep `.webSearch` absent unless the caller supplied it.
- A38: `ChatStore` has test coverage proving bootstrap-composed Search
  availability reaches `capabilityAvailability` through the same construction
  path as `ChatHomeView.init(bootstrap:)`, without mutating transcript or slate.
- A39: `ChatStore.searchAvailabilityState` exposes a pure three-state Search
  availability value derived only from `capabilityAvailability[.webSearch]`, with
  factual non-executing status copy.
- A40: `ChatStore.searchAvailabilityDisplay` maps the Search state to stable
  icon, tone, title, status, and accessibility copy for future UI binding without
  rendering UI or executing Search.
- A41: `ChatHomeView` consumes `ChatStore.searchAvailabilityDisplay` through a
  non-interactive `SearchAvailabilityIndicator`; the default not-in-build state
  renders nothing, while explicit Search registration can show boundary-safe
  status copy without routing or execution.
- A42: `ServerProviderRuntimePipeline` composes readiness, descriptor lookup,
  invocation planning, dispatch boundary creation, fixture-adapter registry
  resolution, and receipt projection into one value-only receipt path without
  calling transport.
- A43: Pipeline-generated receipts now feed `RuntimeReceiptProviderStatusStore`,
  `ProviderStatusSourceMultiplexer`, and `ProviderStatusCompactCellDisplay` by
  recommendation id without layout changes, provider execution, transcript
  writes, navigation, or telemetry.
- A44: App-root callers can install precomputed pipeline receipt status stores
  through `AppBootstrap(providerStatusSources:)`; the ChatStore/ChatHome
  composition path consumes pipeline-derived status only for rendered
  recommendation ids without executing the pipeline in AppBootstrap, views, or
  ChatStore.
- A45: `ServerProviderQuotaSnapshot` can now be built from
  `ProviderAccessProfile` plus explicit quota inputs. Profile membership does
  not silently grant remote/provider access; metered eligibility, included
  quota, unavailable providers, and crawler/MCP experimental enablement remain
  explicit value gates.
- A46: `AppBootstrap` now carries a value-only `providerQuotaSnapshot`,
  defaulting from its resolved `providerAccessProfile` through the A45 bridge.
  Direct quota injection wins exactly, and the app root still does not execute
  Search, provider factories, runtime pipeline, MCP, crawler, or transport.
- A47: `SearchCapabilityAdapter.Configuration` now carries
  `providerQuotaSnapshot`, defaulting through the A45 bridge and preserving
  explicit custom snapshots. `DefaultCapabilityRegistry` can pass an explicit
  snapshot into reserved Search configuration, and `AppBootstrap` passes its
  already-composed snapshot only when Search configuration is explicitly opted
  in.
- A48: `SearchCapabilityAdapter` can now produce an advisory
  `ServerProviderDryRunReport` from a `SearchIntent` or precomputed
  `SearchProviderDecision`, using `configuration.providerQuotaSnapshot` as the
  only quota source and without calling `resolve`, transport, crawler/MCP,
  runtime pipeline, telemetry, navigation, transcript, or UI code.
- A49: `SearchCapabilityAdapter` can now project Search dry-run reports through
  `ServerProviderDryRunPresentationProjector` into advisory
  `ServerProviderDryRunPresentation` values, preserving selected and blocked
  provider/cost/freshness/source/rejection metadata without rendering UI or
  implying provider execution.
- A50: `SearchDryRunProviderStatusStore` can now expose precomputed Search
  dry-run presentations through `ProviderStatusProviding` by recommendation id.
  The source preserves selected/blocked provider status, deterministic lookup,
  first-entry duplicate behavior, and advisory-only copy without Chat/UI wiring
  or Search execution.
- A51: `AppBootstrap.providerStatusSources` can now carry a precomputed
  `SearchDryRunProviderStatusStore` through the existing app-root composition
  path. Tests prove selected/blocked Search dry-run status, source order, missing
  ids, and ChatStore rendered-id filtering without making AppBootstrap,
  ChatStore, ChatHomeView, or views generate dry-runs.
- A52: `SearchCapabilityAdapter` can now package Search dry-run intent, report,
  or presentation output into a `SearchDryRunProviderStatusStore` for an explicit
  caller-supplied recommendation id. Tests prove selected/blocked status,
  missing-id nil lookup, advisory-only copy, and no `MatchingObject` mutation or
  app/UI wiring.
- A53: `SearchCapabilityAdapter` can now package multiple explicit
  recommendation ids with precomputed Search dry-run presentations or reports
  into one deterministic `SearchDryRunProviderStatusStore`. Tests prove
  selected/blocked lookup, sorted ids, missing-id nil lookup, first-entry
  duplicate behavior, and advisory-only copy without app/UI wiring or Search
  execution.
- A54: `Contracts/search-capability-contract-v1.md` now defines the Search
  dry-run status source handoff contract. Adapter helpers are value-packaging
  seams, ids are caller-owned, only recommendation/search composition code or
  tests may precompute stores, and app/root/view layers consume only
  `ProviderStatusProviding` without generating dry-runs.
- A55: `SearchDryRunStatusSourceProducer` now encodes that handoff as a pure
  Search data-layer producer. Callers pass explicit recommendation ids plus
  precomputed dry-run reports or presentations and receive a
  `SearchDryRunProviderStatusStore`; tests prove selected/blocked packaging,
  no `MatchingObject` id source, first-entry duplicate behavior, missing-id nil
  lookup, and advisory-only copy without app/root/view/runtime wiring.
- A56: A producer-built `SearchDryRunProviderStatusStore` now has an app-root
  handoff proof. Tests build the source outside `AppBootstrap`, pass it through
  `providerStatusSources`, and prove ChatStore consumes selected/blocked status
  only for rendered recommendation ids without app/root/view dry-run generation.
- A57: `SearchRenderedDryRunStatusSource` now wraps a producer-built
  `SearchDryRunProviderStatusStore` with explicit rendered recommendation ids.
  Tests prove rendered selected/blocked ids return status, hidden wrapped-store
  ids return nil, duplicate rendered ids are deterministic, and no
  `MatchingObject` id inference or Search execution is required.
- A58: A guarded producer-built Search dry-run status source now has an
  app-root handoff proof. Tests build the producer source and rendered-id guard
  outside `AppBootstrap`, pass the guard through `providerStatusSources`, and
  prove selected/blocked status survives while hidden wrapped-store ids return
  nil before and after ChatStore composition.
- A59: `ServerProviderRuntimeAdapterSet` now reserves explicit runtime-adapter
  injection for future real providers without changing the default fixture-only
  registry. Tests prove injected Search resolution, missing-family rejection,
  first-adapter-wins duplicate behavior, and non-prepared boundaries staying
  non-executing.
- A60: `ServerProviderRuntimePipeline` can now consume a caller-supplied
  `ServerProviderRuntimeAdapterSet`. Tests prove injected prepared Search
  receipts, default fixture-only pipeline isolation, and unchanged local-only,
  blocked, confirmation-required, descriptor-unavailable, and plan-rejected
  receipt semantics.
- A61: Injected-pipeline receipts can now feed
  `RuntimeReceiptProviderStatusStore` and `ProviderStatusSourceMultiplexer` by
  explicit recommendation id. Tests prove missing-id nil lookup, source-order
  behavior with another status source, injected adapter marker propagation, and
  advisory non-executing copy.
- A62: `ServerProviderRuntimeStatusSourceProducer` now packages explicit
  recommendation ids with precomputed runtime receipts or receipts generated
  through `ServerProviderRuntimePipeline.run(..., adapterSet:)`, returning
  `RuntimeReceiptProviderStatusStore` without app/root/view generation.
- A63: Producer-built runtime status sources can now pass through
  `AppBootstrap(providerStatusSources:)` and be consumed by ChatStore only for
  rendered recommendation ids. Tests prove hidden producer-store ids stay nil in
  ChatStore, source order remains deterministic, and copy stays advisory.
- A64: `ServerProviderRenderedRuntimeStatusSource` now wraps producer-built
  runtime status behind explicit rendered recommendation ids before app-root
  injection. Tests prove rendered ids return wrapped runtime status, hidden ids
  return nil, duplicate rendered ids are deterministic, and copy stays advisory.
- A65: Guarded producer-built runtime status sources can now pass through
  `AppBootstrap(providerStatusSources:)` and be consumed by ChatStore for
  rendered ids only. Tests prove hidden wrapped-store ids stay nil before app
  root injection, at app-root lookup, and after ChatStore composition, while
  source order and advisory copy remain deterministic.
- A66: `ServerProviderRuntimeAdapterReadinessMatrix` now emits one value-only
  readiness report per `ProviderFamily`. Tests prove remote providers are not
  adapter-ready unless all family-specific gates are explicitly satisfied,
  Google/Gaode/Search/Crawler/MCP gate sets stay distinct, Apple/cache remain
  local/no-server-adapter paths, and encoded reports avoid sensitive runtime
  fields.
- A67: `ServerProviderRuntimeAdapterInstallationGate` now gates future injected
  server-side adapter families against same-family ready reports. Tests prove
  remote families are installable only with ready reports, while missing reports,
  non-ready reports, report-family mismatches, Apple local, and cache are
  rejected deterministically.
- A68: `ServerProviderRuntimeAdapterSetReadinessValidator` now validates
  already-created `ServerProviderRuntimeAdapterSet` values by registered
  provider family against installation decisions. Tests prove ready remote sets
  are accepted without calling `resolve(_:)`, while missing decisions, rejected
  decisions, local/cache families, mismatches, and duplicate adapters remain
  deterministic.
- A69: `ServerProviderRuntimeAdapterSetUseGate` now authorizes one future
  adapter-set use by requested provider family against an A68 validation result.
  Tests prove accepted validation authorizes registered remote families, while
  rejected validation, nil requested family, Apple/cache, unregistered families,
  and missing accepted-family entries are rejected deterministically.
- A70: `ServerProviderRuntimePipeline` now has explicit validation-taking
  injected-adapter overloads that run A69 use authorization before
  `ServerProviderRuntimeAdapterSet.resolve(_:)`. Tests prove authorized
  validation preserves existing injected fixture behavior, while rejected
  validation, missing requested family, unregistered family, local/cache, and
  not-accepted family paths project non-success receipts without injected
  adapter calls.
- A71: `ServerProviderRuntimeStatusSourceProducer` now has an explicit
  validation-taking injected-pipeline overload. Tests prove authorized
  validation packages injected adapter metadata by recommendation id, rejected
  validation packages non-success advisory status without resolving injected
  adapters, duplicate ids keep the first authorized/unauthorized receipt, and
  existing precomputed/unvalidated producer paths remain green.
- A72: authorized producer-built runtime status sources now pass through
  `AppBootstrap(providerStatusSources:)` and ChatStore composition behind
  `ServerProviderRenderedRuntimeStatusSource`. Tests prove accepted validation
  preserves injected metadata for rendered ids, rejected validation remains
  non-success advisory without resolving adapters, hidden producer ids stay nil
  before app-root injection, at app-root lookup, and after ChatStore lookup, and
  source order remains deterministic.
- A73: `ServerProviderRuntimeAdapterManifestCatalog` now exposes value-only
  manifests for the five remote provider families and no installable manifests
  for Apple local/cache. Tests prove manifest metadata mirrors the readiness
  matrix, Google/Gaode/Search/Crawler/MCP flags match policy, lookup is
  deterministic and duplicate-safe, and encoding/status/debug text do not leak
  sensitive runtime fields.
- A74: `ServerProviderRuntimeAdapterManifestInstallationPlanner` now requires an
  A73 manifest before consuming readiness reports. Tests prove remote families
  become installable only with a manifest plus ready same-family report, local
  and missing-manifest requests are rejected before readiness, manifest/readiness
  mismatch and gate drift are distinct, A67 installation semantics remain
  preserved after manifest validation, and copy/encoding remain non-sensitive.
- A75: `ServerProviderRuntimeAdapterManifestSetValidator` now validates
  already-created `ServerProviderRuntimeAdapterSet` values only from A74
  manifest-backed installation decisions before delegating to A68. Tests prove
  ready remote sets require installable manifest-backed decisions for every
  registered family, missing/local/non-installable/mismatched/missing-underlying
  decisions reject distinctly, A68 duplicate first-family output is preserved,
  rejected paths never call `resolve(_:)`, and copy/encoding remain
  non-sensitive.
- A76: `ServerProviderRuntimeAdapterManifestSetUseGate` now authorizes future
  adapter-set use only from accepted A75 manifest-backed validation with embedded
  A68 readiness validation before delegating to A69. Tests prove registered
  remote families authorize only when accepted by A75, nil/local/rejected
  validation/not-accepted/missing-readiness/A69-rejected paths remain distinct,
  accepted paths preserve A69 authorization output, and copy/encoding remain
  non-sensitive.
- A77: `ServerProviderRuntimePipeline` now exposes explicit manifest-backed
  injected-pipeline overloads that accept A76 authorization before any
  `ServerProviderRuntimeAdapterSet.resolve(_:)` path. Tests prove same-family
  accepted A76 authorization allows injected fixture projection, rejected/missing
  family/local/mismatch/missing-A69/A69-rejected paths return non-success
  receipts without resolving injected adapters, and existing default plus A70
  validation overloads remain green.
- A78: `ServerProviderRuntimeStatusSourceProducer` now exposes a
  manifest-backed injected-pipeline overload. Tests prove accepted A76
  authorizations package A77 injected-pipeline metadata by explicit recommendation
  id, rejected A76 authorization packages non-success advisory status without
  resolving injected adapters, duplicate ids keep the first receipt, missing ids
  return nil, and existing precomputed/unvalidated/A70 validation-taking producer
  paths remain green.
- A79: manifest-backed producer-built runtime status sources now pass through
  `AppBootstrap(providerStatusSources:)` and ChatStore composition behind
  `ServerProviderRenderedRuntimeStatusSource`. Tests prove accepted A76 status
  preserves injected metadata for rendered ids, rejected A76 status stays
  non-success advisory without resolving adapters, hidden producer ids stay nil
  before app-root injection, at app-root lookup, and after ChatStore lookup, and
  source order remains deterministic.
- A80: `ServerProviderRuntimeConnector` now reserves a value-only connector
  boundary for future remote provider adapters. Tests prove connector
  requests/results are Codable/Hashable/Sendable metadata only, remote
  eligibility is limited to Google Maps, Gaode, Search API, crawler, and MCP,
  Apple local/cache remain no-connector paths, mismatched manifest/authorization
  inputs fail request creation, connector-family mismatches reject without
  provider metadata, and status/debug copy remains advisory.
- A81: `ServerProviderRuntimeConnectorPlanner` now derives value-only connector
  requests from prepared dispatch boundaries, A73 manifests, and A76
  authorization before any connector is run. Tests prove accepted planning copies
  manifest id, authorization id, boundary id, trace id, capability, cost class,
  and freshness; rejected planning keeps distinct non-prepared, missing-family,
  local/cache, manifest mismatch, A76 mismatch/rejected, and missing-metadata
  reasons; output encoding and copy stay advisory.
- A82: `ServerProviderRuntimeConnectorInvoker` now consumes accepted A81
  planning through an injected connector boundary and projects value-only
  invocation receipts. Tests prove accepted planning calls the connector once and
  preserves connector-result metadata, rejected planning does not call the
  connector, connector-family mismatch stays rejected without provider metadata,
  and encoded receipt copy stays advisory.
- A83: `ServerProviderRuntimeConnectorStatusSourceProducer` now packages A82
  connector invocation receipts by explicit recommendation id into rendered-id
  scoped advisory provider-status presentations. Tests prove accepted receipts
  expose provider/cost/freshness status, rejected planning and connector-family
  mismatch stay non-success without provider metadata leakage, duplicate ids keep
  the first receipt, missing ids return nil, and copy remains advisory.
- A84: A83 connector receipt status sources now pass through
  `AppBootstrap(providerStatusSources:)` and ChatStore composition while staying
  rendered-id scoped. Tests prove accepted/rejected connector receipt status is
  visible only for rendered recommendation ids, hidden ids stay nil before
  app-root injection, at app-root lookup, and after ChatStore lookup, source order
  remains deterministic, and copy stays advisory.
- A85: the research, market, prompt/interface, and provider cut plan was
  refreshed from current 2026 papers/specs/vendor docs/competitor docs. The
  selected first provider-specific cut is Search API, contract-only and
  non-networked first. Google/Gaode runtime, crawler runtime, MCP runtime, and
  remote model gateway remain deferred until quota, privacy, source,
  attribution, descriptor-security, and UI-safe status gates are explicit.
- A86: `ServerProviderSearchAPIAdapterContract` now defines value-only Search
  API query, quota/access/source snapshots, request decision, citation, result,
  and result receipt contracts. Tests prove accepted web-search and
  local-service-search metadata, rejected non-Search and unsafe provider paths,
  privacy/quota/source/citation/connector/freshness failures, advisory copy, and
  no network/provider execution fields.
- A87: `SearchAPIAdapterProviderStatusStore` now packages A86 request decisions
  and result receipts behind explicit recommendation ids through
  `ProviderStatusProviding`. Tests prove prepared request and normalized result
  status, rejected non-success status without provider badges, duplicate-id
  first-wins behavior, missing-id nil lookup, Codable/status copy safety, and no
  provider execution claims.
- A88: `AppBootstrapTests` now proves A87 Search API adapter status sources pass
  through app-root provider-status composition and ChatStore lookup for rendered
  recommendation ids while hidden ids stay nil, rejected values remain
  non-success/advisory, and source order stays first-wins.
- A89: `ServerProviderSearchAPIAdapterStatusSourceProducer` now packages typed
  A86 request-decision/result-receipt inputs into an A87 status store wrapped by
  explicit rendered recommendation ids before app-root injection. Tests prove
  A87-equivalent prepared/normalized status, hidden supplied ids nil, rejected
  non-success/advisory copy, and duplicate first-wins behavior.
- A90: `AppBootstrapTests` now proves A89 producer-built guarded Search API
  adapter status sources pass through app-root provider-status composition and
  ChatStore lookup for rendered ids, while hidden supplied ids stay nil, rejected
  values remain non-success/advisory, and source order stays first-wins.

Do not ask the next coding agent to re-create these files. Ask it to
extend from this baseline.

## Round A1 - Architecture Comments Only

```text
Task: Fill comment-only architecture scaffolds for kAir's AI, Models,
Memory, and SystemBridge layers. Do not implement business behavior.

Files to create or update:
- kAir/Core/AI/ConversationEngine.swift
- kAir/Core/AI/AgentRegistry.swift
- kAir/Core/AI/ToolRegistry.swift
- kAir/Core/Models/ModelProvider.swift
- kAir/Core/Models/LocalModelDescriptor.swift
- kAir/Core/Memory/MemoryStore.swift
- kAir/Core/Networking/ServerTransport.swift

Acceptance:
- Files compile unchanged because comments only or pure type stubs only.
- Comments name responsibilities, forbidden dependencies, privacy gates,
  and test expectations.
- No new dependency is added.
- No placeholder says "implement later" without an owner or gate.
```

## Round A2 - Pure Value Contracts

```text
Task: Add pure Swift value contracts for the AI orchestration pipeline.

Allowed files:
- kAir/Core/AI/IntentDraft.swift
- kAir/Core/AI/ActionPlan.swift
- kAir/Core/AI/CapabilityRouter.swift
- kAir/Core/AI/PlanValidator.swift
- kAirTests/AI/IntentDraftContractTests.swift
- kAirTests/AI/PlanValidatorTests.swift

Constraints:
- Foundation only; no SwiftUI.
- Codable, Hashable, Sendable where possible.
- No model runtime calls.
- No network calls.
- No HealthKit import.
- Low-confidence and risky-action states must be represented.

Acceptance:
- Build passes.
- Tests cover capability route, missing slots, confirmation requirement,
  privacy-blocked health-to-remote route, and unknown intent fallback.
```

## Round A3 - Model Catalog and Download State

```text
Task: Add model catalog and download state-machine types without real
network download.

Allowed files:
- kAir/Core/Models/ModelRuntimeFamily.swift
- kAir/Core/Models/ModelCatalog.swift
- kAir/Core/Models/ModelDownloadState.swift
- kAir/Core/Models/ModelEntitlementPolicy.swift
- kAir/Features/Models/Data/ModelLibraryStore.swift
- kAirTests/Models/ModelCatalogTests.swift
- kAirTests/Models/ModelDownloadStateTests.swift

Constraints:
- No real StoreKit purchase call yet.
- No real URLSession download yet.
- Use fixtures only.
- Keep RemoteModelGateway as comment-only or protocol-only.

Acceptance:
- Model states include free, installed, paid locked, downloading,
  verifying, compiling, active, failed, unavailable.
- Store view can later bind to this state without hardcoded cards.
- Tests lock state transitions and paid gating.
```

## Round A4 - Memory Facade and Policy

```text
Task: Add MemoryStore facade and in-memory implementation with strict
domain policy.

Allowed files:
- kAir/Core/Memory/MemoryDomain.swift
- kAir/Core/Memory/MemoryRecord.swift
- kAir/Core/Memory/MemoryWritePolicy.swift
- kAir/Core/Memory/MemoryStore.swift
- kAirTests/Memory/MemoryWritePolicyTests.swift
- kAirTests/Memory/HealthMemoryIsolationTests.swift

Constraints:
- In-memory only for this round.
- No SQLite/GRDB yet.
- No embeddings yet.
- Health memory cannot be returned to general chat/social retrieval.

Acceptance:
- Tests cover write, retrieve, delete, pause, health isolation, and
  blocked sensitive cross-domain memory.
```

## Round A5 - Conversation Engine Skeleton

```text
Task: Wire ConversationEngine as a deterministic orchestration skeleton.

Allowed files:
- kAir/Core/AI/ConversationEngine.swift
- kAir/Core/AI/ResultProjector.swift
- kAir/Features/Chat/Data/ChatStore.swift
- kAirTests/AI/ConversationEngineTests.swift

Constraints:
- Do not replace Chat UI.
- Do not call real LLM.
- Use deterministic parser fixture.
- Preserve existing recommendation and continuation tests.

Acceptance:
- Chat input can produce an IntentDraft and recommended surface route in
  tests.
- No execution of write/pay/share actions without confirmation artifact.
```

## Round A5b - Provider Routing Contracts

```text
Task: Add pure value contracts for provider routing, membership/cost
policy, and provider trace. No real provider calls.

Allowed files:
- kAir/Core/Providers/ProviderRoutingPolicy.swift
- kAir/Core/Providers/MapProviderDescriptor.swift
- kAirTests/Providers/ProviderRoutingPolicyTests.swift

Constraints:
- Foundation only.
- No Google/Gaode SDK.
- No URLSession.
- No API keys.
- No MCP runtime.
- No crawler.
- Health/private contexts cannot route to remote providers.
- Metered providers require membership/entitlement.

Acceptance:
- Tests cover local default, Gaode member route, Google member route,
  cost-blocked premium route, privacy-blocked route, cache fallback, and
  provider trace contents.
```

## Round A5c - Search and MCP Reservation

```text
Task: Add pure value contracts for search/crawler/MCP reservation.
No real network calls.

Allowed files:
- kAir/Core/Search/SearchProvider.swift
- kAir/Core/SystemBridge/MCPGateway.swift
- kAirTests/Search/SearchProviderPolicyTests.swift
- kAirTests/SystemBridge/MCPGatewayPolicyTests.swift

Constraints:
- Foundation only.
- No real search API.
- No crawler implementation.
- No MCP server connection.
- No API keys.
- Search is read-only.
- Crawler must model robots/source/cost/privacy blocks.
- MCP must be disabled by default and allowlisted.

Acceptance:
- Search result envelope includes source URL, fetchedAt, freshness,
  provider id, cost class, confidence, and limitations.
- Tests cover robots-blocked, source-denied, cost-blocked,
  privacy-blocked, stale-cache, and cited success.
- MCP tests cover unknown server blocked, destructive tool requires
  confirmation, Health resource blocked, and read-only allowlisted tool.
```

## Round A6 - App Intents First Pass

```text
Status: completed and verified on 2026-05-30. Keep this prompt only as
historical context; do not re-run it unless the App Intents bridge is
reverted.

Task: Add the first App Intents integration for kAir-owned actions only.

Allowed files:
- kAir/Core/SystemBridge/AppIntents/OpenKAirSurfaceIntent.swift
- kAir/Core/SystemBridge/AppIntents/ContinueChatIntent.swift
- kAir/Core/SystemBridge/AppIntents/KAirIntentEntity.swift
- kAir/App/Navigation/SurfaceRouter.swift
- kAirTests/SystemBridge/AppIntentRouteTests.swift

Constraints:
- Expose only 1-2 high-value actions.
- Intent types call services or router, not SwiftUI views.
- No external app automation.
- No private APIs.

Acceptance:
- Build passes.
- Tests prove intent route maps to known AppSection or safe fallback.
- Health/private routes cannot be exposed as remote or third-party
  actions.
- App Intent code depends on a route/service boundary, not SwiftUI view
  construction.
- App shortcuts expose only the same narrow, kAir-owned surface actions.
```

## Round A7 - Model Library UI Truthfulness

```text
Status: completed and verified on 2026-05-30. Keep this prompt only as
historical context; do not re-run it unless the Model Library regresses
to hardcoded cards.

Task: Replace hardcoded ModelLibraryView cards with state-driven model
catalog rows.

Allowed files:
- kAir/Features/Models/Presentation/ModelLibraryView.swift
- kAir/Features/Models/Data/ModelLibraryStore.swift
- kAirTests/Models/ModelLibraryStoreTests.swift

Constraints:
- UI can show actions as disabled if backend is not wired.
- No fake download success.
- No fake premium entitlement.
- Use existing DesignSystem components.

Acceptance:
- UI states show installed, active, paid locked, unavailable, failed,
  and placeholder download.
- If no model backend exists, copy truthfully says setup is not wired.
```

## Round A8 - First New Vertical Adapter

```text
Status: completed and verified on 2026-05-30. Keep this prompt only as
historical context; do not re-run it unless the Search vertical
contracts are reverted.

Task: Add one future vertical adapter as a real contract-first example.
Use Search as the first candidate because the current product direction
needs read-only public life-service lookup before any booking/payment
surface. Do not start Food ordering/payment.

Allowed files:
- kAir/Features/Search/Domain/SearchIntent.swift
- kAir/Features/Search/Data/SearchCapabilityAdapter.swift
- kAir/Features/Search/Presentation/SearchHomeView.swift
- Contracts/search-capability-contract-v1.md
- kAirTests/Search/SearchCapabilityAdapterTests.swift

Constraints:
- Start read-only.
- No paid action, no booking, no order placement.
- Results must carry source and confidence.
- If web search is remote, route through ServerTransport and privacy gate.

Acceptance:
- Adapter availability and normalized result tests pass.
- UI shell uses ExecutionSurfaceShell.
```

## Round A9 - Search Surface Route Integration

```text
Status: completed and verified on 2026-05-30. Keep this prompt only as
historical context; do not re-run it unless the Search route integration
is reverted.

Task: Wire the read-only Search surface into kAir's app-owned route
boundary without changing its provider/runtime safety model.

Allowed files:
- kAir/App/Navigation/AppSection.swift
- kAir/App/Navigation/RootShellView.swift
- kAir/App/Navigation/SurfaceRouter.swift
- kAir/Core/SystemBridge/AppIntents/KAirIntentEntity.swift
- kAir/Core/Matching/Models/MatchingObject.swift
- kAir/Core/AI/ProjectedRecommendation.swift
- kAirTests/SystemBridge/AppIntentRouteTests.swift
- kAirTests/Recommendation/ProjectedRecommendationProviderTests.swift
- kAirTests/Recommendation/RecommendationAcceptTests.swift

Constraints:
- Add Search as a kAir-owned read-only surface only.
- Do not add provider SDKs, web fetch, crawler runtime, API keys,
  booking, order, payment, or merchant-write behavior.
- App Intents may open Search, but must not imply third-party app
  control or remote Health/private search.
- Search recommendations may become routable to Search only when the
  projection is resolved and read-only.

Acceptance:
- RootShell can present `SearchHomeView`.
- `SurfaceRouter` maps `search` to Search and still falls back unknown
  or unbuilt identifiers to Chat.
- App Intent entity suggestions include Search only if the surface is
  actually wired.
- Projected search recommendations can carry `.search` as their
  preferred section without changing map/health/store behavior.
- Full tests pass.
```

## Round A10 - Research-Backed Architecture Redesign Audit

```text
Status: completed and verified on 2026-05-30. Keep this prompt only as
historical context; do not re-run it unless the A10 docs are reverted.

Task: Refresh kAir's architecture decision docs from current external
research and public market references, then produce the next code
implementation frame. This is a documentation/comment-only audit round.

Allowed files:
- Docs/architecture/kair-agent-market-fit-audit-v1.md
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-superapp-architecture-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/research/2026-agent-market-ui-provider-research.md
- Contracts/search-capability-contract-v1.md

Research requirements:
- Use primary or authoritative sources where possible: Google Scholar,
  IEEE/ACM/arXiv papers, Apple developer docs, MCP specification,
  provider docs/pricing pages, and public product/technical pages for
  Marvis-style mobile agents, Tencent Yuanbao, Meituan/LongCat or
  life-service agents.
- Record source URL, publication/update date when available, and a short
  adoption judgment. Do not cite unsourced claims.
- Distinguish proven implementation patterns from experimental ideas.

Audit requirements:
- Re-check the full current repo state before editing docs.
- Produce an adopt/reserve/reject matrix for agent planning, memory,
  tool/MCP routing, mobile GUI control, provider routing, crawler/search,
  map providers, model cost routing, and life-service actions.
- Update the interface reservation matrix for local iOS maps first,
  optional Google/Gaode provider upgrades by membership/cost/region,
  server-side search API, server-side crawler, MCP tools/resources/prompts,
  and remote model/provider calls.
- Keep Health local-only and keep paid/remote/provider calls gated by
  entitlement, privacy class, quota/cost, and audit trace.
- Do not add runtime behavior, SDKs, API keys, network calls, crawler code,
  booking/order/payment flows, or merchant writes in this round.

Acceptance:
- Docs no longer contradict the current A6-A9 implementation baseline.
- Every market/research claim has a source or is clearly labeled as a
  product judgment.
- The next direct coding point is a narrow, testable implementation step
  derived from the audit, not a broad redesign request.
- `git diff --check` passes.
```

## Round A11 - Server Provider Envelope Contract

Status: implemented and verified. Do not ask the next coding agent to
re-create this round.

```text
Task: Add a pure server/provider transport envelope contract. Do not add
network runtime, URLSession, endpoints, SDKs, API keys, Google/Gaode
clients, crawler code, MCP client code, booking/order/payment, or
merchant writes.

Allowed files:
- kAir/Core/Networking/ServerTransport.swift
- kAirTests/Networking/ServerTransportEnvelopeTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md

Implementation shape:
- Define value-only request/response/audit types for remote provider
  transport.
- Require traceID, capability, provider family, privacy class,
  membership tier, cost class, freshness, source policy, and
  confirmation state.
- Provide a pure validator that blocks Health/private remote routing,
  blocks missing entitlement for metered providers, blocks crawler
  requests without robots/source pass, and blocks MCP unless explicitly
  enabled.
- Add a fixture/mock transport only; no real network calls.

Acceptance:
- Tests cover local allowed, Google/Gaode/search allowed only with
  entitlement, Health/private blocked, crawler robots/source blocked,
  MCP disabled by default, and no API key field in the envelope.
- Static scan confirms no URLSession, SDK imports, API keys, WebView,
  StoreKit purchase call, or MCP client runtime.
- `git diff --check` passes.
```

## Round A12 - Provider Envelope Adapter and Quota Snapshot

Status: implemented and verified. Do not ask the next coding agent to
re-create this round.

```text
Task: Add a pure adapter layer that turns existing provider/search/MCP
policy decisions plus a quota/entitlement snapshot into
ServerProviderEnvelope values. Do not execute the envelope and do not add
network runtime, URLSession, endpoints, SDKs, provider auth material,
Google/Gaode clients, crawler code, MCP client code, booking/order/payment,
or merchant writes.

Allowed files:
- kAir/Core/Networking/ServerProviderEnvelopeFactory.swift
- kAirTests/Networking/ServerProviderEnvelopeFactoryTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md

Implementation shape:
- Define value-only quota/entitlement snapshot types for provider-family
  allowance, remaining included quota, metered eligibility, and disabled
  provider families.
- Provide factory methods that can build `ServerProviderEnvelope` from
  `ProviderRequest + ProviderSelection`, `SearchProviderRequest +
  SearchProviderDecision`, and `MCPGatewayRequest + MCPGatewayDecision`.
- Preserve traceID, capability, provider family, privacy class,
  membership tier, cost class, freshness, source policy, and confirmation
  state exactly enough for `ServerProviderEnvelopeValidator` to re-check.
- Return a blocked/no-envelope decision when the upstream policy was
  unresolved, the quota snapshot disables the provider, or the source/
  confirmation metadata is insufficient.

Acceptance:
- Tests cover Google/Gaode/search decision -> envelope only when quota and
  entitlement snapshot allow it.
- Tests cover crawler decision -> envelope only when crawler is enabled and
  robots/source are passed.
- Tests cover blocked provider/search/MCP decisions producing no executable
  envelope.
- Tests prove Health/private remote still cannot be converted into an
  accepted envelope.
- Static scan confirms no URLSession, SDK imports, provider auth fields,
  WebView, StoreKit purchase call, crawler runtime, or MCP client runtime.
- `git diff --check` passes.
```

## Round A13 - Provider Dry-Run Evaluation Trace

Status: implemented and verified. Do not ask the next coding agent to
re-create this round.

```text
Task: Add a pure dry-run evaluator that compares candidate
ServerProviderEnvelopeFactoryResult values and produces an audit-only
provider execution plan. Do not execute envelopes and do not add network
runtime, URLSession, endpoints, SDKs, provider auth material,
Google/Gaode clients, crawler code, MCP client code, booking/order/payment,
or merchant writes.

Allowed files:
- kAir/Core/Networking/ServerProviderDryRunEvaluator.swift
- kAirTests/Networking/ServerProviderDryRunEvaluatorTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md

Implementation shape:
- Define value-only dry-run candidate, report, and selected/blocked trace
  types.
- Accept multiple `ServerProviderEnvelopeFactoryResult` candidates plus a
  user-visible capability label.
- Prefer accepted local/cache candidates when remote cost or privacy would
  block; prefer entitled included-quota providers before metered-premium
  providers when both satisfy freshness.
- Preserve traceID, provider family, capability, privacy class,
  membership tier, cost class, freshness, source policy, denial reason,
  and fallback reason in the report.
- Return an audit-only plan; do not call `MockServerTransport` or any real
  transport.

Acceptance:
- Tests cover local fallback winning when remote candidate is blocked.
- Tests cover included-quota provider winning over metered-premium when
  both are valid and freshness is equal.
- Tests cover liveRequired rejecting stale cache candidates.
- Tests cover all candidates blocked producing no selected envelope but
  preserving every rejection reason.
- Tests prove Health/private remote remains blocked in dry-run output.
- Static scan confirms no URLSession, SDK imports, provider auth fields,
  WebView, StoreKit purchase call, crawler runtime, MCP client runtime, or
  transport send call.
- `git diff --check` passes.
```

## Round A14 - Provider Dry-Run Presentation Projection

Status: implemented and verified. Do not ask the next coding agent to
re-create this round.

```text
Task: Add a pure projection layer that turns `ServerProviderDryRunReport`
into UI-safe provider status copy and badge metadata. Do not execute
envelopes and do not add SwiftUI, network runtime, URLSession, endpoints,
SDKs, provider auth material, Google/Gaode clients, crawler code, MCP
client code, booking/order/payment, merchant writes, or transport send
calls.

Allowed files:
- kAir/Core/Networking/ServerProviderDryRunPresentation.swift
- kAirTests/Networking/ServerProviderDryRunPresentationTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md

Implementation shape:
- Define value-only presentation rows for selected provider, blocked
  candidates, cost/freshness/source status, and fallback reason.
- Convert `ServerProviderDryRunReport` into deterministic user-safe text
  without prompt text, raw source content, health data, or provider auth
  material.
- Preserve provider family, cost class, freshness, privacy class, source
  policy, validator denial, factory rejection, and fallback reason.
- Mark every row as advisory/dry-run only; no wording may claim an action
  was completed or a provider was called.

Acceptance:
- Tests cover local fallback copy, included quota copy, metered premium
  warning copy, live-required stale-cache rejection copy, all-blocked copy,
  and Health/private remote privacy-block copy.
- Tests prove no row uses completed/action-done wording.
- Static scan confirms no SwiftUI, URLSession, SDK imports, provider auth
  fields, WebView, StoreKit purchase call, crawler runtime, MCP client
  runtime, or transport send call.
- `git diff --check` passes.
```

## Round A15 - Dry-Run Provider Status Bridge

Status: implemented and verified. Do not ask the next coding agent to
re-create this round.

```text
Task: Add a pure bridge from `ServerProviderDryRunPresentation` into the
existing `ProviderStatusPresentation` side-channel so future UI can show
dry-run provider/cost/freshness status without changing rail layout. Do
not add SwiftUI, network runtime, URLSession, endpoints, SDKs, provider
auth material, Google/Gaode clients, crawler code, MCP client code,
booking/order/payment, merchant writes, or transport send calls.

Allowed files:
- kAir/DesignSystem/Components/ProviderStatusBadgeModel.swift
- kAirTests/DesignSystem/ProviderStatusBadgeModelTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md

Implementation shape:
- Add a value-only adapter that maps `ServerProviderDryRunPresentation`
  rows and badges into `ProviderStatusPresentation`.
- Reuse existing `ProviderStatusBadgeKind`, `ProviderStatusBadgeModel`,
  and `ProviderStatusCardHint`; do not add new frozen recommendation or
  trust-pill cases unless a test proves an existing kind cannot represent
  the state.
- Preserve advisory/dry-run wording and blocked reasons in `statusLine`.
- Keep local fallback, included quota, metered premium, stale cache,
  all-blocked, and privacy-block states distinguishable.

Acceptance:
- Tests cover local fallback -> normal provider status, included quota ->
  normal status, metered premium -> warning/neutral cost badge, stale cache
  rejection -> warning status, all-blocked -> disabled status, and
  Health/private privacy block -> privacy blocked badge.
- Tests prove the bridge does not alter `ActionCardTrustPillKind`,
  `MatchingObjectKind`, or `RecommendationRail.maxSlateSize`.
- Tests prove status copy still avoids completed/action-done wording.
- Static scan confirms no SwiftUI, URLSession, SDK imports, provider auth
  fields, WebView, StoreKit purchase call, crawler runtime, MCP client
  runtime, or transport send call.
- `git diff --check` passes.
```

## Round A16 - Server Provider Execution Readiness Gate

Status: implemented and verified. Do not ask the next coding agent to
re-create this round.

```text
Task: Add a pure final execution-readiness gate for future server/provider
runtime work. It should convert existing `ServerProviderEnvelopeFactoryResult`
values into an explicit readiness decision before any transport can be
called. Do not add network runtime, URLSession, endpoints, provider SDKs,
provider auth material, Google/Gaode clients, crawler runtime, MCP client
runtime, booking/order/payment, merchant writes, or `ServerTransport.send`
calls.

Allowed files:
- kAir/Core/Networking/ServerProviderExecutionGate.swift
- kAirTests/Networking/ServerProviderExecutionGateTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md

Implementation shape:
- Define a value-only readiness decision with explicit states for
  local-only, server-ready, confirmation-required, and blocked.
- Consume `ServerProviderEnvelopeFactoryResult` and reuse its envelope,
  validation, denial reason, quota/factory rejection, source policy, cost
  class, freshness, and audit record. Do not re-run provider policy or
  invent new routing behavior.
- Local Apple/cache routes must never become server-send-ready.
- Remote Google/Gaode/search/crawler/MCP routes may be marked server-ready
  only when the factory result is executable and validation allowed.
- Confirmation, privacy, source, robots, entitlement, cost, and disabled
  provider failures must remain distinguishable.

Acceptance:
- Tests cover local-only Apple/cache, Google/Gaode/search server-ready only
  with entitlement/quota, Health/private remote privacy block, crawler
  source/robots block, MCP disabled or confirmation-required block, and
  all-blocked factory reasons.
- Tests prove no local-only route exposes a send-ready envelope.
- Tests prove no readiness copy/status uses completed/action-done wording.
- Static scan confirms no SwiftUI, URLSession, SDK imports, provider auth
  fields, WebView, StoreKit purchase call, crawler runtime, MCP client
  runtime, or transport send call.
- `git diff --check` passes.
```

## Round A17 - Server Provider Runtime Registry Contract

Status: implemented and verified. Do not ask the next coding agent to
re-create this round.

```text
Task: Add a protocol/value contract for future server-provider runtime
adapters and registry lookup. This is still not a real runtime: do not add
URLSession, endpoints, provider SDKs, provider auth material, Google/Gaode
clients, crawler runtime, MCP client runtime, booking/order/payment,
merchant writes, or `ServerTransport.send` calls.

Allowed files:
- kAir/Core/Networking/ServerProviderRuntimeRegistry.swift
- kAirTests/Networking/ServerProviderRuntimeRegistryTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md

Implementation shape:
- Define value-only runtime adapter descriptors for Google Maps, Gaode,
  Search API, Crawler, and MCP. Local Apple/cache routes stay outside the
  server runtime registry.
- Descriptor metadata should record provider family, supported
  capabilities, required membership tier, cost class, source/robots
  requirement, confirmation requirement, and whether experimental enablement
  is required.
- Add a pure registry lookup that consumes
  `ServerProviderExecutionReadinessDecision` and returns an adapter
  descriptor only when the decision is `.serverReady`.
- Local-only, blocked, and confirmation-required decisions must return no
  runtime descriptor while preserving the reason for UI/audit handoff.

Acceptance:
- Tests cover Google/Gaode/search descriptor lookup from server-ready
  decisions, crawler and MCP descriptor lookup only after A16 readiness,
  local Apple/cache returning no descriptor, Health/private blocked returning
  no descriptor, and confirmation-required returning no descriptor.
- Tests prove no descriptor stores endpoint URLs, API keys, bearer tokens,
  provider credentials, prompts, raw source content, Health data, booking,
  order, payment, or merchant-write fields.
- Static scan confirms no SwiftUI, URLSession, SDK imports, provider auth
  fields, WebView, StoreKit purchase call, crawler runtime, MCP client
  runtime, or transport send call.
- `git diff --check` passes.
```

## Round A18 - Server Provider Runtime Invocation Plan

Status: implemented and verified. Do not ask the next coding agent to
re-create this round.

```text
Task: Add a pure invocation-plan contract that combines
`ServerProviderExecutionReadinessDecision` and
`ServerProviderRuntimeLookupResult` into a future runtime invocation plan.
This is still not a runtime executor: do not add URLSession, endpoints,
provider SDKs, provider auth material, Google/Gaode clients, crawler
runtime, MCP client runtime, booking/order/payment, merchant writes, or
`ServerTransport.send` calls.

Allowed files:
- kAir/Core/Networking/ServerProviderRuntimeInvocationPlan.swift
- kAirTests/Networking/ServerProviderRuntimeInvocationPlanTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md

Implementation shape:
- Define a value-only invocation plan with explicit states for
  `planned`, `localOnly`, `confirmationRequired`, `blocked`, and
  `descriptorUnavailable`.
- Plans may include trace id, provider family, capability, cost class,
  freshness, source policy, confirmation state, descriptor id, and audit
  metadata. They must not include prompt text, raw source content, Health
  data, provider credentials, endpoint URLs, booking/order/payment, or
  merchant-write instructions.
- Produce `planned` only when A16 readiness is `.serverReady` and A17 lookup
  has a descriptor for the same provider family and capability.
- Preserve local-only, blocked, confirmation-required, and descriptor-missing
  reasons for UI/audit handoff without falling through to planned.

Acceptance:
- Tests cover planned Google/Gaode/Search, planned Crawler/MCP only after
  readiness plus descriptor lookup, local Apple/cache not planned,
  Health/private blocked not planned, confirmation-required not planned, and
  descriptor/provider mismatch not planned.
- Tests prove plan encoding contains no prompt/raw content/Health data,
  endpoint URL, API key, bearer token, provider credential, booking, order,
  payment, or merchant-write fields.
- Tests prove no plan/status uses completed/action-done wording.
- Static scan confirms no SwiftUI, URLSession, SDK imports, provider auth
  fields, WebView, StoreKit purchase call, crawler runtime, MCP client
  runtime, or transport send call.
- `git diff --check` passes.
```

## Round A19 - Server Provider Runtime Dispatch Boundary

Status: implemented and verified. Do not ask the next coding agent to
re-create this round.

```text
Task: Add a pure dispatch-boundary contract that consumes
`ServerProviderRuntimeInvocationPlan` and prepares future adapter dispatch
without executing it. This is still not a runtime executor: do not add
URLSession, endpoints, provider SDKs, provider auth material, Google/Gaode
clients, crawler runtime, MCP client runtime, booking/order/payment, merchant
writes, or `ServerTransport.send` calls.

Allowed files:
- kAir/Core/Networking/ServerProviderRuntimeDispatch.swift
- kAirTests/Networking/ServerProviderRuntimeDispatchTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md

Implementation shape:
- Define value-only dispatch boundary types with explicit states for
  `prepared`, `localOnly`, `confirmationRequired`, `blocked`,
  `descriptorUnavailable`, and `planRejected`.
- `prepared` may include plan id, trace id, provider family, capability,
  descriptor id, cost class, freshness, source policy, confirmation state,
  and audit metadata. It must not include prompt text, raw source content,
  Health data, provider credentials, endpoint URLs, booking/order/payment, or
  merchant-write instructions.
- Produce `prepared` only when A18 plan is `.planned` and the descriptor id,
  provider family, and capability are all present.
- Preserve all non-planned A18 states without falling through to a prepared
  dispatch state.

Acceptance:
- Tests cover prepared Google/Gaode/Search, prepared Crawler/MCP only after
  A18 planned state, local Apple/cache not prepared, Health/private blocked
  not prepared, confirmation-required not prepared, descriptor-unavailable not
  prepared, and malformed planned metadata rejected.
- Tests prove dispatch-boundary encoding contains no prompt/raw content/Health
  data, endpoint URL, API key, bearer token, provider credential, booking,
  order, payment, or merchant-write fields.
- Tests prove no dispatch/status uses completed/action-done wording.
- Static scan confirms no SwiftUI, URLSession, SDK imports, provider auth
  fields, WebView, StoreKit purchase call, crawler runtime, MCP client
  runtime, or transport send call.
- `git diff --check` passes.
```

## Round A20 - Server Provider Runtime Adapter Protocol Contract

Status: implemented and verified. Do not ask the next coding agent to
re-create this round.

```text
Task: Add a pure adapter protocol/result contract that consumes
`ServerProviderRuntimeDispatchBoundary` and returns a value-only runtime
adapter result. This is still not a real provider runtime: do not add
URLSession, endpoints, provider SDKs, provider auth material, Google/Gaode
clients, crawler runtime, MCP client runtime, booking/order/payment, merchant
writes, or `ServerTransport.send` calls.

Allowed files:
- kAir/Core/Networking/ServerProviderRuntimeAdapter.swift
- kAirTests/Networking/ServerProviderRuntimeAdapterTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md

Implementation shape:
- Define a protocol-only adapter surface that accepts prepared dispatch
  boundary values and returns a value-only `ServerProviderRuntimeAdapterResult`.
- Add a fixture/no-op adapter implementation for tests only in production code
  if needed, but it must not perform I/O or claim a real provider was contacted.
- Result states should distinguish `acceptedFixture`, `notPrepared`,
  `localOnly`, `confirmationRequired`, `blocked`, `descriptorUnavailable`, and
  `planRejected`.
- Results may include boundary id, plan id, trace id, provider family,
  capability, descriptor id, cost class, freshness, source policy,
  confirmation state, and audit metadata. They must not include prompt text,
  raw source content, Health data, provider credentials, endpoint URLs,
  booking/order/payment, or merchant-write instructions.

Acceptance:
- Tests cover fixture accepted Google/Gaode/Search/Crawler/MCP only from A19
  prepared boundaries, and rejection for local-only, Health/private blocked,
  confirmation-required, descriptor-unavailable, plan-rejected, and malformed
  boundary metadata.
- Tests prove adapter-result encoding contains no prompt/raw content/Health
  data, endpoint URL, API key, bearer token, provider credential, booking,
  order, payment, or merchant-write fields.
- Tests prove no adapter-result/status uses completed/action-done wording or
  implies a real provider call.
- Static scan confirms no SwiftUI, URLSession, SDK imports, provider auth
  fields, WebView, StoreKit purchase call, crawler runtime, MCP client
  runtime, or transport send call.
- `git diff --check` passes.
```

## Round A21 - Server Provider Runtime Adapter Registry Contract

Status: implemented and verified. Do not ask the next coding agent to
re-create this round.

```text
Task: Add a pure adapter registry/selection contract that consumes
`ServerProviderRuntimeDispatchBoundary`, selects a fixture adapter by provider
family, and returns `ServerProviderRuntimeAdapterResult`. This is still not a
real provider runtime: do not add URLSession, endpoints, provider SDKs,
provider auth material, Google/Gaode clients, crawler runtime, MCP client
runtime, booking/order/payment, merchant writes, or `ServerTransport.send`
calls.

Allowed files:
- kAir/Core/Networking/ServerProviderRuntimeAdapterRegistry.swift
- kAirTests/Networking/ServerProviderRuntimeAdapterRegistryTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md

Implementation shape:
- Define a value-only adapter registry with fixture adapters for Google Maps,
  Gaode, Search API, Crawler, and MCP.
- Registry selection must occur only for A19 `.prepared` boundaries with a
  provider family. Non-prepared states must return non-executing adapter
  results without selecting an adapter.
- Missing provider family, unknown provider family, and adapter/provider
  mismatch must remain non-executing and preserve audit/status reasons.
- Registry results may include boundary id, plan id, trace id, provider family,
  capability, descriptor id, cost class, freshness, source policy,
  confirmation state, and audit metadata. They must not include prompt text,
  raw source content, Health data, provider credentials, endpoint URLs,
  booking/order/payment, or merchant-write instructions.

Acceptance:
- Tests cover registry fixture acceptance for prepared Google/Gaode/Search,
  Crawler, and MCP; local Apple/cache not selected; Health/private blocked not
  selected; confirmation-required not selected; descriptor-unavailable and
  plan-rejected not selected; malformed prepared metadata rejected; and
  unregistered provider family rejected.
- Tests prove registry-result encoding contains no prompt/raw content/Health
  data, endpoint URL, API key, bearer token, provider credential, booking,
  order, payment, or merchant-write fields.
- Tests prove no registry-result/status uses completed/action-done wording or
  implies a real provider call.
- Static scan confirms no SwiftUI, URLSession, SDK imports, provider auth
  fields, WebView, StoreKit purchase call, crawler runtime, MCP client
  runtime, or transport send call.
- `git diff --check` passes.
```

## Round A22 - Server Provider Runtime Receipt Projection Contract

Status: implemented and verified. Do not ask the next coding agent to
re-create this round.

```text
Task: Add a pure receipt/projection contract that consumes
`ServerProviderRuntimeAdapterResult` and returns a UI/audit-safe runtime
receipt for future provider-result display. This is still not a real provider
runtime: do not add URLSession, endpoints, provider SDKs, provider auth
material, Google/Gaode clients, crawler runtime, MCP client runtime,
booking/order/payment, merchant writes, or `ServerTransport.send` calls.

Allowed files:
- kAir/Core/Networking/ServerProviderRuntimeReceipt.swift
- kAirTests/Networking/ServerProviderRuntimeReceiptTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Define value-only receipt/projection types that preserve the public status,
  provider family, capability, cost class, freshness, source policy,
  confirmation state, and audit handoff from A21 adapter results.
- Accepted A21 fixture results may project as fixture receipts only; non-
  accepted results must project as local-only, confirmation-required, blocked,
  descriptor-unavailable, plan-rejected, not-prepared, or unavailable receipts
  without implying provider execution.
- Receipts must be safe for UI and analytics: no prompt text, raw source
  content, Health data, endpoint URLs, provider credentials, booking/order/
  payment, merchant-write instructions, or transport request payloads.
- Keep receipt copy truthful: metadata/projection only, no completed/action-
  done wording and no claim that Google, Gaode, search, crawler, or MCP was
  contacted.

Acceptance:
- Tests cover accepted fixture receipts for Google/Gaode/Search/Crawler/MCP
  from the A21 registry result.
- Tests cover non-success receipts for local Apple/cache, Health/private
  blocked, confirmation-required, descriptor-unavailable, plan-rejected,
  malformed/not-prepared, and unregistered-provider adapter results.
- Tests prove receipt encoding contains no prompt/raw content/Health data,
  endpoint URL, API key, bearer token, provider credential, booking, order,
  payment, merchant-write fields, or transport request payloads.
- Tests prove no receipt/status uses completed/action-done wording or implies
  a real provider call.
- Static scan confirms no SwiftUI, URLSession, SDK imports, provider auth
  fields, WebView, StoreKit purchase call, crawler runtime, MCP client
  runtime, or transport send call.
- `git diff --check` passes.
```

## Round A23 - Server Provider Runtime Receipt Status Bridge

Status: implemented and verified. Do not ask the next coding agent to
re-create this round.

```text
Task: Add a pure bridge from `ServerProviderRuntimeReceipt` into the existing
provider-status side channel so UI can display future runtime receipt state
without changing recommendation rail layout, trust-pill vocabulary, or claiming
real provider execution. This is still not a real provider runtime: do not add
URLSession, endpoints, provider SDKs, provider auth material, Google/Gaode
clients, crawler runtime, MCP client runtime, booking/order/payment, merchant
writes, or `ServerTransport.send` calls.

Allowed files:
- kAir/DesignSystem/Components/ProviderStatusBadgeModel.swift
- kAirTests/DesignSystem/ProviderStatusBadgeModelTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add a value-only adapter that maps `ServerProviderRuntimeReceipt` into
  `ProviderStatusPresentation`, reusing existing badge kinds and card hints
  where possible.
- Preserve receipt states distinctly: fixture-projected, local-only,
  confirmation-required, blocked, descriptor-unavailable, plan-rejected,
  not-prepared, and unavailable.
- Preserve provider family, cost class, freshness, source policy,
  confirmation state, and audit/rejection reasons in UI-safe copy where the
  existing presentation model can carry them.
- Do not add new recommendation object kinds, trust-pill cases, navigation
  routes, SwiftUI layout, or live provider/client code.

Acceptance:
- Tests cover fixture Google/Gaode/Search/Crawler/MCP receipts mapping to
  normal or advisory provider status without execution wording.
- Tests cover local-only/cache, confirmation-required, Health/private blocked,
  descriptor-unavailable, plan-rejected, not-prepared, and unregistered/
  unavailable receipts mapping to truthful warning/disabled status.
- Tests prove the bridge does not alter `ActionCardTrustPillKind`,
  `MatchingObjectKind`, or `RecommendationRail.maxSlateSize`.
- Tests prove status copy still avoids completed/action-done wording and does
  not imply a real provider call.
- Static scan confirms no SwiftUI, URLSession, SDK imports, provider auth
  fields, WebView, StoreKit purchase call, crawler runtime, MCP client
  runtime, or transport send call.
- `git diff --check` passes.
```

## Round A24 - Server Provider Runtime Receipt Status Lookup Contract

Status: implemented and verified. Do not ask the next coding agent to
re-create this round.

```text
Task: Add a pure lookup/provider contract that stores
`ServerProviderRuntimeReceipt` values by recommendation id and exposes them
through the existing `ProviderStatusProviding` side channel. This makes future
runtime receipt status queryable by UI stores without mutating `MatchingObject`
or claiming real provider execution. This is still not a real provider runtime:
do not add URLSession, endpoints, provider SDKs, provider auth material,
Google/Gaode clients, crawler runtime, MCP client runtime, booking/order/
payment, merchant writes, or `ServerTransport.send` calls.

Allowed files:
- kAir/DesignSystem/Components/ProviderStatusBadgeModel.swift
- kAirTests/DesignSystem/ProviderStatusBadgeModelTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add a value-only receipt status provider/store that takes a dictionary or
  sequence of `(recommendationID, ServerProviderRuntimeReceipt)` pairs.
- The provider should conform to `ProviderStatusProviding` and return
  `ProviderStatusBadgeResolver.presentation(recommendationID:for:)` for known
  ids, `nil` for unknown ids.
- Duplicate recommendation ids must resolve deterministically without
  generating duplicate badges or mutating the receipt.
- Keep this as a side channel only: no `MatchingObject` schema changes, no
  new recommendation kinds, no trust-pill vocabulary changes, no SwiftUI
  layout, no ChatStore mutation, and no live provider/client code.

Acceptance:
- Tests cover lookup hit/miss, deterministic duplicate handling, and receipt
  status projection for fixture, local-only, blocked, confirmation-required,
  not-prepared, and unavailable receipts.
- Tests prove the provider does not alter `ActionCardTrustPillKind`,
  `MatchingObjectKind`, `RecommendationRail.maxSlateSize`, or any
  `MatchingObject` fields.
- Tests prove status copy still avoids completed/action-done wording and does
  not imply a real provider call.
- Static scan confirms no SwiftUI, URLSession, SDK imports, provider auth
  fields, WebView, StoreKit purchase call, crawler runtime, MCP client
  runtime, or transport send call.
- `git diff --check` passes.
```

## Round A25 - Provider Status Source Multiplexer Contract

Status: implemented and verified. Do not ask the next coding agent to
re-create this round.

```text
Task: Add a pure provider-status source multiplexer so UI stores can ask one
`ProviderStatusProviding` value for status while the implementation checks
runtime receipt status first and falls back to projected recommendation status.
This is a composition contract only: do not add SwiftUI layout, ChatStore
mutation, URLSession, endpoints, provider SDKs, provider auth material,
Google/Gaode clients, crawler runtime, MCP client runtime, booking/order/
payment, merchant writes, or `ServerTransport.send` calls.

Allowed files:
- kAir/DesignSystem/Components/ProviderStatusBadgeModel.swift
- kAirTests/DesignSystem/ProviderStatusBadgeModelTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add a value-only `ProviderStatusProviding` multiplexer that accepts an ordered
  list of provider-status sources.
- It should return the first non-nil `ProviderStatusPresentation` for a
  recommendation id and return `nil` when every source misses.
- Runtime receipt status should be able to override projected recommendation
  status by source order, but the multiplexer must not know about receipt,
  projection, or UI internals.
- Keep this as a side channel only: no `MatchingObject` schema changes, no new
  recommendation kinds, no trust-pill vocabulary changes, no SwiftUI layout, no
  ChatStore mutation, and no live provider/client code.

Acceptance:
- Tests cover runtime-source override, projected-source fallback, all-source
  miss, deterministic source order, and empty-source behavior.
- Tests prove the multiplexer does not alter `ActionCardTrustPillKind`,
  `MatchingObjectKind`, `RecommendationRail.maxSlateSize`, or any
  `MatchingObject` fields.
- Tests prove composed status copy still avoids completed/action-done wording
  and does not imply a real provider call.
- Static scan confirms no SwiftUI, URLSession, SDK imports, provider auth
  fields, WebView, StoreKit purchase call, crawler runtime, MCP client runtime,
  or transport send call.
- `git diff --check` passes.
```

## Round A26 - ChatStore Provider Status Source Injection Contract

Status: implemented and verified. Do not ask the next coding agent to
re-create this round.

```text
Task: Add explicit provider-status source injection to `ChatStore` so the app
composition root can later pass the A25 `ProviderStatusSourceMultiplexer` while
the chat rail still renders only `[MatchingObject]`. This is still not a UI
layout change and still not a live provider runtime: do not add SwiftUI layout,
URLSession, endpoints, provider SDKs, provider auth material, Google/Gaode
clients, crawler runtime, MCP client runtime, booking/order/payment, merchant
writes, or `ServerTransport.send` calls.

Allowed files:
- kAir/Features/Chat/Data/ChatStore.swift
- kAirTests/DesignSystem/ProviderStatusLookupTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add an optional `providerStatusProvider: ProviderStatusProviding? = nil`
  parameter to `ChatStore.init`.
- If an explicit provider-status source is supplied, use it. If not, preserve
  current behavior by deriving `recommendationProvider as? ProviderStatusProviding`.
- `providerStatusPresentation(for:)` should return status only for ids currently
  present in `recommendedMatches`, so stale receipt/provider statuses cannot
  appear for non-rendered cards.
- Keep this as a side channel only: no `MatchingObject` schema changes, no new
  recommendation kinds, no trust-pill vocabulary changes, no SwiftUI layout, no
  provider runtime calls, and no real server transport.

Acceptance:
- Tests prove default `ChatStore()` still exposes no fake provider status.
- Tests prove projected recommendation provider fallback still works when no
  explicit status source is supplied.
- Tests prove an explicit A25 multiplexer can override projected status for the
  same rendered recommendation id.
- Tests prove statuses for unknown or dismissed/non-rendered recommendation ids
  return nil even when the injected source can answer them.
- Tests prove `ActionCardTrustPillKind`, `MatchingObjectKind`,
  `RecommendationRail.maxSlateSize`, and `MatchingObject` fields are unchanged.
- Static scan confirms no SwiftUI layout, URLSession, SDK imports, provider auth
  fields, WebView, StoreKit purchase call, crawler runtime, MCP client runtime,
  or transport send call.
- `git diff --check` passes.
```

## Round A27 - App Composition Provider Status Wiring Contract

Status: implemented and verified. Do not ask the next coding agent to
re-create this round.

```text
Task: Wire the app composition root so `AppBootstrap` can carry an explicit
`ProviderStatusProviding` source and `ChatHomeView` passes that source into
`ChatStore`. This lets the app later install the A25 multiplexer without making
`ChatStore` infer composition policy. This is still not a UI layout change and
still not a live provider runtime: do not add URLSession, endpoints, provider
SDKs, provider auth material, Google/Gaode clients, crawler runtime, MCP client
runtime, booking/order/payment, merchant writes, or `ServerTransport.send`
calls.

Allowed files:
- kAir/App/AppEntry/AppBootstrap.swift
- kAir/Features/Chat/Presentation/ChatHomeView.swift
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add an optional `providerStatusProvider: ProviderStatusProviding? = nil`
  parameter/property to `AppBootstrap`.
- `ChatHomeView.init(bootstrap:)` should pass `bootstrap.providerStatusProvider`
  into `ChatStore(providerStatusProvider:)`.
- Preserve default and preview behavior: default bootstrap still carries nil,
  `ChatStore` default recommendation fixtures still expose no fake status.
- Keep this as composition wiring only: no `MatchingObject` schema changes, no
  recommendation kind changes, no trust-pill vocabulary changes, no SwiftUI
  layout changes, no provider runtime calls, and no real server transport.

Acceptance:
- Tests prove default and preview `AppBootstrap` expose no explicit provider
  status source.
- Tests prove a custom provider-status source is stored on `AppBootstrap`.
- Tests prove `ChatStore` still handles nil source through its A26 fallback
  behavior; do not duplicate ChatStore tests beyond the composition seam.
- Static scan confirms no URLSession, SDK imports, provider auth fields,
  WebView, StoreKit purchase call, crawler runtime, MCP client runtime, or
  transport send call.
- `git diff --check` passes.
```

## Round A28 - Chat Recommended Next Provider Status UI Binding Contract

Status: implemented and verified. Do not ask the next coding agent to
re-create this round.

```text
Task: Render the existing provider-status side channel in the Chat Recommended
Next UI. `ChatStore.providerStatusPresentation(for:)` is already wired through
the app composition root; this round should make the compact Recommended Next
cells show that status truthfully without changing recommendation schemas or
claiming real provider execution. Keep the UI dense, calm, and scan-friendly.
Do not add URLSession, endpoints, provider SDKs, provider auth material,
Google/Gaode clients, crawler runtime, MCP client runtime, booking/order/payment,
merchant writes, WebView/WKWebView, StoreKit purchase calls, or
`ServerTransport.send` calls.

Allowed files:
- kAir/Features/Chat/Presentation/ChatHomeView.swift
- kAir/DesignSystem/Components/ProviderStatusBadgeModel.swift
- kAirTests/DesignSystem/ProviderStatusBadgeModelTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add a UI-facing binding that lets `RecommendedNextConsole`/`RecommendedNextCell`
  receive an optional `ProviderStatusPresentation` for each `MatchingObject`.
  `ChatHomeView` should pass `store.providerStatusPresentation(for: object.id)`.
- Render provider-status badges and the status line inside the compact cell,
  under the existing recommendation text. Use existing badge labels, symbols,
  and tones from `ProviderStatusBadgeModel`; do not add trust-pill cases or
  mutate `MatchingObject`.
- Map `ProviderStatusCardHint` only to visual treatment for the compact cell
  (normal / warning / disabled). Do not introduce a new execution state or a
  provider send path.
- Preserve default behavior: when status is nil, the Recommended Next UI should
  look and behave as it did before A28.
- Keep the display copy truthful: fixture/dry-run/local/blocked/confirmation
  states must not say that a remote provider was contacted, a booking/order was
  completed, or a payment was attempted.

Acceptance:
- Tests cover the provider-status display model/binding for nil, normal,
  warning, and disabled hints without requiring brittle view-tree inspection.
- Tests prove the frozen `ProviderStatusBadgeKind`, `ActionCardTrustPillKind`,
  `MatchingObjectKind`, `RecommendationRail.maxSlateSize`, and `MatchingObject`
  field contracts do not change.
- Tests prove display copy for fixture/runtime receipt statuses remains
  non-executing and contains no "booked", "ordered", "paid", or "provider
  contacted" claim.
- Static scan confirms no URLSession, SDK imports, provider auth fields,
  WebView/WKWebView, StoreKit purchase call, crawler runtime, MCP client runtime,
  or transport send call.
- `git diff --check` passes.
```

## Round A29 - App Composition Recommendation Provider Wiring Contract

Status: implemented and verified. Do not ask the next coding agent to
re-create this round.

```text
Task: Wire the app composition root so `AppBootstrap` can carry an explicit
`RecommendationProvider` and `ChatHomeView` passes that provider into
`ChatStore`. A28 can render provider-status UI, but default Chat still constructs
its own stub recommendation provider. This round should make recommendation
source composition an app-root decision so future projected provider/search/MCP
recommendations can line up rendered card ids with provider-status sources. This
is still not a provider runtime: do not add URLSession, endpoints, provider SDKs,
provider auth material, Google/Gaode clients, crawler runtime, MCP client
runtime, booking/order/payment, merchant writes, WebView/WKWebView, StoreKit
purchase calls, or `ServerTransport.send` calls.

Allowed files:
- kAir/App/AppEntry/AppBootstrap.swift
- kAir/Features/Chat/Presentation/ChatHomeView.swift
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add an optional or defaulted `recommendationProvider` composition property to
  `AppBootstrap` without changing the default user-visible slate.
- `ChatHomeView.init(bootstrap:)` should pass the bootstrap-composed
  recommendation provider into `ChatStore(recommendationProvider:)` along with
  the existing provider-status source, feedback runtime, handoff, telemetry
  emitter, and capability registry.
- Preserve the default and preview slate behavior: default bootstrap should still
  produce the existing stub triple slate unless a caller injects another
  provider.
- Keep source composition separate from status composition. A projected provider
  may also conform to `ProviderStatusProviding`, but this round should not infer
  or auto-build a multiplexer.
- No `MatchingObject` schema changes, no recommendation kind changes, no
  trust-pill vocabulary changes, no provider runtime calls, and no server
  transport.

Acceptance:
- Tests prove default and preview `AppBootstrap` expose the same stub slate
  through the composition seam.
- Tests prove a custom `RecommendationProvider` is stored on `AppBootstrap` and
  reaches `ChatStore` through the same construction chain as `ChatHomeView`.
- Tests prove a projected recommendation provider can be injected and its
  recommendation ids still line up with `ChatStore.providerStatusPresentation`.
- Tests prove nil/explicit provider-status source behavior from A27/A28 remains
  unchanged.
- Static scan confirms no URLSession, SDK imports, provider auth fields,
  WebView/WKWebView, StoreKit purchase call, crawler runtime, MCP client runtime,
  or transport send call.
- `git diff --check` passes.
```

## Round A30 - App Provider Status Source Multiplexer Assembly Contract

Status: implemented and verified. Do not ask the next coding agent to
re-create this round.

```text
Task: Assemble provider-status source priority at the app composition root.
`ProviderStatusSourceMultiplexer`, `RuntimeReceiptProviderStatusStore`, and
`ProjectedRecommendationProvider` already exist as pure contracts, but
`AppBootstrap` needs an app-root composition path beyond a prebuilt optional
`ProviderStatusProviding`. This round should let the app root compose ordered
provider-status sources so a receipt-backed source can override projected
recommendation fallback without making `ChatStore` infer source order. This is
still not a provider runtime: do
not add URLSession, endpoints, provider SDKs, provider auth material,
Google/Gaode clients, crawler runtime, MCP client runtime, booking/order/payment,
merchant writes, WebView/WKWebView, StoreKit purchase calls, or
`ServerTransport.send` calls.

Allowed files:
- kAir/App/AppEntry/AppBootstrap.swift
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add a narrow app-root factory or initializer path that accepts ordered
  `ProviderStatusProviding` sources and stores a single composed
  `providerStatusProvider` on `AppBootstrap`.
- Preserve current behavior: default and preview bootstraps should still expose
  nil provider status, and a directly injected `providerStatusProvider` should
  still be stored as-is.
- When ordered sources are provided, compose them with
  `ProviderStatusSourceMultiplexer` in caller order. Receipt-derived stores must
  be able to win over projected recommendation fallback by ordering, not by
  `ChatStore` knowledge.
- Keep recommendation-provider composition separate from status composition. Do
  not auto-infer a multiplexer from every `RecommendationProvider`; callers must
  opt into status-source assembly explicitly.
- No `MatchingObject` schema changes, no UI layout changes, no trust-pill
  vocabulary changes, no provider runtime calls, and no server transport.

Acceptance:
- Tests prove default and preview `AppBootstrap` still expose nil
  `providerStatusProvider`.
- Tests prove directly injected provider-status source identity is preserved.
- Tests prove ordered app-root sources compose deterministically: first source
  wins when both return status, and later source acts as fallback when earlier
  source returns nil.
- Tests prove a projected recommendation provider plus an explicit status-source
  order can line up rendered card ids with `ChatStore.providerStatusPresentation`
  without changing recommendation cards.
- Static scan confirms no URLSession, SDK imports, provider auth fields,
  WebView/WKWebView, StoreKit purchase call, crawler runtime, MCP client runtime,
  or transport send call.
- `git diff --check` passes.
```

## Round A31 - Provider Access Profile Contract

Status: implemented and verified. Do not ask the next coding agent to
re-create this round.

```text
Task: Add a pure provider-access profile contract that centralizes the user's
current membership/cost/provider defaults before any `ProviderRequest` is built.
This is the next step toward membership-based switching between local Apple,
Gaode, Google, search, crawler, and MCP paths, but it must remain value-only:
do not add URLSession, endpoints, provider SDKs, provider auth material,
Google/Gaode clients, crawler runtime, MCP client runtime, booking/order/payment,
merchant writes, WebView/WKWebView, StoreKit purchase calls, or
`ServerTransport.send` calls.

Allowed files:
- kAir/Core/Providers/ProviderAccessProfile.swift
- kAirTests/Providers/ProviderAccessProfileTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Define a `ProviderAccessProfile` value type (`Codable`, `Hashable`,
  `Sendable`) with explicit fields for membership tier, default region,
  preferred map/provider family, metered provider entitlements, experimental
  provider enablement, unavailable providers, and cache-fallback default.
- Add conservative presets/factories for free-local default, plus China/Gaode
  preference, plus/pro Google entitlement, and developer/internal diagnostics.
  Presets must not grant metered providers unless the entitlement set explicitly
  includes that family.
- Add a method that builds `ProviderRequest` from a trace id, capability,
  privacy class, freshness, optional region override, and optional preferred
  provider override. It should apply profile defaults without hiding privacy,
  cost, entitlement, source, or experimental-provider gates already enforced by
  `ProviderRoutingPolicy`.
- Keep profile construction separate from `AppBootstrap` in this round. No UI,
  no model runtime, no server transport, and no changes to `ProviderRoutingPolicy`
  behavior except what tests consume through generated requests.

Acceptance:
- Tests prove the free-local profile routes map/place/route work to Apple local
  or cache without any metered entitlement.
- Tests prove a plus China profile can prefer Gaode for China route/local-service
  requests.
- Tests prove Google preferred routing remains blocked without an explicit
  Google entitlement and succeeds when the profile includes it.
- Tests prove Health/private privacy class still blocks remote providers even
  when the profile has membership/entitlement.
- Tests prove crawler and MCP remain disabled unless explicitly enabled in the
  profile, and cache fallback disabled is preserved in generated requests.
- Static scan confirms no URLSession, SDK imports, provider auth fields,
  WebView/WKWebView, StoreKit purchase call, crawler runtime, MCP client runtime,
  or transport send call.
- `git diff --check` passes.
```

## Round A32 - Provider Access Profile Search and MCP Request Bridge

```text
Status: implemented and verified.

Task: Extend `ProviderAccessProfile` so the same membership/cost/provider
defaults can build search/crawler and MCP request values. A31 covers
`ProviderRequest`; this round should cover `SearchProviderRequest` and
`MCPGatewayRequest` without adding runtime execution. Do not add URLSession,
endpoints, provider SDKs, provider auth material, Google/Gaode clients, crawler
runtime, MCP client runtime, booking/order/payment, merchant writes,
WebView/WKWebView, StoreKit purchase calls, or `ServerTransport.send` calls.

Allowed files:
- kAir/Core/Providers/ProviderAccessProfile.swift
- kAirTests/Providers/ProviderAccessProfileTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add a pure method that builds `SearchProviderRequest` from profile defaults plus
  query, trace id, capability, privacy class, freshness, robots state, result
  draft, cached result, optional provider override, and timestamp.
- Add a pure method that builds `MCPGatewayRequest` from profile defaults plus
  server id, operation, trace id, privacy class, and optional confirmation
  artifact.
- Search/MCP request builders must copy membership tier, preferred provider,
  metered entitlements, and experimental-provider enablement from the profile
  where the target request type supports those fields. They must keep privacy,
  robots/source, and confirmation explicit at the call site.
- Do not change `SearchProviderPolicy`, `MCPGatewayPolicy`, `ProviderRoutingPolicy`,
  UI, app composition, server transport, or provider runtime behavior.

Acceptance:
- Tests prove a free-local profile builds search requests that do not grant
  metered search or crawler access.
- Tests prove a profile with `.searchAPI` entitlement can build a search request
  that passes cost gates when a result draft is supplied.
- Tests prove crawler search requests remain disabled unless the profile enables
  `.crawler`, and still require robots/source policy inputs.
- Tests prove private/Health privacy class still blocks remote search/crawler
  even when profile membership/entitlement exists.
- Tests prove MCP requests carry membership/privacy/confirmation from the profile
  and call site, while MCP allowlist, Health prompt/resource blocking, and
  confirmation-required behavior remain owned by `MCPGatewayPolicy`.
- Static scan confirms no URLSession, SDK imports, provider auth fields,
  WebView/WKWebView, StoreKit purchase call, crawler runtime, MCP client runtime,
  or transport send call.
- `git diff --check` passes.
```

## Round A33 - Provider Access Profile App and Search Intent Wiring

```text
Status: implemented and verified.

Task: Thread `ProviderAccessProfile` through app composition and Search intent
request lowering so membership/cost/provider defaults are not duplicated by
vertical fixtures. Do not add URLSession, endpoints, provider SDKs, provider auth
material, Google/Gaode clients, crawler runtime, MCP client runtime,
booking/order/payment, merchant writes, WebView/WKWebView, StoreKit purchase
calls, or `ServerTransport.send` calls.

Allowed files:
- kAir/App/AppEntry/AppBootstrap.swift
- kAir/Features/Search/Domain/SearchIntent.swift
- kAirTests/App/AppBootstrapTests.swift
- kAirTests/Search/SearchIntentTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add a default-preserving `providerAccessProfile` property to `AppBootstrap`,
  defaulting to `.freeLocalDefault` unless explicitly injected.
- Add a SearchIntent lowering path that accepts `ProviderAccessProfile` and uses
  `profile.searchProviderRequest(...)` instead of hand-copying membership,
  entitlement, and experimental-provider fields.
- Preserve source-mode provider override behavior: `.searchAPI`, `.crawlerFetch`,
  and `.cacheOnly` remain explicit intent choices and should override the
  profile's preferred provider only for the lowered search request.
- Keep privacy class, freshness, robots state, result draft, cached result, and
  timestamp explicit at the SearchIntent/call-site boundary.
- Do not change `SearchProviderPolicy`, `MCPGatewayPolicy`, `ProviderRoutingPolicy`,
  UI, server transport, provider runtime, or app navigation behavior.

Acceptance:
- Tests prove default `AppBootstrap` exposes `.freeLocalDefault` without changing
  existing bootstrap defaults.
- Tests prove an injected `ProviderAccessProfile` is stored by value and survives
  alongside existing recommendation/status/capability bootstrap injection.
- Tests prove SearchIntent can lower through a profile so search entitlement,
  membership tier, and crawler experimental enablement come from the profile.
- Tests prove SearchIntent source mode still owns the preferred provider override.
- Tests prove privacy class and robots state are still explicit on the intent and
  are not inferred from profile membership.
- Static scan confirms no URLSession, SDK imports, provider auth fields,
  WebView/WKWebView, StoreKit purchase call, crawler runtime, MCP client runtime,
  or transport send call.
- `git diff --check` passes.
```

## Round A34 - Search Capability Adapter Access Profile Configuration

```text
Status: implemented and verified.

Task: Thread `ProviderAccessProfile` through `SearchCapabilityAdapter`
configuration so Search adapter decisions use the same profile-based lowering as
`AppBootstrap` and `SearchIntent`. Do not add URLSession, endpoints, provider
SDKs, provider auth material, Google/Gaode clients, crawler runtime, MCP client
runtime, booking/order/payment, merchant writes, WebView/WKWebView, StoreKit
purchase calls, or `ServerTransport.send` calls.

Allowed files:
- kAir/Features/Search/Data/SearchCapabilityAdapter.swift
- kAirTests/Search/SearchCapabilityAdapterTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add `providerAccessProfile` to `SearchCapabilityAdapter.Configuration`.
- Preserve existing fixture defaults by expressing them as an access profile
  rather than separate membership/entitlement/experimental-provider fields.
- Update `decision(for:)` so it calls
  `intent.providerRequest(providerAccessProfile: configuration.providerAccessProfile, ...)`.
- Keep source mode, privacy class, freshness, robots state, result drafts,
  cached results, registry, and timestamp explicit in configuration/intent.
- Do not change `SearchProviderPolicy`, `ProviderRoutingPolicy`,
  `MCPGatewayPolicy`, UI, app navigation, server transport, or provider runtime
  behavior.

Acceptance:
- Existing SearchCapabilityAdapter tests still pass.
- Tests prove enabled fixture search entitlement comes from
  `providerAccessProfile`.
- Tests prove crawler enablement comes from `providerAccessProfile` while robots
  state remains explicit configuration input.
- Tests prove private-context blocking still uses explicit configuration privacy,
  not profile membership.
- Tests prove legacy convenience parameters, if retained, produce the same
  `providerAccessProfile` values and do not create a second routing path.
- Static scan confirms no URLSession, SDK imports, provider auth fields,
  WebView/WKWebView, StoreKit purchase call, crawler runtime, MCP client runtime,
  or transport send call.
- `git diff --check` passes.
```

## Round A35 - Reserved Search Adapter Factory

```text
Status: implemented and verified.

Task: Add an explicit reserved Search adapter factory seam so the app can build a
profile-aware `SearchCapabilityAdapter` later without registering `.webSearch` in
the default shipped registry. Do not add URLSession, endpoints, provider SDKs,
provider auth material, Google/Gaode clients, crawler runtime, MCP client
runtime, booking/order/payment, merchant writes, WebView/WKWebView, StoreKit
purchase calls, or `ServerTransport.send` calls.

Allowed files:
- kAir/Core/Capability/DefaultCapabilityRegistry.swift
- kAirTests/Capability/DefaultCapabilityRegistryTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add a factory method that builds a `SearchCapabilityAdapter` or
  `SearchCapabilityAdapter.Configuration` from explicit inputs, including
  `ProviderAccessProfile`.
- Keep `makeWithShippedStubs()` unchanged: it must still register only the three
  v1 shipped kinds and leave `.webSearch` unregistered by default.
- Keep search adapter availability explicit; the factory must not silently make
  search available unless the caller passes an enabled fixture/configuration.
- Keep privacy class, source mode, freshness, robots state, result drafts,
  cached results, registry, and timestamp explicit factory inputs.
- Do not change `SearchCapabilityAdapter`, `SearchProviderPolicy`,
  `ProviderRoutingPolicy`, `MCPGatewayPolicy`, UI, app navigation, server
  transport, or provider runtime behavior unless tests prove a narrowly required
  signature adjustment.

Acceptance:
- Tests prove `DefaultCapabilityRegistry.makeWithShippedStubs()` still registers
  exactly `.aiCompletion`, `.threadLookup`, and `.localStoreLookup`.
- Tests prove `.webSearch` remains absent from the default registry.
- Tests prove the new reserved factory can build a search adapter/configuration
  that carries an injected `ProviderAccessProfile`.
- Tests prove the reserved factory preserves explicit privacy/robots/source-mode
  inputs and disabled-by-default availability.
- Static scan confirms no URLSession, SDK imports, provider auth fields,
  WebView/WKWebView, StoreKit purchase call, crawler runtime, MCP client runtime,
  or transport send call.
- `git diff --check` passes.
```

## Round A36 - Explicit Reserved Search Registry Composition

```text
Status: implemented and verified.

Task: Add an explicit registry-composition method that can install a caller-built
`SearchCapabilityAdapter` into a `CapabilityRegistry` only when the caller opts
in. The default `makeWithShippedStubs()` path must stay unchanged and must not
register `.webSearch`. Do not add URLSession, endpoints, provider SDKs, provider
auth material, Google/Gaode clients, crawler runtime, MCP client runtime,
booking/order/payment, merchant writes, WebView/WKWebView, StoreKit purchase
calls, or `ServerTransport.send` calls.

Allowed files:
- kAir/Core/Capability/DefaultCapabilityRegistry.swift
- kAirTests/Capability/DefaultCapabilityRegistryTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add a method such as `makeWithShippedStubs(reservedSearchAdapter:)` or
  `makeWithExplicitSearchAdapter(...)` that starts from the three shipped stubs
  and registers `.webSearch` only when an explicit `SearchCapabilityAdapter` is
  supplied.
- Keep `makeWithShippedStubs()` byte-for-byte behavior equivalent from caller
  perspective: three shipped kinds, no `.webSearch`.
- Do not let the composition method construct network or provider runtimes. If it
  needs a Search adapter, use the A35 reserved configuration factory plus
  `SearchCapabilityAdapter(configuration:)`.
- Preserve duplicate-registration behavior and first-registered-wins invariant.
- Do not change `CapabilityRegistry`, `SearchCapabilityAdapter`,
  `SearchProviderPolicy`, UI, app navigation, server transport, or provider
  runtime behavior unless compile tests prove a narrowly required signature
  adjustment.

Acceptance:
- Tests prove default `makeWithShippedStubs()` still returns exactly the three
  shipped adapters and no `.webSearch`.
- Tests prove the explicit composition method registers `.webSearch` only when a
  search adapter is supplied.
- Tests prove the registered adapter reports `.webSearch` and its availability
  reflects the explicit Search configuration.
- Tests prove calling the explicit composition method with no search adapter, if
  that overload exists, behaves like the default shipped registry.
- Static scan confirms no URLSession, SDK imports, provider auth fields,
  WebView/WKWebView, StoreKit purchase call, crawler runtime, MCP client runtime,
  or transport send call.
- `git diff --check` passes.
```

## Round A37 - App Bootstrap Reserved Search Opt-In

```text
Status: implemented and verified.

Task: Add a default-preserving app-bootstrap opt-in for the reserved Search
adapter. The app root may assemble `.webSearch` only when an explicit
`SearchCapabilityAdapter` is supplied or when an explicit disabled/enabled Search
configuration is converted into an adapter at composition time. The default app
bootstrap must remain local-only and must not register `.webSearch`.

Allowed files:
- kAir/App/AppEntry/AppBootstrap.swift
- kAir/Core/Capability/DefaultCapabilityRegistry.swift
- kAirTests/App/AppBootstrapTests.swift
- kAirTests/Capability/DefaultCapabilityRegistryTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Keep `AppBootstrap()` and preview/default bootstrap behavior unchanged:
  provider access profile remains `.freeLocalDefault`, registry remains the three
  shipped local stubs, and `.webSearch` is absent.
- Add an explicit initializer path or factory parameter that accepts a
  `SearchCapabilityAdapter` or `SearchCapabilityAdapter.Configuration`.
- If configuration is accepted, construct the adapter through
  `SearchCapabilityAdapter(configuration:)` and install it through the A36
  registry-composition method.
- Preserve existing custom-registry injection behavior: a directly injected
  registry should not be overwritten by Search opt-in glue unless the new API
  explicitly documents and tests that behavior.
- Do not add URLSession, endpoints, provider SDKs, provider auth material,
  Google/Gaode clients, crawler runtime, MCP client runtime, booking/order/payment,
  merchant writes, WebView/WKWebView, StoreKit purchase calls, or
  `ServerTransport.send` calls.

Acceptance:
- Tests prove default `AppBootstrap()` and preview bootstrap still expose a
  registry with exactly `.aiCompletion`, `.threadLookup`, and `.localStoreLookup`.
- Tests prove `.webSearch` is absent by default.
- Tests prove the explicit Search opt-in path registers `.webSearch` and its
  availability reflects the supplied Search configuration.
- Tests prove `providerAccessProfile` remains a separate app-root input and is
  not silently inferred from Search adapter availability.
- Static scan confirms no URLSession, SDK imports, provider auth fields,
  WebView/WKWebView, StoreKit purchase call, crawler runtime, MCP client runtime,
  or transport send call.
- `git diff --check` passes.
```

## Round A38 - Chat Search Availability Propagation

```text
Status: implemented and verified.

Task: Prove the reserved Search opt-in assembled by `AppBootstrap` reaches the
chat composition path as capability availability, without triggering Search
resolution, crawler/runtime execution, MCP calls, network calls, or UI behavior
changes. This is a propagation/contract gate only.

Allowed files:
- kAir/Features/Chat/Data/ChatStore.swift
- kAir/Features/Chat/Presentation/ChatHomeView.swift
- kAirTests/App/AppBootstrapTests.swift
- kAirTests/Capability/ChatStoreCapabilityConsumerTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer tests first. If `ChatStore` already reflects any bootstrap registry
  snapshot, add coverage only.
- Add or update a test that builds `AppBootstrap(reservedSearchConfiguration:)`,
  constructs `ChatStore` the same way `ChatHomeView.init(bootstrap:)` does, waits
  for `pendingCapabilityRefresh`, and asserts `.webSearch` appears only when the
  bootstrap opt-in registry contains it.
- Add or update a test proving default bootstrap still keeps `.webSearch` absent
  from `ChatStore.capabilityAvailability`.
- If code changes are needed, keep them to wiring `bootstrap.capabilityRegistry`
  through existing init seams. Do not add prompts, result resolution, search UI,
  provider routing calls, network runtime, crawler runtime, MCP runtime, or
  server transport calls.

Acceptance:
- Tests prove default ChatStore-from-bootstrap availability has only the three
  shipped local kinds.
- Tests prove Search-opt-in bootstrap availability reaches ChatStore as
  `.webSearch == true` or `.webSearch == false` according to the supplied Search
  configuration.
- Tests prove no transcript message or recommendation slate mutation is caused by
  Search availability refresh alone.
- Static scan confirms no URLSession, SDK imports, provider auth fields,
  WebView/WKWebView, StoreKit purchase call, crawler runtime, MCP client runtime,
  search `resolve` call, or transport send call.
- `git diff --check` passes.
```

## Round A39 - Chat Search Availability Presentation

```text
Status: implemented and verified.

Task: Add a pure Chat-side Search availability presentation/state mapping so the
chat layer can distinguish three states from `capabilityAvailability`:
not-in-build (`.webSearch` absent), registered but unavailable (`.webSearch ==
false`), and registered available (`.webSearch == true`). Do not execute Search,
do not add search UI, and do not call any provider/crawler/MCP/runtime path.

Allowed files:
- kAir/Features/Chat/Data/ChatStore.swift
- kAirTests/Capability/ChatStoreCapabilityConsumerTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer a small value type or enum close to `ChatStore` such as
  `ChatSearchAvailabilityState`.
- Compute it from `capabilityAvailability[.webSearch]` only:
  nil -> not in build; false -> registered unavailable; true -> available.
- Keep the value read-only/presentation-only. It must not trigger
  `SearchCapabilityAdapter.resolve`, recommendation refresh, transcript writes,
  routing, UI navigation, network calls, crawler runtime, MCP runtime, or server
  transport.
- Keep copy factual: "Search not installed", "Search reserved but unavailable",
  and "Search available" style language is acceptable; do not claim live web
  results, crawling, booking, ordering, or provider contact.

Acceptance:
- Tests prove all three states from default bootstrap, disabled Search opt-in,
  and enabled Search opt-in.
- Tests prove the state changes only after the capability refresh task lands.
- Tests prove reading the state does not mutate transcript messages or
  recommendations.
- Static scan confirms no URLSession, SDK imports, provider auth fields,
  WebView/WKWebView, StoreKit purchase call, crawler runtime, MCP client runtime,
  search `resolve` call, provider routing call, or transport send call.
- `git diff --check` passes.
```

## Round A40 - Chat Search Availability Display Model

```text
Status: implemented and verified.

Task: Add a non-executing Chat Search availability display model that maps
`ChatSearchAvailabilityState` to stable icon, tone, and accessibility copy for
future UI binding. Do not render new visible UI in this round and do not call
Search/provider/crawler/MCP/runtime paths.

Allowed files:
- kAir/Features/Chat/Data/ChatStore.swift
- kAirTests/Capability/ChatStoreCapabilityConsumerTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add a small value type such as `ChatSearchAvailabilityDisplay`.
- Map the three A39 states to stable, factual values:
  not-in-build -> hidden/neutral/offline copy,
  registered-unavailable -> warning or disabled tone,
  available -> positive/ready tone.
- Use system icon names only as strings; do not import SwiftUI if the model can
  stay pure.
- Keep copy factual and boundary-safe. It must not claim live web results,
  crawling, booking, ordering, provider contact, or external execution.
- Reading/building the display model must not mutate transcript messages,
  recommendations, capability availability, navigation state, or telemetry.

Acceptance:
- Tests prove every `ChatSearchAvailabilityState` maps to stable icon/tone/copy.
- Tests prove the default not-in-build state is non-promotional and does not
  imply Search can run.
- Tests prove reading the display model does not mutate transcript messages or
  recommendations.
- Static scan confirms no URLSession, SDK imports, provider auth fields,
  WebView/WKWebView, StoreKit purchase call, crawler runtime, MCP client runtime,
  search `resolve` call, provider routing call, SwiftUI view rendering, or
  transport send call.
- `git diff --check` passes.
```

## Round A41 - Chat Search Availability UI Binding

```text
Status: implemented and verified.

Task: Bind `ChatStore.searchAvailabilityDisplay` into a non-interactive Chat UI
affordance. It should be visible only when Search is explicitly registered
(`display.isVisible == true`) and must not create a button, prompt submission,
navigation route, Search resolve call, crawler call, MCP call, network call, or
provider-runtime path.

Allowed files:
- kAir/Features/Chat/Presentation/ChatHomeView.swift
- kAir/Features/Chat/Data/ChatStore.swift
- kAirTests/Capability/ChatStoreCapabilityConsumerTests.swift
- kAirTests/DesignSystem or an existing Chat/UI test file if a pure display
  assertion already lives there
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add a small SwiftUI view only if needed, such as
  `SearchAvailabilityIndicator`, that consumes `ChatSearchAvailabilityDisplay`.
- Render nothing for `isVisible == false`.
- For visible states, render icon + concise status copy only. Do not add tap,
  button, menu, routing, submit, or command handlers.
- Use existing theme tokens and avoid new one-off palettes.
- Keep copy boundary-safe: "Search reserved but unavailable" and "Search
  available" are acceptable; do not claim live web results, crawling, booking,
  ordering, provider contact, or external execution.

Acceptance:
- Tests or view-model assertions prove hidden default behavior for not-in-build.
- Tests prove registered-unavailable and available states expose distinct
  tone/copy/accessibility values.
- Tests prove the binding does not mutate transcript messages, recommendations,
  capability availability, navigation state, or telemetry.
- Static scan confirms no URLSession, SDK imports, provider auth fields,
  WebView/WKWebView, StoreKit purchase call, crawler runtime, MCP client runtime,
  search `resolve` call, provider routing call, prompt submission, navigation
  route, or transport send call.
- `git diff --check` passes.
```

## Round A42 - Server Provider Runtime Pipeline

```text
Status: implemented and verified.

Task: Add a single non-network server-provider runtime pipeline that composes
the already-built A11-A23 pieces into one value-returning entry point:
readiness gate -> runtime descriptor lookup -> invocation plan -> dispatch
boundary -> fixture adapter registry -> runtime receipt. This is orchestration
only. Do not call `ServerTransport.send`, URLSession, provider SDKs, crawler
runtime, MCP runtime, StoreKit, or any real network/API path.

Allowed files:
- kAir/Core/Networking/ServerProviderRuntimePipeline.swift
- kAir/Core/Networking/ServerProviderRuntime*.swift only if a small public seam
  is missing
- kAirTests/Networking/ServerProviderRuntimePipelineTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer a value-only type such as `ServerProviderRuntimePipeline.run(_:)` that
  accepts `ServerProviderReadinessDecision` or the current readiness output type
  already used by `ServerProviderRuntimeInvocationPlanner`.
- The pipeline must return `ServerProviderRuntimeReceipt`.
- Preserve every intermediate audit state on the returned receipt; do not
  collapse confirmation-required, descriptor-unavailable, malformed-plan,
  private-remote-blocked, local-only, or unregistered-adapter states into a
  generic failure.
- Use `ServerProviderRuntimeAdapterRegistry.resolve` as the only adapter
  resolver. Keep fixture adapters fixture-only.
- Keep copy boundary-safe: no "completed", "action done", "provider contacted",
  "live result", or "server executed" wording unless a future real transport
  receipt proves it.

Acceptance:
- Tests prove prepared Google/Gaode/Search/Crawler/MCP readiness decisions flow
  through to accepted fixture receipts.
- Tests prove local Apple/cache and blocked/private/confirmation/malformed
  states return non-success receipts and preserve the exact audit reason.
- Tests prove the pipeline output encoding does not expose prompt text, API keys,
  bearer tokens, credentials, raw Health data, raw page content, payment data,
  or merchant-write instructions.
- Static scan confirms no URLSession, SDK imports, provider auth fields,
  WebView/WKWebView, StoreKit purchase call, crawler runtime, MCP client runtime,
  `ServerTransport.send`, or real network call.
- `git diff --check` passes.
```

## Round A43 - Pipeline Receipt Status Source

```text
Task: Prove pipeline-generated `ServerProviderRuntimeReceipt` values can feed
the existing provider-status side channel by recommendation id. This is a
composition proof only: do not create real provider calls, do not execute
Search/crawler/MCP, do not call `ServerTransport.send`, and do not change
Recommended Next layout.

Allowed files:
- kAir/DesignSystem/Components/ProviderStatusBadgeModel.swift only if a small
  composition seam is missing
- kAirTests/DesignSystem/ProviderStatusBadgeModelTests.swift
- kAirTests/Networking/ServerProviderRuntimePipelineTests.swift only if shared
  pipeline fixtures need a small helper
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer tests first. `RuntimeReceiptProviderStatusStore` and
  `ProviderStatusSourceMultiplexer` already exist; do not duplicate them.
- Build several receipts through `ServerProviderRuntimePipeline.run(...)`, then
  install them in `RuntimeReceiptProviderStatusStore` with recommendation ids.
- Assert the resulting `ProviderStatusPresentation` values preserve provider,
  cost, freshness, blocked/confirmation/unavailable states, and safe copy.
- Assert the multiplexer can compose pipeline-receipt status before or after an
  existing projected source using the existing first-source-wins semantics.
- Do not mutate `MatchingObject`, recommendation order, ChatStore slate,
  transcript messages, navigation state, telemetry, or layout constants.

Acceptance:
- Tests prove pipeline-generated fixture receipts map to provider-status badges
  and compact-cell displays without execution wording.
- Tests prove local-only, private-blocked, confirmation-required,
  descriptor-unavailable, plan-rejected, and unavailable receipts remain distinct
  in provider-status presentation.
- Tests prove duplicate recommendation ids still keep first receipt semantics.
- Static scan confirms no URLSession, SDK imports, provider auth fields,
  WebView/WKWebView, StoreKit purchase call, crawler runtime, MCP client runtime,
  `ServerTransport.send`, Search resolve call, prompt submission, navigation
  route, or layout rewrites.
- `git diff --check` passes.
```

Status after review: implemented and verified in
`ProviderStatusBadgeModelTests`. The tests build fixture, local-only,
private-blocked, confirmation-required, descriptor-unavailable, plan-rejected,
and unavailable receipts through `ServerProviderRuntimePipeline.run(...)`, then
prove the existing status store, multiplexer, duplicate-id handling, compact-cell
display, and frozen rail contracts stay intact.

## Round A44 - AppBootstrap Pipeline Receipt Status Composition

```text
Task: Prove an app-root caller can supply precomputed pipeline-derived runtime
receipt status through `AppBootstrap.providerStatusSources`, and that the
ChatStore/ChatHome composition path can consume it by recommendation id. This is
a composition proof only: `AppBootstrap`, views, and ChatStore must not execute
`ServerProviderRuntimePipeline.run(...)`.

Allowed files:
- kAir/App/AppEntry/AppBootstrap.swift only if a tiny precomputed-source seam is
  missing
- kAirTests/App/AppBootstrapTests.swift
- kAirTests/Capability/ChatStoreCapabilityConsumerTests.swift only if the
  ChatHome-mirroring store helper needs direct coverage
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer tests first. Build pipeline receipts in tests, wrap them in
  `RuntimeReceiptProviderStatusStore`, then pass that store through
  `AppBootstrap(providerStatusSources:)`.
- Assert `AppBootstrap.providerStatusProvider` returns the pipeline-derived
  `ProviderStatusPresentation` for the supplied recommendation id and nil for
  unknown ids.
- Assert first-source-wins behavior still holds when a precomputed receipt store
  is composed with another `ProviderStatusProviding` source at the app root.
- If covering ChatStore, mirror the existing ChatHome initializer path: supply a
  recommendation provider whose recommendation id matches the receipt store, then
  assert only rendered recommendation ids expose status.
- Do not call providers, Search/crawler/MCP, `ServerTransport.send`, navigation
  routes, prompt submission, telemetry, or transcript writes.
- Do not mutate `MatchingObject`, recommendation order, ChatStore slate defaults,
  Recommended Next layout, or compact-cell copy.

Acceptance:
- Tests prove a precomputed `RuntimeReceiptProviderStatusStore` can be installed
  through `AppBootstrap(providerStatusSources:)` and queried through
  `providerStatusProvider`.
- Tests prove app-root source order remains deterministic for pipeline-derived
  receipt status versus fallback status sources.
- If ChatStore coverage is touched, tests prove status remains scoped to rendered
  recommendation ids and default/preview bootstraps remain nil/default.
- Static scan confirms no view-time pipeline execution, real transport/network
  call, provider runtime call, Search resolve call, prompt submission,
  navigation route, transcript write, telemetry emit, or layout rewrite.
- `git diff --check` passes.
```

Status after review: implemented and verified in `AppBootstrapTests`. The tests
install a precomputed `RuntimeReceiptProviderStatusStore` through
`AppBootstrap(providerStatusSources:)`, prove source order remains deterministic
against fallback status providers, and mirror the ChatHome -> ChatStore
composition path so pipeline-derived status is exposed only for rendered
recommendation ids. No production code was required.

## Round A45 - Provider Access Quota Snapshot Bridge

```text
Task: Add a pure bridge from `ProviderAccessProfile` into
`ServerProviderQuotaSnapshot` so membership packages, metered entitlements,
unavailable providers, experimental provider enablement, and explicit included
quota inputs can be assembled before real Google/Gaode/Search/Crawler/MCP
transport exists.

Allowed files:
- kAir/Core/Networking/ServerProviderEnvelopeFactory.swift
- kAirTests/Networking/ServerProviderEnvelopeFactoryTests.swift
- kAirTests/Providers/ProviderAccessProfileTests.swift only if the bridge
  belongs on the profile type rather than the quota snapshot type
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer tests first. Do not add SDKs, network calls, API keys, endpoints,
  payment code, StoreKit, crawler runtime, MCP client runtime, or transport
  execution.
- Keep the bridge value-only and deterministic. A safe shape is a
  `ServerProviderQuotaSnapshot` factory/init that accepts a
  `ProviderAccessProfile` plus explicit allowed families, remaining included
  quota, and metered eligibility inputs.
- Do not silently grant paid/provider access from membership alone. Metered
  providers must still require explicit metered entitlement/eligibility, and
  included-quota providers must still require explicit included quota.
- Profile unavailable providers must become disabled provider families.
- Profile enabled experimental providers must gate crawler/MCP experimental
  enablement.
- Preserve the existing default: local Apple/cache only unless the caller
  supplies explicit remote/provider quota inputs.

Acceptance:
- Tests prove `.freeLocalDefault` lowers to a local-only quota snapshot and
  cannot create remote executable envelopes.
- Tests prove a Google-entitled profile still needs explicit metered eligibility
  before Google can produce an executable envelope.
- Tests prove `plusChinaGaode` can produce an included-quota Gaode envelope only
  when explicit Gaode quota remains.
- Tests prove disabled/unavailable providers block even if quota/entitlement is
  otherwise present.
- Tests prove crawler/MCP experimental providers remain disabled unless the
  profile enables them and the quota snapshot explicitly allows them.
- Static scan confirms no transport/network/provider runtime call, SDK import,
  API credential field, StoreKit purchase, crawler runtime, MCP client runtime,
  prompt submission, navigation route, transcript write, telemetry emit, or UI
  layout change.
- `git diff --check` passes.
```

Status after review: implemented and verified in
`ServerProviderEnvelopeFactoryTests`. The bridge lives on
`ServerProviderQuotaSnapshot`; it folds in profile metered entitlements,
unavailable providers, and experimental intent while keeping allowed provider
families, remaining included quota, metered eligibility, and explicit
experimental quota inputs caller-controlled.

## Round A46 - AppBootstrap Provider Quota Snapshot Composition

```text
Task: Wire the app composition root so `AppBootstrap` can carry an explicit
`ServerProviderQuotaSnapshot`, defaulting to the local-only snapshot derived from
its `providerAccessProfile`. This is composition-only; do not call provider
factories, Search/crawler/MCP, the runtime pipeline, or `ServerTransport.send`.

Allowed files:
- kAir/App/AppEntry/AppBootstrap.swift
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer tests first.
- Add a value-only `providerQuotaSnapshot` property to `AppBootstrap`.
- Default it from the already-selected `providerAccessProfile` using the A45
  bridge, so default and preview bootstraps remain Apple/cache local-only.
- Allow explicit injection of a custom `ServerProviderQuotaSnapshot` for future
  paid/provider package composition. Direct injection should preserve exact
  value semantics and should not be recomputed.
- Ensure the property coexists with existing recommendation provider,
  provider-status source, reserved Search, capability registry, telemetry, and
  continuation injection seams.
- Do not pass the quota snapshot into Search adapters, envelope factories, or
  runtime pipeline in this round.

Acceptance:
- Tests prove default and preview `AppBootstrap` expose the local-only quota
  snapshot derived from `.freeLocalDefault`.
- Tests prove a custom `providerAccessProfile` changes the default quota
  snapshot only through the A45 bridge and still does not grant remote allowed
  families without explicit quota inputs.
- Tests prove an explicitly injected quota snapshot is stored exactly and wins
  over the profile-derived default.
- Tests prove the quota snapshot survives alongside existing app-root injection
  seams.
- Static scan confirms no transport/network/provider runtime call, SDK import,
  API credential field, StoreKit purchase, crawler runtime, MCP client runtime,
  prompt submission, navigation route, transcript write, telemetry emit, Search
  resolve call, envelope factory call from AppBootstrap, or UI layout change.
- `git diff --check` passes.
```

Status after review: implemented and verified in `AppBootstrapTests`.
`AppBootstrap` now stores `providerQuotaSnapshot`, derives the default from the
resolved `providerAccessProfile`, preserves explicitly injected snapshots
exactly, and keeps the value alongside existing recommendation, capability,
status-source, telemetry, and continuation seams without executing providers.

## Round A47 - Search Adapter Quota Snapshot Configuration

```text
Task: Thread `ServerProviderQuotaSnapshot` into reserved Search adapter
configuration so Search can carry package/cost context at the configuration
boundary before any real provider call exists. This is configuration-only; do
not call Search resolve, `ServerProviderEnvelopeFactory`, provider runtime,
crawler/MCP, network transport, or `ServerTransport.send`.

Allowed files:
- kAir/Features/Search/Data/SearchCapabilityAdapter.swift
- kAir/Core/Capability/DefaultCapabilityRegistry.swift only if the reserved
  Search factory must preserve or default the quota snapshot
- kAir/App/AppEntry/AppBootstrap.swift only if reserved Search opt-in needs
  app-root pass-through for the already-composed snapshot
- kAirTests/Search/SearchCapabilityAdapterTests.swift
- kAirTests/Capability/DefaultCapabilityRegistryTests.swift
- kAirTests/App/AppBootstrapTests.swift only if bootstrap pass-through needs
  direct coverage
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer tests first.
- Add a value-only `providerQuotaSnapshot` to
  `SearchCapabilityAdapter.Configuration`.
- Default the snapshot from the configuration's `providerAccessProfile` using
  `ServerProviderQuotaSnapshot(providerAccessProfile:)`, preserving existing
  local/default behavior.
- Preserve explicit custom snapshot injection exactly; do not recompute or
  widen it when the caller supplies one.
- Keep legacy convenience initializers and existing Search availability /
  decision behavior stable.
- If updating `DefaultCapabilityRegistry.makeReservedSearchConfiguration`,
  make it default-preserving and allow explicit quota snapshot pass-through.
- If touching `AppBootstrap`, only pass the already-composed value into an
  explicitly opted-in reserved Search configuration; do not register Search by
  default.

Acceptance:
- Tests prove default Search configuration still lowers to the local-only quota
  snapshot and preserves current availability/decision behavior.
- Tests prove a custom `providerAccessProfile` affects the default quota
  snapshot only through the A45 bridge and does not grant remote Search
  execution by itself.
- Tests prove an explicitly supplied `ServerProviderQuotaSnapshot` is stored
  exactly on `SearchCapabilityAdapter.Configuration`.
- Tests prove the reserved Search factory and any app-root pass-through preserve
  the snapshot value without registering `.webSearch` by default.
- Static scan confirms no transport/network/provider runtime call, SDK import,
  API credential field, StoreKit purchase, crawler runtime, MCP client runtime,
  prompt submission, navigation route, transcript write, telemetry emit,
  `SearchCapabilityAdapter.resolve`, `ServerProviderEnvelopeFactory` call, or UI
  layout change.
- `git diff --check` passes.
```

Status after review: implemented and verified in `SearchCapabilityAdapterTests`,
`DefaultCapabilityRegistryTests`, and `AppBootstrapTests`. The quota snapshot is
stored on Search configuration, defaulted from the profile through the A45
bridge, preserved exactly when explicit, and passed from `AppBootstrap` only for
explicit reserved Search configuration opt-in. Search resolve and policy decision
behavior remain unchanged.

## Round A48 - Search Dry-Run Envelope Preview

```text
Task: Add a non-executing Search dry-run preview that combines a
`SearchProviderDecision` with `SearchCapabilityAdapter.Configuration`'s
`providerQuotaSnapshot`, then projects the result through the existing
`ServerProviderEnvelopeFactory` and `ServerProviderDryRunEvaluator` layers. This
is advisory-only; do not call Search resolve, network transport, crawler/MCP
runtime, provider runtime pipeline, or `ServerTransport.send`.

Allowed files:
- kAir/Features/Search/Data/SearchCapabilityAdapter.swift
- kAirTests/Search/SearchCapabilityAdapterTests.swift
- kAirTests/Networking/ServerProviderEnvelopeFactoryTests.swift only if existing
  factory coverage needs a small Search-specific assertion
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer tests first.
- Add a value-only method or helper on `SearchCapabilityAdapter` that accepts a
  `SearchIntent` or `SearchProviderDecision` and returns a
  `ServerProviderDryRunReport`.
- The helper may call `decision(for:)`,
  `ServerProviderEnvelopeFactory.makeEnvelope(decision:quotaSnapshot:)`, and
  `ServerProviderDryRunEvaluator.evaluate(...)`; it must not call
  `resolve(_:)`, adapter registry dispatch, runtime pipeline, transport,
  crawler, MCP, telemetry, navigation, or transcript mutation.
- Use `configuration.providerQuotaSnapshot` as the only quota source.
- Preserve local/default behavior: default Search config produces blocked or
  local/cache advisory results, not remote execution.
- Preserve explicit quota behavior: a Search-entitled profile still needs quota
  allowance and metered eligibility before the dry-run report can select a
  Search API envelope.

Acceptance:
- Tests prove default Search dry-run preview is advisory-only and cannot select
  a remote Search provider from profile membership alone.
- Tests prove a profile-entitled Search decision remains cost/quota-blocked
  until `providerQuotaSnapshot` allows `.searchAPI` and marks it metered
  eligible.
- Tests prove an explicit Search quota snapshot can produce a selected dry-run
  Search envelope, with source/freshness/cost metadata preserved.
- Tests prove the helper never calls `resolve(_:)`, transport, runtime pipeline,
  crawler/MCP runtime, telemetry, navigation, or transcript mutation.
- Static scan confirms no network/provider runtime call, SDK import, API
  credential field, StoreKit purchase, crawler runtime, MCP client runtime,
  prompt submission, navigation route, transcript write, telemetry emit, or UI
  layout change.
- `git diff --check` passes.
```

Status after review: implemented and verified in `SearchCapabilityAdapterTests`.
Search dry-run preview now accepts either a `SearchIntent` or a precomputed
`SearchProviderDecision` plus request, builds an envelope factory result using
`configuration.providerQuotaSnapshot`, and returns an advisory
`ServerProviderDryRunReport` through `ServerProviderDryRunEvaluator`. It does
not call `resolve(_:)` or any provider runtime.

## Round A49 - Search Dry-Run Presentation Projection

```text
Task: Project Search dry-run reports into UI-safe advisory presentation copy
using the existing `ServerProviderDryRunPresentationProjector`. This is a
presentation-value layer only; do not render UI, call Search resolve, call
network transport, run crawler/MCP, execute provider runtime, or emit telemetry.

Allowed files:
- kAir/Features/Search/Data/SearchCapabilityAdapter.swift
- kAirTests/Search/SearchCapabilityAdapterTests.swift
- kAirTests/Networking/ServerProviderDryRunPresentationTests.swift only if
  existing projector copy needs one small Search-specific lock
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer tests first.
- Add a value-only helper on `SearchCapabilityAdapter` that projects
  `dryRunPreview(...)` through `ServerProviderDryRunPresentationProjector`.
- The helper may accept `SearchIntent` or a precomputed dry-run report.
- Preserve advisory-only copy. The presentation must not say Search was called,
  completed, booked, ordered, paid, crawled, or contacted a provider.
- Preserve selected and blocked metadata: provider family, cost class,
  freshness, source host/policy, and factory rejection reason.
- Do not bind this to Chat UI or recommendation cards in this round.

Acceptance:
- Tests prove selected Search dry-run preview produces presentation rows for
  selected provider, cost, freshness, and source policy.
- Tests prove blocked Search dry-run preview produces advisory blocked copy with
  the factory rejection reason preserved.
- Tests prove presentation copy stays advisory-only and does not contain
  execution/completion/provider-contact wording.
- Static scan confirms no transport/network/provider runtime call, SDK import,
  API credential field, StoreKit purchase, crawler runtime, MCP client runtime,
  prompt submission, navigation route, transcript write, telemetry emit,
  `resolve(_:)` call, or UI layout change.
- `git diff --check` passes.
```

Status after review: implemented and verified in `SearchCapabilityAdapterTests`.
Search dry-run presentation projection now accepts either a `SearchIntent` or a
precomputed `ServerProviderDryRunReport`, projects through
`ServerProviderDryRunPresentationProjector`, preserves selected/blocked
provider metadata, and keeps copy advisory-only without calling `resolve(_:)` or
binding UI.

## Round A50 - Search Dry-Run Provider Status Source

```text
Task: Bridge precomputed Search dry-run presentations into the existing
`ProviderStatusProviding` side channel by recommendation id. This is a value
projection/source layer only; do not render UI, wire ChatStore/AppBootstrap,
call Search resolve, call transport, run crawler/MCP, execute provider runtime,
or emit telemetry.

Allowed files:
- kAir/DesignSystem/Components/ProviderStatusBadgeModel.swift
- kAir/Features/Search/Data/SearchCapabilityAdapter.swift only if the helper
  belongs next to Search dry-run presentation
- kAirTests/DesignSystem/ProviderStatusBadgeModelTests.swift
- kAirTests/Search/SearchCapabilityAdapterTests.swift only if Search-owned helper
  coverage is needed
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer tests first.
- Add a small value/source type that maps recommendation id to a precomputed
  `ServerProviderDryRunPresentation` or Search dry-run presentation payload.
- Expose it through `ProviderStatusProviding` so existing provider-status lookup
  and multiplexer seams can consume it later.
- Preserve selected and blocked metadata in `ProviderStatusPresentation`: remote
  provider badge, cost badge, source/freshness/status line where available, and
  warning/disabled hints for blocked candidates.
- Keep copy advisory-only. It may say "dry run" and "no provider was contacted";
  it must not claim Search was executed, completed, booked, ordered, paid,
  crawled, or that a provider was contacted.
- Do not mutate `MatchingObject`, recommendation card kinds, ChatStore, or UI
  layout in this round.

Acceptance:
- Tests prove selected Search dry-run presentation maps to
  `ProviderStatusPresentation` with provider, cost, and advisory status line.
- Tests prove blocked Search dry-run presentation preserves factory rejection
  reason in warning/disabled status copy.
- Tests prove missing recommendation ids return nil and source lookup is
  deterministic.
- Tests prove copy remains advisory-only and does not claim execution.
- Static scan confirms no transport/network/provider runtime call, SDK import,
  API credential field, StoreKit purchase, crawler runtime, MCP client runtime,
  prompt submission, navigation route, transcript write, telemetry emit,
  `resolve(_:)` call, Chat UI binding, or layout change.
- `git diff --check` passes.
```

Status after review: implemented and verified in `ProviderStatusBadgeModelTests`.
Precomputed Search dry-run presentations now have a dedicated
`ProviderStatusProviding` source keyed by recommendation id. Lookup is nil on
miss, sorted for inspection, first-entry deterministic for duplicate tuple input,
and reuses the existing dry-run resolver so selected/blocked provider, cost,
freshness, source, and rejection metadata remain intact without executing Search
or binding UI.

## Round A51 - App-Root Search Dry-Run Status Composition

```text
Task: Prove app-root callers can install a precomputed
`SearchDryRunProviderStatusStore` through the existing
`AppBootstrap.providerStatusSources` composition path. This is composition
verification only; do not make AppBootstrap, ChatStore, ChatHomeView, or any view
generate Search dry-runs or execute Search.

Allowed files:
- kAirTests/AppBootstrapTests.swift
- kAirTests/ChatStoreCapabilityConsumerTests.swift only if a ChatStore rendered-id
  filter assertion is missing
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer tests first.
- Build a precomputed `SearchDryRunProviderStatusStore` in tests with one selected
  Search dry-run presentation and one blocked Search dry-run presentation.
- Pass that store through `AppBootstrap(providerStatusSources:)` or the existing
  app-root status-source composition API.
- Assert the composed provider-status source returns Search dry-run status for the
  supplied recommendation ids and still returns nil for missing ids.
- If ChatStore coverage is needed, assert status is visible only for ids currently
  present in `recommendedMatches`; do not generate dry-runs inside ChatStore.
- Preserve source-order behavior when combined with an existing fixed/runtime
  provider-status source.

Acceptance:
- Tests prove AppBootstrap preserves and composes the precomputed
  `SearchDryRunProviderStatusStore` through `providerStatusSources`.
- Tests prove selected and blocked Search dry-run status can be looked up through
  the app-root composed source by recommendation id.
- Tests prove missing/non-rendered ids remain nil at the relevant seam.
- Tests prove no Search adapter `resolve`, transport, crawler/MCP, provider
  runtime pipeline, telemetry, transcript mutation, navigation, or UI layout code
  is introduced.
- Static scan confirms no network/provider runtime call, SDK import, API key,
  StoreKit purchase, prompt submission, Chat UI binding, or layout change.
- `git diff --check` passes.
```

Status after review: implemented and verified in `AppBootstrapTests`.
App-root callers can now pass a precomputed `SearchDryRunProviderStatusStore`
through `AppBootstrap(providerStatusSources:)`; selected and blocked Search
dry-run statuses are available by recommendation id, source order stays
first-source-wins, missing ids stay nil, and ChatStore only surfaces status for
currently rendered recommendation ids. AppBootstrap, ChatStore, ChatHomeView, and
views still do not generate dry-runs or execute Search.

## Round A52 - Search Dry-Run Status Source Builder

```text
Task: Add a Search adapter-owned value helper that packages Search dry-run
presentation/report output into a `SearchDryRunProviderStatusStore` for a
caller-supplied recommendation id. This is a value packaging layer only; do not
wire AppBootstrap, ChatStore, ChatHomeView, or UI, and do not call Search
`resolve(_:)`, transport, crawler/MCP, provider runtime, telemetry, navigation,
or transcript mutation.

Allowed files:
- kAir/Features/Search/Data/SearchCapabilityAdapter.swift
- kAirTests/Search/SearchCapabilityAdapterTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer tests first.
- Add a value-only helper on `SearchCapabilityAdapter`, for example
  `dryRunProviderStatusSource(forRecommendationID:intent:capabilityLabel:)`, that
  uses the existing dry-run preview/presentation path and returns a
  `SearchDryRunProviderStatusStore`.
- Add a second overload for callers that already have a
  `ServerProviderDryRunReport` or `ServerProviderDryRunPresentation`, so batch or
  app-root composition code does not have to duplicate projection steps.
- The helper must require the recommendation id explicitly; do not infer or
  mutate `MatchingObject` ids.
- Preserve selected and blocked metadata in the resulting
  `ProviderStatusPresentation`: provider badge, cost badge, freshness/source
  status, warning/disabled hint, and factory rejection reason.

Acceptance:
- Tests prove a selected Search intent can produce a status source whose lookup by
  the supplied recommendation id returns Search dry-run provider/cost/source
  status.
- Tests prove blocked Search dry-run input preserves factory rejection copy and a
  disabled hint in the returned source.
- Tests prove missing ids return nil and the helper does not mutate or require a
  `MatchingObject`.
- Tests prove copy remains advisory-only and does not claim execution, provider
  contact, booking, ordering, payment, crawling, or completion.
- Static scan confirms no network/provider runtime call, SDK import, API key,
  StoreKit purchase, prompt submission, AppBootstrap/ChatStore/UI binding,
  telemetry, navigation, transport, crawler/MCP runtime, `resolve(_:)`, or layout
  change.
- `git diff --check` passes.
```

Status after review: implemented and verified in `SearchCapabilityAdapterTests`.
`SearchCapabilityAdapter` now owns value helpers that package a Search dry-run
intent, report, or presentation into `SearchDryRunProviderStatusStore` for an
explicit recommendation id. The source preserves selected/blocked metadata,
returns nil for missing ids, keeps copy advisory-only, and does not require or
mutate `MatchingObject`.

## Round A53 - Batch Search Dry-Run Status Source Builder

```text
Task: Add a batch value helper for callers that already have multiple
recommendation ids and Search dry-run presentations. It should produce one
deterministic `SearchDryRunProviderStatusStore` without wiring AppBootstrap,
ChatStore, ChatHomeView, UI, Search execution, transport, crawler/MCP, provider
runtime, telemetry, navigation, or transcript mutation.

Allowed files:
- kAir/Features/Search/Data/SearchCapabilityAdapter.swift
- kAirTests/Search/SearchCapabilityAdapterTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer tests first.
- Add a value-only helper on `SearchCapabilityAdapter`, for example
  `dryRunProviderStatusSource(presentations:)`, where each entry pairs an
  explicit recommendation id with a precomputed `ServerProviderDryRunPresentation`.
- If useful, add an overload that accepts explicit recommendation id plus
  `ServerProviderDryRunReport` and projects each report through the existing
  dry-run presentation path.
- Keep duplicate recommendation id behavior deterministic and aligned with
  `SearchDryRunProviderStatusStore` tuple init: first entry wins.
- Do not infer ids from query strings, provider traces, or `MatchingObject`.

Acceptance:
- Tests prove two selected/blocked Search dry-run presentations can be packaged
  into one source and looked up by their supplied recommendation ids.
- Tests prove duplicate recommendation ids keep the first presentation.
- Tests prove missing ids return nil and `recommendationIDs` are sorted.
- Tests prove copy remains advisory-only and does not claim execution, provider
  contact, booking, ordering, payment, crawling, or completion.
- Static scan confirms no network/provider runtime call, SDK import, API key,
  StoreKit purchase, prompt submission, AppBootstrap/ChatStore/UI binding,
  telemetry, navigation, transport, crawler/MCP runtime, `resolve(_:)`, or layout
  change.
- `git diff --check` passes.
```

Status after review: implemented and verified in `SearchCapabilityAdapterTests`.
`SearchCapabilityAdapter` now exposes batch value helpers for precomputed Search
dry-run presentations and reports. The resulting `SearchDryRunProviderStatusStore`
preserves caller-supplied ids, sorted lookup, missing-id nil behavior, first-entry
duplicates, and advisory-only copy without AppBootstrap, ChatStore, UI, transport,
crawler/MCP, provider runtime, telemetry, navigation, transcript mutation, or
Search execution.

## Round A54 - Search Status Source Handoff Contract

```text
Task: Document the handoff contract for adapter-generated Search dry-run status
sources before any app-root, recommendation-source, or UI wiring change. This is
documentation/comment contract only; do not add runtime behavior, UI binding,
AppBootstrap/ChatStore generation, transport, crawler/MCP, provider runtime,
telemetry, navigation, transcript mutation, or tests that require a new behavior
surface.

Allowed files:
- Contracts/search-capability-contract-v1.md
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add a section naming `SearchCapabilityAdapter.dryRunProviderStatusSource(...)`
  as a value-packaging seam for precomputed Search dry-run status.
- Document that recommendation ids are caller-owned and must be supplied by the
  recommendation/search composition layer or tests.
- Document allowed producers: recommendation/search composition code that already
  has explicit rendered recommendation ids and precomputed dry-run reports or
  presentations.
- Document forbidden producers: AppBootstrap, ChatStore, ChatHomeView, SwiftUI
  views, provider runtime adapters, transport, crawler/MCP adapters, telemetry,
  and prompt/model execution paths.
- Document that consumers receive only `ProviderStatusProviding` or
  `SearchDryRunProviderStatusStore`; they must not call Search dry-run helpers
  while rendering.
- Preserve the local/default iOS path and make no real execution claims.

Acceptance:
- Docs state app/view layers consume Search dry-run status but never generate it.
- Docs state ids must not be inferred from query strings, provider traces,
  `MatchingObject` mutation, transcript content, or model output.
- Docs state Search/crawler/MCP/runtime provider work remains blocked until
  explicit transport, security, policy, entitlement, and product gates.
- Static scan confirms no prompt asks for runtime/UI/network/telemetry changes.
- `git diff --check` passes.
```

Status after review: implemented and verified as documentation-only. The Search
contract now names `SearchCapabilityAdapter.dryRunProviderStatusSource(...)` as a
value-packaging seam, keeps recommendation ids caller-owned, allows only
recommendation/search composition code or tests to produce stores, forbids
AppBootstrap, ChatStore, ChatHomeView, SwiftUI, provider runtime, transport,
crawler/MCP, telemetry, and prompt paths from generating dry-runs, and preserves
the rule that app/root/view layers consume only `ProviderStatusProviding` or a
precomputed `SearchDryRunProviderStatusStore`.

## Round A55 - Search Status Source Producer Skeleton

```text
Task: Add a value-only Search dry-run status source producer skeleton for the
recommendation/search composition layer. This should encode the A54 handoff as a
testable pure type: callers provide explicit recommendation ids plus precomputed
Search dry-run reports or presentations, and the producer returns a
`SearchDryRunProviderStatusStore`. Do not wire AppBootstrap, ChatStore,
ChatHomeView, SwiftUI, navigation, telemetry, transcript mutation, transport,
crawler/MCP, provider runtime, real Search execution, SDKs, API keys, or network.

Allowed files:
- kAir/Features/Search/Data/SearchDryRunStatusSourceProducer.swift
- kAirTests/Search/SearchDryRunStatusSourceProducerTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer tests first.
- Add a small pure producer type in the Search feature data layer. It may hold a
  `SearchCapabilityAdapter` or accept one in a method, but it must call only the
  existing dry-run presentation/source helpers.
- Define named input entries if useful, but each entry must carry an explicit
  `recommendationID`; do not accept `MatchingObject` as the id source.
- Support precomputed presentations and precomputed reports.
- Preserve `SearchDryRunProviderStatusStore` behavior: first duplicate id wins,
  `recommendationIDs` are sorted, missing ids return nil, and copy is advisory.

Acceptance:
- Tests prove the producer packages selected and blocked report inputs by their
  supplied recommendation ids.
- Tests prove presentation inputs do not require `MatchingObject` and do not
  mutate projected/recommendation objects.
- Tests prove duplicate ids keep the first input and missing ids return nil.
- Tests prove the producer does not call `resolve(_:)`, AppBootstrap, ChatStore,
  ChatHomeView, SwiftUI, transport, crawler/MCP, provider runtime, telemetry,
  navigation, transcript mutation, SDKs, API keys, or network.
- Static scan confirms the new file is pure Foundation/value code only.
- Targeted Search tests pass, and `git diff --check` passes.
```

Status after review: implemented and verified in
`SearchDryRunStatusSourceProducerTests`. The producer is a pure Search data-layer
value seam that packages caller-supplied recommendation ids with precomputed
Search dry-run reports or presentations into `SearchDryRunProviderStatusStore`.
The tests use a disabled packaging adapter to prove the producer does not depend
on Search availability, app/root/view generation, runtime execution, or
`MatchingObject` ids.

## Round A56 - Producer Source App-Root Handoff Proof

```text
Task: Prove a producer-built `SearchDryRunProviderStatusStore` can pass through
the existing app-root `providerStatusSources` path and be consumed by ChatStore
for rendered recommendation ids. This is a composition test only; do not make
AppBootstrap, ChatStore, ChatHomeView, SwiftUI views, navigation, telemetry,
transcript mutation, transport, crawler/MCP, provider runtime, real Search
execution, SDKs, API keys, or network instantiate the producer or generate
dry-runs.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer tests first.
- In the test, build Search dry-run reports/presentations and a
  `SearchDryRunProviderStatusStore` with `SearchDryRunStatusSourceProducer`
  outside `AppBootstrap`.
- Pass that precomputed store through `AppBootstrap(providerStatusSources:)`.
- Compose ChatStore through the existing bootstrap/composition path.
- Assert ChatStore provider-status lookup returns status only for rendered
  recommendation ids and returns nil for missing ids.

Acceptance:
- Tests prove AppBootstrap stores/forwards a producer-built Search dry-run source
  without constructing the producer itself.
- Tests prove ChatStore consumes the resulting `ProviderStatusProviding` source
  only by rendered recommendation id.
- Tests prove selected/blocked status survives the app-root handoff and missing
  ids return nil.
- Static scan confirms no production AppBootstrap/ChatStore/ChatHomeView/SwiftUI
  changes and no Search execution, transport, crawler/MCP, provider runtime,
  telemetry, navigation, transcript mutation, SDK, API key, or network call.
- Targeted AppBootstrap tests pass, full iOS tests pass, and `git diff --check`
  passes.
```

Status after review: implemented and verified in `AppBootstrapTests`. The test
builds a `SearchDryRunProviderStatusStore` with
`SearchDryRunStatusSourceProducer` outside `AppBootstrap`, passes that precomputed
source through `AppBootstrap(providerStatusSources:)`, mirrors
`ChatHomeView.init(bootstrap:)`, and proves ChatStore returns selected/blocked
Search dry-run status for rendered ids while hidden and missing ids return nil.

## Round A57 - Rendered Search Status Source Guard

```text
Task: Add a value-only rendered-id guard source for producer-built Search dry-run
status. It should wrap a precomputed `SearchDryRunProviderStatusStore` and expose
`ProviderStatusProviding` only for explicit rendered recommendation ids supplied
by the recommendation/search composition layer. Do not wire AppBootstrap,
ChatStore, ChatHomeView, SwiftUI, navigation, telemetry, transcript mutation,
transport, crawler/MCP, provider runtime, real Search execution, SDKs, API keys,
or network.

Allowed files:
- kAir/Features/Search/Data/SearchRenderedDryRunStatusSource.swift
- kAirTests/Search/SearchRenderedDryRunStatusSourceTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer tests first.
- Add a small pure type that conforms to `ProviderStatusProviding`.
- Inputs must be explicit rendered recommendation ids plus a precomputed
  `SearchDryRunProviderStatusStore`.
- Return nil for ids not in the rendered-id set even if the wrapped store has
  status for them.
- Keep duplicate rendered ids deterministic and expose a sorted or stable
  `renderedRecommendationIDs` diagnostic if useful.
- Do not accept `MatchingObject`, query strings, provider traces, transcript
  content, or model output as the id source.

Acceptance:
- Tests prove rendered selected/blocked ids return status from the wrapped
  producer-built source.
- Tests prove hidden ids in the wrapped store return nil when not in the rendered
  id set.
- Tests prove missing ids return nil and duplicate rendered ids are deterministic.
- Tests prove the wrapper does not mutate `MatchingObject` or call Search
  `resolve(_:)`.
- Static scan confirms the new file is pure Foundation/value code only and has
  no AppBootstrap/ChatStore/ChatHomeView/SwiftUI/transport/crawler/MCP/provider
  runtime/telemetry/navigation/transcript/API-key/network references.
- Targeted Search tests pass, full iOS tests pass, and `git diff --check` passes.
```

Status after review: implemented and verified in
`SearchRenderedDryRunStatusSourceTests`. The guard conforms to
`ProviderStatusProviding`, stores only explicit rendered recommendation ids, and
delegates to a precomputed `SearchDryRunProviderStatusStore` only when the queried
id is rendered. Hidden ids in the wrapped store return nil before app-root
injection.

## Round A58 - Guarded Source App-Root Handoff Proof

```text
Task: Prove a guarded producer-built Search dry-run source can pass through the
existing app-root `providerStatusSources` path and remain hidden-id safe before
and after ChatStore composition. This is a composition test only; do not make
AppBootstrap, ChatStore, ChatHomeView, SwiftUI views, navigation, telemetry,
transcript mutation, transport, crawler/MCP, provider runtime, real Search
execution, SDKs, API keys, or network instantiate the producer/guard or generate
dry-runs.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer tests first.
- In the test, build a producer-built `SearchDryRunProviderStatusStore` outside
  `AppBootstrap`.
- Wrap it with `SearchRenderedDryRunStatusSource` outside `AppBootstrap`, using
  explicit rendered recommendation ids.
- Pass the guarded source through `AppBootstrap(providerStatusSources:)`.
- Compose ChatStore through the existing bootstrap/composition path.
- Assert selected/blocked rendered ids return status at both bootstrap-source and
  ChatStore lookup points.
- Assert hidden wrapped-store ids return nil at both bootstrap-source and
  ChatStore lookup points.

Acceptance:
- Tests prove AppBootstrap stores/forwards the guarded source without
  constructing the producer or guard itself.
- Tests prove selected/blocked status survives the guarded app-root handoff.
- Tests prove hidden ids in the wrapped store return nil before and after
  ChatStore composition.
- Static scan confirms no production AppBootstrap/ChatStore/ChatHomeView/SwiftUI
  changes and no Search execution, transport, crawler/MCP, provider runtime,
  telemetry, navigation, transcript mutation, SDK, API key, or network call.
- Targeted AppBootstrap tests pass, full iOS tests pass, and `git diff --check`
  passes.
```

Status after review: implemented and verified in `AppBootstrapTests`.
The test builds a producer-backed Search dry-run source and wraps it with
`SearchRenderedDryRunStatusSource` outside `AppBootstrap`, then passes only the
guarded source through `providerStatusSources`. Selected and blocked rendered ids
return status from both the bootstrap provider and ChatStore; the hidden
wrapped-store id returns nil at both points.

## Round A59 - Runtime Adapter Injection Set

```text
Task: Add a value-only runtime adapter injection set so future real provider
adapters can be installed by server/composition code without changing the
default fixture-only runtime path. This is an interface reservation only; do not
add URLSession, endpoints, provider SDKs, credentials, Google/Gaode clients,
crawler runtime, MCP client runtime, AppBootstrap wiring, ChatStore wiring,
SwiftUI/UI changes, navigation, telemetry, transcript mutation, booking/order,
payment, StoreKit, or real provider execution.

Allowed files:
- kAir/Core/Networking/ServerProviderRuntimeAdapterRegistry.swift
- kAirTests/Networking/ServerProviderRuntimeAdapterRegistryTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer tests first.
- Introduce a small value type such as `ServerProviderRuntimeAdapterSet` that
  accepts caller-supplied `ServerProviderRuntimeAdapter` instances and resolves a
  `ServerProviderRuntimeDispatchBoundary` through the adapter matching the
  boundary provider family.
- Preserve `ServerProviderRuntimeAdapterRegistry.resolve(_:)` as the existing
  default fixture-only path.
- Make duplicate adapter-family behavior deterministic, preferably first adapter
  wins.
- Preserve non-prepared boundary behavior: local-only, blocked,
  confirmation-required, descriptor-unavailable, and plan-rejected boundaries
  must not select a real/injected adapter.

Acceptance:
- Tests prove an explicit injected Search adapter can resolve a prepared Search
  boundary without using the static default registry.
- Tests prove missing/unregistered injected provider families return a
  non-executing rejected result.
- Tests prove duplicate injected adapter families are deterministic.
- Tests prove non-prepared boundaries preserve their existing states and do not
  select injected adapters.
- Static scan confirms no URLSession, endpoint, SDK, credential, crawler/MCP
  runtime, AppBootstrap, ChatStore, SwiftUI/UI, navigation, telemetry,
  transcript, payment, StoreKit, or provider execution is introduced.
- Targeted runtime-adapter registry tests pass, full iOS tests pass, and
  `git diff --check` passes.
```

Status after review: implemented and verified in
`ServerProviderRuntimeAdapterRegistryTests`. The new
`ServerProviderRuntimeAdapterSet` stores caller-supplied adapters by provider
family with deterministic first-adapter-wins behavior. It resolves prepared
boundaries through injected adapters, rejects missing injected families, and
preserves existing non-prepared boundary states without selecting injected
adapters. The static `ServerProviderRuntimeAdapterRegistry.resolve(_:)` remains
the default fixture-only path.

## Round A60 - Runtime Pipeline Adapter Set Handoff Proof

```text
Task: Prove the value-only runtime pipeline can consume an explicit
`ServerProviderRuntimeAdapterSet` while preserving the existing default
fixture-only pipeline path. This is an interface handoff proof only; do not add
URLSession, endpoints, provider SDKs, credentials, Google/Gaode clients, crawler
runtime, MCP client runtime, AppBootstrap wiring, ChatStore wiring, SwiftUI/UI
changes, navigation, telemetry, transcript mutation, booking/order, payment,
StoreKit, or real provider execution.

Allowed files:
- kAir/Core/Networking/ServerProviderRuntimePipeline.swift
- kAirTests/Networking/ServerProviderRuntimePipelineTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer tests first.
- Add a small overload or parameter path that lets callers pass a
  `ServerProviderRuntimeAdapterSet` into `ServerProviderRuntimePipeline.run`.
- Preserve the current overloads and their fixture-only behavior unchanged.
- The injected-adapter path should prepare the invocation plan, resolve through
  the supplied adapter set, and project the existing receipt shape.
- Do not make the pipeline construct real adapters, load SDKs, call transport, or
  read app/UI state.

Acceptance:
- Tests prove a prepared Search readiness/lookup can produce a receipt through
  an injected Search adapter set.
- Tests prove the default pipeline path still uses the static fixture registry
  and does not observe injected adapter markers.
- Tests prove local-only, blocked, confirmation-required, descriptor-unavailable,
  and plan-rejected paths preserve their existing receipt states through the
  injected-adapter pipeline path.
- Static scan confirms no URLSession, endpoint, SDK, credential, crawler/MCP
  runtime, AppBootstrap, ChatStore, SwiftUI/UI, navigation, telemetry,
  transcript, payment, StoreKit, or provider execution is introduced.
- Targeted runtime-pipeline tests pass, full iOS tests pass, and
  `git diff --check` passes.
```

Status after review: implemented and verified in
`ServerProviderRuntimePipelineTests`. New adapter-set overloads let callers pass
`ServerProviderRuntimeAdapterSet` into the value-only pipeline. The default
overloads still use the static fixture registry. Tests prove injected prepared
Search receipts, default-path isolation from injected markers, and unchanged
non-prepared receipt states.

## Round A61 - Injected Pipeline Receipt Status Source Proof

```text
Task: Prove receipts produced through the A60 injected-adapter pipeline path can
feed the existing provider-status side channel by explicit recommendation id.
This is a status-source proof only; do not add URLSession, endpoints, provider
SDKs, credentials, Google/Gaode clients, crawler runtime, MCP client runtime,
AppBootstrap wiring, ChatStore wiring, SwiftUI/UI changes, navigation,
telemetry, transcript mutation, booking/order, payment, StoreKit, or real
provider execution.

Allowed files:
- kAirTests/DesignSystem/ProviderStatusBadgeModelTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer tests first.
- In the test, build a prepared Search receipt through
  `ServerProviderRuntimePipeline.run(..., adapterSet:)`.
- Install that receipt in `RuntimeReceiptProviderStatusStore` with an explicit
  recommendation id.
- Assert the status store returns a provider-status presentation for the
  explicit recommendation id and nil for missing ids.
- If useful, compose it through `ProviderStatusSourceMultiplexer` to prove
  existing source-order behavior still works with injected-pipeline receipts.
- Do not make AppBootstrap, ChatStore, ChatHomeView, SwiftUI, or any runtime
  layer generate receipts.

Acceptance:
- Tests prove injected-pipeline receipts feed `RuntimeReceiptProviderStatusStore`
  by explicit recommendation id.
- Tests prove missing ids return nil and source-order behavior remains
  deterministic when composed with another provider-status source.
- Tests prove copy remains advisory and does not claim provider contact,
  completion, booking, ordering, payment, crawling, or execution.
- Static scan confirms no URLSession, endpoint, SDK, credential, crawler/MCP
  runtime, AppBootstrap, ChatStore, SwiftUI/UI, navigation, telemetry,
  transcript, payment, StoreKit, or provider execution is introduced.
- Targeted provider-status model tests pass, full iOS tests pass, and
  `git diff --check` passes.
```

Status after review: implemented and verified in
`ProviderStatusBadgeModelTests`. Tests build Search receipts through
`ServerProviderRuntimePipeline.run(..., adapterSet:)`, install them in
`RuntimeReceiptProviderStatusStore` under explicit recommendation ids, compose
them through `ProviderStatusSourceMultiplexer`, and lock advisory copy that does
not claim provider contact, completion, booking, ordering, payment, crawling, or
execution.

## Round A62 - Runtime Pipeline Status Source Producer Skeleton

```text
Task: Add a value-only runtime pipeline status source producer skeleton. The
producer must package caller-supplied explicit recommendation ids with either
precomputed `ServerProviderRuntimeReceipt` values or receipts generated through
`ServerProviderRuntimePipeline.run(..., adapterSet:)`, returning
`RuntimeReceiptProviderStatusStore`. This is a composition seam only; do not add
URLSession, endpoints, provider SDKs, credentials, Google/Gaode clients, crawler
runtime, MCP client runtime, AppBootstrap wiring, ChatStore wiring, SwiftUI/UI
changes, navigation, telemetry, transcript mutation, booking/order, payment,
StoreKit, or real provider execution.

Allowed files:
- kAir/Core/Networking/ServerProviderRuntimeStatusSourceProducer.swift
- kAirTests/Networking/ServerProviderRuntimeStatusSourceProducerTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer tests first.
- Introduce a small value-only producer type, for example
  `ServerProviderRuntimeStatusSourceProducer`, in Core/Networking.
- The producer may expose one helper that packages precomputed
  `(recommendationID, receipt)` pairs into `RuntimeReceiptProviderStatusStore`.
- The producer may expose one helper that accepts explicit recommendation ids
  plus readiness decisions and an explicit `ServerProviderRuntimeAdapterSet`,
  runs the existing injected pipeline, and returns a
  `RuntimeReceiptProviderStatusStore`.
- Preserve caller-owned recommendation ids. Do not infer ids from
  `MatchingObject`, ChatStore, views, transcript entries, or route state.
- Preserve first-entry-wins duplicate behavior by delegating storage to
  `RuntimeReceiptProviderStatusStore`.
- Do not add AppBootstrap, ChatStore, ChatHomeView, SwiftUI, or provider runtime
  wiring.

Acceptance:
- Tests prove the producer packages precomputed receipts into
  `RuntimeReceiptProviderStatusStore` by explicit recommendation id.
- Tests prove the producer can build a store from an injected Search pipeline
  receipt and that the injected adapter marker reaches the stored receipt's
  provider-status presentation path.
- Tests prove sorted ids, missing-id nil lookup, and first-entry duplicate
  behavior remain deterministic.
- Tests prove copy remains advisory and does not claim provider contact,
  completion, booking, ordering, payment, crawling, or execution.
- Static scan confirms no URLSession, endpoint, SDK, credential, crawler/MCP
  runtime, AppBootstrap, ChatStore, SwiftUI/UI, navigation, telemetry,
  transcript, payment, StoreKit, or provider execution is introduced.
- Targeted runtime status-source producer tests pass, full iOS tests pass, and
  `git diff --check` passes.
```

Status after review: implemented and verified in
`ServerProviderRuntimeStatusSourceProducerTests`.
`ServerProviderRuntimeStatusSourceProducer` packages explicit recommendation ids
with precomputed receipts or injected-pipeline receipts into
`RuntimeReceiptProviderStatusStore`. Tests prove sorted ids, missing-id nil
lookup, first-entry duplicate behavior, injected adapter metadata reaching
provider-status presentation, and advisory non-executing copy.

## Round A63 - Runtime Producer Source App-Root Handoff Proof

```text
Task: Prove a producer-built `RuntimeReceiptProviderStatusStore` can pass through
the existing app-root `providerStatusSources` path and be consumed by ChatStore
for rendered recommendation ids. This is a handoff proof only; do not add
URLSession, endpoints, provider SDKs, credentials, Google/Gaode clients, crawler
runtime, MCP client runtime, SwiftUI/UI changes, navigation, telemetry,
transcript mutation beyond existing ChatStore test harness expectations,
booking/order, payment, StoreKit, or real provider execution.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer tests first.
- Build a `RuntimeReceiptProviderStatusStore` outside `AppBootstrap` using
  `ServerProviderRuntimeStatusSourceProducer`.
- Pass that store through `AppBootstrap(providerStatusSources:)`.
- Construct ChatStore through the existing composition-root path used by
  `ChatHomeView.init(bootstrap:)` tests.
- Assert ChatStore returns the producer-built runtime provider status for a
  rendered recommendation id and nil for a hidden producer-store id that is not
  currently rendered.
- Assert source order remains deterministic if another provider-status source is
  present.
- Do not make AppBootstrap, ChatStore, ChatHomeView, SwiftUI, or any view layer
  instantiate the producer or generate runtime receipts.

Acceptance:
- Tests prove a producer-built runtime status source passes through
  `AppBootstrap(providerStatusSources:)`.
- Tests prove ChatStore consumes the producer-built status only for rendered
  recommendation ids and returns nil for hidden/non-rendered ids.
- Tests prove source-order behavior remains deterministic when composed with
  another provider-status source.
- Tests prove copy remains advisory and does not claim provider contact,
  completion, booking, ordering, payment, crawling, or execution.
- Static scan confirms no URLSession, endpoint, SDK, credential, crawler/MCP
  runtime, SwiftUI/UI changes, navigation, telemetry, payment, StoreKit, or real
  provider execution is introduced.
- Targeted AppBootstrap tests pass, full iOS tests pass, and
  `git diff --check` passes.
```

Status after review: implemented and verified in `AppBootstrapTests`.
Tests build `RuntimeReceiptProviderStatusStore` outside `AppBootstrap` through
`ServerProviderRuntimeStatusSourceProducer`, pass it through
`AppBootstrap(providerStatusSources:)`, construct ChatStore through the same
composition-root path used by `ChatHomeView.init(bootstrap:)`, and prove rendered
ids receive producer-built runtime status while hidden ids return nil. Source
order remains first-source-wins and copy remains advisory/non-executing.

## Round A64 - Rendered Runtime Status Source Guard

```text
Task: Add a value-only rendered-id guard source for producer-built runtime
status. The guard should wrap an existing `RuntimeReceiptProviderStatusStore`
or any `ProviderStatusProviding` source and expose status only for an explicit
set of rendered recommendation ids before app-root injection. This is a
composition guard only; do not add URLSession, endpoints, provider SDKs,
credentials, Google/Gaode clients, crawler runtime, MCP client runtime,
AppBootstrap wiring, ChatStore wiring, SwiftUI/UI changes, navigation,
telemetry, transcript mutation, booking/order, payment, StoreKit, or real
provider execution.

Allowed files:
- kAir/Core/Networking/ServerProviderRenderedRuntimeStatusSource.swift
- kAirTests/Networking/ServerProviderRenderedRuntimeStatusSourceTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer tests first.
- Model the source after the Search rendered dry-run guard pattern, but keep it
  in Core/Networking because runtime receipts are provider/runtime-level values.
- The source should store a wrapped `ProviderStatusProviding` source plus a
  deterministic set of rendered recommendation ids.
- `providerStatusPresentation(for:)` must return wrapped status only when the id
  is explicitly rendered; hidden wrapped-store ids must return nil.
- Preserve duplicate rendered-id determinism and sorted rendered-id inspection.
- Do not infer ids from `MatchingObject`, ChatStore, views, transcript entries,
  route state, or receipt ids.
- Do not add app/root/view wiring.

Acceptance:
- Tests prove rendered ids return wrapped producer-built runtime status.
- Tests prove hidden wrapped-store ids and missing ids return nil.
- Tests prove duplicate rendered ids are deterministic and exposed ids are
  sorted.
- Tests prove the wrapper does not mutate `MatchingObject`, infer fixture ids, or
  execute provider/runtime work.
- Tests prove copy remains advisory and does not claim provider contact,
  completion, booking, ordering, payment, crawling, or execution.
- Static scan confirms no URLSession, endpoint, SDK, credential, crawler/MCP
  runtime, AppBootstrap, ChatStore, SwiftUI/UI, navigation, telemetry,
  transcript, payment, StoreKit, or provider execution is introduced.
- Targeted rendered runtime status source tests pass, full iOS tests pass, and
  `git diff --check` passes.
```

Status after review: implemented and verified in
`ServerProviderRenderedRuntimeStatusSourceTests`.
`ServerProviderRenderedRuntimeStatusSource` wraps a `ProviderStatusProviding`
source and exposes status only for explicit rendered recommendation ids. Tests
use producer-built runtime stores, prove hidden wrapped-store ids and missing ids
return nil, preserve sorted/duplicate rendered ids, avoid `MatchingObject` id
inference, and lock advisory non-executing copy.

## Round A65 - Guarded Runtime Source App-Root Handoff Proof

```text
Task: Prove a guarded producer-built runtime status source can pass through the
existing app-root `providerStatusSources` path and be consumed by ChatStore for
rendered recommendation ids while hidden wrapped-store ids stay nil before and
after ChatStore composition. This is a handoff proof only; do not add
URLSession, endpoints, provider SDKs, credentials, Google/Gaode clients, crawler
runtime, MCP client runtime, SwiftUI/UI changes, navigation, telemetry,
transcript mutation beyond existing ChatStore test harness expectations,
booking/order, payment, StoreKit, or real provider execution.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer tests first.
- Build a producer-created `RuntimeReceiptProviderStatusStore` outside
  `AppBootstrap`.
- Wrap it in `ServerProviderRenderedRuntimeStatusSource` with explicit rendered
  recommendation ids.
- Pass the guarded source through `AppBootstrap(providerStatusSources:)`.
- Construct ChatStore through the existing composition-root path used by
  `ChatHomeView.init(bootstrap:)` tests.
- Assert the guarded source returns status for rendered ids and nil for hidden
  wrapped-store ids before app-root injection.
- Assert ChatStore returns status for rendered ids and nil for hidden
  wrapped-store ids after composition.
- Assert source order remains deterministic if another provider-status source is
  present.
- Do not make AppBootstrap, ChatStore, ChatHomeView, SwiftUI, or any view layer
  instantiate the producer, create the guard, or generate runtime receipts.

Acceptance:
- Tests prove a guarded producer-built runtime status source passes through
  `AppBootstrap(providerStatusSources:)`.
- Tests prove rendered ids return status and hidden wrapped-store ids return nil
  both before and after ChatStore composition.
- Tests prove source-order behavior remains deterministic when composed with
  another provider-status source.
- Tests prove copy remains advisory and does not claim provider contact,
  completion, booking, ordering, payment, crawling, or execution.
- Static scan confirms no URLSession, endpoint, SDK, credential, crawler/MCP
  runtime, SwiftUI/UI changes, navigation, telemetry, payment, StoreKit, or real
  provider execution is introduced.
- Targeted AppBootstrap tests pass, full iOS tests pass, and
  `git diff --check` passes.
```

Status after review: implemented and verified in `AppBootstrapTests`.
Tests build a producer-created `RuntimeReceiptProviderStatusStore` outside
`AppBootstrap`, wrap it in `ServerProviderRenderedRuntimeStatusSource`, pass the
guarded source through `AppBootstrap(providerStatusSources:)`, and construct
ChatStore through the `ChatHomeView.init(bootstrap:)` path. Rendered ids return
runtime status before and after composition; hidden wrapped-store ids and missing
ids return nil; source order remains first-source-wins; copy remains advisory and
non-executing.

## Round A66 - Real Provider Adapter Readiness Matrix

```text
Task: Add a value-only readiness matrix that says which provider families are
eligible to graduate from fixture adapter metadata to a future real server-side
adapter implementation. This is a pre-runtime contract only; do not add
URLSession, endpoints, provider SDKs, credentials, Google/Gaode clients, crawler
runtime, MCP client runtime, SwiftUI/UI changes, navigation, telemetry,
transcript mutation, booking/order, payment, StoreKit, or real provider
execution.

Allowed files:
- kAir/Core/Networking/ServerProviderRuntimeAdapterReadiness.swift
- kAirTests/Networking/ServerProviderRuntimeAdapterReadinessTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer tests first.
- Define a value-only readiness report for each `ProviderFamily`.
- The report should be derived from existing provider family policy,
  `ServerProviderRuntimeRegistry` descriptors, entitlement/cost expectations,
  privacy/source/robots/confirmation requirements, and explicit security gates.
- Google Maps and Gaode must require server mediation, membership/entitlement or
  included-quota evidence, privacy allowance, audit trace, response redaction,
  and no iOS-bundled credential.
- Search API must additionally require source attribution and freshness/citation
  readiness.
- Crawler must additionally require source allowlist, robots allow, rate-limit,
  raw-page redaction, and experimental enablement.
- MCP must additionally require allowlisted tool/resource/prompt descriptors,
  user confirmation where required, OAuth/secrets separation, sandboxing, and
  prompt-injection review.
- Apple local and cache should be reported as local/no real server adapter
  required.
- Readiness reports may expose missing gates, but they must not store endpoint
  URLs, API keys, bearer tokens, credentials, prompt text, raw source content,
  Health data, merchant-write instructions, or payment details.
- Do not wire the matrix into AppBootstrap, ChatStore, views, adapters, runtime
  pipeline execution, or transport.

Acceptance:
- Tests prove every `ProviderFamily` has one readiness report.
- Tests prove remote providers are not marked ready unless all required gates for
  that family are explicitly satisfied.
- Tests prove Google/Gaode/Search/Crawler/MCP have distinct required gate sets
  matching cost, privacy, source, robots, MCP, and security constraints.
- Tests prove Apple local/cache are local/no-server-adapter paths.
- Tests prove encoded reports contain no endpoints, API keys, tokens,
  credentials, prompts, raw source content, Health data, merchant-write
  instructions, payment, booking, or order fields.
- Static scan confirms no URLSession, endpoint, SDK, credential, crawler/MCP
  runtime, SwiftUI/UI changes, navigation, telemetry, payment, StoreKit, or real
  provider execution is introduced.
- Targeted readiness tests pass, full iOS tests pass, and `git diff --check`
  passes.
```

Status after review: implemented and verified in
`ServerProviderRuntimeAdapterReadinessTests`.
`ServerProviderRuntimeAdapterReadinessMatrix` derives each remote report from
existing runtime descriptors and provider-family policy, keeps Apple/cache on
local/no-server-adapter paths, and exposes missing gates until callers
explicitly satisfy every required gate for that provider family. Encoded reports
carry metadata only and do not store endpoint URLs, API keys, bearer tokens,
credentials, prompt text, raw source content, Health data, merchant-write
instructions, payment, booking, or order fields.

## Round A67 - Readiness-Gated Adapter Installation Proof

```text
Task: Add a value-only gate that proves future injected server-side provider
adapters cannot be selected unless their provider family has a ready
`ServerProviderRuntimeAdapterReadinessReport`. This is an installation proof
only; do not add URLSession, endpoints, provider SDKs, credentials,
Google/Gaode clients, crawler runtime, MCP client runtime, SwiftUI/UI changes,
navigation, telemetry, transcript mutation, booking/order, payment, StoreKit,
or real provider execution.

Allowed files:
- kAir/Core/Networking/ServerProviderRuntimeAdapterReadinessGate.swift
- kAirTests/Networking/ServerProviderRuntimeAdapterReadinessGateTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer tests first.
- Build a pure gate that accepts provider families intended for future injected
  adapters plus readiness reports keyed by `ProviderFamily`.
- Return a value-only decision per family: installable only when the family
  requires a server-side adapter and its readiness report is
  `.readyForServerAdapter`.
- Apple local/cache must be rejected as local/no-server-adapter paths.
- Remote families with missing reports, family mismatches, or missing gates must
  be rejected with stable reasons.
- The gate must not construct adapters, mutate `ServerProviderRuntimeAdapterSet`,
  call the runtime pipeline, call transport, or wire app/root/view code.

Acceptance:
- Tests prove Google/Gaode/Search/Crawler/MCP are installable only with ready
  reports for the same provider family.
- Tests prove missing reports, non-ready reports, and family mismatches are
  rejected with deterministic reasons.
- Tests prove Apple local/cache are rejected as no-server-adapter paths.
- Tests prove decisions encode no endpoints, API keys, tokens, credentials,
  prompts, raw source content, Health data, merchant-write instructions,
  payment, booking, or order fields.
- Static scan confirms no URLSession, endpoint, SDK, credential, crawler/MCP
  runtime, SwiftUI/UI changes, navigation, telemetry, payment, StoreKit,
  adapter construction, runtime pipeline execution, transport call, or real
  provider execution is introduced.
- Targeted readiness-gate tests pass, full iOS tests pass, and
  `git diff --check` passes.
```

Status after review: implemented and verified in
`ServerProviderRuntimeAdapterReadinessGateTests`.
`ServerProviderRuntimeAdapterInstallationGate` accepts intended future
server-adapter families plus readiness reports keyed by `ProviderFamily`, then
returns value-only installation decisions. Remote families are installable only
when the same-family report is `.readyForServerAdapter`; missing reports,
non-ready reports, report-family mismatches, Apple local, and cache are rejected
with stable reasons. The gate does not construct adapters, mutate
`ServerProviderRuntimeAdapterSet`, call the runtime pipeline, call transport, or
wire app/root/view code.

`ServerProviderRuntimeAdapterSetReadinessValidator` accepts an already-created
`ServerProviderRuntimeAdapterSet` plus installation decisions keyed by
`ProviderFamily`, then returns a value-only validation result. Registered
remote families are accepted only with same-family installable decisions;
missing decisions, rejected decisions, local/cache families, and mismatches are
rejected deterministically. The validator does not call `resolve(_:)`, construct
adapters, mutate the set, run the runtime pipeline, call transport, or wire
app/root/view code.

## Round A68 - Readiness-Gated Adapter Set Validation Proof

```text
Task: Add a value-only validator that checks an already-created
`ServerProviderRuntimeAdapterSet` by its registered provider families against
`ServerProviderRuntimeAdapterInstallationDecision` values before any set can be
used. This is a validation proof only; do not add URLSession, endpoints,
provider SDKs, credentials, Google/Gaode clients, crawler runtime, MCP client
runtime, SwiftUI/UI changes, navigation, telemetry, transcript mutation,
booking/order, payment, StoreKit, real provider execution, or runtime pipeline
execution.

Allowed files:
- kAir/Core/Networking/ServerProviderRuntimeAdapterSetReadinessValidation.swift
- kAirTests/Networking/ServerProviderRuntimeAdapterSetReadinessValidationTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer tests first.
- Build a pure validator that accepts an already-created
  `ServerProviderRuntimeAdapterSet` plus installation decisions keyed by
  `ProviderFamily`.
- Validate only `registeredProviderFamilies`; do not call `resolve(_:)`, do not
  construct adapters, and do not mutate the set.
- Return a value-only validation result with accepted families, rejected
  families, and stable rejection reasons.
- Accept a family only when a same-family installation decision exists and is
  installable.
- Reject missing decisions, rejected decisions, local/no-server-adapter
  families, and any unregistered/mismatched family.

Acceptance:
- Tests prove an adapter set with ready remote families validates as accepted
  without calling `resolve(_:)`.
- Tests prove missing decisions, rejected decisions, Apple local/cache, and
  mismatched families are rejected with deterministic reasons.
- Tests prove source order or duplicate registered families remain deterministic
  through `ServerProviderRuntimeAdapterSet`'s existing first-family behavior.
- Tests prove encoded validation results contain no endpoints, API keys, tokens,
  credentials, prompts, raw source content, Health data, merchant-write
  instructions, payment, booking, or order fields.
- Static scan confirms no URLSession, endpoint, SDK, credential, crawler/MCP
  runtime, SwiftUI/UI changes, navigation, telemetry, payment, StoreKit,
  runtime pipeline execution, transport call, or real provider execution is
  introduced.
- Targeted set-readiness validation tests pass, full iOS tests pass, and
  `git diff --check` passes.
```

Status after implementation:

`ServerProviderRuntimeAdapterSetReadinessValidator` now validates
already-created injected adapter sets by their registered provider families.
Ready remote families are accepted only when a same-family installation decision
is installable. Missing decisions, rejected decisions, local/cache families, and
mismatched decision families are rejected with stable reasons. Tests prove the
validator does not call `resolve(_:)`, duplicate adapters collapse through the
set's existing first-family behavior, encoded validation output stays free of
sensitive runtime fields, and targeted/full iOS gates pass.

`ServerProviderRuntimeAdapterSetUseGate` accepts a requested `ProviderFamily?`
plus an A68 set-readiness validation, then returns a value-only authorization
result. It authorizes only non-nil, remote, registered, accepted families from
an accepted validation. Nil requested family, local/cache families, unregistered
families, rejected validation, and requested families missing from
`acceptedProviderFamilies` are rejected deterministically. The gate has no
adapter-set input, does not call `resolve(_:)`, does not construct adapters, and
does not mutate validation values.

`ServerProviderRuntimePipeline` now exposes validation-taking injected-adapter
overloads. These prepare the existing invocation boundary, run
`ServerProviderRuntimeAdapterSetUseGate`, and enter
`ServerProviderRuntimeAdapterSet.resolve(_:)` only after authorization. Rejected
authorization projects a value-only `.unavailable` receipt with no accepted
provider metadata and `.adapterSetUseNotAuthorized` in the adapter audit. The
default fixture path and older unvalidated injected-adapter overloads remain
unchanged.

`ServerProviderRuntimeStatusSourceProducer` now has a validation-taking
injected-pipeline overload. It accepts existing explicit recommendation
`PipelineInput` values plus an adapter set and A68 validation, runs the A70
validation-taking pipeline, and packages receipts into
`RuntimeReceiptProviderStatusStore`. The existing precomputed-receipt overload
and older unvalidated injected-pipeline overload remain unchanged.

## Round A69 - Adapter Set Use Authorization Proof

```text
Task: Add a value-only use-authorization gate for future injected
`ServerProviderRuntimeAdapterSet` usage. The gate should accept a requested
`ProviderFamily?` plus a `ServerProviderRuntimeAdapterSetReadinessValidation`
and return whether that single provider family is authorized to enter a future
adapter-set resolve path. This is an authorization proof only; do not add
URLSession, endpoints, provider SDKs, credentials, Google/Gaode clients, crawler
runtime, MCP client runtime, SwiftUI/UI changes, navigation, telemetry,
transcript mutation, booking/order, payment, StoreKit, real provider execution,
or runtime pipeline execution.

Allowed files:
- kAir/Core/Networking/ServerProviderRuntimeAdapterSetUseGate.swift
- kAirTests/Networking/ServerProviderRuntimeAdapterSetUseGateTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer tests first.
- Build a pure gate over `requestedProviderFamily` and an A68 validation result.
- Do not accept or touch the adapter set itself, do not call `resolve(_:)`, do
  not construct adapters, and do not mutate validation values.
- Return a value-only authorization result with accepted/rejected state and a
  stable rejection reason.
- Accept only when the requested family is non-nil, remote, present in
  `registeredProviderFamilies`, present in `acceptedProviderFamilies`, and the
  validation state is accepted.
- Reject nil requested family, rejected validation, local/cache families,
  unregistered requested families, and requested families missing from accepted
  families.

Acceptance:
- Tests prove accepted validation authorizes registered remote families.
- Tests prove rejected validation blocks even if the requested family appears in
  accepted families.
- Tests prove nil requested family, Apple local/cache, unregistered families,
  and missing accepted-family entries are rejected with deterministic reasons.
- Tests prove the gate has no adapter set input and cannot call `resolve(_:)`.
- Tests prove encoded authorization results contain no endpoints, API keys,
  tokens, credentials, prompts, raw source content, Health data,
  merchant-write instructions, payment, booking, or order fields.
- Static scan confirms no URLSession, endpoint, SDK, credential, crawler/MCP
  runtime, SwiftUI/UI changes, navigation, telemetry, payment, StoreKit,
  runtime pipeline execution, transport call, or real provider execution is
  introduced.
- Targeted use-gate tests pass, full iOS tests pass, and `git diff --check`
  passes.
```

Status after implementation:

`ServerProviderRuntimeAdapterSetUseGate` now gates one requested provider family
against an A68 set-readiness validation. Authorized results require an accepted
validation plus a remote family present in both registered and accepted family
lists. Rejections are stable for nil requested family, local/cache families,
unregistered families, rejected validation, and registered-but-not-accepted
families. Tests prove the gate has no adapter-set input, cannot call
`resolve(_:)`, encoded authorization output stays free of sensitive runtime
fields, and targeted/full iOS gates pass.

## Round A70 - Authorized Adapter Set Pipeline Handoff Proof

```text
Task: Add a pipeline handoff proof that requires A69 adapter-set use
authorization before the injected-adapter `ServerProviderRuntimePipeline` path
can enter `ServerProviderRuntimeAdapterSet.resolve(_:)`. This is still a
fixture/value proof only; do not add URLSession, endpoints, provider SDKs,
credentials, Google/Gaode clients, crawler runtime, MCP client runtime,
SwiftUI/UI changes, navigation, telemetry, transcript mutation, booking/order,
payment, StoreKit, real provider execution, or transport execution.

Allowed files:
- kAir/Core/Networking/ServerProviderRuntimePipeline.swift
- kAir/Core/Networking/ServerProviderRuntimeAdapter.swift
- kAir/Core/Networking/ServerProviderRuntimeReceipt.swift
- kAirTests/Networking/ServerProviderRuntimePipelineTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer tests first.
- Add explicit injected-adapter pipeline overloads that accept an A68
  `ServerProviderRuntimeAdapterSetReadinessValidation` alongside the adapter set.
- Before calling `adapterSet.resolve(_:)`, derive the requested provider family
  from the prepared boundary and run `ServerProviderRuntimeAdapterSetUseGate`.
- Authorized use should preserve the existing injected-adapter behavior.
- Rejected use should return a non-success value-only receipt with no accepted
  provider metadata and a stable adapter rejection/audit signal.
- Keep all existing default and unvalidated injected-adapter overload behavior
  unchanged for backward compatibility in current tests.

Acceptance:
- Tests prove authorized validation allows the existing injected-adapter fixture
  path for a prepared remote family.
- Tests prove rejected validation, missing requested provider family,
  unregistered family, local/cache family, and registered-but-not-accepted family
  do not call injected adapter `resolve(_:)`.
- Tests prove unauthorized pipeline results project to non-success receipts with
  no provider metadata, no descriptor, and stable audit/status copy.
- Tests prove existing default fixture-only pipeline and existing unvalidated
  adapter-set overload tests remain green.
- Tests prove encoded receipts/results contain no endpoints, API keys, tokens,
  credentials, prompts, raw source content, Health data, merchant-write
  instructions, payment, booking, or order fields.
- Static scan confirms no URLSession, endpoint, SDK, credential, crawler/MCP
  runtime, SwiftUI/UI changes, navigation, telemetry, payment, StoreKit,
  transport call, or real provider execution is introduced.
- Targeted pipeline tests pass, full iOS tests pass, and `git diff --check`
  passes.
```

Status after implementation:

`ServerProviderRuntimePipeline` now has explicit injected-adapter overloads that
accept an A68 set-readiness validation and run A69 authorization before
`adapterSet.resolve(_:)`. Authorized validation preserves the existing injected
fixture path. Rejected validation, missing requested provider family,
unregistered family, local/cache family, and registered-but-not-accepted family
paths return non-success receipts with no accepted provider metadata and stable
`.adapterSetUseNotAuthorized` audit. Existing default and unvalidated
injected-adapter overloads remain unchanged, and targeted/full iOS gates pass.

## Round A71 - Authorized Runtime Status Source Producer Proof

```text
Task: Add a value-only status-source producer overload that packages authorized
injected-pipeline receipts by explicit recommendation id. The producer should
accept the existing `ServerProviderRuntimeStatusSourceProducer.PipelineInput`
values, an injected `ServerProviderRuntimeAdapterSet`, and an A68
`ServerProviderRuntimeAdapterSetReadinessValidation`, then use the A70
validation-taking pipeline overload before packaging receipts into
`RuntimeReceiptProviderStatusStore`. This is still a fixture/value proof only;
do not add URLSession, endpoints, provider SDKs, credentials, Google/Gaode
clients, crawler runtime, MCP client runtime, SwiftUI/UI changes, navigation,
telemetry, transcript mutation, booking/order, payment, StoreKit, real provider
execution, or transport execution.

Allowed files:
- kAir/Core/Networking/ServerProviderRuntimeStatusSourceProducer.swift
- kAirTests/Networking/ServerProviderRuntimeStatusSourceProducerTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer tests first.
- Add an explicit overload such as
  `statusSource(readinessDecisions:adapterSet:validation:)`.
- The new overload must call the A70 validation-taking
  `ServerProviderRuntimePipeline.run(..., adapterSet:validation:)`.
- Preserve the existing precomputed-receipt overload and existing unvalidated
  injected-pipeline overload behavior for backward compatibility.
- Preserve explicit recommendation ids, sorted ids, duplicate first-entry
  behavior, and missing-id nil lookup.

Acceptance:
- Tests prove authorized validation packages injected-pipeline receipt status
  and preserves injected adapter metadata by recommendation id.
- Tests prove rejected validation packages a non-success advisory status without
  calling injected adapter `resolve(_:)`.
- Tests prove duplicate ids keep the first authorized/unauthorized receipt and
  missing ids return nil.
- Tests prove existing precomputed and unvalidated producer tests remain green.
- Tests prove status copy remains advisory and does not imply provider contact,
  booking, order, payment, crawling, or completion.
- Static scan confirms no URLSession, endpoint, SDK, credential, crawler/MCP
  runtime, SwiftUI/UI changes, navigation, telemetry, payment, StoreKit,
  transport call, or real provider execution is introduced.
- Targeted producer tests pass, full iOS tests pass, and `git diff --check`
  passes.
```

Status after implementation:

`ServerProviderRuntimeStatusSourceProducer` now exposes
`statusSource(readinessDecisions:adapterSet:validation:)`. It packages
authorized injected-pipeline receipts by explicit recommendation id through the
A70 validation-taking pipeline path. Authorized validation preserves injected
adapter metadata in provider-status presentation; rejected validation packages
non-success advisory status without resolving injected adapters. Duplicate ids
keep the first authorized or unauthorized receipt, missing ids return nil,
existing precomputed/unvalidated overloads remain green, status copy stays
advisory, and targeted/full iOS gates pass.

## Round A72 - Authorized Runtime Status App-Root Handoff Proof

```text
Task: Prove that authorized producer-built runtime status sources can pass
through the existing app-root provider-status composition path and remain
rendered-id scoped before ChatStore consumption. This is a handoff proof only;
do not add URLSession, endpoints, provider SDKs, credentials, Google/Gaode
clients, crawler runtime, MCP client runtime, SwiftUI/UI changes, navigation,
telemetry, transcript mutation, booking/order, payment, StoreKit, real provider
execution, runtime pipeline execution in app/root/view code, or transport
execution.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer tests first.
- Build authorized producer status sources in the test/composition layer using
  `ServerProviderRuntimeStatusSourceProducer.statusSource(readinessDecisions:adapterSet:validation:)`.
- Wrap them with `ServerProviderRenderedRuntimeStatusSource` before app-root
  injection when hidden producer ids exist.
- Pass the wrapped source through `AppBootstrap(providerStatusSources:)` and
  the existing `providerStatusSource` composition path.
- Do not add production app/root/view runtime generation.

Acceptance:
- Tests prove an authorized producer-built source passes through
  `AppBootstrap(providerStatusSources:)` and ChatStore can read provider status
  for the rendered recommendation id.
- Tests prove a rejected-validation producer-built source passes through as
  non-success advisory status without implying provider contact.
- Tests prove hidden producer ids stay nil before app-root injection, at
  app-root lookup, and after ChatStore composition when wrapped by rendered ids.
- Tests prove source-order behavior remains deterministic when an authorized
  source is composed with another provider-status source.
- Tests prove no AppBootstrap, ChatStore, RootShell, SwiftUI, navigation,
  telemetry, transport, provider execution, booking/order/payment, or StoreKit
  production code is changed.
- Targeted AppBootstrap tests pass, full iOS tests pass, and
  `git diff --check` passes.
```

Status after implementation:

Authorized producer-built runtime status sources now pass through
`AppBootstrap(providerStatusSources:)` and the existing ChatStore provider-status
composition path while staying rendered-id scoped. Accepted validation preserves
the injected adapter metadata for the rendered recommendation id and hides
non-rendered producer ids before app-root injection, at app-root lookup, and
after ChatStore lookup. Rejected validation passes through as non-success
advisory status without resolving injected adapters. Source ordering stays
first-source-wins when an authorized source is composed with another
provider-status source. Production AppBootstrap, ChatStore, RootShell, SwiftUI,
navigation, telemetry, transport, provider execution, booking/order/payment, and
StoreKit code are unchanged. Targeted/full iOS gates pass.

## Round A73 - Runtime Adapter Manifest Catalog Proof

```text
Task: Add a value-only runtime adapter manifest catalog for future real provider
adapters. The manifest catalog should describe which provider families can ever
be installed, which capabilities they cover, and which readiness/security gates
must be satisfied before any future runtime adapter can exist. This is a manifest
contract only; do not add URLSession, endpoints, SDK clients, credentials,
Google/Gaode clients, crawler runtime, MCP client runtime, SwiftUI/UI changes,
navigation, telemetry, transcript mutation, booking/order, payment, StoreKit,
real provider execution, runtime pipeline execution in app/root/view code, or
transport execution.

Allowed files:
- kAir/Core/Networking/ServerProviderRuntimeAdapterManifest.swift
- kAirTests/Networking/ServerProviderRuntimeAdapterManifestTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer tests first.
- Add a pure `ServerProviderRuntimeAdapterManifest` value with stable id,
  provider family, display name, supported capabilities, required membership
  tier, cost class, required readiness gates, region-policy flag, source-policy
  flag, robots flag, MCP/tool-resource flag, confirmation/human-review flag, and
  experimental-enable flag.
- Add a `ServerProviderRuntimeAdapterManifestCatalog` that returns one manifest
  per remote provider family (`googleMaps`, `gaode`, `searchAPI`, `crawler`,
  `mcp`) and no installable manifest for `appleLocal` or `cache`.
- Derive or cross-check manifest values against the existing
  `ServerProviderRuntimeAdapterReadinessMatrix` / runtime descriptors so the
  manifest cannot drift from readiness gates.
- Manifest encoding must not expose endpoint URLs, API keys, tokens,
  credentials, prompts, raw source/page content, health data, merchant payloads,
  booking/order/payment fields, OAuth secrets, or user private data.
- Keep the manifest catalog value-only and deterministic; no adapter resolution,
  runtime pipeline, transport, AppBootstrap, ChatStore, UI, telemetry, or
  navigation code should change.

Acceptance:
- Tests prove the catalog includes exactly the five remote provider families and
  excludes Apple local/cache as installable manifests.
- Tests prove each manifest's required gates are a superset/equal match of the
  corresponding readiness matrix required gates, including Google/Gaode/Search,
  crawler, and MCP-specific gates.
- Tests prove capabilities, cost class, membership tier, and special flags match
  the provider family policy.
- Tests prove encoding and debug/status text do not leak endpoints, credentials,
  prompts, raw content, health, merchant, booking, order, payment, or OAuth
  secret fields.
- Tests prove manifest ordering and lookup by provider family are deterministic,
  duplicate-safe, and nil for unsupported/local families.
- Static scan confirms no URLSession, endpoint, SDK, credential, Google/Gaode
  client, crawler runtime, MCP client runtime, SwiftUI/UI changes, navigation,
  telemetry, payment, StoreKit, transport call, runtime pipeline execution in
  app/root/view code, or real provider execution is introduced.
- Targeted manifest tests pass, full iOS tests pass, and `git diff --check`
  passes.
```

Status after implementation:

`ServerProviderRuntimeAdapterManifestCatalog` now provides value-only manifests
for `gaode`, `googleMaps`, `searchAPI`, `crawler`, and `mcp`, with nil lookup for
`appleLocal` and `cache`. Manifest values are derived from
`ServerProviderRuntimeAdapterReadinessMatrix`, so display name, capabilities,
membership tier, cost class, and required readiness gates stay aligned with
existing readiness policy. Flags for region policy, source policy, robots,
MCP/tool-resource allowlist, human review, and experimental enablement are
derived from those gates. Tests prove deterministic default ordering, batch
lookup de-duplication, local-family nil lookup, and no sensitive runtime fields
in encoded/status/debug text. Targeted/full iOS gates pass.

## Round A74 - Manifest-Backed Adapter Installation Proof

```text
Task: Prove that future runtime adapter installation decisions must be backed by
the A73 manifest catalog before consuming readiness reports. This is a value-only
planning/authorization proof; do not add URLSession, endpoints, SDK clients,
credentials, Google/Gaode clients, crawler runtime, MCP client runtime,
SwiftUI/UI changes, navigation, telemetry, transcript mutation, booking/order,
payment, StoreKit, real provider execution, runtime pipeline execution in
app/root/view code, or transport execution.

Allowed files:
- kAir/Core/Networking/ServerProviderRuntimeAdapterManifestInstallation.swift
- kAirTests/Networking/ServerProviderRuntimeAdapterManifestInstallationTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer tests first.
- Add a pure `ServerProviderRuntimeAdapterManifestInstallationPlanner` that
  accepts manifest-backed provider-family requests plus readiness reports and
  returns existing `ServerProviderRuntimeAdapterInstallationDecision` values or a
  small manifest-installation wrapper if needed.
- The planner must require `ServerProviderRuntimeAdapterManifestCatalog.manifest(for:)`
  to exist before using readiness reports.
- The planner should reject Apple local/cache and any missing manifest before
  readiness-report acceptance.
- The planner should reject manifest/readiness family mismatch and manifest gate
  drift before delegating to `ServerProviderRuntimeAdapterInstallationGate`.
- Ready same-family reports whose gates match the manifest may delegate to the
  existing A67 installation gate and preserve its installable/rejected semantics.
- Keep ordering deterministic and duplicate handling explicit.
- Keep the planner value-only: no adapter resolution, adapter set creation,
  runtime pipeline, transport, AppBootstrap, ChatStore, UI, telemetry, or
  navigation code should change.

Acceptance:
- Tests prove remote provider families become installable only when both a
  manifest exists and the same-family readiness report is ready with the manifest
  gate set satisfied.
- Tests prove Apple local/cache and missing-manifest requests are rejected before
  readiness reports are considered.
- Tests prove manifest/readiness family mismatch and readiness-gate drift are
  rejected distinctly.
- Tests prove existing A67 installation semantics are preserved for missing,
  non-ready, and ready same-family reports after manifest validation.
- Tests prove ordering and duplicate behavior are deterministic.
- Tests prove encoding/debug/status text do not leak endpoints, credentials,
  prompts, raw content, health, merchant, booking, order, payment, OAuth secret,
  or user private data fields.
- Static scan confirms no URLSession, endpoint, SDK, credential, Google/Gaode
  client, crawler runtime, MCP client runtime, SwiftUI/UI changes, navigation,
  telemetry, payment, StoreKit, transport call, runtime pipeline execution in
  app/root/view code, or real provider execution is introduced.
- Targeted manifest-installation tests pass, full iOS tests pass, and
  `git diff --check` passes.
```

Status after implementation:

`ServerProviderRuntimeAdapterManifestInstallationPlanner` now returns a
value-only manifest-backed installation decision before any future adapter set can
use readiness-installation decisions. Remote provider families become installable
only when the A73 manifest exists and the same-family readiness report is ready
with the manifest gate set satisfied. Apple local/cache and missing-manifest
requests are rejected before readiness reports are considered. Manifest/readiness
family mismatch and gate drift are rejected distinctly before the planner
delegates to `ServerProviderRuntimeAdapterInstallationGate`. Existing A67
installation semantics for missing, non-ready, and ready same-family reports are
preserved after manifest validation. Targeted/full iOS gates pass.

## Round A75 - Manifest-Backed Adapter Set Validation Proof

```text
Task: Prove that already-created injected adapter sets can be validated only from
manifest-backed installation decisions before delegating to A68 set validation.
This is a value-only validation proof; do not add URLSession, endpoints, SDK
clients, credentials, Google/Gaode clients, crawler runtime, MCP client runtime,
SwiftUI/UI changes, navigation, telemetry, transcript mutation, booking/order,
payment, StoreKit, real provider execution, runtime pipeline execution in
app/root/view code, or transport execution.

Allowed files:
- kAir/Core/Networking/ServerProviderRuntimeAdapterManifestSetValidation.swift
- kAirTests/Networking/ServerProviderRuntimeAdapterManifestSetValidationTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer tests first.
- Add a pure `ServerProviderRuntimeAdapterManifestSetValidator` that accepts an
  already-created `ServerProviderRuntimeAdapterSet` plus A74
  `ServerProviderRuntimeAdapterManifestInstallationDecision` values.
- The validator must require every registered remote adapter family to have a
  manifest-backed installable decision before it can delegate to
  `ServerProviderRuntimeAdapterSetReadinessValidator`.
- The validator should reject missing manifest-backed decisions, local/cache
  registered adapters, non-installable manifest-backed decisions, manifest-family
  mismatches, and missing underlying A67 installation decisions distinctly.
- Accepted paths may delegate to A68 using the underlying
  `ServerProviderRuntimeAdapterInstallationDecision` values and should preserve
  A68 accepted/rejected semantics.
- Keep ordering and duplicate behavior deterministic through the existing
  adapter-set first-family behavior.
- Keep the validator value-only: do not call adapter `resolve(_:)`, create
  transport envelopes, run the runtime pipeline, create AppBootstrap/ChatStore/UI
  wiring, or mutate telemetry/navigation/transcript state.

Acceptance:
- Tests prove ready remote adapter sets validate only when every registered
  family has an installable manifest-backed decision.
- Tests prove missing manifest-backed decisions, local/cache adapters,
  non-installable decisions, manifest-family mismatches, and missing underlying
  A67 installation decisions are rejected distinctly.
- Tests prove accepted paths preserve A68 validation output, including accepted
  provider families and deterministic duplicate-adapter first-family behavior.
- Tests prove rejected paths never call adapter `resolve(_:)`.
- Tests prove encoding/debug/status text do not leak endpoints, credentials,
  prompts, raw content, health, merchant, booking, order, payment, OAuth secret,
  or user private data fields.
- Static scan confirms no URLSession, endpoint, SDK, credential, Google/Gaode
  client, crawler runtime, MCP client runtime, SwiftUI/UI changes, navigation,
  telemetry, payment, StoreKit, transport call, runtime pipeline execution in
  app/root/view code, or real provider execution is introduced.
- Targeted manifest-set-validation tests pass, full iOS tests pass, and
  `git diff --check` passes.
```

Status after implementation:

`ServerProviderRuntimeAdapterManifestSetValidator` now returns a value-only
manifest-backed adapter-set validation before any future adapter-set use can
consume readiness validation. Ready remote adapter sets validate only when every
registered family has an installable A74 manifest-backed decision with an
underlying A67 installation decision. Missing manifest-backed decisions,
local/cache adapters, non-installable decisions, manifest-family mismatches, and
missing underlying A67 decisions are rejected distinctly. Accepted paths delegate
to A68 and preserve accepted provider families plus deterministic duplicate
first-family behavior. Rejected paths do not call adapter `resolve(_:)`.
Targeted/full iOS gates pass.

## Round A76 - Manifest-Backed Adapter Set Use Authorization Proof

```text
Task: Prove that future injected adapter-set use authorization can consume only
manifest-backed adapter-set validation before delegating to A69 use
authorization. This is a value-only authorization proof; do not add URLSession,
endpoints, SDK clients, credentials, Google/Gaode clients, crawler runtime, MCP
client runtime, SwiftUI/UI changes, navigation, telemetry, transcript mutation,
booking/order, payment, StoreKit, real provider execution, runtime pipeline
execution in app/root/view code, or transport execution.

Allowed files:
- kAir/Core/Networking/ServerProviderRuntimeAdapterManifestSetUseGate.swift
- kAirTests/Networking/ServerProviderRuntimeAdapterManifestSetUseGateTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer tests first.
- Add a pure `ServerProviderRuntimeAdapterManifestSetUseGate` that accepts a
  requested `ProviderFamily?` plus an A75
  `ServerProviderRuntimeAdapterManifestSetValidation`.
- The gate must require accepted manifest-backed set validation and an embedded
  A68 readiness validation before delegating to
  `ServerProviderRuntimeAdapterSetUseGate`.
- Reject nil requested family, Apple local/cache, rejected manifest-backed
  validation, requested families not accepted by the manifest-backed validation,
  missing embedded A68 validation, and any A69 rejection distinctly.
- Accepted paths may delegate to A69 and must preserve its authorization output
  without receiving an adapter set or calling `resolve(_:)`.
- Keep the gate value-only: do not create adapters, create transport envelopes,
  run the runtime pipeline, create AppBootstrap/ChatStore/UI wiring, or mutate
  telemetry/navigation/transcript state.

Acceptance:
- Tests prove registered remote families are authorized only when the A75
  manifest-backed validation is accepted and contains the requested family.
- Tests prove nil requested family, local/cache, rejected manifest-backed
  validation, not-accepted families, missing embedded A68 validation, and A69
  delegated rejection are distinct.
- Tests prove accepted paths preserve A69 authorization output.
- Tests prove the gate does not accept an adapter set and cannot call adapter
  `resolve(_:)`.
- Tests prove encoding/debug/status text do not leak endpoints, credentials,
  prompts, raw content, health, merchant, booking, order, payment, OAuth secret,
  or user private data fields.
- Static scan confirms no URLSession, endpoint, SDK, credential, Google/Gaode
  client, crawler runtime, MCP client runtime, SwiftUI/UI changes, navigation,
  telemetry, payment, StoreKit, transport call, runtime pipeline execution in
  app/root/view code, or real provider execution is introduced.
- Targeted manifest-set-use-gate tests pass, full iOS tests pass, and
  `git diff --check` passes.
```

Status after implementation:

`ServerProviderRuntimeAdapterManifestSetUseGate` now returns a value-only
manifest-backed authorization before any future injected adapter-set pipeline can
use A69 authorization. Registered remote families authorize only when the A75
manifest-backed validation is accepted, contains the requested family, and
includes embedded A68 readiness validation that A69 also authorizes. Nil
requested family, Apple local/cache, rejected A75 validation, not-accepted
families, missing embedded A68 validation, and A69 delegated rejection are
distinct. The gate does not accept an adapter set and cannot call
`resolve(_:)`. Targeted/full iOS gates pass.

## Round A77 - Manifest-Backed Runtime Pipeline Handoff Proof

```text
Task: Prove that the injected-adapter runtime pipeline can consume only A76
manifest-backed adapter-set use authorization before any adapter-set
`resolve(_:)` path. This is still a value-only handoff proof; do not add
URLSession, endpoints, SDK clients, credentials, Google/Gaode clients, crawler
runtime, MCP client runtime, SwiftUI/UI changes, navigation, telemetry,
transcript mutation, booking/order, payment, StoreKit, real provider execution,
production app/root/view runtime generation, or transport execution.

Allowed files:
- kAir/Core/Networking/ServerProviderRuntimePipeline.swift
- kAirTests/Networking/ServerProviderRuntimePipelineTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer tests first.
- Add explicit manifest-backed injected-pipeline overloads that accept existing
  value pipeline inputs, an injected `ServerProviderRuntimeAdapterSet`, and an
  A76 `ServerProviderRuntimeAdapterManifestSetUseAuthorization`.
- The overload must reject before `adapterSet.resolve(_:)` unless the A76
  authorization is authorized, contains the requested prepared provider family,
  and carries an authorized embedded A69 authorization.
- Accepted paths may preserve the existing A70 authorized injected-adapter
  behavior by entering `adapterSet.resolve(_:)` only after the A76 proof.
- Rejected paths must project non-success receipts without provider metadata and
  without injected adapter calls.
- Keep default/uninjected pipeline paths unchanged.
- Keep the pipeline value-only: no transport envelopes beyond existing value
  receipts, no network calls, no AppBootstrap/ChatStore/UI wiring, no telemetry
  mutation, and no real provider execution.

Acceptance:
- Tests prove prepared remote boundaries resolve injected adapters only when A76
  authorization is accepted for the same requested provider family.
- Tests prove rejected A76 authorization, missing requested family, local/cache,
  requested-family mismatch, missing embedded A69 authorization, and A69 rejected
  authorization all produce deterministic non-success receipts without resolving
  injected adapters.
- Tests prove existing default pipeline behavior and existing A70 validation
  overloads remain green.
- Tests prove receipt/status text do not imply provider contact or action
  completion and do not leak endpoints, credentials, prompts, raw content,
  health, merchant, booking, order, payment, OAuth secret, or user private data.
- Static scan confirms no URLSession, endpoint, SDK, credential, Google/Gaode
  client, crawler runtime, MCP client runtime, SwiftUI/UI changes, navigation,
  telemetry, payment, StoreKit, transport call, production app/root/view runtime
  execution, or real provider execution is introduced.
- Targeted runtime-pipeline tests pass, full iOS tests pass, and
  `git diff --check` passes.
```

Status after implementation:

`ServerProviderRuntimePipeline` now has explicit manifest-backed injected
adapter overloads that accept A76
`ServerProviderRuntimeAdapterManifestSetUseAuthorization` before any injected
adapter-set `resolve(_:)` path. Prepared remote boundaries resolve injected
adapters only when A76 is authorized for the same provider family and carries an
authorized embedded A69 authorization. Rejected A76 authorization, missing
requested family, local/cache, requested-family mismatch, missing embedded A69
authorization, and A69 rejected authorization all produce deterministic
non-success receipts without injected adapter calls. Existing default pipeline
behavior and A70 validation overloads remain green. Targeted/full iOS gates pass.

## Round A78 - Manifest-Backed Runtime Status Source Producer Proof

```text
Task: Prove that runtime/provider composition can package manifest-backed
injected-pipeline receipts by explicit recommendation id through the A77
authorization-taking pipeline path. This is still a value-only status-source
handoff proof; do not add URLSession, endpoints, SDK clients, credentials,
Google/Gaode clients, crawler runtime, MCP client runtime, SwiftUI/UI changes,
navigation, telemetry, transcript mutation, booking/order, payment, StoreKit,
real provider execution, production app/root/view runtime generation, or
transport execution.

Allowed files:
- kAir/Core/Networking/ServerProviderRuntimeStatusSourceProducer.swift
- kAirTests/Networking/ServerProviderRuntimeStatusSourceProducerTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer tests first.
- Add an explicit manifest-backed producer overload that accepts recommendation
  ids, value pipeline inputs, an injected `ServerProviderRuntimeAdapterSet`, and
  A76 `ServerProviderRuntimeAdapterManifestSetUseAuthorization` values.
- The overload should call the A77 authorization-taking pipeline path and package
  the resulting receipts into the existing `RuntimeReceiptProviderStatusStore`.
- Accepted paths should preserve injected adapter metadata for rendered
  recommendation ids.
- Rejected paths should package non-success advisory provider status without
  resolving injected adapters or exposing provider metadata.
- Preserve existing precomputed, unvalidated, and A70 validation-taking producer
  overloads.
- Keep the producer value-only: no AppBootstrap/ChatStore/UI wiring, no
  telemetry/navigation/transcript mutation, no transport calls, and no real
  provider execution.

Acceptance:
- Tests prove accepted A76 authorizations package A77 injected-pipeline metadata
  by explicit recommendation id.
- Tests prove rejected A76 authorizations package non-success advisory status
  without resolving injected adapters.
- Tests prove duplicate recommendation ids keep the first receipt/status and
  missing ids return nil.
- Tests prove existing precomputed, unvalidated, and A70 validation-taking
  producer paths remain green.
- Tests prove provider-status copy stays advisory and does not imply provider
  contact or action completion, and encoded/status text does not leak endpoints,
  credentials, prompts, raw content, health, merchant, booking, order, payment,
  OAuth secret, or user private data.
- Static scan confirms no URLSession, endpoint, SDK, credential, Google/Gaode
  client, crawler runtime, MCP client runtime, SwiftUI/UI changes, navigation,
  telemetry, payment, StoreKit, transport call, production app/root/view runtime
  execution, or real provider execution is introduced.
- Targeted runtime-status-source-producer tests pass, full iOS tests pass, and
  `git diff --check` passes.
```

Status after implementation:

`ServerProviderRuntimeStatusSourceProducer` now exposes
`statusSource(manifestBackedReadinessDecisions:adapterSet:)`. It packages
manifest-backed injected-pipeline receipts by explicit recommendation id through
the A77 authorization-taking pipeline path. Accepted A76 authorization preserves
injected adapter metadata in provider-status presentation; rejected A76
authorization packages non-success advisory status without resolving injected
adapters. Duplicate ids keep the first receipt, missing ids return nil, existing
precomputed/unvalidated/A70 validation-taking overloads remain green, and status
copy stays advisory. Targeted/full iOS gates pass.

## Round A79 - Manifest-Backed Runtime Status App-Root Handoff Proof

```text
Task: Prove that manifest-backed producer-built runtime status sources can pass
through the existing app-root provider-status composition path and remain
rendered-id scoped before ChatStore consumption. This is a handoff proof only;
do not add URLSession, endpoints, provider SDKs, credentials, Google/Gaode
clients, crawler runtime, MCP client runtime, SwiftUI/UI changes, navigation,
telemetry, transcript mutation, booking/order, payment, StoreKit, real provider
execution, runtime pipeline execution in production app/root/view code, or
transport execution.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer tests first.
- Build manifest-backed producer status sources in the test/composition layer
  using `ServerProviderRuntimeStatusSourceProducer.statusSource(manifestBackedReadinessDecisions:adapterSet:)`.
- Wrap them with `ServerProviderRenderedRuntimeStatusSource` before app-root
  injection when hidden producer ids exist.
- Pass the wrapped source through `AppBootstrap(providerStatusSources:)` and the
  existing `providerStatusSource` composition path.
- Do not add production app/root/view runtime generation.

Acceptance:
- Tests prove a manifest-backed accepted producer-built source passes through
  `AppBootstrap(providerStatusSources:)` and ChatStore can read provider status
  for the rendered recommendation id.
- Tests prove a rejected-A76 producer-built source passes through as non-success
  advisory status without implying provider contact and without resolving
  injected adapters.
- Tests prove hidden producer ids stay nil before app-root injection, at
  app-root lookup, and after ChatStore composition when wrapped by rendered ids.
- Tests prove source-order behavior remains deterministic when a manifest-backed
  source is composed with another provider-status source.
- Tests prove no AppBootstrap, ChatStore, RootShell, SwiftUI, navigation,
  telemetry, transport, provider execution, booking/order/payment, or StoreKit
  production code is changed.
- Targeted AppBootstrap tests pass, full iOS tests pass, and `git diff --check`
  passes.
```

Status after implementation:

Manifest-backed producer-built runtime status sources now pass through
`AppBootstrap(providerStatusSources:)` and the existing ChatStore provider-status
composition path while staying rendered-id scoped. Accepted A76 authorization
preserves injected adapter metadata for the rendered recommendation id and hides
non-rendered producer ids before app-root injection, at app-root lookup, and
after ChatStore lookup. Rejected A76 authorization passes through as non-success
advisory status without resolving injected adapters. Source ordering stays
first-source-wins when a manifest-backed source is composed with another
provider-status source. Production AppBootstrap, ChatStore, RootShell, SwiftUI,
navigation, telemetry, transport, provider execution, booking/order/payment, and
StoreKit code are unchanged. Targeted/full iOS gates pass.

## Round A80 - Real Provider Connector Boundary Skeleton

```text
Task: Add the smallest value-only connector boundary for future real provider
adapters. This is an interface/skeleton proof only; do not add URLSession,
endpoints, SDK clients, credentials, Google/Gaode clients, crawler runtime, MCP
client runtime, SwiftUI/UI changes, navigation, telemetry, transcript mutation,
booking/order, payment, StoreKit, real provider execution, production
app/root/view runtime generation, or transport execution.

Allowed files:
- kAir/Core/Networking/ServerProviderRuntimeConnector.swift
- kAirTests/Networking/ServerProviderRuntimeConnectorTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer tests first.
- Define value-only connector request/result types that can name the provider
  family, capability, cost class, freshness, manifest id, authorization id,
  boundary id, and trace id without storing endpoints, keys, prompts, raw
  content, Health/private data, merchant/order/payment details, or SDK handles.
- Define a connector protocol or equivalent boundary that future Google Maps,
  Gaode, Search API, crawler, and MCP adapters can conform to after policy
  approval.
- Add a fixture/no-op connector only if needed for tests; it must return metadata
  only and must not perform transport.
- Keep local Apple/cache paths out of real-provider connector eligibility.
- Preserve A79: no app/root/view layer should construct connector requests or
  run connector code.

Acceptance:
- Tests prove connector requests/results are value-only, Codable/Hashable/Sendable
  where existing project style allows, and do not expose endpoints, credentials,
  prompts, raw content, Health/private data, merchant/order/payment details, or
  SDK handles.
- Tests prove Google Maps, Gaode, Search API, crawler, and MCP are the only
  remote families eligible for future connector boundaries; Apple local and cache
  remain local-only/no-connector paths.
- Tests prove status/debug copy is advisory and does not imply provider contact,
  action completion, crawling, booking, ordering, or payment.
- Static scan confirms no URLSession, endpoint, SDK, credential, Google/Gaode
  client, crawler runtime, MCP client runtime, SwiftUI/UI changes, navigation,
  telemetry, payment, StoreKit, transport call, production app/root/view runtime
  execution, or real provider execution is introduced.
- Targeted connector tests pass, full iOS tests pass, and `git diff --check`
  passes.
```

Status after implementation:

`ServerProviderRuntimeConnector` now defines value-only connector request/result
types, a connector protocol, a metadata-only connector double, and a remote-family
eligibility catalog. Requests can name provider family, capability, cost class,
freshness, manifest id, authorization id, boundary id, and trace id only after the
provider family is remote, manifest-backed, and A76-authorized for the same
family. Results preserve metadata for accepted boundaries and strip provider
metadata for connector-family mismatch rejections. Google Maps, Gaode, Search
API, crawler, and MCP are the only eligible future connector families; Apple
local and cache stay no-connector paths. Targeted/full iOS gates pass.

## Round A81 - Connector Request Planner Proof

```text
Task: Prove that runtime/provider composition can derive value-only connector
requests from prepared dispatch boundaries, A73 manifests, and A76
manifest-backed authorization before any connector is run. This is still a
request-planning proof only; do not add URLSession, endpoints, SDK clients,
credentials, Google/Gaode clients, crawler runtime, MCP client runtime,
SwiftUI/UI changes, navigation, telemetry, transcript mutation, booking/order,
payment, StoreKit, real provider execution, production app/root/view runtime
generation, connector execution, or transport execution.

Allowed files:
- kAir/Core/Networking/ServerProviderRuntimeConnectorPlanner.swift
- kAirTests/Networking/ServerProviderRuntimeConnectorPlannerTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer tests first.
- Add a value-only planner that accepts a `ServerProviderRuntimeDispatchBoundary`,
  an A73 manifest, and an A76 `ServerProviderRuntimeAdapterManifestSetUseAuthorization`.
- Accepted planning should create a `ServerProviderRuntimeConnectorRequest` only
  for prepared, remote, manifest-backed, same-family, authorized boundaries with
  trace id, capability, cost class, and freshness metadata present.
- Rejected planning should stay value-only and keep distinct reasons for
  non-prepared boundary, missing requested provider family, local/cache,
  manifest-family mismatch, A76 mismatch/rejection, and missing boundary metadata.
- The planner must not call `ServerProviderRuntimeConnector.prepare(_:)`,
  `ServerProviderRuntimeAdapterSet.resolve(_:)`, app/root/view code, or transport.

Acceptance:
- Tests prove prepared same-family remote boundaries produce connector requests
  with manifest id, authorization id, boundary id, trace id, capability, cost
  class, and freshness copied from metadata.
- Tests prove local/cache, non-prepared boundaries, missing provider family,
  missing required boundary metadata, manifest mismatch, A76 family mismatch, and
  A76 rejection each produce deterministic rejected planning output without
  connector execution.
- Tests prove output copy and encoding stay advisory and do not expose endpoints,
  credentials, prompts, raw content, Health/private data, merchant/order/payment
  details, OAuth secret, SDK handles, or provider result payloads.
- Static scan confirms no URLSession, endpoint, SDK, credential, Google/Gaode
  client, crawler runtime, MCP client runtime, SwiftUI/UI changes, navigation,
  telemetry, payment, StoreKit, connector execution, transport call, production
  app/root/view runtime execution, or real provider execution is introduced.
- Targeted connector-planner tests pass, full iOS tests pass, and
  `git diff --check` passes.
```

Status after implementation:

`ServerProviderRuntimeConnectorPlanner` now creates connector requests only from
prepared remote dispatch boundaries with same-family A73 manifest metadata and
A76 manifest-backed authorization. Planning output is value-only and
Codable/Hashable/Sendable: accepted output preserves provider family, capability,
cost class, freshness, manifest id, authorization id, boundary id, trace id, and
request id; rejected output carries deterministic reasons without a request.
Targeted/full iOS gates pass.

## Round A82 - Connector Invocation Receipt Proof

```text
Task: Prove that an A81 prepared connector request can be consumed by an
injected connector boundary and projected into a value-only connector invocation
receipt. This is still a metadata-only connector proof; do not add URLSession,
endpoints, SDK clients, credentials, Google/Gaode clients, crawler runtime, MCP
client runtime, SwiftUI/UI changes, navigation, telemetry, transcript mutation,
booking/order, payment, StoreKit, real provider execution, production
app/root/view runtime generation, or transport execution.

Allowed files:
- kAir/Core/Networking/ServerProviderRuntimeConnectorInvocation.swift
- kAirTests/Networking/ServerProviderRuntimeConnectorInvocationTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer tests first.
- Add a value-only invocation receipt that accepts an A81
  `ServerProviderRuntimeConnectorPlanningResult` and an injected
  `ServerProviderRuntimeConnector`.
- Accepted planning plus same-family connector should call the connector once and
  preserve the A80 connector result metadata.
- Rejected planning must not call the connector and must return a deterministic
  non-success receipt.
- Connector-family mismatch should preserve the A80 mismatch result without
  leaking provider metadata.
- This layer may call `ServerProviderRuntimeConnector.prepare(_:)` only through
  the injected connector protocol; it must not call adapter sets, app/root/view
  code, or transport.

Acceptance:
- Tests prove accepted A81 planning output plus a same-family metadata-only
  connector produces a receipt with request id, result id, provider family,
  capability, cost class, freshness, manifest id, authorization id, boundary id,
  and trace id copied from the connector result.
- Tests prove rejected A81 planning output returns a receipt without calling the
  connector.
- Tests prove connector-family mismatch returns a rejected receipt without
  provider metadata, manifest id, authorization id, or trace id.
- Tests prove receipt copy and encoding stay advisory and do not expose
  endpoints, credentials, prompts, raw content, Health/private data,
  merchant/order/payment details, OAuth secret, SDK handles, or provider result
  payloads.
- Static scan confirms no URLSession, endpoint, SDK, credential, Google/Gaode
  client, crawler runtime, MCP client runtime, SwiftUI/UI changes, navigation,
  telemetry, payment, StoreKit, transport call, production app/root/view runtime
  execution, or real provider execution is introduced.
- Targeted connector-invocation tests pass, full iOS tests pass, and
  `git diff --check` passes.
```

Status after implementation:

`ServerProviderRuntimeConnectorInvoker` now projects A81 planning output into
value-only connector invocation receipts through an injected
`ServerProviderRuntimeConnector`. Accepted planning calls the connector once and
preserves the A80 connector result metadata; rejected planning returns a rejected
receipt without calling the connector; connector-family mismatch preserves the
A80 rejected result while stripping provider metadata, manifest id,
authorization id, and trace id. Targeted/full iOS gates pass.

## Round A83 - Connector Receipt Status Source Proof

```text
Task: Prove that A82 connector invocation receipts can be packaged by explicit
recommendation id into an advisory provider-status source for rendered
recommendations. This is still a value-only status projection proof; do not add
URLSession, endpoints, SDK clients, credentials, Google/Gaode clients, crawler
runtime, MCP client runtime, SwiftUI/UI changes, navigation, telemetry,
transcript mutation, booking/order, payment, StoreKit, real provider execution,
production app/root/view runtime generation, or transport execution.

Allowed files:
- kAir/Core/Networking/ServerProviderRuntimeConnectorStatusSourceProducer.swift
- kAirTests/Networking/ServerProviderRuntimeConnectorStatusSourceProducerTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer tests first.
- Add a value-only status source producer that accepts explicit
  recommendation-id / A82 receipt pairs.
- The status source should preserve duplicate-id first-wins behavior and return
  nil for missing ids.
- Accepted connector receipts should map to advisory provider-status
  presentation with provider family, capability, freshness/cost metadata, and
  no claim that a real provider was contacted.
- Rejected connector receipts should map to deterministic non-success status
  copy that preserves the rejection reason without leaking provider metadata.
- The producer must not run connector planning, connector invocation, adapter-set
  resolve, app/root/view code, UI, telemetry, or transport.

Acceptance:
- Tests prove accepted A82 receipts package by explicit recommendation id and
  expose stable advisory status for rendered ids.
- Tests prove rejected planning and connector-family mismatch receipts package as
  non-success advisory status without provider metadata leakage.
- Tests prove duplicate ids keep the first receipt and missing ids return nil.
- Tests prove output copy and encoding stay advisory and do not expose endpoints,
  credentials, prompts, raw content, Health/private data, merchant/order/payment
  details, OAuth secret, SDK handles, or provider result payloads.
- Static scan confirms no URLSession, endpoint, SDK, credential, Google/Gaode
  client, crawler runtime, MCP client runtime, SwiftUI/UI changes, navigation,
  telemetry, payment, StoreKit, connector execution, transport call, production
  app/root/view runtime execution, or real provider execution is introduced.
- Targeted connector-status-source tests pass, full iOS tests pass, and
  `git diff --check` passes.
```

Status after implementation:

`ServerProviderRuntimeConnectorStatusSourceProducer` now builds rendered-id
scoped provider-status sources from explicit recommendation-id / A82 receipt
pairs. Accepted receipts expose advisory provider family, cost, and freshness
badges without claiming provider contact. Rejected planning and connector-family
mismatch receipts surface non-success copy without provider metadata leakage.
Duplicate recommendation ids keep the first receipt, hidden ids stay nil, and
missing ids return nil. Targeted/full iOS gates pass.

## Round A84 - Connector Receipt Status App-Root Handoff Proof

```text
Task: Prove that A83 connector receipt status sources can pass through
`AppBootstrap(providerStatusSources:)` and ChatStore composition while remaining
rendered-id scoped. This is still an app-root handoff proof only; do not add
URLSession, endpoints, SDK clients, credentials, Google/Gaode clients, crawler
runtime, MCP client runtime, SwiftUI/UI changes, navigation, telemetry,
transcript mutation outside existing status lookup, booking/order, payment,
StoreKit, connector planning, connector invocation, real provider execution,
production app/root/view runtime generation, or transport execution.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Prefer tests first.
- Build A83 connector receipt status sources in tests and pass them through
  `AppBootstrap(providerStatusSources:)`.
- Prove app-root provider-status source composition preserves source order and
  only exposes rendered recommendation ids.
- Prove accepted and rejected connector receipt status presentations remain
  advisory and are visible through ChatStore/provider-status lookup only for
  rendered ids.
- Do not add production app/root/view runtime generation.

Acceptance:
- Tests prove A83 connector status sources survive `AppBootstrap` provider-status
  source composition and can be consumed by ChatStore/provider-status lookup.
- Tests prove hidden connector receipt ids stay nil before app-root injection,
  after app-root lookup, and after ChatStore lookup.
- Tests prove accepted and rejected connector receipt status copy remains
  advisory and does not expose endpoints, credentials, prompts, raw content,
  Health/private data, merchant/order/payment details, OAuth secret, SDK handles,
  or provider result payloads.
- Static scan confirms no URLSession, endpoint, SDK, credential, Google/Gaode
  client, crawler runtime, MCP client runtime, SwiftUI/UI changes, navigation,
  telemetry, payment, StoreKit, connector planning, connector invocation,
  transport call, production app/root/view runtime execution, or real provider
  execution is introduced.
- Targeted AppBootstrap connector-status handoff tests pass, full iOS tests pass,
  and `git diff --check` passes.
```

Status after implementation:

A83 connector receipt status sources now survive app-root provider-status source
composition and ChatStore lookup behind the rendered-id guard. Accepted connector
receipt status preserves provider/cost/freshness advisory badges for rendered
recommendations; rejected connector receipt status remains disabled/non-success
without leaking provider metadata. Hidden connector receipt ids remain nil before
app-root injection, after app-root lookup, and after ChatStore lookup. Source
order remains first-source-wins. Targeted/full iOS gates pass.

## Round A85 - Research, Market, and Interface Cut Plan Refresh

```text
Task: Refresh the research and product-market architecture audit after the A84
connector-status handoff. This is a docs/research step only: deeply review current
agent papers, open-source agent architectures, mobile/GUI-agent patterns,
MCP/tool security guidance, and market competitors, then translate the findings
into the next implementation cut plan for kAir. Do not add Swift runtime behavior,
URLSession, endpoints, SDK clients, credentials, Google/Gaode clients, crawler
runtime, MCP client runtime, SwiftUI/UI changes, navigation, telemetry, transcript
mutation, booking/order, payment, StoreKit, real provider execution, production
app/root/view runtime generation, or transport execution.

Allowed files:
- Docs/research/2026-agent-market-ui-provider-research.md
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Use live web/research lookup and cite sources with dates. Prefer primary papers,
  official docs, and public competitor/product docs over commentary.
- Compare kAir against current agent patterns: plan/act separation, tool-use
  gating, memory, MCP prompts/resources/tools, GUI/mobile agents, provider routing,
  cost/latency/privacy evaluation, and app-store-safe local/remote boundaries.
- Audit existing prompt/interface reservations in the docs: model prompts,
  provider prompts, MCP prompt descriptors, reserved Search/crawler paths, and
  connector/provider-status handoff.
- Decide whether the next real-provider step should be Google Maps, Gaode,
  Search API, MCP, crawler, or remote model. The recommendation must include
  why the others remain deferred.
- Produce one concrete next coding-agent prompt with allowed files and acceptance
  tests. The prompt must preserve A11-A84 gates and must not authorize real
  provider execution until the selected provider has an explicit server-side
  adapter contract, quota gate, privacy gate, prompt/source policy, and UI-safe
  status path.

Acceptance:
- Research doc includes current source-backed findings, not stale A10-only claims.
- Architecture docs explain which advanced paper patterns are applicable now,
  which are experimental/deferred, and why.
- Market-fit audit identifies competitor gaps/opportunities and maps them to
  kAir implementation risks.
- Prompt/interface audit confirms no hidden prompt, MCP prompt, provider adapter,
  credential, endpoint, or transport execution seam is accidentally authorized.
- Next coding prompt is specific enough for a coding agent to implement without
  broad redesign or scope creep.
- `git diff --check` passes. No Swift build is required if this round remains
  docs-only.
```

Status after implementation:

A85 refreshed the research and architecture docs from current papers, MCP spec
and security work, Apple/provider docs, competitor signals, and Search API market
docs. It keeps kAir on the local-first, typed planner -> policy -> adapter ->
receipt/status architecture; treats GUI-agent research as test/assistive input
only; keeps MCP prompts/descriptors disabled by default; and selects Search API
as the first provider-specific contract proof. No Swift runtime changed and no
provider execution is authorized.

## Round A86 - Search API Server Adapter Contract Proof

```text
Task: Add a value-only Search API server adapter contract that consumes already
approved search provider metadata, envelope/connector receipt inputs, and policy
state, then produces normalized, citation-required, UI-safe Search API adapter
request/result/receipt values. This is provider-specific contract proof only.
Do not add URLSession, endpoint URLs, API keys, OAuth tokens, SDK clients,
Exa/Brave/Tavily/Google/Gaode calls, crawler runtime, MCP client runtime,
SwiftUI/UI, navigation, telemetry, transcript mutation, booking/order/payment,
StoreKit, memory writes, production app/root/view runtime generation, transport
execution, or real provider execution.

Allowed files:
- kAir/Core/Networking/ServerProviderSearchAPIAdapterContract.swift
- kAirTests/Networking/ServerProviderSearchAPIAdapterContractTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Define pure Codable/Hashable/Sendable request/result/receipt types for a
  Search API adapter contract.
- Accept only the `.searchAPI` provider family with `.webSearch` or
  `.localServiceSearch`, public/general privacy, explicit entitlement/quota, and
  a source policy that requires citations.
- Carry trace id, connector/request id when available, provider family, capability,
  freshness, cost class, quota summary, membership/access summary, source policy,
  citation-required flag, result limit, and a sanitized typed query/context value.
- Do not carry raw user prompt text, endpoint URLs, API keys, bearer/OAuth tokens,
  SDK handles, raw page bodies, provider raw payloads, Health/private data,
  merchant-write payloads, booking/order/payment state, or UI copy that claims
  provider contact.
- Reject private/Health requests, non-search providers, Google/Gaode maps
  providers, crawler/MCP providers, cache/local providers, missing quota or
  entitlement, missing source/citation policy, stale freshness that requires live
  data, malformed connector metadata, and provider-family mismatches.
- Keep status/debug/copy advisory: "eligible", "prepared", "blocked",
  "citation required", "quota required", etc. Never use "contacted", "fetched",
  "crawled", "completed", "booked", "ordered", or "paid".

Acceptance:
- Tests cover accepted web-search and local-service-search contracts from
  eligible Search API metadata and approved connector/envelope inputs.
- Tests cover rejected Google, Gaode, crawler, MCP, Apple local, cache,
  private/Health, quota/cost block, missing entitlement, missing source/citation
  policy, stale freshness, malformed metadata, and provider-family mismatch paths.
- Encoding/status/debug tests prove no endpoint, key, token, OAuth, SDK handle,
  raw prompt, raw page body, Health/private data, merchant/order/payment payload,
  or provider raw payload appears in output.
- Static scan confirms no URLSession, endpoint URL constants, SDK imports,
  network transport, crawler/MCP runtime, SwiftUI/view/app-root generation, or
  real provider calls were added.
- Targeted tests pass, full iOS tests pass, and `git diff --check` passes.
```

Status after implementation:

`ServerProviderSearchAPIAdapterContract` now prepares Search API adapter request
values only from `.searchAPI` envelopes and A82 connector receipts that agree on
capability, cost, freshness, trace, entitlement, privacy, and citation-required
source policy. It normalizes cited result candidates into advisory result
receipts while rejecting missing citations, source mismatch, and stale cached
results for live-required requests. No network, endpoint, SDK, credential, MCP,
crawler, UI, app-root, memory, transcript, booking/order/payment, or real
provider execution was added. Targeted A86 tests pass; full iOS tests pass.

## Round A87 - Search API Adapter Receipt Status Source Proof

```text
Task: Project A86 Search API adapter request decisions and result receipts into
the existing `ProviderStatusProviding` side channel by explicit recommendation
id. This is status packaging only. Do not add URLSession, endpoint URLs, API
keys, OAuth tokens, SDK clients, Exa/Brave/Tavily/Google/Gaode calls, crawler
runtime, MCP client runtime, SwiftUI/UI, AppBootstrap/ChatStore/root wiring,
navigation, telemetry, transcript mutation, booking/order/payment, StoreKit,
memory writes, transport execution, or real provider execution.

Allowed files:
- kAir/DesignSystem/Components/ProviderStatusBadgeModel.swift
- kAirTests/DesignSystem/ProviderStatusBadgeModelTests.swift
- kAir/Core/Networking/ServerProviderSearchAPIAdapterContract.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add a small value-only status store or producer for explicit
  `(recommendationID, A86 value)` inputs. The output must conform to
  `ProviderStatusProviding` or return an existing provider-status store.
- Support both prepared request decisions and normalized result receipts.
- Preserve duplicate-id first-wins behavior and missing-id nil lookup.
- Prepared/normalized Search API values may expose advisory provider family,
  capability, cost, freshness, citation-required/source-host status, and
  limitation copy.
- Rejected request/result values must stay non-success and must not leak provider
  raw payload, endpoint, credential, raw prompt, raw page body, Health/private
  data, merchant-write payload, or booking/order/payment state.
- Status copy must remain advisory: "prepared", "blocked", "citation required",
  "source policy required", etc. Never use "contacted", "fetched", "crawled",
  "completed", "booked", "ordered", or "paid".

Acceptance:
- Tests prove accepted A86 request decisions and normalized result receipts can
  be looked up by explicit rendered recommendation id through
  `ProviderStatusProviding`.
- Tests prove rejected A86 values produce non-success advisory status without
  provider metadata leakage.
- Tests prove duplicate recommendation ids keep the first value and missing ids
  return nil.
- Encoding/status/debug tests prove no endpoint, key, token, OAuth, SDK handle,
  raw prompt, raw page body, Health/private data, merchant/order/payment payload,
  or provider raw payload appears.
- Static scan confirms no URLSession, endpoint URL constants, SDK imports,
  network transport, crawler/MCP runtime, SwiftUI/view/app-root generation, or
  real provider calls were added.
- Targeted tests pass, full iOS tests pass, and `git diff --check` passes.
```

Status after implementation:

`SearchAPIAdapterProviderStatusStore` now accepts explicit recommendation-id
pairs containing A86 request decisions or result receipts and exposes them
through `ProviderStatusProviding`. Prepared request decisions and normalized
result receipts render advisory Search API provider/cost/freshness/citation
status; rejected values render disabled non-success status without remote provider
or cost badges. Duplicate ids keep the first value and missing ids return nil.
No UI, AppBootstrap/ChatStore/root wiring, transport, crawler/MCP, endpoint,
credential, or real provider execution was added. Targeted A87 tests pass; full
iOS tests pass.

## Round A88 - Search API Adapter Status App-Root Handoff Proof

```text
Task: Prove that A87 Search API adapter status sources can pass through
`AppBootstrap(providerStatusSources:)` and ChatStore provider-status lookup while
remaining rendered-id scoped. This is test/composition proof only. Do not add
URLSession, endpoint URLs, API keys, OAuth tokens, SDK clients,
Exa/Brave/Tavily/Google/Gaode calls, crawler runtime, MCP client runtime,
SwiftUI/UI layout changes, production AppBootstrap/ChatStore/root runtime
generation, navigation, telemetry, transcript mutation, booking/order/payment,
StoreKit, memory writes, transport execution, or real provider execution.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Build A87 `SearchAPIAdapterProviderStatusStore` values in tests from
  hand-authored A86 request decisions/result receipts.
- Pass the precomputed source through `AppBootstrap(providerStatusSources:)`.
- Prove ChatStore can read prepared and normalized Search API adapter status only
  for rendered recommendation ids.
- Prove hidden store ids remain nil before app-root injection, at app-root lookup,
  and after ChatStore lookup.
- Prove rejected A86 status remains disabled/non-success and advisory only.
- Prove provider-status source order remains deterministic when an A87 source is
  composed with another source.

Acceptance:
- Tests prove prepared request and normalized result status survive app-root
  provider-status composition for rendered recommendation ids only.
- Tests prove hidden ids return nil before app-root injection, at app-root lookup,
  and after ChatStore lookup.
- Tests prove rejected A86 values remain non-success and do not leak endpoint,
  credential, raw prompt, raw page body, Health/private data, merchant/order/
  payment payload, provider raw payload, or provider execution claims.
- Tests prove source-order first-wins behavior is unchanged.
- Static scan confirms no URLSession, endpoint URL constants, SDK imports,
  network transport, crawler/MCP runtime, SwiftUI/view/root generation, or real
  provider calls were added.
- Targeted AppBootstrap tests pass, full iOS tests pass, and `git diff --check`
  passes.
```

Status after implementation:

`AppBootstrapTests` now proves A87 `SearchAPIAdapterProviderStatusStore` values
can pass through `AppBootstrap(providerStatusSources:)` and ChatStore lookup for
rendered recommendation ids. Prepared request and normalized result status
survive the handoff; rejected request/result values remain disabled and advisory;
hidden ids return nil before app-root injection, at app-root lookup, and after
ChatStore lookup; source order remains first-wins. No production AppBootstrap,
ChatStore, SwiftUI, transport, crawler/MCP, endpoint, credential, or provider
runtime code was added. Targeted A88 AppBootstrap tests pass; full iOS tests
pass.

## Round A89 - Search API Adapter Status Source Producer Guard

```text
Task: Add a value-only Search API adapter status source producer that packages
A86 request decisions/result receipts into the A87 provider-status store and
wraps the store behind explicit rendered recommendation ids before app-root
injection. This is producer/test proof only. Do not add URLSession, endpoint
URLs, API keys, OAuth tokens, SDK clients, Exa/Brave/Tavily/Google/Gaode calls,
crawler runtime, MCP client runtime, SwiftUI/UI layout changes, production
AppBootstrap/ChatStore/root runtime generation, navigation, telemetry,
transcript mutation, booking/order/payment, StoreKit, memory writes, transport
execution, or real provider execution.

Allowed files:
- kAir/Core/Networking/ServerProviderSearchAPIAdapterStatusSourceProducer.swift
- kAirTests/Networking/ServerProviderSearchAPIAdapterStatusSourceProducerTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add a `ServerProviderSearchAPIAdapterStatusSourceProducer` value producer with
  typed inputs for request decisions and result receipts.
- The producer must build `SearchAPIAdapterProviderStatusStore` values and return
  a rendered-id guarded `ProviderStatusProviding` source using explicit rendered
  recommendation ids.
- Preserve first-entry duplicate behavior from A87.
- Keep missing ids nil and hidden non-rendered ids nil even when caller supplies
  hidden Search API adapter values.
- Keep status copy advisory: prepared/normalized/blocked metadata only.

Acceptance:
- Tests prove request-decision and result-receipt inputs produce the same A87
  prepared/normalized status for rendered ids.
- Tests prove hidden supplied ids return nil before any app-root handoff.
- Tests prove rejected request/result inputs remain disabled/non-success and do
  not expose endpoint, credential, raw prompt, raw page body, Health/private data,
  merchant/order/payment payload, provider raw payload, or provider execution
  claims.
- Tests prove duplicate recommendation ids keep the first value.
- Static scan confirms no URLSession, endpoint URL constants, SDK imports,
  network transport, crawler/MCP runtime, SwiftUI/view/root generation, or real
  provider calls were added.
- Targeted producer tests pass, full iOS tests pass, and `git diff --check`
  passes.
```

Status after implementation:

`ServerProviderSearchAPIAdapterStatusSourceProducer` now accepts typed
request-decision/result-receipt inputs, converts them into
`SearchAPIAdapterProviderStatusStore` values, and returns a rendered-id guarded
`ProviderStatusProviding` source. Tests prove producer output matches A87 store
presentations for rendered prepared/normalized values, hidden supplied ids return
nil before app-root handoff, rejected request/result values stay
disabled/non-success/advisory, and duplicate recommendation ids keep the first
input. No UI, AppBootstrap/ChatStore/root wiring, transport, crawler/MCP,
endpoint, credential, or real provider execution was added. Targeted A89 producer
tests pass; full iOS tests pass.

## Round A90 - Search API Adapter Producer Guard App-Root Handoff Proof

```text
Task: Prove the A89 producer-built guarded Search API adapter status source can
pass through `AppBootstrap(providerStatusSources:)` and ChatStore lookup while
remaining rendered-id scoped. This is test/composition proof only. Do not add
URLSession, endpoint URLs, API keys, OAuth tokens, SDK clients,
Exa/Brave/Tavily/Google/Gaode calls, crawler runtime, MCP client runtime,
SwiftUI/UI layout changes, production AppBootstrap/ChatStore/root runtime
generation, navigation, telemetry, transcript mutation, booking/order/payment,
StoreKit, memory writes, transport execution, or real provider execution.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Build an A89 `ServerProviderSearchAPIAdapterStatusSourceProducer` source in
  `AppBootstrapTests` from hand-authored A86 request decisions/result receipts.
- Pass the producer-built guarded source through
  `AppBootstrap(providerStatusSources:)`.
- Prove ChatStore reads prepared and normalized Search API adapter status only
  for rendered recommendation ids.
- Prove hidden supplied ids remain nil before app-root injection, at app-root
  lookup, and after ChatStore lookup.
- Prove rejected request/result status remains disabled/non-success and advisory
  only.
- Prove provider-status source order remains deterministic when the producer
  source is composed with another source.

Acceptance:
- Tests prove prepared request and normalized result status survive app-root
  provider-status composition for rendered recommendation ids only.
- Tests prove hidden supplied ids return nil before app-root injection, at
  app-root lookup, and after ChatStore lookup.
- Tests prove rejected A86 request/result values remain non-success and do not
  expose endpoint, credential, raw prompt, raw page body, Health/private data,
  merchant/order/payment payload, provider raw payload, or provider execution
  claims.
- Tests prove source-order first-wins behavior is unchanged.
- Static scan confirms no URLSession, endpoint URL constants, SDK imports,
  network transport, crawler/MCP runtime, SwiftUI/view/root generation, or real
  provider calls were added.
- Targeted AppBootstrap tests pass, full iOS tests pass, and `git diff --check`
  passes.
```

Status after implementation:

`AppBootstrapTests` now proves the A89 producer-built guarded Search API adapter
status source passes through `AppBootstrap(providerStatusSources:)` and ChatStore
lookup for rendered recommendation ids. Prepared request and normalized result
status survive the handoff; rejected request/result values remain disabled and
advisory; hidden supplied ids return nil before app-root injection, at app-root
lookup, and after ChatStore lookup; source order remains first-wins. No
production AppBootstrap, ChatStore, SwiftUI, transport, crawler/MCP, endpoint,
credential, or provider runtime code was added. Targeted A90 AppBootstrap tests
pass; full iOS tests pass.

## Round A91 - Search API Adapter Transport Payload Boundary Proof

```text
Task: Add a value-only Search API adapter transport payload boundary that derives
an outbound-safe request payload from a prepared A86 Search API adapter request.
This is contract/test proof only. Do not add URLSession, endpoint URLs, API
keys, OAuth tokens, SDK clients, Exa/Brave/Tavily/Google/Gaode calls, crawler
runtime, MCP client runtime, SwiftUI/UI layout changes, production
AppBootstrap/ChatStore/root runtime generation, navigation, telemetry,
transcript mutation, booking/order/payment, StoreKit, memory writes, transport
execution, or real provider execution.

Allowed files:
- kAir/Core/Networking/ServerProviderSearchAPIAdapterPayload.swift
- kAirTests/Networking/ServerProviderSearchAPIAdapterPayloadTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add pure payload structs that copy only approved A86 request metadata:
  request id, trace id, query text/locale hint, result limit, capability,
  freshness, cost class, citation/source policy snapshot, and provider family.
- Add a pure builder that accepts `ServerProviderSearchAPIAdapterRequestDecision`
  or `ServerProviderSearchAPIAdapterRequest` and returns prepared/rejected
  payload decisions without executing transport.
- Rejected A86 request decisions must not produce a payload.
- Payload/debug/encoded copy must stay advisory and must not include endpoint
  URLs, credentials, tokens, SDK identifiers, raw prompt/page/provider payload,
  Health/private data, merchant/order/payment data, or execution-complete claims.

Acceptance:
- Tests prove prepared A86 request decisions build deterministic payloads.
- Tests prove rejected A86 request decisions do not build payloads and preserve
  deterministic rejection reasons.
- Tests prove payload values preserve source/citation/freshness/cost metadata
  needed for future Search API execution gates.
- Tests prove encoded/debug/status copy does not expose endpoint, credential, raw
  prompt, raw page body, Health/private data, merchant/order/payment payload,
  provider raw payload, or provider execution claims.
- Static scan confirms no URLSession, endpoint URL constants, SDK imports,
  network transport, crawler/MCP runtime, SwiftUI/view/root generation, or real
  provider calls were added.
- Targeted payload tests pass, full iOS tests pass, and `git diff --check`
  passes.
```

Status after implementation:

`ServerProviderSearchAPIAdapterPayloadBuilder` now derives value-only
`ServerProviderSearchAPIAdapterTransportPayload` decisions from prepared A86
requests, copying only request id, trace id, query text/locale hint, result
limit, capability, freshness, cost class, source/citation policy snapshot, and
provider family. Rejected A86 decisions produce no payload and preserve the
request-decision rejection reason. Direct request payload building rejects unsafe
provider, capability, privacy, quota, result-limit, source-policy, citation, and
empty-query metadata. Encoded/debug/status copy remains advisory and carries no
endpoint, credential, SDK, raw provider/page/prompt content, Health/private data,
commerce data, or provider execution claim. Targeted A91 payload tests pass.

## Round A92 - Search API Adapter Payload Dispatch Gate Proof

```text
Task: Add a value-only Search API adapter payload dispatch gate that consumes an
A91 payload decision plus its original A86 request and returns an advisory
dispatch eligibility receipt. This is contract/test proof only. Do not add
URLSession, endpoint URLs, API keys, OAuth tokens, SDK clients,
Exa/Brave/Tavily/Google/Gaode calls, crawler runtime, MCP client runtime,
SwiftUI/UI layout changes, production AppBootstrap/ChatStore/root runtime
generation, navigation, telemetry, transcript mutation, booking/order/payment,
StoreKit, memory writes, transport execution, or real provider execution.

Allowed files:
- kAir/Core/Networking/ServerProviderSearchAPIAdapterPayloadDispatchGate.swift
- kAirTests/Networking/ServerProviderSearchAPIAdapterPayloadDispatchGateTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add pure dispatch gate structs/enums, e.g. eligible/blocked state, rejection
  reasons, and a receipt carrying only payload/request ids, trace id, provider
  family, capability, freshness, cost class, result limit, and source/citation
  gate snapshot.
- Add a pure gate function that accepts
  `ServerProviderSearchAPIAdapterPayloadDecision` and
  `ServerProviderSearchAPIAdapterRequest`.
- Mark eligible only when the payload decision is prepared, payload is present,
  ids/trace/provider/capability/freshness/cost/result-limit/query/source-policy
  all match the request, request privacy remains `.general`, quota remains
  allowed, source policy remains approved, and citation policy remains required.
- Rejected/missing/mismatched payload decisions must return blocked receipts
  with deterministic reasons and no transport execution.
- Receipt/debug/encoded copy must stay advisory and must not include endpoint
  URLs, credentials, tokens, SDK identifiers, raw prompt/page/provider payload,
  Health/private data, merchant/order/payment data, or execution-complete claims.

Acceptance:
- Tests prove prepared A91 payloads matching their A86 request become
  deterministic eligible receipts.
- Tests prove rejected/missing payload decisions never become eligible and
  preserve deterministic rejection reasons.
- Tests prove id/trace/provider/capability/freshness/cost/result-limit/query and
  source/citation mismatches block dispatch eligibility.
- Tests prove encoded/debug/status copy does not expose endpoint, credential, raw
  prompt, raw page body, Health/private data, merchant/order/payment payload,
  provider raw payload, or provider execution claims.
- Static scan confirms no URLSession, endpoint URL constants, SDK imports,
  network transport, crawler/MCP runtime, SwiftUI/view/root generation, or real
  provider calls were added.
- Targeted dispatch-gate tests pass, full iOS tests pass, and `git diff
  --check` passes.
```

Status after implementation:

`ServerProviderSearchAPIAdapterPayloadDispatchGate` now produces value-only
advisory dispatch receipts from A91 payload decisions and their original A86
requests. Matching prepared payloads become deterministic `dispatchEligible`
receipts carrying ids, trace/provider/capability/freshness/cost/result-limit, and
source/citation snapshot only. Rejected/missing payload decisions, mismatched
metadata, and unsafe forged request metadata all produce blocked receipts with
deterministic reasons. Receipt encoded/debug/status copy does not carry query
text, endpoints, credentials, SDK identifiers, raw provider/page/prompt content,
Health/private data, commerce data, or provider execution claims. Targeted A92
dispatch-gate tests pass.

## Round A93 - Search API Adapter Payload Dispatch Status Source Proof

```text
Task: Package A92 Search API adapter payload dispatch receipts into the existing
provider-status side channel by explicit rendered recommendation id. This is
contract/test proof only. Do not add URLSession, endpoint URLs, API keys, OAuth
tokens, SDK clients, Exa/Brave/Tavily/Google/Gaode calls, crawler runtime, MCP
client runtime, SwiftUI/UI layout changes, production AppBootstrap/ChatStore/root
runtime generation, navigation, telemetry, transcript mutation,
booking/order/payment, StoreKit, memory writes, transport execution, or real
provider execution.

Allowed files:
- kAir/Core/Networking/ServerProviderSearchAPIAdapterPayloadDispatchStatusSourceProducer.swift
- kAirTests/Networking/ServerProviderSearchAPIAdapterPayloadDispatchStatusSourceProducerTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add a pure producer/input type that accepts
  `ServerProviderSearchAPIAdapterPayloadDispatchReceipt` values plus explicit
  rendered recommendation ids.
- Return a provider-status source/store that exposes only explicitly supplied
  rendered recommendation ids; hidden or missing ids must return nil.
- Map `.dispatchEligible` receipts to an advisory dispatch-ready provider status
  that does not imply provider contact, fetched data, or task completion.
- Map `.blocked` receipts to non-success/advisory status that preserves the
  deterministic rejection reason and payload/request ids without leaking query
  text.
- Duplicate rendered recommendation ids must be deterministic first-wins.
- Status/debug/encoded copy must stay advisory and must not include endpoint
  URLs, credentials, tokens, SDK identifiers, raw prompt/page/provider payload,
  Health/private data, merchant/order/payment data, or execution-complete claims.

Acceptance:
- Tests prove eligible A92 dispatch receipts package into advisory
  dispatch-ready provider status for explicit rendered ids.
- Tests prove blocked A92 dispatch receipts package into non-success/advisory
  provider status with deterministic rejection copy.
- Tests prove duplicate ids keep first input and missing/hidden ids return nil.
- Tests prove encoded/debug/status copy does not expose endpoint, credential, raw
  prompt, raw page body, Health/private data, merchant/order/payment payload,
  provider raw payload, or provider execution claims.
- Static scan confirms no URLSession, endpoint URL constants, SDK imports,
  network transport, crawler/MCP runtime, SwiftUI/view/root generation, or real
  provider calls were added.
- Targeted dispatch status-source tests pass, full iOS tests pass, and `git
  diff --check` passes.
```

Status after implementation:

`ServerProviderSearchAPIAdapterPayloadDispatchStatusSourceProducer` now packages
A92 payload dispatch receipts into a rendered-id scoped provider-status source.
Eligible receipts present dispatch-ready metadata as advisory status with remote,
cost, and freshness badges; blocked receipts present disabled/non-success status
with deterministic dispatch, payload-decision, and request-decision rejection
copy. Hidden and missing rendered ids return nil, duplicate recommendation ids
remain first-wins, and status copy carries no query text, endpoint, credential,
SDK, raw provider/page/prompt content, Health/private data, commerce data, or
provider execution claims. Targeted A93 dispatch status-source tests pass.

## Round A94 - Search API Adapter Payload Dispatch Status App-Root Handoff Proof

```text
Task: Prove the A93 Search API adapter payload dispatch status source can pass
through app-root provider-status composition and ChatStore lookup while remaining
rendered-id scoped. This is test proof only. Do not change production
AppBootstrap, ChatStore runtime behavior, SwiftUI/UI layout, navigation,
telemetry, transcript mutation, URLSession, endpoint URLs, API keys, OAuth
tokens, SDK clients, Exa/Brave/Tavily/Google/Gaode calls, crawler runtime, MCP
client runtime, booking/order/payment, StoreKit, memory writes, transport
execution, or real provider execution.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add focused AppBootstrap tests that build an A93 dispatch status source from
  eligible, blocked, and hidden A92 receipts, then inject it through
  `AppBootstrap(providerStatusSources:)`.
- Prove ChatStore can read eligible and blocked rendered recommendation ids
  through the composed provider-status source.
- Prove hidden supplied ids and missing ids return nil before app-root
  injection, at app-root lookup, and after ChatStore lookup.
- Prove blocked dispatch receipts remain `.disabled` / non-success advisory and
  do not become accepted/successful provider output.
- Prove source order remains deterministic first-wins if an earlier status
  source already owns the rendered id.

Acceptance:
- Tests prove app-root composition preserves eligible A93 dispatch status for
  rendered ids and keeps hidden ids nil.
- Tests prove ChatStore lookup reads the app-root composed A93 dispatch status
  for rendered ids only.
- Tests prove blocked A93 dispatch status remains disabled/advisory and carries
  deterministic rejection copy without query text.
- Tests prove source order is first-wins when A93 is composed with existing
  provider-status sources.
- Static scan confirms no URLSession, endpoint URL constants, SDK imports,
  network transport, crawler/MCP runtime, SwiftUI/view/root generation, or real
  provider calls were added.
- Targeted AppBootstrap tests pass, full iOS tests pass, and `git diff --check`
  passes.
```

Status after implementation:

`AppBootstrapTests` now proves an A93 payload dispatch status source can pass
through app-root `providerStatusSources` composition and ChatStore lookup. The
rendered eligible dispatch status stays advisory and dispatch-ready, the rendered
blocked status stays disabled/non-success with deterministic rejection copy,
hidden supplied ids stay nil before app-root injection, at app-root lookup, and
after ChatStore lookup, and source order remains first-wins. No production
AppBootstrap, ChatStore, SwiftUI, transport, endpoint, credential, SDK,
crawler/MCP, telemetry, transcript, or provider runtime code was changed.
Targeted A94 AppBootstrap tests pass.

## Round A95 - Search API Adapter Cross-Stage Status Composition Proof

```text
Task: Prove A93 Search API adapter payload dispatch status composes
deterministically with earlier Search API adapter request/result status sources
through app-root provider-status composition and ChatStore lookup. This is test
proof only. Do not change production AppBootstrap, ChatStore runtime behavior,
SwiftUI/UI layout, navigation, telemetry, transcript mutation, URLSession,
endpoint URLs, API keys, OAuth tokens, SDK clients, Exa/Brave/Tavily/Google/Gaode
calls, crawler runtime, MCP client runtime, booking/order/payment, StoreKit,
memory writes, transport execution, or real provider execution.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add focused AppBootstrap tests that build both an A89/A90
  `ServerProviderSearchAPIAdapterStatusSourceProducer` source and an A93
  `ServerProviderSearchAPIAdapterPayloadDispatchStatusSourceProducer` source for
  the same rendered recommendation id.
- Compose them through `AppBootstrap(providerStatusSources:)` in both source
  orders and mirror `ChatHomeView.init(bootstrap:)` with `ChatStore`.
- Prove first-wins ordering: request/result status wins when it is first, and
  dispatch status wins when it is first.
- Prove hidden ids from either source stay nil before app-root injection, at
  app-root lookup, and after ChatStore lookup.
- Prove selected status stays advisory and does not combine stale details from
  the second source.

Acceptance:
- Tests prove A89/A90 request/result status first hides A93 dispatch status for
  the same rendered id.
- Tests prove A93 dispatch status first hides A89/A90 request/result status for
  the same rendered id.
- Tests prove hidden ids from both sources remain nil at source, app-root, and
  ChatStore lookup.
- Tests prove selected status copy remains advisory, has no query text, and does
  not include stale details from the non-selected source.
- Static scan confirms no URLSession, endpoint URL constants, SDK imports,
  network transport, crawler/MCP runtime, SwiftUI/view/root generation, or real
  provider calls were added.
- Targeted AppBootstrap tests pass, full iOS tests pass, and `git diff --check`
  passes.
```

Status after implementation:

`AppBootstrapTests` now proves A89/A90 Search API adapter request/result status
and A93 payload dispatch status compose deterministically through app-root
`providerStatusSources` and ChatStore lookup. The same rendered recommendation
ids are covered in both source orders: request/result status wins when it is
first, dispatch status wins when it is first, hidden ids from both sources stay
nil before app-root injection, at app-root lookup, and after ChatStore lookup,
and selected advisory copy does not merge stale details or query text from the
second source. No production AppBootstrap, ChatStore, SwiftUI, transport,
endpoint, credential, SDK, crawler/MCP, telemetry, transcript, memory, or
provider runtime code was changed. Targeted A95 AppBootstrap test and full iOS
suite pass.

## Round A96 - Search API Adapter Fixture Transport Bridge Contract

```text
Task: Add a value-only fixture transport bridge contract for Search API adapter
payload dispatch. The bridge may consume an A86 prepared request decision, an
A91 payload decision, and an A92 dispatch receipt, then produce an audit-only
fixture response. It must not add URLSession, endpoint URLs, API keys, OAuth
tokens, SDK clients, Exa/Brave/Tavily/Google/Gaode calls, crawler runtime, MCP
client runtime, AppBootstrap/ChatStore wiring, SwiftUI/UI layout, navigation,
telemetry, transcript mutation, memory writes, booking/order/payment, StoreKit,
or real provider execution.

Allowed files:
- kAir/Core/Networking/ServerProviderSearchAPIAdapterFixtureTransportBridge.swift
- kAirTests/Networking/ServerProviderSearchAPIAdapterFixtureTransportBridgeTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add small value types for bridge input/output and deterministic rejection
  reasons.
- Accept only when the request is prepared, payload is prepared, dispatch is
  eligible, provider family is `.searchAPI`, ids/trace/capability/cost/freshness
  metadata match, source policy is approved, and citation policy is present.
- Reject missing, blocked, mismatched, private, quota-blocked, or malformed
  inputs without producing a fixture success.
- Output copy must say fixture/audit metadata only and must not imply provider
  contact, crawling, payment, booking, or transport execution.
- Do not wire the bridge into AppBootstrap, ChatStore, SwiftUI, navigation,
  telemetry, search execution, crawler/MCP, or real transport.

Acceptance:
- Eligible A86/A91/A92 metadata produces one fixture/audit response with stable
  ids and no provider execution claim.
- Rejected request, rejected payload, blocked dispatch, and mismatched metadata
  all produce deterministic non-success reasons.
- Encoding/debug/status copy does not expose endpoint URLs, credentials, OAuth,
  SDK names, private/Health data, raw provider content, booking/order/payment,
  or real provider execution claims.
- Static scan confirms no URLSession, endpoint URL constants, SDK imports,
  network transport, crawler/MCP runtime, SwiftUI/view/root generation, or real
  provider calls were added.
- Targeted networking tests pass, full iOS tests pass, and `git diff --check`
  passes.
```

Status after implementation:

`ServerProviderSearchAPIAdapterFixtureTransportBridge` now consumes A86 prepared
request decisions, A91 payload decisions, and A92 dispatch receipts to produce
fixture audit metadata only. It accepts only prepared request, prepared payload,
eligible dispatch, matching ids/trace/capability/cost/freshness/source policy,
general privacy, allowed quota, and citation policy. Rejected request, rejected
payload, missing payload, blocked dispatch, and mismatched metadata produce
deterministic non-success reasons. The bridge output does not carry query text,
endpoint, credential, SDK, raw provider content, private/Health data,
booking/order/payment data, crawler/MCP runtime, AppBootstrap/ChatStore/UI
wiring, or real provider execution. Targeted A96 networking tests and the full
iOS suite pass.

## Round A97 - Search API Adapter Fixture Bridge Status Source Producer

```text
Task: Package A96 Search API adapter fixture bridge responses into a rendered-id
scoped provider-status source. This is status projection only. Do not change
production AppBootstrap, ChatStore runtime behavior, SwiftUI/UI layout,
navigation, telemetry, transcript mutation, URLSession, endpoint URLs, API keys,
OAuth tokens, SDK clients, Exa/Brave/Tavily/Google/Gaode calls, crawler runtime,
MCP client runtime, booking/order/payment, StoreKit, memory writes, transport
execution, or real provider execution.

Allowed files:
- kAir/Core/Networking/ServerProviderSearchAPIAdapterFixtureTransportStatusSourceProducer.swift
- kAirTests/Networking/ServerProviderSearchAPIAdapterFixtureTransportStatusSourceProducerTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add a value-only producer that accepts explicit recommendation ids plus A96
  `ServerProviderSearchAPIAdapterFixtureTransportBridgeResponse` values.
- Wrap the underlying status store with `ServerProviderRenderedRuntimeStatusSource`
  so only explicit rendered ids are visible.
- Ready fixture responses should produce advisory provider-status copy with
  remote/cost/freshness/source context and no provider execution claim.
- Rejected responses should produce disabled/non-success status with the A96
  rejection reason chain and no query/raw content.
- Preserve duplicate first-wins behavior, sorted rendered ids, missing-id nil
  lookup, and hidden supplied-id nil lookup.
- Do not wire the producer into AppBootstrap, ChatStore, SwiftUI, navigation,
  telemetry, search execution, crawler/MCP, or real transport.

Acceptance:
- Tests prove ready A96 fixture bridge responses package as advisory status for
  rendered ids only.
- Tests prove rejected A96 bridge responses package as disabled/non-success
  advisory status without provider metadata leakage.
- Tests prove duplicate recommendation ids keep the first response and missing
  or hidden ids return nil.
- Tests prove status copy has no query text and does not imply provider contact,
  crawling, booking, payment, transport execution, or real provider execution.
- Static scan confirms no URLSession, endpoint URL constants, SDK imports,
  network transport, crawler/MCP runtime, SwiftUI/view/root generation, or real
  provider calls were added.
- Targeted networking tests pass, full iOS tests pass, and `git diff --check`
  passes.
```

Status after implementation:

`ServerProviderSearchAPIAdapterFixtureTransportStatusSourceProducer` now packages
A96 fixture bridge responses into a rendered-id scoped provider-status source.
Ready responses show advisory fixture/audit metadata with remote, cost,
freshness, and source context; rejected responses show disabled non-success
reason chains; duplicate recommendation ids keep the first response; hidden and
missing ids return nil; status copy does not include query text or imply
provider contact, crawling, booking, payment, transport execution, or real
provider execution. Targeted A97 networking tests and the full iOS suite pass.

## Round A98 - Search API Adapter Fixture Bridge Status App-Root Handoff Proof

```text
Task: Prove A97 Search API adapter fixture bridge status sources pass through
app-root provider-status composition and ChatStore lookup for rendered
recommendation ids only. This is test proof only. Do not change production
AppBootstrap, ChatStore runtime behavior, SwiftUI/UI layout, navigation,
telemetry, transcript mutation, URLSession, endpoint URLs, API keys, OAuth
tokens, SDK clients, Exa/Brave/Tavily/Google/Gaode calls, crawler runtime, MCP
client runtime, booking/order/payment, StoreKit, memory writes, transport
execution, or real provider execution.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add focused AppBootstrap tests that build A97 fixture bridge status sources
  with ready, rejected, and hidden A96 responses.
- Inject the source through `AppBootstrap(providerStatusSources:)` and mirror
  `ChatHomeView.init(bootstrap:)` with `ChatStore`.
- Prove rendered ready/rejected statuses survive pre-bootstrap lookup,
  app-root lookup, and ChatStore lookup.
- Prove hidden ids remain nil before app-root injection, at app-root lookup,
  and after ChatStore lookup.
- Prove source order remains first-wins when A97 is composed with another
  provider-status source.
- Do not wire the producer into production AppBootstrap, ChatStore, SwiftUI,
  navigation, telemetry, search execution, crawler/MCP, or real transport.

Acceptance:
- Tests prove A97 ready fixture status reaches ChatStore for rendered ids only.
- Tests prove A97 rejected fixture status reaches ChatStore as disabled
  non-success advisory copy.
- Tests prove hidden ids are nil at source, app-root, and ChatStore lookup.
- Tests prove source order is first-wins when A97 is composed with existing
  provider-status sources.
- Static scan confirms no URLSession, endpoint URL constants, SDK imports,
  network transport, crawler/MCP runtime, SwiftUI/view/root generation, or real
  provider calls were added.
- Targeted AppBootstrap tests pass, full iOS tests pass, and `git diff --check`
  passes.
```

Status after implementation:

A97 fixture bridge status sources now pass through
`AppBootstrap(providerStatusSources:)` and ChatStore lookup for rendered ids
only. Ready fixture status stays advisory with remote/cost/freshness/source
context, rejected fixture status stays disabled non-success copy, hidden ids
return nil at source/root/store lookup, and source order remains first-wins
without production AppBootstrap, ChatStore runtime, SwiftUI, endpoint,
credential, SDK, crawler/MCP, transport, or real-provider wiring. Targeted A98
AppBootstrap tests and the full iOS suite pass.

## Round A99 - Search API Adapter Fixture Bridge Cross-Stage Status Composition Proof

```text
Task: Prove A97 Search API adapter fixture bridge status composes
deterministically with earlier A89/A90 request/result status and A93 dispatch
status through app-root provider-status composition and ChatStore lookup. This
is test proof only. Do not change production AppBootstrap, ChatStore runtime
behavior, SwiftUI/UI layout, navigation, telemetry, transcript mutation,
URLSession, endpoint URLs, API keys, OAuth tokens, SDK clients,
Exa/Brave/Tavily/Google/Gaode calls, crawler runtime, MCP client runtime,
booking/order/payment, StoreKit, memory writes, transport execution, or real
provider execution.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add focused AppBootstrap tests that build one A97 fixture bridge status
  source, one A89/A90 Search API adapter request/result status source, and one
  A93 payload dispatch status source for the same rendered recommendation ids.
- Inject sources through `AppBootstrap(providerStatusSources:)` in both
  fixture-first and earlier-stage-first orders, then mirror
  `ChatHomeView.init(bootstrap:)` with `ChatStore`.
- Prove first-wins selection at app-root and ChatStore lookup in both orders.
- Prove hidden ids from every source remain nil at source, root, and store
  lookup.
- Prove selected advisory copy does not merge stale details, query text, hidden
  source hosts, or execution claims from lower-priority sources.
- Do not wire the producer into production AppBootstrap, ChatStore, SwiftUI,
  navigation, telemetry, search execution, crawler/MCP, or real transport.

Acceptance:
- Tests prove A97 fixture status wins over A89/A90 and A93 details when it is
  first.
- Tests prove A89/A90 or A93 status wins over A97 fixture status when it is
  first.
- Tests prove hidden ids are nil across source, app-root, and ChatStore lookup.
- Tests prove selected status text contains only the selected source details and
  no stale hosts/query/execution copy from lower-priority sources.
- Static scan confirms no URLSession, endpoint URL constants, SDK imports,
  network transport, crawler/MCP runtime, SwiftUI/view/root generation, or real
  provider calls were added.
- Targeted AppBootstrap tests pass, full iOS tests pass, and `git diff --check`
  passes.
```

Status after implementation:

A97 fixture bridge status now composes deterministically with A89/A90
request/result status and A93 dispatch status through
`AppBootstrap(providerStatusSources:)` and ChatStore lookup. Fixture-first keeps
fixture audit copy, adapter-first keeps request/result copy, dispatch-first
keeps dispatch-ready copy, hidden ids from all three sources remain nil at
source/root/store lookup, and selected status text does not mix query, hidden
host, stale lower-priority details, or execution claims. Targeted A99
AppBootstrap tests and the full iOS suite pass.

## Round A100 - Search API Adapter Cost and Entitlement Status Matrix Proof

```text
Task: Prove Search API adapter cost and entitlement outcomes remain explicit
across A86 request decisions, A91 payloads, A92 dispatch receipts, A96 fixture
bridge responses, and A97 provider-status copy. This is test proof only. Do not
change production transport, AppBootstrap, ChatStore runtime behavior,
SwiftUI/UI layout, navigation, telemetry, transcript mutation, URLSession,
endpoint URLs, API keys, OAuth tokens, SDK clients,
Exa/Brave/Tavily/Google/Gaode calls, crawler runtime, MCP client runtime,
booking/order/payment, StoreKit, memory writes, transport execution, or real
provider execution.

Allowed files:
- kAirTests/Networking/ServerProviderSearchAPIAdapterFixtureTransportStatusSourceProducerTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add focused networking tests that build Search API adapter chains for
  included-quota, metered-premium, missing-entitlement, blocked-cost, and
  private-privacy cases.
- For allowed cases, prove request -> payload -> dispatch -> fixture bridge
  remains accepted and that A97 status copy preserves the cost badge/tone.
- For blocked cases, prove the chain remains non-success before any fixture
  ready state and that status copy is disabled/non-success with the exact
  rejection reason preserved.
- Prove no case silently upgrades a free/local or blocked path into
  metered-premium eligibility.
- Prove status text does not include endpoint, credential, raw provider, query,
  payment, booking, crawler/MCP runtime, transport-execution, or real-provider
  claims.
- Do not wire the producer into production AppBootstrap, ChatStore, SwiftUI,
  navigation, telemetry, search execution, crawler/MCP, or real transport.

Acceptance:
- Tests prove included-quota and metered-premium allowed paths keep distinct
  cost status instead of collapsing into one generic remote-provider state.
- Tests prove missing-entitlement, blocked-cost, and private-privacy paths stay
  rejected/non-success through status copy.
- Tests prove no blocked case creates fixture-ready status, dispatch-eligible
  status, or premium-metered copy.
- Static scan confirms no URLSession, endpoint URL constants, SDK imports,
  network transport, crawler/MCP runtime, SwiftUI/view/root generation,
  StoreKit/payment, or real provider calls were added.
- Targeted networking tests pass, full iOS tests pass, and `git diff --check`
  passes.
```

Status after implementation:

Search API adapter cost and entitlement outcomes now remain explicit across A86
request decisions, A91 payloads, A92 dispatch receipts, A96 fixture bridge
responses, and A97 provider-status copy. Included-quota and metered-premium
allowed paths keep distinct status badges/copy, while missing-entitlement,
blocked-cost, private-privacy, and free-local paths stay rejected or blocked
without fixture-ready status, dispatch eligibility, premium-metered status, or
provider execution. Targeted A100 networking tests and the full iOS suite pass.

## Round A101 - Search API Adapter Source Citation Attribution Status Matrix Proof

```text
Task: Prove Search API adapter source, citation, and attribution outcomes
remain explicit across A86 request decisions, A91 payloads, A92 dispatch
receipts, A96 fixture bridge responses, and A97 provider-status copy. This is
test proof only. Do not change production transport, AppBootstrap, ChatStore
runtime behavior, SwiftUI/UI layout, navigation, telemetry, transcript
mutation, URLSession, endpoint URLs, API keys, OAuth tokens, SDK clients,
Exa/Brave/Tavily/Google/Gaode calls, crawler runtime, MCP client runtime,
booking/order/payment, StoreKit, memory writes, raw page content, transport
execution, or real provider execution.

Allowed files:
- kAirTests/Networking/ServerProviderSearchAPIAdapterFixtureTransportStatusSourceProducerTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add focused networking tests that build Search API adapter chains for
  accepted cited source metadata, source-policy blocked metadata, citation
  policy missing metadata, result citation missing metadata, and result citation
  source mismatch metadata.
- For accepted cited source metadata, prove request -> payload -> dispatch ->
  fixture bridge remains accepted and A97 status copy includes only the
  selected public source host plus citation-required/source-policy metadata.
- For blocked request/payload/dispatch/bridge cases, prove non-success state
  and exact source/citation rejection reason are preserved through status copy.
- Prove hidden or mismatched source hosts do not leak into selected status text.
- Prove status text does not include endpoint, credential, raw provider, raw
  page content, query, payment, booking, crawler/MCP runtime,
  transport-execution, or real-provider claims.
- Do not wire the producer into production AppBootstrap, ChatStore, SwiftUI,
  navigation, telemetry, search execution, crawler/MCP, or real transport.

Acceptance:
- Tests prove accepted cited source metadata keeps the selected source host and
  citation-required attribution context in A97 status copy.
- Tests prove source-policy blocked, citation-policy missing, result citation
  missing, and result citation source mismatch paths stay rejected/non-success.
- Tests prove hidden/mismatched source hosts and query text are not present in
  selected status copy.
- Static scan confirms no URLSession, endpoint URL constants, SDK imports,
  network transport, crawler/MCP runtime, SwiftUI/view/root generation,
  StoreKit/payment, raw page content, or real provider calls were added.
- Targeted networking tests pass, full iOS tests pass, and `git diff --check`
  passes.
```

Status after implementation:

Search API adapter source, citation, and attribution outcomes now remain
explicit across A86 request/result metadata, A91 payloads, A92 dispatch
receipts, A96 fixture bridge responses, and A97/A87 provider-status copy.
Accepted cited source metadata preserves the selected public source host plus
citation-required attribution context, while source-policy blocked,
citation-policy missing, result citation missing, and result citation source
mismatch paths stay rejected/non-success without hidden host, query, raw page,
or provider-execution leakage. Targeted A101 networking tests and the full iOS
suite pass.

## Round A102 - Search API Adapter Result Freshness Content Status Matrix Proof

```text
Task: Prove Search API adapter result freshness, content, and limitation
outcomes remain explicit across A86 result receipts and provider-status copy.
This is test proof only. Do not change production transport, AppBootstrap,
ChatStore runtime behavior, SwiftUI/UI layout, navigation, telemetry,
transcript mutation, URLSession, endpoint URLs, API keys, OAuth tokens, SDK
clients, Exa/Brave/Tavily/Google/Gaode calls, crawler runtime, MCP client
runtime, booking/order/payment, StoreKit, memory writes, raw page content,
transport execution, or real provider execution.

Allowed files:
- kAirTests/Networking/ServerProviderSearchAPIAdapterFixtureTransportStatusSourceProducerTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add focused networking tests that build Search API adapter result receipts
  for live-preferred fresh result, cached-ok result, live-required stale result,
  missing-content result, and result-with-limitations metadata.
- Prove accepted fresh/cached results preserve freshness badges/status and
  citation context through status copy.
- Prove live-required stale and missing-content results stay rejected/non-success
  with exact rejection reasons and disabled status copy.
- Prove limitations remain metadata-only and do not become action/completion,
  booking, payment, crawler, or provider-execution claims.
- Prove status text does not include endpoint, credential, raw provider, raw
  page content, query text, hidden hosts, or real-provider claims.
- Do not wire the producer into production AppBootstrap, ChatStore, SwiftUI,
  navigation, telemetry, search execution, crawler/MCP, or real transport.

Acceptance:
- Tests prove fresh and cached accepted result receipts keep distinct freshness
  status through provider-status copy.
- Tests prove live-required stale and missing-content paths stay
  rejected/non-success with exact reasons.
- Tests prove limitations/citation metadata do not leak hidden hosts, query
  text, raw page content, or execution claims.
- Static scan confirms no URLSession, endpoint URL constants, SDK imports,
  network transport, crawler/MCP runtime, SwiftUI/view/root generation,
  StoreKit/payment, raw page content, or real provider calls were added.
- Targeted networking tests pass, full iOS tests pass, and `git diff --check`
  passes.
```

Status after implementation:

Search API adapter result freshness, content, and limitation outcomes now
remain explicit across A86 result receipts and A87 provider-status copy.
Live-preferred and cached-ok accepted results keep distinct freshness status;
live-required stale and missing-content results stay rejected/non-success with
exact reasons; limitation metadata remains metadata-only and does not leak
hidden hosts, query text, raw page content, or provider-execution claims.
Targeted A102 networking tests and the full iOS suite pass.

## Round A103 - Search API Adapter Result Status Matrix App-Root Handoff Proof

```text
Task: Prove A102 Search API adapter result freshness/content/limitation status
sources pass through AppBootstrap provider-status composition and ChatStore
lookup for rendered recommendation ids only. This is test proof only. Do not
change production transport, production AppBootstrap behavior, ChatStore runtime
behavior, SwiftUI/UI layout, navigation, telemetry, transcript mutation,
URLSession, endpoint URLs, API keys, OAuth tokens, SDK clients,
Exa/Brave/Tavily/Google/Gaode calls, crawler runtime, MCP client runtime,
booking/order/payment, StoreKit, memory writes, raw page content, transport
execution, or real provider execution.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add focused AppBootstrap tests that build a value-only A87
  `ServerProviderSearchAPIAdapterStatusSourceProducer` from A86 result receipts
  covering live-preferred, cached-ok, live-required stale, and missing-content
  result states.
- Inject the status source through `AppBootstrap(providerStatusSources:)` with
  a recommendation provider that renders only the selected recommendation id.
- Prove bootstrap lookup and `ChatStore` lookup preserve the same status,
  badges, card hint, and rejection/freshness copy for rendered ids.
- Prove hidden recommendation ids stay nil before bootstrap, after bootstrap,
  and in `ChatStore`.
- Prove selected status text does not include query text, hidden hosts, raw page
  content, endpoint/credential hints, crawler/MCP, booking/payment, or real
  provider execution claims.
- Do not wire the producer into production AppBootstrap, ChatStore, SwiftUI,
  navigation, telemetry, search execution, crawler/MCP, or real transport.

Acceptance:
- Tests prove fresh/cached/stale/missing-content result status survives
  source -> AppBootstrap -> ChatStore unchanged for rendered ids.
- Tests prove hidden ids stay nil at every lookup layer.
- Tests prove first-wins composition remains unchanged when the A102 source is
  composed with an existing provider-status source.
- Tests prove status copy stays advisory and does not leak hidden host, query,
  raw page, endpoint, credential, or execution wording.
- Static scan confirms no URLSession, endpoint URL constants, SDK imports,
  network transport, crawler/MCP runtime, SwiftUI/view/root behavior changes,
  StoreKit/payment, raw page content, or real provider calls were added.
- Targeted AppBootstrap tests pass, full iOS tests pass, and `git diff --check`
  passes.
```

Status after implementation:

A102 Search API adapter result freshness/content/limitation status sources now
pass through app-root provider-status composition and ChatStore lookup for
rendered recommendation ids only. Fresh, cached, live-required stale, and
missing-content status copy stays identical from source to root to store; hidden
ids stay nil; limitation metadata stays metadata-only; and first-wins
composition with an existing status source remains deterministic. Targeted A103
AppBootstrap tests and the full iOS suite pass.

## Round A104 - Research Market Provider Cut-Plan Refresh

```text
Task: Refresh the kAir research, market, UI, provider-policy, and interface cut
plan against current public evidence before choosing the first real-provider
integration slice. Use current web research and cite links/dates. Do not change
Swift code, tests, production transport, AppBootstrap runtime behavior,
ChatStore runtime behavior, SwiftUI/UI layout, navigation, telemetry,
transcript mutation, URLSession, endpoint URLs, API keys, OAuth tokens, SDK
clients, provider calls, crawler runtime, MCP client runtime, booking/order/
payment, StoreKit, memory writes, raw page ingestion, transport execution, or
real provider execution.

Allowed files:
- Docs/research/2026-agent-market-ui-provider-research.md
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Re-check current public agent architecture and UI evidence, including at
  least: Marvis/Mist AI public docs, Tencent Yuanbao public docs, public
  Meituan/life-service agent material if available, and comparable
  assistant/search/tool-use products.
- Re-check current papers from authoritative venues or indexes such as Google
  Scholar, IEEE, ACM, arXiv, or vendor research pages for agent planning,
  tool-use, RAG/search, UI handoff, cost-aware routing, privacy, and
  evaluation.
- Re-check provider-policy evidence for Apple/local-first, Google Maps/Places,
  Gaode, Search API vendors, crawler/robots, and MCP boundaries.
- Compare that evidence against the current repo architecture and identify what
  is already covered by A31-A103 versus what is still missing.
- Select the next concrete implementation slice after A104 and write its
  allowed files, non-goals, tests, static scans, and acceptance gate.
- Do not add unverified market claims; clearly label inference versus sourced
  fact.

Acceptance:
- Research doc has source links and access dates for all external claims.
- Audit clearly separates confirmed public evidence from inference and opinion.
- Docs state whether to continue Search API, switch to Google/Gaode, add
  crawler/MCP, or repair UI first, with explicit reasoning tied to current
  code and market evidence.
- Next implementation prompt is paste-ready, narrow, and includes allowed
  files, forbidden scope, tests/static scans, and verification gates.
- Static diff confirms only the four allowed docs changed; `git diff --check`
  passes.
```

Status after implementation:

A104 refreshed the research, market, UI, provider-policy, and interface cut
plan against current public papers, product docs, provider policies, and Search
API vendor docs. The selected next slice is a value-only Search API vendor
policy matrix because vendor pricing, quota, raw-content controls,
source/citation support, freshness semantics, and result-shape differences must
be explicit before any live provider call. Google/Gaode runtime, crawler
runtime, MCP runtime, and remote model gateway remain deferred.

## Round A105 - Search API Vendor Policy Matrix Proof

```text
Task: Add a value-only Search API vendor policy matrix that can select or reject
Exa/Brave/Tavily-like vendors by cost, quota, freshness, source/citation,
raw-content/retention, and result-shape requirements before any live provider
call. This is contract/test proof only. Do not change production transport,
AppBootstrap runtime behavior, ChatStore runtime behavior, SwiftUI/UI layout,
navigation, telemetry, transcript mutation, URLSession, endpoint URLs, API
keys, OAuth tokens, SDK clients, provider calls, crawler runtime, MCP client
runtime, booking/order/payment, StoreKit, memory writes, raw page ingestion,
transport execution, or real provider execution.

Allowed files:
- kAir/Core/Networking/ServerProviderSearchAPIVendorPolicy.swift
- kAirTests/Networking/ServerProviderSearchAPIVendorPolicyTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add pure value types for Search API vendor identity, declared capabilities,
  cost class, quota requirement, freshness support, citation/source support,
  raw-content/retention policy, and result-shape requirements.
- Add a deterministic evaluator that accepts an A86-style request context plus
  vendor policy metadata and returns accepted or rejected policy decisions.
- Rejections must cover disabled vendor, missing entitlement/quota, unsupported
  freshness, missing citation/source support, raw-content not allowed, retention
  conflict, private/Health context, and unsupported result shape.
- Encoded/debug/status copy must not contain endpoint URLs, API keys, OAuth
  tokens, SDK handles, raw provider payloads, raw page content, query text, or
  execution claims.
- Do not import networking/UI frameworks or call any vendor.

Acceptance:
- Tests prove vendor-accepted, quota-blocked, entitlement-blocked,
  freshness-blocked, source/citation-blocked, raw-content-blocked,
  retention-blocked, privacy-blocked, and result-shape-blocked decisions.
- Tests prove decisions are deterministic, Codable/Hashable/Sendable where
  appropriate, and do not leak endpoint, credential, raw page, raw provider, or
  query text.
- Static scan confirms no URLSession, endpoint URL constants, SDK imports,
  network transport, crawler/MCP runtime, SwiftUI/view/root behavior changes,
  StoreKit/payment, raw page content, or real provider calls were added.
- Targeted vendor policy tests pass, full iOS tests pass, and `git diff --check`
  passes.
```

Status after implementation: A105 added a value-only Search API vendor policy
matrix and tests. Vendor decisions now accept or reject Search API vendor
metadata by enabled state, provider family, capability, privacy, cost/quota,
entitlement, freshness, citation/source/attribution, page-body, retention, and
result-shape requirements before any live provider call. The next slice is to
package those decisions into rendered-id scoped provider-status copy without
app-root or runtime wiring.

## Round A106 - Search API Vendor Policy Status Source Proof

```text
Task: Package A105 Search API vendor policy decisions into the existing
provider-status side channel by explicit recommendation id, guarded to rendered
recommendation ids only. Accepted decisions should show safe vendor-policy
metadata copy; rejected decisions should show disabled/warning copy with the
explicit rejection reason. This is status-copy proof only. Do not change
production transport, AppBootstrap runtime behavior, ChatStore runtime
behavior, SwiftUI/UI layout, navigation, telemetry, transcript mutation,
URLSession, endpoint URLs, API keys, OAuth tokens, SDK clients, provider calls,
crawler runtime, MCP client runtime, booking/order/payment, StoreKit, memory
writes, raw page ingestion, transport execution, or real provider execution.

Allowed files:
- kAir/DesignSystem/Components/ProviderStatusBadgeModel.swift
- kAir/Core/Networking/ServerProviderSearchAPIVendorPolicyStatusSourceProducer.swift
- kAirTests/Networking/ServerProviderSearchAPIVendorPolicyStatusSourceProducerTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add a `SearchAPIVendorPolicyProviderStatusStore` or equivalent value-only
  store that maps explicit recommendation ids to
  `ServerProviderSearchAPIVendorPolicyDecision`.
- Add resolver copy for accepted and rejected vendor-policy decisions using
  existing `ProviderStatusPresentation`, `ProviderStatusBadgeModel`, and
  `ProviderStatusCardHint` vocabulary. Do not add new trust-pill vocabulary or
  UI components.
- Add a producer that accepts decision inputs and rendered recommendation ids,
  then returns a rendered-id guarded `ProviderStatusProviding` source.
- Preserve first-entry duplicate behavior, sorted exposed ids where applicable,
  missing-id nil lookup, and hidden-id nil lookup after rendering guard.
- Status copy must not contain endpoint URLs, API keys, OAuth tokens, SDK
  handles, query text, raw provider payloads, raw page content, or execution
  claims.

Acceptance:
- Tests prove accepted, disabled-vendor, quota/entitlement, privacy, freshness,
  source/citation, page-body, retention, and result-shape rejection decisions
  map to stable provider-status copy.
- Tests prove duplicate ids keep the first decision, missing ids return nil, and
  rendered-id guards hide unrendered recommendation ids.
- Tests prove status copy and encoded/debug strings do not leak endpoint,
  credential, SDK/client handle, query, raw page, raw provider payload, payment,
  booking, or execution claims.
- Static scan confirms no URLSession, endpoint URL constants, SDK imports,
  network transport, crawler/MCP runtime, SwiftUI/view/root behavior changes,
  StoreKit/payment, raw page content, or real provider calls were added.
- Targeted A106 tests pass, full iOS tests pass, and `git diff --check` passes.
```

Status after implementation: A106 added
`SearchAPIVendorPolicyProviderStatusStore` plus
`ServerProviderSearchAPIVendorPolicyStatusSourceProducer`. A105 vendor policy
decisions now package into rendered-id scoped provider-status copy with stable
accepted/blocked presentations, duplicate first-wins behavior, hidden-id
filtering, and no provider execution claims. The next slice is the app-root
handoff proof.

## Round A107 - Search API Vendor Policy Status App-Root Handoff Proof

```text
Task: Prove A106 Search API vendor policy status sources can pass through
`AppBootstrap(providerStatusSources:)` and ChatStore lookup for rendered
recommendation ids only. Accepted and rejected vendor-policy status copy must
remain unchanged from source to root to store, hidden ids must stay nil, and
source order must remain first-wins when composed with another provider-status
source. This is app-root handoff proof only. Do not change production
transport, AppBootstrap runtime behavior, ChatStore runtime behavior,
SwiftUI/UI layout, navigation, telemetry, transcript mutation, URLSession,
endpoint URLs, API keys, OAuth tokens, SDK clients, provider calls, crawler
runtime, MCP client runtime, booking/order/payment, StoreKit, memory writes,
raw page ingestion, transport execution, or real provider execution.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Build accepted and rejected A105 vendor policy decisions in test fixtures.
- Package them with `ServerProviderSearchAPIVendorPolicyStatusSourceProducer`
  and inject the rendered-id guarded source through
  `AppBootstrap(providerStatusSources:)`.
- Prove ChatStore reads the same accepted/rejected presentations only for
  rendered recommendation ids and returns nil for hidden ids.
- Prove source order remains first-wins when the vendor policy source is
  composed with an existing provider-status source.
- Do not add production code unless a compile-only access issue blocks the test.

Acceptance:
- Tests prove accepted and rejected vendor policy status survives
  AppBootstrap-to-ChatStore lookup unchanged for rendered ids.
- Tests prove hidden ids stay nil at source/root/store lookup and missing ids
  return nil.
- Tests prove source order remains first-wins when composed with another
  provider-status source.
- Tests prove no endpoint, credential, SDK/client handle, query, raw page, raw
  provider payload, payment, booking, or execution claims appear in app-root
  handoff status copy.
- Static scan confirms no URLSession, endpoint URL constants, SDK imports,
  network transport, crawler/MCP runtime, SwiftUI/view/root behavior changes,
  StoreKit/payment, raw page content, or real provider calls were added.
- Targeted A107 tests pass, full iOS tests pass, and `git diff --check` passes.
```

Status after implementation: A107 proved the A106 vendor policy status source
passes through `AppBootstrap(providerStatusSources:)` and ChatStore lookup for
rendered recommendation ids only. Accepted and rejected copy remains unchanged
from source to root to store, hidden ids stay nil, missing ids stay nil, and
source-order composition remains first-wins without production root/UI/runtime
changes.

## Round A108 - Search API Vendor Policy Dispatch Authorization Proof

```text
Task: Add a value-only Search API vendor policy dispatch authorization gate that
combines A92 `ServerProviderSearchAPIAdapterPayloadDispatchReceipt` values with
A105 `ServerProviderSearchAPIVendorPolicyDecision` values. Dispatch can be
authorized only when the dispatch receipt is eligible, the vendor policy
decision is accepted, provider/capability/cost/freshness metadata matches, and
the requested result shape is allowed. Rejected, missing, non-dispatch,
mismatched, and unsupported-result-shape paths must stay blocked before any
transport call. This is dispatch-authorization proof only. Do not change
production transport, AppBootstrap runtime behavior, ChatStore runtime
behavior, SwiftUI/UI layout, navigation, telemetry, transcript mutation,
URLSession, endpoint URLs, API keys, OAuth tokens, SDK clients, provider calls,
crawler runtime, MCP client runtime, booking/order/payment, StoreKit, memory
writes, raw page ingestion, transport execution, or real provider execution.

Allowed files:
- kAir/Core/Networking/ServerProviderSearchAPIVendorPolicyDispatchAuthorization.swift
- kAirTests/Networking/ServerProviderSearchAPIVendorPolicyDispatchAuthorizationTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add pure value types for vendor dispatch authorization state, rejection
  reason, and authorization output.
- Add a deterministic evaluator that consumes an optional A92 dispatch receipt,
  an optional A105 vendor policy decision, and a requested result shape.
- Accept only dispatch-eligible receipts plus accepted vendor decisions whose
  provider family, capability, cost, freshness, and result shape are compatible.
- Preserve explicit rejection reasons for missing dispatch, blocked dispatch,
  missing vendor decision, rejected vendor decision, provider/capability/cost/
  freshness mismatch, and unsupported result shape.
- Encoded/debug/status copy must stay metadata-only and must not include query
  text, endpoint URLs, API keys, OAuth tokens, SDK handles, raw provider
  payloads, raw page content, or execution claims.

Acceptance:
- Tests prove accepted authorization preserves safe dispatch/vendor metadata.
- Tests prove missing dispatch, blocked dispatch, missing vendor policy,
  rejected vendor policy, provider mismatch, capability mismatch, cost mismatch,
  freshness mismatch, and result-shape mismatch reject deterministically.
- Tests prove output is deterministic, Codable/Hashable/Sendable where
  appropriate, and does not leak endpoint, credential, SDK/client handle, query,
  raw page, raw provider payload, payment, booking, or execution claims.
- Static scan confirms no URLSession, endpoint URL constants, SDK imports,
  network transport, crawler/MCP runtime, SwiftUI/view/root behavior changes,
  StoreKit/payment, raw page content, or real provider calls were added.
- Targeted A108 tests pass, full iOS tests pass, and `git diff --check` passes.
```

Status after implementation: A108 added a value-only Search API vendor policy
dispatch authorization gate. A92 dispatch receipts are authorized only when
paired with an accepted A105 vendor policy decision and matching provider,
capability, cost, freshness, and result-shape metadata. Missing, blocked,
rejected, mismatched, and unsupported-result-shape paths remain rejected before
any transport call.

## Round A109 - Search API Vendor Policy Dispatch Authorization Status Source Proof

```text
Task: Package A108 Search API vendor policy dispatch authorization results into
the existing provider-status side channel by explicit recommendation id,
guarded to rendered recommendation ids only. Authorized results should show safe
dispatch/vendor metadata copy; rejected results should show disabled/warning
copy with explicit authorization, dispatch, and vendor-policy reasons. This is
status-copy proof only. Do not change production transport, AppBootstrap
runtime behavior, ChatStore runtime behavior, SwiftUI/UI layout, navigation,
telemetry, transcript mutation, URLSession, endpoint URLs, API keys, OAuth
tokens, SDK clients, provider calls, crawler runtime, MCP client runtime,
booking/order/payment, StoreKit, memory writes, raw page ingestion, transport
execution, or real provider execution.

Allowed files:
- kAir/DesignSystem/Components/ProviderStatusBadgeModel.swift
- kAir/Core/Networking/ServerProviderSearchAPIVendorPolicyDispatchAuthorizationStatusSourceProducer.swift
- kAirTests/Networking/ServerProviderSearchAPIVendorPolicyDispatchAuthorizationStatusSourceProducerTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add a `SearchAPIVendorDispatchAuthorizationProviderStatusStore` or equivalent
  value-only store mapping explicit recommendation ids to
  `ServerProviderSearchAPIVendorPolicyDispatchAuthorization`.
- Add resolver copy for authorized and rejected authorization results using
  existing `ProviderStatusPresentation`, `ProviderStatusBadgeModel`, and
  `ProviderStatusCardHint` vocabulary. Do not add new trust-pill vocabulary or
  UI components.
- Add a producer that accepts authorization inputs and rendered recommendation
  ids, then returns a rendered-id guarded `ProviderStatusProviding` source.
- Preserve first-entry duplicate behavior, sorted exposed ids where applicable,
  missing-id nil lookup, and hidden-id nil lookup after rendering guard.
- Status copy must not contain endpoint URLs, API keys, OAuth tokens, SDK
  handles, query text, raw provider payloads, raw page content, or execution
  claims.

Acceptance:
- Tests prove authorized, missing dispatch, blocked dispatch, missing vendor
  policy, rejected vendor policy, provider mismatch, capability mismatch, cost
  mismatch, freshness mismatch, and result-shape mismatch authorizations map to
  stable provider-status copy.
- Tests prove duplicate ids keep the first authorization, missing ids return
  nil, and rendered-id guards hide unrendered recommendation ids.
- Tests prove status copy and encoded/debug strings do not leak endpoint,
  credential, SDK/client handle, query, raw page, raw provider payload, payment,
  booking, or execution claims.
- Static scan confirms no URLSession, endpoint URL constants, SDK imports,
  network transport, crawler/MCP runtime, SwiftUI/view/root behavior changes,
  StoreKit/payment, raw page content, or real provider calls were added.
- Targeted A109 tests pass, full iOS tests pass, and `git diff --check` passes.
```

Status after implementation: A109 packaged A108 Search API vendor policy
dispatch authorization results into rendered-id scoped provider-status copy.
Authorized results show safe dispatch/vendor metadata; rejected results preserve
explicit authorization, dispatch, and vendor-policy reasons; duplicate ids keep
the first authorization; hidden and missing ids return nil. No app-root,
ChatStore, UI, transport, or provider runtime behavior was changed.

## Round A110 - Search API Vendor Policy Dispatch Authorization Status App-Root Handoff Proof

```text
Task: Prove A109 Search API vendor policy dispatch authorization status sources
pass through `AppBootstrap(providerStatusSources:)` and ChatStore lookup for
rendered recommendation ids only. Authorized and rejected copy must remain
unchanged from source to root to store; hidden and missing ids must return nil;
source order must remain first-wins when another source has the same
recommendation id. This is app-root handoff proof only. Do not change
production transport, AppBootstrap production defaults, ChatStore production
behavior, SwiftUI/UI layout, navigation, telemetry, transcript mutation,
URLSession, endpoint URLs, API keys, OAuth tokens, SDK clients, provider calls,
crawler runtime, MCP client runtime, booking/order/payment, StoreKit, memory
writes, raw page ingestion, transport execution, or real provider execution.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add focused tests that inject A109-produced status sources through
  `AppBootstrap(providerStatusSources:)`.
- Prove ChatStore lookup returns the exact same authorized and rejected
  `ProviderStatusPresentation` values as the source.
- Prove hidden supplied ids, missing ids, and unrendered ids return nil.
- Prove source-order first-wins when a fallback/fixture source shares a rendered
  recommendation id with the dispatch authorization source.
- Keep all changes test-only except doc status sync.

Acceptance:
- Tests prove authorized and rejected A109 presentations survive source -> root
  -> ChatStore lookup unchanged.
- Tests prove hidden supplied ids, missing ids, and unrendered ids return nil.
- Tests prove source-order first-wins composition for duplicate rendered ids.
- Tests prove app-root handoff copy does not leak endpoint, credential,
  SDK/client handle, query, raw page, raw provider payload, payment, booking, or
  execution claims.
- Static scan confirms no URLSession, endpoint URL constants, SDK imports,
  network transport, crawler/MCP runtime, SwiftUI/view/root behavior changes,
  StoreKit/payment, raw page content, or real provider calls were added.
- Targeted A110 tests pass, full iOS tests pass, and `git diff --check` passes.
```

Status after implementation: A110 proved A109 dispatch authorization status
sources pass through `AppBootstrap(providerStatusSources:)` and ChatStore
lookup for rendered recommendation ids only. Authorized and rejected copy
remains unchanged from source to root to store; hidden and missing ids return
nil; source order remains first-wins. No production root/UI/runtime/provider
behavior was changed.

## Round A111 - Search API Vendor Dispatch Cross-Stage Status Composition Proof

```text
Task: Prove A106 Search API vendor policy status, A93 Search API adapter payload
dispatch status, and A109 Search API vendor dispatch authorization status
sources compose deterministically through `AppBootstrap(providerStatusSources:)`
and ChatStore lookup. When multiple sources have the same rendered
recommendation id, the first source must win exactly; later sources must not
leak stale vendor, dispatch, authorization, query, source-host, or execution
copy into the selected presentation. Hidden and missing ids must remain nil at
source, root, and ChatStore. This is cross-stage status composition proof only.
Do not change production transport, AppBootstrap production defaults, ChatStore
production behavior, SwiftUI/UI layout, navigation, telemetry, transcript
mutation, URLSession, endpoint URLs, API keys, OAuth tokens, SDK clients,
provider calls, crawler runtime, MCP client runtime, booking/order/payment,
StoreKit, memory writes, raw page ingestion, transport execution, or real
provider execution.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add focused tests that build rendered-id guarded A106, A93, and A109 status
  sources for the same recommendation ids plus hidden ids.
- Compose the sources through `AppBootstrap(providerStatusSources:)` in at
  least vendor-first, dispatch-first, and authorization-first orders.
- Prove ChatStore receives exactly the first source's presentation for each
  rendered id and none of the later source's detail strings.
- Prove hidden supplied ids, missing ids, and unrendered ids return nil at
  source, root, and ChatStore.
- Keep all changes test-only except doc status sync.

Acceptance:
- Tests prove vendor-first, dispatch-first, and authorization-first source
  orders select the correct first presentation through ChatStore.
- Tests prove hidden supplied ids, missing ids, and unrendered ids return nil at
  every checked layer.
- Tests prove selected copy does not mix stale vendor id, dispatch source host,
  authorization reason, query text, raw page/provider payload, payment, booking,
  or execution claims from later sources.
- Static scan confirms no URLSession, endpoint URL constants, SDK imports,
  network transport, crawler/MCP runtime, SwiftUI/view/root behavior changes,
  StoreKit/payment, raw page content, or real provider calls were added.
- Targeted A111 tests pass, full iOS tests pass, and `git diff --check` passes.
```

Status after implementation: A111 proved A106 vendor policy status, A93 payload
dispatch status, and A109 dispatch authorization status compose
deterministically through `AppBootstrap(providerStatusSources:)` and ChatStore
lookup. Vendor-first, dispatch-first, and authorization-first orders select the
first source exactly; hidden ids stay nil; selected copy does not mix later
vendor, dispatch, authorization, query, source-host, or execution detail.

## Round A112 - Search API Vendor-Authorized Transport Lease Budget Guard Proof

```text
Task: Add a value-only Search API vendor-authorized transport lease and
cost-budget guard. The evaluator should consume approved Search API payload/
dispatch metadata plus A108 vendor dispatch authorization and an explicit
budget context, then issue a safe lease only when dispatch is eligible,
authorization is accepted, provider/capability/cost/freshness/result-shape
metadata matches, and the budget allows the requested cost class. Rejected,
missing, mismatched, over-budget, quota-blocked, and non-authorized paths must
remain blocked before any endpoint or transport call. This is lease/budget
proof only. Do not change production transport, AppBootstrap production
defaults, ChatStore production behavior, SwiftUI/UI layout, navigation,
telemetry, transcript mutation, URLSession, endpoint URLs, API keys, OAuth
tokens, SDK clients, provider calls, crawler runtime, MCP client runtime,
booking/order/payment, StoreKit, memory writes, raw page ingestion, transport
execution, or real provider execution.

Allowed files:
- kAir/Core/Networking/ServerProviderSearchAPITransportLease.swift
- kAirTests/Networking/ServerProviderSearchAPITransportLeaseTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add pure value types for transport lease state, rejection reason, budget
  context, and lease output.
- Add a deterministic evaluator that consumes optional A91 payload decision,
  optional A92 dispatch receipt, optional A108 dispatch authorization, requested
  result shape, and a budget context.
- Issue a lease only for dispatch-eligible, vendor-authorized, metadata-matched,
  budget-allowed inputs.
- Preserve explicit rejection reasons for missing payload, rejected payload,
  missing dispatch, blocked dispatch, missing authorization, rejected
  authorization, provider/capability/cost/freshness/result-shape mismatch,
  entitlement/quota/budget denial, and stale/unsafe source policy.
- Encoded/debug/status copy must stay metadata-only and must not include query
  text, endpoint URLs, API keys, OAuth tokens, SDK handles, raw provider
  payloads, raw page content, or execution claims.

Acceptance:
- Tests prove accepted leases preserve only safe payload/dispatch/vendor/budget
  metadata and do not imply network execution.
- Tests prove missing/rejected payload, missing/blocked dispatch,
  missing/rejected authorization, provider/capability/cost/freshness/result
  shape mismatch, quota denial, entitlement denial, and explicit budget denial
  reject deterministically.
- Tests prove output is deterministic, Codable/Hashable/Sendable where
  appropriate, and encoded/debug/status copy does not leak endpoint,
  credential, SDK/client handle, query, raw page, raw provider payload, payment,
  booking, or execution claims.
- Static scan confirms no URLSession, endpoint URL constants, SDK imports,
  network transport, crawler/MCP runtime, SwiftUI/view/root behavior changes,
  StoreKit/payment, raw page content, or real provider calls were added.
- Targeted A112 tests pass, full iOS tests pass, and `git diff --check` passes.
```

Status after implementation: A112 added a value-only Search API
vendor-authorized transport lease and budget guard. A91 payload metadata, A92
dispatch receipts, A108 dispatch authorization, and explicit budget context now
issue or reject safe transport leases; missing/rejected payload, missing/blocked
dispatch, missing/rejected authorization, metadata mismatch, source/citation
failure, entitlement denial, included-quota exhaustion, metered eligibility
absence, and explicit budget denial all stop before endpoint, credential,
transport, crawler/MCP runtime, or provider execution.

## Round A113 - Search API Transport Lease Status Source Proof

```text
Task: Add a value-only Search API transport lease status source producer. The
producer should consume explicit rendered recommendation ids plus A112 transport
lease outputs and return a `ProviderStatusProviding` source that surfaces
issued/rejected lease state as advisory UI-safe copy. Issued lease copy may
include safe lease id, vendor id, budget id, provider family, capability,
cost class, freshness, result shape, result limit, source state, and citation
required. Rejected lease copy must preserve explicit lease rejection plus nested
payload, dispatch, and authorization rejection reasons when present. Hidden or
missing rendered ids must return nil; duplicate rendered ids must remain
first-wins. This is status-source proof only. Do not change AppBootstrap
production defaults, ChatStore production behavior, SwiftUI/UI layout,
navigation, telemetry, transcript mutation, URLSession, endpoint URLs, API
keys, OAuth tokens, SDK clients, provider calls, crawler runtime, MCP client
runtime, booking/order/payment, StoreKit, memory writes, raw page ingestion,
transport execution, or real provider execution.

Allowed files:
- kAir/DesignSystem/Components/ProviderStatusBadgeModel.swift
- kAir/Core/Networking/ServerProviderSearchAPITransportLeaseStatusSourceProducer.swift
- kAirTests/Networking/ServerProviderSearchAPITransportLeaseStatusSourceProducerTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Follow the existing A89/A93/A106/A109 status-source producer patterns:
  typed producer inputs, explicit rendered id filtering, and a store/source
  that conforms to `ProviderStatusProviding`.
- Map issued leases to non-success advisory "transport lease ready" copy,
  not execution-success copy.
- Map rejected leases to disabled/warning copy with the exact A112 rejection
  reason and nested payload/dispatch/authorization reasons.
- Preserve duplicate first-wins behavior and nil lookup for hidden or missing
  rendered ids.
- Encoded/debug/status copy must stay metadata-only and must not include query
  text, source host, endpoint URLs, API keys, OAuth tokens, SDK handles, raw
  provider payloads, raw page content, or execution claims.

Acceptance:
- Tests prove issued lease status exposes only safe A112 metadata and remains
  advisory/non-execution copy.
- Tests prove rejected lease status preserves explicit lease, payload,
  dispatch, authorization, and budget reasons.
- Tests prove duplicate rendered ids are first-wins and hidden/missing ids
  return nil.
- Tests prove encoded/debug/status copy does not leak endpoint, credential,
  SDK/client handle, query, source host, raw page, raw provider payload,
  payment, booking, or execution claims.
- Static scan confirms no URLSession, endpoint URL constants, SDK imports,
  network transport, crawler/MCP runtime, SwiftUI/view/root behavior changes,
  StoreKit/payment, raw page content, or real provider calls were added.
- Targeted A113 tests pass, full iOS tests pass, and `git diff --check` passes.
```

Status after implementation: A113 added a value-only Search API transport lease
status source producer. A112 issued/rejected leases can now be packaged by
explicit rendered recommendation id into `ProviderStatusProviding` copy.
Issued copy stays advisory and exposes only safe lease/vendor/budget/provider
metadata; rejected copy preserves lease, payload, dispatch, authorization, and
budget reasons; hidden/missing ids return nil; duplicate ids keep the first
lease; status/debug copy does not expose query text, source host, endpoint,
credentials, raw page/provider content, or execution claims.

## Round A114 - Search API Transport Lease Status App-Root Handoff Proof

```text
Task: Prove the A113 Search API transport lease status source can pass through
the app composition root and ChatStore without changing copy or widening runtime
scope. Build issued and rejected A113 lease status sources, inject them through
`AppBootstrap(providerStatusSources:)`, and verify ChatStore lookup for rendered
recommendation ids returns the same presentations as the source. Hidden ids,
missing ids, and unrendered lease ids must remain nil. Multiple status sources
must preserve first-source-wins ordering. This is app-root handoff proof only.
Do not change AppBootstrap production defaults, ChatStore production behavior,
SwiftUI/UI layout, navigation, telemetry, transcript mutation, URLSession,
endpoint URLs, API keys, OAuth tokens, SDK clients, provider calls, crawler
runtime, MCP client runtime, booking/order/payment, StoreKit, memory writes,
raw page ingestion, transport execution, or real provider execution.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Follow the existing A88/A90/A94/A98/A103/A107/A110 app-root handoff test
  pattern in `AppBootstrapTests.swift`.
- Use `ServerProviderSearchAPITransportLeaseStatusSourceProducer` to create a
  rendered-id scoped source containing at least one issued lease and one
  rejected lease.
- Inject the source through `AppBootstrap(providerStatusSources:)`, then verify
  root-level `providerStatusPresentation(for:)` and ChatStore lookup return the
  same presentations as the original source.
- Add a source-order test with two rendered sources for the same id and prove
  the first source wins without mixing lease id, vendor id, budget id,
  rejection reason, or status copy from later sources.
- Keep all fixtures value-only; do not instantiate transport clients or provider
  runtimes.

Acceptance:
- Tests prove issued and rejected A113 lease status presentations pass unchanged
  through AppBootstrap and ChatStore for rendered ids.
- Tests prove hidden/unrendered/missing ids return nil at source, root, and
  ChatStore lookup.
- Tests prove source order remains first-wins and selected copy does not mix
  later lease/vendor/budget/rejection details.
- Tests prove status copy remains advisory and does not include query text,
  source host, endpoint, credential, SDK/client handle, raw page, raw provider
  payload, payment, booking, or execution claims.
- Static scan confirms no URLSession, endpoint URL constants, SDK imports,
  network transport, crawler/MCP runtime, SwiftUI/view/root behavior changes,
  StoreKit/payment, raw page content, or real provider calls were added.
- Targeted A114 tests pass, full iOS tests pass, and `git diff --check` passes.
```

Status after implementation: A114 proved that A113 Search API transport lease
status sources pass through `AppBootstrap(providerStatusSources:)` and
ChatStore lookup for rendered ids only. Issued/rejected copy remains unchanged
from source to root to store; hidden and missing ids return nil; source order
remains first-wins; no production AppBootstrap, ChatStore, UI, transport,
endpoint, crawler/MCP runtime, or provider execution behavior changed.

## Round A115 - Search API Transport Lease Cross-Stage Status Composition Proof

```text
Task: Prove the Search API status pipeline composes across vendor policy,
payload dispatch, dispatch authorization, and transport lease layers without
stale detail mixing. Build A106 vendor policy status, A93 payload dispatch
status, A109 dispatch authorization status, and A113 transport lease status
sources for the same rendered recommendation ids, inject them through
`AppBootstrap(providerStatusSources:)` in multiple source orders, and verify
ChatStore lookup returns exactly the first source's presentations. Hidden ids,
missing ids, and unrendered ids from every layer must remain nil. This is
cross-stage status composition proof only. Do not change AppBootstrap
production defaults, ChatStore production behavior, SwiftUI/UI layout,
navigation, telemetry, transcript mutation, URLSession, endpoint URLs, API
keys, OAuth tokens, SDK clients, provider calls, crawler runtime, MCP client
runtime, booking/order/payment, StoreKit, memory writes, raw page ingestion,
transport execution, or real provider execution.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Follow the existing A111 cross-stage composition test pattern.
- Use two rendered recommendation ids: one ready/issued path and one blocked/
  rejected path.
- Build four rendered-id scoped sources: A106 vendor policy, A93 payload
  dispatch, A109 dispatch authorization, and A113 transport lease.
- Compose at least four source orders: vendor-first, dispatch-first,
  authorization-first, and lease-first.
- Verify source, root, and ChatStore hidden/missing id behavior stays nil.
- Verify the selected presentation equals the first source's presentation and
  does not mix later layer details such as vendor id, dispatch source host,
  authorization reason, lease id, budget id, query text, or execution copy.

Acceptance:
- Tests prove vendor-first, dispatch-first, authorization-first, and lease-first
  orders select the first source exactly at AppBootstrap and ChatStore.
- Tests prove hidden/unrendered/missing ids from every layer return nil at
  source, root, and ChatStore lookup.
- Tests prove selected copy does not mix stale vendor/dispatch/authorization/
  lease/budget/query/source-host/execution details from later sources.
- Tests prove status copy remains advisory and does not include endpoint,
  credential, SDK/client handle, raw page, raw provider payload, payment,
  booking, or execution claims.
- Static scan confirms no URLSession, endpoint URL constants, SDK imports,
  network transport, crawler/MCP runtime, SwiftUI/view/root behavior changes,
  StoreKit/payment, raw page content, or real provider calls were added.
- Targeted A115 tests pass, full iOS tests pass, and `git diff --check` passes.
```

Status after implementation: A115 proved A106 vendor policy status, A93 payload
dispatch status, A109 dispatch authorization status, and A113 transport lease
status compose deterministically through app-root and ChatStore lookup.
Vendor-first, dispatch-first, authorization-first, and lease-first orders all
select the first source exactly; hidden ids stay nil; selected copy does not
mix later vendor, dispatch, authorization, lease, budget, query, source-host, or
execution detail.

## Round A116 - Research/Market Provider Cut-Plan Refresh

```text
Task: Refresh the research, market, and provider cut-plan now that the Search
API value-only pipeline has reached A115. Re-check current public sources for
agent architecture, life-service agent UX, search/crawler/API provider policy,
MCP safety, and cost/entitlement implications. Compare the current project
contracts against that evidence and decide the next smallest safe implementation
gate. This is research/planning proof only. Do not add runtime transport,
endpoint URLs, API keys, OAuth tokens, SDK clients, crawler runtime, MCP client
runtime, provider calls, AppBootstrap production defaults, ChatStore production
behavior, SwiftUI/UI layout, navigation, telemetry, transcript mutation,
StoreKit/payment, memory writes, raw page ingestion, transport execution, or
real provider execution.

Allowed files:
- Docs/research/2026-agent-market-ui-provider-research.md
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Research scope:
- Current agent architecture papers and credible technical reports, including
  planning/tool-use/memory/safety patterns relevant to mobile agents.
- Public documentation or product material for life-service agents and market
  comparables, including Marvis-like personal agents, Tencent Yuanbao-style
  assistants, Meituan-style life-service agents, and search-first agents where
  reliable public material exists.
- Search API vendor docs and pricing/policy for at least two providers already
  referenced in project docs, plus crawler and MCP safety/policy sources.
- Apple/iOS constraints relevant to local-first execution, App Intents,
  privacy, maps, and future Google/Gaode membership-based routing.

Implementation shape:
- Update the research doc with dated evidence, links, and a concise conclusion.
- Update architecture docs with the selected next gate and explicit non-goals.
- If evidence is uncertain, keep the next gate contract-only and say why.
- Preserve the current local-first/privacy-gated product contract and value-only
  runtime boundary unless evidence justifies a narrower change.

Acceptance:
- Sources are current, cited, and distinguish direct evidence from inference.
- The selected next implementation gate is paste-ready and narrower than
  "integrate real providers" unless evidence and existing contracts prove that
  live transport is safe.
- Docs explicitly cover Search API, crawler, MCP, maps provider routing
  (Apple/local vs Google/Gaode by membership/cost), cost/entitlement, privacy,
  source/citation/attribution, and UI/provider-status implications.
- No Swift or production behavior changes are made.
- `git diff --check` passes, and if no Swift changed, no xcodebuild run is
  required beyond a short explanation.
```

Status after implementation: A116 refreshed the research/market/provider cut
plan after the completed A115 Search API value-only pipeline. Current evidence
from agent architecture papers, MCP safety work, Search API vendor docs,
Google/Gaode policy surfaces, and Apple local-first constraints says live
Search API transport is still premature. The next safe gate is a value-only
server-provider metered entitlement ledger that normalizes membership, quota
period, unit accounting, and provider/vendor budget decisions before endpoints
or SDKs exist.

## Round A117 - Server Provider Metered Entitlement Ledger Proof

```text
Task: Add a value-only server-provider metered entitlement ledger. The ledger
must represent a server-verified snapshot for provider-family/vendor budget
state and evaluate estimated usage requests before Search API vendor policy or
transport lease can be treated as budget-eligible. This is the cost/entitlement
precondition selected by the A116 research refresh. Do not add live Search API
transport, endpoint URLs, API keys, OAuth tokens, SDK clients, crawler runtime,
MCP client runtime, Google/Gaode SDKs, provider calls, AppBootstrap production
defaults, ChatStore production behavior, SwiftUI/UI layout, navigation,
telemetry, transcript mutation, StoreKit/payment, memory writes, raw page
ingestion, transport execution, or real provider execution.

Allowed files:
- kAir/Core/Networking/ServerProviderMeteredEntitlementLedger.swift
- kAirTests/Networking/ServerProviderMeteredEntitlementLedgerTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add `ServerProviderMeteredEntitlementSnapshot` with provider family/vendor id,
  membership tier, quota period id, included units, used units, reserved units,
  remaining units, currency/unit label, snapshot timestamp, and stale threshold.
- Add `ServerProviderMeteredUsageRequest` with trace id, provider family/vendor
  id, capability, estimated units, cost class, privacy class, freshness, and
  user-facing reason.
- Add `ServerProviderMeteredUsageDecision` with accepted/rejected state, denial
  reason, safe audit copy, remaining/reserved units, and no execution wording.
- Rejection reasons should cover missing snapshot, vendor disabled, missing
  membership/entitlement, over quota, stale snapshot, currency/unit mismatch,
  provider mismatch, capability mismatch, privacy/Health block, and already
  reserved budget.

Acceptance:
- Unit tests cover accepted included quota, accepted metered entitlement,
  over-budget rejection, stale snapshot rejection, provider/vendor mismatch,
  capability mismatch, privacy/Health block, disabled vendor, unit/currency
  mismatch, and duplicate request determinism.
- Encoded/debug/status-safe copy must not contain endpoint URLs, API keys,
  OAuth tokens, SDK/client handles, raw query text, raw page/provider payloads,
  payment/order data, or execution claims.
- The ledger decision is value-only and can later be passed into A105 vendor
  policy and A112 transport lease; A117 must not wire production root, UI,
  transport, StoreKit, MCP, crawler, Google/Gaode, or real provider execution.
- Run targeted tests for the new ledger file, full `test_sim`, forbidden
  fragment scan for the new file, and `git diff --check`.
```

Status after implementation: A117 added a value-only server-provider metered
entitlement ledger. Server-verified budget snapshots and usage requests now
preserve membership, entitlement, quota period, unit/currency, cost class,
privacy/Health context, freshness, provider/vendor/capability match, disabled
vendor, stale snapshot, duplicate reservation, and over-budget decisions. The
ledger can produce value-only quota/budget contexts for later A105/A112 use, but
no runtime, transport, provider, StoreKit, MCP, crawler, Google/Gaode SDK,
AppBootstrap, ChatStore, UI, telemetry, transcript, or memory behavior changed.

## Round A118 - Server Provider Metered Entitlement Status Source Proof

```text
Task: Package A117 server-provider metered entitlement usage decisions into
the existing provider-status side channel by explicit recommendation id. This
is a value-only status source proof only. Do not add live Search API transport,
endpoint URLs, API keys, OAuth tokens, SDK clients, crawler runtime, MCP client
runtime, Google/Gaode SDKs, provider calls, AppBootstrap production defaults,
ChatStore production behavior, SwiftUI/UI layout, navigation, telemetry,
transcript mutation, StoreKit/payment, memory writes, raw page ingestion,
transport execution, or real provider execution.

Allowed files:
- kAir/Core/Networking/ServerProviderMeteredEntitlementStatusSourceProducer.swift
- kAirTests/Networking/ServerProviderMeteredEntitlementStatusSourceProducerTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add a producer that accepts explicit `(recommendationID, decision)` inputs and
  builds a `ProviderStatusProviding` store.
- Accepted decisions should produce budget-ready advisory copy with safe
  provider family/vendor id, quota period id, remaining/reserved units,
  cost class, freshness, and unit label only.
- Rejected decisions should produce disabled/blocked advisory copy with the
  explicit A117 denial reason, while omitting hidden budget internals.
- Duplicate recommendation ids keep the first decision; missing ids and
  unrendered/hidden ids return nil.

Acceptance:
- Tests cover accepted included-quota and metered decisions, rejected decisions
  for stale/over-budget/privacy/provider mismatch reasons, duplicate first-wins
  behavior, missing-id nil lookup, and hidden-id nil lookup.
- Status-safe copy must not contain endpoint URLs, API keys, OAuth tokens,
  SDK/client handles, raw query text, raw page/provider payloads, payment/order
  data, or execution claims.
- A118 must not change AppBootstrap, ChatStore, SwiftUI, transport, StoreKit,
  MCP, crawler, Google/Gaode, memory, or real provider behavior.
- Run targeted status-source tests, full `test_sim`, forbidden-fragment scan for
  the new file, and `git diff --check`.
```

Status after implementation: A118 added
`ServerProviderMeteredEntitlementStatusSourceProducer` and
`ServerProviderMeteredEntitlementStatusStore`. A117 accepted included-quota and
metered usage decisions can now be packaged by explicit recommendation id into
rendered-id scoped `ProviderStatusProviding` copy. Accepted copy exposes only
safe provider/vendor/quota-period/remaining-reserved-unit/cost/freshness/unit
metadata; rejected copy exposes the explicit A117 denial reason without hidden
budget internals. Tests cover stale, over-budget, privacy, and provider-mismatch
rejections, duplicate first-wins behavior, hidden/missing nil lookup, and
status-safe copy without app-root, ChatStore, UI, runtime, transport, StoreKit,
MCP/crawler, Google/Gaode SDK, memory, or provider execution changes.

## Round A119 - Server Provider Metered Entitlement Status App-Root Handoff Proof

```text
Task: Prove A118 server-provider metered entitlement status sources pass
through `AppBootstrap(providerStatusSources:)` and ChatStore provider-status
lookup for rendered recommendation ids only. This is a handoff proof only. Do
not add live Search API transport, endpoint URLs, API keys, OAuth tokens, SDK
clients, crawler runtime, MCP client runtime, Google/Gaode SDKs, provider calls,
AppBootstrap production defaults, ChatStore production behavior, SwiftUI/UI
layout, navigation, telemetry, transcript mutation, StoreKit/payment, memory
writes, raw page ingestion, transport execution, or real provider execution.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Build A118 status sources in tests from accepted included-quota, accepted
  metered, and rejected A117 usage decisions.
- Inject those sources through `AppBootstrap(providerStatusSources:)`.
- Verify root-level `providerStatusPresentation(for:)` and ChatStore lookup
  return the same rendered-id scoped accepted/rejected presentations.
- Compose at least two sources with an overlapping recommendation id and prove
  first-source-wins behavior.

Acceptance:
- Tests cover accepted included-quota, accepted metered, rejected over-budget,
  and rejected privacy/provider-mismatch status through root and ChatStore.
- Hidden/unrendered ids and missing ids return nil before root injection, at
  root lookup, and after ChatStore composition.
- Source order stays first-wins for overlapping recommendation ids without
  stale accepted/rejected budget-copy mixing.
- Status-safe copy must not contain endpoint URLs, API keys, OAuth tokens,
  SDK/client handles, raw query text, raw page/provider payloads, payment/order
  data, or execution claims.
- A119 must not change AppBootstrap, ChatStore, SwiftUI, transport, StoreKit,
  MCP, crawler, Google/Gaode, memory, or real provider behavior.
- Run targeted AppBootstrap tests, full `test_sim`, forbidden-fragment scan for
  changed Swift files, and `git diff --check`.
```

Status after implementation: A119 proved A118 server-provider metered
entitlement status sources pass through `AppBootstrap(providerStatusSources:)`
and ChatStore lookup for rendered recommendation ids only. Tests cover accepted
included-quota, accepted metered, rejected over-budget, rejected privacy, and
rejected provider-mismatch status from source to app root to ChatStore. Hidden
and missing ids stay nil before root injection, at root lookup, and after
ChatStore composition. Source order stays first-wins for overlapping
recommendation ids without stale accepted/rejected budget-copy mixing, and no
production AppBootstrap, ChatStore, UI, runtime, transport, StoreKit, MCP,
crawler, Google/Gaode SDK, memory, telemetry, transcript, or provider execution
behavior changed.

## Round A120 - Server Provider Metered Entitlement Cross-Stage Status Composition Proof

```text
Task: Prove A118 server-provider metered entitlement status composes
deterministically with A106 vendor policy status, A93 payload dispatch status,
A109 dispatch authorization status, and A113 transport lease status through
`AppBootstrap(providerStatusSources:)` and ChatStore lookup. This is a
cross-stage status composition proof only. Do not add live Search API transport,
endpoint URLs, API keys, OAuth tokens, SDK clients, crawler runtime, MCP client
runtime, Google/Gaode SDKs, provider calls, AppBootstrap production defaults,
ChatStore production behavior, SwiftUI/UI layout, navigation, telemetry,
transcript mutation, StoreKit/payment, memory writes, raw page ingestion,
transport execution, or real provider execution.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Build five rendered-id scoped status sources for the same ready/blocked
  recommendation ids: A118 metered entitlement, A106 vendor policy, A93 payload
  dispatch, A109 dispatch authorization, and A113 transport lease.
- Include at least one hidden id in each source and prove all hidden ids return
  nil before app-root injection, at app-root lookup, and after ChatStore
  composition.
- Compose the sources through `AppBootstrap(providerStatusSources:)` in
  multiple source orders, including metered-first and lease-first.
- Verify ChatStore returns the first source exactly for both ready and blocked
  ids in each order.

Acceptance:
- Tests prove first-wins ordering across metered, vendor, dispatch,
  authorization, and lease sources.
- Selected status copy must not mix stale budget/vendor/dispatch/
  authorization/lease details from lower-priority sources.
- Hidden and missing ids return nil through source, app-root, and ChatStore
  lookup.
- Status-safe copy must not contain endpoint URLs, API keys, OAuth tokens,
  SDK/client handles, raw query text, raw page/provider payloads, payment/order
  data, source-host leakage from non-selected lower-priority sources, or
  execution claims.
- A120 must not change AppBootstrap, ChatStore, SwiftUI, transport, StoreKit,
  MCP, crawler, Google/Gaode, memory, or real provider behavior.
- Run targeted AppBootstrap tests, full `test_sim`, forbidden-fragment scan for
  changed Swift diffs, and `git diff --check`.
```

Status after implementation: A120 proved A118 metered entitlement status
composes deterministically with A106 vendor policy status, A93 payload dispatch
status, A109 dispatch authorization status, and A113 transport lease status
through `AppBootstrap(providerStatusSources:)` and ChatStore lookup. Tests build
all five rendered-id scoped sources for the same ready/blocked ids, include a
hidden id per source, verify hidden/missing nil lookup before source injection,
at app root, and after ChatStore composition, and cover metered-first,
vendor-first, dispatch-first, authorization-first, and lease-first source
orders. Selected ready/blocked presentations are exact first-source matches and
do not mix stale budget/vendor/dispatch/authorization/lease/query/execution
copy from lower-priority sources. No production AppBootstrap, ChatStore, UI,
runtime, transport, StoreKit, MCP/crawler, Google/Gaode SDK, memory, telemetry,
transcript, or provider execution behavior changed.

## Round A121 - Research / Market / Provider Cut-Plan Refresh After Metered Status Stack

```text
Task: Re-run the research, market, provider, MCP, API, and agent-architecture
cut-plan after A120. Treat current public papers, product/vendor docs, MCP
spec/security notes, iOS platform docs, Search API/vendor policies, maps/search
provider policies, open-source agent projects, and competitor product signals
as time-sensitive: browse and cite current primary sources where possible.
Decide whether the next safe implementation gate can introduce a real-provider
runtime precursor or must remain value-only. This is a research and architecture
sync only. Do not add Swift production code, live Search API transport, endpoint
URLs, API keys, OAuth tokens, SDK clients, crawler runtime, MCP client runtime,
Google/Gaode SDKs, provider calls, AppBootstrap production defaults, ChatStore
production behavior, SwiftUI/UI layout, navigation, telemetry, transcript
mutation, StoreKit/payment, memory writes, raw page ingestion, transport
execution, or real provider execution.

Allowed files:
- Docs/research/2026-agent-market-ui-provider-research.md
- Docs/research/2026-agent-architecture-deep-dive-v1.md
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Read the current A11-A120 architecture/status docs first and treat previous
  reports as untrusted claims.
- Recheck current external evidence from primary sources where available:
  advanced agent papers/architectures, MCP protocol/security work, Apple iOS
  action/model surfaces, search/provider policy docs, cost/entitlement surfaces,
  open-source agent frameworks, and relevant market competitors.
- Compare that evidence against kAir's completed value-only stack: provider
  routing, envelope/dry-run/readiness/receipt/status pipeline, Search API
  adapter contracts, vendor policy, dispatch authorization, transport lease,
  and metered entitlement status composition.
- Select exactly one next implementation slice and explain why it is safer than
  jumping directly to live provider execution. If live provider runtime remains
  blocked, name the missing contract precisely.
- Update the next-agent prompt with a paste-ready A122 coding frame: allowed
  files, explicit non-goals, acceptance checks, and required gates.

Acceptance:
- Research update cites current sources and separates primary evidence from
  product judgment.
- Architecture docs state whether the next slice is value-only or a
  real-provider-runtime precursor, and why.
- Prompt docs include one concrete A122 task with narrow allowed files and
  explicit bans on runtime/provider/API-key scope creep.
- No Swift, runtime, provider, UI, StoreKit, MCP client, crawler, maps SDK,
  app-root default, ChatStore behavior, transcript, telemetry, payment, or
  memory code changes.
- Run doc consistency scans for A120/A121/A122 naming, forbidden runtime/API-key
  scope creep in changed docs, and `git diff --check`.
```

Status after implementation: A121 rechecked current agent, MCP, Apple/iOS,
Google/Gaode, Search API, crawler, life-service, and competitor evidence
against the completed A120 metered entitlement status stack. The decision is to
keep live Search API, Google/Gaode, crawler, MCP, payment, booking, and remote
model runtime blocked. The next safe slice is A122: prove A112 Search API
transport lease issuance can be driven by accepted A117 metered entitlement
budget contexts, and that rejected or mismatched entitlement decisions cannot
issue leases.

## Round A122 - Search API Metered Entitlement Transport Lease Handoff Proof

```text
Task: Prove A112 Search API transport lease issuance can be driven by accepted
A117 server-provider metered entitlement budget contexts, and that rejected or
mismatched entitlement decisions cannot issue leases. This is a value-only
pre-runtime handoff proof. Do not add live Search API transport, endpoint URLs,
API keys, OAuth tokens, SDK clients, crawler runtime, MCP client runtime,
Google/Gaode SDKs, provider calls, AppBootstrap production defaults, ChatStore
production behavior, SwiftUI/UI layout, navigation, telemetry, transcript
mutation, StoreKit/payment, memory writes, raw page ingestion, transport
execution, or real provider execution.

Allowed files:
- kAirTests/Networking/ServerProviderSearchAPITransportLeaseTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Build accepted A117 `ServerProviderMeteredUsageDecision` values for
  included-quota and metered-premium Search API usage.
- Pass `decision.transportBudgetContext(...)` into the A112
  `ServerProviderSearchAPITransportLeaseGate.evaluate(...)` path.
- Verify leases issue only when payload decision, dispatch receipt, vendor
  dispatch authorization, provider family, capability, cost class, freshness,
  result shape, source policy, citation policy, and metered budget context all
  match.
- Prove rejected A117 decisions return nil budget context and cannot issue a
  lease.
- Prove mismatched provider family, cost class, vendor, or missing entitlement
  remains blocked without falling back to generic quota snapshots.

Acceptance:
- Tests cover accepted included-quota and accepted metered-premium A117
  decisions producing budget contexts that issue A112 leases.
- Tests cover rejected entitlement, privacy/Health block, over-quota, stale
  snapshot, provider mismatch, cost-class mismatch, and missing-entitlement
  decisions failing before lease issuance.
- Lease/status/debug/encoded copy contains no endpoint URL, API key, OAuth
  token, SDK/client handle, raw query text, raw page/provider payload,
  payment/order/booking data, crawler/MCP metadata, maps SDK metadata, or
  execution claim.
- A122 must not change production AppBootstrap, ChatStore, SwiftUI, runtime
  transport, StoreKit, crawler, MCP client, Google/Gaode SDK, memory, telemetry,
  transcript, payment, booking, or real provider behavior.
- Run targeted `ServerProviderSearchAPITransportLeaseTests`, full `test_sim` if
  Swift changed, forbidden-fragment scan for changed Swift diffs, touched-file
  trailing-whitespace scan, A121/A122 doc consistency scan, and
  `git diff --check`.
```

Status after implementation: A122 tightened the value-only transport lease
handoff so `ServerProviderSearchAPITransportBudgetContext` can carry accepted
A117 metered decision metadata, and `ServerProviderSearchAPITransportLeaseGate`
rejects generic or mismatched budget contexts before issuing a lease. Tests now
prove accepted included-quota and metered-premium A117 decisions can issue A112
leases only when provider, vendor, capability, cost class, freshness, source,
citation, payload dispatch, and vendor authorization metadata match. Rejected
entitlement decisions, privacy/Health blocks, over-quota, stale snapshot,
provider/vendor mismatch, cost-class mismatch, missing entitlement, and generic
budget contexts cannot issue leases. No live provider, endpoint, SDK, StoreKit,
MCP/crawler, maps SDK, AppBootstrap/ChatStore production default, UI,
telemetry, transcript, memory, payment, booking, or provider execution was
added.

## Round A123 - Metered Entitlement Transport Lease Status Handoff Proof

```text
Task: Prove A122 metered-entitlement transport leases package into A113
provider-status copy and pass through app-root and ChatStore lookup without
losing hidden/missing-id filtering, new metered-entitlement rejection reasons,
or source-order determinism. This is a status handoff proof only. Do not add
live Search API transport, endpoint URLs, API keys, OAuth tokens, SDK clients,
crawler runtime, MCP client runtime, Google/Gaode SDKs, provider calls,
AppBootstrap production defaults, ChatStore production behavior, SwiftUI/UI
layout, navigation, telemetry, transcript mutation, StoreKit/payment, memory
writes, raw page ingestion, transport execution, or real provider execution.

Allowed files:
- kAirTests/Networking/ServerProviderSearchAPITransportLeaseStatusSourceProducerTests.swift
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Build issued and rejected A122 leases from accepted/rejected A117 metered
  entitlement decisions.
- Package them through `ServerProviderSearchAPITransportLeaseStatusSourceProducer`
  and verify status copy covers issued, `meteredEntitlementMissing`,
  `vendorMismatch`, and cost/provider/capability mismatch cases without raw
  query, source-host leakage from hidden ids, endpoint, credential, or execution
  wording.
- Prove the produced source remains rendered-id scoped: hidden and missing ids
  return nil before app-root injection, at app-root lookup, and after ChatStore
  composition.
- Compose the metered-derived lease status source with a lower-priority fallback
  source and prove first-source-wins behavior without stale budget/vendor/lease
  detail mixing.

Acceptance:
- Tests cover A122 issued included-quota and metered-premium leases as
  `.ready` or equivalent advisory provider-status copy.
- Tests cover A122 rejected `meteredEntitlementMissing` and `vendorMismatch`
  leases as blocked/non-success status copy with truthful badge/tone behavior.
- Hidden/missing ids stay nil through source, AppBootstrap, and ChatStore.
- Source order remains first-wins and selected copy does not mix lower-priority
  budget/vendor/lease detail.
- A123 must not change production AppBootstrap, ChatStore, SwiftUI, runtime
  transport, StoreKit, crawler, MCP client, Google/Gaode SDK, memory, telemetry,
  transcript, payment, booking, or real provider behavior unless a status-copy
  gap is proven by tests.
- Run targeted lease status source and AppBootstrap tests, full `test_sim` if
  Swift changed, forbidden-fragment scan for changed Swift diffs, touched-file
  trailing-whitespace scan, A122/A123 doc consistency scan, and
  `git diff --check`.
```

Status after implementation: A123 proved A122 metered-entitlement transport
leases package through `ServerProviderSearchAPITransportLeaseStatusSourceProducer`
and pass through AppBootstrap/ChatStore lookup while staying rendered-id scoped.
Tests cover issued included-quota and metered-premium leases from accepted A117
decisions, rejected `meteredEntitlementMissing` and `vendorMismatch` leases,
hidden/missing nil lookup, first-source-wins ordering against lower-priority
fallback lease status, and safe copy without raw query, endpoint, credential,
source-host, crawler/MCP, maps SDK, payment/booking, or execution wording. No
production AppBootstrap, ChatStore, SwiftUI, transport, StoreKit, MCP/crawler,
Google/Gaode, memory, telemetry, transcript, payment, booking, or real provider
runtime behavior changed.

## Round A124 - Metered Entitlement Transport Lease Cross-Stage Status Composition Proof

```text
Task: Prove A123 metered-entitlement transport lease status composes
deterministically with A118 metered entitlement status, A106 vendor policy
status, A93 payload dispatch status, and A109 dispatch authorization status
through `AppBootstrap(providerStatusSources:)` and ChatStore lookup. This is a
cross-stage provider-status composition proof only. Do not add live Search API
transport, endpoint URLs, API keys, OAuth tokens, SDK clients, crawler runtime,
MCP client runtime, Google/Gaode SDKs, provider calls, AppBootstrap production
defaults, ChatStore production behavior, SwiftUI/UI layout, navigation,
telemetry, transcript mutation, StoreKit/payment, memory writes, raw page
ingestion, transport execution, or real provider execution.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Build five rendered-id scoped status sources for the same ready/blocked ids:
  A118 metered entitlement, A106 vendor policy, A93 payload dispatch, A109
  dispatch authorization, and A123 metered-entitlement transport lease status.
- Include at least one hidden id in each source and prove all hidden/missing ids
  return nil before app-root injection, at app-root lookup, and after ChatStore
  composition.
- Compose sources through `AppBootstrap(providerStatusSources:)` in multiple
  orders, including metered-first and lease-first.
- Verify ChatStore returns the first source exactly for ready and blocked ids in
  each order.

Acceptance:
- Tests prove first-wins ordering across metered entitlement, vendor, dispatch,
  authorization, and metered-derived lease status sources.
- Selected status copy must not mix stale budget/vendor/dispatch/
  authorization/lease details from lower-priority sources.
- Hidden and missing ids return nil through source, app-root, and ChatStore
  lookup.
- Status-safe copy must not contain endpoint URLs, API keys, OAuth tokens,
  SDK/client handles, raw query text, raw page/provider payloads, payment/order/
  booking data, crawler/MCP metadata, maps SDK metadata, source-host leakage
  from hidden or lower-priority sources, or execution claims.
- A124 must not change production AppBootstrap, ChatStore, SwiftUI, runtime
  transport, StoreKit, crawler, MCP client, Google/Gaode SDK, memory, telemetry,
  transcript, payment, booking, or real provider behavior.
- Run targeted AppBootstrap tests, full `test_sim` if Swift changed,
  forbidden-fragment scan for changed Swift diffs, touched-file
  trailing-whitespace scan, A123/A124 doc consistency scan, and
  `git diff --check`.
```

Status after implementation: A124 proved A123 metered-entitlement transport
lease status composes through `AppBootstrap(providerStatusSources:)` and
ChatStore lookup with A118 metered entitlement, A106 vendor policy, A93 payload
dispatch, and A109 dispatch authorization status. Tests cover metered-first,
vendor-first, dispatch-first, authorization-first, and lease-first source
orders for ready and blocked recommendations, hidden/missing nil lookup, exact
first-source equality at root and ChatStore, and no stale
budget/vendor/dispatch/authorization/lease detail mixing. No production
AppBootstrap, ChatStore, SwiftUI, transport, StoreKit, MCP/crawler,
Google/Gaode, memory, telemetry, transcript, payment, booking, or real provider
runtime behavior changed.

## Round A125 - Research Market Provider Cut-Plan Refresh After Metered Lease Composition

```text
Task: Re-run the current kAir architecture, market, UI, provider, MCP, and
cost-routing cut-plan after A124. Treat the current repo and docs as ground
truth, then verify current external evidence before selecting the next code
gate. This is a docs/research planning round only unless the review discovers
stale or unsafe docs that need correction. Do not add live Search API transport,
endpoint URLs, API keys, OAuth tokens, SDK clients, crawler runtime, MCP client
runtime, Google/Gaode SDKs, provider calls, AppBootstrap production defaults,
ChatStore production behavior, SwiftUI/UI layout, navigation, telemetry,
transcript mutation, StoreKit/payment, memory writes, raw page ingestion,
transport execution, or real provider execution.

Allowed files:
- Docs/research/2026-agent-market-ui-provider-research.md
- Docs/research/2026-agent-architecture-deep-dive-v1.md
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Research scope:
- Recheck recent agent architecture papers and reports from authoritative
  sources such as arXiv, Google Scholar-indexed papers, IEEE/ACM when
  available, vendor engineering docs, and standards/specification sources.
- Recheck MCP specification/security/access-control direction and how it
  affects kAir's deferred MCP client/server interface.
- Recheck Apple App Intents, Foundation Models, Core Location, and local iOS
  execution constraints relevant to kAir's local-first default path.
- Recheck Google Maps/Places and Gaode public pricing, quota, privacy, key,
  attribution, and policy surfaces for future membership-gated provider
  routing.
- Recheck Search API/crawler/public-information provider surfaces, robots/source
  attribution constraints, and cost/freshness tradeoffs.
- Recheck competitor signals from MARVIS-style mobile assistants, Tencent
  Yuanbao/Hy3-style assistants, Meituan life-service agents, and other public
  agent products that affect UI, trust, provider status, and life-service
  workflow design.

Output shape:
- Update the research docs with concrete citations and a short current-state
  decision: either keep live providers deferred or name the narrowest next
  pre-runtime code gate.
- Update the architecture prompt docs with the next exact round label,
  acceptance criteria, allowed files, and explicit non-goals.
- Preserve the existing local-first, value-only, rendered-id scoped, cost-aware,
  privacy-gated contract unless current evidence proves a safer replacement.

Acceptance:
- The docs clearly explain whether A124 is enough to start live provider runtime
  work or which pre-runtime gate still comes first.
- The decision accounts for UI trust/status copy, membership/cost routing,
  Google/Gaode provider switching, Search API/crawler public-info retrieval,
  MCP interface reservation, and local iOS defaults.
- All citations are current enough for the May 31, 2026 decision point and are
  linked or otherwise source-identifiable.
- Run `git diff --check`, touched-file trailing-whitespace scan, and stale-next
  prompt consistency scan.
```

Status after implementation: A125 rechecked current research, provider docs,
MCP/security direction, Apple platform constraints, Google/Gaode/Search API
provider policy, and public competitor signals after the completed A124 stack.
The decision remains no live Search API, Google/Gaode, crawler, MCP, payment,
booking, or remote model runtime yet. The next narrow code gate is a value-only
Search API transport request contract that binds an issued A122
metered-entitlement transport lease to the exact request, payload, dispatch,
vendor, authorization, source, citation, result-shape, freshness, cost, and
metered decision metadata a future server adapter would consume.

## Round A126 - Search API Transport Request Contract Proof

```text
Task: Add a value-only Search API transport request contract. The contract must
prepare a metadata-only server-side Search API transport request only from an
issued A122 metered-entitlement transport lease plus the matching A86 request,
A91 payload, A92 dispatch receipt, A105 vendor policy decision, and A108
dispatch authorization metadata. This is still pre-runtime. Do not add live
Search API transport, endpoint URLs, API keys, OAuth tokens, SDK clients,
URLSession, crawler runtime, MCP client runtime, Google/Gaode SDKs, provider
calls, AppBootstrap production defaults, ChatStore production behavior,
SwiftUI/UI layout, navigation, telemetry, transcript mutation, StoreKit/payment,
memory writes, raw page ingestion, transport execution, or real provider
execution.

Allowed files:
- kAir/Core/Networking/ServerProviderSearchAPITransportRequest.swift
- kAirTests/Networking/ServerProviderSearchAPITransportRequestTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add `ServerProviderSearchAPITransportRequest` as a Codable/Hashable/Sendable
  metadata-only value containing safe ids and typed metadata needed by a future
  server adapter: request id, payload id, dispatch receipt id, vendor decision
  id, authorization id, lease id, metered decision id, provider family, vendor
  id, capability, cost class, freshness, result shape, result limit, and
  source/citation policy summary.
- Add `ServerProviderSearchAPITransportRequestDecision` with prepared/rejected
  state, rejection reason, status-safe summary, optional request, and nested
  upstream rejection fields.
- Add a pure `ServerProviderSearchAPITransportRequestBuilder`/gate that rejects
  unless the lease is issued and every upstream id and safe metadata field
  matches the request/payload/dispatch/vendor/authorization/lease chain.
- Rejection reasons should include missing/rejected lease, missing payload,
  missing request, missing dispatch, missing vendor decision, missing
  authorization, lease-payload mismatch, lease-dispatch mismatch,
  lease-authorization mismatch, provider/vendor/capability/cost/freshness/result
  shape/result limit mismatch, source-policy mismatch, citation-policy missing,
  and missing metered decision id.

Acceptance:
- Tests prove an issued metered-entitlement Search API lease prepares a request
  only when all upstream ids and typed metadata match.
- Tests prove rejected leases, generic-budget leases, stale payload/dispatch/
  vendor/authorization metadata, mismatched result shape, missing citation
  policy, missing metered decision id, and hidden generic quota snapshots reject
  deterministically.
- Encoded/debug/status copy contains no endpoint URL, API key, OAuth token,
  SDK/client handle, raw query, raw page/provider payload, payment/order data,
  crawler/MCP metadata, maps SDK metadata, or execution claim.
- A126 must not change production AppBootstrap, ChatStore, SwiftUI, runtime
  transport, StoreKit, crawler, MCP client, Google/Gaode SDK, memory, telemetry,
  transcript, payment, booking, or real provider behavior.
- Run targeted `ServerProviderSearchAPITransportRequestTests`, full `test_sim`
  if Swift changed, forbidden-fragment scan for changed Swift diffs,
  touched-file trailing-whitespace scan, A125/A126 doc consistency scan, and
  `git diff --check`.
```

Status after implementation: A126 added a value-only
`ServerProviderSearchAPITransportRequest` contract plus targeted tests. The
request decision can be prepared only from an issued A122 metered-entitlement
lease and matching A86 request, A91 payload, A92 dispatch receipt, A105 vendor
policy decision, A108 dispatch authorization, budget context, source/citation
policy, result shape, freshness, cost, and metered decision metadata. Rejected
leases, generic budget contexts, stale upstream ids, source/citation drift, and
metadata mismatches reject deterministically. No endpoint, credential,
URLSession, SDK, crawler/MCP, Google/Gaode, StoreKit, SwiftUI, AppBootstrap,
ChatStore, telemetry, transcript, memory, payment, booking, transport, or real
provider runtime behavior changed.

## Round A127 - Search API Transport Request Status Source Proof

```text
Task: Package A126 Search API transport request decisions into a rendered-id
scoped provider-status source. This is advisory status plumbing only. Do not
add live Search API transport, endpoint URLs, API keys, OAuth tokens, SDK
clients, URLSession, crawler runtime, MCP client runtime, Google/Gaode SDKs,
provider calls, AppBootstrap production defaults, ChatStore production
behavior, SwiftUI/UI layout, navigation, telemetry, transcript mutation,
StoreKit/payment, memory writes, raw page ingestion, transport execution, or
real provider execution.

Allowed files:
- kAir/Core/Networking/ServerProviderSearchAPITransportRequestStatusSourceProducer.swift
- kAirTests/Networking/ServerProviderSearchAPITransportRequestStatusSourceProducerTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add a status source producer that accepts explicit recommendation ids plus
  `ServerProviderSearchAPITransportRequestDecision` values and wraps them behind
  an explicit `renderedRecommendationIDs` set.
- Prepared request decisions should produce UI-safe advisory status copy with
  remote provider, metered/included cost, freshness, vendor id, lease id, budget
  id, metered decision id, result shape, result limit, and source/citation
  summary, but no raw query, source-host, endpoint, credential, SDK/client,
  crawler/MCP, maps SDK, payment/order, or execution copy.
- Rejected decisions should preserve the A126 rejection reason and nested
  request/payload/dispatch/vendor/authorization/lease reasons as blocked
  advisory copy.
- Duplicate recommendation ids keep the first input; hidden and missing ids
  return nil.

Acceptance:
- Tests prove prepared and rejected A126 decisions package into
  `ProviderStatusPresentation` with stable badges/card hints and safe copy.
- Tests prove duplicate first-wins behavior and hidden/missing nil lookup.
- Tests prove encoded/debug/status copy contains no endpoint URL, API key,
  OAuth token, SDK/client handle, raw query, raw page/provider payload,
  source-host leakage, crawler/MCP metadata, maps SDK metadata, payment/order
  data, or execution claim.
- A127 must not change production AppBootstrap, ChatStore, SwiftUI, runtime
  transport, StoreKit, crawler, MCP client, Google/Gaode SDK, memory, telemetry,
  transcript, payment, booking, or real provider behavior.
- Run targeted `ServerProviderSearchAPITransportRequestStatusSourceProducerTests`,
  full `test_sim` if Swift changed, forbidden-fragment scan for changed Swift
  diffs, touched-file trailing-whitespace scan, A126/A127 doc consistency scan,
  and `git diff --check`.
```

Status after implementation: A127 added
`ServerProviderSearchAPITransportRequestStatusSourceProducer` plus targeted
tests. A126 prepared/rejected transport request decisions now package into
rendered-id scoped provider-status presentations with stable badges/card hints,
duplicate first-wins behavior, hidden/missing nil lookup, safe source/citation
summary copy, nested rejection reason copy, and no raw query, source-host,
endpoint, credential, SDK, crawler/MCP, maps, payment, booking, transport, or
real provider execution leakage. No AppBootstrap, ChatStore, SwiftUI, runtime,
StoreKit, memory, telemetry, transcript, payment, booking, or provider behavior
changed.

## Round A128 - Search API Transport Request Status App-Root Handoff Proof

```text
Task: Prove A127 Search API transport request status sources pass through
`AppBootstrap(providerStatusSources:)` and ChatStore provider-status lookup for
rendered recommendation ids only. This is app-root handoff proof only. Do not
add live Search API transport, endpoint URLs, API keys, OAuth tokens, SDK
clients, URLSession, crawler runtime, MCP client runtime, Google/Gaode SDKs,
provider calls, AppBootstrap production defaults, ChatStore production
behavior, SwiftUI/UI layout, navigation, telemetry, transcript mutation,
StoreKit/payment, memory writes, raw page ingestion, transport execution, or
real provider execution.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Follow the existing A88/A94/A98/A103/A107/A110/A114/A119 app-root handoff
  test pattern in `AppBootstrapTests.swift`.
- Use `ServerProviderSearchAPITransportRequestStatusSourceProducer` to create
  rendered-id scoped sources containing at least one prepared A126 request
  decision and one rejected A126 request decision.
- Inject those sources through `AppBootstrap(providerStatusSources:)`.
- Verify root-level `providerStatusPresentation(for:)` and ChatStore lookup
  return the same rendered-id scoped prepared/rejected presentations.
- Compose at least two sources with an overlapping recommendation id and prove
  first-source-wins behavior without mixing request id, vendor id, lease id,
  budget id, metered decision id, rejection reason, or status copy from later
  sources.
- Keep all fixtures value-only; do not instantiate transport clients or
  provider runtimes.

Acceptance:
- Tests prove prepared and rejected A127 request status presentations pass
  unchanged through AppBootstrap and ChatStore for rendered ids.
- Hidden/unrendered ids and missing ids return nil before root injection, at
  root lookup, and after ChatStore composition.
- Source order stays first-wins for overlapping recommendation ids without
  stale request/vendor/lease/budget/metered/rejection copy mixing.
- Status-safe copy must not contain endpoint URLs, API keys, OAuth tokens,
  SDK/client handles, raw query text, source-host values, raw page/provider
  payloads, crawler/MCP metadata, maps SDK metadata, payment/order data, or
  execution claims.
- A128 must not change AppBootstrap production defaults, ChatStore production
  behavior, SwiftUI, transport, StoreKit, MCP, crawler, Google/Gaode, memory,
  telemetry, transcript, payment, booking, or real provider behavior.
- Run targeted AppBootstrap A128 tests, full `test_sim`, forbidden-fragment
  scan for changed Swift files, touched-file trailing-whitespace scan,
  A127/A128 doc consistency scan, and `git diff --check`.
```

Status after implementation: A128 proved A127 Search API transport request
status sources pass through `AppBootstrap(providerStatusSources:)` and ChatStore
provider-status lookup for rendered ids only. Prepared/rejected copy remains
unchanged from source to root to store; hidden/unrendered/missing ids stay nil;
source order remains first-wins; selected copy does not mix later request,
vendor, lease, budget, metered-decision, or rejection details. No production
AppBootstrap defaults, ChatStore behavior, SwiftUI, transport, StoreKit, MCP,
crawler, Google/Gaode SDK, memory, telemetry, transcript, payment, booking, or
provider execution behavior changed.

## Round A129 - Search API Transport Request Cross-Stage Status Composition Proof

```text
Task: Prove A127 Search API transport request status composes deterministically
with A118 metered entitlement, A106 vendor policy, A93 payload dispatch, A109
dispatch authorization, and A113 transport lease status through
`AppBootstrap(providerStatusSources:)` and ChatStore lookup. This is
cross-stage status composition proof only. Do not add live Search API transport,
endpoint URLs, API keys, OAuth tokens, SDK clients, URLSession, crawler runtime,
MCP client runtime, Google/Gaode SDKs, provider calls, AppBootstrap production
defaults, ChatStore production behavior, SwiftUI/UI layout, navigation,
telemetry, transcript mutation, StoreKit/payment, memory writes, raw page
ingestion, transport execution, or real provider execution.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Build rendered-id scoped sources for the same ready and blocked
  recommendation ids:
  - A118 `ServerProviderMeteredEntitlementStatusSourceProducer`
  - A106 `ServerProviderSearchAPIVendorPolicyStatusSourceProducer`
  - A93 `ServerProviderSearchAPIAdapterPayloadDispatchStatusSourceProducer`
  - A109 `ServerProviderSearchAPIVendorPolicyDispatchAuthorizationStatusSourceProducer`
  - A113 `ServerProviderSearchAPITransportLeaseStatusSourceProducer`
  - A127 `ServerProviderSearchAPITransportRequestStatusSourceProducer`
- Include hidden ids inside each source and prove they stay nil before and
  after app-root/ChatStore composition.
- Inject the same sources through `AppBootstrap(providerStatusSources:)` in
  multiple source orders. Prove the first source wins for each order.
- For every selected status, prove it contains only the selected layer's
  advisory copy and does not mix stale vendor, dispatch, authorization, lease,
  budget, metered-decision, request, source-host, query, raw page, payment,
  booking, or execution details from later sources.

Acceptance:
- Tests cover at least ready and blocked recommendation ids across all six
  status layers.
- Tests prove first-source-wins ordering when request status wins and when at
  least one earlier upstream layer wins over request status.
- Hidden/unrendered ids and missing ids return nil at source, app root, and
  ChatStore lookup.
- Status-safe copy must not contain endpoint URLs, API keys, OAuth tokens,
  SDK/client handles, raw query text, source-host values, raw page/provider
  payloads, crawler/MCP metadata, maps SDK metadata, payment/order data, or
  execution claims.
- A129 must not change AppBootstrap production defaults, ChatStore production
  behavior, SwiftUI, transport, StoreKit, MCP, crawler, Google/Gaode, memory,
  telemetry, transcript, payment, booking, or real provider behavior.
- Run targeted AppBootstrap A129 tests, full `test_sim`, forbidden-fragment
  scan for changed Swift files, touched-file trailing-whitespace scan,
  A128/A129 doc consistency scan, and `git diff --check`.
```

Status after implementation: A129 proved A127 Search API transport request
status composes deterministically with A118 metered entitlement, A106 vendor
policy, A93 payload dispatch, A109 dispatch authorization, and A113 transport
lease status through `AppBootstrap(providerStatusSources:)` and ChatStore
lookup. Tests cover ready/blocked ids across all six layers, first-source-wins
ordering for every layer including request status, hidden/missing nil lookup,
and no stale metered, vendor, dispatch, authorization, lease, request, budget,
metered-decision, source-host, query, payment, booking, or execution-detail
mixing. No production AppBootstrap defaults, ChatStore behavior, SwiftUI,
transport, StoreKit, MCP, crawler, Google/Gaode SDK, memory, telemetry,
transcript, payment, booking, or provider execution behavior changed.

## Round A130 - Research and Provider Cut-Plan Refresh After Request Status Composition

```text
Task: Refresh kAir's research, market, UI, provider-policy, MCP/crawler, maps,
and cost-aware routing cut plan after A129. This is docs/research only. Do not
add Swift runtime behavior, endpoint URLs, API keys, OAuth tokens, SDK clients,
URLSession, crawler runtime, MCP client runtime, Google/Gaode SDKs, provider
calls, AppBootstrap production defaults, ChatStore production behavior,
SwiftUI/UI layout, navigation, telemetry, transcript mutation, StoreKit/payment,
memory writes, raw page ingestion, transport execution, or real provider
execution.

Allowed files:
- Docs/research/2026-agent-market-ui-provider-research.md
- Docs/research/2026-agent-architecture-deep-dive-v1.md
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Research requirements:
- Recheck current agent papers and architecture signals from authoritative
  sources such as Google Scholar, IEEE, ACM/arXiv where available, plus Apple
  developer docs and current provider docs.
- Recheck public product/market signals for MARVIS-style mobile assistants,
  Tencent Yuanbao, Meituan LongCat/life-service agents, Google/Gaode maps,
  Search API vendors, MCP security/spec direction, and crawler/robots policy.
- Compare the external evidence against the current A11-A129 repo state:
  local-first iOS execution, membership/cost-aware Google/Gaode escalation,
  Search API/crawler public-info lookup, MCP reserved interfaces, Health
  local-only privacy, and rendered-id scoped provider-status plumbing.
- Decide the next safest code gate. Prefer another value-only or server-side
  proof unless evidence and current repo state justify a narrower
  runtime-adjacent slice.

Acceptance:
- Docs clearly state what changed since A125/A121/A116 research refreshes and
  why the next gate was selected.
- Docs list explicit non-goals for live Search API, Google/Gaode SDKs,
  crawler runtime, MCP client runtime, payment/booking, remote model runtime,
  and hidden third-party app control unless the selected next gate intentionally
  narrows one of those items with tests.
- `kair-next-agent-prompts-v1.md` ends with one paste-ready next coding prompt.
- Run `git diff --check`, touched-file trailing-whitespace scan, and stale
  A129/A130 doc consistency scan. No Swift build is required if only docs
  changed.
```

Status after implementation: A130 rechecked current cost-aware routing and
agent papers, MCP specification/security direction, Apple platform docs,
Google/Gaode maps policy, Search API vendor docs, crawler/robots policy, and
public competitor/life-service signals against the completed A11-A129 repo
state. The decision remains no live Search API, Google/Gaode SDK/API runtime,
crawler runtime, MCP client runtime, payment, booking, remote model runtime, or
hidden third-party app control yet. The next narrow code gate is a value-only
Search API transport response receipt contract that binds a normalized/cited
adapter result receipt to the prepared A126 transport request and full metered,
vendor, lease, source, citation, cost, and freshness chain.

## Round A131 - Search API Transport Response Receipt Contract Proof

```text
Task: Add a value-only Search API transport response receipt contract. The
contract must accept a normalized/cited Search API adapter result receipt only
when it belongs to the exact prepared A126 transport request and matching
upstream request/payload/dispatch/vendor/authorization/lease/budget/metered
metadata. This is still pre-runtime. Do not add live Search API transport,
endpoint URLs, API keys, OAuth tokens, SDK clients, URLSession, crawler runtime,
MCP client runtime, Google/Gaode SDKs, provider calls, AppBootstrap production
defaults, ChatStore production behavior, SwiftUI/UI layout, navigation,
telemetry, transcript mutation, StoreKit/payment, memory writes, raw page
ingestion, transport execution, booking/payment/order flow, remote model
runtime, hidden third-party app control, or real provider execution.

Allowed files:
- kAir/Core/Networking/ServerProviderSearchAPITransportResponse.swift
- kAirTests/Networking/ServerProviderSearchAPITransportResponseTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add `ServerProviderSearchAPITransportResponse` as a Codable/Hashable/Sendable
  value-only receipt containing safe ids and typed metadata from the accepted
  chain: response id, transport request id, adapter result receipt id, request
  id, payload decision id, payload id, dispatch receipt id, vendor decision id,
  authorization id, lease id, budget id, metered decision id, provider family,
  vendor id, capability, cost class, freshness, result shape, requested result
  limit, returned result count, citation count, and source/citation summary.
- Add `ServerProviderSearchAPITransportResponseDecision` with accepted/rejected
  state, rejection reason, status-safe summary, optional response, and nested
  request/result rejection fields. Keep descriptions and status lines safe:
  they may name ids and policy states but must not include raw query text, raw
  page/provider payloads, provider endpoints, credentials, SDK/client handles,
  payment/order data, crawler/MCP metadata, maps SDK metadata, or execution
  claims.
- Add a pure `ServerProviderSearchAPITransportResponseBuilder`/gate that
  accepts only when the A126 request decision is prepared, the A86 adapter
  result receipt is normalized, and provider/capability/cost/freshness/source/
  citation/result-limit metadata still matches the A126 request.
- Rejection reasons should include missing/rejected transport request decision,
  missing transport request, missing adapter result receipt, adapter result
  rejected, missing result, request id mismatch, provider family mismatch,
  capability mismatch, cost class mismatch, freshness mismatch, result-limit
  overflow, source/citation policy mismatch, citation missing, vendor missing,
  lease/budget/metered metadata missing, and normalized content missing.
- Add only succinct comments that explain invariant boundaries, for example
  why this receipt is still pre-runtime and why status-safe copy cannot expose
  raw queries or provider endpoints.

Acceptance:
- Tests prove a prepared A126 request plus a normalized/cited adapter result
  receipt produces an accepted response receipt with all upstream ids and typed
  metadata preserved.
- Tests prove missing/rejected request decisions, missing requests, rejected
  adapter result receipts, missing normalized result, request/provider/
  capability/cost/freshness/source/citation mismatches, result-limit overflow,
  and missing lease/budget/metered metadata reject deterministically.
- Tests prove encoded/debug/status-safe copy contains no endpoint URL, API key,
  OAuth token, SDK/client handle, raw query, raw page/provider payload,
  crawler/MCP metadata, maps SDK metadata, StoreKit/payment/order/booking data,
  hidden third-party app-control claim, or execution claim. Public citation URL
  values may exist only inside the pre-existing normalized adapter result
  structures; do not put them in status-safe copy.
- A131 must not change production AppBootstrap defaults, ChatStore production
  behavior, SwiftUI, runtime transport, StoreKit, crawler, MCP client,
  Google/Gaode SDK, memory, telemetry, transcript, payment, booking, remote
  model runtime, hidden app control, or real provider behavior.
- Run targeted `ServerProviderSearchAPITransportResponseTests`, full
  `test_sim` if Swift changed, forbidden-fragment scan for changed Swift diffs
  with citation fixtures reviewed separately from provider endpoint strings,
  touched-file trailing-whitespace scan, A130/A131 doc consistency scan, and
  `git diff --check`.
```

Status after implementation: A131 added a value-only
`ServerProviderSearchAPITransportResponse` contract plus targeted tests. A
normalized/cited A86 adapter result receipt can be accepted only when it belongs
to the prepared A126 transport request and preserves the request, payload,
dispatch, vendor, authorization, lease, budget, metered decision, source,
citation, cost, freshness, result-shape, and result-limit chain. Missing or
rejected request/result decisions, request/provider/capability/cost/freshness
mismatches, result-limit overflow, source/citation drift, normalized-content
gaps, and missing vendor/lease/budget/metered metadata reject before runtime.
No endpoint, credential, URLSession, SDK, crawler/MCP, Google/Gaode SDK,
StoreKit, SwiftUI, AppBootstrap, ChatStore, telemetry, transcript, memory,
payment, booking, hidden app control, transport, or real provider runtime
behavior changed.

## Round A132 - Search API Transport Response Status Source Proof

```text
Task: Package A131 Search API transport response decisions into a rendered-id
scoped provider-status source. This is advisory status plumbing only. Do not
add live Search API transport, endpoint URLs, API keys, OAuth tokens, SDK
clients, URLSession, crawler runtime, MCP client runtime, Google/Gaode SDKs,
provider calls, AppBootstrap production defaults, ChatStore production
behavior, SwiftUI/UI layout, navigation, telemetry, transcript mutation,
StoreKit/payment, memory writes, raw page ingestion, transport execution,
booking/payment/order flow, remote model runtime, hidden third-party app
control, or real provider execution.

Allowed files:
- kAir/Core/Networking/ServerProviderSearchAPITransportResponseStatusSourceProducer.swift
- kAirTests/Networking/ServerProviderSearchAPITransportResponseStatusSourceProducerTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add a status source producer that accepts explicit recommendation ids plus
  `ServerProviderSearchAPITransportResponseDecision` values and wraps them
  behind an explicit `renderedRecommendationIDs` set.
- Accepted response decisions should produce UI-safe advisory status copy with
  remote provider, vendor id, metered/included cost, freshness, result shape,
  requested result limit, returned result count, citation count, response id,
  transport request id, lease id, budget id, metered decision id, and
  source/citation policy summary.
- Rejected response decisions should preserve the A131 rejection reason and
  nested A126 request/A86 result rejection reasons as blocked advisory copy.
- Duplicate recommendation ids keep the first input; hidden and missing ids
  return nil.
- Keep status copy safe: no raw query text, citation URL values, source-host
  values, raw page/provider payloads, provider endpoints, credentials,
  SDK/client handles, crawler/MCP metadata, maps SDK metadata, payment/order/
  booking data, hidden app-control claims, or execution claims.

Acceptance:
- Tests prove accepted and rejected A131 response decisions package into
  `ProviderStatusPresentation` with stable badges/card hints and safe copy.
- Tests prove duplicate first-wins behavior and hidden/missing nil lookup.
- Tests prove encoded/debug/status copy contains no endpoint URL, API key,
  OAuth token, SDK/client handle, raw query, citation URL, source-host,
  raw page/provider payload, crawler/MCP metadata, maps SDK metadata,
  StoreKit/payment/order/booking data, hidden third-party app-control claim, or
  execution claim.
- A132 must not change production AppBootstrap, ChatStore, SwiftUI, runtime
  transport, StoreKit, crawler, MCP client, Google/Gaode SDK, memory,
  telemetry, transcript, payment, booking, remote model runtime, hidden app
  control, or real provider behavior.
- Run targeted
  `ServerProviderSearchAPITransportResponseStatusSourceProducerTests`, full
  `test_sim` if Swift changed, forbidden-fragment scan for changed Swift diffs,
  touched-file trailing-whitespace scan, A131/A132 doc consistency scan, and
  `git diff --check`.
```

Status after implementation: A132 added
`ServerProviderSearchAPITransportResponseStatusSourceProducer` plus targeted
tests. A131 accepted/rejected response decisions now package into rendered-id
scoped provider-status presentations with stable badges/card hints, duplicate
first-wins behavior, hidden/missing nil lookup, safe response/request/vendor/
lease/budget/metered/result-count/citation-count/source-policy copy, nested A126
request and A86 result rejection reason copy, and no raw query, citation URL,
source-host value, endpoint, credential, SDK, crawler/MCP, maps, payment,
booking, hidden app-control, transport, or real provider execution leakage. No
AppBootstrap, ChatStore, SwiftUI, runtime, StoreKit, memory, telemetry,
transcript, payment, booking, hidden app control, or provider behavior changed.

## Round A133 - Search API Transport Response Status App-Root Handoff Proof

```text
Task: Prove A132 Search API transport response status sources pass through
`AppBootstrap(providerStatusSources:)` and ChatStore provider-status lookup for
rendered recommendation ids only. This is app-root handoff proof only. Do not
add live Search API transport, endpoint URLs, API keys, OAuth tokens, SDK
clients, URLSession, crawler runtime, MCP client runtime, Google/Gaode SDKs,
provider calls, AppBootstrap production defaults, ChatStore production
behavior, SwiftUI/UI layout, navigation, telemetry, transcript mutation,
StoreKit/payment, memory writes, raw page ingestion, transport execution,
booking/payment/order flow, remote model runtime, hidden third-party app
control, or real provider execution.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Follow the existing A88/A94/A98/A103/A107/A110/A114/A119/A128 app-root
  handoff test pattern in `AppBootstrapTests.swift`.
- Use `ServerProviderSearchAPITransportResponseStatusSourceProducer` to create
  rendered-id scoped sources containing at least one accepted A131 response
  decision and one rejected A131 response decision.
- Inject those sources through `AppBootstrap(providerStatusSources:)`.
- Verify root-level `providerStatusPresentation(for:)` and ChatStore lookup
  return the same rendered-id scoped accepted/rejected presentations.
- Compose at least two sources with an overlapping recommendation id and prove
  first-source-wins behavior without mixing response id, transport request id,
  adapter result receipt id, vendor id, lease id, budget id, metered decision
  id, result/citation counts, rejection reason, or status copy from later
  sources.
- Keep all fixtures value-only; do not instantiate transport clients, provider
  runtimes, crawler/MCP clients, map SDKs, payment/booking handlers, or hidden
  app-control surfaces.

Acceptance:
- Tests prove accepted and rejected A132 response status presentations pass
  unchanged through AppBootstrap and ChatStore for rendered ids.
- Hidden/unrendered ids and missing ids return nil before root injection, at
  root lookup, and after ChatStore composition.
- Source order stays first-wins for overlapping recommendation ids without
  stale response/request/result/vendor/lease/budget/metered/rejection copy
  mixing.
- Status-safe copy must not contain endpoint URLs, API keys, OAuth tokens,
  SDK/client handles, raw query text, citation URL values, source-host values,
  raw page/provider payloads, crawler/MCP metadata, maps SDK metadata,
  StoreKit/payment/order/booking data, hidden app-control claims, or execution
  claims.
- A133 must not change AppBootstrap production defaults, ChatStore production
  behavior, SwiftUI, transport, StoreKit, MCP, crawler, Google/Gaode, memory,
  telemetry, transcript, payment, booking, remote model runtime, hidden app
  control, or real provider behavior.
- Run targeted AppBootstrap A133 tests, full `test_sim`, forbidden-fragment
  scan for changed Swift diffs, touched-file trailing-whitespace scan,
  A132/A133 doc consistency scan, and `git diff --check`.
```

Status after implementation: A133 proved A132 Search API transport response
status sources pass through `AppBootstrap(providerStatusSources:)` and ChatStore
provider-status lookup for rendered ids only. Accepted/rejected copy remains
unchanged from source to root to store; hidden/unrendered/missing ids stay nil;
source order remains first-wins; selected copy does not mix later response,
transport request, adapter result receipt, vendor, lease, budget, metered
decision, result/citation count, or rejection details. No production
AppBootstrap defaults, ChatStore behavior, SwiftUI, transport, StoreKit, MCP,
crawler, Google/Gaode SDK, memory, telemetry, transcript, payment, booking,
remote model runtime, hidden app control, or provider execution behavior
changed.

## Round A134 - Search API Transport Response Cross-Stage Status Composition Proof

```text
Task: Prove A132 Search API transport response status composes
deterministically with A118 metered entitlement, A106 vendor policy, A93
payload dispatch, A109 dispatch authorization, A113 transport lease status, and
A127 transport request status through `AppBootstrap(providerStatusSources:)`
and ChatStore lookup. This is cross-stage status composition proof only. Do not
add live Search API transport, endpoint URLs, API keys, OAuth tokens, SDK
clients, URLSession, crawler runtime, MCP client runtime, Google/Gaode SDKs,
provider calls, AppBootstrap production defaults, ChatStore production
behavior, SwiftUI/UI layout, navigation, telemetry, transcript mutation,
StoreKit/payment, memory writes, raw page ingestion, transport execution,
booking/payment/order flow, remote model runtime, hidden third-party app
control, or real provider execution.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Build rendered-id scoped sources for the same ready and blocked
  recommendation ids:
  - A118 `ServerProviderMeteredEntitlementStatusSourceProducer`
  - A106 `ServerProviderSearchAPIVendorPolicyStatusSourceProducer`
  - A93 `ServerProviderSearchAPIAdapterPayloadDispatchStatusSourceProducer`
  - A109 `ServerProviderSearchAPIVendorPolicyDispatchAuthorizationStatusSourceProducer`
  - A113 `ServerProviderSearchAPITransportLeaseStatusSourceProducer`
  - A127 `ServerProviderSearchAPITransportRequestStatusSourceProducer`
  - A132 `ServerProviderSearchAPITransportResponseStatusSourceProducer`
- Include hidden ids inside each source and prove they stay nil before and
  after app-root/ChatStore composition.
- Inject the same sources through `AppBootstrap(providerStatusSources:)` in
  multiple source orders. Prove the first source wins for each order.
- For every selected status, prove it contains only the selected layer's
  advisory copy and does not mix stale response, request, adapter-result,
  vendor, dispatch, authorization, lease, budget, metered-decision,
  source-host, citation URL, query, raw page, payment, booking, hidden app
  control, or execution details from later sources.

Acceptance:
- Tests cover at least ready and blocked recommendation ids across all seven
  status layers.
- Tests prove first-source-wins ordering when response status wins and when at
  least one earlier upstream layer wins over response status.
- Hidden/unrendered ids and missing ids return nil at source, app root, and
  ChatStore lookup.
- Status-safe copy must not contain endpoint URLs, API keys, OAuth tokens,
  SDK/client handles, raw query text, citation URL values, source-host values,
  raw page/provider payloads, crawler/MCP metadata, maps SDK metadata,
  StoreKit/payment/order/booking data, hidden app-control claims, or execution
  claims.
- A134 must not change AppBootstrap production defaults, ChatStore production
  behavior, SwiftUI, transport, StoreKit, MCP, crawler, Google/Gaode, memory,
  telemetry, transcript, payment, booking, remote model runtime, hidden app
  control, or real provider behavior.
- Run targeted AppBootstrap A134 tests, full `test_sim`, forbidden-fragment
  scan for changed Swift diffs, touched-file trailing-whitespace scan,
  A133/A134 doc consistency scan, and `git diff --check`.
```

Status after implementation: A134 proved A132 response status composes
deterministically with A118 metered entitlement, A106 vendor policy, A93 payload
dispatch, A109 dispatch authorization, A113 transport lease, and A127 transport
request status through `AppBootstrap(providerStatusSources:)` and ChatStore
lookup. Ready and blocked rendered ids are covered across all seven layers;
hidden/unrendered/missing ids stay nil at source, app root, and store; first
source wins for metered, vendor, dispatch, authorization, lease, request, and
response orders; selected copy does not mix stale response/request/result,
vendor, dispatch, authorization, lease, budget, metered, source-host, citation,
query, payment, booking, hidden app-control, or execution detail. No production
AppBootstrap defaults, ChatStore behavior, SwiftUI, transport, StoreKit, MCP,
crawler, Google/Gaode SDK, memory, telemetry, transcript, payment, booking,
remote model runtime, hidden app control, or provider execution behavior
changed.

## Round A135 - External Provider Transport Adapter Interface Preflight

```text
Task: Add a value-only external provider transport adapter interface preflight
contract for future Search API, Google/Gaode maps, crawler, and MCP provider
paths. This is interface and policy proof only. Do not add live Search API
transport, endpoint URLs, API keys, OAuth tokens, SDK clients, URLSession,
crawler runtime, MCP client runtime, Google/Gaode SDKs, provider calls,
AppBootstrap production defaults, ChatStore production behavior, SwiftUI/UI
layout, navigation, telemetry, transcript mutation, StoreKit/payment, memory
writes, raw page ingestion, transport execution, booking/payment/order flow,
remote model runtime, hidden third-party app control, or real provider
execution.

Allowed files:
- kAir/Core/Networking/ServerProviderTransportAdapter.swift
- kAirTests/Networking/ServerProviderTransportAdapterTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add a pure `ServerProviderTransportAdapter` boundary that describes future
  provider transport interfaces by provider family, capability, membership
  floor, cost class, entitlement requirement, source/attribution requirement,
  privacy allowance, and disabled-by-default gates.
- Add value-only request/decision types for adapter preflight. They may consume
  existing policy metadata such as `ServerProviderEnvelope`,
  `ServerProviderQuotaSnapshot`, `ServerProviderMeteredUsageDecision`,
  `ServerProviderSearchAPITransportLease`, `ProviderAccessProfile`, or
  `ProviderTrace`, but they must not carry prompt text, raw query/page content,
  endpoint URLs, credentials, SDK handles, URLRequest values, payment/order
  payloads, or executable closures.
- Ship static descriptor fixtures for `.searchAPI`, `.gaode`, `.googleMaps`,
  `.crawler`, and `.mcp`. Search API may be preflight-eligible only after the
  existing cost/entitlement/source/lease gates are represented; Google/Gaode
  must remain membership/entitlement/attribution gated; crawler and MCP must
  remain disabled by default until explicit experimental enablement plus source
  or descriptor gates are present.
- Add tests for accepted preflight and rejected preflight covering membership
  too low, missing entitlement, private/Health privacy block, missing source or
  attribution evidence, disabled crawler/MCP, unsupported capability, blocked
  cost class, and stale/mismatched budget or lease metadata.
- Add encoded/debug/status-copy tests proving no endpoint, API key, OAuth
  token, credential, raw query/page/source body, citation URL, source-host
  value, SDK/client handle, URLSession, crawler/MCP runtime metadata,
  Google/Gaode SDK metadata, StoreKit/payment/order/booking data, hidden
  app-control claim, or execution/completion claim is exposed.

Acceptance:
- New tests compile and prove the adapter preflight contract is pure and
  deterministic.
- Search API, Google Maps, Gaode, crawler, and MCP paths are represented as
  descriptors, but every runtime remains uncalled and disabled unless the
  value-only gates explicitly allow preflight.
- Cost/membership/entitlement gates are explicit enough to support future
  membership-package routing without silently changing iOS local defaults.
- No AppBootstrap production defaults, ChatStore behavior, SwiftUI, navigation,
  live transport, SDK import, endpoint, credential, telemetry, transcript,
  memory write, payment, booking, remote model runtime, hidden app control, or
  real provider execution is added.
- Run targeted `ServerProviderTransportAdapterTests`, full `test_sim`,
  forbidden-fragment scan for changed Swift diffs, touched-file
  trailing-whitespace scan, A134/A135 doc consistency scan, and
  `git diff --check`.
```

Status after implementation: A135 added the value-only
`ServerProviderTransportAdapter` preflight boundary for future Search API,
Google/Gaode maps, crawler, and MCP provider paths. Static descriptors now
record provider family, capability, minimum membership, cost class,
entitlement, source/attribution, privacy, disabled-by-default, confirmation,
metered decision, and lease requirements. Preflight requests consume existing
metadata values only; decisions are deterministic and safe for audit/status
copy. Tests cover accepted Search API, Google, Gaode, crawler, and MCP metadata
paths plus membership, entitlement, privacy, source, attribution, disabled
crawler/MCP, unsupported capability, blocked cost, stale budget, and lease
mismatch rejection. No AppBootstrap production defaults, ChatStore behavior,
SwiftUI, navigation, live transport, SDK import, endpoint, credential,
telemetry, transcript, memory write, payment, booking, remote model runtime,
hidden app control, or real provider execution was added.

## Round A136 - External Provider Transport Adapter Status Source

```text
Task: Package A135 external provider transport adapter preflight decisions into
rendered-id scoped provider-status copy for future Search API, Google/Gaode
maps, crawler, and MCP paths. This is status projection only. Do not add live
Search API transport, endpoint URLs, API keys, OAuth tokens, SDK clients,
URLSession, crawler runtime, MCP client runtime, Google/Gaode SDKs, provider
calls, AppBootstrap production defaults, ChatStore production behavior,
SwiftUI/UI layout, navigation, telemetry, transcript mutation, StoreKit/payment,
memory writes, raw page ingestion, transport execution, booking/payment/order
flow, remote model runtime, hidden third-party app control, or real provider
execution.

Allowed files:
- kAir/Core/Networking/ServerProviderTransportAdapterStatusSourceProducer.swift
- kAirTests/Networking/ServerProviderTransportAdapterStatusSourceProducerTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add a rendered-id scoped status source producer that accepts explicit
  `(recommendationID, ServerProviderTransportAdapterPreflightDecision)` inputs
  plus a rendered recommendation id set.
- Preserve duplicate recommendation id first-wins behavior.
- Return nil for hidden/unrendered ids and missing ids.
- Project accepted Search API, Google Maps, Gaode, crawler, and MCP preflight
  decisions into advisory provider-status copy with stable badges/card hints.
- Project rejected decisions into non-success advisory copy while preserving the
  rejection reason and avoiding any implication that a provider was contacted.
- Status copy must describe preflight/metadata only and must not expose
  endpoint URLs, API keys, OAuth tokens, credentials, URLSession/SDK/client
  handles, raw query text, citation URL values, source-host values, raw
  page/provider payloads, crawler/MCP runtime metadata, maps SDK metadata,
  StoreKit/payment/order/booking data, hidden app-control claims, completion
  claims, or execution claims.

Acceptance:
- Tests cover accepted and rejected preflight decisions for at least Search API,
  Google/Gaode maps, crawler, and MCP.
- Tests prove duplicate id first-wins, hidden/unrendered nil, missing nil, and
  encoded/debug/status copy safety.
- A136 must not change AppBootstrap production defaults, ChatStore behavior,
  SwiftUI, navigation, live transport, SDK imports, endpoints, credentials,
  telemetry, transcript, memory writes, payment, booking, remote model runtime,
  hidden app control, or real provider execution.
- Run targeted `ServerProviderTransportAdapterStatusSourceProducerTests`, full
  `test_sim`, forbidden-fragment scan for changed Swift diffs, touched-file
  trailing-whitespace scan, A135/A136 doc consistency scan, and
  `git diff --check`.
```

Status after implementation: A136 packaged A135 external provider transport
adapter preflight decisions into rendered-id scoped provider-status copy for
Search API, Google/Gaode maps, crawler, and MCP paths. The producer preserves
accepted/rejected advisory copy, duplicate-id first-wins behavior,
hidden/missing nil lookup, badge/card-hint stability, and safety against
endpoint, credential, SDK, URLSession, crawler/MCP runtime, maps SDK, payment,
booking, hidden app-control, completion, or execution leakage. No AppBootstrap
production defaults, ChatStore behavior, SwiftUI, navigation, telemetry,
transcript, memory write, payment, booking, remote model runtime, hidden app
control, live transport, or real provider execution was added.

## Round A137 - External Provider Transport Adapter Status App-Root Handoff Proof

```text
Task: Prove A136 external provider transport adapter status sources pass through
AppBootstrap(providerStatusSources:) and ChatStore lookup for rendered
recommendation ids only. This is app-root handoff proof only. Do not add live
Search API transport, endpoint URLs, API keys, OAuth tokens, SDK clients,
URLSession, crawler runtime, MCP client runtime, Google/Gaode SDKs, provider
calls, production AppBootstrap defaults, ChatStore production behavior,
SwiftUI/UI layout, navigation, telemetry, transcript mutation, StoreKit/payment,
memory writes, raw page ingestion, transport execution, booking/payment/order
flow, remote model runtime, hidden third-party app control, or real provider
execution.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Build accepted and rejected A135 preflight decisions for Search API,
  Google/Gaode maps, crawler, and MCP.
- Package them with `ServerProviderTransportAdapterStatusSourceProducer`.
- Inject the resulting sources through `AppBootstrap(providerStatusSources:)`
  and consume them through `ChatStore`.
- Include rendered ids, hidden/unrendered ids, and a missing id; prove nil at
  the raw source, app-root source, and ChatStore lookup levels where each level
  is applicable.
- Prove selected rendered ids preserve exact source-to-AppBootstrap-to-ChatStore
  provider-status copy, badges, and card hints.
- Prove source-order first-wins with an A136 status source preceding a duplicate
  fallback or stale source.
- Prove no stale provider, capability, cost, source, attribution, privacy,
  metered decision, transport lease, preflight rejection reason, or runtime
  detail leaks from hidden ids or later duplicate sources.

Acceptance:
- Tests cover accepted and rejected preflight status handoff for Search API,
  Google/Gaode maps, crawler, and MCP.
- Tests prove hidden/unrendered nil, missing nil, source-order first-wins, exact
  copy preservation, and no stale preflight/provider/cost/source/metered/lease
  detail mixing.
- Tests or static scans prove status/debug/copy does not expose endpoints, API
  keys, OAuth tokens, credentials, URLSession/SDK/client handles, raw query
  text, citation URLs, source-host values, raw page/provider payloads,
  crawler/MCP runtime metadata, maps SDK metadata, StoreKit/payment/order/
  booking data, hidden app-control claims, completion claims, or execution
  claims.
- A137 must not change production AppBootstrap defaults, ChatStore production
  behavior, SwiftUI, navigation, live transport, SDK imports, endpoints,
  credentials, telemetry, transcript, memory writes, payment, booking, remote
  model runtime, hidden app control, or real provider execution.
- Run targeted `AppBootstrapTests` for the new A137 coverage, full `test_sim`,
  forbidden-fragment scan for touched Swift diffs, touched-file
  trailing-whitespace scan, A136/A137 doc consistency scan, and
  `git diff --check`.
```

Status after implementation: A137 proved A136 external provider transport
adapter status sources pass through `AppBootstrap(providerStatusSources:)` and
ChatStore lookup for rendered recommendation ids only. New tests cover accepted
and rejected preflight status for Search API, Google/Gaode maps, crawler, and
MCP; hidden/unrendered and missing ids remain nil at source, app-root, and
ChatStore lookup; source-order first-wins blocks stale later-source preflight,
provider, capability, cost, metered decision, and lease details. No production
AppBootstrap defaults, ChatStore production behavior, SwiftUI, navigation,
telemetry, live transport, SDK import, endpoint, credential, transcript, memory
write, payment, booking, remote model runtime, hidden app control, or real
provider execution was added.

## Round A138 - External Provider Transport Adapter Cross-Stage Status Composition

```text
Task: Compose A136 external provider transport adapter preflight status with
existing provider-status sources through AppBootstrap and ChatStore. This is
cross-stage status selection proof only. Do not add live Search API transport,
endpoint URLs, API keys, OAuth tokens, SDK clients, URLSession, crawler runtime,
MCP client runtime, Google/Gaode SDKs, provider calls, production AppBootstrap
defaults, ChatStore production behavior, SwiftUI/UI layout, navigation,
telemetry, transcript mutation, StoreKit/payment, memory writes, raw page
ingestion, transport execution, booking/payment/order flow, remote model
runtime, hidden third-party app control, or real provider execution.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Build a rendered Search API recommendation with existing status sources for
  metered entitlement, vendor policy, payload dispatch, dispatch authorization,
  transport lease, transport request, transport response, and A136 transport
  adapter preflight.
- Build at least one non-Search external provider recommendation
  (Google/Gaode maps, crawler, or MCP) with A136 transport adapter preflight and
  a generic stale fallback status source.
- Inject multiple source-order permutations through
  `AppBootstrap(providerStatusSources:)` and consume them through `ChatStore`.
- Prove each permutation selects the first matching source exactly and preserves
  exact root-to-store copy.
- Prove hidden/unrendered ids and missing ids stay nil.
- Prove selected status text does not mix stale provider, capability, cost,
  source, attribution, privacy, metered decision, transport lease, request,
  response, preflight rejection reason, fallback, or runtime details from later
  sources or hidden ids.

Acceptance:
- Tests cover Search API cross-stage composition with A136 preflight plus the
  existing metered/vendor/dispatch/authorization/lease/request/response status
  sources.
- Tests cover at least one non-Search A136 external provider path composed with
  a stale fallback source.
- Tests prove source-order first-wins, exact AppBootstrap-to-ChatStore copy,
  hidden/missing nil lookup, and no stale detail mixing.
- Tests or static scans prove status/debug/copy does not expose endpoints, API
  keys, OAuth tokens, credentials, URLSession/SDK/client handles, raw query
  text, citation URLs, source-host values, raw page/provider payloads,
  crawler/MCP runtime metadata, maps SDK metadata, StoreKit/payment/order/
  booking data, hidden app-control claims, completion claims, or execution
  claims.
- A138 must not change production AppBootstrap defaults, ChatStore production
  behavior, SwiftUI, navigation, live transport, SDK imports, endpoints,
  credentials, telemetry, transcript, memory writes, payment, booking, remote
  model runtime, hidden app control, or real provider execution.
- Run targeted `AppBootstrapTests` for the new A138 coverage, full `test_sim`,
  forbidden-fragment scan for touched Swift diffs, touched-file
  trailing-whitespace scan, A137/A138 doc consistency scan, and
  `git diff --check`.
```

Status after implementation: A138 composed A136 external provider transport
adapter preflight status with existing provider-status sources through
AppBootstrap and ChatStore. Tests cover Search API metered entitlement, vendor
policy, payload dispatch, dispatch authorization, transport lease, transport
request, transport response, A136 preflight, and generic fallback source-order
selection; they also cover a non-Search Gaode preflight source composed with a
fallback source. The selected source remains first-wins, exact root-to-store copy
is preserved, hidden/missing ids stay nil, and stale provider/cost/source/
metered/lease/request/response/preflight/fallback details do not mix. No
production AppBootstrap defaults, ChatStore production behavior, SwiftUI,
navigation, telemetry, live transport, SDK import, endpoint, credential,
transcript, memory write, payment, booking, remote model runtime, hidden app
control, or real provider execution was added.

## Round A139 - Research, Market, Provider, and MCP Cut-Plan Refresh

```text
Task: Refresh kAir's current research/market/provider cut plan after the A138
provider-status stack. This is docs/research only. Do not add Swift runtime
code, live Search API transport, endpoint URLs, API keys, OAuth tokens, SDK
clients, URLSession, crawler runtime, MCP client runtime, Google/Gaode SDKs,
provider calls, production AppBootstrap defaults, ChatStore production behavior,
SwiftUI/UI layout, navigation, telemetry, transcript mutation, StoreKit/payment,
memory writes, raw page ingestion, transport execution, booking/payment/order
flow, remote model runtime, hidden third-party app control, or real provider
execution.

Allowed files:
- Docs/research/2026-agent-market-ui-provider-research.md
- Docs/research/2026-agent-architecture-deep-dive-v1.md
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Research scope:
- Recheck current public agent architecture papers and benchmark/evaluation
  work from authoritative sources such as arXiv, Google Scholar, IEEE/ACM
  indexes when available, and official project repositories.
- Recheck MCP specification/security/governance work, especially tool poisoning,
  prompt injection, OAuth/authorization, descriptor trust, client/server
  lifecycle, registry governance, and runtime policy enforcement.
- Recheck Apple public iOS action/model surfaces relevant to kAir, including
  App Intents, Foundation Models, Core ML model installation, and public API
  limits around background execution or third-party app control.
- Recheck Google Maps/Places/Routes, Gaode, Search API vendors, crawler/robots,
  attribution, caching, privacy, quota, pricing, and server-side compliance
  constraints.
- Recheck visible market positioning from Marvis-style mobile agents, Tencent
  Yuanbao-style consumer agents, and Meituan/LongCat-style life-service agent
  references, using public docs/articles only.

Implementation shape:
- Update the research docs with short, source-linked evidence bullets and
  clear "adopt now / reserve / reject" decisions.
- Update the architecture docs with a concrete next gate number and exact
  paste-ready prompt.
- Decide explicitly whether A140 should start live provider transport or remain
  value-only. If live transport is still premature, name the smallest next
  value-only gate and explain why.
- Preserve the current local-first iOS default: Apple/local and cache paths stay
  default; Google/Gaode/Search/crawler/MCP remain membership/cost/privacy/
  entitlement/policy gated.

Acceptance:
- Docs cite concrete current sources and distinguish source facts from reviewer
  judgment.
- The decision covers UI architecture, provider cost routing, MCP reserved
  interfaces, crawler/search source policy, membership package behavior, and
  iOS local-first constraints.
- The next gate is narrow, implementation-ready, and includes allowed files,
  non-goals, tests/scans, and verification steps.
- No Swift files change in A139.
- Run touched-file trailing-whitespace scan, stale A138/A139 doc scan,
  source-link sanity scan, and `git diff --check`.
```

Status after implementation: A139 refreshed the current research, market,
provider-policy, MCP, crawler, and iOS platform evidence after the A138
provider-status stack. The selected next gate is not live provider transport.
Search API, Google/Gaode, crawler, MCP, and remote model paths still need a
shared value-only audit trace/evaluation contract that can explain future
attempts, rejections, source policy, cost class, privacy class, attribution,
membership, status-source selection, and expected evaluation dimensions before
any endpoint, SDK, URLSession, crawler, MCP client, payment/order, hidden app
control, or real execution appears.

## Round A140 - External Provider Transport Audit Trace and Evaluation Contract Proof

```text
Task: Add a value-only external provider transport audit trace and evaluation
contract for future provider attempts. This is not live runtime. Do not add
endpoint URLs, API keys, OAuth tokens, SDK/client handles, URLSession,
crawler runtime, MCP client runtime, Google/Gaode SDKs, provider calls,
production AppBootstrap defaults, ChatStore production behavior, SwiftUI/UI
layout, navigation, telemetry, transcript mutation, StoreKit/payment, memory
writes, raw query/page/provider payload ingestion, booking/payment/order flow,
remote model runtime, hidden third-party app control, or real provider
execution.

Allowed files:
- kAir/Core/Networking/ServerProviderTransportAuditTrace.swift
- kAirTests/Networking/ServerProviderTransportAuditTraceTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add a pure Swift value contract named around
  `ServerProviderTransportAuditTrace` and
  `ServerProviderTransportAuditEvent`.
- Model future provider-attempt metadata for Search API, Google/Gaode maps,
  crawler, MCP, and remote model families without adding runtime transport.
- Accept only audit-safe fields: rendered recommendation id, provider family,
  capability, membership tier, cost class, privacy class, source policy,
  citation/attribution policy summary, preflight/status source id, selected
  status source rank/order, user confirmation state, expected evaluation
  dimensions, and deterministic rejection reason.
- Include a stable status/debug/encoded copy that preserves accepted/rejected
  copy but strips endpoints, credentials, OAuth, SDK/client handles, raw
  query/page/provider payloads, source-host URLs, citation URLs, payment/order
  data, MCP descriptors, crawler fetch details, maps SDK details, and execution
  claims.
- Keep the object independent from AppBootstrap and ChatStore in A140. This
  slice proves the contract and tests only; app-root/status-source projection
  can be a later gate.

Acceptance:
- Tests cover accepted audit traces for Search API, Google/Gaode maps, crawler,
  MCP, and remote model provider families.
- Tests cover rejected traces for missing rendered id, missing status source,
  missing privacy policy, missing source/citation/attribution policy where
  required, unsupported capability, blocked cost class, blocked privacy class,
  disabled crawler/MCP, absent user confirmation where required, and unsafe raw
  runtime detail.
- Tests prove the status/debug/encoded copy is deterministic and contains no
  endpoint URL, API key, OAuth token, SDK/client handle, URLSession mention,
  raw query, raw page body, provider payload, citation URL, source-host URL,
  payment/order/booking data, crawler fetch detail, MCP descriptor/tool call,
  maps SDK detail, hidden app-control action, or execution/completion claim.
- Tests prove evaluation dimensions are explicit enough for latency, cost,
  source quality, citation/attribution, privacy, fallback, user-confirmation,
  and safety review, but contain no real measurements or network results.
- Update docs to mark A140 done and name the next narrow gate. Do not stage,
  commit, merge, or widen into live provider transport.

Verification:
- Run the new `ServerProviderTransportAuditTraceTests`.
- Run full `test_sim` only if Swift compile/test scope requires it under the
  current project gate; otherwise run the repo's narrow networking test target
  plus `git diff --check`.
- Run a forbidden-fragment scan for touched Swift diffs covering `URLSession`,
  `https://`, `apiKey`, `OAuth`, `SDK`, `MCPClient`, `StoreKit`, `booking`,
  `payment`, `rawQuery`, `rawPage`, `providerPayload`, and `execution`.
- Run touched-file trailing-whitespace scan and A139/A140 doc consistency scan.
```

Status after implementation: A140 added the pure
`ServerProviderTransportAuditTrace` / `ServerProviderTransportAuditEvent`
contract plus `ServerProviderTransportAuditTraceTests`. The value contract
covers Search API, Google/Gaode maps, crawler, MCP, and remote model families
without runtime transport. Tests cover accepted provider-family audit events,
missing rendered id/status/privacy/source/citation/attribution policy,
unsupported capability, blocked cost/privacy, disabled crawler/MCP, missing
confirmation, missing evaluation dimensions, unsafe runtime material,
deterministic safe-copy encoding, and explicit latency/cost/source/citation/
privacy/fallback/confirmation/safety review labels. No AppBootstrap, ChatStore,
SwiftUI, live transport, endpoint, credential, SDK/client, crawler/MCP runtime,
payment/booking/order, hidden app-control, or provider execution was added.

## Round A141 - Transport Audit Event Status Source Projection

```text
Task: Project A140 external provider transport audit events into rendered-id
scoped provider-status copy. This is still value-only. Do not add live Search
API transport, endpoint URLs, API keys, OAuth tokens, SDK/client handles,
URLSession, crawler runtime, MCP client runtime, Google/Gaode SDKs, provider
calls, production AppBootstrap defaults, ChatStore production behavior,
SwiftUI/UI layout, navigation, telemetry, transcript mutation, StoreKit/payment,
memory writes, raw query/page/provider payload ingestion, booking/payment/order
flow, remote model runtime, hidden third-party app control, or real provider
execution.

Allowed files:
- kAir/Core/Networking/ServerProviderTransportAuditTraceStatusSourceProducer.swift
- kAirTests/Networking/ServerProviderTransportAuditTraceStatusSourceProducerTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add a rendered-id scoped status-source producer for
  `ServerProviderTransportAuditEvent`, following the existing
  `ServerProviderTransportAdapterStatusSourceProducer` pattern.
- Store audit events by recommendation id with duplicate first-wins behavior.
- Return nil for hidden, unrendered, or missing ids.
- Accepted audit events should produce remote/provider/cost/evaluation badges,
  a status line that includes provider family, capability, membership, cost,
  privacy, status-source id, selected rank, confirmation state, and evaluation
  dimensions, and a warning card hint for metered premium or reserved provider
  families.
- Rejected audit events should produce disabled card hints and rejection badges
  mapped to privacy, cost, terms, or unavailable categories.
- Status copy must not leak endpoint URLs, API keys, OAuth tokens, SDK/client
  handles, URLSession, raw query/page/provider payloads, source-host URLs,
  citation URLs, payment/order/booking data, crawler fetch detail, MCP
  descriptor/tool call, maps SDK detail, hidden app-control action, or
  execution/completion claims.
- Keep AppBootstrap and ChatStore untouched in A141. App-root composition can
  be a later gate.

Acceptance:
- Tests cover accepted status projection for Search API, Google/Gaode maps,
  crawler, MCP, and remote model audit events.
- Tests cover rejected status projection for missing policy, blocked privacy,
  blocked cost, disabled reserved provider, missing confirmation, missing
  evaluation dimension, and unsafe runtime material.
- Tests prove duplicate recommendation ids keep the first event, hidden and
  missing ids return nil, and exact safe copy reaches presentation without
  stale provider/cost/privacy/status-source/evaluation detail mixing.
- Tests prove status lines, badges, card hints, descriptions, and encoded safe
  copies contain none of the forbidden runtime fragments above.
- Update docs to mark A141 done and name the next narrow gate. Do not stage,
  commit, merge, or widen into AppBootstrap, ChatStore, SwiftUI, or live
  provider transport.

Verification:
- Run the new
  `ServerProviderTransportAuditTraceStatusSourceProducerTests`.
- Run full `test_sim` if compile/build scope requires it; otherwise run the
  narrow networking tests plus `git diff --check`.
- Run forbidden-fragment scan for touched Swift diffs, touched-file
  trailing-whitespace scan, and A140/A141 doc consistency scan.
```

Status after implementation: A141 added
`ServerProviderTransportAuditTraceStatusSourceProducer` and
`ServerProviderTransportAuditTraceStatusSourceProducerTests`. A140 audit events
now project into rendered-id scoped provider-status copy with accepted/rejected
status lines, provider/cost/evaluation badges, disabled rejection hints,
duplicate first-wins behavior, hidden/missing nil lookup, and no stale
provider/cost/privacy/status-source/evaluation detail mixing. AppBootstrap,
ChatStore, SwiftUI, live transport, endpoints, credentials, SDK/client handles,
crawler/MCP runtime, maps runtime, raw payloads, payment/booking/order, hidden
app-control, and real provider execution remain untouched.

## Round A142 - Transport Audit Status App-Root Handoff Proof

```text
Task: Prove the A141 transport audit event status source passes through
`AppBootstrap(providerStatusSources:)` and ChatStore lookup for rendered ids
only. This is a handoff test gate. Do not add live Search API transport,
endpoint URLs, API keys, OAuth tokens, SDK/client handles, URLSession,
crawler runtime, MCP client runtime, Google/Gaode SDKs, provider calls,
production AppBootstrap defaults, ChatStore production behavior, SwiftUI/UI
layout, navigation, telemetry, transcript mutation, StoreKit/payment, memory
writes, raw query/page/provider payload ingestion, booking/payment/order flow,
remote model runtime, hidden third-party app control, or real provider
execution.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add focused AppBootstrap tests that create A140 audit events, package them
  through the A141 status-source producer, inject that source through
  `AppBootstrap(providerStatusSources:)`, and read it back through ChatStore's
  provider-status lookup for rendered recommendation ids.
- Cover accepted Search API audit status and one non-Search family such as
  remote model or MCP.
- Cover rejected audit status, hidden/unrendered ids returning nil, missing ids
  returning nil, and duplicate source-order first-wins when a fallback source
  is also present.
- Assert exact source-to-root-to-store copy for status line, badges, card hint,
  recommendation id, provider/cost/privacy/status-source/evaluation fragments,
  and rejection copy.
- Keep the production AppBootstrap defaults and ChatStore production behavior
  unchanged. This gate only proves optional injected sources compose correctly.

Acceptance:
- Targeted AppBootstrap tests pass for the new A142 coverage.
- No production AppBootstrap defaults, ChatStore behavior, SwiftUI, navigation,
  live transport, SDK imports, endpoints, credentials, telemetry, transcript,
  memory writes, payment/booking/order, remote model runtime, hidden app
  control, or real provider execution changes are introduced.
- Forbidden-fragment scan for touched Swift diffs remains clean.
- Docs mark A142 done and name the next narrow gate. Do not stage, commit,
  merge, or widen into live provider runtime.

Verification:
- Run targeted `AppBootstrapTests` for the new A142 methods.
- Run full `test_sim`.
- Run forbidden-fragment scan for touched Swift diffs, touched-file
  trailing-whitespace scan, A141/A142 doc consistency scan, and
  `git diff --check`.
```

Status after implementation: A142 added focused AppBootstrap tests proving the
A141 audit-event status source passes through
`AppBootstrap(providerStatusSources:)` and ChatStore lookup for rendered ids
only. The tests cover accepted Search API audit status, accepted remote-model
audit status, rejected privacy-blocked audit status, hidden/missing nil lookup,
exact source-to-root-to-store copy, and source-order first-wins against fallback
status. No production AppBootstrap defaults, ChatStore behavior, SwiftUI,
navigation, live transport, endpoints, credentials, SDK/client handles,
crawler/MCP runtime, maps runtime, raw payloads, payment/booking/order, hidden
app-control, or real provider execution was added.

## Round A143 - Transport Audit Status Cross-Stage Composition

```text
Task: Compose A141 transport audit-event status with the existing provider
status stack through AppBootstrap and ChatStore. This is a first-wins
composition test gate. Do not add live Search API transport, endpoint URLs,
API keys, OAuth tokens, SDK/client handles, URLSession, crawler runtime, MCP
client runtime, Google/Gaode SDKs, provider calls, production AppBootstrap
defaults, ChatStore production behavior, SwiftUI/UI layout, navigation,
telemetry, transcript mutation, StoreKit/payment, memory writes, raw query/page/
provider payload ingestion, booking/payment/order flow, remote model runtime,
hidden third-party app control, or real provider execution.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add focused AppBootstrap tests that include A141 audit-event status alongside
  the existing metered entitlement, vendor policy, payload dispatch, dispatch
  authorization, transport lease, transport request, transport response,
  transport adapter preflight, and generic fallback provider-status sources.
- Prove source-order first-wins for both ready and blocked recommendations when
  audit status is first, when an earlier Search API/status-stack source is
  first, and when fallback is first.
- Cover at least one non-Search audit family such as remote model or MCP
  composed with fallback ordering.
- Preserve hidden/unrendered and missing ids as nil across every composed
  source.
- Assert selected status copy does not mix stale provider family, cost,
  privacy, status-source id, source/citation/attribution policy, metered,
  vendor, dispatch, authorization, lease, request, response, preflight,
  audit-event, fallback, or evaluation detail.

Acceptance:
- Targeted AppBootstrap tests pass for the new A143 coverage.
- Full `test_sim` passes.
- No production AppBootstrap defaults, ChatStore behavior, SwiftUI, navigation,
  live transport, SDK imports, endpoints, credentials, telemetry, transcript,
  memory writes, payment/booking/order, remote model runtime, hidden app
  control, or real provider execution changes are introduced.
- Forbidden-fragment scan for touched Swift diffs remains clean.
- Docs mark A143 done and name the next narrow gate. Do not stage, commit,
  merge, or widen into live provider runtime.

Verification:
- Run targeted `AppBootstrapTests` for the new A143 methods.
- Run full `test_sim`.
- Run forbidden-fragment scan for touched Swift diffs, touched-file
  trailing-whitespace scan, A142/A143 doc consistency scan, and
  `git diff --check`.
```

Status after implementation: A143 added a focused AppBootstrap cross-stage
composition proof for A141 transport audit-event status. The test composes audit
status with metered entitlement, vendor policy, payload dispatch, dispatch
authorization, transport lease, transport request, transport response,
transport adapter preflight, and generic fallback sources through AppBootstrap
and ChatStore. It proves source-order first-wins when audit status is first,
when existing status-stack sources are first, and when fallback is first; it
also proves non-Search remote-model audit status composes with fallback
ordering. Hidden/missing ids remain nil and selected copy does not mix stale
provider, cost, privacy, status-source, policy, metered, vendor, dispatch,
authorization, lease, request, response, preflight, audit, fallback, or
evaluation detail. No production defaults, UI, live transport, endpoint,
credential, SDK/client, crawler/MCP runtime, maps runtime, raw payload,
payment/booking/order, hidden app-control, or real provider execution was
added.

## Round A144 - Search API Live Transport Boundary Comment-Programming

```text
Task: Add the Search API live-transport boundary comment-programming and
cut-plan needed before any future real provider call. This is a design/code
comment gate only. Do not add live Search API transport, endpoint URLs, API
keys, OAuth tokens, SDK/client handles, URLSession calls, crawler runtime, MCP
client runtime, Google/Gaode SDKs, provider calls, production AppBootstrap
defaults, ChatStore production behavior, SwiftUI/UI layout, navigation,
telemetry, transcript mutation, StoreKit/payment, memory writes, raw query/page/
provider payload ingestion, booking/payment/order flow, remote model runtime,
hidden third-party app control, or real provider execution.

Allowed files:
- kAir/Core/Networking/ServerProviderSearchAPILiveTransportBoundary.swift
- kAirTests/Networking/ServerProviderSearchAPILiveTransportBoundaryTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add a comment-first Swift boundary file that defines the future Search API
  live-transport ownership model without performing transport.
- The file may contain value-only placeholder types/protocol names if needed
  for compilation, but every runtime method must be unavailable or return a
  deterministic value-only planning artifact. It must not import networking
  clients or create URL/request/session objects.
- Document the required upstream chain before a live call can exist:
  metered entitlement, vendor policy, payload dispatch, dispatch authorization,
  transport lease, transport request, transport response receipt/audit binding,
  external provider preflight, transport audit trace, rendered-id status, and
  AppBootstrap/ChatStore status composition.
- Document the required runtime cut-plan: server ownership, credential
  injection, request signing boundary, retry/rate-limit policy, kill switch,
  quota/membership enforcement, privacy source policy, citation/attribution,
  logging redaction, test fixtures, failure taxonomy, and rollback checks.
- Add tests that verify the boundary is explicitly non-executable in A144 and
  that debug/status/comment-derived copy contains no endpoint, credential,
  runtime client, raw payload, booking/payment/order, hidden app-control, or
  provider execution claim.

Acceptance:
- Tests prove the A144 boundary is compile-safe, value-only, and unavailable
  for runtime execution.
- Tests prove the boundary names the required upstream chain and runtime
  readiness checklist without leaking endpoint URLs, credentials, SDK handles,
  URLSession, raw query/page/provider payloads, payment/order/booking data,
  crawler/MCP details, maps SDK details, hidden app-control actions, or
  execution/completion claims.
- Docs mark A144 done and name the next narrow gate. Do not stage, commit,
  merge, or widen into live provider runtime.

Verification:
- Run the new `ServerProviderSearchAPILiveTransportBoundaryTests`.
- Run full `test_sim`.
- Run forbidden-fragment scan for touched Swift diffs, touched-file
  trailing-whitespace scan, A143/A144 doc consistency scan, and
  `git diff --check`.
```

Status after implementation: A144 added
`ServerProviderSearchAPILiveTransportBoundary.swift` and
`ServerProviderSearchAPILiveTransportBoundaryTests.swift`. The boundary is a
compile-safe value-only planning document with the full upstream chain,
runtime-readiness checklist, nil runtime entry point, non-callable state,
deterministic safe copy, and forbidden-material tests. It does not wire
URLSession, endpoint URLs, keys, OAuth, SDK/client handles, crawler/MCP runtime,
maps runtime, provider calls, production AppBootstrap defaults, ChatStore
behavior, SwiftUI, telemetry, transcript writes, StoreKit/payment, memory
writes, raw payload ingestion, booking/order flows, hidden app-control, remote
model runtime, or real provider execution.

## Round A145 - Search API Live Transport Readiness Gate

```text
Task: Turn the A144 Search API live-transport boundary comments into a
value-only readiness gate. This is still a planning/validation gate only. Do
not add live Search API transport, endpoint URLs, API keys, OAuth tokens,
SDK/client handles, URLSession calls, crawler runtime, MCP client runtime,
Google/Gaode SDKs, provider calls, production AppBootstrap defaults, ChatStore
production behavior, SwiftUI/UI layout, navigation, telemetry, transcript
mutation, StoreKit/payment, memory writes, raw query/page/provider payload
ingestion, booking/payment/order flow, remote model runtime, hidden third-party
app control, or real provider execution.

Allowed files:
- kAir/Core/Networking/ServerProviderSearchAPILiveTransportReadinessGate.swift
- kAirTests/Networking/ServerProviderSearchAPILiveTransportReadinessGateTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add a value-only readiness gate that consumes or references the A144 boundary
  document and verifies the required upstream chain plus runtime checklist are
  represented by explicit safe evidence ids.
- The gate should return a deterministic readiness decision with accepted and
  rejected states, stable rejection reasons, and safe copy suitable for tests
  and docs. It must remain non-callable for runtime transport.
- Require evidence for metered entitlement, vendor policy, payload dispatch,
  dispatch authorization, transport lease, transport request, transport response
  receipt/audit binding, external provider preflight, transport audit trace,
  rendered-id status, AppBootstrap/ChatStore status composition, server
  ownership, credential injection, request signing boundary,
  retry/rate-limit policy, kill switch, quota/membership enforcement, privacy
  source policy, citation/attribution, logging redaction, test fixtures,
  failure taxonomy, and rollback checks.
- Reject missing evidence, duplicate evidence ids, unknown checkpoint names,
  callable runtime entrypoints, unsafe material markers, stale boundary ids, or
  any attempt to mark a live provider path as enabled.

Acceptance:
- Tests prove accepted readiness only when every A144 checkpoint and checklist
  item has safe evidence and the boundary remains non-callable.
- Tests prove rejection reasons are stable for missing evidence, duplicate
  evidence, unknown evidence, callable runtime state, stale boundary id, and
  unsafe material.
- Tests prove safe copy contains no endpoint URL, credential value, SDK handle,
  URLSession, raw query/page/provider payload, payment/order/booking data,
  crawler/MCP detail, maps SDK detail, hidden app-control action, or
  execution/completion claim.
- Docs mark A145 done and name the next narrow gate. Do not stage, commit,
  merge, or widen into live provider runtime.

Verification:
- Run the new `ServerProviderSearchAPILiveTransportReadinessGateTests`.
- Run full `test_sim`.
- Run forbidden-fragment scan for touched Swift diffs, touched-file
  trailing-whitespace scan, A144/A145 doc consistency scan, and
  `git diff --check`.
```

Status after implementation: A145 added
`ServerProviderSearchAPILiveTransportReadinessGate.swift` and
`ServerProviderSearchAPILiveTransportReadinessGateTests.swift`. The gate
consumes the A144 boundary document, requires explicit safe evidence ids for
every upstream checkpoint and readiness item, returns deterministic accepted and
rejected readiness decisions, keeps runtime entrypoints nil, keeps live provider
path enablement rejected, and emits safe copy with no live transport material.
It does not wire URLSession, endpoint URLs, keys, OAuth, SDK/client handles,
crawler/MCP runtime, maps runtime, provider calls, production AppBootstrap
defaults, ChatStore behavior, SwiftUI, telemetry, transcript writes,
StoreKit/payment, memory writes, raw payload ingestion, booking/order flows,
hidden app-control, remote model runtime, or real provider execution.

## Round A146 - Search API Live Transport Readiness Status Source

```text
Task: Package the A145 Search API live-transport readiness decision into a
rendered-id scoped provider-status source. This is still an advisory/status
gate only. Do not add live Search API transport, endpoint URLs, API keys, OAuth
tokens, SDK/client handles, URLSession calls, crawler runtime, MCP client
runtime, Google/Gaode SDKs, provider calls, production AppBootstrap defaults,
ChatStore production behavior, SwiftUI/UI layout, navigation, telemetry,
transcript mutation, StoreKit/payment, memory writes, raw query/page/provider
payload ingestion, booking/payment/order flow, remote model runtime, hidden
third-party app control, or real provider execution.

Allowed files:
- kAir/Core/Networking/ServerProviderSearchAPILiveTransportReadinessStatusSourceProducer.swift
- kAirTests/Networking/ServerProviderSearchAPILiveTransportReadinessStatusSourceProducerTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add a value-only status source producer that packages A145 readiness decisions
  by explicit rendered recommendation ids.
- Accepted readiness should produce advisory copy that says the planning
  evidence is ready while the live provider path remains disabled.
- Rejected readiness should produce disabled/advisory copy with stable reason
  badges and no raw evidence or unsafe material.
- Duplicate rendered ids must keep the first input. Hidden or missing rendered
  ids must return nil.
- Safe copy must not leak endpoint URLs, credential values, SDK/client handles,
  URLSession, raw query/page/provider payloads, payment/order/booking data,
  crawler/MCP details, maps SDK details, hidden app-control actions, or
  execution/completion claims.

Acceptance:
- Tests prove accepted and rejected readiness decisions package into
  rendered-id scoped provider status.
- Tests prove duplicate ids keep first, hidden/missing ids return nil, and
  rejected decisions remain advisory only.
- Tests prove safe copy does not carry stale boundary, readiness, unsafe
  marker, live-path, endpoint, credential, SDK/client, crawler/MCP, maps,
  payload, payment/booking/order, hidden app-control, or execution/completion
  details.
- Docs mark A146 done and name the next narrow gate. Do not stage, commit,
  merge, or widen into live provider runtime.

Verification:
- Run the new `ServerProviderSearchAPILiveTransportReadinessStatusSourceProducerTests`.
- Run full `test_sim`.
- Run forbidden-fragment scan for touched Swift diffs, touched-file
  trailing-whitespace scan, A145/A146 doc consistency scan, and
  `git diff --check`.
```

Status after implementation: A146 added
`ServerProviderSearchAPILiveTransportReadinessStatusSourceProducer.swift` and
`ServerProviderSearchAPILiveTransportReadinessStatusSourceProducerTests.swift`.
The source packages A145 readiness decisions into rendered-id scoped provider
status, uses advisory copy for accepted planning evidence, maps rejected
decisions to stable disabled/warning badges, preserves duplicate first-wins,
keeps hidden/missing ids nil, and does not leak live transport material. It
does not wire URLSession, endpoint URLs, keys, OAuth, SDK/client handles,
crawler/MCP runtime, maps runtime, provider calls, production AppBootstrap
defaults, ChatStore behavior, SwiftUI, telemetry, transcript writes,
StoreKit/payment, memory writes, raw payload ingestion, booking/order flows,
hidden app-control, remote model runtime, or real provider execution.

## Round A147 - Search API Live Transport Readiness App-Root Handoff

```text
Task: Prove the A146 Search API live-transport readiness status source passes
through `AppBootstrap(providerStatusSources:)` and ChatStore lookup for rendered
ids only. This is still an advisory/status handoff gate only. Do not add live
Search API transport, endpoint URLs, API keys, OAuth tokens, SDK/client handles,
URLSession calls, crawler runtime, MCP client runtime, Google/Gaode SDKs,
provider calls, production AppBootstrap defaults, ChatStore production
behavior, SwiftUI/UI layout, navigation, telemetry, transcript mutation,
StoreKit/payment, memory writes, raw query/page/provider payload ingestion,
booking/payment/order flow, remote model runtime, hidden third-party app
control, or real provider execution.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add focused AppBootstrap tests that build the A146 status source with
  accepted and rejected readiness decisions and inject it through
  `AppBootstrap(providerStatusSources:)`.
- Verify ChatStore reads the exact same provider-status presentation for
  rendered recommendation ids.
- Verify hidden and missing recommendation ids return nil at root and store
  lookup.
- Verify source-order first-wins against fallback status without stale fallback
  detail leaking into the selected readiness status.
- Do not change production AppBootstrap defaults, ChatStore behavior,
  SwiftUI/UI, navigation, provider runtime, networking, or status-source order
  outside the test.

Acceptance:
- Tests prove accepted and rejected A146 readiness status pass through root and
  store lookup exactly.
- Tests prove hidden/missing ids stay nil and source-order first-wins prevents
  stale fallback details.
- Tests prove no endpoint URL, credential value, SDK handle, URLSession, raw
  query/page/provider payload, payment/order/booking data, crawler/MCP detail,
  maps SDK detail, hidden app-control action, or execution/completion claim is
  introduced.
- Docs mark A147 done and name the next narrow gate. Do not stage, commit,
  merge, or widen into live provider runtime.

Verification:
- Run the new focused AppBootstrap test(s).
- Run full `test_sim`.
- Run forbidden-fragment scan for touched Swift diffs, touched-file
  trailing-whitespace scan, A146/A147 doc consistency scan, and
  `git diff --check`.
```

Status after implementation: A147 added focused AppBootstrap tests proving the
A146 readiness status source passes through
`AppBootstrap(providerStatusSources:)` and ChatStore lookup for rendered ids
only. Accepted and rejected readiness status copy is identical from source to
root to store, hidden/missing ids stay nil, and fallback source-order first-wins
does not leak stale fallback detail into selected readiness status. It does not
wire URLSession, endpoint URLs, keys, OAuth, SDK/client handles, crawler/MCP
runtime, maps runtime, provider calls, production AppBootstrap defaults,
ChatStore behavior, SwiftUI, telemetry, transcript writes, StoreKit/payment,
memory writes, raw payload ingestion, booking/order flows, hidden app-control,
remote model runtime, or real provider execution.

## Round A148 - Search API Live Transport Readiness Cross-Stage Composition

```text
Task: Compose the A146 Search API live-transport readiness status source with
the earlier Search API status stack through `AppBootstrap(providerStatusSources:)`
and ChatStore. This is still an advisory/status composition gate only. Do not
add live Search API transport, endpoint URLs, API keys, OAuth tokens,
SDK/client handles, URLSession calls, crawler runtime, MCP client runtime,
Google/Gaode SDKs, provider calls, production AppBootstrap defaults, ChatStore
production behavior, SwiftUI/UI layout, navigation, telemetry, transcript
mutation, StoreKit/payment, memory writes, raw query/page/provider payload
ingestion, booking/payment/order flow, remote model runtime, hidden third-party
app control, or real provider execution.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Build the A146 readiness source plus representative earlier Search API status
  sources already available in tests: metered entitlement, vendor policy,
  payload dispatch, dispatch authorization, transport lease, transport request,
  transport response, transport adapter preflight, transport audit trace, and
  fallback provider status.
- Compose those sources through `AppBootstrap(providerStatusSources:)` in
  multiple source orders: readiness first, earlier stack first, and fallback
  first.
- Verify ChatStore reads the selected first-wins presentation exactly for
  rendered ids.
- Verify hidden and missing recommendation ids return nil at root and store
  lookup.
- Verify selected copy never mixes stale readiness, fallback, metered, vendor,
  dispatch, authorization, lease, request, response, preflight, audit, unsafe
  marker, live-path, endpoint, credential, SDK/client, crawler/MCP, maps,
  payload, payment/booking/order, hidden app-control, or execution/completion
  details.

Acceptance:
- Tests prove source-order first-wins for readiness-first, earlier-stack-first,
  and fallback-first composition.
- Tests prove hidden/missing ids stay nil and selected copy is exact from root
  to store.
- Tests prove no endpoint URL, credential value, SDK handle, URLSession, raw
  query/page/provider payload, payment/order/booking data, crawler/MCP detail,
  maps SDK detail, hidden app-control action, or execution/completion claim is
  introduced.
- Docs mark A148 done and name the next narrow gate. Do not stage, commit,
  merge, or widen into live provider runtime.

Verification:
- Run the new focused AppBootstrap test(s).
- Run full `test_sim`.
- Run forbidden-fragment scan for touched Swift diffs, touched-file
  trailing-whitespace scan, A147/A148 doc consistency scan, and
  `git diff --check`.
```

Status after implementation: A148 added a focused AppBootstrap composition test
that combines the A146 readiness source with the representative earlier Search
API status stack and fallback status. It proves readiness-first,
earlier-stack-first, and fallback-first first-wins ordering, exact selected copy
from root to ChatStore, hidden/missing nil lookup, and no stale status,
endpoint, credential, SDK/client, crawler/MCP, maps, raw payload,
payment/booking/order, hidden app-control, or execution/completion detail in
the selected copy. No production runtime, AppBootstrap default, ChatStore
behavior, SwiftUI, networking, credential, provider call, telemetry, payment,
booking, order, memory, or transcript behavior was changed.

## Round A149 - Search API Live Transport Research Refresh and Cut-Plan Revalidation

```text
Task: Perform a docs-only research refresh and cut-plan revalidation before any
live Search API transport work. Treat prior audits and other agents' summaries
as claims, not ground truth. Read the current repo docs first, then browse
current primary sources and high-signal papers/open-source projects to decide
whether kAir should start a live transport implementation in A150 or insert
another value-only architecture gate.

Allowed files:
- Docs/research/2026-agent-architecture-deep-dive-v1.md
- Docs/research/2026-agent-market-ui-provider-research.md
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Hard non-goals:
- Do not edit Swift, tests, Xcode project metadata, app settings, entitlements,
  networking code, provider adapters, production AppBootstrap defaults,
  ChatStore behavior, SwiftUI/UI layout, telemetry, transcript writes,
  StoreKit/payment, booking/order flows, memory writes, credentials, endpoint
  URLs, API keys, OAuth tokens, SDK/client handles, crawler runtime, MCP client
  runtime, Google/Gaode SDKs, or real provider execution.
- Do not infer the latest market or paper state from memory. Browse and cite
  sources for current claims.

Research scope:
- Market/product scan: current consumer and developer agent/search products
  that shape user expectations for answer attribution, tool disclosure,
  browsing/search status, source trust, provider fallback, task execution, and
  multi-step agent UX. Prefer official docs, product pages, release notes,
  published evaluations, and primary demos over commentary.
- Paper/benchmark scan: recent and durable agent architecture work around
  tool use, planning, memory, web/navigation agents, RAG/search attribution,
  evaluation, safety, budget/latency routing, and human handoff. Include only
  papers that change a concrete kAir decision.
- Open-source architecture scan: practical agent frameworks and projects
  relevant to kAir's local-first/chat-first super-app constraints, including
  graph planners, tool routers, browser/search agents, evaluation harnesses,
  MCP-style tool surfaces, and UI status contracts.
- Architecture fit: compare findings against kAir's existing provider status
  stack: hidden/missing nil, first-wins source order, value-only copy,
  attribution/source policy, quota/entitlement, privacy, audit/evaluation, and
  no live execution until explicit gates.

Required output:
- Update the research docs with current, cited findings and a short decision
  matrix: adopt now, monitor, reject, and why.
- Update the architecture docs with the resulting A150 gate. The gate must be
  narrow enough for a coding agent to implement without reopening broad
  product strategy.
- If live transport is not yet justified, name the next missing value-only
  proof instead of forcing runtime work.
- Preserve existing A148 conclusions unless live research provides concrete
  evidence that changes them.

Acceptance:
- Sources are cited with dates or access context where useful.
- The docs explicitly answer: "Can A150 start live Search API transport?" with
  a yes/no and a specific next gate.
- The decision references market UX, papers, open-source architecture, privacy,
  attribution, quota/entitlement, audit/evaluation, and UI-safe status.
- No Swift, Xcode project, runtime, credential, endpoint, provider adapter, or
  production behavior files change.

Verification:
- Run a doc consistency scan for A148/A149/A150 status.
- Run a touched-file trailing-whitespace scan.
- Run `git diff --check`.
- Run `git status --short` and confirm only allowed docs changed in this gate.
```

Status after implementation: A149 refreshed current market, paper,
open-source-agent, MCP, Search API, maps, and crawler evidence after A148. The
decision is **no live Search API transport in A150**. The next missing proof is
a value-only live vendor candidate selection and cost-policy matrix because
current Search API vendors differ on pricing units, quota/QPS, result shape,
answer generation, citation/source support, raw-content controls, retention,
latency, region, and enterprise terms. No Swift, tests, Xcode project metadata,
runtime, credentials, endpoints, provider adapters, AppBootstrap defaults,
ChatStore behavior, SwiftUI, payment, booking, order, memory, telemetry, or
transcript files were changed in A149.

## Round A150 - Search API Live Vendor Candidate Selection and Cost Policy Matrix Proof

```text
Task: Add a pure value-only Search API live vendor candidate selection and cost
policy matrix. This is not live transport. Do not add URLSession, endpoint
URLs, API keys, OAuth tokens, SDK/client handles, crawler runtime, MCP client
runtime, Google/Gaode SDKs, provider calls, production AppBootstrap defaults,
ChatStore behavior, SwiftUI/UI layout, navigation, telemetry, transcript
mutation, StoreKit/payment, memory writes, raw query/page/provider payload
ingestion, booking/payment/order flow, remote model runtime, hidden third-party
app control, or real provider execution.

Allowed files:
- kAir/Core/Networking/ServerProviderSearchAPILiveVendorSelection.swift
- kAirTests/Networking/ServerProviderSearchAPILiveVendorSelectionTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add `ServerProviderSearchAPILiveVendorCandidate` with only value metadata:
  stable id, display name, provider family, capability, supported result
  shapes, supported freshness, citation/source support, raw-content mode,
  retention level, cost unit, estimated unit price, quota/QPS class, allowed
  regions, latency class, answer-generation support, disabled state, and
  disabled reason.
- Add `ServerProviderSearchAPILiveVendorSelectionRequest` with desired
  capability, result shape, freshness, privacy class, cost class, membership
  tier, region, source/citation policy, max unit price, quota snapshot, and
  user-facing purpose.
- Add `ServerProviderSearchAPILiveVendorSelectionDecision` with
  accepted/rejected state, selected candidate id, ordered safe candidate
  summaries, deterministic rejection reasons, and status-safe copy.
- Selection should keep first eligible candidate deterministically and keep
  duplicate ids first-wins.
- Safe summaries/status/debug/encoded text must be value-only and must not
  contain endpoints, credentials, SDK/client handles, raw query/page/provider
  payloads, crawler/MCP runtime detail, maps SDK detail, payment/booking/order
  data, hidden app-control action, or execution/completion claims.

Acceptance:
- Tests prove candidate acceptance only when capability, freshness, result
  shape, citation/source support, raw-content and retention policy, privacy
  class, region, quota/QPS, and max cost pass.
- Tests prove disabled vendor, over-budget, missing citation/source support,
  raw-content policy mismatch, unsupported region, privacy/Health block,
  unsupported freshness/result shape, missing quota, duplicate candidate ids,
  and empty candidate list reject deterministically or keep the first valid
  candidate.
- Tests prove safe copy/encoding/status text has no endpoint URL, API key,
  OAuth token, SDK/client handle, URLSession, raw query, raw page/provider
  payload, crawler/MCP runtime detail, maps SDK detail, payment/booking/order
  data, hidden app-control action, or execution/completion claim.
- A150 does not change production AppBootstrap defaults, ChatStore behavior,
  SwiftUI/UI layout, runtime networking, provider adapters, StoreKit, crawler,
  MCP client, Google/Gaode SDK, memory, telemetry, transcript, payment,
  booking, order, or real provider behavior.
- Docs mark A150 done and name the next narrow gate. Do not stage, commit,
  merge, or widen into live provider runtime.

Verification:
- Run targeted networking tests for the new A150 type(s).
- Run full `test_sim`.
- Run forbidden-fragment scan for touched Swift diffs, touched-file
  trailing-whitespace scan, A149/A150 doc consistency scan, and
  `git diff --check`.
```

Status after implementation: A150 added
`ServerProviderSearchAPILiveVendorSelection` and focused networking tests. The
new value-only matrix models Search API live vendor candidates, selection
requests, selected/rejected decisions, duplicate-id first-wins, ordered safe
candidate summaries, deterministic rejection reasons, and safe copy. Tests cover
acceptance only when capability, freshness, result shape, citation/source
support, page-body and retention policy, privacy, region, quota/QPS, and max
cost pass; they also cover disabled vendors, over-budget vendors, missing
citation/source support, policy mismatch, unsupported region, Health/private
blocks, unsupported freshness/result shape, missing quota, duplicate ids, empty
candidate lists, Codable/Hashable/Sendable behavior, and safe-copy
forbidden-fragment checks. No AppBootstrap default, ChatStore behavior, SwiftUI,
runtime networking, endpoint, credential, provider adapter, StoreKit, crawler,
MCP client, Google/Gaode SDK, memory, telemetry, transcript, payment, booking,
order, hidden app-control, or real provider behavior was changed.

## Round A151 - Search API Live Vendor Selection Status Source Projection

```text
Task: Package A150 Search API live vendor selection decisions into rendered-id
scoped provider-status copy. This is still value-only status projection. Do not
add AppBootstrap/ChatStore composition yet, and do not add live Search API
transport, endpoint URLs, API keys, OAuth tokens, SDK/client handles,
URLSession, crawler runtime, MCP client runtime, Google/Gaode SDKs, provider
calls, production AppBootstrap defaults, ChatStore behavior, SwiftUI/UI layout,
navigation, telemetry, transcript mutation, StoreKit/payment, memory writes,
raw query/page/provider payload ingestion, booking/payment/order flow, remote
model runtime, hidden third-party app control, or real provider execution.

Allowed files:
- kAir/Core/Networking/ServerProviderSearchAPILiveVendorSelectionStatusSourceProducer.swift
- kAirTests/Networking/ServerProviderSearchAPILiveVendorSelectionStatusSourceProducerTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add an input wrapper that pairs `recommendationID` with
  `ServerProviderSearchAPILiveVendorSelectionDecision`.
- Add `ServerProviderSearchAPILiveVendorSelectionStatusSourceProducer` that
  packages selected and rejected A150 decisions into `ProviderStatusProviding`
  for rendered recommendation ids only.
- Add a store type that keeps duplicate recommendation ids first-wins, hides
  non-rendered ids, and returns nil for missing ids.
- Map selected decisions to advisory/warning status with a Search API/provider
  badge, cost/candidate policy badge, and status text that says the vendor
  candidate is selected for policy planning only and no provider runtime has
  run.
- Map rejected decisions to disabled/warning status with stable rejection
  badges/copy and no selected candidate claim.
- Status copy must carry only A150 safe-copy metadata; it must not expose
  endpoints, credentials, SDK/client handles, URLSession, raw query/page/provider
  payloads, crawler/MCP runtime detail, maps SDK detail, payment/booking/order
  data, hidden app-control action, or execution/completion claims.

Acceptance:
- Tests prove selected and rejected A150 decisions package into provider-status
  presentations for rendered ids.
- Tests prove duplicate recommendation ids keep first input, hidden ids and
  missing ids return nil, and rendered ids are sorted/deterministic if the
  local pattern requires it.
- Tests prove selected/rejected badge kinds, labels, tones, card hints, and
  status copy are stable.
- Tests prove encoded/debug/status text has no endpoint URL, API key, OAuth
  token, SDK/client handle, URLSession, raw query, raw page/provider payload,
  crawler/MCP runtime detail, maps SDK detail, payment/booking/order data,
  hidden app-control action, or execution/completion claim.
- A151 does not change production AppBootstrap defaults, ChatStore behavior,
  SwiftUI/UI layout, runtime networking, provider adapters, StoreKit, crawler,
  MCP client, Google/Gaode SDK, memory, telemetry, transcript, payment,
  booking, order, or real provider behavior.
- Docs mark A151 done and name the next narrow gate. Do not stage, commit,
  merge, or widen into live provider runtime.

Verification:
- Run targeted networking tests for the new A151 status-source type(s).
- Run full `test_sim`.
- Run forbidden-fragment scan for touched Swift diffs, touched-file
  trailing-whitespace scan, A150/A151 doc consistency scan, and
  `git diff --check`.
```

Status after implementation: A151 added
`ServerProviderSearchAPILiveVendorSelectionStatusSourceProducer.swift` and
`ServerProviderSearchAPILiveVendorSelectionStatusSourceProducerTests.swift`.
The source packages A150 selected/rejected live vendor selection decisions into
rendered-id scoped provider status, keeps duplicate recommendation ids
first-wins, hides non-rendered ids, returns nil for missing ids, maps selected
decisions to advisory warning copy with Search API/candidate/cost badges, and
maps rejected decisions to disabled warning copy with stable rejection badges.
The status copy and tests stay value-only and do not add AppBootstrap defaults,
ChatStore behavior, SwiftUI, runtime networking, endpoint URLs, keys, OAuth,
SDK/client handles, crawler/MCP runtime, Google/Gaode SDKs, provider calls,
telemetry, transcript writes, StoreKit/payment, memory writes, raw payload
ingestion, booking/order flows, hidden app-control, remote model runtime, or
real provider execution.

## Round A152 - Search API Live Vendor Selection App-Root Handoff

```text
Task: Prove the A151 Search API live vendor selection status source passes
through `AppBootstrap(providerStatusSources:)` and ChatStore lookup for rendered
ids only. This is still an advisory/status handoff gate only. Do not add live
Search API transport, endpoint URLs, API keys, OAuth tokens, SDK/client handles,
URLSession calls, crawler runtime, MCP client runtime, Google/Gaode SDKs,
provider calls, production AppBootstrap defaults, ChatStore production behavior,
SwiftUI/UI layout, navigation, telemetry, transcript mutation, StoreKit/payment,
memory writes, raw query/page/provider payload ingestion, booking/payment/order
flow, remote model runtime, hidden third-party app control, or real provider
execution.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add focused AppBootstrap tests that build the A151 status source with selected
  and rejected live vendor selection decisions and inject it through
  `AppBootstrap(providerStatusSources:)`.
- Verify ChatStore reads the exact same provider-status presentation for
  rendered recommendation ids.
- Verify hidden and missing recommendation ids return nil at root and store
  lookup.
- Verify source-order first-wins against fallback status without stale fallback
  detail leaking into the selected live vendor selection status.
- Do not change production AppBootstrap defaults, ChatStore behavior,
  SwiftUI/UI, navigation, provider runtime, networking, or status-source order
  outside the test.

Acceptance:
- Tests prove selected and rejected A151 live vendor selection status pass
  through root and store lookup exactly.
- Tests prove hidden/missing ids stay nil and source-order first-wins prevents
  stale fallback details.
- Tests prove no endpoint URL, credential value, SDK handle, URLSession, raw
  query/page/provider payload, payment/order/booking data, crawler/MCP detail,
  maps SDK detail, hidden app-control action, or execution/completion claim is
  introduced.
- Docs mark A152 done and name the next narrow gate. Do not stage, commit,
  merge, or widen into live provider runtime.

Verification:
- Run the new focused AppBootstrap test(s).
- Run full `test_sim`.
- Run forbidden-fragment scan for touched Swift diffs, touched-file
  trailing-whitespace scan, A151/A152 doc consistency scan, and
  `git diff --check`.
```

Status after implementation: A152 added focused AppBootstrap tests proving the
A151 live vendor selection status source passes through
`AppBootstrap(providerStatusSources:)` and ChatStore lookup for rendered ids
only. Selected and rejected live vendor selection status copy is identical from
source to root to store, hidden/missing ids stay nil, and fallback
source-order first-wins does not leak stale fallback detail into selected live
vendor selection status. It does not wire URLSession, endpoint URLs, keys,
OAuth, SDK/client handles, crawler/MCP runtime, maps runtime, provider calls,
production AppBootstrap defaults, ChatStore behavior, SwiftUI, telemetry,
transcript writes, StoreKit/payment, memory writes, raw payload ingestion,
booking/order flows, hidden app-control, remote model runtime, or real provider
execution.

## Round A153 - Search API Live Vendor Selection Cross-Stage Status Composition

```text
Task: Compose the A151 Search API live vendor selection status source with the
earlier Search API status stack through `AppBootstrap(providerStatusSources:)`
and ChatStore lookup. This is still a status-composition proof only. Do not add
live Search API transport, endpoint URLs, API keys, OAuth tokens,
SDK/client handles, URLSession calls, crawler runtime, MCP client runtime,
Google/Gaode SDKs, provider calls, production AppBootstrap defaults, ChatStore
production behavior, SwiftUI/UI layout, navigation, telemetry, transcript
mutation, StoreKit/payment, memory writes, raw query/page/provider payload
ingestion, booking/payment/order flow, remote model runtime, hidden third-party
app control, or real provider execution.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add focused AppBootstrap tests that build the A151 live vendor selection status
  source alongside the existing Search API status stack sources.
- Include at least one selected/rendered recommendation id, one rejected/rendered
  recommendation id, hidden ids for each participating source, and a missing id.
- Verify source-order first-wins across live vendor selection, metered
  entitlement, vendor policy, dispatch authorization, transport lease, transport
  request/response, preflight, audit, and fallback sources according to the local
  stack pattern already established in this file.
- Verify ChatStore sees the exact root-selected provider status for rendered ids,
  hidden/missing ids remain nil, and selected copy does not contain stale detail
  from later status sources.
- Do not change production AppBootstrap defaults, ChatStore behavior,
  SwiftUI/UI, navigation, provider runtime, networking, or status-source order
  outside the test.

Acceptance:
- Tests prove A151 live vendor selection status composes deterministically with
  the existing Search API status stack through root and store lookup.
- Tests prove first-wins source order prevents stale metered/vendor/dispatch/
  authorization/lease/request/response/preflight/audit/fallback detail from
  leaking into selected copy.
- Tests prove hidden/missing ids stay nil across all participating sources.
- Tests prove no endpoint URL, credential value, SDK handle, URLSession, raw
  query/page/provider payload, payment/order/booking data, crawler/MCP detail,
  maps SDK detail, hidden app-control action, or execution/completion claim is
  introduced.
- Docs mark A153 done and name the next narrow gate. Do not stage, commit,
  merge, or widen into live provider runtime.

Verification:
- Run the new focused AppBootstrap test(s).
- Run full `test_sim`.
- Run forbidden-fragment scan for touched Swift diffs, touched-file
  trailing-whitespace scan, A152/A153 doc consistency scan, and
  `git diff --check`.
```

Status after implementation: A153 added a focused cross-stage AppBootstrap test
that composes the A151 live vendor selection status source with the existing
Search API status stack. Live vendor selection, metered entitlement, vendor
policy, dispatch, authorization, lease, request, response, preflight, audit,
and fallback sources are each tested as the first source through
`AppBootstrap(providerStatusSources:)` and ChatStore lookup. Root and store copy
stay identical, hidden/missing ids stay nil, and later-source markers do not
leak into the selected presentation. It does not wire live Search API
transport, endpoints, credentials, URLSession, SDK/client handles, crawler/MCP
runtime, maps runtime, provider calls, production AppBootstrap defaults,
ChatStore behavior, SwiftUI, telemetry, transcript writes, StoreKit/payment,
memory writes, raw payload ingestion, booking/order flows, hidden app-control,
remote model runtime, or real provider execution.

## Round A154 - Search API Live Transport Research Refresh and Cut-Plan Revalidation

```text
Task: Before any live Search API transport implementation, refresh the current
market, paper, open-source-agent, MCP, search-provider, crawler, maps, and UI
architecture evidence against the now-complete A153 status-composition stack.
This is a research/docs gate only. Decide whether A155 can safely begin a live
transport proof, or whether another value-only proof is still required. Do not
add or edit Swift production code, tests, runtime transport, endpoint URLs, API
keys, OAuth tokens, SDK/client handles, URLSession calls, crawler runtime, MCP
client runtime, Google/Gaode SDKs, provider calls, AppBootstrap defaults,
ChatStore production behavior, SwiftUI/UI layout, navigation, telemetry,
transcript mutation, StoreKit/payment, memory writes, raw query/page/provider
payload ingestion, booking/payment/order flow, remote model runtime, hidden
third-party app control, or real provider execution.

Allowed files:
- Docs/research/2026-agent-market-ui-provider-research.md
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Deep-search current competitive products and agent surfaces, including
  consumer super-app agents, mobile search assistants, local-first assistants,
  MCP-backed tools, and provider-routing products. Separate verified facts from
  product-manager judgment.
- Re-read recent agent architecture papers and credible experimental systems for
  planning, tool use, memory, UI grounding, evaluation, safety gates, and
  cost-aware routing. Call out what applies to kAir and what should remain a
  non-goal.
- Compare open-source agent frameworks and MCP/search/crawler projects against
  the current kAir contracts: rendered-id scoped status, first-wins composition,
  provider safe copy, privacy/cost/source gates, and no hidden app-control.
- Re-check Search API, crawler, maps, and MCP provider constraints that affect
  live transport: pricing units, quota/QPS, citation/source-host support,
  raw-content retention, answer-vs-link shape, regional availability, privacy
  terms, latency, and enterprise constraints.
- Produce a clear A155 recommendation: either a narrow live-transport proof can
  start, or the next gate must stay value-only. Include the exact next prompt
  and hard non-goals.

Acceptance:
- Docs contain dated sources and explicit reasoning, not generic market claims.
- The recommendation preserves the A153 status-composition contract and does not
  weaken hidden/missing nil lookup, first-wins source order, safe-copy wording,
  privacy/cost/source/citation gates, or no-provider-execution boundaries.
- The next prompt is paste-ready for the coding agent and has an allowed-file
  list, implementation shape, acceptance checks, and verification commands.
- Do not stage, commit, merge, or widen into live provider runtime.

Verification:
- Run doc consistency scans for A153/A154/A155 labels.
- Run touched-file trailing-whitespace scan.
- Run `git diff --check`.
```

Status after implementation: A154 refreshed current market, UI, paper,
open-source-agent, MCP/search/crawler, maps, Search API vendor, and provider
constraint evidence after A153. The decision is that A155 may start a narrow
live-transport proof only as a comment-programming/value-only server adapter
interface. A155 must still avoid URLSession, endpoint URLs, credentials, OAuth,
SDK/client handles, live provider calls, Google/Gaode SDK/API calls, crawler/MCP
runtime, production AppBootstrap defaults, ChatStore behavior, SwiftUI provider
UI, payment/booking/order runtime, raw payload ingestion, hidden app-control,
and execution/completion claims.

## Round A155 - Search API Live Transport Server Adapter Interface Comment-Programming Proof

```text
Task: Add a Search API live transport server adapter interface proof that is
pure value/comment-programming only. This is the first narrow live-transport
interface step after A153/A154, not a runtime transport. Bind A150 live vendor
selection, A117 metered entitlement, A122 lease, A126 transport request, A131
response-receipt rules, A140 audit trace, A144 boundary readiness, and A153
status composition into metadata-only descriptor, request, and decision values.
Do not add URLSession, endpoint URLs, API keys, OAuth tokens, SDK/client
handles, live provider calls, production AppBootstrap defaults, ChatStore
production behavior, SwiftUI/UI layout, navigation, telemetry, transcript
mutation, StoreKit/payment, memory writes, raw query/page/provider payload
ingestion, crawler runtime, MCP client runtime, Google/Gaode SDKs, booking/
payment/order flow, remote model runtime, hidden third-party app control, or
real provider execution.

Allowed files:
- kAir/Core/Networking/ServerProviderSearchAPILiveTransportAdapterInterface.swift
- kAirTests/Networking/ServerProviderSearchAPILiveTransportAdapterInterfaceTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add `ServerProviderSearchAPILiveTransportAdapterDescriptor`: adapter id,
  vendor id, provider family, capability, supported result shapes/freshness,
  cost unit, search depth/context class, raw-content mode, retention class,
  citation/source support, QPS/rate class, region set, kill-switch id, retry
  policy id, and server-owned secret mode.
- Add `ServerProviderSearchAPILiveTransportAdapterInterfaceRequest`: selected
  A150 vendor decision id, metered decision id, lease id, transport request id,
  audit trace id, boundary id, expected result shape/freshness/cost class,
  privacy class, source/citation/attribution requirements, and user-facing
  purpose. It must not carry raw query text or page/provider payload.
- Add `ServerProviderSearchAPILiveTransportAdapterInterfaceDecision`: accepted
  or rejected metadata-only state, deterministic rejection reason, safe
  descriptor summary, and `isRuntimeCallable == false`.
- Add deterministic rejection reasons for provider family mismatch, vendor
  mismatch, unsupported capability/result shape/freshness, cost unit mismatch,
  raw-content policy conflict, retention conflict, missing citation/source
  support, region blocked, quota/QPS class unavailable, kill switch active,
  missing upstream id, privacy/Health blocked, stale boundary/readiness, and
  server secret mode not server-owned.
- Follow local first-wins and safe-copy patterns from A150-A153. Do not change
  production AppBootstrap defaults, ChatStore behavior, SwiftUI/UI, navigation,
  provider runtime, networking, or status-source order outside the new proof.

Acceptance:
- Tests prove only a matching Search API descriptor and matching upstream ids can
  create an accepted interface decision.
- Tests prove every mismatch/rejection reason is deterministic and value-only.
- Tests prove duplicate descriptors keep first-wins or reject deterministically
  according to the local pattern.
- Tests prove `isRuntimeCallable` remains false for accepted and rejected
  interface decisions.
- Encoded/debug/status copy contains no endpoint URL, API key, OAuth token,
  bearer token, credential, URLSession, URLRequest, SDK/client handle, raw query,
  raw page/provider payload, StoreKit/payment/order/booking data, crawler/MCP
  runtime detail, maps SDK detail, hidden app-control, provider call, or
  execution/completion claim.
- Docs mark A155 done and name the next narrow gate. Do not stage, commit,
  merge, or widen into live provider runtime.

Verification:
- Run the new focused Search API live transport adapter interface tests.
- Run full `test_sim`.
- Run forbidden-fragment scan for touched Swift diffs, touched-file
  trailing-whitespace scan, A154/A155 doc consistency scan, and
  `git diff --check`.
```

Status after implementation: A155 added
`ServerProviderSearchAPILiveTransportAdapterInterface.swift` and focused tests.
The new metadata-only descriptor, request, summary, decision, and safe-copy
values bind selected vendor, metered entitlement, lease, transport request,
audit trace, boundary, readiness, result/freshness/cost/source requirements,
region, kill-switch, retry policy, and server-owned secret mode while keeping
`isRuntimeCallable == false`. Focused tests prove accepted matching descriptors,
deterministic rejection reasons, duplicate descriptor first-wins,
Codable/Hashable/Sendable behavior, and forbidden-fragment copy checks. A155
does not add URLSession, endpoints, credentials, OAuth, SDK/client handles, live
provider calls, Google/Gaode SDK/API calls, crawler/MCP runtime, production
AppBootstrap defaults, ChatStore behavior, SwiftUI provider UI, payment/booking/
order runtime, raw payload ingestion, hidden app-control, or execution/
completion claims.

## Round A156 - Search API Live Transport Adapter Interface Status Source

```text
Task: Package A155 Search API live transport adapter interface decisions into a
rendered-id scoped provider-status source. This is still status packaging only,
not app-root handoff and not runtime transport. Do not add URLSession, endpoint
URLs, API keys, OAuth tokens, SDK/client handles, live provider calls,
production AppBootstrap defaults, ChatStore production behavior, SwiftUI/UI
layout, navigation, telemetry, transcript mutation, StoreKit/payment, memory
writes, raw query/page/provider payload ingestion, crawler runtime, MCP client
runtime, Google/Gaode SDKs, booking/payment/order flow, remote model runtime,
hidden third-party app control, or real provider execution.

Allowed files:
- kAir/Core/Networking/ServerProviderSearchAPILiveTransportAdapterInterfaceStatusSourceProducer.swift
- kAirTests/Networking/ServerProviderSearchAPILiveTransportAdapterInterfaceStatusSourceProducerTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add a rendered-id scoped status source producer for
  `ServerProviderSearchAPILiveTransportAdapterInterfaceDecision`.
- Accepted interface decisions should render advisory warning copy that names the
  Search API interface, candidate adapter policy, and cost/source state without
  claiming a provider call.
- Rejected interface decisions should render disabled warning copy with stable
  rejection badges for privacy, cost/quota, terms/source, unavailable, or
  readiness blocks.
- Preserve duplicate recommendation-id first-wins and hidden/missing nil lookup.
- Preserve `isRuntimeCallable == false` in status copy and do not expose
  descriptor internals beyond safe metadata.
- Do not change AppBootstrap defaults, ChatStore behavior, SwiftUI/UI,
  navigation, provider runtime, networking, or status-source order outside the
  new proof.

Acceptance:
- Tests prove accepted and rejected A155 decisions package into rendered-id
  scoped provider-status copy with stable badges, card hints, and status text.
- Tests prove duplicate recommendation ids keep the first input, hidden ids stay
  nil behind rendered-id filtering, and missing ids return nil.
- Tests prove status/debug/encoded copy contains no endpoint URL, API key, OAuth
  token, bearer token, credential, URLSession, URLRequest, SDK/client handle,
  raw query, raw page/provider payload, StoreKit/payment/order/booking data,
  crawler/MCP runtime detail, maps SDK detail, hidden app-control, provider
  call, or execution/completion claim.
- Docs mark A156 done and name the next narrow gate. Do not stage, commit,
  merge, or widen into live provider runtime.

Verification:
- Run the new focused adapter interface status-source tests.
- Run full `test_sim`.
- Run forbidden-fragment scan for touched Swift diffs, touched-file
  trailing-whitespace scan, A155/A156 doc consistency scan, and
  `git diff --check`.
```

Status after implementation: A156 added
`ServerProviderSearchAPILiveTransportAdapterInterfaceStatusSourceProducer.swift`
and focused tests. The source packages A155 accepted/rejected Search API live
transport adapter interface decisions into rendered-id scoped provider status,
maps accepted decisions to advisory warning copy with Search API interface,
candidate adapter policy, cost, and source-state metadata, maps rejected
decisions to disabled warning copy with stable privacy, cost/quota,
terms/source, readiness, and unavailable badges, keeps duplicate recommendation
ids first-wins, hides non-rendered ids, returns nil for missing ids, and
preserves `isRuntimeCallable false` in status copy. It exposes only safe
descriptor-summary metadata and does not add AppBootstrap defaults, ChatStore
behavior, SwiftUI/UI, navigation, networking, provider runtime, URLSession,
endpoints, credentials, OAuth, SDK/client handles, raw query/page/provider
payload ingestion, crawler/MCP runtime, Google/Gaode SDKs, StoreKit/payment,
booking/order flows, memory writes, telemetry, transcript mutation, hidden
app-control, provider calls, or execution/completion claims.

## Round A157 - Search API Live Transport Adapter Interface App-Root Handoff

```text
Task: Prove the A156 Search API live transport adapter interface status source
passes through `AppBootstrap(providerStatusSources:)` and ChatStore lookup for
rendered recommendation ids only. This is still an advisory/status handoff gate
only, not runtime transport. Do not add URLSession, endpoint URLs, API keys,
OAuth tokens, SDK/client handles, live provider calls, production AppBootstrap
defaults, ChatStore production behavior, SwiftUI/UI layout, navigation,
telemetry, transcript mutation, StoreKit/payment, memory writes, raw query/page/
provider payload ingestion, crawler runtime, MCP client runtime, Google/Gaode
SDKs, booking/payment/order flow, remote model runtime, hidden third-party app
control, or real provider execution.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add focused AppBootstrap tests that build the A156 status source with accepted
  and rejected A155 adapter interface decisions and inject it through
  `AppBootstrap(providerStatusSources:)`.
- Verify root lookup and ChatStore lookup return the exact same
  provider-status presentation for rendered recommendation ids.
- Verify hidden and missing recommendation ids return nil at root and store
  lookup.
- Verify source-order first-wins against fallback provider status without stale
  fallback detail leaking into the selected A156 copy.
- Do not change production AppBootstrap defaults, ChatStore behavior, SwiftUI/UI,
  navigation, provider runtime, networking, or status-source order outside the
  test.

Acceptance:
- Tests prove accepted and rejected A156 adapter interface status passes through
  root and store lookup exactly.
- Tests prove hidden/missing ids stay nil and source-order first-wins prevents
  stale fallback details.
- Tests prove no endpoint URL, credential value, SDK handle, URLSession,
  URLRequest, raw query/page/provider payload, payment/order/booking data,
  crawler/MCP detail, maps SDK detail, hidden app-control action, provider call,
  or execution/completion claim is introduced.
- Docs mark A157 done and name the next narrow gate. Do not stage, commit,
  merge, or widen into live provider runtime.

Verification:
- Run the new focused AppBootstrap test(s).
- Run full `test_sim`.
- Run forbidden-fragment scan for touched Swift diffs, touched-file
  trailing-whitespace scan, A156/A157 doc consistency scan, and
  `git diff --check`.
```

Status after implementation: A157 added focused AppBootstrap tests proving the
A156 Search API live transport adapter interface status source passes through
`AppBootstrap(providerStatusSources:)` and ChatStore lookup for rendered ids
only. Accepted and rejected adapter interface status copy is identical from
source to root to store, hidden/missing ids stay nil, and source-order
first-wins against fallback status prevents stale fallback detail from leaking
into selected A156 copy. It does not change production AppBootstrap defaults,
ChatStore behavior, SwiftUI/UI, navigation, networking, provider runtime,
URLSession, endpoints, credentials, OAuth, SDK/client handles, raw query/page/
provider payload ingestion, crawler/MCP runtime, Google/Gaode SDKs,
StoreKit/payment, booking/order flows, memory writes, telemetry, transcript
mutation, hidden app-control, provider calls, or execution/completion claims.

## Round A158 - Search API Live Transport Adapter Interface Cross-Stage Status Composition

```text
Task: Compose the A156 Search API live transport adapter interface status source
with the existing Search API status stack through
`AppBootstrap(providerStatusSources:)` and ChatStore lookup. This is still a
status-composition proof only. Do not add URLSession, endpoint URLs, API keys,
OAuth tokens, SDK/client handles, live provider calls, production AppBootstrap
defaults, ChatStore production behavior, SwiftUI/UI layout, navigation,
telemetry, transcript mutation, StoreKit/payment, memory writes, raw query/page/
provider payload ingestion, crawler runtime, MCP client runtime, Google/Gaode
SDKs, booking/payment/order flow, remote model runtime, hidden third-party app
control, or real provider execution.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add focused AppBootstrap tests that build the A156 adapter interface status
  source alongside the existing Search API status stack sources.
- Include at least one accepted/rendered recommendation id, one rejected/rendered
  recommendation id, hidden ids for each participating source, and a missing id.
- Verify source-order first-wins across adapter interface, live vendor selection,
  readiness, metered entitlement, vendor policy, dispatch authorization,
  transport lease, transport request/response, preflight, audit, and fallback
  sources according to the local stack pattern already established in
  `AppBootstrapTests.swift`.
- Verify ChatStore sees the exact root-selected provider status for rendered ids,
  hidden/missing ids remain nil, and selected copy does not contain stale detail
  from later status sources.
- Do not change production AppBootstrap defaults, ChatStore behavior, SwiftUI/UI,
  navigation, provider runtime, networking, or status-source order outside the
  test.

Acceptance:
- Tests prove A156 adapter interface status composes deterministically with the
  existing Search API status stack through root and store lookup.
- Tests prove first-wins source order prevents stale adapter/vendor/readiness/
  metered/dispatch/authorization/lease/request/response/preflight/audit/fallback
  detail from leaking into selected copy.
- Tests prove hidden/missing ids stay nil across all participating sources.
- Tests prove no endpoint URL, credential value, SDK handle, URLSession,
  URLRequest, raw query/page/provider payload, payment/order/booking data,
  crawler/MCP detail, maps SDK detail, hidden app-control action, provider call,
  or execution/completion claim is introduced.
- Docs mark A158 done and name the next narrow gate. Do not stage, commit,
  merge, or widen into live provider runtime.

Verification:
- Run the new focused AppBootstrap test(s).
- Run full `test_sim`.
- Run forbidden-fragment scan for touched Swift diffs, touched-file
  trailing-whitespace scan, A157/A158 doc consistency scan, and
  `git diff --check`.
```

Status after implementation: A158 added a focused AppBootstrap cross-stage
composition test for the A156 Search API live transport adapter interface status
source plus the existing Search API status stack. Adapter interface, live vendor
selection, readiness, metered entitlement, vendor policy, dispatch
authorization, lease, request, response, preflight, audit, and fallback sources
are each tested as the first source through `AppBootstrap(providerStatusSources:)`
and ChatStore lookup. Root and store copy stay identical, hidden/missing ids stay
nil, and later-source markers do not leak into the selected presentation. It
does not wire live Search API transport, endpoints, credentials, URLSession,
SDK/client handles, crawler/MCP runtime, maps runtime, provider calls,
production AppBootstrap defaults, ChatStore behavior, SwiftUI, telemetry,
transcript writes, StoreKit/payment, memory writes, raw payload ingestion,
booking/order flows, hidden app-control, remote model runtime, or real provider
execution.

## Round A159 - Search API Live Provider Research Refresh and Cut-Plan Revalidation

```text
Task: Run a docs/research refresh after the A158 status-composition stack and
decide the next narrow server-side Search API live-provider gate. This is a
research/docs gate only. Do not add Swift code, URLSession, endpoint URLs, API
keys, OAuth tokens, SDK/client handles, live provider calls, production
AppBootstrap defaults, ChatStore production behavior, SwiftUI/UI layout,
navigation, telemetry, transcript mutation, StoreKit/payment, memory writes, raw
query/page/provider payload ingestion, crawler runtime, MCP client runtime,
Google/Gaode SDKs, booking/payment/order flow, remote model runtime, hidden
third-party app control, or real provider execution.

Allowed files:
- Docs/research/2026-agent-market-ui-provider-research.md
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Research shape:
- Re-check current agent architecture papers and open-source frameworks for
  verifier/planner/tool-use/search/cost-routing patterns that affect the next
  Search API gate.
- Re-check mobile agent and life-service agent products, including Marvis-style
  local/remote assistant UX, Tencent Yuanbao/Hy3-style chat+search patterns, and
  Meituan/LongCat-style life-service agent direction where public evidence is
  available.
- Re-check MCP, crawler, robots/source policy, Search API vendor, Google/Gaode
  maps-provider, and Apple local-first/App Intents/Core Location constraints.
- Compare findings against kAir's current provider-status stack, A150-A158
  Search API gates, local-first privacy boundary, membership/cost routing, and
  rendered-id side-channel rules.

Decision requirement:
- Produce a clear A160 recommendation: either a narrow server-side live-provider
  proof can start, or another value-only/interface/status gate must come first.
- If A160 can start, name exactly one implementation slice, allowed files,
  explicit non-goals, acceptance tests, and verification commands.
- Preserve the A158 status-composition contract and do not reopen broad runtime
  work without a narrow next gate.

Acceptance:
- Docs summarize new/reconfirmed market, UI, paper, open-source-agent, MCP,
  crawler, maps, Search API vendor, cost, privacy, and source-policy evidence.
- Docs explicitly explain why the selected next gate follows from A158 and what
  remains out of scope.
- Docs mark A159 done and name the next narrow gate. Do not stage, commit,
  merge, or widen into live provider runtime.

Verification:
- Run doc consistency scans for A158/A159/A160 labels.
- Run touched-doc trailing-whitespace scan and `git diff --check`.
```

Status after implementation: A159 refreshed the current agent architecture,
mobile/life-service agent, Search API vendor, MCP/crawler, maps provider, Apple
local-first, and cost-aware routing evidence after the A158 cross-stage status
composition proof. The refresh keeps the project out of direct URLSession/API
runtime work. It selects A160 as a metadata-only server-side invocation
preflight contract that joins accepted adapter interface, selected vendor,
metered entitlement, lease, transport request, boundary/readiness, source
policy, budget, region, and audit metadata into a non-callable receipt before
any live provider path can exist.

## Round A160 - Search API Live Provider Invocation Preflight Contract

```text
Task: Add a value-only Search API live-provider invocation preflight contract.
This is comment-programming and contract/test work only. It must prove that an
accepted A155 adapter interface decision can be joined with upstream A150/A117/
A122/A126/A140/A144 metadata before a future server-side provider call, while
keeping the result non-callable. Do not add URLSession, endpoint URLs, API keys,
OAuth tokens, bearer tokens, credentials, SDK/client handles, live provider
calls, production AppBootstrap defaults, ChatStore production behavior,
SwiftUI/UI layout, navigation, telemetry, transcript mutation, StoreKit/payment,
memory writes, raw query/page/provider payload ingestion, crawler runtime, MCP
client runtime, Google/Gaode SDKs, booking/payment/order flow, remote model
runtime, hidden third-party app control, or real provider execution.

Allowed files:
- kAir/Core/Networking/ServerProviderSearchAPILiveProviderInvocationPreflight.swift
- kAirTests/Networking/ServerProviderSearchAPILiveProviderInvocationPreflightTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Define `ServerProviderSearchAPILiveProviderInvocationPreflightInput` carrying
  only upstream ids and policy metadata: accepted adapter-interface decision,
  selected descriptor id, selected vendor decision id, metered decision id,
  lease id, transport request id, audit trace id, boundary/readiness ids,
  provider family, capability, result shape, freshness, cost class, cost unit,
  search-context class, raw-content requirement, retention class, citation,
  source-host, attribution, region, membership tier, budget snapshot id, and
  user-facing purpose.
- Define `ServerProviderSearchAPILiveProviderInvocationPreflightDecision` with
  accepted/rejected metadata-only state, stable preflight/audit id,
  deterministic rejection reasons, safe summary, and non-callable flag.
- Rejection reasons should include adapter interface not accepted, runtime
  callable flag true, provider family mismatch, vendor/descriptor mismatch,
  missing upstream id, metered decision mismatch, lease mismatch/expired lease,
  transport request mismatch, stale boundary/readiness, cost unit/class
  mismatch, missing budget snapshot, region blocked, privacy/Health blocked,
  missing citation/source/attribution, raw-content policy conflict, retention
  conflict, server secret mode not server-owned, unsupported maps/crawler/MCP
  family, and duplicate preflight id.

Acceptance:
- Tests prove accepted preflight only when adapter interface, vendor decision,
  entitlement, lease, request, boundary/readiness, source policy, region, cost,
  budget, and audit metadata all match.
- Tests prove every rejection reason is deterministic and value-only.
- Tests prove duplicate preflight ids keep first-wins or reject deterministically
  according to the local pattern.
- Tests prove `isRuntimeCallable` or equivalent remains false.
- Encoded/debug/status-safe copy contains no endpoint URL, API key, OAuth token,
  bearer token, credential, URLSession, URLRequest, SDK/client handle, raw
  query, raw page/provider payload, crawler/MCP runtime detail, maps SDK detail,
  StoreKit/payment/order/booking data, hidden app-control, provider call, or
  execution/completion claim.
- A160 does not change production AppBootstrap defaults, ChatStore behavior,
  SwiftUI/UI, navigation, telemetry, memory writes, transcript mutation,
  URLSession/networking, crawler/MCP client, Google/Gaode SDK, StoreKit/payment,
  booking/order, remote model runtime, or real provider behavior.

Verification:
- Run the new focused networking test(s).
- Run full `test_sim`.
- Run forbidden-fragment scan for touched Swift diffs, touched-file
  trailing-whitespace scan, A159/A160 doc consistency scan, and
  `git diff --check`.
```

Status after implementation: A160 added
`ServerProviderSearchAPILiveProviderInvocationPreflight` plus focused networking
tests. The contract joins the accepted A155 adapter interface, selected vendor,
metered entitlement id, lease, request, audit, boundary/readiness, cost, source,
region, privacy, retention, server-secret, budget, and purpose metadata into a
non-callable preflight receipt. Accepted decisions remain metadata-only;
rejected paths cover runtime-callable flags, unsupported provider families,
upstream id mismatches, stale readiness, expired leases, source/citation/
attribution gaps, privacy/Health blocks, duplicate preflight ids, and policy
conflicts. No URLSession, endpoint, credential, SDK/client, provider call,
AppBootstrap default, ChatStore production behavior, SwiftUI/UI, crawler/MCP,
maps SDK, payment/booking/order, hidden app-control, raw provider payload,
telemetry, memory write, transcript mutation, or real provider execution was
added.

## Round A161 - Search API Live Provider Invocation Preflight Status Source

```text
Task: Package A160 Search API live-provider invocation preflight decisions into
a rendered-id scoped provider-status source. This is status projection only.
Do not add AppBootstrap handoff, ChatStore production behavior, SwiftUI/UI,
URLSession, endpoint URLs, API keys, OAuth tokens, bearer tokens, credentials,
SDK/client handles, live provider calls, telemetry, transcript mutation,
StoreKit/payment, memory writes, raw query/page/provider payload ingestion,
crawler runtime, MCP client runtime, Google/Gaode SDKs, booking/payment/order
flow, remote model runtime, hidden third-party app control, or real provider
execution.

Allowed files:
- kAir/Core/Networking/ServerProviderSearchAPILiveProviderInvocationPreflightStatusSourceProducer.swift
- kAirTests/Networking/ServerProviderSearchAPILiveProviderInvocationPreflightStatusSourceProducerTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add `ServerProviderSearchAPILiveProviderInvocationPreflightStatusSourceProducer`
  that accepts explicit recommendation ids plus A160 preflight decisions and
  returns a `ServerProviderRenderedRuntimeStatusSource`.
- Add a status store implementing `ProviderStatusProviding`.
- Accepted preflight copy should expose advisory metadata only: Search API
  provider preflight, selected descriptor/vendor, cost, source, region, budget,
  and `isRuntimeCallable false`.
- Rejected preflight copy should be disabled and map rejection reasons to stable
  badges/card hints without exposing raw ids beyond safe upstream ids already
  allowed by A160.
- Duplicate recommendation ids must keep first-wins. Hidden/missing rendered ids
  must return nil.

Acceptance:
- Tests prove accepted and rejected A160 preflight decisions project into stable
  provider status presentations.
- Tests prove duplicate recommendation ids keep first-wins and hidden/missing
  rendered ids return nil.
- Tests prove badge/card-hint mappings are deterministic for cost, source,
  privacy, readiness, region, duplicate, unavailable, and advisory accepted
  paths.
- Tests prove status/debug copy contains no endpoint URL, API key, OAuth token,
  bearer token, credential, URLSession, URLRequest, SDK/client handle, raw
  query, raw page/provider payload, crawler/MCP runtime detail, maps SDK detail,
  StoreKit/payment/order/booking data, hidden app-control, provider call, or
  execution/completion claim.
- A161 does not change AppBootstrap defaults, ChatStore production behavior,
  SwiftUI/UI, navigation, telemetry, memory writes, transcript mutation,
  URLSession/networking, crawler/MCP client, Google/Gaode SDK, StoreKit/payment,
  booking/order, remote model runtime, or real provider behavior.

Verification:
- Run the new focused status-source test(s).
- Run full `test_sim`.
- Run forbidden-fragment scan for touched Swift diffs, touched-file
  trailing-whitespace scan, A160/A161 doc consistency scan, and
  `git diff --check`.
```

Status after implementation: A161 added
`ServerProviderSearchAPILiveProviderInvocationPreflightStatusSourceProducer`
and focused status-source tests. A160 preflight decisions now package into a
rendered-id scoped provider-status source. Accepted copy is advisory only and
exposes Search API preflight, descriptor/vendor, cost, source, region, budget,
and `isRuntimeCallable false`; rejected copy is disabled with stable privacy,
cost, readiness, source/terms, region, duplicate, and unavailable badge
mappings. Duplicate recommendation ids keep first-wins, hidden/missing rendered
ids return nil, and status/debug copy stays free of runtime/provider material.
No AppBootstrap handoff, ChatStore production behavior, SwiftUI/UI, networking,
crawler/MCP runtime, Google/Gaode SDK, StoreKit/payment, booking/order, hidden
app-control, provider call, or real provider behavior was added.

## Round A162 - Search API Live Provider Invocation Preflight App-Root Handoff

```text
Task: Prove the A161 Search API live-provider invocation preflight status source
passes through the app composition root and ChatStore rendered-id lookup. This
is an AppBootstrap test-only handoff proof. Do not add production AppBootstrap
defaults, ChatStore production behavior, SwiftUI/UI, URLSession, endpoint URLs,
API keys, OAuth tokens, bearer tokens, credentials, SDK/client handles, live
provider calls, telemetry, transcript mutation, StoreKit/payment, memory writes,
raw query/page/provider payload ingestion, crawler runtime, MCP client runtime,
Google/Gaode SDKs, booking/payment/order flow, remote model runtime, hidden
third-party app control, or real provider execution.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add focused AppBootstrap tests that build accepted and rejected A160 preflight
  decisions, package them with A161 producer, inject the source through
  `AppBootstrap(providerStatusSources:)`, and read the resulting presentation
  through ChatStore for rendered recommendation ids only.
- Prove source -> root -> store copy identity for accepted and rejected
  presentations.
- Prove hidden and missing recommendation ids return nil.
- Prove source-order first-wins against a fallback provider status source so
  later stale copy cannot replace the selected A161 presentation.

Acceptance:
- Tests prove accepted and rejected A161 status copy passes through app-root and
  ChatStore unchanged.
- Tests prove hidden/missing rendered ids remain nil.
- Tests prove direct `providerStatusSource` and `providerStatusSources` order
  still use first source wins.
- Tests prove selected copy contains `isRuntimeCallable false` and no endpoint
  URL, API key, OAuth token, bearer token, credential, URLSession, URLRequest,
  SDK/client handle, raw query, raw page/provider payload, crawler/MCP runtime
  detail, maps SDK detail, StoreKit/payment/order/booking data, hidden
  app-control, provider call, or execution/completion claim.
- A162 does not change production AppBootstrap defaults, ChatStore production
  behavior, SwiftUI/UI, navigation, telemetry, memory writes, transcript
  mutation, URLSession/networking, crawler/MCP client, Google/Gaode SDK,
  StoreKit/payment, booking/order, remote model runtime, or real provider
  behavior.

Verification:
- Run the new focused AppBootstrap test(s).
- Run full `test_sim`.
- Run forbidden-fragment scan for touched Swift diffs, touched-file
  trailing-whitespace scan, A161/A162 doc consistency scan, and
  `git diff --check`.
```

Status after implementation: A162 added focused AppBootstrap tests proving A161
Search API live-provider invocation preflight status sources pass through
`AppBootstrap(providerStatusSources:)` and ChatStore rendered-id lookup.
Accepted/rejected status copy is identical from source to root to store,
hidden/missing ids remain nil, and both direct `providerStatusProvider` plus
ordered `providerStatusSources` keep first-wins against fallback status. The
selected copy stays advisory with `isRuntimeCallable false` and no production
AppBootstrap defaults, ChatStore behavior, SwiftUI/UI, navigation, telemetry,
memory writes, transcript mutation, networking, crawler/MCP client,
Google/Gaode SDK, StoreKit/payment, booking/order, remote model runtime,
provider call, or real provider behavior was added.

## Round A163 - Search API Live Provider Invocation Preflight Cross-Stage Status Composition

```text
Task: Prove the A161 Search API live-provider invocation preflight status source
composes with the existing Search API status stack through
`AppBootstrap(providerStatusSources:)` and ChatStore rendered-id lookup. This is
an AppBootstrap test-only cross-stage priority proof. Do not add production
AppBootstrap defaults, ChatStore production behavior, SwiftUI/UI, URLSession,
endpoint URLs, API keys, OAuth tokens, bearer tokens, credentials, SDK/client
handles, live provider calls, telemetry, transcript mutation, StoreKit/payment,
memory writes, raw query/page/provider payload ingestion, crawler runtime, MCP
client runtime, Google/Gaode SDKs, booking/payment/order flow, remote model
runtime, hidden third-party app control, or real provider execution.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Add one focused AppBootstrap cross-stage test that builds accepted and rejected
  A161 preflight status presentations plus the existing Search API status stack
  sources already covered by prior gates.
- Inject each source as the first source through `AppBootstrap(providerStatusSources:)`
  with the remaining sources trailing, then read selected presentations through
  ChatStore for rendered recommendation ids only.
- Prove the selected source's accepted/rejected copy is identical from source to
  root to store, while all later source markers are absent from the selected
  copy.
- Prove hidden ids for every source and a missing id return nil before and after
  AppBootstrap/ChatStore composition.

Acceptance:
- Tests prove A161 preflight status can win ahead of older Search API status
  sources without leaking earlier/later vendor, request, response, lease,
  budget, metered, audit, adapter, or fallback copy.
- Tests prove every existing Search API status source still wins when it is
  first, and A161 preflight markers do not leak when preflight is trailing.
- Tests prove accepted/rejected selected copies contain `isRuntimeCallable false`
  where applicable and no endpoint URL, API key, OAuth token, bearer token,
  credential, URLSession, URLRequest, SDK/client handle, raw query, raw
  page/provider payload, crawler/MCP runtime detail, maps SDK detail,
  StoreKit/payment/order/booking data, hidden app-control, provider call, or
  execution/completion claim.
- A163 does not change production AppBootstrap defaults, ChatStore production
  behavior, SwiftUI/UI, navigation, telemetry, memory writes, transcript
  mutation, URLSession/networking, crawler/MCP client, Google/Gaode SDK,
  StoreKit/payment, booking/order, remote model runtime, or real provider
  behavior.

Verification:
- Run the new focused AppBootstrap cross-stage test.
- Run full `test_sim`.
- Run forbidden-fragment scan for touched Swift diffs, touched-file
  trailing-whitespace scan, A162/A163 doc consistency scan, and
  `git diff --check`.
```

Status after implementation: A163 added a focused AppBootstrap cross-stage test
proving the A161 Search API live-provider invocation preflight status source
composes with the existing Search API status stack through
`AppBootstrap(providerStatusSources:)` and ChatStore lookup. Invocation
preflight, adapter interface, live vendor selection, readiness, metered
entitlement, vendor policy, dispatch, authorization, lease, request, response,
transport preflight, audit, and fallback sources are each tested as first
source. Selected accepted/rejected copy remains identical from source to root to
store, hidden/missing ids stay nil, later source markers do not leak, and
`isRuntimeCallable false` remains pinned where applicable. No production
AppBootstrap defaults, ChatStore behavior, SwiftUI/UI, navigation, telemetry,
memory writes, transcript mutation, networking, crawler/MCP client,
Google/Gaode SDK, StoreKit/payment, booking/order, remote model runtime,
provider call, or real provider behavior was added.

## Round A164 - Research, Market, UI, and Provider Cut-Plan Refresh After Invocation Preflight Composition

```text
Task: Re-run the research and cut-plan decision after A163. Use current public
evidence, not stale assumptions, to decide the next safe kAir gate now that
Search API live-provider invocation preflight has status-source, app-root, and
cross-stage composition proofs. This is docs/research-only. Do not add Swift
production code, AppBootstrap defaults, ChatStore production behavior, SwiftUI
UI, URLSession, endpoint URLs, API keys, OAuth tokens, bearer tokens,
credentials, SDK/client handles, live provider calls, telemetry, transcript
mutation, StoreKit/payment, memory writes, raw query/page/provider payload
ingestion, crawler runtime, MCP client runtime, Google/Gaode SDKs,
booking/payment/order flow, remote model runtime, hidden third-party app
control, or real provider execution.

Allowed files:
- Docs/research/2026-agent-market-ui-provider-research.md
- Docs/research/2026-agent-architecture-deep-dive-v1.md
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Implementation shape:
- Browse and cite current primary/authoritative sources for agent architecture,
  mobile/local-first agent UX, MCP/tool security, Apple iOS local action
  surfaces, Google/Gaode Maps provider policy, Search API/provider policy, and
  crawler/public-information constraints.
- Recheck relevant competitor/product direction from public sources, including
  MARVIS-style assistants, Tencent Yuanbao-style assistants, and Meituan-style
  life-service agents, focusing on architecture and UI implications rather than
  copying product claims.
- Update the research docs with a dated delta section that maps evidence to
  kAir's local-first iOS contract, member-tier provider switching, search/MCP/
  crawler reservation, and cost-aware API routing.
- Select exactly one next implementation gate with allowed files, non-goals,
  acceptance criteria, and verification. Prefer the smallest gate that moves
  toward the verified architecture without jumping to live provider execution.

Acceptance:
- Research docs include fresh source-backed deltas for architecture, UI/market,
  platform/provider policy, MCP/crawler safety, and cost-aware routing.
- The selected next gate is justified against the current kAir code/docs and
  explicitly states whether live provider work remains blocked or can widen.
- The next gate preserves local-first iOS defaults, privacy gating, member-tier
  cost policy, source/citation requirements, and no hidden third-party app
  control.
- A164 changes docs only and does not modify Swift code, production behavior,
  project files, UI assets, network/runtime clients, credentials, or tests.

Verification:
- Run source-link/quote hygiene review for the touched research docs.
- Run A163/A164 doc consistency scan.
- Run touched-file trailing-whitespace scan and `git diff --check`.
```

Status after implementation: A164 refreshed current research, market, UI,
provider-policy, MCP/crawler, Apple local-first, Google/Gaode, Search API, and
cost-aware routing evidence after the A163 invocation-preflight composition
proof. The conclusion remains no live provider execution yet: no URLSession,
endpoints, credentials, SDK/client handles, crawler/MCP runtime, Google/Gaode
runtime, StoreKit/payment, booking/order, raw provider payloads, hidden app
control, or provider execution. The selected next gate is A165, a prepared-only
Search API live-provider invocation envelope contract that freezes accepted
preflight, vendor, cost, source/citation, retention, region, lease, request,
and audit metadata while keeping the attempt non-executable.

## Round A165 - Search API Live Provider Invocation Envelope Contract

```text
Task: Add a pure value/comment-programming Search API live-provider invocation
envelope contract. This comes after A160-A163 proved invocation preflight,
status-source projection, AppBootstrap handoff, and cross-stage composition.
The envelope should package an accepted A160 preflight into a prepared-only,
server-owned provider attempt shape without enabling URLSession, endpoint URLs,
API keys, OAuth tokens, bearer tokens, credentials, SDK/client handles, live
provider calls, telemetry, transcript mutation, StoreKit/payment, memory
writes, raw query/page/provider payload ingestion, crawler runtime, MCP client
runtime, Google/Gaode SDKs, booking/payment/order flow, remote model runtime,
hidden third-party app control, or real provider execution.

Allowed files:
- kAir/Core/Networking/ServerProviderSearchAPILiveProviderInvocationEnvelope.swift
- kAirTests/Networking/ServerProviderSearchAPILiveProviderInvocationEnvelopeTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Read first:
- kAir/Core/Networking/ServerProviderSearchAPILiveProviderInvocationPreflight.swift
- kAirTests/Networking/ServerProviderSearchAPILiveProviderInvocationPreflightTests.swift
- kAir/Core/Networking/ServerProviderSearchAPILiveProviderInvocationPreflightStatusSourceProducer.swift
- kAirTests/Networking/ServerProviderSearchAPILiveProviderInvocationPreflightStatusSourceProducerTests.swift
- kAirTests/App/AppBootstrapTests.swift

Implementation shape:
- Add `ServerProviderSearchAPILiveProviderInvocationEnvelopeInput` as a pure
  value type. It should carry accepted preflight id/summary, selected
  vendor/adapter ids, provider family, capability, result shape, freshness
  class, search-context class, raw-content policy, citation/source/attribution
  requirements, retention class, region, membership tier, budget snapshot id,
  cost unit, quota/rate class, transport lease id, request id, audit trace id,
  server-secret mode, expiry, redaction policy, and user-facing purpose.
- Add `ServerProviderSearchAPILiveProviderInvocationEnvelopeDecision` as a pure
  value type with prepared/rejected state, deterministic rejection reasons,
  stable envelope id, expiry, safe debug summary, safe status summary,
  `isRuntimeCallable == false`, and `isExecutable == false`.
- Add a small evaluator/factory only if the existing local pattern calls for
  it. Keep it deterministic and value-only.
- Do not add AppBootstrap default wiring, ChatStore production behavior,
  SwiftUI/UI, navigation, URLSession, URLRequest, endpoint URL, credentials,
  SDK/client handles, provider execution, crawler/MCP runtime, Google/Gaode
  runtime, StoreKit/payment/order/booking runtime, telemetry, transcript
  mutation, memory writes, or raw payload storage.

Required rejection reasons:
- preflight not accepted;
- stale or expired preflight;
- descriptor/vendor/adapter mismatch;
- provider family mismatch;
- missing or mismatched budget snapshot;
- cost unit mismatch;
- missing lease id, request id, or audit trace id;
- duplicate envelope id;
- unsafe retention, source, citation, or attribution policy;
- unsupported region;
- client-owned or missing secret mode;
- runtime callable flag true;
- executable flag true;
- unsupported maps/crawler/MCP family;
- payment/order/booking field present;
- raw query, raw page, or raw provider payload present;
- hidden app-control field present.

Acceptance:
- Tests prove a prepared envelope is returned only when an accepted preflight
  and all upstream ids, policy classes, cost fields, region, retention,
  source/citation requirements, lease/request/audit metadata, expiry, and
  server-secret mode match.
- Tests prove rejected envelopes are deterministic, carry the expected reason,
  and do not leak unsafe fragments into safe copy.
- Tests prove duplicate envelope ids are rejected or keep first-wins according
  to the existing local pattern chosen for the collection helper.
- Tests prove `isRuntimeCallable` and `isExecutable` stay false for prepared
  and rejected decisions.
- Tests prove encoded, debug, and status-safe copy contains no endpoint URL,
  API key, OAuth token, bearer token, credential, URLSession, URLRequest,
  SDK/client handle, raw query, raw page/provider payload, crawler/MCP runtime
  detail, maps SDK detail, StoreKit/payment/order/booking data, hidden
  app-control, provider call, or execution/completion claim.
- A165 does not change production AppBootstrap defaults, ChatStore behavior,
  SwiftUI/UI, navigation, telemetry, memory writes, transcript mutation,
  URLSession/networking, crawler/MCP client, Google/Gaode SDK, StoreKit/payment,
  booking/order, remote model runtime, or real provider behavior.

Verification:
- Run the new focused envelope tests.
- Run full `test_sim`.
- Run forbidden-fragment scan for touched Swift diffs, touched-file
  trailing-whitespace scan, A164/A165 doc consistency scan, and
  `git diff --check`.
```

Status after implementation: A165 added
`ServerProviderSearchAPILiveProviderInvocationEnvelope` and focused tests. The
envelope is pure value/comment-programming: it accepts only an accepted A160
preflight, freezes vendor/adapter, provider family, capability, result shape,
freshness, source/citation/attribution, retention, region, membership tier,
budget, cost unit, quota/rate, lease, request, audit, server-secret, expiry,
redaction, and user-facing-purpose metadata, and always keeps
`isRuntimeCallable == false` plus `isExecutable == false`. Rejections cover
non-accepted/stale preflight, mismatched vendor/adapter/policy/cost/lease/
request/audit metadata, duplicate envelope id, unsafe source/retention/
redaction policy, unsupported region/family, unavailable quota, client-owned
secret mode, runtime-callable/executable flags, and unsafe material flags. No
AppBootstrap default, ChatStore behavior, SwiftUI/UI, navigation, networking,
crawler/MCP client, Google/Gaode SDK, StoreKit/payment, booking/order, remote
model runtime, hidden app-control, provider call, or real provider behavior was
added.

## Round A166 - Search API Live Provider Invocation Envelope Status Source Producer

```text
Task: Add a pure status-source projection for A165 Search API live-provider
invocation envelope decisions. This round should make prepared/rejected
envelope state available to rendered recommendation ids as UI-safe provider
status, but it must not wire AppBootstrap defaults, ChatStore production
behavior, SwiftUI/UI, navigation, URLSession, URLRequest, endpoint URLs, API
keys, OAuth tokens, bearer tokens, credentials, SDK/client handles, live
provider calls, telemetry, transcript mutation, StoreKit/payment, memory
writes, raw query/page/provider payload ingestion, crawler runtime, MCP client
runtime, Google/Gaode SDKs, booking/payment/order flow, remote model runtime,
hidden third-party app control, or real provider execution.

Allowed files:
- kAir/Core/Networking/ServerProviderSearchAPILiveProviderInvocationEnvelopeStatusSourceProducer.swift
- kAirTests/Networking/ServerProviderSearchAPILiveProviderInvocationEnvelopeStatusSourceProducerTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Read first:
- kAir/Core/Networking/ServerProviderSearchAPILiveProviderInvocationEnvelope.swift
- kAirTests/Networking/ServerProviderSearchAPILiveProviderInvocationEnvelopeTests.swift
- kAir/Core/Networking/ServerProviderSearchAPILiveProviderInvocationPreflightStatusSourceProducer.swift
- kAirTests/Networking/ServerProviderSearchAPILiveProviderInvocationPreflightStatusSourceProducerTests.swift
- kAir/DesignSystem/Components/ProviderStatusBadgeModel.swift

Implementation shape:
- Add a small projection input that binds a rendered recommendation id, status
  source id/rank, visibility flag, and
  `ServerProviderSearchAPILiveProviderInvocationEnvelopeDecision`.
- Add a producer/source type following the local provider-status-source pattern.
  Prepared envelope decisions should render as advisory/ready provider status;
  rejected decisions should render as blocked/degraded provider status.
- Status copy must include the selected provider family/cost/source/retention
  posture when safe, and must state that both `isRuntimeCallable false` and
  `isExecutable false` remain pinned.
- Hidden inputs and missing rendered ids return nil.
- Duplicate rendered recommendation ids keep first-wins exactly like the
  existing Search API status-source producers.
- Do not expose raw query text, raw page/provider payloads, URLs, credentials,
  SDK/client handles, provider-call claims, completion claims, crawler/MCP
  runtime details, maps SDK details, or commerce flow details.

Acceptance:
- Tests prove prepared envelope decisions map to stable ready/advisory status
  copy and rejected envelope decisions map to stable blocked/degraded status
  copy.
- Tests prove the status source uses only `decision.safeCopy` and preserves
  `isRuntimeCallable false` and `isExecutable false` in visible copy.
- Tests prove hidden inputs and missing rendered ids return nil.
- Tests prove duplicate rendered recommendation ids keep the first envelope
  status and later source markers do not leak.
- Tests prove encoded/debug/status-safe copy contains no endpoint URL, API key,
  OAuth token, bearer token, credential, URLSession, URLRequest, SDK/client
  handle, raw query, raw page/provider payload, crawler/MCP runtime detail,
  maps SDK detail, StoreKit/payment/order/booking data, hidden app-control,
  provider call, or execution/completion claim.
- A166 does not change production AppBootstrap defaults, ChatStore behavior,
  SwiftUI/UI, navigation, telemetry, memory writes, transcript mutation,
  URLSession/networking, crawler/MCP client, Google/Gaode SDK, StoreKit/payment,
  booking/order, remote model runtime, or real provider behavior.

Verification:
- Run the new focused envelope status-source tests.
- Run full `test_sim`.
- Run forbidden-fragment scan for touched Swift diffs, touched-file
  trailing-whitespace scan, A165/A166 doc consistency scan, and
  `git diff --check`.
```

Status after implementation: A166 added
`ServerProviderSearchAPILiveProviderInvocationEnvelopeStatusSourceProducer`
and focused tests. The projection stores only A165 `decision.safeCopy`, maps
prepared envelope decisions to advisory rendered-id provider status, maps
rejected envelope decisions to disabled rendered-id provider status, preserves
hidden/missing nil, duplicate first-wins, status-source id/rank copy, and visible
`isRuntimeCallable false` plus `isExecutable false`. No AppBootstrap default,
ChatStore behavior, SwiftUI/UI, navigation, networking, crawler/MCP client,
Google/Gaode SDK, StoreKit/payment, booking/order, remote model runtime, hidden
app-control, provider call, or real provider behavior was added.

## Round A167 - Search API Live Provider Invocation Envelope Status AppBootstrap Handoff

```text
Task: Prove the A166 Search API live-provider invocation envelope status source
passes through `AppBootstrap(providerStatusSources:)` and `ChatStore`
rendered-id lookup. This round is focused test-only plus docs sync. Do not add
production AppBootstrap defaults, ChatStore production behavior, SwiftUI/UI,
navigation, URLSession, URLRequest, endpoint URLs, API keys, OAuth tokens,
bearer tokens, credentials, SDK/client handles, live provider calls, telemetry,
transcript mutation, StoreKit/payment, memory writes, raw query/page/provider
payload ingestion, crawler runtime, MCP client runtime, Google/Gaode SDKs,
booking/payment/order flow, remote model runtime, hidden third-party app
control, or real provider execution.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Read first:
- kAir/Core/Networking/ServerProviderSearchAPILiveProviderInvocationEnvelopeStatusSourceProducer.swift
- kAirTests/Networking/ServerProviderSearchAPILiveProviderInvocationEnvelopeStatusSourceProducerTests.swift
- kAir/Core/Networking/ServerProviderSearchAPILiveProviderInvocationEnvelope.swift
- kAirTests/App/AppBootstrapTests.swift

Implementation shape:
- Add focused AppBootstrap tests proving an A166 envelope status source can be
  injected through `providerStatusSources`.
- Tests should cover prepared and rejected envelope presentations.
- Tests should prove direct `providerStatusProvider` and ordered
  `providerStatusSources` preserve the exact visible copy from source to root to
  `ChatStore`.
- Tests should prove hidden and missing rendered ids return nil.
- Tests should prove first-wins when the envelope source appears before a
  fallback source and fallback wins only when the envelope source misses.
- Do not add a default A166 source to production `AppBootstrap`.
- Do not compose A166 with the full Search API status stack yet; that is a
  later cross-stage gate.

Acceptance:
- Prepared envelope status copy is identical source -> AppBootstrap -> ChatStore.
- Rejected envelope status copy is identical source -> AppBootstrap -> ChatStore.
- Hidden/missing ids stay nil.
- Ordered source arrays preserve first-wins and fallback behavior.
- Visible copy still includes `isRuntimeCallable false` and `isExecutable false`.
- A167 does not change production AppBootstrap defaults, ChatStore behavior,
  SwiftUI/UI, navigation, telemetry, memory writes, transcript mutation,
  URLSession/networking, crawler/MCP client, Google/Gaode SDK, StoreKit/payment,
  booking/order, remote model runtime, or real provider behavior.

Verification:
- Run the new focused AppBootstrap handoff tests.
- Run full `test_sim`.
- Run forbidden-fragment scan for touched Swift diffs, touched-file
  trailing-whitespace scan, A166/A167 doc consistency scan, and
  `git diff --check`.
```

Status after implementation: A167 added focused AppBootstrap tests proving the
A166 envelope status source can be injected through `providerStatusSources`,
passed directly through `providerStatusProvider`, and read by `ChatStore` for
rendered recommendation ids. Prepared and rejected envelope presentations remain
byte-for-byte equal source -> root -> store, hidden/missing ids stay nil, and
ordered arrays preserve first-wins plus fallback behavior. No production
AppBootstrap default, ChatStore production behavior, SwiftUI/UI, navigation,
networking, crawler/MCP client, Google/Gaode SDK, StoreKit/payment,
booking/order, remote model runtime, hidden app-control, provider call, or real
provider behavior was added.

## Round A168 - Search API Live Provider Invocation Envelope Status Stack Composition

```text
Task: Prove the A166 Search API live-provider invocation envelope status source
composes with the existing Search API status stack through
`AppBootstrap(providerStatusSources:)` and `ChatStore` rendered-id lookup. This
round is focused AppBootstrap tests plus docs sync. Do not add production
AppBootstrap defaults, ChatStore production behavior, SwiftUI/UI, navigation,
URLSession, URLRequest, endpoint URLs, API keys, OAuth tokens, bearer tokens,
credentials, SDK/client handles, live provider calls, telemetry, transcript
mutation, StoreKit/payment, memory writes, raw query/page/provider payload
ingestion, crawler runtime, MCP client runtime, Google/Gaode SDKs,
booking/payment/order flow, remote model runtime, hidden third-party app
control, or real provider execution.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Read first:
- kAir/Core/Networking/ServerProviderSearchAPILiveProviderInvocationEnvelopeStatusSourceProducer.swift
- kAir/Core/Networking/ServerProviderSearchAPILiveProviderInvocationPreflightStatusSourceProducer.swift
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md

Implementation shape:
- Add one focused AppBootstrap cross-stage composition test, following the A163
  source-stack pattern and inserting the A166 envelope status source as the new
  top candidate.
- Build ready/blocked rendered recommendations plus hidden/missing ids for each
  source.
- Include these sources in the ordered matrix: envelope, invocation preflight,
  adapter interface, live vendor selection, readiness, metered entitlement,
  vendor policy, dispatch authorization, lease, request, response, transport
  preflight, audit, and fallback.
- For each selected source first in the array, assert root/store presentations
  exactly equal that source's expected ready/blocked copy.
- Assert hidden/missing ids stay nil for every source and through ChatStore.
- Assert each selected source's marker appears while later-source markers and
  hidden markers do not leak.
- Keep `isRuntimeCallable false` and `isExecutable false` visible for envelope
  status copy.
- Do not add a default A166 source to production `AppBootstrap`.
- Do not add real provider execution or production runtime composition.

Acceptance:
- Envelope status wins when it appears before all existing Search API status
  sources.
- Every existing Search API status source still wins when placed first.
- Fallback wins only when placed first or when earlier sources miss.
- Source -> AppBootstrap -> ChatStore copy remains identical for ready/blocked
  rendered recommendations.
- Hidden/missing ids stay nil and cross-source leak markers stay absent.
- A168 does not change production AppBootstrap defaults, ChatStore behavior,
  SwiftUI/UI, navigation, telemetry, memory writes, transcript mutation,
  URLSession/networking, crawler/MCP client, Google/Gaode SDK, StoreKit/payment,
  booking/order, remote model runtime, or real provider behavior.

Verification:
- Run the new focused AppBootstrap stack-composition test.
- Run full `test_sim`.
- Run forbidden-fragment scan for touched Swift diffs, touched-file
  trailing-whitespace scan, A167/A168 doc consistency scan, and
  `git diff --check`.
```

Status after implementation: A168 added one focused AppBootstrap stack-
composition test proving the A166 envelope status source composes with the
existing Search API status stack through `providerStatusSources` and `ChatStore`
rendered-id lookup. Envelope, invocation preflight, adapter interface, live
vendor selection, readiness, metered entitlement, vendor policy, dispatch
authorization, lease, request, response, transport preflight, audit, and
fallback each preserve first-wins, hidden/missing nil, source -> root -> store
copy equality, no cross-source leakage, and fallback-after-miss behavior. No
production AppBootstrap default, ChatStore production behavior, SwiftUI/UI,
navigation, networking, crawler/MCP client, Google/Gaode SDK, StoreKit/payment,
booking/order, remote model runtime, hidden app-control, provider call, or real
provider behavior was added.

## Round A169 - Search API Provider Status Stack Ordering Plan

```text
Task: Add a pure Search API provider-status stack ordering/plan contract for
future composition-root wiring. This round should freeze the ordered stage
sequence proved by A168 without instantiating production status sources by
default. Do not add production AppBootstrap defaults, ChatStore production
behavior, SwiftUI/UI, navigation, URLSession, URLRequest, endpoint URLs, API
keys, OAuth tokens, bearer tokens, credentials, SDK/client handles, live
provider calls, telemetry, transcript mutation, StoreKit/payment, memory
writes, raw query/page/provider payload ingestion, crawler runtime, MCP client
runtime, Google/Gaode SDKs, booking/payment/order flow, remote model runtime,
hidden third-party app control, or real provider execution.

Allowed files:
- kAir/Core/Networking/ServerProviderSearchAPIProviderStatusStackPlan.swift
- kAirTests/Networking/ServerProviderSearchAPIProviderStatusStackPlanTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Read first:
- kAirTests/App/AppBootstrapTests.swift
- kAir/Core/Networking/ServerProviderSearchAPILiveProviderInvocationEnvelopeStatusSourceProducer.swift
- kAir/Core/Networking/ServerProviderRenderedRuntimeStatusSource.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md

Implementation shape:
- Add a pure value/comment-programming stack plan type with a stage enum and
  stable ordered stages:
  envelope, invocation preflight, adapter interface, live vendor selection,
  readiness, metered entitlement, vendor policy, dispatch authorization, lease,
  request, response, transport preflight, audit, fallback.
- Each stage should expose a stable id, rank, display/debug label, and a short
  contract note describing what it may contribute to UI-safe provider status.
- The plan should expose the default ordered stages and a lightweight validation
  result that checks uniqueness, contiguous ranks, fallback last, envelope
  first, and no duplicate ids.
- Include extension slots/notes for future cost-based provider selection and
  membership-tier routing without carrying endpoint, credential, raw query/page,
  SDK/client, crawler/MCP runtime, maps SDK, commerce, hidden app-control, or
  provider-execution material.
- Do not wire this plan into production `AppBootstrap` yet.

Acceptance:
- Tests freeze the exact stage order and ranks.
- Tests prove ids are unique, ranks are contiguous, envelope is first, fallback
  is last, and validation catches duplicate/misordered plans.
- Tests prove the plan copy is value-only and contains no endpoint URL, API
  key, OAuth token, bearer token, credential, URLSession, URLRequest,
  SDK/client handle, raw query/page/provider payload, crawler/MCP runtime,
  Google/Gaode SDK, StoreKit/payment/order/booking data, hidden app-control,
  provider call, execution, completion, or success claim.
- A169 does not change production AppBootstrap defaults, ChatStore behavior,
  SwiftUI/UI, navigation, telemetry, memory writes, transcript mutation,
  URLSession/networking, crawler/MCP client, Google/Gaode SDK, StoreKit/payment,
  booking/order, remote model runtime, or real provider behavior.

Verification:
- Run the new focused stack-plan tests.
- Run full `test_sim`.
- Run forbidden-fragment scan for touched Swift diffs, touched-file
  trailing-whitespace scan, A168/A169 doc consistency scan, and
  `git diff --check`.
```

Status after implementation: A169 added a pure
`ServerProviderSearchAPIProviderStatusStackPlan` plus focused tests. The plan
freezes the Search API provider-status order from envelope through fallback,
stage ids/ranks, display/debug labels, extension slots for future cost and
membership routing, validation state/reasons, and a value-only safe copy.
Focused tests prove exact order/ranks, extension slots, Codable determinism,
Sendable shape, duplicate/misordered rejection paths, no runtime-callable flag,
and forbidden-fragment absence. No production AppBootstrap default, ChatStore
behavior, SwiftUI/UI, navigation, networking, crawler/MCP client, Google/Gaode
SDK, StoreKit/payment, booking/order, remote model runtime, hidden app-control,
provider call, or real provider behavior was added.

## Round A170 - Search API Cost Membership Routing Plan

```text
Task: Add a pure Search API cost/membership routing plan that uses the A169
stack-plan extension slots as the next value-only contract. This round should
freeze advisory routing labels for membership tier, quota posture, region
posture, cost posture, and fallback posture without selecting or calling a real
provider. Do not add production AppBootstrap defaults, ChatStore production
behavior, SwiftUI/UI, navigation, URLSession, URLRequest, endpoint URLs, API
keys, OAuth tokens, bearer tokens, credentials, SDK/client handles, live
provider calls, telemetry, transcript mutation, StoreKit/payment, memory
writes, raw query/page/provider payload ingestion, crawler runtime, MCP client
runtime, Google/Gaode SDKs, booking/payment/order flow, remote model runtime,
hidden third-party app control, or real provider execution.

Allowed files:
- kAir/Core/Networking/ServerProviderSearchAPICostMembershipRoutingPlan.swift
- kAirTests/Networking/ServerProviderSearchAPICostMembershipRoutingPlanTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Read first:
- kAir/Core/Networking/ServerProviderSearchAPIProviderStatusStackPlan.swift
- kAirTests/Networking/ServerProviderSearchAPIProviderStatusStackPlanTests.swift
- kAir/Core/Networking/ServerProviderMeteredEntitlementLedger.swift
- kAir/Core/Networking/ServerProviderSearchAPIVendorPolicy.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md

Implementation shape:
- Add a pure value/comment-programming cost/membership routing plan type with
  stable advisory routes such as local fallback, included-quota preferred,
  metered allowed, region review, and cost blocked.
- Each route should expose a stable id, rank, membership tier posture, quota
  posture, cost posture, region posture, UI-safe label, and reviewer note.
- The plan should expose default ordered routes and a validation result that
  checks unique ids, unique ranks, contiguous ranks, fallback-first or
  fallback-last semantics as chosen in the implementation note, required
  membership coverage, and no duplicate route kinds.
- Include extension notes for later server-owned vendor selection and
  membership package mapping, but keep all output advisory/value-only.
- Do not wire this plan into production `AppBootstrap`, `ChatStore`, or any
  runtime status source yet.

Acceptance:
- Tests freeze exact route order, ranks, ids, tier/quota/cost/region labels, and
  validation reasons.
- Tests prove validation catches duplicate ids, duplicate ranks, missing
  membership coverage, misplaced fallback, and unsupported route kinds.
- Tests prove safe copy is value-only, not runtime-callable, Codable,
  deterministic, and contains no endpoint URL, API key, OAuth token, bearer
  token, credential, URLSession, URLRequest, SDK/client handle, raw
  query/page/provider payload, crawler/MCP runtime, Google/Gaode SDK,
  StoreKit/payment/order/booking data, hidden app-control, provider call,
  execution, completion, or success claim.
- A170 does not change production AppBootstrap defaults, ChatStore behavior,
  SwiftUI/UI, navigation, telemetry, memory writes, transcript mutation,
  URLSession/networking, crawler/MCP client, Google/Gaode SDK, StoreKit/payment,
  booking/order, remote model runtime, or real provider behavior.

Verification:
- Run the new focused cost/membership routing-plan tests.
- Run full `test_sim`.
- Run forbidden-fragment scan for touched Swift diffs, touched-file
  trailing-whitespace scan, A169/A170 doc consistency scan, and
  `git diff --check`.
```

Status after implementation: A170 added a pure
`ServerProviderSearchAPICostMembershipRoutingPlan` plus focused tests. The plan
freezes local fallback, included-quota preferred, metered allowed, region
review, and cost-blocked advisory route ordering; route ids/ranks;
minimum/eligible membership posture; quota/cost/region posture; UI labels;
extension notes; A169 stack extension slots; validation state/reasons; and a
value-only safe copy. Focused tests prove exact route order, labels, postures,
membership coverage, extension slots, Codable determinism, Sendable shape,
duplicate/misordered/missing/unsupported rejection paths, no runtime-callable
flag, and forbidden-fragment absence. No production AppBootstrap default,
ChatStore behavior, SwiftUI/UI, navigation, networking, crawler/MCP client,
Google/Gaode SDK, StoreKit/payment, booking/order, remote model runtime, hidden
app-control, provider call, or real provider behavior was added.

## Round A171 - Search API Cost Membership Routing Decision

```text
Task: Add a pure Search API cost/membership routing decision that consumes the
A170 routing plan plus safe metadata and selects an advisory route label. This
round should turn membership tier, requested cost class, quota snapshot, region,
and privacy posture into a value-only decision for UI-safe provider status. Do
not add production AppBootstrap defaults, ChatStore production behavior,
SwiftUI/UI, navigation, URLSession, URLRequest, endpoint URLs, API keys, OAuth
tokens, bearer tokens, credentials, SDK/client handles, live provider calls,
telemetry, transcript mutation, StoreKit/payment, memory writes, raw
query/page/provider payload ingestion, crawler runtime, MCP client runtime,
Google/Gaode SDKs, booking/payment/order flow, remote model runtime, hidden
third-party app control, concrete vendor selection, or real provider execution.

Allowed files:
- kAir/Core/Networking/ServerProviderSearchAPICostMembershipRoutingDecision.swift
- kAirTests/Networking/ServerProviderSearchAPICostMembershipRoutingDecisionTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Read first:
- kAir/Core/Networking/ServerProviderSearchAPICostMembershipRoutingPlan.swift
- kAirTests/Networking/ServerProviderSearchAPICostMembershipRoutingPlanTests.swift
- kAir/Core/Providers/ProviderRoutingPolicy.swift
- kAir/Core/Networking/ServerProviderEnvelopeFactory.swift
- kAir/Core/Networking/ServerProviderMeteredEntitlementLedger.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md

Implementation shape:
- Add a pure value-only routing decision input containing membership tier,
  requested cost class, region, privacy class, quota snapshot, and optional
  preferred route kind. Do not include vendor ids beyond existing safe policy
  ids, request text, page bodies, or runtime handles.
- Add a decision state and rejection reason enum. The decision should select one
  A170 route kind from the plan when metadata is sufficient, or reject with a
  stable reason when the plan is invalid, membership coverage is missing, privacy
  blocks remote posture, quota is unavailable, cost class is blocked, region
  review is required, or the preferred route is not allowed.
- Preserve local fallback as the first safe advisory route. Included quota should
  require positive quota and eligible membership; metered posture should require
  metered eligibility and eligible membership; region review should remain a
  review label, not a vendor choice.
- Add a safe copy that exposes only ids, route kind, route rank, membership tier,
  cost class, region, decision state/reasons, and runtime-callable false.
- Do not wire this decision into production `AppBootstrap`, `ChatStore`, or any
  runtime status source yet.

Acceptance:
- Tests freeze decision outcomes for local fallback, included-quota preferred,
  metered allowed, region review, cost blocked, privacy blocked, invalid plan,
  missing quota, missing membership coverage, and preferred-route mismatch.
- Tests prove the decision is deterministic, Codable, Sendable, and preserves
  stable rejection reasons.
- Tests prove safe copy is value-only, not runtime-callable, and contains no
  endpoint URL, API key, OAuth token, bearer token, credential, URLSession,
  URLRequest, SDK/client handle, raw query/page/provider payload, crawler/MCP
  runtime, Google/Gaode SDK, StoreKit/payment/order/booking data, hidden
  app-control, provider call, execution, completion, or success claim.
- A171 does not change production AppBootstrap defaults, ChatStore behavior,
  SwiftUI/UI, navigation, telemetry, memory writes, transcript mutation,
  URLSession/networking, crawler/MCP client, Google/Gaode SDK, StoreKit/payment,
  booking/order, remote model runtime, concrete vendor selection, or real
  provider behavior.

Verification:
- Run the new focused cost/membership routing-decision tests.
- Run full `test_sim`.
- Run forbidden-fragment scan for touched Swift diffs, touched-file
  trailing-whitespace scan, A170/A171 doc consistency scan, and
  `git diff --check`.
```

Status after implementation: A171 added a pure
`ServerProviderSearchAPICostMembershipRoutingDecision` plus focused tests. The
decision consumes the A170 routing plan plus safe membership, requested cost
class, region, privacy, quota snapshot, and optional preferred route metadata,
then returns an advisory route label and stable rejection reason. Focused tests
freeze local fallback, included-quota preferred, metered allowed, region review,
cost blocked, privacy blocked, invalid plan, missing quota, missing membership
coverage, preferred-route mismatch, membership-tier-not-eligible, and blocked
terms outcomes. Safe copy is deterministic, Codable, Sendable, value-only, and
not runtime-callable. No production AppBootstrap default, ChatStore behavior,
SwiftUI/UI, navigation, networking, crawler/MCP client, Google/Gaode SDK,
StoreKit/payment, booking/order, remote model runtime, hidden app-control,
concrete vendor selection, provider call, or real provider behavior was added.

## Round A172 - Search API Cost Membership Routing Decision Status Source

```text
Task: Add a pure Search API cost/membership routing-decision status source
producer that packages A171 decisions into rendered-id scoped provider status
copy. This round should expose UI-safe status for accepted advisory routes and
rejected review/block outcomes without wiring the source into production roots.
Do not add production AppBootstrap defaults, ChatStore production behavior,
SwiftUI/UI, navigation, URLSession, URLRequest, endpoint URLs, API keys, OAuth
tokens, bearer tokens, credentials, SDK/client handles, live provider calls,
telemetry, transcript mutation, StoreKit/payment, memory writes, raw
query/page/provider payload ingestion, crawler runtime, MCP client runtime,
Google/Gaode SDKs, booking/payment/order flow, remote model runtime, hidden
third-party app control, concrete vendor selection, or real provider execution.

Allowed files:
- kAir/Core/Networking/ServerProviderSearchAPICostMembershipRoutingDecisionStatusSourceProducer.swift
- kAirTests/Networking/ServerProviderSearchAPICostMembershipRoutingDecisionStatusSourceProducerTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Read first:
- kAir/Core/Networking/ServerProviderSearchAPICostMembershipRoutingDecision.swift
- kAirTests/Networking/ServerProviderSearchAPICostMembershipRoutingDecisionTests.swift
- kAir/Core/Networking/ServerProviderRenderedRuntimeStatusSource.swift
- kAir/Core/Networking/ServerProviderSearchAPILiveProviderInvocationEnvelopeStatusSourceProducer.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md

Implementation shape:
- Add a value-only status source producer whose inputs bind rendered
  recommendation ids to A171 routing decisions.
- For accepted decisions, package the selected advisory route as UI-safe
  provider status. For rejected decisions, package a disabled/review status that
  includes the stable rejection reason and selected advisory route when present.
- Preserve duplicate first-wins, rendered-id scoping, hidden/missing nil, and
  not-runtime-callable copy.
- The status copy must not claim vendor selection, provider runtime readiness,
  user-visible action success, or any concrete transport result.
- Do not add this source to production `AppBootstrap` yet.

Acceptance:
- Tests prove accepted local fallback, included-quota, and metered decisions
  package stable advisory status.
- Tests prove region review, cost blocked, privacy blocked, invalid plan,
  missing quota, missing membership coverage, and preferred-route mismatch
  package disabled/review status with stable reasons.
- Tests prove duplicate recommendation ids keep first input, hidden/missing ids
  return nil, encoded/debug status copy is value-only, and all status copy stays
  not runtime-callable.
- A172 does not change production AppBootstrap defaults, ChatStore behavior,
  SwiftUI/UI, navigation, telemetry, memory writes, transcript mutation,
  URLSession/networking, crawler/MCP client, Google/Gaode SDK, StoreKit/payment,
  booking/order, remote model runtime, concrete vendor selection, or real
  provider behavior.

Verification:
- Run the new focused routing-decision status-source tests.
- Run full `test_sim`.
- Run forbidden-fragment scan for touched Swift diffs, touched-file
  trailing-whitespace scan, A171/A172 doc consistency scan, and
  `git diff --check`.
```

## Round A173 - Cost Membership Routing Status App-Root Handoff

```text
Task: Prove the pure A172 Search API cost/membership routing-decision status
source can pass through `AppBootstrap(providerStatusSources:)` and `ChatStore`
rendered-id lookup. This round is a test-only handoff proof; do not install the
source as a production default and do not compose it into the app-root provider
status stack yet.

Do not add production AppBootstrap defaults, ChatStore production behavior,
SwiftUI/UI, navigation, URLSession, URLRequest, endpoint URLs, API keys, OAuth
tokens, bearer tokens, credentials, SDK/client handles, live provider calls,
telemetry, transcript mutation, StoreKit/payment, memory writes, raw
query/page/provider payload ingestion, crawler runtime, MCP client runtime,
Google/Gaode SDKs, booking/payment/order flow, remote model runtime, hidden
third-party app control, concrete vendor selection, or real provider execution.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Read first:
- kAir/Core/Networking/ServerProviderSearchAPICostMembershipRoutingDecisionStatusSourceProducer.swift
- kAirTests/Networking/ServerProviderSearchAPICostMembershipRoutingDecisionStatusSourceProducerTests.swift
- kAir/App/AppEntry/AppBootstrap.swift
- kAir/Features/Chat/Data/ChatStore.swift
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md

Implementation shape:
- Add focused AppBootstrap tests that build A172 producer sources from accepted
  and rejected routing decisions, then pass them through explicit
  `providerStatusSources`.
- Prove the source -> app root -> ChatStore presentation copy is identical for
  accepted advisory and rejected review/block decisions.
- Prove hidden/missing ids stay nil, duplicate recommendation ids keep first
  input, earlier source wins over fallback, and fallback still appears after a
  miss.
- Keep every assertion value-only and not-runtime-callable; do not mutate
  default app bootstrap provider sources.

Acceptance:
- Accepted local/included/metered routing status can be read through ChatStore
  when explicitly supplied to AppBootstrap.
- Rejected region-review/cost/privacy/invalid/quota/coverage/preferred mismatch
  status can be read through ChatStore with stable reason copy.
- Hidden/missing ids return nil, source order remains first-wins, and fallback
  source copy does not leak when A172 has a match.
- A173 does not change production AppBootstrap defaults, ChatStore behavior,
  SwiftUI/UI, navigation, telemetry, memory writes, transcript mutation,
  URLSession/networking, crawler/MCP client, Google/Gaode SDK, StoreKit/payment,
  booking/order, remote model runtime, concrete vendor selection, or real
  provider behavior.

Verification:
- Run the focused AppBootstrap A173 tests.
- Run full `test_sim`.
- Run forbidden-fragment scan for touched Swift diffs, touched-file
  trailing-whitespace scan, A172/A173 doc consistency scan, and
  `git diff --check`.
```

## Round A174 - Cost Membership Routing Status Stack Composition

```text
Task: Compose the pure A172 Search API cost/membership routing-decision status
source with the existing Search API provider-status stack through
`AppBootstrap(providerStatusSources:)` and `ChatStore` lookup. This round is a
test-only composition proof; do not install the source as a production default.

Do not add production AppBootstrap defaults, ChatStore production behavior,
SwiftUI/UI, navigation, URLSession, URLRequest, endpoint URLs, API keys, OAuth
tokens, bearer tokens, credentials, SDK/client handles, live provider calls,
telemetry, transcript mutation, StoreKit/payment, memory writes, raw
query/page/provider payload ingestion, crawler runtime, MCP client runtime,
Google/Gaode SDKs, booking/payment/order flow, remote model runtime, hidden
third-party app control, concrete vendor selection, or real provider execution.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Read first:
- kAir/Core/Networking/ServerProviderSearchAPICostMembershipRoutingDecisionStatusSourceProducer.swift
- kAir/Core/Networking/ServerProviderSearchAPIProviderStatusStackPlan.swift
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md

Implementation shape:
- Add focused AppBootstrap composition tests that place the A172 routing source
  alongside the existing Search API status stack sources.
- Prove A172 can be selected first without leaking later source markers.
- Prove each existing Search API stack source can still be selected first
  without leaking A172 routing markers.
- Prove hidden/missing ids stay nil and fallback-after-miss still works.
- Keep the proof value-only and not-runtime-callable; do not mutate default app
  bootstrap provider sources.

Acceptance:
- A172 routing status composes first-wins with envelope, invocation preflight,
  adapter interface, live vendor selection, readiness, metered entitlement,
  vendor policy, dispatch authorization, lease, request, response, transport
  preflight, audit, and fallback sources.
- Root/store copy remains identical to the selected source for ready and
  blocked/review examples.
- Later source markers and hidden routing markers never leak into selected copy.
- A174 does not change production AppBootstrap defaults, ChatStore behavior,
  SwiftUI/UI, navigation, telemetry, memory writes, transcript mutation,
  URLSession/networking, crawler/MCP client, Google/Gaode SDK, StoreKit/payment,
  booking/order, remote model runtime, concrete vendor selection, or real
  provider behavior.

Verification:
- Run the focused AppBootstrap A174 tests.
- Run full `test_sim`.
- Run forbidden-fragment scan for touched Swift diffs, touched-file
  trailing-whitespace scan, A173/A174 doc consistency scan, and
  `git diff --check`.
```

Status after implementation: A174 composed the A172 routing-decision status
source with the existing Search API provider-status stack through
`AppBootstrap(providerStatusSources:)` and ChatStore lookup. Routing-first,
existing-stack-first, and fallback-first orders preserve first-wins copy for
ready and blocked/review examples. Hidden/missing ids stay nil,
fallback-after-miss is explicit with the full stack ordered before fallback, and
later source markers never leak into selected copy. No production AppBootstrap
default, ChatStore behavior, UI, networking, telemetry, memory, transcript,
StoreKit/payment, booking/order, crawler/MCP, maps SDK, remote model runtime,
concrete vendor selection, or real provider behavior was added.

## Round A175 - Research / Market / Provider Cut-Plan Refresh After Routing Status Stack

```text
Task: Perform a docs-only research, market, paper, open-source, and provider
cut-plan refresh after A174. Treat prior agent reports as untrusted claims.
Read the current kAir architecture and research docs first, then browse current
primary sources and high-signal papers/projects before selecting the next
narrow Search API/provider gate. Do not force live provider runtime unless the
evidence proves all privacy, attribution, quota, cost, audit, and UI-safe status
preconditions are already covered.

Hard non-goals:
- Do not edit Swift, tests, Xcode project metadata, app settings, entitlements,
  networking code, provider adapters, production AppBootstrap defaults,
  ChatStore behavior, SwiftUI/UI layout, telemetry, transcript writes,
  StoreKit/payment, booking/order flows, memory writes, credentials, endpoint
  URLs, API keys, OAuth tokens, SDK/client handles, crawler runtime, MCP client
  runtime, Google/Gaode SDKs, remote model runtime, or real provider execution.
- Do not infer the latest market or paper state from memory. Browse and cite
  sources for current claims.

Allowed files:
- Docs/research/2026-agent-market-ui-provider-research.md
- Docs/research/2026-agent-architecture-deep-dive-v1.md
- Docs/research/2026-ui-market-deep-dive-v1.md
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Read first:
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md
- Docs/research/2026-agent-market-ui-provider-research.md
- Docs/research/2026-agent-architecture-deep-dive-v1.md
- Docs/research/2026-ui-market-deep-dive-v1.md
- kAirTests/App/AppBootstrapTests.swift

Research scope:
- Current consumer and developer agent products: status disclosure, source
  attribution, model/provider choice, task execution UI, fallback, pricing, and
  trust/permission patterns.
- Current agent papers and benchmarks: planning, tool use, memory, RAG/search
  attribution, browser/web agents, evaluation, safety, cost/latency routing, and
  human handoff. Include only findings that change a concrete kAir decision.
- Current open-source agent architectures: graph planners, tool routers,
  MCP-style tool surfaces, browser/search agents, eval harnesses, and UI status
  contracts that can fit kAir's local-first/chat-first constraints.
- Current provider policy and economics: Search API, maps/local-life providers,
  quota, rate limits, source/citation requirements, privacy/data residency,
  cost units, and terms that affect provider-status copy.

Required output:
- Update research docs with cited findings and a decision matrix:
  adopt now / monitor / reject, with reason and kAir contract impact.
- Explicitly answer: "Can A176 start live provider/runtime work?" with yes/no.
- If no, name exactly one next value-only gate and why it is safer than runtime.
  Candidate families include cross-stage routing-status composition with
  payload-dispatch / vendor-policy / authorization / lease sources, or the next
  provider-specific interface/status contract.
- Update architecture docs with A175 done and a paste-ready A176 implementation
  frame: allowed files, non-goals, acceptance checks, and verification gates.

Acceptance:
- Sources are current and cited, separating primary evidence from product
  judgment.
- The next gate references market UX, papers/open-source architecture, provider
  policy, privacy, attribution, quota/entitlement, cost, audit/evaluation, and
  UI-safe status.
- Docs preserve hidden/missing nil, first-wins source order, rendered-id scope,
  value-only copy, `isRuntimeCallable false`, and no stale provider/runtime
  leakage as active constraints.
- No Swift, Xcode project, runtime, credential, endpoint, provider adapter,
  production behavior, UI, StoreKit, payment, booking, transcript, telemetry, or
  memory-code files change.

Verification:
- Run doc consistency scans for A174/A175/A176 naming.
- Run forbidden-scope scans for runtime/API-key/endpoint/SDK creep in changed
  docs.
- Run touched-file trailing-whitespace scan and `git diff --check`.
- Run `git status --short` and confirm only allowed docs changed in this gate.
```

Status after implementation: A175 refreshed the current agent-framework,
agent-cost, MCP/security, UI/market, Search API, maps/local-life, crawler, and
Apple local-first evidence. Decision: A176 must not start live provider/runtime
work. A174 proves source-order composition, but it does not prove semantic
compatibility between cost/membership routing and downstream metered
entitlement, vendor policy, payload dispatch, dispatch authorization, transport
lease, and fallback state. The next safe gate is a focused AppBootstrap
test-only policy-compatibility proof.

## Round A176 - Search API Cost/Membership Routing Cross-Stage Policy Compatibility Proof

```text
Task: Implement A176 as a test-only/value-only Search API cost/membership
routing cross-stage policy compatibility proof. Treat prior agent reports as
untrusted. Read the listed files first, then add focused AppBootstrap tests
showing that A172 routing-decision status composes semantically with downstream
metered entitlement, vendor policy, payload dispatch, dispatch authorization,
transport lease, and fallback status sources. Do not add live provider/runtime
work.

Hard non-goals:
- Do not edit production Swift files, Xcode project metadata, app settings,
  entitlements, production AppBootstrap defaults, ChatStore behavior,
  SwiftUI/UI layout, navigation, telemetry, transcript writes, StoreKit/payment,
  booking/order flows, memory writes, credentials, endpoint URLs, API keys,
  OAuth tokens, SDK/client handles, URLSession/networking, provider adapters,
  crawler runtime, MCP client runtime, Google/Gaode SDKs, remote model runtime,
  concrete vendor selection, or real provider execution.
- Do not change source-order semantics to make a test pass. Preserve
  hidden/missing nil, first-wins source order, rendered-id scope, value-only
  copy, `isRuntimeCallable false`, and no stale lower-priority marker leakage.

Allowed files:
- kAirTests/App/AppBootstrapTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Read first:
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md
- Docs/research/2026-agent-market-ui-provider-research.md
- Docs/research/2026-agent-architecture-deep-dive-v1.md
- Docs/research/2026-ui-market-deep-dive-v1.md
- kAir/Core/Networking/ServerProviderSearchAPICostMembershipRoutingDecisionStatusSourceProducer.swift
- kAir/Core/Networking/ServerProviderSearchAPICostMembershipRoutingPlan.swift
- kAir/Core/Networking/ServerProviderSearchAPICostMembershipRoutingDecision.swift
- kAir/Core/Networking/ServerProviderMeteredEntitlementStatusSourceProducer.swift
- kAir/Core/Networking/ServerProviderSearchAPIVendorPolicyStatusSourceProducer.swift
- kAir/Core/Networking/ServerProviderSearchAPIAdapterPayloadDispatchStatusSourceProducer.swift
- kAir/Core/Networking/ServerProviderSearchAPIVendorPolicyDispatchAuthorizationStatusSourceProducer.swift
- kAir/Core/Networking/ServerProviderSearchAPITransportLeaseStatusSourceProducer.swift
- kAirTests/App/AppBootstrapTests.swift

Implementation frame:
- Add one focused A176 AppBootstrap test or a small focused test group in
  `kAirTests/App/AppBootstrapTests.swift`.
- Build representative status sources for:
  - A172 cost/membership routing decision status.
  - Metered entitlement status.
  - Search API vendor policy status.
  - Adapter payload dispatch status.
  - Vendor-policy dispatch authorization status.
  - Transport lease status.
  - Fallback status.
- Use rendered ids that prove both matching and missing cases. Keep helper
  names local to the test file and consistent with existing AppBootstrap test
  style.

Required proof cases:
- Included-quota route plus compatible downstream entitlement/vendor/dispatch/
  authorization/lease status can be selected first without stale marker
  mixing.
- Metered route plus overquota or blocked downstream source preserves
  first-wins order but never implies provider runtime, callability, execution,
  or completion.
- Privacy/cost/region rejected routing status does not leak later vendor,
  payload, authorization, lease, request, response, transport, audit, or
  fallback markers.
- Downstream-first order still does not leak routing route, cost, quota,
  membership, or entitlement markers.
- Hidden/missing rendered ids stay nil.
- Fallback-after-miss remains explicit when the full ordered stack misses
  before fallback.
- Root/store selected-copy equality is preserved for at least one accepted
  route and one blocked/review route.

Acceptance:
- A176 is test-only plus doc status sync. Production behavior is unchanged.
- Selected status copy is byte/field-identical from source -> app root -> store.
- Later source markers never leak into the selected copy.
- Rejected privacy/cost/region routing copy remains blocked or review-only and
  does not expose downstream vendor/lease detail.
- Downstream-selected copy remains downstream-selected and does not acquire
  A172 cost/membership routing detail.
- All selected copies remain value-only with `isRuntimeCallable false`.
- No endpoint URL, API key, OAuth token, SDK/client handle, URLSession,
  URLRequest, provider adapter, crawler/MCP client, maps SDK, StoreKit/payment,
  booking/order, remote model runtime, concrete vendor selection, provider
  call, execution claim, completion claim, telemetry mutation, transcript
  write, or memory-code change appears in the diff.

Verification:
- Run the focused AppBootstrap A176 test.
- Run full `test_sim`.
- Run forbidden-fragment scan for touched Swift diffs.
- Run touched-file trailing-whitespace scan.
- Run A175/A176 doc consistency scan.
- Run `git diff --check`.
- Run `git status --short` and confirm A176 touched only the allowed test and
  architecture docs.
```

Status after implementation: A176 added a focused AppBootstrap policy
compatibility proof for Search API cost/membership routing. The test composes
A172 routing status with metered entitlement, vendor policy, payload dispatch,
dispatch authorization, transport lease, and fallback sources. Routing-first,
downstream-first, hidden/missing, and fallback-after-miss cases preserve
selected source -> root -> store copy equality; later markers do not leak; and
selected copies remain value-only with `isRuntimeCallable false`. A176 did not
add production Swift, provider runtime, network transport, endpoints,
credentials, SDK/client handles, UI, StoreKit/payment, booking/order, crawler
runtime, MCP runtime, Google/Gaode SDKs, concrete vendor selection, or real
provider execution.

## Round A177 - Search API Route-Policy Compatibility Contract

```text
Task: Implement A177 as a pure value/comment-programming Search API
route-policy compatibility contract. Treat prior agent reports as untrusted.
Read the listed files first. A176 proved selected status copy does not leak
across AppBootstrap/ChatStore source order; A177 should freeze the semantic
compatibility rule itself: a cost/membership route can only become
"runtime-eligible metadata" when routing, metered entitlement, vendor policy,
payload dispatch, dispatch authorization, and transport lease metadata all
agree. The result must still be non-executable and not runtime-callable.

Hard non-goals:
- Do not add provider runtime, URLSession/networking, endpoint URLs, API keys,
  OAuth tokens, bearer tokens, credentials, SDK/client handles, provider
  adapters, production AppBootstrap defaults, ChatStore behavior, SwiftUI/UI,
  navigation, telemetry, transcript writes, memory writes, StoreKit/payment,
  booking/order flows, crawler runtime, MCP client runtime, Google/Gaode SDKs,
  remote model runtime, concrete vendor selection, provider calls, execution
  claims, or completion claims.
- Do not log or store raw query text, raw page/provider payloads, source bodies,
  private Health/location data, prompt text, credentials, endpoint URLs,
  crawler payloads, MCP descriptors, maps SDK details, payment/order data, or
  hidden app-control state.

Allowed files:
- kAir/Core/Networking/ServerProviderSearchAPIRoutePolicyCompatibility.swift
- kAirTests/Networking/ServerProviderSearchAPIRoutePolicyCompatibilityTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Read first:
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md
- kAir/Core/Networking/ServerProviderSearchAPICostMembershipRoutingDecision.swift
- kAir/Core/Networking/ServerProviderSearchAPICostMembershipRoutingDecisionStatusSourceProducer.swift
- kAir/Core/Networking/ServerProviderMeteredEntitlementLedger.swift
- kAir/Core/Networking/ServerProviderSearchAPIVendorPolicy.swift
- kAir/Core/Networking/ServerProviderSearchAPIAdapterPayloadDispatchGate.swift
- kAir/Core/Networking/ServerProviderSearchAPIVendorPolicyDispatchAuthorization.swift
- kAir/Core/Networking/ServerProviderSearchAPITransportLease.swift
- kAirTests/App/AppBootstrapTests.swift

Implementation frame:
- Add `ServerProviderSearchAPIRoutePolicyCompatibilityInput` with safe metadata
  only: compatibility id, rendered recommendation id, routing decision safe
  copy or decision id, metered decision, vendor policy decision, payload
  dispatch receipt, dispatch authorization, transport lease, selected
  status-source id/rank, membership tier, provider family, vendor id, cost
  class, route kind, quota posture, source/citation posture, and audit/debug
  ids. Keep raw payloads and secrets out.
- Add `ServerProviderSearchAPIRoutePolicyCompatibilityDecision` with states
  `compatible` / `rejected`, deterministic rejection reasons, a status-safe
  copy, `isRuntimeCallable false`, `isExecutable false`, and safe status/debug
  text.
- Rejection reasons should cover routing rejected, missing selected route,
  local-fallback route, metered entitlement rejected, vendor policy rejected,
  payload dispatch blocked, dispatch authorization rejected, lease rejected,
  provider-family mismatch, vendor mismatch, cost-class mismatch,
  membership-tier mismatch, route-kind/cost-posture mismatch, quota posture
  mismatch, source/citation posture mismatch, lease id mismatch, missing audit
  id, unsafe visibility/status-source metadata, and stale or hidden source
  markers.

Acceptance:
- Tests prove compatible included-quota metadata only when routing,
  entitlement, vendor policy, payload dispatch, authorization, and lease all
  agree on provider family, vendor, capability, cost class, membership, source,
  citation, and lease/budget ids.
- Tests prove compatible metered metadata only when metered entitlement and
  lease both agree with the metered route and no overquota/cost-blocked state
  exists.
- Tests reject privacy/cost/region blocked routing even if downstream metadata
  is otherwise accepted.
- Tests reject downstream blocked states even if routing is accepted.
- Tests reject vendor/cost/membership/source/citation/lease mismatches with
  deterministic reasons.
- Tests prove encoded/debug/status-safe copy contains no endpoint URL, API key,
  OAuth token, bearer token, credential, URLSession, URLRequest, SDK/client
  handle, raw query, raw page/provider payload, crawler/MCP runtime detail,
  maps SDK detail, StoreKit/payment/order/booking data, hidden app-control,
  provider call, execution claim, or completion claim.
- A177 does not change production AppBootstrap defaults, ChatStore behavior,
  UI, telemetry, transcript, memory-code, provider adapter, networking,
  crawler/MCP, maps SDK, payment, booking/order, remote model runtime, concrete
  vendor selection, or real provider behavior.

Verification:
- Run focused A177 networking tests.
- Run full `test_sim`.
- Run forbidden-fragment scan for touched Swift diffs.
- Run touched-file trailing-whitespace scan.
- Run A176/A177 doc consistency scan.
- Run `git diff --check`.
- Run `git status --short` and confirm A177 touched only the allowed contract,
  test, and architecture docs.
```

Status after implementation: A177 added
`ServerProviderSearchAPIRoutePolicyCompatibility` as a pure value contract plus
focused networking tests. The decision binds A172 routing safe copy, metered
entitlement, vendor policy, payload dispatch, dispatch authorization, transport
lease, selected status-source metadata, membership/provider/vendor/cost/route
posture, source/citation posture, lease id, and audit id into a compatible or
rejected non-executable safe copy. Tests cover included-quota compatibility,
metered compatibility, routing/downstream blocked states, vendor/cost/
membership/source/citation/lease/status-source mismatches, encoded/debug/status
leak checks, `isRuntimeCallable false`, and `isExecutable false`. No provider
runtime, networking, endpoint, credential, SDK/client handle, production
AppBootstrap default, ChatStore behavior, UI, telemetry, transcript, memory
code, crawler/MCP, maps SDK, StoreKit/payment, booking/order, concrete vendor
selection, provider call, execution claim, or completion claim was added.

## Round A178 - Search API Route-Policy Compatibility Status Source

```text
Task: Implement A178 as a pure rendered-id scoped provider-status source for
`ServerProviderSearchAPIRoutePolicyCompatibilityDecision`. Treat prior agent
reports as untrusted. Read A177 code/tests first, then package compatible and
rejected route-policy compatibility safe copies into `ProviderStatusPresentation`
without changing production AppBootstrap defaults or enabling runtime.

Hard non-goals:
- Do not add provider runtime, URLSession/networking, endpoint URLs, API keys,
  OAuth tokens, bearer tokens, credentials, SDK/client handles, provider
  adapters, production AppBootstrap defaults, ChatStore behavior, SwiftUI/UI,
  navigation, telemetry, transcript writes, memory writes, StoreKit/payment,
  booking/order flows, crawler runtime, MCP client runtime, Google/Gaode SDKs,
  remote model runtime, concrete vendor selection, provider calls, execution
  claims, or completion claims.
- Do not expose raw query text, raw page/provider payloads, source bodies,
  private Health/location data, prompt text, credentials, endpoint URLs,
  crawler payloads, MCP descriptors, maps SDK details, payment/order data, or
  hidden app-control state in status/debug/encoded copy.

Allowed files:
- kAir/Core/Networking/ServerProviderSearchAPIRoutePolicyCompatibilityStatusSourceProducer.swift
- kAirTests/Networking/ServerProviderSearchAPIRoutePolicyCompatibilityStatusSourceProducerTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Read first:
- kAir/Core/Networking/ServerProviderSearchAPIRoutePolicyCompatibility.swift
- kAirTests/Networking/ServerProviderSearchAPIRoutePolicyCompatibilityTests.swift
- kAir/Core/Networking/ServerProviderRenderedRuntimeStatusSource.swift
- kAir/Core/Networking/ServerProviderSearchAPICostMembershipRoutingDecisionStatusSourceProducer.swift
- kAir/Core/Networking/ServerProviderSearchAPILiveProviderInvocationEnvelopeStatusSourceProducer.swift
- kAir/Core/Networking/ServerProviderSearchAPITransportLeaseStatusSourceProducer.swift
- kAir/DesignSystem/Components/ProviderStatusBadgeModel.swift

Implementation frame:
- Add `ServerProviderSearchAPIRoutePolicyCompatibilityStatusSourceProducer`
  with an `Input` carrying recommendation id, status-source id/rank,
  visibility, and an A177 compatibility decision.
- Add a store that keeps duplicate recommendation ids first-wins, hides
  `isVisible == false`, and wraps the store with
  `ServerProviderRenderedRuntimeStatusSource` for rendered-id scope.
- Compatible decisions should produce a normal or warning status depending on
  included-quota vs metered posture, with badges for Search API, included quota
  or premium metered, and live/source/citation posture where appropriate.
- Rejected decisions should produce stable disabled or warning status based on
  rejection reason: privacy/source/terms/cost/unavailable should map to the
  existing badge vocabulary instead of inventing new UI.
- Status text must include route, vendor, cost, status-source id/rank,
  `isRuntimeCallable false`, `isExecutable false`, and no provider execution
  claim.

Acceptance:
- Tests package compatible included-quota and metered decisions into stable
  rendered status.
- Tests package rejected routing/downstream/mismatch decisions with stable badge
  and card-hint mappings.
- Tests prove duplicate recommendation ids keep the first visible input.
- Tests prove hidden and missing rendered ids return nil.
- Tests prove status/debug/encoded copy contains no endpoint URL, API key,
  OAuth token, bearer token, credential, URLSession, URLRequest, SDK/client
  handle, raw query, raw page/provider payload, crawler/MCP runtime detail,
  maps SDK detail, StoreKit/payment/order/booking data, hidden app-control,
  provider call, execution claim, or completion claim.
- A178 does not change production AppBootstrap defaults, ChatStore behavior,
  UI, telemetry, transcript, memory-code, provider adapter, networking,
  crawler/MCP, maps SDK, payment, booking/order, remote model runtime, concrete
  vendor selection, or real provider behavior.

Verification:
- Run focused A178 networking tests.
- Run full `test_sim`.
- Run forbidden-fragment scan for touched Swift diffs.
- Run touched-file trailing-whitespace scan.
- Run A177/A178 doc consistency scan.
- Run `git diff --check`.
- Run `git status --short` and confirm A178 touched only the allowed source,
  test, and architecture docs.
```

Status after implementation: A178 added
`ServerProviderSearchAPIRoutePolicyCompatibilityStatusSourceProducer` and
focused networking tests. Compatible included-quota decisions render normal
Search API policy status; compatible metered decisions render warning status;
rejected routing/downstream/mismatch decisions map to stable existing
provider-status badges and card hints. The store preserves duplicate
recommendation-id first-wins behavior, hides `isVisible == false`, and is
wrapped by `ServerProviderRenderedRuntimeStatusSource` so hidden/missing
rendered ids return nil. Status/debug/encoded copy stays value-only with
`isRuntimeCallable false`, `isExecutable false`, and no provider runtime,
networking, endpoint, credential, SDK/client handle, production AppBootstrap
default, ChatStore behavior, UI, telemetry, transcript, memory-code,
crawler/MCP, maps SDK, StoreKit/payment, booking/order, concrete vendor
selection, provider call, execution claim, or completion claim.

## Round A179 - Search API Route-Policy Compatibility Status App-Root Handoff

```text
Task: Implement A179 as a test-only app-root handoff proof for A178 route-policy
compatibility status sources. Treat prior agent reports as untrusted. Read A177
and A178 code/tests first, then prove `AppBootstrap(providerStatusSources:)` and
ChatStore lookup can carry A178 compatible/rejected status for rendered
recommendation ids without production defaults, UI, runtime, or networking.

Hard non-goals:
- Do not add provider runtime, URLSession/networking, endpoint URLs, API keys,
  OAuth tokens, bearer tokens, credentials, SDK/client handles, provider
  adapters, production AppBootstrap defaults, ChatStore behavior, SwiftUI/UI,
  navigation, telemetry, transcript writes, memory writes, StoreKit/payment,
  booking/order flows, crawler runtime, MCP client runtime, Google/Gaode SDKs,
  remote model runtime, concrete vendor selection, provider calls, execution
  claims, or completion claims.
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
- kAir/Core/Networking/ServerProviderSearchAPIRoutePolicyCompatibility.swift
- kAir/Core/Networking/ServerProviderSearchAPIRoutePolicyCompatibilityStatusSourceProducer.swift
- kAirTests/Networking/ServerProviderSearchAPIRoutePolicyCompatibilityTests.swift
- kAirTests/Networking/ServerProviderSearchAPIRoutePolicyCompatibilityStatusSourceProducerTests.swift
- kAirTests/App/AppBootstrapTests.swift
- kAir/App/AppEntry/AppBootstrap.swift
- kAir/Features/Chat/Data/ChatStore.swift
- kAir/DesignSystem/Components/ProviderStatusBadgeModel.swift

Implementation frame:
- Add focused AppBootstrap tests that build A178 status sources for compatible
  included-quota, compatible metered, rejected routing/downstream, and fallback
  sources, then inject them with `AppBootstrap(providerStatusSources:)`.
- Verify root lookup and ChatStore lookup return the same selected
  `ProviderStatusPresentation` only for rendered recommendation ids.
- Verify source order remains first-wins, fallback-after-miss stays explicit,
  duplicate recommendation ids keep the first visible input, and hidden/missing
  rendered ids return nil.
- Verify selected copy does not mix lower-priority route/vendor/cost/rejection
  markers from later sources.
- Keep helper data local to tests; do not add production factories or runtime
  defaults.

Acceptance:
- Tests prove A178 included-quota, metered, and rejected route-policy
  compatibility status passes through AppBootstrap and ChatStore unchanged.
- Tests prove first-wins source ordering and fallback-after-miss behavior for
  A178 sources.
- Tests prove hidden and missing rendered ids return nil before and after
  ChatStore composition.
- Tests prove selected status copy contains `isRuntimeCallable false`,
  `isExecutable false`, and no endpoint URL, API key, OAuth token, bearer token,
  credential, URLSession, URLRequest, SDK/client handle, raw query, raw
  page/provider payload, crawler/MCP runtime detail, maps SDK detail,
  StoreKit/payment/order/booking data, hidden app-control, provider call,
  execution claim, or completion claim.
- A179 does not change production AppBootstrap defaults, ChatStore behavior,
  UI, telemetry, transcript, memory-code, provider adapter, networking,
  crawler/MCP, maps SDK, payment, booking/order, remote model runtime, concrete
  vendor selection, or real provider behavior.

Verification:
- Run focused A179 AppBootstrap tests.
- Run full `test_sim`.
- Run forbidden-fragment scan for touched Swift diffs.
- Run touched-file trailing-whitespace scan.
- Run A178/A179 doc consistency scan.
- Run `git diff --check`.
- Run `git status --short` and confirm A179 touched only the allowed test and
  architecture docs.
```

Status after implementation: A179 added a focused `AppBootstrapTests` handoff
proof for A178 route-policy compatibility status. The test packages compatible
included-quota, compatible metered, rejected route-policy, lower-priority
route-policy, hidden, duplicate, and fallback sources. It proves
`AppBootstrap(providerStatusSources:)` root lookup and ChatStore lookup return
the same selected copy for rendered ids only; source order remains first-wins;
duplicate recommendation ids keep the first visible A178 input;
fallback-after-miss remains explicit; hidden/missing ids stay nil; selected
copy includes `isRuntimeCallable false` and `isExecutable false`; and selected
copy does not mix lower-priority route/vendor/cost/rejection or fallback
markers. A179 did not add provider runtime, networking, endpoint, credential,
SDK/client handle, production AppBootstrap default, ChatStore behavior, UI,
telemetry, transcript, memory-code, crawler/MCP, maps SDK, StoreKit/payment,
booking/order, concrete vendor selection, provider call, execution claim, or
completion claim.

## Round A180 - Search API Route-Policy Compatibility Cross-Stage Status Composition

```text
Task: Implement A180 as a test-only cross-stage provider-status composition
proof for A178 route-policy compatibility status. Treat prior agent reports as
untrusted. Read A176, A178, and A179 tests first, then prove A178 can compose
with the earlier Search API status stack through `AppBootstrap(providerStatusSources:)`
and ChatStore lookup without stale upstream/downstream marker mixing.

Hard non-goals:
- Do not add provider runtime, URLSession/networking, endpoint URLs, API keys,
  OAuth tokens, bearer tokens, credentials, SDK/client handles, provider
  adapters, production AppBootstrap defaults, ChatStore behavior, SwiftUI/UI,
  navigation, telemetry, transcript writes, memory writes, StoreKit/payment,
  booking/order flows, crawler runtime, MCP client runtime, Google/Gaode SDKs,
  remote model runtime, concrete vendor selection, provider calls, execution
  claims, or completion claims.
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
- kAirTests/App/AppBootstrapTests.swift
- kAir/Core/Networking/ServerProviderSearchAPIRoutePolicyCompatibility.swift
- kAir/Core/Networking/ServerProviderSearchAPIRoutePolicyCompatibilityStatusSourceProducer.swift
- kAir/Core/Networking/ServerProviderSearchAPICostMembershipRoutingDecisionStatusSourceProducer.swift
- kAir/Core/Networking/ServerProviderMeteredEntitlementStatusSourceProducer.swift
- kAir/Core/Networking/ServerProviderSearchAPIVendorPolicyStatusSourceProducer.swift
- kAir/Core/Networking/ServerProviderSearchAPIAdapterPayloadDispatchStatusSourceProducer.swift
- kAir/Core/Networking/ServerProviderSearchAPIVendorPolicyDispatchAuthorizationStatusSourceProducer.swift
- kAir/Core/Networking/ServerProviderSearchAPITransportLeaseStatusSourceProducer.swift

Implementation frame:
- Add focused AppBootstrap tests that compose A178 route-policy compatibility
  status with A172 routing, metered entitlement, vendor policy, payload
  dispatch, dispatch authorization, transport lease, and fallback status
  sources.
- Verify route-policy-first selected copy wins for compatible included,
  compatible metered, and rejected route-policy cases, and does not leak
  upstream/downstream/fallback markers.
- Verify upstream/downstream-first source order can intentionally select those
  earlier/later sources without leaking A178 route-policy markers.
- Verify fallback-after-miss remains explicit when all route-policy and
  upstream/downstream sources miss a rendered recommendation id.
- Verify hidden/missing ids stay nil and selected copy remains value-only with
  `isRuntimeCallable false`, `isExecutable false`, and no runtime/execution
  claims.

Acceptance:
- Tests prove A178 route-policy compatibility status composes deterministically
  with routing, metered entitlement, vendor policy, payload dispatch, dispatch
  authorization, transport lease, and fallback status sources through app-root
  and ChatStore lookup.
- Tests prove source-order first-wins behavior for route-policy-first and
  upstream/downstream-first cases.
- Tests prove selected copy does not mix stale route/vendor/cost/rejection
  markers from lower-priority sources.
- Tests prove hidden and missing rendered ids return nil.
- Tests prove selected copy contains no endpoint URL, API key, OAuth token,
  bearer token, credential, URLSession, URLRequest, SDK/client handle, raw
  query, raw page/provider payload, crawler/MCP runtime detail, maps SDK detail,
  StoreKit/payment/order/booking data, hidden app-control, provider call,
  execution claim, or completion claim.
- A180 does not change production AppBootstrap defaults, ChatStore behavior,
  UI, telemetry, transcript, memory-code, provider adapter, networking,
  crawler/MCP, maps SDK, payment, booking/order, remote model runtime, concrete
  vendor selection, or real provider behavior.

Verification:
- Run focused A180 AppBootstrap tests.
- Run full `test_sim`.
- Run forbidden-fragment scan for touched Swift diffs.
- Run touched-file trailing-whitespace scan.
- Run A179/A180 doc consistency scan.
- Run `git diff --check`.
- Run `git status --short` and confirm A180 touched only the allowed test and
  architecture docs.
```

Status after implementation: A180 is complete. The route-policy compatibility
status source now has an app-root cross-stage composition proof with routing,
metered entitlement, vendor policy, payload dispatch, dispatch authorization,
transport lease, and fallback sources. Keep the proof test-only and do not
widen runtime from it.

## Round A181 - Agent Market, Paper, Provider Cut-Plan Refresh After Route-Policy Status Composition

```text
Task: Implement A181 as a docs-only research and architecture refresh. Treat
all prior research notes, agent reports, and model memory as untrusted until
checked against the current repo and current public sources. Use a product
manager plus market analyst stance: decide whether kAir's current chat-first,
local-first, provider-status architecture still matches the agent market,
advanced papers, open-source agent patterns, and vendor constraints after A180.

Hard non-goals:
- Do not change Swift, tests, project files, production AppBootstrap defaults,
  ChatStore behavior, UI, telemetry, transcript, memory-code, provider
  adapters, networking, crawler/MCP runtime, maps SDK runtime, StoreKit/payment,
  booking/order flows, remote model runtime, concrete vendor selection,
  provider calls, execution claims, or completion claims.
- Do not recommend live runtime widening unless the required quota, privacy,
  attribution, entitlement, source, audit, evaluation, and UI-safe status gates
  are listed as explicit prior gates.

Allowed files:
- Docs/research/2026-agent-market-ui-provider-research.md
- Docs/research/2026-agent-architecture-deep-dive-v1.md
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Read first:
- Docs/research/2026-agent-market-ui-provider-research.md
- Docs/research/2026-agent-architecture-deep-dive-v1.md
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md
- kAir/App/AppEntry/AppBootstrap.swift
- kAirTests/App/AppBootstrapTests.swift
- The current `git status --short` output, to avoid claiming unrelated dirty
  work as A181 work.

Research scope:
- Re-check current public evidence for mobile agents, life-service agents,
  tool-use agents, memory, cost-aware routing, MCP/security, GUI/web agents,
  and provider-status UX.
- Include current market comparisons for Apple Intelligence/App Intents,
  Google/Gaode maps constraints, Search API vendors, MCP ecosystems, MARVIS-
  style mobile assistants, Tencent Yuanbao/Hy3, Meituan LongCat/Xiaomei, and
  comparable open-source agent frameworks.
- Separate sourced fact from kAir product judgment. Every recommendation must
  map back to a concrete repo gate or an explicit non-goal.

Implementation frame:
- Update the two research docs with an A181 delta section that records source
  dates, market/architecture findings, and what changed since the earlier
  research snapshots.
- Update the provider-routing and market-fit docs with the A181 decision:
  whether the next cut remains value-only/test-only, which surface or contract
  should move next, and which runtime paths remain blocked.
- Add the next exact prompt as A182 in this file. It should be small enough for
  a coding agent to execute in one round, with allowed files, hard non-goals,
  acceptance, and verification.

Acceptance:
- A181 produces no Swift/code changes.
- Research notes include current-source dates and clearly mark sourced facts
  versus kAir judgment.
- The cut-plan explicitly evaluates whether advanced paper patterns or
  open-source agent architectures should be adopted now, reserved, or rejected
  for v1.
- The next gate is narrow, executable, and keeps provider/runtime/UI claims
  honest.
- Existing A180 status remains documented as Done; A182 is documented as Next.

Verification:
- Run a touched-doc trailing-whitespace scan.
- Run A180/A181/A182 doc consistency scan.
- Run `git diff --check`.
- Run `git status --short` and confirm A181 touched only the allowed docs.
```

Status after implementation: A181 is complete. The research refresh still
blocks live provider/runtime work and selects A182 as a comment-programming
contract for provider service lanes across local iOS, Google/Gaode maps, Search
API, crawler, and MCP. Keep A181 docs-only and do not infer runtime approval
from it.

## Round A182 - Provider Service Cut-Plan Comment Contract

```text
Task: Implement A182 as a pure value/comment-programming contract for provider
service lanes. Treat prior agent reports as untrusted. Read A181 docs first,
then freeze the code vocabulary that distinguishes local iOS behavior,
server-mediated maps/search upgrades, reserved crawler, and reserved MCP before
any provider runtime is widened.

Hard non-goals:
- Do not add URLSession/networking, endpoint URLs, API keys, OAuth tokens,
  bearer tokens, credentials, SDK/client handles, provider adapters, production
  AppBootstrap defaults, ChatStore behavior, SwiftUI/UI, navigation, telemetry,
  transcript writes, memory writes, StoreKit/payment, booking/order flows,
  crawler runtime, MCP client runtime, Google/Gaode SDKs, Search API calls,
  remote model runtime, concrete vendor selection, provider calls, execution
  claims, or completion claims.
- Do not expose raw query text, raw page/provider payloads, source bodies,
  private Health/location data, prompt text, credentials, endpoint URLs,
  crawler payloads, MCP descriptors, maps SDK details, payment/order data, or
  hidden app-control state in status/debug/encoded copy.

Allowed files:
- kAir/Core/Networking/ServerProviderServiceCutPlan.swift
- kAirTests/Networking/ServerProviderServiceCutPlanTests.swift
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- Docs/architecture/kair-next-agent-prompts-v1.md
- Docs/architecture/kair-agent-market-fit-audit-v1.md

Read first:
- Docs/research/2026-agent-market-ui-provider-research.md
- Docs/research/2026-agent-architecture-deep-dive-v1.md
- Docs/architecture/kair-provider-routing-mcp-search-v1.md
- kAir/Core/Providers/ProviderAccessProfile.swift
- kAir/Core/Networking/ServerProviderEnvelopeFactory.swift
- kAir/Core/Networking/ServerProviderRuntimeAdapter.swift
- kAirTests/Providers/ProviderAccessProfileTests.swift
- kAirTests/Networking/ServerProviderExecutionGateTests.swift

Implementation frame:
- Add `ServerProviderServiceLane` with lanes for local Apple/iOS maps, cache
  fallback, server-mediated Google Maps, server-mediated Gaode, server-mediated
  Search API, reserved crawler, and reserved MCP.
- Add `ServerProviderServiceIntent` for map display/route/search,
  public-info search, public-source crawl candidate, MCP tool/resource/prompt
  candidate, and life-service read-only lookup.
- Add `ServerProviderServiceCutPlanInput` carrying service intent,
  provider family, capability, membership tier, region, privacy class, cost
  class, quota posture, source/citation requirement, raw-content policy,
  attribution/cache/display policy, descriptor-trust posture, confirmation
  requirement, server-secret posture, and private-data posture.
- Add `ServerProviderServiceCutPlanDecision` returning local-ready,
  server-reserved, blocked, or unsupported, with selected lane, required prior
  gates, user-facing status line, and pinned `isRuntimeCallable == false` plus
  `isExecutable == false`.
- Keep the implementation deterministic, codable/hashable/sendable where local
  patterns support it, and comment every field that exists only to reserve a
  future provider/runtime gate.

Acceptance:
- Tests prove free/local maps choose Apple/local and do not require remote
  entitlement.
- Tests prove Google/Gaode map upgrades become server-reserved only when
  membership, region, attribution/cache/display, quota/QPS, privacy, and
  server-secret posture are represented; they remain non-executable.
- Tests prove Search API public-info lookup becomes server-reserved only when
  source/citation, raw-content, retention, cost unit, and metered entitlement
  posture are represented; it remains non-executable.
- Tests prove crawler stays blocked unless public source policy, robots
  posture, rate/retention posture, sandbox/audit, and experimental enablement
  are represented; it remains non-executable.
- Tests prove MCP is disabled/reserved by default and requires descriptor
  verification, discovery filtering, invocation authorization,
  consent/confirmation, token protection, and audit posture before it can be
  server-reserved; it remains non-executable.
- Tests prove private/Health/location-sensitive remote requests are blocked.
- Tests prove encoded/debug/status copy contains no endpoint URL, API key,
  OAuth token, bearer token, credential, URLSession, URLRequest, SDK/client
  handle, raw query, raw page/provider payload, crawler/MCP runtime detail,
  maps SDK detail, StoreKit/payment/order/booking data, hidden app-control,
  provider call, execution claim, or completion claim.
- A182 does not change production AppBootstrap defaults, ChatStore behavior,
  UI, telemetry, transcript, memory-code, provider adapter, networking,
  crawler/MCP, maps SDK, payment, booking/order, remote model runtime, concrete
  vendor selection, or real provider behavior.

Verification:
- Run focused `ServerProviderServiceCutPlanTests`.
- Run full `test_sim`.
- Run forbidden-fragment scan for touched Swift diffs.
- Run touched-file trailing-whitespace scan.
- Run A181/A182 doc consistency scan.
- Run `git diff --check`.
- Run `git status --short` and confirm A182 touched only the allowed Swift/test
  files and architecture docs.
```

Status after implementation: A183 is complete. The provider service cut-plan
status source now packages A182 decisions into rendered-id scoped
`ProviderStatusPresentation` copy with stable badges, card hints, first visible
input wins, hidden/missing nil lookup, and value-only status text. It remains
detached from production defaults, UI, runtime adapters, networking, crawler/MCP
runtime, maps SDK runtime, Search API calls, provider calls, execution claims,
and completion claims.

## Round A184 - Provider Service Cut-Plan Status App-Root Handoff

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

## Review Prompt After Every Round

Use this prompt for the reviewing/patching agent:

```text
Review the coding agent's report as untrusted.

1. Inspect git status and relevant diffs.
2. Compare changes with Docs/architecture/*.md and Contracts/*.
3. Patch only drift, stale docs, missing tests, broken comments, or
   unsafe scope creep.
4. Run git diff --check.
5. Run build/tests if Swift compile or behavior changed.
6. Report concrete pass/fail and give the exact next coding-agent
   prompt. Do not stage, commit, merge, or cross to the next step.
```
