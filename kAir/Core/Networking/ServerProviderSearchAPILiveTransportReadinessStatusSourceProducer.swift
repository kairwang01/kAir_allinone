//
//  ServerProviderSearchAPILiveTransportReadinessStatusSourceProducer.swift
//  kAir
//
//  Rendered-id scoped provider-status projection for A145 Search API planning
//  evidence decisions. This is advisory copy only and never exposes runtime
//  material.
//

import Foundation

@MainActor
struct ServerProviderSearchAPILiveTransportReadinessStatusSourceProducer {
    struct Input: Hashable, Sendable {
        let recommendationID: String
        let decision: ServerProviderSearchAPILiveTransportReadinessDecision
    }

    func statusSource(
        inputs: [Input],
        renderedRecommendationIDs: [String]
    ) -> ServerProviderRenderedRuntimeStatusSource {
        ServerProviderRenderedRuntimeStatusSource(
            source: ServerProviderSearchAPILiveTransportReadinessStatusStore(
                decisions: inputs.map { input in
                    (
                        recommendationID: input.recommendationID,
                        decision: input.decision
                    )
                }
            ),
            renderedRecommendationIDs: renderedRecommendationIDs
        )
    }
}

struct ServerProviderSearchAPILiveTransportReadinessStatusStore: ProviderStatusProviding {
    private let decisionsByRecommendationID:
        [String: ServerProviderSearchAPILiveTransportReadinessDecision]

    nonisolated init(
        decisionsByRecommendationID: [String: ServerProviderSearchAPILiveTransportReadinessDecision]
    ) {
        self.decisionsByRecommendationID = decisionsByRecommendationID
    }

    nonisolated init(
        decisions: [
            (
                recommendationID: String,
                decision: ServerProviderSearchAPILiveTransportReadinessDecision
            )
        ]
    ) {
        var indexed: [String: ServerProviderSearchAPILiveTransportReadinessDecision] = [:]
        var seenRecommendationIDs: Set<String> = []
        for entry in decisions where seenRecommendationIDs.insert(entry.recommendationID).inserted {
            indexed[entry.recommendationID] = entry.decision
        }
        self.decisionsByRecommendationID = indexed
    }

    nonisolated var recommendationIDs: [String] {
        decisionsByRecommendationID.keys.sorted()
    }

    nonisolated func providerStatusPresentation(
        for recommendationID: String
    ) -> ProviderStatusPresentation? {
        guard let decision = decisionsByRecommendationID[recommendationID] else {
            return nil
        }
        return ProviderStatusPresentation(
            recommendationID: recommendationID,
            badges: Self.badges(for: decision),
            statusLine: Self.statusLine(for: decision),
            cardHint: Self.cardHint(for: decision)
        )
    }

    nonisolated private static func badges(
        for decision: ServerProviderSearchAPILiveTransportReadinessDecision
    ) -> [ProviderStatusBadgeModel] {
        guard isReadyForPlanning(decision) else {
            return [rejectionBadge(for: decision.rejection)]
        }
        return deduplicated([
            ProviderStatusBadgeModel(
                kind: .remoteProvider,
                label: "Remote provider",
                systemImage: "network",
                tone: .neutral
            ),
            ProviderStatusBadgeModel(
                kind: .includedQuota,
                label: "Planning evidence",
                systemImage: "checkmark.seal",
                tone: .neutral
            ),
            ProviderStatusBadgeModel(
                kind: .liveFreshness,
                label: "Provider path disabled",
                systemImage: "pause.circle",
                tone: .neutral
            ),
        ])
    }

    nonisolated private static func statusLine(
        for decision: ServerProviderSearchAPILiveTransportReadinessDecision
    ) -> String {
        if isReadyForPlanning(decision) {
            return deduplicatedStatusSegments([
                "Search API planning evidence is ready for advisory status.",
                "Provider path remains disabled.",
            ])
            .joined(separator: " ")
        }

        return deduplicatedStatusSegments([
            "Search API planning evidence is blocked by value-only policy.",
            "Provider path remains disabled.",
        ])
        .joined(separator: " ")
    }

    nonisolated private static func cardHint(
        for decision: ServerProviderSearchAPILiveTransportReadinessDecision
    ) -> ProviderStatusCardHint {
        isReadyForPlanning(decision) ? .warning : .disabled
    }

    nonisolated private static func isReadyForPlanning(
        _ decision: ServerProviderSearchAPILiveTransportReadinessDecision
    ) -> Bool {
        decision.state == .readyForPlanning
            && decision.rejection == nil
            && decision.runtimeEntryPointName == nil
            && decision.liveProviderPathEnabled == false
    }

    nonisolated private static func rejectionBadge(
        for rejection: ServerProviderSearchAPILiveTransportReadinessRejection?
    ) -> ProviderStatusBadgeModel {
        switch rejection {
        case .staleBoundaryID:
            return ProviderStatusBadgeModel(
                kind: .staleCache,
                label: "Planning stale",
                systemImage: "clock.arrow.circlepath",
                tone: .warning
            )
        case .callableRuntimeEntrypoint, .liveProviderPathEnabled,
             .unsafeMaterialDetected:
            return ProviderStatusBadgeModel(
                kind: .termsBlocked,
                label: "Provider blocked",
                systemImage: "exclamationmark.triangle",
                tone: .warning
            )
        case .missingEvidence, .duplicateEvidenceID,
             .unknownEvidenceTarget, .none:
            return ProviderStatusBadgeModel(
                kind: .unavailable,
                label: "Planning unavailable",
                systemImage: "wifi.slash",
                tone: .warning
            )
        }
    }

    nonisolated private static func deduplicated(
        _ badges: [ProviderStatusBadgeModel]
    ) -> [ProviderStatusBadgeModel] {
        var seen: Set<ProviderStatusBadgeKind> = []
        var result: [ProviderStatusBadgeModel] = []
        for badge in badges where seen.insert(badge.kind).inserted {
            result.append(badge)
        }
        return result
    }

    nonisolated private static func deduplicatedStatusSegments(
        _ segments: [String]
    ) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for segment in segments {
            let trimmed = segment.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else {
                continue
            }
            guard seen.insert(trimmed).inserted else {
                continue
            }
            result.append(trimmed)
        }
        return result
    }
}
