//
//  ServerTransport.swift
//  kAir
//
//  Planned path for optional server-backed sync and friends transport.
//

import Foundation

/// Protocol-only seam for future kAir-owned backend traffic.
///
/// A11 deliberately keeps this file value-only: no endpoints, no provider
/// auth material, no SDK adapters, and no direct UI callers. The app can now
/// prove policy and audit shape before any concrete transport exists.
protocol ServerTransport: Sendable {
    func send(_ request: ServerProviderEnvelope) -> ServerProviderResponse
}

/// Source-policy state for a server/provider request. This is narrower than a
/// crawler implementation: it records whether a caller already proved source
/// and robots eligibility without fetching anything here.
enum ServerSourcePolicyState: String, Codable, Hashable, Sendable, CaseIterable {
    case notApplicable
    case passed
    case blocked
    case unknown
}

struct ServerSourcePolicy: Codable, Hashable, Sendable {
    let sourceState: ServerSourcePolicyState
    let robotsState: SearchRobotsState
    let attributionRequired: Bool
    let sourceHost: String?

    init(
        sourceState: ServerSourcePolicyState,
        robotsState: SearchRobotsState = .notApplicable,
        attributionRequired: Bool = false,
        sourceHost: String? = nil
    ) {
        self.sourceState = sourceState
        self.robotsState = robotsState
        self.attributionRequired = attributionRequired
        self.sourceHost = sourceHost
    }

    static let notApplicable = ServerSourcePolicy(sourceState: .notApplicable)
}

/// Confirmation state is explicit even when no confirmation is needed, so
/// higher-risk MCP or crawler paths cannot accidentally omit review metadata.
enum ServerConfirmationState: Codable, Hashable, Sendable {
    case notRequired
    case requiredMissing
    case confirmed(artifactID: String)

    var isSatisfied: Bool {
        switch self {
        case .notRequired, .confirmed:
            return true
        case .requiredMissing:
            return false
        }
    }
}

/// Client-visible value envelope for an optional server/provider hop.
///
/// The envelope records route metadata only. It must not carry prompt text,
/// Health data, raw page content, provider auth material, payment details, or
/// merchant-write instructions.
struct ServerProviderEnvelope: Codable, Hashable, Sendable {
    let traceID: String
    let capability: ProviderCapability
    let providerFamily: ProviderFamily
    let privacyClass: ProviderPrivacyClass
    let membershipTier: MembershipTier
    let costClass: ProviderCostClass
    let freshness: ProviderFreshness
    let sourcePolicy: ServerSourcePolicy
    let confirmationState: ServerConfirmationState
    let meteredProviderEntitlements: Set<ProviderFamily>
    let enabledExperimentalProviders: Set<ProviderFamily>

    init(
        traceID: String,
        capability: ProviderCapability,
        providerFamily: ProviderFamily,
        privacyClass: ProviderPrivacyClass = .general,
        membershipTier: MembershipTier = .free,
        costClass: ProviderCostClass,
        freshness: ProviderFreshness = .cachedOK,
        sourcePolicy: ServerSourcePolicy = .notApplicable,
        confirmationState: ServerConfirmationState = .notRequired,
        meteredProviderEntitlements: Set<ProviderFamily> = [],
        enabledExperimentalProviders: Set<ProviderFamily> = []
    ) {
        self.traceID = traceID
        self.capability = capability
        self.providerFamily = providerFamily
        self.privacyClass = privacyClass
        self.membershipTier = membershipTier
        self.costClass = costClass
        self.freshness = freshness
        self.sourcePolicy = sourcePolicy
        self.confirmationState = confirmationState
        self.meteredProviderEntitlements = meteredProviderEntitlements
        self.enabledExperimentalProviders = enabledExperimentalProviders
    }
}

