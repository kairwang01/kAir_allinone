//
//  ServerProviderSearchAPIAdapterContract.swift
//  kAir
//
//  Value-only Search API adapter contract. This file prepares and normalizes
//  metadata only; it never contacts a provider or transport.
//

import Foundation

enum ServerProviderSearchAPIAdapterRequestState: String, Codable, Hashable, Sendable, CaseIterable {
    case requestPrepared
    case rejected
}

enum ServerProviderSearchAPIAdapterResultState: String, Codable, Hashable, Sendable, CaseIterable {
    case resultNormalized
    case rejected
}

enum ServerProviderSearchAPIAdapterRejectionReason: String, Codable, Hashable, Sendable, CaseIterable {
    case emptyQuery
    case invalidResultLimit
    case providerFamilyNotSearchAPI
    case unsupportedCapability
    case privacyBlocked
    case quotaBlocked
    case entitlementMissing
    case sourcePolicyInsufficient
    case citationPolicyMissing
    case connectorReceiptRejected
    case connectorMetadataMissing
    case connectorProviderFamilyMismatch
    case connectorCapabilityMismatch
    case connectorTraceMismatch
    case connectorCostMismatch
    case connectorFreshnessMismatch
    case resultContentMissing
    case resultCitationMissing
    case resultCitationSourceMismatch
    case resultStaleForLiveRequired
}

struct ServerProviderSearchAPIAdapterQuery: Codable, Hashable, Sendable {
    let text: String
    let localeHint: String?

    init(
        text: String,
        localeHint: String? = nil
    ) {
        self.text = Self.normalized(text, maxLength: 240)
        self.localeHint = localeHint.map { Self.normalized($0, maxLength: 32) }
            .flatMap { $0.isEmpty ? nil : $0 }
    }

    var isValid: Bool {
        text.isEmpty == false
    }

    private static func normalized(
        _ value: String,
        maxLength: Int
    ) -> String {
        let collapsed = value
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard collapsed.count > maxLength else {
            return collapsed
        }
        return String(collapsed.prefix(maxLength))
    }
}

struct ServerProviderSearchAPIAdapterQuotaSummary: Codable, Hashable, Sendable {
    let providerFamily: ProviderFamily
    let membershipTier: MembershipTier
    let costClass: ProviderCostClass
    let entitlementPresent: Bool

    var isAllowed: Bool {
        costClass.isSearchAPIAdapterAllowed && entitlementPresent
    }

    var statusLine: String {
        if isAllowed {
            return "Search API quota metadata is eligible. No provider runtime has run."
        }
        return "Search API quota metadata is not eligible. No provider runtime has run."
    }
}

struct ServerProviderSearchAPIAdapterAccessSummary: Codable, Hashable, Sendable {
    let membershipTier: MembershipTier
    let privacyClass: ProviderPrivacyClass
    let providerFamily: ProviderFamily
    let capability: ProviderCapability
}

struct ServerProviderSearchAPIAdapterSourcePolicySnapshot: Codable, Hashable, Sendable {
    let sourceState: ServerSourcePolicyState
    let robotsState: SearchRobotsState
    let attributionRequired: Bool
    let sourceHost: String?
    let citationRequired: Bool

    init(
        sourcePolicy: ServerSourcePolicy,
        citationRequired: Bool = true
    ) {
        self.sourceState = sourcePolicy.sourceState
        self.robotsState = sourcePolicy.robotsState
        self.attributionRequired = sourcePolicy.attributionRequired
        self.sourceHost = sourcePolicy.sourceHost?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        self.citationRequired = citationRequired
    }

    var hasApprovedSourcePolicy: Bool {
        sourceState == .passed
    }

    var hasCitationPolicy: Bool {
        citationRequired && attributionRequired
    }
}

