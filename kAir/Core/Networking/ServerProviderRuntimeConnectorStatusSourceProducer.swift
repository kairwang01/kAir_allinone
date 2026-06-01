//
//  ServerProviderRuntimeConnectorStatusSourceProducer.swift
//  kAir
//
//  Pure status-source projection for connector invocation receipts.
//

import Foundation

@MainActor
struct ServerProviderRuntimeConnectorStatusSourceProducer {
    struct ReceiptInput: Hashable, Sendable {
        let recommendationID: String
        let receipt: ServerProviderRuntimeConnectorInvocationReceipt
    }

    func statusSource(
        receipts inputs: [ReceiptInput],
        renderedRecommendationIDs: [String]
    ) -> ServerProviderRenderedRuntimeStatusSource {
        ServerProviderRenderedRuntimeStatusSource(
            source: ServerProviderRuntimeConnectorReceiptStatusStore(
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

struct ServerProviderRuntimeConnectorReceiptStatusStore: ProviderStatusProviding {
    private let receiptsByRecommendationID: [String: ServerProviderRuntimeConnectorInvocationReceipt]

    nonisolated init(
        receiptsByRecommendationID: [String: ServerProviderRuntimeConnectorInvocationReceipt]
    ) {
        self.receiptsByRecommendationID = receiptsByRecommendationID
    }

    nonisolated init(
        receipts: [(recommendationID: String, receipt: ServerProviderRuntimeConnectorInvocationReceipt)]
    ) {
        var indexed: [String: ServerProviderRuntimeConnectorInvocationReceipt] = [:]
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
        for receipt: ServerProviderRuntimeConnectorInvocationReceipt
    ) -> [ProviderStatusBadgeModel] {
        guard receipt.state == .receiptPrepared else {
            return [unavailableBadge()]
        }

        var badges = [providerBadge(for: receipt.providerFamily)]
        if let costClass = receipt.costClass {
            badges.append(costBadge(for: costClass))
        }
        if let freshness = receipt.freshness,
           let freshnessBadge = freshnessBadge(for: freshness) {
            badges.append(freshnessBadge)
        }
        return deduplicated(badges)
    }

    nonisolated private static func statusLine(
        for receipt: ServerProviderRuntimeConnectorInvocationReceipt
    ) -> String {
        let segments: [String]

        switch receipt.state {
        case .receiptPrepared:
            segments = [
                "Connector receipt is projected from connector metadata only.",
                providerSegment(for: receipt),
                costSegment(for: receipt),
                freshnessSegment(for: receipt),
                "No provider runtime has run.",
            ]
        case .rejected:
            segments = [
                "Connector receipt is unavailable for provider display.",
                rejectionSegment(for: receipt),
                "No provider runtime has run.",
            ]
        }

        return deduplicatedStatusSegments(segments)
            .joined(separator: " ")
    }

    nonisolated private static func cardHint(
        for receipt: ServerProviderRuntimeConnectorInvocationReceipt
    ) -> ProviderStatusCardHint {
        switch receipt.state {
        case .receiptPrepared:
            return receipt.costClass == .meteredPremium ? .warning : .normal
        case .rejected:
            return .disabled
        }
    }

    nonisolated private static func providerSegment(
        for receipt: ServerProviderRuntimeConnectorInvocationReceipt
    ) -> String {
        guard let providerFamily = receipt.providerFamily else {
            return "Provider family is unavailable."
        }
        return "Provider family: \(providerFamily.rawValue)."
    }

    nonisolated private static func costSegment(
        for receipt: ServerProviderRuntimeConnectorInvocationReceipt
    ) -> String {
        guard let costClass = receipt.costClass else {
            return "Cost class is unavailable."
        }
        return "Cost: \(costClass.rawValue)."
    }

    nonisolated private static func freshnessSegment(
        for receipt: ServerProviderRuntimeConnectorInvocationReceipt
    ) -> String {
        guard let freshness = receipt.freshness else {
            return "Freshness is unavailable."
        }
        return "Freshness: \(freshness.rawValue)."
    }

    nonisolated private static func rejectionSegment(
        for receipt: ServerProviderRuntimeConnectorInvocationReceipt
    ) -> String {
        if let connectorRejection = receipt.connectorRejection {
            return "Connector reason: \(connectorRejection.rawValue)."
        }
        if let invocationRejection = receipt.invocationRejection {
            return "Invocation reason: \(invocationRejection.rawValue)."
        }
        if let planningRejection = receipt.planningRejection {
            return "Planning reason: \(planningRejection.rawValue)."
        }
        return "Reason is unavailable."
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
            return ProviderStatusBadgeModel(
                kind: .costBlocked,
                label: "Premium locked",
                systemImage: "lock.badge.clock",
                tone: .warning
            )
        case .blockedByPrivacy:
            return ProviderStatusBadgeModel(
                kind: .privacyBlocked,
                label: "Privacy blocked",
                systemImage: "lock.shield",
                tone: .warning
            )
        case .blockedByTerms:
            return ProviderStatusBadgeModel(
                kind: .termsBlocked,
                label: "Provider blocked",
                systemImage: "exclamationmark.triangle",
                tone: .warning
            )
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
