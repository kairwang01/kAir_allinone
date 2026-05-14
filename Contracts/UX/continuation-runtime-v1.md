# Continuation Runtime Contract — v1

Status: draft, normative
Authority split:
- This doc owns **the data envelope** (`ChatContinuationEvent`) the continuation runtime emits.
- [`Contracts/UX/continuation-transcript-visual-v1.md`](continuation-transcript-visual-v1.md) owns **how** the envelope renders.
- [`Contracts/UX/post-return-and-continuation-ux-v1.md`](post-return-and-continuation-ux-v1.md) owns **when** the envelope emits per terminal outcome.
- [`Contracts/Design/design-system-v1.md`](../Design/design-system-v1.md) owns the visual tokens used downstream.

---

## 1. Purpose, scope, non-goals

**Purpose.** Lock the data envelope the continuation runtime emits — `ChatContinuationEvent` — so that every vertical's terminal-outcome handler produces a single, well-typed shape, and downstream consumers (transcript view, scorer, telemetry) bind to one schema.

**Scope.**
- The `ChatContinuationEvent` envelope.
- Three sub-payload schemas: `SystemSummaryPayload`, `SystemEvidencePayload`, `NextStepPromptPayload`.
- Validation rules and required invariants.
- Render-eligibility per terminal outcome (imported from post-return §2.4).
- Versioning rules.
- Bridging to existing `ConversationMessage` / `ConversationToolResult` types.

**Non-goals (v1).**
- Visual rendering — owned by `continuation-transcript-visual-v1.md`.
- Outcome decision (which surface return classifies as which outcome) — owned by `post-return-and-continuation-ux-v1.md`.
- Persistence (which fields are durable in transcript history vs ephemeral) — separate concern; this contract assumes the envelope is emitted once per render-eligible outcome and is immutable once emitted.
- A SwiftUI implementation of the bridge between this envelope and `ConversationMessage`. v1 describes the bridge in §8 but does not specify code shape.
- Schema migrations from the existing post-return three-metric `ConversationToolResult` shape. The bridging in §8 is additive; the existing shape stays valid until a fully-migrated v2.
- Localization mechanics. Fields with `*Localized` companions are documented; the localization pipeline itself is out of scope.

---

## 2. The envelope: `ChatContinuationEvent`

A continuation-runtime emission is **exactly one `ChatContinuationEvent` per terminal outcome**. The envelope:

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | `String` | Yes | Stable identifier. Format: `"<surface>-continuation-<sequence>"` or `"<surface>-continuation-<topic>"`. Unique within a session. |
| `surface` | `SurfaceKind` | Yes | Which vertical emitted the event. See §2.1. |
| `outcome` | `TerminalOutcome` | Yes | Imported from post-return §1. See §2.2. |
| `renderEligible` | `Bool` | Yes | Derived: `true` iff `outcome ∈ {.completion, .abandon}`. The runtime sets this per outcome (post-return §2.4). Consumers MUST short-circuit when `false` (see §6). |
| `summary` | `SystemSummaryPayload?` | Required when `renderEligible == true`; MUST be `nil` otherwise | The `systemSummary` block payload. See §3. |
| `evidence` | `SystemEvidencePayload?` | Optional, MUST be `nil` when `renderEligible == false` | The `systemEvidence` block payload. See §4. |
| `nextStep` | `NextStepPromptPayload?` | Optional, MUST be `nil` when `renderEligible == false` | The `nextStepPrompt` block payload. See §5. |
| `createdAt` | `Date` (UTC, second precision) | Yes | Emission timestamp. |

### 2.1 `SurfaceKind` (frozen vocabulary)

```
.chat | .health | .ai | .maps | .store | .music | .video | .search
```

Identical to the surface set covered by post-return-and-continuation-ux-v1 §1.2. Adding a new surface requires a v2 of this contract AND the post-return contract in lockstep.

### 2.2 `TerminalOutcome` (frozen vocabulary)

```
.completion | .abandon | .dismiss | .acceptNoEntry
```

