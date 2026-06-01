//
//  ServerProviderTransportAuditTrace.swift
//  kAir
//
//  Value-only audit trace for future external provider attempts.
//

import Foundation

enum ServerProviderTransportAuditFamily:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case searchAPI
    case gaode
    case googleMaps
    case crawler
    case mcp
    case remoteModel

    nonisolated var isReservedByDefault: Bool {
        self == .crawler || self == .mcp
    }

    nonisolated func supports(_ capability: ServerProviderTransportAuditCapability) -> Bool {
        switch self {
        case .searchAPI:
            return capability == .webSearch || capability == .localServiceSearch
        case .gaode, .googleMaps:
            return capability == .placeSearch
                || capability == .routePlanning
                || capability == .localServiceSearch
        case .crawler:
            return capability == .crawlerFetch || capability == .localServiceSearch
        case .mcp:
            return capability == .mcpTool
        case .remoteModel:
            return capability == .remoteModelCompletion
        }
    }
}

enum ServerProviderTransportAuditCapability:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case mapDisplay
    case placeSearch
    case routePlanning
    case webSearch
    case localServiceSearch
    case crawlerFetch
    case mcpTool
    case remoteModelCompletion
}

enum ServerProviderTransportAuditEventState:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case accepted
    case rejected
}

enum ServerProviderTransportAuditRejectionReason:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case missingRenderedRecommendationID
    case missingStatusSource
    case missingPrivacyPolicy
    case missingSourcePolicy
    case missingCitationPolicy
    case missingAttributionPolicy
    case unsupportedCapability
    case blockedCostClass
    case blockedPrivacyClass
    case reservedProviderDisabled
    case userConfirmationMissing
    case missingEvaluationDimension
    case unsafeRuntimeMaterial
}

enum ServerProviderTransportAuditEvaluationDimension:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case latency
    case cost
    case sourceQuality
    case citationAttribution
    case privacy
    case fallback
    case userConfirmation
    case safety
}

struct ServerProviderTransportAuditSourcePolicySummary:
    Codable,
    Hashable,
    Identifiable,
    Sendable
{
    let id: String
    let sourceState: ServerSourcePolicyState
    let robotsState: SearchRobotsState
    let sourcePolicyRequired: Bool
    let citationPolicyRequired: Bool
    let citationPolicyPresent: Bool
    let attributionPolicyRequired: Bool
    let attributionPolicyPresent: Bool

    init(
        id: String,
        sourceState: ServerSourcePolicyState,
        robotsState: SearchRobotsState = .notApplicable,
        sourcePolicyRequired: Bool,
        citationPolicyRequired: Bool,
        citationPolicyPresent: Bool,
        attributionPolicyRequired: Bool,
        attributionPolicyPresent: Bool
    ) {
        self.id = Self.safeID(id, fallback: "audit-source-policy")
        self.sourceState = sourceState
        self.robotsState = robotsState
        self.sourcePolicyRequired = sourcePolicyRequired
        self.citationPolicyRequired = citationPolicyRequired
        self.citationPolicyPresent = citationPolicyPresent
        self.attributionPolicyRequired = attributionPolicyRequired
        self.attributionPolicyPresent = attributionPolicyPresent
    }

    private static func safeID(
        _ value: String,
        fallback: String
    ) -> String {
        ServerProviderTransportAuditSanitizer.safeID(value, fallback: fallback)
    }
}

struct ServerProviderTransportAuditRequest: Hashable, Sendable {
    let renderedRecommendationID: String
    let providerFamily: ServerProviderTransportAuditFamily
    let capability: ServerProviderTransportAuditCapability
    let membershipTier: MembershipTier
    let costClass: ProviderCostClass
    let privacyClass: ProviderPrivacyClass?
    let sourcePolicySummary: ServerProviderTransportAuditSourcePolicySummary?
    let statusSourceID: String
    let selectedStatusSourceRank: Int
    let confirmationState: ServerConfirmationState
    let requiresUserConfirmation: Bool
    let enabledReservedProviderFamilies: Set<ServerProviderTransportAuditFamily>
    let evaluationDimensions: Set<ServerProviderTransportAuditEvaluationDimension>
    let unsafeRuntimeMaterial: [String]

