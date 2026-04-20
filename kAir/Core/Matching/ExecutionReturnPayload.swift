//
//  ExecutionReturnPayload.swift
//  kAir
//
//  Structured payload returned to chat when an execution surface closes.
//  The event loop logs this as the `completion` or `abandon` return event
//  and folds `returnContextDelta` back into the conversation model so the
//  next decision has updated state.
//

import Foundation

enum ExecutionOutcome: String, Codable, Hashable, Sendable {
    case completed
    case abandoned
    case partial
    case failed
}

struct ExecutionReturnPayload: Codable, Hashable, Sendable {
    let executedCandidateId: String
    let executionSurfaceType: AppSection
    let outcome: ExecutionOutcome
    let duration: TimeInterval
    let returnContextDelta: ReturnContextDelta
    let sourceRequestId: String?
    let sourceRecommendationId: String?

    init(
        executedCandidateId: String,
        executionSurfaceType: AppSection,
        outcome: ExecutionOutcome,
        duration: TimeInterval,
        returnContextDelta: ReturnContextDelta,
        sourceRequestId: String? = nil,
        sourceRecommendationId: String? = nil
    ) {
        self.executedCandidateId = executedCandidateId
        self.executionSurfaceType = executionSurfaceType
        self.outcome = outcome
        self.duration = duration
        self.returnContextDelta = returnContextDelta
        self.sourceRequestId = sourceRequestId
        self.sourceRecommendationId = sourceRecommendationId
    }

    struct ReturnContextDelta: Codable, Hashable, Sendable {
        let downstreamValue: Double
        let completionScore: Double
        let addedIntentTags: [MatchingIntentTag]
        let resolvedObjectIds: [String]
        let dismissedObjectIds: [String]
        let summary: String?

        static let neutral = ReturnContextDelta(
            downstreamValue: 0,
            completionScore: 0,
            addedIntentTags: [],
            resolvedObjectIds: [],
            dismissedObjectIds: [],
            summary: nil
        )
    }

    static func jsonEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func jsonDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    func encodeJSONData() throws -> Data {
        try Self.jsonEncoder().encode(self)
    }

    static func decode(from data: Data) throws -> ExecutionReturnPayload {
        try jsonDecoder().decode(ExecutionReturnPayload.self, from: data)
    }

    var toOutcomeEventPayload: MatchingEventOutcome {
        MatchingEventOutcome(
            completionScore: returnContextDelta.completionScore,
            downstreamValue: returnContextDelta.downstreamValue,
            dwellSeconds: duration,
            wasSuccessful: outcome == .completed
        )
    }
}

struct ExecutionReturnContextState: Codable, Hashable, Sendable {
    struct SurfaceState: Codable, Hashable, Sendable {
        let section: AppSection
        let outcome: ExecutionOutcome
        let downstreamValue: Double
        let completionScore: Double
    }

    let addedIntentTags: [MatchingIntentTag]
    let resolvedObjectIds: [String]
    let dismissedObjectIds: [String]
    let surfaceStates: [SurfaceState]
    let summary: String?
    let createdAt: Date

    static func from(
        payload: ExecutionReturnPayload,
        createdAt: Date = .now
    ) -> ExecutionReturnContextState {
        ExecutionReturnContextState(
            addedIntentTags: dedupedTags(payload.returnContextDelta.addedIntentTags),
            resolvedObjectIds: dedupedIDs(payload.returnContextDelta.resolvedObjectIds),
            dismissedObjectIds: dedupedIDs(payload.returnContextDelta.dismissedObjectIds),
            surfaceStates: [
                SurfaceState(
                    section: payload.executionSurfaceType,
                    outcome: payload.outcome,
                    downstreamValue: payload.returnContextDelta.downstreamValue,
                    completionScore: payload.returnContextDelta.completionScore
                )
            ],
            summary: payload.returnContextDelta.summary,
            createdAt: createdAt
        )
    }

    func merged(with newer: ExecutionReturnContextState) -> ExecutionReturnContextState {
        let addedTags = Self.dedupedTags(addedIntentTags + newer.addedIntentTags)
        let resolved = Set(resolvedObjectIds)
            .union(newer.resolvedObjectIds)
            .subtracting(newer.dismissedObjectIds)
        let dismissed = Set(dismissedObjectIds)
            .union(newer.dismissedObjectIds)
            .subtracting(newer.resolvedObjectIds)

        var surfaceStatesBySection = Dictionary(uniqueKeysWithValues: surfaceStates.map { ($0.section, $0) })
        for state in newer.surfaceStates {
            surfaceStatesBySection[state.section] = state
        }

        return ExecutionReturnContextState(
            addedIntentTags: addedTags,
            resolvedObjectIds: Self.dedupedIDs(Array(resolved)),
            dismissedObjectIds: Self.dedupedIDs(Array(dismissed)),
            surfaceStates: surfaceStatesBySection
                .values
                .sorted { $0.section.rawValue < $1.section.rawValue },
            summary: newer.summary ?? summary,
            createdAt: newer.createdAt
        )
    }

    private static func dedupedTags(
        _ tags: [MatchingIntentTag]
    ) -> [MatchingIntentTag] {
        Array(Set(tags)).sorted { $0.rawValue < $1.rawValue }
    }

    private static func dedupedIDs(_ ids: [String]) -> [String] {
        Array(Set(ids)).sorted()
    }
}
