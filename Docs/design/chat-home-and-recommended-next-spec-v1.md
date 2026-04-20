# Chat Home + Recommended Next Spec v1

**Status**: Frozen (2026-04-19).
**Scope**: The super-app shell's primary screen. Defines the Chat Home page and the Recommended Next block that lives on it. This is the global rule set — no vertical (Maps, Music, Video, Store, …) may define its own Chat Home variant.

This spec sits **above** `maps-ui-spec-v1.md` and `action-card-component-inventory.md`. Those docs tell you how an individual card is rendered; this one tells you *where* the card goes, *when* it renders, and *how* the host page behaves around it. When the two conflict, this doc wins.

Intent: freeze the super-app shell so every future capability slots into the existing four-layer grammar without growing new entry points. If a feature cannot be expressed in the four layers below, do not invent a fifth layer — redesign the feature.

---

## 1. The four information layers (frozen)

Chat Home has exactly four layers. Nothing can be added to this list without a v2 bump on this doc. The whole-screen order, top to bottom, is:

```
┌──────────────────────────────────────────────────────────────┐
│ LAYER 1 — CHAT / ASK surface                                  │
│   (header identity, hero summary, continue-thread entry,      │
│    conversation body when thread is open)                     │
├──────────────────────────────────────────────────────────────┤
│ LAYER 2 — Action Card stream                                  │
│   (zero or more ActionCardShell instances in the scroll)      │
├──────────────────────────────────────────────────────────────┤
│ LAYER 3 — Execution Surface portal                            │
│   (not rendered on Chat Home itself — a fullScreenCover        │
│    hosted by RootShellView; Chat Home only owns the entry      │
│    path into it, via AppBootstrap.open*)                      │
├──────────────────────────────────────────────────────────────┤
│ LAYER 4 — Recommended Next console                            │
│   (safe-area bottom inset: the collapsible "next step" tray)  │
└──────────────────────────────────────────────────────────────┘
```

### 1.1 What each layer owns

