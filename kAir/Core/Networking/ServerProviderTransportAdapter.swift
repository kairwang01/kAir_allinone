//
//  ServerProviderTransportAdapter.swift
//  kAir
//
//  Value-only preflight seam for future external provider transport adapters.
//

import Foundation

protocol ServerProviderTransportAdapter: Sendable {
    var descriptor: ServerProviderTransportAdapterDescriptor { get }

    func preflight(
        _ request: ServerProviderTransportAdapterPreflightRequest
    ) -> ServerProviderTransportAdapterPreflightDecision
}

struct ServerProviderTransportAdapterDescriptor:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let providerFamily: ProviderFamily
    let supportedCapabilities: Set<ProviderCapability>
    let minimumMembershipTier: MembershipTier
    let costClass: ProviderCostClass
    let requiresEntitlement: Bool
    let requiresMeteredEligibility: Bool
    let requiresIncludedQuota: Bool
    let requiresSourcePolicyPass: Bool
    let requiresAttribution: Bool
    let requiresExperimentalEnablement: Bool
    let requiresConfirmation: Bool
    let requiresMeteredDecision: Bool
    let requiresIssuedLease: Bool
    let allowedPrivacyClasses: Set<ProviderPrivacyClass>

    var description: String {
        [
            "ServerProviderTransportAdapterDescriptor(",
            "id: \(id), ",
            "providerFamily: \(providerFamily.rawValue), ",
            "costClass: \(costClass.rawValue)",
            ")",
        ].joined()
    }

    func supports(_ capability: ProviderCapability) -> Bool {
        supportedCapabilities.contains(capability)
    }

    static let searchAPI = ServerProviderTransportAdapterDescriptor(
        id: "transport-adapter-search-api",
        providerFamily: .searchAPI,
        supportedCapabilities: [.webSearch, .localServiceSearch],
        minimumMembershipTier: .plus,
        costClass: .meteredPremium,
        requiresEntitlement: true,
        requiresMeteredEligibility: true,
        requiresIncludedQuota: false,
        requiresSourcePolicyPass: true,
        requiresAttribution: true,
        requiresExperimentalEnablement: false,
        requiresConfirmation: false,
        requiresMeteredDecision: true,
        requiresIssuedLease: true,
        allowedPrivacyClasses: [.general]
    )

    static let gaode = ServerProviderTransportAdapterDescriptor(
        id: "transport-adapter-gaode",
        providerFamily: .gaode,
        supportedCapabilities: [.placeSearch, .routePlanning, .localServiceSearch],
        minimumMembershipTier: .plus,
        costClass: .includedQuota,
        requiresEntitlement: true,
        requiresMeteredEligibility: false,
        requiresIncludedQuota: true,
        requiresSourcePolicyPass: false,
        requiresAttribution: true,
        requiresExperimentalEnablement: false,
        requiresConfirmation: false,
        requiresMeteredDecision: false,
        requiresIssuedLease: false,
        allowedPrivacyClasses: [.general]
    )

    static let googleMaps = ServerProviderTransportAdapterDescriptor(
        id: "transport-adapter-google-maps",
        providerFamily: .googleMaps,
        supportedCapabilities: [.placeSearch, .routePlanning, .localServiceSearch],
        minimumMembershipTier: .plus,
        costClass: .meteredPremium,
        requiresEntitlement: true,
        requiresMeteredEligibility: true,
        requiresIncludedQuota: false,
        requiresSourcePolicyPass: false,
        requiresAttribution: true,
        requiresExperimentalEnablement: false,
        requiresConfirmation: false,
        requiresMeteredDecision: false,
        requiresIssuedLease: false,
        allowedPrivacyClasses: [.general]
    )

    static let crawler = ServerProviderTransportAdapterDescriptor(
        id: "transport-adapter-crawler",
        providerFamily: .crawler,
        supportedCapabilities: [.crawlerFetch, .localServiceSearch],
        minimumMembershipTier: .pro,
        costClass: .meteredPremium,
        requiresEntitlement: true,
        requiresMeteredEligibility: true,
        requiresIncludedQuota: false,
        requiresSourcePolicyPass: true,
        requiresAttribution: true,
        requiresExperimentalEnablement: true,
        requiresConfirmation: false,
        requiresMeteredDecision: false,
        requiresIssuedLease: false,
        allowedPrivacyClasses: [.general]
    )

    static let mcp = ServerProviderTransportAdapterDescriptor(
        id: "transport-adapter-mcp",
        providerFamily: .mcp,
        supportedCapabilities: [.mcpTool],
        minimumMembershipTier: .pro,
        costClass: .includedQuota,
        requiresEntitlement: true,
        requiresMeteredEligibility: false,
        requiresIncludedQuota: true,
        requiresSourcePolicyPass: false,
        requiresAttribution: false,
        requiresExperimentalEnablement: true,
        requiresConfirmation: true,
        requiresMeteredDecision: false,
        requiresIssuedLease: false,
        allowedPrivacyClasses: [.general]
    )

    static let defaultRegistry: [ServerProviderTransportAdapterDescriptor] = [
        .searchAPI,
        .gaode,
        .googleMaps,
        .crawler,
        .mcp,
    ]
}