struct ServerProviderSearchAPIAdapterRequest:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let traceID: String
    let envelopeTraceID: String
    let connectorReceiptID: String
    let connectorRequestID: String?
    let providerFamily: ProviderFamily
    let capability: ProviderCapability
    let privacyClass: ProviderPrivacyClass
    let membershipTier: MembershipTier
    let costClass: ProviderCostClass
    let freshness: ProviderFreshness
    let resultLimit: Int
    let query: ServerProviderSearchAPIAdapterQuery
    let quotaSummary: ServerProviderSearchAPIAdapterQuotaSummary
    let accessSummary: ServerProviderSearchAPIAdapterAccessSummary
    let sourcePolicy: ServerProviderSearchAPIAdapterSourcePolicySnapshot

    var description: String {
        "ServerProviderSearchAPIAdapterRequest(id: \(id), providerFamily: \(providerFamily.rawValue), capability: \(capability.rawValue))"
    }

    var statusLine: String {
        "Search API adapter request is prepared from approved metadata only. No provider runtime has run."
    }
}

struct ServerProviderSearchAPIAdapterRequestDecision:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let state: ServerProviderSearchAPIAdapterRequestState
    let statusLine: String
    let request: ServerProviderSearchAPIAdapterRequest?
    let rejection: ServerProviderSearchAPIAdapterRejectionReason?

    var description: String {
        "ServerProviderSearchAPIAdapterRequestDecision(id: \(id), state: \(state.rawValue), rejection: \(rejection?.rawValue ?? "none"))"
    }
}

struct ServerProviderSearchAPIAdapterCitation: Codable, Hashable, Sendable {
    let sourceURL: URL
    let sourceHost: String
    let title: String
    let attribution: String

    init(
        sourceURL: URL,
        title: String,
        attribution: String
    ) {
        self.sourceURL = sourceURL
        self.sourceHost = sourceURL.host?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        self.title = Self.normalized(title, maxLength: 160)
        self.attribution = Self.normalized(attribution, maxLength: 120)
    }

    var isValid: Bool {
        sourceHost.isEmpty == false
            && title.isEmpty == false
            && attribution.isEmpty == false
            && ["http", "https"].contains(sourceURL.scheme?.lowercased() ?? "")
    }

    private static func normalized(
        _ value: String,
        maxLength: Int
    ) -> String {
        let collapsed = value
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard collapsed.count > maxLength else {
            return collapsed
        }
        return String(collapsed.prefix(maxLength))
    }
}

struct ServerProviderSearchAPIAdapterResultCandidate: Codable, Hashable, Sendable {
    let title: String
    let snippet: String
    let freshness: ProviderFreshness
    let citations: [ServerProviderSearchAPIAdapterCitation]
    let limitations: [String]

    init(
        title: String,
        snippet: String,
        freshness: ProviderFreshness,
        citations: [ServerProviderSearchAPIAdapterCitation],
        limitations: [String] = []
    ) {
        self.title = Self.normalized(title, maxLength: 180)
        self.snippet = Self.normalized(snippet, maxLength: 360)
        self.freshness = freshness
        self.citations = citations
        self.limitations = limitations
            .map { Self.normalized($0, maxLength: 160) }
            .filter { $0.isEmpty == false }
    }

    var hasContent: Bool {
        title.isEmpty == false && snippet.isEmpty == false
    }

    private static func normalized(
        _ value: String,
        maxLength: Int
    ) -> String {
        let collapsed = value
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard collapsed.count > maxLength else {
            return collapsed
        }
        return String(collapsed.prefix(maxLength))
    }
}

struct ServerProviderSearchAPIAdapterResult: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let requestID: String
    let traceID: String
    let providerFamily: ProviderFamily
    let capability: ProviderCapability
    let costClass: ProviderCostClass
    let title: String
    let snippet: String
    let freshness: ProviderFreshness
    let citations: [ServerProviderSearchAPIAdapterCitation]
    let limitations: [String]
}

struct ServerProviderSearchAPIAdapterResultReceipt:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let state: ServerProviderSearchAPIAdapterResultState
    let statusLine: String
    let requestID: String
    let traceID: String?
    let providerFamily: ProviderFamily?
    let capability: ProviderCapability?
    let costClass: ProviderCostClass?
    let result: ServerProviderSearchAPIAdapterResult?
    let rejection: ServerProviderSearchAPIAdapterRejectionReason?

    var description: String {
        "ServerProviderSearchAPIAdapterResultReceipt(id: \(id), state: \(state.rawValue), rejection: \(rejection?.rawValue ?? "none"))"
    }
}

