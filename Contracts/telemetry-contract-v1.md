# kAir Telemetry Contract — v1

Status: draft, normative
Authority split:
- This doc owns **the identifier vocabulary and span / event naming** for the chat-first user request lifecycle (Chat home → RecommendationRail → execution surface → Transcript continuation → Feedback).
- [`Contracts/UX/continuation-runtime-v1.md`](UX/continuation-runtime-v1.md) owns the `ChatContinuationEvent` envelope. This contract layers identifiers onto that envelope; it does not redefine its fields.
- [`Contracts/UX/mixed-recommendation-rail-visual-v1.md`](UX/mixed-recommendation-rail-visual-v1.md) owns rail-visual states; this contract names the events that fire during those states.
- [`Contracts/UX/negative-feedback-affordance-visual-v1.md`](UX/negative-feedback-affordance-visual-v1.md) owns feedback affordance behavior; this contract names the events those affordances emit.
- [`Contracts/Design/design-system-v1.md`](Design/design-system-v1.md) is irrelevant to telemetry payloads except where token names appear in event metadata. This contract does not redefine tokens.

---

## 1. Purpose, scope, non-goals

**Purpose.** Lock the identifier vocabulary and span / event naming used to describe the end-to-end user request lifecycle so every emitter (chat home, the conversation intent engine, the recommendation rail, execution surfaces, the continuation runtime, the feedback affordances) records the same correlation keys against the same span / event names. With this contract, a single user prompt produces one observable chain that downstream tooling (scorer, analytics, replay) can reconstruct without re-litigating who issued which id.

**Scope.**
- Seven identifier fields that propagate across the lifecycle (§3).
- Span / event naming conventions for chat submission, rail impressions and dismissals, execution-surface entry, transcript continuation append, and feedback events (§4).
- End-to-end chain rules — explicit forward and backward links from Chat → RecommendationRail → Transcript → Feedback (§5).
- Versioning rules for vocabulary changes (§7).
- Change process and ratification (§8).

**Non-goals (v1).**
- The transport / wire format. This contract names ids and events; the transport (OpenTelemetry, a custom JSONL sink, an in-app analytics provider, or none yet) is implementation choice.
- The persistence schema. Whether ids are stored alongside the projected `ConversationMessage`, in a separate telemetry table, or only in process memory is out of scope.
- Sampling, redaction, or privacy filters. v1 does not specify which events are PII-bearing and which are sampled. Privacy review is a separate workstream.
- The scorer's interpretation of these events. The scorer consumes the chain; it does not own the vocabulary.
- Cross-platform telemetry (watchOS, macOS). v1 covers iOS surfaces only.
- Crash / stability telemetry. v1 covers user-initiated lifecycle events only.
- Performance traces (frame time, GPU stalls). v1 is request-lifecycle oriented; performance instrumentation is a separate axis.
- Localization of event names. Span / event names are ASCII identifiers; user-facing copy is not part of telemetry.
- A `MatchingBehaviorEvent` field-by-field mapping. The continuation runtime contract §8.3 says the existing telemetry stream stays parallel to `ChatContinuationEvent`. v1 names ids that bridge them; it does not specify the existing stream's payload.
- A SwiftUI implementation. v1 is normative; instrumentation lags.

**v1 freeze means.**
- The seven identifier names in §3 are public vocabulary. They will not be renamed during the v1 lifetime.
- The span / event names in §4 are public vocabulary. They will not be renamed during the v1 lifetime.
- The chain rules in §5 (which id propagates from where to where) will not be loosened. New ids may be added; existing forward / backward links will not be broken.
- Values for individual ids (formats, lifetimes) may be re-tuned per §3 within their stated scope, but never silently.

---

## 2. Dependencies

