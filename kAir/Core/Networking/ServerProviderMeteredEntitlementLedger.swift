//
//  ServerProviderMeteredEntitlementLedger.swift
//  kAir
//
//  Value-only server-provider budget ledger. This file models server-verified
//  entitlement and quota state before a future provider transport can be
//  considered. It stores no provider URLs, credentials, client handles, raw
//  queries, source bodies, or runtime objects.
//

import Foundation

enum ServerProviderMeteredUsageDecisionState:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case accepted
    case rejected
}

enum ServerProviderMeteredUsageDenialReason:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case missingSnapshot
    case vendorDisabled
    case membershipMissing
    case entitlementMissing
    case providerFamilyMismatch
    case vendorMismatch
    case capabilityMismatch
    case privacyBlocked
    case healthContextBlocked
    case overQuota
    case staleSnapshot
    case currencyMismatch
    case unitMismatch
    case alreadyReservedBudget
    case unsupportedCostClass
}

struct ServerProviderMeteredEntitlementSnapshot:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let providerFamily: ProviderFamily
    let vendorID: String
    let capability: ProviderCapability
    let costClass: ProviderCostClass
    let isVendorEnabled: Bool
    let membershipTier: MembershipTier
    let minimumMembershipTier: MembershipTier
    let hasEntitlement: Bool
    let quotaPeriodID: String
    let includedUnits: Int
    let usedUnits: Int
    let reservedUnits: Int
    let remainingUnits: Int
    let currencyCode: String
    let unitLabel: String
    let sourceTimestamp: Date
    let staleAfter: TimeInterval
    let reservedRequestIDs: Set<String>

    init(
        id: String,
        providerFamily: ProviderFamily,
        vendorID: String,
        capability: ProviderCapability,
        costClass: ProviderCostClass,
        isVendorEnabled: Bool = true,
        membershipTier: MembershipTier,
        minimumMembershipTier: MembershipTier = .free,
        hasEntitlement: Bool = true,
        quotaPeriodID: String,
        includedUnits: Int,
        usedUnits: Int,
        reservedUnits: Int,
        remainingUnits: Int,
        currencyCode: String,
        unitLabel: String,
        sourceTimestamp: Date,
        staleAfter: TimeInterval,
        reservedRequestIDs: Set<String> = []
    ) {
        self.id = Self.safeID(id, fallback: "metered-entitlement-snapshot")
        self.providerFamily = providerFamily
        self.vendorID = Self.safeID(vendorID, fallback: "provider-vendor")
        self.capability = capability
        self.costClass = costClass
        self.isVendorEnabled = isVendorEnabled
        self.membershipTier = membershipTier
        self.minimumMembershipTier = minimumMembershipTier
        self.hasEntitlement = hasEntitlement
        self.quotaPeriodID = Self.safeID(quotaPeriodID, fallback: "quota-period")
        self.includedUnits = max(0, includedUnits)
        self.usedUnits = max(0, usedUnits)
        self.reservedUnits = max(0, reservedUnits)
        self.remainingUnits = max(0, remainingUnits)
        self.currencyCode = Self.safeSymbol(currencyCode, fallback: "unit")
        self.unitLabel = Self.safeSymbol(unitLabel, fallback: "request-unit")
        self.sourceTimestamp = sourceTimestamp
        self.staleAfter = max(0, staleAfter)
        self.reservedRequestIDs = Set(
            reservedRequestIDs.map {
                Self.safeID($0, fallback: "reserved-request")
            }
        )
    }

    var description: String {
        [
            "ServerProviderMeteredEntitlementSnapshot(",
            "id: \(id), ",
            "providerFamily: \(providerFamily.rawValue), ",
            "vendorID: \(vendorID), ",
            "quotaPeriodID: \(quotaPeriodID)",
            ")",
        ]
            .joined()
    }

    func isStale(now: Date) -> Bool {
        now.timeIntervalSince(sourceTimestamp) > staleAfter
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

    private static func safeSymbol(
        _ value: String,
        fallback: String
    ) -> String {
        let normalized = value
            .uppercased()
            .map { character in
                character.isLetter || character.isNumber ? String(character) : "-"
            }
            .joined()
        let slug = normalized
            .split(separator: "-")
            .joined(separator: "-")
        return slug.isEmpty ? fallback.uppercased() : slug
    }
}

