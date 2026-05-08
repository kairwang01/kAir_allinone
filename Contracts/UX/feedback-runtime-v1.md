# Feedback Runtime Contract — v1

Status: draft, normative
Authority split:
- This doc owns **the data envelope** (`FeedbackEvent`) the negative-feedback runtime emits, and the runtime-side write timing / propagation rules around it.
- [`Docs/design/negative-feedback-ux-v1.md`](../../Docs/design/negative-feedback-ux-v1.md) owns the **vocabulary**: the 5 frozen `MatchingFeedbackKind` cases, scope of suppression, scorer effect per kind, the `.alreadyDone` → `.completion` elevation.
- [`Contracts/UX/negative-feedback-affordance-visual-v1.md`](negative-feedback-affordance-visual-v1.md) owns the **UI**: the two affordance entry points (`✕`, `⋯`), menu structure, same-frame card removal, no toast / no undo / no transcript receipt.
- [`Contracts/UX/post-return-and-continuation-ux-v1.md`](post-return-and-continuation-ux-v1.md) owns the **post-return continuation path** that `.alreadyDone` elevates into.
- [`Contracts/Design/design-system-v1.md`](../Design/design-system-v1.md) owns the visual tokens consumed downstream.

---

## 1. Purpose, scope, non-goals

**Purpose.** Lock the data envelope the negative-feedback runtime emits — `FeedbackEvent` — and the runtime-side rules around when it emits, what it propagates, and what it is forbidden from writing. Every vertical's card-dismiss path produces a single, well-typed shape; downstream consumers (scorer, telemetry, suppression log) bind to one schema. The chat transcript stays silent.

**Scope.**
- The `FeedbackEvent` envelope (fields, types, optionality, identifiers).
- Mapping each `MatchingFeedbackKind` case to its runtime-side propagation effects (suppression scope, duration, scorer effect, completion-elevation).
- The UI-vs-runtime responsibility boundary at the dismiss tap.
- Write timing: when the event emits, in what order relative to card removal, and the prohibition on debouncing / batching.
- Interaction with the chat transcript and the Recommended Next rail.
- Validation rules and required invariants.
- Versioning rules and the bridge to existing `dismissRecommendation(_:feedback:)` API.

**Non-goals (v1).**
- The visual treatment of the affordances themselves — owned by [`negative-feedback-affordance-visual-v1.md`](negative-feedback-affordance-visual-v1.md).
- Behavior-side vocabulary (the 5 kinds, scorer-effect words like "soft negative" / "structural negative") — owned by [`negative-feedback-ux-v1.md`](../../Docs/design/negative-feedback-ux-v1.md). This contract mirrors that table for runtime alignment but is not the source of truth.
- Scoring algorithms (how the scorer consumes the event, weights, decay curves). The runtime emits the event; the scorer is opaque to this contract.
- Telemetry transport details (HTTP envelope, batching to backend, retry semantics). Field-level chain identifiers (`traceId`, `threadId`, `sourceRequestId`, `feedbackChainId`) are declared as runtime-carried; their telemetry-side schema is owned by the (future) telemetry contract.
- Per-vertical event variants — explicitly forbidden by behavior contract §6.
- Toast / snackbar / undo / receipt UI — explicitly forbidden by behavior §3.2 / §3.3 and visual §6.2.
- Transcript receipt — explicitly forbidden by behavior §3.4 and visual §6.3.
- A SwiftUI implementation of the bridge between this envelope and the existing `dismissRecommendation(_:feedback:)` call site. v1 describes the eventual emission shape; existing code may not yet emit a typed event.
- Schema migrations from the existing `MatchingBehaviorEvent` records. The bridging in §9 is additive; the existing enum-stage shape stays valid until a fully-migrated v2.
- Localization mechanics. The kind labels live with the visual contract; this contract does not localize.

---

## 2. Dependencies

