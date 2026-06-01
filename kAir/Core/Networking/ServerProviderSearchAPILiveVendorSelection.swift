//
//  ServerProviderSearchAPILiveVendorSelection.swift
//  kAir
//
//  Value-only Search API live vendor selection policy. This file ranks and
//  rejects candidate metadata before any future provider runtime can exist.
//

import Foundation

enum ServerProviderSearchAPILiveVendorCostUnit:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case request
    case result
    case searchQuery
    case contextBlock
    case citationToken
}

enum ServerProviderSearchAPILiveVendorQuotaClass:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case includedQuota
    case metered
    case enterpriseMetered
    case unavailable
}

enum ServerProviderSearchAPILiveVendorQPSClass:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case low
    case standard
    case high
    case unavailable
}

enum ServerProviderSearchAPILiveVendorLatencyClass:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case interactive
    case balanced
    case batch
}

enum ServerProviderSearchAPILiveVendorDisabledReason:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case vendorPaused
    case policyReviewRequired
    case quotaContractMissing
}

enum ServerProviderSearchAPILiveVendorSelectionRejectionReason:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case candidateListEmpty
    case duplicateCandidateID
    case vendorDisabled
    case providerFamilyMismatch
    case unsupportedCapability
    case privacyBlocked
    case membershipTierTooLow
    case providerDisabled
    case providerNotAllowed
    case entitlementMissing
    case includedQuotaExhausted
    case meteredEligibilityMissing
    case unsupportedCostClass
    case costClassMismatch
    case quotaUnavailable
    case qpsUnavailable
    case unsupportedFreshness
    case unsupportedResultShape
    case citationSupportMissing
    case sourceSupportMissing
    case attributionSupportMissing
    case pageBodyPolicyMismatch
    case retentionConflict
    case unsupportedRegion
    case unitPriceTooHigh
    case missingUserFacingPurpose
    case noEligibleCandidate
}

enum ServerProviderSearchAPILiveVendorSelectionState:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case selected
    case rejected
}

struct ServerProviderSearchAPILiveVendorCandidate:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let displayName: String
    let providerFamily: ProviderFamily
    let capability: ProviderCapability
    let costClass: ProviderCostClass
    let supportedResultShapes: Set<ServerProviderSearchAPIVendorResultShape>
    let supportedFreshness: Set<ProviderFreshness>
    let citationSupport: ServerProviderSearchAPIVendorCitationSupport
    let pageBodyMode: ServerProviderSearchAPIVendorPageBodyMode
    let requiredRetention: ServerProviderSearchAPIRetentionLevel
    let costUnit: ServerProviderSearchAPILiveVendorCostUnit
    let estimatedUnitMicros: Int
    let currencyCode: String
    let quotaClass: ServerProviderSearchAPILiveVendorQuotaClass
    let qpsClass: ServerProviderSearchAPILiveVendorQPSClass
    let allowedRegions: Set<ProviderRegion>
    let latencyClass: ServerProviderSearchAPILiveVendorLatencyClass
    let supportsAnswerGeneration: Bool
    let minimumMembershipTier: MembershipTier
    let isEnabled: Bool
    let disabledReason: ServerProviderSearchAPILiveVendorDisabledReason?

    init(
        id: String,
        displayName: String,
        providerFamily: ProviderFamily = .searchAPI,
        capability: ProviderCapability,
        costClass: ProviderCostClass,
        supportedResultShapes: Set<ServerProviderSearchAPIVendorResultShape>,
        supportedFreshness: Set<ProviderFreshness>,
        citationSupport: ServerProviderSearchAPIVendorCitationSupport,
        pageBodyMode: ServerProviderSearchAPIVendorPageBodyMode,
        requiredRetention: ServerProviderSearchAPIRetentionLevel,
        costUnit: ServerProviderSearchAPILiveVendorCostUnit,
        estimatedUnitMicros: Int,
        currencyCode: String = "usd",
        quotaClass: ServerProviderSearchAPILiveVendorQuotaClass,
        qpsClass: ServerProviderSearchAPILiveVendorQPSClass,
        allowedRegions: Set<ProviderRegion>,
        latencyClass: ServerProviderSearchAPILiveVendorLatencyClass,
        supportsAnswerGeneration: Bool,
        minimumMembershipTier: MembershipTier = .plus,
        isEnabled: Bool = true,
        disabledReason: ServerProviderSearchAPILiveVendorDisabledReason? = nil
    ) {
        self.id = Self.safeID(id)
        self.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.providerFamily = providerFamily
        self.capability = capability
        self.costClass = costClass
        self.supportedResultShapes = supportedResultShapes
        self.supportedFreshness = supportedFreshness
        self.citationSupport = citationSupport
        self.pageBodyMode = pageBodyMode
        self.requiredRetention = requiredRetention
        self.costUnit = costUnit
        self.estimatedUnitMicros = max(0, estimatedUnitMicros)
        self.currencyCode = currencyCode.lowercased()
        self.quotaClass = quotaClass
        self.qpsClass = qpsClass
        self.allowedRegions = allowedRegions
        self.latencyClass = latencyClass
        self.supportsAnswerGeneration = supportsAnswerGeneration
        self.minimumMembershipTier = minimumMembershipTier
        self.isEnabled = isEnabled
        self.disabledReason = disabledReason
    }

    var description: String {
        "SearchAPILiveVendorCandidate(id: \(id), costClass: \(costClass.rawValue), unit: \(costUnit.rawValue))"
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
        return slug.isEmpty ? "search-api-live-vendor" : slug
    }
}

