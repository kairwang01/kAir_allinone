# Maps UI Spec v1

**Status**: Frozen (2026-04-19).
**Scope**: Three Maps task kinds × two user-visible surfaces. Nothing else.

Covered task kinds (frozen; no 4th/5th type will be added under v1):

| Kind          | zh 显示      | en display        |
| ------------- | ------------ | ----------------- |
| `goToPlace`   | 去某地       | Go to place       |
| `nearbySearch`| 附近探索     | Nearby            |
| `routeCompare`| 路线查看     | Route             |

Covered surfaces:

1. **Recommended Next** — the single `MapActionCardView` shown inside a chat reply.
2. **Maps Execution Surface** — the first screen a user sees after accepting the card (`MapsHomeView` root, above the fold).

Anything deeper (place details, step-by-step navigation, settings) is explicitly **out of v1**. This spec does not cover those surfaces — they will be re-reviewed before they ship.

The card content contract is frozen in `MapActionCardModel.swift`: 6 content fields, 4 states, 5 events. This spec locks the *user-facing rendering and copy rules* for those fields and states. If a new field is ever needed, bump to v2 — do not stretch v1 semantics.

---

## 1. Recommended Next — `MapActionCardView`

### 1.1 Layout (frozen)

```
┌────────────────────────────────────────────────────────────┐
│  [kind-label]   ICON TEXT                 [⋯ menu]  [✕]    │  ← HEADER ROW
├────────────────────────────────────────────────────────────┤
│  📍  partner · trust · permission pill row                 │  ← METADATA ROW (v1 addition)
├────────────────────────────────────────────────────────────┤
│                                                            │
│   Title (title2, bold, 2 lines max)                        │  ← BODY
│   Subtitle (subheadline, 3 lines max, muted)               │
│   · reason chip · (caption, muted)                         │
│                                                            │
├────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Primary Action (CTA)                    │  │  ← ACTION STACK
│  │  (black 0.9 capsule, 16pt v-padding, white text)     │  │
│  └──────────────────────────────────────────────────────┘  │
│            Secondary Action (plain text, optional)         │
└────────────────────────────────────────────────────────────┘
```

Padding is fixed: outer edges 20pt horizontal, 12pt top, 20pt bottom. Gap between body and action stack is 16pt. The metadata row is optional and collapses to zero height when empty, so a card with no trust affordance must visually match the pre-v1 layout.

The card is rendered inside the shared `ActionCardShell` primitive. Maps **must not** introduce its own container, its own shadow, its own corner radius, or its own margins. A visual divergence = spec violation.

### 1.2 Field → slot mapping (frozen)

The 6 frozen content fields from `MapActionCardModel` map into the layout above as follows. No other mapping is allowed.

| `MapActionCardModel` field       | Slot               | Font / style                                   |
| -------------------------------- | ------------------ | ---------------------------------------------- |
| `taskKind` (derived)             | Header label + icon| caption, bold, uppercase, accentStrong         |
| `title`                          | Body line 1        | title2, bold, textPrimary, 2 lines max         |
| `subtitle`                       | Body line 2        | subheadline, textSecondary, 3 lines max        |
| `reasonChipText`                 | Body line 3        | caption, medium, textMuted — **plain text, no pill** |
| `primaryActionTitle`             | Primary CTA label  | headline, white on black-0.9 capsule            |
| `secondaryActionTitle` (nilable) | Secondary text CTA | subheadline semibold, textSecondary             |
| `feedbackAffordanceLabel`        | Header menu a11y   | reader-only — drives the `⋯` accessibility label |

The reason chip was previously rendered as a capsule in `MapActionCardView` only. That rendering is removed in v1 — it is the Maps visual fork that this spec eliminates (see §3).

### 1.3 Title rules

- `title` comes straight from the underlying `UnifiedMatchingCandidate.title`. The card does **not** prefix, suffix, reformat, or translate it.
- Max 2 lines. Tail truncation. No ellipsis dance, no auto-resize.
- Language follows `model.language`; zh and en are the only dimensions allowed to vary copy. No per-region override.

### 1.4 Aux info rules (subtitle + reason chip)

