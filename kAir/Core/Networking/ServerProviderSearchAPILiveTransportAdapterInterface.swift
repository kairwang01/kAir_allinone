//
//  ServerProviderSearchAPILiveTransportAdapterInterface.swift
//  kAir
//
//  A155 metadata-only Search API live-transport adapter interface proof.
//  This file defines the server-owned interface shape for a future adapter
//  without making any remote path callable.
//

import Foundation

enum ServerProviderSearchAPILiveTransportAdapterSearchContextClass:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case searchOnly
    case compactContext
    case expandedContext
    case answerContext
}

enum ServerProviderSearchAPILiveTransportAdapterSecretMode:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case serverOwned
    case clientProvided
    case missing
}

enum ServerProviderSearchAPILiveTransportAdapterInterfaceState:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case accepted
    case rejected
}

enum ServerProviderSearchAPILiveTransportAdapterInterfaceRejectionReason:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case descriptorListEmpty
    case duplicateDescriptorID
    case noEligibleDescriptor
    case providerFamilyMismatch
    case vendorMismatch
    case unsupportedCapability
    case unsupportedResultShape
    case unsupportedFreshness
    case costClassMismatch
    case costUnitMismatch
    case pageContentPolicyConflict
    case retentionConflict
    case missingCitationSupport
    case missingSourceSupport
    case missingAttributionSupport
    case regionBlocked
    case quotaOrQPSUnavailable
    case killSwitchActive
    case missingUpstreamID
    case privacyBlocked
    case staleBoundaryOrReadiness
    case serverSecretModeNotServerOwned
}

