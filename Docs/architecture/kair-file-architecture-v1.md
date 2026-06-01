# kAir File Architecture v1

Status: target file architecture, comment-only.
Last updated: 2026-05-30.

This document is the file map future coding agents should implement
against. It respects the current repo shape and adds target folders only
where they clarify ownership.

## 0. Current Shape to Preserve

Current useful anchors:

```text
kAir/
  App/
    AppEntry/AppBootstrap.swift
    Navigation/AppSection.swift
    Navigation/RootShellView.swift
  Core/
    AI/
    Capability/
    Continuation/
    Feedback/
    Matching/
    Memory/
    Models/
    Networking/
    Privacy/
    Surface/
    Telemetry/
  DesignSystem/
    Components/
    Tokens/
  Features/
    AI/
    Chat/
    Friends/
    Maps/
    Me/
    Models/
    Store/
    Today/
  Spaces/
    Health/
```

Do not flatten this. The split between `Core`, `Features`, `Spaces`,
`DesignSystem`, and `App` is already the right foundation.

## 1. Target Top-Level Tree

```text
kAir/
  App/                         // app lifecycle, composition, root navigation
  Core/                        // platform contracts and reusable engines
  DesignSystem/                // visual tokens and shared components
  Features/                    // product-facing feature groups
  Spaces/                      // complex workspaces with richer domain rules
  Shared/                      // small cross-feature UI or utilities
  Resources/                   // localization, model manifests, configs
```

Rule:

- `App` wires.
- `Core` defines protocols, engines, value contracts, and policy.
- `Features` and `Spaces` implement user-facing verticals.
- `DesignSystem` never imports feature modules.
- `Core` never imports feature presentation modules.

## 2. App Layer

Target:

```text
kAir/App/
  AppEntry/
    KAirApp.swift                    // @main entry only
    AppBootstrap.swift               // current composition root, keep
    AppContainer.swift               // future DI object, comment scaffold first
    StartupCoordinator.swift         // model catalog, memory, permissions warmup
  Navigation/
    AppSection.swift                 // visible sections only
    AppRoute.swift                   // typed internal route enum
    RootShellView.swift              // shell, sheets, full-screen surfaces
    SurfaceRouter.swift              // route from capability result to surface
  Entitlements/
    EntitlementState.swift           // StoreKit/product entitlement state
    ModelEntitlementPolicy.swift     // free/local/paid model access policy
```

Ownership comments:

- `AppBootstrap` remains the current single composition object until a
  later PR introduces `AppContainer`.
- `SurfaceRouter` must not parse natural language. It consumes structured
  `IntentDraft` or `NormalizedResult`.
- `AppSection` should stay small. Reserved verticals should not be added
  until they have a real surface.

## 3. Core AI Layer

Target:

```text
kAir/Core/AI/
  ConversationEngine.swift           // orchestration pipeline
  IntentParser.swift                 // text -> IntentDraft
  IntentDraft.swift                  // structured candidate intent
  CapabilityRouter.swift             // IntentDraft -> CapabilityKind
  ActionPlan.swift                   // tool plan, confirmation needs, risk
  PlanValidator.swift                // permission/privacy/entitlement check
  ResultProjector.swift              // NormalizedResult -> transcript/surface/memory
  AgentRegistry.swift                // role registry, not execution logic
  ToolRegistry.swift                 // tool declarations and permissions
  ToolExecutor.swift                 // dispatches approved tool calls
  StructuredOutput/
    JSONSchemaContract.swift         // parser/rejection contract
    ParserDiagnostics.swift          // parse failure taxonomy
```

Rules:

- No SwiftUI import in `Core/AI`.
- No direct network call from `ConversationEngine`.
- No direct HealthKit access from AI files.
- The parser output must be Codable, Sendable, and testable.
- The router returns "ask clarification" when confidence is low.

## 4. Core Capability Layer

Current layer is strong. Extend it like this:

```text
kAir/Core/Capability/
  CapabilityKind.swift               // frozen vocabulary by contract version
  CapabilityAdapter.swift            // adapter protocol
  CapabilityRegistry.swift           // single process registry
  DefaultCapabilityRegistry.swift    // composition seam
  NormalizedResult.swift             // result envelope
  CapabilityRisk.swift               // read/write/pay/share/open classification
  CapabilityConfirmation.swift       // confirmation artifact model
  Adapters/
    ...                              // concrete adapter implementations
```

