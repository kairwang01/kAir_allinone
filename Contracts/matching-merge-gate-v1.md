# Matching Merge Gate v1

- Authoritative ledger: `Contracts/live-residual-ledger.md`
- Live slice report: `Contracts/live-residual-scorer-slice-report.md`
- Status: **binding gate**. This document defines what must be true in replay before a matching-layer PR (provider, scorer, composer, or retrieval) may merge.

## What This Gate Controls

Every PR that touches any of:

- `kAir/Core/Matching/**`
- `kAir/Features/*/Domain/**` matching-adjacent code (intent routers, task adapters)
- `kAir/Core/Models/**`
- `Scripts/run_provider_phase_replay.swift`
- `Contracts/live-residual-ledger.md` or any file it renders from

must pass this gate before merge. PRs that only touch shell, design-system, docs, or unrelated features are out of scope for this gate.

## Gate Inputs

All gate inputs must be regenerated against the PR's HEAD, not cached:

1. Full replay report (`Contracts/provider-phase-replay-report.md`).
2. Live residual ledger (`Contracts/live-residual-ledger.md`).
3. Live scorer slice report (`Contracts/live-residual-scorer-slice-report.md`).
4. Weak-trace trace-strength diagnosis (`Contracts/weak-trace-trace-strength-diagnosis.md`).

If any of these disagree on a case count or root cause, the PR is **blocked on reconciliation** and the ledger is the tiebreaker.

## Blocker Set

The following cases are **merge blockers**. A PR is blocked if any of these regress (drops out of final top-k, or the dominant delta bucket gets worse, or direct-slot is lost where it currently exists):

### Currently direct-slot (must not regress — 6 recovered cases)

- `local-cafe-long-term-drift`
- `search-health-dismiss`
- `tool-health-dismiss`
- `tool-runtime-long-term-drift`
- `tool-store-surface`
- `video-neighborhood-history`

### Currently final top-k + weak-trace direct-slot (must not drop from direct slot — 8 cases)

- `commute-ambiguous-go-now`
- `commute-long-term-drift`
- `commute-route-dismiss`
- `commute-route-history`
- `music-focus-history`
- `search-health-dismiss` (appears in both lists; unified tracking)
- `tool-store-surface` (appears in both lists; unified tracking)
- `tool-vs-search-conflict`

A merge is hard-blocked if any blocker case's `direct slot = yes` becomes `no`, or its rank drops to outside the top-k.

## Known Residual — Allowed To Pass

The following 22 cases are the current live residual near-miss set and are **allowed to remain as-is across a merge**. A PR does not need to recover them to merge, but it also must not make them worse.

### Group A (14 — still-unresolved old near-miss)

`commute-search-facts`, `local-search-conflict`, `music-ambiguous-session`, `music-focus-clean`, `music-long-term-commute-drift`, `music-recent-search-drift`, `search-ambiguous-why`, `search-answer-drift`, `search-low-info`, `search-parking-clean`, `search-recent-tool-drift`, `search-runtime-history`, `video-howto-surface`, `video-vs-answer-conflict`.

### Group B (8 — newly entered live residual)

`local-cafe-maps-surface`, `local-dinner-dismiss`, `music-focus-dismiss`, `music-multi-object`, `search-multi-object`, `tool-ai-runtime-history`, `tool-ambiguous-open-right-thing`, `video-ambiguous-show-me`.

### Weak-trace (17 — allowed as-is)

All 17 live weak-trace cases are allowed to pass. Splitting:
- 8 final top-k + direct slot (blocker subset above)
- 5 final top-k + non-direct (overlap with Group A/B above, tracked via those)
- 4 outside final top-k (`music-commute-surface`, `music-conflict-route-later`, `search-runtime-ai-surface`, `video-howto-dismiss`)

## Blocking Metrics

A PR is hard-blocked if any of these fail:

| Metric | Threshold | Action if breached |
| --- | --- | --- |
| `not aligned = 0.0%` | must stay 0% | Block |
| `candidate miss = 0` | must stay 0 | Block |
| Blocker-set direct-slot count (14) | must stay ≥ 14 | Block |
| Live residual near-miss count | must stay ≤ 22 | Block |
| Live candidate-miss count | must stay 0 | Block |
| Weak-trace count | must stay ≤ 17 | Block |
| Explicit-dismiss rate | must stay ≥ 70% (current 75%) | Block on drop > 5 pp |
| Object-type concentration | must stay ≤ 0.33 (current 0.29) | Block on increase > 0.04 |

## Regressions That Must Be Fixed Before Merge

If any of the following appear in the PR's replay, they must be fixed (or explicitly documented and waived by the reviewer) before merge:

1. Any new case enters `provider miss`. Current: 0.
2. Any new case enters `candidate miss`. Current: 0.
3. Any blocker-set case loses its direct slot.
4. Any Group A or Group B case moves backward (rank worsens by ≥1, or drops out of final top-k).
5. Any weak-trace case moves from `final top-k` to `outside final top-k` for a reason other than explicit composer change.
6. The `Near-miss Cases` and `live residual ledger` counts disagree (report-accounting mismatch) — blocks until ledger is refreshed.

## Out-of-scope For This Gate (Do Not Block On)

- Shell, design-system, or UI home-surface changes (governed by separate shell review).
- Doc-only changes under `Docs/` or `Contracts/*.md` that do not alter numeric counts.
- Replay corpus additions under `Contracts/runtime-replay-artifacts/`.
- New hypothesis files that explicitly declare `status: exploration-only`.

## Hypothesis Status Convention

Every proposed matching change must start life as a hypothesis file under `Contracts/` with one of:

- `status: open` — under design, not yet counterfactual'd.
- `status: counterfactual_pending` — counterfactual plan written, not run.
- `status: counterfactual_weak` — counterfactual ran, did not meet slice recovery bar. Do not ship.
- `status: rejected_by_counterfactual` — counterfactual ran, failed cleanly; do not re-open without new evidence.
- `status: gate_pending` — counterfactual passed, full replay scheduled.
- `status: gate_passed` — ready to land.
- `status: shipped` — merged, marked in ledger.

H1 (`contextLexicalBonus = contextSupport × 0.30`) is currently `status: rejected_by_counterfactual` per `Contracts/group-a-context-lexical-counterfactual.md`.

## Upgrades To This Gate

Any change to the blocker set, the blocking metrics thresholds, or the known-residual list requires:

1. An updated `live-residual-ledger.md`.
2. A merge-gate changelog entry at the bottom of this file, signed and dated.
3. A matching-layer PR separate from the gate change itself.

## Changelog

- `2026-04-20` — v1 gate established. 14 blockers, 22 known residual, 17 weak-trace held. H1 formally rejected.
