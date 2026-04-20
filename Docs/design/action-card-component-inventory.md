# Action Card Component Inventory

**Status**: Frozen (2026-04-19).
**Scope**: Every Action Card surfaced in Chat → Recommended Next.

This doc is the single source of truth for what is shared vs. what a specific card kind may bend on. It is read alongside `maps-ui-spec-v1.md`. If a future card (Music, Store, …) needs to diverge outside this matrix, file a v2 bump — do not ship the divergence.

## 1. Shared primitive

All cards are rendered by `ActionCardShell` ([DesignSystem/Components/ActionCardShell.swift](../../kAir/DesignSystem/Components/ActionCardShell.swift)). The shell freezes the 7 regions below and owns all visual tokens (padding, radius, shadow, colors, fonts, button style).

```
┌──────────────────────────────────────────────────────────────┐
│ (1) HEAD: label + ⋯ menu + ✕ dismiss                         │
├──────────────────────────────────────────────────────────────┤
│ (2) METADATA ROW: 0..n ActionCardTrustPill  ← includes (7)   │
├──────────────────────────────────────────────────────────────┤
│ (3) BODY: title · subtitle · optional reason (plain caption) │
├──────────────────────────────────────────────────────────────┤
│ (4) PRIMARY CTA: black-0.9 capsule                           │
│ (5) SECONDARY CTA: plain text (optional)                     │
└──────────────────────────────────────────────────────────────┘
(6) FEEDBACK AFFORDANCE: the ⋯ menu in (1), a11y label only
(7) PARTNER / SOURCE BADGE: rendered as a trust pill in (2)
```

The 7 regions are the only visual structure any card may carry. No overlays beyond the single state-badge (top-trailing) are allowed.

## 2. Region inventory — shared vs. allowed-difference

| Region                                   | Shared (frozen)                                                                                                       | Allowed per-kind difference                                                         |
| ---------------------------------------- | --------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| (1) Card head — label glyph & text       | Font (caption bold, uppercase). Color (accentStrong). Layout.                                                         | Copy + SF Symbol name. Nothing else.                                                |
| (1) Card head — ⋯ menu                   | Fixed set of items: all `MatchingFeedbackKind` except `.dismiss`. Item rendering. Trigger glyph.                      | **None.** All cards ship the same 4 feedback options.                               |
| (1) Card head — ✕ dismiss                | Glyph, size, color, tap target. Routes to `.dismiss`.                                                                 | **None.**                                                                           |
| (2) Metadata row                         | Scroll container, spacing, pill-only content. Empty row collapses to zero height.                                      | Which `ActionCardTrustPillKind` values appear. Ordering.                            |
| (3) Body — title                         | `title2`, bold, `textPrimary`, 2 lines max.                                                                           | Copy only.                                                                          |
| (3) Body — subtitle                      | `subheadline`, `textSecondary`, 3 lines max.                                                                          | Copy only.                                                                          |
| (3) Body — reason caption                | `caption`, medium, `textMuted`. Plain text; **no pill, no icon.**                                                     | Copy only.                                                                          |
| (3) Body — tap behavior                  | Whole body routes to `onCardTap`; `.contentShape(Rectangle())`.                                                       | **None.**                                                                           |
| (4) Primary CTA                          | Black-0.9 rounded rect (`compactRadius`), headline white text, `frame(maxWidth: .infinity)`, 16pt v-padding.          | Copy only. Enabled/disabled per state.                                              |
| (5) Secondary CTA                        | Plain text `subheadline semibold`, `textSecondary`, 12pt v-padding. Never styled destructive.                         | Copy only. Presence (may be nil).                                                   |
| (6) Feedback affordance a11y label       | Read from `feedbackAffordanceLabel` arg.                                                                              | Copy only.                                                                          |
| (7) Partner / source badge               | Renders as an `ActionCardTrustPill` inside region (2). No standalone slot.                                            | Whether a partner pill is included in `trustPills`.                                 |

**There is no allowed per-kind difference for:** padding, corner radius, shadow, container, background, stroke, button hierarchy, margin system, feedback item count, feedback position, body layout, CTA layout, or state-badge treatment.