struct ServerProviderMeteredUsageRequest:
    Codable,
    Hashable,
    Identifiable,
    Sendable
{
    let id: String
    let traceID: String
    let providerFamily: ProviderFamily
    let vendorID: String
    let capability: ProviderCapability
    let estimatedUnits: Int
    let costClass: ProviderCostClass
    let privacyClass: ProviderPrivacyClass
    let freshness: ProviderFreshness
    let membershipTier: MembershipTier
    let currencyCode: String
    let unitLabel: String
    let userFacingReason: String

    init(
        id: String,
        traceID: String,
        providerFamily: ProviderFamily,
        vendorID: String,
        capability: ProviderCapability,
        estimatedUnits: Int,
        costClass: ProviderCostClass,
        privacyClass: ProviderPrivacyClass = .general,
        freshness: ProviderFreshness = .livePreferred,
        membershipTier: MembershipTier,
        currencyCode: String,
        unitLabel: String,
        userFacingReason: String
    ) {
        self.id = Self.safeID(id, fallback: "metered-usage-request")
        self.traceID = Self.safeID(traceID, fallback: "metered-trace")
        self.providerFamily = providerFamily
        self.vendorID = Self.safeID(vendorID, fallback: "provider-vendor")
        self.capability = capability
        self.estimatedUnits = max(0, estimatedUnits)
        self.costClass = costClass
        self.privacyClass = privacyClass
        self.freshness = freshness
        self.membershipTier = membershipTier
        self.currencyCode = Self.safeSymbol(currencyCode, fallback: "unit")
        self.unitLabel = Self.safeSymbol(unitLabel, fallback: "request-unit")
        self.userFacingReason = String(userFacingReason.prefix(80))
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

    private static func safeSymbol(
        _ value: String,
        fallback: String
    ) -> String {
        let normalized = value
            .uppercased()
            .map { character in
                character.isLetter || character.isNumber ? String(character) : "-"
            }
            .joined()
        let slug = normalized
            .split(separator: "-")
            .joined(separator: "-")
        return slug.isEmpty ? fallback.uppercased() : slug
    }
}

struct ServerProviderMeteredUsageAudit:
    Codable,
    Hashable,
    Sendable
{
    let traceID: String
    let requestID: String
    let snapshotID: String?
    let quotaPeriodID: String?
    let providerFamily: ProviderFamily
    let vendorID: String
    let capability: ProviderCapability
    let costClass: ProviderCostClass
    let privacyClass: ProviderPrivacyClass
    let freshness: ProviderFreshness
    let membershipTier: MembershipTier
    let estimatedUnits: Int
    let remainingUnitsBefore: Int?
    let remainingUnitsAfter: Int?
    let reservedUnitsAfter: Int?
    let currencyCode: String?
    let unitLabel: String?
    let denialReason: ServerProviderMeteredUsageDenialReason?
}

struct ServerProviderMeteredUsageDecision:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let state: ServerProviderMeteredUsageDecisionState
    let statusLine: String
    let requestID: String
    let snapshotID: String?
    let quotaPeriodID: String?
    let providerFamily: ProviderFamily?
    let vendorID: String?
    let capability: ProviderCapability?
    let costClass: ProviderCostClass?
    let freshness: ProviderFreshness?
    let estimatedUnits: Int
    let remainingUnitsBefore: Int?
    let remainingUnitsAfter: Int?
    let reservedUnitsAfter: Int?
    let currencyCode: String?
    let unitLabel: String?
    let denialReason: ServerProviderMeteredUsageDenialReason?
    let audit: ServerProviderMeteredUsageAudit

    var isAccepted: Bool {
        state == .accepted
    }

    var description: String {
        "ServerProviderMeteredUsageDecision(id: \(id), state: \(state.rawValue), denial: \(denialReason?.rawValue ?? "none"))"
    }

    func quotaSnapshotForProvider() -> ServerProviderQuotaSnapshot? {
        guard isAccepted,
              let providerFamily,
              let costClass,
              let remainingUnitsAfter else {
            return nil
        }

        let includedQuota: [ProviderFamily: Int] = costClass == .includedQuota
            ? [providerFamily: remainingUnitsAfter]
            : [:]
        let meteredEligible: Set<ProviderFamily> = costClass == .meteredPremium
            ? [providerFamily]
            : []

        return ServerProviderQuotaSnapshot(
            allowedProviderFamilies: [providerFamily],
            entitledProviderFamilies: [providerFamily],
            remainingIncludedQuota: includedQuota,
            meteredEligibleProviderFamilies: meteredEligible
        )
    }

    func transportBudgetContext(
        id: String? = nil
    ) -> ServerProviderSearchAPITransportBudgetContext? {
        guard let quotaSnapshot = quotaSnapshotForProvider(),
              let costClass else {
            return nil
        }

        return ServerProviderSearchAPITransportBudgetContext(
            id: id ?? "\(self.id)-budget-context",
            quotaSnapshot: quotaSnapshot,
            allowedCostClasses: [costClass],
            meteredDecisionID: self.id,
            providerFamily: providerFamily,
            vendorID: vendorID,
            capability: capability,
            costClass: costClass,
            freshness: freshness
        )
    }
}