| Dep | Path | Authority |
|---|---|---|
| Behavior | [`negative-feedback-ux-v1.md`](../../Docs/design/negative-feedback-ux-v1.md) | The 5 feedback kinds; scope/duration/scorer-effect per kind; the `.alreadyDone` → `.completion` elevation; silent-transcript rule; no-undo rule. |
| Visual (V3) | [`negative-feedback-affordance-visual-v1.md`](negative-feedback-affordance-visual-v1.md) | The two affordance entry points; menu order with `.dismiss` first; same-frame card removal; no-receipt UI rules. |
| Continuation runtime (analogue) | [`continuation-runtime-v1.md`](continuation-runtime-v1.md) | The runtime-contract style this doc mirrors. Continuation runtime owns post-return envelopes; this runtime owns feedback envelopes. The two are parallel, non-overlapping streams. |
| Post-return | [`post-return-and-continuation-ux-v1.md`](post-return-and-continuation-ux-v1.md) | The four terminal outcomes (`.completion`, `.abandon`, `.dismiss`, `.acceptNoEntry`) and which surface-return entry points record which. `.alreadyDone` elevates to `.completion` and re-enters the post-return path; this contract hands off to it. |
| Telemetry | *(future contract)* | The chain-identifier schema (`traceId`, `threadId`, `sourceRequestId`, `feedbackChainId`). This contract declares only what the runtime carries forward; telemetry owns the on-wire shape. |
| Tokens | [`design-system-v1.md`](../Design/design-system-v1.md) | Indirectly — this contract has no visual axis but its consumers (rail, transcript) bind to the V0 tokens. |

**Authority resolution.** When this doc disagrees with [`negative-feedback-ux-v1.md`](../../Docs/design/negative-feedback-ux-v1.md) on the kind vocabulary, scope/duration/scorer-effect, or the `.alreadyDone` elevation, the behavior doc wins. When this doc disagrees with [`negative-feedback-affordance-visual-v1.md`](negative-feedback-affordance-visual-v1.md) on the UI surface (affordance entries, menu structure, removal motion, receipt UI), the visual doc wins. When this doc disagrees with [`post-return-and-continuation-ux-v1.md`](post-return-and-continuation-ux-v1.md) on what the elevation path does after `.alreadyDone` is selected, the post-return doc wins. This doc's authority is bounded to the data envelope and the runtime-side write timing.

---

## 3. The envelope: `FeedbackEvent`

A negative-feedback emission is **exactly one `FeedbackEvent` per user tap**. The envelope:

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | `String` | Yes | Stable event identifier. Unique opaque identifier; format implementation-defined. Consumers MUST NOT parse the string. Unique within a session; consumers MAY use it for deduplication. |
| `recommendationId` | `String` | Yes | The `MatchingObject.id` of the card the user dismissed. Implementation-defined opaque string owned by the matching/recommendation subsystem; consumers MUST NOT parse it. MUST be non-empty. MUST match a recommendation that was present in `recommendedMatches` at the moment of the tap. |
| `feedbackKind` | `MatchingFeedbackKind` | Yes | One of the 5 frozen cases: `.dismiss`, `.notInterested`, `.lessLikeThis`, `.notNow`, `.alreadyDone`. See §4. |
| `surface` | `SurfaceKind?` | Optional | Which vertical originated the recommendation, if known. Same `SurfaceKind` vocabulary as [`continuation-runtime-v1.md`](continuation-runtime-v1.md) §2.1. May be `nil` for cross-surface recommendations whose origin is ambiguous. |
| `createdAt` | `Date` (UTC, second precision) | Yes | Emission timestamp. MUST NOT be in the future relative to wall-clock at validation time (see §8). |
| `traceId` | `String?` | Optional | Carried-forward identifier for tracing this user action across runtime → scorer → telemetry. Implementation-defined opaque string owned by the telemetry / tracing subsystem; consumers MUST NOT parse it. Schema details deferred to telemetry contract; this contract only declares that the runtime MUST propagate it when present on the originating context. |
| `threadId` | `String?` | Optional | The chat-thread identifier the recommendation was rendered into. Implementation-defined opaque string owned by the chat-session subsystem; consumers MUST NOT parse it. Carried for cross-stream correlation. |
| `sourceRequestId` | `String?` | Optional | Identifier of the `selectCandidates` / provider request that produced the recommendation. Implementation-defined opaque string owned by the matching-provider subsystem; consumers MUST NOT parse it. Used to attribute the feedback to the originating decision lifecycle. |
| `feedbackChainId` | `String?` | Optional | Identifier that links a series of feedback events that share a causal context (e.g., user dismisses three cards in quick succession in the same slate). Implementation-defined opaque string owned by the feedback-runtime layer; consumers MUST NOT parse it. The runtime MAY assign this; consumers MUST NOT depend on it being present. |