struct ServerProviderSearchAPILiveVendorSelectionRequest:
    Codable,
    Hashable,
    Sendable
{
    let desiredCapability: ProviderCapability
    let resultShape: ServerProviderSearchAPIVendorResultShape
    let freshness: ProviderFreshness
    let privacyClass: ProviderPrivacyClass
    let costClass: ProviderCostClass
    let membershipTier: MembershipTier
    let region: ProviderRegion
    let citationRequired: Bool
    let sourceHostRequired: Bool
    let attributionRequired: Bool
    let pageBodyRequirement: ServerProviderSearchAPIPageBodyRequirement
    let allowedRetention: ServerProviderSearchAPIRetentionLevel
    let maxUnitMicros: Int
    let quotaSnapshot: ServerProviderQuotaSnapshot
    let userFacingPurpose: String

    init(
        desiredCapability: ProviderCapability,
        resultShape: ServerProviderSearchAPIVendorResultShape,
        freshness: ProviderFreshness,
        privacyClass: ProviderPrivacyClass = .general,
        costClass: ProviderCostClass,
        membershipTier: MembershipTier,
        region: ProviderRegion,
        citationRequired: Bool = true,
        sourceHostRequired: Bool = true,
        attributionRequired: Bool = true,
        pageBodyRequirement: ServerProviderSearchAPIPageBodyRequirement = .snippetsOnly,
        allowedRetention: ServerProviderSearchAPIRetentionLevel = .ephemeralOnly,
        maxUnitMicros: Int,
        quotaSnapshot: ServerProviderQuotaSnapshot,
        userFacingPurpose: String
    ) {
        self.desiredCapability = desiredCapability
        self.resultShape = resultShape
        self.freshness = freshness
        self.privacyClass = privacyClass
        self.costClass = costClass
        self.membershipTier = membershipTier
        self.region = region
        self.citationRequired = citationRequired
        self.sourceHostRequired = sourceHostRequired
        self.attributionRequired = attributionRequired
        self.pageBodyRequirement = pageBodyRequirement
        self.allowedRetention = allowedRetention
        self.maxUnitMicros = max(0, maxUnitMicros)
        self.quotaSnapshot = quotaSnapshot
        self.userFacingPurpose = userFacingPurpose
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct ServerProviderSearchAPILiveVendorCandidateSummary:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let displayName: String
    let costClass: ProviderCostClass
    let costUnit: ServerProviderSearchAPILiveVendorCostUnit
    let estimatedUnitMicros: Int
    let currencyCode: String
    let quotaClass: ServerProviderSearchAPILiveVendorQuotaClass
    let qpsClass: ServerProviderSearchAPILiveVendorQPSClass
    let latencyClass: ServerProviderSearchAPILiveVendorLatencyClass
    let supportsAnswerGeneration: Bool
    let isEligible: Bool
    let rejectionReasons: [ServerProviderSearchAPILiveVendorSelectionRejectionReason]

    var description: String {
        "SearchAPILiveVendorCandidateSummary(id: \(id), eligible: \(isEligible), reasons: \(rejectionReasons.map(\.rawValue).joined(separator: ",")))"
    }
}

struct ServerProviderSearchAPILiveVendorSelectionSafeCopy:
    Codable,
    Hashable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let state: ServerProviderSearchAPILiveVendorSelectionState
    let selectedCandidateID: String?
    let candidateSummaries: [ServerProviderSearchAPILiveVendorCandidateSummary]
    let rejectionReasons: [ServerProviderSearchAPILiveVendorSelectionRejectionReason]
    let duplicateCandidateIDs: [String]
    let statusLine: String

    var description: String {
        "SearchAPILiveVendorSelectionSafeCopy(id: \(id), state: \(state.rawValue), selected: \(selectedCandidateID ?? "none"))"
    }
}

