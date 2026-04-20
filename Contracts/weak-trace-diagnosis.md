# Weak-trace Diagnosis (Bucket Map — Historical)

> **Status:** Historical bucket map. For the trace-strength read on the 5 final-top-k + non-direct cases, see `Contracts/weak-trace-trace-strength-diagnosis.md`. All counts originate from `Contracts/live-residual-ledger.md`.

- Source: `Contracts/provider-phase-replay-report.md`
- Current weak-trace count: `17`
- Scope: diagnosis only, no patch

## Bucket Summary

### Final top-k + direct slot

Count: `8`

Cases:
- `commute-ambiguous-go-now`
- `commute-long-term-drift`
- `commute-route-dismiss`
- `commute-route-history`
- `music-focus-history`
- `search-health-dismiss`
- `tool-store-surface`
- `tool-vs-search-conflict`

Main cause distribution:
- `lexical weighting`: `8`

Read:
- These cases are already direct-slot wins.
- They remain weak-trace because retrieval evidence is still thin or context-heavy, but they are **not** the next scorer problem.

### Final top-k + non-direct

Count: `5`

Cases:
- `commute-search-facts`
- `local-dinner-dismiss`
- `music-ambiguous-session`
- `music-focus-dismiss`
- `search-multi-object`

Main cause distribution:
- `lexical weighting`: `5`

Read:
- This is the only weak-trace bucket that still looks scorer-adjacent.
- Even here, the underlying problem is still weak lexical support rather than a clean, strong candidate being scored down at the end.

### Final top-k outside

Count: `4`

Cases:
- `music-commute-surface`
- `music-conflict-route-later`
- `search-runtime-ai-surface`
- `video-howto-dismiss`

Main cause distribution:
- `query construction`: `1`
- `lexical weighting`: `3`

Read:
- These are not scorer-first failures.
- They still need better trace strength before another scorer hypothesis would be cleanly attributable.

## Diagnosis

The `17` weak-trace cases are no longer one problem:

- `8 / 17` are already direct-slot and should stay out of the next scorer experiment
- `4 / 17` are still outside final top-k and remain retrieval-side trace problems
- only `5 / 17` are final top-k non-direct

## Recommendation

Do **not** open a new weak-trace-only scorer hypothesis yet.

Reason:
- most weak-trace cases are either already direct-slot (`8`) or still outside final top-k (`4`)
- the remaining `5` non-direct weak-trace cases are still dominated by weak lexical support, not a clean last-hop ranking miss

So the next weak-trace step should stay diagnostic and trace-strength oriented, not another scorer bonus.
