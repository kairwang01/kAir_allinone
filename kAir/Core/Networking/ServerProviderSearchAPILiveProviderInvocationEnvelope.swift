//
//  ServerProviderSearchAPILiveProviderInvocationEnvelope.swift
//  kAir
//
//  A165 metadata-only Search API provider invocation envelope proof. This file
//  packages an accepted preflight into a prepared attempt shape while keeping
//  the remote provider path disabled.
//

import Foundation

enum ServerProviderSearchAPILiveProviderInvocationEnvelopeState:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case prepared
    case rejected
}

enum ServerProviderSearchAPILiveProviderInvocationEnvelopeRedactionPolicy:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case statusOnly
    case sourceCitationMetadataOnly
    case unsafeUnredactedMaterial
}

enum ServerProviderSearchAPILiveProviderInvocationEnvelopeRejectionReason:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case preflightNotAccepted
    case staleOrExpiredPreflight
    case vendorOrAdapterMismatch
    case providerFamilyMismatch
    case unsupportedProviderFamily
    case capabilityMismatch
    case resultShapeMismatch
    case freshnessMismatch
    case searchContextMismatch
    case pageContentPolicyMismatch
    case missingBudgetSnapshot
    case budgetSnapshotMismatch
    case costUnitMismatch
    case missingLeaseRequestOrAuditID
    case leaseRequestOrAuditMismatch
    case duplicateEnvelopeID
    case unsafeSourceOrRetentionPolicy
    case unsafeRedactionPolicy
    case unsupportedRegion
    case quotaRateUnavailable
    case serverSecretModeNotServerOwned
    case runtimeCallableFlagTrue
    case executableFlagTrue
    case unsafeCommerceMaterialPresent
    case unredactedSourceMaterialPresent
    case hiddenAppControlMaterialPresent
}