### 3.1 `MatchingFeedbackKind` (frozen vocabulary)

```
.dismiss | .notInterested | .lessLikeThis | .notNow | .alreadyDone
```

Identical to [`negative-feedback-ux-v1.md`](../../Docs/design/negative-feedback-ux-v1.md) §1 and the in-repo `MatchingFeedbackKind` enum. Adding a sixth case requires a v2 of behavior contract, V3 visual contract, AND this contract in lockstep.

### 3.2 `SurfaceKind` (frozen vocabulary)

```
.chat | .health | .ai | .maps | .store | .music | .video | .search
```

Identical to [`continuation-runtime-v1.md`](continuation-runtime-v1.md) §2.1. Adding a new surface requires a v2 of this contract AND the post-return / continuation-runtime contracts in lockstep.

### 3.3 Envelope invariants

The runtime MUST guarantee:

1. `recommendationId` is non-empty.
2. `feedbackKind ∈ MatchingFeedbackKind.allCases` (no extras, no aliasing).
3. `createdAt <= wallClock + small skew` at validation time. Future-dated events MUST be rejected (see §8).
4. The envelope is immutable once emitted. Updates require a new event with a new `id`.
5. `id` is unique within a session.
6. Exactly one `FeedbackEvent` is emitted per user tap. No debouncing, no batching, no coalescing — see §6.

Violations are programming errors and MUST be rejected at the type system level where possible (§8), and at runtime otherwise.

---

## 4. Feedback-kind vocabulary table

The 5 frozen `MatchingFeedbackKind` cases and their runtime-side propagation effects. This table mirrors [`negative-feedback-ux-v1.md`](../../Docs/design/negative-feedback-ux-v1.md) §1 and §4 but is expressed as runtime contract — i.e., what the envelope causes downstream, not what the user sees.

| `MatchingFeedbackKind` | Class | Scope of suppression | Duration (rolling) | Scorer effect | Elevates to `.completion`? |
|---|---|---|---|---|---|
| `.dismiss` | Negative (soft) | This exact `recommendationId` | Remainder of current decision lifecycle | Soft negative on this candidate; siblings unchanged | No |
| `.notInterested` | Negative (medium) | This `recommendationId` + near-duplicates from same source pool | Remainder of lifecycle + next 1 refresh | Medium negative; near-duplicates suppressed | No |
| `.lessLikeThis` | Negative (structural) | All candidates of the same `objectKind` | Next 3 refreshes | Down-weights the entire `objectKind` across refreshes | No |
| `.notNow` | Negative (timing) | This `recommendationId` only | Current `MatchingDaypart` only | Rebuckets to a different daypart; kind stays available | No |
| `.alreadyDone` | Completion | *(see column to right — completion path)* | *(consumed by completion)* | Records task as succeeded outside the surface; not a future-suppression signal except where post-return §5 carves an exception | **Yes — elevates to `.completion`**, hands off to [`post-return-and-continuation-ux-v1.md`](post-return-and-continuation-ux-v1.md) |

### 4.1 `.alreadyDone` is in the menu but is not a negative

