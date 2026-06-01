//
//  ServerProviderEnvelopeFactory.swift
//  kAir
//
//  Pure A12 adapter from provider/search/MCP policy decisions into the A11
//  server/provider envelope. No transport is executed here.
//

import Foundation

struct ServerProviderQuotaSnapshot: Codable, Hashable, Sendable {
    let allowedProviderFamilies: Set<ProviderFamily>
    let entitledProviderFamilies: Set<ProviderFamily>
    let remainingIncludedQuota: [ProviderFamily: Int]
    let meteredEligibleProviderFamilies: Set<ProviderFamily>
    let disabledProviderFamilies: Set<ProviderFamily>
    let enabledExperimentalProviderFamilies: Set<ProviderFamily>

    init(
        allowedProviderFamilies: Set<ProviderFamily> = [.appleLocal, .cache],
        entitledProviderFamilies: Set<ProviderFamily> = [],
        remainingIncludedQuota: [ProviderFamily: Int] = [:],
        meteredEligibleProviderFamilies: Set<ProviderFamily> = [],
        disabledProviderFamilies: Set<ProviderFamily> = [],
        enabledExperimentalProviderFamilies: Set<ProviderFamily> = []
    ) {
        self.allowedProviderFamilies = allowedProviderFamilies
        self.entitledProviderFamilies = entitledProviderFamilies
        self.remainingIncludedQuota = remainingIncludedQuota
        self.meteredEligibleProviderFamilies = meteredEligibleProviderFamilies
        self.disabledProviderFamilies = disabledProviderFamilies
        self.enabledExperimentalProviderFamilies = enabledExperimentalProviderFamilies
    }

    /// Builds an explicit quota snapshot from app-root access defaults.
    ///
    /// The profile may declare membership, metered entitlements, unavailable
    /// providers, and experimental intent, but it must not silently grant remote
    /// provider allowance. Callers still supply the provider families currently
    /// allowed by server policy plus concrete included-quota and metered
    /// eligibility inputs.
    init(
        providerAccessProfile profile: ProviderAccessProfile,
        allowedProviderFamilies: Set<ProviderFamily> = [.appleLocal, .cache],
        entitledProviderFamilies: Set<ProviderFamily> = [],
        remainingIncludedQuota: [ProviderFamily: Int] = [:],
        meteredEligibleProviderFamilies: Set<ProviderFamily> = [],
        disabledProviderFamilies: Set<ProviderFamily> = [],
        enabledExperimentalProviderFamilies: Set<ProviderFamily> = []
    ) {
        let includedQuotaEntitlements = Set(
            remainingIncludedQuota.compactMap { family, remaining in
                remaining > 0 ? family : nil
            }
        )
        self.allowedProviderFamilies = allowedProviderFamilies
        self.entitledProviderFamilies = entitledProviderFamilies
            .union(profile.meteredProviderEntitlements)
            .union(includedQuotaEntitlements)
        self.remainingIncludedQuota = remainingIncludedQuota
        self.meteredEligibleProviderFamilies = meteredEligibleProviderFamilies
        self.disabledProviderFamilies = disabledProviderFamilies
            .union(profile.unavailableProviders)
        self.enabledExperimentalProviderFamilies = enabledExperimentalProviderFamilies
            .intersection(profile.enabledExperimentalProviders)
    }

    func mergedEntitlements(with requestEntitlements: Set<ProviderFamily>) -> Set<ProviderFamily> {
        requestEntitlements.union(entitledProviderFamilies)
    }

    func enabledExperimentalProviders(
        from requestEnabledProviders: Set<ProviderFamily>
    ) -> Set<ProviderFamily> {
        requestEnabledProviders.intersection(enabledExperimentalProviderFamilies)
    }
}

enum ServerProviderEnvelopeFactoryRejectionReason: Codable, Hashable, Sendable {
    case upstreamUnresolved
    case providerNotAllowed(ProviderFamily)
    case providerDisabled(ProviderFamily)
    case entitlementMissing(ProviderFamily)
    case includedQuotaExhausted(ProviderFamily)
    case meteredEligibilityMissing(ProviderFamily)
    case experimentalProviderDisabled(ProviderFamily)
    case sourcePolicyInsufficient
    case confirmationMissing
    case validatorRejected(ServerProviderDenialReason)
}

