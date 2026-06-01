//
//  ServerProviderSearchAPICostMembershipRoutingDecision.swift
//  kAir
//
//  A171 value-only decision for Search API cost and membership route labels.
//  It consumes the A170 plan plus safe metadata and returns an advisory route
//  label without installing a production source or selecting a concrete vendor.
//

import Foundation

struct ServerProviderSearchAPICostMembershipRoutingDecisionInput:
    Codable,
    Hashable,
    Identifiable,
    Sendable
{
    let id: String
    let membershipTier: MembershipTier
    let requestedCostClass: ProviderCostClass
    let region: ProviderRegion
    let privacyClass: ProviderPrivacyClass
    let quotaSnapshot: ServerProviderQuotaSnapshot
    let preferredRouteKind: ServerProviderSearchAPICostMembershipRouteKind?

    nonisolated init(
        id: String = "a171-search-api-cost-routing-input",
        membershipTier: MembershipTier,
        requestedCostClass: ProviderCostClass,
        region: ProviderRegion,
        privacyClass: ProviderPrivacyClass = .general,
        quotaSnapshot: ServerProviderQuotaSnapshot,
        preferredRouteKind: ServerProviderSearchAPICostMembershipRouteKind? = nil
    ) {
        self.id = Self.safeID(id, fallback: "a171-search-api-cost-routing-input")
        self.membershipTier = membershipTier
        self.requestedCostClass = requestedCostClass
        self.region = region
        self.privacyClass = privacyClass
        self.quotaSnapshot = quotaSnapshot
        self.preferredRouteKind = preferredRouteKind
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
}

enum ServerProviderSearchAPICostMembershipRoutingDecisionState:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case accepted
    case rejected
}

enum ServerProviderSearchAPICostMembershipRoutingDecisionRejectionReason:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case invalidPlan
    case membershipCoverageMissing
    case membershipTierNotEligible
    case privacyBlocksRemotePosture
    case quotaUnavailable
    case costClassBlocked
    case regionReviewRequired
    case preferredRouteNotAllowed
    case routeUnavailable
}

struct ServerProviderSearchAPICostMembershipRoutingDecisionSafeCopy:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let inputID: String
    let planID: String
    let selectedRouteID: String?
    let selectedRouteKind: ServerProviderSearchAPICostMembershipRouteKind?
    let selectedRouteRank: Int?
    let membershipTier: MembershipTier
    let requestedCostClass: ProviderCostClass
    let region: ProviderRegion
    let privacyClass: ProviderPrivacyClass
    let state: ServerProviderSearchAPICostMembershipRoutingDecisionState
    let rejectionReason: ServerProviderSearchAPICostMembershipRoutingDecisionRejectionReason?
    let isRuntimeCallable: Bool

    nonisolated var description: String {
        "SearchAPICostMembershipRoutingDecisionSafeCopy(id: \(id), route: \(selectedRouteKind?.rawValue ?? "none"), state: \(state.rawValue), callable: \(isRuntimeCallable))"
    }
}

struct ServerProviderSearchAPICostMembershipRoutingDecision:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let inputID: String
    let planID: String
    let state: ServerProviderSearchAPICostMembershipRoutingDecisionState
    let selectedRouteID: String?
    let selectedRouteKind: ServerProviderSearchAPICostMembershipRouteKind?
    let selectedRouteRank: Int?
    let selectedRouteLabel: String?
    let membershipTier: MembershipTier
    let requestedCostClass: ProviderCostClass
    let region: ProviderRegion
    let privacyClass: ProviderPrivacyClass
    let statusLine: String
    let rejectionReason: ServerProviderSearchAPICostMembershipRoutingDecisionRejectionReason?

    nonisolated var isAccepted: Bool {
        state == .accepted
    }

    nonisolated var isRuntimeCallable: Bool {
        false
    }

    nonisolated var safeCopy: ServerProviderSearchAPICostMembershipRoutingDecisionSafeCopy {
        ServerProviderSearchAPICostMembershipRoutingDecisionSafeCopy(
            id: id,
            inputID: inputID,
            planID: planID,
            selectedRouteID: selectedRouteID,
            selectedRouteKind: selectedRouteKind,
            selectedRouteRank: selectedRouteRank,
            membershipTier: membershipTier,
            requestedCostClass: requestedCostClass,
            region: region,
            privacyClass: privacyClass,
            state: state,
            rejectionReason: rejectionReason,
            isRuntimeCallable: isRuntimeCallable
        )
    }

    nonisolated var description: String {
        "ServerProviderSearchAPICostMembershipRoutingDecision(id: \(id), state: \(state.rawValue), route: \(selectedRouteKind?.rawValue ?? "none"), callable: \(isRuntimeCallable))"
    }
}