struct ServerProviderSearchAPILiveVendorSelectionDecision:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let state: ServerProviderSearchAPILiveVendorSelectionState
    let selectedCandidateID: String?
    let candidateSummaries: [ServerProviderSearchAPILiveVendorCandidateSummary]
    let rejectionReasons: [ServerProviderSearchAPILiveVendorSelectionRejectionReason]
    let duplicateCandidateIDs: [String]
    let statusLine: String

    var isSelected: Bool {
        state == .selected && selectedCandidateID != nil
    }

    var safeCopy: ServerProviderSearchAPILiveVendorSelectionSafeCopy {
        ServerProviderSearchAPILiveVendorSelectionSafeCopy(
            id: id,
            state: state,
            selectedCandidateID: selectedCandidateID,
            candidateSummaries: candidateSummaries,
            rejectionReasons: rejectionReasons,
            duplicateCandidateIDs: duplicateCandidateIDs,
            statusLine: statusLine
        )
    }

    var description: String {
        "SearchAPILiveVendorSelectionDecision(id: \(id), state: \(state.rawValue), selected: \(selectedCandidateID ?? "none"), reasons: \(rejectionReasons.map(\.rawValue).joined(separator: ",")))"
    }
}

enum ServerProviderSearchAPILiveVendorSelection {
    static func evaluate(
        request: ServerProviderSearchAPILiveVendorSelectionRequest,
        candidates: [ServerProviderSearchAPILiveVendorCandidate]
    ) -> ServerProviderSearchAPILiveVendorSelectionDecision {
        guard candidates.isEmpty == false else {
            return rejected(
                summaries: [],
                reasons: [.candidateListEmpty],
                duplicateCandidateIDs: []
            )
        }

        let (orderedCandidates, duplicateIDs) = firstWinsCandidates(candidates)
        let summaries = orderedCandidates.map { candidate in
            summary(for: candidate, request: request)
        }

        if let selected = summaries.first(where: \.isEligible) {
            return ServerProviderSearchAPILiveVendorSelectionDecision(
                id: "search-api-live-vendor-selection-\(selected.id)-selected",
                state: .selected,
                selectedCandidateID: selected.id,
                candidateSummaries: summaries,
                rejectionReasons: [],
                duplicateCandidateIDs: duplicateIDs,
                statusLine: "Search API live vendor candidate is selected from policy metadata only. No transport or provider runtime has run."
            )
        }

        return rejected(
            summaries: summaries,
            reasons: aggregateRejectionReasons(
                from: summaries,
                duplicateCandidateIDs: duplicateIDs
            ),
            duplicateCandidateIDs: duplicateIDs
        )
    }