struct ServerProviderSearchAPILiveTransportAdapterDescriptor:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let vendorID: String
    let providerFamily: ProviderFamily
    let capability: ProviderCapability
    let costClass: ProviderCostClass
    let supportedResultShapes: Set<ServerProviderSearchAPIVendorResultShape>
    let supportedFreshness: Set<ProviderFreshness>
    let costUnit: ServerProviderSearchAPILiveVendorCostUnit
    let searchContextClass: ServerProviderSearchAPILiveTransportAdapterSearchContextClass
    let pageContentMode: ServerProviderSearchAPIVendorPageBodyMode
    let retentionClass: ServerProviderSearchAPIRetentionLevel
    let citationSupport: ServerProviderSearchAPIVendorCitationSupport
    let qpsClass: ServerProviderSearchAPILiveVendorQPSClass
    let allowedRegions: Set<ProviderRegion>
    let killSwitchID: String
    let retryPolicyID: String
    let serverSecretMode: ServerProviderSearchAPILiveTransportAdapterSecretMode
    let isKillSwitchActive: Bool

    init(
        id: String,
        vendorID: String,
        providerFamily: ProviderFamily = .searchAPI,
        capability: ProviderCapability = .webSearch,
        costClass: ProviderCostClass = .meteredPremium,
        supportedResultShapes: Set<ServerProviderSearchAPIVendorResultShape>,
        supportedFreshness: Set<ProviderFreshness>,
        costUnit: ServerProviderSearchAPILiveVendorCostUnit,
        searchContextClass: ServerProviderSearchAPILiveTransportAdapterSearchContextClass,
        pageContentMode: ServerProviderSearchAPIVendorPageBodyMode,
        retentionClass: ServerProviderSearchAPIRetentionLevel,
        citationSupport: ServerProviderSearchAPIVendorCitationSupport,
        qpsClass: ServerProviderSearchAPILiveVendorQPSClass,
        allowedRegions: Set<ProviderRegion>,
        killSwitchID: String,
        retryPolicyID: String,
        serverSecretMode: ServerProviderSearchAPILiveTransportAdapterSecretMode = .serverOwned,
        isKillSwitchActive: Bool = false
    ) {
        self.id = Self.safeID(id, fallback: "search-api-live-adapter")
        self.vendorID = Self.safeID(vendorID, fallback: "search-api-live-vendor")
        self.providerFamily = providerFamily
        self.capability = capability
        self.costClass = costClass
        self.supportedResultShapes = supportedResultShapes
        self.supportedFreshness = supportedFreshness
        self.costUnit = costUnit
        self.searchContextClass = searchContextClass
        self.pageContentMode = pageContentMode
        self.retentionClass = retentionClass
        self.citationSupport = citationSupport
        self.qpsClass = qpsClass
        self.allowedRegions = allowedRegions
        self.killSwitchID = Self.safeID(killSwitchID, fallback: "search-api-live-kill-switch")
        self.retryPolicyID = Self.safeID(retryPolicyID, fallback: "search-api-live-retry-policy")
        self.serverSecretMode = serverSecretMode
        self.isKillSwitchActive = isKillSwitchActive
    }

    var description: String {
        "SearchAPILiveTransportAdapterDescriptor(id: \(id), vendor: \(vendorID), state: metadataOnly)"
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

struct ServerProviderSearchAPILiveTransportAdapterInterfaceRequest:
    Codable,
    Hashable,
    Sendable
{
    let selectedVendorDecisionID: String
    let selectedVendorID: String
    let meteredDecisionID: String
    let leaseID: String
    let transportRequestID: String
    let auditTraceID: String
    let boundaryID: String
    let readinessDecisionID: String
    let readinessState: ServerProviderSearchAPILiveTransportReadinessState
    let liveProviderPathEnabled: Bool
    let expectedCapability: ProviderCapability
    let expectedResultShape: ServerProviderSearchAPIVendorResultShape
    let expectedFreshness: ProviderFreshness
    let expectedCostClass: ProviderCostClass
    let expectedCostUnit: ServerProviderSearchAPILiveVendorCostUnit
    let privacyClass: ProviderPrivacyClass
    let region: ProviderRegion
    let citationRequired: Bool
    let sourceHostRequired: Bool
    let attributionRequired: Bool
    let pageContentRequirement: ServerProviderSearchAPIPageBodyRequirement
    let allowedRetention: ServerProviderSearchAPIRetentionLevel
    let userFacingPurpose: String

    init(
        selectedVendorDecisionID: String,
        selectedVendorID: String,
        meteredDecisionID: String,
        leaseID: String,
        transportRequestID: String,
        auditTraceID: String,
        boundaryID: String = ServerProviderSearchAPILiveTransportReadinessGate.expectedBoundaryID,
        readinessDecisionID: String = "a145-search-api-live-transport-readiness",
        readinessState: ServerProviderSearchAPILiveTransportReadinessState = .readyForPlanning,
        liveProviderPathEnabled: Bool = false,
        expectedCapability: ProviderCapability = .webSearch,
        expectedResultShape: ServerProviderSearchAPIVendorResultShape,
        expectedFreshness: ProviderFreshness,
        expectedCostClass: ProviderCostClass,
        expectedCostUnit: ServerProviderSearchAPILiveVendorCostUnit,
        privacyClass: ProviderPrivacyClass = .general,
        region: ProviderRegion,
        citationRequired: Bool = true,
        sourceHostRequired: Bool = true,
        attributionRequired: Bool = true,
        pageContentRequirement: ServerProviderSearchAPIPageBodyRequirement = .snippetsOnly,
        allowedRetention: ServerProviderSearchAPIRetentionLevel = .ephemeralOnly,
        userFacingPurpose: String
    ) {
        self.selectedVendorDecisionID = selectedVendorDecisionID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.selectedVendorID = Self.safeID(
            selectedVendorID,
            fallback: "search-api-live-vendor"
        )
        self.meteredDecisionID = meteredDecisionID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.leaseID = leaseID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.transportRequestID = transportRequestID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.auditTraceID = auditTraceID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.boundaryID = boundaryID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.readinessDecisionID = readinessDecisionID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.readinessState = readinessState
        self.liveProviderPathEnabled = liveProviderPathEnabled
        self.expectedCapability = expectedCapability
        self.expectedResultShape = expectedResultShape
        self.expectedFreshness = expectedFreshness
        self.expectedCostClass = expectedCostClass
        self.expectedCostUnit = expectedCostUnit
        self.privacyClass = privacyClass
        self.region = region
        self.citationRequired = citationRequired
        self.sourceHostRequired = sourceHostRequired
        self.attributionRequired = attributionRequired
        self.pageContentRequirement = pageContentRequirement
        self.allowedRetention = allowedRetention
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

struct ServerProviderSearchAPILiveTransportAdapterDescriptorSummary:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let vendorID: String
    let providerFamily: ProviderFamily
    let capability: ProviderCapability
    let costClass: ProviderCostClass
    let costUnit: ServerProviderSearchAPILiveVendorCostUnit
    let searchContextClass: ServerProviderSearchAPILiveTransportAdapterSearchContextClass
    let pageContentMode: ServerProviderSearchAPIVendorPageBodyMode
    let retentionClass: ServerProviderSearchAPIRetentionLevel
    let qpsClass: ServerProviderSearchAPILiveVendorQPSClass
    let regionIDs: [String]
    let isEligible: Bool
    let rejectionReasons: [ServerProviderSearchAPILiveTransportAdapterInterfaceRejectionReason]

    var description: String {
        "SearchAPILiveTransportAdapterDescriptorSummary(id: \(id), eligible: \(isEligible), reasons: \(rejectionReasons.map(\.rawValue).joined(separator: ",")))"
    }
}

struct ServerProviderSearchAPILiveTransportAdapterInterfaceSafeCopy:
    Codable,
    Hashable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let state: ServerProviderSearchAPILiveTransportAdapterInterfaceState
    let selectedDescriptorID: String?
    let selectedVendorID: String?
    let descriptorSummaries: [ServerProviderSearchAPILiveTransportAdapterDescriptorSummary]
    let rejectionReasons: [ServerProviderSearchAPILiveTransportAdapterInterfaceRejectionReason]
    let duplicateDescriptorIDs: [String]
    let statusLine: String
    let isRuntimeCallable: Bool

    var description: String {
        "SearchAPILiveTransportAdapterInterfaceSafeCopy(id: \(id), state: \(state.rawValue), selected: \(selectedDescriptorID ?? "none"), callable: \(isRuntimeCallable))"
    }
}

struct ServerProviderSearchAPILiveTransportAdapterInterfaceDecision:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let state: ServerProviderSearchAPILiveTransportAdapterInterfaceState
    let selectedDescriptorID: String?
    let selectedVendorID: String?
    let descriptorSummaries: [ServerProviderSearchAPILiveTransportAdapterDescriptorSummary]
    let rejectionReasons: [ServerProviderSearchAPILiveTransportAdapterInterfaceRejectionReason]
    let duplicateDescriptorIDs: [String]
    let statusLine: String

    var isAccepted: Bool {
        state == .accepted && selectedDescriptorID != nil
    }

    var isRuntimeCallable: Bool {
        false
    }

    var safeCopy: ServerProviderSearchAPILiveTransportAdapterInterfaceSafeCopy {
        ServerProviderSearchAPILiveTransportAdapterInterfaceSafeCopy(
            id: id,
            state: state,
            selectedDescriptorID: selectedDescriptorID,
            selectedVendorID: selectedVendorID,
            descriptorSummaries: descriptorSummaries,
            rejectionReasons: rejectionReasons,
            duplicateDescriptorIDs: duplicateDescriptorIDs,
            statusLine: statusLine,
            isRuntimeCallable: isRuntimeCallable
        )
    }

    var description: String {
        "SearchAPILiveTransportAdapterInterfaceDecision(id: \(id), state: \(state.rawValue), selected: \(selectedDescriptorID ?? "none"), callable: \(isRuntimeCallable))"
    }
}

