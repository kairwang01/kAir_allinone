# 2026 Open-Source Methods — kAir Mapping

Status: research note (informational — NOT a contract, NOT a roadmap, NOT a dependency list).
Created: 2026-05-14.

This note is the **single** durable artifact of the 2026 open-source
research round. Per the governing directive, that research must NOT
fan out into multiple parallel adoption lines — it is consolidated
here, into one mapping table, and nothing more.

## Phase 1 priority is unchanged

**This research does NOT change the Phase 1 priority.** The active
main line is unchanged: finish the `Contracts/Design/design-system-v1.md`
§8.1 ratification blockers (box 6 — `tint(for:)` / `statusTint(for:)`
signature ruling; box 7 — §4.4 seven-state coverage), then the
design-system recheck — and only then return to the SwiftData /
capability-registry / AI-runtime architecture decisions.

Nothing in the table below is **adopted**, **scheduled**, or
**promoted to a project dependency**. Each row is a **candidate
pattern** — something to learn an architectural method from at the
right time, behind an explicit gate. None of these external
frameworks (Spezi, Foundation Models, Spec-Kit, FluentUI, MLX /
ExecuTorch / Core ML) is on the kAir dependency graph and none is
proposed for it here.

## Mapping table

| Topic (candidate pattern + method) | kAir subsystem it maps to | Decision timing |
|---|---|---|
| **Stanford Spezi** — modular health-app framework: a typed `Standard` data contract every module talks through; `@Application` / `@Dependency` module DI; a Data Source vs Data Storage Provider split. | SwiftData / Friends / Data Storage Provider ADR (currently deferred) — relates to `AppBootstrap`, `CapabilityRegistry`, `HealthDashboardStore`. | **LATER** — after design-system ratification. *This is the next research-to-plan line* (deep-dive → ADR adoption proposal). Architecture pattern only; no Spezi dependency. |
| **Apple Foundation Models** — on-device ~3B LLM; `@Generable` / `@Guide` guided generation (type-safe structured output); tool calling. | `CapabilityKind.aiCompletion` / `StubAICompletionAdapter` — the stub awaiting a real AI runtime. | **LATER** — after capability-registry UI gating. Candidate runtime for the AI capability; not adopted. |
| **GitHub Spec-Kit** — spec-driven dev toolkit: Specify → Plan → Tasks → Implement phases; spec-validation hooks that score/trace docs. | Contract validation tooling — the `Contracts/` directory + the ratification-checklist / status-sweep workflow kAir runs by hand. | **LATER** — after the current contract sweep stabilizes. Candidate tooling to automate contract↔implementation alignment; NOT wired into CI. |
| **FluentUI Apple tokens** — Global → Alias → Control three-layer token architecture with unidirectional dependency and theme-scoped aliases. | design-system **v2** direction — relates to `AppTheme.Palette` (globals), the now-retired `HealthPalette` aliases, the per-component `static let` wiring pins. | **LATER** — after design-system-v1 is ratified. Candidate v2 structure; does NOT modify v1. |
| **Core ML / ExecuTorch / MLX** — on-device inference engines; ANE routing; benchmarked INT8/FP16 speedups; tiny runtime footprints. | Local prediction bundle — `Contracts/AIProviders/LocalModelProviderContract.md` (the on-device disease-prediction model bundle). | **LATER** — after `LocalModelProviderContract` is canonicalized. Candidate runtimes; no engine adopted. |

**now / later / never legend.** Every row above is **LATER** — gated
on an explicit milestone. **No row is NOW** (none is in scope for the
current Phase 1 main line). **No row is NEVER** (all five stay worth
revisiting once their gate is reached).

## Next research-to-plan line (single)

Per the directive, the only research line that may advance to a plan
next is **Spezi** — because it directly serves the already-deferred
SwiftData / Friends ADR. Foundation Models, Spec-Kit, the inference
engines, and FluentUI tokens are explicitly **not** to be advanced
until their own gates are reached.

When the Spezi deep-dive runs, its sole output is a **SwiftData /
Friends ADR adoption proposal** that answers exactly three questions —
what kAir's `Standard` (the shared data contract) should be; how Data
Source and Data Storage Provider should layer; and why Friends stays
dormant — borrowing the **architecture pattern only**, with no Spezi
dependency and no engineering migration.

## Recency basis

All five candidates were verified 2024–2026 during the research round:
Stanford Spezi (Spezi HealthKit module updated 2026-04; *My Heart
Counts* rebuilt on it, 2026-05), Apple Foundation Models (iOS 26,
announced 2025-09), GitHub Spec-Kit (open-sourced ~2026-05, 90k+
stars), FluentUI Apple design tokens (current), ExecuTorch 1.0 (GA
2025-10) / MLX Swift (WWDC25) / Core ML 2026 ANE routing. Full search
findings live in the conversation record of the 2026-05-14 research
round; this note is the distillation.