struct ServerProviderTransportAdapterPreflightRequest: Hashable, Sendable {
    let id: String
    let envelope: ServerProviderEnvelope
    let quotaSnapshot: ServerProviderQuotaSnapshot
    let providerAccessProfile: ProviderAccessProfile
    let meteredDecision: ServerProviderMeteredUsageDecision?
    let transportLease: ServerProviderSearchAPITransportLease?
    let expectedVendorID: String?
    let budgetEvidenceExpiresAt: Date?
    let now: Date

    init(
        id: String,
        envelope: ServerProviderEnvelope,
        quotaSnapshot: ServerProviderQuotaSnapshot,
        providerAccessProfile: ProviderAccessProfile,
        meteredDecision: ServerProviderMeteredUsageDecision? = nil,
        transportLease: ServerProviderSearchAPITransportLease? = nil,
        expectedVendorID: String? = nil,
        budgetEvidenceExpiresAt: Date? = nil,
        now: Date = Date()
    ) {
        self.id = id
        self.envelope = envelope
        self.quotaSnapshot = quotaSnapshot
        self.providerAccessProfile = providerAccessProfile
        self.meteredDecision = meteredDecision
        self.transportLease = transportLease
        self.expectedVendorID = expectedVendorID
        self.budgetEvidenceExpiresAt = budgetEvidenceExpiresAt
        self.now = now
    }
}

enum ServerProviderTransportAdapterPreflightState:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case accepted
    case rejected
}

enum ServerProviderTransportAdapterPreflightRejectionReason:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case providerFamilyMismatch
    case unsupportedCapability
    case blockedCostClass
    case costClassMismatch
    case privacyBlocked
    case membershipTierTooLow
    case providerNotAllowed
    case providerDisabled
    case experimentalProviderDisabled
    case missingEntitlement
    case includedQuotaExhausted
    case meteredEligibilityMissing
    case sourcePolicyMissing
    case sourcePolicyBlocked
    case attributionMissing
    case crawlerRobotsBlocked
    case confirmationMissing
    case missingMeteredDecision
    case meteredDecisionRejected
    case meteredDecisionMismatch
    case missingTransportLease
    case transportLeaseNotIssued
    case transportLeaseMismatch
    case missingBudgetEvidence
    case staleBudgetEvidence
}

struct ServerProviderTransportAdapterPreflightDecision:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let state: ServerProviderTransportAdapterPreflightState
    let statusLine: String
    let adapterID: String
    let requestID: String
    let providerFamily: ProviderFamily
    let capability: ProviderCapability
    let costClass: ProviderCostClass
    let membershipTier: MembershipTier
    let meteredDecisionID: String?
    let transportLeaseID: String?
    let rejectionReason: ServerProviderTransportAdapterPreflightRejectionReason?

    var isAccepted: Bool {
        state == .accepted
    }

    var description: String {
        [
            "ServerProviderTransportAdapterPreflightDecision(",
            "id: \(id), ",
            "state: \(state.rawValue), ",
            "providerFamily: \(providerFamily.rawValue), ",
            "rejection: \(rejectionReason?.rawValue ?? "none")",
            ")",
        ].joined()
    }

    static func accepted(
        descriptor: ServerProviderTransportAdapterDescriptor,
        request: ServerProviderTransportAdapterPreflightRequest
    ) -> ServerProviderTransportAdapterPreflightDecision {
        ServerProviderTransportAdapterPreflightDecision(
            id: "\(request.id)-accepted",
            state: .accepted,
            statusLine: "External provider transport preflight accepted for \(descriptor.providerFamily.rawValue) using value-only metadata. No provider transport has run.",
            adapterID: descriptor.id,
            requestID: request.id,
            providerFamily: descriptor.providerFamily,
            capability: request.envelope.capability,
            costClass: request.envelope.costClass,
            membershipTier: request.envelope.membershipTier,
            meteredDecisionID: request.meteredDecision?.id,
            transportLeaseID: request.transportLease?.id,
            rejectionReason: nil
        )
    }

    static func rejected(
        _ reason: ServerProviderTransportAdapterPreflightRejectionReason,
        descriptor: ServerProviderTransportAdapterDescriptor,
        request: ServerProviderTransportAdapterPreflightRequest
    ) -> ServerProviderTransportAdapterPreflightDecision {
        ServerProviderTransportAdapterPreflightDecision(
            id: "\(request.id)-rejected-\(reason.rawValue)",
            state: .rejected,
            statusLine: "External provider transport preflight blocked for \(descriptor.providerFamily.rawValue): \(reason.rawValue). No provider transport has run.",
            adapterID: descriptor.id,
            requestID: request.id,
            providerFamily: descriptor.providerFamily,
            capability: request.envelope.capability,
            costClass: request.envelope.costClass,
            membershipTier: request.envelope.membershipTier,
            meteredDecisionID: request.meteredDecision?.id,
            transportLeaseID: request.transportLease?.id,
            rejectionReason: reason
        )
    }
}