| Dep | Path | Authority |
|---|---|---|
| Continuation envelope | [`Contracts/UX/continuation-runtime-v1.md`](UX/continuation-runtime-v1.md) | The `ChatContinuationEvent` shape. v1 telemetry layers ids onto every emission of this envelope; it does not redefine its fields. |
| Rail visual | [`Contracts/UX/mixed-recommendation-rail-visual-v1.md`](UX/mixed-recommendation-rail-visual-v1.md) | Per-card states (`default` / `accepted` / `dismissed` / `loading` / `suppressed` / `refreshed`). v1 telemetry names the events that fire during impressions, accepts, and dismissals. |
| Feedback visual | [`Contracts/UX/negative-feedback-affordance-visual-v1.md`](UX/negative-feedback-affordance-visual-v1.md) | The `✕` button, the `⋯` menu, and the 5 `MatchingFeedbackKind` entries. v1 telemetry names the event each affordance emits. |
| Behavior — recommendation slate | [`Docs/design/mixed-recommendation-layout-v1.md`](../Docs/design/mixed-recommendation-layout-v1.md) | What renders in the rail. v1 telemetry assumes its slot tiers and slate caps. |
| Behavior — negative feedback | [`Docs/design/negative-feedback-ux-v1.md`](../Docs/design/negative-feedback-ux-v1.md) | The 5 feedback kinds, the silent-transcript rule, the no-undo rule. v1 telemetry preserves silence in the transcript and emits the feedback event independently. |

**Authority-split path note (reviewer clarity).** `Contracts/Design/...` and `Contracts/UX/...` are the canonical paths for ratified visual / runtime contracts — this is the new contract surface. `Docs/design/...` paths are the older location for behavior contracts that have NOT yet been relocated. Where this doc references both (e.g., the rail visual at `Contracts/UX/mixed-recommendation-rail-visual-v1.md` alongside the rail behavior at `Docs/design/mixed-recommendation-layout-v1.md`), assume the `Contracts/...` path is canonical going forward; the `Docs/design/...` reference is to the un-relocated original. This contract itself does NOT migrate any files; the path split exists only to disambiguate which document is canonical for reviewers.

**Authority resolution.** When this doc disagrees with the continuation envelope on field shape, the envelope wins. When this doc disagrees with the rail-visual or feedback-visual contract on **when** an event fires, the visual contract wins. This doc's authority is bounded to **what the event is named** and **which identifier fields it carries**.

---

## 3. Identifier vocabulary

The seven fields below are the v1 identifier vocabulary. Every span / event named in §4 carries some subset of these. The chain rules in §5 specify which subset is required for which event.

Identifiers are opaque strings unless otherwise stated. Format constraints are a SHOULD; uniqueness within the stated scope is a MUST.

| Field | Definition | Lifetime | Issuer | Consumers |
|---|---|---|---|---|
| `trace_id` | Root-level chain identifier across the entire user request lifecycle. Every event from the originating chat prompt through downstream rail impressions, surface sessions, transcript continuations, and feedback events MUST carry the same `trace_id`. | One user request lifecycle. Begins at `chat.prompt.submit`; ends when no further descendant events can fire (no live rail card, no live surface session, no pending continuation, no feedback chain). Lifetime is one user request lifecycle; bounding policies (TTL, rotation) are an implementation concern owned by the runtime that issues the id, not by this contract. | Chat home (the composer / `ChatStore`) at the moment a user prompt is committed. Issued exactly once per submitted prompt. | Every emitter in §4. |
| `thread_id` | The conversation thread. Identifies the persistent chat session the prompt belongs to. Multiple prompts in the same thread share `thread_id` but have distinct `trace_id`s. | Lifetime of the thread. Stable across app restarts when the thread is restored from persistence. | The chat session manager (the layer that owns `ConversationMessage` history). Issued when the thread is created. | Every emitter in §4. The transcript renderer uses it to scope which thread the continuation block appends to. |
| `recommendation_id` | One card in `recommendedMatches`. Identifies a single rendered `MatchingObject` instance within a slate. Two slates emitted from the same prompt but in different refresh cycles MUST issue distinct `recommendation_id`s for what is otherwise the "same" `MatchingObject`. | One slate render of one card. A `recommendation_id` becomes inert when the card leaves `recommendedMatches` (via accept, dismiss, suppression, or refresh-replacement). | The `ConversationIntentEngine` / recommendation provider at the moment a slate is materialized for the rail. Issued exactly once per (slate, slot) pair. | The rail (impression, accept, dismiss events), the execution-surface entry event, the continuation runtime, and the feedback events. |
| `source_request_id` | The originating user prompt that produced the rec slate. For an event fired during or after a rail interaction, `source_request_id` traces back to the `chat.prompt.submit` whose response slate the card belongs to. | Same as `trace_id` for the originating prompt. | Chat home, at `chat.prompt.submit`. Stamped onto every downstream `recommendation_id`-carrying event. | Rail events, surface events, continuation event, feedback event. |
| `source_recommendation_id` | Parent rec when this rec is chained / derived. Set on a `recommendation_id` when the slate that produced it was generated in response to acceptance, dismissal, or completion of a prior rec — i.e., the new slate is *because of* the previous card, not *because of* a fresh prompt. When the slate is the direct child of a `chat.prompt.submit` (no parent rec), `source_recommendation_id` is unset / `nil`. | Same as the new `recommendation_id`. | The recommendation provider, at the moment the new slate is materialized when a parent rec was the trigger. | Rail events, continuation event, feedback event for the new slate. Establishes the backward link from a new card to its causal predecessor. |
| `surface_session_id` | One execution-surface session — a single `Maps` trip, a single `Music` play session, a single `Health` detail-view visit, etc. Distinct from `recommendation_id`: a single accepted rec opens a single surface session, but a user can re-enter the same `recommendation_id` (if the rec persists across refreshes) to begin a new `surface_session_id`. | One end-to-end surface entry → return / abandon / dismiss / acceptNoEntry. Begins at `surface.<kind>.enter`; ends at the corresponding `ChatContinuationEvent` emission (or its silent equivalent for non-render-eligible outcomes). | The execution surface itself, on entry. | The surface's own internal events (out of scope), the continuation event, and any feedback event raised against the rec that opened the session. |
| `feedback_chain_id` | Links a feedback event back to its rec lineage. Stamped on a `feedback.event` and on any subsequent rerank / refresh slate that the scorer attributes to that feedback. Allows a downstream slate's `recommendation_id`s to be traced back not just to a `source_recommendation_id` but to the specific feedback signal that caused the rerank. | One feedback signal's downstream effect window. Begins at `feedback.event`; ends when the next slate refresh that consumed this signal has fully propagated (i.e., when no more `recommendation_id`s carry this `feedback_chain_id` as their cause). | The feedback affordance (the `✕` button or the `⋯` menu), at the moment `dismissRecommendation(_:feedback:)` runs. Issued exactly once per feedback submission. | The recommendation provider's rerank logic; downstream rail events (impression, accept, dismiss) on slates produced by the rerank. |