enum ServerProviderSearchAPILiveTransportAdapterInterface {
    static func evaluate(
        request: ServerProviderSearchAPILiveTransportAdapterInterfaceRequest,
        descriptors: [ServerProviderSearchAPILiveTransportAdapterDescriptor]
    ) -> ServerProviderSearchAPILiveTransportAdapterInterfaceDecision {
        let requestReasons = rejectionReasons(for: request)
        guard descriptors.isEmpty == false else {
            return rejected(
                summaries: [],
                reasons: deduplicated([.descriptorListEmpty] + requestReasons),
                duplicateDescriptorIDs: []
            )
        }

        let (orderedDescriptors, duplicateIDs) = firstWinsDescriptors(descriptors)
        let summaries = orderedDescriptors.map { descriptor in
            summary(
                for: descriptor,
                request: request,
                requestReasons: requestReasons
            )
        }

        if let selected = summaries.first(where: \.isEligible) {
            return ServerProviderSearchAPILiveTransportAdapterInterfaceDecision(
                id: "search-api-live-transport-adapter-interface-\(selected.id)-accepted",
                state: .accepted,
                selectedDescriptorID: selected.id,
                selectedVendorID: selected.vendorID,
                descriptorSummaries: summaries,
                rejectionReasons: [],
                duplicateDescriptorIDs: duplicateIDs,
                statusLine: "Search API live transport adapter interface is accepted from metadata only; live provider path remains disabled."
            )
        }

        return rejected(
            summaries: summaries,
            reasons: aggregateRejectionReasons(
                from: summaries,
                requestReasons: requestReasons,
                duplicateDescriptorIDs: duplicateIDs
            ),
            duplicateDescriptorIDs: duplicateIDs
        )
    }

