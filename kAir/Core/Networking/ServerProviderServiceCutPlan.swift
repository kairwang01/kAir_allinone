//
//  ServerProviderServiceCutPlan.swift
//  kAir
//
//  A182 value-only service-lane contract. This file classifies future provider
//  lanes before any adapter or transport can exist.
//

import Foundation

/// Product-level lane selected before lower-level provider routing.
///
/// Lanes are deliberately broader than concrete provider descriptors. They
/// define whether a service remains local, is only reserved for a future
/// server-mediated path, or stays disabled behind crawler/MCP gates.
enum ServerProviderServiceLane: String, Codable, Hashable, Sendable, CaseIterable {
    case localAppleMaps
    case cacheFallback
    case serverGoogleMaps
    case serverGaode
    case serverSearchAPI
    case reservedCrawler
    case reservedMCP
}

/// User/product intent used by the cut plan before provider-family details.
enum ServerProviderServiceIntent: String, Codable, Hashable, Sendable, CaseIterable {
    case mapDisplay
    case mapRoute
    case mapSearch
    case publicInfoSearch
    case publicSourceCrawlCandidate
    case mcpToolCandidate
    case mcpResourceCandidate
    case mcpPromptCandidate
    case lifeServiceReadOnlyLookup
}

enum ServerProviderServiceCutPlanState: String, Codable, Hashable, Sendable, CaseIterable {
    case localReady
    case serverReserved
    case blocked
    case unsupported
}

/// Gate labels a future implementation must satisfy before a reserved lane can
/// move closer to runtime.
enum ServerProviderServiceGate: String, Codable, Hashable, Sendable, CaseIterable {
    case membershipPackage
    case regionPolicy
    case costUnitPolicy
    case quotaOrQPSPolicy
    case attributionCacheDisplayPolicy
    case sourceCitationPolicy
    case rawContentPolicy
    case retentionPolicy
    case serverSecretOwnership
    case robotsPolicy
    case rateLimitPolicy
    case sandboxAudit
    case experimentalEnablement
    case mcpDescriptorVerification
    case mcpDiscoveryFiltering
    case mcpInvocationAuthorization
    case mcpConsentConfirmation
    case mcpTokenProtection
    case privateDataLocalOnly
}

enum ServerProviderServiceCutPlanBlockReason: String, Codable, Hashable, Sendable, CaseIterable {
    case unsupportedLane
    case unsupportedCapability
    case membershipMissing
    case regionMissing
    case privacyBlocked
    case privateDataBlocked
    case costPolicyMissing
    case quotaPolicyMissing
    case sourceCitationMissing
    case rawContentPolicyMissing
    case attributionCacheDisplayMissing
    case descriptorUnverified
    case confirmationMissing
    case serverSecretMissing
    case clientOwnedSecret
    case robotsPolicyMissingOrBlocked
    case rateRetentionMissing
    case sandboxAuditMissing
    case experimentalProviderDisabled
    case mcpAuthorizationMissing
    case tokenProtectionMissing
}

enum ServerProviderServiceQuotaPosture: String, Codable, Hashable, Sendable, CaseIterable {
    case notRequired
    case includedQuotaAvailable
    case meteredEligible
    case missing
    case exhausted

    var isRepresentedForReservedLane: Bool {
        switch self {
        case .includedQuotaAvailable, .meteredEligible:
            return true
        case .notRequired, .missing, .exhausted:
            return false
        }
    }
}

enum ServerProviderServiceSourceCitationRequirement: String, Codable, Hashable, Sendable, CaseIterable {
    case notApplicable
    case requiredAndRepresented
    case missing
}

enum ServerProviderServiceRawContentPolicy: String, Codable, Hashable, Sendable, CaseIterable {
    case notApplicable
    case redactedOrDisabled
    case missing
    case unsafeAllowed
}

enum ServerProviderServiceAttributionCacheDisplayPolicy: String, Codable, Hashable, Sendable, CaseIterable {
    case notApplicable
    case represented
    case missing
}

