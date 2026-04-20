# Super App Visual System — v1 (frozen)

Round 6 P1 spec. This is the **single visual contract** for every layer of the
kAir super-app: Chat Home, Recommended Next, and every Execution Surface
(Maps, Music, Health, Search, and every future vertical).

All three layers resolve to the tables below. If a vertical needs something
that isn't in this doc, the vertical doesn't ship — the doc bumps to v2
first. This is what it means to "freeze."

**This spec is not polish.** It defines structure, tokens, state vocabulary,
copy rules, and the shells every layer must route through. Animation curves,
motion, haptics, and iconography beyond what is listed here are explicitly
out of scope for v1.

> **Source of truth.** Every numeric token in this document is also encoded
> in code under `kAir/DesignSystem/Tokens/` and `kAir/DesignSystem/Components/`.
> If this doc and code diverge, the code is wrong and must be fixed — the
> lock tests under `kAir/DesignSystem/Tests/` are written against this doc,
> not against the code.

---

## §1 — Three layers, one system

| Layer                | Shell                                     | Allowed primary region                | Allowed surrounding regions |
|----------------------|-------------------------------------------|---------------------------------------|------------------------------|
| Chat Home            | `ChatHomeView` + composer + top bar       | Message bubbles + tool results        | `RecommendedNextConsole` bottom inset |
| Recommended Next     | `UnifiedActionCard` → `ActionCardShell`   | One `ActionCardShell` per recommendation | None (lives inside Chat Home) |
| Execution Surface    | `ExecutionSurfaceShell` (7 regions, locked) | One `ActionCardShell` per vertical   | Vertical-supplied supplementary cards |

**Verticals may not introduce their own shell.** Maps, Music, Health, Search,
Video, Store all instantiate `ExecutionSurfaceShell`. The primary card is
always an `ActionCardShell`. Vertical-specific content appears only inside
the `ActionCardShell.body` slots (title, subtitle, reasonText, CTA titles)
and inside the `ExecutionSurfaceShell.supplementary` region.

---

## §2 — Typography scale

Fonts are resolved via SwiftUI `.font(...)` modifiers. No custom font family
is shipped in v1 — everything is the system font. Weights are from
`Font.Weight`. Sizes come from Apple's dynamic type table (we don't hardcode
point sizes).

| Role                  | SwiftUI font                         | Used where                        | Notes                                 |
|-----------------------|--------------------------------------|-----------------------------------|---------------------------------------|
| `display`             | `.largeTitle.weight(.bold)`          | `ExecutionSurfaceTitle.title`     | One per surface, never inside cards   |
| `title-card`          | `.title2.weight(.bold)`              | `ActionCardShell.title`           | One per card                          |
| `title-inline`        | `.title3.weight(.semibold)`          | Place rows, nav steps             | For dense inline content              |
| `headline`            | `.headline`                          | Section headers, card head label  | Never inside bodies                   |
| `body`                | `.body`                              | `ExecutionSurfaceTitle.summary`   | The only long-form region             |
| `subheadline`         | `.subheadline`                       | `ActionCardShell.subtitle`        | Up to 3 lines                         |
| `caption-strong`      | `.caption.weight(.semibold)`         | Trust pills, status strip         | Tracking `1.0` on eyebrows            |
| `caption-muted`       | `.caption.weight(.medium)`           | `ActionCardShell.reasonText`      | Muted color only                      |
| `caption-micro`       | `.caption2.weight(.semibold)`        | Pill labels                       | Only inside trust pills               |
| `eyebrow`             | `.caption.weight(.bold)` + uppercase + `tracking(1.0)` | Surface eyebrow | One per surface                       |

**Do not invent new type roles.** If a design needs something between
`subheadline` and `body`, use `subheadline` and change the layout instead.

---

## §3 — Spacing, radius, stroke, shadow

All numeric tokens come from `AppTheme.Metrics` unless noted.