Rules:

- Adding a capability kind requires a contract update and tests.
- Adapters own availability checks.
- Adapters must not silently substitute AI synthesis for partner failure.
- A capability result must carry honest source: partner, local, or AI
  synthesized.

## 5. Core Models Layer

Target:

```text
kAir/Core/Models/
  LocalModelDescriptor.swift         // installed/downloadable model metadata
  ModelProvider.swift                // runtime-agnostic generation interface
  ModelRequest.swift                 // task, privacy class, budget, schema
  ModelResponse.swift                // text, structured object, tokens, metrics
  ModelCatalog.swift                 // remote/local catalog snapshot
  ModelDownloadManager.swift         // download/compile/install/delete state machine
  ModelRuntimeFamily.swift           // foundationModels/coreML/mlx/llamaCPP/remote
  ModelBenchmarkStore.swift          // local latency/memory success metrics
  Runtime/
    FoundationModelsProvider.swift   // gated by OS availability
    CoreMLProvider.swift             // compiled .mlmodelc runtime
    MLXProvider.swift                // experimental Apple Silicon runtime
    LlamaCPPProvider.swift           // optional GGUF runtime
    RemoteModelGateway.swift         // server-gated paid providers
```

Rules:

- UI chooses from descriptors and entitlements, not provider classes.
- Providers never decide pricing.
- Download manager never decides routing quality.
- Remote providers must go through `ServerTransport`; API keys stay server-side.
- Health requests must be rejected before reaching remote providers.

## 6. Core Memory Layer

Target:

```text
kAir/Core/Memory/
  MemoryStore.swift                  // facade for write/read/delete/pause
  MemoryRecord.swift                 // normalized durable memory value
  MemoryDomain.swift                 // chat/health/model/capability/social
  MemoryWritePolicy.swift            // consent, sensitivity, retention
  MemoryConsolidator.swift           // raw event -> distilled facts
  MemoryRetriever.swift              // scoped retrieval with budget
  MemoryIndex.swift                  // FTS + optional vector facade
  EmbeddingProvider.swift            // local embedding provider abstraction
  Persistence/
    SQLiteMemoryDatabase.swift       // GRDB-backed implementation candidate
    MemoryMigrations.swift           // schema versioning
    VectorIndexStore.swift           // sqlite-vec candidate behind facade
```

Rules:

- Memory is domain-scoped.
- Health memory uses a separate database.
- User can pause memory writes.
- User can delete one record, one domain, or all memory.
- Retrieval must return citations/provenance to the engine.
- Raw transcript chunks are not enough; compact facts and task state are
  first-class memory.

## 7. Core App Intents / External Bridge

Target:

```text
kAir/Core/SystemBridge/
  AppIntents/
    OpenKAirSurfaceIntent.swift      // open a kAir-owned surface
    ContinueChatIntent.swift         // continue current thread
    RunSavedActionIntent.swift       // user-approved saved action only
    KAirIntentEntity.swift           // minimal display-friendly entities
  ExternalHandoff/
    DeepLinkBuilder.swift            // universal link / URL scheme builder
    ShareSheetPayload.swift          // explicit export payload
    ExternalActionReceipt.swift      // result from partner/system handoff
```

Rules:

- Expose 1-3 high-value intents first.
- App Intents call app services, not views.
- Every external handoff has a visible user action.
- If receipt cannot be verified, UI says "opened" or "prepared", not
  "completed".

## 8. Features Layer

Current feature tree should evolve to this pattern:

```text
kAir/Features/<FeatureName>/
  Domain/                    // pure values, feature-specific intent
  Data/                      // repositories/adapters/service clients
  Presentation/              // SwiftUI views, shell callers
  Testing/                   // fixtures and mocks when module grows
```

Feature rules:

- `Presentation` can import `DesignSystem`, `Core`, and its own Domain.
- `Domain` must not import SwiftUI.
- `Data` owns partner SDK clients and maps to `NormalizedResult`.
- `Testing` holds fixtures; production code should not depend on tests.

## 9. Reserved Vertical Feature Packages

Create these only when implementing the first real adapter or surface:

```text
kAir/Features/Social/
kAir/Features/Food/
kAir/Features/Music/
kAir/Features/Movies/
kAir/Features/Search/
kAir/Features/Payments/
kAir/Features/Bookings/
```

