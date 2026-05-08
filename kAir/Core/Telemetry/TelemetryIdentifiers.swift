//
//  TelemetryIdentifiers.swift
//  kAir
//
//  Typed opaque-string wrappers for the v1 telemetry identifier
//  vocabulary. Each id is one of the seven fields enumerated in
//  Contracts/telemetry-contract-v1.md §3 (identifier vocabulary).
//
//  Per §3.2 (identifier opacity rule): consumers MUST NOT parse the
//  raw string. The format (UUID, ULID, hash, scoped sequence) is an
//  implementation choice owned by the issuer. Two events sharing the
//  same id refer to the same logical entity; consumers MUST NOT derive
//  ordering, time, or attribution from the bytes of an id.
//
//  These are skeleton scaffolding. No emitter in the existing kAir
//  codebase calls any TelemetryEmitter today; the wrappers exist so
//  downstream instrumentation PRs land typed signatures, not raw
//  Strings. Per the contract, the runtime SHOULD catch identifier
//  invariant violations at the type system level — that future work
//  builds on these wrappers.
//

import Foundation

// MARK: - Identifier types (one per §3 row)

/// Root-level chain identifier across the entire user request lifecycle.
///
/// Per Contracts/telemetry-contract-v1.md §3:
/// - Definition: every event from the originating chat prompt through
///   downstream rail impressions, surface sessions, transcript
///   continuations, and feedback events MUST carry the same `trace_id`.
/// - Lifetime: one user request lifecycle. Begins at
///   `chat.prompt.submit`; ends when no further descendant events can
///   fire.
/// - Issuer: chat home (the composer / `ChatStore`) at the moment a
///   user prompt is committed. Issued exactly once per submitted prompt.
struct TraceID: Hashable, Codable, RawRepresentable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(_ raw: String) {
        self.rawValue = raw
    }
}

/// The conversation thread the prompt belongs to.
///
/// Per Contracts/telemetry-contract-v1.md §3:
/// - Definition: identifies the persistent chat session the prompt
///   belongs to. Multiple prompts in the same thread share `thread_id`
///   but have distinct `trace_id`s.
/// - Lifetime: lifetime of the thread. Stable across app restarts when
///   the thread is restored from persistence.
/// - Issuer: the chat session manager (the layer that owns
///   `ConversationMessage` history). Issued when the thread is created.
struct ThreadID: Hashable, Codable, RawRepresentable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(_ raw: String) {
        self.rawValue = raw
    }
}

/// One card in `recommendedMatches`: a single rendered `MatchingObject`
/// instance within a slate.
///
/// Per Contracts/telemetry-contract-v1.md §3:
/// - Definition: two slates emitted from the same prompt but in
///   different refresh cycles MUST issue distinct `recommendation_id`s
///   for what is otherwise the "same" `MatchingObject`.
/// - Lifetime: one slate render of one card.
/// - Issuer: the `ConversationIntentEngine` / recommendation provider
///   at the moment a slate is materialized for the rail. Issued exactly
///   once per (slate, slot) pair.
struct RecommendationID: Hashable, Codable, RawRepresentable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(_ raw: String) {
        self.rawValue = raw
    }
}

/// The originating user prompt that produced a downstream event.
///
/// Per Contracts/telemetry-contract-v1.md §3:
/// - Definition: for an event fired during or after a rail interaction,
///   `source_request_id` traces back to the `chat.prompt.submit` whose
///   response slate the card belongs to.
/// - Lifetime: same as `trace_id` for the originating prompt.
/// - Issuer: chat home, at `chat.prompt.submit`. Stamped onto every
///   downstream `recommendation_id`-carrying event.
struct SourceRequestID: Hashable, Codable, RawRepresentable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(_ raw: String) {
        self.rawValue = raw
    }
}

/// Parent rec when this rec is chained / derived.
///
/// Per Contracts/telemetry-contract-v1.md §3:
/// - Definition: set on a `recommendation_id` when the slate that
///   produced it was generated in response to acceptance, dismissal,
///   or completion of a prior rec — i.e., the new slate is *because of*
///   the previous card, not *because of* a fresh prompt. When the slate
///   is the direct child of a `chat.prompt.submit` (no parent rec),
///   `source_recommendation_id` is unset / `nil`.
/// - Lifetime: same as the new `recommendation_id`.
/// - Issuer: the recommendation provider, at the moment the new slate
///   is materialized when a parent rec was the trigger.
struct SourceRecommendationID: Hashable, Codable, RawRepresentable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(_ raw: String) {
        self.rawValue = raw
    }
}

/// One execution-surface session.
///
/// Per Contracts/telemetry-contract-v1.md §3:
/// - Definition: a single `Maps` trip, a single `Music` play session, a
///   single `Health` detail-view visit, etc. Distinct from
///   `recommendation_id`: a single accepted rec opens a single surface
///   session, but a user can re-enter the same `recommendation_id` (if
///   the rec persists across refreshes) to begin a new
///   `surface_session_id`.
/// - Lifetime: one end-to-end surface entry → return / abandon /
///   dismiss / acceptNoEntry. Begins at `surface.<kind>.enter`; ends at
///   the corresponding `ChatContinuationEvent` emission.
/// - Issuer: the execution surface itself, on entry.
struct SurfaceSessionID: Hashable, Codable, RawRepresentable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(_ raw: String) {
        self.rawValue = raw
    }
}

/// Links a feedback event back to its rec lineage.
///
/// Per Contracts/telemetry-contract-v1.md §3:
/// - Definition: stamped on a `feedback.event` and on any subsequent
///   rerank / refresh slate that the scorer attributes to that
///   feedback. Allows a downstream slate's `recommendation_id`s to be
///   traced back not just to a `source_recommendation_id` but to the
///   specific feedback signal that caused the rerank.
/// - Lifetime: one feedback signal's downstream effect window. Begins
///   at `feedback.event`; ends when the next slate refresh that
///   consumed this signal has fully propagated.
/// - Issuer: the feedback affordance (the `✕` button or the `⋯` menu),
///   at the moment `dismissRecommendation(_:feedback:)` runs. Issued
///   exactly once per feedback submission.
struct FeedbackChainID: Hashable, Codable, RawRepresentable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(_ raw: String) {
        self.rawValue = raw
    }
}
