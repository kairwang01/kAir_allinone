# Mixed Recommendation Layout v1

**Status**: Frozen (2026-04-20).
**Scope**: Freezes how **Recommended Next** in chat home renders slates that mix object types (place, route, song, video, search result, answer card, web/partner result, tool entry, thread). Defines direct-slot vs alternatives visual priority, single / dual / triple card layouts, metadata density caps per object type, and multi-object feedback / accepted-state expression. This is a **binding** over the existing shell — no new card primitive, no new trust pill, no new layout enum. It freezes *behavior* so per-vertical slates (Maps-heavy, Music-heavy, Search-heavy) cannot each invent their own stacking, grouping, or prioritization story.

This doc sits below:

- `super-app-visual-system-v1.md` — visual source of truth.
- `chat-home-and-recommended-next-spec-v1.md` — Recommended Next container (Layer 4).
- `action-card-component-inventory.md` — card primitive inventory.
- `../../Contracts/UX/post-return-and-continuation-ux-v1.md` — refresh timing, count, retention rules.

If anything here disagrees with the specs above, **the shell specs win**. Mixed layout cannot invent a grid, a carousel, a per-kind section header, or a per-vertical size variant.

---

## 1. The nine object kinds that can be mixed

`MatchingObjectKind` has exactly nine cases. Every card rendered in Recommended Next is one of these — no card has zero kind, no card has multiple kinds.

| # | `MatchingObjectKind` | Home surface   | Header glyph                                    | Header label (en / zh) |
| - | -------------------- | -------------- | ----------------------------------------------- | ---------------------- |
| 1 | `.place`             | Maps           | `mappin.and.ellipse`                            | `Place` / `地点`        |
| 2 | `.route`             | Maps           | `arrow.triangle.turn.up.right.diamond`          | `Route` / `路线`        |
| 3 | `.contact`           | Contacts/Chat  | `person.2`                                      | `Contact` / `联系人`    |
| 4 | `.song`              | Music          | `music.note`                                    | `Song` / `歌曲`         |
| 5 | `.video`             | Video          | `play.rectangle`                                | `Video` / `视频`        |
| 6 | `.searchResult`      | Search (web)   | `magnifyingglass`                               | `Web result` / `网络结果` |
| 7 | `.answerCard`        | Search (inline)| `text.bubble`                                   | `Answer` / `答案`       |
| 8 | `.toolEntry`         | Any surface    | `square.stack.3d.up`                            | `Tool` / `工具`         |
| 9 | `.thread`            | Chat           | `bubble.left.and.bubble.right`                  | `Thread` / `线程`       |

**Hard rule**: no tenth kind may be added without a v2 of this doc. Health, AI, and Store do **not** get their own object kind — they surface through `toolEntry` (for "open the surface") or through whatever object they produce (`answerCard` for an AI summary, `song` for a Music pick, etc.).

The v1 spec explicitly covers **≥5 kinds in a single slate** because that is the cap the provider enforces (see §3). Kinds 1, 2, 4, 5, 6, 7, 8 are the seven that can realistically co-appear in one slate; `.contact` and `.thread` are rarer but follow identical rules.

---

## 2. Direct slot vs alternatives — the two-tier hierarchy

Every Recommended Next slate has **exactly two visual tiers**. No third tier, no nesting, no "expand for more."

### 2.1 Direct slot (tier 1)

- **Position**: First card in the slate — always the top of the rail.
- **Role**: The single highest-ranked candidate for the user's current context. The matcher's one explicit bet.
- **Count**: Always **exactly 1**. Never zero (an empty slate hides the rail entirely), never more than one.
- **Visual treatment**: Standard `ActionCardShell` with no tier marker, no "recommended" badge, no ribbon. The position itself is the signal. Adding a "Top pick" pill would be a vertical-specific ornament and is forbidden.

### 2.2 Alternatives (tier 2)