enum ServerProviderServiceDescriptorTrustPosture: String, Codable, Hashable, Sendable, CaseIterable {
    case notApplicable
    case verified
    case unverified
    case missing
}

enum ServerProviderServiceConfirmationRequirement: String, Codable, Hashable, Sendable, CaseIterable {
    case notRequired
    case requiredSatisfied
    case requiredMissing
}

enum ServerProviderServiceServerSecretPosture: String, Codable, Hashable, Sendable, CaseIterable {
    case notRequired
    case serverOwned
    case clientOwned
    case missing
}

enum ServerProviderServicePrivateDataPosture: String, Codable, Hashable, Sendable, CaseIterable {
    case publicOrGeneral
    case privateOrHealthLocalOnly
    case containsPrivateRemoteData
}

enum ServerProviderServiceRateRetentionPosture: String, Codable, Hashable, Sendable, CaseIterable {
    case notApplicable
    case represented
    case missing
}

enum ServerProviderServiceSandboxAuditPosture: String, Codable, Hashable, Sendable, CaseIterable {
    case notApplicable
    case represented
    case missing
}

enum ServerProviderServiceExperimentalEnablementPosture: String, Codable, Hashable, Sendable, CaseIterable {
    case notRequired
    case enabled
    case disabled
}

enum ServerProviderServiceMCPAuthorizationPosture: String, Codable, Hashable, Sendable, CaseIterable {
    case notApplicable
    case represented
    case missing
}

enum ServerProviderServiceTokenProtectionPosture: String, Codable, Hashable, Sendable, CaseIterable {
    case notApplicable
    case represented
    case missing
}

/// Input for the product cut plan.
///
/// Every field is policy metadata. The struct intentionally carries no query
/// text, page body, provider response, secret, network address, or SDK object.
struct ServerProviderServiceCutPlanInput: Codable, Hashable, Sendable {
    let serviceIntent: ServerProviderServiceIntent
    let providerFamily: ProviderFamily
    let capability: ProviderCapability
    let membershipTier: MembershipTier
    let region: ProviderRegion
    let privacyClass: ProviderPrivacyClass
    let costClass: ProviderCostClass
    let quotaPosture: ServerProviderServiceQuotaPosture
    let sourceCitationRequirement: ServerProviderServiceSourceCitationRequirement
    let rawContentPolicy: ServerProviderServiceRawContentPolicy
    let attributionCacheDisplayPolicy: ServerProviderServiceAttributionCacheDisplayPolicy
    let descriptorTrustPosture: ServerProviderServiceDescriptorTrustPosture
    let confirmationRequirement: ServerProviderServiceConfirmationRequirement
    let serverSecretPosture: ServerProviderServiceServerSecretPosture
    let privateDataPosture: ServerProviderServicePrivateDataPosture
    let robotsState: SearchRobotsState
    let rateRetentionPosture: ServerProviderServiceRateRetentionPosture
    let sandboxAuditPosture: ServerProviderServiceSandboxAuditPosture
    let experimentalEnablementPosture: ServerProviderServiceExperimentalEnablementPosture
    let mcpAuthorizationPosture: ServerProviderServiceMCPAuthorizationPosture
    let tokenProtectionPosture: ServerProviderServiceTokenProtectionPosture

