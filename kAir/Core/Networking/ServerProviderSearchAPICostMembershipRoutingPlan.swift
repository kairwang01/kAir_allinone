//
//  ServerProviderSearchAPICostMembershipRoutingPlan.swift
//  kAir
//
//  A170 value-only plan for Search API cost and membership routing labels.
//  The plan uses the A169 stack-plan extension slots without installing a
//  production source or selecting a concrete vendor.
//

import Foundation

enum ServerProviderSearchAPICostMembershipRouteKind:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case localFallback
    case includedQuotaPreferred
    case meteredAllowed
    case regionReview
    case costBlocked
    case unsupportedRoute

    nonisolated static let defaultOrder: [Self] = [
        .localFallback,
        .includedQuotaPreferred,
        .meteredAllowed,
        .regionReview,
        .costBlocked,
    ]

    nonisolated var defaultRank: Int {
        Self.defaultOrder.firstIndex(of: self).map { $0 + 1 } ?? 0
    }

    nonisolated var routeID: String {
        switch self {
        case .localFallback:
            return "search-api-cost-route-local-fallback"
        case .includedQuotaPreferred:
            return "search-api-cost-route-included-quota-preferred"
        case .meteredAllowed:
            return "search-api-cost-route-metered-allowed"
        case .regionReview:
            return "search-api-cost-route-region-review"
        case .costBlocked:
            return "search-api-cost-route-cost-blocked"
        case .unsupportedRoute:
            return "search-api-cost-route-unsupported"
        }
    }

    nonisolated var uiLabel: String {
        switch self {
        case .localFallback:
            return "Local fallback"
        case .includedQuotaPreferred:
            return "Included quota preferred"
        case .meteredAllowed:
            return "Metered allowed"
        case .regionReview:
            return "Region review"
        case .costBlocked:
            return "Cost blocked"
        case .unsupportedRoute:
            return "Unsupported route"
        }
    }

    nonisolated var reviewerNote: String {
        switch self {
        case .localFallback:
            return "Keeps local and cache posture ahead of remote advisory status."
        case .includedQuotaPreferred:
            return "Uses included quota metadata before metered posture."
        case .meteredAllowed:
            return "Allows metered posture only for eligible membership metadata."
        case .regionReview:
            return "Defers region-specific vendor choice to later policy review."
        case .costBlocked:
            return "Shows blocked status when budget metadata does not allow a remote path."
        case .unsupportedRoute:
            return "Rejected placeholder for validation coverage."
        }
    }

    nonisolated var eligibleMembershipTiers: [MembershipTier] {
        switch self {
        case .localFallback, .costBlocked:
            return MembershipTier.allCases
        case .includedQuotaPreferred, .regionReview:
            return [.plus, .pro, .developerInternal]
        case .meteredAllowed:
            return [.pro, .developerInternal]
        case .unsupportedRoute:
            return []
        }
    }

    nonisolated var minimumMembershipTier: MembershipTier {
        switch self {
        case .localFallback, .costBlocked:
            return .free
        case .includedQuotaPreferred, .regionReview:
            return .plus
        case .meteredAllowed:
            return .pro
        case .unsupportedRoute:
            return .developerInternal
        }
    }
}

enum ServerProviderSearchAPIQuotaPosture:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case notRequired
    case includedAvailable
    case meteredEligible
    case reviewRequired
    case unavailable
}

enum ServerProviderSearchAPICostPosture:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case localOnly
    case includedQuota
    case metered
    case reviewRequired
    case blocked
}

enum ServerProviderSearchAPIRegionPosture:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case localOnly
    case globalAllowed
    case regionReviewRequired
}