Identical to post-return §1. The `ExecutionOutcome.failed` provider-level case (post-return §1, last paragraph) is NOT a `ChatContinuationEvent` outcome — provider failures do not flow through the continuation runtime.

### 2.3 Envelope invariants

The runtime MUST guarantee:

1. `renderEligible == (outcome == .completion || outcome == .abandon)`.
2. If `renderEligible == true`, then `summary != nil`.
3. If `renderEligible == false`, then `summary == nil && evidence == nil && nextStep == nil`. The event still emits (for telemetry / scorer wiring) but produces zero transcript output.
4. The envelope is immutable once emitted. Updates require a new event with a new `id`.
5. `id` is unique within a session; consumers MAY use it for deduplication.

Violations are programming errors and MUST be rejected at the type system level where possible (§7), and at runtime otherwise.

---

## 3. `SystemSummaryPayload`

| Field | Type | Required | Notes |
|---|---|---|---|
| `eyebrow` | `EyebrowDescriptor?` | Optional | Surface-name eyebrow (e.g., "Maps"). When present, drives the visual contract §5.1 eyebrow slot. |
| `title` | `String` | Yes | One-line. Max 80 visual characters; runtime SHOULD reject longer values (no client-side truncation). |
| `summary` | `String` | Yes | One-sentence. Max 240 visual characters. |
| `metrics` | `[Metric]` | Yes — exactly 3 | Imports post-return §2.2 (the three-metric rule). |
| `continuityMetricIndex` | `Int` | Yes | Index into `metrics` of the continuity proof. **v1: ALWAYS `2`** (the last position). |
| `footer` | `String?` | Optional | One-line. Max 120 visual characters. |
| `outcomeTone` | `OutcomeTone` | Yes | `.completion` \| `.abandon`. Drives the visual contract §7 state-dot color. |

### 3.1 `EyebrowDescriptor`

| Field | Type | Required | Notes |
|---|---|---|---|
| `label` | `String` | Yes | Max 24 visual characters. |
| `labelLocalized` | `String?` | Optional | When present, used by the rendering layer in place of `label`. |
| `glyphName` | `String?` | Optional | SF Symbol identifier. Visual contract §5.1 permits the leading 12pt glyph slot only when this is non-nil. |

### 3.2 `Metric`

| Field | Type | Required | Notes |
|---|---|---|---|
| `key` | `String` | Yes | Short label. Max 24 visual characters. |
| `value` | `String` | Yes | Short value. Max 48 visual characters; visual layer wraps to max 2 lines. |
| `keyLocalized` | `String?` | Optional | When present, used in place of `key`. |
| `valueLocalized` | `String?` | Optional | When present, used in place of `value`. |

### 3.3 `OutcomeTone`

```
.completion | .abandon
```

`outcomeTone` MUST match the envelope's `outcome` (`.completion → .completion`, `.abandon → .abandon`). The duplicate field is intentional: the visual layer reads tone from the payload, not from the envelope, so that future runtime variants (e.g., a partial-success tone) can be added without changing the envelope's outcome enum.

### 3.4 `SystemSummaryPayload` invariants

- `metrics.count == 3`.
- `continuityMetricIndex == 2`.
- The metric at `continuityMetricIndex` is the thread-continuity proof. Its `key` (or `keyLocalized`) MUST match one of the locked vocabulary values from post-return §2.2 (e.g., `"Thread"`, `"线程"`).
- `outcomeTone` MUST equal the envelope's `outcome` value.

---

## 4. `SystemEvidencePayload`

| Field | Type | Required | Notes |
|---|---|---|---|
| `eyebrow` | `String?` | Optional | Single short label. Max 24 visual characters. |
| `eyebrowLocalized` | `String?` | Optional | When present, used in place of `eyebrow`. |
| `pairs` | `[EvidencePair]` | Yes — 1 to 6 | Per visual contract §5.2 maximum. |

### 4.1 `EvidencePair`

| Field | Type | Required | Notes |
|---|---|---|---|
| `label` | `String` | Yes | Max 32 visual characters. |
| `value` | `String` | Yes | Max 240 visual characters; visual layer wraps to max 3 lines. |
| `labelLocalized` | `String?` | Optional | |
| `valueLocalized` | `String?` | Optional | |