| Token                 | Value           | Used where                                           |
|-----------------------|-----------------|------------------------------------------------------|
| `screenPadding`       | **20pt**        | Horizontal edge padding on `ExecutionSurfaceShell` and `ChatHomeView` |
| `sectionSpacing`      | **16pt**        | Vertical spacing between top-level regions inside a shell |
| `cardRadius`          | **26pt**        | `KAirSurface` background + border                    |
| `compactRadius`       | **16pt**        | Inline tiles, metric boxes, inner chips              |
| Stroke (hairline)     | **0.8pt**       | `KAirSurface` border (`AppTheme.Palette.line`)       |
| Stroke (trust-pill)   | **0.8pt**       | Trust pill outline                                   |
| Stroke (emphasis)     | **1.0pt**       | Pill outlines, segmented pickers                     |
| Shadow (hero)         | `black 7% · r12 · y6` | `KAirSurface(style: .hero)`                  |
| Shadow (elevated)     | `black 6% · r12 · y6` | `KAirSurface(style: .elevated)` (default)    |
| Shadow (sunken)       | `black 4% · r12 · y6` | `KAirSurface(style: .sunken)`                |

Card fill is pure `Color.white` across all three styles — the style only
changes the **shadow opacity**. No fill gradients in v1.

---

## §4 — Color palette

All colors come from `AppTheme.Palette`. Hex values below are derived from
the raw RGB tuples in `AppTheme.swift` (and are the binding contract: if the
code ships different values, the code is wrong).

### §4.1 — Neutral tokens

| Token             | sRGB (r, g, b)          | Hex     | Used where                                                |
|-------------------|-------------------------|---------|-----------------------------------------------------------|
| `accent`          | 0.35, 0.37, 0.41        | #595E68 | Secondary accent, muted chrome                            |
| `accentStrong`    | 0.10, 0.11, 0.13        | #1A1C21 | Primary CTA fill, strong text, tab accent                 |
| `tabAccent`       | 0.15, 0.16, 0.18        | #26292E | Bottom-tab selection indicator                            |
| `backgroundStart` | 1.00, 1.00, 1.00        | #FFFFFF | `AppBackground` top color                                 |
| `backgroundEnd`   | 0.97, 0.97, 0.975       | #F7F7F9 | `AppBackground` gradient stop                             |
| `backgroundInset` | 0.985, 0.985, 0.99      | #FBFBFC | `AppBackground` ambient blur blob                         |
| `surface`         | white                   | #FFFFFF | Primary card fill                                         |
| `surfaceElevated` | white                   | #FFFFFF | Card fill (same as `surface`; distinguished by shadow)    |
| `surfaceStrong`   | 0.15, 0.16, 0.18        | #26292E | Profile avatar, dark chips                                |
| `tabBar`          | white                   | #FFFFFF | Bottom tab bar                                            |
| `line`            | `black @ 6%`            | #000000 6% | Default hairline strokes                               |
| `lineStrong`      | `black @ 10%`           | #000000 10% | Emphasis hairline                                     |

### §4.2 — Text tokens

| Token           | sRGB (r, g, b)       | Hex     | Used where                                                   |
|-----------------|----------------------|---------|--------------------------------------------------------------|
| `textPrimary`   | 0.11, 0.12, 0.13     | #1C1F21 | Card titles, list rows, large headings                       |
| `textSecondary` | 0.34, 0.35, 0.37     | #565A5E | Subtitles, summaries                                         |
| `textMuted`     | 0.51, 0.52, 0.54     | #82858B | Captions, muted eyebrows, status strip                       |
| `textOnStrong`  | white                | #FFFFFF | Text inside `accentStrong` / `surfaceStrong` backgrounds     |

### §4.3 — State tokens

Only these four state colors exist in v1. Verticals do NOT introduce their
own state colors. Every state-bearing surface maps to one of these.