### 3.1 Identifier invariants

The runtime MUST guarantee:

1. `trace_id` is unique per user request lifecycle. Two distinct `chat.prompt.submit` events MUST issue distinct `trace_id`s.
2. `thread_id` is stable across all events in a thread. A single thread MAY produce arbitrarily many `trace_id`s but only one `thread_id`.
3. `recommendation_id` is unique per (slate, slot). Two cards in the same slate MUST have distinct `recommendation_id`s. The same `MatchingObject` rendered in two distinct slates (e.g., before and after a refresh) MUST have distinct `recommendation_id`s.
4. `source_request_id` MUST equal the `trace_id` of the originating `chat.prompt.submit` for the slate this event belongs to.
5. `source_recommendation_id` MUST be `nil` when the slate is the direct child of a `chat.prompt.submit`. It MUST be non-`nil` when the slate is the causal child of a prior rec interaction (accept, dismiss, completion). The runtime MUST NOT set `source_recommendation_id` to a value the issuer never produced.
6. `surface_session_id` is unique per surface entry. Re-entering the same `recommendation_id` after a return MUST issue a new `surface_session_id`.
7. `feedback_chain_id` is unique per feedback submission. The same affordance tap MUST NOT issue two `feedback_chain_id`s; two distinct taps MUST issue two distinct `feedback_chain_id`s.

Violations are programming errors and MUST be caught at the type system level where possible (typed wrappers around opaque strings) and at runtime otherwise.

### 3.2 Identifier opacity rule

Consumers MUST NOT parse identifier strings. The format is implementation choice (UUID, ULID, hash, scoped sequence). Two events with the same `recommendation_id` MUST be treated as referencing the same card; consumers MUST NOT attempt to derive ordering, time, or attribution from the bytes of an id.

---

## 4. Span / event naming

Every emitter in the lifecycle uses the names below. Names are dotted-lowercase ASCII; segments separate by `.`. The `<kind>` placeholder in `surface.<kind>.enter` is filled with one of the `SurfaceKind` values from `continuation-runtime-v1.md` §2.1 (`chat`, `health`, `ai`, `maps`, `store`, `music`, `video`, `search`).

### 4.1 Frozen vocabulary

