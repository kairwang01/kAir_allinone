//
//  ServerProviderSearchAPIVendorPolicy.swift
//  kAir
//
//  Value-only Search API vendor policy matrix. This file models vendor
//  eligibility metadata only; it never stores provider URLs, credentials,
//  client handles, query text, page bodies, or transport state.
//

import Foundation

enum ServerProviderSearchAPIVendorResultShape: String, Codable, Hashable, Sendable, CaseIterable {
    case organicLinks
    case answerSummary
    case localBusiness
    case documentSnippets
}

enum ServerProviderSearchAPIVendorPageBodyMode: String, Codable, Hashable, Sendable, CaseIterable {
    case unavailable
    case optional
    case required
}

enum ServerProviderSearchAPIPageBodyRequirement: String, Codable, Hashable, Sendable, CaseIterable {
    case snippetsOnly
    case optional
    case required
}

enum ServerProviderSearchAPIRetentionLevel:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable,
    Comparable
{
    case ephemeralOnly
    case shortTermCache
    case persistentCache

    private var rank: Int {
        switch self {
        case .ephemeralOnly:
            return 0
        case .shortTermCache:
            return 1
        case .persistentCache:
            return 2
        }
    }

    static func < (
        lhs: ServerProviderSearchAPIRetentionLevel,
        rhs: ServerProviderSearchAPIRetentionLevel
    ) -> Bool {
        lhs.rank < rhs.rank
    }
}

struct ServerProviderSearchAPIVendorCitationSupport: Codable, Hashable, Sendable {
    let supportsCitations: Bool
    let supportsSourceHost: Bool
    let supportsAttribution: Bool

    init(
        supportsCitations: Bool,
        supportsSourceHost: Bool,
        supportsAttribution: Bool
    ) {
        self.supportsCitations = supportsCitations
        self.supportsSourceHost = supportsSourceHost
        self.supportsAttribution = supportsAttribution
    }

    static let full = ServerProviderSearchAPIVendorCitationSupport(
        supportsCitations: true,
        supportsSourceHost: true,
        supportsAttribution: true
    )
}

struct ServerProviderSearchAPIVendorPolicyDescriptor:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let isEnabled: Bool
    let costClass: ProviderCostClass
    let supportedFreshness: Set<ProviderFreshness>
    let citationSupport: ServerProviderSearchAPIVendorCitationSupport
    let pageBodyMode: ServerProviderSearchAPIVendorPageBodyMode
    let requiredRetention: ServerProviderSearchAPIRetentionLevel
    let supportedResultShapes: Set<ServerProviderSearchAPIVendorResultShape>

    init(
        id: String,
        isEnabled: Bool = true,
        costClass: ProviderCostClass,
        supportedFreshness: Set<ProviderFreshness>,
        citationSupport: ServerProviderSearchAPIVendorCitationSupport,
        pageBodyMode: ServerProviderSearchAPIVendorPageBodyMode,
        requiredRetention: ServerProviderSearchAPIRetentionLevel,
        supportedResultShapes: Set<ServerProviderSearchAPIVendorResultShape>
    ) {
        self.id = Self.safeID(id)
        self.isEnabled = isEnabled
        self.costClass = costClass
        self.supportedFreshness = supportedFreshness
        self.citationSupport = citationSupport
        self.pageBodyMode = pageBodyMode
        self.requiredRetention = requiredRetention
        self.supportedResultShapes = supportedResultShapes
    }

    var description: String {
        "ServerProviderSearchAPIVendorPolicyDescriptor(id: \(id), costClass: \(costClass.rawValue))"
    }

    private static func safeID(_ value: String) -> String {
        let normalized = value
            .lowercased()
            .map { character in
                character.isLetter || character.isNumber ? String(character) : "-"
            }
            .joined()
        let slug = normalized
            .split(separator: "-")
            .joined(separator: "-")
        return slug.isEmpty ? "search-api-vendor" : slug
    }
}

struct ServerProviderSearchAPIVendorPolicyContext: Codable, Hashable, Sendable {
    let providerFamily: ProviderFamily
    let capability: ProviderCapability
    let privacyClass: ProviderPrivacyClass
    let costClass: ProviderCostClass
    let freshness: ProviderFreshness
    let citationRequired: Bool
    let sourceHostRequired: Bool
    let pageBodyRequirement: ServerProviderSearchAPIPageBodyRequirement
    let allowedRetention: ServerProviderSearchAPIRetentionLevel
    let resultShape: ServerProviderSearchAPIVendorResultShape
    let quotaSnapshot: ServerProviderQuotaSnapshot