    init(
        renderedRecommendationID: String,
        providerFamily: ServerProviderTransportAuditFamily,
        capability: ServerProviderTransportAuditCapability,
        membershipTier: MembershipTier,
        costClass: ProviderCostClass,
        privacyClass: ProviderPrivacyClass? = .general,
        sourcePolicySummary: ServerProviderTransportAuditSourcePolicySummary? = nil,
        statusSourceID: String,
        selectedStatusSourceRank: Int = 0,
        confirmationState: ServerConfirmationState = .notRequired,
        requiresUserConfirmation: Bool = false,
        enabledReservedProviderFamilies: Set<ServerProviderTransportAuditFamily> = [],
        evaluationDimensions: Set<ServerProviderTransportAuditEvaluationDimension> =
            ServerProviderTransportAuditEvaluationDimension.requiredSet,
        unsafeRuntimeMaterial: [String] = []
    ) {
        self.renderedRecommendationID = renderedRecommendationID
        self.providerFamily = providerFamily
        self.capability = capability
        self.membershipTier = membershipTier
        self.costClass = costClass
        self.privacyClass = privacyClass
        self.sourcePolicySummary = sourcePolicySummary
        self.statusSourceID = statusSourceID
        self.selectedStatusSourceRank = selectedStatusSourceRank
        self.confirmationState = confirmationState
        self.requiresUserConfirmation = requiresUserConfirmation
        self.enabledReservedProviderFamilies = enabledReservedProviderFamilies
        self.evaluationDimensions = evaluationDimensions
        self.unsafeRuntimeMaterial = unsafeRuntimeMaterial
    }
}

struct ServerProviderTransportAuditTrace:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let renderedRecommendationID: String
    let providerFamily: ServerProviderTransportAuditFamily
    let capability: ServerProviderTransportAuditCapability
    let membershipTier: MembershipTier
    let costClass: ProviderCostClass
    let privacyClass: ProviderPrivacyClass
    let sourcePolicySummary: ServerProviderTransportAuditSourcePolicySummary?
    let statusSourceID: String
    let selectedStatusSourceRank: Int
    let confirmationState: ServerConfirmationState
    let evaluationDimensions: Set<ServerProviderTransportAuditEvaluationDimension>

    var description: String {
        [
            "ServerProviderTransportAuditTrace(",
            "id: \(id), ",
            "providerFamily: \(providerFamily.rawValue), ",
            "capability: \(capability.rawValue), ",
            "statusSourceID: \(statusSourceID)",
            ")",
        ].joined()
    }
}

struct ServerProviderTransportAuditSafeCopy:
    Codable,
    Hashable,
    Identifiable,
    Sendable
{
    let id: String
    let state: ServerProviderTransportAuditEventState
    let renderedRecommendationID: String?
    let providerFamily: ServerProviderTransportAuditFamily
    let capability: ServerProviderTransportAuditCapability
    let membershipTier: MembershipTier
    let costClass: ProviderCostClass
    let privacyClass: ProviderPrivacyClass?
    let sourcePolicyID: String?
    let statusSourceID: String?
    let selectedStatusSourceRank: Int
    let confirmationState: ServerConfirmationState
    let evaluationDimensionIDs: [String]
    let rejectionReason: ServerProviderTransportAuditRejectionReason?
    let statusLine: String
}

struct ServerProviderTransportAuditEvent:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let state: ServerProviderTransportAuditEventState
    let statusLine: String
    let trace: ServerProviderTransportAuditTrace?
    let rejectionReason: ServerProviderTransportAuditRejectionReason?
    let safeCopy: ServerProviderTransportAuditSafeCopy

    nonisolated var isAccepted: Bool {
        state == .accepted && trace != nil
    }

    var description: String {
        [
            "ServerProviderTransportAuditEvent(",
            "id: \(id), ",
            "state: \(state.rawValue), ",
            "rejection: \(rejectionReason?.rawValue ?? "none")",
            ")",
        ].joined()
    }
}

