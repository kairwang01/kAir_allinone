# Group A Context-lexical Counterfactual

- Authoritative ledger: `Contracts/live-residual-ledger.md`
- Live slice report: `Contracts/live-residual-scorer-slice-report.md`
- Upstream replay (raw bucket values): `Contracts/provider-phase-replay-report.md`
- Scoring code under study: `kAir/Core/Matching/MatchingPipeline.swift:305–321`
- Scope: the 14 Group A cases from the live ledger (still-unresolved old near-miss). Group B and weak-trace are **explicitly excluded**.
- Policy state at counterfactual time: `retrievalLiftWeight = 0.24`, `promptDirectnessWeight = 0.30` (the landed patch), `diversityPenalty = 0`.

## Hypothesis (P1)

**H1 — Context-lexical amplifier.**

```
contextLexicalBonus = contextSupport * contextLexicalWeight
```

Applied to `finalScore` in `MatchingPipeline.swift:312–321`, as an additive term mirroring the shape of `promptDirectnessBonus`:

```swift
let finalScore = max(
    0,
    globalEligibility * 0.34 +
        domainUtility * 0.28 +
        nextStepValue * 0.28 +
        explorationBoost * 0.1 +
        retrievalLift +
        promptDirectnessBonus +
        contextLexicalBonus -       // NEW, single term
        diversityPenalty
)
```

- **Affected term:** `context_lexical`, defined exactly as the replay's 4-bucket breakdown: the retrieval-side `contextSupport` value produced in `RetrievalCandidateProvider.swift:142`.
- **Where it applies:** `finalScore` stage only. No change to retrieval. No change to `promptDirectnessBonus`. No change to any other term.
- **Coefficient under test:** `contextLexicalWeight = 0.30` (mirrors the landed `promptDirectnessWeight` so the shape is comparable, not a tuning sweep).
- **Why this one:** Group A's per-case dominant delta bucket is labeled `context_lexical` in 7 / 14 cases (50%) and the slice report identified `context_lexical` as the Group A head. The cleanest single-term analogue of the landed `promptDirectnessBonus` on that head is a direct `contextSupport`-scaled additive bonus.

No coefficient sweep. No multi-rule bundle. No second-order change. One term.

## Counterfactual

The counterfactual evaluates the incremental change on Group A directly from the replay's per-case bucket values. Because the bonus is a pure additive on `finalScore` and is monotone in `contextSupport`, the gap shift for each case is:

```
Δnew_gap = Δold_gap + contextLexicalWeight × (contextSupport_top1 − contextSupport_expected)
```

A direct-slot flip requires `new_gap ≤ 0`.

### Per-case result (contextLexicalWeight = 0.30)

| # | Case | ctx expected | ctx top-1 | ctx Δ (top1−exp) | bonus Δ to gap | old final gap | new final gap | direct slot before | direct slot after | rank before | rank after | outcome |
| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- | ---: | ---: | --- |
| 1 | `commute-search-facts` | 0.06 | 0.09 | +0.03 | +0.009 | +0.13 | +0.139 | no | no | 2 | 2 | regressed |
| 2 | `local-search-conflict` | 0.03 | 0.03 | 0.00 | 0.000 | +0.04 | +0.04 | no | no | 2 | 2 | held |
| 3 | `music-ambiguous-session` | 0.07 | 0.07 | 0.00 | 0.000 | +0.25 | +0.25 | no | no | 3 | 3 | held |
| 4 | `music-focus-clean` | 0.01 | 0.01 | 0.00 | 0.000 | +0.11 | +0.11 | no | no | 2 | 2 | held |
| 5 | `music-long-term-commute-drift` | 0.01 | 0.01 | 0.00 | 0.000 | +0.14 | +0.14 | no | no | 2 | 2 | held |
| 6 | `music-recent-search-drift` | 0.01 | 0.01 | 0.00 | 0.000 | +0.10 | +0.10 | no | no | 2 | 2 | held |
| 7 | `search-ambiguous-why` | 0.07 | 0.06 | −0.01 | −0.003 | +0.14 | +0.137 | no | no | 5 | 5 | held (−0.003) |
| 8 | `search-answer-drift` | 0.01 | 0.01 | 0.00 | 0.000 | +0.14 | +0.14 | no | no | 5 | 5 | held |
| 9 | `search-low-info` | 0.01 | 0.01 | 0.00 | 0.000 | +0.09 | +0.09 | no | no | 4 | 4 | held |
| 10 | `search-parking-clean` | 0.01 | 0.01 | 0.00 | 0.000 | +0.04 | +0.04 | no | no | 2 | 2 | held |
| 11 | `search-recent-tool-drift` | 0.06 | 0.06 | 0.00 | 0.000 | +0.04 | +0.04 | no | no | 3 | 3 | held |
| 12 | `search-runtime-history` | 0.06 | 0.06 | 0.00 | 0.000 | +0.01 | +0.01 | no | no | 3 | 3 | held |
| 13 | `video-howto-surface` | 0.06 | 0.06 | 0.00 | 0.000 | +0.09 | +0.09 | no | no | 2 | 2 | held |
| 14 | `video-vs-answer-conflict` | 0.01 | 0.01 | 0.00 | 0.000 | +0.13 | +0.13 | no | no | 2 | 2 | held |