    init(
        providerFamily: ProviderFamily = .searchAPI,
        capability: ProviderCapability = .webSearch,
        privacyClass: ProviderPrivacyClass = .general,
        costClass: ProviderCostClass = .meteredPremium,
        freshness: ProviderFreshness = .livePreferred,
        citationRequired: Bool = true,
        sourceHostRequired: Bool = true,
        pageBodyRequirement: ServerProviderSearchAPIPageBodyRequirement = .snippetsOnly,
        allowedRetention: ServerProviderSearchAPIRetentionLevel = .ephemeralOnly,
        resultShape: ServerProviderSearchAPIVendorResultShape = .organicLinks,
        quotaSnapshot: ServerProviderQuotaSnapshot
    ) {
        self.providerFamily = providerFamily
        self.capability = capability
        self.privacyClass = privacyClass
        self.costClass = costClass
        self.freshness = freshness
        self.citationRequired = citationRequired
        self.sourceHostRequired = sourceHostRequired
        self.pageBodyRequirement = pageBodyRequirement
        self.allowedRetention = allowedRetention
        self.resultShape = resultShape
        self.quotaSnapshot = quotaSnapshot
    }

    init(
        request: ServerProviderSearchAPIAdapterRequest,
        quotaSnapshot: ServerProviderQuotaSnapshot,
        pageBodyRequirement: ServerProviderSearchAPIPageBodyRequirement = .snippetsOnly,
        allowedRetention: ServerProviderSearchAPIRetentionLevel = .ephemeralOnly,
        resultShape: ServerProviderSearchAPIVendorResultShape = .organicLinks
    ) {
        self.init(
            providerFamily: request.providerFamily,
            capability: request.capability,
            privacyClass: request.privacyClass,
            costClass: request.costClass,
            freshness: request.freshness,
            citationRequired: request.sourcePolicy.citationRequired,
            sourceHostRequired: request.sourcePolicy.sourceHost?.isEmpty == false,
            pageBodyRequirement: pageBodyRequirement,
            allowedRetention: allowedRetention,
            resultShape: resultShape,
            quotaSnapshot: quotaSnapshot
        )
    }
}

enum ServerProviderSearchAPIVendorPolicyRejectionReason:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case vendorDisabled
    case providerFamilyMismatch
    case unsupportedCapability
    case privacyBlocked
    case providerDisabled
    case providerNotAllowed
    case entitlementMissing
    case includedQuotaExhausted
    case meteredEligibilityMissing
    case costClassMismatch
    case unsupportedCostClass
    case unsupportedFreshness
    case citationSupportMissing
    case sourceSupportMissing
    case attributionSupportMissing
    case pageBodyNotAllowed
    case pageBodyRequiredUnsupported
    case retentionConflict
    case unsupportedResultShape
}

enum ServerProviderSearchAPIVendorPolicyDecisionState: String, Codable, Hashable, Sendable, CaseIterable {
    case accepted
    case rejected
}

struct ServerProviderSearchAPIVendorPolicyDecision:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let state: ServerProviderSearchAPIVendorPolicyDecisionState
    let vendorID: String
    let providerFamily: ProviderFamily?
    let capability: ProviderCapability?
    let costClass: ProviderCostClass?
    let freshness: ProviderFreshness?
    let resultShape: ServerProviderSearchAPIVendorResultShape?
    let statusLine: String
    let rejection: ServerProviderSearchAPIVendorPolicyRejectionReason?

    var isAccepted: Bool {
        state == .accepted
    }

    var description: String {
        "ServerProviderSearchAPIVendorPolicyDecision(id: \(id), state: \(state.rawValue), rejection: \(rejection?.rawValue ?? "none"))"
    }
}