**`.alreadyDone` shares the affordance surface (it lives in the same `⋯` menu and emits a `FeedbackEvent` envelope) but semantically exits the negative-feedback flow and enters the completion / post-return flow.**

`.alreadyDone` lives in the same 5-entry menu as the four negatives ([`negative-feedback-affordance-visual-v1.md`](negative-feedback-affordance-visual-v1.md) §4.2, behavior §1) but is not a suppression signal. The runtime MUST treat it as the completion path:

- The `FeedbackEvent` envelope is still emitted (so the event is in the record).
- The corresponding `MatchingBehaviorEvent.Stage` recorded alongside is `.completion`, not `.dismiss` (behavior §1 last paragraph; post-return §1.1 row C).
- The runtime hands off to the post-return continuation path. **This contract's runtime does NOT call `refreshRecommendedMatches` for `.alreadyDone`** — refresh is owned by the post-return path on the elevation side, not by this contract on the feedback side.
- Implementations MUST NOT treat `.alreadyDone` as a suppression / dismissal signal; the suppression log MUST NOT receive an entry from `.alreadyDone`. Suppression is the four negatives' job; completion is `.alreadyDone`'s job. The two are non-overlapping.

### 4.2 Rerank invariants the runtime MUST honor

- A new `FeedbackEvent` MUST NOT reshuffle siblings already on screen (behavior §4.1). Refresh produces a *new* slate; in-place reorder is forbidden.
- The dismissed candidate MUST NOT re-surface in the next refresh of the current lifecycle (behavior §4.2). The runtime is responsible for filtering it out via the suppression log even if the next ranking would otherwise produce it.
- No suppression-state indicator MUST be exposed downstream (behavior §4.3) — the envelope carries the raw kind; consumers do not produce a "muted" badge or "recently dismissed" surface.

---

## 5. UI / runtime boundary

The feedback flow has two responsibilities, drawn cleanly:

### 5.1 UI layer (owned by V3 visual contract)

The UI MUST:

1. Render the two affordances (`✕`, `⋯` menu) per [`negative-feedback-affordance-visual-v1.md`](negative-feedback-affordance-visual-v1.md) §3.
2. On tap, call the runtime entry point — today, `dismissRecommendation(_:feedback:)` on `ChatStore` (see §9).
3. Remove the card on the same frame as the tap (behavior §3.1, V3 §6.1).
4. Show **no** toast, snackbar, banner, undo button, sound, haptic, color flash, or any other receipt UI (behavior §3.2 / §3.3, V3 §6.2).
5. Write **nothing** to the chat transcript (behavior §3.4, V3 §6.3).

The UI MUST NOT:

- Construct a typed `FeedbackEvent` envelope itself. The runtime is the sole emitter.
- Validate `feedbackKind` against the vocabulary — that is the runtime's job (§8).
- Defer the call to coalesce with future taps, or batch multiple feedbacks. One tap, one runtime call.

### 5.2 Runtime layer (owned by this contract)

The runtime MUST:

1. Accept the `(MatchingObject, MatchingFeedbackKind)` pair from the UI's `dismissRecommendation` call.
2. Construct a valid `FeedbackEvent` per §3.
3. Validate the envelope per §8 before any propagation.
4. Propagate carried identifiers (`traceId`, `threadId`, `sourceRequestId`, `feedbackChainId`) from the originating context where available.
5. Write **zero** records to `session.messages` or any other transcript collection (§7).
6. Remove the recommendation from `recommendedMatches` synchronously (the existing implementation already does this).
7. For the four negatives: emit the event, then trigger a single `refreshRecommendedMatches` per dismissal (behavior §3.1, §4). See §6.2.
8. For `.alreadyDone`: emit the event, hand off to the post-return continuation path. **Do not** trigger `refreshRecommendedMatches` from this contract's runtime — refresh is owned by the post-return path.

The runtime MUST NOT:

- Surface any UI artifact. No toast, no banner, no transcript row.
- Coalesce or batch events. One tap, one event (§6.1).
- Modify the envelope after emission (§3.3 invariant 4).
- Re-order siblings already on screen (§4.2).

