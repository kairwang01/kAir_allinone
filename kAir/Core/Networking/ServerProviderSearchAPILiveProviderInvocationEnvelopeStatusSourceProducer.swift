//
//  ServerProviderSearchAPILiveProviderInvocationEnvelopeStatusSourceProducer.swift
//  kAir
//
//  Rendered-id scoped provider-status projection for A165 Search API invocation
//  envelope decisions. This packages advisory metadata only.
//

import Foundation

@MainActor
struct ServerProviderSearchAPILiveProviderInvocationEnvelopeStatusSourceProducer {
    struct Input: Hashable, Sendable {
        let recommendationID: String
        let statusSourceID: String
        let statusSourceRank: Int
        let isVisible: Bool
        let decision: ServerProviderSearchAPILiveProviderInvocationEnvelopeDecision

        init(
            recommendationID: String,
            statusSourceID: String,
            statusSourceRank: Int,
            isVisible: Bool = true,
            decision: ServerProviderSearchAPILiveProviderInvocationEnvelopeDecision
        ) {
            self.recommendationID = recommendationID
            self.statusSourceID = Self.safeID(
                statusSourceID,
                fallback: "search-api-live-provider-invocation-envelope-status"
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
            source: ServerProviderSearchAPILiveProviderInvocationEnvelopeStatusStore(
                entries: inputs.map { input in
                    ServerProviderSearchAPILiveProviderInvocationEnvelopeStatusStore.Entry(
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

struct ServerProviderSearchAPILiveProviderInvocationEnvelopeStatusStore:
    ProviderStatusProviding
{
    struct Entry: Hashable, Sendable {
        let recommendationID: String
        let statusSourceID: String
        let statusSourceRank: Int
        let isVisible: Bool
        let safeCopy: ServerProviderSearchAPILiveProviderInvocationEnvelopeSafeCopy
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
        for safeCopy: ServerProviderSearchAPILiveProviderInvocationEnvelopeSafeCopy
    ) -> [ProviderStatusBadgeModel] {
        guard safeCopy.state == .prepared,
              let summary = safeCopy.summary else {
            return [rejectionBadge(for: safeCopy.rejectionReasons)]
        }

        return deduplicated([
            ProviderStatusBadgeModel(
                kind: .remoteProvider,
                label: "Search API envelope",
                systemImage: "network.badge.shield.half.filled",
                tone: .neutral
            ),
            ProviderStatusBadgeModel(
                kind: .meteredPremium,
                label: "Cost unit \(summary.costUnit.rawValue)",
                systemImage: "creditcard",
                tone: .neutral
            ),
            ProviderStatusBadgeModel(
                kind: .includedQuota,
                label: "Envelope policy",
                systemImage: "checkmark.seal",
                tone: .neutral
            ),
            ProviderStatusBadgeModel(
                kind: .liveFreshness,
                label: "Source retained",
                systemImage: "quote.bubble",
                tone: .neutral
            ),
        ])
    }

    nonisolated private static func statusLine(
        for entry: Entry
    ) -> String {
        let safeCopy = entry.safeCopy
        guard safeCopy.state == .prepared,
              let summary = safeCopy.summary else {
            return rejectedStatusLine(for: entry)
        }

        return deduplicatedStatusSegments([
            "Search API invocation envelope is advisory only.",
            idSegment(label: "Envelope", id: summary.id),
            idSegment(label: "Preflight", id: summary.preflightID),
            idSegment(label: "Adapter", id: summary.selectedAdapterID),
            idSegment(label: "Vendor", id: summary.selectedVendorID),
            idSegment(label: "Budget", id: summary.budgetSnapshotID),
            idSegment(label: "Lease", id: summary.transportLeaseID),
            idSegment(label: "Request", id: summary.transportRequestID),
            idSegment(label: "Audit", id: summary.auditTraceID),
            idSegment(label: "Status source", id: entry.statusSourceID),
            "Rank: \(entry.statusSourceRank).",
            "Family: \(summary.providerFamily.rawValue).",
            "Capability: \(summary.capability.rawValue).",
            "Result: \(summary.resultShape.rawValue).",
            "Freshness: \(summary.freshness.rawValue).",
            "Cost unit: \(summary.costUnit.rawValue).",
            "Quota: \(summary.quotaRateClass.rawValue).",
            "Source: \(summary.sourceState.rawValue).",
            "Retention: \(summary.retentionClass.rawValue).",
            "Redaction: \(summary.redactionPolicy.rawValue).",
            "Region: \(summary.region.rawValue).",
            "isRuntimeCallable false.",
            "isExecutable false.",
            "No transport or provider runtime has run.",
        ])
        .joined(separator: " ")
    }

    nonisolated private static func rejectedStatusLine(
        for entry: Entry
    ) -> String {
        let safeCopy = entry.safeCopy
        return deduplicatedStatusSegments([
            "Search API invocation envelope is disabled by envelope policy.",
            rejectionSegment(for: safeCopy.rejectionReasons),
            summarySegment(for: safeCopy.summary),
            idSegment(label: "Status source", id: entry.statusSourceID),
            "Rank: \(entry.statusSourceRank).",
            "isRuntimeCallable false.",
            "isExecutable false.",
            "No transport or provider runtime has run.",
        ])
        .joined(separator: " ")
    }

    nonisolated private static func cardHint(
        for safeCopy: ServerProviderSearchAPILiveProviderInvocationEnvelopeSafeCopy
    ) -> ProviderStatusCardHint {
        safeCopy.state == .prepared ? .warning : .disabled
    }

    nonisolated private static func rejectionBadge(
        for reasons: [ServerProviderSearchAPILiveProviderInvocationEnvelopeRejectionReason]
    ) -> ProviderStatusBadgeModel {
        if reasons.contains(where: isStaleRejection) {
            return ProviderStatusBadgeModel(
                kind: .staleCache,
                label: "Envelope stale",
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

    nonisolated private static func isStaleRejection(
        _ reason: ServerProviderSearchAPILiveProviderInvocationEnvelopeRejectionReason
    ) -> Bool {
        switch reason {
        case .staleOrExpiredPreflight:
            return true
        case .preflightNotAccepted, .vendorOrAdapterMismatch,
             .providerFamilyMismatch, .unsupportedProviderFamily,
             .capabilityMismatch, .resultShapeMismatch, .freshnessMismatch,
             .searchContextMismatch, .pageContentPolicyMismatch,
             .missingBudgetSnapshot, .budgetSnapshotMismatch, .costUnitMismatch,
             .missingLeaseRequestOrAuditID, .leaseRequestOrAuditMismatch,
             .duplicateEnvelopeID, .unsafeSourceOrRetentionPolicy,
             .unsafeRedactionPolicy, .unsupportedRegion, .quotaRateUnavailable,
             .serverSecretModeNotServerOwned, .runtimeCallableFlagTrue,
             .executableFlagTrue, .unsafeCommerceMaterialPresent,
             .unredactedSourceMaterialPresent, .hiddenAppControlMaterialPresent:
            return false
        }
    }

    nonisolated private static func isCostOrQuotaRejection(
        _ reason: ServerProviderSearchAPILiveProviderInvocationEnvelopeRejectionReason
    ) -> Bool {
        switch reason {
        case .missingBudgetSnapshot, .budgetSnapshotMismatch, .costUnitMismatch,
             .missingLeaseRequestOrAuditID, .leaseRequestOrAuditMismatch,
             .quotaRateUnavailable:
            return true
        case .preflightNotAccepted, .staleOrExpiredPreflight,
             .vendorOrAdapterMismatch, .providerFamilyMismatch,
             .unsupportedProviderFamily, .capabilityMismatch,
             .resultShapeMismatch, .freshnessMismatch, .searchContextMismatch,
             .pageContentPolicyMismatch, .duplicateEnvelopeID,
             .unsafeSourceOrRetentionPolicy, .unsafeRedactionPolicy,
             .unsupportedRegion, .serverSecretModeNotServerOwned,
             .runtimeCallableFlagTrue, .executableFlagTrue,
             .unsafeCommerceMaterialPresent, .unredactedSourceMaterialPresent,
             .hiddenAppControlMaterialPresent:
            return false
        }
    }

    nonisolated private static func isTermsOrSourceRejection(
        _ reason: ServerProviderSearchAPILiveProviderInvocationEnvelopeRejectionReason
    ) -> Bool {
        switch reason {
        case .vendorOrAdapterMismatch, .providerFamilyMismatch,
             .unsupportedProviderFamily, .capabilityMismatch,
             .resultShapeMismatch, .freshnessMismatch, .searchContextMismatch,
             .pageContentPolicyMismatch, .unsafeSourceOrRetentionPolicy,
             .unsafeRedactionPolicy, .unsupportedRegion,
             .serverSecretModeNotServerOwned, .unsafeCommerceMaterialPresent,
             .unredactedSourceMaterialPresent, .hiddenAppControlMaterialPresent:
            return true
        case .preflightNotAccepted, .staleOrExpiredPreflight,
             .missingBudgetSnapshot, .budgetSnapshotMismatch, .costUnitMismatch,
             .missingLeaseRequestOrAuditID, .leaseRequestOrAuditMismatch,
             .duplicateEnvelopeID, .quotaRateUnavailable,
             .runtimeCallableFlagTrue, .executableFlagTrue:
            return false
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
        for reasons: [ServerProviderSearchAPILiveProviderInvocationEnvelopeRejectionReason]
    ) -> String {
        guard reasons.isEmpty == false else {
            return "Reason: unavailable."
        }
        return "Reason: \(reasons.map(\.rawValue).joined(separator: ","))."
    }

    nonisolated private static func summarySegment(
        for summary: ServerProviderSearchAPILiveProviderInvocationEnvelopeSummary?
    ) -> String {
        guard let summary else {
            return ""
        }
        return deduplicatedStatusSegments([
            idSegment(label: "Envelope", id: summary.id),
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
