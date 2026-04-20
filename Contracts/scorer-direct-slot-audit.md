# Scorer Direct-slot Audit (Frozen Slice — Historical)

> **Status:** Historical. Audits the patch against the frozen 20-case pre-patch slice.
> For live post-patch residual accounting, see `Contracts/live-residual-ledger.md`.

- Frozen residual scorer slice source: `Contracts/residual-scorer-slice-report.md`
- Replay source: `Contracts/provider-phase-replay-report.md`
- Patch under test: `promptDirectnessBonus = max(0, promptLexical + phrase - suppression) * 0.30`
- Scope rule: only the frozen scorer residual slice is counted here. The 7 weak-trace hold-outs stay excluded from patch success.

## Near-miss Audit

- Base set: `20`
- Direct-slot recovery: `6 improved / 14 held / 0 regressed`
- Direct Slot Recovery Rate: `30.0%`

Improved labels:
- `local-cafe-long-term-drift`
- `search-health-dismiss`
- `tool-health-dismiss`
- `tool-runtime-long-term-drift`
- `tool-store-surface`
- `video-neighborhood-history`

## Weak-trace Audit

- Base set: `17`
- Hold-out excluded: `7`
- In-scope weak-trace: `10`
- Outcome: `0 improved / 10 held / 0 regressed`

Excluded hold-outs:
- `music-commute-surface`
- `local-dinner-dismiss`
- `music-conflict-route-later`
- `music-multi-object`
- `search-runtime-ai-surface`
- `tool-ai-runtime-history`
- `video-howto-dismiss`
