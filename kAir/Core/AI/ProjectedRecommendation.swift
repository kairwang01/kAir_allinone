//
//  ProjectedRecommendation.swift
//  kAir
//
//  Pure seam from provider result projections to Recommended Next data.
//  No SwiftUI, no real providers, no network, no MCP execution.
//

import Foundation

/// Recommendation-level state derived from provider projection status. This is
/// intentionally not `ActionCardState`; Core/AI must not depend on DesignSystem.
enum ProjectedRecommendationState: String, Codable, Hashable, Sendable, CaseIterable {
    case ready
    case blocked
    case unavailable

    var allowsPrimaryAction: Bool {
        self == .ready
    }
}

/// One recommendation object plus the provider metadata that the current
/// `MatchingObject` intentionally does not carry. UI can render `object` today;
/// future provider badges/status can read `metadata` without re-routing.
struct ProjectedRecommendation: Hashable, Identifiable {
    let id: String
    let sourceProjectionID: String
    let object: MatchingObject
    let state: ProjectedRecommendationState
    let metadata: ResultProviderMetadata

    var isActionable: Bool {
        state.allowsPrimaryAction
            && object.primaryCTA != "Unavailable"
            && object.activationPrompt.isEmpty == false
    }
}

/// Deterministic adapter from projected provider results to a capped
/// `RecommendationProvider` slate. It preserves metadata outside
/// `MatchingObject` because the frozen domain card model has no provider fields.
final class ProjectedRecommendationProvider: RecommendationProvider {
    static let maxProjectedSlateSize = 3

    private let items: [ProjectedRecommendation]

    init(projections: [ProjectedProviderResult]) {
        self.items = Array(
            projections
                .map(ResultRecommendationProjector.project)
                .prefix(Self.maxProjectedSlateSize)
        )
    }

    func recommendedMatches() -> [MatchingObject] {
        items.map(\.object)
    }

    func projectedRecommendations() -> [ProjectedRecommendation] {
        items
    }

    func metadata(for recommendationID: String) -> ResultProviderMetadata? {
        items.first { $0.id == recommendationID }?.metadata
    }
}

enum ResultRecommendationProjector {
    nonisolated static func project(_ projection: ProjectedProviderResult) -> ProjectedRecommendation {
        let state = recommendationState(for: projection)
        let object = MatchingObject(
            id: recommendationID(for: projection),
            kind: objectKind(for: projection),
            title: title(for: projection),
            subtitleTokens: subtitleTokens(for: projection, state: state),
            reasonText: reasonText(for: projection, state: state),
            primaryCTA: primaryCTA(for: projection, state: state),
            secondaryCTA: nil,
            activationPrompt: activationPrompt(for: projection, state: state),
            preferredSection: preferredSection(for: projection, state: state)
        )

        return ProjectedRecommendation(
            id: object.id,
            sourceProjectionID: projection.id,
            object: object,
            state: state,
            metadata: projection.metadata
        )
    }

    nonisolated private static func recommendationState(
        for projection: ProjectedProviderResult
    ) -> ProjectedRecommendationState {
        switch projection.status {
        case .resolved:
            if case .some = projection.normalizedResult {
                return .ready
            }
            return .unavailable
        case .blocked:
            return .blocked
        case .unavailable:
            return .unavailable
        }
    }

    nonisolated private static func recommendationID(for projection: ProjectedProviderResult) -> String {
        "rec-\(projection.id)"
    }

    nonisolated private static func objectKind(for projection: ProjectedProviderResult) -> MatchingObjectKind {
        guard let payload = projection.normalizedResult?.payload else {
            return .toolEntry
        }

        switch payload {
        case .placeSearch:
            return .place
        case .routePlanning:
            return .route
        case .webSearch:
            return .searchResult
        case .aiCompletion, .healthRead:
            return .answerCard
        case .threadLookup:
            return .thread
        case .localStoreLookup, .healthWrite:
            return .toolEntry
        case .musicPlayback:
            return .song
        case .videoPlayback:
            return .video
        }
    }

