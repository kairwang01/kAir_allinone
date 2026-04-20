# Music UI Spec v0

**Status**: Frozen shell reuse (2026-04-19).
**Scope**: Music is the **second UI validation vertical** for the kAir super-app. Its sole purpose in Round 5 is to prove that `ActionCardShell` and `ExecutionSurfaceShell` can host a second vertical **without any Music-specific visual skeleton, primitive, or fork**. Full playback, streaming, partner integration, and persistent-player polish are **out of scope** here.

This doc is a **binding**, not a shell spec. It sits below:

- `chat-home-and-recommended-next-spec-v1.md` (Chat Home + Recommended Next)
- `execution-surface-framework-v1.md` (the 7-region surface contract)
- `action-card-component-inventory.md` (the card primitive inventory)

If anything here disagrees with the two shell specs above, **the shell specs win**. Music cannot invent regions, states, trust pills, or back-to-chat styling.

---

## 1. Music as a vertical — what it is (and isn't) in v0

| Dimension                     | v0 answer                                                                              |
| ----------------------------- | -------------------------------------------------------------------------------------- |
| Is Music a permanent root tab? | **No.** Music is a chat-invoked Execution Surface, same shell class as Maps.           |
| Does it get its own primitive? | **No.** Music cards use `ActionCardShell`; Music surface uses `ExecutionSurfaceShell`.  |
| Does it get its own trust pills? | **No.** Music draws from the shared `ActionCardTrustPillKind` vocabulary. No new cases. |
| Does it get its own state vocabulary? | **No.** `ExecutionSurfaceSystemState` covers all degradations.                         |
| Does it get its own nav rail? | **No.** The shell's `Back to chat` / `返回聊天` capsule is the only return.             |
| Does it get its own feedback affordance? | **No.** The shell's `⋯` menu + `✕` dismiss are the only feedback controls.              |
| Partner / streaming integration? | **Deferred.** The "partner pending" trust pill communicates the state; no wiring here. |

**Net effect**: Music in v0 is *the simplest possible proof* that the super-app's shells are vertical-agnostic. If Music needs anything the shells don't already give it, that is a shell gap — we fix the shell, not Music.

---

## 2. Three Music task kinds (frozen for v0)

Music introduces exactly three task kinds that can reach the user as an Action Card in Recommended Next. Each kind is a projection onto `ActionCardShell` — the shell renders the card; Music only supplies copy and a kind glyph.

| Task kind             | Trigger                                                      | Primary CTA (en / zh) | Secondary CTA (en / zh)      | Kind glyph          |
| --------------------- | ------------------------------------------------------------ | --------------------- | ---------------------------- | ------------------- |
| `playNow`             | User asked for a specific song, artist, or immediate start.  | `Play now` / `立刻播放` | `Preview` / `试听`            | `play.circle.fill`  |
| `continueListening`   | Resume a session that was started earlier in the same thread. | `Resume` / `继续听`    | `Switch track` / `换一首`     | `arrow.clockwise`   |
| `moodMix`             | Mood-based request ("focus music", "放一些爵士").             | `Start mix` / `开始播放` | `Different mood` / `换种心情` | `waveform.path`     |

Rules:

1. **No fourth kind in v0.** If a new class of Music intent comes in, it maps onto one of these three or the feature waits.
2. **Copy is locked here**, not overridable by provider layer. The kind label ("Play now" / "立刻播放") renders in the card's region 1 (head) exactly as listed.
3. **Secondary CTA is optional** but if present must be exactly the copy above — no partner-specific overrides ("Open in Spotify", etc. — those are v1+).
4. **Trust pill** on every Music card in v0 is `partnerFallback` (shared vocabulary). This truthfully communicates "partner pending." When a partner lands, that pill is removed; it is never replaced with a Music-specific pill.

---

## 3. Card binding — MusicActionCardView

`MusicActionCardView` is a thin projection over `ActionCardShell`. It is structurally identical to `MapActionCardView` — the only Music-specific additions are the kind-label copy, the kind glyph, and the trust-pill array. Everything else (padding, radius, CTA button style, dismiss/feedback affordances) is inherited.

| Shell region             | Music supplies                             | Hard-coded by shell                                        |
| ------------------------ | ------------------------------------------ | ---------------------------------------------------------- |
| (1) Head — kind label    | "Play now" / "立刻播放" etc. per §2         | Uppercase + caption font + accent color                    |
| (1) Head — feedback menu | Localized `feedbackAffordanceLabel`         | `⋯` glyph, menu spawns the frozen `MatchingFeedbackKind` list |
| (1) Head — dismiss       | (shell-driven)                             | `✕` glyph                                                   |
| (2) Trust pills          | `[.partnerFallback]` in v0                  | Pill style, vocabulary                                      |
| (3) Body                 | Title + subtitle + optional reason          | Title / subtitle / reason typography                       |
| (4) Primary CTA          | Frozen §2 copy per task kind                | Black capsule, full-width                                   |
| (5) Secondary CTA        | Frozen §2 copy (or nil)                     | Plain-text style                                            |
| (6) Feedback row         | (lives inside region 1)                    | n/a                                                         |
| (7) Partner badge slot   | (lives inside region 2 as the pill)        | n/a                                                         |

