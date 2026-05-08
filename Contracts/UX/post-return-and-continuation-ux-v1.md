# Post-Return & Continuation UX v1

**Status**: Frozen (2026-04-20).
**Scope**: Defines what happens in the **chat home** after a user leaves an Execution Surface (Maps, Music, Video, Health, AI, Store, Search when wired) and comes back, plus how Recommended Next behaves across the four terminal outcomes. This is a **binding** over the existing shell — no new surface, no new card primitive, no new trust-pill, no new feedback kind. It freezes the *behavior* a user sees after every return so Maps / Music / Search / any future vertical cannot each invent their own post-return story.

This doc sits below:

- [`../../Docs/design/super-app-visual-system-v1.md`](../../Docs/design/super-app-visual-system-v1.md) — visual source of truth.
- [`../../Docs/design/chat-home-and-recommended-next-spec-v1.md`](../../Docs/design/chat-home-and-recommended-next-spec-v1.md) — Layer 1 (chat) + Layer 4 (Recommended Next) container.
- [`../../Docs/design/execution-surface-framework-v1.md`](../../Docs/design/execution-surface-framework-v1.md) — the 7-region surface contract.
- [`../../Docs/design/action-card-component-inventory.md`](../../Docs/design/action-card-component-inventory.md) — card primitive inventory.

If anything here disagrees with those, **the shell specs win**. Post-return UX cannot invent a new chat message style, a new toast, a new "results" panel, a new card kind, or a new refresh rule per vertical. It can only select from what the shell already exposes.

---

## 1. The four terminal outcomes (frozen set)

Every time a recommendation or an execution surface ends, the chat home treats it as one of exactly four terminal outcomes. No fifth outcome exists. No vertical may add one.

| #  | Outcome               | Trigger                                                                                                       | `MatchingBehaviorEvent.Stage` emitted | `ExecutionOutcome` emitted         | User action             |
| -- | --------------------- | ------------------------------------------------------------------------------------------------------------- | ------------------------------------- | ----------------------------------- | ----------------------- |
| A  | **completion**        | User entered a surface, something useful happened, user returned through `Back to chat`.                     | `.completion`                          | `.completed` (wasSuccessful) / `.partial` | Implicit (returnToChat) |
| B  | **abandon**           | User entered a surface but left without producing a usable session (e.g., Music/Video with no playback), OR the surface was closed silently (swipe-to-dismiss etc.), OR Chat/Maps early-return paths. | `.abandon`                             | `.abandoned`                        | Explicit or silent exit |
| C  | **dismiss**           | User never entered the surface; they hit `✕` / selected a `MatchingFeedbackKind` on the card.                 | `.dismiss` (or `.completion` if feedback is `.alreadyDone`) | *(no ExecutionReturnPayload — no surface opened)* | Explicit on card        |
| D  | **accept-no-entry**   | User tapped `Accept` on the card but never actually reached the surface (routing aborted, app backgrounded, surface not yet wired, etc.). | `.accept` stage already recorded; no subsequent `.completion` / `.abandon` arrives | *(deferred until follow-up)*        | Implicit (state orphan) |

`ExecutionOutcome` has a fourth case, `.failed`, reserved for provider-level breakages (e.g., a surface crashed during entry). The chat post-return path today does not emit `.failed` — the four user-visible outcomes above are all the chat UX treats as terminal. T10 locks all four enum cases so nothing silently grows the vocabulary.

### 1.1 Outcome → who records it

- **A (completion)**: `ChatStore.recordSurfaceReturn(from:dashboard:healthSession:)` (for Health / AI / Music / Video / Store) or `ChatStore.recordMapReturn(from:)` (for Maps). For Music/Video specifically, if the returning context has **no** session, the same entry point instead records **B (abandon)** (see `surfaceReturnStage`).
- **B (abandon)**: `ChatStore.recordSilentSurfaceExit(_:)` for swipe-style exits, OR `recordSurfaceReturn` when Music/Video return without a session, OR the Chat/Maps early-return branch of `recordSurfaceReturn` (which no-ops because Maps has its own path and Chat never "returned" anywhere).
- **C (dismiss)**: `ChatStore.dismissRecommendation(_:feedback:)`. Stage is `.dismiss` for four of the five feedback kinds; `.alreadyDone` elevates to `.completion` because the user is telling us the *task* succeeded outside our UI.
- **D (accept-no-entry)**: Detected by the presence of `pendingAcceptedRecommendation` without a matching completion/abandon within the session. This state is cleared by `beginDecisionLifecycle`, by the next `dismissRecommendation`, or by the next successful return.

