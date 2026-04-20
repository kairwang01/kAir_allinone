# Negative Feedback UX v1

**Status**: Frozen (2026-04-20).
**Scope**: Freezes the **four explicit negative feedback entry types** a user can trigger on any Recommended Next card, plus immediate UI response, post-submission rerank behavior, chat-thread receipt (if any), and suppression rules after a surface return. This is a **binding** over the existing `MatchingFeedbackKind` enum — no new feedback kind, no new enum case, no new ⋯-menu option. It freezes *behavior* so Maps / Music / Video / Search / any future vertical cannot each invent their own "tell us why" flow.

This doc sits below:

- `super-app-visual-system-v1.md` — visual source of truth.
- `chat-home-and-recommended-next-spec-v1.md` — Recommended Next container (Layer 4).
- `action-card-component-inventory.md` — `ActionCardShell` affordances (⋯ menu + ✕ dismiss).
- `mixed-recommendation-layout-v1.md` — per-card feedback rule (§5.1).
- `post-return-and-continuation-ux-v1.md` — suppression after return (§6).

If anything here disagrees with the specs above, **the shell specs win**. Negative feedback UX cannot invent a new affordance, a new dialog, a new toast, a new "why" modal, or a new enum case.

---

## 1. The four explicit negative feedback entries (frozen set)

`MatchingFeedbackKind` has exactly five cases. One (`.alreadyDone`) is not strictly *negative* — it says "task succeeded, just not here." The remaining four are the frozen **negative** vocabulary:

| # | `MatchingFeedbackKind` | Affordance       | Card menu copy (zh / en)            | Scorer effect                                                                          |
| - | ---------------------- | ---------------- | ----------------------------------- | -------------------------------------------------------------------------------------- |
| 1 | `.dismiss`             | `✕` on card head | `忽略` / `Dismiss`                   | Soft negative. Suppresses this exact candidate in the current decision lifecycle.      |
| 2 | `.notInterested`       | `⋯` → menu item  | `不感兴趣` / `Not interested`        | Medium negative. Suppresses this exact suggestion *and* similar ones until context shifts. |
| 3 | `.lessLikeThis`        | `⋯` → menu item  | `以后少推这类` / `Less like this`    | Structural negative. Down-ranks the `objectKind` for a rolling window.                  |
| 4 | `.notNow`              | `⋯` → menu item  | `现在不需要` / `Not now`             | Timing negative. De-prioritizes this timing only; the category itself stays live.       |

The fifth case, `.alreadyDone`, is treated as a *completion* path in `ChatStore.dismissRecommendation` (stage elevates to `.completion`) and is therefore covered by `post-return-and-continuation-ux-v1.md`, not here. Listing it alongside the four negatives is intentional — the card menu still offers all five in one panel, because offering four "no" answers and forcing the user to re-open the menu for "actually, done" would feel adversarial.

**Hard rule**: no new `MatchingFeedbackKind` case is allowed in v1. If a new signal is needed, it maps to one of the existing four (or five) or waits.

---

## 2. Affordance inventory (what the user can tap)

Every Recommended Next card has **exactly two** entry points for negative feedback:

### 2.1 The `✕` on the card head

- **Shape**: 28×28 hit target at the top-right of `ActionCardShell` region (1).
- **Action**: Single tap fires `.dismiss` directly.
- **No confirmation.** No "Are you sure?" dialog, no undo snackbar, no action sheet. Tapping ✕ is the confirmation.
- **Rationale**: `.dismiss` is the lowest-consequence negative. Forcing confirmation would make dismissal feel expensive and push users toward just ignoring cards, which gives the scorer no signal.

### 2.2 The `⋯` menu on the card head

- **Shape**: 28×28 hit target beside ✕. Opens a SwiftUI `Menu` (platform sheet on iOS).
- **Contents**: The five `MatchingFeedbackKind` entries in a fixed order:
  1. `忽略` / Dismiss
  2. `不感兴趣` / Not interested
  3. `以后少推这类` / Less like this
  4. `现在不需要` / Not now
  5. `已经做过了` / Already done
- **No grouping**. No submenus. No "More options" disclosure.
- **No custom-write-in**. No "Other (specify)" row. The vocabulary is the five cases, period.
- **One tap commits**. The menu closes on selection and the feedback is applied — no "submit" button.

### 2.3 What's **not** an entry point for negative feedback

- **Swipe gesture on the card**. A horizontal swipe is not wired and must not be wired — it would duplicate `✕` and invite per-platform divergence (iOS swipe-to-delete semantics).
- **Long-press on the card**. Also not wired; would conflict with accessibility long-press hints.
- **Shake-to-undo**. Explicitly not used. Undo is not part of v1 (see §3.3).
- **Pull-to-refresh**. Refresh is policy-driven (§3 of `post-return-and-continuation-ux-v1.md`), not user-initiated.
- **A "Feedback" button outside the card** (e.g., in chat home, on the rail). No such button exists.

The two entries above are the only negative-feedback vectors in v1.

---

## 3. Immediate UI response after submission

