# Search UI Spec v0

**Status**: Frozen shell reuse (2026-04-20).
**Scope**: Search is the **third UI validation vertical** for the kAir super-app. Its sole purpose in Round 6 is to prove — after Maps (vertical 1) and Music (vertical 2) — that `ActionCardShell` and `ExecutionSurfaceShell` can host a **third** vertical without any Search-specific visual skeleton, primitive, or fork. Real web search, crawling, ranking, and answer generation are **out of scope** here. This is a UI shell-reuse proof, not a search engine.

This doc is a **binding**, not a shell spec. It sits below:

- `super-app-visual-system-v1.md` — the single visual source of truth (typography, palette, spacing, radius, state colors, CTA hierarchy, trust-pill vocabulary).
- `chat-home-and-recommended-next-spec-v1.md` — Chat Home + Recommended Next (Layers 1 & 4).
- `execution-surface-framework-v1.md` — the 7-region surface contract.
- `action-card-component-inventory.md` — the card primitive inventory.

If anything here disagrees with the specs above, **the shell specs win**. Search cannot invent regions, states, trust pills, or back-to-chat styling. If Search needs something the shells don't give it, that is a shell gap — we fix the shell, not Search.

---

## 1. Search as a vertical — what it is (and isn't) in v0

| Dimension                              | v0 answer                                                                                 |
| -------------------------------------- | ----------------------------------------------------------------------------------------- |
| Is Search a permanent root tab?        | **No.** Search is a chat-invoked Execution Surface, same shell class as Maps and Music.    |
| Does it get its own card primitive?    | **No.** Search cards use `ActionCardShell`.                                                |
| Does it get its own execution shell?   | **No.** Search surface uses `ExecutionSurfaceShell`.                                       |
| Does it get its own trust-pill kind?   | **No.** Search draws from the shared `ActionCardTrustPillKind` vocabulary. No new cases.   |
| Does it get its own state vocabulary?  | **No.** `ExecutionSurfaceSystemState` covers all degradations.                             |
| Does it get its own nav rail?          | **No.** The shell's `Back to chat` / `返回聊天` capsule is the only return.                |
| Does it get its own feedback affordance? | **No.** The shell's `⋯` menu + `✕` dismiss are the only feedback controls.                 |
| Does it actually hit the web in v0?    | **No.** All results are deterministic fixtures. No network, no scraping, no real ranking. |
| Does it have a permanent search box?   | **No.** Search is *chat-invoked*, exactly like Maps and Music. The chat thread is the input. |

**Net effect**: Search in v0 is *the simplest possible proof* that a third vertical adopts the existing shells without introducing a new skeleton. If Search can fit with zero shell mutation and zero new primitive, the shell model is vertical-count-agnostic. Round 6 asserts exactly that.

---

## 2. Three Search task kinds (frozen for v0)

Search introduces exactly three task kinds that can reach the user as an Action Card in Recommended Next. Each kind is a projection onto `ActionCardShell` — the shell renders the card; Search only supplies copy, a kind glyph, and a trust-pill array.

| Task kind        | Trigger                                                                        | Primary CTA (en / zh)              | Secondary CTA (en / zh)         | Header label (en / zh)            | Kind glyph                 |
| ---------------- | ------------------------------------------------------------------------------ | ---------------------------------- | ------------------------------- | --------------------------------- | -------------------------- |
| `answerNow`      | User asked a factual question that the system can answer inline ("What is X?"). | `Show answer` / `查看答案`         | `Why this answer` / `依据`       | `Answer` / `答案`                  | `sparkles.square.filled.on.square` |
| `openWebResult`  | User asked for a specific source ("Apple's Swift 6 release notes").           | `Open result` / `打开结果`         | `Open another` / `换一个`       | `Web result` / `网络结果`          | `link`                     |
| `deepResearch`   | User asked for multi-source analysis ("Compare A vs B with citations").       | `Start research` / `开始研究`      | `Narrow scope` / `缩小范围`     | `Deep research` / `深度研究`       | `doc.text.magnifyingglass` |

Rules:

1. **No fourth kind in v0.** If a new class of Search intent comes in, it maps onto one of these three or the feature waits. Any expansion requires a v1 event on this doc + a T9 update.
2. **Copy is locked here**, not overridable by the provider layer. Kind labels and CTA titles render in the card exactly as listed.
3. **Secondary CTA is always present** for Search (unlike Music where secondary is optional). This gives the user an explicit "alternate path" without inventing a third CTA tier — the visual system has no third tier (see `super-app-visual-system-v1.md` §6).
4. **No partner-specific copy**. Do **not** say "Open in Safari," "Search on Google," etc. Those are v1+ concerns once a real search partner is wired. v0 stays provider-agnostic.