    private static func firstWinsCandidates(
        _ candidates: [ServerProviderSearchAPILiveVendorCandidate]
    ) -> (
        ordered: [ServerProviderSearchAPILiveVendorCandidate],
        duplicateIDs: [String]
    ) {
        var seen: Set<String> = []
        var duplicateIDs: [String] = []
        var ordered: [ServerProviderSearchAPILiveVendorCandidate] = []

        for candidate in candidates {
            if seen.contains(candidate.id) {
                if duplicateIDs.contains(candidate.id) == false {
                    duplicateIDs.append(candidate.id)
                }
                continue
            }
            seen.insert(candidate.id)
            ordered.append(candidate)
        }

        return (ordered, duplicateIDs)
    }

    private static func summary(
        for candidate: ServerProviderSearchAPILiveVendorCandidate,
        request: ServerProviderSearchAPILiveVendorSelectionRequest
    ) -> ServerProviderSearchAPILiveVendorCandidateSummary {
        let reasons = rejectionReasons(for: candidate, request: request)
        return ServerProviderSearchAPILiveVendorCandidateSummary(
            id: candidate.id,
            displayName: candidate.displayName,
            costClass: candidate.costClass,
            costUnit: candidate.costUnit,
            estimatedUnitMicros: candidate.estimatedUnitMicros,
            currencyCode: candidate.currencyCode,
            quotaClass: candidate.quotaClass,
            qpsClass: candidate.qpsClass,
            latencyClass: candidate.latencyClass,
            supportsAnswerGeneration: candidate.supportsAnswerGeneration,
            isEligible: reasons.isEmpty,
            rejectionReasons: reasons
        )
    }

    private static func rejectionReasons(
        for candidate: ServerProviderSearchAPILiveVendorCandidate,
        request: ServerProviderSearchAPILiveVendorSelectionRequest
    ) -> [ServerProviderSearchAPILiveVendorSelectionRejectionReason] {
        var reasons: [ServerProviderSearchAPILiveVendorSelectionRejectionReason] = []

        if request.userFacingPurpose.isEmpty {
            reasons.append(.missingUserFacingPurpose)
        }
        if candidate.isEnabled == false {
            reasons.append(.vendorDisabled)
        }
        if candidate.providerFamily != .searchAPI {
            reasons.append(.providerFamilyMismatch)
        }
        if candidate.capability != request.desiredCapability
            || [.webSearch, .localServiceSearch].contains(request.desiredCapability) == false {
            reasons.append(.unsupportedCapability)
        }
        if request.privacyClass.allowsRemoteProvider == false {
            reasons.append(.privacyBlocked)
        }
        if request.membershipTier < candidate.minimumMembershipTier {
            reasons.append(.membershipTierTooLow)
        }
        if candidate.costClass != request.costClass {
            reasons.append(.costClassMismatch)
        }
        if candidate.quotaClass == .unavailable {
            reasons.append(.quotaUnavailable)
        }
        if candidate.qpsClass == .unavailable {
            reasons.append(.qpsUnavailable)
        }
        if let quotaReason = quotaRejection(
            candidate: candidate,
            request: request
        ) {
            reasons.append(quotaReason)
        }
        if candidate.supportedFreshness.contains(request.freshness) == false {
            reasons.append(.unsupportedFreshness)
        }
        if candidate.supportedResultShapes.contains(request.resultShape) == false {
            reasons.append(.unsupportedResultShape)
        }
        if request.citationRequired,
           candidate.citationSupport.supportsCitations == false {
            reasons.append(.citationSupportMissing)
        }
        if request.sourceHostRequired,
           candidate.citationSupport.supportsSourceHost == false {
            reasons.append(.sourceSupportMissing)
        }
        if request.attributionRequired,
           candidate.citationSupport.supportsAttribution == false {
            reasons.append(.attributionSupportMissing)
        }
        if pageBodyPolicyMatches(candidate: candidate, request: request) == false {
            reasons.append(.pageBodyPolicyMismatch)
        }
        if candidate.requiredRetention > request.allowedRetention {
            reasons.append(.retentionConflict)
        }
        if regionMatches(candidate: candidate, request: request) == false {
            reasons.append(.unsupportedRegion)
        }
        if candidate.estimatedUnitMicros > request.maxUnitMicros {
            reasons.append(.unitPriceTooHigh)
        }

        return reasons
    }

