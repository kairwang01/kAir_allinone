//
//  ServerProviderServiceCutPlanStatusSourceProducer.swift
//  kAir
//
//  A183 rendered-id scoped provider-status projection for A182 service
//  cut-plan decisions. This packages planning copy only.
//

import Foundation

struct ServerProviderServiceCutPlanStatusSourceProducer {
    struct Input: Hashable, Sendable {
        let recommendationID: String
        let statusSourceID: String
        let statusSourceRank: Int
        let isVisible: Bool
        let decision: ServerProviderServiceCutPlanDecision

        init(
            recommendationID: String,
            statusSourceID: String = "provider-service-cut-plan-status",
            statusSourceRank: Int = 0,
            isVisible: Bool = true,
            decision: ServerProviderServiceCutPlanDecision
        ) {
            self.recommendationID = recommendationID
            self.statusSourceID = Self.safeID(
                statusSourceID,
                fallback: "provider-service-cut-plan-status"
            )
            self.statusSourceRank = statusSourceRank
            self.isVisible = isVisible
            self.decision = decision
        }

        private static func safeID(
            _ value: String,
            fallback: String
        ) -> String {
            let normalized = value
                .lowercased()
                .map { character in
                    character.isLetter || character.isNumber ? String(character) : "-"
                }
                .joined()
            let slug = normalized
                .split(separator: "-")
                .joined(separator: "-")
            return slug.isEmpty ? fallback : slug
        }
    }

    func statusSource(
        inputs: [Input],
        renderedRecommendationIDs: [String]
    ) -> ServerProviderRenderedRuntimeStatusSource {
        ServerProviderRenderedRuntimeStatusSource(
            source: ServerProviderServiceCutPlanStatusStore(
                entries: inputs.map { input in
                    ServerProviderServiceCutPlanStatusStore.Entry(
                        recommendationID: input.recommendationID,
                        statusSourceID: input.statusSourceID,
                        statusSourceRank: input.statusSourceRank,
                        isVisible: input.isVisible,
                        decision: input.decision
                    )
                }
            ),
            renderedRecommendationIDs: renderedRecommendationIDs
        )
    }
}

struct ServerProviderServiceCutPlanStatusStore: ProviderStatusProviding {
    struct Entry: Hashable, Sendable {
        let recommendationID: String
        let statusSourceID: String
        let statusSourceRank: Int
        let isVisible: Bool
        let decision: ServerProviderServiceCutPlanDecision
    }

    private let entriesByRecommendationID: [String: Entry]

    nonisolated init(entries: [Entry]) {
        var indexed: [String: Entry] = [:]
        var seenRecommendationIDs: Set<String> = []
        for entry in entries
            where entry.isVisible && seenRecommendationIDs.insert(entry.recommendationID).inserted {
            indexed[entry.recommendationID] = entry
        }
        self.entriesByRecommendationID = indexed
    }

    nonisolated var recommendationIDs: [String] {
        entriesByRecommendationID.keys.sorted()
    }

    nonisolated func providerStatusPresentation(
        for recommendationID: String
    ) -> ProviderStatusPresentation? {
        guard let entry = entriesByRecommendationID[recommendationID] else {
            return nil
        }
        return ProviderStatusPresentation(
            recommendationID: recommendationID,
            badges: Self.badges(for: entry.decision),
            statusLine: Self.statusLine(for: entry),
            cardHint: Self.cardHint(for: entry.decision)
        )
    }

    nonisolated private static func badges(
        for decision: ServerProviderServiceCutPlanDecision
    ) -> [ProviderStatusBadgeModel] {
        switch decision.state {
        case .localReady:
            return localBadges(for: decision)
        case .serverReserved:
            return serverReservedBadges(for: decision)
        case .blocked:
            return [blockedBadge(for: decision)]
        case .unsupported:
            return [unavailableBadge()]
        }
    }

    nonisolated private static func localBadges(
        for decision: ServerProviderServiceCutPlanDecision
    ) -> [ProviderStatusBadgeModel] {
        if decision.selectedLane == .cacheFallback {
            return [
                ProviderStatusBadgeModel(
                    kind: .cacheProvider,
                    label: "Cache fallback",
                    systemImage: "archivebox",
                    tone: .neutral
                ),
            ]
        }
        return [
            ProviderStatusBadgeModel(
                kind: .localProvider,
                label: "Local service",
                systemImage: "iphone",
                tone: .positive
            ),
            costBadge(for: decision.costClass),
        ]
    }

    nonisolated private static func serverReservedBadges(
        for decision: ServerProviderServiceCutPlanDecision
    ) -> [ProviderStatusBadgeModel] {
        deduplicated([
            ProviderStatusBadgeModel(
                kind: .remoteProvider,
                label: "Server reserved",
                systemImage: "network",
                tone: .neutral
            ),
            costBadge(for: decision.costClass),
            lanePolicyBadge(for: decision),
        ])
    }

    nonisolated private static func lanePolicyBadge(
        for decision: ServerProviderServiceCutPlanDecision
    ) -> ProviderStatusBadgeModel {
        switch decision.selectedLane {
        case .serverSearchAPI, .reservedCrawler:
            return ProviderStatusBadgeModel(
                kind: .termsBlocked,
                label: "Source gated",
                systemImage: "checkmark.seal",
                tone: .neutral
            )
        case .reservedMCP:
            return ProviderStatusBadgeModel(
                kind: .termsBlocked,
                label: "Security gated",
                systemImage: "lock.shield",
                tone: .neutral
            )
        case .serverGoogleMaps, .serverGaode:
            return ProviderStatusBadgeModel(
                kind: .termsBlocked,
                label: "Attribution gated",
                systemImage: "map",
                tone: .neutral
            )
        case .localAppleMaps, .cacheFallback, nil:
            return costBadge(for: decision.costClass)
        }
    }