Each starts with:

```text
Domain/<Vertical>Intent.swift
Data/<Vertical>CapabilityAdapter.swift
Presentation/<Vertical>HomeView.swift
```

Do not add empty decorative screens. A reserved vertical begins with an
adapter contract or a real user flow.

## 10. DesignSystem Layer

Target:

```text
kAir/DesignSystem/
  Tokens/
    AppTheme.swift
    AppTheme+Typography.swift
    AppTheme+Motion.swift
    AppTheme+Elevation.swift
  Components/
    ExecutionSurfaceShell.swift
    ActionCardShell.swift
    RecommendationRail.swift
    KAirSurface.swift
    StatusPill.swift
  Layout/
    SurfaceGrid.swift
    CompactToolbar.swift
```

Rules:

- No feature-specific copy in DesignSystem.
- Components accept data and actions; they do not import stores.
- Execution surfaces should reuse `ExecutionSurfaceShell` unless they
  have a documented exception.

## 11. Resources

Target:

```text
kAir/Resources/
  Localizable.xcstrings
  ModelCatalog/
    bundled-models.json
    remote-catalog-schema.json
  Privacy/
    privacy-copy.zh-Hans.json
  Demo/
    demo-fixtures.json
```

Rules:

- User-facing copy moves to localization once strings stabilize.
- Model catalog JSON is data, not code.
- Demo fixtures must never contain real health, friend, or payment data.

## 12. Tests

Target:

```text
kAirTests/
  Architecture/
    FileArchitectureContractTests.swift
    DependencyDirectionTests.swift
  AI/
    IntentParserContractTests.swift
    CapabilityRouterTests.swift
    PlanValidatorTests.swift
  Models/
    ModelCatalogTests.swift
    ModelDownloadStateMachineTests.swift
    ModelEntitlementPolicyTests.swift
  Memory/
    MemoryWritePolicyTests.swift
    MemoryRetrievalTests.swift
    HealthMemoryIsolationTests.swift
  Capability/
    Existing tests stay here
  DesignSystem/
    Existing shell tests stay here
```

Every new architecture file needs one of:

- a compile-time protocol test,
- a contract/vocabulary test,
- a state-machine test, or
- a privacy rejection test.

## 13. Dependency Direction

Allowed:

```text
App -> Features
App -> Core
Features -> Core
Features -> DesignSystem
Spaces -> Core
Spaces -> DesignSystem
DesignSystem -> SwiftUI/Foundation only
  Core -> Foundation/system frameworks only
```

## 15. Provider, MCP, and Search Layers

Provider routing adds three Core folders:

```text
kAir/Core/Providers/
  ProviderRoutingPolicy.swift       // membership/cost/privacy provider choice
  MapProviderDescriptor.swift       // Apple/Gaode/Google/cache descriptors

kAir/Core/SystemBridge/
  MCPGateway.swift                  // reserved MCP gateway, disabled by default

kAir/Core/Search/
  SearchProvider.swift              // search API/crawler/cache result contracts
```

Rules:

- These folders define contracts first; no real provider SDK, API key,
  crawler, or MCP runtime is wired until policy tests exist.
- UI never calls provider adapters directly.
- Provider results normalize before they reach execution surfaces.
- Any server-mediated provider request must include privacy class,
  membership/cost class, provider id, and trace id.

Forbidden:

```text
Core -> Features
Core -> DesignSystem
DesignSystem -> Features
FeatureA -> FeatureB implementation
AI -> HealthKit directly
UI -> ServerTransport directly
UI -> concrete paid model provider directly
```

## 14. Migration Order

1. Fill comment scaffolds in `Core/AI`, `Core/Models`, and `Core/Memory`.
2. Add contract tests that lock the planned types and policies.
3. Implement `IntentDraft`, `ActionPlan`, and `PlanValidator` as pure
   value types.
4. Implement local-only parser fallback with deterministic rules.
5. Add `ModelCatalog` and `ModelDownloadManager` state machine.
6. Add `MemoryStore` facade with in-memory implementation.
7. Replace stub AI adapter with local planner route only.
8. Add first App Intent: open Chat or continue a thread.
9. Move to SQLite/GRDB only after value contracts are stable.
10. Add paid/remote model gateway only after StoreKit entitlement tests.