enum ServerProviderSearchAPIAdapterContract {
    static let maximumResultLimit = 10

    static func prepareRequest(
        envelope: ServerProviderEnvelope,
        connectorReceipt: ServerProviderRuntimeConnectorInvocationReceipt,
        query: ServerProviderSearchAPIAdapterQuery,
        resultLimit: Int = 5
    ) -> ServerProviderSearchAPIAdapterRequestDecision {
        if query.isValid == false {
            return rejected(envelope: envelope, reason: .emptyQuery)
        }
        guard (1...maximumResultLimit).contains(resultLimit) else {
            return rejected(envelope: envelope, reason: .invalidResultLimit)
        }
        guard envelope.providerFamily == .searchAPI else {
            return rejected(envelope: envelope, reason: .providerFamilyNotSearchAPI)
        }
        guard envelope.capability == .webSearch || envelope.capability == .localServiceSearch else {
            return rejected(envelope: envelope, reason: .unsupportedCapability)
        }
        guard envelope.privacyClass == .general else {
            return rejected(envelope: envelope, reason: .privacyBlocked)
        }

        let quotaSummary = ServerProviderSearchAPIAdapterQuotaSummary(
            providerFamily: envelope.providerFamily,
            membershipTier: envelope.membershipTier,
            costClass: envelope.costClass,
            entitlementPresent: envelope.meteredProviderEntitlements.contains(.searchAPI)
        )
        guard envelope.costClass.isSearchAPIAdapterAllowed else {
            return rejected(envelope: envelope, reason: .quotaBlocked)
        }
        guard quotaSummary.entitlementPresent else {
            return rejected(envelope: envelope, reason: .entitlementMissing)
        }

        let sourcePolicy = ServerProviderSearchAPIAdapterSourcePolicySnapshot(
            sourcePolicy: envelope.sourcePolicy
        )
        guard sourcePolicy.hasApprovedSourcePolicy else {
            return rejected(envelope: envelope, reason: .sourcePolicyInsufficient)
        }
        guard sourcePolicy.hasCitationPolicy else {
            return rejected(envelope: envelope, reason: .citationPolicyMissing)
        }
        guard connectorReceipt.state == .receiptPrepared else {
            return rejected(envelope: envelope, reason: .connectorReceiptRejected)
        }
        guard let connectorProviderFamily = connectorReceipt.providerFamily,
              let connectorCapability = connectorReceipt.capability,
              let connectorCostClass = connectorReceipt.costClass,
              let connectorFreshness = connectorReceipt.freshness,
              let connectorTraceID = connectorReceipt.traceID else {
            return rejected(envelope: envelope, reason: .connectorMetadataMissing)
        }
        guard connectorProviderFamily == .searchAPI else {
            return rejected(envelope: envelope, reason: .connectorProviderFamilyMismatch)
        }
        guard connectorCapability == envelope.capability else {
            return rejected(envelope: envelope, reason: .connectorCapabilityMismatch)
        }
        guard connectorTraceID == envelope.traceID else {
            return rejected(envelope: envelope, reason: .connectorTraceMismatch)
        }
        guard connectorCostClass == envelope.costClass else {
            return rejected(envelope: envelope, reason: .connectorCostMismatch)
        }
        guard connectorFreshness == envelope.freshness else {
            return rejected(envelope: envelope, reason: .connectorFreshnessMismatch)
        }

        let request = ServerProviderSearchAPIAdapterRequest(
            id: "search-api-adapter-request-\(safeID(envelope.traceID))-\(safeID(connectorReceipt.id))",
            traceID: envelope.traceID,
            envelopeTraceID: envelope.traceID,
            connectorReceiptID: connectorReceipt.id,
            connectorRequestID: connectorReceipt.requestID,
            providerFamily: .searchAPI,
            capability: envelope.capability,
            privacyClass: envelope.privacyClass,
            membershipTier: envelope.membershipTier,
            costClass: envelope.costClass,
            freshness: envelope.freshness,
            resultLimit: resultLimit,
            query: query,
            quotaSummary: quotaSummary,
            accessSummary: ServerProviderSearchAPIAdapterAccessSummary(
                membershipTier: envelope.membershipTier,
                privacyClass: envelope.privacyClass,
                providerFamily: envelope.providerFamily,
                capability: envelope.capability
            ),
            sourcePolicy: sourcePolicy
        )

        return ServerProviderSearchAPIAdapterRequestDecision(
            id: "search-api-adapter-request-decision-\(safeID(request.id))",
            state: .requestPrepared,
            statusLine: request.statusLine,
            request: request,
            rejection: nil
        )
    }