| Event name | Fires when | Required ids | Optional ids |
|---|---|---|---|
| `chat.prompt.submit` | The user commits a prompt in chat home. The composer fires this exactly once per committed prompt. | `trace_id`, `thread_id` | — |
| `intent.decide` | The `ConversationIntentEngine` produces a decision (intent kind, surface routing, whether to surface a slate). Fires once per `chat.prompt.submit`. | `trace_id`, `thread_id`, `source_request_id` | — |
| `rail.slate.materialize` | The recommendation provider produces a slate for the rail (1, 2, or 3 cards). Fires once per slate render — either as the first slate after `chat.prompt.submit` or as a refresh after a downstream event. | `trace_id`, `thread_id`, `source_request_id` | `source_recommendation_id` (set when this slate is the child of a prior rec, not of a fresh prompt); `feedback_chain_id` (set when this slate is the rerank child of a prior `feedback.event`) |
| `rail.card.impression` | A card is rendered in the rail. Fires once per (slate, slot) when the card first becomes visible in the view tree. | `trace_id`, `thread_id`, `recommendation_id`, `source_request_id` | `source_recommendation_id`, `feedback_chain_id` |
| `rail.card.accept` | The user taps the primary `Accept` action on a card. Fires once per acceptance. | `trace_id`, `thread_id`, `recommendation_id`, `source_request_id` | `source_recommendation_id`, `feedback_chain_id` |
| `rail.card.dismiss` | The user taps `✕` or selects a `MatchingFeedbackKind` from `⋯`. **Fires alongside `feedback.event`**, never as a standalone event. The two events share `trace_id` / `thread_id` / `recommendation_id`; the `feedback.event` adds the `feedback_chain_id`. `feedback.event` is emitted exactly once per dismissing user action; `rail.card.dismiss` is the UI-side paired event for the same action, **not a second semantic action**. | `trace_id`, `thread_id`, `recommendation_id`, `source_request_id` | `source_recommendation_id`, `feedback_chain_id` |
| `surface.<kind>.enter` | An execution surface opens in response to an accepted rec or a direct intent route. Fires once per surface entry. | `trace_id`, `thread_id`, `surface_session_id` | `recommendation_id` (set when the surface was opened by accepting a rec; unset when intent routed directly without going through the rail), `source_request_id`, `source_recommendation_id`, `feedback_chain_id` |
| `surface.<kind>.return` | The surface returns control to chat (any of `.completion`, `.abandon`, `.dismiss`, `.acceptNoEntry`). Fires once per surface entry. | `trace_id`, `thread_id`, `surface_session_id` | `recommendation_id`, `source_request_id`, `source_recommendation_id`, `feedback_chain_id` |
| `transcript.continuation.append` | The continuation runtime emits a render-eligible `ChatContinuationEvent` (`outcome ∈ {.completion, .abandon}`) AND the transcript appends the projected `ConversationMessage`. Per `continuation-runtime-v1.md` §6, non-render-eligible outcomes do NOT fire this event — they fire `transcript.continuation.silent` instead. | `trace_id`, `thread_id`, `surface_session_id` | `recommendation_id`, `source_request_id`, `source_recommendation_id`, `feedback_chain_id` |
| `transcript.continuation.silent` | The continuation runtime emits a non-render-eligible `ChatContinuationEvent` (`outcome ∈ {.dismiss, .acceptNoEntry}`). The transcript appends nothing; this event records the silent decision for telemetry. | `trace_id`, `thread_id`, `surface_session_id` | `recommendation_id`, `source_request_id`, `source_recommendation_id`, `feedback_chain_id` |
| `feedback.event` | The user submits feedback (the `✕` button or any `⋯` menu entry). Fires once per submission. **Always co-fires with `rail.card.dismiss`.** Per `negative-feedback-ux-v1.md` §3.4, the transcript receives no update; this event is the sole feedback record. `feedback.event` is emitted exactly once per dismissing user action; `rail.card.dismiss` is its UI-side paired event for the same user action, **never a separate dismissal**. | `trace_id`, `thread_id`, `recommendation_id`, `source_request_id`, `feedback_chain_id` | `source_recommendation_id` |

### 4.2 Naming rules