    init(
        serviceIntent: ServerProviderServiceIntent,
        providerFamily: ProviderFamily,
        capability: ProviderCapability,
        membershipTier: MembershipTier = .free,
        region: ProviderRegion = .global,
        privacyClass: ProviderPrivacyClass = .general,
        costClass: ProviderCostClass = .freeLocal,
        quotaPosture: ServerProviderServiceQuotaPosture = .notRequired,
        sourceCitationRequirement: ServerProviderServiceSourceCitationRequirement = .notApplicable,
        rawContentPolicy: ServerProviderServiceRawContentPolicy = .notApplicable,
        attributionCacheDisplayPolicy: ServerProviderServiceAttributionCacheDisplayPolicy = .notApplicable,
        descriptorTrustPosture: ServerProviderServiceDescriptorTrustPosture = .notApplicable,
        confirmationRequirement: ServerProviderServiceConfirmationRequirement = .notRequired,
        serverSecretPosture: ServerProviderServiceServerSecretPosture = .notRequired,
        privateDataPosture: ServerProviderServicePrivateDataPosture = .publicOrGeneral,
        robotsState: SearchRobotsState = .notApplicable,
        rateRetentionPosture: ServerProviderServiceRateRetentionPosture = .notApplicable,
        sandboxAuditPosture: ServerProviderServiceSandboxAuditPosture = .notApplicable,
        experimentalEnablementPosture: ServerProviderServiceExperimentalEnablementPosture = .notRequired,
        mcpAuthorizationPosture: ServerProviderServiceMCPAuthorizationPosture = .notApplicable,
        tokenProtectionPosture: ServerProviderServiceTokenProtectionPosture = .notApplicable
    ) {
        self.serviceIntent = serviceIntent
        self.providerFamily = providerFamily
        self.capability = capability
        self.membershipTier = membershipTier
        self.region = region
        self.privacyClass = privacyClass
        self.costClass = costClass
        self.quotaPosture = quotaPosture
        self.sourceCitationRequirement = sourceCitationRequirement
        self.rawContentPolicy = rawContentPolicy
        self.attributionCacheDisplayPolicy = attributionCacheDisplayPolicy
        self.descriptorTrustPosture = descriptorTrustPosture
        self.confirmationRequirement = confirmationRequirement
        self.serverSecretPosture = serverSecretPosture
        self.privateDataPosture = privateDataPosture
        self.robotsState = robotsState
        self.rateRetentionPosture = rateRetentionPosture
        self.sandboxAuditPosture = sandboxAuditPosture
        self.experimentalEnablementPosture = experimentalEnablementPosture
        self.mcpAuthorizationPosture = mcpAuthorizationPosture
        self.tokenProtectionPosture = tokenProtectionPosture
    }
}

struct ServerProviderServiceCutPlanDecision: Codable, Hashable, Sendable {
    let state: ServerProviderServiceCutPlanState
    let selectedLane: ServerProviderServiceLane?
    let providerFamily: ProviderFamily
    let serviceIntent: ServerProviderServiceIntent
    let capability: ProviderCapability
    let membershipTier: MembershipTier
    let region: ProviderRegion
    let privacyClass: ProviderPrivacyClass
    let costClass: ProviderCostClass
    let requiredPriorGates: [ServerProviderServiceGate]
    let blockReasons: [ServerProviderServiceCutPlanBlockReason]
    let statusLine: String

    var isRuntimeCallable: Bool { false }
    var isExecutable: Bool { false }
}

enum ServerProviderServiceCutPlanner {
    static func decide(
        _ input: ServerProviderServiceCutPlanInput
    ) -> ServerProviderServiceCutPlanDecision {
        guard let lane = lane(for: input) else {
            return decision(
                input,
                state: .unsupported,
                lane: nil,
                gates: [],
                reasons: [.unsupportedLane],
                statusLine: "Service lane is unsupported by the value-only cut plan."
            )
        }

        if input.providerFamily.isRemote,
           input.privacyClass.allowsRemoteProvider == false {
            return decision(
                input,
                state: .blocked,
                lane: lane,
                gates: [.privateDataLocalOnly],
                reasons: [.privacyBlocked],
                statusLine: "Remote service lane is blocked by privacy class."
            )
        }

        if input.providerFamily.isRemote,
           input.privateDataPosture != .publicOrGeneral {
            return decision(
                input,
                state: .blocked,
                lane: lane,
                gates: [.privateDataLocalOnly],
                reasons: [.privateDataBlocked],
                statusLine: "Remote service lane is blocked by private-data posture."
            )
        }

        switch lane {
        case .localAppleMaps, .cacheFallback:
            return localDecision(input, lane: lane)
        case .serverGoogleMaps, .serverGaode:
            return reservedDecision(
                input,
                lane: lane,
                gatesAndReasons: mapUpgradeGates(for: input),
                successLine: "Map service lane is reserved for a future server-mediated provider path."
            )
        case .serverSearchAPI:
            return reservedDecision(
                input,
                lane: lane,
                gatesAndReasons: searchAPIGates(for: input),
                successLine: "Search API service lane is reserved with source and cost policy represented."
            )
        case .reservedCrawler:
            return reservedDecision(
                input,
                lane: lane,
                gatesAndReasons: crawlerGates(for: input),
                successLine: "Crawler service lane is reserved only after source, robots, and audit policy."
            )
        case .reservedMCP:
            return reservedDecision(
                input,
                lane: lane,
                gatesAndReasons: mcpGates(for: input),
                successLine: "MCP service lane is reserved only after descriptor and authorization policy."
            )
        }
    }

