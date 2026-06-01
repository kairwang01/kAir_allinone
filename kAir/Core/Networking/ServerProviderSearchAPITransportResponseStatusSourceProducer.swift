//
//  ServerProviderSearchAPITransportResponseStatusSourceProducer.swift
//  kAir
//
//  Rendered-id scoped provider-status projection for Search API transport
//  response decisions. This is advisory copy only and never exposes raw
//  queries, citation URLs, provider endpoints, auth material, or runtimes.
//

import Foundation

@MainActor
struct ServerProviderSearchAPITransportResponseStatusSourceProducer {
    struct Input: Hashable, Sendable {
        let recommendationID: String
        let decision: ServerProviderSearchAPITransportResponseDecision
    }

    func statusSource(
        inputs: [Input],
        renderedRecommendationIDs: [String]
    ) -> ServerProviderRenderedRuntimeStatusSource {
        ServerProviderRenderedRuntimeStatusSource(
            source: SearchAPITransportResponseProviderStatusStore(
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

struct SearchAPITransportResponseProviderStatusStore: ProviderStatusProviding {
    private let decisionsByRecommendationID: [String: ServerProviderSearchAPITransportResponseDecision]

    nonisolated init(
        decisionsByRecommendationID: [String: ServerProviderSearchAPITransportResponseDecision]
    ) {
        self.decisionsByRecommendationID = decisionsByRecommendationID
    }

    nonisolated init(
        decisions: [
            (
                recommendationID: String,
                decision: ServerProviderSearchAPITransportResponseDecision
            )
        ]
    ) {
        var indexed: [String: ServerProviderSearchAPITransportResponseDecision] = [:]
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
        for decision: ServerProviderSearchAPITransportResponseDecision
    ) -> [ProviderStatusBadgeModel] {
        guard decision.state == .responseAccepted,
              let response = decision.response else {
            return [rejectionBadge(for: decision)]
        }

        var badges = [
            providerBadge(for: response.providerFamily),
            costBadge(for: response.costClass),
        ]
        if let freshnessBadge = freshnessBadge(for: response.freshness) {
            badges.append(freshnessBadge)
        }
        return deduplicated(badges)
    }

    nonisolated private static func statusLine(
        for decision: ServerProviderSearchAPITransportResponseDecision
    ) -> String {
        guard decision.state == .responseAccepted,
              let response = decision.response else {
            return rejectedStatusLine(for: decision)
        }

        return deduplicatedStatusSegments([
            "Search API transport response accepted from request-bound cited metadata only.",
            idSegment(label: "Response", id: response.id),
            idSegment(label: "Transport request", id: response.transportRequestID),
            idSegment(label: "Adapter result receipt", id: response.adapterResultReceiptID),
            idSegment(label: "Request", id: response.requestID),
            idSegment(label: "Payload decision", id: response.payloadDecisionID),
            idSegment(label: "Payload", id: response.payloadID),
            idSegment(label: "Dispatch", id: response.dispatchReceiptID),
            idSegment(label: "Vendor decision", id: response.vendorDecisionID),
            idSegment(label: "Authorization", id: response.authorizationID),
            idSegment(label: "Lease", id: response.leaseID),
            idSegment(label: "Budget", id: response.budgetID),
            idSegment(label: "Metered decision", id: response.meteredDecisionID),
            providerSegment(for: response.providerFamily),
            vendorSegment(for: response.vendorID),
            capabilitySegment(for: response.capability),
            costSegment(for: response.costClass),
            freshnessSegment(for: response.freshness),
            resultShapeSegment(for: response.resultShape),
            "Requested result limit: \(response.requestedResultLimit).",
            "Returned results: \(response.returnedResultCount).",
            "Citations: \(response.citationCount).",
            sourceCitationSegment(for: response.sourceCitationSummary),
            "No transport or provider runtime has run.",
        ])
        .joined(separator: " ")
    }

    nonisolated private static func rejectedStatusLine(
        for decision: ServerProviderSearchAPITransportResponseDecision
    ) -> String {
        deduplicatedStatusSegments([
            "Search API transport response is blocked by metadata policy.",
            idSegment(label: "Decision", id: decision.id),
            responseRejectionSegment(for: decision.rejection),
            transportRequestRejectionSegment(for: decision.transportRequestRejection),
            adapterResultRejectionSegment(for: decision.adapterResultRejection),
            "No transport or provider runtime has run.",
        ])
        .joined(separator: " ")
    }

    nonisolated private static func cardHint(
        for decision: ServerProviderSearchAPITransportResponseDecision
    ) -> ProviderStatusCardHint {
        guard decision.state == .responseAccepted,
              let response = decision.response else {
            return .disabled
        }
        return response.costClass == .meteredPremium ? .warning : .normal
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
        for decision: ServerProviderSearchAPITransportResponseDecision
    ) -> ProviderStatusBadgeModel {
        switch decision.rejection {
        case .missingTransportRequestDecision, .transportRequestDecisionRejected,
             .missingTransportRequest, .missingAdapterResultReceipt,
             .adapterResultRejected, .missingResult, .normalizedContentMissing,
             .none:
            return unavailableBadge()
        case .costClassMismatch, .resultLimitOverflow, .vendorMissing,
             .leaseMetadataMissing, .budgetMetadataMissing,
             .meteredMetadataMissing:
            return blockedCostBadge()
        case .freshnessMismatch:
            return ProviderStatusBadgeModel(
                kind: .staleCache,
                label: "Stale cache",
                systemImage: "clock.arrow.circlepath",
                tone: .warning
            )
        case .requestIDMismatch, .providerFamilyMismatch, .capabilityMismatch,
             .sourceCitationPolicyMismatch, .citationMissing:
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

    nonisolated private static func responseRejectionSegment(
        for reason: ServerProviderSearchAPITransportResponseRejectionReason?
    ) -> String {
        guard let reason else {
            return "Response reason: unavailable."
        }
        return "Response reason: \(reason.rawValue)."
    }

    nonisolated private static func transportRequestRejectionSegment(
        for reason: ServerProviderSearchAPITransportRequestRejectionReason?
    ) -> String {
        guard let reason else {
            return ""
        }
        return "Transport request reason: \(reason.rawValue)."
    }

    nonisolated private static func adapterResultRejectionSegment(
        for reason: ServerProviderSearchAPIAdapterRejectionReason?
    ) -> String {
        guard let reason else {
            return ""
        }
        return "Adapter result reason: \(reason.rawValue)."
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
