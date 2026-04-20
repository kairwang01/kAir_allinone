# Surface Entry Contract Audit

Freezes the semantics of `SurfaceEntryRequest`, `ExecutionReturnPayload`, and
the three `surface_entry_*` events as they exist today. This is a factual
snapshot, not a roadmap.

Sources of record:
- [SurfaceEntryRequest.swift](../../kAir/Core/Matching/SurfaceEntryRequest.swift)
- [ExecutionReturnPayload.swift](../../kAir/Core/Matching/ExecutionReturnPayload.swift)
- [MatchingEvent.swift](../../kAir/Core/Matching/MatchingEvent.swift)
- [AppBootstrap.swift](../../kAir/App/AppEntry/AppBootstrap.swift)
- [ChatStore.swift](../../kAir/Features/Chat/Data/ChatStore.swift) (`preparePendingSurfaceEntryRequest`)
- [SurfaceEntryChain.swift](../../kAir/Core/Matching/SurfaceEntryChain.swift)

## 1. Field semantic freeze

### 1.1 `SurfaceEntryRequest`

| Field | Type | Source | Required | nil allowed | Default |
| --- | --- | --- | --- | --- | --- |
| `requestId` | `String` | generated at construction (`UUID().uuidString`); once assigned, never mutated | yes | no | fresh UUID |
| `surfaceType` | `AppSection` | caller (`ChatStore.preparePendingSurfaceEntryRequest`, `AppBootstrap.openMaps/openMusic/openVideo/openHealth`, or `AppBootstrap.resolveEntryRequest` fallback) | yes | no | — |
| `entryIntent` | `SurfaceEntryIntent` | caller; default-synthesized via `SurfaceEntryIntent(section:)` when not supplied | yes | no | `SurfaceEntryIntent(section: surfaceType)` |
| `sourceCardId` | `String?` | `ChatStore.preparePendingSurfaceEntryRequest` sets it to `candidate.candidate.id`. All other code paths leave it nil. | no | yes (see §2) | `nil` |
| `sourceRecommendationId` | `String?` | `ChatStore.preparePendingSurfaceEntryRequest` sets it to `activeDecision?.recommendationId`. `AppBootstrap.build*EntryRequest` builders leave it nil. | no | yes (see §2) | `nil` |
| `sourceThreadId` | `String?` | `ChatStore` sets `session.id.uuidString`. `AppBootstrap.buildMapsEntryRequest` sets `task.threadId.uuidString`. Music/Video/Health builders leave nil (see §4). | no | yes (see §2) | `nil` |
| `objectType` | `String?` | caller; `ChatStore` uses `MatchingObjectKind.*.rawValue`; `AppBootstrap.build*EntryRequest` uses the same enum. | no | yes (when no object, e.g. direct Store/AI open) | `nil` |
| `objectId` | `String?` | caller; ties to a specific `MapTask.id`, `session.id.uuidString`, candidate id, etc. | no | yes (when no object) | `nil` |
| `normalizedArgs` | `[String: String]` | caller; flat string→string bag, adapter-defined keys (see §3). Always constructed, never nil. | yes | no (empty dict is allowed) | `[:]` |
| `requiresConfirmation` | `Bool` | caller | yes | no | `false` (see §2) |
| `handoffContext` | `SurfaceEntryHandoffContext` | caller; always a concrete struct, `.empty` is the zero value. | yes | no | `.empty` |
| `issuedAt` | `Date` | generated at construction (`.now`) | yes | no | `.now` |

`SurfaceEntryHandoffContext` sub-fields:

| Field | Type | Source | nil allowed | Default |
| --- | --- | --- | --- | --- |
| `sourceMessagePreview` | `String?` | caller; in `ChatStore` it is `candidate.candidate.activationPrompt`; builders pass the originating prompt/query. | yes | `nil` |
| `returnThreadId` | `String?` | caller; set to `session.id.uuidString` when the request originates from a chat session, nil otherwise (see §2 and §4). | yes | `nil` |
| `priorContextStateSummary` | `String?` | caller; adapter-specific summary of prior state, empty-string treated as nil by convention. | yes | `nil` |

### 1.2 `ExecutionReturnPayload`

| Field | Type | Source | Required | nil allowed | Default |
| --- | --- | --- | --- | --- | --- |
| `executedCandidateId` | `String` | caller (recorder or surface-side producer) | yes | no | — |
| `executionSurfaceType` | `AppSection` | caller; must equal the chain's `surfaceType` | yes | no | — |
| `outcome` | `ExecutionOutcome` | caller; one of `.completed`, `.abandoned`, `.partial`, `.failed` | yes | no | — |
| `duration` | `TimeInterval` | caller; seconds the surface was active | yes | no | — |
| `returnContextDelta` | `ReturnContextDelta` | caller; zero value is `.neutral` | yes | no | `.neutral` |
| `sourceRequestId` | `String?` | caller; if non-nil, MUST equal the chain's `requestId` | no | yes (see §2) | `nil` |
| `sourceRecommendationId` | `String?` | caller; if non-nil and the chain has a non-synthetic recommendation, MUST equal that recommendation id | no | yes (see §2) | `nil` |