### 1.2 Every surface lands in exactly one outcome

| Surface | Completion path                                      | Abandon path                                         | Dismiss path                      | Accept-no-entry path                 |
| ------- | ---------------------------------------------------- | ---------------------------------------------------- | --------------------------------- | ------------------------------------ |
| Maps    | `recordMapReturn(from:)` — always `.completion` (Maps returns only when the user explicitly returns) | `recordSilentSurfaceExit(.maps)`                     | Recommended Next card dismiss     | Accepted, navigation aborted          |
| Music   | `recordSurfaceReturn` with non-nil `musicSession`     | `recordSurfaceReturn` with nil session, OR silent exit | Recommended Next card dismiss     | Accepted, surface never presented     |
| Video   | `recordSurfaceReturn` with non-nil `videoSession`     | `recordSurfaceReturn` with nil session, OR silent exit | Recommended Next card dismiss     | Accepted, surface never presented     |
| Health  | `recordSurfaceReturn` (always `.completion`)          | `recordSilentSurfaceExit(.health)`                   | Recommended Next card dismiss     | Accepted, permission flow cancelled   |
| AI      | `recordSurfaceReturn` (always `.completion`)          | `recordSilentSurfaceExit(.ai)`                       | Recommended Next card dismiss     | Accepted, surface hidden before entry |
| Store   | `recordSurfaceReturn` (always `.completion`)          | `recordSilentSurfaceExit(.store)`                    | Recommended Next card dismiss     | Accepted, surface hidden before entry |
| Search  | *(v1+ wiring)* — same shape as Music when SearchSession is non-nil | *(v1+ wiring)* — same shape as Music when nil         | Recommended Next card dismiss     | Accepted, surface hidden before entry |

**Hard rule**: no vertical may add a fifth terminal branch. If we need a new one, this doc gets versioned and T10 updates — not a per-vertical shim.

---

## 2. The post-return chat message (the only UI unit that writes back)

When A (completion) or B (abandon via `recordSurfaceReturn` with no session) fires, the chat transcript receives **exactly one** assistant message that carries **exactly one** `ConversationToolResult`. No vertical may render anything else into the transcript on return — no toast, no banner, no second assistant message, no inline chart. The transcript is the durable record; ephemeral UX belongs on the surface, not in chat.

### 2.1 Structure (frozen)

```swift
ConversationMessage.assistant(
    text: <one-line acknowledgement — "Back in chat.">,
    tags: [<SurfaceName>, <"Back in chat" | "返回聊天">],
    toolResults: [
        ConversationToolResult(
            id: <"<surface>-return"|"<surface>-return-<topic>"|"maps-return-summary">,
            title: <"<Surface> wrote back to chat" | "<Surface> 已回写线程">,
            summary: <one sentence — evidence or result>,
            state: .ready,                     // always .ready for return blocks (never .error)
            metrics: [ <exactly 3 ConversationToolMetric> ],
            footer: <one sentence — policy or continuity reassurance>
        )
    ]
)
```

### 2.2 The three-metric rule

Every post-return `ConversationToolResult` carries **exactly three** metrics. Not two, not four. The metric keys per surface are locked:

| Surface | Metric 1 (subject)        | Metric 2 (evidence class)           | Metric 3 (continuity)                             |
| ------- | ------------------------- | ----------------------------------- | -------------------------------------------------- |
| Maps    | `Task` / `任务`            | `Thread` / `线程` (kept)             | `Return` / `返回` (Complete / 已完成)               |
| Music   | `Track` / `曲目`           | `Mode` / `模式`                      | `Thread` / `线程` (Original thread kept)            |
| Video   | `Title` / `标题`           | `Category` / `类别`                  | `Thread` / `线程` (Original thread kept)            |
| Health  | `Topic` / `主题`           | `Data` / `数据` (Local Apple Health) | `Thread` / `线程` (Original thread kept)            |
| AI      | `Primary` / `主运行时`     | `Health` / `健康` (grounding state)  | `Thread` / `线程` (Original thread kept)            |
| Store   | `Focus` / `焦点`           | `Catalog` / `目录`                   | `Thread` / `线程` (Original thread kept)            |
| Search  | `Kind` / `类别`            | `Source` / `来源` (AI-synthesized in v0) | `Thread` / `线程` (Original thread kept)         |

