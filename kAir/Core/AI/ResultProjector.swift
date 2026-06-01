//
//  ResultProjector.swift
//  kAir
//
//  Pure fixture-only projection from provider/search/MCP decisions to a
//  UI/recommendation-consumable envelope. No provider calls, no network, no UI.
//

import Foundation

/// Projection state after a provider decision has been normalized for UI,
/// recommendations, transcript blocks, or future memory candidates.
enum ResultProjectionStatus: String, Codable, Hashable, Sendable, CaseIterable {
    case resolved
    case blocked
    case unavailable
}

/// Provider metadata that must survive projection. This keeps cost/freshness
/// and trace visible to UI/recommendation code without asking callers to inspect
/// provider-specific decision types.
struct ResultProviderMetadata: Hashable {
    let providerID: String?
    let providerFamily: ProviderFamily?
    let costClass: ProviderCostClass
    let freshness: ProviderFreshness
    let limitations: [String]
    let trace: ProviderTrace
}

/// The A5d normalized projection envelope. `normalizedResult` is present only
/// when the provider produced a concrete fixture result; blocked/unavailable
/// MCP/provider decisions still carry status + metadata for honest UI copy.
struct ProjectedProviderResult: Hashable, Identifiable {
    let id: String
    let status: ResultProjectionStatus
    let surface: SurfaceKind
    let capability: CapabilityKind?
    let normalizedResult: NormalizedResult?
    let metadata: ResultProviderMetadata
    let summaryTitle: String
    let summarySubtitle: String

    var isResolved: Bool {
        status == .resolved && normalizedResult != nil
    }
}

enum ResultProjector {
    private static let mapFixtureLimitation = "Fixture map provider result; no real map SDK call."
    private static let providerUnavailableLimitation = "Provider selection did not produce a usable fixture result."
    private static let mcpBlockedLimitation = "MCP operation was not executed."

    static func project(
        providerSelection selection: ProviderSelection,
        createdAt: Date = Date()
    ) -> ProjectedProviderResult {
        let capability = capabilityKind(for: selection.trace.capability)
        let normalized = makeMapNormalizedResult(
            capability: capability,
            provider: selection.provider,
            traceID: selection.trace.traceID,
            createdAt: createdAt
        )
        let status = normalized == nil ? blockedStatus(for: selection.failureReason) : .resolved
        let limitations = selection.provider == nil
            ? [providerUnavailableLimitation]
            : [mapFixtureLimitation]

        return ProjectedProviderResult(
            id: "projection-\(selection.trace.traceID)",
            status: status,
            surface: capability?.surfaceFamily ?? .maps,
            capability: capability,
            normalizedResult: normalized,
            metadata: ResultProviderMetadata(
                providerID: selection.provider?.providerID,
                providerFamily: selection.provider?.family,
                costClass: selection.trace.costClass,
                freshness: selection.trace.freshness,
                limitations: limitations,
                trace: selection.trace
            ),
            summaryTitle: selection.provider?.displayName ?? "Provider unavailable",
            summarySubtitle: summarySubtitle(
                providerID: selection.provider?.providerID,
                costClass: selection.trace.costClass,
                freshness: selection.trace.freshness
            )
        )
    }

    static func project(
        searchDecision decision: SearchProviderDecision,
        createdAt: Date = Date()
    ) -> ProjectedProviderResult {
        let normalized = makeSearchNormalizedResult(
            decision: decision,
            createdAt: createdAt
        )
        let status = normalized == nil ? blockedStatus(for: decision.trace.failureReason) : .resolved
        let limitations = decision.result?.limitations ?? [
            decision.failureReason?.rawValue ?? providerUnavailableLimitation,
        ]

        return ProjectedProviderResult(
            id: "projection-\(decision.trace.traceID)",
            status: status,
            surface: .search,
            capability: .webSearch,
            normalizedResult: normalized,
            metadata: ResultProviderMetadata(
                providerID: decision.selectedProvider?.providerID,
                providerFamily: decision.selectedProvider?.family,
                costClass: decision.trace.costClass,
                freshness: decision.trace.freshness,
                limitations: limitations,
                trace: decision.trace
            ),
            summaryTitle: decision.result?.title ?? "Search unavailable",
            summarySubtitle: summarySubtitle(
                providerID: decision.selectedProvider?.providerID,
                costClass: decision.trace.costClass,
                freshness: decision.trace.freshness
            )
        )
    }