A new `MusicActionCardModel` parallel type is **not** required in v0 (we don't need a per-vertical card model type for a single adapter). `MusicActionCardView` takes the parameters as a lightweight struct (`MusicCardContent`) so that T4/T7 tests can compare inputs. If a richer Music card model later becomes necessary (for scorer-driven bindings), it must mirror `MapActionCardModel`'s frozen 6-field/4-state/5-event shape — no new fields.

---

## 4. Surface binding — MusicHomeView

`MusicHomeView` is a caller of `ExecutionSurfaceShell`. It supplies the seven region inputs from its runtime (currently `AppBootstrap.activeMusicSession`) and delegates every return path to `AppBootstrap.returnToChat()` (which in turn falls into `closeSurface(notifyingReturn: true)` for Music, keeping persistent-player continuity).

Music cannot render:

- A private nav bar or back button.
- A private hero `KAirSurface(style: .hero)` block that mirrors the shell's own hero.
- A private empty state (`No active music` copy) — that is `ExecutionSurfaceSystemState.empty`, and the shell owns the copy.
- A private feedback row or status strip style — reuse `ExecutionSurfaceStatus`.

Music's **primary region (3)** is allowed to render exactly one vertical-flavored card: a `MusicNowPlayingCard` that itself is an `ActionCardShell` instance (per framework §4 rule). It shows the current session title, subtitle, mood, source label, and the two primary controls (`Back to chat` — already covered by the shell, so omitted here — and `Stop playback`). **Stop playback** is the one Music-specific affordance that doesn't exist in the generic shell. It lives inside the card, not on the nav rail.

Music's **supplementary region** in v0 renders nothing. No queue, no up-next list, no equalizer. The whole point is to prove the shell is sufficient without a Music-specific skeleton.

### 4.1 State mapping

| `MusicHomeView` condition                                 | `ExecutionSurfaceSystemState` |
| ---------------------------------------------------------- | ----------------------------- |
| `bootstrap.activeMusicSession != nil`                      | `.ready`                      |
| No active session (fresh launch of surface)                | `.empty`                      |
| Future: streaming failed / partner offline                 | `.error`                      |
| Future: partner not granted / subscription lapsed          | `.permissionOrUnavailable`    |
| Future: loading on entry (async fetch for resume session)  | `.loading`                    |

### 4.2 Terminal row

Music **does** use region (7) — the terminal row — for one signal only: **playback ended naturally**. When a session finishes on its own (as opposed to being stopped by the user), the shell renders:

- Title: `Playback ended` / `播放结束`
- Glyph: `music.note`
- Inline `Back to chat` capsule — same as the nav rail's.

In v0, playback-ended is not wired (we don't actually stream), so this region is dormant but declared. The T7 test asserts the wiring is in place for the moment Music earns a real lifecycle.

---

## 5. What Music explicitly does **not** get in v0

This list is part of the freeze. Adding any of these is a v1 event on this doc, not a v0 patch.

- A `MusicActionCardModel` frozen-contract type (deferred until the Music scorer adapter lands).
- A partner-specific trust pill (e.g. "via Spotify" / "via Apple Music").
- Per-mood color theming on the card or the surface.
- An equalizer, waveform visualization, or artwork block.
- A Music-specific empty-state copy — `ExecutionSurfaceSystemState.empty` is the only empty state.
- A "now playing" persistent chip in Chat Home (already covered by the global `persistent-player` area of `chat-home-and-recommended-next-spec-v1.md` §5, which is shell-owned, not Music-owned).
- Its own `@MainActor @Observable MusicRuntime` (not needed for v0; current `AppBootstrap.activeMusicSession` property is sufficient).
- Its own set of feedback kinds — reuse `MatchingFeedbackKind`.

---

## 6. Verification

Two test suites lock the v0 contract:

- **T6 `ExecutionSurfaceShellValidationTests`** (shared) — asserts the shell itself is frozen. Covers:
  - `ExecutionSurfaceSystemState.allCases.count == 5`.
  - Back-to-chat copy is `Back to chat` / `返回聊天`, no other string ever emitted.
  - The state region copy is frozen (loading / empty / error / permissionOrUnavailable — locked zh + en strings).
  - A pair of `ExecutionSurfaceShellInputs` — one built from a Maps task, one from a Music session — produce identical shell-side shape (same regions, same trust-pill type, same back-to-chat copy for the same language).

- **T7 `MusicShellReuseTests`** — asserts Music is a pure caller of the shell:
  - `MusicActionCardView` never emits a trust-pill type outside `ActionCardTrustPillKind`.
  - `MusicHomeView` always calls `ExecutionSurfaceShell` — no private `KAirSurface(style: .hero)` at the top of its body.
  - The three task kinds (`playNow` / `continueListening` / `moodMix`) project onto `ActionCardShell` with the frozen copy from §2.
  - Music's state mapping in §4.1 produces the exact `ExecutionSurfaceSystemState` case expected.

---

## 7. Review checklist

- [ ] Every Music Action Card is a `MusicActionCardView` → `ActionCardShell` (no ad-hoc `KAirSurface` cards).
- [ ] Every Music full-screen surface is a `MusicHomeView` → `ExecutionSurfaceShell`.
- [ ] The only Music-specific copy is (§2) kind labels + CTA titles + terminal-row title.
- [ ] The only Music-specific affordance inside the primary region is `Stop playback` (inside the card, not on the rail).
- [ ] All back-to-chat entries read `Back to chat` / `返回聊天` with accessibility identifier `execution-surface-back-to-chat`.
- [ ] Trust pills (if any) come from `ActionCardTrustPillKind`.
- [ ] No private empty / error string — degradations render via `ExecutionSurfaceSystemState`.
