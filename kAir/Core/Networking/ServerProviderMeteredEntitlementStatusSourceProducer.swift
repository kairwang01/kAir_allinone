//
//  ServerProviderMeteredEntitlementStatusSourceProducer.swift
//  kAir
//
//  Pure rendered-id scoped provider-status projection for server-verified
//  metered entitlement decisions. This file packages metadata copy only; it
//  does not hold network addresses, credentials, transports, provider
//  runtimes, unredacted prompt text, source bodies, or UI state.
//

import Foundation

@MainActor
struct ServerProviderMeteredEntitlementStatusSourceProducer {
    struct Input: Hashable, Sendable {
        let recommendationID: String
        let decision: ServerProviderMeteredUsageDecision
    }

    func statusSource(
        inputs: [Input],
        renderedRecommendationIDs: [String]
    ) -> ServerProviderRenderedRuntimeStatusSource {
        ServerProviderRenderedRuntimeStatusSource(
            source: ServerProviderMeteredEntitlementStatusStore(
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

struct ServerProviderMeteredEntitlementStatusStore: ProviderStatusProviding {
    private let decisionsByRecommendationID: [String: ServerProviderMeteredUsageDecision]

    nonisolated init(
        decisionsByRecommendationID: [String: ServerProviderMeteredUsageDecision]
    ) {
        self.decisionsByRecommendationID = decisionsByRecommendationID
    }

    nonisolated init(
        decisions: [(recommendationID: String, decision: ServerProviderMeteredUsageDecision)]
    ) {
        var indexed: [String: ServerProviderMeteredUsageDecision] = [:]
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
        for decision: ServerProviderMeteredUsageDecision
    ) -> [ProviderStatusBadgeModel] {
        switch decision.state {
        case .accepted:
            var badges = [
                providerBadge(for: decision.providerFamily),
                costBadge(for: decision.costClass),
            ]
            if let freshness = decision.freshness,
               let freshnessBadge = freshnessBadge(for: freshness) {
                badges.append(freshnessBadge)
            }
            return deduplicated(badges)
        case .rejected:
            return [rejectionBadge(for: decision.denialReason)]
        }
    }

    nonisolated private static func statusLine(
        for decision: ServerProviderMeteredUsageDecision
    ) -> String {
        switch decision.state {
        case .accepted:
            return deduplicatedStatusSegments([
                "Server provider metered entitlement is accepted from budget metadata only.",
                providerSegment(for: decision.providerFamily),
                vendorSegment(for: decision.vendorID),
                quotaSegment(for: decision.quotaPeriodID),
                unitsSegment(for: decision),
                costSegment(for: decision.costClass),
                freshnessSegment(for: decision.freshness),
                "No transport or provider runtime has run.",
            ])
            .joined(separator: " ")
        case .rejected:
            return deduplicatedStatusSegments([
                "Server provider metered entitlement is blocked by budget metadata policy.",
                denialSegment(for: decision.denialReason),
                "No transport or provider runtime has run.",
            ])
            .joined(separator: " ")
        }
    }

    nonisolated private static func cardHint(
        for decision: ServerProviderMeteredUsageDecision
    ) -> ProviderStatusCardHint {
        switch decision.state {
        case .accepted:
            return decision.costClass == .meteredPremium ? .warning : .normal
        case .rejected:
            return .disabled
        }
    }

    nonisolated private static func providerBadge(
        for providerFamily: ProviderFamily?
    ) -> ProviderStatusBadgeModel {
        switch providerFamily {
        case .appleLocal:
            return ProviderStatusBadgeModel(
                kind: .localProvider,
                label: "Local provider",
                systemImage: "iphone",
                tone: .positive
            )
        case .cache:
            return ProviderStatusBadgeModel(
                kind: .cacheProvider,
                label: "Cached provider",
                systemImage: "archivebox",
                tone: .neutral
            )
        case .gaode, .googleMaps, .searchAPI, .crawler, .mcp:
            return ProviderStatusBadgeModel(
                kind: .remoteProvider,
                label: "Remote provider",
                systemImage: "network",
                tone: .neutral
            )
        case nil:
            return unavailableBadge()
        }
    }

    nonisolated private static func costBadge(
        for costClass: ProviderCostClass?
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
        case nil:
            return unavailableBadge()
        }
    }

    nonisolated private static func freshnessBadge(
        for freshness: ProviderFreshness
    ) -> ProviderStatusBadgeModel? {
        switch freshness {
        case .cachedOK:
            return nil
        case .livePreferred, .liveRequired:
            return ProviderStatusBadgeModel(
                kind: .liveFreshness,
                label: "Live freshness",
                systemImage: "dot.radiowaves.left.and.right",
                tone: .positive
            )
        }
    }

    nonisolated private static func rejectionBadge(
        for reason: ServerProviderMeteredUsageDenialReason?
    ) -> ProviderStatusBadgeModel {
        switch reason {
        case .privacyBlocked, .healthContextBlocked:
            return blockedPrivacyBadge()
        case .overQuota, .membershipMissing, .entitlementMissing,
             .alreadyReservedBudget, .unsupportedCostClass:
            return blockedCostBadge()
        case .staleSnapshot:
            return ProviderStatusBadgeModel(
                kind: .staleCache,
                label: "Stale cache",
                systemImage: "clock.arrow.circlepath",
                tone: .warning
            )
        case .providerFamilyMismatch, .vendorMismatch, .capabilityMismatch,
             .vendorDisabled, .currencyMismatch, .unitMismatch:
            return blockedTermsBadge()
        case .missingSnapshot, nil:
            return unavailableBadge()
        }
    }

    nonisolated private static func providerSegment(
        for providerFamily: ProviderFamily?
    ) -> String {
        guard let providerFamily else {
            return "Provider: unavailable."
        }
        return "Provider: \(providerFamily.rawValue)."
    }

    nonisolated private static func vendorSegment(
        for vendorID: String?
    ) -> String {
        guard let vendorID,
              vendorID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return "Vendor: unavailable."
        }
        return "Vendor: \(vendorID)."
    }

    nonisolated private static func quotaSegment(
        for quotaPeriodID: String?
    ) -> String {
        guard let quotaPeriodID,
              quotaPeriodID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return "Quota period: unavailable."
        }
        return "Quota period: \(quotaPeriodID)."
    }

    nonisolated private static func unitsSegment(
        for decision: ServerProviderMeteredUsageDecision
    ) -> String {
        let remaining = decision.remainingUnitsAfter.map(String.init) ?? "unavailable"
        let reserved = decision.reservedUnitsAfter.map(String.init) ?? "unavailable"
        let unitLabel = decision.unitLabel ?? "UNIT"
        return [
            "Units:",
            "\(remaining) remaining,",
            "\(reserved) reserved,",
            "estimate \(decision.estimatedUnits) \(unitLabel).",
        ]
            .joined(separator: " ")
    }

    nonisolated private static func costSegment(
        for costClass: ProviderCostClass?
    ) -> String {
        guard let costClass else {
            return "Cost: unavailable."
        }
        return "Cost: \(costClass.rawValue)."
    }

    nonisolated private static func freshnessSegment(
        for freshness: ProviderFreshness?
    ) -> String {
        guard let freshness else {
            return "Freshness: unavailable."
        }
        return "Freshness: \(freshness.rawValue)."
    }

    nonisolated private static func denialSegment(
        for reason: ServerProviderMeteredUsageDenialReason?
    ) -> String {
        guard let reason else {
            return "Budget reason: unavailable."
        }
        return "Budget reason: \(reason.rawValue)."
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