`ReturnContextDelta` fields (`downstreamValue`, `completionScore`,
`addedIntentTags`, `resolvedObjectIds`, `dismissedObjectIds`, `summary`) follow
the same pattern: scalars default to `0`, arrays default to `[]`, `summary`
is `String?` defaulting to `nil`. `.neutral` is the canonical zero value.

### 1.3 `surface_entry_*` `MatchingEvent`

The three entry phases serialize as `MatchingEvent` with `type` in:
`.surfaceEntryRequested`, `.surfaceEntryStarted`, `.surfaceEntryReturned`.

| Field | Semantic in entry events |
| --- | --- |
| `surfaceEntryRequestId` | **Required and non-nil for any event to count as part of a chain.** `MatchingReplayLab.submitSurfaceEntryEvent` drops events whose `surfaceEntryRequestId` is nil. Must equal the chain's `requestId`. |
| `recommendationId` | Set to the real recommendation id when the chain is recommendation-triggered; set to a `synthetic-direct-*` sentinel for direct-opens (seeder) or to the current active recommendation in runtime. Never nil because `MatchingEvent.recommendationId: String` is non-optional. |
| `candidateId` | Falls back to `request.objectId` when no explicit candidate is attached; may be nil. |
| `objectType` | Mirrors `request.objectType` (may be nil for direct Store/AI opens). |
| `executionSurfaceType` | String rawValue of the chain's `AppSection`. Required in recorder output. |
| `outcome` (event-level) | Set only on `surfaceEntryReturned` when a payload is attached; otherwise nil. |

`SurfaceEntryTerminalOutcome` is derived in `SurfaceEntryReplayBuilder.resolveTerminal`
with this precedence:

1. If a payload is retained for the chain: `.completed | .partial → completion`, `.abandoned | .failed → abandon`. Payload wins; no `.dismiss` is produced from a payload.
2. Otherwise, the builder searches `allEvents` by `recommendationId` for a terminal event: `.completion → completion`, `.abandon → abandon`, `.dismiss → dismiss`.
3. Otherwise, if a `surface_entry_returned` event exists: `.returnedOnly`.
4. Otherwise: `.inFlight`.

## 2. Currently allowed empty values

Each nil/empty state is intentional. The reason is that not every chain has
the upstream signal required to populate the field.

### 2.1 `sourceCardId == nil`

Allowed because the chain was not opened from a recommendation card:
- Direct tab-bar taps (`AppBootstrap.openSurface(.music)`, etc., with no active recommendation) go through the default-synthesis fallback which leaves it nil.
- `AppBootstrap.buildMapsEntryRequest / buildMusicEntryRequest / buildVideoEntryRequest / buildHealthEntryRequest` do not populate `sourceCardId` even when a session/task exists; these builders are used for programmatic opens, not card-driven ones.

`sourceCardId` is only populated in `ChatStore.preparePendingSurfaceEntryRequest`,
where it carries `candidate.candidate.id` — the specific recommendation card
the user tapped. Absence is the dominant state today.

### 2.2 `sourceRecommendationId == nil`

Allowed because the chain is not tied to an `activeDecision`:
- Direct tab-bar taps have no recommendation decision in flight.
- `AppBootstrap.build*EntryRequest` adapters are reused for both rec-driven
  and non-rec-driven opens, and they do not attempt to look up the active
  decision.

Chain aggregation still works: when `sourceRecommendationId` is nil on the
request, `SurfaceEntryReplayBuilder` uses the per-event `recommendationId`
(`synthetic-direct-*` sentinel or the real active id) for terminal lookup.
The replay panel labels these chains as "direct" in the list row.

### 2.3 `objectId == nil`

Allowed because the entry is not anchored to a specific object:
- `store` and `ai` opens currently have no object-level target. The user is
  opening the surface as a category, not an item.
- `health` opens anchored to an `answerCard` intentionally carry
  `objectType = "answerCard"` with `objectId = nil`, because the answer card
  itself is the surface state, not a referable object id.

### 2.4 `handoffContext.returnThreadId == nil`

Allowed because no chat thread is claiming the return:
- `AppBootstrap.buildMusicEntryRequest` and `buildVideoEntryRequest` do not
  thread a `returnThreadId` through the `MusicPlaybackSession` /
  `VideoPlaybackSession` value types today.
- Direct-open chains from the tab bar have no originating chat session.

When `returnThreadId` is nil, the return path simply closes the surface
without notifying a specific thread; `AppBootstrap.closeSurface` uses
`surfaceReturnHandler` on the active chat if one is installed, which is
orthogonal to the chain payload.

### 2.5 `requiresConfirmation == false`

Allowed, and currently the **only** value emitted by any code path. No
adapter flips this to `true` today. The field is kept in the struct as a
stable slot for future confirmation gating, but every existing flow opens
without a confirmation step. Treat `false` as the de facto constant until
an adapter is introduced that sets it otherwise.