enum ServerProviderSearchAPIVendorPolicy {
    static func evaluate(
        context: ServerProviderSearchAPIVendorPolicyContext,
        vendor: ServerProviderSearchAPIVendorPolicyDescriptor
    ) -> ServerProviderSearchAPIVendorPolicyDecision {
        guard vendor.isEnabled else {
            return rejected(vendor: vendor, reason: .vendorDisabled)
        }
        guard context.providerFamily == .searchAPI else {
            return rejected(vendor: vendor, reason: .providerFamilyMismatch)
        }
        guard context.capability == .webSearch || context.capability == .localServiceSearch else {
            return rejected(vendor: vendor, reason: .unsupportedCapability)
        }
        guard context.privacyClass == .general else {
            return rejected(vendor: vendor, reason: .privacyBlocked)
        }
        guard vendor.costClass == context.costClass else {
            return rejected(vendor: vendor, reason: .costClassMismatch)
        }
        if let quotaRejection = quotaRejection(
            vendor: vendor,
            quotaSnapshot: context.quotaSnapshot
        ) {
            return rejected(vendor: vendor, reason: quotaRejection)
        }
        guard vendor.supportedFreshness.contains(context.freshness) else {
            return rejected(vendor: vendor, reason: .unsupportedFreshness)
        }
        if context.citationRequired,
           vendor.citationSupport.supportsCitations == false {
            return rejected(vendor: vendor, reason: .citationSupportMissing)
        }
        if context.sourceHostRequired,
           vendor.citationSupport.supportsSourceHost == false {
            return rejected(vendor: vendor, reason: .sourceSupportMissing)
        }
        if context.citationRequired,
           vendor.citationSupport.supportsAttribution == false {
            return rejected(vendor: vendor, reason: .attributionSupportMissing)
        }
        if context.pageBodyRequirement == .snippetsOnly,
           vendor.pageBodyMode == .required {
            return rejected(vendor: vendor, reason: .pageBodyNotAllowed)
        }
        if context.pageBodyRequirement == .required,
           vendor.pageBodyMode == .unavailable {
            return rejected(vendor: vendor, reason: .pageBodyRequiredUnsupported)
        }
        guard vendor.requiredRetention <= context.allowedRetention else {
            return rejected(vendor: vendor, reason: .retentionConflict)
        }
        guard vendor.supportedResultShapes.contains(context.resultShape) else {
            return rejected(vendor: vendor, reason: .unsupportedResultShape)
        }

        return ServerProviderSearchAPIVendorPolicyDecision(
            id: "search-api-vendor-policy-\(vendor.id)-accepted",
            state: .accepted,
            vendorID: vendor.id,
            providerFamily: .searchAPI,
            capability: context.capability,
            costClass: vendor.costClass,
            freshness: context.freshness,
            resultShape: context.resultShape,
            statusLine: "Search API vendor policy is accepted from approved metadata only. No provider runtime has run.",
            rejection: nil
        )
    }

    private static func quotaRejection(
        vendor: ServerProviderSearchAPIVendorPolicyDescriptor,
        quotaSnapshot: ServerProviderQuotaSnapshot
    ) -> ServerProviderSearchAPIVendorPolicyRejectionReason? {
        if quotaSnapshot.disabledProviderFamilies.contains(.searchAPI) {
            return .providerDisabled
        }
        guard quotaSnapshot.allowedProviderFamilies.contains(.searchAPI) else {
            return .providerNotAllowed
        }
        guard quotaSnapshot.entitledProviderFamilies.contains(.searchAPI) else {
            return .entitlementMissing
        }

        switch vendor.costClass {
        case .includedQuota:
            let remaining = quotaSnapshot.remainingIncludedQuota[.searchAPI] ?? 0
            return remaining > 0 ? nil : .includedQuotaExhausted
        case .meteredPremium:
            return quotaSnapshot.meteredEligibleProviderFamilies.contains(.searchAPI)
                ? nil
                : .meteredEligibilityMissing
        case .freeLocal, .blockedByCost, .blockedByPrivacy, .blockedByTerms:
            return .unsupportedCostClass
        }
    }

    private static func rejected(
        vendor: ServerProviderSearchAPIVendorPolicyDescriptor,
        reason: ServerProviderSearchAPIVendorPolicyRejectionReason
    ) -> ServerProviderSearchAPIVendorPolicyDecision {
        ServerProviderSearchAPIVendorPolicyDecision(
            id: "search-api-vendor-policy-\(vendor.id)-\(reason.rawValue)",
            state: .rejected,
            vendorID: vendor.id,
            providerFamily: nil,
            capability: nil,
            costClass: nil,
            freshness: nil,
            resultShape: nil,
            statusLine: "Search API vendor policy is blocked by metadata policy: \(reason.rawValue). No provider runtime has run.",
            rejection: reason
        )
    }
}