### 4.2 `SystemEvidencePayload` invariants

- `pairs.count ∈ [1, 6]`.
- No nesting: `label` and `value` are flat strings. Rich content (markdown, HTML, attributed strings) is forbidden.
- The runtime decides which structured fields from `ExecutionReturnPayload` (`resolvedObjectIds`, `downstreamValue`, `completionScore`, etc.) surface as evidence pairs vs stay structural-only. v1 default: most paths emit no evidence; evidence is reserved for explicit "show your work" surfaces. Per post-return §5.1, scorer-meaningful numbers (`downstreamValue`, `completionScore`) are NOT rendered.

---

## 5. `NextStepPromptPayload`

| Field | Type | Required | Notes |
|---|---|---|---|
| `eyebrow` | `String?` | Optional | Max 24 visual characters. |
| `eyebrowLocalized` | `String?` | Optional | |
| `mode` | `NextStepMode` | Yes | `.chipStrip` \| `.primaryWithSecondary`. |
| `primary` | `NextStepChip?` | Required iff `mode == .primaryWithSecondary`; MUST be `nil` otherwise | Forbidden when the envelope's `outcome == .abandon`. |
| `secondaryChips` | `[NextStepChip]` | Yes (may be empty) | Combined with `primary`, total chips in `[1, 5]`. |

### 5.1 `NextStepMode`

```
.chipStrip | .primaryWithSecondary
```

### 5.2 `NextStepChip`

| Field | Type | Required | Notes |
|---|---|---|---|
| `label` | `String` | Yes | Max 32 visual characters. |
| `labelLocalized` | `String?` | Optional | |
| `glyphName` | `String?` | Optional | SF Symbol identifier. |
| `action` | `NextStepAction` | Yes | See §5.3. |

### 5.3 `NextStepAction` (frozen vocabulary)

```
.sendPrompt(text: String)
.navigate(intent: NavigationIntent)
.dismissBlock
```

- `.sendPrompt(text:)` populates the composer with `text` and submits as if the user typed it. Max 200 visual characters in `text`.
- `.navigate(intent:)` opens a known surface intent. `NavigationIntent` is a typed enum owned by the routing layer; this contract treats it as an opaque value.
- `.dismissBlock` hides the block; no other side effect. MUST NOT mutate `pendingAcceptedRecommendation`, `recommendedMatches`, or any state in `ChatStore`.

### 5.4 `NextStepPromptPayload` invariants

- `mode == .primaryWithSecondary` → `primary != nil`.
- `mode == .chipStrip` → `primary == nil`.
- Total chips: `(primary != nil ? 1 : 0) + secondaryChips.count ∈ [1, 5]`.
- Envelope's `outcome == .abandon` → `mode == .chipStrip` (and therefore `primary == nil`). The runtime MUST enforce this; the visual layer also enforces (visual §7) but is the second line of defense.

---

## 6. Outcome render-eligibility (imported)

This table is the contract surface for "should the envelope carry sub-payloads". It mirrors post-return-and-continuation-ux-v1.md §2.4 verbatim.

| `TerminalOutcome` | `renderEligible` | `summary` | `evidence` | `nextStep` |
|---|---|---|---|---|
| `.completion` | `true` | required | optional | optional (`.chipStrip` or `.primaryWithSecondary`) |
| `.abandon` | `true` | required | optional | optional (`.chipStrip` only) |
| `.dismiss` | `false` | MUST be `nil` | MUST be `nil` | MUST be `nil` |
| `.acceptNoEntry` | `false` | MUST be `nil` | MUST be `nil` | MUST be `nil` |

The runtime emits a `ChatContinuationEvent` for ALL FOUR outcomes (including `.dismiss` and `.acceptNoEntry`) — the event itself is the telemetry record. Only the sub-payloads are gated by `renderEligible`. The visual layer reads `renderEligible` and short-circuits before constructing any block view when it is `false`.

---

## 7. Validation

The runtime MUST reject (or refuse to emit) an event when any of the following hold:

1. Envelope: `renderEligible != (outcome == .completion || outcome == .abandon)`.
2. Envelope: `renderEligible == true && summary == nil`.
3. Envelope: `renderEligible == false && (summary != nil || evidence != nil || nextStep != nil)`.
4. Summary: `metrics.count != 3`.
5. Summary: `continuityMetricIndex != 2`.
6. Summary: continuity metric's `key` (or `keyLocalized`) outside the post-return §2.2 vocabulary.
7. Summary: `outcomeTone != outcome`'s tonal class.
8. Summary: any string field exceeds its max-character limit (§3, §3.1, §3.2).
9. Evidence: `pairs.count` outside `[1, 6]`.
10. Evidence: any string field exceeds its max-character limit (§4.1).
11. Next step: `mode == .primaryWithSecondary && primary == nil`.
12. Next step: `mode == .chipStrip && primary != nil`.
13. Next step: total chip count outside `[1, 5]`.
14. Next step: `outcome == .abandon && mode == .primaryWithSecondary`.
15. Next step: `action == .sendPrompt(text:)` with `text` exceeding 200 characters.

Where the type system can express the invariant (§7.11, §7.12 via mode-tagged unions; §7.4 via fixed-arity tuples), it MUST. Where it cannot, runtime checks MUST run before emission.

The visual rendering layer MAY apply additional clamping, but runtime-side validation is authoritative.

---

## 8. Bridging to existing types

`ChatContinuationEvent` is **additive**. It does NOT replace `ConversationMessage` or `ConversationToolResult` in v1.

### 8.1 Projection rules

| Envelope state | Projection to existing types |
|---|---|
| `renderEligible == true` | Exactly one `ConversationMessage.assistant` is appended to `session.messages`. The message's `toolResults` carries the visual blocks per the visual contract §5. **Implementation choice (not contract):** the implementation MAY (a) project all three blocks into a single `ConversationToolResult` (preserving the existing post-return shape, layering blocks via internal structure), OR (b) extend `ConversationMessage` with a typed `continuationEvent` field and let the view layer read it directly. v1 leaves this choice open. Both projections MUST satisfy the visual contract §3 stacking rules. |
| `renderEligible == false` | Zero `ConversationMessage` emissions. The event is recorded for telemetry / scorer only. Matches post-return §2.4. |

### 8.2 Coexistence with the existing post-return shape

During migration, the existing post-return path (single `ConversationToolResult`, three metrics, `state: .ready`, footer) and the new `ChatContinuationEvent` path may coexist. A surface return MUST NOT emit BOTH for the same outcome — implementations choose one path per call site, migrating gradually.

The existing path is considered v0 of the runtime; the new path is v1. Both produce visually-compliant transcript blocks. v0 is permitted until the visual contract §11.1 ratification consumer-proof items are met.

### 8.3 Telemetry

`MatchingBehaviorEvent.Stage` and `ExecutionOutcome` (post-return §1) are NOT replaced by this contract. The continuation runtime emits a `ChatContinuationEvent` AND records the appropriate stage / outcome via the existing telemetry path. The two streams are parallel: stage / outcome records the behavior; `ChatContinuationEvent` records the user-visible artifact.

---

## 9. Versioning

1. Adding a new optional field to any payload — minor version, backward-compatible.
2. Tightening or relaxing string max-character limits — minor version.
3. Changing constraints (metric count, chip max, mode rules) — v2.
4. Adding a fourth sub-payload type — v2 (also requires visual v2).
5. Renaming any field — v2.
6. Changing `TerminalOutcome` or `SurfaceKind` — v2 AND coordinated bump of post-return contract.
7. Changing `NextStepAction` vocabulary — v2.

---

## 10. What this contract does NOT do

- Does NOT define the runtime's emission timing within a session lifecycle. `ChatStore.recordSurfaceReturn` / `recordMapReturn` / `dismissRecommendation` / `recordSilentSurfaceExit` decide when to emit; this contract defines what they emit.
- Does NOT define how the envelope is persisted. The session transcript stores the projected `ConversationMessage`; whether the raw `ChatContinuationEvent` is persisted alongside is an implementation choice.
- Does NOT define the `NavigationIntent` type referenced in §5.3. That's owned by the routing layer.
- Does NOT define localization mechanics. The `*Localized` companion fields exist; how the runtime sources them is out of scope.
- Does NOT cover real-time streaming (e.g., a runtime that emits partial summaries). v1 envelopes are atomic.

