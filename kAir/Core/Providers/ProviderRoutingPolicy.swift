//
//  ProviderRoutingPolicy.swift
//  kAir
//
//  Pure value contracts for provider routing, membership tiers, and cost
//  policy. No provider SDKs, no network calls, no API keys.
//

import Foundation

/// Provider families reserved by
/// `Docs/architecture/kair-provider-routing-mcp-search-v1.md` §3.
enum ProviderFamily: String, Codable, Hashable, Sendable, CaseIterable {
    case appleLocal
    case gaode
    case googleMaps
    case searchAPI
    case crawler
    case mcp
    case cache

    /// Providers that leave the local iOS process or depend on a non-local
    /// service. These are blocked for `.private` and `.health` contexts in v1.
    var isRemote: Bool {
        switch self {
        case .appleLocal, .cache:
            return false
        case .gaode, .googleMaps, .searchAPI, .crawler, .mcp:
            return true
        }
    }

    /// Providers that must be explicitly enabled before selection. MCP and
    /// crawlers have extra security / source-policy risk and are disabled by
    /// default.
    var isDisabledByDefault: Bool {
        self == .mcp || self == .crawler
    }
}

/// Provider-facing capability vocabulary. This is intentionally narrower than
/// app navigation and wider than maps-only providers.
enum ProviderCapability: String, Codable, Hashable, Sendable, CaseIterable {
    case mapDisplay
    case placeSearch
    case routePlanning
    case webSearch
    case localServiceSearch
    case crawlerFetch
    case mcpTool
}

/// Region signal used for provider choice. It is not a locale; it is a routing
/// hint for provider coverage and terms.
enum ProviderRegion: String, Codable, Hashable, Sendable, CaseIterable {
    case global
    case china
    case northAmerica
    case europe
    case other
}

/// Membership tier as a routing constraint. Ordering is explicit so policy can
/// compare minimum tier requirements without relying on enum declaration order.
enum MembershipTier: String, Codable, Hashable, Sendable, CaseIterable, Comparable {
    case free
    case plus
    case pro
    case developerInternal

    private var rank: Int {
        switch self {
        case .free:              return 0
        case .plus:              return 1
        case .pro:               return 2
        case .developerInternal: return 3
        }
    }

    static func < (lhs: MembershipTier, rhs: MembershipTier) -> Bool {
        lhs.rank < rhs.rank
    }
}

/// Privacy class for provider routing. Remote providers are blocked for
/// private and health contexts until a future legal/product review changes the
/// contract.
enum ProviderPrivacyClass: String, Codable, Hashable, Sendable, CaseIterable {
    case general
    case `private`
    case health

    var allowsRemoteProvider: Bool {
        self == .general
    }
}

/// Cost class for provider use and UI badges.
enum ProviderCostClass: String, Codable, Hashable, Sendable, CaseIterable {
    case freeLocal
    case includedQuota
    case meteredPremium
    case blockedByCost
    case blockedByPrivacy
    case blockedByTerms
}

/// Freshness requirement for a provider request.
enum ProviderFreshness: String, Codable, Hashable, Sendable, CaseIterable {
    case cachedOK
    case livePreferred
    case liveRequired
}

/// Request consumed by `ProviderRoutingPolicy`.
struct ProviderRequest: Codable, Hashable, Sendable {
    let traceID: String
    let capability: ProviderCapability
    let region: ProviderRegion
    let privacyClass: ProviderPrivacyClass
    let membershipTier: MembershipTier
    let preferredProvider: ProviderFamily?
    let meteredProviderEntitlements: Set<ProviderFamily>
    let enabledExperimentalProviders: Set<ProviderFamily>
    let unavailableProviders: Set<ProviderFamily>
    let freshness: ProviderFreshness
    let allowCacheFallback: Bool

    init(
        traceID: String = "provider-trace",
        capability: ProviderCapability,
        region: ProviderRegion = .global,
        privacyClass: ProviderPrivacyClass = .general,
        membershipTier: MembershipTier = .free,
        preferredProvider: ProviderFamily? = nil,
        meteredProviderEntitlements: Set<ProviderFamily> = [],
        enabledExperimentalProviders: Set<ProviderFamily> = [],
        unavailableProviders: Set<ProviderFamily> = [],
        freshness: ProviderFreshness = .cachedOK,
        allowCacheFallback: Bool = true
    ) {
        self.traceID = traceID
        self.capability = capability
        self.region = region
        self.privacyClass = privacyClass
        self.membershipTier = membershipTier
        self.preferredProvider = preferredProvider
        self.meteredProviderEntitlements = meteredProviderEntitlements
        self.enabledExperimentalProviders = enabledExperimentalProviders
        self.unavailableProviders = unavailableProviders
        self.freshness = freshness
        self.allowCacheFallback = allowCacheFallback
    }
}

/// Why a provider was skipped during selection.
enum ProviderSkipReason: String, Codable, Hashable, Sendable, CaseIterable {
    case unsupportedCapability
    case unsupportedRegion
    case unavailable
    case disabledByDefault
    case blockedByPrivacy
    case blockedByCost
    case cacheFallbackDisabled
}

/// One skipped provider and its reason.
struct ProviderSkip: Codable, Hashable, Sendable {
    let providerID: String
    let family: ProviderFamily
    let reason: ProviderSkipReason
}