---

## 6. Write timing

### 6.1 Emission ordering and atomicity

The runtime MUST emit the `FeedbackEvent`:

1. **Immediately on user tap.** Not on the next run-loop tick, not after an animation, not after a confirmation step (there is no confirmation per behavior §2.1 / §2.2).
2. **Before card removal completes.** The event emission and the `recommendedMatches.removeAll { ... }` happen in the same synchronous call; the event MUST be recorded as having occurred no later than the removal. (In practice, both happen before the next frame; the contract requires only that the event is not lost if the removal succeeds.)
3. **Exactly once per user action.** No debouncing. No batching. No coalescing of rapid successive taps. If the user dismisses three cards in 200ms, the runtime emits exactly three `FeedbackEvent`s.

### 6.2 Refresh trigger

For the four negatives, the runtime MUST call `refreshRecommendedMatches` exactly once per dismissal, after event emission and after card removal. For `.alreadyDone`, the runtime MUST NOT call `refreshRecommendedMatches` from this contract's path; the elevation hands off to post-return, which owns the refresh.

### 6.3 Order of operations (normative)

For a single user tap on `✕` or any menu item except `.alreadyDone`:

1. Construct `FeedbackEvent` from `(recommendation, kind)` and ambient identifiers.
2. Validate per §8. If invalid, the runtime MUST refuse to emit and MUST NOT remove the card. The UI's tap is silently a no-op in that pathological case (this is a programming error, not a user-facing branch).
3. Record the event (scorer / telemetry sinks).
4. Remove the recommendation from `recommendedMatches` and any dependent active-section state.
5. Trigger `refreshRecommendedMatches` (per §6.2).

For `.alreadyDone`, steps 1–3 run identically, then the runtime hands off to post-return (which records `.completion` and runs its own refresh).

---

## 7. Transcript and rail interaction

### 7.1 Transcript: silent

The chat transcript receives **zero** updates from a `FeedbackEvent`:

- **Zero `ConversationMessage`** appended to `session.messages`.
- **Zero system rows** (no `.system(text:)` entry).
- **Zero `ConversationToolResult`** entries (this is not a post-return; the continuation runtime does not run for feedback).
- **Zero banners** or inline strips inside the transcript view.

This matches behavior §3.4 and visual §6.3 verbatim, and aligns with the post-return rule that `.dismiss` / `.acceptNoEntry` write nothing to chat ([`post-return-and-continuation-ux-v1.md`](post-return-and-continuation-ux-v1.md) §2.4).

For `.alreadyDone`, the transcript silence applies to **the feedback emission specifically**. The post-return continuation path that the elevation hands off to MAY write a continuation block per its own contract; the feedback runtime itself writes nothing.

### 7.2 Rail: same-frame removal, no sibling re-render

The Recommended Next rail's response to a `FeedbackEvent`:

- **Card removed same-frame** as the tap (V3 §2.1 override, V3 §6.1). No fade, slide, scale, or opacity transition.
- **Siblings collapse instantaneously** to fill the freed slot ([`mixed-recommendation-rail-visual-v1.md`](mixed-recommendation-rail-visual-v1.md) §7.2).
- **No re-render of siblings.** Cards already on screen MUST NOT be re-ordered, re-skinned, or re-keyed by a feedback event (behavior §4.1).
- **No rail-level indicator.** No "you dismissed N cards" badge, no "recently dismissed" strip, no suppression-state hint on returning cards.

After refresh (§6.2), the rail re-renders with whatever the next provider call produces. New cards render in their `default` state per [`mixed-recommendation-rail-visual-v1.md`](mixed-recommendation-rail-visual-v1.md) §6 `refreshed`.

### 7.3 No external surface receipt

The runtime MUST NOT emit any user-visible artifact outside the rail:

