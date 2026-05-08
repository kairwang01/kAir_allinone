//
//  TelemetryEventPayload.swift
//  kAir
//
//  Typed payload carrying the right subset of identifiers per
//  Contracts/telemetry-contract-v1.md §5.2 (required propagation
//  matrix).
//
//  All seven ids appear here as `Optional` `let` fields. Per the
//  contract, each event in §4.1 requires a specific subset; this v1
//  payload does NOT enforce the matrix at the type level. Matrix
//  enforcement is a runtime check in TelemetryPropagationMatrix.swift
//  and is reserved as a v2 nicety to lift into per-event payload
//  types if shape evolves slowly enough to justify it.
//
//  The companion enum `TelemetryRequiredID` names the slot each
//  identifier occupies in the §5.2 matrix; it is the propagation-check
//  vocabulary used by `TelemetryEventPayload.required(for:)`.
//

import Foundation

/// Identifies one of the seven id slots in the §5.2 propagation
/// matrix. Used by the propagation validator and any future generic
/// matrix tooling. Internal-by-design: external callers fill the
/// payload with the typed wrappers in TelemetryIdentifiers.swift, not
/// with this enum.
enum TelemetryRequiredID: Hashable, CaseIterable {
    case traceID
    case threadID
    case recommendationID
    case sourceRequestID
    case sourceRecommendationID
    case surfaceSessionID
    case feedbackChainID
}

/// Carries the subset of the seven identifiers in
/// Contracts/telemetry-contract-v1.md §3 that an event needs. Callers
/// fill the required ids per the §5.2 matrix; the propagation check
/// at emit time enforces the matrix.
struct TelemetryEventPayload: Hashable {
    let traceID: TraceID?
    let threadID: ThreadID?
    let recommendationID: RecommendationID?
    let sourceRequestID: SourceRequestID?
    let sourceRecommendationID: SourceRecommendationID?
    let surfaceSessionID: SurfaceSessionID?
    let feedbackChainID: FeedbackChainID?

    init(
        traceID: TraceID? = nil,
        threadID: ThreadID? = nil,
        recommendationID: RecommendationID? = nil,
        sourceRequestID: SourceRequestID? = nil,
        sourceRecommendationID: SourceRecommendationID? = nil,
        surfaceSessionID: SurfaceSessionID? = nil,
        feedbackChainID: FeedbackChainID? = nil
    ) {
        self.traceID = traceID
        self.threadID = threadID
        self.recommendationID = recommendationID
        self.sourceRequestID = sourceRequestID
        self.sourceRecommendationID = sourceRecommendationID
        self.surfaceSessionID = surfaceSessionID
        self.feedbackChainID = feedbackChainID
    }

    /// Returns the set of identifier slots that MUST be set for the
    /// given event per Contracts/telemetry-contract-v1.md §5.2. The
    /// returned set covers only the ✓ entries; ✗ (forbidden) and •
    /// (optional) entries are not included.
    static func required(for event: TelemetryEvent) -> Set<TelemetryRequiredID> {
        switch event {
        case .chatPromptSubmit:
            return [.traceID, .threadID]
        case .intentDecide:
            return [.traceID, .threadID, .sourceRequestID]
        case .railSlateMaterialize:
            return [.traceID, .threadID, .sourceRequestID]
        case .railCardImpression:
            return [.traceID, .threadID, .recommendationID, .sourceRequestID]
        case .railCardAccept:
            return [.traceID, .threadID, .recommendationID, .sourceRequestID]
        case .railCardDismiss:
            return [.traceID, .threadID, .recommendationID, .sourceRequestID]
        case .surfaceEnter:
            return [.traceID, .threadID, .surfaceSessionID]
        case .surfaceReturn:
            return [.traceID, .threadID, .surfaceSessionID]
        case .transcriptContinuationAppend:
            return [.traceID, .threadID, .surfaceSessionID]
        case .transcriptContinuationSilent:
            return [.traceID, .threadID, .surfaceSessionID]
        case .feedbackEvent:
            return [.traceID, .threadID, .recommendationID, .sourceRequestID, .feedbackChainID]
        }
    }

    /// Returns the set of identifier slots that MUST NOT be set for
    /// the given event per Contracts/telemetry-contract-v1.md §5.2.
    /// The returned set covers only the ✗ entries; ✓ (required) and •
    /// (optional) entries are not included.
    static func forbidden(for event: TelemetryEvent) -> Set<TelemetryRequiredID> {
        switch event {
        case .chatPromptSubmit:
            return [.recommendationID, .sourceRequestID, .sourceRecommendationID, .surfaceSessionID, .feedbackChainID]
        case .intentDecide:
            return [.recommendationID, .sourceRecommendationID, .surfaceSessionID, .feedbackChainID]
        case .railSlateMaterialize:
            return [.recommendationID, .surfaceSessionID]
        case .railCardImpression:
            return [.surfaceSessionID]
        case .railCardAccept:
            return [.surfaceSessionID]
        case .railCardDismiss:
            return [.surfaceSessionID]
        case .surfaceEnter:
            return []
        case .surfaceReturn:
            return []
        case .transcriptContinuationAppend:
            return []
        case .transcriptContinuationSilent:
            return []
        case .feedbackEvent:
            return [.surfaceSessionID]
        }
    }

    // MARK: - Internal helpers

    /// Returns the set of identifier slots that ARE present (non-nil)
    /// in this payload. Used by the propagation validator.
    func presentIDs() -> Set<TelemetryRequiredID> {
        var present: Set<TelemetryRequiredID> = []
        if traceID != nil { present.insert(.traceID) }
        if threadID != nil { present.insert(.threadID) }
        if recommendationID != nil { present.insert(.recommendationID) }
        if sourceRequestID != nil { present.insert(.sourceRequestID) }
        if sourceRecommendationID != nil { present.insert(.sourceRecommendationID) }
        if surfaceSessionID != nil { present.insert(.surfaceSessionID) }
        if feedbackChainID != nil { present.insert(.feedbackChainID) }
        return present
    }
}
