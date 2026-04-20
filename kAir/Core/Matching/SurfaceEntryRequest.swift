//
//  SurfaceEntryRequest.swift
//  kAir
//
//  Unified entry contract for the 5 capability surfaces (Maps, Music,
//  Video, Health, Store) plus chat + AI. Every open* call serializes
//  through this struct so the matching layer, the replay exporter,
//  and the return payload read one shape.
//
//  The struct is deliberately minimal and stable: a dispatcher only
//  needs `surfaceType`, the intent label, references back to the
//  source card / recommendation / thread, an object pointer, and a
//  flat argument bag. `handoffContext` carries the conversation-side
//  continuation info that the surface needs to fold back when it
//  closes.
//

import Foundation

enum SurfaceEntryIntent: String, Codable, CaseIterable, Hashable, Sendable {
    case navigate
    case discoverNearby
    case reviewRoute
    case playMusic
    case watchVideo
    case openHealth
    case openStore
    case openAI
    case resumeChat
    case unspecified

    init(section: AppSection) {
        switch section {
        case .maps:
            self = .navigate
        case .music:
            self = .playMusic
        case .video:
            self = .watchVideo
        case .health:
            self = .openHealth
        case .store:
            self = .openStore
        case .ai:
            self = .openAI
        case .chat:
            self = .resumeChat
        }
    }
}

struct SurfaceEntryHandoffContext: Codable, Hashable, Sendable {
    let sourceMessagePreview: String?
    let returnThreadId: String?
    let priorContextStateSummary: String?

    static let empty = SurfaceEntryHandoffContext(
        sourceMessagePreview: nil,
        returnThreadId: nil,
        priorContextStateSummary: nil
    )
}

struct SurfaceEntryRequest: Codable, Hashable, Sendable, Identifiable {
    let requestId: String
    let surfaceType: AppSection
    let entryIntent: SurfaceEntryIntent
    let sourceCardId: String?
    let sourceRecommendationId: String?
    let sourceThreadId: String?
    let objectType: String?
    let objectId: String?
    let normalizedArgs: [String: String]
    let requiresConfirmation: Bool
    let handoffContext: SurfaceEntryHandoffContext
    let issuedAt: Date

    var id: String { requestId }

    init(
        requestId: String = UUID().uuidString,
        surfaceType: AppSection,
        entryIntent: SurfaceEntryIntent,
        sourceCardId: String? = nil,
        sourceRecommendationId: String? = nil,
        sourceThreadId: String? = nil,
        objectType: String? = nil,
        objectId: String? = nil,
        normalizedArgs: [String: String] = [:],
        requiresConfirmation: Bool = false,
        handoffContext: SurfaceEntryHandoffContext = .empty,
        issuedAt: Date = .now
    ) {
        self.requestId = requestId
        self.surfaceType = surfaceType
        self.entryIntent = entryIntent
        self.sourceCardId = sourceCardId
        self.sourceRecommendationId = sourceRecommendationId
        self.sourceThreadId = sourceThreadId
        self.objectType = objectType
        self.objectId = objectId
        self.normalizedArgs = normalizedArgs
        self.requiresConfirmation = requiresConfirmation
        self.handoffContext = handoffContext
        self.issuedAt = issuedAt
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

    static func decode(from data: Data) throws -> SurfaceEntryRequest {
        try jsonDecoder().decode(SurfaceEntryRequest.self, from: data)
    }
}

enum SurfaceEntryEventPhase: String, Codable, Hashable, Sendable {
    case requested
    case started
    case returned
}