enum ServerProviderTransportAuditTraceBuilder {
    static func evaluate(
        _ request: ServerProviderTransportAuditRequest
    ) -> ServerProviderTransportAuditEvent {
        let renderedID = normalizedID(request.renderedRecommendationID)
        guard renderedID.isEmpty == false else {
            return rejected(.missingRenderedRecommendationID, request: request)
        }
        let statusSourceID = normalizedID(request.statusSourceID)
        guard statusSourceID.isEmpty == false,
              request.selectedStatusSourceRank >= 0 else {
            return rejected(.missingStatusSource, request: request)
        }
        guard let privacyClass = request.privacyClass else {
            return rejected(.missingPrivacyPolicy, request: request)
        }
        guard request.providerFamily.supports(request.capability) else {
            return rejected(.unsupportedCapability, request: request)
        }
        guard isBlockedCost(request.costClass) == false else {
            return rejected(.blockedCostClass, request: request)
        }
        guard privacyClass.allowsRemoteProvider else {
            return rejected(.blockedPrivacyClass, request: request)
        }
        if request.providerFamily.isReservedByDefault,
           request.enabledReservedProviderFamilies.contains(request.providerFamily) == false {
            return rejected(.reservedProviderDisabled, request: request)
        }
        if requiresConfirmation(request),
           request.confirmationState.isSatisfied == false {
            return rejected(.userConfirmationMissing, request: request)
        }
        if let sourceRejection = sourcePolicyRejection(for: request) {
            return rejected(sourceRejection, request: request)
        }
        guard request.evaluationDimensions.isSuperset(
            of: ServerProviderTransportAuditEvaluationDimension.requiredSet
        ) else {
            return rejected(.missingEvaluationDimension, request: request)
        }
        guard containsUnsafeRuntimeMaterial(request.unsafeRuntimeMaterial) == false else {
            return rejected(.unsafeRuntimeMaterial, request: request)
        }

        let trace = ServerProviderTransportAuditTrace(
            id: "provider-transport-audit-\(renderedID)-\(request.providerFamily.rawValue)",
            renderedRecommendationID: renderedID,
            providerFamily: request.providerFamily,
            capability: request.capability,
            membershipTier: request.membershipTier,
            costClass: request.costClass,
            privacyClass: privacyClass,
            sourcePolicySummary: request.sourcePolicySummary,
            statusSourceID: statusSourceID,
            selectedStatusSourceRank: request.selectedStatusSourceRank,
            confirmationState: request.confirmationState,
            evaluationDimensions: request.evaluationDimensions
        )
        let statusLine = "Provider transport audit accepted for \(request.providerFamily.rawValue) using value-only metadata. No provider transport has run."
        return event(
            state: .accepted,
            statusLine: statusLine,
            request: request,
            trace: trace,
            rejectionReason: nil
        )
    }

    private static func rejected(
        _ reason: ServerProviderTransportAuditRejectionReason,
        request: ServerProviderTransportAuditRequest
    ) -> ServerProviderTransportAuditEvent {
        event(
            state: .rejected,
            statusLine: "Provider transport audit blocked for \(request.providerFamily.rawValue): \(reason.rawValue). No provider transport has run.",
            request: request,
            trace: nil,
            rejectionReason: reason
        )
    }

    private static func event(
        state: ServerProviderTransportAuditEventState,
        statusLine: String,
        request: ServerProviderTransportAuditRequest,
        trace: ServerProviderTransportAuditTrace?,
        rejectionReason: ServerProviderTransportAuditRejectionReason?
    ) -> ServerProviderTransportAuditEvent {
        let renderedID = normalizedID(request.renderedRecommendationID)
        let statusSourceID = normalizedID(request.statusSourceID)
        let eventID = [
            "provider-transport-audit",
            renderedID.isEmpty ? "missing-rendered-id" : renderedID,
            request.providerFamily.rawValue,
            state.rawValue,
            rejectionReason?.rawValue,
        ]
            .compactMap { $0 }
            .joined(separator: "-")
        let safeCopy = ServerProviderTransportAuditSafeCopy(
            id: "\(eventID)-safe-copy",
            state: state,
            renderedRecommendationID: renderedID.isEmpty ? nil : renderedID,
            providerFamily: request.providerFamily,
            capability: request.capability,
            membershipTier: request.membershipTier,
            costClass: request.costClass,
            privacyClass: request.privacyClass,
            sourcePolicyID: request.sourcePolicySummary?.id,
            statusSourceID: statusSourceID.isEmpty ? nil : statusSourceID,
            selectedStatusSourceRank: max(0, request.selectedStatusSourceRank),
            confirmationState: request.confirmationState,
            evaluationDimensionIDs: request.evaluationDimensions.stableIDs,
            rejectionReason: rejectionReason,
            statusLine: statusLine
        )
        return ServerProviderTransportAuditEvent(
            id: eventID,
            state: state,
            statusLine: statusLine,
            trace: trace,
            rejectionReason: rejectionReason,
            safeCopy: safeCopy
        )
    }

