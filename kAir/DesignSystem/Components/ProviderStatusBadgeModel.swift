//
//  ProviderStatusBadgeModel.swift
//  kAir
//
//  Pure view-model mapping for provider/cost/freshness status. No UI
//  framework imports, no layout changes, no provider runtime calls.
//

import Foundation

/// UI-facing provider badge status. This is separate from
/// `ActionCardTrustPillKind` so A5f can surface provider/cost/freshness without
/// adding a new frozen trust-pill case or changing the card layout.
enum ProviderStatusBadgeKind: String, Codable, Hashable, Sendable, CaseIterable {
    case localProvider
    case remoteProvider
    case cacheProvider
    case freeLocal
    case includedQuota
    case meteredPremium
    case liveFreshness
    case staleCache
    case privacyBlocked
    case costBlocked
    case termsBlocked
    case unavailable
}

struct ProviderStatusBadgeModel: Hashable, Identifiable {
    let id: String
    let kind: ProviderStatusBadgeKind
    let label: String
    let systemImage: String
    let tone: ActionCardTrustPillTone

    nonisolated init(
        kind: ProviderStatusBadgeKind,
        label: String,
        systemImage: String,
        tone: ActionCardTrustPillTone
    ) {
        self.id = kind.rawValue
        self.kind = kind
        self.label = label
        self.systemImage = systemImage
        self.tone = tone
    }
}

enum ProviderStatusCardHint: String, Codable, Hashable, Sendable, CaseIterable {
    case normal
    case warning
    case disabled
}

struct ProviderStatusPresentation: Hashable, Identifiable {
    let id: String
    let recommendationID: String
    let badges: [ProviderStatusBadgeModel]
    let statusLine: String
    let cardHint: ProviderStatusCardHint

    nonisolated init(
        recommendationID: String,
        badges: [ProviderStatusBadgeModel],
        statusLine: String,
        cardHint: ProviderStatusCardHint
    ) {
        self.id = "provider-status-\(recommendationID)"
        self.recommendationID = recommendationID
        self.badges = badges
        self.statusLine = statusLine
        self.cardHint = cardHint
    }
}

enum ProviderStatusCompactCellTreatment: String, Hashable, Sendable, CaseIterable {
    case normal
    case warning
    case disabled

    nonisolated init(cardHint: ProviderStatusCardHint) {
        switch cardHint {
        case .normal:
            self = .normal
        case .warning:
            self = .warning
        case .disabled:
            self = .disabled
        }
    }
}

/// Pure display binding for Chat's compact Recommended Next cells.
///
/// The cell still receives `MatchingObject` separately; this model only carries
/// the optional provider-status side channel that A28 renders under the card
/// text. Nil input returns nil so the pre-A28 compact-cell layout stays absent.
struct ProviderStatusCompactCellDisplay: Hashable, Identifiable {
    let id: String
    let recommendationID: String
    let badges: [ProviderStatusBadgeModel]
    let statusLine: String
    let treatment: ProviderStatusCompactCellTreatment

    nonisolated var accessibilityLabel: String {
        ([statusLine] + badges.map(\.label))
            .filter { $0.isEmpty == false }
            .joined(separator: ", ")
    }

    nonisolated static func make(
        from presentation: ProviderStatusPresentation?
    ) -> ProviderStatusCompactCellDisplay? {
        guard let presentation else {
            return nil
        }

        let trimmedStatusLine = presentation.statusLine.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard trimmedStatusLine.isEmpty == false || presentation.badges.isEmpty == false else {
            return nil
        }

        return ProviderStatusCompactCellDisplay(
            id: "compact-\(presentation.id)",
            recommendationID: presentation.recommendationID,
            badges: presentation.badges,
            statusLine: trimmedStatusLine,
            treatment: ProviderStatusCompactCellTreatment(cardHint: presentation.cardHint)
        )
    }
}

/// Optional composition seam for recommendation providers that can expose
/// provider/cost/freshness status by recommendation id. The rail still renders
/// only `[MatchingObject]`; this side channel is for future status badges.
protocol ProviderStatusProviding {
    func providerStatusPresentation(for recommendationID: String) -> ProviderStatusPresentation?
}

struct RuntimeReceiptProviderStatusStore: ProviderStatusProviding {
    private let receiptsByRecommendationID: [String: ServerProviderRuntimeReceipt]

    nonisolated init(
        receiptsByRecommendationID: [String: ServerProviderRuntimeReceipt]
    ) {
        self.receiptsByRecommendationID = receiptsByRecommendationID
    }

    nonisolated init(
        receipts: [(recommendationID: String, receipt: ServerProviderRuntimeReceipt)]
    ) {
        var indexed: [String: ServerProviderRuntimeReceipt] = [:]
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
        return ProviderStatusBadgeResolver.presentation(
            recommendationID: recommendationID,
            for: receipt
        )
    }
}

struct SearchDryRunProviderStatusStore: ProviderStatusProviding {
    private let presentationsByRecommendationID: [String: ServerProviderDryRunPresentation]

    nonisolated init(
        presentationsByRecommendationID: [String: ServerProviderDryRunPresentation]
    ) {
        self.presentationsByRecommendationID = presentationsByRecommendationID
    }

