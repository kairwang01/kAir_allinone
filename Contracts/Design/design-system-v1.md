# kAir Design System Contract — v1

Status: draft, normative
Reference implementation: [`kAir/DesignSystem/Tokens/AppTheme.swift`](../../kAir/DesignSystem/Tokens/AppTheme.swift)
Authority: this file is contract. Where it disagrees with `AppTheme.swift`, this file wins; the next code change reconciles the Swift to match. Where it disagrees with `Docs/Planning/`, this file wins absolutely.

---

## 1. Purpose, scope, non-goals

**Purpose.** Define the visual contract for the kAir iOS shell so that every UI PR can answer three questions without re-litigating: (a) which token is allowed here, (b) what does this state look like, (c) what is forbidden.

**Scope.** The chat-first home, plus the Chat / Health / AI / Maps / Store sections. SwiftUI surfaces only.

**Non-goals (v1).**
- Dark-mode palette
- WCAG AA contrast audit (separate workstream)
- Custom font families; CJK / RTL typographic metrics
- Cross-platform tokens (watchOS, macOS)
- Asset / icon system (separate Assets contract)
- Theming for embedded surfaces (partner web views, etc.)
- Reduce-motion variants of every motion token (only the two-tier scale is locked)

**v1 freeze means.**
- **Role names** (e.g. `Palette.textPrimary`, `Metrics.cardRadius`, the `display` text token) are public API. They will not be renamed during the v1 lifetime.
- **Role meanings** will not be reassigned (`success` will not become a brand color).
- **Values** may be re-tuned within the role's intent via §7, but never silently.
- The §3–§5 tables are normative. Anything outside §3–§5 is not contract.

---

## 2. How to read this contract

1. §3 — frozen token tables (color, typography, spacing, radius, elevation, motion). All values present here; reviewers do NOT need to open Swift to verify a token.
2. §4 — state mapping: section / domain → color, plus the **component-state visual mapping** table. Every component state in v1 must map through §4.
3. §5 — naming rules.
4. §6 — alias / rename candidates: things that exist in code but are NOT contract.
5. §7 — out-of-scope: explicitly excluded; new code MUST NOT reach for these.
6. §8 — change process and ratification checklist.

---

## 3. Frozen token tables

### 3.1 Color

Hex values are computed from the SwiftUI literals in `AppTheme.swift` (sRGB, 8-bit per channel, rounded). Where alpha < 1, written `#RRGGBB @ α`.

| Token | Hex | SwiftUI source | Role | Allowed change scope |
|---|---|---|---|---|
| `Palette.accentStrong` | `#1A1C21` | `Color(red: 0.10, g: 0.11, b: 0.13)` | Primary action; chat section identity; default fallback tint | Re-tunable within near-black ink range; MUST keep contrast ≥ 8:1 against `surface` |
| `Palette.accent` | `#595E69` | `Color(red: 0.35, g: 0.37, b: 0.41)` | Store section identity; ECG / "skipped" status binding | Re-tunable within mid-gray range; never crosses into colored hue |
| `Palette.backgroundStart` | `#FFFFFF` | `Color.white` | Top of canvas gradient; Health canvas | Locked to pure white in v1 |
| `Palette.backgroundEnd` | `#F7F7F9` | `Color(0.97, 0.97, 0.975)` | Bottom of canvas gradient | ±2/255 per channel; must stay near-neutral |
| `Palette.backgroundInset` | `#FBFBFC` | `Color(0.985, 0.985, 0.99)` | Inset / map track / glow blob fill | ±2/255 per channel |
| `Palette.surface` | `#FFFFFF` | `Color.white` | Default card / sheet body | Locked to pure white in v1 |
| `Palette.surfaceStrong` | `#26292E` | `Color(0.15, 0.16, 0.18)` | Inverted dark surface; primary-on-dark CTA fill | Re-tunable within near-black; contrast ≥ 7:1 against `textOnStrong` |
| `Palette.line` | `#000000 @ 0.06` | `Color.black.opacity(0.06)` | Hairline border on cards, chips, capsules | α ∈ [0.05, 0.08]; color stays pure black |
| `Palette.textPrimary` | `#1C1F21` | `Color(0.11, 0.12, 0.13)` | Headlines and body copy on light surfaces | Contrast ≥ 12:1 against `surface` |
| `Palette.textSecondary` | `#57595E` | `Color(0.34, 0.35, 0.37)` | Supporting copy, subtitles | Contrast ≥ 7:1 against `surface` |
| `Palette.textMuted` | `#82858A` | `Color(0.51, 0.52, 0.54)` | Eyebrow, metadata, disabled label | Contrast ≥ 4.5:1 against `surface` |
| `Palette.textOnStrong` | `#FFFFFF` | `Color.white` | All text on `surfaceStrong` and emphasized capsule | Locked to pure white in v1 |
| `Palette.success` | `#4F6E61` | `Color(0.31, 0.43, 0.38)` | Status: stable / clean. Bound by `tint(for:)` to heart / recovery domain | Re-tunable within muted green; ΔE ≤ 8 from current |
| `Palette.warning` | `#91754A` | `Color(0.57, 0.46, 0.29)` | Status: watch / guarded. Bound by `tint(for:)` to activity domain | Re-tunable within muted amber; ΔE ≤ 8 |
| `Palette.danger` | `#9E574D` | `Color(0.62, 0.34, 0.30)` | **Destructive / error semantic.** See §3.1.1. | Re-tunable within muted red; ΔE ≤ 8 |
| `Palette.sky` | `#61738A` | `Color(0.38, 0.45, 0.54)` | **Informational / neutral accent.** See §3.1.2. | Re-tunable within muted blue-gray; ΔE ≤ 8 |