enum ServerProviderMeteredEntitlementLedger {
    static func evaluate(
        request: ServerProviderMeteredUsageRequest,
        snapshot: ServerProviderMeteredEntitlementSnapshot?,
        now: Date
    ) -> ServerProviderMeteredUsageDecision {
        guard let snapshot else {
            return rejected(
                request: request,
                snapshot: nil,
                reason: .missingSnapshot
            )
        }
        guard snapshot.isVendorEnabled else {
            return rejected(
                request: request,
                snapshot: snapshot,
                reason: .vendorDisabled
            )
        }
        guard snapshot.providerFamily == request.providerFamily else {
            return rejected(
                request: request,
                snapshot: snapshot,
                reason: .providerFamilyMismatch
            )
        }
        guard snapshot.vendorID == request.vendorID else {
            return rejected(
                request: request,
                snapshot: snapshot,
                reason: .vendorMismatch
            )
        }
        guard snapshot.capability == request.capability else {
            return rejected(
                request: request,
                snapshot: snapshot,
                reason: .capabilityMismatch
            )
        }
        if request.privacyClass == .health {
            return rejected(
                request: request,
                snapshot: snapshot,
                reason: .healthContextBlocked
            )
        }
        guard request.privacyClass.allowsRemoteProvider else {
            return rejected(
                request: request,
                snapshot: snapshot,
                reason: .privacyBlocked
            )
        }
        guard snapshot.membershipTier >= snapshot.minimumMembershipTier,
              request.membershipTier >= snapshot.minimumMembershipTier else {
            return rejected(
                request: request,
                snapshot: snapshot,
                reason: .membershipMissing
            )
        }
        guard snapshot.hasEntitlement else {
            return rejected(
                request: request,
                snapshot: snapshot,
                reason: .entitlementMissing
            )
        }
        guard snapshot.costClass == request.costClass,
              request.costClass == .includedQuota || request.costClass == .meteredPremium else {
            return rejected(
                request: request,
                snapshot: snapshot,
                reason: .unsupportedCostClass
            )
        }
        guard snapshot.currencyCode == request.currencyCode else {
            return rejected(
                request: request,
                snapshot: snapshot,
                reason: .currencyMismatch
            )
        }
        guard snapshot.unitLabel == request.unitLabel else {
            return rejected(
                request: request,
                snapshot: snapshot,
                reason: .unitMismatch
            )
        }
        guard snapshot.isStale(now: now) == false else {
            return rejected(
                request: request,
                snapshot: snapshot,
                reason: .staleSnapshot
            )
        }
        guard snapshot.reservedRequestIDs.contains(request.id) == false else {
            return rejected(
                request: request,
                snapshot: snapshot,
                reason: .alreadyReservedBudget
            )
        }
        guard request.estimatedUnits > 0,
              request.estimatedUnits <= snapshot.remainingUnits else {
            return rejected(
                request: request,
                snapshot: snapshot,
                reason: .overQuota
            )
        }

        let remainingAfter = snapshot.remainingUnits - request.estimatedUnits
        let reservedAfter = snapshot.reservedUnits + request.estimatedUnits
        let audit = audit(
            request: request,
            snapshot: snapshot,
            remainingAfter: remainingAfter,
            reservedAfter: reservedAfter,
            reason: nil
        )

        return ServerProviderMeteredUsageDecision(
            id: "metered-usage-\(request.id)-accepted",
            state: .accepted,
            statusLine: "Server provider metered entitlement is accepted from budget metadata only. No transport or provider runtime has run.",
            requestID: request.id,
            snapshotID: snapshot.id,
            quotaPeriodID: snapshot.quotaPeriodID,
            providerFamily: request.providerFamily,
            vendorID: request.vendorID,
            capability: request.capability,
            costClass: request.costClass,
            freshness: request.freshness,
            estimatedUnits: request.estimatedUnits,
            remainingUnitsBefore: snapshot.remainingUnits,
            remainingUnitsAfter: remainingAfter,
            reservedUnitsAfter: reservedAfter,
            currencyCode: request.currencyCode,
            unitLabel: request.unitLabel,
            denialReason: nil,
            audit: audit
        )
    }

