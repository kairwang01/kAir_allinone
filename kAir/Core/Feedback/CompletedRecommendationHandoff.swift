//
//  CompletedRecommendationHandoff.swift
//  kAir
//
//  Hand-off surface for recommendations the user marked
//  `MatchingFeedbackKind.alreadyDone`.
//
//  Per `Contracts/UX/feedback-runtime-v1.md` §4.1, `.alreadyDone`
//  shares the affordance surface with the four negatives but
//  semantically EXITS the negative-feedback flow and ENTERS the
//  completion / post-return flow:
//
//    - The `FeedbackEvent` envelope is still emitted via
//      `FeedbackRuntime` (it's the universal record; `.alreadyDone`
//      is the in-band elevation signal).
//    - `refreshRecommendedMatches()` is NOT called on this path —
//      refresh is owned by post-return.
//    - The recommendation MUST be recorded as completed (NOT
//      suppressed) so the (future) post-return continuation runtime
//      can consume the elevation per
//      `post-return-and-continuation-ux-v1.md` §1.1 row C.
//
//  In Main A (#28) the recording was a stopgap local log on
//  `ChatStore.completedRecommendations`. Main A.2 replaces that
//  stopgap with this explicit handoff surface so the responsibility
//  lives in a separate, swappable component instead of a public
//  property on `ChatStore`.
//
//  Boundary (intentional):
//    - This protocol does NOT know about the chat transcript. It
//      MUST NOT cause a `ConversationMessage` append. Transcript
//      receipt is forbidden by behavior §3.4 + V3 §6.3 + feedback-
//      runtime §7.1.
//    - This protocol does NOT know about telemetry. The chain ids
//      and span names belong to telemetry-contract-v1, not here.
//    - This protocol is NOT a suppression sink. `.alreadyDone` MUST
//      NOT trigger suppression (feedback-runtime §4.1 last bullet);
//      the four negatives have their own path for that.
//

import Foundation

/// Receives recommendations the user marked `.alreadyDone`.
///
/// Concrete implementations record the completion intent for
/// downstream consumers (e.g. the future post-return continuation
/// runtime). `ChatStore` calls `record(_:)` exactly once per
/// `.alreadyDone` dismissal, after the `FeedbackEvent` envelope has
/// been emitted via `FeedbackRuntime` and after the card has been
/// removed from `recommendedMatches`.
///
/// Implementations MUST:
///   - Record the recommendation as a completion intent (NOT a
///     suppression).
///   - Not write any record to `session.messages` or any transcript
///     collection.
///   - Not emit telemetry events on their own; chain identifiers
///     and span naming are owned by `telemetry-contract-v1`.
protocol CompletedRecommendationHandoff {
    /// Records the recommendation as elevated to `.completion` per
    /// post-return §1.1 row C.
    ///
    /// - Parameter recommendation: the `MatchingObject` the user
    ///   marked `.alreadyDone`.
    func record(_ recommendation: MatchingObject)
}

/// A `CompletedRecommendationHandoff` that does nothing on `record(_:)`.
///
/// Suitable for SwiftUI previews and the test scaffold. The real
/// implementation will:
///   - Forward to the post-return continuation runtime when wired
///     (separate work line per `post-return-and-continuation-ux-v1.md`).
///   - Or persist the intent to a session-scoped completion log if
///     the post-return runtime is not yet active.
///
/// This stub is INTENTIONALLY behavior-free so it can stand in
/// wherever the protocol is required without adding any side effect.
final class NoOpCompletedRecommendationHandoff: CompletedRecommendationHandoff {
    init() {}

    /// No-op. See type doc.
    func record(_ recommendation: MatchingObject) {
        _ = recommendation
    }
}