1. **Lifecycle stage first.** The first segment is the lifecycle stage (`chat`, `intent`, `rail`, `surface`, `transcript`, `feedback`). Consumers can filter by stage without parsing the rest.
2. **Subject second.** The second segment is the subject (`prompt`, `decide`, `slate`, `card`, `<kind>`, `continuation`, `event`).
3. **Action third.** The third segment is the action (`submit`, `materialize`, `impression`, `accept`, `dismiss`, `enter`, `return`, `append`, `silent`, `event`). Single-segment actions are permitted when the subject is the action (`feedback.event`).
4. **No vertical-specific event names.** Maps does not emit `surface.maps.trip.complete`; that's covered by `surface.maps.return` plus the continuation envelope's `ExecutionReturnPayload`. Per-vertical event names are forbidden in v1; the lifecycle vocabulary is closed.
5. **No per-token event names.** A design-token change (e.g., a card flips to `accepted` chrome) does NOT fire a telemetry event. Only user-initiated and runtime-decision events are in the v1 vocabulary.
6. **Underscores in id field names; dots in event names.** `trace_id` (not `trace.id`); `chat.prompt.submit` (not `chat_prompt_submit`). The two namespaces never collide.

### 4.3 Forbidden event names (v1)

- No `rail.card.click`. Use `rail.card.accept` (primary action) or `rail.card.dismiss` (the `✕` / `⋯` paths).
- No `rail.refresh`. Refresh produces a new `rail.slate.materialize` followed by N new `rail.card.impression` events; "refresh" itself is not a discrete telemetry event.
- No `feedback.menu.open`. Opening the `⋯` menu without selecting an entry produces no event. Per `negative-feedback-affordance-visual-v1.md` §4, only the selection commits.
- No `chat.prompt.draft` or any pre-submit composer telemetry. The lifecycle starts at `chat.prompt.submit`.
- No `surface.<kind>.<vertical-specific-action>`. Per §4.2 rule 4.
- No `transcript.message.render`. Per-message render telemetry is performance instrumentation, which is out of v1 scope.

### 4.4 Co-fire invariant

Every `feedback.event` corresponds to exactly one `rail.card.dismiss`, and vice versa: both share `trace_id` / `thread_id` / `recommendation_id` / `source_request_id`, and consumers MUST treat them as a single dismissal event with two complementary records — `rail.card.dismiss` is the UI confirmation receipt, `feedback.event` is the runtime feedback record. Implementations MUST NOT increment any "dismissals + feedback events" combined counter that would double-count the same action.

---

## 5. End-to-end chain (Chat → Rail → Transcript → Feedback)

The chain rules below specify how each id propagates across the lifecycle. Forward links travel from cause to effect; backward links travel from effect to cause. v1 freezes both directions for every transition.

### 5.1 Stage transitions

