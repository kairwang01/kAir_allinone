//
//  FeedbackEvent.swift
//  kAir
//
//  Data envelope emitted by the negative-feedback runtime on every
//  user dismiss / menu-item tap.
//
//  Mirrors `Contracts/UX/feedback-runtime-v1.md` §3 (the field table)
//  and §3.3 (envelope invariants) verbatim:
//
//    - exactly one `FeedbackEvent` per user tap (no batching, no
//      coalescing);
//    - `recommendationId` MUST be non-empty;
//    - `feedbackKind` is constrained to the 5 frozen
//      `MatchingFeedbackKind` cases by the Swift type system;
//    - `createdAt` is UTC and MUST NOT be in the future;
//    - the envelope is immutable once emitted (all `let` fields).
//
//  Skeleton scope (I0): pure data types only. No runtime emission yet,
//  no integration with `ChatStore.dismissRecommendation(_:feedback:)`.
//  That is I4's territory.
//
//  Boundary note: the chain-identifier fields (`traceId`, `threadId`,
//  `sourceRequestId`, `feedbackChainId`) are declared `String?` here so
//  the runtime CAN propagate them when present (per contract §3, §5.2),
//  but this skeleton does NOT integrate them with telemetry or any
//  request lifecycle — that's Agent E's territory.
//

import Foundation

/// The negative-feedback envelope. One per user tap on the `✕` button
/// or any item in the `⋯` menu.
///
/// Mirrors `Contracts/UX/feedback-runtime-v1.md` §3.
struct FeedbackEvent: Hashable, Identifiable {
    /// Stable event identifier. Unique opaque identifier; format
    /// implementation-defined.
    ///
    /// Consumers MUST NOT parse this string. Unique within a session;
    /// consumers MAY use it for deduplication.
    /// (Contract §3 row 1.)
    let id: String

    /// The `MatchingObject.id` of the card the user dismissed.
    ///
    /// Implementation-defined opaque string owned by the matching /
    /// recommendation subsystem. Consumers MUST NOT parse it. MUST be
    /// non-empty (enforced by `FeedbackEventValidator` per §8.1).
    /// (Contract §3 row 2.)
    let recommendationId: String

    /// One of the 5 frozen `MatchingFeedbackKind` cases:
    /// `.dismiss`, `.notInterested`, `.lessLikeThis`, `.notNow`, `.alreadyDone`.
    ///
    /// Vocabulary type-system-enforced; adding a sixth case requires a
    /// v2 of the behavior contract, the V3 visual contract, AND this
    /// runtime contract in lockstep.
    /// (Contract §3 row 3, §3.1.)
    let feedbackKind: MatchingFeedbackKind

    /// Which vertical originated the recommendation, if known.
    ///
    /// Same `SurfaceKind` vocabulary as continuation-runtime §2.1
    /// (8 frozen cases). May be `nil` for cross-surface recommendations
    /// whose origin is ambiguous.
    /// (Contract §3 row 4, §3.2.)
    let surface: SurfaceKind?

    /// Emission timestamp. UTC, second precision.
    ///
    /// MUST NOT be in the future relative to wall-clock at validation
    /// time (skew tolerance 5s per §8.3, enforced by
    /// `FeedbackEventValidator`).
    /// (Contract §3 row 5.)
    let createdAt: Date

    /// Carried-forward identifier for tracing this user action across
    /// runtime → scorer → telemetry.
    ///
    /// Implementation-defined opaque string owned by the telemetry /
    /// tracing subsystem. Consumers MUST NOT parse it. Schema details
    /// deferred to the (future) telemetry contract.
    /// (Contract §3 row 6, §9.4.)
    let traceId: String?

    /// The chat-thread identifier the recommendation was rendered into.
    ///
    /// Implementation-defined opaque string owned by the chat-session
    /// subsystem. Consumers MUST NOT parse it. Carried for cross-stream
    /// correlation.
    /// (Contract §3 row 7.)
    let threadId: String?

    /// Identifier of the `selectCandidates` / provider request that
    /// produced the recommendation.
    ///
    /// Implementation-defined opaque string owned by the
    /// matching-provider subsystem. Consumers MUST NOT parse it. Used
    /// to attribute the feedback to the originating decision lifecycle.
    /// (Contract §3 row 8.)
    let sourceRequestId: String?

    /// Identifier that links a series of feedback events that share a
    /// causal context (e.g., user dismisses three cards in quick
    /// succession in the same slate).
    ///
    /// Implementation-defined opaque string owned by the feedback-runtime
    /// layer. Consumers MUST NOT parse it. The runtime MAY assign this;
    /// consumers MUST NOT depend on it being present.
    /// (Contract §3 row 9.)
    let feedbackChainId: String?

    /// Memberwise initializer. All chain-identifier fields default to
    /// `nil` so call sites only need to specify required fields plus
    /// the chain identifiers they actually carry.
    init(
        id: String,
        recommendationId: String,
        feedbackKind: MatchingFeedbackKind,
        surface: SurfaceKind? = nil,
        createdAt: Date,
        traceId: String? = nil,
        threadId: String? = nil,
        sourceRequestId: String? = nil,
        feedbackChainId: String? = nil
    ) {
        self.id = id
        self.recommendationId = recommendationId
        self.feedbackKind = feedbackKind
        self.surface = surface
        self.createdAt = createdAt
        self.traceId = traceId
        self.threadId = threadId
        self.sourceRequestId = sourceRequestId
        self.feedbackChainId = feedbackChainId
    }
}