    static func project(
        mcpDecision decision: MCPGatewayDecision
    ) -> ProjectedProviderResult {
        let status: ResultProjectionStatus = decision.isAllowed ? .unavailable : .blocked
        let limitation = decision.denialReason
            .map { "\(mcpBlockedLimitation) Reason: \($0.rawValue)." }
            ?? "MCP operation allowed but not executed in fixture mode."

        return ProjectedProviderResult(
            id: "projection-\(decision.audit.trace.traceID)",
            status: status,
            surface: .chat,
            capability: .threadLookup,
            normalizedResult: nil,
            metadata: ResultProviderMetadata(
                providerID: decision.isAllowed ? decision.audit.serverID : nil,
                providerFamily: decision.isAllowed ? .mcp : nil,
                costClass: decision.audit.trace.costClass,
                freshness: decision.audit.trace.freshness,
                limitations: [limitation],
                trace: decision.audit.trace
            ),
            summaryTitle: decision.isAllowed ? "MCP operation reserved" : "MCP operation blocked",
            summarySubtitle: summarySubtitle(
                providerID: decision.isAllowed ? decision.audit.serverID : nil,
                costClass: decision.audit.trace.costClass,
                freshness: decision.audit.trace.freshness
            )
        )
    }

    private static func makeMapNormalizedResult(
        capability: CapabilityKind?,
        provider: MapProviderDescriptor?,
        traceID: String,
        createdAt: Date
    ) -> NormalizedResult? {
        guard let capability, let provider else { return nil }
        let source: ResultSource = provider.family == .appleLocal || provider.family == .cache
            ? .local
            : .partner

        switch capability {
        case .placeSearch:
            let place = PlaceCandidate(
                id: "\(provider.providerID)-fixture-place",
                name: "\(provider.displayName) fixture place",
                address: provider.attributionRequired ? "Provider attribution required" : nil
            )
            return NormalizedResult(
                id: "normalized-\(traceID)",
                capability: .placeSearch,
                payload: .placeSearch(places: [place]),
                source: source,
                confidence: 0.0,
                createdAt: createdAt
            )
        case .routePlanning:
            let route = RouteSummary(
                origin: "fixture-origin",
                destination: "\(provider.displayName) fixture destination",
                durationSeconds: nil
            )
            return NormalizedResult(
                id: "normalized-\(traceID)",
                capability: .routePlanning,
                payload: .routePlanning(route: route),
                source: source,
                confidence: 0.0,
                createdAt: createdAt
            )
        default:
            return nil
        }
    }

    private static func makeSearchNormalizedResult(
        decision: SearchProviderDecision,
        createdAt: Date
    ) -> NormalizedResult? {
        guard let result = decision.result else { return nil }
        let hit = WebHit(
            title: result.title,
            url: result.sourceURL.absoluteString,
            snippet: result.snippet
        )
        let source: ResultSource = decision.selectedProvider?.family == .cache
            ? .local
            : .partner

        return NormalizedResult(
            id: "normalized-\(decision.trace.traceID)",
            capability: .webSearch,
            payload: .webSearch(hits: [hit]),
            source: source,
            confidence: result.confidence,
            createdAt: createdAt
        )
    }

    private static func capabilityKind(for providerCapability: ProviderCapability) -> CapabilityKind? {
        switch providerCapability {
        case .placeSearch, .localServiceSearch:
            return .placeSearch
        case .routePlanning, .mapDisplay:
            return .routePlanning
        case .webSearch, .crawlerFetch:
            return .webSearch
        case .mcpTool:
            return .threadLookup
        }
    }

    private static func blockedStatus(for reason: ProviderSkipReason?) -> ResultProjectionStatus {
        reason == nil ? .unavailable : .blocked
    }

    private static func summarySubtitle(
        providerID: String?,
        costClass: ProviderCostClass,
        freshness: ProviderFreshness
    ) -> String {
        let provider = providerID ?? "none"
        return "provider=\(provider); cost=\(costClass.rawValue); freshness=\(freshness.rawValue)"
    }
}