enum ServerProviderSearchAPICostMembershipRoutingDecider {
    nonisolated static func decide(
        input: ServerProviderSearchAPICostMembershipRoutingDecisionInput,
        plan: ServerProviderSearchAPICostMembershipRoutingPlan = .defaultPlan()
    ) -> ServerProviderSearchAPICostMembershipRoutingDecision {
        let planValidation = plan.validation
        guard planValidation.isAccepted else {
            let reason: ServerProviderSearchAPICostMembershipRoutingDecisionRejectionReason =
                planValidation.reasons.contains(.missingMembershipCoverage)
                    ? .membershipCoverageMissing
                    : .invalidPlan
            return rejected(
                input: input,
                plan: plan,
                route: nil,
                reason: reason
            )
        }

        guard let localRoute = route(.localFallback, in: plan),
              let includedRoute = route(.includedQuotaPreferred, in: plan),
              let meteredRoute = route(.meteredAllowed, in: plan),
              let regionRoute = route(.regionReview, in: plan),
              let costBlockedRoute = route(.costBlocked, in: plan) else {
            return rejected(
                input: input,
                plan: plan,
                route: nil,
                reason: .invalidPlan
            )
        }

        if input.requestedCostClass == .freeLocal {
            return finish(
                input: input,
                plan: plan,
                route: localRoute,
                state: .accepted,
                reason: nil
            )
        }

        guard allowsRemotePosture(input.privacyClass) else {
            return finish(
                input: input,
                plan: plan,
                route: localRoute,
                state: .rejected,
                reason: .privacyBlocksRemotePosture
            )
        }

        if input.region == .china {
            return finish(
                input: input,
                plan: plan,
                route: regionRoute,
                state: .rejected,
                reason: .regionReviewRequired
            )
        }

        switch input.requestedCostClass {
        case .includedQuota:
            guard includedRoute.eligibleMembershipTiers.contains(input.membershipTier) else {
                return finish(
                    input: input,
                    plan: plan,
                    route: costBlockedRoute,
                    state: .rejected,
                    reason: .membershipTierNotEligible
                )
            }
            guard hasIncludedQuota(input.quotaSnapshot) else {
                return finish(
                    input: input,
                    plan: plan,
                    route: costBlockedRoute,
                    state: .rejected,
                    reason: .quotaUnavailable
                )
            }
            return finish(
                input: input,
                plan: plan,
                route: includedRoute,
                state: .accepted,
                reason: nil
            )
        case .meteredPremium:
            guard meteredRoute.eligibleMembershipTiers.contains(input.membershipTier) else {
                return finish(
                    input: input,
                    plan: plan,
                    route: costBlockedRoute,
                    state: .rejected,
                    reason: .membershipTierNotEligible
                )
            }
            guard hasMeteredEligibility(input.quotaSnapshot) else {
                return finish(
                    input: input,
                    plan: plan,
                    route: costBlockedRoute,
                    state: .rejected,
                    reason: .quotaUnavailable
                )
            }
            return finish(
                input: input,
                plan: plan,
                route: meteredRoute,
                state: .accepted,
                reason: nil
            )
        case .freeLocal:
            return finish(
                input: input,
                plan: plan,
                route: localRoute,
                state: .accepted,
                reason: nil
            )
        case .blockedByCost, .blockedByPrivacy, .blockedByTerms:
            return finish(
                input: input,
                plan: plan,
                route: costBlockedRoute,
                state: .rejected,
                reason: .costClassBlocked
            )
        }
    }

    private nonisolated static func finish(
        input: ServerProviderSearchAPICostMembershipRoutingDecisionInput,
        plan: ServerProviderSearchAPICostMembershipRoutingPlan,
        route: ServerProviderSearchAPICostMembershipRoute,
        state: ServerProviderSearchAPICostMembershipRoutingDecisionState,
        reason: ServerProviderSearchAPICostMembershipRoutingDecisionRejectionReason?
    ) -> ServerProviderSearchAPICostMembershipRoutingDecision {
        if let preferredRouteKind = input.preferredRouteKind,
           preferredRouteKind != route.kind {
            return rejected(
                input: input,
                plan: plan,
                route: route,
                reason: .preferredRouteNotAllowed
            )
        }

        return decision(
            input: input,
            plan: plan,
            route: route,
            state: state,
            reason: reason,
            statusLine: statusLine(state: state, route: route, reason: reason)
        )
    }