    private static func lane(
        for input: ServerProviderServiceCutPlanInput
    ) -> ServerProviderServiceLane? {
        switch input.providerFamily {
        case .appleLocal:
            return supportsLocalMaps(input) ? .localAppleMaps : nil
        case .cache:
            return .cacheFallback
        case .googleMaps:
            return supportsMapOrLifeService(input) ? .serverGoogleMaps : nil
        case .gaode:
            return supportsMapOrLifeService(input) ? .serverGaode : nil
        case .searchAPI:
            return supportsSearch(input) ? .serverSearchAPI : nil
        case .crawler:
            return supportsCrawler(input) ? .reservedCrawler : nil
        case .mcp:
            return supportsMCP(input) ? .reservedMCP : nil
        }
    }

    private static func supportsLocalMaps(
        _ input: ServerProviderServiceCutPlanInput
    ) -> Bool {
        switch input.serviceIntent {
        case .mapDisplay:
            return input.capability == .mapDisplay
        case .mapRoute:
            return input.capability == .routePlanning
        case .mapSearch, .lifeServiceReadOnlyLookup:
            return input.capability == .placeSearch || input.capability == .localServiceSearch
        case .publicInfoSearch, .publicSourceCrawlCandidate,
             .mcpToolCandidate, .mcpResourceCandidate, .mcpPromptCandidate:
            return false
        }
    }

    private static func supportsMapOrLifeService(
        _ input: ServerProviderServiceCutPlanInput
    ) -> Bool {
        supportsLocalMaps(input)
    }

    private static func supportsSearch(
        _ input: ServerProviderServiceCutPlanInput
    ) -> Bool {
        switch input.serviceIntent {
        case .publicInfoSearch:
            return input.capability == .webSearch
        case .lifeServiceReadOnlyLookup:
            return input.capability == .localServiceSearch || input.capability == .webSearch
        case .mapDisplay, .mapRoute, .mapSearch, .publicSourceCrawlCandidate,
             .mcpToolCandidate, .mcpResourceCandidate, .mcpPromptCandidate:
            return false
        }
    }

    private static func supportsCrawler(
        _ input: ServerProviderServiceCutPlanInput
    ) -> Bool {
        input.serviceIntent == .publicSourceCrawlCandidate
            && input.capability == .crawlerFetch
    }

    private static func supportsMCP(
        _ input: ServerProviderServiceCutPlanInput
    ) -> Bool {
        switch input.serviceIntent {
        case .mcpToolCandidate:
            return input.capability == .mcpTool
        case .mcpResourceCandidate, .mcpPromptCandidate:
            return input.capability == .mcpTool
        case .mapDisplay, .mapRoute, .mapSearch, .publicInfoSearch,
             .publicSourceCrawlCandidate, .lifeServiceReadOnlyLookup:
            return false
        }
    }