- `subtitle` is the candidate summary. Max 3 lines. Muted foreground.
- `reasonChipText` is mandatory and is always prefixed by `MapActionCardCopy.reasonChipPrefix` (`Why` / `为什么推荐`). No emoji, no icon.
- Neither subtitle nor reason may carry ETAs, distances, or partner names — those belong in the **metadata row** (§1.5). Mixing them into the subtitle is a spec violation.

### 1.5 Metadata row (trust layer, v1 addition)

The metadata row sits directly below the header and above the body. It is the only place trust affordances are allowed on the card. It renders zero or more **trust pills** using `ActionCardTrustPill`. When empty, the row is removed from the layout tree.

Supported pills in v1 (frozen — new pills require v2 bump):

| Pill kind                | zh copy                   | en copy                    | When shown                                                                         |
| ------------------------ | ------------------------- | -------------------------- | ---------------------------------------------------------------------------------- |
| `.placeResolutionLive`   | 实时地点                  | Live place                 | Place resolution returned a real candidate from a live provider.                   |
| `.placeResolutionStub`   | 估算地点                  | Estimated place            | Place resolution used stubbed fixture data. This is the current default.           |
| `.etaConfidenceEstimate` | ETA 估算                  | ETA estimate               | Route ETA comes from a canned provider (current default).                          |
| `.distanceConfidenceEstimate` | 距离估算             | Distance estimate          | Distance comes from stubbed geometry (current default).                            |
| `.partnerFallback`       | 合作方待接入              | Partner pending            | Partner integration is not yet wired (current default).                            |
| `.locationPermissionDenied` | 无定位权限             | No location permission     | `MapPermissionState == .denied`.                                                   |
| `.locationPermissionManual` | 手动地点               | Manual place               | `MapPermissionState == .manualOnly`.                                               |

Copy is hard-locked. Pills render as 11pt capsule tiles with a system icon. **No free-form text.** If a situation isn't covered by one of the kinds above, the card must render **no** pill rather than inventing a label. This is the single knob that stops trust UI from drifting.

### 1.6 Primary / secondary button rules

- **Primary CTA** is always the activation path. Copy is locked per kind:
  - `goToPlace`   → `Go here`   / `去这里`
  - `nearbySearch`→ `Explore nearby` / `看看附近`
  - `routeCompare`→ `Compare routes` / `看路线`
  Button disables (greyed, still focusable) when card state is `.accepted` or `.dismissed`.
- **Secondary CTA** is optional. When present, its copy is also locked per kind:
  - `goToPlace`   → `Change destination` / `换个目的地`
  - `nearbySearch`→ `Change keyword`     / `换个关键词`
  - `routeCompare`→ `Change origin`      / `换个出发点`
  Secondary CTA is plain text, not a capsule. It must never be styled as a destructive action.
- The accept/primary button routes into `MapActionCardEvent.accept`. The secondary routes into its host's `onSecondaryAction` handler; it does **not** fan out to a different event bucket — this is deliberate, it keeps telemetry tied to the frozen 5 events.

### 1.7 Negative feedback entry (frozen)

Two affordances, both in the header row:

1. `⋯` menu — expands all non-`.dismiss` `MatchingFeedbackKind` values. Accessibility label comes from `feedbackAffordanceLabel`.
2. `✕` button — always routes to `.dismiss`.

No other path is allowed to dismiss a card. Swipe-to-dismiss is **out of scope** for v1. Long-press feedback is out of scope. Everything funnels through these two controls.

### 1.8 Return-to-chat entry (from the card)

The card itself does not own a return control — the host chat surface owns it. The card only guarantees:

- Tapping the body routes into `.tap` (opens the execution surface).
- Tapping primary CTA routes into `.accept` (opens the execution surface with intent).
- Neither path is allowed to leave the user without a return route. The execution surface (§2) is responsible for rendering the return control.

### 1.9 Four system states on the card

State machine is locked to `MapActionCardState`. Each state has a single visual treatment; no new treatments are allowed.

| State          | Card opacity | Primary CTA   | Badge overlay (top-trailing)      | Metadata row                |
| -------------- | ------------ | ------------- | --------------------------------- | --------------------------- |
| `.loading`     | 1.0          | enabled       | `Loading` / `加载中` pill         | show — may include skeleton |
| `.recommended` | 1.0          | enabled       | none                              | show                        |
| `.accepted`    | 1.0          | disabled      | `Accepted` / `已接入` pill        | show                        |
| `.dismissed`   | 0.4          | disabled      | `Dismissed` / `已忽略` pill       | show but desaturated        |

