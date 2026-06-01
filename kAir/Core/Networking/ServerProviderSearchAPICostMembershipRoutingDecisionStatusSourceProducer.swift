//
//  ServerProviderSearchAPICostMembershipRoutingDecisionStatusSourceProducer.swift
//  kAir
//
//  Pure rendered-id scoped provider-status projection for A171 Search API cost
//  and membership routing decisions. This packages advisory metadata only.
//

import Foundation

@MainActor
struct ServerProviderSearchAPICostMembershipRoutingDecisionStatusSourceProducer {
    struct Input: Hashable, Sendable {
        let recommendationID: String
        let statusSourceID: String
        let statusSourceRank: Int
        let isVisible: Bool
        let decision: ServerProviderSearchAPICostMembershipRoutingDecision

        init(
            recommendationID: String,
            statusSourceID: String = "search-api-cost-membership-routing-status",
            statusSourceRank: Int = 0,
            isVisible: Bool = true,
            decision: ServerProviderSearchAPICostMembershipRoutingDecision
        ) {
            self.recommendationID = recommendationID
            self.statusSourceID = Self.safeID(
                statusSourceID,
                fallback: "search-api-cost-membership-routing-status"
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
            source: ServerProviderSearchAPICostMembershipRoutingDecisionStatusStore(
                entries: inputs.map { input in
                    ServerProviderSearchAPICostMembershipRoutingDecisionStatusStore.Entry(
                        recommendationID: input.recommendationID,
                        statusSourceID: input.statusSourceID,
                        statusSourceRank: input.statusSourceRank,
                        isVisible: input.isVisible,
                        safeCopy: input.decision.safeCopy
                    )
                }
            ),
            renderedRecommendationIDs: renderedRecommendationIDs
        )
    }
}

struct ServerProviderSearchAPICostMembershipRoutingDecisionStatusStore:
    ProviderStatusProviding
{
    struct Entry: Hashable, Sendable {
        let recommendationID: String
        let statusSourceID: String
        let statusSourceRank: Int
        let isVisible: Bool
        let safeCopy: ServerProviderSearchAPICostMembershipRoutingDecisionSafeCopy
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
            badges: Self.badges(for: entry.safeCopy),
            statusLine: Self.statusLine(for: entry),
            cardHint: Self.cardHint(for: entry.safeCopy)
        )
    }

    nonisolated private static func badges(
        for safeCopy: ServerProviderSearchAPICostMembershipRoutingDecisionSafeCopy
    ) -> [ProviderStatusBadgeModel] {
        switch safeCopy.state {
        case .accepted:
            return acceptedBadges(for: safeCopy.selectedRouteKind)
        case .rejected:
            return [rejectionBadge(for: safeCopy.rejectionReason)]
        }
    }

    nonisolated private static func statusLine(
        for entry: Entry
    ) -> String {
        let safeCopy = entry.safeCopy
        switch safeCopy.state {
        case .accepted:
            return deduplicatedStatusSegments([
                "Search API cost membership routing is advisory status only.",
                routeSegment(for: safeCopy),
                membershipSegment(for: safeCopy.membershipTier),
                costSegment(for: safeCopy.requestedCostClass),
                regionSegment(for: safeCopy.region),
                privacySegment(for: safeCopy.privacyClass),
                idSegment(label: "Status source", id: entry.statusSourceID),
                "Rank: \(entry.statusSourceRank).",
                "isRuntimeCallable false.",
                "No transport or provider runtime has run.",
            ])
            .joined(separator: " ")
        case .rejected:
            return deduplicatedStatusSegments([
                "Search API cost membership routing is review-only status.",
                reasonSegment(for: safeCopy.rejectionReason),
                routeSegment(for: safeCopy),
                membershipSegment(for: safeCopy.membershipTier),
                costSegment(for: safeCopy.requestedCostClass),
                regionSegment(for: safeCopy.region),
                privacySegment(for: safeCopy.privacyClass),
                idSegment(label: "Status source", id: entry.statusSourceID),
                "Rank: \(entry.statusSourceRank).",
                "isRuntimeCallable false.",
                "No transport or provider runtime has run.",
            ])
            .joined(separator: " ")
        }
    }

    nonisolated private static func cardHint(
        for safeCopy: ServerProviderSearchAPICostMembershipRoutingDecisionSafeCopy
    ) -> ProviderStatusCardHint {
        switch safeCopy.state {
        case .accepted:
            return safeCopy.selectedRouteKind == .meteredAllowed ? .warning : .normal
        case .rejected:
            return safeCopy.rejectionReason == .regionReviewRequired ? .warning : .disabled
        }
    }

