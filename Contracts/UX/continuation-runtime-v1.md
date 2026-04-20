# Continuation Runtime v1

**Status**: frozen for implementation
**Version**: v1
**Owner**: Core / Continuation
**Doc layer**: `Contracts/UX/`

**Normative dependencies**
- `Contracts/UX/post-return-and-continuation-ux-v1.md`
- `Contracts/UX/mixed-recommendation-layout-v1.md`
- `Contracts/UX/negative-feedback-ux-v1.md`
- `Contracts/telemetry-contract-v1.md` *(field and span names, once landed)*
- `Contracts/capability-registry-and-adapter-contract-v1.md` *(surface/capability alignment, once landed)*

---

## 1. Purpose

`Continuation Runtime` is the single runtime contract that translates an **Execution Surface return** into:

1. structured transcript insertions inside Chat,
2. deterministic `Recommended Next` refresh behavior,
3. a normalized continuation classification for the current task thread.

This runtime exists to stop per-vertical return logic from spreading across Maps / Music / Search / future surfaces.

**Rule**: after v1 lands, no vertical may define its own post-return Chat insertion rule or recommendation-refresh rule outside this runtime.

---

## 2. Scope

### 2.1 In scope

`Continuation Runtime v1` handles only the moment when a user returns from an execution surface back into Chat and the immediate follow-up UI behavior.

It normalizes these inputs:

- source surface
- source request id
- source recommendation id
- terminal outcome
- optional structured payload
- timestamp
- current thread context

It produces these outputs:

- transcript insertion plan
- recommendation refresh plan
- continuation state classification

### 2.2 Non-goals

The following are explicitly **not** handled by v1:

1. **Silent exit ownership**
   - Example: app background, OS kill, restore after relaunch.
   - Telemetry may record it, but `Continuation Runtime v1` does not define final ownership or attribution.
2. **Abandon timeout policy**
   - The duration that qualifies as `abandon` is not defined here.
   - Upstream surface/session logic must emit the final normalized outcome before calling this runtime.
3. **Provider-side completion semantics**
   - Example: whether a music provider treats "playback started" as completion.
   - Provider adapters and surface logic normalize this before the return event is emitted.
4. **Long-running orchestration**
   - Deferred completion, background jobs, resumable research workflows, and delayed returns are out of scope.
   - v1 handles only immediate return-time continuation.
5. **Ranking policy**
   - This runtime can request refresh, preserve, suppress, or regroup recommendations.
   - It does not score or rank candidate objects.
6. **Negative feedback policy definition**
   - It may consume already-written negative signals when deciding suppression behavior.
   - It does not define feedback event shape; that belongs to `feedback-runtime-v1.md`.
7. **Mixed layout rendering**
   - It outputs a refresh plan, not final slot rendering.
   - Layout mapping belongs to `mixed-recommendation-composer-v1.md`.

---

## 3. Product role

This runtime protects the main loop:

**ask → recommended next → execute → return → continue**

Without this runtime, every vertical will define its own:

- summary text,
- post-return behavior,
- refresh timing,
- same-task vs new-task interpretation.

That is forbidden.

---

## 4. Normative language

The key words **MUST**, **MUST NOT**, **SHOULD**, **SHOULD NOT**, and **MAY** are normative.

---

## 5. Core model

### 5.1 Input event

```swift
public struct ExecutionReturnEvent: Equatable, Sendable {
    public let sourceSurface: SurfaceKind
    public let sourceRequestId: String
    public let sourceRecommendationId: String?
    public let outcome: ContinuationOutcome
    public let payload: ReturnPayload?
    public let returnedAt: Date
}
```

### 5.2 Outcome enum

```swift
public enum ContinuationOutcome: String, Equatable, Sendable {
    case completion
    case abandon
    case dismiss
    case acceptNoEntry
}
```

### 5.3 Context input

```swift
public struct ContinuationContext: Equatable, Sendable {
    public let threadId: String
    public let activePrompt: String?
    public let activeSurface: SurfaceKind?
    public let currentRecommendationIds: [String]
    public let acceptedRecommendationId: String?
    public let latestUserIntentTags: [String]
    public let latestObjectTypes: [ObjectType]
    public let recentNegativeSignals: [RecentNegativeSignal]
}
```

### 5.4 Output

