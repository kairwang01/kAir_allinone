//
//  MatchingEvent.swift
//  kAir
//
//  Canonical product event model for the Phase-1 runtime loop. Every event
//  in the ask → recommend → execute → return → log chain serializes through
//  this type so replay export and runtime logging read one contract.
//
//  Every MatchingEvent carries sessionId, recommendationId, candidateId,
//  timestamp, objectType, executionSurfaceType, optional feedbackOption,
//  policyVersion, and type-specific payload.
//

import Foundation

enum MatchingEventType: String, Codable, CaseIterable, Hashable, Sendable {
    case impression
    case click
    case accept
    case dismiss
    case abandon
    case completion
    case downstreamValue = "downstream_value"
    case surfaceEntryRequested = "surface_entry_requested"
    case surfaceEntryStarted = "surface_entry_started"
    case surfaceEntryReturned = "surface_entry_returned"
}

struct MatchingEventOutcome: Codable, Hashable, Sendable {
    let completionScore: Double
    let downstreamValue: Double
    let dwellSeconds: Double?
    let wasSuccessful: Bool

    static let neutral = MatchingEventOutcome(
        completionScore: 0,
        downstreamValue: 0,
        dwellSeconds: nil,
        wasSuccessful: false
    )
}

struct MatchingEvent: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let type: MatchingEventType
    let sessionId: String
    let recommendationId: String
    let candidateId: String?
    let timestamp: Date
    let objectType: String?
    let executionSurfaceType: String?
    let feedbackOption: FeedbackOption?
    let policyVersion: String
    let outcome: MatchingEventOutcome?
    let surfaceEntryRequestId: String?

    static let schemaVersion = MatchingKernelBaseline.current.eventSchemaVersion

    init(
        id: UUID = UUID(),
        type: MatchingEventType,
        sessionId: String,
        recommendationId: String,
        candidateId: String?,
        timestamp: Date = .now,
        objectType: String? = nil,
        executionSurfaceType: String? = nil,
        feedbackOption: FeedbackOption? = nil,
        policyVersion: String,
        outcome: MatchingEventOutcome? = nil,
        surfaceEntryRequestId: String? = nil
    ) {
        self.id = id
        self.type = type
        self.sessionId = sessionId
        self.recommendationId = recommendationId
        self.candidateId = candidateId
        self.timestamp = timestamp
        self.objectType = objectType
        self.executionSurfaceType = executionSurfaceType
        self.feedbackOption = feedbackOption
        self.policyVersion = policyVersion
        self.outcome = outcome
        self.surfaceEntryRequestId = surfaceEntryRequestId
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

    static func decode(from data: Data) throws -> MatchingEvent {
        try jsonDecoder().decode(MatchingEvent.self, from: data)
    }
}