    private static func firstWinsDescriptors(
        _ descriptors: [ServerProviderSearchAPILiveTransportAdapterDescriptor]
    ) -> (
        ordered: [ServerProviderSearchAPILiveTransportAdapterDescriptor],
        duplicateIDs: [String]
    ) {
        var seen: Set<String> = []
        var duplicateIDs: [String] = []
        var ordered: [ServerProviderSearchAPILiveTransportAdapterDescriptor] = []

        for descriptor in descriptors {
            if seen.contains(descriptor.id) {
                if duplicateIDs.contains(descriptor.id) == false {
                    duplicateIDs.append(descriptor.id)
                }
                continue
            }
            seen.insert(descriptor.id)
            ordered.append(descriptor)
        }

        return (ordered, duplicateIDs)
    }

    private static func summary(
        for descriptor: ServerProviderSearchAPILiveTransportAdapterDescriptor,
        request: ServerProviderSearchAPILiveTransportAdapterInterfaceRequest,
        requestReasons: [ServerProviderSearchAPILiveTransportAdapterInterfaceRejectionReason]
    ) -> ServerProviderSearchAPILiveTransportAdapterDescriptorSummary {
        let reasons = deduplicated(
            requestReasons + rejectionReasons(for: descriptor, request: request)
        )
        return ServerProviderSearchAPILiveTransportAdapterDescriptorSummary(
            id: descriptor.id,
            vendorID: descriptor.vendorID,
            providerFamily: descriptor.providerFamily,
            capability: descriptor.capability,
            costClass: descriptor.costClass,
            costUnit: descriptor.costUnit,
            searchContextClass: descriptor.searchContextClass,
            pageContentMode: descriptor.pageContentMode,
            retentionClass: descriptor.retentionClass,
            qpsClass: descriptor.qpsClass,
            regionIDs: descriptor.allowedRegions.map(\.rawValue).sorted(),
            isEligible: reasons.isEmpty,
            rejectionReasons: reasons
        )
    }

    private static func rejectionReasons(
        for request: ServerProviderSearchAPILiveTransportAdapterInterfaceRequest
    ) -> [ServerProviderSearchAPILiveTransportAdapterInterfaceRejectionReason] {
        var reasons: [ServerProviderSearchAPILiveTransportAdapterInterfaceRejectionReason] = []
        let upstreamIDs = [
            request.selectedVendorDecisionID,
            request.selectedVendorID,
            request.meteredDecisionID,
            request.leaseID,
            request.transportRequestID,
            request.auditTraceID,
            request.boundaryID,
            request.readinessDecisionID,
            request.userFacingPurpose,
        ]
        if upstreamIDs.contains(where: \.isEmpty) {
            reasons.append(.missingUpstreamID)
        }
        if request.boundaryID != ServerProviderSearchAPILiveTransportReadinessGate.expectedBoundaryID
            || request.readinessState != .readyForPlanning
            || request.liveProviderPathEnabled {
            reasons.append(.staleBoundaryOrReadiness)
        }
        if request.privacyClass.allowsRemoteProvider == false {
            reasons.append(.privacyBlocked)
        }
        return reasons
    }