    private static func localDecision(
        _ input: ServerProviderServiceCutPlanInput,
        lane: ServerProviderServiceLane
    ) -> ServerProviderServiceCutPlanDecision {
        decision(
            input,
            state: .localReady,
            lane: lane,
            gates: [],
            reasons: [],
            statusLine: "Local service lane is ready as value-only planning copy."
        )
    }

    private static func reservedDecision(
        _ input: ServerProviderServiceCutPlanInput,
        lane: ServerProviderServiceLane,
        gatesAndReasons: [(ServerProviderServiceGate, ServerProviderServiceCutPlanBlockReason)],
        successLine: String
    ) -> ServerProviderServiceCutPlanDecision {
        let gates = gatesAndReasons.map(\.0)
        let reasons = gatesAndReasons.map(\.1)
        return decision(
            input,
            state: reasons.isEmpty ? .serverReserved : .blocked,
            lane: lane,
            gates: reasons.isEmpty ? requiredSuccessGates(for: lane) : gates,
            reasons: reasons,
            statusLine: reasons.isEmpty
                ? successLine
                : "Service lane is blocked until required planning gates are represented."
        )
    }

    private static func mapUpgradeGates(
        for input: ServerProviderServiceCutPlanInput
    ) -> [(ServerProviderServiceGate, ServerProviderServiceCutPlanBlockReason)] {
        var missing: [(ServerProviderServiceGate, ServerProviderServiceCutPlanBlockReason)] = []
        if input.membershipTier < .plus {
            missing.append((.membershipPackage, .membershipMissing))
        }
        if input.region == .global {
            missing.append((.regionPolicy, .regionMissing))
        }
        if input.costClass != .includedQuota && input.costClass != .meteredPremium {
            missing.append((.costUnitPolicy, .costPolicyMissing))
        }
        if input.quotaPosture.isRepresentedForReservedLane == false {
            missing.append((.quotaOrQPSPolicy, .quotaPolicyMissing))
        }
        if input.attributionCacheDisplayPolicy != .represented {
            missing.append((.attributionCacheDisplayPolicy, .attributionCacheDisplayMissing))
        }
        appendSecretGate(input, to: &missing)
        return missing
    }

    private static func searchAPIGates(
        for input: ServerProviderServiceCutPlanInput
    ) -> [(ServerProviderServiceGate, ServerProviderServiceCutPlanBlockReason)] {
        var missing: [(ServerProviderServiceGate, ServerProviderServiceCutPlanBlockReason)] = []
        if input.membershipTier < .plus {
            missing.append((.membershipPackage, .membershipMissing))
        }
        if input.costClass != .includedQuota && input.costClass != .meteredPremium {
            missing.append((.costUnitPolicy, .costPolicyMissing))
        }
        if input.quotaPosture.isRepresentedForReservedLane == false {
            missing.append((.quotaOrQPSPolicy, .quotaPolicyMissing))
        }
        if input.sourceCitationRequirement != .requiredAndRepresented {
            missing.append((.sourceCitationPolicy, .sourceCitationMissing))
        }
        if input.rawContentPolicy != .redactedOrDisabled {
            missing.append((.rawContentPolicy, .rawContentPolicyMissing))
        }
        if input.rateRetentionPosture != .represented {
            missing.append((.retentionPolicy, .rateRetentionMissing))
        }
        appendSecretGate(input, to: &missing)
        return missing
    }

    private static func crawlerGates(
        for input: ServerProviderServiceCutPlanInput
    ) -> [(ServerProviderServiceGate, ServerProviderServiceCutPlanBlockReason)] {
        var missing = searchAPIGates(for: input)
        if input.robotsState != .allowed {
            missing.append((.robotsPolicy, .robotsPolicyMissingOrBlocked))
        }
        if input.sandboxAuditPosture != .represented {
            missing.append((.sandboxAudit, .sandboxAuditMissing))
        }
        if input.experimentalEnablementPosture != .enabled {
            missing.append((.experimentalEnablement, .experimentalProviderDisabled))
        }
        return missing
    }