- No push notification.
- No system "send feedback" hook.
- No appearance in any global "feedback settings" or counter (behavior §6).
- No update to a "feedback dashboard" or insights surface.

The card vanishing IS the entire user-facing receipt. Everything else is silent telemetry.

---

## 8. Validation

The runtime MUST reject (or refuse to emit) an event when any of the following hold:

1. `recommendationId.isEmpty`.
2. `feedbackKind` is not a value of `MatchingFeedbackKind` (compile-time prevented in Swift; documented for completeness).
3. `createdAt` is in the future (after wall-clock plus a small skew tolerance, recommended ≤ 5 seconds).
4. `id.isEmpty`, or `id` collides with a previously-emitted event in the same session.
5. `recommendationId` does not correspond to a recommendation that was present in `recommendedMatches` at the moment of emission. (This catches duplicate emissions and stale taps.)
6. `surface` is non-nil and not a member of the §3.2 frozen vocabulary.
7. The envelope was constructed by anything other than the runtime layer (the UI MUST NOT construct envelopes — see §5.2). Where the call site permits, this is type-enforced; otherwise it is a code-review invariant.

Where the type system can express the invariant (§8.2 via the existing `MatchingFeedbackKind` enum; §8.6 via the existing `SurfaceKind` enum), it MUST. Where it cannot, runtime checks MUST run before propagation.

The visual rendering layer MAY apply additional clamping on the UI side (e.g., disable the menu if the recommendation is mid-removal), but runtime-side validation is authoritative.

---

## 9. Bridging to existing types

`FeedbackEvent` is **additive**. It does NOT replace the existing `dismissRecommendation(_:feedback:)` API or the existing `MatchingBehaviorEvent` records in v1.

### 9.1 Existing API

The runtime entry point today is:

```
ChatStore.dismissRecommendation(_ object: MatchingObject, feedback: MatchingFeedbackKind)
```

— a method on `ChatStore` that takes the recommendation and the kind. The UI calls this from the `✕` button and from each `⋯` menu item ([`negative-feedback-affordance-visual-v1.md`](negative-feedback-affordance-visual-v1.md) §4.3). The implementation today removes from `recommendedMatches` and writes nothing to `session.messages`. This contract describes the **eventual** shape of the event the runtime SHOULD emit when persisting / forwarding the call; existing code may not yet emit a typed `FeedbackEvent`.

### 9.2 Projection rules

| Envelope state | Projection to existing types |
|---|---|
| `feedbackKind ∈ {.dismiss, .notInterested, .lessLikeThis, .notNow}` | One `FeedbackEvent` recorded for the scorer / telemetry sinks. One corresponding `MatchingBehaviorEvent` with `Stage = .dismiss` recorded via the existing telemetry path. Zero `ConversationMessage` appended (§7.1). |
| `feedbackKind == .alreadyDone` | One `FeedbackEvent` recorded. One corresponding `MatchingBehaviorEvent` with `Stage = .completion` recorded (per behavior §1, post-return §1.1 row C). The post-return continuation path then runs and MAY produce its own `ChatContinuationEvent` per [`continuation-runtime-v1.md`](continuation-runtime-v1.md). |

**Implementation choice (not contract):** the implementation MAY (a) construct a full typed `FeedbackEvent` value at the call site and forward it to a single sink, OR (b) extend `MatchingBehaviorEvent` with the additional carried-identifier fields and emit only one record. v1 leaves this open; both are visually-and-behaviorally identical to the user. The §14.1 ratification checklist tracks the choice being made and documented.

### 9.3 Coexistence with the existing `MatchingBehaviorEvent` shape

During migration, the existing `MatchingBehaviorEvent` path (records stage / outcome via the existing telemetry path) and the new `FeedbackEvent` path may coexist. A single user tap MUST NOT produce two semantically-different events — the two paths describe the same emission from different angles, not two separate emissions. Implementations choose one source-of-truth representation; the other is computed.

The existing path is considered v0 of the runtime; the new path is v1. Both produce identical user-visible outcomes (silent transcript, same-frame card removal, refreshed rail).