struct ValueOnlyServerProviderTransportAdapter: ServerProviderTransportAdapter {
    let descriptor: ServerProviderTransportAdapterDescriptor

    func preflight(
        _ request: ServerProviderTransportAdapterPreflightRequest
    ) -> ServerProviderTransportAdapterPreflightDecision {
        ServerProviderTransportAdapterPreflight.evaluate(
            descriptor: descriptor,
            request: request
        )
    }
}

enum ServerProviderTransportAdapterPreflight {
    static func evaluate(
        descriptor: ServerProviderTransportAdapterDescriptor,
        request: ServerProviderTransportAdapterPreflightRequest
    ) -> ServerProviderTransportAdapterPreflightDecision {
        if descriptor.providerFamily != request.envelope.providerFamily {
            return rejected(.providerFamilyMismatch, descriptor: descriptor, request: request)
        }
        guard descriptor.supports(request.envelope.capability) else {
            return rejected(.unsupportedCapability, descriptor: descriptor, request: request)
        }
        guard isBlockedCost(request.envelope.costClass) == false else {
            return rejected(.blockedCostClass, descriptor: descriptor, request: request)
        }
        guard descriptor.costClass == request.envelope.costClass else {
            return rejected(.costClassMismatch, descriptor: descriptor, request: request)
        }
        guard descriptor.allowedPrivacyClasses.contains(request.envelope.privacyClass) else {
            return rejected(.privacyBlocked, descriptor: descriptor, request: request)
        }
        guard request.envelope.membershipTier >= descriptor.minimumMembershipTier,
              request.providerAccessProfile.membershipTier >= descriptor.minimumMembershipTier else {
            return rejected(.membershipTierTooLow, descriptor: descriptor, request: request)
        }
        guard request.quotaSnapshot.allowedProviderFamilies.contains(descriptor.providerFamily) else {
            return rejected(.providerNotAllowed, descriptor: descriptor, request: request)
        }
        guard request.quotaSnapshot.disabledProviderFamilies.contains(descriptor.providerFamily) == false else {
            return rejected(.providerDisabled, descriptor: descriptor, request: request)
        }
        if descriptor.requiresExperimentalEnablement,
           experimentalProviderEnabled(
               descriptor.providerFamily,
               request: request
           ) == false {
            return rejected(.experimentalProviderDisabled, descriptor: descriptor, request: request)
        }
        if descriptor.requiresEntitlement,
           hasEntitlement(for: descriptor.providerFamily, request: request) == false {
            return rejected(.missingEntitlement, descriptor: descriptor, request: request)
        }
        if descriptor.requiresIncludedQuota,
           (request.quotaSnapshot.remainingIncludedQuota[descriptor.providerFamily] ?? 0) <= 0 {
            return rejected(.includedQuotaExhausted, descriptor: descriptor, request: request)
        }
        if descriptor.requiresMeteredEligibility,
           request.quotaSnapshot.meteredEligibleProviderFamilies.contains(descriptor.providerFamily) == false {
            return rejected(.meteredEligibilityMissing, descriptor: descriptor, request: request)
        }
        if request.envelope.sourcePolicy.sourceState == .blocked {
            return rejected(.sourcePolicyBlocked, descriptor: descriptor, request: request)
        }
        if descriptor.requiresSourcePolicyPass,
           request.envelope.sourcePolicy.sourceState != .passed {
            return rejected(.sourcePolicyMissing, descriptor: descriptor, request: request)
        }
        if descriptor.providerFamily == .crawler,
           request.envelope.sourcePolicy.robotsState != .allowed {
            return rejected(.crawlerRobotsBlocked, descriptor: descriptor, request: request)
        }
        if descriptor.requiresAttribution,
           request.envelope.sourcePolicy.attributionRequired == false {
            return rejected(.attributionMissing, descriptor: descriptor, request: request)
        }
        if descriptor.requiresConfirmation,
           request.envelope.confirmationState.isSatisfied == false {
            return rejected(.confirmationMissing, descriptor: descriptor, request: request)
        }
        if descriptor.requiresMeteredDecision,
           let rejection = meteredDecisionRejection(descriptor: descriptor, request: request) {
            return rejected(rejection, descriptor: descriptor, request: request)
        }
        if descriptor.requiresIssuedLease,
           let rejection = transportLeaseRejection(descriptor: descriptor, request: request) {
            return rejected(rejection, descriptor: descriptor, request: request)
        }
        return .accepted(descriptor: descriptor, request: request)
    }

