//
//  ServerProviderExecutionGate.swift
//  kAir
//
//  Pure A16 final readiness gate before any future server/provider runtime.
//  This file only classifies validated envelope factory results.
//

import Foundation

enum ServerProviderExecutionReadinessState: String, Codable, Hashable, Sendable, CaseIterable {
    case localOnly
    case serverReady
    case confirmationRequired
    case blocked
}

struct ServerProviderExecutionReadinessDecision: Hashable, Identifiable, Sendable {
    let id: String
    let state: ServerProviderExecutionReadinessState
    let statusLine: String
    let sendReadyEnvelope: ServerProviderEnvelope?
    let providerFamily: ProviderFamily?
    let capability: ProviderCapability?
    let privacyClass: ProviderPrivacyClass?
    let membershipTier: MembershipTier?
    let costClass: ProviderCostClass?
    let freshness: ProviderFreshness?
    let sourcePolicy: ServerSourcePolicy?
    let confirmationState: ServerConfirmationState?
    let factoryRejectionReason: ServerProviderEnvelopeFactoryRejectionReason?
    let validatorDenialReason: ServerProviderDenialReason?
    let validation: ServerProviderValidationDecision?
    let audit: ServerProviderAuditRecord?

    var isServerReady: Bool {
        state == .serverReady && sendReadyEnvelope != nil
    }
}

enum ServerProviderExecutionGate {
    nonisolated static func evaluate(
        _ result: ServerProviderEnvelopeFactoryResult
    ) -> ServerProviderExecutionReadinessDecision {
        let state = readinessState(for: result)
        let envelope = state == .serverReady ? result.envelope : nil
        let validation = result.validation
        let providerFamily = result.envelope?.providerFamily ?? validation?.audit.providerFamily
        let capability = result.envelope?.capability ?? validation?.audit.trace.capability
        let privacyClass = result.envelope?.privacyClass ?? validation?.audit.trace.privacyClass
        let membershipTier = result.envelope?.membershipTier ?? validation?.audit.trace.membershipTier
        let costClass = result.envelope?.costClass ?? validation?.audit.trace.costClass
        let freshness = result.envelope?.freshness ?? validation?.audit.trace.freshness
        let sourcePolicy = result.envelope?.sourcePolicy ?? validation?.audit.sourcePolicy
        let confirmationState = result.envelope?.confirmationState ?? validation?.audit.confirmationState
        let denialReason = validation?.denialReason ?? validatorDenialReason(from: result.rejectionReason)

        return ServerProviderExecutionReadinessDecision(
            id: "server-provider-execution-\(decisionID(for: result))",
            state: state,
            statusLine: statusLine(
                state: state,
                providerFamily: providerFamily,
                factoryRejectionReason: result.rejectionReason,
                validatorDenialReason: denialReason
            ),
            sendReadyEnvelope: envelope,
            providerFamily: providerFamily,
            capability: capability,
            privacyClass: privacyClass,
            membershipTier: membershipTier,
            costClass: costClass,
            freshness: freshness,
            sourcePolicy: sourcePolicy,
            confirmationState: confirmationState,
            factoryRejectionReason: result.rejectionReason,
            validatorDenialReason: denialReason,
            validation: validation,
            audit: validation?.audit
        )
    }

    nonisolated private static func readinessState(
        for result: ServerProviderEnvelopeFactoryResult
    ) -> ServerProviderExecutionReadinessState {
        if hasConfirmationRequirement(result) {
            return .confirmationRequired
        }

        guard let envelope = result.envelope,
              result.validation?.isAllowed == true else {
            return .blocked
        }

        return isRemoteProvider(envelope.providerFamily) ? .serverReady : .localOnly
    }

    nonisolated private static func hasConfirmationRequirement(
        _ result: ServerProviderEnvelopeFactoryResult
    ) -> Bool {
        if case .confirmationMissing? = result.rejectionReason {
            return true
        }
        if case .confirmationRequired? = result.validation?.denialReason {
            return true
        }
        if case .validatorRejected(.confirmationRequired)? = result.rejectionReason {
            return true
        }
        return false
    }

    nonisolated private static func validatorDenialReason(
        from rejectionReason: ServerProviderEnvelopeFactoryRejectionReason?
    ) -> ServerProviderDenialReason? {
        guard case .validatorRejected(let reason)? = rejectionReason else {
            return nil
        }
        return reason
    }

    nonisolated private static func decisionID(
        for result: ServerProviderEnvelopeFactoryResult
    ) -> String {
        if let traceID = result.envelope?.traceID ?? result.validation?.audit.trace.traceID,
           traceID.isEmpty == false {
            return slug(traceID)
        }
        if let reason = result.rejectionReason {
            return slug(rejectionLabel(reason))
        }
        return "unknown"
    }

