# PROJECT_BRIEF · kAir

Status: project-specific brief.
Last updated: 2026-05-30.

## 1. Project Identity

| Field | Value |
|---|---|
| `PROJECT_NAME` | kAir |
| `PROJECT_NAME_EN` | kAir |
| `ONE_LINE_PITCH` | One chat command routes daily life tasks to the right local or app capability. |
| `TARGET_USERS` | iPhone users who want one private command surface for health, maps, AI, services, media, commerce, and personal memory. |
| `TARGET_PLATFORM` | iPhone first; Universal later. |
| `IOS_MIN_VERSION` | Current repo target; keep existing deployment target until an explicit project-file PR changes it. |
| `REPO_PATH` | `/Users/kair/Projects/kAir` |
| `BRIEF_PATH` | `/Users/kair/Projects/kAir/Docs/PROJECT_BRIEF.md` |

## 2. Main Demo Flow

The 90-second demo should prove command-to-surface routing:

1. Launch kAir and land on Chat.
2. User enters a natural instruction such as "帮我找去 Union Station 的路线".
3. Chat creates a trace and sends the text to the local router path.
4. Router returns a structured intent and safe action plan.
5. PlanValidator checks permission, risk, model availability, and privacy.
6. Recommendation rail shows the target action with honest trust pills.
7. User accepts.
8. kAir opens the correct execution surface through `ExecutionSurfaceShell`.
9. Surface displays status, result summary, and any unavailable/permission
   state truthfully.
10. User returns to Chat.
11. Continuation runtime records the return outcome.
12. Memory policy writes only allowed task state or preference.

## 3. Screen Clusters

| Cluster | Screens | Owner | Difficulty |
|---|---|---|---|
| Chat Command Surface | ChatHomeView, composer, recommendation rail, continuation transcript | A6 / main UI | High |
| Execution Surfaces | Maps, AI, Store, Health, future Search/Music/Video/Food/Social shells | A7 / secondary UI | High |
| Model Library | ModelLibraryView, model state rows, download/purchase placeholders | A5 / AI layer + UI | Medium |
| Profile and Settings | Profile, privacy controls, memory controls, model settings | A7 / settings | Medium |
| System Bridge | App Intents, deeplinks, external handoff confirmations | A4 / services | Medium |

## 4. Global State and Stores

| Store | Fields | Persistence | Readers |
|---|---|---|---|
| `AppBootstrap` | current section, presented surface, active maps session, registries, runtimes | in-memory composition root | Root shell, Chat, surfaces |
| `ChatStore` | thread, transcript, recommendations, pending route context, telemetry ids | future local store | Chat UI, continuation |
| `HealthDashboardStore` | HealthKit permission and dashboard state | HealthKit + local derived state | Health workspace |
| `ModelLibraryStore` | catalog entries, install/download state, active model role, entitlement view | local catalog + StoreKit/server later | Model Library, AI surface |
| `MemoryStore` | domain-scoped records, pause/delete state, retrieval indexes | local-only SQLite later | ConversationEngine, settings |
| `EntitlementState` | StoreKit purchases, premium model access, expiry | StoreKit + server validation later | Model Library, router policy |
| `CapabilityRegistry` | registered adapters and availability | in-memory | Chat, ConversationEngine, surfaces |

## 5. Services

| Service | Responsibility | Calls | Called by |
|---|---|---|---|
| `ConversationEngine` | input orchestration, intent parsing, plan validation, result projection | ModelProvider, MemoryStore, CapabilityRegistry | ChatStore |
| `ModelProvider` | runtime-agnostic local/remote generation and embeddings | runtime adapters | ConversationEngine |
| `ModelDownloadManager` | download, verify, compile, install, delete model files | URLSession/server catalog later | ModelLibraryStore |
| `MemoryStore` | memory write/manage/read/delete/pause | SQLite/FTS/vector later | ConversationEngine, Settings |
| `ServerTransport` | optional backend transport, StoreKit validation, remote model gateway | kAir backend | model/commerce/social services only |
| `PrivacyGuard` | release-blocking policy checks | none | every sensitive path |
| `SurfaceRouter` | structured result to kAir surface | AppBootstrap | ConversationEngine, App Intents |
| `ToolExecutor` | approved tool-call dispatch | CapabilityRegistry | ConversationEngine |

## 6. AI and Backend

| Field | Value |
|---|---|
| `HAS_AI` | yes |
| `AI_VENDOR` | self-developed local router first; paid market models optional via server gateway |
| `AI_ENDPOINT` | none for local v1; future server gateway only after entitlement/privacy contract |
| `AI_TASKS` | intent routing, tool planning, clarification, memory distillation, local health summary, optional premium generation |
| `API_KEY_LOCATION` | server-side only for paid/remote providers |
| `TIMEOUT_SEC` | 8 seconds for remote gateway; local model uses separate latency budget |
| `HAS_FALLBACK` | yes, deterministic local fallback and clarification copy |

AI constraints:

- Self-developed lightweight model only needs to route, plan, and call
  approved capabilities in v1.
- Health analysis is local-only.
- Paid large models require StoreKit entitlement and server-side provider
  keys.
- No model can execute write/pay/share/external-open actions without
  confirmation.

## 7. Visual Style

| Field | Value |
|---|---|
| `DESIGN_SYSTEM` | kAir AppTheme + iOS HIG |
| `PRIMARY_COLOR` | Existing `AppTheme.Palette.accent` |
| `SUPPORTS_DARK_MODE` | yes |
| `FIGMA_LINK` | none in repo |
| `LOGO_ASSET_PATH` | existing asset catalog only |

Design rule:

- No landing page.
- Chat is the first screen.
- Operational surfaces should be dense, calm, and stateful.
- Execution surfaces should use `ExecutionSurfaceShell`.

## 8. Test and Release

| Field | Value |
|---|---|
| `TEST_COVERAGE_TARGET` | Contract-first coverage; do not chase a percentage before routing/privacy tests exist. |
| `HAS_DEMO_MODE` | yes, later |
| `DEMO_DURATION_SEC` | 90 |
| `DEPLOY_TARGET` | internal/TestFlight later |

Minimum test families:

- Capability vocabulary and adapter envelope.
- AI intent parser and plan validator.
- Model catalog and download state machine.
- Memory domain isolation.
- Health privacy guards.
- Execution surface shell states.
- StoreKit entitlement policy when paid models are wired.

## 9. Explicit Non-Goals for the Next Rounds

- Do not implement real payments before StoreKit entitlement tests.
- Do not implement real model downloads before catalog and state-machine
  tests.
- Do not send Health data to any remote model.
- Do not add private APIs or screen automation for third-party apps.
- Do not add decorative vertical tabs without adapters.
- Do not import a large architecture framework unless a separate ADR
  accepts the dependency.

## 10. Demo Done Definition

Demo is acceptable when:

1. Chat input can produce a structured route or safe clarification.
2. At least one execution surface opens from a recommendation.
3. Return-to-chat continuation is recorded.
4. Model Library truthfully shows model states, including unavailable or
   not wired states.
5. Memory can be paused/deleted and does not cross health/social/chat
   boundaries.
6. Missing permission, missing model, network failure, and empty data do
   not create blank UI.
7. `git diff --check`, build, and relevant tests pass.