struct ServerProviderSearchAPICostMembershipRoute:
    Codable,
    Hashable,
    Identifiable,
    Sendable
{
    let kind: ServerProviderSearchAPICostMembershipRouteKind
    let id: String
    let rank: Int
    let minimumMembershipTier: MembershipTier
    let eligibleMembershipTiers: [MembershipTier]
    let quotaPosture: ServerProviderSearchAPIQuotaPosture
    let costPosture: ServerProviderSearchAPICostPosture
    let costClasses: [ProviderCostClass]
    let region: ProviderRegion
    let regionPosture: ServerProviderSearchAPIRegionPosture
    let uiLabel: String
    let reviewerNote: String

    nonisolated init(kind: ServerProviderSearchAPICostMembershipRouteKind) {
        self.init(
            kind: kind,
            id: kind.routeID,
            rank: kind.defaultRank,
            minimumMembershipTier: kind.minimumMembershipTier,
            eligibleMembershipTiers: kind.eligibleMembershipTiers,
            quotaPosture: kind.defaultQuotaPosture,
            costPosture: kind.defaultCostPosture,
            costClasses: kind.defaultCostClasses,
            region: kind.defaultRegion,
            regionPosture: kind.defaultRegionPosture,
            uiLabel: kind.uiLabel,
            reviewerNote: kind.reviewerNote
        )
    }

    nonisolated init(
        kind: ServerProviderSearchAPICostMembershipRouteKind,
        id: String,
        rank: Int,
        minimumMembershipTier: MembershipTier,
        eligibleMembershipTiers: [MembershipTier],
        quotaPosture: ServerProviderSearchAPIQuotaPosture,
        costPosture: ServerProviderSearchAPICostPosture,
        costClasses: [ProviderCostClass],
        region: ProviderRegion,
        regionPosture: ServerProviderSearchAPIRegionPosture,
        uiLabel: String,
        reviewerNote: String
    ) {
        self.kind = kind
        self.id = Self.safeID(id, fallback: kind.routeID)
        self.rank = rank
        self.minimumMembershipTier = minimumMembershipTier
        self.eligibleMembershipTiers = Self.deduplicated(eligibleMembershipTiers)
        self.quotaPosture = quotaPosture
        self.costPosture = costPosture
        self.costClasses = Self.deduplicated(costClasses)
        self.region = region
        self.regionPosture = regionPosture
        self.uiLabel = uiLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        self.reviewerNote = reviewerNote.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private nonisolated static func safeID(
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

    private nonisolated static func deduplicated<T: Hashable>(
        _ values: [T]
    ) -> [T] {
        var seen: Set<T> = []
        var result: [T] = []
        for value in values where seen.insert(value).inserted {
            result.append(value)
        }
        return result
    }
}

private extension ServerProviderSearchAPICostMembershipRouteKind {
    nonisolated var defaultQuotaPosture: ServerProviderSearchAPIQuotaPosture {
        switch self {
        case .localFallback:
            return .notRequired
        case .includedQuotaPreferred:
            return .includedAvailable
        case .meteredAllowed:
            return .meteredEligible
        case .regionReview:
            return .reviewRequired
        case .costBlocked, .unsupportedRoute:
            return .unavailable
        }
    }

    nonisolated var defaultCostPosture: ServerProviderSearchAPICostPosture {
        switch self {
        case .localFallback:
            return .localOnly
        case .includedQuotaPreferred:
            return .includedQuota
        case .meteredAllowed:
            return .metered
        case .regionReview:
            return .reviewRequired
        case .costBlocked, .unsupportedRoute:
            return .blocked
        }
    }

    nonisolated var defaultCostClasses: [ProviderCostClass] {
        switch self {
        case .localFallback:
            return [.freeLocal]
        case .includedQuotaPreferred:
            return [.includedQuota]
        case .meteredAllowed:
            return [.meteredPremium]
        case .regionReview:
            return [.includedQuota, .meteredPremium]
        case .costBlocked, .unsupportedRoute:
            return [.blockedByCost]
        }
    }

    nonisolated var defaultRegion: ProviderRegion {
        switch self {
        case .regionReview:
            return .china
        case .localFallback, .includedQuotaPreferred, .meteredAllowed,
             .costBlocked, .unsupportedRoute:
            return .global
        }
    }

    nonisolated var defaultRegionPosture: ServerProviderSearchAPIRegionPosture {
        switch self {
        case .localFallback:
            return .localOnly
        case .regionReview:
            return .regionReviewRequired
        case .includedQuotaPreferred, .meteredAllowed, .costBlocked,
             .unsupportedRoute:
            return .globalAllowed
        }
    }
}

enum ServerProviderSearchAPICostMembershipRoutingExtensionKind:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case serverOwnedVendorSelection
    case membershipPackageMapping
    case budgetFallbackReview

    nonisolated var noteID: String {
        switch self {
        case .serverOwnedVendorSelection:
            return "search-api-routing-note-server-owned-vendor-selection"
        case .membershipPackageMapping:
            return "search-api-routing-note-membership-package-mapping"
        case .budgetFallbackReview:
            return "search-api-routing-note-budget-fallback-review"
        }
    }

    nonisolated var reviewerNote: String {
        switch self {
        case .serverOwnedVendorSelection:
            return "Later server policy may bind advisory route labels to vendor choice."
        case .membershipPackageMapping:
            return "Later package rules may map memberships to included or metered posture."
        case .budgetFallbackReview:
            return "Later budget review may tune when local fallback appears first."
        }
    }
}

struct ServerProviderSearchAPICostMembershipRoutingExtensionNote:
    Codable,
    Hashable,
    Identifiable,
    Sendable
{
    let kind: ServerProviderSearchAPICostMembershipRoutingExtensionKind
    let id: String
    let reviewerNote: String

    nonisolated init(kind: ServerProviderSearchAPICostMembershipRoutingExtensionKind) {
        self.kind = kind
        self.id = kind.noteID
        self.reviewerNote = kind.reviewerNote
    }
}

enum ServerProviderSearchAPICostMembershipRoutingPlanValidationState:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case accepted
    case rejected
}