    nonisolated private static func statusLine(
        state: ServerProviderExecutionReadinessState,
        providerFamily: ProviderFamily?,
        factoryRejectionReason: ServerProviderEnvelopeFactoryRejectionReason?,
        validatorDenialReason: ServerProviderDenialReason?
    ) -> String {
        let provider = providerFamily.map(providerLabel) ?? "provider route"
        switch state {
        case .localOnly:
            return "Local-only \(provider) route remains on device. No server transport will run."
        case .serverReady:
            return "Server \(provider) route is ready after policy checks. No provider runtime has run."
        case .confirmationRequired:
            return "Confirmation is required before \(provider) can become server-ready. No provider runtime has run."
        case .blocked:
            return "Provider route is blocked: \(blockedDetail(factoryRejectionReason, validatorDenialReason)). No provider runtime has run."
        }
    }

    nonisolated private static func blockedDetail(
        _ factoryRejectionReason: ServerProviderEnvelopeFactoryRejectionReason?,
        _ validatorDenialReason: ServerProviderDenialReason?
    ) -> String {
        if let validatorDenialReason {
            return validatorDetail(validatorDenialReason)
        }
        if let factoryRejectionReason {
            return factoryDetail(factoryRejectionReason)
        }
        return "factory result is not executable."
    }

    nonisolated private static func factoryDetail(
        _ reason: ServerProviderEnvelopeFactoryRejectionReason
    ) -> String {
        switch reason {
        case .upstreamUnresolved:
            return "upstream provider policy did not resolve."
        case .providerNotAllowed(let family):
            return "\(providerLabel(family)) is not allowed by quota policy."
        case .providerDisabled(let family):
            return "\(providerLabel(family)) is disabled by quota policy."
        case .entitlementMissing(let family):
            return "\(providerLabel(family)) entitlement is missing."
        case .includedQuotaExhausted(let family):
            return "\(providerLabel(family)) included quota is exhausted."
        case .meteredEligibilityMissing(let family):
            return "\(providerLabel(family)) metered eligibility is missing."
        case .experimentalProviderDisabled(let family):
            return "\(providerLabel(family)) experimental enablement is missing."
        case .sourcePolicyInsufficient:
            return "source policy metadata is insufficient."
        case .confirmationMissing:
            return "confirmation metadata is missing."
        case .validatorRejected(let reason):
            return validatorDetail(reason)
        }
    }

    nonisolated private static func validatorDetail(
        _ reason: ServerProviderDenialReason
    ) -> String {
        switch reason {
        case .missingTraceID:
            return "trace metadata is missing."
        case .unsupportedCapability:
            return "provider does not support this capability."
        case .blockedCostClass:
            return "cost class is blocked."
        case .privacyBlocked:
            return "privacy policy blocks remote routing."
        case .membershipTierTooLow:
            return "membership tier is too low."
        case .missingEntitlement:
            return "provider entitlement is missing."
        case .experimentalProviderDisabled:
            return "experimental provider is disabled."
        case .crawlerRobotsBlocked:
            return "crawler robots policy is blocked."
        case .crawlerSourceBlocked:
            return "crawler source policy has not passed."
        case .sourcePolicyBlocked:
            return "source policy is blocked."
        case .mcpDisabled:
            return "MCP is disabled by default."
        case .confirmationRequired:
            return "confirmation is required."
        }
    }

    nonisolated private static func rejectionLabel(
        _ reason: ServerProviderEnvelopeFactoryRejectionReason
    ) -> String {
        switch reason {
        case .upstreamUnresolved:
            return "upstream-unresolved"
        case .providerNotAllowed(let family):
            return "provider-not-allowed-\(family.rawValue)"
        case .providerDisabled(let family):
            return "provider-disabled-\(family.rawValue)"
        case .entitlementMissing(let family):
            return "entitlement-missing-\(family.rawValue)"
        case .includedQuotaExhausted(let family):
            return "included-quota-exhausted-\(family.rawValue)"
        case .meteredEligibilityMissing(let family):
            return "metered-eligibility-missing-\(family.rawValue)"
        case .experimentalProviderDisabled(let family):
            return "experimental-provider-disabled-\(family.rawValue)"
        case .sourcePolicyInsufficient:
            return "source-policy-insufficient"
        case .confirmationMissing:
            return "confirmation-missing"
        case .validatorRejected(let reason):
            return "validator-rejected-\(reason.rawValue)"
        }
    }

    nonisolated private static func providerLabel(_ family: ProviderFamily) -> String {
        switch family {
        case .appleLocal:
            return "Apple Local"
        case .gaode:
            return "Gaode"
        case .googleMaps:
            return "Google Maps"
        case .searchAPI:
            return "Search API"
        case .crawler:
            return "Crawler"
        case .mcp:
            return "MCP"
        case .cache:
            return "Local cache"
        }
    }

    nonisolated private static func isRemoteProvider(_ family: ProviderFamily) -> Bool {
        switch family {
        case .appleLocal, .cache:
            return false
        case .gaode, .googleMaps, .searchAPI, .crawler, .mcp:
            return true
        }
    }

    nonisolated private static func slug(_ value: String) -> String {
        let normalized = value
            .lowercased()
            .map { character in
                character.isLetter || character.isNumber ? String(character) : "-"
            }
            .joined()
        return normalized
            .split(separator: "-")
            .joined(separator: "-")
    }
}