| From → To | Forward link (cause → effect) | Backward link (effect → cause) |
|---|---|---|
| Chat → Intent | `chat.prompt.submit` issues `trace_id`. `intent.decide` carries the same `trace_id` and stamps `source_request_id := trace_id`. | `intent.decide.source_request_id == chat.prompt.submit.trace_id` |
| Intent → Rail (slate materialize) | `intent.decide` triggers (or refrains from triggering) `rail.slate.materialize`. The slate carries the parent `trace_id` and `source_request_id`. When the slate is a refresh caused by a prior rec interaction, it ALSO carries `source_recommendation_id` set to the parent rec's `recommendation_id`. When the slate is a rerank caused by a prior feedback event, it ALSO carries `feedback_chain_id` set to that feedback's id. | `rail.slate.materialize.source_request_id` traces to the originating `chat.prompt.submit`; `rail.slate.materialize.source_recommendation_id` traces to the parent `recommendation_id`; `rail.slate.materialize.feedback_chain_id` traces to the originating `feedback.event` |
| Rail (slate) → Rail (cards) | `rail.slate.materialize` issues N new `recommendation_id`s (1 ≤ N ≤ 3 per `mixed-recommendation-rail-visual-v1.md` §4). Each `rail.card.impression` carries one of those ids plus the slate's `trace_id`, `source_request_id`, optional `source_recommendation_id`, optional `feedback_chain_id`. | `rail.card.impression.recommendation_id` is one of the ids issued by the parent `rail.slate.materialize`; the impression's `source_request_id`, `source_recommendation_id`, `feedback_chain_id` MUST equal those on the slate event. |
| Rail (card) → Surface | `rail.card.accept` triggers `surface.<kind>.enter`. The surface event issues a new `surface_session_id` AND inherits `trace_id`, `thread_id`, `recommendation_id`, `source_request_id`, optional `source_recommendation_id`, optional `feedback_chain_id` from the accept event. When `intent.decide` routes directly to a surface without going through the rail, `surface.<kind>.enter` carries `trace_id`, `thread_id`, `surface_session_id` but NO `recommendation_id`. | `surface.<kind>.enter.recommendation_id` (when present) traces to the accepting `rail.card.accept`. The surface's `source_request_id` traces to the originating prompt either via the rail card or directly via `intent.decide`. |
| Surface → Transcript (render-eligible) | `surface.<kind>.return` with `outcome ∈ {.completion, .abandon}` triggers `transcript.continuation.append`. The append event carries the surface's `trace_id`, `thread_id`, `surface_session_id`, optional `recommendation_id`, `source_request_id`, `source_recommendation_id`, `feedback_chain_id`. | `transcript.continuation.append.surface_session_id` traces to the parent `surface.<kind>.enter` (and in turn to the originating prompt and rail card, if any). |
| Surface → Transcript (silent) | `surface.<kind>.return` with `outcome ∈ {.dismiss, .acceptNoEntry}` triggers `transcript.continuation.silent`. Same id set as the render-eligible variant. The transcript appends NO `ConversationMessage` (per `continuation-runtime-v1.md` §6). | Identical to the render-eligible variant; the difference is only in whether a transcript message is produced. |
| Transcript continuation → next slate (sourced from continuation) | If the transcript continuation block surfaces a `NextStepPromptPayload` chip and the user taps a `.sendPrompt` chip, that tap fires a NEW `chat.prompt.submit` with a NEW `trace_id` — the chain does NOT extend; the second prompt is its own root. The `thread_id` is preserved. **Cross-trace linkage** (e.g., "this prompt was suggested by the prior continuation") is NOT captured by ids in v1; it MAY be captured by an event metadata field in v2. | n/a in v1 |
| Rail (card) → Feedback | `rail.card.dismiss` co-fires with `feedback.event`. The two share `trace_id`, `thread_id`, `recommendation_id`, `source_request_id`, optional `source_recommendation_id`. The `feedback.event` adds `feedback_chain_id`. | `feedback.event.recommendation_id` traces to the dismissed card; `feedback.event.feedback_chain_id` is a new id issued at the moment of the tap. |
| Feedback → next slate (rerank) | When a `feedback.event` causes the recommendation provider to refresh / rerank the rail, the new slate's `rail.slate.materialize` event carries `feedback_chain_id` set to the originating `feedback.event.feedback_chain_id`. Every `rail.card.impression` produced by that slate inherits the `feedback_chain_id`. | `rail.slate.materialize.feedback_chain_id` traces back to the originating `feedback.event`. |

### 5.2 Required propagation matrix

For every event in §4.1, the matrix below specifies which ids MUST appear (✓), which MUST NOT appear (✗), and which are optional (•).

| Event | trace_id | thread_id | recommendation_id | source_request_id | source_recommendation_id | surface_session_id | feedback_chain_id |
|---|---|---|---|---|---|---|---|
| `chat.prompt.submit` | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ |
| `intent.decide` | ✓ | ✓ | ✗ | ✓ | ✗ | ✗ | ✗ |
| `rail.slate.materialize` | ✓ | ✓ | ✗ | ✓ | • | ✗ | • |
| `rail.card.impression` | ✓ | ✓ | ✓ | ✓ | • | ✗ | • |
| `rail.card.accept` | ✓ | ✓ | ✓ | ✓ | • | ✗ | • |
| `rail.card.dismiss` | ✓ | ✓ | ✓ | ✓ | • | ✗ | • |
| `surface.<kind>.enter` | ✓ | ✓ | • | • | • | ✓ | • |
| `surface.<kind>.return` | ✓ | ✓ | • | • | • | ✓ | • |
| `transcript.continuation.append` | ✓ | ✓ | • | • | • | ✓ | • |
| `transcript.continuation.silent` | ✓ | ✓ | • | • | • | ✓ | • |
| `feedback.event` | ✓ | ✓ | ✓ | ✓ | • | ✗ | ✓ |

Legend: ✓ = required; ✗ = MUST be unset / not carried; • = optional, set per the chain rules in §5.1.

### 5.3 Worked example

A single end-to-end lifecycle for a Maps trip recommendation, dismissed afterwards, with one feedback rerank:

1. `chat.prompt.submit` — `trace_id=T1`, `thread_id=H7`. User asked "Where should I go to lunch?"
2. `intent.decide` — `trace_id=T1`, `thread_id=H7`, `source_request_id=T1`.
3. `rail.slate.materialize` — `trace_id=T1`, `thread_id=H7`, `source_request_id=T1`. Issues `recommendation_id`s `R1`, `R2`, `R3`.
4. `rail.card.impression` × 3 — one per card, each with its own `recommendation_id` (`R1` / `R2` / `R3`) and the slate's `trace_id` / `thread_id` / `source_request_id`.
5. User taps Accept on R1: `rail.card.accept` — `trace_id=T1`, `thread_id=H7`, `recommendation_id=R1`, `source_request_id=T1`.
6. `surface.maps.enter` — `trace_id=T1`, `thread_id=H7`, `recommendation_id=R1`, `source_request_id=T1`, new `surface_session_id=S1`.
7. User completes the trip. `surface.maps.return` — same ids as step 6.
8. `transcript.continuation.append` — same ids as step 7. Transcript appends a continuation block.
9. User dismisses R2 from the rail with the `⋯` menu choosing `Less like this`:
   - `rail.card.dismiss` — `trace_id=T1`, `thread_id=H7`, `recommendation_id=R2`, `source_request_id=T1`.
   - `feedback.event` — same plus new `feedback_chain_id=F1`.
10. The provider reranks. `rail.slate.materialize` — `trace_id=T1`, `thread_id=H7`, `source_request_id=T1`, `feedback_chain_id=F1`. Issues `recommendation_id`s `R4`, `R5`.
11. `rail.card.impression` × 2 — `recommendation_id=R4` / `R5`, each carrying `feedback_chain_id=F1`.

The chain is: T1 → all 11 events; H7 → all 11 events; R1 → events 4 (one of three impressions), 5, 6, 7, 8; R2 → events 4 (one of three impressions), 9; S1 → events 6, 7, 8; F1 → events 9 (the feedback half), 10, 11.

Backward link verification: from event 11's `rail.card.impression` carrying `R4` and `feedback_chain_id=F1`, a consumer can trace to `feedback.event=F1` (event 9), to `rail.card.dismiss` on `R2` (event 9), to the slate that issued R2 (event 3), to `chat.prompt.submit=T1` (event 1).

---

## 6. What this contract does NOT do

- Does NOT define the wire format. Whether events ship as OpenTelemetry spans, JSONL records, app-internal messages, or are not yet shipped at all is implementation choice.
- Does NOT define sampling. v1 names every event as if every event is captured. Sampling, when introduced, MUST NOT change the chain rules in §5.
- Does NOT define redaction or PII handling. v1 names ids as opaque strings; it does not specify which event metadata fields contain user content.
- Does NOT define retention. How long a `trace_id`'s events are stored, queried, or discarded is out of scope.
- Does NOT specify retention windows, rotation cadences, or TTLs for any identifier — these are implementation policy.
- Does NOT define the scorer's interpretation. The scorer reads `feedback_chain_id` and `source_recommendation_id` to attribute downstream slate quality; this contract only guarantees the ids are present and correct.
- Does NOT cover non-lifecycle events (crash reports, frame-time traces, network errors, MCP tool latency). Each is a separate axis with its own vocabulary.
- Does NOT cover continuation-runtime field-level mappings. The envelope's fields (per `continuation-runtime-v1.md` §3 / §4 / §5) are payload, not telemetry vocabulary; v1 names which event carries the envelope, not which fields the envelope contains.
- Does NOT cover the existing `MatchingBehaviorEvent.Stage` / `ExecutionOutcome` telemetry path. Per `continuation-runtime-v1.md` §8.3, that path remains parallel to the continuation envelope. v1 defines the new vocabulary; the existing path is grandfathered until a v2 unifies them.
- Does NOT cover localization. Event names, id field names, and the structure of the chain are ASCII-only.
- Does NOT cover cross-platform telemetry — iOS only.
- Does NOT cover real-time streaming events (e.g., partial inference progress). v1 events are atomic.
- Does NOT cover events emitted by partner SDKs or third-party MCPs. Their telemetry is governed by their own contracts.

---

## 7. Versioning