- **Position**: Cards 2 through N, in rank order below the direct slot.
- **Role**: Sibling candidates at the same level of confidence band — "if the direct slot misses, here are the close runners-up."
- **Count**: 0, 1, or 2 cards (see §3 for the layout-state math; the provider cap of 3 per `objectKind` × 3 per `sourcePool` plus a max slate size of 3 bounds this).
- **Visual treatment**: Identical `ActionCardShell` — no visual downgrade, no smaller size, no different border, no dimmed opacity. Alternatives look the same as the direct slot; *position* is the only prioritization signal. This is deliberate: the super-app's promise is "we showed you the best options," not "we ranked your options for you."

### 2.3 Why no visual downgrade for alternatives

Dimming, shrinking, or de-chroming alternatives would signal "these are worse" — but they are *not* worse; they are *different* bets in the same confidence band. Visual downgrade would pressure users toward the direct slot even when an alternative fits better. Position is enough.

### 2.4 Why no grouping / no section headers

Slates do **not** render "From Maps" / "From Music" / "From Search" group dividers even when the slate is mixed. Grouping implies the user wants to filter by source; Recommended Next is context-driven, not source-filtered. A mixed slate of `[place, song, answerCard]` renders as three stacked cards with no divider — the kind glyph inside each card header communicates the source.

---

## 3. Layout states — single / dual / triple

Every slate renders in one of exactly three states. The provider's cap (§3 of `../../Contracts/UX/post-return-and-continuation-ux-v1.md`) keeps slates at ≤ 3 cards, so no other state is reachable. T12 locks this.

### 3.1 Single (1 card)

- **When**: Provider returned exactly 1 candidate that survived the caps.
- **Content**: 1 direct slot. No alternatives.
- **Layout**: Single full-width `ActionCardShell` inside the rail container. No surrounding "X of Y" counter.
- **Rationale**: A single-card state is *common* right after a hard pivot (new task, little context). It must not look broken — no placeholder "more coming soon" card, no empty-state illustration.

### 3.2 Dual (2 cards)

- **When**: Provider returned exactly 2 candidates.
- **Content**: 1 direct slot + 1 alternative.
- **Layout**: Two stacked full-width `ActionCardShell`s. Same card width. Same card height (height is content-driven but caps at the visual system's §5 max-height rule). No "vs." comparator, no side-by-side variant.
- **Rationale**: The most common steady-state. Two equal-width cards communicate "two good options" without forcing the user to pick a winner.

### 3.3 Triple (3 cards)

- **When**: Provider returned 3 candidates (the cap ceiling).
- **Content**: 1 direct slot + 2 alternatives.
- **Layout**: Three stacked full-width `ActionCardShell`s. Identical rules to dual — same width, no comparator, no carousel, no horizontal scroll.
- **Rationale**: Triple is the cap. If the provider returned 4+, `RetrievalCandidateProvider.selectCandidates` already trimmed to ≤ 3. Anything beyond triple is out of scope for v1.

### 3.4 What this doc does **not** permit

- **No 4+ card state**. Not in a scroll strip, not in a "see more" modal.
- **No carousel / horizontal scroller**. The rail is vertical stacking only.
- **No accordion**. Alternatives are never collapsed.
- **No grid**. Two cards side-by-side would prompt "pick one" semantics; we want "here are options."
- **No featured / callout variant**. Size and chrome are uniform across the slate.

---

## 4. Metadata density caps per object kind

Every object kind exposes its own scorer metadata (distance, duration, source count, track length, etc.). `ActionCardShell` has **one** place to render this: the `subtitle` slot plus the optional `reasonText` line. No object kind gets a metric strip, a tag cloud, or a rich inline chart.

### 4.1 Subtitle cap: ≤ 2 metadata tokens

A "metadata token" is one short factoid separated by `·` (middle dot). The subtitle renders **at most two** tokens. Beyond two, the card looks like a dashboard row and breaks the "one glance, one decision" promise of `ActionCardShell`.

| Object kind     | Token 1 (required)                | Token 2 (optional)                   | Forbidden in subtitle                          |
| --------------- | --------------------------------- | ------------------------------------ | ---------------------------------------------- |
| `.place`        | Distance or neighborhood          | Category ("Café", "Clinic")          | Rating, photo count, price tier                |
| `.route`        | ETA or distance                   | Mode ("Walking", "Driving")          | Turn count, traffic level, elevation           |
| `.contact`      | Relationship ("Family", "Coworker") | Last interaction ("Last msg Tue")  | Phone number, email, handles                   |
| `.song`         | Artist                             | Duration or mood                    | BPM, genre tree, album year                    |
| `.video`        | Duration                           | Category ("Tutorial", "Ambient")    | Views, upload date, channel                    |
| `.searchResult` | Domain ("apple.com")               | Date ("2 days ago")                 | Snippet length, query match %, SERP rank        |
| `.answerCard`   | Source ("AI-synthesized")          | Length ("1-paragraph answer")       | Token count, model name, citations count        |
| `.toolEntry`    | Surface ("Maps", "Health")         | Last-used ("Used this morning")     | Grant state, permission detail, version         |
| `.thread`       | Thread title                       | Last message timestamp              | Message count, participant list, unread counter |

### 4.2 reasonText cap: ≤ 1 short clause

`reasonText` is the one-line explanation below subtitle (the "why this") and **must** be:

- A single clause — no sub-clauses, no semicolons.
- ≤ 60 characters.
- In the surface's language (en / zh); never mixed.
- Written in the user's frame (not the matcher's) — "Matches your morning pattern" is allowed; "Scored 0.72 against prior intent tags" is forbidden.

