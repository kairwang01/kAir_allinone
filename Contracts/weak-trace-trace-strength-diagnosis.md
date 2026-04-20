# Weak-trace Trace-strength Diagnosis (Final top-k + Non-direct)

- Authoritative ledger: `Contracts/live-residual-ledger.md`
- Upstream replay: `Contracts/provider-phase-replay-report.md`
- Scope: the 5 weak-trace cases that are in the final top-k but not in the direct slot.
- Purpose: characterize **trace strength** only. No scorer patch, no weak-trace bonus is proposed in this file.

## Cases In Scope

| Case | Expected | Rank | Near-miss group | Dominant delta bucket |
| --- | --- | ---: | --- | --- |
| `commute-search-facts` | `search-parking` | 2 | Group A (old) | `prompt_lexical` |
| `local-dinner-dismiss` | `maps-quiet-dinner` | 2 | Group B (new) | `phrase` |
| `music-ambiguous-session` | `music-focus` | 3 | Group A (old) | `prompt_lexical` |
| `music-focus-dismiss` | `music-focus` | 2 | Group B (new) | `context_lexical` |
| `search-multi-object` | `search-parking` | 2 | Group B (new) | `phrase` |

All 5 are also live near-miss. They are the same scorer-adjacent exposures seen from the trace-strength side, not additional residual.

## Trace-strength Profile

Values are qualitative reads off the live replay weight decomposition (prompt lexical, context lexical, phrase, suppression) plus the retrieval-side lexical/recency/long-term evidence.

| Case | Prompt trace | Context trace | Phrase contribution | Suppression contribution |
| --- | --- | --- | --- | --- |
| `commute-search-facts` | mid. Matched: `facts, look, up` (plus behavior tags). Expected prompt lexical 0.38, top-1 0.48 (+0.10). Expected prompt trace loses to top-1 on the `route/parking` token mix. | strong. Retrieval recency 0.75, long-term 0.75; context lexical delta only +0.03. | neutral. Both at 0.00. | neutral. Both at 0.00. |
| `local-dinner-dismiss` | strong. Matched: `quiet, cafe, dinner, place, restaurant`. Expected prompt lexical 0.34 is the largest of the 5, but top-1 (`maps-evening-cafe`) also matches dinner/cafe tokens, so delta is only -0.15. | mid. Retrieval 0.53 / recency 0.50 / long-term 0.50. Context lexical delta trivial (-0.01). | balanced. Both at 0.05 — phrase does not help expected pull ahead. | neutral. Both at 0.00. |
| `music-ambiguous-session` | weak. Prompt is "Play something that fits this work session." Only `work` / `session` match music-focus tokens. Prompt lexical 0.25 vs top-1 0.26 (+0.01). | mid. Retrieval lexical 0.39, recency/long 0.50. Context lexical delta +0.00. | missing. Both at 0.00. Expected has no phrase signal to pull ahead. | neutral. Both at 0.00. |
| `music-focus-dismiss` | mid. Prompt is "I just need focus music, not another tutorial or video." Matched: `deep, focus, study, work`. Prompt lexical delta -0.06. | mid. Retrieval 0.39, recency/long 0.50. Context lexical delta +0.00. | small. Expected 0.05 vs top-1 0.00 (helps a little). | **adverse**. Expected suppression 0.00 vs top-1 0.07 (+0.07 in favor of top-1). Only case in the 5 where suppression actively hurts expected. |
| `search-multi-object` | strong. Prompt lexical 0.46 vs top-1 0.39 (-0.07). Matched: `facts, look, map, maps, navigate`. | mid. Retrieval lexical 0.78, recency 1.00, long-term 1.00 — strongest retrieval in the 5. Context lexical delta +0.00. | **adverse**. Expected 0.00 vs top-1 0.05 (-0.05). Phrase tips to top-1. | **adverse**. Expected 0.00 vs top-1 0.06 (-0.06). Suppression also tips to top-1. Final-score delta only +0.01. |

## Observations

- `music-ambiguous-session` is the only case with a **weak prompt trace** in the textbook sense — the prompt barely names the expected target. The other 4 have mid-to-strong prompt traces.
- `commute-search-facts` and `search-multi-object` are examples where the **retrieval layer is already strong** (recency/long-term at 0.75-1.00, matched terms present), but the **final-score delta is driven by scorer competition** on phrase / context_lexical / suppression against a very similar alternative (`maps-route-compare`).
- `local-dinner-dismiss` is a close prompt-lexical twin: the expected and top-1 both match dinner/cafe tokens. The near-miss is symmetric trace, not weak trace.
- `music-focus-dismiss` and `search-multi-object` are the only 2 where **suppression is adverse to the expected candidate** (expected = 0.00 vs top-1 > 0). These are the 2 cases most likely to regress if `suppression` is re-tuned without care.
- Phrase contribution is **non-helping for the expected candidate in all 5 cases**: 0 expected-wins, 1 tie, 2 adverse, 2 neutral. The phrase channel is not the weak-trace lever for this bucket.

## Class Judgment

**These 5 cases do not form a clean, single weak-trace class.**

- They split across 3 competing-family axes: `maps-*` vs `search-*`, `music-focus` vs `music-deep-work`, dinner/cafe competition.
- The underlying problem is **not** a missing trace channel. It is **scorer competition on already-present signals**, specifically on `context_lexical` (aligned with the dominant head in the live 22-case residual ledger).
- The only case where trace is truly weak (`music-ambiguous-session`) is weak on the prompt side, which is not a bucket a weak-trace scorer bonus would address — it would need either prompt reformulation or a trace-augmentation approach, not another finalScore channel.

## Conclusion

Do **not** open a second scorer bonus aimed at weak-trace.

- 4 of 5 cases are scorer-competition residual that the live 22-case slice already covers; addressing them separately would double-count the intervention.
- The 5th (`music-ambiguous-session`) is a prompt-trace weakness that does not belong in a scorer lever.
- Any further scorer movement on this bucket should route through the decision in `Contracts/live-residual-scorer-slice-report.md` (Group A first, `context_lexical` head), not through a parallel weak-trace hypothesis.

## Explicit Non-goals

- No patch. No new scorer coefficient.
- No change to suppression.
- No reopening of provider or composer layers.
- No action taken on the 8 weak-trace direct-slot wins or the 4 composer-cut weak-trace cases. They stay described in the ledger and are out of scope here.