enum ServerProviderSearchAPICostMembershipRoutingPlanValidationReason:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case emptyRoutes
    case duplicateRouteID
    case duplicateRouteKind
    case duplicateRank
    case nonContiguousRanks
    case localFallbackNotFirst
    case routeOrderMismatch
    case routeRankMismatch
    case missingMembershipCoverage
    case unsupportedRouteKind
    case duplicateStatusStackExtensionSlot
    case missingStatusStackExtensionSlot
}

struct ServerProviderSearchAPICostMembershipRoutingPlanValidationResult:
    Codable,
    Hashable,
    Sendable
{
    let state: ServerProviderSearchAPICostMembershipRoutingPlanValidationState
    let reasons: [ServerProviderSearchAPICostMembershipRoutingPlanValidationReason]

    nonisolated var isAccepted: Bool {
        state == .accepted
    }
}

struct ServerProviderSearchAPICostMembershipRoutingPlanSafeCopy:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let routeIDs: [String]
    let routeRanks: [Int]
    let routeKinds: [ServerProviderSearchAPICostMembershipRouteKind]
    let coveredMembershipTiers: [MembershipTier]
    let statusStackExtensionSlotIDs: [String]
    let extensionNoteIDs: [String]
    let isRuntimeCallable: Bool
    let validationState: ServerProviderSearchAPICostMembershipRoutingPlanValidationState
    let validationReasons: [ServerProviderSearchAPICostMembershipRoutingPlanValidationReason]

    nonisolated var description: String {
        "SearchAPICostMembershipRoutingPlanSafeCopy(id: \(id), routes: \(routeIDs.count), callable: \(isRuntimeCallable), validation: \(validationState.rawValue))"
    }
}

