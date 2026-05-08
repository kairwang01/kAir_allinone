# Continuation Transcript Visual Contract — v1

Status: draft, normative
Scope: visual contract for the three transcript blocks emitted by the continuation runtime — `systemSummary`, `systemEvidence`, `nextStepPrompt`.
Authority split:
- This doc owns **how** the blocks render.
- [`Contracts/UX/continuation-runtime-v1.md`](continuation-runtime-v1.md) owns **what** data is in each block.
- [`Contracts/UX/post-return-and-continuation-ux-v1.md`](post-return-and-continuation-ux-v1.md) owns **when** blocks render (which terminal outcome triggers which block).
- [`Contracts/Design/design-system-v1.md`](../Design/design-system-v1.md) owns the underlying tokens. Every visual choice in this doc binds to a row there.

---

## 1. Purpose, scope, non-goals

**Purpose.** Lock the visual treatment for continuation-runtime transcript blocks so that any vertical (Maps / Music / Video / Health / AI / Store / Search / future) returning data through the runtime renders identically. No vertical-specific block styling.

**Scope.**
- The three system-emitted transcript block types: `systemSummary`, `systemEvidence`, `nextStepPrompt`.
- Their position relative to user bubbles and assistant text.
- Their internal hierarchy.
- How the four post-return outcomes (`completion` / `abandon` / `dismiss` / `acceptNoEntry`) modulate tone.
- Their token bindings.

**Non-goals (v1).**
- Mixed rail (Recommended Next) visual contract — separate v2.
- Negative-feedback / dismiss affordance — separate v3.
- The data shape of these blocks — owned by `continuation-runtime-v1.md`.
- The behavioral rules of when blocks emit per outcome — owned by `post-return-and-continuation-ux-v1.md`. This doc adopts those rules; it does not re-litigate them.
- User-bubble visuals (right-side, `surfaceStrong`, radius 24pt) — already shipped; only referenced for contrast in §4.
- SwiftUI implementation. This is a normative contract; the implementation lags.
- Vertical-specific prose styling. **Explicitly forbidden** — see §9.
- Reduce-motion behavior beyond the §3.6 collapse already locked by the design system.
- Accessibility / VoiceOver labelling — separate workstream.

---

## 2. Dependencies

| Dep | Path | Authority |
|---|---|---|
| Design tokens | [`../Design/design-system-v1.md`](../Design/design-system-v1.md) | Visual values (color, type, spacing, radius, elevation, motion). |
| Runtime data envelope | [`continuation-runtime-v1.md`](continuation-runtime-v1.md) | What is in each block (`ChatContinuationEvent` schema). |
| Outcome behavior | [`post-return-and-continuation-ux-v1.md`](post-return-and-continuation-ux-v1.md) | When each block renders or suppresses, per terminal outcome. |

