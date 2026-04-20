# Execution Surface Framework v1

**Status**: Frozen (2026-04-19).
**Scope**: Every fullScreenCover the chat can portal into — Maps, Music, Video, Health workspace, and any future vertical that follows the chat-first contract. This is the **generic framework**; there is no per-vertical execution shell.

This spec sits alongside `chat-home-and-recommended-next-spec-v1.md` (which owns Chat Home / Layers 1 & 4) and above `maps-ui-spec-v1.md` (which is now a vertical binding of this framework, not a standalone shell spec). If this doc and a vertical-specific doc disagree, this doc wins.

---

## 1. The seven regions (frozen)

Every Execution Surface, regardless of vertical, is rendered through `ExecutionSurfaceShell` and has exactly these seven regions:

```
┌──────────────────────────────────────────────────────────────┐
│ (1) NAV RAIL                                                 │
│     ◀ Back to chat              (left-leading, always visible)│
├──────────────────────────────────────────────────────────────┤
│ (2) TASK TITLE REGION                                         │
│     eyebrow + title + summary                                 │
├──────────────────────────────────────────────────────────────┤
│ (5) PARTNER / SOURCE ROW                                      │
│     0..n ActionCardTrustPill values                           │
├──────────────────────────────────────────────────────────────┤
│ (4) STATUS STRIP (optional)                                   │
│     status message OR error message — never both              │
├──────────────────────────────────────────────────────────────┤
│ (3) PRIMARY ACTION REGION                                     │
│     vertical-supplied card (always an ActionCardShell-based   │
│     card; Maps place card, Music player card, etc.)           │
├──────────────────────────────────────────────────────────────┤
│ (6) STATE REGION (rendered when state != .ready)              │
│     loading / empty / error / permissionOrUnavailable         │
│     — locked copy + a second "Back to chat" capsule            │
├──────────────────────────────────────────────────────────────┤
│ (7) TERMINAL-STATE ROW (optional)                             │
│     "Playback ended" / "Arrived" / "Episode complete"         │
│     — inline "Back to chat" capsule                            │
└──────────────────────────────────────────────────────────────┘
```

The regions map to the caller-facing types:

| Region                         | Type / parameter                                | Frozen?                        |
| ------------------------------ | ----------------------------------------------- | ------------------------------ |
| (1) Nav rail                   | `ExecutionSurfaceNavRail`                       | Yes — shape + back copy only   |
| (2) Task title                 | `ExecutionSurfaceTitle`                         | Yes — eyebrow/title/summary    |
| (3) Primary action             | `primary: () -> some View` ViewBuilder          | Slot — contents vary per kind  |
| (4) Status strip               | `ExecutionSurfaceStatus`                        | Yes — error wins over status   |
| (5) Partner / source           | `navRail.trustPills` (shared pill vocabulary)   | Yes                            |
| (6) System state               | `ExecutionSurfaceSystemState`                   | Yes — 4 terminal states + ready |
| (7) Terminal-state row         | `ExecutionSurfaceTerminal?`                     | Yes — title + glyph only        |

A supplementary ViewBuilder (`supplementary`) is allowed for verticals that render additional context **below** the state region (Maps uses it for route cards, navigation card, etc.). It is a flat pass-through — the shell does not style it — but it is understood to be the vertical's "rest of the page," not a place to re-implement regions 1–7.

---

## 2. Back-to-chat contract (frozen across all surfaces)

This is the single most important invariant of this framework. `execution-surface-framework-v1.md` exists in large part to freeze this.

| Property                            | Rule                                                                                              |
| ----------------------------------- | ------------------------------------------------------------------------------------------------- |
| Presence                            | Always rendered in region (1). Non-negotiable.                                                    |
| Position                            | Top-leading of the hero surface, inside the shell's own padding — never in the navigation bar chrome. |
| Style                               | `KAirActionCapsule(title: <localized>, systemImage: "chevron.left", emphasized: false)`.           |
| Copy                                | `Back to chat` (en) / `返回聊天` (zh). No other copy allowed.                                    |
| Accessibility identifier            | `execution-surface-back-to-chat` — identical across all verticals.                                |
| Priority across states              | Rendered in **every** state (ready / loading / empty / error / permissionOrUnavailable / terminal). |
| Tap target                          | Routes to the caller-provided `onReturnToChat` closure, which must ultimately call `AppBootstrap.returnToChat()` (or a vertical-specific alias like `returnFromMaps()` that forwards). |

