//
//  ServerProviderTransportAuditTraceStatusSourceProducer.swift
//  kAir
//
//  Rendered-id scoped provider-status projection for transport audit events.
//

import Foundation

@MainActor
struct ServerProviderTransportAuditTraceStatusSourceProducer {
    struct Input: Hashable, Sendable {
        let recommendationID: String
        let event: ServerProviderTransportAuditEvent
    }

    func statusSource(
        inputs: [Input],
        renderedRecommendationIDs: [String]
    ) -> ServerProviderRenderedRuntimeStatusSource {
        ServerProviderRenderedRuntimeStatusSource(
            source: ServerProviderTransportAuditEventStatusStore(
                events: inputs.map { input in
                    (
                        recommendationID: input.recommendationID,
                        event: input.event
                    )
                }
            ),
            renderedRecommendationIDs: renderedRecommendationIDs
        )
    }
}

struct ServerProviderTransportAuditEventStatusStore: ProviderStatusProviding {
    private let eventsByRecommendationID: [String: ServerProviderTransportAuditEvent]

    nonisolated init(
        eventsByRecommendationID: [String: ServerProviderTransportAuditEvent]
    ) {
        self.eventsByRecommendationID = eventsByRecommendationID
    }

    nonisolated init(
        events: [
            (
                recommendationID: String,
                event: ServerProviderTransportAuditEvent
            )
        ]
    ) {
        var indexed: [String: ServerProviderTransportAuditEvent] = [:]
        var seenRecommendationIDs: Set<String> = []
        for entry in events where seenRecommendationIDs.insert(entry.recommendationID).inserted {
            indexed[entry.recommendationID] = entry.event
        }
        self.eventsByRecommendationID = indexed
    }

    nonisolated var recommendationIDs: [String] {
        eventsByRecommendationID.keys.sorted()
    }

    nonisolated func providerStatusPresentation(
        for recommendationID: String
    ) -> ProviderStatusPresentation? {
        guard let event = eventsByRecommendationID[recommendationID] else {
            return nil
        }
        return ProviderStatusPresentation(
            recommendationID: recommendationID,
            badges: Self.badges(for: event),
            statusLine: Self.statusLine(for: event),
            cardHint: Self.cardHint(for: event)
        )
    }

    nonisolated private static func badges(
        for event: ServerProviderTransportAuditEvent
    ) -> [ProviderStatusBadgeModel] {
        guard event.isAccepted else {
            return [rejectionBadge(for: event.rejectionReason)]
        }
        return deduplicated([
            providerBadge(for: event.safeCopy.providerFamily),
            costBadge(for: event.safeCopy.costClass),
            evaluationBadge(),
        ])
    }

    nonisolated private static func statusLine(
        for event: ServerProviderTransportAuditEvent
    ) -> String {
        switch event.state {
        case .accepted:
            return acceptedStatusLine(for: event.safeCopy)
        case .rejected:
            return rejectedStatusLine(for: event.safeCopy)
        }
    }

    nonisolated private static func acceptedStatusLine(
        for copy: ServerProviderTransportAuditSafeCopy
    ) -> String {
        deduplicatedStatusSegments([
            "Provider transport audit accepted from value-only metadata.",
            idSegment(label: "Recommendation", id: copy.renderedRecommendationID),
            familySegment(for: copy.providerFamily),
            capabilitySegment(for: copy.capability),
            membershipSegment(for: copy.membershipTier),
            costSegment(for: copy.costClass),
            privacySegment(for: copy.privacyClass),
            idSegment(label: "Status source", id: copy.statusSourceID),
            "Rank: \(copy.selectedStatusSourceRank).",
            sourcePolicySegment(id: copy.sourcePolicyID),
            confirmationSegment(for: copy.confirmationState),
            evaluationSegment(for: copy.evaluationDimensionIDs),
            "No provider transport has run.",
        ])
        .joined(separator: " ")
    }

