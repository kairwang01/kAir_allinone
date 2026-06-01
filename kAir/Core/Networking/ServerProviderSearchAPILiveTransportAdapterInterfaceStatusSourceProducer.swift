//
//  ServerProviderSearchAPILiveTransportAdapterInterfaceStatusSourceProducer.swift
//  kAir
//
//  Rendered-id scoped provider-status projection for A155 Search API adapter
//  interface decisions. This packages advisory metadata only.
//

import Foundation

@MainActor
struct ServerProviderSearchAPILiveTransportAdapterInterfaceStatusSourceProducer {
    struct Input: Hashable, Sendable {
        let recommendationID: String
        let decision: ServerProviderSearchAPILiveTransportAdapterInterfaceDecision
    }

    func statusSource(
        inputs: [Input],
        renderedRecommendationIDs: [String]
    ) -> ServerProviderRenderedRuntimeStatusSource {
        ServerProviderRenderedRuntimeStatusSource(
            source: ServerProviderSearchAPILiveTransportAdapterInterfaceStatusStore(
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

struct ServerProviderSearchAPILiveTransportAdapterInterfaceStatusStore:
    ProviderStatusProviding
{
    private let decisionsByRecommendationID:
        [String: ServerProviderSearchAPILiveTransportAdapterInterfaceDecision]

    nonisolated init(
        decisionsByRecommendationID: [
            String: ServerProviderSearchAPILiveTransportAdapterInterfaceDecision
        ]
    ) {
        self.decisionsByRecommendationID = decisionsByRecommendationID
    }

    nonisolated init(
        decisions: [
            (
                recommendationID: String,
                decision: ServerProviderSearchAPILiveTransportAdapterInterfaceDecision
            )
        ]
    ) {
        var indexed: [
            String: ServerProviderSearchAPILiveTransportAdapterInterfaceDecision
        ] = [:]
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
        for decision: ServerProviderSearchAPILiveTransportAdapterInterfaceDecision
    ) -> [ProviderStatusBadgeModel] {
        guard decision.state == .accepted,
              let selectedSummary = selectedDescriptorSummary(for: decision) else {
            return [rejectionBadge(for: decision.rejectionReasons)]
        }

        return deduplicated([
            ProviderStatusBadgeModel(
                kind: .remoteProvider,
                label: "Search API interface",
                systemImage: "network",
                tone: .neutral
            ),
            ProviderStatusBadgeModel(
                kind: .includedQuota,
                label: "Adapter policy",
                systemImage: "checkmark.seal",
                tone: .neutral
            ),
            costBadge(for: selectedSummary.costClass),
            ProviderStatusBadgeModel(
                kind: .liveFreshness,
                label: "Source required",
                systemImage: "quote.bubble",
                tone: .neutral
            ),
        ])
    }

    nonisolated private static func statusLine(
        for decision: ServerProviderSearchAPILiveTransportAdapterInterfaceDecision
    ) -> String {
        guard decision.state == .accepted,
              let selectedSummary = selectedDescriptorSummary(for: decision) else {
            return rejectedStatusLine(for: decision)
        }

        return deduplicatedStatusSegments([
            "Search API interface candidate adapter policy is advisory only.",
            idSegment(label: "Descriptor", id: selectedSummary.id),
            idSegment(label: "Vendor", id: selectedSummary.vendorID),
            "Cost: \(selectedSummary.costClass.rawValue).",
            "Unit: \(selectedSummary.costUnit.rawValue).",
            "Context: \(selectedSummary.searchContextClass.rawValue).",
            "Page content: \(selectedSummary.pageContentMode.rawValue).",
            "Retention: \(selectedSummary.retentionClass.rawValue).",
            "QPS: \(selectedSummary.qpsClass.rawValue).",
            regionSegment(for: selectedSummary.regionIDs),
            duplicateSegment(for: decision.duplicateDescriptorIDs),
            "Source state: citation, source host, and attribution requirements remain policy metadata.",
            "isRuntimeCallable false.",
            "No transport or provider runtime has run.",
        ])
        .joined(separator: " ")
    }

    nonisolated private static func rejectedStatusLine(
        for decision: ServerProviderSearchAPILiveTransportAdapterInterfaceDecision
    ) -> String {
        deduplicatedStatusSegments([
            "Search API interface candidate adapter policy is disabled by metadata policy.",
            rejectionSegment(for: decision.rejectionReasons),
            duplicateSegment(for: decision.duplicateDescriptorIDs),
            "isRuntimeCallable false.",
            "No transport or provider runtime has run.",
        ])
        .joined(separator: " ")
    }

    nonisolated private static func cardHint(
        for decision: ServerProviderSearchAPILiveTransportAdapterInterfaceDecision
    ) -> ProviderStatusCardHint {
        decision.state == .accepted ? .warning : .disabled
    }

    nonisolated private static func selectedDescriptorSummary(
        for decision: ServerProviderSearchAPILiveTransportAdapterInterfaceDecision
    ) -> ServerProviderSearchAPILiveTransportAdapterDescriptorSummary? {
        guard let selectedDescriptorID = decision.selectedDescriptorID else {
            return nil
        }
        return decision.descriptorSummaries.first { $0.id == selectedDescriptorID }
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

    nonisolated private static func rejectionBadge(
        for reasons: [ServerProviderSearchAPILiveTransportAdapterInterfaceRejectionReason]
    ) -> ProviderStatusBadgeModel {
        if reasons.contains(.privacyBlocked) {
            return blockedPrivacyBadge()
        }
        if reasons.contains(.staleBoundaryOrReadiness) {
            return ProviderStatusBadgeModel(
                kind: .staleCache,
                label: "Readiness stale",
                systemImage: "clock.arrow.circlepath",
                tone: .warning
            )
        }
        if reasons.contains(where: isCostOrQuotaRejection) {
            return blockedCostBadge()
        }
        if reasons.contains(where: isTermsOrSourceRejection) {
            return blockedTermsBadge()
        }
        return unavailableBadge()
    }

    nonisolated private static func isCostOrQuotaRejection(
        _ reason: ServerProviderSearchAPILiveTransportAdapterInterfaceRejectionReason
    ) -> Bool {
        switch reason {
        case .costClassMismatch, .costUnitMismatch, .quotaOrQPSUnavailable:
            return true
        case .descriptorListEmpty, .duplicateDescriptorID, .noEligibleDescriptor,
             .providerFamilyMismatch, .vendorMismatch, .unsupportedCapability,
             .unsupportedResultShape, .unsupportedFreshness,
             .pageContentPolicyConflict, .retentionConflict,
             .missingCitationSupport, .missingSourceSupport,
             .missingAttributionSupport, .regionBlocked, .killSwitchActive,
             .missingUpstreamID, .privacyBlocked, .staleBoundaryOrReadiness,
             .serverSecretModeNotServerOwned:
            return false
        }
    }

    nonisolated private static func isTermsOrSourceRejection(
        _ reason: ServerProviderSearchAPILiveTransportAdapterInterfaceRejectionReason
    ) -> Bool {
        switch reason {
        case .providerFamilyMismatch, .vendorMismatch, .unsupportedCapability,
             .unsupportedResultShape, .unsupportedFreshness,
             .pageContentPolicyConflict, .retentionConflict,
             .missingCitationSupport, .missingSourceSupport,
             .missingAttributionSupport, .regionBlocked,
             .serverSecretModeNotServerOwned:
            return true
        case .descriptorListEmpty, .duplicateDescriptorID, .noEligibleDescriptor,
             .costClassMismatch, .costUnitMismatch, .quotaOrQPSUnavailable,
             .killSwitchActive, .missingUpstreamID, .privacyBlocked,
             .staleBoundaryOrReadiness:
            return false
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

    nonisolated private static func idSegment(
        label: String,
        id: String
    ) -> String {
        "\(label): \(id)."
    }

    nonisolated private static func regionSegment(
        for regionIDs: [String]
    ) -> String {
        guard regionIDs.isEmpty == false else {
            return ""
        }
        return "Regions: \(regionIDs.joined(separator: ","))."
    }

    nonisolated private static func rejectionSegment(
        for reasons: [ServerProviderSearchAPILiveTransportAdapterInterfaceRejectionReason]
    ) -> String {
        guard reasons.isEmpty == false else {
            return "Reason: unavailable."
        }
        return "Reason: \(reasons.map(\.rawValue).joined(separator: ","))."
    }

    nonisolated private static func duplicateSegment(
        for duplicateDescriptorIDs: [String]
    ) -> String {
        guard duplicateDescriptorIDs.isEmpty == false else {
            return ""
        }
        return "Duplicate descriptor ids: \(duplicateDescriptorIDs.joined(separator: ","))."
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