1. Adding a new id field — minor version, backward-compatible. Existing events MAY add it as optional. The chain rules in §5 update to specify when the new id propagates.
2. Adding a new event name to §4.1 — minor version, backward-compatible. Consumers that filter on existing names are unaffected.
3. Adding a new permitted value to an existing id (e.g., a new `SurfaceKind` and therefore a new `surface.<kind>.enter` / `surface.<kind>.return` pair) — coordinated bump with `continuation-runtime-v1.md` §2.1 (which freezes the surface vocabulary). Within the lifetime of v1, this is permitted via §8 only when the surface vocabulary itself bumps; otherwise v2.
4. Tightening optional → required for an id on an existing event — v2.
5. Loosening required → optional for an id on an existing event — v2.
6. Renaming an id field — v2.
7. Renaming an event — v2.
8. Removing an event from §4.1 — v2.
9. Removing an id field — v2.
10. Changing the chain rules in §5 (e.g., adding a new forward link, breaking an existing backward link) — v2.

---

## 8. Change process

This document is contract; instrumentation is implementation. Both move through here.

1. **Adding a new id field.** Add the row to §3 with full definition + lifetime + issuer + consumers. Add the column to the §5.2 propagation matrix. State which existing events carry it as `✓` / `✗` / `•`. Ship at least one production emitter. Until an emitter ships, the field stays out of contract.
2. **Renaming or removing an id field.** v2 change. Open a v2 contract; v1 stays stable.
3. **Adding a new event.** Add the row to §4.1 with `Required ids` + `Optional ids`. Add it to the §5.2 matrix. State its position in the chain in §5.1. Ship at least one production emitter.
4. **Renaming an event.** v2 change.
5. **Re-tuning a value within a field's stated lifetime / issuer / consumers.** Permitted within the row's stated scope. Update the §3 row in this file in the same PR as the implementation change.
6. **Adding a new `SurfaceKind`.** Lockstep with `continuation-runtime-v1.md` §2.1 v2. Within v1, the §4.1 `surface.<kind>.enter` / `surface.<kind>.return` patterns expand mechanically; no v1 bump is needed if the underlying surface vocabulary has not bumped.
7. **Adding a new chain rule (cross-stage propagation).** v2 only.

### 8.1 Ratification checklist

v1 is ratified when ALL of the following are true (MVP — minimum-viable instrumentation set):

- [ ] `Contracts/UX/continuation-runtime-v1.md` ratified.
- [ ] `Contracts/UX/mixed-recommendation-rail-visual-v1.md` ratified.
- [ ] `Contracts/UX/negative-feedback-affordance-visual-v1.md` ratified.
- [ ] At least one production emitter fires `chat.prompt.submit` carrying `trace_id` and `thread_id`.
- [ ] At least one production emitter fires `rail.slate.materialize` carrying `source_request_id`.
- [ ] At least one production emitter fires `rail.card.impression` carrying `recommendation_id`.
- [ ] At least one production emitter fires `rail.card.accept`.
- [ ] At least one production emitter fires `rail.card.dismiss` co-firing with `feedback.event` (per §4.4 co-fire invariant).
- [ ] At least one production emitter fires `surface.<kind>.enter` and the matching `surface.<kind>.return`.
- [ ] At least one production emitter fires `transcript.continuation.append` (for `.completion` / `.abandon`) and `transcript.continuation.silent` (for `.dismiss` / `.acceptNoEntry`).

### 8.2 Backlog (post-v1 ratification)

These items are post-v1 strengthening — visible but not blocking ratification:

- [ ] An automated test asserts the §5.2 propagation matrix — for every event in §4.1, the required ids are present and the forbidden ids are absent.
- [ ] An automated test asserts that `feedback.event` produces NO `transcript.continuation.append` and NO `transcript.continuation.silent` (per `negative-feedback-ux-v1.md` §3.4 silent-transcript rule).
- [ ] An automated test asserts that two distinct `chat.prompt.submit` events in the same thread produce distinct `trace_id`s and identical `thread_id`s.
- [ ] An automated test asserts that re-entering the same `recommendation_id` after a return produces a new `surface_session_id`.
- [ ] At least one observed slate carries `source_recommendation_id` (slate is the causal child of a prior rec interaction); at least one other observed slate carries `feedback_chain_id` (slate is the rerank child of a prior `feedback.event`).
- [ ] No event in shipped instrumentation exists that is not named in §4.1, AND no id field is carried that is not named in §3.
