//
//  ServerProviderEnvelopeFactoryTests.swift
//  kAirTests
//
//  A12 provider/search/MCP policy decisions become server/provider envelopes
//  only when quota, entitlement, source, and confirmation gates still pass.
//

import XCTest
@testable import kAir

final class ServerProviderEnvelopeFactoryTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_100_000)

    func test_googleGaodeAndSearch_decisionsBuildEnvelopeOnlyWhenQuotaAllows() throws {
        let googleRequest = ProviderRequest(
            traceID: "a12-google",
            capability: .localServiceSearch,
            region: .northAmerica,
            membershipTier: .pro,
            preferredProvider: .googleMaps,
            meteredProviderEntitlements: [.googleMaps],
            freshness: .liveRequired
        )
        let googleSelection = ProviderRoutingPolicy.select(for: googleRequest)

        let googleBlocked = ServerProviderEnvelopeFactory.makeEnvelope(
            for: googleRequest,
            selection: googleSelection,
            quotaSnapshot: ServerProviderQuotaSnapshot(
                allowedProviderFamilies: [.googleMaps],
                entitledProviderFamilies: [.googleMaps]
            )
        )
        XCTAssertFalse(googleBlocked.isExecutable)
        XCTAssertEqual(googleBlocked.rejectionReason, .meteredEligibilityMissing(.googleMaps))

        let googleAllowed = ServerProviderEnvelopeFactory.makeEnvelope(
            for: googleRequest,
            selection: googleSelection,
            quotaSnapshot: ServerProviderQuotaSnapshot(
                allowedProviderFamilies: [.googleMaps],
                entitledProviderFamilies: [.googleMaps],
                meteredEligibleProviderFamilies: [.googleMaps]
            )
        )
        XCTAssertTrue(googleAllowed.isExecutable)
        XCTAssertEqual(googleAllowed.envelope?.providerFamily, .googleMaps)
        XCTAssertEqual(googleAllowed.envelope?.freshness, .liveRequired)

        let gaodeRequest = ProviderRequest(
            traceID: "a12-gaode",
            capability: .localServiceSearch,
            region: .china,
            membershipTier: .plus,
            preferredProvider: .gaode,
            freshness: .livePreferred
        )
        let gaodeSelection = ProviderRoutingPolicy.select(for: gaodeRequest)

        let gaodeBlocked = ServerProviderEnvelopeFactory.makeEnvelope(
            for: gaodeRequest,
            selection: gaodeSelection,
            quotaSnapshot: ServerProviderQuotaSnapshot(
                allowedProviderFamilies: [.gaode],
                entitledProviderFamilies: [.gaode]
            )
        )
        XCTAssertFalse(gaodeBlocked.isExecutable)
        XCTAssertEqual(gaodeBlocked.rejectionReason, .includedQuotaExhausted(.gaode))

        let gaodeAllowed = ServerProviderEnvelopeFactory.makeEnvelope(
            for: gaodeRequest,
            selection: gaodeSelection,
            quotaSnapshot: ServerProviderQuotaSnapshot(
                allowedProviderFamilies: [.gaode],
                entitledProviderFamilies: [.gaode],
                remainingIncludedQuota: [.gaode: 3]
            )
        )
        XCTAssertTrue(gaodeAllowed.isExecutable)
        XCTAssertEqual(gaodeAllowed.envelope?.providerFamily, .gaode)
        XCTAssertEqual(gaodeAllowed.envelope?.costClass, .includedQuota)

        let search = try resolvedSearchAPI()
        let searchAllowed = ServerProviderEnvelopeFactory.makeEnvelope(
            for: search.request,
            decision: search.decision,
            quotaSnapshot: ServerProviderQuotaSnapshot(
                allowedProviderFamilies: [.searchAPI],
                entitledProviderFamilies: [.searchAPI],
                meteredEligibleProviderFamilies: [.searchAPI]
            )
        )
        XCTAssertTrue(searchAllowed.isExecutable)
        XCTAssertEqual(searchAllowed.envelope?.providerFamily, .searchAPI)
        XCTAssertEqual(searchAllowed.envelope?.sourcePolicy.sourceHost, "example.com")
        XCTAssertEqual(searchAllowed.envelope?.sourcePolicy.robotsState, .notApplicable)
    }

    func test_crawlerDecision_buildsEnvelopeOnlyWhenEnabledAndSourcePassed() throws {
        let crawler = try resolvedCrawler()

        let disabled = ServerProviderEnvelopeFactory.makeEnvelope(
            for: crawler.request,
            decision: crawler.decision,
            quotaSnapshot: ServerProviderQuotaSnapshot(
                allowedProviderFamilies: [.crawler],
                entitledProviderFamilies: [.crawler],
                meteredEligibleProviderFamilies: [.crawler]
            )
        )
        XCTAssertFalse(disabled.isExecutable)
        XCTAssertEqual(disabled.rejectionReason, .experimentalProviderDisabled(.crawler))

        let allowed = ServerProviderEnvelopeFactory.makeEnvelope(
            for: crawler.request,
            decision: crawler.decision,
            quotaSnapshot: ServerProviderQuotaSnapshot(
                allowedProviderFamilies: [.crawler],
                entitledProviderFamilies: [.crawler],
                meteredEligibleProviderFamilies: [.crawler],
                enabledExperimentalProviderFamilies: [.crawler]
            )
        )

        XCTAssertTrue(allowed.isExecutable)
        XCTAssertEqual(allowed.envelope?.providerFamily, .crawler)
        XCTAssertEqual(allowed.envelope?.sourcePolicy.sourceState, .passed)
        XCTAssertEqual(allowed.envelope?.sourcePolicy.robotsState, .allowed)
        XCTAssertEqual(allowed.envelope?.sourcePolicy.sourceHost, "public.example.com")
        XCTAssertEqual(allowed.envelope?.enabledExperimentalProviders, [.crawler])
    }

    func test_blockedProviderSearchAndMCPDecisionsProduceNoExecutableEnvelope() throws {
        let blockedProviderRequest = ProviderRequest(
            traceID: "a12-provider-blocked",
            capability: .localServiceSearch,
            region: .northAmerica,
            membershipTier: .free,
            preferredProvider: .googleMaps,
            allowCacheFallback: false
        )
        let blockedProviderSelection = ProviderRoutingPolicy.select(for: blockedProviderRequest)
        let providerResult = ServerProviderEnvelopeFactory.makeEnvelope(
            for: blockedProviderRequest,
            selection: blockedProviderSelection,
            quotaSnapshot: remoteQuota(for: .googleMaps)
        )
        XCTAssertFalse(providerResult.isExecutable)
        XCTAssertEqual(providerResult.rejectionReason, .upstreamUnresolved)

        let draft = SearchResultDraft(
            sourceURL: try publicURL(host: "example.com", path: "/coffee"),
            title: "Coffee",
            snippet: "Public listing fixture.",
            attribution: "example.com",
            confidence: 0.71
        )
        let blockedSearchRequest = SearchProviderRequest(
            query: "coffee nearby",
            membershipTier: .plus,
            preferredProvider: .searchAPI,
            resultDraft: draft,
            now: now
        )
        let blockedSearchDecision = SearchProviderPolicy.evaluate(blockedSearchRequest)
        let searchResult = ServerProviderEnvelopeFactory.makeEnvelope(
            for: blockedSearchRequest,
            decision: blockedSearchDecision,
            quotaSnapshot: remoteQuota(for: .searchAPI)
        )
        XCTAssertFalse(searchResult.isExecutable)
        XCTAssertEqual(searchResult.rejectionReason, .upstreamUnresolved)

        let mcpRequest = MCPGatewayRequest(
            traceID: "a12-mcp-disabled",
            serverID: "calendar",
            operation: .tool(
                MCPToolDescriptor(
                    serverID: "calendar",
                    toolID: "read_events",
                    displayName: "Read events",
                    riskClasses: [.read],
                    isReadOnlyHint: true
                )
            ),
            membershipTier: .pro
        )
        let mcpDecision = MCPGatewayPolicy.authorize(
            mcpRequest,
            registry: [
                MCPServerDescriptor(
                    serverID: "calendar",
                    displayName: "Calendar MCP",
                    isEnabled: false,
                    descriptorTrust: .known,
                    allowedToolIDs: ["read_events"],
                    allowedResourceIDs: []
                ),
            ]
        )
        let mcpResult = ServerProviderEnvelopeFactory.makeEnvelope(
            for: mcpRequest,
            decision: mcpDecision,
            quotaSnapshot: ServerProviderQuotaSnapshot(
                allowedProviderFamilies: [.mcp],
                entitledProviderFamilies: [.mcp],
                remainingIncludedQuota: [.mcp: 1],
                enabledExperimentalProviderFamilies: [.mcp]
            )
        )
        XCTAssertFalse(mcpResult.isExecutable)
        XCTAssertEqual(mcpResult.rejectionReason, .upstreamUnresolved)
    }

    func test_healthRemoteDecisionCannotBecomeAcceptedEnvelope() throws {
        let google = try XCTUnwrap(
            MapProviderDescriptor.defaultRegistry.first { $0.family == .googleMaps }
        )
        let request = ProviderRequest(
            traceID: "a12-health-remote",
            capability: .placeSearch,
            region: .northAmerica,
            privacyClass: .health,
            membershipTier: .pro,
            preferredProvider: .googleMaps,
            meteredProviderEntitlements: [.googleMaps],
            freshness: .livePreferred
        )
        let forgedRemoteSelection = ProviderSelection(
            provider: google,
            skippedProviders: [],
            failureReason: nil,
            trace: ProviderTrace(
                traceID: request.traceID,
                capability: request.capability,
                selectedProviderID: google.providerID,
                selectedProviderFamily: google.family,
                skippedProviders: [],
                costClass: google.costClass,
                privacyClass: request.privacyClass,
                membershipTier: request.membershipTier,
                freshness: request.freshness,
                failureReason: nil
            )
        )

        let result = ServerProviderEnvelopeFactory.makeEnvelope(
            for: request,
            selection: forgedRemoteSelection,
            quotaSnapshot: ServerProviderQuotaSnapshot(
                allowedProviderFamilies: [.googleMaps],
                entitledProviderFamilies: [.googleMaps],
                meteredEligibleProviderFamilies: [.googleMaps]
            )
        )

        XCTAssertFalse(result.isExecutable)
        XCTAssertNil(result.envelope)
        XCTAssertEqual(result.rejectionReason, .validatorRejected(.privacyBlocked))
        XCTAssertEqual(result.validation?.denialReason, .privacyBlocked)
    }

    func test_profileQuotaSnapshotFreeLocalDefaultCannotCreateRemoteEnvelope() {
        let localQuota = ServerProviderQuotaSnapshot(
            providerAccessProfile: .freeLocalDefault
        )
        XCTAssertEqual(localQuota.allowedProviderFamilies, [.appleLocal, .cache])
        XCTAssertTrue(localQuota.entitledProviderFamilies.isEmpty)
        XCTAssertTrue(localQuota.meteredEligibleProviderFamilies.isEmpty)

        let localRequest = ProviderAccessProfile.freeLocalDefault.providerRequest(
            traceID: "a45-local-route",
            capability: .routePlanning,
            regionOverride: .northAmerica
        )
        let localSelection = ProviderRoutingPolicy.select(for: localRequest)
        let localResult = ServerProviderEnvelopeFactory.makeEnvelope(
            for: localRequest,
            selection: localSelection,
            quotaSnapshot: localQuota
        )
        XCTAssertTrue(localResult.isExecutable)
        XCTAssertEqual(localResult.envelope?.providerFamily, .appleLocal)

        let remoteProfile = ProviderAccessProfile.googleEntitled(membershipTier: .pro)
        let remoteRequest = remoteProfile.providerRequest(
            traceID: "a45-free-quota-remote",
            capability: .placeSearch,
            freshness: .livePreferred
        )
        let remoteSelection = ProviderRoutingPolicy.select(for: remoteRequest)
        XCTAssertEqual(remoteSelection.provider?.family, .googleMaps)

        let remoteResult = ServerProviderEnvelopeFactory.makeEnvelope(
            for: remoteRequest,
            selection: remoteSelection,
            quotaSnapshot: localQuota
        )
        XCTAssertFalse(remoteResult.isExecutable)
        XCTAssertEqual(remoteResult.rejectionReason, .providerNotAllowed(.googleMaps))
    }

    func test_profileQuotaSnapshotGoogleEntitlementStillRequiresMeteredEligibility() {
        let profile = ProviderAccessProfile.googleEntitled(membershipTier: .pro)
        let request = profile.providerRequest(
            traceID: "a45-google",
            capability: .placeSearch,
            freshness: .livePreferred
        )
        let selection = ProviderRoutingPolicy.select(for: request)
        XCTAssertEqual(selection.provider?.family, .googleMaps)

        let entitlementOnly = ServerProviderQuotaSnapshot(
            providerAccessProfile: profile,
            allowedProviderFamilies: [.googleMaps]
        )
        XCTAssertEqual(entitlementOnly.entitledProviderFamilies, [.googleMaps])
        XCTAssertTrue(entitlementOnly.meteredEligibleProviderFamilies.isEmpty)

        let blocked = ServerProviderEnvelopeFactory.makeEnvelope(
            for: request,
            selection: selection,
            quotaSnapshot: entitlementOnly
        )
        XCTAssertFalse(blocked.isExecutable)
        XCTAssertEqual(blocked.rejectionReason, .meteredEligibilityMissing(.googleMaps))

        let eligible = ServerProviderQuotaSnapshot(
            providerAccessProfile: profile,
            allowedProviderFamilies: [.googleMaps],
            meteredEligibleProviderFamilies: [.googleMaps]
        )
        let allowed = ServerProviderEnvelopeFactory.makeEnvelope(
            for: request,
            selection: selection,
            quotaSnapshot: eligible
        )
        XCTAssertTrue(allowed.isExecutable)
        XCTAssertEqual(allowed.envelope?.providerFamily, .googleMaps)
        XCTAssertEqual(allowed.envelope?.meteredProviderEntitlements, [.googleMaps])
    }

    func test_profileQuotaSnapshotGaodeRequiresExplicitRemainingIncludedQuota() {
        let profile = ProviderAccessProfile.plusChinaGaode
        let request = profile.providerRequest(
            traceID: "a45-gaode",
            capability: .localServiceSearch
        )
        let selection = ProviderRoutingPolicy.select(for: request)
        XCTAssertEqual(selection.provider?.family, .gaode)

        let noIncludedQuota = ServerProviderQuotaSnapshot(
            providerAccessProfile: profile,
            allowedProviderFamilies: [.gaode]
        )
        let blocked = ServerProviderEnvelopeFactory.makeEnvelope(
            for: request,
            selection: selection,
            quotaSnapshot: noIncludedQuota
        )
        XCTAssertFalse(blocked.isExecutable)
        XCTAssertEqual(blocked.rejectionReason, .entitlementMissing(.gaode))

        let remainingQuota = ServerProviderQuotaSnapshot(
            providerAccessProfile: profile,
            allowedProviderFamilies: [.gaode],
            remainingIncludedQuota: [.gaode: 2]
        )
        XCTAssertEqual(remainingQuota.entitledProviderFamilies, [.gaode])
        let allowed = ServerProviderEnvelopeFactory.makeEnvelope(
            for: request,
            selection: selection,
            quotaSnapshot: remainingQuota
        )
        XCTAssertTrue(allowed.isExecutable)
        XCTAssertEqual(allowed.envelope?.providerFamily, .gaode)
        XCTAssertEqual(allowed.envelope?.costClass, .includedQuota)
    }

    func test_profileQuotaSnapshotUnavailableProviderDisablesEvenWithQuota() {
        let requestProfile = ProviderAccessProfile.googleEntitled(membershipTier: .pro)
        let quotaProfile = ProviderAccessProfile(
            membershipTier: .pro,
            defaultRegion: .northAmerica,
            preferredProvider: .googleMaps,
            meteredProviderEntitlements: [.googleMaps],
            unavailableProviders: [.googleMaps]
        )
        let request = requestProfile.providerRequest(
            traceID: "a45-disabled-google",
            capability: .placeSearch,
            freshness: .livePreferred
        )
        let selection = ProviderRoutingPolicy.select(for: request)
        XCTAssertEqual(selection.provider?.family, .googleMaps)

        let quota = ServerProviderQuotaSnapshot(
            providerAccessProfile: quotaProfile,
            allowedProviderFamilies: [.googleMaps],
            meteredEligibleProviderFamilies: [.googleMaps]
        )
        XCTAssertEqual(quota.disabledProviderFamilies, [.googleMaps])

        let result = ServerProviderEnvelopeFactory.makeEnvelope(
            for: request,
            selection: selection,
            quotaSnapshot: quota
        )
        XCTAssertFalse(result.isExecutable)
        XCTAssertEqual(result.rejectionReason, .providerDisabled(.googleMaps))
    }

    func test_profileQuotaSnapshotExperimentalProvidersRequireProfileAndQuotaEnablement() throws {
        let crawler = try resolvedCrawler()
        let crawlerDisabledProfile = ProviderAccessProfile.developerInternalDiagnostics(
            preferredProvider: .crawler,
            enabledExperimentalProviders: [],
            meteredProviderEntitlements: [.crawler]
        )
        let crawlerEnabledProfile = ProviderAccessProfile.developerInternalDiagnostics(
            preferredProvider: .crawler,
            enabledExperimentalProviders: [.crawler],
            meteredProviderEntitlements: [.crawler]
        )

        let quotaAllowsCrawlerButProfileDoesNot = ServerProviderQuotaSnapshot(
            providerAccessProfile: crawlerDisabledProfile,
            allowedProviderFamilies: [.crawler],
            meteredEligibleProviderFamilies: [.crawler],
            enabledExperimentalProviderFamilies: [.crawler]
        )
        let profileOnlyCrawler = ServerProviderQuotaSnapshot(
            providerAccessProfile: crawlerEnabledProfile,
            allowedProviderFamilies: [.crawler],
            meteredEligibleProviderFamilies: [.crawler]
        )
        let crawlerAllowed = ServerProviderQuotaSnapshot(
            providerAccessProfile: crawlerEnabledProfile,
            allowedProviderFamilies: [.crawler],
            meteredEligibleProviderFamilies: [.crawler],
            enabledExperimentalProviderFamilies: [.crawler]
        )

        XCTAssertTrue(
            quotaAllowsCrawlerButProfileDoesNot.enabledExperimentalProviderFamilies.isEmpty
        )
        XCTAssertTrue(profileOnlyCrawler.enabledExperimentalProviderFamilies.isEmpty)
        XCTAssertEqual(crawlerAllowed.enabledExperimentalProviderFamilies, [.crawler])

        let crawlerBlockedByProfile = ServerProviderEnvelopeFactory.makeEnvelope(
            for: crawler.request,
            decision: crawler.decision,
            quotaSnapshot: quotaAllowsCrawlerButProfileDoesNot
        )
        let crawlerBlockedByQuota = ServerProviderEnvelopeFactory.makeEnvelope(
            for: crawler.request,
            decision: crawler.decision,
            quotaSnapshot: profileOnlyCrawler
        )
        let crawlerExecutable = ServerProviderEnvelopeFactory.makeEnvelope(
            for: crawler.request,
            decision: crawler.decision,
            quotaSnapshot: crawlerAllowed
        )

        XCTAssertEqual(
            crawlerBlockedByProfile.rejectionReason,
            .experimentalProviderDisabled(.crawler)
        )
        XCTAssertEqual(
            crawlerBlockedByQuota.rejectionReason,
            .experimentalProviderDisabled(.crawler)
        )
        XCTAssertTrue(crawlerExecutable.isExecutable)

        let mcpProfile = ProviderAccessProfile.developerInternalDiagnostics(
            preferredProvider: .mcp,
            enabledExperimentalProviders: [.mcp]
        )
        let mcp = allowedMCPReadDecision(profile: mcpProfile)
        let mcpProfileOnly = ServerProviderQuotaSnapshot(
            providerAccessProfile: mcpProfile,
            allowedProviderFamilies: [.mcp],
            remainingIncludedQuota: [.mcp: 1]
        )
        let mcpEnabled = ServerProviderQuotaSnapshot(
            providerAccessProfile: mcpProfile,
            allowedProviderFamilies: [.mcp],
            remainingIncludedQuota: [.mcp: 1],
            enabledExperimentalProviderFamilies: [.mcp]
        )

        let mcpBlocked = ServerProviderEnvelopeFactory.makeEnvelope(
            for: mcp.request,
            decision: mcp.decision,
            quotaSnapshot: mcpProfileOnly
        )
        let mcpExecutable = ServerProviderEnvelopeFactory.makeEnvelope(
            for: mcp.request,
            decision: mcp.decision,
            quotaSnapshot: mcpEnabled
        )

        XCTAssertEqual(mcpBlocked.rejectionReason, .experimentalProviderDisabled(.mcp))
        XCTAssertTrue(mcpExecutable.isExecutable)
        XCTAssertEqual(mcpExecutable.envelope?.providerFamily, .mcp)
    }

    private func resolvedSearchAPI() throws -> (
        request: SearchProviderRequest,
        decision: SearchProviderDecision
    ) {
        let draft = SearchResultDraft(
            sourceURL: try publicURL(host: "example.com", path: "/ramen"),
            title: "Late-night ramen",
            snippet: "Open public listing with hours.",
            attribution: "example.com",
            confidence: 0.82
        )
        let request = SearchProviderRequest(
            traceID: "a12-search",
            query: "late night ramen",
            membershipTier: .plus,
            preferredProvider: .searchAPI,
            meteredProviderEntitlements: [.searchAPI],
            freshness: .livePreferred,
            resultDraft: draft,
            now: now
        )
        let decision = SearchProviderPolicy.evaluate(request)
        XCTAssertTrue(decision.isResolved)
        XCTAssertEqual(decision.selectedProvider?.family, .searchAPI)
        return (request, decision)
    }

    private func resolvedCrawler() throws -> (
        request: SearchProviderRequest,
        decision: SearchProviderDecision
    ) {
        let draft = SearchResultDraft(
            sourceURL: try publicURL(host: "public.example.com", path: "/menu"),
            title: "Menu",
            snippet: "Public menu fixture.",
            attribution: "public.example.com",
            confidence: 0.77
        )
        let request = SearchProviderRequest(
            traceID: "a12-crawler",
            query: "public menu",
            capability: .crawlerFetch,
            membershipTier: .pro,
            preferredProvider: .crawler,
            meteredProviderEntitlements: [.crawler],
            enabledExperimentalProviders: [.crawler],
            freshness: .liveRequired,
            robotsState: .allowed,
            resultDraft: draft,
            now: now
        )
        let decision = SearchProviderPolicy.evaluate(request)
        XCTAssertTrue(decision.isResolved)
        XCTAssertEqual(decision.selectedProvider?.family, .crawler)
        return (request, decision)
    }

    private func allowedMCPReadDecision(
        profile: ProviderAccessProfile
    ) -> (
        request: MCPGatewayRequest,
        decision: MCPGatewayDecision
    ) {
        let request = profile.mcpGatewayRequest(
            traceID: "a45-mcp-read",
            serverID: "calendar",
            operation: .tool(
                MCPToolDescriptor(
                    serverID: "calendar",
                    toolID: "read_events",
                    displayName: "Read events",
                    riskClasses: [.read],
                    isReadOnlyHint: true
                )
            )
        )
        let decision = MCPGatewayPolicy.authorize(
            request,
            registry: [
                MCPServerDescriptor(
                    serverID: "calendar",
                    displayName: "Calendar MCP",
                    isEnabled: true,
                    descriptorTrust: .known,
                    allowedToolIDs: ["read_events"],
                    allowedResourceIDs: []
                ),
            ]
        )
        XCTAssertTrue(decision.isAllowed)
        return (request, decision)
    }

    private func remoteQuota(for family: ProviderFamily) -> ServerProviderQuotaSnapshot {
        ServerProviderQuotaSnapshot(
            allowedProviderFamilies: [family],
            entitledProviderFamilies: [family],
            remainingIncludedQuota: [family: 1],
            meteredEligibleProviderFamilies: [family],
            enabledExperimentalProviderFamilies: [family]
        )
    }

    private func publicURL(host: String, path: String) throws -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        return try XCTUnwrap(components.url)
    }
}