### 9.4 Telemetry

Chain-identifier fields (`traceId`, `threadId`, `sourceRequestId`, `feedbackChainId`) declared in §3 are carried by this runtime but their on-wire schema, redaction, and persistence are owned by the (future) telemetry contract. This contract's job is to declare that the runtime MUST propagate them when present on the originating context, not to specify how the telemetry pipeline serializes them.

---

## 10. What this contract does NOT do

- Does NOT define the visual treatment of the affordances or the menu — owned by [`negative-feedback-affordance-visual-v1.md`](negative-feedback-affordance-visual-v1.md).
- Does NOT define the kind vocabulary or the scorer-effect labels (`"soft negative"`, etc.) — owned by [`negative-feedback-ux-v1.md`](../../Docs/design/negative-feedback-ux-v1.md).
- Does NOT define scoring algorithms. The runtime emits the event; the scorer's weights, decay curves, and re-rank machinery are out of scope.
- Does NOT define a transcript receipt for feedback. **Zero** transcript rows are written; this is a hard rule, not a v1 deferral.
- Does NOT define a toast, snackbar, banner, undo button, sound, or haptic. **Forbidden** by behavior §3.2 / §3.3 and visual §6.2.
- Does NOT define per-vertical event variants. **Forbidden** by behavior §6 — Maps cannot emit a `MapsFeedbackEvent` shape, Music cannot emit a `MusicFeedbackEvent` shape; one envelope serves all surfaces.
- Does NOT define telemetry transport details (HTTP envelope, backend batching, retry semantics). The chain-identifier fields are declared; their wire format is owned by the (future) telemetry contract.
- Does NOT cover real-time streaming or partial-state envelopes. v1 envelopes are atomic — one tap, one event, immutable once emitted.
- Does NOT cover negative-feedback affordances on continuation transcript blocks. Transcript blocks have their own dismiss/acceptNoEntry rules in [`continuation-transcript-visual-v1.md`](continuation-transcript-visual-v1.md) §7.
- Does NOT redefine the four terminal outcomes. `.alreadyDone`'s elevation to `.completion` is owned by [`post-return-and-continuation-ux-v1.md`](post-return-and-continuation-ux-v1.md) §1.1 row C; this contract only declares the hand-off.

---

## 11. Versioning

1. Adding a new optional field to `FeedbackEvent` (e.g., a new chain identifier) — minor version, backward-compatible.
2. Tightening or relaxing string-length / timestamp-skew tolerances — minor version.
3. Changing constraints on existing fields (making an optional field required, narrowing a range) — v2.
4. Adding a sixth `MatchingFeedbackKind` case — v2 of behavior contract, V3 visual contract, AND this contract in lockstep.
5. Removing or renaming any field — v2.
6. Changing `SurfaceKind` — v2 AND coordinated bump of [`continuation-runtime-v1.md`](continuation-runtime-v1.md) and [`post-return-and-continuation-ux-v1.md`](post-return-and-continuation-ux-v1.md).
7. Changing the §4 vocabulary table (scope / duration / scorer-effect per kind) — v2 of behavior contract first; this contract bumps after.
8. Changing the §6 write-timing rules (introducing batching, debouncing, multi-tap coalescing) — v2.
9. Changing the §7 transcript-silence rule (allowing any transcript artifact) — v2 of behavior contract first; this contract follows.

---

## 12. What this contract does NOT do (consolidated forbidden list)

This consolidates the prohibitions across §1, §5, §7, §10 into a single forbidden list for review checklists.

