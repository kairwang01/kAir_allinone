//
//  ProviderAccessProfile.swift
//  kAir
//
//  Pure value contract for membership/cost/provider defaults before provider,
//  search, or MCP request values are built. No SDKs, no network, no server
//  transport.
//

import Foundation

/// User/provider access defaults that apply before provider routing.
///
/// This is not an entitlement validator and not a provider runtime. It only
/// centralizes the inputs that are already enforced by routing/policy layers:
/// membership, provider preference, metered entitlements, experimental provider
/// enablement, unavailable providers, region, and cache fallback.
struct ProviderAccessProfile: Codable, Hashable, Sendable {
    let membershipTier: MembershipTier
    let defaultRegion: ProviderRegion
    let preferredProvider: ProviderFamily?
    let meteredProviderEntitlements: Set<ProviderFamily>
    let enabledExperimentalProviders: Set<ProviderFamily>
    let unavailableProviders: Set<ProviderFamily>
    let allowCacheFallback: Bool

    init(
        membershipTier: MembershipTier = .free,
        defaultRegion: ProviderRegion = .global,
        preferredProvider: ProviderFamily? = nil,
        meteredProviderEntitlements: Set<ProviderFamily> = [],
        enabledExperimentalProviders: Set<ProviderFamily> = [],
        unavailableProviders: Set<ProviderFamily> = [],
        allowCacheFallback: Bool = true
    ) {
        self.membershipTier = membershipTier
        self.defaultRegion = defaultRegion
        self.preferredProvider = preferredProvider
        self.meteredProviderEntitlements = meteredProviderEntitlements
        self.enabledExperimentalProviders = enabledExperimentalProviders
        self.unavailableProviders = unavailableProviders
        self.allowCacheFallback = allowCacheFallback
    }

    /// Default iOS/local profile. Free users route through local Apple/system
    /// providers or cache fallback; no metered provider entitlement is implied.
    static let freeLocalDefault = ProviderAccessProfile()

    /// Plus-tier China-first map/search preference. Gaode is included-quota in
    /// the current descriptor registry, so this preset does not add metered
    /// entitlements.
    static let plusChinaGaode = ProviderAccessProfile(
        membershipTier: .plus,
        defaultRegion: .china,
        preferredProvider: .gaode
    )

    /// Google preference with an explicit Google metered entitlement. Callers
    /// choose the tier; the default is plus because Google descriptors require
    /// at least plus and an entitlement in `ProviderRoutingPolicy`.
    static func googleEntitled(
        membershipTier: MembershipTier = .plus,
        defaultRegion: ProviderRegion = .northAmerica
    ) -> ProviderAccessProfile {
        ProviderAccessProfile(
            membershipTier: membershipTier,
            defaultRegion: defaultRegion,
            preferredProvider: .googleMaps,
            meteredProviderEntitlements: [.googleMaps]
        )
    }

    /// Internal diagnostics profile for exercising disabled-by-default provider
    /// paths in fixtures. It enables experimental providers but still stores no
    /// API keys, endpoints, or runtime objects.
    static func developerInternalDiagnostics(
        defaultRegion: ProviderRegion = .global,
        preferredProvider: ProviderFamily? = nil,
        enabledExperimentalProviders: Set<ProviderFamily> = [.crawler, .mcp],
        meteredProviderEntitlements: Set<ProviderFamily> = []
    ) -> ProviderAccessProfile {
        ProviderAccessProfile(
            membershipTier: .developerInternal,
            defaultRegion: defaultRegion,
            preferredProvider: preferredProvider,
            meteredProviderEntitlements: meteredProviderEntitlements,
            enabledExperimentalProviders: enabledExperimentalProviders
        )
    }

    /// Builds the provider-routing request from profile defaults plus per-call
    /// task signals. Privacy/freshness stay explicit at the call site so a
    /// membership profile cannot hide sensitive-context or live-data requirements.
    func providerRequest(
        traceID: String = "provider-profile-trace",
        capability: ProviderCapability,
        privacyClass: ProviderPrivacyClass = .general,
        freshness: ProviderFreshness = .cachedOK,
        regionOverride: ProviderRegion? = nil,
        preferredProviderOverride: ProviderFamily? = nil
    ) -> ProviderRequest {
        ProviderRequest(
            traceID: traceID,
            capability: capability,
            region: regionOverride ?? defaultRegion,
            privacyClass: privacyClass,
            membershipTier: membershipTier,
            preferredProvider: preferredProviderOverride ?? preferredProvider,
            meteredProviderEntitlements: meteredProviderEntitlements,
            enabledExperimentalProviders: enabledExperimentalProviders,
            unavailableProviders: unavailableProviders,
            freshness: freshness,
            allowCacheFallback: allowCacheFallback
        )
    }

    /// Builds the reserved search/crawler request from profile defaults plus
    /// explicit source-policy inputs. Robots state, drafts, cached results, and
    /// freshness remain call-site data because the profile must not imply that a
    /// source is crawlable, current, trusted, or safe for remote processing.
    func searchProviderRequest(
        traceID: String = "search-profile-trace",
        query: String,
        capability: ProviderCapability = .webSearch,
        privacyClass: ProviderPrivacyClass = .general,
        freshness: ProviderFreshness = .cachedOK,
        robotsState: SearchRobotsState = .notApplicable,
        resultDraft: SearchResultDraft? = nil,
        cachedResult: SearchResultEnvelope? = nil,
        preferredProviderOverride: ProviderFamily? = nil,
        now: Date = Date()
    ) -> SearchProviderRequest {
        SearchProviderRequest(
            traceID: traceID,
            query: query,
            capability: capability,
            privacyClass: privacyClass,
            membershipTier: membershipTier,
            preferredProvider: preferredProviderOverride ?? preferredProvider,
            meteredProviderEntitlements: meteredProviderEntitlements,
            enabledExperimentalProviders: enabledExperimentalProviders,
            freshness: freshness,
            robotsState: robotsState,
            resultDraft: resultDraft,
            cachedResult: cachedResult,
            now: now
        )
    }

    /// Builds the reserved MCP gateway request from profile membership plus
    /// explicit operation/confirmation inputs. Server allowlists, descriptor
    /// trust, Health blocking, and confirmation-required behavior remain owned by
    /// `MCPGatewayPolicy`.
    func mcpGatewayRequest(
        traceID: String = "mcp-profile-trace",
        serverID: String,
        operation: MCPGatewayOperation,
        privacyClass: ProviderPrivacyClass = .general,
        confirmationArtifact: MCPConfirmationArtifact? = nil
    ) -> MCPGatewayRequest {
        MCPGatewayRequest(
            traceID: traceID,
            serverID: serverID,
            operation: operation,
            privacyClass: privacyClass,
            membershipTier: membershipTier,
            confirmationArtifact: confirmationArtifact
        )
    }
}
