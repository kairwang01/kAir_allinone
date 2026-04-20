# Post-patch Residual Reconciliation

- **Authoritative ledger (source of truth for all residual counts):** `Contracts/live-residual-ledger.md`
- Frozen scorer residual slice (historical, pre-patch): `Contracts/residual-scorer-slice-report.md`
- Post-patch full replay (raw): `Contracts/provider-phase-replay-report.md`
- Frozen scorer audit (historical): `Contracts/scorer-direct-slot-audit.md`
- Live scorer slice (current decision basis): `Contracts/live-residual-scorer-slice-report.md`
- Weak-trace trace-strength diagnosis: `Contracts/weak-trace-trace-strength-diagnosis.md`

Every near-miss, candidate-miss, and weak-trace number cited below is rendered from the authoritative ledger. Historical files are kept for traceability; they are not decision inputs.

## Reconciliation Summary

- Frozen pre-patch scorer slice near-miss base: `20`
- Recovered old near-miss after `promptDirectnessBonus`: `6`
- Still unresolved old near-miss: `14`
- Newly entered live residual near-miss after full replay: `8`
- Reconciled live residual near-miss total: `14 + 8 = 22`

This is why the frozen `20`-case scorer slice and the post-patch full replay now point at `22` residual near-miss exposures.

## 1. Recovered Old Near-miss

These were in the frozen `20`-case scorer slice and moved to direct-slot recovery after the scorer patch:

- `local-cafe-long-term-drift`
- `search-health-dismiss`
- `tool-health-dismiss`
- `tool-runtime-long-term-drift`
- `tool-store-surface`
- `video-neighborhood-history`

Count: `6`

## 2. Still Unresolved Old Near-miss

These were in the frozen `20`-case scorer slice and are still non-direct after the patch:

- `commute-search-facts`
- `local-search-conflict`
- `music-ambiguous-session`
- `music-focus-clean`
- `music-long-term-commute-drift`
- `music-recent-search-drift`
- `search-ambiguous-why`
- `search-answer-drift`
- `search-low-info`
- `search-parking-clean`
- `search-recent-tool-drift`
- `search-runtime-history`
- `video-howto-surface`
- `video-vs-answer-conflict`

Count: `14`

## 3. Newly Entered Live Residual Near-miss

These were **not** in the frozen `20`-case scorer slice, but they appear as post-patch live residual near-miss in the full replay ledger:

| Case | Root cause |
| --- | --- |
| `local-cafe-maps-surface` | `scorer` |
| `local-dinner-dismiss` | `scorer` |
| `music-focus-dismiss` | `scorer` |
| `music-multi-object` | `scorer` |
| `search-multi-object` | `scorer` |
| `tool-ai-runtime-history` | `scorer` |
| `tool-ambiguous-open-right-thing` | `scorer` |
| `video-ambiguous-show-me` | `scorer` |

Count: `8`

## Why The Markdown Looks Inconsistent

The current post-patch replay markdown contains two different ledgers:

- the **fixed scorer residual slice** used by the direct-slot audit
- the **live full-replay exposure ledger** used by the post-patch near-miss summary

That is why these numbers can coexist:

- frozen scorer audit still talks about the original `20`-case slice
- full replay residual accounting reconciles to `22`

Inside the current replay markdown, the `## Near-miss Cases` section renders `20` detailed case blocks, while the full residual accounting still reconciles to `22`. The missing two are:

- `video-howto-surface`
- `video-vs-answer-conflict`

Those two still survive as unresolved items in the frozen direct-slot ledger, but they are no longer emitted as standalone live near-miss blocks in the rendered full replay section. This is a **report-accounting mismatch**, not a new provider regression.

## Actionable Read

- The scorer patch remains valid and stays frozen.
- The current residual story is:
  - `6` old scorer near-miss were truly recovered
  - `14` old scorer near-miss are still unresolved
  - `8` new scorer-shaped near-miss entered the live ledger
- The next diagnosis should use the reconciled `22`-case live residual set, not the older fixed `20`-case slice alone.