| Layer | Concrete surface | Owns                                                           | Does **not** own                                          |
| ----- | ---------------- | -------------------------------------------------------------- | --------------------------------------------------------- |
| 1. Chat / Ask | `ChatHomeHero` + `ContinueThreadCard` + `ConversationThreadView` body + `FloatingAskComposer` | Identity, summary, thread history, composer, reference picker, template-chat toggle | Any vertical-specific entry point; any ETA / trust pill |
| 2. Action Cards | `LazyVStack` of `UnifiedActionCard` / `MapActionCardView` / future adapters (`MusicActionCardView`, …) | Single-card and multi-card rendering rules (§4). Feedback routing. | Pre-card headers (no "Maps suggestions:" section labels). Vertical-specific overlays. |
| 3. Execution Surface portal | `AppBootstrap.open*` → `fullScreenCover` in `RootShellView` | The *decision* to open a surface (driven by `ConversationRoute`). Return-to-chat wiring. | The surface contents (that's `execution-surface-framework-v1.md`). |
| 4. Recommended Next | `RecommendedNextConsole` (safeAreaInset bottom) | A compact, horizontally scrolling next-step tray + its collapse/expand state + accept/feedback routing | Full Action Card rendering (those go in Layer 2). Any vertical-specific badge. |

### 1.2 What does **not** exist on Chat Home

Explicit prohibitions. If you find yourself adding any of these, stop.

- **No per-vertical entry chips.** The string "Open Maps" / "Open Store" as a shortcut button is forbidden; verticals are reached via Action Cards (Layer 2) or Recommended Next (Layer 4), never via a header tab or side rail.
- **No pre-card section labels.** "Maps suggestions" / "Music picks" above Layer 2 is forbidden — the card's own `headerLabelTitle` is the only label.
- **No inline capability tiles.** "Quick actions" grids, Today widgets, or dashboards at the Chat Home level are forbidden. Those belong on a Space (Layer 3, see `SpacesHomeView`) and are out of scope here.
- **No second composer.** The `FloatingAskComposer` is the single entry; do not add a "fast command bar," a `/` overlay, or a voice-only input in parallel.

---

## 2. Page states (at least 3, frozen)

Every Chat Home render must be in exactly one of these states. The Recommended Next console behaves differently in each — §3 details those rules.

### 2.1 `coldStart`

**Definition**: no messages in `store.session.messages`, no `recommendedMatches`, no handoff context. The user has not yet spoken to kAir in this session.

| Layer | Rendering                                                                                  |
| ----- | ------------------------------------------------------------------------------------------ |
| 1     | `ChatHomeHero` with the default `Talk to {session.title}` copy + context items.            |
| 2     | Empty. No Action Cards render.                                                             |
| 3     | Not applicable — no surface is open.                                                       |
| 4     | **Hidden** (`recommendedMatches.isEmpty`). Instead, `ConversationPromptTray` shows above the composer when prompts are available. |

The composer is the *only* primary action. Recommended Next is **not** teased in cold start — it is a reactive layer.

### 2.2 `activeThread`

**Definition**: at least one message has been exchanged OR `recommendedMatches` is non-empty OR a previous thread is resumable. The user is mid-conversation (either directly on Chat Home or in the pushed `ConversationThreadView`).

| Layer | Rendering                                                                                  |
| ----- | ------------------------------------------------------------------------------------------ |
| 1     | `ChatHomeHero` (if on home) + optional `ContinueThreadCard` (`store.canResumeThread == true`) + `ConversationThreadView` body when a thread is open. |
| 2     | `LazyVStack` of Action Cards rendered for every recommendation that produced one. See §4 for single vs. multi-card rules. |
| 3     | A surface may be open on top (fullScreenCover) — Chat Home is still live underneath.       |
| 4     | `RecommendedNextConsole` visible at the safe-area bottom when `recommendedMatches.isEmpty == false`. Collapse/expand per §3.3. |

### 2.3 `postReturn`

**Definition**: the user has just closed an Execution Surface (Maps, Music, Video, Health, …) and control is back on Chat Home. `bootstrap.surfaceEntryEventHandler` has fired `.returned` within the last render cycle, and `store.recordSurfaceReturn(…)` / `store.recordMapReturn(…)` have just run.

| Layer | Rendering                                                                                  |
| ----- | ------------------------------------------------------------------------------------------ |
| 1     | Same as `activeThread`. A newly appended assistant message summarizing the return is owned by `ChatStore` — Chat Home does not render a banner. |
| 2     | Freshly regenerated Action Cards may appear (driven by the recommendation engine reacting to the return). These look identical to `activeThread` — no "just returned from X" treatment. |
| 3     | Not applicable — surface has closed.                                                       |
| 4     | Recommended Next console reappears if `recommendedMatches` is non-empty. Its collapsed state is restored from prior `isRecommendedNextExpanded`. No "you just came back" badge on the console. |

**Core rule**: post-return is a *state of the data*, not a *visual mode*. The chat thread and card stream express the return — no dedicated strip, no toast, no tab pill.

---

## 3. Recommended Next — the five frozen rules

The Recommended Next console (Layer 4) is the single most-abused surface in super apps — it tends to grow into a second home screen. These five rules stop that.

### 3.1 Appearance condition (frozen)

The console is **rendered if and only if** `store.recommendedMatches.isEmpty == false`.

- No "empty state" UI. When there are no recommendations, the entire `safeAreaInset` block collapses and the `ConversationPromptTray` takes the same footprint if prompts exist.
- No "always show" mode. The shell does not carry placeholders for marketing, upsell, or rotating tips.
- The console never renders on the pushed `ConversationThreadView`; that screen shows Action Cards inline (Layer 2) and nothing at Layer 4. (The console is a Chat Home chrome element only.)

### 3.2 Sorting expression (frozen)

Recommendations are consumed in the order delivered by `ChatStore.recommendedMatches`, which is produced by the `UnifiedMatchingEngine` pipeline. Chat Home is **not** allowed to re-sort.

- No per-vertical boosting ("Maps first" / "Music last") at the view layer.
- No alphabetical, chronological, or "freshest first" shuffling at the view layer.
- If sort order must change, it changes upstream in the scorer — the shell is a pure mirror.

### 3.3 Card count (frozen)

The console:

- Renders **all** recommendations when expanded (horizontal scroll, no truncation).
- Renders a count badge when collapsed: `"{N} next-step suggestions ready"`.
- Shows **one** row. No grids, no 2-row wraps, no page indicators.
- Expand is the default for the first display in a session; collapse state persists until the session ends.

Layer 2 (inline cards in the scroll view) renders the **same** recommendations — it is not a subset. The console is a second projection of the same list; there is no filtering step between them.

### 3.4 Feedback affordance (frozen)

Every recommendation in the console exposes the same negative-feedback surface as its Layer-2 card: a `⋯` menu expanded into all `MatchingFeedbackKind.allCases`. Copy and placement match `ActionCardShell` region (1).

- No swipe-to-dismiss, no long-press menu, no tap-and-hold alternative.
- Menu routes to `onRecommendationFeedback(recommendation, feedback)`, which drives `store.dismissRecommendation(…)` — same path as the Layer-2 card.
- Positive acceptance is the primary CTA button (the per-kind "Go" capsule). No thumbs-up / heart / star mechanic.

### 3.5 Post-acceptance state (frozen)

When the user accepts a recommendation (primary CTA tap or card tap accept path):

1. `store.prepareRecommendationForAccept(recommendation)` runs — this is the frozen bridge to the thread.
2. `submitHomePrompt(candidate.activationPrompt)` fires — the activation prompt appears as a user message in the thread.
3. The thread is pushed (`isConversationPresented = true`) if it was not already active.
4. `handleRoute(…)` resolves the `ConversationRoute` — if the route targets a surface, `AppBootstrap.open*` is called and the fullScreenCover takes over.
5. On Chat Home, the accepted recommendation **disappears** from `recommendedMatches` (the engine dedupes). The console collapses to its next state — either a smaller count, or hidden if the list is now empty.

**Core rule**: acceptance does not generate a confirmation banner, a pulse animation, or a "recommendation accepted" toast. The thread message + the surface opening is the feedback. If the user wants to know what was accepted, they look at the thread.

---

## 4. Single / multi / mixed list rules (Layer 2)

Layer 2 renders the same `recommendedMatches` as Layer 4, but inline. These rules lock its layout.

### 4.1 Single card

When `recommendedMatches.count == 1`:

- Rendered in a `LazyVStack`. No special full-width "featured" treatment.
- The card adapter is selected by `candidate.preferredSection`:
  - `.maps` → `MapActionCardView`
  - `.music` → `MusicActionCardView` (once shipped in P2 of Round 5)
  - anything else → `UnifiedActionCard`
- No pre-card label. No "1 suggestion" badge.

### 4.2 Multi-card, same vertical

When `recommendedMatches.count > 1` and every entry shares a `preferredSection`:

- Cards render in sequence, same `LazyVStack`, 16pt spacing.
- No section header above the group. No grouping divider.
- The console (Layer 4) mirrors the same list horizontally.

### 4.3 Multi-card, mixed verticals

When `recommendedMatches` spans multiple `preferredSection` values:

- Cards still render in sequence, in the **engine-provided order**. No grouping, no tabs, no filter chips.
- Each card uses its vertical's adapter. Visual grammar is identical (§5).
- The user distinguishes verticals by `headerLabelTitle` + icon + `trustPills` — not by page-level grouping.

### 4.4 Density cap

The view does not cap the number of cards. The engine upstream is responsible for not flooding the list. If the list exceeds screen height, normal scroll applies — the console at the bottom remains pinned via `safeAreaInset`.

---

## 5. Component inventory: global vs. vertical-override

| Component                         | File                                                                                     | Global or per-vertical? | Allowed vertical overrides                                                 |
| --------------------------------- | ---------------------------------------------------------------------------------------- | ----------------------- | -------------------------------------------------------------------------- |
| `ChatHomeHero`                    | [ChatHomeView.swift](../../kAir/Features/Chat/Presentation/ChatHomeView.swift)           | **Global**              | None. Badges and summary copy are general, never vertical-specific.        |
| `ContinueThreadCard`              | [ChatHomeView.swift](../../kAir/Features/Chat/Presentation/ChatHomeView.swift)           | **Global**              | None.                                                                      |
| `ChatHomeTopBar`                  | [ChatHomeView.swift](../../kAir/Features/Chat/Presentation/ChatHomeView.swift)           | **Global**              | None. `Add` button routes to the unified `ReferencePickerSheet`.           |
| `FloatingAskComposer`             | [ChatHomeView.swift](../../kAir/Features/Chat/Presentation/ChatHomeView.swift)           | **Global**              | None. Single composer. Template-chat toggle is general.                    |
| `ConversationPromptTray`          | [ChatHomeView.swift](../../kAir/Features/Chat/Presentation/ChatHomeView.swift)           | **Global**              | Copy (prompts come from `store.suggestedPrompts` — data, not view).        |
| `ActionCardShell`                 | [ActionCardShell.swift](../../kAir/DesignSystem/Components/ActionCardShell.swift)        | **Global**              | See `action-card-component-inventory.md` — copy + icon only.               |
| `UnifiedActionCard`               | [UnifiedActionCard.swift](../../kAir/DesignSystem/Components/UnifiedActionCard.swift)    | **Global adapter**      | None. Thin wrapper over `ActionCardShell`.                                 |
| `MapActionCardView`               | [MapActionCardView.swift](../../kAir/Features/Maps/Presentation/MapActionCardView.swift) | **Per-vertical adapter**| Task-kind label + SF Symbol; trust-pill array. Everything else shared.     |
| `MusicActionCardView` (Round 5 P2)| [MusicActionCardView.swift](../../kAir/Features/Music/Presentation/MusicActionCardView.swift) | **Per-vertical adapter**| Task-kind label + SF Symbol; trust-pill array (may be empty). Shared shell. |
| `RecommendedNextConsole`          | [ChatHomeView.swift](../../kAir/Features/Chat/Presentation/ChatHomeView.swift)           | **Global**              | None. The cell content comes from `candidate` + `reasonText`.              |
| `RecommendedNextCell`             | [ChatHomeView.swift](../../kAir/Features/Chat/Presentation/ChatHomeView.swift)           | **Global**              | None. Renders `candidate.objectKind.title` + `candidate.title`.            |

### 5.1 The rule for new cards

When a new vertical needs a card:

1. Add a thin adapter (`<Vertical>ActionCardView.swift`).
2. Wire the adapter to `ActionCardShell` — no custom container, padding, or button style.
3. If the vertical needs a trust vocabulary, extend `ActionCardTrustPillKind` in the shared enum (not a vertical-specific type).
4. Register the adapter selection in `ChatHomeView.body` + `ConversationThreadView.body` (the `if let <verticalCard> = …` branch).
5. Do **not** add anything to Chat Home's chrome (Layers 1 or 4).

---

## 6. What v1 eliminates

| Before v1                                                                                  | v1 treatment                                                                                       |
| ------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------- |
| Chat Home had no spec — every vertical risked pinning its own entry into the hero.         | Four-layer grammar is frozen. Verticals cannot touch Layer 1 or Layer 4 chrome.                    |
| Recommended Next had no count / ordering / persistence rules — it was a feature undocumented. | Five frozen rules (§3). Engine order is authoritative; console does not re-sort.                  |
| Layer 2 vs Layer 4 projection was implicit.                                                | Explicit: Layer 2 is inline full cards, Layer 4 is the compact tray of the same list.             |
| Acceptance UX was ambiguous ("does it confirm? does it toast?").                           | Acceptance writes a thread message + opens the surface. No dedicated acknowledgment.               |
| Post-return was a dedicated visual concept.                                                | Post-return is a data state, not a UI state. Card stream and thread absorb the return naturally.   |

---

## 7. Out of scope for v1

- Spaces home (`SpacesHomeView`) — that is Layer 3 ecosystem, covered by a different doc.
- Persistent mini-player behavior while a surface is open — see `RootShellView.ShellMiniPlayer`; its rules are stable and not under design iteration.
- Pushed `ConversationThreadView` composer behavior beyond "single composer per screen."
- Notification-originating deep links into a specific thread — not yet wired.
- Widgets, lock screen activities, or iOS 26 control-center integration.

---

## 8. Review checklist (for handoff)

- [ ] Chat Home has exactly the four layers in §1.
- [ ] Layer 1 is the only place the app identity and composer appear.
- [ ] Layer 2 renders cards in engine order; no per-vertical grouping.
- [ ] Layer 4 is hidden when `recommendedMatches.isEmpty`.
- [ ] Layer 4 mirrors Layer 2's list — the two agree on count and order.
- [ ] Accepting a recommendation writes a thread message; no toast or banner.
- [ ] No vertical-specific strip, chip, or section lives above the card stream.
- [ ] The one composer, one reference picker, one template-chat toggle contract holds.