    private static func rejected(
        _ reason: ServerProviderTransportAdapterPreflightRejectionReason,
        descriptor: ServerProviderTransportAdapterDescriptor,
        request: ServerProviderTransportAdapterPreflightRequest
    ) -> ServerProviderTransportAdapterPreflightDecision {
        .rejected(reason, descriptor: descriptor, request: request)
    }

    private static func isBlockedCost(
        _ costClass: ProviderCostClass
    ) -> Bool {
        switch costClass {
        case .blockedByCost, .blockedByPrivacy, .blockedByTerms:
            return true
        case .freeLocal, .includedQuota, .meteredPremium:
            return false
        }
    }

    private static func experimentalProviderEnabled(
        _ family: ProviderFamily,
        request: ServerProviderTransportAdapterPreflightRequest
    ) -> Bool {
        request.providerAccessProfile.enabledExperimentalProviders.contains(family)
            && request.quotaSnapshot.enabledExperimentalProviderFamilies.contains(family)
            && request.envelope.enabledExperimentalProviders.contains(family)
    }

    private static func hasEntitlement(
        for family: ProviderFamily,
        request: ServerProviderTransportAdapterPreflightRequest
    ) -> Bool {
        request.quotaSnapshot.entitledProviderFamilies.contains(family)
            || request.envelope.meteredProviderEntitlements.contains(family)
    }

    private static func meteredDecisionRejection(
        descriptor: ServerProviderTransportAdapterDescriptor,
        request: ServerProviderTransportAdapterPreflightRequest
    ) -> ServerProviderTransportAdapterPreflightRejectionReason? {
        guard let decision = request.meteredDecision else {
            return .missingMeteredDecision
        }
        guard decision.isAccepted else {
            return .meteredDecisionRejected
        }
        guard decision.providerFamily == descriptor.providerFamily,
              decision.capability == request.envelope.capability,
              decision.costClass == request.envelope.costClass,
              decision.freshness == request.envelope.freshness else {
            return .meteredDecisionMismatch
        }
        if let expectedVendorID = request.expectedVendorID,
           decision.vendorID != expectedVendorID {
            return .meteredDecisionMismatch
        }
        return nil
    }

    private static func transportLeaseRejection(
        descriptor: ServerProviderTransportAdapterDescriptor,
        request: ServerProviderTransportAdapterPreflightRequest
    ) -> ServerProviderTransportAdapterPreflightRejectionReason? {
        guard let lease = request.transportLease else {
            return .missingTransportLease
        }
        guard lease.isIssued else {
            return .transportLeaseNotIssued
        }
        guard let expiresAt = request.budgetEvidenceExpiresAt else {
            return .missingBudgetEvidence
        }
        guard request.now <= expiresAt else {
            return .staleBudgetEvidence
        }
        guard lease.providerFamily == descriptor.providerFamily,
              lease.capability == request.envelope.capability,
              lease.costClass == request.envelope.costClass,
              lease.freshness == request.envelope.freshness else {
            return .transportLeaseMismatch
        }
        if let expectedVendorID = request.expectedVendorID,
           lease.vendorID != expectedVendorID {
            return .transportLeaseMismatch
        }
        return nil
    }
}