    nonisolated private static func blockedBadge(
        for decision: ServerProviderServiceCutPlanDecision
    ) -> ProviderStatusBadgeModel {
        if decision.blockReasons.contains(.privacyBlocked)
            || decision.blockReasons.contains(.privateDataBlocked) {
            return blockedPrivacyBadge()
        }
        if decision.blockReasons.contains(.membershipMissing)
            || decision.blockReasons.contains(.costPolicyMissing)
            || decision.blockReasons.contains(.quotaPolicyMissing) {
            return blockedCostBadge()
        }
        if decision.blockReasons.contains(.sourceCitationMissing)
            || decision.blockReasons.contains(.rawContentPolicyMissing)
            || decision.blockReasons.contains(.attributionCacheDisplayMissing)
            || decision.blockReasons.contains(.robotsPolicyMissingOrBlocked)
            || decision.blockReasons.contains(.descriptorUnverified)
            || decision.blockReasons.contains(.mcpAuthorizationMissing)
            || decision.blockReasons.contains(.tokenProtectionMissing) {
            return blockedTermsBadge()
        }
        return unavailableBadge()
    }

    nonisolated private static func statusLine(
        for entry: Entry
    ) -> String {
        let decision = entry.decision
        return deduplicatedStatusSegments([
            headline(for: decision),
            "State: \(decision.state.rawValue).",
            laneSegment(for: decision.selectedLane),
            "Intent: \(decision.serviceIntent.rawValue).",
            "Provider: \(decision.providerFamily.rawValue).",
            "Capability: \(decision.capability.rawValue).",
            "Membership: \(decision.membershipTier.rawValue).",
            "Region: \(decision.region.rawValue).",
            "Privacy: \(decision.privacyClass.rawValue).",
            "Cost: \(decision.costClass.rawValue).",
            gatesSegment(for: decision.requiredPriorGates),
            reasonsSegment(for: decision.blockReasons),
            "Status source: \(entry.statusSourceID).",
            "Rank: \(entry.statusSourceRank).",
            "isRuntimeCallable false.",
            "isExecutable false.",
            "No adapter has run.",
        ])
        .joined(separator: " ")
    }

    nonisolated private static func headline(
        for decision: ServerProviderServiceCutPlanDecision
    ) -> String {
        switch decision.state {
        case .localReady:
            return "Provider service cut-plan is local-ready planning copy."
        case .serverReserved:
            return "Provider service cut-plan is server-reserved planning copy."
        case .blocked:
            return "Provider service cut-plan is blocked by policy metadata."
        case .unsupported:
            return "Provider service cut-plan is unsupported for this lane."
        }
    }

    nonisolated private static func cardHint(
        for decision: ServerProviderServiceCutPlanDecision
    ) -> ProviderStatusCardHint {
        switch decision.state {
        case .localReady:
            return .normal
        case .serverReserved:
            return .warning
        case .blocked, .unsupported:
            return .disabled
        }
    }

    nonisolated private static func laneSegment(
        for lane: ServerProviderServiceLane?
    ) -> String {
        guard let lane else {
            return "Lane: none."
        }
        return "Lane: \(lane.rawValue)."
    }

    nonisolated private static func gatesSegment(
        for gates: [ServerProviderServiceGate]
    ) -> String {
        guard gates.isEmpty == false else {
            return "Required gates: none."
        }
        return "Required gates: \(gates.map(\.rawValue).joined(separator: ","))."
    }

    nonisolated private static func reasonsSegment(
        for reasons: [ServerProviderServiceCutPlanBlockReason]
    ) -> String {
        guard reasons.isEmpty == false else {
            return "Block reasons: none."
        }
        return "Block reasons: \(reasons.map(\.rawValue).joined(separator: ","))."
    }

    nonisolated private static func costBadge(
        for costClass: ProviderCostClass
    ) -> ProviderStatusBadgeModel {
        switch costClass {
        case .freeLocal:
            return ProviderStatusBadgeModel(
                kind: .freeLocal,
                label: "Free local",
                systemImage: "checkmark.shield",
                tone: .positive
            )
        case .includedQuota:
            return ProviderStatusBadgeModel(
                kind: .includedQuota,
                label: "Included quota",
                systemImage: "checkmark.seal",
                tone: .neutral
            )
        case .meteredPremium:
            return ProviderStatusBadgeModel(
                kind: .meteredPremium,
                label: "Premium metered",
                systemImage: "creditcard",
                tone: .neutral
            )
        case .blockedByCost:
            return blockedCostBadge()
        case .blockedByPrivacy:
            return blockedPrivacyBadge()
        case .blockedByTerms:
            return blockedTermsBadge()
        }
    }

    nonisolated private static func blockedPrivacyBadge() -> ProviderStatusBadgeModel {
        ProviderStatusBadgeModel(
            kind: .privacyBlocked,
            label: "Privacy blocked",
            systemImage: "lock.shield",
            tone: .warning
        )
    }

    nonisolated private static func blockedCostBadge() -> ProviderStatusBadgeModel {
        ProviderStatusBadgeModel(
            kind: .costBlocked,
            label: "Premium locked",
            systemImage: "lock.badge.clock",
            tone: .warning
        )
    }

    nonisolated private static func blockedTermsBadge() -> ProviderStatusBadgeModel {
        ProviderStatusBadgeModel(
            kind: .termsBlocked,
            label: "Policy gated",
            systemImage: "exclamationmark.triangle",
            tone: .warning
        )
    }

    nonisolated private static func unavailableBadge() -> ProviderStatusBadgeModel {
        ProviderStatusBadgeModel(
            kind: .unavailable,
            label: "Provider unavailable",
            systemImage: "wifi.slash",
            tone: .warning
        )
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