struct ServerProviderSearchAPILiveProviderInvocationEnvelopeInput:
    Codable,
    Hashable,
    Sendable
{
    let envelopeID: String
    let preflightID: String
    let preflightDecision: ServerProviderSearchAPILiveProviderInvocationPreflightDecision
    let selectedAdapterID: String
    let selectedVendorDecisionID: String
    let selectedVendorID: String
    let providerFamily: ProviderFamily
    let capability: ProviderCapability
    let resultShape: ServerProviderSearchAPIVendorResultShape
    let freshness: ProviderFreshness
    let searchContextClass: ServerProviderSearchAPILiveTransportAdapterSearchContextClass
    let pageContentRequirement: ServerProviderSearchAPIPageBodyRequirement
    let retentionClass: ServerProviderSearchAPIRetentionLevel
    let sourceState: ServerSourcePolicyState
    let citationRequired: Bool
    let sourceHostRequired: Bool
    let attributionRequired: Bool
    let region: ProviderRegion
    let membershipTier: MembershipTier
    let budgetSnapshotID: String
    let costUnit: ServerProviderSearchAPILiveVendorCostUnit
    let quotaRateClass: ServerProviderSearchAPILiveVendorQPSClass
    let transportLeaseID: String
    let transportRequestID: String
    let auditTraceID: String
    let serverSecretMode: ServerProviderSearchAPILiveTransportAdapterSecretMode
    let issuedAt: Date
    let preflightExpiresAt: Date
    let envelopeExpiresAt: Date
    let redactionPolicy: ServerProviderSearchAPILiveProviderInvocationEnvelopeRedactionPolicy
    let userFacingPurpose: String
    let runtimeCallableFlag: Bool
    let executableFlag: Bool
    let containsUnsafeCommerceMaterial: Bool
    let containsUnredactedSourceMaterial: Bool
    let containsHiddenAppControlMaterial: Bool

    init(
        envelopeID: String,
        preflightID: String,
        preflightDecision: ServerProviderSearchAPILiveProviderInvocationPreflightDecision,
        selectedAdapterID: String,
        selectedVendorDecisionID: String,
        selectedVendorID: String,
        providerFamily: ProviderFamily = .searchAPI,
        capability: ProviderCapability = .webSearch,
        resultShape: ServerProviderSearchAPIVendorResultShape,
        freshness: ProviderFreshness,
        searchContextClass: ServerProviderSearchAPILiveTransportAdapterSearchContextClass,
        pageContentRequirement: ServerProviderSearchAPIPageBodyRequirement,
        retentionClass: ServerProviderSearchAPIRetentionLevel,
        sourceState: ServerSourcePolicyState = .passed,
        citationRequired: Bool = true,
        sourceHostRequired: Bool = true,
        attributionRequired: Bool = true,
        region: ProviderRegion,
        membershipTier: MembershipTier,
        budgetSnapshotID: String,
        costUnit: ServerProviderSearchAPILiveVendorCostUnit,
        quotaRateClass: ServerProviderSearchAPILiveVendorQPSClass = .standard,
        transportLeaseID: String,
        transportRequestID: String,
        auditTraceID: String,
        serverSecretMode: ServerProviderSearchAPILiveTransportAdapterSecretMode = .serverOwned,
        issuedAt: Date,
        preflightExpiresAt: Date,
        envelopeExpiresAt: Date,
        redactionPolicy: ServerProviderSearchAPILiveProviderInvocationEnvelopeRedactionPolicy = .sourceCitationMetadataOnly,
        userFacingPurpose: String,
        runtimeCallableFlag: Bool = false,
        executableFlag: Bool = false,
        containsUnsafeCommerceMaterial: Bool = false,
        containsUnredactedSourceMaterial: Bool = false,
        containsHiddenAppControlMaterial: Bool = false
    ) {
        self.envelopeID = Self.safeID(envelopeID, fallback: "search-api-live-provider-invocation-envelope")
        self.preflightID = Self.safeID(preflightID, fallback: "search-api-live-provider-preflight")
        self.preflightDecision = preflightDecision
        self.selectedAdapterID = Self.safeID(selectedAdapterID, fallback: "search-api-live-adapter")
        self.selectedVendorDecisionID = selectedVendorDecisionID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.selectedVendorID = Self.safeID(selectedVendorID, fallback: "search-api-live-vendor")
        self.providerFamily = providerFamily
        self.capability = capability
        self.resultShape = resultShape
        self.freshness = freshness
        self.searchContextClass = searchContextClass
        self.pageContentRequirement = pageContentRequirement
        self.retentionClass = retentionClass
        self.sourceState = sourceState
        self.citationRequired = citationRequired
        self.sourceHostRequired = sourceHostRequired
        self.attributionRequired = attributionRequired
        self.region = region
        self.membershipTier = membershipTier
        self.budgetSnapshotID = budgetSnapshotID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.costUnit = costUnit
        self.quotaRateClass = quotaRateClass
        self.transportLeaseID = transportLeaseID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.transportRequestID = transportRequestID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.auditTraceID = auditTraceID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.serverSecretMode = serverSecretMode
        self.issuedAt = issuedAt
        self.preflightExpiresAt = preflightExpiresAt
        self.envelopeExpiresAt = envelopeExpiresAt
        self.redactionPolicy = redactionPolicy
        self.userFacingPurpose = userFacingPurpose.trimmingCharacters(in: .whitespacesAndNewlines)
        self.runtimeCallableFlag = runtimeCallableFlag
        self.executableFlag = executableFlag
        self.containsUnsafeCommerceMaterial = containsUnsafeCommerceMaterial
        self.containsUnredactedSourceMaterial = containsUnredactedSourceMaterial
        self.containsHiddenAppControlMaterial = containsHiddenAppControlMaterial
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
}

struct ServerProviderSearchAPILiveProviderInvocationEnvelopeSummary:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let preflightID: String
    let selectedAdapterID: String
    let selectedVendorDecisionID: String
    let selectedVendorID: String
    let providerFamily: ProviderFamily
    let capability: ProviderCapability
    let resultShape: ServerProviderSearchAPIVendorResultShape
    let freshness: ProviderFreshness
    let searchContextClass: ServerProviderSearchAPILiveTransportAdapterSearchContextClass
    let pageContentRequirement: ServerProviderSearchAPIPageBodyRequirement
    let retentionClass: ServerProviderSearchAPIRetentionLevel
    let sourceState: ServerSourcePolicyState
    let citationRequired: Bool
    let sourceHostRequired: Bool
    let attributionRequired: Bool
    let region: ProviderRegion
    let membershipTier: MembershipTier
    let budgetSnapshotID: String
    let costUnit: ServerProviderSearchAPILiveVendorCostUnit
    let quotaRateClass: ServerProviderSearchAPILiveVendorQPSClass
    let transportLeaseID: String
    let transportRequestID: String
    let auditTraceID: String
    let serverSecretMode: ServerProviderSearchAPILiveTransportAdapterSecretMode
    let expiresAt: Date
    let redactionPolicy: ServerProviderSearchAPILiveProviderInvocationEnvelopeRedactionPolicy
    let userFacingPurpose: String

    var description: String {
        "SearchAPILiveProviderInvocationEnvelopeSummary(id: \(id), preflight: \(preflightID), vendor: \(selectedVendorID))"
    }
}

struct ServerProviderSearchAPILiveProviderInvocationEnvelopeSafeCopy:
    Codable,
    Hashable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let state: ServerProviderSearchAPILiveProviderInvocationEnvelopeState
    let summary: ServerProviderSearchAPILiveProviderInvocationEnvelopeSummary?
    let rejectionReasons: [ServerProviderSearchAPILiveProviderInvocationEnvelopeRejectionReason]
    let statusLine: String
    let isRuntimeCallable: Bool
    let isExecutable: Bool

    var description: String {
        "SearchAPILiveProviderInvocationEnvelopeSafeCopy(id: \(id), state: \(state.rawValue), preparedOnly: \(isRuntimeCallable == false && isExecutable == false))"
    }
}

