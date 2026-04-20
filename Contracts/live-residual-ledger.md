# Live Residual Ledger

- Authoritative source of truth for post-patch live residual accounting.
- Upstream replay: `Contracts/provider-phase-replay-report.md`
- Downstream reports (scorer slice, direct-slot audit, weak-trace diagnosis, reconciliation) must render every near-miss / candidate-miss / weak-trace number from this file.
- Patch under gate: `promptDirectnessBonus = max(0, promptLexical + phrase - suppression) * 0.30` (scorer-only, frozen).

## Totals

| Slice | Count |
| --- | ---: |
| Near-miss (live) | 22 |
| Candidate-miss (live) | 0 |
| Weak-trace (live) | 17 |
| Provider miss | 0 |

Reconciliation of the 22 near-miss set vs the frozen pre-patch 20-case slice:

- Frozen pre-patch scorer slice near-miss base: 20
- Recovered old near-miss after patch (direct slot): 6
- Still unresolved old near-miss: 14
- Newly entered live residual near-miss after full replay: 8
- Live residual near-miss total: 14 + 8 = 22

This replaces the mismatch in the replay markdown where the `## Near-miss Cases` section renders only 20 blocks (missing `video-howto-surface` and `video-vs-answer-conflict`) while the full replay accounting reconciles to 22. The authoritative count is 22.

## Live Residual Near-miss (22)

All 22 cases: root cause = `scorer`, final top-k = `yes`, direct slot = `no`.

### Group A — Still Unresolved Old Near-miss (14)

These were in the frozen 20-case scorer slice and remain non-direct after the patch.

| # | Case | Expected | Rank | Final top-k | Direct slot | Dominant delta bucket | Root cause |
| ---: | --- | --- | ---: | --- | --- | --- | --- |
| 1 | `commute-search-facts` | `search-parking` | 2 | yes | no | `prompt_lexical` | scorer |
| 2 | `local-search-conflict` | `search-parking` | 2 | yes | no | `context_lexical` | scorer |
| 3 | `music-ambiguous-session` | `music-focus` | 3 | yes | no | `prompt_lexical` | scorer |
| 4 | `music-focus-clean` | `music-focus` | 2 | yes | no | `context_lexical` | scorer |
| 5 | `music-long-term-commute-drift` | `music-focus` | 2 | yes | no | `phrase` | scorer |
| 6 | `music-recent-search-drift` | `music-focus` | 2 | yes | no | `context_lexical` | scorer |
| 7 | `search-ambiguous-why` | `search-runtime` | 5 | yes | no | `phrase` | scorer |
| 8 | `search-answer-drift` | `search-runtime` | 5 | yes | no | `phrase` | scorer |
| 9 | `search-low-info` | `search-parking` | 4 | yes | no | `prompt_lexical` | scorer |
| 10 | `search-parking-clean` | `search-parking` | 2 | yes | no | `context_lexical` | scorer |
| 11 | `search-recent-tool-drift` | `search-runtime` | 3 | yes | no | `context_lexical` | scorer |
| 12 | `search-runtime-history` | `search-runtime` | 3 | yes | no | `context_lexical` | scorer |
| 13 | `video-howto-surface` | `video-howto` | 2 | yes | no | `context_lexical` | scorer |
| 14 | `video-vs-answer-conflict` | `video-howto` | 2 | yes | no | `phrase` | scorer |

### Group B — Newly Entered Live Residual (8)

These were **not** in the frozen 20-case slice; they appear as post-patch live residual near-miss in the full replay ledger.

| # | Case | Expected | Rank | Final top-k | Direct slot | Dominant delta bucket | Root cause |
| ---: | --- | --- | ---: | --- | --- | --- | --- |
| 1 | `local-cafe-maps-surface` | `maps-evening-cafe` | 3 | yes | no | `suppression` | scorer |
| 2 | `local-dinner-dismiss` | `maps-quiet-dinner` | 2 | yes | no | `phrase` | scorer |
| 3 | `music-focus-dismiss` | `music-focus` | 2 | yes | no | `context_lexical` | scorer |
| 4 | `music-multi-object` | `music-focus` | 4 | yes | no | `context_lexical` | scorer |
| 5 | `search-multi-object` | `search-parking` | 2 | yes | no | `phrase` | scorer |
| 6 | `tool-ai-runtime-history` | `tool-ai-runtime` | 2 | yes | no | `context_lexical` | scorer |
| 7 | `tool-ambiguous-open-right-thing` | `tool-health` | 2 | yes | no | `suppression` | scorer |
| 8 | `video-ambiguous-show-me` | `video-howto` | 2 | yes | no | `context_lexical` | scorer |

## Recovered Old Near-miss (6)

In the frozen 20-case slice and moved to direct-slot recovery after the scorer patch. Not part of the 22 live residual total.

- `local-cafe-long-term-drift`
- `search-health-dismiss`
- `tool-health-dismiss`
- `tool-runtime-long-term-drift`
- `tool-store-surface`
- `video-neighborhood-history`

## Live Weak-trace (17)

| Bucket | Count | Cases |
| --- | ---: | --- |
| Final top-k + direct slot | 8 | `commute-ambiguous-go-now`, `commute-long-term-drift`, `commute-route-dismiss`, `commute-route-history`, `music-focus-history`, `search-health-dismiss`, `tool-store-surface`, `tool-vs-search-conflict` |
| Final top-k + non-direct | 5 | `commute-search-facts`, `local-dinner-dismiss`, `music-ambiguous-session`, `music-focus-dismiss`, `search-multi-object` |
| Outside final top-k (composer / diversifier) | 4 | `music-commute-surface`, `music-conflict-route-later`, `search-runtime-ai-surface`, `video-howto-dismiss` |

Note: the 5 `final top-k + non-direct` weak-trace cases fully overlap with Group A/B of the live near-miss ledger (4 from Group A, 1 from Group B). They are not additional residual; they are the same scorer-adjacent exposures seen from the trace-strength side.

## Live Candidate-miss (0)

No live candidate-miss cases post-patch.

## Rendering Rules

- The count `22 near-miss` is canonical. Any downstream report that renders fewer case blocks (e.g. the replay markdown's `## Near-miss Cases` with 20 blocks) is out-of-date and must be reconciled against this ledger before citation.
- The count `17 weak-trace` is canonical. The three buckets above are exhaustive.
- `provider miss = 0` and `candidate-miss = 0` are canonical.
- No scorer patch, weak-trace bonus, or slice decision may be taken from a ledger other than this one until it is updated here first.
