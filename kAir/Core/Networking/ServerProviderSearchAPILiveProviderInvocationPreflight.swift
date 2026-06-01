//
//  ServerProviderSearchAPILiveProviderInvocationPreflight.swift
//  kAir
//
//  A160 metadata-only Search API provider invocation preflight proof. This file
//  joins upstream decisions before any remote path can become callable.
//

import Foundation

enum ServerProviderSearchAPILiveProviderInvocationPreflightState:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case accepted
    case rejected
}

enum ServerProviderSearchAPILiveProviderInvocationLeaseState:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case issued
    case expired
    case rejected
}

enum ServerProviderSearchAPILiveProviderInvocationPreflightRejectionReason:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case adapterInterfaceNotAccepted
    case runtimeCallableFlagTrue
    case unsupportedProviderFamily
    case providerFamilyMismatch
    case capabilityMismatch
    case resultShapeMismatch
    case freshnessMismatch
    case searchContextMismatch
    case vendorOrDescriptorMismatch
    case missingUpstreamID
    case meteredDecisionMismatch
    case leaseMismatch
    case expiredLease
    case transportRequestMismatch
    case staleBoundaryOrReadiness
    case costClassMismatch
    case costUnitMismatch
    case missingBudgetSnapshot
    case regionBlocked
    case privacyBlocked
    case healthContextBlocked
    case missingSourcePolicy
    case missingCitation
    case missingSourceHost
    case missingAttribution
    case pageContentPolicyConflict
    case retentionConflict
    case serverSecretModeNotServerOwned
    case duplicatePreflightID
}