struct ServerProviderSearchAPILiveProviderInvocationEnvelopeDecision:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let state: ServerProviderSearchAPILiveProviderInvocationEnvelopeState
    let summary: ServerProviderSearchAPILiveProviderInvocationEnvelopeSummary?
    let rejectionReasons: [ServerProviderSearchAPILiveProviderInvocationEnvelopeRejectionReason]
    let statusLine: String

    var isPrepared: Bool {
        state == .prepared && summary != nil && rejectionReasons.isEmpty
    }

    var isRuntimeCallable: Bool {
        false
    }

    var isExecutable: Bool {
        false
    }

    var safeCopy: ServerProviderSearchAPILiveProviderInvocationEnvelopeSafeCopy {
        ServerProviderSearchAPILiveProviderInvocationEnvelopeSafeCopy(
            id: id,
            state: state,
            summary: summary,
            rejectionReasons: rejectionReasons,
            statusLine: statusLine,
            isRuntimeCallable: isRuntimeCallable,
            isExecutable: isExecutable
        )
    }

    var description: String {
        "SearchAPILiveProviderInvocationEnvelopeDecision(id: \(id), state: \(state.rawValue), preparedOnly: \(isPrepared))"
    }
}

enum ServerProviderSearchAPILiveProviderInvocationEnvelope {
    static func evaluate(
        input: ServerProviderSearchAPILiveProviderInvocationEnvelopeInput,
        existingEnvelopeIDs: Set<String> = []
    ) -> ServerProviderSearchAPILiveProviderInvocationEnvelopeDecision {
        let summary = envelopeSummary(for: input)
        let reasons = rejectionReasons(
            for: input,
            preflightSummary: input.preflightDecision.summary,
            existingEnvelopeIDs: existingEnvelopeIDs
        )

        if reasons.isEmpty, let summary {
            return ServerProviderSearchAPILiveProviderInvocationEnvelopeDecision(
                id: "search-api-live-provider-invocation-envelope-\(input.envelopeID)-prepared",
                state: .prepared,
                summary: summary,
                rejectionReasons: [],
                statusLine: "Search API invocation envelope is prepared from metadata only; provider path remains disabled."
            )
        }

        let stableReasons = deduplicated(reasons)
        return ServerProviderSearchAPILiveProviderInvocationEnvelopeDecision(
            id: "search-api-live-provider-invocation-envelope-\(input.envelopeID)-rejected-\(stableReasons.first?.rawValue ?? "unknown")",
            state: .rejected,
            summary: summary,
            rejectionReasons: stableReasons,
            statusLine: "Search API invocation envelope is blocked by envelope policy: \(stableReasons.first?.rawValue ?? "unknown"); provider path remains disabled."
        )
    }