There is always a second "Back to chat" surfaced in region (6) and region (7) when they render — so if the user reaches a degenerate state, they are never more than one tap from safety. These secondary entries share the rail's copy and routing.

The system navigation-bar back button is platform-default. It is not covered by this framework and is not design-reviewed. **The shell's rail is the authoritative return path** — it must be present even if the platform chrome exposes its own.

---

## 3. The four system states (frozen)

`ExecutionSurfaceSystemState` has exactly one non-terminal state (`.ready`) and four system states every surface must handle. Verticals cannot add a fifth.

| State                       | When                                                                                                              | Shell rendering in region (6)                                                                 | Primary region (3) rendering           |
| --------------------------- | ----------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- | -------------------------------------- |
| `.ready`                    | The surface has its data and the primary region is fully populated.                                                | Hidden.                                                                                       | Fully rendered.                        |
| `.loading`                  | Data is not yet available (first render before the async fetch, or a refresh kicked off).                         | "Loading" with hourglass; locked copy.                                                        | Caller choice — may show a skeleton or hide. |
| `.empty`                    | Request resolved to zero results (no matching places, no matching songs, no matching videos).                     | "Nothing to show" with tray icon; locked copy.                                                 | Caller choice — usually hides.         |
| `.error`                    | Provider / partner returned an error. `status.errorMessage` is typically set.                                      | "Something went wrong" — includes the error message verbatim when provided.                   | Caller choice — usually hides.         |
| `.permissionOrUnavailable`  | Required permission denied (location), or capability unavailable (no subscription, partner not wired).              | "Permission or service unavailable" with lock glyph.                                           | Caller choice — usually shows a degraded card. |

Notes:

- **Copy is locked** in the shell for these states. Verticals cannot replace the strings. They can *augment* the UX by rendering a degraded primary card (Maps' `LocationGateCard`, Music's "subscribe to continue" card), but the state region's headline and summary are shell-owned.
- **Error message passthrough**: when `status.errorMessage` is non-nil, it replaces the `.error` state region's summary. This is the one place vertical-supplied text enters the state region.
- **Ready is not rendered** — the region collapses entirely when `state == .ready`, matching the "no empty state" rule.

---

## 4. Primary region — slot contract

Region (3) is the only place vertical-specific UI renders. Rules:

1. The vertical's card **must** be built on `ActionCardShell` (the shared Action Card primitive). Any card that lives in region (3) is a first-class Action Card — it participates in the trust-pill vocabulary, the feedback/dismiss affordances, and the 7-region card grammar.
2. Verticals that need below-the-fold content (route list, place list, look-around, playback queue) render it via the `supplementary` ViewBuilder. That content still follows the shared grammar but does not live in region (3).
3. Region (3) is **not** allowed to re-implement a nav rail, a back button, a title bar, or an empty-state card. Those are owned by the shell.

---

## 5. Partner / source row — trust vocabulary

Region (5) is an inline row of `ActionCardTrustPill` instances. Rules:

- The pill vocabulary is the frozen `ActionCardTrustPillKind` set (from `ActionCardShell.swift`): 7 cases, identical to what the card metadata row uses.
- Adding a new pill kind is a v2 event on both this doc **and** `action-card-component-inventory.md`. No per-surface forks allowed.
- Pills are data-driven from the vertical's runtime (provider state, permission state, partner-wired flag). Do not emit a pill from static config — it must reflect current state.
- The row collapses to zero height when empty.

---

## 6. Terminal-state row — when the task has finished

Region (7) exists for the surface-local notion of "done." Examples:

| Vertical | Terminal title (en / zh)       | Glyph                                 |
| -------- | ------------------------------ | ------------------------------------- |
| Maps     | `Arrived` / `已到达`           | `flag.checkered`                      |
| Music    | `Playback ended` / `播放结束`  | `music.note`                          |
| Video    | `Episode complete` / `已看完`  | `play.rectangle.fill`                 |
| Health   | not used (health has no terminal state in v1) |                      |

Rules:

- Optional. The caller supplies `ExecutionSurfaceTerminal` only when the task has reached its own terminal state.
- Renders **below** any supplementary content — this is the last thing on the screen before the scroll ends.
- Includes its own "Back to chat" capsule. The idea: after a task finishes inside the surface, the one forward action is to return to chat with the result.
- Does **not** replace the state region. A surface can be both "ready + terminal" (playback finished) and "error + terminal" is disallowed (error reads as still-in-progress).

---

## 7. What this framework abstracts from `maps-ui-spec-v1.md`

Maps was the first vertical to freeze its execution surface. The patterns it established are now promoted to this generic framework:

| Previously in maps-ui-spec-v1.md                         | Now a framework invariant                                                                 |
| -------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| §2.1 "Nav rail / MapsHero" layout                        | §1 seven-region layout — applies to **every** surface.                                    |
| §2.1 `Back to chat` nav-rail control                     | §2 Back-to-chat contract — identical copy, placement, accessibility across verticals.     |
| §2.1 trust-pill row in `MapsHero`                        | §5 Partner / source row — same vocabulary, same rendering.                                |
| §2.5 four system states                                  | §3 four system states — **promoted** to the framework, no longer Maps-only.               |
| §2.4 degradation UI table                                | Absorbed: states are generic (`.empty` / `.error` / `.permissionOrUnavailable`); verticals render their own degraded primary card. |
| §2.6 two return-to-chat entries                          | §2 (nav rail) + §3 state region + §6 terminal row — three redundant returns, all identical copy + routing. |

Net effect: Maps no longer has a private execution shell. `MapsHomeView` is now a caller of `ExecutionSurfaceShell` with a Maps-flavored primary region (the place card / route card / nearby list). The shell does not know or care that it is hosting Maps.

---

## 8. Verification: the snapshot test

A single sanity test locks the framework's shape:

- **T6 `ExecutionSurfaceShellValidationTests`** (new in Round 5). It asserts:
  1. `ExecutionSurfaceSystemState.allCases` has exactly 5 entries (`ready` + 4 systems).
  2. The nav rail always emits the locked back-to-chat copy for zh/en.
  3. `stateTitleCopy` / `stateSummaryCopy` are frozen strings — no per-surface override.
  4. The 7 regions correspond 1:1 to `ExecutionSurfaceShellInputs` — a Maps surface and a Music surface with identical inputs produce identical shell inputs.
  5. The shared trust-pill vocabulary is referenced (not a vertical-specific type) on every surface that emits pills.

Additionally:

- **T7 `MusicShellReuseTests`** validates that `MusicHomeView` is a pure caller of `ExecutionSurfaceShell` — no private back button, no private empty state, no private state vocabulary.

---

## 9. Out of scope for v1

- Gesture handling (swipe-to-dismiss, pull-to-refresh) — platform default for now.
- Cross-surface transitions / hero animations.
- Settings pages within a surface — those live in the sheet layer (`ProfileAndSettingsView`) and are not "execution surfaces" in this framework's sense.
- Spaces home — those are not execution surfaces; they are a different vertical kind (persistent workspace).
- Video execution surface — Video is still stubbed (`VideoHomeView`). It will adopt this framework when it earns a task model, not before.

---

## 10. Review checklist

- [ ] The surface renders `ExecutionSurfaceShell`, not a bespoke layout.
- [ ] "Back to chat" copy is `Back to chat` / `返回聊天` in the rail, the state region, and the terminal row.
- [ ] Trust pills (if any) are drawn from `ActionCardTrustPillKind`.
- [ ] Primary region is one or more `ActionCardShell`-based cards.
- [ ] `ExecutionSurfaceSystemState` covers the degraded path — no custom empty / error string.
- [ ] No private nav bar, no private trust vocabulary, no private state enum.
