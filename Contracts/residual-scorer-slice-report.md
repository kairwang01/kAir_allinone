# Residual Scorer Slice Report (Frozen Pre-patch — Historical)

> **Status:** Historical. This report describes the frozen pre-patch 20-case scorer slice.
> It is **not** the current decision basis. For live post-patch residual:
> - Authoritative ledger: `Contracts/live-residual-ledger.md`
> - Current slice diagnostic: `Contracts/live-residual-scorer-slice-report.md`

- Frozen provider baseline: `provider-baseline-v4-retrieval-lift`
- Source report: `Contracts/provider-phase-replay-report.md`
- Frozen residual exposure (pre-patch): `37` (`20 near-miss`, `0 candidate-miss`, `17 weak-trace`)
- Current guardrail state from frozen provider baseline: `not aligned = 0.0%`, `explicit dismiss = 75.0%`, `object-type concentration = 0.29`
- Provider miss is already `0`, and current near-miss audit still shows `0 / 20` dropped after scoring; scorer remains the main live layer for direct-slot recovery.

## Residual Scorer Slice

- Near-miss: `20 / 20` already in final top-k, `0 / 20` direct slot. Dominant buckets: `context_lexical` 9, `suppression` 5, `prompt_lexical` 3, `phrase` 3.
- Weak-trace: `10 / 17` still in final top-k, with `6 / 17` already holding direct slot and `4 / 17` still losing direct slot. Dominant buckets inside the top-k weak-trace slice: `suppression` 5, `prompt_lexical` 3, `context_lexical` 2.
- Held-out weak-trace: `7 / 17` sit outside final top-k. They stay visible in the residual ledger, but they are not part of the current scorer direct-slot hypothesis. Dominant buckets there: `composer_diversity` 7.
- Direct-slot-loss exposure summary (`20 near-miss + 4 weak-trace overlap exposures`): `context_lexical` 9, `suppression` 7, `prompt_lexical` 5, `phrase` 3.

### Near-miss

| Case | Expected | Current rank | Final top-k | Direct slot | Dominant scorer bucket | Slices |
| --- | --- | ---: | --- | --- | --- | --- |
| `commute-search-facts` | `search-parking` | 2 | yes | no | `prompt_lexical` | route, dinner, local exploration |
| `local-cafe-long-term-drift` | `maps-quiet-dinner` | 2 | yes | no | `suppression` | dinner, local exploration |
| `local-search-conflict` | `search-parking` | 4 | yes | no | `context_lexical` | dinner, local exploration |
| `music-ambiguous-session` | `music-focus` | 3 | yes | no | `prompt_lexical` | music |
| `music-focus-clean` | `music-focus` | 2 | yes | no | `context_lexical` | music |
| `music-long-term-commute-drift` | `music-focus` | 4 | yes | no | `phrase` | music |
| `music-recent-search-drift` | `music-focus` | 5 | yes | no | `context_lexical` | music |
| `search-ambiguous-why` | `search-runtime` | 5 | yes | no | `phrase` | — |
| `search-answer-drift` | `search-runtime` | 5 | yes | no | `suppression` | — |
| `search-health-dismiss` | `search-health-proof` | 2 | yes | no | `suppression` | — |
| `search-low-info` | `search-parking` | 4 | yes | no | `prompt_lexical` | dinner, local exploration |
| `search-parking-clean` | `search-parking` | 2 | yes | no | `context_lexical` | dinner, local exploration |
| `search-recent-tool-drift` | `search-runtime` | 2 | yes | no | `context_lexical` | — |
| `search-runtime-history` | `search-runtime` | 5 | yes | no | `suppression` | — |
| `tool-health-dismiss` | `tool-health` | 3 | yes | no | `context_lexical` | — |
| `tool-runtime-long-term-drift` | `tool-ai-runtime` | 2 | yes | no | `context_lexical` | — |
| `tool-store-surface` | `tool-store` | 2 | yes | no | `suppression` | — |
| `video-howto-surface` | `video-howto` | 3 | yes | no | `context_lexical` | — |
| `video-neighborhood-history` | `video-neighborhood` | 3 | yes | no | `context_lexical` | local exploration |
| `video-vs-answer-conflict` | `video-howto` | 2 | yes | no | `phrase` | — |

### Weak-trace

