//
//  ServerProviderSearchAPIAdapterFixtureTransportStatusSourceProducer.swift
//  kAir
//
//  Pure rendered-id scoped provider-status projection for Search API adapter
//  fixture bridge responses.
//

import Foundation

@MainActor
struct ServerProviderSearchAPIAdapterFixtureTransportStatusSourceProducer {
    struct ResponseInput: Hashable, Sendable {
        let recommendationID: String
        let response: ServerProviderSearchAPIAdapterFixtureTransportBridgeResponse
    }

    func statusSource(
        responses inputs: [ResponseInput],
        renderedRecommendationIDs: [String]
    ) -> ServerProviderRenderedRuntimeStatusSource {
        ServerProviderRenderedRuntimeStatusSource(
            source: ServerProviderSearchAPIAdapterFixtureTransportStatusStore(
                responses: inputs.map { input in
                    (
                        recommendationID: input.recommendationID,
                        response: input.response
                    )
                }
            ),
            renderedRecommendationIDs: renderedRecommendationIDs
        )
    }
}

struct ServerProviderSearchAPIAdapterFixtureTransportStatusStore: ProviderStatusProviding {
    private let responsesByRecommendationID: [String: ServerProviderSearchAPIAdapterFixtureTransportBridgeResponse]

    nonisolated init(
        responsesByRecommendationID: [String: ServerProviderSearchAPIAdapterFixtureTransportBridgeResponse]
    ) {
        self.responsesByRecommendationID = responsesByRecommendationID
    }

    nonisolated init(
        responses: [(recommendationID: String, response: ServerProviderSearchAPIAdapterFixtureTransportBridgeResponse)]
    ) {
        var indexed: [String: ServerProviderSearchAPIAdapterFixtureTransportBridgeResponse] = [:]
        var seenRecommendationIDs: Set<String> = []
        for entry in responses where seenRecommendationIDs.insert(entry.recommendationID).inserted {
            indexed[entry.recommendationID] = entry.response
        }
        self.responsesByRecommendationID = indexed
    }

    nonisolated var recommendationIDs: [String] {
        responsesByRecommendationID.keys.sorted()
    }

    nonisolated func providerStatusPresentation(
        for recommendationID: String
    ) -> ProviderStatusPresentation? {
        guard let response = responsesByRecommendationID[recommendationID] else {
            return nil
        }
        return ProviderStatusPresentation(
            recommendationID: recommendationID,
            badges: Self.badges(for: response),
            statusLine: Self.statusLine(for: response),
            cardHint: Self.cardHint(for: response)
        )
    }

    nonisolated private static func badges(
        for response: ServerProviderSearchAPIAdapterFixtureTransportBridgeResponse
    ) -> [ProviderStatusBadgeModel] {
        switch response.state {
        case .fixtureReady:
            var badges = [
                providerBadge(for: response.providerFamily),
                costBadge(for: response.costClass),
            ]
            if let freshness = response.freshness,
               let freshnessBadge = freshnessBadge(for: freshness) {
                badges.append(freshnessBadge)
            }
            return deduplicated(badges)
        case .rejected:
            return [rejectionBadge(for: response)]
        }
    }

    nonisolated private static func statusLine(
        for response: ServerProviderSearchAPIAdapterFixtureTransportBridgeResponse
    ) -> String {
        let segments: [String]

        switch response.state {
        case .fixtureReady:
            segments = [
                "Search API adapter fixture bridge audit metadata is ready for advisory display only.",
                requestIDSegment(for: response),
                payloadIDSegment(for: response),
                dispatchIDSegment(for: response),
                capabilitySegment(for: response),
                costSegment(for: response),
                freshnessSegment(for: response),
                sourceSegment(for: response),
                "No transport or provider runtime has run.",
            ]
        case .rejected:
            segments = [
                "Search API adapter fixture bridge status is blocked by metadata policy.",
                requestIDSegment(for: response),
                rejectionSegment(for: response),
                requestDecisionRejectionSegment(for: response),
                payloadDecisionRejectionSegment(for: response),
                dispatchReceiptRejectionSegment(for: response),
                "No transport or provider runtime has run.",
            ]
        }

        return deduplicatedStatusSegments(segments)
            .joined(separator: " ")
    }

    nonisolated private static func cardHint(
        for response: ServerProviderSearchAPIAdapterFixtureTransportBridgeResponse
    ) -> ProviderStatusCardHint {
        switch response.state {
        case .fixtureReady:
            return response.costClass == .meteredPremium ? .warning : .normal
        case .rejected:
            return .disabled
        }
    }

