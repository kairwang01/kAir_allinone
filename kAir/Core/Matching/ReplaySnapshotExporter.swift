//
//  ReplaySnapshotExporter.swift
//  kAir
//
//  Exports replay-ready artifacts from real runtime data. A replay export
//  is self-contained: it carries the context snapshot, the decision that
//  was produced, every event that fired in the lifecycle, and any execution
//  return payloads. Replay can re-drive the decision deterministically
//  from this export.
//

import Foundation

struct ReplayExportedDecision: Codable, Hashable, Sendable {
    let recommendationId: String
    let policyVersion: String
    let directSlotCandidateId: String?
    let rankedCandidateIds: [String]
    let alternativeCandidateIds: [String]
    let reasonCodes: [ReasonCode]
    let suppressionReasons: [ReasonCode]
    let feedbackOptions: [FeedbackOption]
    let executionSurfaceType: AppSection
    let objectType: String?
    let generatedAt: Date

    init(from decision: RecommendationDecision) {
        self.recommendationId = decision.recommendationId
        self.policyVersion = decision.policyVersion.policyVersion
        self.directSlotCandidateId = decision.directSlotCandidateId
        self.rankedCandidateIds = decision.rankedIds
        self.alternativeCandidateIds = decision.alternativeIds
        self.reasonCodes = decision.reasonCodes
        self.suppressionReasons = decision.suppressionReasons
        self.feedbackOptions = decision.feedbackOptions
        self.executionSurfaceType = decision.executionSurfaceType
        self.objectType = decision.objectType?.rawValue
        self.generatedAt = decision.generatedAt
    }
}

struct ReplayExportedSession: Codable, Hashable, Sendable {
    let schemaVersion: String
    let sessionId: String
    let policyVersion: String
    let context: MatchingContextSnapshot
    let decision: ReplayExportedDecision
    let events: [MatchingEvent]
    let executionReturns: [ExecutionReturnPayload]
    let exportedAt: Date

    static let currentSchemaVersion = MatchingKernelBaseline.current.replayExportSchemaVersion

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func jsonEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(iso8601Formatter.string(from: date))
        }
        return encoder
    }

    static func jsonDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = iso8601Formatter.date(from: raw) {
                return date
            }
            let fallback = ISO8601DateFormatter()
            if let date = fallback.date(from: raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO8601 date: \(raw)"
            )
        }
        return decoder
    }

    func encodeJSONData() throws -> Data {
        try Self.jsonEncoder().encode(self)
    }

    static func decode(from data: Data) throws -> ReplayExportedSession {
        try jsonDecoder().decode(ReplayExportedSession.self, from: data)
    }
}

enum ReplaySnapshotExporter {
    static func export(
        sessionId: String,
        context: MatchingContextSnapshot,
        decision: RecommendationDecision,
        events: [MatchingEvent],
        executionReturns: [ExecutionReturnPayload],
        now: Date = .now
    ) -> ReplayExportedSession {
        let sessionEvents = events.filter { $0.sessionId == sessionId }
        return ReplayExportedSession(
            schemaVersion: ReplayExportedSession.currentSchemaVersion,
            sessionId: sessionId,
            policyVersion: decision.policyVersion.policyVersion,
            context: context,
            decision: ReplayExportedDecision(from: decision),
            events: sessionEvents,
            executionReturns: executionReturns,
            exportedAt: now
        )
    }

    @discardableResult
    static func write(
        _ export: ReplayExportedSession,
        to directory: URL,
        filename: String? = nil
    ) throws -> URL {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let name = filename ?? "replay_session_\(export.sessionId).json"
        let url = directory.appendingPathComponent(name)
        try export.encodeJSONData().write(to: url, options: .atomic)
        return url
    }
}