## 3. Concrete card adapters

Every card kind is implemented as a thin adapter that maps its domain model onto `ActionCardShell`.

| Card kind                  | Adapter                                                                               | Trust pills supplied?                      |
| -------------------------- | ------------------------------------------------------------------------------------- | ------------------------------------------ |
| Unified (non-Maps default) | [DesignSystem/Components/UnifiedActionCard.swift](../../kAir/DesignSystem/Components/UnifiedActionCard.swift) | No (v1 — empty array).                     |
| Maps — goToPlace           | [Features/Maps/Presentation/MapActionCardView.swift](../../kAir/Features/Maps/Presentation/MapActionCardView.swift) | Yes (see §4 for rules).                    |
| Maps — nearbySearch        | Same as above.                                                                        | Yes.                                       |
| Maps — routeCompare        | Same as above.                                                                        | Yes.                                       |

`UnifiedActionCard` does **not** render trust pills in v1. Until another card kind earns its trust vocabulary, only Maps uses the metadata row. If / when Music ships, its trust pill set will be added to the shared enum (not forked into a Music-only type).

## 4. Maps-specific bindings (copy-only divergence)

Maps is allowed to supply:

- Header label copy + glyph, per task kind (locked in `MapActionCardView.taskKindLabel` / `taskKindSystemImage`):

  | Task kind     | zh 显示     | en display   | SF Symbol                                 |
  | ------------- | ----------- | ------------ | ----------------------------------------- |
  | goToPlace     | 去某地      | Go to place  | `mappin.and.ellipse`                      |
  | nearbySearch  | 附近探索    | Nearby       | `location.magnifyingglass`                |
  | routeCompare  | 路线查看    | Route        | `arrow.triangle.turn.up.right.diamond`    |

- Trust-pill array, drawn from the frozen `ActionCardTrustPillKind` vocabulary (§5). Pill choice is data-driven — it is not allowed to depend on the task kind alone.

- State-badge overlay (loading / accepted / dismissed). This remains on `MapActionCardView` because it is bound to `MapActionCardState`, which other card kinds don't share today. If Music adopts a 4-state lifecycle, we merge the badge into the shell.

Maps is **not** allowed to supply: custom padding, corner radius, button style, reason-chip pill (removed in v1 refactor), custom feedback affordance position, or any visual property not explicitly listed above.

## 5. Trust pill vocabulary (frozen)

Defined in [DesignSystem/Components/ActionCardShell.swift](../../kAir/DesignSystem/Components/ActionCardShell.swift). Each case owns: a zh/en title, a SF Symbol, and a tone (`positive` / `warning` / `neutral`). Callers cannot override copy.

| Kind                             | zh 显示          | en display              | Tone     |
| -------------------------------- | ---------------- | ----------------------- | -------- |
| `placeResolutionLive`            | 实时地点         | Live place              | positive |
| `placeResolutionStub`            | 估算地点         | Estimated place         | neutral  |
| `etaConfidenceEstimate`          | ETA 估算         | ETA estimate            | neutral  |
| `distanceConfidenceEstimate`     | 距离估算         | Distance estimate       | neutral  |
| `partnerFallback`                | 合作方待接入     | Partner pending         | warning  |
| `locationPermissionDenied`       | 无定位权限       | No location permission  | warning  |
| `locationPermissionManual`       | 手动地点         | Manual place            | warning  |

Adding a new case is a v2 event on `maps-ui-spec-v1.md`.

## 6. No-go list (explicit spec violations)

If you find yourself doing any of these, stop and revisit the spec:

- A card with custom corner radius / padding / shadow that does not go through `KAirSurface(.elevated, padding: 0)` + `ActionCardShell`.
- A Maps-only primary-button treatment (color, height, font).
- Any trust pill whose copy is not in the vocabulary table (§5).
- A reason caption rendered as a pill, capsule, or colored tag.
- A destructive secondary CTA (red text, alert dialog confirmation).
- A feedback affordance placed outside the card head.
- A return-to-chat affordance hidden on the execution surface first screen.
- Any free-form "status text" in place of a trust pill or the error strip.