    nonisolated private static func requestIDSegment(
        for response: ServerProviderSearchAPIAdapterFixtureTransportBridgeResponse
    ) -> String {
        guard let requestID = response.requestID,
              requestID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return "Request id: unavailable."
        }
        return "Request id: \(requestID)."
    }

    nonisolated private static func payloadIDSegment(
        for response: ServerProviderSearchAPIAdapterFixtureTransportBridgeResponse
    ) -> String {
        guard let payloadID = response.payloadID,
              payloadID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return "Payload id: unavailable."
        }
        return "Payload id: \(payloadID)."
    }

    nonisolated private static func dispatchIDSegment(
        for response: ServerProviderSearchAPIAdapterFixtureTransportBridgeResponse
    ) -> String {
        guard let dispatchID = response.dispatchReceiptID,
              dispatchID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return "Dispatch receipt id: unavailable."
        }
        return "Dispatch receipt id: \(dispatchID)."
    }

    nonisolated private static func capabilitySegment(
        for response: ServerProviderSearchAPIAdapterFixtureTransportBridgeResponse
    ) -> String {
        guard let capability = response.capability else {
            return "Capability: unavailable."
        }
        return "Capability: \(capability.rawValue)."
    }

    nonisolated private static func costSegment(
        for response: ServerProviderSearchAPIAdapterFixtureTransportBridgeResponse
    ) -> String {
        guard let costClass = response.costClass else {
            return "Cost: unavailable."
        }
        return "Cost: \(costClass.rawValue)."
    }

    nonisolated private static func freshnessSegment(
        for response: ServerProviderSearchAPIAdapterFixtureTransportBridgeResponse
    ) -> String {
        guard let freshness = response.freshness else {
            return "Freshness: unavailable."
        }
        return "Freshness: \(freshness.rawValue)."
    }

    nonisolated private static func sourceSegment(
        for response: ServerProviderSearchAPIAdapterFixtureTransportBridgeResponse
    ) -> String {
        guard let sourcePolicy = response.sourcePolicy else {
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
        for response: ServerProviderSearchAPIAdapterFixtureTransportBridgeResponse
    ) -> String {
        guard let rejection = response.rejection else {
            return "Bridge reason: unavailable."
        }
        return "Bridge reason: \(rejection.rawValue)."
    }

    nonisolated private static func requestDecisionRejectionSegment(
        for response: ServerProviderSearchAPIAdapterFixtureTransportBridgeResponse
    ) -> String {
        guard let rejection = response.requestDecisionRejection else {
            return ""
        }
        return "Request decision reason: \(rejection.rawValue)."
    }

    nonisolated private static func payloadDecisionRejectionSegment(
        for response: ServerProviderSearchAPIAdapterFixtureTransportBridgeResponse
    ) -> String {
        guard let rejection = response.payloadDecisionRejection else {
            return ""
        }
        return "Payload decision reason: \(rejection.rawValue)."
    }

    nonisolated private static func dispatchReceiptRejectionSegment(
        for response: ServerProviderSearchAPIAdapterFixtureTransportBridgeResponse
    ) -> String {
        guard let rejection = response.dispatchReceiptRejection else {
            return ""
        }
        return "Dispatch receipt reason: \(rejection.rawValue)."
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
        for response: ServerProviderSearchAPIAdapterFixtureTransportBridgeResponse
    ) -> ProviderStatusBadgeModel {
        if response.requestDecisionRejection == .privacyBlocked
            || response.rejection == .privacyBlocked {
            return blockedPrivacyBadge()
        }
        if response.requestDecisionRejection == .quotaBlocked
            || response.payloadDecisionRejection == .quotaBlocked
            || response.rejection == .quotaBlocked {
            return blockedCostBadge()
        }
        switch response.rejection {
        case .requestDecisionRejected, .missingPreparedRequest,
             .payloadDecisionRejected, .missingPayload,
             .dispatchReceiptBlocked:
            return unavailableBadge()
        case .payloadDecisionIDMismatch, .payloadIDMismatch,
             .requestIDMismatch, .traceIDMismatch,
             .providerFamilyMismatch, .capabilityMismatch,
             .freshnessMismatch, .costClassMismatch, .resultLimitMismatch,
             .queryMismatch, .sourcePolicyMismatch, .emptyQuery,
             .providerFamilyNotSearchAPI, .unsupportedCapability,
             .invalidResultLimit, .sourcePolicyInsufficient,
             .citationPolicyMissing:
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