    nonisolated init(
        presentations: [(recommendationID: String, presentation: ServerProviderDryRunPresentation)]
    ) {
        var indexed: [String: ServerProviderDryRunPresentation] = [:]
        var seenRecommendationIDs: Set<String> = []
        for entry in presentations where seenRecommendationIDs.insert(entry.recommendationID).inserted {
            indexed[entry.recommendationID] = entry.presentation
        }
        self.presentationsByRecommendationID = indexed
    }

    nonisolated var recommendationIDs: [String] {
        presentationsByRecommendationID.keys.sorted()
    }

    nonisolated func providerStatusPresentation(
        for recommendationID: String
    ) -> ProviderStatusPresentation? {
        guard let presentation = presentationsByRecommendationID[recommendationID] else {
            return nil
        }
        return ProviderStatusBadgeResolver.presentation(
            recommendationID: recommendationID,
            for: presentation
        )
    }
}

enum SearchAPIAdapterProviderStatusValue: Codable, Hashable, Sendable {
    case requestDecision(ServerProviderSearchAPIAdapterRequestDecision)
    case resultReceipt(ServerProviderSearchAPIAdapterResultReceipt)
}

struct SearchAPIAdapterProviderStatusStore: ProviderStatusProviding {
    private let valuesByRecommendationID: [String: SearchAPIAdapterProviderStatusValue]

    nonisolated init(
        valuesByRecommendationID: [String: SearchAPIAdapterProviderStatusValue]
    ) {
        self.valuesByRecommendationID = valuesByRecommendationID
    }

    nonisolated init(
        values: [(recommendationID: String, value: SearchAPIAdapterProviderStatusValue)]
    ) {
        var indexed: [String: SearchAPIAdapterProviderStatusValue] = [:]
        var seenRecommendationIDs: Set<String> = []
        for entry in values where seenRecommendationIDs.insert(entry.recommendationID).inserted {
            indexed[entry.recommendationID] = entry.value
        }
        self.valuesByRecommendationID = indexed
    }

    nonisolated var recommendationIDs: [String] {
        valuesByRecommendationID.keys.sorted()
    }

    nonisolated func providerStatusPresentation(
        for recommendationID: String
    ) -> ProviderStatusPresentation? {
        guard let value = valuesByRecommendationID[recommendationID] else {
            return nil
        }
        return ProviderStatusBadgeResolver.presentation(
            recommendationID: recommendationID,
            for: value
        )
    }
}

struct SearchAPIVendorPolicyProviderStatusStore: ProviderStatusProviding {
    private let decisionsByRecommendationID: [String: ServerProviderSearchAPIVendorPolicyDecision]

    nonisolated init(
        decisionsByRecommendationID: [String: ServerProviderSearchAPIVendorPolicyDecision]
    ) {
        self.decisionsByRecommendationID = decisionsByRecommendationID
    }

    nonisolated init(
        decisions: [(recommendationID: String, decision: ServerProviderSearchAPIVendorPolicyDecision)]
    ) {
        var indexed: [String: ServerProviderSearchAPIVendorPolicyDecision] = [:]
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
        return ProviderStatusBadgeResolver.presentation(
            recommendationID: recommendationID,
            for: decision
        )
    }
}

struct SearchAPIVendorDispatchAuthorizationProviderStatusStore: ProviderStatusProviding {
    private let authorizationsByRecommendationID: [String: ServerProviderSearchAPIVendorPolicyDispatchAuthorization]

    nonisolated init(
        authorizationsByRecommendationID: [String: ServerProviderSearchAPIVendorPolicyDispatchAuthorization]
    ) {
        self.authorizationsByRecommendationID = authorizationsByRecommendationID
    }

    nonisolated init(
        authorizations: [
            (
                recommendationID: String,
                authorization: ServerProviderSearchAPIVendorPolicyDispatchAuthorization
            )
        ]
    ) {
        var indexed: [String: ServerProviderSearchAPIVendorPolicyDispatchAuthorization] = [:]
        var seenRecommendationIDs: Set<String> = []
        for entry in authorizations where seenRecommendationIDs.insert(entry.recommendationID).inserted {
            indexed[entry.recommendationID] = entry.authorization
        }
        self.authorizationsByRecommendationID = indexed
    }

    nonisolated var recommendationIDs: [String] {
        authorizationsByRecommendationID.keys.sorted()
    }

    nonisolated func providerStatusPresentation(
        for recommendationID: String
    ) -> ProviderStatusPresentation? {
        guard let authorization = authorizationsByRecommendationID[recommendationID] else {
            return nil
        }
        return ProviderStatusBadgeResolver.presentation(
            recommendationID: recommendationID,
            for: authorization
        )
    }
}

struct ProviderStatusSourceMultiplexer: ProviderStatusProviding {
    private let sources: [any ProviderStatusProviding]

    init(sources: [any ProviderStatusProviding]) {
        self.sources = sources
    }

    func providerStatusPresentation(
        for recommendationID: String
    ) -> ProviderStatusPresentation? {
        for source in sources {
            if let presentation = source.providerStatusPresentation(for: recommendationID) {
                return presentation
            }
        }
        return nil
    }
}

enum ProviderStatusBadgeResolver {
    nonisolated static func presentation(
        for recommendation: ProjectedRecommendation
    ) -> ProviderStatusPresentation {
        let metadata = recommendation.metadata
        let badges = makeBadges(
            state: recommendation.state,
            metadata: metadata
        )

        return ProviderStatusPresentation(
            recommendationID: recommendation.id,
            badges: badges,
            statusLine: statusLine(
                state: recommendation.state,
                metadata: metadata
            ),
            cardHint: cardHint(for: recommendation.state)
        )
    }