#### 3.1.1 `danger` — disambiguation ruling

**v1 freezes `danger` as the destructive / error semantic.** Use it for: error states, destructive confirmations, negative-trend signals where the UI is alerting the user.

The current binding of `Palette.danger` to "metabolic" health metrics inside `AppTheme.tint(for: String)` and `HealthPalette.coral` is a **derivative output** of the §4 mapping function, not a contract on the role. If the design later wants metabolic in a different shade, that is changed by editing the function body, not by re-tuning `danger`.

Consequence: components MUST NOT reach for `Palette.danger` directly when expressing a metabolic-domain meaning. Always go through `AppTheme.tint(for:)`.

#### 3.1.2 `sky` — disambiguation ruling

**v1 freezes `sky` as the informational / neutral accent semantic.** Use it for: ambient information surfaces, neutral status, "informational" feedback.

Current bindings — `.ai` section identity in `tint(for: AppSection)`, respiratory / SpO₂ / sleep-apnea in `tint(for: String)`, and the default fall-through in `statusTint(for:)` — are **derivative outputs** of §4 functions, not contracts on the role. They may be rerouted in v2 without touching `sky`.

Consequence: components MUST NOT reach for `Palette.sky` directly when expressing AI-section identity, a respiratory-domain meaning, or "default status". Always go through the §4 function.

### 3.2 Typography

v1 binds to SwiftUI's native dynamic-type ramp. The **token name** (left column) is contract; the SwiftUI source (second column) is the current implementation. Eyebrow tracking is unified at `1.2` (existing `1.0` call sites are migrated on next touch).

| Token | Source | Weight | Tracking | Allowed use | Forbidden use |
|---|---|---|---|---|---|
| `display` | `.largeTitle` | `.bold` | default | Page hero title — exactly one per screen, top of page | Card title, modal title, list row |
| `sectionTitle` | `.title3` (`.system(.title3, design: .rounded)` allowed for numeric / hero metrics) | `.semibold` | default | Card title, hero metric value, top-of-section heading | Body prose, eyebrow, button label |
| `heading` | `.headline` | `.semibold` | default | Inline section heading inside a card; list-row primary text | Page hero (use `display`), captions, button label |
| `actionLabel` | `.subheadline` | `.semibold` | default | Button / capsule label, primary action text | Body prose, page title, eyebrow |
| `body` | `.body` | `.regular` | default | Paragraph copy, page summary, card body text | Button labels, eyebrows, page title |
| `meta` | `.footnote` | `.medium` | default | Metric tile title, supporting label, list-row meta | Page title, button label, prose |
| `chip` | `.caption` | `.semibold` | default | Chip / pill label, status badge | Body prose, headlines |
| `eyebrow` | `.caption` | `.bold` | `1.2` | Section eyebrow paired with a `display` or `sectionTitle` directly below | Standalone label, anywhere without a paired title |
| `micro` | `.caption2` | `.regular` | default | Smallest meta (timestamp, counter, footnote-of-footnote) | Anywhere a user must read at speed |

Weights permitted in v1: `.regular`, `.medium`, `.semibold`, `.bold`. Weights `.thin`, `.light`, `.heavy`, `.black` are out-of-scope (§7).