    nonisolated private static func rejectedStatusLine(
        for copy: ServerProviderTransportAuditSafeCopy
    ) -> String {
        deduplicatedStatusSegments([
            "Provider transport audit is blocked by value-only policy.",
            idSegment(label: "Recommendation", id: copy.renderedRecommendationID),
            familySegment(for: copy.providerFamily),
            capabilitySegment(for: copy.capability),
            membershipSegment(for: copy.membershipTier),
            costSegment(for: copy.costClass),
            privacySegment(for: copy.privacyClass),
            idSegment(label: "Status source", id: copy.statusSourceID),
            "Rank: \(copy.selectedStatusSourceRank).",
            sourcePolicySegment(id: copy.sourcePolicyID),
            confirmationSegment(for: copy.confirmationState),
            evaluationSegment(for: copy.evaluationDimensionIDs),
            rejectionSegment(for: copy.rejectionReason),
            "No provider transport has run.",
        ])
        .joined(separator: " ")
    }

    nonisolated private static func cardHint(
        for event: ServerProviderTransportAuditEvent
    ) -> ProviderStatusCardHint {
        guard event.isAccepted else {
            return .disabled
        }
        if event.safeCopy.costClass == .meteredPremium
            || event.safeCopy.providerFamily.isReservedByDefault {
            return .warning
        }
        return .normal
    }

    nonisolated private static func providerBadge(
        for providerFamily: ServerProviderTransportAuditFamily
    ) -> ProviderStatusBadgeModel {
        ProviderStatusBadgeModel(
            kind: .remoteProvider,
            label: providerFamily == .remoteModel ? "Remote model" : "Remote provider",
            systemImage: providerFamily == .remoteModel ? "brain.head.profile" : "network",
            tone: .neutral
        )
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

    nonisolated private static func evaluationBadge() -> ProviderStatusBadgeModel {
        ProviderStatusBadgeModel(
            kind: .liveFreshness,
            label: "Audit review",
            systemImage: "checklist",
            tone: .neutral
        )
    }

    nonisolated private static func rejectionBadge(
        for reason: ServerProviderTransportAuditRejectionReason?
    ) -> ProviderStatusBadgeModel {
        switch reason {
        case .missingPrivacyPolicy, .blockedPrivacyClass:
            return blockedPrivacyBadge()
        case .blockedCostClass:
            return blockedCostBadge()
        case .unsupportedCapability, .missingSourcePolicy,
             .missingCitationPolicy, .missingAttributionPolicy,
             .userConfirmationMissing, .missingEvaluationDimension,
             .unsafeRuntimeMaterial:
            return blockedTermsBadge()
        case .missingRenderedRecommendationID, .missingStatusSource,
             .reservedProviderDisabled, .none:
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

    nonisolated private static func familySegment(
        for providerFamily: ServerProviderTransportAuditFamily
    ) -> String {
        "Provider: \(providerFamily.rawValue)."
    }

    nonisolated private static func capabilitySegment(
        for capability: ServerProviderTransportAuditCapability
    ) -> String {
        "Capability: \(capability.rawValue)."
    }

    nonisolated private static func membershipSegment(
        for membershipTier: MembershipTier
    ) -> String {
        "Membership: \(membershipTier.rawValue)."
    }

    nonisolated private static func costSegment(
        for costClass: ProviderCostClass
    ) -> String {
        "Cost: \(costClass.rawValue)."
    }

    nonisolated private static func privacySegment(
        for privacyClass: ProviderPrivacyClass?
    ) -> String {
        "Privacy: \(privacyClass?.rawValue ?? "unavailable")."
    }

    nonisolated private static func sourcePolicySegment(
        id: String?
    ) -> String {
        idSegment(label: "Source policy", id: id)
    }

    nonisolated private static func confirmationSegment(
        for confirmationState: ServerConfirmationState
    ) -> String {
        switch confirmationState {
        case .notRequired:
            return "Confirmation: not required."
        case .requiredMissing:
            return "Confirmation: missing."
        case .confirmed:
            return "Confirmation: confirmed."
        }
    }

    nonisolated private static func evaluationSegment(
        for dimensions: [String]
    ) -> String {
        guard dimensions.isEmpty == false else {
            return "Evaluation: unavailable."
        }
        return "Evaluation: \(dimensions.joined(separator: ", "))."
    }

    nonisolated private static func rejectionSegment(
        for reason: ServerProviderTransportAuditRejectionReason?
    ) -> String {
        guard let reason else {
            return "Reason: unavailable."
        }
        return "Reason: \(reason.rawValue)."
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
