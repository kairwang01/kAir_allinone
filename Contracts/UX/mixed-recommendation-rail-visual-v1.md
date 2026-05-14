# Mixed Recommendation Rail Visual Contract — v1

Status: draft, normative
Authority split:
- This doc owns **how** the Recommended Next rail and its cards render.
- [`Docs/design/mixed-recommendation-layout-v1.md`](../../Docs/design/mixed-recommendation-layout-v1.md) owns **what** renders (slate composition, tier hierarchy, slate-size caps, feedback semantics).
- [`Docs/design/action-card-component-inventory.md`](../../Docs/design/action-card-component-inventory.md) owns the card primitive (`ActionCardShell` 7-region structure, trust-pill vocabulary).
- [`Contracts/UX/post-return-and-continuation-ux-v1.md`](post-return-and-continuation-ux-v1.md) owns **when** the rail refreshes per terminal outcome.
- [`Contracts/Design/design-system-v1.md`](../Design/design-system-v1.md) owns the underlying tokens (color, type, spacing, radius, elevation, motion, component-state mapping).

---

## 1. Purpose, scope, non-goals

**Purpose.** Lock the visual treatment for the Recommended Next rail and its cards so that vertical slates render identically. The behavior contract owns what cards exist; this contract owns what the rail and cards LOOK like.

**Scope.**
- Rail container (position, width, padding, surrounding chrome).
- Three layout states: single (1 card), dual (2 cards), triple (3 cards).
- Direct slot vs alternatives visual treatment.
- Per-card states: `default`, `accepted`, `dismissed`, `loading`, `suppressed`, `refreshed`.
- Visual transitions: `preserve`, `suppress`, `refresh`.
- Token bindings to `design-system-v1.md`.

**Non-goals (v1).**
- Card primitive itself — `ActionCardShell` is owned by `action-card-component-inventory.md`. This contract binds it; it does not redefine it.
- Trust-pill copy / vocabulary — locked in `action-card-component-inventory.md` §5.
- Object-kind cardinality — frozen at 9 in `mixed-recommendation-layout-v1.md` §1.
- Behavior rules — slot tiers, slate caps, feedback five-case enum, refresh timing — all owned upstream.
- Negative-feedback affordance — separate v3.
- Continuation transcript blocks — separate v1 (already shipped).
- Empty-state UI — owned by chat-home spec; out of scope here per `post-return-and-continuation-ux-v1.md` §3.4.
- I2 implementation. This is normative contract; the implementation lags.
- Per-vertical visual variants — explicitly forbidden (see §9).

---

## 2. Dependencies

| Dep | Path | Authority |
|---|---|---|
| Behavior | [`mixed-recommendation-layout-v1.md`](../../Docs/design/mixed-recommendation-layout-v1.md) | What renders: slot tiers, slate-size caps, per-card feedback, mixed-slate edge cases. |
| Card primitive | [`action-card-component-inventory.md`](../../Docs/design/action-card-component-inventory.md) | `ActionCardShell` 7-region structure; trust-pill vocabulary. |
| Refresh timing | [`post-return-and-continuation-ux-v1.md`](post-return-and-continuation-ux-v1.md) | When the rail rebuilds and which outcomes trigger which refresh kind. |
| Tokens | [`design-system-v1.md`](../Design/design-system-v1.md) | Visual values (color, type, spacing, radius, elevation, motion). Component-state mapping (§4.4) is binding for §6 below. |

**Authority resolution.** When this doc disagrees with `mixed-recommendation-layout-v1.md` on what renders, the behavior doc wins (cardinality, feedback options, slate caps). When this doc disagrees with `design-system-v1.md` on token values, V0 wins. When this doc disagrees with `post-return-and-continuation-ux-v1.md` on refresh timing, the post-return doc wins. This doc's authority is bounded to the visual axes listed in §1 scope.

---

## 3. Rail container

The rail is the bounded vertical surface inside chat home that presents the Recommended Next slate.

**Position.** Owned by chat-home spec (Layer 4). This contract does not relocate or wrap it.

**Container chrome.**