struct ServerProviderSearchAPILiveProviderInvocationPreflightInput:
    Codable,
    Hashable,
    Sendable
{
    let preflightID: String
    let adapterInterfaceDecision: ServerProviderSearchAPILiveTransportAdapterInterfaceDecision
    let adapterRuntimeCallableFlag: Bool
    let selectedDescriptorID: String
    let selectedVendorDecisionID: String
    let selectedVendorID: String
    let meteredDecisionID: String
    let leaseID: String
    let leaseMeteredDecisionID: String
    let leaseState: ServerProviderSearchAPILiveProviderInvocationLeaseState
    let transportRequestID: String
    let transportLeaseID: String
    let auditTraceID: String
    let auditTransportRequestID: String
    let boundaryID: String
    let readinessDecisionID: String
    let readinessState: ServerProviderSearchAPILiveTransportReadinessState
    let providerFamily: ProviderFamily
    let capability: ProviderCapability
    let adapterResultShape: ServerProviderSearchAPIVendorResultShape
    let adapterFreshness: ProviderFreshness
    let resultShape: ServerProviderSearchAPIVendorResultShape
    let freshness: ProviderFreshness
    let costClass: ProviderCostClass
    let costUnit: ServerProviderSearchAPILiveVendorCostUnit
    let searchContextClass: ServerProviderSearchAPILiveTransportAdapterSearchContextClass
    let pageContentRequirement: ServerProviderSearchAPIPageBodyRequirement
    let retentionClass: ServerProviderSearchAPIRetentionLevel
    let sourceState: ServerSourcePolicyState
    let citationRequired: Bool
    let sourceHostRequired: Bool
    let attributionRequired: Bool
    let region: ProviderRegion
    let privacyClass: ProviderPrivacyClass
    let membershipTier: MembershipTier
    let budgetSnapshotID: String
    let serverSecretMode: ServerProviderSearchAPILiveTransportAdapterSecretMode
    let userFacingPurpose: String

    init(
        preflightID: String,
        adapterInterfaceDecision: ServerProviderSearchAPILiveTransportAdapterInterfaceDecision,
        adapterRuntimeCallableFlag: Bool? = nil,
        selectedDescriptorID: String,
        selectedVendorDecisionID: String,
        selectedVendorID: String,
        meteredDecisionID: String,
        leaseID: String,
        leaseMeteredDecisionID: String,
        leaseState: ServerProviderSearchAPILiveProviderInvocationLeaseState = .issued,
        transportRequestID: String,
        transportLeaseID: String,
        auditTraceID: String,
        auditTransportRequestID: String,
        boundaryID: String = ServerProviderSearchAPILiveTransportReadinessGate.expectedBoundaryID,
        readinessDecisionID: String = "a145-search-api-live-transport-readiness",
        readinessState: ServerProviderSearchAPILiveTransportReadinessState = .readyForPlanning,
        providerFamily: ProviderFamily = .searchAPI,
        capability: ProviderCapability = .webSearch,
        adapterResultShape: ServerProviderSearchAPIVendorResultShape,
        adapterFreshness: ProviderFreshness,
        resultShape: ServerProviderSearchAPIVendorResultShape,
        freshness: ProviderFreshness,
        costClass: ProviderCostClass,
        costUnit: ServerProviderSearchAPILiveVendorCostUnit,
        searchContextClass: ServerProviderSearchAPILiveTransportAdapterSearchContextClass,
        pageContentRequirement: ServerProviderSearchAPIPageBodyRequirement,
        retentionClass: ServerProviderSearchAPIRetentionLevel,
        sourceState: ServerSourcePolicyState = .passed,
        citationRequired: Bool = true,
        sourceHostRequired: Bool = true,
        attributionRequired: Bool = true,
        region: ProviderRegion,
        privacyClass: ProviderPrivacyClass = .general,
        membershipTier: MembershipTier,
        budgetSnapshotID: String,
        serverSecretMode: ServerProviderSearchAPILiveTransportAdapterSecretMode = .serverOwned,
        userFacingPurpose: String
    ) {
        self.preflightID = Self.safeID(preflightID, fallback: "search-api-live-provider-preflight")
        self.adapterInterfaceDecision = adapterInterfaceDecision
        self.adapterRuntimeCallableFlag = adapterRuntimeCallableFlag
            ?? adapterInterfaceDecision.isRuntimeCallable
        self.selectedDescriptorID = Self.safeID(selectedDescriptorID, fallback: "search-api-live-adapter")
        self.selectedVendorDecisionID = selectedVendorDecisionID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.selectedVendorID = Self.safeID(selectedVendorID, fallback: "search-api-live-vendor")
        self.meteredDecisionID = meteredDecisionID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.leaseID = leaseID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.leaseMeteredDecisionID = leaseMeteredDecisionID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.leaseState = leaseState
        self.transportRequestID = transportRequestID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.transportLeaseID = transportLeaseID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.auditTraceID = auditTraceID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.auditTransportRequestID = auditTransportRequestID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.boundaryID = boundaryID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.readinessDecisionID = readinessDecisionID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.readinessState = readinessState
        self.providerFamily = providerFamily
        self.capability = capability
        self.adapterResultShape = adapterResultShape
        self.adapterFreshness = adapterFreshness
        self.resultShape = resultShape
        self.freshness = freshness
        self.costClass = costClass
        self.costUnit = costUnit
        self.searchContextClass = searchContextClass
        self.pageContentRequirement = pageContentRequirement
        self.retentionClass = retentionClass
        self.sourceState = sourceState
        self.citationRequired = citationRequired
        self.sourceHostRequired = sourceHostRequired
        self.attributionRequired = attributionRequired
        self.region = region
        self.privacyClass = privacyClass
        self.membershipTier = membershipTier
        self.budgetSnapshotID = budgetSnapshotID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.serverSecretMode = serverSecretMode
        self.userFacingPurpose = userFacingPurpose.trimmingCharacters(in: .whitespacesAndNewlines)
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

struct ServerProviderSearchAPILiveProviderInvocationPreflightSummary:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let selectedDescriptorID: String
    let selectedVendorDecisionID: String
    let selectedVendorID: String
    let meteredDecisionID: String
    let leaseID: String
    let transportRequestID: String
    let auditTraceID: String
    let budgetSnapshotID: String
    let providerFamily: ProviderFamily
    let capability: ProviderCapability
    let resultShape: ServerProviderSearchAPIVendorResultShape
    let freshness: ProviderFreshness
    let costClass: ProviderCostClass
    let costUnit: ServerProviderSearchAPILiveVendorCostUnit
    let searchContextClass: ServerProviderSearchAPILiveTransportAdapterSearchContextClass
    let pageContentRequirement: ServerProviderSearchAPIPageBodyRequirement
    let retentionClass: ServerProviderSearchAPIRetentionLevel
    let sourceState: ServerSourcePolicyState
    let citationRequired: Bool
    let sourceHostRequired: Bool
    let attributionRequired: Bool
    let region: ProviderRegion
    let membershipTier: MembershipTier

    var description: String {
        "SearchAPILiveProviderInvocationPreflightSummary(id: \(id), descriptor: \(selectedDescriptorID), vendor: \(selectedVendorID))"
    }
}

struct ServerProviderSearchAPILiveProviderInvocationPreflightSafeCopy:
    Codable,
    Hashable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let state: ServerProviderSearchAPILiveProviderInvocationPreflightState
    let summary: ServerProviderSearchAPILiveProviderInvocationPreflightSummary?
    let rejectionReasons: [ServerProviderSearchAPILiveProviderInvocationPreflightRejectionReason]
    let statusLine: String
    let isRuntimeCallable: Bool

    var description: String {
        "SearchAPILiveProviderInvocationPreflightSafeCopy(id: \(id), state: \(state.rawValue), callable: \(isRuntimeCallable))"
    }
}

