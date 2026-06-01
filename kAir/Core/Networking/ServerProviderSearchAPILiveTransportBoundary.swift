//
//  ServerProviderSearchAPILiveTransportBoundary.swift
//  kAir
//
//  A144 comment-programming boundary for a future Search API live transport.
//  The boundary is intentionally value-only: it names the ownership model,
//  prerequisite chain, and readiness checklist without exposing a callable
//  remote path.
//

import Foundation

enum ServerProviderSearchAPILiveTransportBoundary {
    static func planningDocument() -> ServerProviderSearchAPILiveTransportBoundaryDocument {
        ServerProviderSearchAPILiveTransportBoundaryDocument(
            id: "a144-search-api-live-transport-boundary",
            state: .a144PlanningOnly,
            upstreamChain: ServerProviderSearchAPILiveTransportBoundaryCheckpoint.requiredChain
                .enumerated()
                .map { index, checkpoint in
                    ServerProviderSearchAPILiveTransportBoundaryStep(
                        rank: index + 1,
                        checkpoint: checkpoint,
                        reviewerCopy: checkpoint.reviewerCopy
                    )
                },
            readinessChecklist: ServerProviderSearchAPILiveTransportReadinessItem.requiredSet
                .map { item in
                    ServerProviderSearchAPILiveTransportReadinessStep(
                        item: item,
                        reviewerCopy: item.reviewerCopy
                    )
                },
            runtimeEntryPointName: nil
        )
    }
}

enum ServerProviderSearchAPILiveTransportBoundaryState:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case a144PlanningOnly

    var isRuntimeCallable: Bool {
        false
    }

    var statusLine: String {
        "A144 keeps Search API live transport as a value-only planning boundary; no remote provider path is callable."
    }
}

enum ServerProviderSearchAPILiveTransportBoundaryCheckpoint:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case meteredEntitlement
    case vendorPolicy
    case payloadDispatch
    case dispatchAuthorization
    case transportLease
    case transportRequest
    case transportResponseReceiptAuditBinding
    case externalProviderPreflight
    case transportAuditTrace
    case renderedIDStatus
    case appBootstrapChatStoreStatusComposition

    static let requiredChain: [Self] = [
        .meteredEntitlement,
        .vendorPolicy,
        .payloadDispatch,
        .dispatchAuthorization,
        .transportLease,
        .transportRequest,
        .transportResponseReceiptAuditBinding,
        .externalProviderPreflight,
        .transportAuditTrace,
        .renderedIDStatus,
        .appBootstrapChatStoreStatusComposition,
    ]

    var reviewerCopy: String {
        switch self {
        case .meteredEntitlement:
            return "Metered entitlement decision is present before Search API planning."
        case .vendorPolicy:
            return "Vendor policy accepts the family, cost, freshness, and source rules."
        case .payloadDispatch:
            return "Prepared payload dispatch receipt is present before handoff planning."
        case .dispatchAuthorization:
            return "Dispatch authorization approves the selected vendor and capability."
        case .transportLease:
            return "Transport lease binds cost budget, membership, and reservation state."
        case .transportRequest:
            return "Transport request artifact is prepared from approved metadata."
        case .transportResponseReceiptAuditBinding:
            return "Response receipt is bound to adapter audit metadata before status projection."
        case .externalProviderPreflight:
            return "External provider preflight accepts only approved family and capability metadata."
        case .transportAuditTrace:
            return "Transport audit trace records policy and evaluation labels as value-only copy."
        case .renderedIDStatus:
            return "Rendered-id status source exposes only advisory provider copy for visible cards."
        case .appBootstrapChatStoreStatusComposition:
            return "AppBootstrap and ChatStore preserve first-wins status composition."
        }
    }
}