    nonisolated private static func title(for projection: ProjectedProviderResult) -> String {
        guard let payload = projection.normalizedResult?.payload else {
            return projection.summaryTitle
        }

        switch payload {
        case .placeSearch(let places):
            return places.first?.name ?? projection.summaryTitle
        case .routePlanning(let route):
            return "Route to \(route.destination)"
        case .webSearch(let hits):
            return hits.first?.title ?? projection.summaryTitle
        case .aiCompletion(let completion):
            return completion.text
        case .threadLookup(let thread):
            return thread.title ?? "Continue thread"
        case .localStoreLookup(let item):
            return item.title
        case .musicPlayback(let track):
            return track.title
        case .videoPlayback(let video):
            return video.title
        case .healthRead(let snapshot):
            return "Health: \(snapshot.metricToken)"
        case .healthWrite(let receipt):
            return "Health write: \(receipt.metricToken)"
        }
    }

    nonisolated private static func subtitleTokens(
        for projection: ProjectedProviderResult,
        state: ProjectedRecommendationState
    ) -> [String] {
        let provider = projection.metadata.providerID ?? "No provider"
        switch state {
        case .ready:
            return [provider, projection.metadata.freshness.rawValue]
        case .blocked:
            return ["Blocked", projection.metadata.costClass.rawValue]
        case .unavailable:
            return ["Unavailable", projection.metadata.costClass.rawValue]
        }
    }

    nonisolated private static func reasonText(
        for projection: ProjectedProviderResult,
        state: ProjectedRecommendationState
    ) -> String? {
        switch state {
        case .ready:
            return "Provider metadata preserved"
        case .blocked, .unavailable:
            return shortReason(from: projection.metadata.limitations.first)
        }
    }

    nonisolated private static func primaryCTA(
        for projection: ProjectedProviderResult,
        state: ProjectedRecommendationState
    ) -> String {
        guard state == .ready else { return "Unavailable" }

        switch objectKind(for: projection) {
        case .place:
            return "Open place"
        case .route:
            return "Open route"
        case .searchResult:
            return "Review result"
        case .answerCard:
            return "Read"
        case .toolEntry:
            return "Open"
        case .thread:
            return "Continue"
        case .song:
            return "Play"
        case .video:
            return "Watch"
        case .contact:
            return "Open"
        }
    }

    nonisolated private static func activationPrompt(
        for projection: ProjectedProviderResult,
        state: ProjectedRecommendationState
    ) -> String {
        guard state == .ready else { return "" }

        switch objectKind(for: projection) {
        case .route:
            return "Open route: \(title(for: projection))"
        case .place:
            return "Open place: \(title(for: projection))"
        case .searchResult:
            return "Review cited result: \(title(for: projection))"
        case .answerCard:
            return "Read answer: \(title(for: projection))"
        case .toolEntry:
            return "Open tool: \(title(for: projection))"
        case .thread:
            return "Continue thread: \(title(for: projection))"
        case .song:
            return "Play \(title(for: projection))"
        case .video:
            return "Watch \(title(for: projection))"
        case .contact:
            return "Open contact: \(title(for: projection))"
        }
    }

    nonisolated private static func preferredSection(
        for projection: ProjectedProviderResult,
        state: ProjectedRecommendationState
    ) -> RecommendedSurface? {
        guard state == .ready else { return nil }

        switch projection.surface {
        case .health:
            return .health
        case .ai:
            return .ai
        case .maps:
            return .maps
        case .search:
            return .search
        case .store:
            return .store
        case .chat, .music, .video:
            return nil
        }
    }

    nonisolated private static func shortReason(from raw: String?) -> String? {
        guard let raw, raw.isEmpty == false else { return nil }
        if raw.count <= 60 { return raw }
        let limit = raw.index(raw.startIndex, offsetBy: 57)
        return String(raw[..<limit]) + "..."
    }
}