| Token      | sRGB (r, g, b)       | Hex     | Meaning                                  | Surface examples                           |
|------------|----------------------|---------|------------------------------------------|--------------------------------------------|
| `success`  | 0.31, 0.43, 0.38     | #4F6D61 | Ready, positive, available               | `.ready` state icon, positive trust tone   |
| `warning`  | 0.57, 0.46, 0.29     | #92754A | Error, unavailable, permission needed    | `.error`, `.permissionOrUnavailable` states; warning pills |
| `danger`   | 0.62, 0.34, 0.30     | #9E564C | Destructive, critical (used sparingly)   | Reserved for terminal destructive actions  |
| `sky`      | 0.38, 0.45, 0.54     | #61738A | Informational, secondary indicator       | Map origin badge, info metrics             |

### §4.4 — State ↔ color mapping (canonical)

| `ExecutionSurfaceSystemState` | Icon (SF Symbols)         | Tint       |
|-------------------------------|---------------------------|------------|
| `.ready`                      | `checkmark.circle`        | `success`  |
| `.loading`                    | `hourglass`               | `accentStrong` |
| `.empty`                      | `tray`                    | `textMuted` |
| `.error`                      | `exclamationmark.triangle.fill` | `warning` |
| `.permissionOrUnavailable`    | `lock.shield`             | `warning`  |

---

## §5 — Card density & region ownership

### §5.1 — Frozen card primitive

**Every card** in the super-app is an `ActionCardShell` with exactly these
7 regions. No other card primitive exists.

| # | Region               | What lives here                                             | Mandatory? |
|---|----------------------|-------------------------------------------------------------|------------|
| 1 | Head                 | uppercase eyebrow + feedback `⋯` menu + dismiss `×`         | Yes        |
| 2 | Metadata             | 0..n `ActionCardTrustPill` values (shared vocabulary)       | No         |
| 3 | Body                 | title + subtitle + optional reasonText                      | Yes        |
| 4 | Primary CTA          | black capsule, full-width, 16pt vertical padding            | Yes        |
| 5 | Secondary CTA        | plain-text button, optional                                 | No         |
| 6 | Feedback affordance  | accessible label on the `⋯` menu (in head)                  | Yes        |
| 7 | Partner/source badge | rendered as a trust pill inside region 2                    | No         |

### §5.2 — Frozen surface primitive

Every Execution Surface is an `ExecutionSurfaceShell` with exactly these
7 regions.

| # | Region                      | What lives here                                         | Vertical can customize? |
|---|-----------------------------|---------------------------------------------------------|--------------------------|
| 1 | Nav rail                    | back-to-chat capsule with chevron (locked copy §9)      | No                       |
| 2 | Task title region           | eyebrow + display title + body summary                  | Copy only                |
| 3 | Primary action region       | exactly one `ActionCardShell`                           | Copy + CTA + pills       |
| 4 | Status region               | optional inline status/error strip                      | Copy only                |
| 5 | Partner / source row        | trust pills drawn from shared vocabulary                | Selection only           |
| 6 | State region                | locked state title + summary + "Back to chat" button    | No                       |
| 7 | Terminal-state row          | optional "surface completed" banner                     | Copy + icon              |

**No vertical may rearrange these regions.** Supplementary content lives
in `ExecutionSurfaceShell.supplementary`, below region 6, and must use
`KAirSurface(style:)` tiles, not new containers.

### §5.3 — Density

Density is fixed. v1 does not ship a compact mode.

| Container                   | Padding        | Max width | Notes                              |
|-----------------------------|----------------|-----------|------------------------------------|
| `KAirSurface(.hero)`        | 18pt all sides | infinity  | Used by `ExecutionSurfaceShell.heroRegion` |
| `KAirSurface(.elevated)`    | 18pt all sides | infinity  | Default surface                    |
| `KAirSurface(.elevated, padding: 0)` | n/a  | infinity  | For cards that manage their own padding (`ActionCardShell`) |
| `KAirSurface(.sunken)`      | 18pt all sides | infinity  | Meta tiles, terminal row, supplementary |
| `ActionCardShell` head      | 20pt H · 12pt T · 8pt B | infinity  | Locked                             |
| `ActionCardShell` body      | 20pt H · 0 V · 16pt B   | infinity  | Locked                             |
| `ActionCardShell` actions   | 20pt H · 20pt B | infinity  | Locked                             |
| Primary CTA                 | 16pt V · full width | infinity  | Black `0.9 opacity` capsule, `compactRadius` |
| Secondary CTA               | 12pt V · full width | infinity  | Plain text button                  |