Metric 3 is always continuity — the single sentence that proves we did **not** start a new thread. This is load-bearing for the super-app story: "leaving a surface never forks your conversation."

### 2.3 Abandon's message variant

Music/Video abandon (no session) **still** writes back a `ConversationToolResult` with the same three-metric shape, but:

- `state` is `.ready` (not `.error`; leaving without playing is not an error — it's an intentional outcome).
- `summary` uses a language-appropriate "nothing to return" sentence (e.g., `<Surface> closed without a session`).
- Metric 3 (continuity) remains `Thread: Original thread kept`.

Silent abandon (`recordSilentSurfaceExit`) does **not** write anything to the transcript. It records the stage for the scorer but leaves the chat UI untouched — because the user didn't actively return, they simply closed the surface. Writing an assistant message in that case would be noise.

In the current implementation, Music and Video's "abandon via return with no session" path renders `state: .ready` with a continuity message. A future refactor may switch that path to `.warning` to visually mark an abandoned-yet-acknowledged return; T10 does **not** lock the state enum case for abandon because `ConversationToolResultState` only has three cases (`.ready`, `.working`, `.warning`) and any of the three would be valid interpretations. What T10 *does* lock is: the metric count (3), the continuity metric presence, and the one-message-per-return rule.

### 2.4 Dismiss and accept-no-entry write nothing

- **Dismiss (C)**: The card disappears from Recommended Next. No chat message is appended — the dismissal is the receipt. This is load-bearing for `negative-feedback-ux-v1.md` §3 (no "we heard you" receipts in the transcript).
- **Accept-no-entry (D)**: Nothing is written. `pendingAcceptedRecommendation` is retained only until the next lifecycle begins; no follow-up message is ever synthesized.

---

## 3. Recommended Next refresh — timing, count, retention

Every terminal outcome hits `refreshRecommendedMatches(seedPrompt:)` **exactly once**, with one exception (dismiss, which also calls it but does so in the dismiss handler itself). No outcome calls it zero times; no outcome calls it multiple times in a row.

### 3.1 Refresh timing (frozen)

| Outcome              | Calls `refreshRecommendedMatches` | `seedPrompt` argument                              | Rationale                                                                               |
| -------------------- | --------------------------------- | --------------------------------------------------- | --------------------------------------------------------------------------------------- |
| A (completion)       | Yes — at end of `recordSurfaceReturn` / `recordMapReturn` | `context.section.title` (or `task.summaryForChatReturn()` for Maps)                    | The section title biases the next recommendation slate toward "adjacent follow-up" rather than restart. |
| B (abandon, explicit) | Yes — same path as A              | Same as A                                           | Even abandon refreshes — the user is back in chat and the slate is stale.               |
| B (abandon, silent)  | **No**                             | *(n/a — no chat message, no new slate)*             | Silent exit doesn't re-enter chat home; forcing a refresh would shuffle cards under the user's thumb. |
| C (dismiss)          | Yes — at end of `dismissRecommendation` | *(no seed)*                                      | Dismiss is explicit, so user is looking at chat home; refresh restores the slot with a non-dismissed candidate. |
| D (accept-no-entry)  | **No**                             | *(n/a — nothing is being returned from yet)*        | Accept without entry is a pending state; refreshing would re-roll the card the user just said yes to. |

### 3.2 Slate size (frozen)

`RetrievalCandidateProvider.selectCandidates` caps at **3 per `objectKind`** and **3 per `sourcePool`**. Every Recommended Next slate after a refresh obeys this cap — the rail renders whatever the provider returns (typically 2–5 cards), never more than the cap allows. No vertical may increase its own cap to grab more slots.

### 3.3 Retention rules

- **Accepted card (prior to terminal outcome)**: `activeRecommendationBySection[section]` holds it. It is removed from the map on return (any of A/B), so re-entering the same section after return is a *new* decision lifecycle.
- **Accepted card (after completion)**: No on-screen persistence in Recommended Next — the card is gone the next refresh. The *evidence* of acceptance lives in the chat transcript as the post-return `ConversationToolResult` (§2). The transcript is the durable history; the rail is ephemeral.
- **Accepted card (after abandon)**: Same as completion — gone after refresh. The rail does not show a "try again" version of the same card; the provider is free to re-surface the same `objectKind` but must return a *fresh* candidate (different id).
- **Dismissed card**: Removed immediately from `recommendedMatches` and `activeRecommendationBySection`. Never re-surfaced in the same decision lifecycle (tracked by `behaviorLog` — the scorer sees the dismiss event and downweights).
- **Accept-no-entry card**: Held in `pendingAcceptedRecommendation` until `beginDecisionLifecycle` clears it. Not re-rendered in the rail (it's already been accepted); not written to the transcript (no return happened).

### 3.4 What the refresh does *not* do

- Does **not** animate. A rebuild replaces the slate — there is no per-card entry/exit animation, per the visual system's "no vertical-specific animation" rule.
- Does **not** introduce empty states. If `recommendedMatches` is empty after refresh, the rail is simply absent — no "We're fresh out of suggestions" message, because that is a chat-home responsibility and Round 7 does not change chat home's empty-state contract.
- Does **not** write to the transcript. Refresh is a Recommended Next event, not a chat-thread event.

---

## 4. Same-task continuation vs new-task judgment

After a return, the next chat message the user sends is classified as **same-task continuation** or **new-task**. This judgment is made by `ConversationIntentEngine.handlePrompt(_:threadId:pendingMapTask:runtime:)` (plus the Maps-specific `MapsIntentRouter`). The post-return UX must reflect that classification in three ways:

### 4.1 Same-task continuation (user is continuing)

Signals: prompt starts with "and", "also", "but", contains a follow-up referent ("that", "it", "those"), OR `MapsIntentRouter` returns a non-nil `pendingTask` that updates rather than restarts.

UX consequences:
- The post-return `ConversationToolResult` from §2 is still rendered (history is history), but the **next** recommendation slate is seeded with the prior surface title — biasing follow-up toward the same vertical.
- No "New task" system note is written.
- `pendingMapTask` / `pendingAcceptedRecommendation` are retained.

### 4.2 New-task (user pivoted)

Signals: prompt triggers a different intent (Music prompt after Maps return, Health topic after Music return, etc.), OR `MapsIntentRouter` decides the prompt is not a Maps continuation.

UX consequences:
- A fresh decision lifecycle begins (`replaceActiveLifecycle: true` can be passed when the caller knows this is a hard pivot; by default, `refreshRecommendedMatches` just seeds anew).
- `pendingAcceptedRecommendation` is cleared when the new lifecycle is opened.
- No "You started a new task" system note is written — the pivot is implicit. The *absence* of continuation signals **is** the evidence.

### 4.3 The rule: continuation vs new-task is never *declared* in the UI

The super-app does not render an explicit "continuing" or "new task" badge, strip, banner, or pill. The signal is carried *structurally* by whether the next recommendation slate echoes the prior vertical (continuation) or pivots (new-task). Declaring it textually would pressure the user into justifying context changes — the opposite of the super-app's promise.

**Hard rule**: no vertical may add a "same task" / "new task" visual cue. T10 locks this.

---

## 5. How a return payload becomes summary / evidence / next-step prompt

`ChatStore.executionReturnPayload(for:candidate:stage:metrics:)` builds an `ExecutionReturnPayload` on every A or B outcome. The payload is a structured value with three roles; all three flow into the post-return experience.

| Role         | Field on `ExecutionReturnPayload`                                         | UX destination                                                                                     |
| ------------ | ------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| **Summary**  | `returnContextDelta.summary`                                              | The `summary` field of the post-return `ConversationToolResult` (§2).                              |
| **Evidence** | `returnContextDelta.resolvedObjectIds`, `returnContextDelta.downstreamValue`, `returnContextDelta.completionScore` | Scorer weights for the next slate — they bias what Recommended Next offers next, but are *not* rendered visually. |
| **Next-step**| `returnContextDelta.addedIntentTags`                                      | Passed into the next decision lifecycle via `pendingReturnContextState` → `beginDecisionLifecycle` — these tags influence intent scoring without ever appearing in chat. |

### 5.1 Why evidence is not rendered

The payload carries numbers (`downstreamValue`, `completionScore`) that are meaningful to the matcher but **not** to the user. Rendering them would force verticals into their own "we scored this 0.72" block — exactly the per-vertical visual fork this doc exists to prevent. Evidence stays structural; summary stays textual.

### 5.2 Why `addedIntentTags` are not rendered

Intent tags like `.navigation`, `.focus`, `.health` let the matcher bias next recommendations. Surfacing them as visible "labels" would turn every post-return message into a tag cloud and invite each vertical to add its own taxonomy. Tags are policy, not UX.

---

## 6. What this doc does **not** do

- Does **not** add a new `ConversationToolResult` state. The three existing `ConversationToolResultState` cases (`.ready`, `.working`, `.warning`) already cover every case. Post-return blocks are always `.ready`.
- Does **not** add a new `ConversationMessage` kind. All post-return blocks are `.assistant`.
- Does **not** add a toast layer, snackbar, or ephemeral banner. Everything persistent lives in the transcript; everything ephemeral stays on the surface.
- Does **not** add a "return history" rail or "recently from X" list anywhere. Chat home's layer set is Layers 1 / 4 / 6 per `chat-home-and-recommended-next-spec-v1.md` — Round 7 does not introduce a new layer.
- Does **not** add per-vertical post-return animation, haptic, or sound. If a future vertical wants a transition cue, it belongs on the execution surface side of the boundary (pre-return), not in chat.
- Does **not** change `MatchingFeedbackKind`, `MatchingBehaviorEvent.Stage`, `ExecutionOutcome`, or `ConversationToolResultState`. Those are the frozen vocabularies Round 7 *depends on* — changing them would require updating every existing test.

---

## 7. Verification — the T10 lock test

A single new test suite locks Post-Return & Continuation UX v1:

**T10 `PostReturnContinuationUXTests`** — asserts every supported vertical returns through the same structural shape and that Recommended Next refreshes obey §3.

Checks (minimum):

1. **Four terminal outcomes exist and no more** — `MatchingBehaviorEvent.Stage` contains `.completion`, `.abandon`, `.dismiss`, `.accept` (plus `.click`, `.impression` for lifecycle tracking). Any new stage breaks T10.
2. **Every `recordSurfaceReturn` path (Health, AI, Music, Video, Store) produces a `ConversationMessage.assistant` with exactly one `ConversationToolResult` and exactly three metrics** — same structural shape across verticals.
3. **`recordMapReturn` produces the same structural shape** — one assistant message, one `ConversationToolResult`, three metrics, continuity metric last.
4. **Silent exit produces zero chat messages** — abandoning Maps without `returnToChat` must not append to `session.messages`.
5. **Refresh timing** — `refreshRecommendedMatches` is called exactly once per A/B/C outcome and zero times for silent B and D (verified via a counter wrapper in the test harness).
6. **Accepted card removed after return** — after any A/B, `activeRecommendationBySection[section]` is nil for that section.
7. **Continuity metric present on every return block** — metric 3 across all seven surface kinds reads `Thread` / `线程` and asserts the thread is kept.
8. **No "Same task" / "New task" declarative UI** — the post-return message's `tags` field contains `<Surface>` and a back-to-chat marker only; no continuation-class tag is emitted.

T10 runs at startup alongside T1–T9. The startup banner becomes `[T10 Post-Return Continuation UX Tests] passed=… failed=…`.

### 7.1 Which older tests gain coverage

- **T3 `MatchingKernelTests`** already locks the stage vocabulary and the feedback kind vocabulary; T10 references that lock rather than re-asserting it.
- **T7 / T9 shell-reuse suites** already prove per-vertical surfaces don't fork; T10 proves the *post-return* story doesn't fork either.

---

## 8. Review checklist

- [ ] Every terminal outcome maps to exactly one of {completion, abandon, dismiss, accept-no-entry}.
- [ ] Every A/B return writes one and only one `ConversationMessage.assistant` carrying one `ConversationToolResult` with exactly 3 metrics.
- [ ] Metric 3 is a continuity metric on every surface.
- [ ] Silent abandon writes nothing to the transcript.
- [ ] Dismiss writes nothing to the transcript.
- [ ] Accept-no-entry writes nothing to the transcript and nothing to the rail.
- [ ] `refreshRecommendedMatches` is called exactly once on A/B/C and zero times on silent B / D.
- [ ] No vertical renders a "same task" / "new task" visual cue.
- [ ] No per-vertical animation, haptic, or sound on return.
- [ ] T10 passes 8/8 in the startup banner.

---

## 9. Version history

| Date       | Change                                                                                                    |
| ---------- | --------------------------------------------------------------------------------------------------------- |
| 2026-04-20 | v1 frozen. 4 terminal outcomes × 7 surfaces × 1 post-return message shape × 3-metric rule × refresh timing matrix. |
