//
//  ServerProviderSearchAPIAdapterPayloadDispatchStatusSourceProducer.swift
//  kAir
//
//  Pure rendered-id scoped provider-status projection for Search API adapter
//  payload dispatch receipts.
//

import Foundation

@MainActor
struct ServerProviderSearchAPIAdapterPayloadDispatchStatusSourceProducer {
    struct ReceiptInput: Hashable, Sendable {
        let recommendationID: String
        let receipt: ServerProviderSearchAPIAdapterPayloadDispatchReceipt
    }

    func statusSource(
        receipts inputs: [ReceiptInput],
        renderedRecommendationIDs: [String]
    ) -> ServerProviderRenderedRuntimeStatusSource {
        ServerProviderRenderedRuntimeStatusSource(
            source: ServerProviderSearchAPIAdapterPayloadDispatchStatusStore(
                receipts: inputs.map { input in
                    (
                        recommendationID: input.recommendationID,
                        receipt: input.receipt
                    )
                }
            ),
            renderedRecommendationIDs: renderedRecommendationIDs
        )
    }
}

struct ServerProviderSearchAPIAdapterPayloadDispatchStatusStore: ProviderStatusProviding {
    private let receiptsByRecommendationID: [String: ServerProviderSearchAPIAdapterPayloadDispatchReceipt]

    nonisolated init(
        receiptsByRecommendationID: [String: ServerProviderSearchAPIAdapterPayloadDispatchReceipt]
    ) {
        self.receiptsByRecommendationID = receiptsByRecommendationID
    }

    nonisolated init(
        receipts: [(recommendationID: String, receipt: ServerProviderSearchAPIAdapterPayloadDispatchReceipt)]
    ) {
        var indexed: [String: ServerProviderSearchAPIAdapterPayloadDispatchReceipt] = [:]
        var seenRecommendationIDs: Set<String> = []
        for entry in receipts where seenRecommendationIDs.insert(entry.recommendationID).inserted {
            indexed[entry.recommendationID] = entry.receipt
        }
        self.receiptsByRecommendationID = indexed
    }

    nonisolated var recommendationIDs: [String] {
        receiptsByRecommendationID.keys.sorted()
    }

    nonisolated func providerStatusPresentation(
        for recommendationID: String
    ) -> ProviderStatusPresentation? {
        guard let receipt = receiptsByRecommendationID[recommendationID] else {
            return nil
        }
        return ProviderStatusPresentation(
            recommendationID: recommendationID,
            badges: Self.badges(for: receipt),
            statusLine: Self.statusLine(for: receipt),
            cardHint: Self.cardHint(for: receipt)
        )
    }

    nonisolated private static func badges(
        for receipt: ServerProviderSearchAPIAdapterPayloadDispatchReceipt
    ) -> [ProviderStatusBadgeModel] {
        switch receipt.state {
        case .dispatchEligible:
            var badges = [
                providerBadge(for: receipt.providerFamily),
                costBadge(for: receipt.costClass),
            ]
            if let freshness = receipt.freshness,
               let freshnessBadge = freshnessBadge(for: freshness) {
                badges.append(freshnessBadge)
            }
            return deduplicated(badges)
        case .blocked:
            return [rejectionBadge(for: receipt)]
        }
    }

    nonisolated private static func statusLine(
        for receipt: ServerProviderSearchAPIAdapterPayloadDispatchReceipt
    ) -> String {
        let segments: [String]

        switch receipt.state {
        case .dispatchEligible:
            segments = [
                "Search API adapter dispatch-ready metadata is verified for future transport gating only.",
                "Request id: \(receipt.requestID).",
                payloadIDSegment(for: receipt),
                capabilitySegment(for: receipt),
                costSegment(for: receipt),
                freshnessSegment(for: receipt),
                sourceSegment(for: receipt),
                "No transport or provider runtime has run.",
            ]
        case .blocked:
            segments = [
                "Search API adapter dispatch status is blocked by metadata policy.",
                "Request id: \(receipt.requestID).",
                payloadIDSegment(for: receipt),
                rejectionSegment(for: receipt),
                payloadDecisionRejectionSegment(for: receipt),
                requestDecisionRejectionSegment(for: receipt),
                "No transport or provider runtime has run.",
            ]
        }

        return deduplicatedStatusSegments(segments)
            .joined(separator: " ")
    }