Rounded variant (`design: .rounded`): permitted on `sectionTitle` for numeric / hero displays only. Forbidden on prose-bearing tokens (`body`, `heading`, `display`).

### 3.3 Spacing

Frozen tokens:

| Token | Value | Use |
|---|---|---|
| `Metrics.screenPadding` | `20pt` | Horizontal screen gutter (only) |
| `Metrics.sectionSpacing` | `16pt` | Vertical rhythm between top-level page sections (only) |

**v1 boundary:** intra-component spacing (padding inside cards, gap between chips, etc.) MAY use bare CGFloat literals from the set `{4, 8, 12, 16, 20}`. Other literals (`2, 6, 10, 14, 18, 24, …`) require either justification in the PR or migration to one of the five permitted values. A full named scale (`xxs`/`xs`/…) is deferred to v2.

### 3.4 Radius

Frozen tokens:

| Token | Value | Use |
|---|---|---|
| `Metrics.cardRadius` | `26pt` | Default rounded surface — `KAirSurface`, page cards, sheet bodies |
| `Metrics.compactRadius` | `16pt` | Inset surface — chips, mini-cards, inline tiles |

**v1 boundary:** capsule shapes use `Capsule(style: .continuous)` (i.e. radius = `.infinity` / shorter axis); this is a frozen shape, not a token. Other literal radii (`18`, `20`, `22`, `24`, `30`, `34`) are alias candidates (§6). The `120pt` glow-blob radius in `AppBackground` is a decorative implementation detail of that view, not a token.

### 3.5 Elevation

Three tiers are frozen. Values are normative.

| Token | Shadow color | Shadow α | Blur radius | Y-offset | Allowed use |
|---|---|---|---|---|---|
| `elevation.flat` | n/a | `0.00` | `0` | `0` | In-flow content, chips, status pills, anything nested inside an already-raised surface |
| `elevation.raised` | `#000000` | `0.06` | `12` | `+6` | Top-level cards (`KAirSurface` default), sheets at rest, page sections |
| `elevation.floating` | `#000000` | `0.08` | `14` | `+6` | Primary emphasized action (`KAirActionCapsule.emphasized`), modal entry, sheet in motion |

X-offset is `0` for all three. Blur and α are absolute, not multiplied by a system factor.

**v1 boundary:** components MUST pick one of the three tiers. Mixing tiers within a single visual cluster (e.g., two cards at `raised` + one at custom `radius 18, α 0.04`) is forbidden in new code. Existing off-grid shadows in `KAirSurface.hero` (`α 0.07`) and `KAirSurface.sunken` (`α 0.04`), `GlassCard` (`α 0.04, blur 18, y 10`), and `KAirActionCapsule` non-emphasized (`α 0.08, blur 10`) are §6 alias candidates and reroute on next touch.

### 3.6 Motion

Two tiers are frozen.

| Token | Curve | Duration / Response | Allowed use | Forbidden use |
|---|---|---|---|---|
| `motion.standard` | `.easeInOut` | `0.24s` | Layout shifts, opacity fades, color transitions, idle micro-state | Affirmative state change (accepted, dismissed, refresh) |
| `motion.emphasized` | `.spring(response: 0.42, dampingFraction: 0.82)` | response `0.42s` | Accepted / dismissed state, modal present / dismiss, content refresh entry & exit, "preserve / suppress" affordances | Continuous loops (spinners, shimmer), idle hover/press |

Reduce-motion: when the system flag is on, BOTH tokens collapse to a `0.12s` linear fade. (Implementation in components, not in tokens.)

**v1 boundary:** new components MUST pick one of these two. Inventing a third curve requires a §8 change.

---

## 4. State mapping

### 4.1 Section identity — `AppTheme.tint(for: AppSection)`

| `AppSection` | Tint role |
|---|---|
| `.chat` | `accentStrong` |
| `.health` | `success` |
| `.ai` | `sky` |
| `.maps` | `warning` |
| `.store` | `accent` |

Frozen. Adding a new section requires a new row here AND a new `AppSection` case in the same PR.

### 4.2 Domain mapping — `AppTheme.tint(for: String)` (health metric)

Behavior is frozen as it stands in `AppTheme.swift` (string keys → role). Signature is **not** frozen — see §6. Consumers MUST go through this function rather than re-implementing the lookup table.

### 4.3 Status band — `AppTheme.statusTint(for: String)`

Behavior is frozen (`stable|clean → success`, `watch|guarded → warning`, `skipped → accent`, default → `sky`). Signature is **not** frozen — see §6.