    private static func quotaRejection(
        candidate: ServerProviderSearchAPILiveVendorCandidate,
        request: ServerProviderSearchAPILiveVendorSelectionRequest
    ) -> ServerProviderSearchAPILiveVendorSelectionRejectionReason? {
        let quotaSnapshot = request.quotaSnapshot
        if quotaSnapshot.disabledProviderFamilies.contains(.searchAPI) {
            return .providerDisabled
        }
        guard quotaSnapshot.allowedProviderFamilies.contains(.searchAPI) else {
            return .providerNotAllowed
        }
        guard quotaSnapshot.entitledProviderFamilies.contains(.searchAPI) else {
            return .entitlementMissing
        }

        switch candidate.costClass {
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

    private static func pageBodyPolicyMatches(
        candidate: ServerProviderSearchAPILiveVendorCandidate,
        request: ServerProviderSearchAPILiveVendorSelectionRequest
    ) -> Bool {
        switch (request.pageBodyRequirement, candidate.pageBodyMode) {
        case (.snippetsOnly, .required):
            return false
        case (.required, .unavailable):
            return false
        case (.snippetsOnly, _),
             (.optional, _),
             (.required, .optional),
             (.required, .required):
            return true
        }
    }

    private static func regionMatches(
        candidate: ServerProviderSearchAPILiveVendorCandidate,
        request: ServerProviderSearchAPILiveVendorSelectionRequest
    ) -> Bool {
        candidate.allowedRegions.contains(.global)
            || candidate.allowedRegions.contains(request.region)
    }

    private static func aggregateRejectionReasons(
        from summaries: [ServerProviderSearchAPILiveVendorCandidateSummary],
        duplicateCandidateIDs: [String]
    ) -> [ServerProviderSearchAPILiveVendorSelectionRejectionReason] {
        var reasons: [ServerProviderSearchAPILiveVendorSelectionRejectionReason] = [
            .noEligibleCandidate,
        ]
        if duplicateCandidateIDs.isEmpty == false {
            reasons.append(.duplicateCandidateID)
        }
        for summary in summaries {
            for reason in summary.rejectionReasons where reasons.contains(reason) == false {
                reasons.append(reason)
            }
        }
        return reasons
    }

    private static func rejected(
        summaries: [ServerProviderSearchAPILiveVendorCandidateSummary],
        reasons: [ServerProviderSearchAPILiveVendorSelectionRejectionReason],
        duplicateCandidateIDs: [String]
    ) -> ServerProviderSearchAPILiveVendorSelectionDecision {
        ServerProviderSearchAPILiveVendorSelectionDecision(
            id: "search-api-live-vendor-selection-rejected-\(reasons.first?.rawValue ?? "unknown")",
            state: .rejected,
            selectedCandidateID: nil,
            candidateSummaries: summaries,
            rejectionReasons: reasons,
            duplicateCandidateIDs: duplicateCandidateIDs,
            statusLine: "Search API live vendor candidate selection is blocked by metadata policy: \(reasons.first?.rawValue ?? "unknown"). No transport or provider runtime has run."
        )
    }
}