    private static func rejectionReasons(
        for descriptor: ServerProviderSearchAPILiveTransportAdapterDescriptor,
        request: ServerProviderSearchAPILiveTransportAdapterInterfaceRequest
    ) -> [ServerProviderSearchAPILiveTransportAdapterInterfaceRejectionReason] {
        var reasons: [ServerProviderSearchAPILiveTransportAdapterInterfaceRejectionReason] = []
        if descriptor.providerFamily != .searchAPI {
            reasons.append(.providerFamilyMismatch)
        }
        if descriptor.vendorID != request.selectedVendorID {
            reasons.append(.vendorMismatch)
        }
        if descriptor.capability != request.expectedCapability {
            reasons.append(.unsupportedCapability)
        }
        if descriptor.supportedResultShapes.contains(request.expectedResultShape) == false {
            reasons.append(.unsupportedResultShape)
        }
        if descriptor.supportedFreshness.contains(request.expectedFreshness) == false {
            reasons.append(.unsupportedFreshness)
        }
        if descriptor.costClass != request.expectedCostClass {
            reasons.append(.costClassMismatch)
        }
        if descriptor.costUnit != request.expectedCostUnit {
            reasons.append(.costUnitMismatch)
        }
        if pageContentMatches(descriptor: descriptor, request: request) == false {
            reasons.append(.pageContentPolicyConflict)
        }
        if descriptor.retentionClass > request.allowedRetention {
            reasons.append(.retentionConflict)
        }
        if request.citationRequired, descriptor.citationSupport.supportsCitations == false {
            reasons.append(.missingCitationSupport)
        }
        if request.sourceHostRequired, descriptor.citationSupport.supportsSourceHost == false {
            reasons.append(.missingSourceSupport)
        }
        if request.attributionRequired, descriptor.citationSupport.supportsAttribution == false {
            reasons.append(.missingAttributionSupport)
        }
        if descriptor.allowedRegions.contains(.global) == false
            && descriptor.allowedRegions.contains(request.region) == false {
            reasons.append(.regionBlocked)
        }
        if descriptor.qpsClass == .unavailable {
            reasons.append(.quotaOrQPSUnavailable)
        }
        if descriptor.isKillSwitchActive {
            reasons.append(.killSwitchActive)
        }
        if descriptor.serverSecretMode != .serverOwned {
            reasons.append(.serverSecretModeNotServerOwned)
        }
        return reasons
    }

    private static func pageContentMatches(
        descriptor: ServerProviderSearchAPILiveTransportAdapterDescriptor,
        request: ServerProviderSearchAPILiveTransportAdapterInterfaceRequest
    ) -> Bool {
        switch (request.pageContentRequirement, descriptor.pageContentMode) {
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

    private static func aggregateRejectionReasons(
        from summaries: [ServerProviderSearchAPILiveTransportAdapterDescriptorSummary],
        requestReasons: [ServerProviderSearchAPILiveTransportAdapterInterfaceRejectionReason],
        duplicateDescriptorIDs: [String]
    ) -> [ServerProviderSearchAPILiveTransportAdapterInterfaceRejectionReason] {
        var reasons: [ServerProviderSearchAPILiveTransportAdapterInterfaceRejectionReason] = [
            .noEligibleDescriptor,
        ]
        if duplicateDescriptorIDs.isEmpty == false {
            reasons.append(.duplicateDescriptorID)
        }
        reasons.append(contentsOf: requestReasons)
        for summary in summaries {
            reasons.append(contentsOf: summary.rejectionReasons)
        }
        return deduplicated(reasons)
    }

    private static func rejected(
        summaries: [ServerProviderSearchAPILiveTransportAdapterDescriptorSummary],
        reasons: [ServerProviderSearchAPILiveTransportAdapterInterfaceRejectionReason],
        duplicateDescriptorIDs: [String]
    ) -> ServerProviderSearchAPILiveTransportAdapterInterfaceDecision {
        let stableReasons = deduplicated(reasons)
        return ServerProviderSearchAPILiveTransportAdapterInterfaceDecision(
            id: "search-api-live-transport-adapter-interface-rejected-\(stableReasons.first?.rawValue ?? "unknown")",
            state: .rejected,
            selectedDescriptorID: nil,
            selectedVendorID: nil,
            descriptorSummaries: summaries,
            rejectionReasons: stableReasons,
            duplicateDescriptorIDs: duplicateDescriptorIDs,
            statusLine: "Search API live transport adapter interface is blocked by metadata policy: \(stableReasons.first?.rawValue ?? "unknown"); live provider path remains disabled."
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