| Property | Value | Source |
|---|---|---|
| Background fill | transparent — rail sits on chat canvas | — |
| Border | none | — |
| Internal vertical padding | `0pt` (rail is contiguous with chat content above and below) | — |
| Internal horizontal padding | `0pt` (rail inherits chat-home's `Metrics.screenPadding` of `20pt`) | design-system-v1 §3.3 |
| Inter-card vertical spacing | **`12pt`** | design-system-v1 §3.3 (in `{4, 8, 12, 16, 20}` permitted set) |
| Stack direction | vertical, top-to-bottom, in rank order | mixed-recommendation-layout-v1 §2 |
| Max card width inside rail | full rail width (no per-card width inset) | — |

**Forbidden chrome on the rail container.**
- No header label ("Recommended for you", "Suggestions", etc.)
- No section divider above or below
- No "X of Y" counter / pagination indicator
- No surrounding shadow or elevation on the rail itself (each card carries its own elevation; the rail is invisible)
- No expand/collapse affordance
- No background tint or gradient

When `recommendedMatches` is empty, **the rail is absent from the view tree** — no placeholder, no empty-state copy. (Owned by chat-home spec; this contract preserves the rule.)

---

## 4. Layout states

`mixed-recommendation-layout-v1.md` §3 freezes the three states. This section binds each to concrete layout values.

### 4.1 Container behavior (identical across all three states)

| Property | Value | Notes |
|---|---|---|
| Container layout | `VStack(alignment: .leading, spacing: 12pt)` | Single direction, top-to-bottom. |
| Outer margin | inherits chat-home's `Metrics.screenPadding` (`20pt` horizontal); zero vertical padding from the rail itself | Rail is contiguous with chat content above and below. |
| Inter-card gap | `12pt` between successive cards (gap omitted when only 1 card present) | design-system-v1 §3.3 permitted. |
| Card width inside rail | full rail width (no per-card width inset) | Identical for every card in the slate. |
| Card height inside rail | content-driven, no per-card override | Capped by `ActionCardShell` internal max line counts (`title2` 2 lines, `subheadline` 3 lines, `caption` 1 line). |
| Wrapping | **forbidden** — cards never wrap to a new column or row | Rail is single-column only. |
| Horizontal scroll | **forbidden** — the rail is vertical-only | No `ScrollView(.horizontal)` anywhere in the rail subtree. |

The container behavior is **identical across single / dual / triple**. The only thing that changes between states is the card count. There is no per-state padding, no per-state inter-card gap, no per-state width, and no per-state height multiplier.

### 4.2 Per-state visual

| State | Card count | Visual layout |
|---|---|---|
| Single | 1 | One `ActionCardShell` at full rail width. No surrounding decoration. The single-card state MUST NOT render a "more coming" placeholder, an empty trailing slot, or a centered single card with extra side padding. |
| Dual | 2 | Two `ActionCardShell`s stacked top-to-bottom with `12pt` inter-card gap. Identical width, identical chrome. No comparator, no "vs." indicator, no side-by-side variant. |
| Triple | 3 | Three `ActionCardShell`s stacked top-to-bottom with `12pt` inter-card gap. Identical rules to dual. Triple is the cap; the rail MUST NOT render a fourth card, a "see more" affordance, or a paginator. |

### 4.3 Forbidden across all three states

- No grid (`LazyVGrid`, `Grid`, side-by-side `HStack` of cards).
- No carousel / horizontal scroller / `TabView` paging.
- No accordion / collapsed-by-default tier.
- No "expand for more" disclosure.
- No featured / callout variant for the direct slot.
- No 4+ card layout. The provider caps the slate at 3 (post-return §3.2); the rail renders ≤ 3.
- No per-state animation (entering single → dual → triple is instantaneous; see §7).
- No automatic line-wrap of cards into a second column.
- No horizontal swipe gesture, page indicator, or paged container around the rail.

---

## 5. Tier visual — direct slot vs alternatives

Behavior is locked in `mixed-recommendation-layout-v1.md` §2. The visual rule is:

> **The direct slot and the alternatives are the same view.** They differ only in their position in the `VStack`. There is no per-tier visual skeleton, no per-tier override, and no per-tier metadata budget.

### 5.1 Per-axis comparison

| Property | Direct slot (index 0) | Alternatives (index 1–2) |
|---|---|---|
| `ActionCardShell` 7-region structure | identical | identical |
| Width | rail width | rail width |
| Internal padding | per primitive | per primitive |
| Border | per primitive | per primitive |
| Elevation | `elevation.raised` (per primitive) | `elevation.raised` (per primitive) |
| Header glyph | per `objectKind` | per `objectKind` |
| Header label color | `Palette.accentStrong` (per primitive) | `Palette.accentStrong` (per primitive) |
| Title typography | `title2 .bold` (per primitive) | `title2 .bold` (per primitive) |
| Body typography | `subheadline` (per primitive) | `subheadline` (per primitive) |
| Reason caption | per primitive (optional) | per primitive (optional) — same caps |
| Primary CTA | per primitive | per primitive |
| Secondary CTA | per primitive (optional) | per primitive (optional) — same presence rules |
| Trust pills | per `objectKind` | per `objectKind` — same set, same vocabulary |
| Tier badge / "Top pick" pill / ribbon | **forbidden** | **forbidden** |
| Visual downgrade (dim, shrink, de-chrome) | n/a | **forbidden** |

### 5.2 Three rules that close the loop (each is normative)

1. **The visual difference between direct slot and alternatives comes only from sort / position.** Index 0 in the `VStack` is the direct slot; indices 1–2 are alternatives. No view-tree decision branches on `index == 0` for any chrome property listed in §5.1.
2. **The direct slot is NOT permitted to carry extra metadata, extra trust pills, an extra body line, an extra CTA, or any structural element that alternatives lack.** If the direct slot's `MatchingObject` produces 3 candidate trust pills and an alternative's produces 1, both render their respective sets through the same primitive — but the direct slot does NOT get a richer slot allocation (e.g., a longer subtitle limit) by virtue of being the direct slot.
3. **Alternatives are NOT permitted to reduce information density.** No truncated subtitle, no hidden reason caption, no removed secondary CTA, no smaller header glyph, no opacity reduction. If a feature is permitted in the direct slot, the same feature MUST be permitted (and rendered when the data is present) in alternatives.

**Position is the only signal.** The direct slot's primacy comes entirely from being at index 0 in the rail's `VStack`; nothing in the chrome distinguishes it from alternatives. `mixed-recommendation-layout-v1.md` §2.3 explains the rationale; this contract enforces it at the visual level.

---

## 6. Per-card state visual mapping

Imports `design-system-v1.md` §4.4 (component-state visual mapping) as the authority for per-state visual treatment. This section names the rail-specific state vocabulary and maps each to §4.4 with a concrete, perceptible difference.

The six states are mutually exclusive; a card is in exactly one at any time. Two adjacent rows in the table below MUST NOT be confused by a reader. Each row's "Visible difference vs `default`" is a contract obligation, not commentary.

| Card state | Trigger | Visible difference vs `default` (perceptible to user) | Source authority |
|---|---|---|---|
| `default` | Card is at rest in the rail | (baseline) | design-system-v1 §4.4 default; card inventory §1 |
| `accepted` | User taps `Accept` on the card | Container fill briefly receives a `Palette.success @ 0.10` overlay AND the border briefly tints to `Palette.success @ 0.18`, both for one `motion.emphasized` cycle (~`0.42s`). The primary CTA's label glyph swaps to a checkmark for the same window. After the flash, the card visibly returns to `default` and remains in the rail until the next refresh (per behavior §3.3). The user perceives a one-shot "yes, got it" pulse, then a calm card. | design-system-v1 §4.4 accepted |
| `dismissed` | User taps `✕` or selects a `MatchingFeedbackKind` from `⋯` | Card disappears on the same frame as the tap. **No opacity transition, no scale, no slide.** Adjacent cards collapse instantaneously into the freed vertical space (per §7.2). The user perceives a single hard state swap. | `negative-feedback-ux-v1.md` §3.1; `negative-feedback-affordance-visual-v1.md` §2.1 (override) + §6.1 |
| `loading` | Card is mid-resolution (e.g., place lookup in flight). v1 uses this only when the primitive itself surfaces a loading affordance — the rail does NOT manage this state. | Spinner glyph at the resolved tint, body content `0.6` opacity, persistent labels at full opacity, `motion.standard` rotation on the spinner. The user perceives the card as "still resolving" without losing the persistent label. | design-system-v1 §4.4 loading; card inventory §2 |
| `suppressed` | Card was filtered out by the provider before this render, OR was removed by a prior dismiss / accept and has not been re-surfaced | **Zero presence in the view tree.** No skeleton, no placeholder, no greyed-out shell, no reserved slot. The card never reaches `body`. The user perceives no visible artifact — the card is simply not part of the slate. | post-return-and-continuation-ux-v1 §3.3 retention; behavior §3.4 |
| `refreshed` | Card was produced by `refreshRecommendedMatches` AND occupies a rail slot that was previously empty or held a different card | The card renders as `default`. The user perceives the rail content as having changed — possibly different cards in the same slot indices — but **no individual card carries a "just-arrived" marker, badge, or animation**. The slate-level transition is owned by §7 `refresh`; this state is the per-card outcome of that transition (instantaneous, no entry motion). | post-return-and-continuation-ux-v1 §3.4; behavior §3.4 |

### 6.1 Disambiguating overlapping pairs

- **`default` vs `accepted`** — `accepted` is a one-shot pulse with a measurable `motion.emphasized` duration AND a glyph swap on the primary CTA. After the pulse the card returns to `default` chrome but is still in the rail. The two are distinct: during the pulse, the card has a colored overlay and tinted border; in `default`, it does not.
- **`dismissed` vs `suppressed`** — `dismissed` is **user-initiated** (the user tapped `✕` or a `⋯` menu item) and removes the card on the same frame. `suppressed` is **non-user-initiated** (the card never appears, or the provider drops it during refresh) and also removes the card instantaneously. The perceptible difference is causal, not visual: a `dismissed` card was on screen one frame ago and is gone now because of the user's tap; a `suppressed` card was never on screen or fell out via refresh. Both states involve zero motion.
- **`refreshed` vs `default`** — `refreshed` is a labeled state for documentation purposes only; visually it IS `default`. It is named explicitly so a future "show new cards specially" proposal MUST go through §11 change process rather than slipping in as a tweak to `default`.

**`error` state is not part of v1.** A card cannot fail in a way the rail must visualize. Provider failures upstream of the rail produce zero candidates → `recommendedMatches` shrinks → the rail enters Single / Dual or absent. The card primitive's per-kind error strip (e.g., Maps trust-pill `partnerFallback`, `locationPermissionDenied`) is the closest equivalent and is owned by the primitive, not the rail.

**Pressed / focused states** are handled inline by the card primitive's `Button` and `.contentShape` (per `action-card-component-inventory.md` §2). The rail does not contract a separate pressed state.

---

## 7. Visual transitions: preserve / suppress / refresh

Three transitions are named. The behavior contracts (`mixed-recommendation-layout-v1.md` §3.4 and `post-return-and-continuation-ux-v1.md` §3.4) lock all rail transitions as **instantaneous state swaps with no per-card animation on enter/exit**. This section names the transitions and pins their visual semantics.

| Transition | When | Visual semantics | Motion |
|---|---|---|---|
| `preserve` | Slate rebuild produces the same card at the same slot index | Card is unchanged across renders. SwiftUI MUST identify the card by stable `id` (the `MatchingObject` id) so the view tree treats it as the same instance. No fade-out / fade-in of the unchanged card. | none |
| `suppress` | Card was present and is no longer present after a render — either (a) user dismissed it, or (b) refresh removed it because the candidate fell out of the slate | Both paths are **instantaneous, no fade**. (a) **user-dismissed**: card is removed on the same frame as the tap (per `negative-feedback-ux-v1.md` §3.1 and `negative-feedback-affordance-visual-v1.md` §2.1). (b) **refresh-removed without prior user action**: card is removed instantaneously per behavior §3.4. Adjacent cards collapse to fill the vacated slot **instantaneously** in either path. | none |
| `refresh` | `refreshRecommendedMatches` fires (timing per post-return §3.1) and produces a new slate | Entire rail content swaps. **Instantaneous.** No per-card stagger, no skeleton placeholder, no slate-level fade, no haptic, no sound. Cards that were preserved keep their position; cards that are new render as `default` (no `refreshed` badge); cards that fell out follow `suppress` path (b). | none for the rail; preserve/suppress per-card semantics apply |

### 7.1 Why no entry animation on refresh

Two reasons, both from upstream contracts:
1. `mixed-recommendation-layout-v1.md` §3.4 forbids per-kind animation on enter/exit.
2. `post-return-and-continuation-ux-v1.md` §3.4 explicitly states refresh "does not animate."

Adding a fade-in for new cards would (a) imply a per-card "freshness" signal — exactly the kind of per-vertical ornament these contracts forbid — and (b) shuffle cards under the user's thumb during the brief window where they're scanning the slate.

### 7.2 Why no gap-collapse animation on suppress

When a card disappears mid-slate (e.g., a 2-card → 1-card transition after a refresh), the remaining card's vertical position changes. Animating that position change with `motion.standard` would create a "settling" feel. v1 forbids it: the position change is instantaneous so the user perceives a hard state swap, not a soft re-layout. This is consistent with the "instantaneous state swaps" rule in both upstream contracts.

There is no permitted animation in this transition family. Both refresh-removed and user-dismissed cards exit instantaneously. The user-dismissed path is normatively governed by [`negative-feedback-affordance-visual-v1.md`](negative-feedback-affordance-visual-v1.md) §2.1 + §6.1; the refresh-removed path is governed by `mixed-recommendation-layout-v1.md` §3.4 and `post-return-and-continuation-ux-v1.md` §3.4.

### 7.3 Consistency claim

This section adds **zero** new animation rules, motion curves, or delay schedules beyond what is already locked in:

- `design-system-v1.md` §3.6 (motion tokens — `motion.standard` and `motion.emphasized`)
- `design-system-v1.md` §4.4 (component-state visual mapping — including the `accepted` and `dismissed` flash specs that §6 imports)
- `mixed-recommendation-layout-v1.md` §3.4 (no per-kind animation on enter/exit)
- `post-return-and-continuation-ux-v1.md` §3.4 (refresh does not animate)

The principle is unchanged: **state changes are expressed by chrome differences (overlay, border tint, glyph swap, opacity)**, not by animation choreography. Animation is permitted only for the user-initiated `accepted` flash that §6 imports from `design-system-v1.md` §4.4. The `dismissed` state has no animation; the user-dismissed path is governed by [`negative-feedback-affordance-visual-v1.md`](negative-feedback-affordance-visual-v1.md) §2.1 + §6.1. Everything else in this contract is forbidden.

---

## 8. Forbidden visuals (vertical-specific styling)

Cataloged for explicit prohibition. All are forbidden in v1 regardless of `objectKind`:

- **No domain-tinted card backgrounds.** Maps cards do not get an amber-tinted shell; Music does not get a colored shell. The card primitive's container fill is `Palette.surface`, full stop.
- **No mini-map, album art, video thumbnail, favicon, or other inline image preview.** v1 is text-and-glyph (`mixed-recommendation-layout-v1.md` §6).
- **No play button, route preview, or other inline interactive control** beyond the primary / secondary CTAs the primitive defines.
- **No per-`objectKind` typography variant.** Every kind uses the primitive's typography per `action-card-component-inventory.md` §2.
- **No tier marker on the direct slot** (no "Top pick" pill, no "Recommended" ribbon, no inline badge).
- **No visual downgrade on alternatives** (no dimming, no smaller width, no muted border).
- **No group header / section divider** in mixed slates ("From Maps", "Music picks", etc.).
- **No tabs / chips above the rail** to filter by `objectKind`.
- **No carousel, horizontal scroller, accordion, or grid** for multi-card layouts.
- **No animation on slate enter / exit / transition.**
- **No per-vertical haptic, sound, or accent color tied to slate refresh.**
- **No per-card "selected" or "focused" tier-marker** (cards do not communicate selection mid-slate; selection IS acceptance, which goes through the §6 `accepted` state).
- **No counter / pagination indicator** ("1 of 3", dots, progress bar).
- **No skeleton placeholder during refresh.** Refresh is instant; skeletons would imply latency.
- **No empty-state placeholder** ("No suggestions right now" copy / illustration). Empty rail is absent rail.
- **No masonry / staggered layout.** Cards do not interlock vertically across columns or shift x-position based on neighbor heights. The rail is a single, deterministic vertical column.
- **No mixed card heights caused by decorative media blocks** (banner image, hero photo, video thumbnail, oversized illustration). Heights vary only with text content within the primitive's `title2` 2-line / `subheadline` 3-line / `caption` 1-line caps. Any decorative media block that would push a card's height past those caps is forbidden in v1 by `mixed-recommendation-layout-v1.md` §6 ("v1 is text-and-glyph") and re-affirmed here.

---

## 9. Token-binding summary

Every visual axis traces to a `design-system-v1.md` token. If a value below does not appear in V0, it's a contract violation.

| Visual axis | Token | V0 reference |
|---|---|---|
| Inter-card vertical spacing | `12pt` (in `{4, 8, 12, 16, 20}` permitted set) | §3.3 |
| Rail horizontal padding (inherited from chat home) | `Metrics.screenPadding` (`20pt`) | §3.3 |
| Card container radius | `Metrics.cardRadius` (`26pt`, owned by primitive) | §3.4 |
| Card elevation | `elevation.raised` (`α 0.06, blur 12, y +6`, owned by primitive) | §3.5 |
| Card container fill | `Palette.surface` (`#FFFFFF`, owned by primitive) | §3.1 |
| Card border | `Palette.line` (`#000000 @ 0.06`, owned by primitive) | §3.1 |
| Header label color | `Palette.accentStrong` (`#1A1C21`, owned by primitive) | §3.1 |
| Title typography | `sectionTitle` family — primitive uses `title2 .bold` which maps to V0's `sectionTitle` slot | §3.2 |
| Subtitle typography | `body` (`subheadline` per primitive) | §3.2 |
| Reason caption typography | `meta` (`caption .medium` per primitive) | §3.2 |
| Primary CTA typography | `actionLabel` (`subheadline .semibold` per primitive) | §3.2 |
| Accepted-state overlay color | `Palette.success @ 0.10 alpha` | §3.1 (derived alpha permitted in §4.4 state mappings) |
| Accepted-state border tint | `Palette.success @ 0.18 alpha` | §3.1 (derived alpha permitted in §4.4) |
| Accepted-state flash motion | `motion.emphasized` for entry; `motion.standard` for revert | §3.6 |
| Loading-state motion | `motion.standard` (`easeInOut 0.24s`) on the spinner | §3.6 |
| Refresh / preserve / suppress (refresh-removed) transition motion | none | §3.6 (no token used; this is the absence of motion as a contract decision) |
| Trust-pill colors | per `action-card-component-inventory.md` §5 vocabulary | (not redefined here) |

**No new tokens introduced.** This contract consumes V0 only.

---

## 10. What this contract does NOT do

- Does NOT redefine `ActionCardShell`'s 7-region structure. That stays in `action-card-component-inventory.md`.
- Does NOT introduce new trust-pill kinds. The `ActionCardTrustPillKind` vocabulary stays at the 7 cases listed in `action-card-component-inventory.md` §5.
- Does NOT change `MatchingObjectKind` cardinality — frozen at 9 cases.
- Does NOT change `MatchingFeedbackKind` cardinality — frozen at 5 cases.
- Does NOT define the rail's data source / refresh trigger semantics (owned by post-return).
- Does NOT cover the negative-feedback affordance details (deferred v3).
- Does NOT cover continuation transcript blocks (separate v1; already shipped — `Contracts/UX/continuation-transcript-visual-v1.md`).
- Does NOT specify rail behavior on tablet / iPad form factors — out of scope (V0 §1 lists cross-platform tokens as out-of-scope; same applies here).
- Does NOT handle reduce-motion variants beyond the V0 §3.6 collapse already locked.

---

## 11. Change process & ratification

This document is contract; the implementation lags. Visual changes flow through here.

1. **Adding a new layout state** (e.g., quad). Forbidden in v1 — slate cap is 3. Goes to v2 of `mixed-recommendation-layout-v1.md` first, then this contract bumps.
2. **Adding a tier marker** ("Top pick", "Recommended"). Forbidden in v1 — explicit non-goal. Goes to v2.
3. **Adding a per-`objectKind` visual variant** (mini-map, album art, etc.). Forbidden in v1. Goes to v2 of `action-card-component-inventory.md` first.
4. **Re-tuning a value within §3 / §6 / §7.** Permitted if the value still binds to a V0 token. Update both this doc and the implementation in the same PR.
5. **Promoting an animation** (refresh fade-in, gap-collapse spring). Forbidden in v1. Requires coordinated change to `mixed-recommendation-layout-v1.md` §3.4 AND `post-return-and-continuation-ux-v1.md` §3.4 — i.e., a cross-contract v2.
6. **Adding a new card state** (e.g., `pinned`, `expiring`). Forbidden in v1. Goes to v2 with a corresponding `design-system-v1.md` §4.4 row.

### 11.1 Ratification checklist

v1 is ratified when ALL of the following are true:

- [ ] `Contracts/Design/design-system-v1.md` ratified.
- [ ] At least one production consumer renders a single-state rail against this contract.
- [ ] At least one production consumer renders a dual-state rail.
- [ ] At least one production consumer renders a triple-state rail.
- [ ] At least one production consumer triggers the `accepted` state and the §6 flash is observed.
- [ ] At least one production consumer triggers the `dismissed` state and the §6 instantaneous removal is observed (per [`negative-feedback-affordance-visual-v1.md`](negative-feedback-affordance-visual-v1.md) §2.1 override).
- [ ] At least one production consumer triggers a `refresh` and §7's instantaneous swap is verified (no animation).
- [ ] An automated test asserts that a rail with `recommendedMatches.isEmpty` produces zero view-tree presence (matches §3 "rail is absent").
- [ ] An automated test asserts that the rail's view tree contains zero `sectionHeader`-style children regardless of slate composition (matches §8 "no group headers").
- [ ] No new V0 tokens or contract clauses introduced by I2.

### 11.2 Implementation status (informational, not normative)

Informational mirror of §11.1, populated by the Visual Contract
Unlock Sweep after `Contracts/Design/design-system-v1.md` ratified
(PR #55, merge commit `4e60d95`). The §11.1 checklist above remains
the normative gate; this block does NOT tick §11.1 and does NOT
change this contract's `Status:` line — mixed-recommendation-rail-visual-v1
is **NOT ratified**.

**Satisfied:**

- [x] `design-system-v1.md` ratified — PR #55; its `Status:` reads
  `ratified` and all seven §8.1 boxes are ticked.
- [x] Single / dual / triple production rendering — `ChatHomeView`
  renders `RecommendationRail(objects: store.recommendedMatches)` as
  a production consumer; the rail is generic over slate size and
  `RecommendationRailIntegrationTests` proves `store.recommendedMatches`
  reaches `.single` / `.dual` / `.triple`.
- [x] `dismissed` state triggered in production — `ChatHomeView`
  wires the rail's `onDismiss` (✕) and `onFeedback` (⋯) to
  `ChatStore.dismissRecommendation`; the card is removed same-frame.
- [x] Empty-rail zero presence (automated test) — `RecommendationRail`
  returns `EmptyView()` for an empty slate;
  `RecommendationRailContractTests.test_rail_emptyObjects_isAbsent`
  asserts `isAbsent`, `renderedCardCount == 0`, `layoutState == .absent`.
- [x] No new V0 tokens or contract clauses introduced — the rail and
  `ActionCardShell` consume only existing `design-system-v1.md`
  tokens (this contract's §9 binding table).

**Still blocking ratification:**

- [ ] `accepted` state — no production consumer triggers it.
  `RecommendationRail` exposes no accept handler; `ChatHomeView`'s
  call site wires only `onDismiss` / `onFeedback` and its source
  comment states "Accept / refresh wiring stay deferred to a later
  PR." The §6 `accepted` flash is never exercised in production.
- [ ] `refresh` transition — `ChatStore.refreshRecommendedMatches()`
  exists and runs internally after a dismissal, but no production
  consumer drives a refresh with §7's instantaneous-swap property
  verified; the same source comment defers refresh wiring.
- [ ] No automated test asserts "zero `sectionHeader`-style children."
  `RecommendationRail` is structurally header-free, but §11.1 demands
  an automated test; none exists.

**Conclusion.** `design-system-v1.md` ratification cleared the first
§11.1 box but is **not** the only blocker. Three gates remain — the
`accepted` and `refresh` production wiring and the no-`sectionHeader`
automated test — each requiring Swift changes (a later implementation
line), out of scope for this doc-only sweep.
mixed-recommendation-rail-visual-v1 stays **NOT ratified**.