### 4.4 Component-state visual mapping (normative)

Every interactive or feedback-bearing component in v1 MUST express the seven states below by composing the axes given. A component MAY skip a state if the state is meaningless for it (e.g. a static chip has no `loading`); it MUST NOT invent a different visual treatment for a state that IS in this table.

Cell legend: `—` means "no change from default"; `tint` means "the component's tint role as resolved through §4.1–§4.3".

| State | Background | Border | Text / icon color | Container opacity | Icon swap | Motion to enter |
|---|---|---|---|---|---|---|
| **default** | role-resolved surface (`surface` for raised, `surfaceStrong` for inverted, transparent if in-flow) | `Palette.line` at `0.8pt` (raised); none (flat) | `textPrimary` (or `textOnStrong` on `surfaceStrong`); icon at `tint` | `1.0` | — | none |
| **accepted** | brief overlay of `success @ 0.10` for `motion.emphasized` duration, then return | brief `success @ 0.18`, then return to default | `success` for the inline confirmation label, if any | `1.0` | swap to `checkmark` glyph at `success` for the flash, then return | `motion.emphasized` (entry); revert via `motion.standard` |
| **dismissed** | — | — | `textMuted` if the component remains visible after dismissal | fade to `0` if removed; otherwise `0.6` | desaturate icon to `textMuted` | `motion.emphasized` (exit) |
| **loading** | — for the surrounding container; skeleton blocks at `backgroundInset` for content placeholders | — | secondary text becomes skeleton; `textPrimary` retained for any persistent label | container `1.0`; placeholder content blocks `1.0`; persistent text `0.6` | spinner glyph at `tint`, sized `meta` | `motion.standard` shimmer / rotation; loop |
| **empty** | `surface` | `Palette.line` | headline at `textSecondary`; supporting copy at `textMuted` | `1.0` | larger illustrative icon at `textMuted` | none |
| **error** | overlay of `danger @ 0.06` on `surface` | `danger @ 0.18` | headline at `textPrimary`; inline error label at `danger`; icon at `danger` | `1.0` | swap to `exclamationmark.triangle` at `danger` | `motion.emphasized` (entry) |
| **disabled** | — | `Palette.line` | `textMuted` for label and icon | container `0.5` | desaturate icon to `textMuted` | none — disabled does NOT animate hover / press / focus |

Notes:
- The `accepted` and `error` states are the only states allowed to introduce a colored alpha overlay on top of `surface`. No other state may tint the background.
- The `accepted` flash uses `motion.emphasized` for the in-stroke and `motion.standard` for the revert; this is the only state allowed to chain two motion tokens.
- Tokens used here (`success @ 0.10`, `danger @ 0.06 / 0.18`, etc.) are **derived alphas** of frozen colors. They are part of this table's contract, not new palette tokens.

---

## 5. Naming rules

1. **Semantic over literal.** `success` ✓. `mint` ✗. (This is why `HealthPalette.mint` is a §6 alias.)
2. **Namespace by axis.** Colors → `AppTheme.Palette`. Lengths → `AppTheme.Metrics`. New axes get a new sibling namespace (`AppTheme.Motion`, `AppTheme.Elevation`).
3. **Categorize colors.** Color roles fit one of: `background*` (canvas), `surface*` (object body), `text*` (ink on light), `textOn*` (ink on dark/strong), `line*` (border), or a status / accent semantic name. New colors propose the category in their PR or get rejected.
4. **No raw `Color.white` / `Color.black` in component code.** Always go through a role.
5. **No domain-specific palette outside this contract.** `HealthPalette` is grandfathered as alias-only. New domain palettes (Maps, Store, Chat) MUST consume `AppTheme.Palette` directly.
6. **State mapping goes through functions.** Section / metric / status → color is ALWAYS via §4.1–§4.3. Components never branch on `AppSection` themselves.

---

## 6. Alias / rename candidates (NOT contract)

These exist in code today but are explicitly NOT part of v1. New code MUST avoid them. Existing call sites stay until next touch, then migrate.

