//
//  ServerProviderTransportAdapterStatusSourceProducer.swift
//  kAir
//
//  Rendered-id scoped provider-status projection for external provider
//  transport adapter preflight decisions.
//

import Foundation

@MainActor
struct ServerProviderTransportAdapterStatusSourceProducer {
    struct Input: Hashable, Sendable {
        let recommendationID: String
        let decision: ServerProviderTransportAdapterPreflightDecision
    }

    func statusSource(
        inputs: [Input],
        renderedRecommendationIDs: [String]
    ) -> ServerProviderRenderedRuntimeStatusSource {
        ServerProviderRenderedRuntimeStatusSource(
            source: ServerProviderTransportAdapterPreflightStatusStore(
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

struct ServerProviderTransportAdapterPreflightStatusStore: ProviderStatusProviding {
    private let decisionsByRecommendationID: [String: ServerProviderTransportAdapterPreflightDecision]

    nonisolated init(
        decisionsByRecommendationID: [String: ServerProviderTransportAdapterPreflightDecision]
    ) {
        self.decisionsByRecommendationID = decisionsByRecommendationID
    }

    nonisolated init(
        decisions: [
            (
                recommendationID: String,
                decision: ServerProviderTransportAdapterPreflightDecision
            )
        ]
    ) {
        var indexed: [String: ServerProviderTransportAdapterPreflightDecision] = [:]
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
        for decision: ServerProviderTransportAdapterPreflightDecision
    ) -> [ProviderStatusBadgeModel] {
        guard decision.state == .accepted else {
            return [rejectionBadge(for: decision.rejectionReason)]
        }

        return deduplicated([
            providerBadge(for: decision.providerFamily),
            costBadge(for: decision.costClass),
        ])
    }

    nonisolated private static func statusLine(
        for decision: ServerProviderTransportAdapterPreflightDecision
    ) -> String {
        switch decision.state {
        case .accepted:
            return acceptedStatusLine(for: decision)
        case .rejected:
            return rejectedStatusLine(for: decision)
        }
    }

    nonisolated private static func acceptedStatusLine(
        for decision: ServerProviderTransportAdapterPreflightDecision
    ) -> String {
        deduplicatedStatusSegments([
            "External provider transport preflight accepted from value-only metadata.",
            idSegment(label: "Adapter", id: decision.adapterID),
            idSegment(label: "Request", id: decision.requestID),
            providerSegment(for: decision.providerFamily),
            capabilitySegment(for: decision.capability),
            costSegment(for: decision.costClass),
            membershipSegment(for: decision.membershipTier),
            optionalIDSegment(label: "Metered decision", id: decision.meteredDecisionID),
            optionalIDSegment(label: "Transport lease", id: decision.transportLeaseID),
            "No provider transport has run.",
        ])
        .joined(separator: " ")
    }

    nonisolated private static func rejectedStatusLine(
        for decision: ServerProviderTransportAdapterPreflightDecision
    ) -> String {
        deduplicatedStatusSegments([
            "External provider transport preflight is blocked by metadata policy.",
            idSegment(label: "Adapter", id: decision.adapterID),
            idSegment(label: "Request", id: decision.requestID),
            providerSegment(for: decision.providerFamily),
            capabilitySegment(for: decision.capability),
            costSegment(for: decision.costClass),
            membershipSegment(for: decision.membershipTier),
            rejectionSegment(for: decision.rejectionReason),
            optionalIDSegment(label: "Metered decision", id: decision.meteredDecisionID),
            optionalIDSegment(label: "Transport lease", id: decision.transportLeaseID),
            "No provider transport has run.",
        ])
        .joined(separator: " ")
    }

    nonisolated private static func cardHint(
        for decision: ServerProviderTransportAdapterPreflightDecision
    ) -> ProviderStatusCardHint {
        guard decision.state == .accepted else {
            return .disabled
        }
        return decision.costClass == .meteredPremium ? .warning : .normal
    }

    nonisolated private static func providerBadge(
        for providerFamily: ProviderFamily
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

    nonisolated private static func rejectionBadge(
        for reason: ServerProviderTransportAdapterPreflightRejectionReason?
    ) -> ProviderStatusBadgeModel {
        switch reason {
        case .privacyBlocked:
            return blockedPrivacyBadge()
        case .membershipTierTooLow, .missingEntitlement,
             .includedQuotaExhausted, .meteredEligibilityMissing,
             .blockedCostClass, .costClassMismatch, .missingMeteredDecision,
             .meteredDecisionRejected, .meteredDecisionMismatch,
             .missingBudgetEvidence, .staleBudgetEvidence:
            return blockedCostBadge()
        case .unsupportedCapability, .providerFamilyMismatch,
             .sourcePolicyMissing, .sourcePolicyBlocked, .attributionMissing,
             .crawlerRobotsBlocked, .confirmationMissing,
             .transportLeaseMismatch:
            return blockedTermsBadge()
        case .providerNotAllowed, .providerDisabled,
             .experimentalProviderDisabled, .missingTransportLease,
             .transportLeaseNotIssued, .none:
            return unavailableBadge()
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

    nonisolated private static func optionalIDSegment(
        label: String,
        id: String?
    ) -> String {
        guard let id,
              id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return ""
        }
        return "\(label): \(id)."
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

    nonisolated private static func costSegment(
        for costClass: ProviderCostClass
    ) -> String {
        "Cost: \(costClass.rawValue)."
    }

    nonisolated private static func membershipSegment(
        for membershipTier: MembershipTier
    ) -> String {
        "Membership: \(membershipTier.rawValue)."
    }

    nonisolated private static func rejectionSegment(
        for reason: ServerProviderTransportAdapterPreflightRejectionReason?
    ) -> String {
        guard let reason else {
            return "Preflight reason: unavailable."
        }
        return "Preflight reason: \(reason.rawValue)."
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