    static func normalizeResult(
        request: ServerProviderSearchAPIAdapterRequest,
        candidate: ServerProviderSearchAPIAdapterResultCandidate
    ) -> ServerProviderSearchAPIAdapterResultReceipt {
        guard candidate.hasContent else {
            return resultRejected(request: request, reason: .resultContentMissing)
        }
        guard candidate.citations.isEmpty == false,
              candidate.citations.allSatisfy(\.isValid) else {
            return resultRejected(request: request, reason: .resultCitationMissing)
        }
        if let requiredHost = request.sourcePolicy.sourceHost,
           requiredHost.isEmpty == false,
           candidate.citations.contains(where: { $0.sourceHost == requiredHost }) == false {
            return resultRejected(request: request, reason: .resultCitationSourceMismatch)
        }
        if request.freshness == .liveRequired,
           candidate.freshness == .cachedOK {
            return resultRejected(request: request, reason: .resultStaleForLiveRequired)
        }

        let result = ServerProviderSearchAPIAdapterResult(
            id: "search-api-adapter-result-\(safeID(request.id))",
            requestID: request.id,
            traceID: request.traceID,
            providerFamily: request.providerFamily,
            capability: request.capability,
            costClass: request.costClass,
            title: candidate.title,
            snippet: candidate.snippet,
            freshness: candidate.freshness,
            citations: candidate.citations,
            limitations: candidate.limitations
        )

        return ServerProviderSearchAPIAdapterResultReceipt(
            id: "search-api-adapter-result-receipt-\(safeID(result.id))",
            state: .resultNormalized,
            statusLine: "Search API adapter result is normalized from cited metadata only. No provider runtime has run.",
            requestID: request.id,
            traceID: request.traceID,
            providerFamily: request.providerFamily,
            capability: request.capability,
            costClass: request.costClass,
            result: result,
            rejection: nil
        )
    }

    private static func rejected(
        envelope: ServerProviderEnvelope,
        reason: ServerProviderSearchAPIAdapterRejectionReason
    ) -> ServerProviderSearchAPIAdapterRequestDecision {
        ServerProviderSearchAPIAdapterRequestDecision(
            id: "search-api-adapter-request-decision-\(safeID(envelope.traceID))-\(reason.rawValue)",
            state: .rejected,
            statusLine: "Search API adapter request is blocked by metadata policy: \(reason.rawValue). No provider runtime has run.",
            request: nil,
            rejection: reason
        )
    }

    private static func resultRejected(
        request: ServerProviderSearchAPIAdapterRequest,
        reason: ServerProviderSearchAPIAdapterRejectionReason
    ) -> ServerProviderSearchAPIAdapterResultReceipt {
        ServerProviderSearchAPIAdapterResultReceipt(
            id: "search-api-adapter-result-receipt-\(safeID(request.id))-\(reason.rawValue)",
            state: .rejected,
            statusLine: "Search API adapter result is blocked by metadata policy: \(reason.rawValue). No provider runtime has run.",
            requestID: request.id,
            traceID: nil,
            providerFamily: nil,
            capability: nil,
            costClass: nil,
            result: nil,
            rejection: reason
        )
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
        return slug.isEmpty ? "missing-search-api-id" : slug
    }
}

private extension ProviderCostClass {
    var isSearchAPIAdapterAllowed: Bool {
        switch self {
        case .includedQuota, .meteredPremium:
            return true
        case .freeLocal, .blockedByCost, .blockedByPrivacy, .blockedByTerms:
            return false
        }
    }
}