struct ServerProviderEnvelopeFactoryResult: Hashable, Sendable {
    let envelope: ServerProviderEnvelope?
    let validation: ServerProviderValidationDecision?
    let rejectionReason: ServerProviderEnvelopeFactoryRejectionReason?

    var isExecutable: Bool {
        envelope != nil && validation?.isAllowed == true
    }

    static func executable(
        envelope: ServerProviderEnvelope,
        validation: ServerProviderValidationDecision
    ) -> ServerProviderEnvelopeFactoryResult {
        ServerProviderEnvelopeFactoryResult(
            envelope: envelope,
            validation: validation,
            rejectionReason: nil
        )
    }

    static func blocked(
        _ reason: ServerProviderEnvelopeFactoryRejectionReason,
        validation: ServerProviderValidationDecision? = nil
    ) -> ServerProviderEnvelopeFactoryResult {
        ServerProviderEnvelopeFactoryResult(
            envelope: nil,
            validation: validation,
            rejectionReason: reason
        )
    }
}

enum ServerProviderEnvelopeFactory {
    static func makeEnvelope(
        for request: ProviderRequest,
        selection: ProviderSelection,
        quotaSnapshot: ServerProviderQuotaSnapshot
    ) -> ServerProviderEnvelopeFactoryResult {
        guard let provider = selection.provider, selection.isResolved else {
            return .blocked(.upstreamUnresolved)
        }

        if let rejection = quotaRejection(
            for: provider.family,
            costClass: provider.costClass,
            quotaSnapshot: quotaSnapshot
        ) {
            return .blocked(rejection)
        }

        let envelope = ServerProviderEnvelope(
            traceID: request.traceID,
            capability: request.capability,
            providerFamily: provider.family,
            privacyClass: request.privacyClass,
            membershipTier: request.membershipTier,
            costClass: provider.costClass,
            freshness: request.freshness,
            sourcePolicy: .notApplicable,
            confirmationState: .notRequired,
            meteredProviderEntitlements: quotaSnapshot.mergedEntitlements(
                with: request.meteredProviderEntitlements
            ),
            enabledExperimentalProviders: quotaSnapshot.enabledExperimentalProviders(
                from: request.enabledExperimentalProviders
            )
        )
        return validated(envelope)
    }

    static func makeEnvelope(
        for request: SearchProviderRequest,
        decision: SearchProviderDecision,
        quotaSnapshot: ServerProviderQuotaSnapshot
    ) -> ServerProviderEnvelopeFactoryResult {
        guard let provider = decision.selectedProvider,
              decision.isResolved else {
            return .blocked(.upstreamUnresolved)
        }

        if let rejection = quotaRejection(
            for: provider.family,
            costClass: provider.costClass,
            quotaSnapshot: quotaSnapshot
        ) {
            return .blocked(rejection)
        }

        guard let sourcePolicy = sourcePolicy(
            for: request,
            decision: decision,
            provider: provider
        ) else {
            return .blocked(.sourcePolicyInsufficient)
        }

        let envelope = ServerProviderEnvelope(
            traceID: request.traceID,
            capability: request.capability,
            providerFamily: provider.family,
            privacyClass: request.privacyClass,
            membershipTier: request.membershipTier,
            costClass: provider.costClass,
            freshness: decision.result?.freshness ?? request.freshness,
            sourcePolicy: sourcePolicy,
            confirmationState: .notRequired,
            meteredProviderEntitlements: quotaSnapshot.mergedEntitlements(
                with: request.meteredProviderEntitlements
            ),
            enabledExperimentalProviders: quotaSnapshot.enabledExperimentalProviders(
                from: request.enabledExperimentalProviders
            )
        )
        return validated(envelope)
    }

