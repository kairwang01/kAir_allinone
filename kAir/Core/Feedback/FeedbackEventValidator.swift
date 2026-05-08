//
//  FeedbackEventValidator.swift
//  kAir
//
//  Pure-function validator for `FeedbackEvent`.
//
//  Mirrors `Contracts/UX/feedback-runtime-v1.md` §8 (validation rules).
//  The validator is the chokepoint the runtime uses before propagation
//  per §6.3 step 2.
//
//  Skeleton scope (I0): the static-checkable rules. Specifically:
//    - §8.1 `recommendationId.isEmpty`
//    - §8.3 `createdAt` more than 5s in the future (skew tolerance)
//    - §8.4 `id.isEmpty`
//
//  The remaining §8 rules are intentionally NOT implemented here:
//
//    - §8.2 (`feedbackKind` in vocabulary) is type-system-enforced via
//      the `MatchingFeedbackKind` enum — there is no way to construct
//      a `FeedbackEvent` whose `feedbackKind` falls outside the 5
//      frozen cases in Swift. The validator therefore does not need a
//      runtime check.
//
//    - §8.4 second clause (`id` collides with a previously-emitted
//      event in the same session) requires session state and is the
//      runtime's responsibility, not a pure-function pre-check. I4
//      will add the per-session uniqueness check at the runtime layer.
//
//    - §8.5 (`recommendationId` corresponds to a recommendation present
//      in `recommendedMatches` at the moment of emission) is OUT OF
//      SCOPE for this pure-function validator: it requires access to
//      `ChatStore` state and is by definition a runtime check. I4
//      will add it at the runtime layer.
//
//    - §8.6 (`surface` is non-nil and a member of the §3.2 vocabulary)
//      is type-system-enforced via the `SurfaceKind` enum (8 frozen
//      cases). No runtime check needed.
//
//    - §8.7 (the envelope is constructed by the runtime layer, not the
//      UI) is a code-review invariant, not a runtime-checkable rule.
//
//  This file is pure: no side effects, no I/O, no global state, no
//  notion of "current session". `validate(_:)` is a pure function
//  from `FeedbackEvent` to a list of violations, suitable for use
//  directly inside the runtime's emit path or independently in tests.
//

import Foundation

// MARK: - Violation vocabulary

/// One of the §8 invariant violations the validator can report.
///
/// `Hashable, Equatable` so violation sets can be compared in tests
/// directly with `XCTAssertEqual`.
enum FeedbackEventViolation: Hashable, Equatable {
    /// §8.1 — `recommendationId.isEmpty` is `true`.
    case recommendationIdEmpty

    /// §8.4 — `id.isEmpty` is `true`. (The session-uniqueness clause
    /// of §8.4 is not modeled here; see file header.)
    case idEmpty

    /// §8.3 — `createdAt` is more than `skewToleranceSeconds`
    /// (= 5s, recommended) past the wall clock at validation time.
    case createdAtInFuture
}

// MARK: - Validator

/// Pure-function validator for `FeedbackEvent`.
///
/// Use:
///
/// ```swift
/// let violations = FeedbackEventValidator.validate(event)
/// guard violations.isEmpty else {
///     throw FeedbackRuntimeError.invalidEvent
/// }
/// ```
///
/// Mirrors `Contracts/UX/feedback-runtime-v1.md` §8.
enum FeedbackEventValidator {
    /// The §8.3 skew tolerance. Per the contract, "recommended ≤ 5
    /// seconds". A `createdAt` later than `now + skewToleranceSeconds`
    /// is rejected.
    static let skewToleranceSeconds: TimeInterval = 5

    /// Run all pure-function checks against `event`. Returns the
    /// (possibly empty) list of violations.
    ///
    /// - Parameter event: the envelope to check.
    /// - Returns: violations in declaration order
    ///   (`.recommendationIdEmpty`, `.idEmpty`, `.createdAtInFuture`).
    ///   An empty array means the event passes every pure-function
    ///   §8 rule. The runtime is responsible for the §8.5 cross-state
    ///   check before propagation.
    static func validate(_ event: FeedbackEvent) -> [FeedbackEventViolation] {
        validate(event, now: Date())
    }

    /// Variant accepting an explicit `now` for deterministic testing.
    ///
    /// `validate(_:)` calls this with `Date()`.
    static func validate(
        _ event: FeedbackEvent,
        now: Date
    ) -> [FeedbackEventViolation] {
        var violations: [FeedbackEventViolation] = []

        // §8.1 — recommendationId must be non-empty.
        if event.recommendationId.isEmpty {
            violations.append(.recommendationIdEmpty)
        }

        // §8.4 — id must be non-empty. (Session-uniqueness handled
        // at the runtime layer, not here; see file header.)
        if event.id.isEmpty {
            violations.append(.idEmpty)
        }

        // §8.3 — createdAt must NOT be in the future beyond the
        // skew tolerance. Recommendation: ≤ 5s.
        let cutoff = now.addingTimeInterval(skewToleranceSeconds)
        if event.createdAt > cutoff {
            violations.append(.createdAtInFuture)
        }

        return violations
    }
}