---

## §6 — CTA hierarchy

Exactly three CTA tiers exist in v1. No vertical may add a fourth.

| Tier      | Visual                                              | Used for                                           |
|-----------|-----------------------------------------------------|----------------------------------------------------|
| Primary   | Black capsule (`accentStrong @ 0.9`, white text), `compactRadius` corners, `.headline` font | One per `ActionCardShell`          |
| Secondary | Plain-text button in `textSecondary`, `.subheadline.weight(.semibold)` | Optional, below primary              |
| Capsule   | `KAirActionCapsule` (rounded outlined pill)         | Nav rail back button, in-card link-style actions   |

Disabled state: primary CTA at **55% opacity**, `primaryEnabled = false`.
No other visual disabled state exists.

---

## §7 — Trust pill vocabulary

v1 freezes exactly these 7 trust pill kinds (`ActionCardTrustPillKind`).
Verticals do **not** invent their own pill enum. Adding a new pill kind is
a v2 bump for this doc.

| Case                           | en                       | zh           | Glyph                            | Tone     |
|--------------------------------|--------------------------|--------------|----------------------------------|----------|
| `placeResolutionLive`          | Live place               | 实时地点     | `mappin.circle.fill`             | positive |
| `placeResolutionStub`          | Estimated place          | 估算地点     | `mappin.and.ellipse`             | neutral  |
| `etaConfidenceEstimate`        | ETA estimate             | ETA 估算     | `clock`                          | neutral  |
| `distanceConfidenceEstimate`   | Distance estimate        | 距离估算     | `ruler`                          | neutral  |
| `partnerFallback`              | Partner pending          | 合作方待接入 | `square.stack.3d.up.slash`       | warning  |
| `locationPermissionDenied`     | No location permission   | 无定位权限   | `location.slash`                 | warning  |
| `locationPermissionManual`     | Manual place             | 手动地点     | `hand.point.up.braille`          | warning  |

### Tone → color

| Tone     | Foreground       | Outline                |
|----------|------------------|------------------------|
| positive | `success`        | `success @ 18%`        |
| neutral  | `textMuted`      | `textMuted @ 18%`      |
| warning  | `warning`        | `warning @ 18%`        |

### Pill geometry

| Property        | Value                                          |
|-----------------|------------------------------------------------|
| Font            | `.caption2.weight(.semibold)`                  |
| Icon spacing    | 5pt between glyph and label                    |
| Padding         | 9pt horizontal · 4pt vertical                  |
| Fill            | `Color.white`                                  |
| Shape           | `Capsule(style: .continuous)`                  |
| Stroke          | 0.8pt in `tone.borderColor` (tone foreground @ 18%) |

---

## §8 — Icon & badge sizes

| Element                       | Geometry                              | Font / weight                |
|-------------------------------|---------------------------------------|------------------------------|
| Profile avatar (top bar)      | 30pt × 30pt circle, `surfaceStrong`   | `.caption.weight(.bold)` "K" |
| Status pill (`KAirStatusPill`)| 12pt H · 8pt V · capsule              | `.caption.weight(.semibold)` |
| Trust pill (§7)               | 9pt H · 4pt V · capsule               | `.caption2.weight(.semibold)` |
| State-region icon             | `.headline` size                      | tint per §4.4                |
| Terminal-row icon             | `.headline` size, `success` tint      | fixed                        |
| Map annotation badge          | 28pt × 28pt circle, tinted            | `.caption.weight(.bold)` glyph, white |
| Map overlay button            | 12pt H · 10pt V, capsule + shadow     | `.caption.weight(.semibold)` |

SF Symbols resolve at SwiftUI's default rendering weights. No custom icon
pack ships in v1.

---

## §9 — State vocabulary (frozen)

### §9.1 — System-state enum (exactly 5)

```
ExecutionSurfaceSystemState = {
  .ready,
  .loading,
  .empty,
  .error,
  .permissionOrUnavailable
}
```