### Per-case dominant bucket before / after

The hypothesis only shifts the `context_lexical` contribution uniformly for every scored candidate. It does not change the dominant-delta bucket label for any case in the slice because the relative bucket ordering within each case is preserved.

| Case | Dominant bucket before | Dominant bucket after |
| --- | --- | --- |
| `commute-search-facts` | `prompt_lexical` | `prompt_lexical` |
| `local-search-conflict` | `context_lexical` | `context_lexical` |
| `music-ambiguous-session` | `prompt_lexical` | `prompt_lexical` |
| `music-focus-clean` | `context_lexical` | `context_lexical` |
| `music-long-term-commute-drift` | `phrase` | `phrase` |
| `music-recent-search-drift` | `context_lexical` | `context_lexical` |
| `search-ambiguous-why` | `phrase` | `phrase` |
| `search-answer-drift` | `phrase` | `phrase` |
| `search-low-info` | `prompt_lexical` | `prompt_lexical` |
| `search-parking-clean` | `context_lexical` | `context_lexical` |
| `search-recent-tool-drift` | `context_lexical` | `context_lexical` |
| `search-runtime-history` | `context_lexical` | `context_lexical` |
| `video-howto-surface` | `context_lexical` | `context_lexical` |
| `video-vs-answer-conflict` | `phrase` | `phrase` |

### Roll-up

| Metric | Value |
| --- | ---: |
| Cases in scope (Group A) | 14 |
| Improved (gap narrowed) | 1 (by −0.003) |
| Held (no material change) | 12 |
| Regressed (gap widened) | 1 (by +0.009) |
| Recovered to direct slot | 0 |
| Top-k status changes | 0 |

### Coefficient sensitivity

Because the bonus is linear in `contextLexicalWeight` and the `contextSupport` delta for each Group A case is in `{0.00, ±0.01, +0.03}`, no value of `contextLexicalWeight ∈ [0.10, 0.60]` produces a direct-slot flip. At every value in that range the `commute-search-facts` gap widens, and no other case moves enough to cross its existing final-score gap. The binding constraint is structural, not a coefficient choice.

## Why The Slice Is Weak

The live-slice report labels `context_lexical` the Group A dominant head because it is the per-case argmax of the 4-bucket delta `(top1 − expected)`. For 12 of the 14 Group A cases the `context_lexical` delta is literally `0.00`: the expected and top-1 candidates have effectively the same `contextSupport` value. `context_lexical` is only the "dominant bucket" label because every other bucket is also near-zero, not because the expected candidate has a real margin there.

A `contextSupport × k` amplifier moves both candidates by the same amount whenever their `contextSupport` values are equal, so it cannot flip the gap. In the one case with a non-trivial ctx delta (`commute-search-facts`, +0.03 in favor of top-1), the amplifier actively hurts the expected candidate.

This is a label-attribution finding that bears on the P1 decision boundary: the "Group A dominant head = context_lexical" claim is arithmetically correct but does not imply that expected-side context_lexical margin exists to amplify. No scorer term acting purely on the `context_lexical` bucket — at any coefficient — will recover Group A direct slots.

## Decision

**Stop. Do not run the full replay gate. Do not ship any code patch.**

Acceptance criterion (P2) requires the Group A slice to show "clear recovery, not just small rank movement." This slice produced 0 direct-slot recoveries, 0 rank changes, 1 trivial narrow (−0.003), and 1 small regression (+0.009). That is weak and messy, not clean recovery. Per the stop rule, the counterfactual ends here.

## Guardrail Snapshot (Not Run)

No full replay was executed. The landed baseline guardrails (`not aligned = 0.0%`, `candidate miss = 0`, explicit dismiss and object-type concentration at post-patch levels) remain the authoritative state. No change is made to them by this exercise.

## Observations (Not Recommendations)

1. **Retrieval-side margin exists for Group A, but it is not isolated in `context_lexical`.** Eight of the 14 Group A expected candidates already out-retrieve their top-1 competitor on the aggregate retrieval score (e.g., `search-runtime-history` -0.36, `video-howto-surface` -0.21, `search-ambiguous-why` -0.19, `music-recent-search-drift` -0.11). The margin is spread across `prompt_lexical`, `phrase`, and `context_lexical` jointly. Any future hypothesis that targets Group A will likely need to touch the retrieval-to-finalScore pathway as a whole, not one retrieval bucket in isolation. This is a flag for a future P1, not a proposal now.
2. **The live-slice "Group A dominant head" read deserves a caveat.** Future slice reports should distinguish bucket-argmax labels computed over near-zero deltas from buckets where expected actually has margin. This would prevent a future single-term hypothesis from being designed against a phantom head.
3. **No action is taken on either observation in this file.** They are flagged for later framing only.

## Explicit Non-goals Honored

- Group B was not touched.
- Weak-trace was not touched.
- Provider, retrieval, and composer layers were not reopened.
- No new reporting layer was added for either Group B or weak-trace.
- No code patch was written.
- No coefficient sweep was run.