/// Final provider route outcome.
struct ProviderSelection: Hashable, Sendable {
    let provider: MapProviderDescriptor?
    let skippedProviders: [ProviderSkip]
    let failureReason: ProviderSkipReason?
    let trace: ProviderTrace

    var isResolved: Bool {
        provider != nil
    }
}

/// Non-PII provider route audit. This is safe for tests and future telemetry
/// because it records routing metadata only, never prompt text, raw health
/// data, API keys, or personal secrets.
struct ProviderTrace: Codable, Hashable, Sendable {
    let traceID: String
    let capability: ProviderCapability
    let selectedProviderID: String?
    let selectedProviderFamily: ProviderFamily?
    let skippedProviders: [ProviderSkip]
    let costClass: ProviderCostClass
    let privacyClass: ProviderPrivacyClass
    let membershipTier: MembershipTier
    let freshness: ProviderFreshness
    let failureReason: ProviderSkipReason?
}

/// Pure provider selection. No side effects, no SDK imports, no network.
enum ProviderRoutingPolicy {
    static func select(
        for request: ProviderRequest,
        registry: [MapProviderDescriptor] = MapProviderDescriptor.defaultRegistry
    ) -> ProviderSelection {
        var skipped: [ProviderSkip] = []
        let ordered = orderedProviders(for: request, registry: registry)

        for descriptor in ordered {
            if let skip = skipReason(for: descriptor, request: request) {
                skipped.append(
                    ProviderSkip(
                        providerID: descriptor.providerID,
                        family: descriptor.family,
                        reason: skip
                    )
                )
                continue
            }

            return makeSelection(
                provider: descriptor,
                skipped: skipped,
                failureReason: nil,
                request: request
            )
        }

        return makeSelection(
            provider: nil,
            skipped: skipped,
            failureReason: dominantFailureReason(from: skipped),
            request: request
        )
    }

    private static func orderedProviders(
        for request: ProviderRequest,
        registry: [MapProviderDescriptor]
    ) -> [MapProviderDescriptor] {
        let base = registry.sorted { lhs, rhs in
            lhs.priority < rhs.priority
        }

        guard let preferred = request.preferredProvider else { return base }

        return base.sorted { lhs, rhs in
            if lhs.family == preferred, rhs.family != preferred { return true }
            if rhs.family == preferred, lhs.family != preferred { return false }
            return lhs.priority < rhs.priority
        }
    }

    private static func skipReason(
        for descriptor: MapProviderDescriptor,
        request: ProviderRequest
    ) -> ProviderSkipReason? {
        guard descriptor.supports(capability: request.capability) else {
            return .unsupportedCapability
        }
        guard descriptor.supports(region: request.region) else {
            return .unsupportedRegion
        }
        guard request.unavailableProviders.contains(descriptor.family) == false else {
            return .unavailable
        }
        if descriptor.family.isDisabledByDefault,
           request.enabledExperimentalProviders.contains(descriptor.family) == false {
            return .disabledByDefault
        }
        if descriptor.family == .cache, request.allowCacheFallback == false {
            return .cacheFallbackDisabled
        }
        if descriptor.family.isRemote, request.privacyClass.allowsRemoteProvider == false {
            return .blockedByPrivacy
        }
        guard request.membershipTier >= descriptor.minimumMembership else {
            return .blockedByCost
        }
        if descriptor.costClass == .meteredPremium,
           request.membershipTier != .developerInternal,
           request.meteredProviderEntitlements.contains(descriptor.family) == false {
            return .blockedByCost
        }
        return nil
    }

    private static func makeSelection(
        provider: MapProviderDescriptor?,
        skipped: [ProviderSkip],
        failureReason: ProviderSkipReason?,
        request: ProviderRequest
    ) -> ProviderSelection {
        let trace = ProviderTrace(
            traceID: request.traceID,
            capability: request.capability,
            selectedProviderID: provider?.providerID,
            selectedProviderFamily: provider?.family,
            skippedProviders: skipped,
            costClass: provider?.costClass ?? costClass(for: failureReason),
            privacyClass: request.privacyClass,
            membershipTier: request.membershipTier,
            freshness: request.freshness,
            failureReason: failureReason
        )
        return ProviderSelection(
            provider: provider,
            skippedProviders: skipped,
            failureReason: failureReason,
            trace: trace
        )
    }

    private static func costClass(for failureReason: ProviderSkipReason?) -> ProviderCostClass {
        switch failureReason {
        case .blockedByPrivacy:
            return .blockedByPrivacy
        case .blockedByCost:
            return .blockedByCost
        case .disabledByDefault, .unsupportedRegion, .unsupportedCapability,
             .unavailable, .cacheFallbackDisabled, nil:
            return .blockedByTerms
        }
    }

    private static func dominantFailureReason(from skipped: [ProviderSkip]) -> ProviderSkipReason? {
        let priority: [ProviderSkipReason] = [
            .blockedByPrivacy,
            .blockedByCost,
            .unavailable,
            .disabledByDefault,
            .unsupportedRegion,
            .unsupportedCapability,
            .cacheFallbackDisabled,
        ]
        for reason in priority where skipped.contains(where: { $0.reason == reason }) {
            return reason
        }
        return nil
    }
}
