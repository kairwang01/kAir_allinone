# Negative Feedback Affordance Visual Contract — v1

Status: draft, normative
Authority split:
- This doc owns **how** negative-feedback affordances render on Recommended Next cards.
- [`Docs/design/negative-feedback-ux-v1.md`](../../Docs/design/negative-feedback-ux-v1.md) owns **behavior**: the 4 negative kinds, the 2 affordance entry points, the silent-transcript rule, the rerank semantics, the no-undo rule.
- [`Docs/design/action-card-component-inventory.md`](../../Docs/design/action-card-component-inventory.md) owns the card primitive (`ActionCardShell`) and its 7-region structure — including the ✕ button and ⋯ menu glyph slots.
- [`Contracts/UX/mixed-recommendation-rail-visual-v1.md`](mixed-recommendation-rail-visual-v1.md) owns the rail container and the per-card visual states (default / accepted / dismissed / loading / suppressed / refreshed).
- [`Contracts/Design/design-system-v1.md`](../Design/design-system-v1.md) owns the underlying tokens.

---

## 1. Purpose, scope, non-goals

**Purpose.** Lock the visual treatment for the negative-feedback affordances so every vertical's cards expose the same dismiss / menu surface, the same hit targets, the same menu structure, and the same post-submission visual semantics. The behavior contract owns the four kinds and the rerank rules; this contract owns what the user sees and touches.

**Scope.**
- The two affordance entry points: `✕` button on the card head and `⋯` menu beside it.
- The menu structure (5 entries, fixed order, no submenus).
- The visual treatment of each `MatchingFeedbackKind` entry inside the menu.
- The immediate post-submission visual response (card removal, no toast, no banner).
- Confirmation / receipt state — explicitly: there is none beyond the card vanishing.
- Rail and transcript visibility of the feedback event — explicitly: silent in both surfaces.
- Token bindings to `design-system-v1.md`.

**Non-goals (v1).**
- Adding a new `MatchingFeedbackKind` case — frozen at 5 by behavior contract §1.
- Adding a new affordance type (sidebar, gesture, modal) — explicitly forbidden by behavior §2.3.
- Free-text "tell us more" UI — explicitly forbidden by behavior §6.
- Category picker, rating widget, emoji reactions — forbidden by behavior §6.
- Undo affordance — forbidden by behavior §3.3.
- Confirmation toast / snackbar / banner — forbidden by behavior §3.2.
- Transcript receipt — forbidden by behavior §3.4.
- Per-vertical variants — explicitly forbidden by behavior §6.
- I3 implementation. This contract is normative; the implementation lags.

---

## 2. Dependencies

| Dep | Path | Authority |
|---|---|---|
| Behavior | [`negative-feedback-ux-v1.md`](../../Docs/design/negative-feedback-ux-v1.md) | The 4 + 1 feedback kinds; the 2 affordance entries; rerank rules; silent transcript; no-undo. |
| Card primitive | [`action-card-component-inventory.md`](../../Docs/design/action-card-component-inventory.md) | `ActionCardShell` head region (✕ + ⋯); fixed feedback option set. |
| Rail | [`mixed-recommendation-rail-visual-v1.md`](mixed-recommendation-rail-visual-v1.md) | Per-card states (default / accepted / dismissed / etc.); slate transitions (preserve / suppress / refresh). |
| Tokens | [`design-system-v1.md`](../Design/design-system-v1.md) | Visual values (color, type, spacing, motion). |

**Authority resolution.** When this doc disagrees with `negative-feedback-ux-v1.md` on entry-point inventory, menu vocabulary, rerank, or transcript silence, the behavior doc wins. When this doc disagrees with `mixed-recommendation-rail-visual-v1.md` on container chrome or rail-level transitions, the rail doc wins. This doc's authority is bounded to the visual treatment of the affordances themselves and the per-action visual receipt.

### 2.1 Cross-contract override (normative)

**For negative-feedback dismissal, [`negative-feedback-ux-v1.md`](../../Docs/design/negative-feedback-ux-v1.md) governs over [`mixed-recommendation-rail-visual-v1.md`](mixed-recommendation-rail-visual-v1.md). Any dismissed-card fade language in V2 is superseded by this contract and MUST NOT be implemented.**

The user-initiated dismissal path (the `✕` button or any `⋯` menu selection) is the only `.dismiss` source the user can produce. This override therefore covers every user-facing dismissal in v1.

**What is superseded:**