| Symbol | Ruling |
|---|---|
| `Palette.surfaceElevated` | **v1 does not freeze. New code MUST use `Palette.surface` instead.** Existing consumers (`MessageBubble`, `ComposerBar`) are grandfathered until next touch; on next touch they reroute to `surface`. v2 decides whether a real `surfaceElevated` value emerges. |
| `Palette.lineStrong` | No consumers; do not freeze. New code MUST NOT use it. v2 decides whether to retire or repurpose. |
| `AppTheme.tint(for: String)` signature | Behavior frozen (§4.2); signature not. v2 typechecks via a `HealthMetricToken` enum. New consumers SHOULD anticipate the rename. |
| `AppTheme.statusTint(for: String)` signature | Behavior frozen (§4.3); signature not. v2 typechecks via a `StatusBand` enum. |
| `HealthPalette.{mint, cyan, amber, coral}` | Color-name aliases of `success`, `sky`, `warning`, `danger`. Forbidden in new code. Existing call sites migrate on next touch. |
| `HealthPalette.{canvas, ink, mutedInk, cardStroke}` | Aliases of `backgroundStart`, `textPrimary`, `textSecondary`, `line`. Forbidden in new code. |
| Off-grid shadows in `KAirSurface.hero`, `KAirSurface.sunken`, `GlassCard`, `KAirActionCapsule` non-emphasized | Reroute to `elevation.raised` on next touch. |
| Eyebrow tracking `1.0` (existing in `KAirPageHeader`) | Migrate to `eyebrow` token (`1.2`) on next touch. |
| Spacing literals outside `{4, 8, 12, 16, 20}` | Justify in PR or migrate. |
| Radius literals outside `{16, 26}` and `Capsule` | Migrate to `compactRadius` / `cardRadius` on next touch, or document as a §3.4 boundary exception. |

---

## 7. Out-of-scope for v1

These are excluded from contract. New code MUST NOT introduce them; existing code referencing them is on borrowed time.

| Symbol / area | Why out-of-scope |
|---|---|
| `Palette.tabAccent` | No consumers. Either delete or repurpose post-v1. |
| `Palette.tabBar` | No consumers. Tab chrome is currently inline `Color.white`. |
| `HealthPalette.plum` | Local-only color with no `AppTheme` counterpart. Lift or accept it lives outside contract. |
| `HealthPalette.sky` (the `0.54, 0.60, 0.68` local variant — distinct from `Palette.sky`) | Naming collision with frozen role; do NOT rely on this symbol resolving to anything stable. |
| `HealthPalette.heroGradient` | Multi-stop gradient; not a token role yet. |
| `LiquidGlassSurface` modifier | iOS 26 platform feature; treated as a platform capability, not a token. |
| `AppBackground`'s `120pt` decorative blob | Implementation detail of that one view. |
| `.thin`, `.light`, `.heavy`, `.black` font weights | Forbidden in v1. |
| Custom font families | Forbidden in v1. |
| Dark-mode palette | Forbidden in v1. |
| Cross-platform tokens | Forbidden in v1. |
| Asset / icon tokens | Separate Assets contract. |

---

## 8. Change process

This document is contract; the Swift file is implementation. Both move through here.

1. **Adding a new frozen token.** Add the row to §3 with full value + use + change-scope. Add the value to `AppTheme.swift`. Ship at least one production consumer. Until a consumer ships, the row stays in §6 (alias candidate), not §3.
2. **Renaming or removing a frozen token.** v2 change. Open a v2 contract; v1 stays stable.
3. **Re-tuning a frozen value.** Permitted within the row's "allowed change scope". Update the value in this file AND `AppTheme.swift` in the same PR; bump the changelog (added on ratification).
4. **Promoting an alias / out-of-scope token to frozen.** Move the row into §3, lock the name, document at least one production consumer, declare its allowed change scope.
5. **Inventing a new state, motion curve, elevation tier, or text token.** Requires a §3 / §4 row added in the same PR as the first consumer; otherwise reject.

### 8.1 Ratification checklist

v1 is ratified when ALL of the following are true:

- [ ] All §3 frozen rows have a production consumer.
- [ ] §6 row "off-grid shadows" reaches zero remaining call sites OR each remaining call site has an exception line in §3.5.
- [ ] §6 row "eyebrow tracking 1.0" reaches zero remaining call sites.
- [ ] §6 rows for `HealthPalette.{mint, cyan, amber, coral, canvas, ink, mutedInk, cardStroke}` reach zero remaining call sites.
- [ ] No new code added since this draft references `Palette.surfaceElevated` directly.
- [ ] `tint(for: String)` and `statusTint(for: String)` either rename to typed signatures OR are formally accepted as v1-permanent (forces a v2 rename later).
- [ ] §4.4 component-state mapping has at least one component implementing each of the seven states end-to-end (proves the table is buildable).