**No other states exist.** If a vertical needs a condition that doesn't map
to one of the five, it's a data issue, not a new state — re-shape the data.

### §9.2 — Locked copy (source = `ExecutionSurfaceLockedCopy`)

| Context                                 | en                                     | zh                               |
|-----------------------------------------|----------------------------------------|----------------------------------|
| Back to chat button                     | Back to chat                           | 返回聊天                          |
| `.ready` — title                        | Ready                                  | 就绪                              |
| `.ready` — summary                      | *(empty)*                              | *(empty)*                         |
| `.loading` — title                      | Loading                                | 正在加载                          |
| `.loading` — summary                    | Preparing this task — you can come back in a moment. | 正在准备这次任务，稍后回来即可。          |
| `.empty` — title                        | Nothing to show                        | 暂无结果                          |
| `.empty` — summary                      | No matches this time. Return to chat and try a different phrasing. | 这次没有匹配到内容，可以返回聊天换个说法再试。 |
| `.error` — title                        | Something went wrong                   | 出错了                            |
| `.error` — summary                      | Something went wrong — returning to chat is safe. (overridable via `ExecutionSurfaceStatus.errorMessage`) | 出现了问题，可以返回聊天继续。（可用 `errorMessage` 覆写） |
| `.permissionOrUnavailable` — title      | Permission or service unavailable      | 权限或服务不可用                     |
| `.permissionOrUnavailable` — summary    | This needs a permission or a service that is not ready. Return to chat or adjust in another card. | 需要权限或服务暂不可用。可以返回聊天，或者在其他卡片中调整。 |

**Error summary override rule:** if `status.errorMessage` is non-empty, it
replaces the `.error` summary. Empty string falls back to the locked copy.
No other state accepts an override in v1.

### §9.3 — Recommended Next / ActionCard states

Recommended cards ride on the same `ActionCardShell` and use the system-state
vocabulary above. There is no separate "card state" enum. Accepted, dismissed,
feedback-resolved states are modeled via `MatchingFeedbackKind` (5 cases:
`.dismiss`, `.notInterested`, `.lessLikeThis`, `.notNow`, `.alreadyDone`).

### §9.4 — Visual mapping table

| Visual state   | Where it shows                             | Icon                         | Tint          | Copy source            |
|----------------|--------------------------------------------|------------------------------|---------------|------------------------|
| Loading        | Execution state region, primary CTA "…"   | `hourglass`                  | `accentStrong` | §9.2 loading           |
| Empty          | Execution state region                     | `tray`                       | `textMuted`   | §9.2 empty             |
| Error          | Status strip (inline) OR state region      | `exclamationmark.triangle.fill` | `warning` | `status.errorMessage` or §9.2 error |
| Accepted       | Recommended card dismissed + new chat message | none                      | `success`     | per-vertical return msg |
| Dismissed      | Recommended card removed                   | none                         | n/a           | (no UI)                |
| Permission     | State region                               | `lock.shield`                | `warning`     | §9.2 permissionOrUnavailable |

---

## §10 — Language, formatting, numeric display

### §10.1 — Two locked languages

English (`en`) and Simplified Chinese (`zh`). Every user-facing string that
ships in v1 has a zh and en variant. Unknown locale falls back to en.

### §10.2 — Title / summary length rules

| Region                    | Hard cap (en / zh) | Wrapping                |
|---------------------------|--------------------|-------------------------|
| `ExecutionSurfaceTitle.title` | 48 chars / 24 汉字 | Single line preferred, wraps if needed |
| `ExecutionSurfaceTitle.summary` | ~180 chars / ~90 汉字 | Free-wrap, no `lineLimit` |
| `ActionCardShell.title`   | 36 chars / 18 汉字 | Single line preferred   |
| `ActionCardShell.subtitle` | 140 chars / 70 汉字 | `.lineLimit(3)`         |
| `ActionCardShell.reasonText` | 80 chars / 40 汉字 | Wraps freely         |
| Trust pill title          | 18 chars / 6 汉字  | Never wraps             |