The four system states listed in the P0 directive — loading / empty / error / location permission — map onto the card as follows:

- **Loading**: card state is `.loading`. Body renders normally; trust pills and badge signal uncertainty.
- **Empty (no recommendation to show)**: the card is **not rendered at all**. Chat falls through to its regular no-recommendation copy. This is a first-class state: "no card" is a valid rendering.
- **Error (recommendation failed to build)**: same as empty — the card does not render. The upstream `fromRecommendation` factory returning `nil` is the contract.
- **Location permission**: card still renders; its metadata row carries either `.locationPermissionDenied` or `.locationPermissionManual` pill. Primary CTA copy does **not** change — the degradation is visible in the pill, not in the button.

The card never renders a partial / skeleton version of the body. Either the 6 fields are present, or the card does not render.

---

## 2. Maps Execution Surface — first screen

The first screen is everything visible without scrolling after the user taps the card. Below-the-fold cards (InAppNavigationCard, LookAroundCard, RouteListCard tail, etc.) are still out of v1 scope.

### 2.1 Layout (frozen)

```
┌────────────────────────────────────────────────────────────┐
│ ◀ Back to chat            [partner · permission · trust]  │  ← NAV RAIL
├────────────────────────────────────────────────────────────┤
│                                                            │
│   HERO                                                     │  ← MapsHero
│     eyebrow: task kind (去某地 / 附近探索 / 路线查看)      │
│     title:   task.headerTitle                              │
│     summary: task.headerSummary                            │
│     status:  task.statusMessage (optional)                 │
│     error:   task.errorMessage (optional, replaces status) │
│                                                            │
├────────────────────────────────────────────────────────────┤
│                                                            │
│   PRIMARY CONTEXT CARD (varies by task kind)               │  ← see §2.3
│                                                            │
├────────────────────────────────────────────────────────────┤
│   [Secondary card or degraded state placeholder]           │  ← see §2.4
└────────────────────────────────────────────────────────────┘
```

The **Back to chat** affordance lives in the nav rail, top-leading. Copy is `Back to chat` / `返回对话`. It is always present on the first screen, regardless of task kind or state. It routes into `AppBootstrap.returnFromMaps()` — which runs the frozen `executionReturn` event path.

### 2.2 Field → slot mapping (frozen)

| Source                                | Slot                     | Rules                                                   |
| ------------------------------------- | ------------------------ | ------------------------------------------------------- |
| `task.taskType`                       | Hero eyebrow             | Uses `MapTaskType.title(for:)` — locked copy.           |
| `task.headerTitle`                    | Hero title               | title, bold. No trimming, no reformat.                  |
| `task.headerSummary`                  | Hero summary             | body, textSecondary, 4 lines max.                       |
| `task.permissionState`                | Nav rail permission pill | Uses `.locationPermission*` pill kind (same as card).   |
| Adapter `stubNote`                    | Nav rail trust pill(s)   | Uses `.placeResolutionStub` / `.partnerFallback`.       |
| `task.errorMessage`                   | Hero error strip         | When non-nil, replaces summary and is tinted warning.   |
| `task.statusMessage`                  | Hero status strip        | When non-nil and error is nil, renders under summary.   |

### 2.3 Primary context card — per task kind

| Task kind     | Primary context card                                                                                         |
| ------------- | ------------------------------------------------------------------------------------------------------------ |
| `goToPlace`   | Single place card: `selectedDestination.title` + subtitle + distance pill (trust-tagged).                    |
| `nearbySearch`| Search-area card: anchor place + result count + distance scope. If results empty, see §2.4 degradation.      |
| `routeCompare`| Mode-switcher card: walking / driving / transit segments, each annotated with ETA pill (trust-tagged).       |

All three render through `ActionCardShell`. They are **not** allowed to introduce a separate visual grammar — they reuse the 7-region shell (§ `action-card-component-inventory.md`). Surface-specific widgets (map preview, route list) sit below the first screen and are out of v1 scope.

### 2.4 Degradation UI (replaces the primary card when a stub blocks real content)