```swift
public struct ContinuationResult: Equatable, Sendable {
    public let transcriptInsertions: [ChatContinuationEvent]
    public let recommendationRefreshPlan: RecommendationRefreshPlan
    public let continuationState: ContinuationState
}
```

### 5.5 Continuation state

```swift
public enum ContinuationState: String, Equatable, Sendable {
    case sameTask
    case adjacentTask
    case newTask
}
```

---

## 6. Output contract

### 6.1 Transcript insertion

The runtime MUST produce zero or more structured transcript insertions.

It MUST NOT directly produce free-form vertical-specific prose as its primary contract.

Transcript insertion is represented as typed events:

```swift
public enum ChatContinuationEvent: Equatable, Sendable {
    case systemSummary(ContinuationSummaryBlock)
    case systemEvidence(ContinuationEvidenceBlock)
    case nextStepPrompt(ContinuationPromptBlock)
}
```

### 6.2 Recommendation refresh

The runtime MUST produce an explicit refresh plan.

It MUST NOT rely on the UI layer to infer whether recommendations should refresh.

```swift
public struct RecommendationRefreshPlan: Equatable, Sendable {
    public let mode: RefreshMode
    public let preserveAcceptedCard: Bool
    public let suppressSourceRecommendationId: String?
    public let preferredTaskFamily: TaskFamilyBias?
}

public enum RefreshMode: String, Equatable, Sendable {
    case preserve
    case refreshSameFamily
    case refreshAdjacentFamily
    case refreshNewTask
    case clear
}
```

### 6.3 Continuation classification

The runtime MUST classify the return into exactly one of:

- `sameTask`
- `adjacentTask`
- `newTask`

This classification drives transcript tone, refresh scope, and post-return UI.

---

## 7. v1 frozen behavior

### 7.1 Outcome mapping

#### A. completion

Definition: user entered the surface and finished the intended action as normalized by the surface.

Runtime behavior:

- MUST insert a `systemSummary`
- MAY insert `systemEvidence` if payload contains structured result details
- SHOULD insert a `nextStepPrompt` when a clear adjacent step exists
- MUST set `continuationState` to `sameTask` or `adjacentTask`, never `newTask` by default
- MUST set refresh mode to `refreshSameFamily` or `refreshAdjacentFamily`
- MUST preserve accepted card in terminal state when the source recommendation exists

#### B. abandon

Definition: user entered the surface but left without normalized completion.

Runtime behavior:

- MUST insert a `systemSummary`
- MUST NOT fabricate completion evidence
- SHOULD prefer `sameTask` over `newTask` unless payload explicitly indicates intent drift
- SHOULD set refresh mode to `refreshSameFamily`
- MAY preserve accepted card if it improves recovery
- MUST NOT present abandon as success

#### C. dismiss

Definition: user explicitly rejects or closes the path in a way normalized as dismiss.

Runtime behavior:

- MAY insert a short `systemSummary`
- MUST suppress the source recommendation if present
- SHOULD set refresh mode to `refreshAdjacentFamily` or `clear`
- SHOULD classify as `adjacentTask` unless thread context shows full task switch
- MUST NOT preserve the dismissed source card as active-next

#### D. acceptNoEntry

Definition: user accepted the recommendation but no execution surface session was established.

Examples:

- accepted card state in Chat, but user never entered the surface
- provider bridge failed before entry
- surface open was canceled upstream

Runtime behavior:

- MUST insert at most one lightweight `systemSummary`
- MUST NOT emit execution evidence
- SHOULD preserve accepted state only if retry is meaningful
- SHOULD set refresh mode to `preserve` or `refreshSameFamily`
- MUST NOT classify as `completion`

---

## 8. Transcript block rules

### 8.1 System summary block

Purpose: neutral structural acknowledgment of what happened.

It MUST include:

- source surface label
- normalized outcome
- user-visible short summary
- sourceRequestId
- optional sourceRecommendationId

It MUST NOT:

- invent provider-specific claims
- include marketing tone
- imply success when outcome is not completion

### 8.2 System evidence block

Purpose: structured result details that matter for next-step reasoning.

Examples:

- selected place
- chosen route
- playback target
- search result opened

It MUST only be emitted when payload contains normalized evidence fields.

It MUST NOT appear for:

- plain dismiss
- plain acceptNoEntry
- abandon without structured evidence