### §10.3 — Numeric formatting

| Kind            | Formatter                                          | Example      |
|-----------------|----------------------------------------------------|--------------|
| ETA             | Integer minutes + `min` / `分钟` (no seconds)      | `16 min` / `16 分钟` |
| Distance        | 1-decimal miles/km or int meters                   | `1.2 mi` / `1.2 公里` |
| Time-of-day     | `.dateTime.hour().minute()`                        | `09:42`      |
| Counts          | Integer, no thousands grouping below 10k           | `482 nights` |

---

## §11 — Animation rules (definition only)

v1 does not ship a motion system. Only these three animation tokens exist,
and they are applied only where called out below.

| Token            | Curve                                   | Used where                          |
|------------------|-----------------------------------------|-------------------------------------|
| `expand`         | `.spring(response: 0.4, dampingFraction: 0.8)` | `RecommendedNextConsole` expand/collapse |
| `fade`           | SwiftUI default `.easeInOut` (no custom duration) | Card insertion / removal   |
| `pulse`          | Not implemented — v2                    | Reserved                            |

No custom transitions, staggers, or entrance effects. A card appears; a card
disappears. Nothing else.

---

## §12 — Accessibility invariants

| Requirement                              | How it's enforced                         |
|------------------------------------------|-------------------------------------------|
| Every interactive surface has a label    | `.accessibilityLabel` on nav rail, trust row, dismiss, feedback menu |
| Dynamic type supported end-to-end        | Only `.font(...)` tokens (§2) — no hardcoded sizes |
| Color is never the only signal           | Every state has an icon AND a tint (§4.4) |
| Tap target ≥ 44pt                        | CTA vertical padding + hitbox padding on `⋯` and `×` (8pt) |

---

## §13 — What's explicitly OUT of scope for v1

If you need one of these, this doc doesn't cover you and v2 has to
open first:

- Dark mode palette (v1 is light-only — white surfaces, hairline strokes)
- Custom fonts / variable-font tables
- Compact / dense mode for iPad-class devices
- Third interactive tier beyond primary / secondary / capsule
- Per-vertical pill vocabulary (everything goes through §7)
- Haptic tokens / haptic contracts
- Motion polish (§11 is skeletal by design)
- Theming per-surface — every vertical shares the neutral palette

---

## §14 — What the lock tests verify (T6 + T8 today)

| Lock                                                 | Test                                     |
|------------------------------------------------------|------------------------------------------|
| Back-to-chat copy is `Back to chat` / `返回聊天`     | T6 `shell_back_to_chat_copy_locked` + T8 `shell_guard_back_to_chat_single_source` |
| 5 `ExecutionSurfaceSystemState` cases, no drift       | T6 `shell_state_enum_frozen` + T8 `shell_guard_system_state_cardinality` |
| State title/summary copy per zh/en                   | T6 `shell_state_title_copy_locked`, `shell_state_summary_copy_locked` |
| `.error` accepts override, empty falls back          | T6 `shell_error_summary_prefers_override` |
| Trust pills draw from shared 7-case enum             | T8 `shell_guard_trust_pill_shared_vocabulary` + Music T7 pills |
| Health phase → framework state                        | T8 `shell_guard_health_state_mapping` |
| Music kinds stay at 3                                | T7 `music_three_task_kinds` + T8 `shell_guard_music_task_kind_cardinality` |
| `AppBootstrap.returnToChat` is the only return path  | T8 `_ShellReturnContract.selector` (compile-time witness) |

New verticals that ship must add a `_ShellReuseTests` suite proving they
reuse `ActionCardShell` + `ExecutionSurfaceShell` unchanged. See Search
T9 (Round 6 P2) for the template.

---

## §15 — Version history

| Version | Date (AD) | What changed                                   |
|---------|-----------|------------------------------------------------|
| v1      | 2026-04-20 | Initial freeze. Supersedes ad-hoc per-vertical color and state choices in maps-ui-spec-v1.md, music-ui-spec-v0.md, and the now-decommissioned Health private shell. |