| Superseded clause | What it said | What now applies |
|---|---|---|
| `mixed-recommendation-rail-visual-v1.md` §6 (`dismissed` state) | "Card opacity animates from `1.0` to `0` via `motion.emphasized`" | Card disappears on the same frame; no opacity transition. |
| `mixed-recommendation-rail-visual-v1.md` §7.2 | "The single permitted animation in this transition family is the leaving card's own fade when the user dismissed it." | No animation in this transition family. The leaving card uses zero motion. |

**Authority order for the user-initiated dismissal path:**

1. [`negative-feedback-ux-v1.md`](../../Docs/design/negative-feedback-ux-v1.md) §3.1 — "No exit animation — the card disappears on the same frame."
2. This contract — visual rendering of the override (see §3, §6).
3. [`mixed-recommendation-rail-visual-v1.md`](mixed-recommendation-rail-visual-v1.md) §6 / §7.2 — **superseded for this code path.**

**Normative implementation rule:**

- The card vanishes on the same frame as the menu / button tap.
- No opacity transition. No scale. No slide. No haptic. No sound.
- No motion token is consumed for the removal — neither `motion.standard` nor `motion.emphasized`.
- Adjacent cards collapse instantaneously to fill the freed slot (matches `mixed-recommendation-rail-visual-v1.md` §7.2's "instantaneously" rule for gap-collapse, which is preserved).

A separate doc-only hygiene PR will retract the V2 §6 / §7.2 fade language to keep the docs textually consistent. **That hygiene PR is not a prerequisite for this contract or its consumers** — V3 already overrides V2 for the user-initiated dismissal path; the hygiene work is documentation tidiness only.

---

## 3. Affordance inventory (the two entry points)

Behavior contract §2 freezes exactly two entries. This section binds each to visual values.

### 3.1 The `✕` button (card head, region 1)

| Property | Value | Source |
|---|---|---|
| Position | Top-right of `ActionCardShell` head, immediately right of the `⋯` menu (so they cluster) | inventory §1 |
| Hit target | `28 × 28 pt` minimum touch area | behavior §2.1 |
| Visible glyph size | SF Symbol `xmark`, `caption .semibold` weight (matches `⋯`) | inventory §2 |
| Glyph color | `Palette.textMuted` (`#82858A`) at rest | design-system-v1 §3.1 |
| Container fill | none (button blends into card head) | inventory §2 |
| Border | none | inventory §2 |
| Pressed visual | opacity `0.6` via `motion.standard` (per design-system-v1 §4.4 default→pressed pattern) | design-system-v1 §3.6 / §4.4 |
| Tap action | Single tap → fires `.dismiss`. **No confirmation dialog, no action sheet.** | behavior §2.1 |
| Accessibility label | `"Dismiss recommendation"` (or zh equivalent when localized) | inventory §6 |

The ✕ button does NOT show any state indicator before tap — no badge, no count, no warning glyph. Its visible affordance is the glyph and its hit target alone.

### 3.2 The `⋯` menu trigger (card head, region 1)

| Property | Value | Source |
|---|---|---|
| Position | Top-right of `ActionCardShell` head, immediately left of the `✕` button | inventory §1 |
| Hit target | `28 × 28 pt` minimum | behavior §2.2 |
| Visible glyph | SF Symbol `ellipsis`, `caption .semibold` | inventory §2 |
| Glyph color | `Palette.textMuted` at rest | design-system-v1 §3.1 |
| Container fill | none | — |
| Border | none | — |
| Pressed visual | opacity `0.6` via `motion.standard` | design-system-v1 §4.4 |
| Tap action | Opens a SwiftUI `Menu` (platform native sheet on iOS). See §4 for menu structure. | behavior §2.2 |
| Accessibility label | `"More feedback options"` (or zh equivalent) | inventory §6 |

The `⋯` button is visually identical to `✕` (same glyph weight, same color, same hit target, same pressed transition). Only the SF Symbol identifier differs.

### 3.3 The two affordances are visually equal in weight

- Both buttons share size, color, and pressed state.
- Neither button is "primary" relative to the other.
- The `✕` button MUST NOT be larger, brighter, or more prominent. The `⋯` button MUST NOT be subdued or hidden behind a long-press.
- They sit side-by-side in the card head with `8pt` horizontal gap (in §3.3 permitted set).

### 3.4 Forbidden affordance variants

- No swipe gesture on the card to trigger dismiss (behavior §2.3).
- No long-press on the card to open the feedback menu (behavior §2.3).
- No drag-to-archive or pull-down-to-dismiss interaction.
- No third button beyond `✕` and `⋯` (behavior §1 hard rule).
- No "Feedback" button outside the card (e.g., in the rail header, in chat home toolbar) (behavior §2.3).
- No icon-only badge that hints at suppression state ("muted", "throttled", etc.).
- No tooltip or hover popover before tap.

---

## 4. Menu structure

### 4.1 Container

The `⋯` tap opens a SwiftUI `Menu`. The menu is the platform-native action sheet on iOS — typography, spacing, and presentation animation are all owned by the platform; this contract does NOT override them.

### 4.2 Entries (frozen 5, fixed order)

The menu offers exactly the 5 `MatchingFeedbackKind` entries from behavior contract §2.2 in the locked order:

| # | `MatchingFeedbackKind` | English label | zh label |
|---|---|---|---|
| 1 | `.dismiss` | `Dismiss` | `忽略` |
| 2 | `.notInterested` | `Not interested` | `不感兴趣` |
| 3 | `.lessLikeThis` | `Less like this` | `以后少推这类` |
| 4 | `.notNow` | `Not now` | `现在不需要` |
| 5 | `.alreadyDone` | `Already done` | `已经做过了` |

Entry #1 (`.dismiss`) is the same outcome as the `✕` button. It appears in the menu so a user who opened the menu does not have to close it and reach for `✕` separately.

Entry #5 (`.alreadyDone`) is technically a completion path (behavior §1) but lives in the same menu so the user never has to choose between "negative menu" and "completion menu" — there is one menu.

### 4.3 Item rendering

Each entry is a `Button` inside the `Menu` with:

- The display label as `Text(verbatim:)` (no markdown / AttributedString interpretation, per design-system-v1 §9 and visual-v1 §9).
- No leading icon, no trailing icon, no destructive role marker. The menu is uniform — a stars-row of "Dismiss" item and a plain "Not now" item would suggest one is more severe than the other; v1 forbids that hierarchy.
- One tap commits. The menu closes on selection and `dismissRecommendation(_:feedback:)` runs immediately.

### 4.4 Forbidden menu features

- No section headers or grouping (e.g., "Feedback" / "Other").
- No submenus or "More options" disclosure.
- No "Other (specify)" row that opens a free-text input.
- No keyboard shortcut hints inline (system menu may add platform-default shortcuts; this is platform behavior, not a contract feature).
- No checkmark next to a "previously selected" item — feedback is non-undoable per behavior §3.3 and there is no "currently selected" state to mark.
- No "Submit" button at the bottom of the menu — one tap commits per behavior §2.2.

---

## 5. Per-feedback-kind entry forms (visual)

The five feedback kinds are visually uniform in v1: same menu item shape, same typography, same color. The kind-specific behavior (scorer effect per behavior §4) is invisible to the user.

| Kind | Visual difference vs other menu items |
|---|---|
| `.dismiss` | none |
| `.notInterested` | none |
| `.lessLikeThis` | none |
| `.notNow` | none |
| `.alreadyDone` | none |

Visual uniformity is normative. A future v2 that wants to surface scorer-effect strength in the UI (e.g., "Less like this" gets a badge for "stronger" suppression) MUST go through §11 change process AND coordinate with behavior contract.

### 5.1 Why no per-kind visual differentiation

The behavior contract §1 says "the option set does not vary by object kind" and §6 forbids per-vertical feedback affordances. Per-kind visual differentiation inside the menu would create a second axis of variation (besides kind) and invite verticals to extend it. Keeping all 5 entries visually equal preserves the behavioral promise that "all five are equally easy to choose."

---

## 6. Immediate UI response after submission

Behavior contract §3 freezes the response. This section binds it visually.

### 6.1 Card removal

| Property | Value | Source |
|---|---|---|
| Removal timing | Same frame as the menu tap (or `✕` tap). The card MUST disappear instantaneously. | behavior §3.1 |
| Removal motion | **None.** No fade, no slide, no scale, no opacity transition. | behavior §3.1 (also §2.1 of this doc reconciles with rail-visual §6) |
| Adjacent cards | Collapse instantaneously into the freed slot. Per rail-visual §7.2, gap-collapse is instantaneous. | rail-visual §7.2 |
| Refresh trigger | `refreshRecommendedMatches` fires immediately after removal. | behavior §3.1 |
| New cards from refresh | Render as `default` state per rail-visual §6 `refreshed`. | rail-visual §6 |

### 6.2 No transient receipt UI

| UI element | Allowed? | Source |
|---|---|---|
| Toast / snackbar | NO | behavior §3.2 |
| Banner | NO | behavior §3.2 |
| Bottom sheet confirmation | NO | behavior §3.2 |
| `Undo` button | NO | behavior §3.3 |
| Inline strip in the freed slot ("You dismissed X") | NO | behavior §3.1 |
| Checkmark overlay before card vanishes | NO | (would be a fade-in receipt; forbidden) |
| Sound effect | NO | behavior §6 |
| Haptic | NO | behavior §6 |
| Color flash on the card before vanishing | NO | (would be a fade analog; forbidden) |

**The card vanishing IS the entire receipt.** No additional visual is permitted in v1.

### 6.3 No transcript receipt

The chat transcript receives **zero** updates from a feedback submission:

- No `ConversationMessage` is appended.
- No system event row.
- No `ConversationToolResult` is added.
- No banner inside the transcript.

This matches behavior §3.4 verbatim and aligns with `post-return-and-continuation-ux-v1.md` §2.4 (dismiss / acceptNoEntry write nothing).

---

## 7. Confirmation / receipt state

### 7.1 There is no confirmation state

A "confirmation state" would mean a visual property persists after the tap to communicate "we got your feedback." v1 has no such state:

- The card vanishes; nothing replaces it in the same slot.
- The rail re-renders with whatever the next refresh produces.
- No card in the rail is annotated with a "responded to feedback" indicator.

### 7.2 There is no receipt state

A "receipt state" would mean the affordance itself reflects "we received your tap." v1 has no such state:

- The `✕` and `⋯` glyphs do not change color or icon after a tap (the card is gone before the user could perceive any glyph state change).
- The menu does not show a "submitted" message before closing.
- The rail does not show a temporary "feedback applied" badge.

The reason: the card's removal is the only signal v1 needs. Adding a receipt state would (a) duplicate the signal and (b) imply the system might be "thinking" — which it is not, per behavior §3.1 ("disappears on the same frame").

---

## 8. Rail and transcript visibility of feedback events

| Surface | Renders feedback event? | Visual artifact | Source |
|---|---|---|---|
| Recommended Next rail | Indirectly: the dismissed card is absent from subsequent renders. The rail itself shows no "you dismissed N cards" indicator. | None beyond the slate's normal post-refresh content | behavior §3.1, §4.3; rail-visual §3, §6 (suppressed) |
| Chat transcript | No | None — not a single character | behavior §3.4 |
| Chat home outside the rail (e.g., header, composer) | No | None | behavior §6 (no global "feedback settings", no counter) |
| Push notification / system surface | No | None | behavior §6 (no shake-to-report-problem, no system feedback hook) |

### 8.1 Why neither surface confirms

The transcript is the durable record of *tasks*. Dismissing a card is metadata, not a task (behavior §3.4). The rail is ephemeral; today's slate is whatever survived the latest refresh. Surfacing a "we heard you" message in either surface would be performative — the scorer accumulates the signal silently.

---

## 9. Forbidden visuals (extending behavior §6)

This section consolidates and extends the prohibitions in behavior contract §6 with their visual counterparts.

- **No "tell us more" text field** in the menu, in a follow-up sheet, or as an inline expander on the card.
- **No category picker** ("Was this too repetitive / too off-topic?") in any modal, popover, or inline panel.
- **No "why this suggestion?" explainer** triggered from the feedback menu. If the user wants provenance, they tap the card's primary action; the menu does not open a meta-explanation.
- **No rating widget** — no star row, no thumbs-up/down pair, no emoji reaction strip, no slider.
- **No shake-to-report gesture or system "send feedback" hook**.
- **No post-feedback confirmation sound, haptic, or screen flash**.
- **No per-vertical feedback UI** ("Wrong address" for Maps, "Wrong mood" for Music, "Off-topic" for Search) — all map to the existing 5 kinds or wait.
- **No global "feedback settings" page** — there is no place to configure category-wide opt-out.
- **No feedback counter or dashboard** ("12 cards dismissed this week") in the app, in Settings, or in any insights surface.
- **No "recently dismissed" list** anywhere.
- **No suppression-state indicator** on returning cards ("muted last week", "down-weighted").
- **No alternate-color affordance** for the `✕` or `⋯` button (e.g., red `✕` for "stronger negative").
- **No animation choreography on the menu open** beyond what SwiftUI's native `Menu` provides.

---

## 10. Token-binding summary

Every visual axis traces to a `design-system-v1.md` token. No new tokens introduced.

| Visual axis | Token | V0 reference |
|---|---|---|
| `✕` glyph color (rest) | `Palette.textMuted` | §3.1 |
| `⋯` glyph color (rest) | `Palette.textMuted` | §3.1 |
| `✕` and `⋯` glyph weight | `caption .semibold` (chip-family typography) | §3.2 |
| `✕` and `⋯` hit target | `28 × 28 pt` (size, not in §3.3 spacing set; documented per behavior §2.1 / §2.2 as accessibility floor) | (size, not spacing) |
| Inter-button spacing in card head | `8pt` (in `{4, 8, 12, 16, 20}` permitted set) | §3.3 |
| Pressed-state opacity | `0.6` via `motion.standard` | §3.6 / §4.4 |
| Menu container | platform-native (SwiftUI `Menu`) | (platform) |
| Menu item typography | platform-default | (platform) |
| Card removal motion | **none** (instantaneous; see §6.1 and §2.1 reconciliation) | (no token consumed; this is the absence of motion as a contract decision) |

---

## 11. What this doc does NOT do

- Does NOT redefine `MatchingFeedbackKind` cardinality (frozen at 5 by behavior §1).
- Does NOT introduce a new affordance type or trigger gesture (behavior §2.3).
- Does NOT cover localization rendering specifics — `*Localized` companions are deferred until a localization pipeline exists.
- Does NOT cover the post-feedback rerank (owned by behavior §4).
- Does NOT cover post-return suppression rules (owned by behavior §5).
- Does NOT cover the `.alreadyDone` → `.completion` elevation (owned by behavior §1; surfaces in `post-return-and-continuation-ux-v1.md`).
- Does NOT change `mixed-recommendation-rail-visual-v1.md`. The §2.1 reconciliation flags an inconsistency to be addressed in a future v1.1 of that doc; this PR does not modify it.
- Does NOT cover negative-feedback affordances on continuation transcript blocks (out of scope; transcript blocks have their own dismiss/acceptNoEntry rules in `continuation-transcript-visual-v1.md` §7).

---

## 12. Change process & ratification

1. **Adding a new feedback kind.** v2 of `negative-feedback-ux-v1.md` AND this doc, in lockstep.
2. **Adding a third affordance type** (e.g., a sidebar quick-feedback button). v2 of behavior contract first; this contract bumps after.
3. **Re-tuning a value within §3 / §4 / §6.** Permitted if the value still binds to a V0 token. Update both this doc and the implementation in the same PR.
4. **Adding a confirmation toast / receipt state.** Forbidden in v1. v2 only.
5. **Adding a per-kind visual differentiation in the menu.** Forbidden in v1. v2 only.
6. **Resolving the §2.1 reconciliation** (rail-visual §6 dismissed-state fade). v1.1 of `mixed-recommendation-rail-visual-v1.md`. This v1 stays as written; the rail-visual revision retracts its fade.

### 12.1 Ratification checklist

v1 is ratified when ALL of the following are true:

- [ ] `Contracts/Design/design-system-v1.md` ratified.
- [ ] `Contracts/UX/mixed-recommendation-rail-visual-v1.md` ratified.
- [ ] At least one production consumer renders a card with both `✕` and `⋯` per §3.1 / §3.2.
- [ ] At least one production consumer wires the `⋯` menu with the 5 `MatchingFeedbackKind` entries in the §4.2 frozen order.
- [ ] An automated test asserts no `ConversationMessage` is appended after `dismissRecommendation` (silent transcript, behavior §3.4).
- [ ] An automated test asserts the dismissed card is removed from `recommendedMatches` on the same frame (behavior §3.1; visual: no fade per §2.1 override).
- [ ] An automated test asserts the menu vocabulary is exactly the 5 `MatchingFeedbackKind.allCases` (no extras, no missing).
- [ ] No new tokens or contract clauses introduced by I3.
- [ ] §2.1 override is enforced by I3 — the user-initiated dismissal path uses zero motion. (This contract's override is sufficient on its own; the V2 hygiene PR that retracts §6 / §7.2's superseded fade language is independent and does NOT block ratification of this contract.)
