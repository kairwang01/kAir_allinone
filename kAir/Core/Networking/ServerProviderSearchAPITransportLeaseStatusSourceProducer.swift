//
//  ServerProviderSearchAPITransportLeaseStatusSourceProducer.swift
//  kAir
//
//  Pure rendered-id scoped provider-status projection for Search API transport
//  lease results.
//

import Foundation

@MainActor
struct ServerProviderSearchAPITransportLeaseStatusSourceProducer {
    struct Input: Hashable, Sendable {
        let recommendationID: String
        let lease: ServerProviderSearchAPITransportLease
    }

    func statusSource(
        leases inputs: [Input],
        renderedRecommendationIDs: [String]
    ) -> ServerProviderRenderedRuntimeStatusSource {
        ServerProviderRenderedRuntimeStatusSource(
            source: SearchAPITransportLeaseProviderStatusStore(
                leases: inputs.map { input in
                    (
                        recommendationID: input.recommendationID,
                        lease: input.lease
                    )
                }
            ),
            renderedRecommendationIDs: renderedRecommendationIDs
        )
    }
}

struct SearchAPITransportLeaseProviderStatusStore: ProviderStatusProviding {
    private let leasesByRecommendationID: [String: ServerProviderSearchAPITransportLease]

    nonisolated init(
        leasesByRecommendationID: [String: ServerProviderSearchAPITransportLease]
    ) {
        self.leasesByRecommendationID = leasesByRecommendationID
    }

    nonisolated init(
        leases: [(recommendationID: String, lease: ServerProviderSearchAPITransportLease)]
    ) {
        var indexed: [String: ServerProviderSearchAPITransportLease] = [:]
        var seenRecommendationIDs: Set<String> = []
        for entry in leases where seenRecommendationIDs.insert(entry.recommendationID).inserted {
            indexed[entry.recommendationID] = entry.lease
        }
        self.leasesByRecommendationID = indexed
    }

    nonisolated var recommendationIDs: [String] {
        leasesByRecommendationID.keys.sorted()
    }

    nonisolated func providerStatusPresentation(
        for recommendationID: String
    ) -> ProviderStatusPresentation? {
        guard let lease = leasesByRecommendationID[recommendationID] else {
            return nil
        }
        return ProviderStatusPresentation(
            recommendationID: recommendationID,
            badges: Self.badges(for: lease),
            statusLine: Self.statusLine(for: lease),
            cardHint: Self.cardHint(for: lease)
        )
    }

    nonisolated private static func badges(
        for lease: ServerProviderSearchAPITransportLease
    ) -> [ProviderStatusBadgeModel] {
        switch lease.state {
        case .issued:
            var badges = [
                providerBadge(for: lease.providerFamily),
            ]
            if let costClass = lease.costClass {
                badges.append(costBadge(for: costClass))
            }
            if let freshness = lease.freshness,
               let freshnessBadge = freshnessBadge(for: freshness) {
                badges.append(freshnessBadge)
            }
            return deduplicated(badges)
        case .rejected:
            return [rejectionBadge(for: lease)]
        }
    }

    nonisolated private static func statusLine(
        for lease: ServerProviderSearchAPITransportLease
    ) -> String {
        let segments: [String]

        switch lease.state {
        case .issued:
            segments = [
                "Search API transport lease ready from verified metadata only.",
                "Lease: \(lease.id).",
                idSegment(label: "Payload", id: lease.payloadID),
                idSegment(label: "Dispatch", id: lease.dispatchReceiptID),
                idSegment(label: "Authorization", id: lease.authorizationID),
                "Budget: \(lease.budgetID).",
                vendorSegment(for: lease),
                providerSegment(for: lease),
                capabilitySegment(for: lease),
                costSegment(for: lease),
                freshnessSegment(for: lease),
                resultShapeSegment(for: lease),
                resultLimitSegment(for: lease),
                sourceSegment(for: lease),
                citationSegment(for: lease),
                "No transport or provider runtime has run.",
            ]
        case .rejected:
            segments = [
                "Search API transport lease is blocked by metadata policy.",
                "Lease: \(lease.id).",
                "Budget: \(lease.budgetID).",
                leaseRejectionSegment(for: lease.rejection),
                payloadRejectionSegment(for: lease.payloadRejection),
                dispatchRejectionSegment(for: lease.dispatchRejection),
                authorizationRejectionSegment(for: lease.authorizationRejection),
                vendorSegment(for: lease),
                "No transport or provider runtime has run.",
            ]
        }

        return deduplicatedStatusSegments(segments)
            .joined(separator: " ")
    }