### 3.1 Card removal

The dismissed / feedbacked card is removed from the rail immediately. This is hard-coded in `ChatStore.dismissRecommendation(_:feedback:)`:

```swift
recommendedMatches.removeAll { $0.id == recommendation.id }
activeRecommendationBySection = activeRecommendationBySection.filter { _, value in
    value.id != recommendation.id
}
refreshRecommendedMatches()
```

- **No exit animation** — the card disappears on the same frame.
- **No "you dismissed X" row** replacing the card position.
- **Refresh follows**. `refreshRecommendedMatches()` repopulates the slate; the user sees whatever surviving candidates the provider returns.

### 3.2 No confirmation toast / snackbar / banner

- No "We won't show this again" banner.
- No "Got it — we'll show less like this" toast.
- No snackbar with an `Undo` button.
- No inline strip that reserves the card's old position with a success checkmark.

**Rationale**: the card vanishing *is* the receipt. Adding a toast would be pre-emptive apology for an act the user already completed. It also would duplicate affordances from the card's own dismiss menu.

### 3.3 No undo

`.dismiss`, `.notInterested`, `.lessLikeThis`, `.notNow`, and `.alreadyDone` are all non-undoable in v1. The user can re-trigger the same recommendation by issuing a new chat prompt; the scorer will re-surface the candidate once its suppression window (§4) expires. There is no per-action rewind.

**Rationale**: undo for recommendation dismissal is a trap. It either lives 5 seconds (rare to catch) or forever (grows a "recently dismissed" list that competes with Recommended Next). v1 takes neither path.

### 3.4 No chat-thread receipt

Feedback submissions do **not** write anything to the chat transcript. No assistant message, no system note, no tool result. This is the cornerstone rule that keeps chat readable:

> The transcript is the durable record of *tasks*. Dismissing a card is not a task; it is metadata. Metadata never writes to the transcript.

This is identical to the post-return spec's rule that dismiss and accept-no-entry write nothing to chat (`post-return-and-continuation-ux-v1.md` §2.4).

---

## 4. Rerank rules — what happens to the slate after submission

After the card is removed, `refreshRecommendedMatches()` rebuilds the slate through `replayLab.beginScenario` → `selectCandidates`. The scorer consumes the new behavior event (emitted by `dismissRecommendation`) and the rerank behavior per feedback kind is:

| Feedback kind     | Scope of suppression         | Duration (rolling)                   | Effect on same `objectKind`                           |
| ----------------- | ----------------------------- | ------------------------------------ | ----------------------------------------------------- |
| `.dismiss`        | This exact candidate id       | Remainder of current lifecycle       | Other `objectKind` candidates unchanged               |
| `.notInterested`  | This candidate + near-duplicates (same source pool) | Remainder of lifecycle + next 1 refresh | Near-duplicates suppressed; other kinds unchanged      |
| `.lessLikeThis`   | All candidates of this `objectKind` | Next 3 refreshes              | Entire kind down-weighted across refreshes            |
| `.notNow`         | This candidate only           | Current daypart (see `MatchingDaypart`) | Rebucketed to a different daypart; kind stays available |
| `.alreadyDone`    | *(not negative — see §1)*     | *(completion path)*                  | *(marks task complete; see post-return spec)*         |

### 4.1 Rerank never reshuffles siblings already on screen

Siblings in the current slate are not re-ordered by a new feedback event. Feedback triggers **remove + refresh**, and the refresh produces a *new* ranked slate. Re-ordering siblings in place would make the rail feel unstable under the user's thumb.

### 4.2 Rerank never re-surfaces the dismissed candidate

Even if the next refresh's ranking produces the same candidate, `selectCandidates` filters it out via the behavior log's `.dismiss` event for the current lifecycle. The candidate may re-appear after a lifecycle pivot (new task, app relaunch) — that is the intended behavior.

### 4.3 No rerank signal is ever visible

The user cannot see "this candidate is currently down-weighted." There is no "muted" list, no "recently dismissed" strip, no indicator on returning cards. Opacity is a behavior, not a visualization.

---

## 5. Post-return suppression rules

When the user returns from an execution surface (`recordSurfaceReturn` / `recordMapReturn`), the refresh that follows (§3.1 of `post-return-and-continuation-ux-v1.md`) must honor the suppression state accumulated during the prior lifecycle:

- **`.dismiss` / `.notInterested` / `.lessLikeThis` / `.notNow`** events from the prior in-chat session are still suppressing their targets when the post-return refresh runs. The user does not get "a fresh start" just because they opened a surface.
- **Exception: `.alreadyDone` on a card whose `objectKind` matches the returned surface**. If the user said "already done" on a place card then opened Maps and completed a real task, the already-done signal is *consumed* by the completion — it is not double-counted as future suppression.
- **Exception: a new-task pivot** (§4 of `post-return-and-continuation-ux-v1.md`). If `beginDecisionLifecycle` opens with `replaceActiveLifecycle: true` — i.e., the caller explicitly signals a hard pivot — the prior suppression rolls off on the next refresh. This is rare; in normal use, the suppression persists.

