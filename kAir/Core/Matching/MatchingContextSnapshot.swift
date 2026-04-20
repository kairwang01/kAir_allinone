//
//  MatchingContextSnapshot.swift
//  kAir
//
//  Serializable product-level context captured at the moment a prompt is
//  submitted. Owned by the event loop, not the scorer. It must be stable
//  enough to round-trip through replay export and carry enough state for
//  deterministic re-scoring later.
//

import Foundation

struct MatchingContextSnapshot: Codable, Hashable, Sendable {
    let prompt: String
    let recentBehavior: [RecentBehaviorEntry]
    let activeSurface: AppSection
    let daypart: MatchingDaypart
    let locationState: MatchingLocationState
    let healthAvailability: MatchingHealthAvailability
    let motionContext: MatchingMotionContext
    let intentTags: [MatchingIntentTag]
    let longTermTags: [MatchingIntentTag]
    let foldedIntentTags: [MatchingIntentTag]
    let resolvedObjectIds: [String]
    let dismissedObjectIds: [String]
    let executionSurfaceStates: [ExecutionSurfaceState]
    let threadDepth: Int
    let capturedAt: Date
    let policyVersion: String

    struct RecentBehaviorEntry: Codable, Hashable, Sendable {
        let stage: String
        let subject: String
        let candidateId: String?
        let objectType: String?
        let surface: String?
        let feedback: String?
        let timestamp: Date
    }

    struct ExecutionSurfaceState: Codable, Hashable, Sendable {
        let section: AppSection
        let outcome: ExecutionOutcome
        let downstreamValue: Double
        let completionScore: Double
    }

    static func capture(
        prompt: String,
        context: MatchingFeatureContext,
        behaviorLog: [MatchingBehaviorEvent],
        policy: MatchingPolicyVersion,
        now: Date
    ) -> MatchingContextSnapshot {
        let recent = behaviorLog.suffix(16).map { event in
            RecentBehaviorEntry(
                stage: event.stage.rawValue,
                subject: event.subject.rawValue,
                candidateId: event.candidateID,
                objectType: event.objectKind?.rawValue,
                surface: event.surface?.rawValue,
                feedback: event.feedback?.rawValue,
                timestamp: event.timestamp
            )
        }

        return MatchingContextSnapshot(
            prompt: prompt,
            recentBehavior: recent,
            activeSurface: context.activeSurface,
            daypart: context.daypart,
            locationState: context.locationState,
            healthAvailability: context.healthAvailability,
            motionContext: context.motionContext,
            intentTags: MatchingContextSnapshot.sortedTags(context.sessionIntentTags),
            longTermTags: MatchingContextSnapshot.sortedTags(context.longTermTags),
            foldedIntentTags: MatchingContextSnapshot.sortedTags(context.foldedIntentTags),
            resolvedObjectIds: context.resolvedObjectIds.sorted(),
            dismissedObjectIds: context.dismissedObjectIds.sorted(),
            executionSurfaceStates: context.executionSurfaceStates.values
                .map { state in
                    ExecutionSurfaceState(
                        section: state.section,
                        outcome: state.outcome,
                        downstreamValue: state.downstreamValue,
                        completionScore: state.completionScore
                    )
                }
                .sorted { $0.section.rawValue < $1.section.rawValue },
            threadDepth: context.messageCount,
            capturedAt: now,
            policyVersion: policy.policyVersion
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

    static func decode(from data: Data) throws -> MatchingContextSnapshot {
        try jsonDecoder().decode(MatchingContextSnapshot.self, from: data)
    }

    private static func sortedTags(_ tags: Set<MatchingIntentTag>) -> [MatchingIntentTag] {
        tags.sorted { $0.rawValue < $1.rawValue }
    }
}

extension AppSection: Codable {}
extension MatchingDaypart: Codable {}
extension MatchingLocationState: Codable {}
extension MatchingHealthAvailability: Codable {}
extension MatchingMotionContext: Codable {}
extension MatchingIntentTag: Codable {}