---

## 3. Trust pill selection (no new pills)

Search draws from the shared `ActionCardTrustPillKind` vocabulary. The v0 mapping is:

| Task kind        | Trust pills in v0                                  | Rationale                                                                 |
| ---------------- | -------------------------------------------------- | ------------------------------------------------------------------------- |
| `answerNow`      | `[.partnerFallback]`                               | "Provider pending" — no real LLM or index behind the answer in v0.        |
| `openWebResult`  | `[.partnerFallback]`                               | "Provider pending" — no real crawl behind the result in v0.               |
| `deepResearch`   | `[.partnerFallback]`                               | "Provider pending" — no real multi-source synthesis in v0.                |

All three kinds emit **exactly one** pill — the shared `partnerFallback` — which truthfully communicates "partner pending." When a real search provider lands (v1+), this pill is removed on the affected kinds; it is never replaced with a Search-specific pill like `searchPartnerLive` or `citationVerified`. If we need a new pill, it lands on `ActionCardTrustPillKind` as a new case that Maps / Music / Health / Search all share.

---

## 4. Card binding — `SearchActionCardView`

`SearchActionCardView` is a thin projection over `ActionCardShell`. It is structurally identical to `MusicActionCardView` and `MapActionCardView` — the only Search-specific additions are the kind-label copy, the kind glyph, and the trust-pill array. Everything else (padding, radius, CTA button style, dismiss/feedback affordances, typography) is inherited from `super-app-visual-system-v1.md` via the shell.

| Shell region             | Search supplies                                 | Hard-coded by shell / visual system                                                                  |
| ------------------------ | ----------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| (1) Head — kind label    | "Answer" / "Web result" / "Deep research" per §2 | Uppercase + caption font + accent color (visual system §2 `eyebrow` role)                           |
| (1) Head — feedback menu | Localized `feedbackAffordanceLabel`              | `⋯` glyph; menu spawns the frozen `MatchingFeedbackKind` list                                       |
| (1) Head — dismiss       | (shell-driven)                                  | `✕` glyph                                                                                             |
| (2) Trust pills          | `[.partnerFallback]` per §3                      | Shared `ActionCardTrustPillKind` style + vocabulary                                                  |
| (3) Body                 | Title + subtitle + optional reason              | Title / subtitle / reason typography (visual system §2)                                              |
| (4) Primary CTA          | Frozen §2 copy per task kind                     | Black capsule, full-width (visual system §6 — primary tier)                                          |
| (5) Secondary CTA        | Frozen §2 copy (always present for Search)       | Plain-text + capsule style (visual system §6 — secondary tier)                                       |
| (6) Feedback row         | (lives inside region 1)                         | n/a                                                                                                   |
| (7) Partner badge slot   | (lives inside region 2 as the pill)             | n/a                                                                                                   |