    private static func rejected(
        request: ServerProviderMeteredUsageRequest,
        snapshot: ServerProviderMeteredEntitlementSnapshot?,
        reason: ServerProviderMeteredUsageDenialReason
    ) -> ServerProviderMeteredUsageDecision {
        let audit = audit(
            request: request,
            snapshot: snapshot,
            remainingAfter: nil,
            reservedAfter: nil,
            reason: reason
        )

        return ServerProviderMeteredUsageDecision(
            id: "metered-usage-\(request.id)-\(reason.rawValue)",
            state: .rejected,
            statusLine: "Server provider metered entitlement is blocked by budget metadata: \(reason.rawValue). No transport or provider runtime has run.",
            requestID: request.id,
            snapshotID: snapshot?.id,
            quotaPeriodID: snapshot?.quotaPeriodID,
            providerFamily: nil,
            vendorID: snapshot?.vendorID,
            capability: nil,
            costClass: nil,
            freshness: nil,
            estimatedUnits: request.estimatedUnits,
            remainingUnitsBefore: snapshot?.remainingUnits,
            remainingUnitsAfter: nil,
            reservedUnitsAfter: nil,
            currencyCode: snapshot?.currencyCode,
            unitLabel: snapshot?.unitLabel,
            denialReason: reason,
            audit: audit
        )
    }

    private static func audit(
        request: ServerProviderMeteredUsageRequest,
        snapshot: ServerProviderMeteredEntitlementSnapshot?,
        remainingAfter: Int?,
        reservedAfter: Int?,
        reason: ServerProviderMeteredUsageDenialReason?
    ) -> ServerProviderMeteredUsageAudit {
        ServerProviderMeteredUsageAudit(
            traceID: request.traceID,
            requestID: request.id,
            snapshotID: snapshot?.id,
            quotaPeriodID: snapshot?.quotaPeriodID,
            providerFamily: request.providerFamily,
            vendorID: request.vendorID,
            capability: request.capability,
            costClass: request.costClass,
            privacyClass: request.privacyClass,
            freshness: request.freshness,
            membershipTier: request.membershipTier,
            estimatedUnits: request.estimatedUnits,
            remainingUnitsBefore: snapshot?.remainingUnits,
            remainingUnitsAfter: remainingAfter,
            reservedUnitsAfter: reservedAfter,
            currencyCode: snapshot?.currencyCode,
            unitLabel: snapshot?.unitLabel,
            denialReason: reason
        )
    }
}