---

## 11. Change process & ratification

1. **Adding a new optional field.** Allowed; mark as optional in §3 / §4 / §5. Update §7 only if a new validation rule applies.
2. **Tightening a constraint.** Treated as v2; do not narrow v1.
3. **Adding a new `NextStepAction` case.** v2.
4. **Adding a new `SurfaceKind` case.** v2 lockstep with post-return contract.

### 11.1 Ratification checklist

v1 is ratified when ALL of the following are true:

- [ ] `Contracts/Design/design-system-v1.md` ratified.
- [ ] `Contracts/UX/post-return-and-continuation-ux-v1.md` exists at the canonical path (✓ already relocated).
- [ ] `Contracts/UX/continuation-transcript-visual-v1.md` ratified.
- [ ] At least one production runtime path emits a valid `ChatContinuationEvent` for `.completion`.
- [ ] At least one production runtime path emits a valid `ChatContinuationEvent` for `.abandon`.
- [ ] `.dismiss` and `.acceptNoEntry` emissions are verified to carry `renderEligible == false` and zero sub-payloads (test asserts).
- [ ] §7 validation rules enforced — at type level where possible, otherwise via a single chokepoint validator before emission.
- [ ] The §8.1 projection choice (option a or b) decided and documented in the implementation; both paths MUST NOT coexist for the same surface.

### 11.2 Implementation status (informational, not normative)

This section is an informational mirror of §11.1, populated by the
Contract Status Sweep. The §11.1 checklist remains the normative
gate; this block exists so reviewers can see which boxes have a
shipping implementation today without having to cross-reference the
repository history.

Closed by `Main D` (PR #34, merge commit `dc7407f`):

- [x] At least one production runtime path emits a valid `ChatContinuationEvent` for `.completion`. Wired via `AppBootstrap.recordSurfaceReturn(.completion)` from the toolbar "Back to chat" button + the three in-surface back buttons (Maps / AI / Store).
- [x] At least one production runtime path emits a valid `ChatContinuationEvent` for `.abandon`. Wired via the `fullScreenCover` binding nil-setter (system swipe-dismiss) calling `recordSurfaceReturn(.abandon)`.
- [x] `.dismiss` and `.acceptNoEntry` emissions verified to carry `renderEligible == false` and zero sub-payloads. Asserted by `ContinuationProjectionTests` and `AppBootstrapContinuationTests`.
- [x] §7 validation enforced via the single chokepoint in `AppBootstrap.recordSurfaceReturn(_:)` calling `ContinuationEventValidator.validate(_:)` before emit. A non-empty violation list silently aborts the emit and the transcript projection while still resetting surface state.
- [x] §8.1 projection choice (b) chosen and documented in the implementation: `ConversationMessage.continuationEvent` field + `ChatStore.recordContinuation(_:)`. Option (a) is NOT used at any call site.

Closed by `Main D.1` (PR #35, merge commit `228fb5a`):

- (no §11.1 boxes — D.1 closed §8.3 telemetry mirror boxes in `Contracts/telemetry-contract-v1.md` §8.1, not this contract's checklist.)

Still open (blockers for §11.1):

- [ ] `Contracts/Design/design-system-v1.md` ratified — blocked by the token-migration sweep enumerated in `design-system-v1.md` §6 (off-grid shadows, eyebrow tracking 1.0, legacy `HealthPalette.*` aliases, `Palette.surfaceElevated`, `tint(for:)` / `statusTint(for:)` signature decision). Separate work line; not opened.
- [ ] `Contracts/UX/continuation-transcript-visual-v1.md` ratified — the visual blocks ship, their suppression behavior is asserted, the transitive blocker is design-system-v1. Auto-unlocks once design-system-v1 ratifies.