A per-vertical `SearchActionCardModel` frozen-contract type is **not** required in v0 (we don't need a scorer adapter yet). `SearchActionCardView` takes the parameters as a lightweight struct (`SearchCardContent`), following the Music template. If a richer Search card model later becomes necessary, it must mirror `MapActionCardModel`'s frozen 6-field / 4-state / 5-event shape — no new fields.

---

## 5. Surface binding — `SearchHomeView`

`SearchHomeView` is a caller of `ExecutionSurfaceShell`. It supplies the seven region inputs from a runtime `SearchSession` value (see §6) and delegates every return path to `AppBootstrap.returnToChat()`. It is **not** allowed to render:

- A private nav bar, hamburger, or back button.
- A private hero `KAirSurface(style: .hero)` block that mirrors the shell's own hero.
- A private empty state ("No results" copy) — that is `ExecutionSurfaceSystemState.empty`, and the shell owns the copy.
- A private feedback row or status strip style — reuse `ExecutionSurfaceStatus`.
- A search text field inside the surface. Search is chat-invoked; refining a query means returning to the chat thread. (This is the clarifying rule that makes Search fit the surface model — if we ever wanted an in-surface search box, Search would stop being an Execution Surface and become a Space, which is a different contract entirely.)

Search's **primary region (3)** renders exactly one vertical-flavored card: a `SearchResultCard`, which is itself an `ActionCardShell` instance (per framework §4 rule). It shows the session title (the query), subtitle (one-line summary), and the kind-appropriate primary + secondary CTAs.

Search's **supplementary region** in v0 renders nothing. No result list, no related searches, no follow-up prompts. v0 is the shell-reuse proof, not a real search product.

### 5.1 State mapping

| `SearchHomeView` condition                                            | `ExecutionSurfaceSystemState` |
| --------------------------------------------------------------------- | ----------------------------- |
| `bootstrap.activeSearchSession != nil` and result is populated         | `.ready`                      |
| No active session (fresh launch of surface)                            | `.empty`                      |
| Future: query issued but provider fetch in flight                      | `.loading`                    |
| Future: provider returned an error                                     | `.error`                      |
| Future: search API unavailable (rate-limited, partner not wired)       | `.permissionOrUnavailable`    |

In v0, sessions are deterministic fixtures — we only exercise `.empty` (no session on first entry) and `.ready` (a synthesized session). The remaining three cases are wired but dormant. T9 asserts the mapping is the framework enum, not a Search-private enum.

### 5.2 Terminal row

Search **does** declare region (7) — the terminal row — for one signal only: **research finished**. When a `deepResearch` session synthesizes its final answer (in a future version with a real pipeline), the shell renders:

- Title: `Research complete` / `研究完成`
- Glyph: `checkmark.seal`
- Inline `Back to chat` capsule — same as the nav rail's.

For `answerNow` and `openWebResult`, there is no terminal row: answering and opening a link are instantaneous from the card's perspective and the card itself is the payload. The terminal row is specifically for tasks with an internal lifecycle.

In v0, `deepResearch` is not wired (we don't actually synthesize), so this region is dormant but declared. T9 asserts the wiring is in place for the moment Search earns a real lifecycle.

---

## 6. Runtime — `SearchSession`

`SearchSession` is the smallest value that can represent "a Search task that has been invoked from chat and not yet returned." It is modeled on `MusicPlaybackSession` (same lightness, same scope).

```swift
struct SearchSession: Identifiable, Hashable {
    enum Language { case english, chinese }

    let id: UUID
    let kind: SearchTaskKind
    let query: String            // the user's chat prompt, verbatim
    let headlineAnswer: String   // for answerNow: the inline answer
                                 // for openWebResult: the result title
                                 // for deepResearch: the synthesis so far
    let summary: String          // one-line explanation (visible in card subtitle)
    let sourceLabel: String      // "AI-synthesized" (v0 only — no real source)
    let language: Language
    let startedAt: Date
}
```

**AppBootstrap coupling is deferred.** Unlike Music (which exposes `activeMusicSession` and is chat-invoked), Search in v0 is **not** yet hooked to the chat-invocation pipeline. `SearchHomeView` takes the session directly as a `let` parameter plus an `onReturnToChat: () -> Void` closure — no `bootstrap` reference. When Search earns real chat-invocation (v1+), `AppBootstrap` will gain `activeSearchSession: SearchSession?` and `openSearch(with:)`, mirroring the Music interface exactly. This keeps v0 strictly scoped to the shell-reuse proof: Search renders through the shared shell without yet requiring runtime plumbing.

No new runtime object, no new event loop, no new scorer, no `SurfaceEntryRequest` extension in v0. The T9 tests exercise the types directly.

---

## 7. What Search explicitly does **not** get in v0

This list is part of the freeze. Adding any of these is a v1 event on this doc, not a v0 patch.

- A `SearchActionCardModel` frozen-contract type (deferred until a real Search scorer adapter lands).
- A partner-specific trust pill (e.g. "via Google," "via Perplexity," "via Apple Intelligence"). When a partner lands, existing pills extend or disappear — no new kind is added.
- A provider-ranking display (e.g. confidence scores, citation counts, source reliability badges). v0 has no provider.
- Per-kind color theming on the card or the surface. The visual system §4 palette is the only palette.
- A search text field in `SearchHomeView`. If refinement is needed, the user returns to the chat thread (this is what "chat-invoked" means).
- An in-card preview of web content (favicons, OG images, rich snippets). Preview payloads are v1+.
- A "recent searches" rail in Chat Home. That is owned by `chat-home-and-recommended-next-spec-v1.md`; Search does not fork it.
- Its own `@MainActor @Observable SearchRuntime`. The existing `AppBootstrap.activeSearchSession` property is sufficient for v0.
- Its own set of feedback kinds. Reuse `MatchingFeedbackKind`.
- Any network access, crawling, scraping, or real API call. This is deliberate: Round 6's Search vertical is a **shell-reuse proof**, not a search product.

---

## 8. Post-return message format (Search → chat thread)

When Search returns to chat via `AppBootstrap.returnToChat()`, the thread receives a one-line system message summarizing what happened. The format is identical to Maps/Music — Search does not invent a new summary format.

| Task kind       | Return message (en)                                        | Return message (zh)                        |
| --------------- | ---------------------------------------------------------- | ------------------------------------------ |
| `answerNow`     | `Answer shown: <query>`                                    | `已回答：<query>`                           |
| `openWebResult` | `Opened result for: <query>`                               | `已打开结果：<query>`                       |
| `deepResearch`  | `Research started on: <query>`                             | `已开始研究：<query>`                       |

`<query>` is truncated at 60 characters with an ellipsis if longer. This reuses the existing truncation helper in `ChatStore` — Search does not fork that either.

(In v0, no chat message is actually written because we don't wire the `SurfaceEntryEventPhase.returned` handler for Search yet. T9 only asserts the format table is correct and reachable from the task kind.)

---

## 9. Verification — the T9 lock test

A single new test suite locks the v0 contract:

**T9 `SearchShellReuseTests`** — asserts Search is a pure caller of the shells. Checks:

1. `SearchTaskKind` has exactly the three v0 kinds (`answerNow`, `openWebResult`, `deepResearch`). Adding a fourth breaks T9.
2. Primary + secondary CTA copy per kind × language is exactly §2. No provider layer can mutate these strings.
3. Header label + glyph per kind × language is exactly §2.
4. `SearchCardContent.trustPills` is exactly `[.partnerFallback]` for all three kinds in v0. No Search-specific pill is introduced.
5. `SearchCardContent.trustPills` is typed as `[ActionCardTrustPillKind]` (compile-time witness — if a Search-private enum is introduced, the type annotation fails).
6. Search surface state mapping lives in a test-only mirror (`SearchSurfaceStateMapper`) whose codomain is `ExecutionSurfaceSystemState` (compile-time witness — Search cannot forge a private state enum).
7. The post-return message format table (§8) produces the locked strings per kind × language.

T9 runs at startup alongside T1–T8. The startup banner becomes `[T9 Search Shell Reuse Tests] passed=… failed=…`.

Existing tests that gain extra coverage from Search:

- **T6 `ExecutionSurfaceShellValidationTests`** — already vertical-agnostic; Search surface automatically benefits from the existing "same inputs → identical shell output" assertions because `SearchHomeView` calls the shell with the same builders Music does.
- **T8 `ShellExceptionGuardTests`** — already enforces the 7-case trust-pill cardinality, the 5-case state cardinality, and the single `returnToChat` entry point. Adding Search does not and cannot expand these.

T8 and T9 together are the joint guard: T8 asserts no *new* vocabulary appears globally; T9 asserts that *Search specifically* obeys the existing vocabulary.

---

## 10. Review checklist

- [ ] Every Search Action Card is a `SearchActionCardView` → `ActionCardShell` (no ad-hoc `KAirSurface` cards).
- [ ] Every Search full-screen surface is a `SearchHomeView` → `ExecutionSurfaceShell`.
- [ ] The only Search-specific copy is (§2) kind labels + CTA titles + (§5.2) terminal-row title + (§8) post-return message.
- [ ] No Search-specific affordance in the primary region outside the card CTAs.
- [ ] All back-to-chat entries read `Back to chat` / `返回聊天` with accessibility identifier `execution-surface-back-to-chat`.
- [ ] Trust pills (if any) come from `ActionCardTrustPillKind`; only `.partnerFallback` in v0.
- [ ] No private empty / error string — degradations render via `ExecutionSurfaceSystemState`.
- [ ] No network / crawl / real search logic. Fixtures only.
- [ ] T9 passes with 7/7 green in the startup banner.

---

## 11. Version history

| Date       | Change                                                                                 |
| ---------- | -------------------------------------------------------------------------------------- |
| 2026-04-20 | v0 frozen. Three kinds (`answerNow`, `openWebResult`, `deepResearch`), shared pills, shared states, shared shells. Round 6 third-vertical shell-reuse proof. |