    private static func mcpGates(
        for input: ServerProviderServiceCutPlanInput
    ) -> [(ServerProviderServiceGate, ServerProviderServiceCutPlanBlockReason)] {
        var missing: [(ServerProviderServiceGate, ServerProviderServiceCutPlanBlockReason)] = []
        if input.experimentalEnablementPosture != .enabled {
            missing.append((.experimentalEnablement, .experimentalProviderDisabled))
        }
        if input.descriptorTrustPosture != .verified {
            missing.append((.mcpDescriptorVerification, .descriptorUnverified))
        }
        if input.mcpAuthorizationPosture != .represented {
            missing.append((.mcpInvocationAuthorization, .mcpAuthorizationMissing))
            missing.append((.mcpDiscoveryFiltering, .mcpAuthorizationMissing))
        }
        if input.confirmationRequirement == .requiredMissing {
            missing.append((.mcpConsentConfirmation, .confirmationMissing))
        }
        if input.tokenProtectionPosture != .represented {
            missing.append((.mcpTokenProtection, .tokenProtectionMissing))
        }
        if input.sandboxAuditPosture != .represented {
            missing.append((.sandboxAudit, .sandboxAuditMissing))
        }
        appendSecretGate(input, to: &missing)
        return missing
    }

    private static func appendSecretGate(
        _ input: ServerProviderServiceCutPlanInput,
        to missing: inout [(ServerProviderServiceGate, ServerProviderServiceCutPlanBlockReason)]
    ) {
        switch input.serverSecretPosture {
        case .serverOwned:
            return
        case .clientOwned:
            missing.append((.serverSecretOwnership, .clientOwnedSecret))
        case .missing, .notRequired:
            missing.append((.serverSecretOwnership, .serverSecretMissing))
        }
    }

    private static func requiredSuccessGates(
        for lane: ServerProviderServiceLane
    ) -> [ServerProviderServiceGate] {
        switch lane {
        case .localAppleMaps, .cacheFallback:
            return []
        case .serverGoogleMaps, .serverGaode:
            return [
                .membershipPackage,
                .regionPolicy,
                .costUnitPolicy,
                .quotaOrQPSPolicy,
                .attributionCacheDisplayPolicy,
                .serverSecretOwnership,
            ]
        case .serverSearchAPI:
            return [
                .membershipPackage,
                .costUnitPolicy,
                .quotaOrQPSPolicy,
                .sourceCitationPolicy,
                .rawContentPolicy,
                .retentionPolicy,
                .serverSecretOwnership,
            ]
        case .reservedCrawler:
            return [
                .membershipPackage,
                .costUnitPolicy,
                .quotaOrQPSPolicy,
                .sourceCitationPolicy,
                .rawContentPolicy,
                .retentionPolicy,
                .serverSecretOwnership,
                .robotsPolicy,
                .sandboxAudit,
                .experimentalEnablement,
            ]
        case .reservedMCP:
            return [
                .experimentalEnablement,
                .mcpDescriptorVerification,
                .mcpDiscoveryFiltering,
                .mcpInvocationAuthorization,
                .mcpConsentConfirmation,
                .mcpTokenProtection,
                .sandboxAudit,
                .serverSecretOwnership,
            ]
        }
    }

    private static func decision(
        _ input: ServerProviderServiceCutPlanInput,
        state: ServerProviderServiceCutPlanState,
        lane: ServerProviderServiceLane?,
        gates: [ServerProviderServiceGate],
        reasons: [ServerProviderServiceCutPlanBlockReason],
        statusLine: String
    ) -> ServerProviderServiceCutPlanDecision {
        ServerProviderServiceCutPlanDecision(
            state: state,
            selectedLane: lane,
            providerFamily: input.providerFamily,
            serviceIntent: input.serviceIntent,
            capability: input.capability,
            membershipTier: input.membershipTier,
            region: input.region,
            privacyClass: input.privacyClass,
            costClass: input.costClass,
            requiredPriorGates: gates,
            blockReasons: reasons,
            statusLine: statusLine
        )
    }
}
