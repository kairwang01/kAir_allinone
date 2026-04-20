//
//  ContinuationClassifier.swift
//  kAir
//
//  outcome + context → ContinuationState
//  Normative spec: Contracts/UX/continuation-runtime-v1.md §10, §7.1
//
//  The classifier is intentionally deterministic and conservative. v1
//  §10 says `completion` MUST NOT default to `newTask` and abandon
//  SHOULD prefer `sameTask`; the mapping below enforces those rules
//  without any per-vertical branching.
//

import Foundation

public struct ContinuationClassifier: Sendable {
    public init() {}

    public func classify(
        event: ExecutionReturnEvent,
        context: ContinuationContext
    ) -> ContinuationState {
        switch event.outcome {
        case .completion:
            // §7.1.A + §10 — sameTask by default; escalate to
            // adjacentTask when the payload advertises a different
            // taskFamily than whatever drove the current thread.
            if hasTaskFamilyShift(event: event, context: context) {
                return .adjacentTask
            }
            return .sameTask

        case .abandon:
            // §7.1.B + §10.1 — prefer sameTask; we only leave this
            // family when the payload explicitly indicates drift.
            if payloadIndicatesIntentDrift(event: event) {
                return .adjacentTask
            }
            return .sameTask

        case .dismiss:
            // §7.1.C — adjacentTask unless thread context shows a full
            // task switch. v1 is conservative: only upgrade to newTask
            // when the thread has explicitly cleared the accepted
            // recommendation AND no current recs remain.
            if context.acceptedRecommendationId == nil
                && context.currentRecommendationIds.isEmpty {
                return .newTask
            }
            return .adjacentTask

        case .acceptNoEntry:
            // §7.1.D — never classify as completion; default sameTask
            // so the rail stays in place for a retry.
            return .sameTask
        }
    }

    // MARK: - Helpers

    /// True when the return payload's taskFamily differs from the
    /// family implied by current recommendations / latest object
    /// types. Conservative: absence of signal → no shift.
    private func hasTaskFamilyShift(
        event: ExecutionReturnEvent,
        context: ContinuationContext
    ) -> Bool {
        guard let payloadFamily = event.payload?.taskFamily,
              !payloadFamily.isEmpty else {
            return false
        }
        // If the payload declares an objectType the current thread has
        // not seen, treat as adjacent.
        if let payloadObjectType = event.payload?.objectType,
           !context.latestObjectTypes.isEmpty,
           !context.latestObjectTypes.contains(payloadObjectType) {
            return true
        }
        return false
    }

    /// True when the payload suggests the abandon was actually a
    /// pivot (different objectType from anything the thread has
    /// engaged with). Conservative: any ambiguity → false.
    private func payloadIndicatesIntentDrift(
        event: ExecutionReturnEvent
    ) -> Bool {
        guard let hint = event.payload?.downstreamValueHint,
              !hint.isEmpty else {
            return false
        }
        // v1 uses structural markers only. String-matching heuristics
        // live behind this helper so they can evolve without touching
        // the classifier's outer shape.
        return hint.lowercased().contains("switch")
            || hint.lowercased().contains("new task")
    }
}
