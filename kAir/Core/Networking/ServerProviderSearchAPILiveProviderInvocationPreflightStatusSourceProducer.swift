//
//  ServerProviderSearchAPILiveProviderInvocationPreflightStatusSourceProducer.swift
//  kAir
//
//  Rendered-id scoped provider-status projection for A160 Search API invocation
//  preflight decisions. This packages advisory metadata only.
//

import Foundation

@MainActor
struct ServerProviderSearchAPILiveProviderInvocationPreflightStatusSourceProducer {
    struct Input: Hashable, Sendable {
        let recommendationID: String
        let decision: ServerProviderSearchAPILiveProviderInvocationPreflightDecision
    }

    func statusSource(
        inputs: [Input],
        renderedRecommendationIDs: [String]
    ) -> ServerProviderRenderedRuntimeStatusSource {
        ServerProviderRenderedRuntimeStatusSource(
            source: ServerProviderSearchAPILiveProviderInvocationPreflightStatusStore(
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

struct ServerProviderSearchAPILiveProviderInvocationPreflightStatusStore:
    ProviderStatusProviding
{
    private let decisionsByRecommendationID:
        [String: ServerProviderSearchAPILiveProviderInvocationPreflightDecision]

    nonisolated init(
        decisionsByRecommendationID: [
            String: ServerProviderSearchAPILiveProviderInvocationPreflightDecision
        ]
    ) {
        self.decisionsByRecommendationID = decisionsByRecommendationID
    }

    nonisolated init(
        decisions: [
            (
                recommendationID: String,
                decision: ServerProviderSearchAPILiveProviderInvocationPreflightDecision
            )
        ]
    ) {
        var indexed: [
            String: ServerProviderSearchAPILiveProviderInvocationPreflightDecision
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
        for decision: ServerProviderSearchAPILiveProviderInvocationPreflightDecision
    ) -> [ProviderStatusBadgeModel] {
        guard decision.state == .accepted,
              let summary = decision.summary else {
            return [rejectionBadge(for: decision.rejectionReasons)]
        }

        return deduplicated([
            ProviderStatusBadgeModel(
                kind: .remoteProvider,
                label: "Search API preflight",
                systemImage: "network.badge.shield.half.filled",
                tone: .neutral
            ),
            ProviderStatusBadgeModel(
                kind: .includedQuota,
                label: "Preflight policy",
                systemImage: "checkmark.seal",
                tone: .neutral
            ),
            costBadge(for: summary.costClass),
            ProviderStatusBadgeModel(
                kind: .liveFreshness,
                label: "Source checked",
                systemImage: "quote.bubble",
                tone: .neutral
            ),
        ])
    }

    nonisolated private static func statusLine(
        for decision: ServerProviderSearchAPILiveProviderInvocationPreflightDecision
    ) -> String {
        guard decision.state == .accepted,
              let summary = decision.summary else {
            return rejectedStatusLine(for: decision)
        }

        return deduplicatedStatusSegments([
            "Search API provider preflight is advisory only.",
            idSegment(label: "Preflight", id: summary.id),
            idSegment(label: "Descriptor", id: summary.selectedDescriptorID),
            idSegment(label: "Vendor", id: summary.selectedVendorID),
            "Cost: \(summary.costClass.rawValue).",
            "Unit: \(summary.costUnit.rawValue).",
            "Context: \(summary.searchContextClass.rawValue).",
            "Source: \(summary.sourceState.rawValue).",
            "Region: \(summary.region.rawValue).",
            idSegment(label: "Budget", id: summary.budgetSnapshotID),
            "isRuntimeCallable false.",
            "No transport or provider runtime has run.",
        ])
        .joined(separator: " ")
    }

    nonisolated private static func rejectedStatusLine(
        for decision: ServerProviderSearchAPILiveProviderInvocationPreflightDecision
    ) -> String {
        deduplicatedStatusSegments([
            "Search API provider preflight is disabled by metadata policy.",
            rejectionSegment(for: decision.rejectionReasons),
            summarySegment(for: decision.summary),
            "isRuntimeCallable false.",
            "No transport or provider runtime has run.",
        ])
        .joined(separator: " ")
    }

    nonisolated private static func cardHint(
        for decision: ServerProviderSearchAPILiveProviderInvocationPreflightDecision
    ) -> ProviderStatusCardHint {
        decision.state == .accepted ? .warning : .disabled
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
        for reasons: [ServerProviderSearchAPILiveProviderInvocationPreflightRejectionReason]
    ) -> ProviderStatusBadgeModel {
        if reasons.contains(.privacyBlocked) || reasons.contains(.healthContextBlocked) {
            return blockedPrivacyBadge()
        }
        if reasons.contains(where: isReadinessOrFreshnessRejection) {
            return ProviderStatusBadgeModel(
                kind: .staleCache,
                label: "Preflight stale",
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

    nonisolated private static func isReadinessOrFreshnessRejection(
        _ reason: ServerProviderSearchAPILiveProviderInvocationPreflightRejectionReason
    ) -> Bool {
        switch reason {
        case .staleBoundaryOrReadiness, .expiredLease, .freshnessMismatch:
            return true
        case .adapterInterfaceNotAccepted, .runtimeCallableFlagTrue,
             .unsupportedProviderFamily, .providerFamilyMismatch,
             .capabilityMismatch, .resultShapeMismatch, .searchContextMismatch,
             .vendorOrDescriptorMismatch, .missingUpstreamID,
             .meteredDecisionMismatch, .leaseMismatch, .transportRequestMismatch,
             .costClassMismatch, .costUnitMismatch, .missingBudgetSnapshot,
             .regionBlocked, .privacyBlocked, .healthContextBlocked,
             .missingSourcePolicy, .missingCitation, .missingSourceHost,
             .missingAttribution, .pageContentPolicyConflict, .retentionConflict,
             .serverSecretModeNotServerOwned, .duplicatePreflightID:
            return false
        }
    }

    nonisolated private static func isCostOrQuotaRejection(
        _ reason: ServerProviderSearchAPILiveProviderInvocationPreflightRejectionReason
    ) -> Bool {
        switch reason {
        case .costClassMismatch, .costUnitMismatch, .missingBudgetSnapshot,
             .meteredDecisionMismatch, .leaseMismatch:
            return true
        case .adapterInterfaceNotAccepted, .runtimeCallableFlagTrue,
             .unsupportedProviderFamily, .providerFamilyMismatch,
             .capabilityMismatch, .resultShapeMismatch, .freshnessMismatch,
             .searchContextMismatch, .vendorOrDescriptorMismatch,
             .missingUpstreamID, .expiredLease, .transportRequestMismatch,
             .staleBoundaryOrReadiness, .regionBlocked, .privacyBlocked,
             .healthContextBlocked, .missingSourcePolicy, .missingCitation,
             .missingSourceHost, .missingAttribution, .pageContentPolicyConflict,
             .retentionConflict, .serverSecretModeNotServerOwned,
             .duplicatePreflightID:
            return false
        }
    }

    nonisolated private static func isTermsOrSourceRejection(
        _ reason: ServerProviderSearchAPILiveProviderInvocationPreflightRejectionReason
    ) -> Bool {
        switch reason {
        case .unsupportedProviderFamily, .providerFamilyMismatch,
             .capabilityMismatch, .resultShapeMismatch, .searchContextMismatch,
             .vendorOrDescriptorMismatch, .transportRequestMismatch,
             .regionBlocked, .missingSourcePolicy, .missingCitation,
             .missingSourceHost, .missingAttribution, .pageContentPolicyConflict,
             .retentionConflict, .serverSecretModeNotServerOwned:
            return true
        case .adapterInterfaceNotAccepted, .runtimeCallableFlagTrue,
             .missingUpstreamID, .meteredDecisionMismatch, .leaseMismatch,
             .expiredLease, .staleBoundaryOrReadiness, .costClassMismatch,
             .costUnitMismatch, .missingBudgetSnapshot, .freshnessMismatch,
             .privacyBlocked, .healthContextBlocked, .duplicatePreflightID:
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

    nonisolated private static func rejectionSegment(
        for reasons: [ServerProviderSearchAPILiveProviderInvocationPreflightRejectionReason]
    ) -> String {
        guard reasons.isEmpty == false else {
            return "Reason: unavailable."
        }
        return "Reason: \(reasons.map(\.rawValue).joined(separator: ","))."
    }

    nonisolated private static func summarySegment(
        for summary: ServerProviderSearchAPILiveProviderInvocationPreflightSummary?
    ) -> String {
        guard let summary else {
            return ""
        }
        return deduplicatedStatusSegments([
            idSegment(label: "Preflight", id: summary.id),
            idSegment(label: "Vendor", id: summary.selectedVendorID),
            idSegment(label: "Budget", id: summary.budgetSnapshotID),
        ])
        .joined(separator: " ")
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