### 5.1 What this means visually after return

The user sees a refreshed slate in which:

- The cards they dismissed are absent (still suppressed).
- A lower-ranked candidate may have been promoted into the direct slot because a higher-ranked candidate was suppressed (rerank happened, user did not see it happen).
- No "we remembered your feedback" message appears anywhere.

---

## 6. Forbidden things (the hard no list)

Negative feedback in v1 must **not** include:

- **A "tell us more" text field.** Free-text feedback is out of scope.
- **A category picker** ("Was this too repetitive / too off-topic / too early?"). The 5 options are the vocabulary.
- **A "why this suggestion?" explainer opened from the feedback menu.** If the user wants provenance, they tap the card's primary action; there is no per-feedback "explain the explanation."
- **A rating widget** (stars, thumbs up/down, emoji reactions). The scorer does not consume these; exposing them would be performative.
- **A shake-to-report-problem gesture** or a system-level "send feedback to Apple" hook.
- **A post-feedback confirmation sound or haptic.** The card vanishing is the entire feedback event.
- **A per-vertical feedback affordance.** Maps cannot offer "Wrong address," Music cannot offer "Wrong mood," Search cannot offer "Off-topic result." These all map to one of the four existing kinds (`.notInterested`, `.lessLikeThis`, `.notNow`, `.dismiss`) or the feature waits until v2.
- **A global "feedback settings" page.** There is no place to configure "don't show me music recommendations ever." The scorer accumulates signal; aggressive permanent opt-out is not a v1 concept.
- **A feedback counter or dashboard** ("You've dismissed 12 cards this week"). Behavior is a scorer input, not a user-visible metric.

---

## 7. Verification — the T11 lock test

A single new test suite locks Negative Feedback UX v1:

**T11 `NegativeFeedbackUXTests`** — asserts the affordance inventory, the menu vocabulary, the remove-and-refresh pipeline, and the silence of the transcript.

Checks (minimum):

1. **Feedback kind cardinality is 5** — `MatchingFeedbackKind.allCases.count == 5`. No sixth case may be added.
2. **The four negatives are exactly the expected set** — `{dismiss, notInterested, lessLikeThis, notNow}`.
3. **`.alreadyDone` elevates stage to `.completion`** in `dismissRecommendation` — verified by a black-box call with the feedback kind and assertion on the emitted `MatchingBehaviorEvent.Stage`.
4. **Other four kinds emit `.dismiss` stage** — verified the same way.
5. **Dismiss removes from `recommendedMatches` and `activeRecommendationBySection`** — after `dismissRecommendation`, neither collection contains the candidate id.
6. **Dismiss triggers exactly one `refreshRecommendedMatches` call** — shared counter with T10.
7. **Dismiss writes zero messages to the transcript** — `session.messages.count` is unchanged by dismissal.
8. **The ⋯ menu vocabulary is exactly the 5 `MatchingFeedbackKind.title` strings** — compile-time witness the menu binder draws from the enum, not a hand-rolled list.
9. **No per-vertical feedback kind is added** — T11 enumerates every concrete caller of `dismissRecommendation` and asserts the feedback argument type is `MatchingFeedbackKind` (the shared enum).
10. **Post-return suppression persists through the refresh** — after a synthetic dismiss + silent-return cycle, the dismissed candidate id is not in the new slate for the current lifecycle.

T11 runs at startup alongside T1–T10. Startup banner gets `[T11 Negative Feedback UX Tests] passed=… failed=…`.

### 7.1 Which older tests gain coverage

- **T3 `MatchingKernelTests`** already locks the 5-case `MatchingFeedbackKind` vocabulary; T11 references that lock.
- **T10 `PostReturnContinuationUXTests`** already locks the silent transcript on dismiss / accept-no-entry; T11 cross-checks the same invariant from the feedback angle.

---

## 8. Review checklist

- [ ] Exactly 4 explicit negative entries: dismiss / notInterested / lessLikeThis / notNow.
- [ ] Exactly 2 affordances: the ✕ on the card head and the ⋯ menu with 5 entries.
- [ ] ✕ fires `.dismiss` without confirmation.
- [ ] ⋯ menu has the 5 `MatchingFeedbackKind` entries, frozen order, no submenus, no free-text.
- [ ] No toast / snackbar / banner / undo anywhere in the feedback flow.
- [ ] No chat-thread receipt for feedback.
- [ ] No per-vertical feedback kind or affordance.
- [ ] Rerank happens through `refreshRecommendedMatches`; siblings are not reshuffled in place.
- [ ] No visible "recently dismissed" list anywhere.
- [ ] Post-return refresh still respects prior-lifecycle suppression.
- [ ] T11 passes 10/10 in the startup banner.

---

## 9. Version history

| Date       | Change                                                                                                    |
| ---------- | --------------------------------------------------------------------------------------------------------- |
| 2026-04-20 | v1 frozen. 4 negative entries × 2 affordances × frozen 5-option menu × silent transcript × deterministic rerank. |