    static func makeEnvelope(
        for request: MCPGatewayRequest,
        decision: MCPGatewayDecision,
        quotaSnapshot: ServerProviderQuotaSnapshot
    ) -> ServerProviderEnvelopeFactoryResult {
        guard decision.isAllowed else {
            return .blocked(.upstreamUnresolved)
        }
        guard decision.requiresConfirmation == false else {
            return .blocked(.confirmationMissing)
        }

        if let rejection = quotaRejection(
            for: .mcp,
            costClass: decision.audit.trace.costClass,
            quotaSnapshot: quotaSnapshot
        ) {
            return .blocked(rejection)
        }

        let envelope = ServerProviderEnvelope(
            traceID: request.traceID,
            capability: .mcpTool,
            providerFamily: .mcp,
            privacyClass: request.privacyClass,
            membershipTier: request.membershipTier,
            costClass: decision.audit.trace.costClass,
            freshness: decision.audit.trace.freshness,
            sourcePolicy: .notApplicable,
            confirmationState: confirmationState(from: request.confirmationArtifact),
            meteredProviderEntitlements: quotaSnapshot.entitledProviderFamilies,
            enabledExperimentalProviders: quotaSnapshot.enabledExperimentalProviderFamilies
        )
        return validated(envelope)
    }

    private static func quotaRejection(
        for family: ProviderFamily,
        costClass: ProviderCostClass,
        quotaSnapshot: ServerProviderQuotaSnapshot
    ) -> ServerProviderEnvelopeFactoryRejectionReason? {
        if quotaSnapshot.disabledProviderFamilies.contains(family) {
            return .providerDisabled(family)
        }
        guard quotaSnapshot.allowedProviderFamilies.contains(family) else {
            return .providerNotAllowed(family)
        }
        if family.requiresA12Entitlement,
           quotaSnapshot.entitledProviderFamilies.contains(family) == false {
            return .entitlementMissing(family)
        }
        if family.isDisabledByDefault,
           quotaSnapshot.enabledExperimentalProviderFamilies.contains(family) == false {
            return .experimentalProviderDisabled(family)
        }
        if costClass == .includedQuota,
           quotaSnapshot.remainingIncludedQuota[family, default: 0] <= 0 {
            return .includedQuotaExhausted(family)
        }
        if costClass == .meteredPremium,
           quotaSnapshot.meteredEligibleProviderFamilies.contains(family) == false {
            return .meteredEligibilityMissing(family)
        }
        return nil
    }

    private static func sourcePolicy(
        for request: SearchProviderRequest,
        decision: SearchProviderDecision,
        provider: SearchProviderDescriptor
    ) -> ServerSourcePolicy? {
        guard let result = decision.result else {
            return nil
        }

        if provider.family == .cache {
            return .notApplicable
        }

        guard let host = result.sourceURL.host?.lowercased(),
              host.isEmpty == false else {
            return nil
        }

        if provider.family == .crawler,
           request.robotsState != .allowed {
            return nil
        }

        return ServerSourcePolicy(
            sourceState: .passed,
            robotsState: provider.requiresRobotsAllow ? request.robotsState : .notApplicable,
            attributionRequired: provider.requiresRobotsAllow || provider.costClass != .freeLocal,
            sourceHost: host
        )
    }

    private static func confirmationState(
        from artifact: MCPConfirmationArtifact?
    ) -> ServerConfirmationState {
        guard let artifact else { return .notRequired }
        return .confirmed(artifactID: artifact.id)
    }

    private static func validated(
        _ envelope: ServerProviderEnvelope
    ) -> ServerProviderEnvelopeFactoryResult {
        let validation = ServerProviderEnvelopeValidator.validate(envelope)
        guard validation.isAllowed else {
            return .blocked(
                .validatorRejected(validation.denialReason ?? .unsupportedCapability),
                validation: validation
            )
        }
        return .executable(envelope: envelope, validation: validation)
    }
}

private extension ProviderFamily {
    var requiresA12Entitlement: Bool {
        switch self {
        case .appleLocal, .cache:
            return false
        case .gaode, .googleMaps, .searchAPI, .crawler, .mcp:
            return true
        }
    }
}
