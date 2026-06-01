//
//  ServerProviderSearchAPIRoutePolicyCompatibilityStatusSourceProducer.swift
//  kAir
//
//  Pure rendered-id scoped provider-status projection for A177 Search API
//  route-policy compatibility decisions. This packages safe copy only.
//

import Foundation

@MainActor
struct ServerProviderSearchAPIRoutePolicyCompatibilityStatusSourceProducer {
    struct Input: Hashable, Sendable {
        let recommendationID: String
        let statusSourceID: String
        let statusSourceRank: Int
        let isVisible: Bool
        let decision: ServerProviderSearchAPIRoutePolicyCompatibilityDecision

        init(
            recommendationID: String,
            statusSourceID: String = "search-api-route-policy-compatibility-status",
            statusSourceRank: Int = 0,
            isVisible: Bool = true,
            decision: ServerProviderSearchAPIRoutePolicyCompatibilityDecision
        ) {
            self.recommendationID = recommendationID
            self.statusSourceID = Self.safeID(
                statusSourceID,
                fallback: "search-api-route-policy-compatibility-status"
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
            source: ServerProviderSearchAPIRoutePolicyCompatibilityStatusStore(
                entries: inputs.map { input in
                    ServerProviderSearchAPIRoutePolicyCompatibilityStatusStore.Entry(
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

struct ServerProviderSearchAPIRoutePolicyCompatibilityStatusStore:
    ProviderStatusProviding
{
    struct Entry: Hashable, Sendable {
        let recommendationID: String
        let statusSourceID: String
        let statusSourceRank: Int
        let isVisible: Bool
        let safeCopy: ServerProviderSearchAPIRoutePolicyCompatibilitySafeCopy
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
        for safeCopy: ServerProviderSearchAPIRoutePolicyCompatibilitySafeCopy
    ) -> [ProviderStatusBadgeModel] {
        switch safeCopy.state {
        case .compatible:
            return compatibleBadges(for: safeCopy)
        case .rejected:
            return [rejectionBadge(for: safeCopy.rejectionReason)]
        }
    }

    nonisolated private static func statusLine(
        for entry: Entry
    ) -> String {
        let safeCopy = entry.safeCopy
        switch safeCopy.state {
        case .compatible:
            return deduplicatedStatusSegments([
                "Search API route-policy compatibility is advisory status only.",
                routeSegment(for: safeCopy.routeKind),
                providerSegment(for: safeCopy.providerFamily),
                capabilitySegment(for: safeCopy.capability),
                vendorSegment(for: safeCopy.vendorID),
                membershipSegment(for: safeCopy.membershipTier),
                costSegment(for: safeCopy.costClass),
                quotaSegment(for: safeCopy.quotaPosture),
                sourceSegment(for: safeCopy.sourceCitationPosture),
                idSegment(label: "Route decision", id: safeCopy.routingDecisionID),
                idSegment(label: "Metered decision", id: safeCopy.meteredDecisionID),
                idSegment(label: "Vendor policy", id: safeCopy.vendorPolicyDecisionID),
                idSegment(label: "Dispatch", id: safeCopy.payloadDispatchReceiptID),
                idSegment(label: "Authorization", id: safeCopy.dispatchAuthorizationID),
                idSegment(label: "Lease", id: safeCopy.transportLeaseID),
                idSegment(label: "Status source", id: entry.statusSourceID),
                "Rank: \(entry.statusSourceRank).",
                "isRuntimeCallable false.",
                "isExecutable false.",
                "No transport or provider runtime has run.",
            ])
            .joined(separator: " ")
        case .rejected:
            return deduplicatedStatusSegments([
                "Search API route-policy compatibility is disabled by policy.",
                reasonSegment(for: safeCopy.rejectionReason),
                routeSegment(for: safeCopy.routeKind),
                providerSegment(for: safeCopy.providerFamily),
                capabilitySegment(for: safeCopy.capability),
                vendorSegment(for: safeCopy.vendorID),
                membershipSegment(for: safeCopy.membershipTier),
                costSegment(for: safeCopy.costClass),
                quotaSegment(for: safeCopy.quotaPosture),
                sourceSegment(for: safeCopy.sourceCitationPosture),
                idSegment(label: "Status source", id: entry.statusSourceID),
                "Rank: \(entry.statusSourceRank).",
                "isRuntimeCallable false.",
                "isExecutable false.",
                "No transport or provider runtime has run.",
            ])
            .joined(separator: " ")
        }
    }

    nonisolated private static func cardHint(
        for safeCopy: ServerProviderSearchAPIRoutePolicyCompatibilitySafeCopy
    ) -> ProviderStatusCardHint {
        switch safeCopy.state {
        case .compatible:
            return safeCopy.quotaPosture == .meteredPremium ? .warning : .normal
        case .rejected:
            return safeCopy.rejectionReason == .staleOrHiddenSourceMarkers ? .warning : .disabled
        }
    }

    nonisolated private static func compatibleBadges(
        for safeCopy: ServerProviderSearchAPIRoutePolicyCompatibilitySafeCopy
    ) -> [ProviderStatusBadgeModel] {
        var badges = [
            searchAPIBadge(),
            costBadge(for: safeCopy.costClass),
        ]
        if safeCopy.sourceCitationPosture == .passedCitationRequired {
            badges.append(sourceCitedBadge())
        }
        return deduplicated(badges)
    }

    nonisolated private static func rejectionBadge(
        for reason: ServerProviderSearchAPIRoutePolicyCompatibilityRejectionReason?
    ) -> ProviderStatusBadgeModel {
        switch reason {
        case .localFallbackRoute:
            return localProviderBadge()
        case .meteredEntitlementRejected, .costClassMismatch,
             .membershipTierMismatch, .routeKindCostPostureMismatch,
             .quotaPostureMismatch:
            return blockedCostBadge()
        case .vendorPolicyRejected, .payloadDispatchBlocked,
             .dispatchAuthorizationRejected, .sourceCitationPostureMismatch:
            return blockedTermsBadge()
        case .staleOrHiddenSourceMarkers:
            return staleCacheBadge()
        case .routingRejected, .missingSelectedRoute, .leaseRejected,
             .providerFamilyMismatch, .vendorMismatch, .capabilityMismatch,
             .leaseIDMismatch, .missingAuditID, .unsafeStatusSourceMetadata, nil:
            return unavailableBadge()
        }
    }

    nonisolated private static func routeSegment(
        for routeKind: ServerProviderSearchAPICostMembershipRouteKind
    ) -> String {
        "Route: \(routeKind.rawValue)."
    }

    nonisolated private static func providerSegment(
        for providerFamily: ProviderFamily
    ) -> String {
        "Provider: \(providerFamily.rawValue)."
    }

    nonisolated private static func capabilitySegment(
        for capability: ProviderCapability
    ) -> String {
        "Capability: \(capability.rawValue)."
    }

    nonisolated private static func vendorSegment(
        for vendorID: String
    ) -> String {
        idSegment(label: "Vendor", id: vendorID)
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

    nonisolated private static func quotaSegment(
        for quotaPosture: ServerProviderSearchAPIRoutePolicyQuotaPosture
    ) -> String {
        "Quota: \(quotaPosture.rawValue)."
    }

    nonisolated private static func sourceSegment(
        for sourcePosture: ServerProviderSearchAPIRoutePolicySourceCitationPosture
    ) -> String {
        "Source: \(sourcePosture.rawValue)."
    }

    nonisolated private static func reasonSegment(
        for reason: ServerProviderSearchAPIRoutePolicyCompatibilityRejectionReason?
    ) -> String {
        guard let reason else {
            return "Reason: unavailable."
        }
        return "Reason: \(reason.rawValue)."
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
            label: "Search API policy",
            systemImage: "network.badge.shield.half.filled",
            tone: .neutral
        )
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

    nonisolated private static func sourceCitedBadge() -> ProviderStatusBadgeModel {
        ProviderStatusBadgeModel(
            kind: .liveFreshness,
            label: "Source cited",
            systemImage: "quote.bubble",
            tone: .neutral
        )
    }

    nonisolated private static func staleCacheBadge() -> ProviderStatusBadgeModel {
        ProviderStatusBadgeModel(
            kind: .staleCache,
            label: "Status stale",
            systemImage: "clock.arrow.circlepath",
            tone: .warning
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