struct ServerProviderSearchAPILiveProviderInvocationPreflightDecision:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let state: ServerProviderSearchAPILiveProviderInvocationPreflightState
    let summary: ServerProviderSearchAPILiveProviderInvocationPreflightSummary?
    let rejectionReasons: [ServerProviderSearchAPILiveProviderInvocationPreflightRejectionReason]
    let statusLine: String

    var isAccepted: Bool {
        state == .accepted && summary != nil && rejectionReasons.isEmpty
    }

    var isRuntimeCallable: Bool {
        false
    }

    var safeCopy: ServerProviderSearchAPILiveProviderInvocationPreflightSafeCopy {
        ServerProviderSearchAPILiveProviderInvocationPreflightSafeCopy(
            id: id,
            state: state,
            summary: summary,
            rejectionReasons: rejectionReasons,
            statusLine: statusLine,
            isRuntimeCallable: isRuntimeCallable
        )
    }

    var description: String {
        "SearchAPILiveProviderInvocationPreflightDecision(id: \(id), state: \(state.rawValue), callable: \(isRuntimeCallable))"
    }
}

enum ServerProviderSearchAPILiveProviderInvocationPreflight {
    static func evaluate(
        input: ServerProviderSearchAPILiveProviderInvocationPreflightInput,
        existingPreflightIDs: Set<String> = []
    ) -> ServerProviderSearchAPILiveProviderInvocationPreflightDecision {
        let selectedSummary = input.adapterInterfaceDecision.descriptorSummaries.first {
            $0.id == input.selectedDescriptorID
        }
        let reasons = rejectionReasons(
            for: input,
            selectedSummary: selectedSummary,
            existingPreflightIDs: existingPreflightIDs
        )
        let summary = selectedSummary.map {
            preflightSummary(for: input, selectedSummary: $0)
        }

        if reasons.isEmpty, let summary {
            return ServerProviderSearchAPILiveProviderInvocationPreflightDecision(
                id: "search-api-live-provider-invocation-preflight-\(input.preflightID)-accepted",
                state: .accepted,
                summary: summary,
                rejectionReasons: [],
                statusLine: "Search API provider invocation preflight is accepted from metadata only; remote provider path remains disabled."
            )
        }

        let stableReasons = deduplicated(reasons)
        return ServerProviderSearchAPILiveProviderInvocationPreflightDecision(
            id: "search-api-live-provider-invocation-preflight-\(input.preflightID)-rejected-\(stableReasons.first?.rawValue ?? "unknown")",
            state: .rejected,
            summary: summary,
            rejectionReasons: stableReasons,
            statusLine: "Search API provider invocation preflight is blocked by metadata policy: \(stableReasons.first?.rawValue ?? "unknown"); remote provider path remains disabled."
        )
    }