enum ServerProviderSearchAPILiveTransportReadinessItem:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case serverOwnership
    case serverSideSecretInjection
    case signingBoundary
    case retryRateLimitPolicy
    case killSwitch
    case quotaMembershipEnforcement
    case privacySourcePolicy
    case citationAttribution
    case redactedLogging
    case deterministicFixtures
    case failureTaxonomy
    case rollbackChecks

    static let requiredSet: [Self] = [
        .serverOwnership,
        .serverSideSecretInjection,
        .signingBoundary,
        .retryRateLimitPolicy,
        .killSwitch,
        .quotaMembershipEnforcement,
        .privacySourcePolicy,
        .citationAttribution,
        .redactedLogging,
        .deterministicFixtures,
        .failureTaxonomy,
        .rollbackChecks,
    ]

    var reviewerCopy: String {
        switch self {
        case .serverOwnership:
            return "Server side owns any future remote hop and its policy checks."
        case .serverSideSecretInjection:
            return "Secret material is injected only by server-owned configuration."
        case .signingBoundary:
            return "Signing is isolated at the server hop boundary."
        case .retryRateLimitPolicy:
            return "Retry and rate-limit policy are defined before any remote hop can be enabled."
        case .killSwitch:
            return "A kill switch can disable the live path independently of app release cadence."
        case .quotaMembershipEnforcement:
            return "Quota and membership gates are enforced before any vendor handoff."
        case .privacySourcePolicy:
            return "Privacy and source policy are checked before any public-info lookup plan."
        case .citationAttribution:
            return "Citation and attribution rules are bound before user-visible status copy."
        case .redactedLogging:
            return "Logging stores only redacted status and failure labels."
        case .deterministicFixtures:
            return "Fixtures cover accepted and rejected paths before live enablement."
        case .failureTaxonomy:
            return "Failure taxonomy is stable before user-visible status copy changes."
        case .rollbackChecks:
            return "Rollback checks preserve local-first behavior and existing status fallback."
        }
    }
}

struct ServerProviderSearchAPILiveTransportBoundaryStep:
    Codable,
    Hashable,
    Sendable
{
    let rank: Int
    let checkpoint: ServerProviderSearchAPILiveTransportBoundaryCheckpoint
    let reviewerCopy: String
}

struct ServerProviderSearchAPILiveTransportReadinessStep:
    Codable,
    Hashable,
    Sendable
{
    let item: ServerProviderSearchAPILiveTransportReadinessItem
    let reviewerCopy: String
}

struct ServerProviderSearchAPILiveTransportBoundaryDocument:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let state: ServerProviderSearchAPILiveTransportBoundaryState
    let upstreamChain: [ServerProviderSearchAPILiveTransportBoundaryStep]
    let readinessChecklist: [ServerProviderSearchAPILiveTransportReadinessStep]
    let runtimeEntryPointName: String?

    var isRuntimeCallable: Bool {
        state.isRuntimeCallable && runtimeEntryPointName != nil
    }

    var statusLine: String {
        state.statusLine
    }

    var safeCopy: ServerProviderSearchAPILiveTransportBoundarySafeCopy {
        ServerProviderSearchAPILiveTransportBoundarySafeCopy(
            id: id,
            state: state.rawValue,
            statusLine: statusLine,
            upstreamCheckpointIDs: upstreamChain.map { $0.checkpoint.rawValue },
            readinessItemIDs: readinessChecklist.map { $0.item.rawValue },
            isRuntimeCallable: isRuntimeCallable
        )
    }

    var description: String {
        "ServerProviderSearchAPILiveTransportBoundaryDocument(id: \(id), state: \(state.rawValue), upstream: \(upstreamChain.count), checklist: \(readinessChecklist.count), callable: \(isRuntimeCallable))"
    }
}

struct ServerProviderSearchAPILiveTransportBoundarySafeCopy:
    Codable,
    Hashable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let state: String
    let statusLine: String
    let upstreamCheckpointIDs: [String]
    let readinessItemIDs: [String]
    let isRuntimeCallable: Bool

    var description: String {
        "SearchAPILiveTransportBoundarySafeCopy(id: \(id), state: \(state), upstream: \(upstreamCheckpointIDs.count), checklist: \(readinessItemIDs.count), callable: \(isRuntimeCallable))"
    }
}