    nonisolated private static func cardHint(
        for receipt: ServerProviderSearchAPIAdapterPayloadDispatchReceipt
    ) -> ProviderStatusCardHint {
        switch receipt.state {
        case .dispatchEligible:
            return receipt.costClass == .meteredPremium ? .warning : .normal
        case .blocked:
            return .disabled
        }
    }

    nonisolated private static func payloadIDSegment(
        for receipt: ServerProviderSearchAPIAdapterPayloadDispatchReceipt
    ) -> String {
        guard let payloadID = receipt.payloadID,
              payloadID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return "Payload id: unavailable."
        }
        return "Payload id: \(payloadID)."
    }

    nonisolated private static func capabilitySegment(
        for receipt: ServerProviderSearchAPIAdapterPayloadDispatchReceipt
    ) -> String {
        guard let capability = receipt.capability else {
            return "Capability: unavailable."
        }
        return "Capability: \(capability.rawValue)."
    }

    nonisolated private static func costSegment(
        for receipt: ServerProviderSearchAPIAdapterPayloadDispatchReceipt
    ) -> String {
        guard let costClass = receipt.costClass else {
            return "Cost: unavailable."
        }
        return "Cost: \(costClass.rawValue)."
    }

    nonisolated private static func freshnessSegment(
        for receipt: ServerProviderSearchAPIAdapterPayloadDispatchReceipt
    ) -> String {
        guard let freshness = receipt.freshness else {
            return "Freshness: unavailable."
        }
        return "Freshness: \(freshness.rawValue)."
    }

    nonisolated private static func sourceSegment(
        for receipt: ServerProviderSearchAPIAdapterPayloadDispatchReceipt
    ) -> String {
        guard let sourcePolicy = receipt.sourcePolicy else {
            return "Source policy: unavailable."
        }
        var details = ["Source: \(sourcePolicy.sourceState.rawValue)"]
        if sourcePolicy.robotsState != .notApplicable {
            details.append("robots \(sourcePolicy.robotsState.rawValue)")
        }
        if sourcePolicy.citationRequired {
            details.append("citation required")
        }
        if let sourceHost = sourcePolicy.sourceHost,
           sourceHost.isEmpty == false {
            details.append(sourceHost)
        }
        return details.joined(separator: " · ") + "."
    }

    nonisolated private static func rejectionSegment(
        for receipt: ServerProviderSearchAPIAdapterPayloadDispatchReceipt
    ) -> String {
        guard let rejection = receipt.rejection else {
            return "Dispatch reason: unavailable."
        }
        return "Dispatch reason: \(rejection.rawValue)."
    }

    nonisolated private static func payloadDecisionRejectionSegment(
        for receipt: ServerProviderSearchAPIAdapterPayloadDispatchReceipt
    ) -> String {
        guard let rejection = receipt.payloadDecisionRejection else {
            return ""
        }
        return "Payload decision reason: \(rejection.rawValue)."
    }

    nonisolated private static func requestDecisionRejectionSegment(
        for receipt: ServerProviderSearchAPIAdapterPayloadDispatchReceipt
    ) -> String {
        guard let rejection = receipt.requestDecisionRejection else {
            return ""
        }
        return "Request decision reason: \(rejection.rawValue)."
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
        for receipt: ServerProviderSearchAPIAdapterPayloadDispatchReceipt
    ) -> ProviderStatusBadgeModel {
        if receipt.requestDecisionRejection == .privacyBlocked
            || receipt.rejection == .privacyBlocked {
            return blockedPrivacyBadge()
        }
        if receipt.requestDecisionRejection == .quotaBlocked
            || receipt.payloadDecisionRejection == .quotaBlocked
            || receipt.rejection == .quotaBlocked {
            return blockedCostBadge()
        }
        switch receipt.rejection {
        case .payloadDecisionRejected, .missingPayload:
            return unavailableBadge()
        case .sourcePolicyInsufficient, .citationPolicyMissing,
             .queryMismatch, .sourcePolicyMismatch, .emptyQuery,
             .providerFamilyNotSearchAPI, .unsupportedCapability,
             .invalidResultLimit, .requestIDMismatch, .traceIDMismatch,
             .providerFamilyMismatch, .capabilityMismatch, .freshnessMismatch,
             .costClassMismatch, .resultLimitMismatch:
            return blockedTermsBadge()
        case .privacyBlocked:
            return blockedPrivacyBadge()
        case .quotaBlocked:
            return blockedCostBadge()
        case nil:
            return unavailableBadge()
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
