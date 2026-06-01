//
//  ServerProviderSearchAPILiveVendorSelectionStatusSourceProducer.swift
//  kAir
//
//  Rendered-id scoped provider-status projection for A150 Search API live vendor
//  selection decisions.
//

import Foundation

@MainActor
struct ServerProviderSearchAPILiveVendorSelectionStatusSourceProducer {
    struct Input: Hashable, Sendable {
        let recommendationID: String
        let decision: ServerProviderSearchAPILiveVendorSelectionDecision
    }

    func statusSource(
        inputs: [Input],
        renderedRecommendationIDs: [String]
    ) -> ServerProviderRenderedRuntimeStatusSource {
        ServerProviderRenderedRuntimeStatusSource(
            source: ServerProviderSearchAPILiveVendorSelectionStatusStore(
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

struct ServerProviderSearchAPILiveVendorSelectionStatusStore: ProviderStatusProviding {
    private let decisionsByRecommendationID:
        [String: ServerProviderSearchAPILiveVendorSelectionDecision]

    nonisolated init(
        decisionsByRecommendationID: [String: ServerProviderSearchAPILiveVendorSelectionDecision]
    ) {
        self.decisionsByRecommendationID = decisionsByRecommendationID
    }

    nonisolated init(
        decisions: [
            (
                recommendationID: String,
                decision: ServerProviderSearchAPILiveVendorSelectionDecision
            )
        ]
    ) {
        var indexed: [String: ServerProviderSearchAPILiveVendorSelectionDecision] = [:]
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
        for decision: ServerProviderSearchAPILiveVendorSelectionDecision
    ) -> [ProviderStatusBadgeModel] {
        guard decision.state == .selected else {
            return [rejectionBadge(for: decision.rejectionReasons)]
        }

        var badges = [
            ProviderStatusBadgeModel(
                kind: .remoteProvider,
                label: "Search API",
                systemImage: "network",
                tone: .neutral
            ),
            ProviderStatusBadgeModel(
                kind: .includedQuota,
                label: "Candidate policy",
                systemImage: "checkmark.seal",
                tone: .neutral
            ),
        ]
        if let selectedSummary = selectedCandidateSummary(for: decision) {
            badges.append(costBadge(for: selectedSummary.costClass))
        }
        return deduplicated(badges)
    }

    nonisolated private static func statusLine(
        for decision: ServerProviderSearchAPILiveVendorSelectionDecision
    ) -> String {
        switch decision.state {
        case .selected:
            var segments = [
                "Search API live vendor candidate is selected for policy planning only.",
            ]
            if let selectedSummary = selectedCandidateSummary(for: decision) {
                segments.append("Candidate: \(selectedSummary.id).")
                segments.append("Cost: \(selectedSummary.costClass.rawValue).")
                segments.append("Unit: \(selectedSummary.costUnit.rawValue).")
                segments.append("Estimate: \(selectedSummary.estimatedUnitMicros) micros \(selectedSummary.currencyCode).")
                segments.append("Quota: \(selectedSummary.quotaClass.rawValue).")
                segments.append("QPS: \(selectedSummary.qpsClass.rawValue).")
                segments.append("Latency: \(selectedSummary.latencyClass.rawValue).")
            }
            segments.append(duplicateSegment(for: decision.duplicateCandidateIDs))
            segments.append("No transport or provider runtime has run.")
            return deduplicatedStatusSegments(segments)
                .joined(separator: " ")
        case .rejected:
            return deduplicatedStatusSegments([
                "Search API live vendor candidate selection is blocked by metadata policy.",
                rejectionSegment(for: decision.rejectionReasons),
                duplicateSegment(for: decision.duplicateCandidateIDs),
                "No candidate is eligible.",
                "No transport or provider runtime has run.",
            ])
            .joined(separator: " ")
        }
    }

    nonisolated private static func cardHint(
        for decision: ServerProviderSearchAPILiveVendorSelectionDecision
    ) -> ProviderStatusCardHint {
        decision.state == .selected ? .warning : .disabled
    }

    nonisolated private static func selectedCandidateSummary(
        for decision: ServerProviderSearchAPILiveVendorSelectionDecision
    ) -> ServerProviderSearchAPILiveVendorCandidateSummary? {
        guard let selectedCandidateID = decision.selectedCandidateID else {
            return nil
        }
        return decision.candidateSummaries.first { $0.id == selectedCandidateID }
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
        for reasons: [ServerProviderSearchAPILiveVendorSelectionRejectionReason]
    ) -> ProviderStatusBadgeModel {
        if reasons.contains(.privacyBlocked) {
            return blockedPrivacyBadge()
        }
        if reasons.contains(where: isCostRejection) {
            return blockedCostBadge()
        }
        if reasons.contains(.unsupportedFreshness) {
            return staleCacheBadge()
        }
        if reasons.contains(where: isTermsRejection) {
            return blockedTermsBadge()
        }
        return unavailableBadge()
    }

    nonisolated private static func isCostRejection(
        _ reason: ServerProviderSearchAPILiveVendorSelectionRejectionReason
    ) -> Bool {
        switch reason {
        case .membershipTierTooLow, .providerDisabled, .providerNotAllowed,
             .entitlementMissing, .includedQuotaExhausted,
             .meteredEligibilityMissing, .unsupportedCostClass,
             .costClassMismatch, .quotaUnavailable, .qpsUnavailable,
             .unitPriceTooHigh:
            return true
        case .candidateListEmpty, .duplicateCandidateID, .vendorDisabled,
             .providerFamilyMismatch, .unsupportedCapability, .privacyBlocked,
             .unsupportedFreshness, .unsupportedResultShape,
             .citationSupportMissing, .sourceSupportMissing,
             .attributionSupportMissing, .pageBodyPolicyMismatch,
             .retentionConflict, .unsupportedRegion,
             .missingUserFacingPurpose, .noEligibleCandidate:
            return false
        }
    }

    nonisolated private static func isTermsRejection(
        _ reason: ServerProviderSearchAPILiveVendorSelectionRejectionReason
    ) -> Bool {
        switch reason {
        case .vendorDisabled, .providerFamilyMismatch, .unsupportedCapability,
             .unsupportedResultShape, .citationSupportMissing,
             .sourceSupportMissing, .attributionSupportMissing,
             .pageBodyPolicyMismatch, .retentionConflict, .unsupportedRegion,
             .missingUserFacingPurpose:
            return true
        case .candidateListEmpty, .duplicateCandidateID, .privacyBlocked,
             .membershipTierTooLow, .providerDisabled, .providerNotAllowed,
             .entitlementMissing, .includedQuotaExhausted,
             .meteredEligibilityMissing, .unsupportedCostClass,
             .costClassMismatch, .quotaUnavailable, .qpsUnavailable,
             .unsupportedFreshness, .unitPriceTooHigh, .noEligibleCandidate:
            return false
        }
    }

    nonisolated private static func rejectionSegment(
        for reasons: [ServerProviderSearchAPILiveVendorSelectionRejectionReason]
    ) -> String {
        guard reasons.isEmpty == false else {
            return "Reason: unavailable."
        }
        return "Reason: \(reasons.map(\.rawValue).joined(separator: ","))."
    }

    nonisolated private static func duplicateSegment(
        for duplicateCandidateIDs: [String]
    ) -> String {
        guard duplicateCandidateIDs.isEmpty == false else {
            return ""
        }
        return "Duplicate candidate ids: \(duplicateCandidateIDs.joined(separator: ","))."
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

    nonisolated private static func staleCacheBadge() -> ProviderStatusBadgeModel {
        ProviderStatusBadgeModel(
            kind: .staleCache,
            label: "Stale cache",
            systemImage: "clock.arrow.circlepath",
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