    private static func rejectionReasons(
        for input: ServerProviderSearchAPILiveProviderInvocationPreflightInput,
        selectedSummary: ServerProviderSearchAPILiveTransportAdapterDescriptorSummary?,
        existingPreflightIDs: Set<String>
    ) -> [ServerProviderSearchAPILiveProviderInvocationPreflightRejectionReason] {
        var reasons: [ServerProviderSearchAPILiveProviderInvocationPreflightRejectionReason] = []

        if existingPreflightIDs.contains(input.preflightID) {
            reasons.append(.duplicatePreflightID)
        }
        if input.adapterInterfaceDecision.isAccepted == false {
            reasons.append(.adapterInterfaceNotAccepted)
        }
        if input.adapterRuntimeCallableFlag || input.adapterInterfaceDecision.isRuntimeCallable {
            reasons.append(.runtimeCallableFlagTrue)
        }
        if input.providerFamily != .searchAPI {
            reasons.append(.unsupportedProviderFamily)
        }
        if requiredIDs(for: input).contains(where: \.isEmpty) {
            reasons.append(.missingUpstreamID)
        }
        if input.budgetSnapshotID.isEmpty {
            reasons.append(.missingBudgetSnapshot)
        }
        if input.leaseMeteredDecisionID != input.meteredDecisionID {
            reasons.append(.meteredDecisionMismatch)
        }
        if input.transportLeaseID != input.leaseID {
            reasons.append(.leaseMismatch)
        }
        if input.leaseState == .expired {
            reasons.append(.expiredLease)
        }
        if input.leaseState == .rejected {
            reasons.append(.leaseMismatch)
        }
        if input.auditTransportRequestID != input.transportRequestID {
            reasons.append(.transportRequestMismatch)
        }
        if input.boundaryID != ServerProviderSearchAPILiveTransportReadinessGate.expectedBoundaryID
            || input.readinessState != .readyForPlanning {
            reasons.append(.staleBoundaryOrReadiness)
        }
        if input.privacyClass == .health {
            reasons.append(.healthContextBlocked)
        } else if input.privacyClass.allowsRemoteProvider == false {
            reasons.append(.privacyBlocked)
        }
        if input.sourceState != .passed {
            reasons.append(.missingSourcePolicy)
        }
        if input.citationRequired == false {
            reasons.append(.missingCitation)
        }
        if input.sourceHostRequired == false {
            reasons.append(.missingSourceHost)
        }
        if input.attributionRequired == false {
            reasons.append(.missingAttribution)
        }
        if input.serverSecretMode != .serverOwned {
            reasons.append(.serverSecretModeNotServerOwned)
        }

        guard let selectedSummary else {
            reasons.append(.vendorOrDescriptorMismatch)
            return deduplicated(reasons)
        }

        if input.adapterInterfaceDecision.selectedDescriptorID != input.selectedDescriptorID
            || input.adapterInterfaceDecision.selectedVendorID != input.selectedVendorID
            || selectedSummary.id != input.selectedDescriptorID
            || selectedSummary.vendorID != input.selectedVendorID {
            reasons.append(.vendorOrDescriptorMismatch)
        }
        if selectedSummary.providerFamily != input.providerFamily {
            reasons.append(.providerFamilyMismatch)
        }
        if selectedSummary.capability != input.capability {
            reasons.append(.capabilityMismatch)
        }
        if selectedSummary.isEligible == false
            || selectedSummary.rejectionReasons.isEmpty == false {
            reasons.append(.adapterInterfaceNotAccepted)
        }
        if input.adapterResultShape != input.resultShape {
            reasons.append(.resultShapeMismatch)
        }
        if input.adapterFreshness != input.freshness {
            reasons.append(.freshnessMismatch)
        }
        if selectedSummary.costClass != input.costClass {
            reasons.append(.costClassMismatch)
        }
        if selectedSummary.costUnit != input.costUnit {
            reasons.append(.costUnitMismatch)
        }
        if selectedSummary.searchContextClass != input.searchContextClass {
            reasons.append(.searchContextMismatch)
        }
        if pageContentMatches(
            requirement: input.pageContentRequirement,
            mode: selectedSummary.pageContentMode
        ) == false {
            reasons.append(.pageContentPolicyConflict)
        }
        if selectedSummary.retentionClass > input.retentionClass {
            reasons.append(.retentionConflict)
        }
        if selectedSummary.regionIDs.contains(ProviderRegion.global.rawValue) == false
            && selectedSummary.regionIDs.contains(input.region.rawValue) == false {
            reasons.append(.regionBlocked)
        }

        return deduplicated(reasons)
    }

