//
//  ContinuationProjection.swift
//  kAir
//
//  Pure-function seam that constructs minimum-shape
//  `ChatContinuationEvent` envelopes from a `(SurfaceKind,
//  TerminalOutcome)` pair.
//
//  Why a single projection seam:
//
//    - Reviewer invariant for Main D: continuation-event construction
//      is single-sourced. The bootstrap's `recordSurfaceReturn(...)`
//      is the only production caller; tests reuse the same projection
//      so the event shape matches what production emits.
//    - The minimum shape produced here satisfies the
//      `ContinuationEventValidator` rules (§7 of
//      `continuation-runtime-v1.md`) without any per-surface domain
//      content. Rich per-surface summaries (track name, route ETA,
//      etc.) are explicitly post-v1 work — they don't ship in Main D.
//    - Render-eligibility derivation lives here so the validator's
//      §7.1 invariant (`renderEligible == (outcome ∈ {.completion,
//      .abandon})`) is satisfied by construction, not enforced
//      late.
//
//  Per `Contracts/UX/continuation-runtime-v1.md` §6 + §7:
//    - `.completion` / `.abandon` events MUST have `renderEligible
//      = true`, MUST carry a `SystemSummaryPayload` with 3 metrics,
//      with the continuity metric at index 2 carrying the locked
//      key vocabulary `{"Thread", "线程"}` and an `outcomeTone`
//      matching the outcome.
//    - `.dismiss` / `.acceptNoEntry` events MUST have
//      `renderEligible = false` and MUST NOT carry any
//      sub-payloads.
//
//  Boundary (intentional):
//    - This projection does NOT decide whether to emit or whether to
//      project to the transcript. Those decisions belong to the
//      caller (`AppBootstrap.recordSurfaceReturn(_:)` and
//      `ChatStore.recordContinuation(_:)`).
//    - This projection does NOT introduce evidence or next-step
//      blocks. Surface-specific blocks land via per-surface work in
//      later main lines.
//    - This projection does NOT emit telemetry on its own.
//

import Foundation

/// Pure-function namespace that constructs Main D's minimum-shape
/// continuation events.
enum ContinuationProjection {
    /// Locked continuity key per
    /// `Contracts/UX/post-return-and-continuation-ux-v1.md` §2.2 and
    /// `ContinuationEventValidator.continuityVocabulary`.
    static let continuityKey: String = "Thread"

    /// Build a minimum-shape `ChatContinuationEvent` for the given
    /// surface and outcome.
    ///
    /// The returned envelope satisfies
    /// `ContinuationEventValidator.validate(_:)` with empty
    /// violations under Main D's projection assumptions. Callers
    /// SHOULD still run the validator before emit to guard against
    /// future drift.
    ///
    /// - Parameters:
    ///   - surface: which execution surface is closing.
    ///   - outcome: one of the four terminal outcomes per the post-
    ///     return contract §1.
    ///   - now: clock injection for tests; defaults to `Date()`.
    /// - Returns: a fully-built event ready for validation + emit.
    static func makeEvent(
        surface: SurfaceKind,
        outcome: TerminalOutcome,
        now: Date = Date()
    ) -> ChatContinuationEvent {
        let renderEligible = isRenderEligible(outcome)
        let summary = renderEligible ? makeSummary(surface: surface, outcome: outcome) : nil

        return ChatContinuationEvent(
            id: "continuation-\(surface.rawValue)-\(outcome.rawValue)-\(UUID().uuidString)",
            surface: surface,
            outcome: outcome,
            renderEligible: renderEligible,
            summary: summary,
            evidence: nil,
            nextStep: nil,
            createdAt: now
        )
    }

    /// `true` for outcomes whose envelope carries sub-payloads and
    /// produces a transcript message, per
    /// `continuation-runtime-v1.md` §6.
    static func isRenderEligible(_ outcome: TerminalOutcome) -> Bool {
        switch outcome {
        case .completion, .abandon:
            return true
        case .dismiss, .acceptNoEntry:
            return false
        }
    }

    /// Minimum-shape summary that satisfies the validator (§7.4–§7.8):
    /// three metrics, continuity at index 2 with key `"Thread"`, tone
    /// matching the outcome.
    private static func makeSummary(
        surface: SurfaceKind,
        outcome: TerminalOutcome
    ) -> SystemSummaryPayload {
        let tone: OutcomeTone = (outcome == .completion) ? .completion : .abandon

        let title: String
        let summary: String
        switch outcome {
        case .completion:
            title = "Returned from \(surface.rawValue)"
            summary = "You returned to chat after visiting \(surface.rawValue). The original thread is preserved."
        case .abandon:
            title = "Closed \(surface.rawValue) without a session"
            summary = "You left \(surface.rawValue) without producing a session. The thread is unchanged."
        case .dismiss, .acceptNoEntry:
            // Defensive: this branch is unreachable because
            // `makeSummary` is only called when renderEligible.
            // Fall back to abandon-shaped text so the validator's
            // length rules still pass if a future caller misuses
            // the API.
            title = "Closed \(surface.rawValue)"
            summary = "Surface closed."
        }

        let metrics = [
            Metric(
                key: "Surface",
                value: surface.rawValue,
                keyLocalized: nil,
                valueLocalized: nil
            ),
            Metric(
                key: "Outcome",
                value: outcome.rawValue,
                keyLocalized: nil,
                valueLocalized: nil
            ),
            Metric(
                key: continuityKey,
                value: "Original thread kept",
                keyLocalized: nil,
                valueLocalized: nil
            ),
        ]

        return SystemSummaryPayload(
            eyebrow: nil,
            title: title,
            summary: summary,
            metrics: metrics,
            continuityMetricIndex: 2,
            footer: nil,
            outcomeTone: tone
        )
    }
}
