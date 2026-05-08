//
//  FeedbackRuntime.swift
//  kAir
//
//  Runtime protocol + no-op stub for the negative-feedback envelope.
//
//  Mirrors `Contracts/UX/feedback-runtime-v1.md` §5 (UI / runtime
//  boundary):
//
//    - The runtime accepts the typed `FeedbackEvent` from the call
//      site (today, `ChatStore.dismissRecommendation(_:feedback:)`).
//    - The runtime writes NOTHING to the chat transcript
//      (zero `ConversationMessage`, zero system rows, zero
//      `ConversationToolResult`).
//    - The runtime does NOT call `refreshRecommendedMatches` for
//      `.alreadyDone` — the elevation hands off to the post-return
//      continuation path, which owns refresh.
//    - The UI MUST NOT construct `FeedbackEvent` envelopes itself; the
//      runtime is the sole emitter.
//
//  Skeleton scope (I0): protocol + a no-op stub suitable for previews
//  and the test scaffold. Validation lives in
//  `FeedbackEventValidator` (a pure function, kept separate from the
//  protocol so consumers can validate before emit). Wiring into
//  `ChatStore.dismissRecommendation(_:feedback:)` is I4's territory.
//

import Foundation

// MARK: - Protocol

/// Runtime entry point for emitting a `FeedbackEvent`.
///
/// One method, one event, one tap — the contract forbids batching,
/// debouncing, or coalescing (§6.1).
///
/// Implementations MUST:
///   - validate per §8 before propagation (or rely on a separate
///     validator chokepoint),
///   - NOT write any record to `session.messages` or any transcript
///     collection (§7.1),
///   - propagate carried chain identifiers (`traceId`, `threadId`,
///     `sourceRequestId`, `feedbackChainId`) when present on the
///     originating context (§5.2 step 4, §9.4).
protocol FeedbackRuntime {
    /// Emit one `FeedbackEvent` to whichever sinks the implementation
    /// owns (scorer, telemetry, suppression log).
    ///
    /// - Parameter event: a fully-formed envelope per `FeedbackEvent`.
    /// - Throws: `FeedbackRuntimeError.invalidEvent` if the event fails
    ///   validation (or any implementation-specific transport error).
    ///   The stub `NoOpFeedbackRuntime` never throws; the protocol
    ///   permits it so I4's real implementation can surface failures.
    func emit(_ event: FeedbackEvent) async throws
}

// MARK: - Errors

/// Errors the feedback runtime can throw.
///
/// `Hashable` conformance keeps these usable in test fixtures and
/// expectation sets without bespoke equality plumbing.
enum FeedbackRuntimeError: Error, Hashable {
    /// The event failed validation per `FeedbackEventValidator`. The
    /// runtime refused to emit; per §6.3 step 2, the card is NOT
    /// removed in this pathological case.
    case invalidEvent
}

// MARK: - No-op stub

/// A `FeedbackRuntime` that does nothing on `emit(_:)`.
///
/// Suitable for SwiftUI previews and the test scaffold. The real I4
/// implementation will:
///   - validate via `FeedbackEventValidator.validate(_:)`,
///   - record to scorer / telemetry sinks per §6.3 step 3,
///   - hand off to the post-return path for `.alreadyDone` per §4.1.
///
/// This stub is INTENTIONALLY behavior-free so it can stand in
/// wherever the protocol is required without adding any side effect.
final class NoOpFeedbackRuntime: FeedbackRuntime {
    init() {}

    /// No-op. Never throws.
    func emit(_ event: FeedbackEvent) async throws {
        // Intentionally empty. See type doc.
        _ = event
    }
}