    private static func sourcePolicyRejection(
        for request: ServerProviderTransportAuditRequest
    ) -> ServerProviderTransportAuditRejectionReason? {
        let requirements = sourceRequirements(for: request.providerFamily)
        guard requirements.requiresAnyPolicy else {
            return nil
        }
        guard let summary = request.sourcePolicySummary else {
            return .missingSourcePolicy
        }
        if requirements.sourceRequired,
           summary.sourceState != .passed {
            return .missingSourcePolicy
        }
        if request.providerFamily == .crawler,
           summary.robotsState != .allowed {
            return .missingSourcePolicy
        }
        if requirements.citationRequired,
           (summary.citationPolicyRequired == false || summary.citationPolicyPresent == false) {
            return .missingCitationPolicy
        }
        if requirements.attributionRequired,
           (summary.attributionPolicyRequired == false || summary.attributionPolicyPresent == false) {
            return .missingAttributionPolicy
        }
        return nil
    }

    private static func sourceRequirements(
        for family: ServerProviderTransportAuditFamily
    ) -> SourceRequirements {
        switch family {
        case .searchAPI:
            return SourceRequirements(
                sourceRequired: true,
                citationRequired: true,
                attributionRequired: true
            )
        case .gaode, .googleMaps:
            return SourceRequirements(
                sourceRequired: false,
                citationRequired: false,
                attributionRequired: true
            )
        case .crawler:
            return SourceRequirements(
                sourceRequired: true,
                citationRequired: true,
                attributionRequired: true
            )
        case .mcp, .remoteModel:
            return SourceRequirements(
                sourceRequired: false,
                citationRequired: false,
                attributionRequired: false
            )
        }
    }

    private static func requiresConfirmation(
        _ request: ServerProviderTransportAuditRequest
    ) -> Bool {
        request.requiresUserConfirmation || request.providerFamily == .mcp
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

    private static func containsUnsafeRuntimeMaterial(
        _ values: [String]
    ) -> Bool {
        let probes = values.map { $0.lowercased() }
        return probes.contains { value in
            ServerProviderTransportAuditSanitizer.disallowedRuntimeFragments.contains {
                value.contains($0)
            }
        }
    }

    private static func normalizedID(
        _ value: String
    ) -> String {
        ServerProviderTransportAuditSanitizer.safeID(value, fallback: "")
    }
}

private struct SourceRequirements: Hashable, Sendable {
    let sourceRequired: Bool
    let citationRequired: Bool
    let attributionRequired: Bool

    var requiresAnyPolicy: Bool {
        sourceRequired || citationRequired || attributionRequired
    }
}

private enum ServerProviderTransportAuditSanitizer {
    static let disallowedRuntimeFragments = [
        "url" + "session",
        "http" + "s://",
        "api" + "key",
        "o" + "auth",
        "s" + "dk",
        "mcp" + "client",
        "store" + "kit",
        "book" + "ing",
        "pay" + "ment",
        "raw" + "query",
        "raw" + "page",
        "provider" + "payload",
        "exec" + "ution",
    ]

    static func safeID(
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

private extension Set where Element == ServerProviderTransportAuditEvaluationDimension {
    var stableIDs: [String] {
        map(\.rawValue).sorted()
    }
}

extension ServerProviderTransportAuditEvaluationDimension {
    nonisolated static let requiredSet: Set<ServerProviderTransportAuditEvaluationDimension> = [
        .latency,
        .cost,
        .sourceQuality,
        .citationAttribution,
        .privacy,
        .fallback,
        .userConfirmation,
        .safety,
    ]
}