## 3. Default synthesis vs real adapter boundary

"Real adapter" = the request is built from a typed session/task value that
carries domain-specific state. "Default synthesis" = the request is the
minimal shape produced by `AppBootstrap.resolveEntryRequest` when no caller
or provider supplies a richer one.

| Surface | Real adapter | Default-synthesis fallback | Status |
| --- | --- | --- | --- |
| `maps` | `AppBootstrap.buildMapsEntryRequest(for: MapTask)` + `ChatStore.preparePendingSurfaceEntryRequest` (maps branch). Fills `query`, `task_type`, `language`, `entry_mode`, `transport_mode`, `destination_title`, handoff preview and state summary. | Yes | Real adapter |
| `music` | `AppBootstrap.buildMusicEntryRequest(for: MusicPlaybackSession)` + `ChatStore` music branch. Fills `mood`, `query`, `title`, `source`, handoff preview and subtitle. | Yes | Real adapter |
| `video` | `AppBootstrap.buildVideoEntryRequest(for: VideoPlaybackSession)` + `ChatStore` video branch. Fills `category`, `query`, `title`, `duration`, handoff summary. | Yes | Real adapter |
| `health` | `AppBootstrap.buildHealthEntryRequest(for: HealthRouteSession)` + `ChatStore` health branch. Fills `topic`, `language`, `original_prompt`, handoff preview. | Yes | Real adapter |
| `store` | — | Yes | Default synthesis only. `ChatStore.preparePendingSurfaceEntryRequest` has an explicit `.store, .ai: break` in its switch. No `buildStoreEntryRequest` exists. |
| `ai` | — | Yes | Default synthesis only. Same `break` branch in `ChatStore`. No `buildAIEntryRequest` exists. |
| `chat` | N/A | N/A | `chat` is not a surface you can open as an entry target. `AppBootstrap.openSurface(.chat)` short-circuits to `closeSurface()`. |

The default-synthesis shape emitted by `AppBootstrap.resolveEntryRequest` is:

```
SurfaceEntryRequest(
    requestId: <fresh UUID>,
    surfaceType: <section>,
    entryIntent: SurfaceEntryIntent(section: <section>),
    sourceCardId: nil,
    sourceRecommendationId: nil,
    sourceThreadId: nil,
    objectType: nil,
    objectId: nil,
    normalizedArgs: [:],
    requiresConfirmation: false,
    handoffContext: .empty,
    issuedAt: .now
)
```

## 4. Known limitations and follow-up points

Facts only. Each item below is a current gap, not a commitment to change it.

- **No store / ai real adapters.** Any open of `.store` or `.ai` produces the
  default-synthesis request. No session/task type exists to feed into a
  builder.
- **`AppBootstrap.buildMusicEntryRequest` / `buildVideoEntryRequest` /
  `buildHealthEntryRequest` do not set `sourceThreadId`.** Only the maps
  builder threads through a thread id (from `MapTask.threadId`). Music /
  video / health sessions do not carry a chat thread id today.
- **`AppBootstrap.build*EntryRequest` does not set `sourceCardId` or
  `sourceRecommendationId`.** Those fields are only populated when the
  chain originates in `ChatStore.preparePendingSurfaceEntryRequest`.
- **`requiresConfirmation` is never set to `true`.** No adapter currently
  produces a confirmation-gated entry.
- **Payload outcome cannot express dismiss.** `ExecutionOutcome` has
  `{ completed, abandoned, partial, failed }` with no `dismiss` case. A
  chain reaches `.dismiss` terminal only by emitting a real `.dismiss`
  `MatchingEvent` and retaining no payload. `SurfaceEntryCanonicalFlowSeeder.emitDismissChain`
  follows this shape; runtime paths do not currently produce `.dismiss`
  chains (no recorder method emits a `.dismiss` `MatchingEvent` on a
  surface-entry-linked event).
- **`synthetic-` recommendation id prefix is a first-class sentinel.**
  `SurfaceEntryReplayBuilder` uses it in two places:
  (a) `build` maps an event-level `recommendationId` starting with
  `synthetic-` back to nil when computing `chain.sourceRecommendationId`,
  so a direct-open chain that nonetheless carries a sentinel event rec id
  still reports `hasRecommendation == false`;
  (b) `evaluateInvariants` skips the payload-vs-chain recommendation-id
  check when the chain's recommendation is synthetic, so the payload
  consistency invariant does not require a match. Real runtime chains
  (no `synthetic-` prefix) do enforce the match.
- **`MatchingReplayLab` request retention is capped at 256 entries and
  events at 512.** Chains beyond this window are dropped. Intentional bound
  for the in-memory dev-only Replay panel; not a durability contract.
- **`handoffContext.priorContextStateSummary`** is set by adapters only
  when a meaningful summary exists (e.g. `MapTask.resultSummary` is
  non-empty). Empty-string is treated as nil by convention and not emitted.
