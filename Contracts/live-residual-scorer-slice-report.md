# Live Residual Scorer Slice Report

- Authoritative ledger: `Contracts/live-residual-ledger.md`
- Upstream replay: `Contracts/provider-phase-replay-report.md`
- Patch in effect (frozen): `promptDirectnessBonus = max(0, promptLexical + phrase - suppression) * 0.30`
- Scope: scorer-only diagnostic on the live **22-case** residual near-miss set.
- This report supersedes the frozen 20-case pre-patch slice (`Contracts/residual-scorer-slice-report.md`). That file stays for historical reference only; it is **not** the basis for the next scorer decision.

## Base Set

- Live residual near-miss: `22 / 22` in final top-k, `0 / 22` in direct slot.
- All 22 have root cause `scorer`. Retrieval is not the bottleneck on this slice.
- Group A (still unresolved old near-miss): `14`
- Group B (newly entered live residual): `8`

## Bucket Distribution

### Group A — 14 still-unresolved old near-miss

| Dominant delta bucket | Count | Cases |
| --- | ---: | --- |
| `context_lexical` | 7 | `local-search-conflict`, `music-focus-clean`, `music-recent-search-drift`, `search-parking-clean`, `search-recent-tool-drift`, `search-runtime-history`, `video-howto-surface` |
| `phrase` | 4 | `music-long-term-commute-drift`, `search-ambiguous-why`, `search-answer-drift`, `video-vs-answer-conflict` |
| `prompt_lexical` | 3 | `commute-search-facts`, `music-ambiguous-session`, `search-low-info` |
| `suppression` | 0 | — |

Dominant head: `context_lexical` (50%). Secondary head: `phrase` (29%). Together `context_lexical + phrase` cover `11 / 14 = 79%` of Group A.

### Group B — 8 newly entered live residual

| Dominant delta bucket | Count | Cases |
| --- | ---: | --- |
| `context_lexical` | 4 | `music-focus-dismiss`, `music-multi-object`, `tool-ai-runtime-history`, `video-ambiguous-show-me` |
| `phrase` | 2 | `local-dinner-dismiss`, `search-multi-object` |
| `suppression` | 2 | `local-cafe-maps-surface`, `tool-ambiguous-open-right-thing` |
| `prompt_lexical` | 0 | — |

Dominant head: `context_lexical` (50%). Secondary is split evenly between `phrase` and `suppression` (2 each). `context_lexical + phrase` cover `6 / 8 = 75%` of Group B, but the phrase share is half the size of Group A.

### Combined 22-case view (for reference only, not a decision basis)

| Dominant delta bucket | Count |
| --- | ---: |
| `context_lexical` | 11 |
| `phrase` | 6 |
| `prompt_lexical` | 3 |
| `suppression` | 2 |

## Object-type Slice

| Expected object family | Group A | Group B | Total |
| --- | ---: | ---: | ---: |
| `search-*` | 8 | 1 | 9 |
| `music-*` | 4 | 2 | 6 |
| `video-*` | 2 | 1 | 3 |
| `maps-*` | 0 | 2 | 2 |
| `tool-*` | 0 | 2 | 2 |

Group A concentration: search + music = `12 / 14 = 86%`. Group B spreads more thinly across families; `maps-*` and `tool-*` appear only in Group B.

## Final-score Delta Profile

- Group A median `final_score(top-1 − expected)` delta: ~`+0.11` (range `+0.01` … `+0.14`). All 14 cases are scored down behind top-1 by a visible margin; the patch has not narrowed them enough to flip direct-slot.
- Group B median delta: ~`+0.08` (range `+0.01` … `+0.15`). Several sit very close to the direct-slot boundary (`search-multi-object +0.01`, `tool-ambiguous-open-right-thing +0.02`, `local-search-conflict-style` cases).

Group B is on average closer to direct-slot flip than Group A, but its dominant head is the same.

## Cross-group Comparison

| Dimension | Group A (14) | Group B (8) |
| --- | --- | --- |
| Dominant head | `context_lexical` (50%) | `context_lexical` (50%) |
| Secondary head | `phrase` (29%) monolithic | `phrase` / `suppression` split |
| Tertiary head | `prompt_lexical` (21%) | `prompt_lexical` 0% |
| Object-type spread | search + music heavy | spread across 5 families |
| Avg final-score gap | larger | smaller, several at the edge |
| Exposure stability | stable (same cases as frozen slice) | new exposures from live replay |

## Decision

**If the next move is another scorer patch, target Group A first.**

Rationale:

1. Group A is larger (14 vs 8) and contributes more to the residual count.
2. Group A has a clean two-head structure (`context_lexical + phrase` = 79%), so a single-channel scorer change can target it cleanly without leaking into `suppression`.
3. Group B's secondary head splits across `phrase` and `suppression`; a Group-B-first patch would need to balance two channels and risks fighting the frozen `promptDirectnessBonus` (which already subtracts `suppression`).
4. Group B's object-type spread means a Group-B-first change can easily bleed into families (`maps-*`, `tool-*`) that were not exposed on the frozen slice, which would make the next gate harder to attribute.
5. Group B cases are on average closer to the direct-slot boundary, so many should move incidentally when Group A's head is addressed.

**Do not attempt a single scorer change aimed at both groups simultaneously.** The bucket-distribution profiles overlap on `context_lexical` but diverge on the secondary head, so a shared lever would be underspecified.

## Explicit Non-goals

- No new scorer coefficient is proposed in this report. This is a slice diagnostic, not a patch.
- Group B is not dismissed; it is deferred behind Group A.
- Weak-trace is not considered here. See `Contracts/weak-trace-trace-strength-diagnosis.md`.
- The frozen 20-case slice is **not** used as the basis for any decision above.