    nonisolated private static func acceptedBadges(
        for routeKind: ServerProviderSearchAPICostMembershipRouteKind?
    ) -> [ProviderStatusBadgeModel] {
        switch routeKind {
        case .localFallback:
            return deduplicated([
                localProviderBadge(),
                freeLocalBadge(),
            ])
        case .includedQuotaPreferred:
            return deduplicated([
                searchAPIBadge(),
                includedQuotaBadge(),
            ])
        case .meteredAllowed:
            return deduplicated([
                searchAPIBadge(),
                meteredBadge(),
            ])
        case .regionReview:
            return [regionReviewBadge()]
        case .costBlocked:
            return [blockedCostBadge()]
        case .unsupportedRoute, nil:
            return [unavailableBadge()]
        }
    }

    nonisolated private static func rejectionBadge(
        for reason: ServerProviderSearchAPICostMembershipRoutingDecisionRejectionReason?
    ) -> ProviderStatusBadgeModel {
        switch reason {
        case .privacyBlocksRemotePosture:
            return blockedPrivacyBadge()
        case .membershipTierNotEligible, .quotaUnavailable, .costClassBlocked:
            return blockedCostBadge()
        case .regionReviewRequired:
            return regionReviewBadge()
        case .preferredRouteNotAllowed:
            return blockedTermsBadge()
        case .invalidPlan, .membershipCoverageMissing, .routeUnavailable, nil:
            return unavailableBadge()
        }
    }

    nonisolated private static func routeSegment(
        for safeCopy: ServerProviderSearchAPICostMembershipRoutingDecisionSafeCopy
    ) -> String {
        guard let selectedRouteKind = safeCopy.selectedRouteKind else {
            return "Route: none."
        }
        let routeRank = safeCopy.selectedRouteRank.map(String.init) ?? "unavailable"
        return "Route: \(selectedRouteKind.rawValue), rank \(routeRank)."
    }

    nonisolated private static func reasonSegment(
        for reason: ServerProviderSearchAPICostMembershipRoutingDecisionRejectionReason?
    ) -> String {
        guard let reason else {
            return "Reason: unavailable."
        }
        return "Reason: \(reason.rawValue)."
    }

    nonisolated private static func membershipSegment(
        for membershipTier: MembershipTier
    ) -> String {
        "Membership: \(membershipTier.rawValue)."
    }

    nonisolated private static func costSegment(
        for costClass: ProviderCostClass
    ) -> String {
        "Cost: \(costClass.rawValue)."
    }

    nonisolated private static func regionSegment(
        for region: ProviderRegion
    ) -> String {
        "Region: \(region.rawValue)."
    }

    nonisolated private static func privacySegment(
        for privacyClass: ProviderPrivacyClass
    ) -> String {
        "Privacy: \(privacyClass.rawValue)."
    }

    nonisolated private static func idSegment(
        label: String,
        id: String
    ) -> String {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return "\(label): unavailable."
        }
        return "\(label): \(trimmed)."
    }

    nonisolated private static func localProviderBadge() -> ProviderStatusBadgeModel {
        ProviderStatusBadgeModel(
            kind: .localProvider,
            label: "Local provider",
            systemImage: "iphone",
            tone: .positive
        )
    }

    nonisolated private static func searchAPIBadge() -> ProviderStatusBadgeModel {
        ProviderStatusBadgeModel(
            kind: .remoteProvider,
            label: "Search API",
            systemImage: "network",
            tone: .neutral
        )
    }

    nonisolated private static func freeLocalBadge() -> ProviderStatusBadgeModel {
        ProviderStatusBadgeModel(
            kind: .freeLocal,
            label: "Free local",
            systemImage: "checkmark.shield",
            tone: .positive
        )
    }

    nonisolated private static func includedQuotaBadge() -> ProviderStatusBadgeModel {
        ProviderStatusBadgeModel(
            kind: .includedQuota,
            label: "Included quota",
            systemImage: "checkmark.seal",
            tone: .neutral
        )
    }

    nonisolated private static func meteredBadge() -> ProviderStatusBadgeModel {
        ProviderStatusBadgeModel(
            kind: .meteredPremium,
            label: "Premium metered",
            systemImage: "creditcard",
            tone: .neutral
        )
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
            label: "Provider blocked",
            systemImage: "exclamationmark.triangle",
            tone: .warning
        )
    }

    nonisolated private static func regionReviewBadge() -> ProviderStatusBadgeModel {
        ProviderStatusBadgeModel(
            kind: .termsBlocked,
            label: "Region review",
            systemImage: "globe.asia.australia",
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
        var output: [ProviderStatusBadgeModel] = []
        for badge in badges where seen.insert(badge.kind).inserted {
            output.append(badge)
        }
        return output
    }

    nonisolated private static func deduplicatedStatusSegments(
        _ segments: [String]
    ) -> [String] {
        var seen: Set<String> = []
        var output: [String] = []
        for segment in segments {
            let trimmed = segment.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false,
                  seen.insert(trimmed).inserted else {
                continue
            }
            output.append(trimmed)
        }
        return output
    }
}