    private nonisolated static func rejected(
        input: ServerProviderSearchAPICostMembershipRoutingDecisionInput,
        plan: ServerProviderSearchAPICostMembershipRoutingPlan,
        route: ServerProviderSearchAPICostMembershipRoute?,
        reason: ServerProviderSearchAPICostMembershipRoutingDecisionRejectionReason
    ) -> ServerProviderSearchAPICostMembershipRoutingDecision {
        decision(
            input: input,
            plan: plan,
            route: route,
            state: .rejected,
            reason: reason,
            statusLine: statusLine(state: .rejected, route: route, reason: reason)
        )
    }

    private nonisolated static func decision(
        input: ServerProviderSearchAPICostMembershipRoutingDecisionInput,
        plan: ServerProviderSearchAPICostMembershipRoutingPlan,
        route: ServerProviderSearchAPICostMembershipRoute?,
        state: ServerProviderSearchAPICostMembershipRoutingDecisionState,
        reason: ServerProviderSearchAPICostMembershipRoutingDecisionRejectionReason?,
        statusLine: String
    ) -> ServerProviderSearchAPICostMembershipRoutingDecision {
        let routeSuffix = route?.kind.rawValue ?? reason?.rawValue ?? "none"
        return ServerProviderSearchAPICostMembershipRoutingDecision(
            id: "a171-search-api-cost-routing-\(input.id)-\(routeSuffix)-\(state.rawValue)",
            inputID: input.id,
            planID: plan.id,
            state: state,
            selectedRouteID: route?.id,
            selectedRouteKind: route?.kind,
            selectedRouteRank: route?.rank,
            selectedRouteLabel: route?.uiLabel,
            membershipTier: input.membershipTier,
            requestedCostClass: input.requestedCostClass,
            region: input.region,
            privacyClass: input.privacyClass,
            statusLine: statusLine,
            rejectionReason: reason
        )
    }

    private nonisolated static func route(
        _ kind: ServerProviderSearchAPICostMembershipRouteKind,
        in plan: ServerProviderSearchAPICostMembershipRoutingPlan
    ) -> ServerProviderSearchAPICostMembershipRoute? {
        plan.routes.first { $0.kind == kind }
    }

    private nonisolated static func hasIncludedQuota(
        _ quotaSnapshot: ServerProviderQuotaSnapshot
    ) -> Bool {
        quotaSnapshot.allowedProviderFamilies.contains(.searchAPI)
            && quotaSnapshot.entitledProviderFamilies.contains(.searchAPI)
            && (quotaSnapshot.remainingIncludedQuota[.searchAPI] ?? 0) > 0
            && quotaSnapshot.disabledProviderFamilies.contains(.searchAPI) == false
    }

    private nonisolated static func allowsRemotePosture(
        _ privacyClass: ProviderPrivacyClass
    ) -> Bool {
        privacyClass == .general
    }

    private nonisolated static func hasMeteredEligibility(
        _ quotaSnapshot: ServerProviderQuotaSnapshot
    ) -> Bool {
        quotaSnapshot.allowedProviderFamilies.contains(.searchAPI)
            && quotaSnapshot.entitledProviderFamilies.contains(.searchAPI)
            && quotaSnapshot.meteredEligibleProviderFamilies.contains(.searchAPI)
            && quotaSnapshot.disabledProviderFamilies.contains(.searchAPI) == false
    }

    private nonisolated static func statusLine(
        state: ServerProviderSearchAPICostMembershipRoutingDecisionState,
        route: ServerProviderSearchAPICostMembershipRoute?,
        reason: ServerProviderSearchAPICostMembershipRoutingDecisionRejectionReason?
    ) -> String {
        if state == .accepted, let route {
            return "Search API cost routing selected advisory route \(route.kind.rawValue) from safe metadata only. No provider runtime has run."
        }
        if let route, let reason {
            return "Search API cost routing returned advisory route \(route.kind.rawValue) with review reason \(reason.rawValue). No provider runtime has run."
        }
        return "Search API cost routing is rejected by safe metadata review: \(reason?.rawValue ?? "unknown"). No provider runtime has run."
    }
}