struct ServerProviderSearchAPICostMembershipRoutingPlan:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let routes: [ServerProviderSearchAPICostMembershipRoute]
    let statusStackExtensionSlots: [ServerProviderSearchAPIProviderStatusStackExtensionSlot]
    let extensionNotes: [ServerProviderSearchAPICostMembershipRoutingExtensionNote]
    let runtimeEntryPointName: String?

    nonisolated init(
        id: String = "a170-search-api-cost-membership-routing-plan",
        routes: [ServerProviderSearchAPICostMembershipRoute],
        statusStackExtensionSlots: [ServerProviderSearchAPIProviderStatusStackExtensionSlot],
        extensionNotes: [ServerProviderSearchAPICostMembershipRoutingExtensionNote],
        runtimeEntryPointName: String? = nil
    ) {
        self.id = id
        self.routes = routes
        self.statusStackExtensionSlots = statusStackExtensionSlots
        self.extensionNotes = extensionNotes
        self.runtimeEntryPointName = runtimeEntryPointName
    }

    nonisolated static func defaultPlan() -> Self {
        ServerProviderSearchAPICostMembershipRoutingPlan(
            routes: routes(for: ServerProviderSearchAPICostMembershipRouteKind.defaultOrder),
            statusStackExtensionSlots: ServerProviderSearchAPIProviderStatusStackExtensionSlot.defaultSlots,
            extensionNotes: ServerProviderSearchAPICostMembershipRoutingExtensionKind.allCases
                .map(ServerProviderSearchAPICostMembershipRoutingExtensionNote.init),
            runtimeEntryPointName: nil
        )
    }

    nonisolated static func routes(
        for order: [ServerProviderSearchAPICostMembershipRouteKind]
    ) -> [ServerProviderSearchAPICostMembershipRoute] {
        order.map(ServerProviderSearchAPICostMembershipRoute.init)
    }

    nonisolated var isRuntimeCallable: Bool {
        false
    }

    nonisolated var coveredMembershipTiers: [MembershipTier] {
        Self.membershipCoverage(for: routes)
    }

    nonisolated var validation: ServerProviderSearchAPICostMembershipRoutingPlanValidationResult {
        Self.validate(
            routes: routes,
            statusStackExtensionSlots: statusStackExtensionSlots
        )
    }

    nonisolated var safeCopy: ServerProviderSearchAPICostMembershipRoutingPlanSafeCopy {
        let result = validation
        return ServerProviderSearchAPICostMembershipRoutingPlanSafeCopy(
            id: id,
            routeIDs: routes.map(\.id),
            routeRanks: routes.map(\.rank),
            routeKinds: routes.map(\.kind),
            coveredMembershipTiers: coveredMembershipTiers,
            statusStackExtensionSlotIDs: statusStackExtensionSlots.map(\.slotID),
            extensionNoteIDs: extensionNotes.map(\.id),
            isRuntimeCallable: isRuntimeCallable,
            validationState: result.state,
            validationReasons: result.reasons
        )
    }

    nonisolated var description: String {
        "ServerProviderSearchAPICostMembershipRoutingPlan(id: \(id), routes: \(routes.count), slots: \(statusStackExtensionSlots.count), callable: \(isRuntimeCallable), validation: \(validation.state.rawValue))"
    }

    nonisolated static func validate(
        routes: [ServerProviderSearchAPICostMembershipRoute],
        statusStackExtensionSlots: [ServerProviderSearchAPIProviderStatusStackExtensionSlot] = ServerProviderSearchAPIProviderStatusStackExtensionSlot.defaultSlots
    ) -> ServerProviderSearchAPICostMembershipRoutingPlanValidationResult {
        var reasons: [ServerProviderSearchAPICostMembershipRoutingPlanValidationReason] = []

        if routes.isEmpty {
            reasons.append(.emptyRoutes)
        }
        if Set(routes.map(\.id)).count != routes.count {
            reasons.append(.duplicateRouteID)
        }
        if Set(routes.map(\.kind)).count != routes.count {
            reasons.append(.duplicateRouteKind)
        }
        if Set(routes.map(\.rank)).count != routes.count {
            reasons.append(.duplicateRank)
        }
        if !routes.isEmpty, routes.map(\.rank) != Array(1...routes.count) {
            reasons.append(.nonContiguousRanks)
        }
        if routes.first?.kind != .localFallback {
            reasons.append(.localFallbackNotFirst)
        }
        if routes.map(\.kind) != ServerProviderSearchAPICostMembershipRouteKind.defaultOrder {
            reasons.append(.routeOrderMismatch)
        }
        if routes.contains(where: { $0.rank != $0.kind.defaultRank }) {
            reasons.append(.routeRankMismatch)
        }
        if Set(membershipCoverage(for: routes)) != Set(MembershipTier.allCases) {
            reasons.append(.missingMembershipCoverage)
        }
        if routes.contains(where: { ServerProviderSearchAPICostMembershipRouteKind.defaultOrder.contains($0.kind) == false }) {
            reasons.append(.unsupportedRouteKind)
        }
        if Set(statusStackExtensionSlots).count != statusStackExtensionSlots.count {
            reasons.append(.duplicateStatusStackExtensionSlot)
        }
        if Set(statusStackExtensionSlots) != Set(ServerProviderSearchAPIProviderStatusStackExtensionSlot.defaultSlots) {
            reasons.append(.missingStatusStackExtensionSlot)
        }

        let stableReasons = deduplicated(reasons)
        return ServerProviderSearchAPICostMembershipRoutingPlanValidationResult(
            state: stableReasons.isEmpty ? .accepted : .rejected,
            reasons: stableReasons
        )
    }

    private nonisolated static func membershipCoverage(
        for routes: [ServerProviderSearchAPICostMembershipRoute]
    ) -> [MembershipTier] {
        let covered = Set(routes.flatMap(\.eligibleMembershipTiers))
        return MembershipTier.allCases.filter { covered.contains($0) }
    }

    private nonisolated static func deduplicated<T: Hashable>(
        _ values: [T]
    ) -> [T] {
        var seen: Set<T> = []
        var result: [T] = []
        for value in values where seen.insert(value).inserted {
            result.append(value)
        }
        return result
    }
}