| Case | Expected | Current rank | Final top-k | Direct slot | Dominant scorer bucket | Slices |
| --- | --- | ---: | --- | --- | --- | --- |
| `music-commute-surface` | `music-commute` | — | no | no | `composer_diversity` | music, dinner |
| `commute-search-facts` | `search-parking` | 2 | yes | no | `prompt_lexical` | route, dinner, local exploration |
| `local-dinner-dismiss` | `maps-quiet-dinner` | — | no | no | `composer_diversity` | dinner, local exploration |
| `music-ambiguous-session` | `music-focus` | 3 | yes | no | `prompt_lexical` | music |
| `music-conflict-route-later` | `music-commute` | — | no | no | `composer_diversity` | music |
| `music-multi-object` | `music-focus` | — | no | no | `composer_diversity` | music |
| `search-health-dismiss` | `search-health-proof` | 2 | yes | no | `suppression` | — |
| `search-runtime-ai-surface` | `search-runtime` | — | no | no | `composer_diversity` | — |
| `tool-ai-runtime-history` | `tool-ai-runtime` | — | no | no | `composer_diversity` | — |
| `tool-store-surface` | `tool-store` | 2 | yes | no | `suppression` | — |
| `video-howto-dismiss` | `video-howto` | — | no | no | `composer_diversity` | — |
| `commute-ambiguous-go-now` | `maps-route-compare` | 1 | yes | yes | `context_lexical`* | route |
| `commute-long-term-drift` | `maps-route-compare` | 1 | yes | yes | `suppression`* | route |
| `commute-route-history` | `maps-route-compare` | 1 | yes | yes | `context_lexical`* | route |
| `music-focus-history` | `music-deep-work` | 1 | yes | yes | `prompt_lexical`* | music |
| `search-multi-object` | `search-parking` | 1 | yes | yes | `suppression`* | dinner, local exploration |
| `tool-vs-search-conflict` | `tool-health` | 1 | yes | yes | `suppression`* | — |

## Slice View

- `music`: near-miss `4` [music-ambiguous-session, music-focus-clean, music-long-term-commute-drift, music-recent-search-drift]; weak-trace `5` [music-commute-surface, music-ambiguous-session, music-conflict-route-later, music-multi-object, music-focus-history]
- `route`: near-miss `1` [commute-search-facts]; weak-trace `4` [commute-search-facts, commute-ambiguous-go-now, commute-long-term-drift, commute-route-history]
- `dinner`: near-miss `5` [commute-search-facts, local-cafe-long-term-drift, local-search-conflict, search-low-info, search-parking-clean]; weak-trace `4` [music-commute-surface, commute-search-facts, local-dinner-dismiss, search-multi-object]
- `local exploration`: near-miss `6` [commute-search-facts, local-cafe-long-term-drift, local-search-conflict, search-low-info, search-parking-clean, video-neighborhood-history]; weak-trace `3` [commute-search-facts, local-dinner-dismiss, search-multi-object]

## One Scorer-only Counterfactual Hypothesis

### H1: Prompt-directness bonus

- Change exactly one scorer channel: add `promptDirectnessBonus` directly to `finalScore`.
- Formula: `promptDirectnessBonus = max(0, promptLexical + phrase - suppression) * 0.30`.
- Why this one: the remaining direct-slot-loss exposure is no longer a recall problem. It is concentrated in prompt/context/phrase competition, and this term keeps suppression inside the signal instead of bypassing explicit negative feedback.
- Targeted residual class: cases where the expected candidate is already visible but loses the direct slot. This is the current live scorer problem; it does not try to repair held-out weak-trace that still sits outside final top-k.

### Pairwise counterfactual on current direct-slot-loss labels

- Unique labels evaluated: `20`
- Direct-slot promotions: `6 / 20`
- Stayed below direct slot: `14 / 20`
- Overlap weak-trace promotions: `2 / 4`
- Promoted labels: `local-cafe-long-term-drift` (+0.006), `local-search-conflict` (+0.001), `search-health-dismiss` (+0.060), `tool-runtime-long-term-drift` (+0.001), `tool-store-surface` (+0.012), `video-neighborhood-history` (+0.066)

### Why this is the next scorer hypothesis and not a patch yet

- It only touches scorer, not provider or composer.
- It is suppression-aware, so it does not win by relaxing explicit dismiss.
- It directly targets the current failure class: already in top-k, still not direct.
- It is still only a counterfactual on the residual scorer slice. It has not been run through a fresh 60/60 full replay gate yet, so it should stay out of product code until that replay passes.

* `*` bucket means trace-inferred rather than decomposition-derived because the case never entered the current decomposition table.