    nonisolated static func presentation(
        recommendationID: String,
        for dryRunPresentation: ServerProviderDryRunPresentation
    ) -> ProviderStatusPresentation {
        ProviderStatusPresentation(
            recommendationID: recommendationID,
            badges: dryRunBadges(for: dryRunPresentation),
            statusLine: dryRunStatusLine(for: dryRunPresentation),
            cardHint: dryRunCardHint(for: dryRunPresentation)
        )
    }

    nonisolated static func presentation(
        recommendationID: String,
        for receipt: ServerProviderRuntimeReceipt
    ) -> ProviderStatusPresentation {
        ProviderStatusPresentation(
            recommendationID: recommendationID,
            badges: receiptBadges(for: receipt),
            statusLine: receiptStatusLine(for: receipt),
            cardHint: receiptCardHint(for: receipt)
        )
    }

    nonisolated static func presentation(
        recommendationID: String,
        for value: SearchAPIAdapterProviderStatusValue
    ) -> ProviderStatusPresentation {
        switch value {
        case .requestDecision(let decision):
            return presentation(recommendationID: recommendationID, for: decision)
        case .resultReceipt(let receipt):
            return presentation(recommendationID: recommendationID, for: receipt)
        }
    }

    nonisolated static func presentation(
        recommendationID: String,
        for decision: ServerProviderSearchAPIAdapterRequestDecision
    ) -> ProviderStatusPresentation {
        ProviderStatusPresentation(
            recommendationID: recommendationID,
            badges: searchAPIRequestDecisionBadges(for: decision),
            statusLine: searchAPIRequestDecisionStatusLine(for: decision),
            cardHint: searchAPIRequestDecisionCardHint(for: decision)
        )
    }

    nonisolated static func presentation(
        recommendationID: String,
        for receipt: ServerProviderSearchAPIAdapterResultReceipt
    ) -> ProviderStatusPresentation {
        ProviderStatusPresentation(
            recommendationID: recommendationID,
            badges: searchAPIResultReceiptBadges(for: receipt),
            statusLine: searchAPIResultReceiptStatusLine(for: receipt),
            cardHint: searchAPIResultReceiptCardHint(for: receipt)
        )
    }

    nonisolated static func presentation(
        recommendationID: String,
        for decision: ServerProviderSearchAPIVendorPolicyDecision
    ) -> ProviderStatusPresentation {
        ProviderStatusPresentation(
            recommendationID: recommendationID,
            badges: searchAPIVendorPolicyBadges(for: decision),
            statusLine: searchAPIVendorPolicyStatusLine(for: decision),
            cardHint: searchAPIVendorPolicyCardHint(for: decision)
        )
    }

    nonisolated static func presentation(
        recommendationID: String,
        for authorization: ServerProviderSearchAPIVendorPolicyDispatchAuthorization
    ) -> ProviderStatusPresentation {
        ProviderStatusPresentation(
            recommendationID: recommendationID,
            badges: searchAPIVendorDispatchAuthorizationBadges(for: authorization),
            statusLine: searchAPIVendorDispatchAuthorizationStatusLine(for: authorization),
            cardHint: searchAPIVendorDispatchAuthorizationCardHint(for: authorization)
        )
    }

    nonisolated private static func makeBadges(
        state: ProjectedRecommendationState,
        metadata: ResultProviderMetadata
    ) -> [ProviderStatusBadgeModel] {
        if state == .blocked {
            return [blockedBadge(for: metadata.costClass)]
        }
        if state == .unavailable {
            return [unavailableBadge()]
        }

        var badges: [ProviderStatusBadgeModel] = []
        badges.append(providerBadge(for: metadata))

        if isStaleCache(metadata) {
            badges.append(staleCacheBadge())
            return deduplicated(badges)
        } else {
            badges.append(costBadge(for: metadata.costClass))
        }

        if metadata.freshness == .livePreferred || metadata.freshness == .liveRequired {
            badges.append(liveFreshnessBadge())
        }

        return deduplicated(badges)
    }

    nonisolated private static func providerBadge(
        for metadata: ResultProviderMetadata
    ) -> ProviderStatusBadgeModel {
        switch metadata.providerFamily {
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
                label: metadata.providerID ?? "Remote provider",
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
            return blockedCostBadge()
        case .blockedByPrivacy:
            return blockedPrivacyBadge()
        case .blockedByTerms:
            return blockedTermsBadge()
        }
    }