**Authority resolution.** When this doc disagrees with the runtime contract, the runtime contract owns the data shape; this doc owns the visual rendering of whatever it emits. When this doc disagrees with post-return-and-continuation-ux-v1, that doc owns the *render-or-suppress* decision per outcome (this doc's §7 imports those rules verbatim).

---

## 3. Block taxonomy (frozen set)

Three system-authored transcript blocks. Always assistant-side. Verticals MAY NOT add a fourth.

| Block | Required? | Max per assistant message | Relative order when stacked |
|---|---|---|---|
| `systemSummary` | Yes, when the assistant message is a continuation-runtime message AND the outcome is render-eligible per §7 | 1 | 1st |
| `systemEvidence` | No (runtime-optional) | 1 | 2nd |
| `nextStepPrompt` | No (runtime-optional) | 1 | 3rd |

Stacking order is fixed: summary → evidence → prompt. Reordering is forbidden in v1. A runtime message MAY emit any subset of {summary} ∪ {summary+evidence} ∪ {summary+prompt} ∪ {all three}, but MUST always lead with summary.

A continuation-runtime assistant message that has render-eligible content MUST emit at least `systemSummary`. A bare assistant text message (no runtime payload) is unaffected by this contract.

---

## 4. Structural difference vs user bubble

The continuation block is NOT a user bubble. The differences below are normative; future visuals MUST preserve them.

| Axis | User bubble | systemSummary block |
|---|---|---|
| Side / alignment | Trailing (right edge) | Leading (left edge) |
| Container shape | Rounded rect, radius `24pt` | Rounded rect, `Metrics.cardRadius` (`26pt`) |
| Fill | `Palette.surfaceStrong` (`#26292E`) | `Palette.surface` (`#FFFFFF`) |
| Foreground | `Palette.textOnStrong` (`#FFFFFF`) | `Palette.textPrimary` (`#1C1F21`) |
| Border | none (border colour equals fill) | `Palette.line` (`#000000 @ 0.06`), 0.8pt stroke |
| Elevation | `elevation.flat` | `elevation.raised` |
| Internal padding | `16h × 14v` | `20pt` all sides |
| Max content width | message column minus 52pt leading spacer | same column budget; soft cap at `560pt` |
| Typography | `body` regular | mixed (see §5.1) |
| Enter motion | (not in scope; see user-input contract) | Fade + 4pt rise via `motion.standard`; no per-block stagger |

`systemEvidence` and `nextStepPrompt` adopt the same leading side and width budget as `systemSummary`. They differ from the summary in container weight (see §5.2 / §5.3) but never in side or column.

---

## 5. Per-block visual specification

All values normative. Any unspecified visual property is forbidden — implementations MAY NOT invent fills, animations, glyphs, or affordances not listed here.

### 5.1 `systemSummary`

**Container**
- Shape: rounded rect, `Metrics.cardRadius` (`26pt`)
- Fill: `Palette.surface`
- Border: `Palette.line`, `0.8pt` stroke
- Elevation: `elevation.raised` (`#000000 @ 0.06`, blur `12`, y `+6`)
- Padding: `20pt` on all sides
- Max content width: `560pt`
- Leading edge: aligned with assistant text leading edge

**Internal hierarchy** (top-to-bottom, exact gaps)

1. **Header row** — `HStack`, baseline-aligned with the title that follows.
   - Leading: optional eyebrow group
     - Optional `12pt` SF Symbol glyph, color resolved via `AppTheme.tint(for: AppSection)` per design-system-v1 §4.1. Renders only if the runtime explicitly sets a glyph; verticals MAY NOT default-inject one.
     - Eyebrow text: `eyebrow` typography token (`.caption .bold` tracking `1.2`), color `Palette.textMuted`, max 1 line.
   - Trailing: outcome state dot — an `8pt` filled circle, color resolved per §7. No accompanying label, no "Ready" / "Attention" pill text in v1.
2. Gap: `4pt`
3. **Title** — `sectionTitle` token (`.title3 .semibold`; rounded variant permitted), color `Palette.textPrimary`. Max 1 line, truncate tail.
4. Gap: `8pt`
5. **Summary** — `body` token (`.body .regular`), color `Palette.textPrimary`, line spacing `3pt`. Max 2 lines in v1, truncate tail.
6. Gap: `12pt` (omitted entirely if no metric grid)
7. **Metric grid** — up to 3 metric tiles. Layout per the existing post-return contract (post-return-and-continuation-ux-v1 §2.2 freezes 3 metrics including the continuity metric).
   - Grid: adaptive columns, minimum tile width `92pt`, inter-tile spacing `8pt`.
   - Per tile:
     - Container: rounded rect, `Metrics.compactRadius` (`16pt`), fill `Palette.backgroundInset` (`#FBFBFC`), border none, elevation `elevation.flat`.
     - Padding: `8pt` all sides.
     - VStack alignment leading, internal spacing `4pt`.
     - Key: `chip` token (`.caption .semibold`), color `Palette.textMuted`, max 1 line.
     - Value: `chip` token (`.caption .semibold`), color `Palette.textPrimary`, max 2 lines truncate tail.
   - Continuity metric (post-return §2.2 metric 3) MUST always be the LAST tile in the grid. Order of metrics 1 and 2 owned by the runtime.
8. Gap: `12pt` (omitted if no footer)
9. **Footer** — `meta` token (`.footnote .medium`), color `Palette.textMuted`. Max 1 line, truncate tail.

**Forbidden in `systemSummary`**
- More than 3 metric tiles.
- Vertical-specific tint on the container fill or border.
- Inline links, bold/italic spans, or rich text in title / summary / footer.
- "Ready" / "Working" / "Attention" pill labels (only the 8pt dot conveys state in v1).
- Any motion inside the block after enter (no count-up, shimmer, pulsing dot).
- Horizontal scroll of metric tiles (the 92pt-min adaptive grid wraps; it does not scroll).

### 5.2 `systemEvidence`

**Container**
- Shape: rounded rect, `Metrics.compactRadius` (`16pt`)
- Fill: `Palette.backgroundInset` (`#FBFBFC`)
- Border: `Palette.line`, `0.8pt` stroke
- Elevation: `elevation.flat`
- Padding: `12pt` all sides
- Max content width: `560pt` (same column as summary; NOT indented under summary)
- Leading edge: same as summary's leading edge — `systemEvidence` is a sibling of `systemSummary`, not a child

**Internal hierarchy**

1. **Optional eyebrow** — `eyebrow` token, `Palette.textMuted`, tracking `1.2`. Single short label set by runtime (e.g., "Detail"). Skipped if runtime omits.
2. Gap: `8pt` (omitted if no eyebrow)
3. **Pair list** — vertical list of label/value rows.
   - Inter-row spacing: `8pt`.
   - Per row: `HStack(spacing: 8)` with leading label, trailing value.
     - Label: `meta` token (`.footnote .medium`), `Palette.textMuted`, max 1 line truncate tail, fixed-width column at `120pt` or `40%` of container width (whichever is smaller).
     - Value: `body` token (`.body .regular`), `Palette.textPrimary`, may wrap to max 3 lines, truncate tail.
   - Maximum 6 pairs in v1.

**Forbidden in `systemEvidence`**
- Nested `KAirSurface` or any raised container inside the block.
- Any elevation or shadow on the block itself or on rows inside.
- Inline icons next to labels or values.
- Color tinting on labels or values (no domain colors here — evidence is monochromatic).
- Rich text spans (bold, italic, monospace, links).
- More than 6 pairs.
- Horizontal scroll inside the block.
- Footer text (evidence has no footer; that role belongs to summary).

### 5.3 `nextStepPrompt`

**Container.** None. The block IS the affordance row — there is no surrounding card. The block participates in the message column directly.

**Two modes.** Mutually exclusive within a single block.

#### Mode A — chip strip (default for all outcomes that render this block)

- Optional leading eyebrow — `eyebrow` token, `Palette.textMuted`, tracking `1.2`, single short label (runtime-set, e.g., "Pick up here"). Below it, gap `8pt`.
- `HStack(spacing: 8)` of up to 5 chips. Horizontally scrollable if total intrinsic width exceeds the column; scroll indicator hidden.
- Per chip:
  - Shape: `Capsule(style: .continuous)`
  - Fill: `Palette.surface`
  - Border: `Palette.line`, `1pt` stroke
  - Padding: `12h × 8v`
  - Typography: `chip` token (`.caption .semibold`), color `Palette.textPrimary`
  - Optional leading SF Symbol glyph at caption-semibold weight, color `Palette.textPrimary`. Runtime-set only; no default injection.
  - Elevation: `elevation.flat`
  - Tap target: full chip rect.
  - Pressed visual: opacity `0.6` for the chip, transitioned via `motion.standard`. Matches design-system-v1 §4.4 default→pressed pattern (loose-mapped — there is no formal pressed state in v1, so this is the in-doc lock).

#### Mode B — primary CTA + secondary chips

- Same as Mode A, but the FIRST chip in the strip is a primary CTA:
  - Fill: `Palette.surfaceStrong`
  - Foreground (text + glyph): `Palette.textOnStrong`
  - Border: none
  - Padding: `16h × 11v`
  - Typography: `actionLabel` token (`.subheadline .semibold`)
  - Elevation: `elevation.floating` (`#000000 @ 0.08`, blur `14`, y `+6`)
- Secondary chips (positions 2–5) follow Mode A specs.
- Mode B is permitted ONLY when the outcome is `completion` (see §7).

**Forbidden in `nextStepPrompt`**
- More than one primary CTA per block.
- More than 5 chips (primary + secondary combined).
- Vertical-specific tint on chip fills (chip fill is always `surface` or `surfaceStrong`; never `accent`, `success`, `warning`, etc.).
- Per-chip elevation differing from the block-level decision (Mode A: all flat; Mode B: first floating, rest flat — no other mix).
- Long-press menus, swipe-actions, drag handles, or any non-tap interaction.
- Animated entry per chip (the strip fades in as one unit via `motion.standard`).
- A surrounding card or background fill behind the strip.
- An eyebrow longer than 24 visual characters in v1.

---

## 6. Inter-block stacking & rhythm

- Inter-block vertical gap within a single assistant message: **`12pt`**, regardless of which two blocks are adjacent. (Bound to the design-system §3.3 permitted intra-component set.)
- Leading edge: all three blocks share the assistant text leading edge. `systemEvidence` is NOT visually nested under `systemSummary`; it sits as a sibling.
- The assistant message's overall `metadataRow` and `tagRow` (existing in `MessageBubble`) render ABOVE `systemSummary` with the same `12pt` gap when the message carries continuation blocks. The legacy `MessageBubble` `10pt` rhythm is the existing component's concern, not this contract — `MessageBubble` migrates to `12pt` on next touch.
- Inter-message vertical spacing (assistant-message-to-assistant-message): owned by the message list, out of scope.
- When `nextStepPrompt` is the last block, no trailing padding inside the message — the column's natural inter-message gap is sufficient.

---

## 7. Outcome → tone variation (normative)

Imported from `post-return-and-continuation-ux-v1.md` §1 (terminal outcomes) and §2.4 (suppression rules). This section is the visual side of the same rules.

| Outcome | `systemSummary` | `systemEvidence` | `nextStepPrompt` |
|---|---|---|---|
| `completion` | Renders. State dot in `Palette.success` (`#4F6E61`). Footer (text owned by runtime) typically reads as continuity reassurance. | Renders if runtime emits. No tone shift. | Renders if runtime emits. **Mode A or Mode B** permitted. |
| `abandon` | Renders. State dot in `Palette.warning` (`#91754A`). Footer phrasing may reflect "no session" tone — text owned by runtime; this contract permits the tonal text shift but does not change visual treatment beyond the dot. | Renders if runtime emits. No tone shift. | Renders if runtime emits. **Mode A only** — Mode B (primary CTA) is forbidden under abandon. |
| `dismiss` | **Suppressed.** No transcript line is appended. Implementations MUST short-circuit before constructing any block view. | Suppressed. | Suppressed. |
| `acceptNoEntry` | **Suppressed.** Same as dismiss. | Suppressed. | Suppressed. |

**Why `dismiss` and `acceptNoEntry` suppress:** post-return-and-continuation-ux-v1 §2.4 — "the dismissal is the receipt"; no "we heard you" message. This contract preserves that rule.

**Why `abandon` forbids Mode B:** a primary CTA after abandon would visually re-promote the same path the user just walked away from. v1 keeps abandon as chip-only.

The state dot is the ONLY visual difference between `completion` and `abandon` in `systemSummary`. Container fill, border, elevation, padding, and typography are identical across both outcomes. The dot is an 8pt filled circle, no halo, no animation, vertically centered with the title baseline.

---

## 8. Token-binding summary

Every visual axis used in §5 traces to a design-system-v1 token. This table is the audit surface — if a reviewer can find a value below that does NOT appear in design-system-v1, that's a contract violation.

| Visual axis | Token | design-system-v1 reference |
|---|---|---|
| Summary container fill | `Palette.surface` (`#FFFFFF`) | §3.1 |
| Summary container border | `Palette.line` (`#000000 @ 0.06`) | §3.1 |
| Summary container radius | `Metrics.cardRadius` (`26pt`) | §3.4 |
| Summary container elevation | `elevation.raised` (`α 0.06, blur 12, y +6`) | §3.5 |
| Summary container padding | `20pt` (in `{4, 8, 12, 16, 20}` permitted set) | §3.3 |
| Evidence container fill | `Palette.backgroundInset` (`#FBFBFC`) | §3.1 |
| Evidence container border | `Palette.line` | §3.1 |
| Evidence container radius | `Metrics.compactRadius` (`16pt`) | §3.4 |
| Evidence container elevation | `elevation.flat` | §3.5 |
| Evidence container padding | `12pt` (in `{4, 8, 12, 16, 20}` permitted set) | §3.3 |
| Metric tile container fill | `Palette.backgroundInset` (opaque) | §3.1 |
| Metric tile radius | `Metrics.compactRadius` | §3.4 |
| Metric tile padding | `8pt` (in `{4, 8, 12, 16, 20}` permitted set) | §3.3 |
| Chip (Mode A) fill | `Palette.surface` | §3.1 |
| Chip (Mode A) border | `Palette.line` | §3.1 |
| Chip (Mode B primary) fill | `Palette.surfaceStrong` (`#26292E`) | §3.1 |
| Chip (Mode B primary) elevation | `elevation.floating` (`α 0.08, blur 14, y +6`) | §3.5 |
| Title typography | `sectionTitle` (`.title3 .semibold`) | §3.2 |
| Summary text typography | `body` (`.body .regular`) | §3.2 |
| Footer typography | `meta` (`.footnote .medium`) | §3.2 |
| Eyebrow typography | `eyebrow` (`.caption .bold` tracking `1.2`) | §3.2 |
| Metric key/value typography | `chip` (`.caption .semibold`) | §3.2 |
| Evidence label typography | `meta` | §3.2 |
| Evidence value typography | `body` | §3.2 |
| Mode B primary chip typography | `actionLabel` (`.subheadline .semibold`) | §3.2 |
| Block enter motion | `motion.standard` (`.easeInOut 0.24s`) | §3.6 |
| Pressed-state opacity transition | `motion.standard` | §3.6 |
| Completion state dot | `Palette.success` | §3.1 |
| Abandon state dot | `Palette.warning` | §3.1 |
| Text on `surfaceStrong` chip | `Palette.textOnStrong` | §3.1 |
| Inter-block stacking gap | `12pt` (in `{4, 8, 12, 16, 20}` permitted set) | §3.3 |

---

## 9. Vertical-specific styling — explicitly forbidden

This section enumerates the ways a vertical might attempt to "personalize" its transcript blocks. All are forbidden in v1.

- **No domain-tinted block backgrounds.** Maps does not get an amber-tinted summary card; Health does not get a green one. Container fills are `surface` / `backgroundInset`. Section identity may surface only through:
  - The eyebrow text glyph color (when runtime sets a glyph) — resolved through `AppTheme.tint(for: AppSection)`.
  - Nowhere else in v1.
- **No domain-tinted borders.** Borders are `Palette.line`, full stop.
- **No serif, monospace, or custom-family fonts** in any block. All text via §3.2 tokens.
- **No domain-specific iconography in titles or footers.** SF Symbols permitted only in: (a) optional eyebrow glyph slot, (b) optional chip leading-glyph slot. Both are runtime-set, never default-injected.
- **No domain-specific motion.** Block enter is `motion.standard` for all verticals. No spring entrances, no slide-from-side. (`motion.emphasized` is reserved for §4.4 state changes per design-system-v1, not block entry.)
- **No domain-specific haptics on block enter.** Haptic feedback in v1 is permitted only on chip tap (handled via system default), not on block render.
- **No glass / blur / gradient surfaces.** `LiquidGlassSurface` is out-of-scope per design-system-v1 §7. Blocks are flat fills only.
- **No animated content inside blocks** after enter — no count-up numbers, no shimmer, no pulsing dot, no progress shimmer for the metric tiles.
- **No "expand for more" disclosures.** `systemEvidence` is always fully expanded in v1; if it has more than 6 pairs, the runtime sends fewer pairs (responsibility upstream).
- **No nested cards.** No `KAirSurface` inside `systemEvidence` or inside metric tiles.
- **No user-facing "delete" / "hide" / "report" affordance on the blocks themselves.** Suppression is decided by post-return-and-continuation-ux-v1 (`dismiss` / `acceptNoEntry` never emit), not by user gesture on a rendered block.
- **No prose tone-shift per vertical.** The "tone" of a Maps summary vs a Health summary is the runtime's text content, not the visual contract. Visually, every vertical's summary is identical in fill, border, radius, elevation, and typography.

---

## 10. What this contract does NOT do

- Does NOT respec the user bubble (right-side, `surfaceStrong`, radius `24pt`). User bubble stays as shipped.
- Does NOT respec the `SystemEventRow` (centered capsule for system-level events like "merged thread"). That is a separate primitive outside the runtime block taxonomy.
- Does NOT define what happens when a continuation-runtime message is `state: .working` (in-flight). v1 assumes `state: .ready`. The `.working` state is render-eligible per the existing `ConversationToolResultState` enum but its visual is out of scope here; `motion.standard` rotation on a 12pt spinner is the most v1 implementations should reach for, and even that is implementation guidance, not contract.
- Does NOT introduce a fourth block type for "open question" or "clarification request". v1's three blocks are the entire vocabulary.
- Does NOT rule on multi-turn continuation (an assistant message that itself emits a `nextStepPrompt`, and the user taps a chip, producing another assistant message with its own three blocks). Each assistant message is rendered independently; chaining is a runtime concern.
- Does NOT define `state: .working` or `.warning` visual treatment beyond the §7 outcome tone matrix. Future runtime states beyond the four outcomes require a v2.
- Does NOT cover empty states (no transcript message at all). Empty thread is owned by chat-home spec.
- Does NOT respec `MessageBubble.metadataRow` or `MessageBubble.tagRow`. They render above `systemSummary` per existing implementation.

---

## 11. Change process & ratification

This document is contract; the runtime contract is data; the post-return doc is behavior. Visual changes flow through here.

1. **Adding a new block type.** Forbidden in v1. Goes to v2.
2. **Adding a new mode to an existing block.** Requires a §5 row plus a §7 row. Open the v1 doc, propose, ratify. v1 stays open until each block has at least one production consumer (see ratification checklist).
3. **Re-tuning a value within a §5 spec.** Permitted if the value still binds to a design-system-v1 token. Update both this doc and the implementation in the same PR.
4. **Promoting Mode B (primary CTA) to abandon outcomes.** Forbidden in v1. v2 decision.
5. **Renaming a block type.** v2 only; v1 names are public API.

### 11.1 Ratification checklist

Upstream contracts are in canonical position (see §2). Remaining gates are consumer proofs:

- [ ] `Contracts/Design/design-system-v1.md` ratified.
- [ ] `Contracts/UX/continuation-runtime-v1.md` ratified.
- [ ] At least one production consumer renders `systemSummary` against this contract.
- [ ] At least one production consumer renders `systemEvidence`.
- [ ] At least one production consumer renders `nextStepPrompt` Mode A.
- [ ] At least one production consumer renders `nextStepPrompt` Mode B (primary CTA).
- [ ] Suppression of `dismiss` and `acceptNoEntry` verified by a test asserting zero block views are constructed for those outcomes.
