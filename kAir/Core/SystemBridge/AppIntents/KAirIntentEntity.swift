//
//  KAirIntentEntity.swift
//  kAir
//
//  Small App Intents entity surface for kAir-owned destinations.
//

import AppIntents
import Foundation

struct KAirIntentEntity: AppEntity, Hashable, Sendable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "kAir Surface"
    }

    static var defaultQuery = KAirIntentEntityQuery()

    let id: String
    let title: String
    let summary: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(summary)"
        )
    }
}

extension KAirIntentEntity {
    static let chat = KAirIntentEntity(
        id: "chat",
        title: "Chat",
        summary: "Open the private kAir command surface."
    )

    static let maps = KAirIntentEntity(
        id: "maps",
        title: "Maps",
        summary: "Open the kAir maps execution surface."
    )

    static let ai = KAirIntentEntity(
        id: "ai",
        title: "AI",
        summary: "Open the local model and routing surface."
    )

    static let search = KAirIntentEntity(
        id: "search",
        title: "Search",
        summary: "Open the read-only public information surface."
    )

    static let store = KAirIntentEntity(
        id: "store",
        title: "Store",
        summary: "Open the curated kAir catalog surface."
    )

    static let health = KAirIntentEntity(
        id: "health",
        title: "Health",
        summary: "Open the local-only Health surface."
    )

    static let allBuiltSurfaces: [KAirIntentEntity] = [
        .chat,
        .maps,
        .search,
        .ai,
        .store,
        .health,
    ]

    static func entity(for id: String) -> KAirIntentEntity? {
        allBuiltSurfaces.first { $0.id == id }
    }
}

struct KAirIntentEntityQuery: EntityQuery, Sendable {
    func entities(for identifiers: [KAirIntentEntity.ID]) async throws -> [KAirIntentEntity] {
        identifiers.compactMap(KAirIntentEntity.entity(for:))
    }

    func suggestedEntities() async throws -> [KAirIntentEntity] {
        KAirIntentEntity.allBuiltSurfaces
    }
}