Every stub has a visible degradation UI. An empty value or an all-zero placeholder is a spec violation.

| Situation                                   | Rendering                                                                                                  |
| ------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| Location permission = `denied` / `manualOnly` | `LocationGateCard` replaces the primary context card. It shows the locked manual-input prompt and a "Use current location" retry. |
| Partner / provider unavailable              | `WarningCard` using `task.errorMessage`; falls back to a locked generic message when `errorMessage` is nil. |
| Nearby / recommendation returned empty      | `MapsEmptyState` card with locked zh/en copy and a "Back to chat" capsule.                                 |
| Place resolution stubbed                    | Primary context card still renders, but its trust pill must be `.placeResolutionStub`.                     |
| ETA / distance stubbed                      | Route card still renders, but each annotated pill must be `.etaConfidenceEstimate` / `.distanceConfidenceEstimate`. |

**Core rule**: a real value and an estimated value are **visually different**. Users must be able to tell at a glance. The mechanism is the trust pill — no value-level formatting differences, no fake precision, no "—" placeholder.

### 2.5 Four system states on the execution surface

| State                | Nav rail         | Hero                                                                 | Primary card slot                           |
| -------------------- | ---------------- | -------------------------------------------------------------------- | ------------------------------------------- |
| `loading`            | present          | title + summary; optional status `"Loading…"`                         | Skeleton variant of primary context card.   |
| `empty`              | present          | title + summary; no status                                            | `MapsEmptyState` card.                      |
| `error`              | present          | title + error strip replaces summary                                  | `WarningCard`.                              |
| `locationPermission` | present + pill   | title + summary; status describes permission state                    | `LocationGateCard` per §2.4.                |

The nav rail is unconditional: the `Back to chat` control is always present across all four states. If it is ever hidden, the user is trapped — spec violation.

### 2.6 Return-to-chat entry (surface)

Two entries, both routed to `AppBootstrap.returnFromMaps()`:

1. The nav rail `Back to chat` control (top-leading).
2. The `MapsEmptyState` card's inline `Back to chat` capsule (only when empty state renders).

Swipe-back and OS back gestures are not covered by this spec — they are platform defaults. The two explicit entries are the ones we design-review.

---

## 3. What v1 eliminates

| Before v1                                                               | v1 treatment                                                                |
| ----------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| `MapActionCardView` wrapped `reasonChipText` in a grey capsule.          | Removed. Reason renders as plain muted caption, matching `UnifiedActionCard`. |
| Trust affordances lived nowhere — stubbed values looked like live data. | Added `ActionCardTrustPill` with 7 frozen kinds (see §1.5).                 |
| Execution-surface return route was implicit (system back only).         | `Back to chat` is a first-class control, always visible.                    |
| Partner / permission state was invisible on the card.                   | Surfaced in the metadata row and nav rail via trust pills.                  |

No Maps-specific visual forks remain. The card and the execution surface share `ActionCardShell` and `ActionCardTrustPill`. Any future visual difference between Maps and the not-yet-built Music / Store cards must be copy-only.

---

## 4. Out of scope for v1 (explicit)

- Music, Video, Store cards. Those will ship on the same `ActionCardShell`, but their content contracts are **not** frozen here.
- A 4th or 5th Maps task kind.
- Live map rendering / routing engine / real POI provider.
- Animations, floats, inline info stacks.
- Simultaneous provider + scorer + shell changes.
- Snapshot testing of every permutation — v1 validation is the 3 task kinds × 4 states matrix covered by `MapActionCardUIValidationTests` and existing canonical tests.

---

## 5. Review checklist (for handoff)

When handing off to design / client eng, the card and the surface are reviewable independently against the list below:

- [ ] The 6 content fields of every rendered card map exactly to the slots in §1.2.
- [ ] No rendered card carries free-form trust text outside the pill vocabulary in §1.5.
- [ ] Primary and secondary CTA copy match the per-kind locks in §1.6.
- [ ] Every card state in §1.9 has the stated opacity, badge, and primary-CTA behavior.
- [ ] The execution surface always renders a visible `Back to chat` control (§2.6).
- [ ] Every stub (§2.4) renders a degradation UI — no empty primitive, no fake precision.
- [ ] No visual grammar differs from `UnifiedActionCard`. Copy and icon choices may; everything else is shared.