When the matcher cannot produce a user-facing reason (e.g., low confidence), `reasonText` is nil and the card simply omits it.

### 4.3 Why caps vary per kind

A `place` card has inherently less useful text-first metadata than a `song` card — places benefit from photos (v1+) while songs benefit from duration. But photos are not permitted in v1: every card is text-first `ActionCardShell`. So the cap is per-kind to keep each card readable *as text*. This is the contract.

---

## 5. Multi-object feedback and accepted-state expression

When the slate is mixed (e.g., one place + one song + one answer card), feedback and accepted states must be expressed per-card — **never globally across the slate**.

### 5.1 Feedback is per-card

Every card has its own `⋯` feedback menu. The menu opens the same five-option `MatchingFeedbackKind` list regardless of `objectKind`:

1. `忽略` / Dismiss
2. `不感兴趣` / Not interested
3. `以后少推这类` / Less like this
4. `现在不需要` / Not now
5. `已经做过了` / Already done

The option set does **not** vary by object kind. A song card and a place card offer the same five options because:

- The matcher treats all five signals as object-kind-aware under the hood (`lessLikeThis` on a song down-weights songs more than places).
- Offering a different menu per kind would create "Music has thumbs-down, Places has lists" — exactly the vertical fork this doc prevents.

### 5.2 Accepted state expression

When the user taps `Accept` on one card in a mixed slate, **only that card** changes state. The other cards in the slate are **untouched**:

- The accepted card is stored in `activeRecommendationBySection[section]` and removed from the visible rail on the next refresh (§3 of `../../Contracts/UX/post-return-and-continuation-ux-v1.md`).
- Siblings in the same slate stay visible until the refresh hits.
- There is **no** "You picked X, dismissing Y and Z" sweep. Siblings are not auto-dismissed by siblings.

### 5.3 Dismissed state expression

When the user hits `✕` / any feedback kind on one card, **only that card** is removed from `recommendedMatches`. Siblings persist. The refresh then backfills the removed slot from the candidate pool.

### 5.4 Mixed-slate edge case: two cards share a kind

The provider caps at 3 per `objectKind`, so a slate can have 0–3 cards of the same kind. When two cards of the same kind co-appear:

- Both render identically — no "primary song / alternate song" badge.
- Feedback on one does not automatically apply to the other (even `lessLikeThis` on a song downrank only the *scorer's future* songs — the sibling already in the slate stays).

---

## 6. What this doc does **not** permit

- **No per-vertical layout variant.** Maps cannot render a mini-map in the card. Music cannot add a play button inline. Video cannot embed a thumbnail. All cards are text-first `ActionCardShell`.
- **No per-vertical arrangement.** Maps cannot push its cards to the top when a map-heavy slate arrives; the direct slot is whatever scores highest, period.
- **No group headers.** No "From Maps," "From Music," "Nearby," "Today."
- **No tabs or chips above the slate** to filter by `objectKind` — Recommended Next is not a drawer.
- **No counter / pagination.** The slate is whatever fits in ≤ 3; no "1 of 5."
- **No inline preview** (map thumbnail, album art, video still, favicon). v1 is text-and-glyph.
- **No tier-3 "deep cuts" section** or "more like this" drill-down.
- **No per-kind animation** on enter/exit. Refreshes are instantaneous state swaps per `../../Contracts/UX/post-return-and-continuation-ux-v1.md` §3.4.
- **No per-kind typography change.** The shell's typography applies uniformly (`super-app-visual-system-v1.md` §2).

---

## 7. Verification — the T12 lock test

A single new test suite locks Mixed Recommendation Layout v1:

**T12 `MixedRecommendationLayoutTests`** — asserts the provider + renderer respect the two-tier hierarchy, the three layout states, and the metadata caps.

Checks (minimum):

1. **Object kind count is 9** — `MatchingObjectKind.allCases.count == 9`. Adding a tenth breaks T12.
2. **Provider cap is 3 per `objectKind`** — a synthetic ranked list with 5 songs + 5 places is trimmed to ≤ 3 of each kind by `RetrievalCandidateProvider.selectCandidates` (black-box via a test harness).
3. **Provider cap is 3 per `sourcePool`** — same idea for `sourcePool`.
4. **Slate size is ≤ 3** — `recommendedMatches.count` never exceeds 3 after any refresh in the test harness.
5. **Direct slot is always index 0** — the rail's first card is the highest-ranked candidate. Verified via the sorted order coming out of `selectCandidates`.
6. **Alternatives use the same `ActionCardShell`** — no alternate view type is constructed for non-direct slots. Verified via a type-identity check in `ChatHomeView` test shim.
7. **Feedback menu is the 5-case `MatchingFeedbackKind`** — the same five options are offered on every card regardless of `objectKind`. (Shared with T11.)
8. **No per-kind branch in the card binder** — the binder only switches on the fields that are *already* per-kind (`title`, `subtitle`, header glyph). It must not switch on layout, width, animation, or affordance set.
9. **Mixed slate does not synthesize group headers** — assert the rail's rendered tree contains no "sectionHeader" view type.

T12 runs at startup alongside T1–T11. Startup banner gets `[T12 Mixed Recommendation Layout Tests] passed=… failed=…`.

### 7.1 Which older tests gain coverage

- **T3 `MatchingKernelTests`** already locks the 9-kind and 5-feedback cardinalities; T12 references that lock rather than duplicating it.
- **T4 `RetrievalProviderTests`** (if wired) locks the cap math; T12 consumes that as a precondition.

---

## 8. Review checklist

- [ ] Every slate has 1–3 cards and exactly one direct slot.
- [ ] Direct slot and alternatives use the same `ActionCardShell` with identical chrome.
- [ ] No group headers, no dividers, no per-source sections.
- [ ] Subtitle has ≤ 2 metadata tokens; `reasonText` ≤ 60 chars.
- [ ] No object kind renders a mini-map, album art, video thumbnail, or favicon in v1.
- [ ] Feedback is per-card; siblings untouched on accept / dismiss.
- [ ] Feedback menu is the same 5 `MatchingFeedbackKind` options on every card.
- [ ] No per-vertical animation, haptic, or sound on slate changes.
- [ ] T12 passes 9/9 in the startup banner.

---

## 9. Version history

| Date       | Change                                                                                                    |
| ---------- | --------------------------------------------------------------------------------------------------------- |
| 2026-04-20 | v1 frozen. 9 object kinds × 2-tier hierarchy × 3 layout states × per-kind metadata caps × per-card feedback. |