### 8.3 Next-step prompt block

Purpose: guide the next system action without forcing ranking.

It SHOULD be emitted only when:

- the completed task has an obvious next step,
- the failed task has a clear recovery path,
- or the user is likely still in the same task family.

It MUST be phrased as a system continuation cue, not a forced answer.

---

## 9. Return payload contract

### 9.1 Payload shape

```swift
public struct ReturnPayload: Equatable, Sendable {
    public let taskFamily: String?
    public let objectType: ObjectType?
    public let title: String?
    public let subtitle: String?
    public let structuredEvidence: [ReturnEvidenceItem]
    public let downstreamValueHint: String?
}

public struct ReturnEvidenceItem: Equatable, Sendable {
    public let key: String
    public let value: String
}
```

### 9.2 v1 rules

- Payload fields are optional.
- Runtime MUST degrade safely when payload is partial or absent.
- Payload MUST be treated as normalized UI/runtime data, not raw provider response.
- Verticals MUST normalize into this shape before calling the runtime.

---

## 10. Continuation classification rules

### 10.1 sameTask

Use `sameTask` when:

- the return still belongs to the same user intent path,
- the next likely step stays in the same task family,
- the system should help resume or continue rather than pivot.

Examples:

- route review completed, next is navigate
- music started, next is queue/controls
- web result opened, next is summarize/extract

### 10.2 adjacentTask

Use `adjacentTask` when:

- the original task is materially advanced,
- the next likely step is related but not the same surface action,
- the recommendation family should shift one level outward.

Examples:

- place chosen, next is route compare
- search answer read, next is open source or use a tool
- health metric checked, next is related explanation

### 10.3 newTask

Use `newTask` only when:

- the return clearly ends the original loop,
- the next recommendation should not be biased toward the same family,
- or the user has explicitly switched intent.

`completion` MUST NOT default to `newTask`.

---

## 11. Recommendation refresh rules

### 11.1 Refresh mode semantics

#### preserve

Keep the current recommendation set. Use when no meaningful state change occurred.

#### refreshSameFamily

Re-run recommendation generation with bias toward the same task family.

#### refreshAdjacentFamily

Re-run recommendation generation with bias toward the nearest adjacent family.

#### refreshNewTask

Re-run recommendation generation without preserving task-family continuity.

#### clear

Clear the current recommendation group. Use only when no immediate next step should be shown.

### 11.2 v1 default mapping

| Outcome        | Default refresh          | Preserve accepted card | Suppress source |
| -------------- | ------------------------ | ---------------------- | --------------- |
| completion     | refreshSameFamily        | yes                    | no              |
| abandon        | refreshSameFamily        | optional               | no              |
| dismiss        | refreshAdjacentFamily    | no                     | yes             |
| acceptNoEntry  | preserve                 | yes if retryable       | no              |

These are defaults. Context-based override is allowed only through the runtime, not per vertical.

---

## 12. Source recommendation handling

### 12.1 Preservation

The runtime MAY preserve the source recommendation card in terminal state when:

- it was accepted,
- it led to a real entry or meaningful return,
- keeping it reduces confusion.

### 12.2 Suppression

The runtime MUST suppress the source recommendation when:

- outcome is `dismiss`,
- the user explicitly indicated rejection,
- or upstream negative-feedback state requires suppression.

### 12.3 No disappearance flash

If a source recommendation is preserved, it MUST remain visible through state transition rather than disappearing instantly and being replaced in the same frame.

---

## 13. UI integration rules

### 13.1 Chat transcript

The Chat layer MUST render continuation outputs as structured system blocks.

The Chat layer MUST NOT rewrite runtime outputs into vertical-specific prose.

### 13.2 Recommended Next

The Recommended Next layer MUST consume `RecommendationRefreshPlan` as the single source of truth for post-return behavior.

It MUST NOT independently infer refresh mode from outcome.

### 13.3 Execution Surface

Execution surfaces MUST only emit normalized `ExecutionReturnEvent` and normalized `ReturnPayload`.

They MUST NOT decide transcript insertion rules themselves.

---

## 14. Telemetry hooks

This document does not define final telemetry schema, but Continuation Runtime v1 reserves the following names for alignment with `telemetry-contract-v1.md`:

- `trace_id`
- `thread_id`
- `source_request_id`
- `source_recommendation_id`
- `source_surface`
- `continuation_outcome`
- `continuation_state`
- `refresh_mode`

### 14.1 Required telemetry events

Once telemetry contract lands, the runtime MUST emit or attach events/spans for:

1. `continuation.runtime.invoked`
2. `continuation.transcript.generated`
3. `continuation.refresh.planned`

Span naming may be finalized by `telemetry-contract-v1.md`, but semantic coverage is frozen here.

---

## 15. Errors and degradation

### 15.1 Invalid input

If required input is structurally invalid:

- runtime MUST return a safe fallback result,
- runtime MUST NOT crash UI,
- runtime SHOULD emit a telemetry error once telemetry contract exists.

### 15.2 Safe fallback result

Safe fallback result for v1:

- `transcriptInsertions = []`
- `recommendationRefreshPlan.mode = preserve`
- `recommendationRefreshPlan.preserveAcceptedCard = false`
- `recommendationRefreshPlan.suppressSourceRecommendationId = nil`
- `recommendationRefreshPlan.preferredTaskFamily = nil`
- `continuationState = sameTask`

Reason: `preserve` is safer than incorrect refresh.

---

## 16. Versioning

### 16.1 What v1 freezes

v1 freezes:

1. the existence and role of `ExecutionReturnEvent`
2. the 4-case `ContinuationOutcome`
3. the 3-case `ContinuationState`
4. the existence and role of `RecommendationRefreshPlan`
5. the 5-case `RefreshMode`
6. the three transcript block types
7. the default outcome-to-refresh mapping
8. the separation between runtime output and UI rendering
9. the rule that verticals may not own post-return behavior

### 16.2 What v1.1 may add without breaking

v1.1 MAY add:

- optional payload fields
- optional evidence item metadata
- optional continuation confidence score
- optional retry hint
- optional richer adjacent-task bias metadata

These are additive only.

### 16.3 What requires v2

The following require v2:

- changing or removing any v1 enum case
- changing default semantics of completion / abandon / dismiss / acceptNoEntry
- replacing transcript block categories
- moving refresh decision ownership out of the runtime
- introducing per-vertical post-return override rules

---

## 17. Conformance requirements

An implementation conforms to Continuation Runtime v1 only if:

1. it exposes a single runtime entry point,
2. it accepts normalized return events,
3. it returns all three outputs (`transcriptInsertions`, `recommendationRefreshPlan`, `continuationState`),
4. it applies v1 outcome mappings,
5. it does not allow per-vertical bypass.

Recommended protocol:

```swift
public protocol ContinuationRuntime: Sendable {
    func handleReturn(
        event: ExecutionReturnEvent,
        context: ContinuationContext
    ) -> ContinuationResult
}
```

---

## 18. Required tests

T13 MUST exist and MUST validate at least the following:

1. completion produces summary and non-newTask
2. abandon never fabricates evidence
3. dismiss suppresses source recommendation
4. acceptNoEntry never maps to completion
5. invalid input returns safe fallback
6. transcript block types are limited to the v1 frozen set
7. refresh modes follow v1 default table
8. verticals cannot inject custom post-return prose via the runtime contract

Test failure format:

```
spec-deviation: continuation-runtime-v1.md §X — ...
```

---

## 19. Implementation notes

This section is informative, not normative.

Suggested file layout:

```
Core/
  Continuation/
    ContinuationRuntime.swift
    DefaultContinuationRuntime.swift
    ContinuationModels.swift
    ContinuationClassifier.swift
    RecommendationRefreshPlanner.swift
```

Suggested ownership split:

- `ContinuationClassifier`: outcome + context → `ContinuationState`
- `RecommendationRefreshPlanner`: outcome + context → `RecommendationRefreshPlan`
- `DefaultContinuationRuntime`: assembles transcript blocks + refresh plan + state

Feature modules must not own these decisions.

---

## 20. Open follow-ups

Deferred, not unresolved defects:

1. whether completion should carry a confidence score in v1.1
2. whether post-return retry hints belong in runtime or feedback layer
3. whether long-running research completion should re-enter via the same runtime or a deferred variant
4. whether acceptNoEntry should split into retryable vs non-retryable in v2

---

## 21. Changelog

- 2026-04-20 — v1 established.