enum ServerProviderDenialReason: String, Codable, Hashable, Sendable, CaseIterable {
    case missingTraceID
    case unsupportedCapability
    case blockedCostClass
    case privacyBlocked
    case membershipTierTooLow
    case missingEntitlement
    case experimentalProviderDisabled
    case crawlerRobotsBlocked
    case crawlerSourceBlocked
    case sourcePolicyBlocked
    case mcpDisabled
    case confirmationRequired
}

struct ServerProviderAuditRecord: Codable, Hashable, Sendable {
    let trace: ProviderTrace
    let providerFamily: ProviderFamily
    let sourcePolicy: ServerSourcePolicy
    let confirmationState: ServerConfirmationState
    let denialReason: ServerProviderDenialReason?
}

struct ServerProviderValidationDecision: Hashable, Sendable {
    let isAllowed: Bool
    let denialReason: ServerProviderDenialReason?
    let audit: ServerProviderAuditRecord
}

enum ServerProviderResponseStatus: String, Codable, Hashable, Sendable, CaseIterable {
    case acceptedFixture
    case blocked
}

struct ServerProviderResponse: Codable, Hashable, Sendable {
    let status: ServerProviderResponseStatus
    let audit: ServerProviderAuditRecord
    let fixtureMessage: String

    var isAccepted: Bool {
        status == .acceptedFixture
    }
}

enum ServerProviderEnvelopeValidator {
    static func validate(
        _ request: ServerProviderEnvelope
    ) -> ServerProviderValidationDecision {
        let denialReason = firstDenialReason(for: request)
        let isAllowed = denialReason == nil
        return ServerProviderValidationDecision(
            isAllowed: isAllowed,
            denialReason: denialReason,
            audit: audit(for: request, denialReason: denialReason)
        )
    }

    private static func firstDenialReason(
        for request: ServerProviderEnvelope
    ) -> ServerProviderDenialReason? {
        guard request.traceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return .missingTraceID
        }
        guard request.providerFamily.supports(serverCapability: request.capability) else {
            return .unsupportedCapability
        }
        guard request.costClass.isBlocked == false else {
            return .blockedCostClass
        }
        if request.providerFamily.isRemote,
           request.privacyClass.allowsRemoteProvider == false {
            return .privacyBlocked
        }
        guard request.membershipTier >= request.providerFamily.minimumServerMembership else {
            return .membershipTierTooLow
        }
        if request.providerFamily.requiresServerEntitlement,
           request.meteredProviderEntitlements.contains(request.providerFamily) == false {
            return .missingEntitlement
        }
        if request.providerFamily == .mcp,
           request.enabledExperimentalProviders.contains(.mcp) == false {
            return .mcpDisabled
        }
        if request.providerFamily == .crawler,
           request.enabledExperimentalProviders.contains(.crawler) == false {
            return .experimentalProviderDisabled
        }
        if request.sourcePolicy.sourceState == .blocked {
            return .sourcePolicyBlocked
        }
        if request.providerFamily == .crawler,
           request.sourcePolicy.robotsState != .allowed {
            return .crawlerRobotsBlocked
        }
        if request.providerFamily == .crawler,
           request.sourcePolicy.sourceState != .passed {
            return .crawlerSourceBlocked
        }
        guard request.confirmationState.isSatisfied else {
            return .confirmationRequired
        }
        return nil
    }

    private static func audit(
        for request: ServerProviderEnvelope,
        denialReason: ServerProviderDenialReason?
    ) -> ServerProviderAuditRecord {
        let providerFailure = denialReason.map(providerSkipReason(for:))
        let trace = ProviderTrace(
            traceID: request.traceID,
            capability: request.capability,
            selectedProviderID: denialReason == nil ? request.providerFamily.rawValue : nil,
            selectedProviderFamily: denialReason == nil ? request.providerFamily : nil,
            skippedProviders: denialReason == nil ? [] : [
                ProviderSkip(
                    providerID: request.providerFamily.rawValue,
                    family: request.providerFamily,
                    reason: providerFailure ?? .unavailable
                ),
            ],
            costClass: denialReason.map(costClass(for:)) ?? request.costClass,
            privacyClass: request.privacyClass,
            membershipTier: request.membershipTier,
            freshness: request.freshness,
            failureReason: providerFailure
        )
        return ServerProviderAuditRecord(
            trace: trace,
            providerFamily: request.providerFamily,
            sourcePolicy: request.sourcePolicy,
            confirmationState: request.confirmationState,
            denialReason: denialReason
        )
    }

    nonisolated private static func providerSkipReason(
        for reason: ServerProviderDenialReason
    ) -> ProviderSkipReason {
        switch reason {
        case .privacyBlocked:
            return .blockedByPrivacy
        case .membershipTierTooLow, .missingEntitlement:
            return .blockedByCost
        case .experimentalProviderDisabled, .mcpDisabled,
             .confirmationRequired:
            return .disabledByDefault
        case .unsupportedCapability:
            return .unsupportedCapability
        case .missingTraceID, .blockedCostClass, .crawlerRobotsBlocked,
             .crawlerSourceBlocked, .sourcePolicyBlocked:
            return .unavailable
        }
    }

    nonisolated private static func costClass(
        for reason: ServerProviderDenialReason
    ) -> ProviderCostClass {
        switch reason {
        case .privacyBlocked:
            return .blockedByPrivacy
        case .membershipTierTooLow, .missingEntitlement:
            return .blockedByCost
        case .missingTraceID, .unsupportedCapability, .blockedCostClass,
             .experimentalProviderDisabled, .crawlerRobotsBlocked,
             .crawlerSourceBlocked, .sourcePolicyBlocked, .mcpDisabled,
             .confirmationRequired:
            return .blockedByTerms
        }
    }
}