    nonisolated private static func blockedBadge(
        for costClass: ProviderCostClass
    ) -> ProviderStatusBadgeModel {
        switch costClass {
        case .blockedByPrivacy:
            return blockedPrivacyBadge()
        case .blockedByCost:
            return blockedCostBadge()
        case .freeLocal, .includedQuota, .meteredPremium, .blockedByTerms:
            return blockedTermsBadge()
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

    nonisolated private static func staleCacheBadge() -> ProviderStatusBadgeModel {
        ProviderStatusBadgeModel(
            kind: .staleCache,
            label: "Stale cache",
            systemImage: "clock.arrow.circlepath",
            tone: .warning
        )
    }

    nonisolated private static func liveFreshnessBadge() -> ProviderStatusBadgeModel {
        ProviderStatusBadgeModel(
            kind: .liveFreshness,
            label: "Live freshness",
            systemImage: "dot.radiowaves.left.and.right",
            tone: .positive
        )
    }

    nonisolated private static func dryRunBadges(
        for presentation: ServerProviderDryRunPresentation
    ) -> [ProviderStatusBadgeModel] {
        var badges: [ProviderStatusBadgeModel] = []

        if let selected = presentation.rows.first(where: { $0.kind == .selectedProvider }) {
            badges.append(dryRunProviderBadge(for: selected.providerFamily))
            if let costClass = selected.costClass {
                badges.append(costBadge(for: costClass))
            }
            if let freshness = selected.freshness,
               let freshnessBadge = dryRunFreshnessBadge(for: freshness) {
                badges.append(freshnessBadge)
            }
        } else {
            for row in presentation.rows {
                if let providerFamily = row.providerFamily {
                    badges.append(dryRunProviderBadge(for: providerFamily))
                }
                if let costClass = row.costClass {
                    badges.append(costBadge(for: costClass))
                }
                if row.fallbackReason == .freshnessRejected {
                    badges.append(staleCacheBadge())
                } else if let freshness = row.freshness,
                          dryRunCanShowFreshnessBadge(for: row),
                          let freshnessBadge = dryRunFreshnessBadge(for: freshness) {
                    badges.append(freshnessBadge)
                }
                if dryRunHasPrivacyDenial(row) {
                    badges.append(blockedPrivacyBadge())
                } else if dryRunHasFactoryRejection(row),
                          row.costClass == nil {
                    badges.append(blockedTermsBadge())
                }
            }
        }

        if badges.isEmpty {
            badges.append(unavailableBadge())
        }
        return deduplicated(badges)
    }

    nonisolated private static func receiptBadges(
        for receipt: ServerProviderRuntimeReceipt
    ) -> [ProviderStatusBadgeModel] {
        var badges: [ProviderStatusBadgeModel] = []

        switch receipt.state {
        case .fixtureProjected:
            badges.append(dryRunProviderBadge(for: receipt.providerFamily))
            if let costClass = receipt.costClass {
                badges.append(costBadge(for: costClass))
            }
            if let freshness = receipt.freshness,
               let freshnessBadge = dryRunFreshnessBadge(for: freshness) {
                badges.append(freshnessBadge)
            }
        case .localOnly:
            badges.append(localOnlyReceiptProviderBadge(for: receipt))
            badges.append(costBadge(for: .freeLocal))
        case .confirmationRequired:
            badges.append(unavailableBadge())
        case .blocked:
            if receipt.audit.validatorDenialReason == .privacyBlocked {
                badges.append(blockedPrivacyBadge())
            } else {
                badges.append(blockedTermsBadge())
            }
        case .descriptorUnavailable, .planRejected, .notPrepared:
            badges.append(unavailableBadge())
        case .unavailable:
            badges.append(unavailableBadge())
        }

        if badges.isEmpty {
            badges.append(unavailableBadge())
        }
        return deduplicated(badges)
    }

    nonisolated private static func searchAPIRequestDecisionBadges(
        for decision: ServerProviderSearchAPIAdapterRequestDecision
    ) -> [ProviderStatusBadgeModel] {
        switch decision.state {
        case .requestPrepared:
            guard let request = decision.request else {
                return [unavailableBadge()]
            }
            var badges = [
                dryRunProviderBadge(for: request.providerFamily),
                costBadge(for: request.costClass),
            ]
            if let freshnessBadge = dryRunFreshnessBadge(for: request.freshness) {
                badges.append(freshnessBadge)
            }
            return deduplicated(badges)
        case .rejected:
            return [searchAPIRejectionBadge(for: decision.rejection)]
        }
    }

    nonisolated private static func searchAPIResultReceiptBadges(
        for receipt: ServerProviderSearchAPIAdapterResultReceipt
    ) -> [ProviderStatusBadgeModel] {
        switch receipt.state {
        case .resultNormalized:
            guard let result = receipt.result else {
                return [unavailableBadge()]
            }
            var badges = [
                dryRunProviderBadge(for: result.providerFamily),
                costBadge(for: result.costClass),
            ]
            if let freshnessBadge = dryRunFreshnessBadge(for: result.freshness) {
                badges.append(freshnessBadge)
            }
            return deduplicated(badges)
        case .rejected:
            return [searchAPIRejectionBadge(for: receipt.rejection)]
        }
    }

    nonisolated private static func searchAPIRejectionBadge(
        for reason: ServerProviderSearchAPIAdapterRejectionReason?
    ) -> ProviderStatusBadgeModel {
        switch reason {
        case .privacyBlocked:
            return blockedPrivacyBadge()
        case .quotaBlocked, .entitlementMissing:
            return blockedCostBadge()
        case .connectorReceiptRejected, .connectorMetadataMissing,
             .connectorProviderFamilyMismatch, .connectorCapabilityMismatch,
             .connectorTraceMismatch, .connectorCostMismatch,
             .connectorFreshnessMismatch:
            return unavailableBadge()
        case .resultStaleForLiveRequired:
            return staleCacheBadge()
        case .emptyQuery, .invalidResultLimit, .providerFamilyNotSearchAPI,
             .unsupportedCapability, .sourcePolicyInsufficient,
             .citationPolicyMissing, .resultContentMissing,
             .resultCitationMissing, .resultCitationSourceMismatch, .none:
            return blockedTermsBadge()
        }
    }

    nonisolated private static func searchAPIVendorPolicyBadges(
        for decision: ServerProviderSearchAPIVendorPolicyDecision
    ) -> [ProviderStatusBadgeModel] {
        switch decision.state {
        case .accepted:
            var badges = [
                dryRunProviderBadge(for: decision.providerFamily),
            ]
            if let costClass = decision.costClass {
                badges.append(costBadge(for: costClass))
            }
            if let freshness = decision.freshness,
               let freshnessBadge = dryRunFreshnessBadge(for: freshness) {
                badges.append(freshnessBadge)
            }
            return deduplicated(badges)
        case .rejected:
            return [searchAPIVendorPolicyRejectionBadge(for: decision.rejection)]
        }
    }

    nonisolated private static func searchAPIVendorPolicyRejectionBadge(
        for reason: ServerProviderSearchAPIVendorPolicyRejectionReason?
    ) -> ProviderStatusBadgeModel {
        switch reason {
        case .privacyBlocked:
            return blockedPrivacyBadge()
        case .providerDisabled, .providerNotAllowed, .entitlementMissing,
             .includedQuotaExhausted, .meteredEligibilityMissing,
             .costClassMismatch, .unsupportedCostClass:
            return blockedCostBadge()
        case .unsupportedFreshness:
            return staleCacheBadge()
        case .vendorDisabled, .providerFamilyMismatch, .unsupportedCapability,
             .citationSupportMissing, .sourceSupportMissing,
             .attributionSupportMissing, .pageBodyNotAllowed,
             .pageBodyRequiredUnsupported, .retentionConflict,
             .unsupportedResultShape, .none:
            return blockedTermsBadge()
        }
    }

    nonisolated private static func searchAPIVendorDispatchAuthorizationBadges(
        for authorization: ServerProviderSearchAPIVendorPolicyDispatchAuthorization
    ) -> [ProviderStatusBadgeModel] {
        switch authorization.state {
        case .authorized:
            var badges = [
                dryRunProviderBadge(for: authorization.providerFamily),
            ]
            if let costClass = authorization.costClass {
                badges.append(costBadge(for: costClass))
            }
            if let freshness = authorization.freshness,
               let freshnessBadge = dryRunFreshnessBadge(for: freshness) {
                badges.append(freshnessBadge)
            }
            return deduplicated(badges)
        case .rejected:
            return [
                searchAPIVendorDispatchAuthorizationRejectionBadge(
                    authorization: authorization
                ),
            ]
        }
    }

    nonisolated private static func searchAPIVendorDispatchAuthorizationRejectionBadge(
        authorization: ServerProviderSearchAPIVendorPolicyDispatchAuthorization
    ) -> ProviderStatusBadgeModel {
        switch authorization.rejection {
        case .missingDispatchReceipt, .dispatchNotEligible, .missingVendorPolicyDecision:
            return unavailableBadge()
        case .vendorPolicyNotAccepted:
            return searchAPIVendorPolicyRejectionBadge(for: authorization.vendorPolicyRejection)
        case .costClassMismatch:
            return blockedCostBadge()
        case .freshnessMismatch:
            return staleCacheBadge()
        case .providerFamilyMismatch, .capabilityMismatch, .resultShapeMismatch, .none:
            return blockedTermsBadge()
        }
    }

    nonisolated private static func localOnlyReceiptProviderBadge(
        for receipt: ServerProviderRuntimeReceipt
    ) -> ProviderStatusBadgeModel {
        if receipt.statusLine.localizedCaseInsensitiveContains("cache") {
            return dryRunProviderBadge(for: .cache)
        }
        return dryRunProviderBadge(for: .appleLocal)
    }

    nonisolated private static func dryRunCanShowFreshnessBadge(
        for row: ServerProviderDryRunPresentationRow
    ) -> Bool {
        row.validatorDenialReason == nil && dryRunHasFactoryRejection(row) == false
    }

    nonisolated private static func dryRunHasFactoryRejection(
        _ row: ServerProviderDryRunPresentationRow
    ) -> Bool {
        guard case nil = row.factoryRejectionReason else {
            return true
        }
        return false
    }

    nonisolated private static func dryRunHasPrivacyDenial(
        _ row: ServerProviderDryRunPresentationRow
    ) -> Bool {
        guard case .privacyBlocked? = row.validatorDenialReason else {
            return false
        }
        return true
    }

    nonisolated private static func dryRunProviderBadge(
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

    nonisolated private static func dryRunFreshnessBadge(
        for freshness: ProviderFreshness
    ) -> ProviderStatusBadgeModel? {
        switch freshness {
        case .cachedOK:
            return nil
        case .livePreferred, .liveRequired:
            return liveFreshnessBadge()
        }
    }

    nonisolated private static func dryRunStatusLine(
        for presentation: ServerProviderDryRunPresentation
    ) -> String {
        var segments = [presentation.summary]

        if dryRunHasSelection(presentation) {
            segments.append(
                contentsOf: presentation.rows
                    .filter { row in
                        row.kind == .fallbackStatus
                            || row.kind == .costStatus
                            || row.kind == .freshnessStatus
                            || row.kind == .sourceStatus
                    }
                    .map(dryRunLineSegment)
            )
        } else {
            segments.append(contentsOf: presentation.rows.map(dryRunLineSegment))
        }

        return deduplicatedStatusSegments(segments)
            .joined(separator: " ")
    }

    nonisolated private static func dryRunLineSegment(
        for row: ServerProviderDryRunPresentationRow
    ) -> String {
        "\(row.title). \(row.detail)"
    }

    nonisolated private static func dryRunCardHint(
        for presentation: ServerProviderDryRunPresentation
    ) -> ProviderStatusCardHint {
        if dryRunHasSelection(presentation) {
            return presentation.tone == .warning ? .warning : .normal
        }
        if presentation.rows.contains(where: { $0.fallbackReason == .freshnessRejected }) {
            return .warning
        }
        return .disabled
    }

    nonisolated private static func receiptCardHint(
        for receipt: ServerProviderRuntimeReceipt
    ) -> ProviderStatusCardHint {
        switch receipt.state {
        case .fixtureProjected:
            return receipt.costClass == .meteredPremium ? .warning : .normal
        case .localOnly:
            return .normal
        case .confirmationRequired, .blocked, .unavailable:
            return .disabled
        case .descriptorUnavailable, .planRejected, .notPrepared:
            return .warning
        }
    }

    nonisolated private static func dryRunHasSelection(
        _ presentation: ServerProviderDryRunPresentation
    ) -> Bool {
        presentation.rows.contains { $0.kind == .selectedProvider }
    }

    nonisolated private static func statusLine(
        state: ProjectedRecommendationState,
        metadata: ResultProviderMetadata
    ) -> String {
        if state == .blocked || state == .unavailable {
            return metadata.limitations.first ?? "Provider is unavailable."
        }
        if isStaleCache(metadata) {
            return SearchProviderPolicy.staleCacheLimitation
        }
        let provider = metadata.providerID ?? "local"
        return "Provider \(provider) · \(metadata.costClass.rawValue) · \(metadata.freshness.rawValue)"
    }

    nonisolated private static func receiptStatusLine(
        for receipt: ServerProviderRuntimeReceipt
    ) -> String {
        let segments: [String]

        switch receipt.state {
        case .fixtureProjected:
            segments = [
                "Runtime receipt is projected from fixture metadata only.",
                receiptProviderSegment(for: receipt),
                receiptCostSegment(for: receipt),
                receiptFreshnessSegment(for: receipt),
                receiptSourceSegment(for: receipt),
                "No provider runtime has run.",
            ]
        case .localOnly:
            segments = [
                "Runtime receipt remains local-only.",
                localOnlyReceiptSegment(for: receipt),
                "No server adapter output is available.",
            ]
        case .confirmationRequired:
            segments = [
                "Confirmation is required before runtime receipt projection can expose provider output.",
                receiptRejectionSegment(for: receipt),
            ]
        case .blocked:
            segments = [
                "Runtime receipt is blocked by policy.",
                receiptRejectionSegment(for: receipt),
            ]
        case .descriptorUnavailable:
            segments = [
                "Runtime receipt is missing descriptor metadata.",
                receiptRejectionSegment(for: receipt),
            ]
        case .planRejected:
            segments = [
                "Runtime receipt is based on rejected plan metadata.",
                receiptRejectionSegment(for: receipt),
            ]
        case .notPrepared:
            segments = [
                "Runtime receipt is not prepared for provider display.",
                receiptRejectionSegment(for: receipt),
            ]
        case .unavailable:
            segments = [
                "Runtime receipt is unavailable because no registered adapter output can be projected.",
                receiptRejectionSegment(for: receipt),
            ]
        }

        return deduplicatedStatusSegments(segments)
            .joined(separator: " ")
    }

    nonisolated private static func receiptProviderSegment(
        for receipt: ServerProviderRuntimeReceipt
    ) -> String {
        guard let providerFamily = receipt.providerFamily else {
            return "Provider family is unavailable."
        }
        return "Provider family: \(providerFamily.rawValue)."
    }

    nonisolated private static func receiptCostSegment(
        for receipt: ServerProviderRuntimeReceipt
    ) -> String {
        guard let costClass = receipt.costClass else {
            return "Cost class is unavailable."
        }
        return "Cost: \(costClass.rawValue)."
    }

    nonisolated private static func receiptFreshnessSegment(
        for receipt: ServerProviderRuntimeReceipt
    ) -> String {
        guard let freshness = receipt.freshness else {
            return "Freshness is unavailable."
        }
        return "Freshness: \(freshness.rawValue)."
    }

    nonisolated private static func receiptSourceSegment(
        for receipt: ServerProviderRuntimeReceipt
    ) -> String {
        guard let sourcePolicy = receipt.sourcePolicy else {
            return "Source policy is unavailable."
        }
        var details = ["Source: \(sourcePolicy.sourceState.rawValue)"]
        if sourcePolicy.robotsState != .notApplicable {
            details.append("robots \(sourcePolicy.robotsState.rawValue)")
        }
        if let sourceHost = sourcePolicy.sourceHost,
           sourceHost.isEmpty == false {
            details.append(sourceHost)
        }
        return details.joined(separator: " · ") + "."
    }

    nonisolated private static func localOnlyReceiptSegment(
        for receipt: ServerProviderRuntimeReceipt
    ) -> String {
        receipt.statusLine.localizedCaseInsensitiveContains("cache")
            ? "Local cache route stays on device."
            : "Apple/local route stays on device."
    }

    nonisolated private static func receiptRejectionSegment(
        for receipt: ServerProviderRuntimeReceipt
    ) -> String {
        if let validatorDenialReason = receipt.audit.validatorDenialReason {
            return "Validator reason: \(validatorDenialReason.rawValue)."
        }
        if let adapterRejectionReason = receipt.audit.adapterRejectionReason {
            return "Adapter reason: \(adapterRejectionReason.rawValue)."
        }
        if let dispatchRejectionReason = receipt.audit.dispatchRejectionReason {
            return "Dispatch reason: \(dispatchRejectionReason.rawValue)."
        }
        if let factoryRejectionReason = receipt.audit.factoryRejectionReason {
            return "Factory reason: \(factoryRejectionReason)."
        }
        return "Reason is unavailable."
    }

    nonisolated private static func searchAPIRequestDecisionStatusLine(
        for decision: ServerProviderSearchAPIAdapterRequestDecision
    ) -> String {
        switch decision.state {
        case .requestPrepared:
            guard let request = decision.request else {
                return "Search API adapter request metadata is unavailable. No provider runtime has run."
            }
            return deduplicatedStatusSegments([
                "Search API adapter request is prepared from approved metadata only.",
                "Capability: \(request.capability.rawValue).",
                "Cost: \(request.costClass.rawValue).",
                "Freshness: \(request.freshness.rawValue).",
                searchAPICitationSegment(
                    required: request.sourcePolicy.citationRequired,
                    sourceHost: request.sourcePolicy.sourceHost
                ),
                "No provider runtime has run.",
            ])
            .joined(separator: " ")
        case .rejected:
            return deduplicatedStatusSegments([
                "Search API adapter request is blocked by metadata policy.",
                searchAPIRejectionSegment(for: decision.rejection),
                "No provider runtime has run.",
            ])
            .joined(separator: " ")
        }
    }

    nonisolated private static func searchAPIResultReceiptStatusLine(
        for receipt: ServerProviderSearchAPIAdapterResultReceipt
    ) -> String {
        switch receipt.state {
        case .resultNormalized:
            guard let result = receipt.result else {
                return "Search API adapter result metadata is unavailable. No provider runtime has run."
            }
            return deduplicatedStatusSegments([
                "Search API adapter result is normalized from cited metadata only.",
                "Capability: \(result.capability.rawValue).",
                "Cost: \(result.costClass.rawValue).",
                "Freshness: \(result.freshness.rawValue).",
                searchAPIResultCitationSegment(for: result),
                "No provider runtime has run.",
            ])
            .joined(separator: " ")
        case .rejected:
            return deduplicatedStatusSegments([
                "Search API adapter result is blocked by metadata policy.",
                searchAPIRejectionSegment(for: receipt.rejection),
                "No provider runtime has run.",
            ])
            .joined(separator: " ")
        }
    }

    nonisolated private static func searchAPICitationSegment(
        required: Bool,
        sourceHost: String?
    ) -> String {
        guard required else {
            return "Citation policy is required before display."
        }
        guard let sourceHost,
              sourceHost.isEmpty == false else {
            return "Citation required."
        }
        return "Citation required for \(sourceHost)."
    }

    nonisolated private static func searchAPIResultCitationSegment(
        for result: ServerProviderSearchAPIAdapterResult
    ) -> String {
        let hosts = result.citations.map(\.sourceHost).filter { $0.isEmpty == false }
        guard let firstHost = hosts.first else {
            return "Citation required."
        }
        return "Citations: \(result.citations.count) source(s), including \(firstHost)."
    }

    nonisolated private static func searchAPIRejectionSegment(
        for reason: ServerProviderSearchAPIAdapterRejectionReason?
    ) -> String {
        guard let reason else {
            return "Reason: unavailable."
        }
        return "Reason: \(reason.rawValue)."
    }

    nonisolated private static func searchAPIVendorPolicyStatusLine(
        for decision: ServerProviderSearchAPIVendorPolicyDecision
    ) -> String {
        switch decision.state {
        case .accepted:
            var segments = [
                "Search API vendor policy is accepted from approved metadata only.",
                "Vendor: \(decision.vendorID).",
            ]
            if let capability = decision.capability {
                segments.append("Capability: \(capability.rawValue).")
            }
            if let costClass = decision.costClass {
                segments.append("Cost: \(costClass.rawValue).")
            }
            if let freshness = decision.freshness {
                segments.append("Freshness: \(freshness.rawValue).")
            }
            if let resultShape = decision.resultShape {
                segments.append("Result shape: \(resultShape.rawValue).")
            }
            segments.append("No provider runtime has run.")
            return deduplicatedStatusSegments(segments)
            .joined(separator: " ")
        case .rejected:
            return deduplicatedStatusSegments([
                "Search API vendor policy is blocked by metadata policy.",
                searchAPIVendorPolicyRejectionSegment(for: decision.rejection),
                "Vendor: \(decision.vendorID).",
                "No provider runtime has run.",
            ])
            .joined(separator: " ")
        }
    }

    nonisolated private static func searchAPIVendorPolicyRejectionSegment(
        for reason: ServerProviderSearchAPIVendorPolicyRejectionReason?
    ) -> String {
        guard let reason else {
            return "Reason: unavailable."
        }
        return "Reason: \(reason.rawValue)."
    }

    nonisolated private static func searchAPIVendorDispatchAuthorizationStatusLine(
        for authorization: ServerProviderSearchAPIVendorPolicyDispatchAuthorization
    ) -> String {
        switch authorization.state {
        case .authorized:
            var segments = [
                "Search API vendor dispatch authorization is ready from verified metadata only.",
                searchAPIVendorDispatchAuthorizationVendorSegment(for: authorization),
            ]
            if let capability = authorization.capability {
                segments.append("Capability: \(capability.rawValue).")
            }
            if let costClass = authorization.costClass {
                segments.append("Cost: \(costClass.rawValue).")
            }
            if let freshness = authorization.freshness {
                segments.append("Freshness: \(freshness.rawValue).")
            }
            if let resultShape = authorization.resultShape {
                segments.append("Result shape: \(resultShape.rawValue).")
            }
            segments.append("No transport or provider runtime has run.")
            return deduplicatedStatusSegments(segments)
                .joined(separator: " ")
        case .rejected:
            return deduplicatedStatusSegments([
                "Search API vendor dispatch authorization is blocked by metadata policy.",
                searchAPIVendorDispatchAuthorizationRejectionSegment(for: authorization.rejection),
                searchAPIVendorDispatchAuthorizationDispatchSegment(for: authorization.dispatchRejection),
                searchAPIVendorDispatchAuthorizationVendorPolicySegment(
                    for: authorization.vendorPolicyRejection
                ),
                searchAPIVendorDispatchAuthorizationVendorSegment(for: authorization),
                "No transport or provider runtime has run.",
            ])
            .joined(separator: " ")
        }
    }

    nonisolated private static func searchAPIVendorDispatchAuthorizationRejectionSegment(
        for reason: ServerProviderSearchAPIVendorPolicyDispatchAuthorizationRejectionReason?
    ) -> String {
        guard let reason else {
            return "Authorization reason: unavailable."
        }
        return "Authorization reason: \(reason.rawValue)."
    }

    nonisolated private static func searchAPIVendorDispatchAuthorizationDispatchSegment(
        for reason: ServerProviderSearchAPIAdapterPayloadDispatchRejectionReason?
    ) -> String {
        guard let reason else {
            return "Dispatch reason: unavailable."
        }
        return "Dispatch reason: \(reason.rawValue)."
    }

    nonisolated private static func searchAPIVendorDispatchAuthorizationVendorPolicySegment(
        for reason: ServerProviderSearchAPIVendorPolicyRejectionReason?
    ) -> String {
        guard let reason else {
            return "Vendor policy reason: unavailable."
        }
        return "Vendor policy reason: \(reason.rawValue)."
    }

    nonisolated private static func searchAPIVendorDispatchAuthorizationVendorSegment(
        for authorization: ServerProviderSearchAPIVendorPolicyDispatchAuthorization
    ) -> String {
        guard let vendorID = authorization.vendorID,
              vendorID.isEmpty == false else {
            return "Vendor: unavailable."
        }
        return "Vendor: \(vendorID)."
    }

    nonisolated private static func searchAPIRequestDecisionCardHint(
        for decision: ServerProviderSearchAPIAdapterRequestDecision
    ) -> ProviderStatusCardHint {
        guard decision.state == .requestPrepared,
              let request = decision.request else {
            return .disabled
        }
        return request.costClass == .meteredPremium ? .warning : .normal
    }

    nonisolated private static func searchAPIResultReceiptCardHint(
        for receipt: ServerProviderSearchAPIAdapterResultReceipt
    ) -> ProviderStatusCardHint {
        guard receipt.state == .resultNormalized,
              let costClass = receipt.costClass else {
            return .disabled
        }
        return costClass == .meteredPremium ? .warning : .normal
    }

    nonisolated private static func searchAPIVendorPolicyCardHint(
        for decision: ServerProviderSearchAPIVendorPolicyDecision
    ) -> ProviderStatusCardHint {
        guard decision.state == .accepted else {
            return .disabled
        }
        return decision.costClass == .meteredPremium ? .warning : .normal
    }

    nonisolated private static func searchAPIVendorDispatchAuthorizationCardHint(
        for authorization: ServerProviderSearchAPIVendorPolicyDispatchAuthorization
    ) -> ProviderStatusCardHint {
        guard authorization.state == .authorized else {
            return .disabled
        }
        return authorization.costClass == .meteredPremium ? .warning : .normal
    }

    nonisolated private static func cardHint(
        for state: ProjectedRecommendationState
    ) -> ProviderStatusCardHint {
        switch state {
        case .ready:
            return .normal
        case .blocked:
            return .disabled
        case .unavailable:
            return .warning
        }
    }

    nonisolated private static func isStaleCache(
        _ metadata: ResultProviderMetadata
    ) -> Bool {
        metadata.providerFamily == .cache
            && metadata.freshness == .cachedOK
            && metadata.limitations.contains(SearchProviderPolicy.staleCacheLimitation)
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

extension ProjectedRecommendationProvider: ProviderStatusProviding {
    func providerStatusPresentation(for recommendationID: String) -> ProviderStatusPresentation? {
        guard let recommendation = projectedRecommendations()
            .first(where: { $0.id == recommendationID })
        else {
            return nil
        }

        return ProviderStatusBadgeResolver.presentation(for: recommendation)
    }
}
