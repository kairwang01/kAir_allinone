//
//  ServerProviderSearchAPITransportRequestStatusSourceProducer.swift
//  kAir
//
//  Pure rendered-id scoped provider-status projection for Search API transport
//  request decisions. This packages advisory metadata only; it does not hold
//  network addresses, auth material, transports, provider runners, queries,
//  source bodies, or UI state.
//

import Foundation

@MainActor
struct ServerProviderSearchAPITransportRequestStatusSourceProducer {
    struct Input: Hashable, Sendable {
        let recommendationID: String
        let decision: ServerProviderSearchAPITransportRequestDecision
    }

    func statusSource(
        inputs: [Input],
        renderedRecommendationIDs: [String]
    ) -> ServerProviderRenderedRuntimeStatusSource {
        ServerProviderRenderedRuntimeStatusSource(
            source: SearchAPITransportRequestProviderStatusStore(
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

struct SearchAPITransportRequestProviderStatusStore: ProviderStatusProviding {
    private let decisionsByRecommendationID: [String: ServerProviderSearchAPITransportRequestDecision]

    nonisolated init(
        decisionsByRecommendationID: [String: ServerProviderSearchAPITransportRequestDecision]
    ) {
        self.decisionsByRecommendationID = decisionsByRecommendationID
    }

    nonisolated init(
        decisions: [
            (
                recommendationID: String,
                decision: ServerProviderSearchAPITransportRequestDecision
            )
        ]
    ) {
        var indexed: [String: ServerProviderSearchAPITransportRequestDecision] = [:]
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
        for decision: ServerProviderSearchAPITransportRequestDecision
    ) -> [ProviderStatusBadgeModel] {
        guard decision.state == .requestPrepared,
              let request = decision.request else {
            return [rejectionBadge(for: decision)]
        }

        var badges = [
            providerBadge(for: request.providerFamily),
            costBadge(for: request.costClass),
        ]
        if let freshnessBadge = freshnessBadge(for: request.freshness) {
            badges.append(freshnessBadge)
        }
        return deduplicated(badges)
    }

    nonisolated private static func statusLine(
        for decision: ServerProviderSearchAPITransportRequestDecision
    ) -> String {
        guard decision.state == .requestPrepared,
              let request = decision.request else {
            return rejectedStatusLine(for: decision)
        }

        return deduplicatedStatusSegments([
            "Search API transport request prepared from lease-bound metadata only.",
            idSegment(label: "Request", id: request.requestID),
            idSegment(label: "Payload decision", id: request.payloadDecisionID),
            idSegment(label: "Payload", id: request.payloadID),
            idSegment(label: "Dispatch", id: request.dispatchReceiptID),
            idSegment(label: "Vendor decision", id: request.vendorDecisionID),
            idSegment(label: "Authorization", id: request.authorizationID),
            idSegment(label: "Lease", id: request.leaseID),
            idSegment(label: "Budget", id: request.budgetID),
            idSegment(label: "Metered decision", id: request.meteredDecisionID),
            providerSegment(for: request.providerFamily),
            vendorSegment(for: request.vendorID),
            capabilitySegment(for: request.capability),
            costSegment(for: request.costClass),
            freshnessSegment(for: request.freshness),
            resultShapeSegment(for: request.resultShape),
            "Result limit: \(request.resultLimit).",
            sourceCitationSegment(for: request.sourceCitationSummary),
            "No transport or provider runtime has run.",
        ])
        .joined(separator: " ")
    }

    nonisolated private static func rejectedStatusLine(
        for decision: ServerProviderSearchAPITransportRequestDecision
    ) -> String {
        deduplicatedStatusSegments([
            "Search API transport request is blocked by metadata policy.",
            idSegment(label: "Decision", id: decision.id),
            requestRejectionSegment(for: decision.rejection),
            adapterRequestRejectionSegment(for: decision.requestDecisionRejection),
            payloadRejectionSegment(for: decision.payloadDecisionRejection),
            dispatchRejectionSegment(for: decision.dispatchReceiptRejection),
            vendorPolicyRejectionSegment(for: decision.vendorPolicyRejection),
            authorizationRejectionSegment(for: decision.authorizationRejection),
            leaseRejectionSegment(for: decision.leaseRejection),
            "No transport or provider runtime has run.",
        ])
        .joined(separator: " ")
    }

    nonisolated private static func cardHint(
        for decision: ServerProviderSearchAPITransportRequestDecision
    ) -> ProviderStatusCardHint {
        guard decision.state == .requestPrepared,
              let request = decision.request else {
            return .disabled
        }
        return request.costClass == .meteredPremium ? .warning : .normal
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
        for decision: ServerProviderSearchAPITransportRequestDecision
    ) -> ProviderStatusBadgeModel {
        switch decision.rejection {
        case .missingLease, .leaseNotIssued, .missingRequestDecision,
             .requestDecisionRejected, .missingRequest, .missingPayloadDecision,
             .payloadNotPrepared, .missingPayload, .missingDispatchReceipt,
             .dispatchNotEligible, .missingVendorPolicyDecision,
             .vendorPolicyNotAccepted, .missingAuthorization,
             .authorizationNotAccepted, .requestPayloadMismatch,
             .requestDispatchMismatch, .dispatchAuthorizationMismatch,
             .vendorAuthorizationMismatch, .leasePayloadMismatch,
             .leaseDispatchMismatch, .leaseAuthorizationMismatch, .none:
            return unavailableBadge()
        case .missingBudgetContext, .budgetContextMismatch,
             .missingMeteredDecisionID, .costClassMismatch:
            return blockedCostBadge()
        case .freshnessMismatch:
            return ProviderStatusBadgeModel(
                kind: .staleCache,
                label: "Stale cache",
                systemImage: "clock.arrow.circlepath",
                tone: .warning
            )
        case .providerFamilyMismatch, .vendorMismatch, .capabilityMismatch,
             .resultShapeMismatch, .resultLimitMismatch,
             .sourcePolicyMismatch, .citationPolicyMissing:
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

    nonisolated private static func providerSegment(
        for providerFamily: ProviderFamily
    ) -> String {
        "Provider: \(providerFamily.rawValue)."
    }

    nonisolated private static func vendorSegment(
        for vendorID: String
    ) -> String {
        "Vendor: \(vendorID)."
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

    nonisolated private static func freshnessSegment(
        for freshness: ProviderFreshness
    ) -> String {
        "Freshness: \(freshness.rawValue)."
    }

    nonisolated private static func resultShapeSegment(
        for resultShape: ServerProviderSearchAPIVendorResultShape
    ) -> String {
        "Result shape: \(resultShape.rawValue)."
    }

    nonisolated private static func sourceCitationSegment(
        for summary: ServerProviderSearchAPITransportSourceCitationSummary
    ) -> String {
        [
            "Source policy: \(summary.sourceState.rawValue)",
            "robots \(summary.robotsState.rawValue)",
            "attribution required \(summary.attributionRequired)",
            "citation required \(summary.citationRequired)",
            "source host metadata required \(summary.sourceHostRequired)",
        ]
            .joined(separator: " · ") + "."
    }

    nonisolated private static func requestRejectionSegment(
        for reason: ServerProviderSearchAPITransportRequestRejectionReason?
    ) -> String {
        guard let reason else {
            return "Request reason: unavailable."
        }
        return "Request reason: \(reason.rawValue)."
    }

    nonisolated private static func adapterRequestRejectionSegment(
        for reason: ServerProviderSearchAPIAdapterRejectionReason?
    ) -> String {
        guard let reason else {
            return ""
        }
        return "Adapter request reason: \(reason.rawValue)."
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

    nonisolated private static func vendorPolicyRejectionSegment(
        for reason: ServerProviderSearchAPIVendorPolicyRejectionReason?
    ) -> String {
        guard let reason else {
            return ""
        }
        return "Vendor policy reason: \(reason.rawValue)."
    }

    nonisolated private static func authorizationRejectionSegment(
        for reason: ServerProviderSearchAPIVendorPolicyDispatchAuthorizationRejectionReason?
    ) -> String {
        guard let reason else {
            return ""
        }
        return "Authorization reason: \(reason.rawValue)."
    }

    nonisolated private static func leaseRejectionSegment(
        for reason: ServerProviderSearchAPITransportLeaseRejectionReason?
    ) -> String {
        guard let reason else {
            return ""
        }
        return "Lease reason: \(reason.rawValue)."
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