    nonisolated private static func cardHint(
        for lease: ServerProviderSearchAPITransportLease
    ) -> ProviderStatusCardHint {
        guard lease.state == .issued else {
            return .disabled
        }
        return lease.costClass == .meteredPremium ? .warning : .normal
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
        for lease: ServerProviderSearchAPITransportLease
    ) -> ProviderStatusBadgeModel {
        switch lease.rejection {
        case .providerDisabled, .providerNotAllowed, .entitlementMissing,
             .meteredEntitlementMissing, .includedQuotaExhausted,
             .meteredEligibilityMissing,
             .explicitBudgetDenied, .costClassMismatch:
            return blockedCostBadge()
        case .freshnessMismatch:
            return ProviderStatusBadgeModel(
                kind: .staleCache,
                label: "Stale cache",
                systemImage: "clock.arrow.circlepath",
                tone: .warning
            )
        case .missingPayloadDecision, .payloadNotPrepared, .missingPayload,
             .missingDispatchReceipt, .dispatchNotEligible,
             .missingAuthorization, .authorizationNotAccepted,
             .payloadDispatchMismatch, .dispatchAuthorizationMismatch:
            return unavailableBadge()
        case .providerFamilyMismatch, .vendorMismatch, .capabilityMismatch,
             .resultShapeMismatch, .sourcePolicyInsufficient,
             .citationPolicyMissing, .none:
            return blockedTermsBadge()
        }
    }

    nonisolated private static func blockedCostBadge() -> ProviderStatusBadgeModel {
        ProviderStatusBadgeModel(
            kind: .costBlocked,
            label: "Premium locked",
            systemImage: "lock.badge.clock",
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

    nonisolated private static func idSegment(
        label: String,
        id: String?
    ) -> String {
        guard let id,
              id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return "\(label): unavailable."
        }
        return "\(label): \(id)."
    }

    nonisolated private static func vendorSegment(
        for lease: ServerProviderSearchAPITransportLease
    ) -> String {
        guard let vendorID = lease.vendorID,
              vendorID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return "Vendor: unavailable."
        }
        return "Vendor: \(vendorID)."
    }

    nonisolated private static func providerSegment(
        for lease: ServerProviderSearchAPITransportLease
    ) -> String {
        guard let providerFamily = lease.providerFamily else {
            return "Provider: unavailable."
        }
        return "Provider: \(providerFamily.rawValue)."
    }

    nonisolated private static func capabilitySegment(
        for lease: ServerProviderSearchAPITransportLease
    ) -> String {
        guard let capability = lease.capability else {
            return "Capability: unavailable."
        }
        return "Capability: \(capability.rawValue)."
    }

    nonisolated private static func costSegment(
        for lease: ServerProviderSearchAPITransportLease
    ) -> String {
        guard let costClass = lease.costClass else {
            return "Cost: unavailable."
        }
        return "Cost: \(costClass.rawValue)."
    }

    nonisolated private static func freshnessSegment(
        for lease: ServerProviderSearchAPITransportLease
    ) -> String {
        guard let freshness = lease.freshness else {
            return "Freshness: unavailable."
        }
        return "Freshness: \(freshness.rawValue)."
    }

    nonisolated private static func resultShapeSegment(
        for lease: ServerProviderSearchAPITransportLease
    ) -> String {
        guard let resultShape = lease.resultShape else {
            return "Result shape: unavailable."
        }
        return "Result shape: \(resultShape.rawValue)."
    }

    nonisolated private static func resultLimitSegment(
        for lease: ServerProviderSearchAPITransportLease
    ) -> String {
        guard let resultLimit = lease.resultLimit else {
            return "Result limit: unavailable."
        }
        return "Result limit: \(resultLimit)."
    }

    nonisolated private static func sourceSegment(
        for lease: ServerProviderSearchAPITransportLease
    ) -> String {
        guard let sourceState = lease.sourceState else {
            return "Source policy: unavailable."
        }
        return "Source policy: \(sourceState.rawValue)."
    }

    nonisolated private static func citationSegment(
        for lease: ServerProviderSearchAPITransportLease
    ) -> String {
        guard let citationRequired = lease.citationRequired else {
            return "Citation required: unavailable."
        }
        return "Citation required: \(citationRequired)."
    }

    nonisolated private static func leaseRejectionSegment(
        for reason: ServerProviderSearchAPITransportLeaseRejectionReason?
    ) -> String {
        guard let reason else {
            return "Lease reason: unavailable."
        }
        return "Lease reason: \(reason.rawValue)."
    }

    nonisolated private static func payloadRejectionSegment(
        for reason: ServerProviderSearchAPIAdapterPayloadRejectionReason?
    ) -> String {
        guard let reason else {
            return ""
        }
        return "Payload reason: \(reason.rawValue)."
    }

    nonisolated private static func dispatchRejectionSegment(
        for reason: ServerProviderSearchAPIAdapterPayloadDispatchRejectionReason?
    ) -> String {
        guard let reason else {
            return ""
        }
        return "Dispatch reason: \(reason.rawValue)."
    }

    nonisolated private static func authorizationRejectionSegment(
        for reason: ServerProviderSearchAPIVendorPolicyDispatchAuthorizationRejectionReason?
    ) -> String {
        guard let reason else {
            return ""
        }
        return "Authorization reason: \(reason.rawValue)."
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