    private static func rejectionReasons(
        for input: ServerProviderSearchAPILiveProviderInvocationEnvelopeInput,
        preflightSummary: ServerProviderSearchAPILiveProviderInvocationPreflightSummary?,
        existingEnvelopeIDs: Set<String>
    ) -> [ServerProviderSearchAPILiveProviderInvocationEnvelopeRejectionReason] {
        var reasons: [ServerProviderSearchAPILiveProviderInvocationEnvelopeRejectionReason] = []

        if existingEnvelopeIDs.contains(input.envelopeID) {
            reasons.append(.duplicateEnvelopeID)
        }
        if input.preflightDecision.isAccepted == false {
            reasons.append(.preflightNotAccepted)
        }
        if input.preflightExpiresAt <= input.issuedAt || input.envelopeExpiresAt <= input.issuedAt {
            reasons.append(.staleOrExpiredPreflight)
        }
        if input.providerFamily != .searchAPI {
            reasons.append(.unsupportedProviderFamily)
        }
        if input.budgetSnapshotID.isEmpty {
            reasons.append(.missingBudgetSnapshot)
        }
        if [input.transportLeaseID, input.transportRequestID, input.auditTraceID]
            .contains(where: \.isEmpty) {
            reasons.append(.missingLeaseRequestOrAuditID)
        }
        if input.quotaRateClass == .unavailable {
            reasons.append(.quotaRateUnavailable)
        }
        if input.sourceState != .passed
            || input.citationRequired == false
            || input.sourceHostRequired == false
            || input.attributionRequired == false {
            reasons.append(.unsafeSourceOrRetentionPolicy)
        }
        if input.redactionPolicy == .unsafeUnredactedMaterial {
            reasons.append(.unsafeRedactionPolicy)
        }
        if input.serverSecretMode != .serverOwned {
            reasons.append(.serverSecretModeNotServerOwned)
        }
        if input.runtimeCallableFlag || input.preflightDecision.isRuntimeCallable {
            reasons.append(.runtimeCallableFlagTrue)
        }
        if input.executableFlag {
            reasons.append(.executableFlagTrue)
        }
        if input.containsUnsafeCommerceMaterial {
            reasons.append(.unsafeCommerceMaterialPresent)
        }
        if input.containsUnredactedSourceMaterial {
            reasons.append(.unredactedSourceMaterialPresent)
        }
        if input.containsHiddenAppControlMaterial {
            reasons.append(.hiddenAppControlMaterialPresent)
        }

        guard let preflightSummary else {
            return deduplicated(reasons)
        }

        if preflightSummary.id != input.preflightID {
            reasons.append(.staleOrExpiredPreflight)
        }
        if preflightSummary.selectedDescriptorID != input.selectedAdapterID
            || preflightSummary.selectedVendorDecisionID != input.selectedVendorDecisionID
            || preflightSummary.selectedVendorID != input.selectedVendorID {
            reasons.append(.vendorOrAdapterMismatch)
        }
        if preflightSummary.providerFamily != input.providerFamily {
            reasons.append(.providerFamilyMismatch)
        }
        if preflightSummary.capability != input.capability {
            reasons.append(.capabilityMismatch)
        }
        if preflightSummary.resultShape != input.resultShape {
            reasons.append(.resultShapeMismatch)
        }
        if preflightSummary.freshness != input.freshness {
            reasons.append(.freshnessMismatch)
        }
        if preflightSummary.searchContextClass != input.searchContextClass {
            reasons.append(.searchContextMismatch)
        }
        if preflightSummary.pageContentRequirement != input.pageContentRequirement {
            reasons.append(.pageContentPolicyMismatch)
        }
        if preflightSummary.retentionClass < input.retentionClass
            || preflightSummary.sourceState != input.sourceState
            || preflightSummary.citationRequired != input.citationRequired
            || preflightSummary.sourceHostRequired != input.sourceHostRequired
            || preflightSummary.attributionRequired != input.attributionRequired {
            reasons.append(.unsafeSourceOrRetentionPolicy)
        }
        if preflightSummary.region != .global && preflightSummary.region != input.region {
            reasons.append(.unsupportedRegion)
        }
        if preflightSummary.membershipTier != input.membershipTier {
            reasons.append(.budgetSnapshotMismatch)
        }
        if preflightSummary.budgetSnapshotID != input.budgetSnapshotID {
            reasons.append(.budgetSnapshotMismatch)
        }
        if preflightSummary.costUnit != input.costUnit {
            reasons.append(.costUnitMismatch)
        }
        if preflightSummary.leaseID != input.transportLeaseID
            || preflightSummary.transportRequestID != input.transportRequestID
            || preflightSummary.auditTraceID != input.auditTraceID {
            reasons.append(.leaseRequestOrAuditMismatch)
        }

        return deduplicated(reasons)
    }

    private static func envelopeSummary(
        for input: ServerProviderSearchAPILiveProviderInvocationEnvelopeInput
    ) -> ServerProviderSearchAPILiveProviderInvocationEnvelopeSummary? {
        guard input.preflightDecision.summary != nil else {
            return nil
        }
        return ServerProviderSearchAPILiveProviderInvocationEnvelopeSummary(
            id: input.envelopeID,
            preflightID: input.preflightID,
            selectedAdapterID: input.selectedAdapterID,
            selectedVendorDecisionID: input.selectedVendorDecisionID,
            selectedVendorID: input.selectedVendorID,
            providerFamily: input.providerFamily,
            capability: input.capability,
            resultShape: input.resultShape,
            freshness: input.freshness,
            searchContextClass: input.searchContextClass,
            pageContentRequirement: input.pageContentRequirement,
            retentionClass: input.retentionClass,
            sourceState: input.sourceState,
            citationRequired: input.citationRequired,
            sourceHostRequired: input.sourceHostRequired,
            attributionRequired: input.attributionRequired,
            region: input.region,
            membershipTier: input.membershipTier,
            budgetSnapshotID: input.budgetSnapshotID,
            costUnit: input.costUnit,
            quotaRateClass: input.quotaRateClass,
            transportLeaseID: input.transportLeaseID,
            transportRequestID: input.transportRequestID,
            auditTraceID: input.auditTraceID,
            serverSecretMode: input.serverSecretMode,
            expiresAt: input.envelopeExpiresAt,
            redactionPolicy: input.redactionPolicy,
            userFacingPurpose: input.userFacingPurpose
        )
    }

    private static func deduplicated<T: Hashable>(_ values: [T]) -> [T] {
        var seen: Set<T> = []
        var result: [T] = []
        for value in values where seen.insert(value).inserted {
            result.append(value)
        }
        return result
    }
}