    private static func requiredIDs(
        for input: ServerProviderSearchAPILiveProviderInvocationPreflightInput
    ) -> [String] {
        [
            input.preflightID,
            input.selectedDescriptorID,
            input.selectedVendorDecisionID,
            input.selectedVendorID,
            input.meteredDecisionID,
            input.leaseID,
            input.leaseMeteredDecisionID,
            input.transportRequestID,
            input.transportLeaseID,
            input.auditTraceID,
            input.auditTransportRequestID,
            input.boundaryID,
            input.readinessDecisionID,
            input.userFacingPurpose,
        ]
    }

    private static func preflightSummary(
        for input: ServerProviderSearchAPILiveProviderInvocationPreflightInput,
        selectedSummary: ServerProviderSearchAPILiveTransportAdapterDescriptorSummary
    ) -> ServerProviderSearchAPILiveProviderInvocationPreflightSummary {
        ServerProviderSearchAPILiveProviderInvocationPreflightSummary(
            id: input.preflightID,
            selectedDescriptorID: selectedSummary.id,
            selectedVendorDecisionID: input.selectedVendorDecisionID,
            selectedVendorID: selectedSummary.vendorID,
            meteredDecisionID: input.meteredDecisionID,
            leaseID: input.leaseID,
            transportRequestID: input.transportRequestID,
            auditTraceID: input.auditTraceID,
            budgetSnapshotID: input.budgetSnapshotID,
            providerFamily: input.providerFamily,
            capability: input.capability,
            resultShape: input.resultShape,
            freshness: input.freshness,
            costClass: input.costClass,
            costUnit: input.costUnit,
            searchContextClass: input.searchContextClass,
            pageContentRequirement: input.pageContentRequirement,
            retentionClass: input.retentionClass,
            sourceState: input.sourceState,
            citationRequired: input.citationRequired,
            sourceHostRequired: input.sourceHostRequired,
            attributionRequired: input.attributionRequired,
            region: input.region,
            membershipTier: input.membershipTier
        )
    }

    private static func pageContentMatches(
        requirement: ServerProviderSearchAPIPageBodyRequirement,
        mode: ServerProviderSearchAPIVendorPageBodyMode
    ) -> Bool {
        switch (requirement, mode) {
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

    private static func deduplicated<T: Hashable>(_ values: [T]) -> [T] {
        var seen: Set<T> = []
        var result: [T] = []
        for value in values where seen.insert(value).inserted {
            result.append(value)
        }
        return result
    }
}