- No transcript receipt of any kind — zero `ConversationMessage`, zero system rows, zero `ConversationToolResult`.
- No toast / snackbar / banner / undo button / inline strip / sound / haptic / screen flash.
- No per-vertical event variant.
- No batching, debouncing, or coalescing of rapid successive taps.
- No reshuffling of on-screen siblings as a side effect of a feedback event.
- No "recently dismissed" list, no global feedback settings page, no feedback counter / dashboard.
- No suppression-state indicator on returning cards.
- No UI-layer construction of `FeedbackEvent` envelopes — runtime is the sole emitter.
- No call to `refreshRecommendedMatches` for `.alreadyDone` from this contract's runtime — the elevation path owns refresh.
- No mutation of an emitted envelope. Updates require a new event with a new `id`.

---

## 13. Implementation gap (current main)

*Dated 2026-05-08. This section is descriptive, not normative — it documents the known gap between this contract's MUST rules and the current `main`-branch implementation. The contract above is authoritative; the implementation will catch up.*

Known gap as of 2026-05-08:

- The current `ChatStore.dismissRecommendation(_:feedback:)` removes the card from `recommendedMatches` but does NOT yet call `refreshRecommendedMatches` for the four negatives. The provider stub deliberately defers the refresh call.
- This gap is tracked in §14.1's ratification checklist (the existing item about refresh-once-per-dismissal will only pass after a real provider with suppression-log support lands).
- The gap is documentation of reality, NOT a contract loosening — §6.2 above says MUST; the implementation will catch up before ratification.

---

## 14. Change process & ratification

1. **Adding a new optional field.** Allowed; mark as optional in §3. Update §8 only if a new validation rule applies.
2. **Tightening a constraint.** Treated as v2; do not narrow v1.
3. **Adding a sixth `MatchingFeedbackKind` case.** v2 of behavior contract, V3 visual contract, AND this contract in lockstep.
4. **Adding a new `SurfaceKind` case.** v2 lockstep with [`continuation-runtime-v1.md`](continuation-runtime-v1.md) and [`post-return-and-continuation-ux-v1.md`](post-return-and-continuation-ux-v1.md).
5. **Allowing a transcript receipt.** Forbidden in v1; v2 of behavior contract first.
6. **Allowing a toast / undo / receipt UI.** Forbidden in v1; v2 of behavior contract and V3 visual contract first.
7. **Re-tuning the §4 vocabulary table.** v2 of behavior contract first; this contract bumps after.

### 14.1 Ratification checklist

v1 is ratified when ALL of the following are true:

- [ ] [`Contracts/Design/design-system-v1.md`](../Design/design-system-v1.md) ratified.
- [ ] [`Contracts/UX/negative-feedback-affordance-visual-v1.md`](negative-feedback-affordance-visual-v1.md) ratified.
- [ ] [`Docs/design/negative-feedback-ux-v1.md`](../../Docs/design/negative-feedback-ux-v1.md) frozen at v1 (✓ already frozen 2026-04-20).
- [ ] At least one production runtime path emits a valid `FeedbackEvent` for each of the four negatives (`.dismiss`, `.notInterested`, `.lessLikeThis`, `.notNow`).
- [ ] At least one production runtime path emits a valid `FeedbackEvent` for `.alreadyDone` AND hands off to the post-return continuation path (which records `.completion`).
- [ ] An automated test asserts no `ConversationMessage` is appended after `dismissRecommendation` for any of the 5 kinds (silent transcript, behavior §3.4, this contract §7.1).
- [ ] An automated test asserts the dismissed card is removed from `recommendedMatches` synchronously (behavior §3.1, this contract §6.3 step 4).
- [ ] An automated test asserts `refreshRecommendedMatches` is called exactly once per dismissal for the four negatives (this contract §6.2; tracks closure of the I3 deferred-behavior flag).
- [ ] An automated test asserts `refreshRecommendedMatches` is NOT called from this runtime for `.alreadyDone` (the elevation path owns refresh; this contract §4.1, §6.2).
- [ ] §8 validation rules enforced — at type level where possible, otherwise via a single chokepoint validator before emission.
- [ ] The §9.2 projection choice (option a or b) decided and documented in the implementation; both paths MUST NOT coexist for the same call site.
- [ ] No new tokens or contract clauses introduced by feedback runtime ratification.