/// Fixture transport for tests and future previews. It validates the envelope
/// and returns an audit-only response; it does not perform I/O.
struct MockServerTransport: ServerTransport {
    let acceptedMessage: String

    init(acceptedMessage: String = "Accepted by fixture transport; no request was executed.") {
        self.acceptedMessage = acceptedMessage
    }

    func send(_ request: ServerProviderEnvelope) -> ServerProviderResponse {
        let decision = ServerProviderEnvelopeValidator.validate(request)
        guard decision.isAllowed else {
            return ServerProviderResponse(
                status: .blocked,
                audit: decision.audit,
                fixtureMessage: "Blocked by server provider envelope policy."
            )
        }
        return ServerProviderResponse(
            status: .acceptedFixture,
            audit: decision.audit,
            fixtureMessage: acceptedMessage
        )
    }
}

private extension ProviderFamily {
    var minimumServerMembership: MembershipTier {
        switch self {
        case .appleLocal, .cache:
            return .free
        case .gaode, .googleMaps, .searchAPI:
            return .plus
        case .crawler, .mcp:
            return .pro
        }
    }

    var requiresServerEntitlement: Bool {
        switch self {
        case .appleLocal, .cache:
            return false
        case .gaode, .googleMaps, .searchAPI, .crawler, .mcp:
            return true
        }
    }

    func supports(serverCapability capability: ProviderCapability) -> Bool {
        switch self {
        case .appleLocal:
            return [.mapDisplay, .placeSearch, .routePlanning].contains(capability)
        case .gaode, .googleMaps:
            return [.placeSearch, .routePlanning, .localServiceSearch].contains(capability)
        case .searchAPI:
            return [.webSearch, .localServiceSearch].contains(capability)
        case .crawler:
            return [.crawlerFetch, .localServiceSearch].contains(capability)
        case .mcp:
            return capability == .mcpTool
        case .cache:
            return ProviderCapability.allCases.contains(capability)
        }
    }
}

private extension ProviderCostClass {
    var isBlocked: Bool {
        switch self {
        case .blockedByCost, .blockedByPrivacy, .blockedByTerms:
            return true
        case .freeLocal, .includedQuota, .meteredPremium:
            return false
        }
    }
}
