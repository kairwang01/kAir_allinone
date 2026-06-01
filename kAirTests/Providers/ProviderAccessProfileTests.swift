//
//  ProviderAccessProfileTests.swift
//  kAirTests
//
//  A31/A32 provider-access profile contract: membership/cost/provider defaults
//  become provider/search/MCP request values without adding provider runtimes.
//

import XCTest
@testable import kAir

final class ProviderAccessProfileTests: XCTestCase {
    func test_freeLocalDefault_routesMapPlaceAndRouteToAppleLocalWithoutMeteredEntitlement() {
        let profile = ProviderAccessProfile.freeLocalDefault

        XCTAssertEqual(profile.membershipTier, .free)
        XCTAssertTrue(profile.meteredProviderEntitlements.isEmpty)

        for capability in [ProviderCapability.mapDisplay, .placeSearch, .routePlanning] {
            let request = profile.providerRequest(
                traceID: "free-local-\(capability.rawValue)",
                capability: capability,
                regionOverride: .northAmerica
            )
            let selection = ProviderRoutingPolicy.select(for: request)

            XCTAssertEqual(selection.provider?.family, .appleLocal)
            XCTAssertEqual(selection.provider?.costClass, .freeLocal)
            XCTAssertEqual(selection.trace.membershipTier, .free)
        }
    }

    func test_freeLocalProfile_canRouteToCacheFallbackWithoutMeteredEntitlement() {
        let profile = ProviderAccessProfile(
            membershipTier: .free,
            defaultRegion: .northAmerica,
            preferredProvider: .googleMaps,
            unavailableProviders: [.appleLocal]
        )
        let request = profile.providerRequest(capability: .routePlanning)
        let selection = ProviderRoutingPolicy.select(for: request)

        XCTAssertTrue(request.meteredProviderEntitlements.isEmpty)
        XCTAssertEqual(selection.provider?.family, .cache)
        XCTAssertTrue(
            selection.skippedProviders.contains {
                $0.family == .googleMaps && $0.reason == .blockedByCost
            }
        )
    }

    func test_plusChinaGaodeProfile_prefersGaodeForChinaRouteAndLocalService() {
        let profile = ProviderAccessProfile.plusChinaGaode

        for capability in [ProviderCapability.routePlanning, .localServiceSearch] {
            let request = profile.providerRequest(
                traceID: "gaode-\(capability.rawValue)",
                capability: capability
            )
            let selection = ProviderRoutingPolicy.select(for: request)

            XCTAssertEqual(request.region, .china)
            XCTAssertEqual(request.preferredProvider, .gaode)
            XCTAssertEqual(selection.provider?.family, .gaode)
            XCTAssertEqual(selection.provider?.costClass, .includedQuota)
            XCTAssertTrue(request.meteredProviderEntitlements.isEmpty)
        }
    }

    func test_googlePreferenceWithoutEntitlement_isCostBlockedAndFallsBackLocal() {
        let profile = ProviderAccessProfile(
            membershipTier: .pro,
            defaultRegion: .northAmerica,
            preferredProvider: .googleMaps
        )
        let request = profile.providerRequest(
            capability: .placeSearch,
            freshness: .livePreferred
        )
        let selection = ProviderRoutingPolicy.select(for: request)

        XCTAssertEqual(request.preferredProvider, .googleMaps)
        XCTAssertTrue(request.meteredProviderEntitlements.isEmpty)
        XCTAssertEqual(selection.provider?.family, .appleLocal)
        XCTAssertTrue(
            selection.skippedProviders.contains {
                $0.family == .googleMaps && $0.reason == .blockedByCost
            }
        )
    }

    func test_googleEntitledProfile_selectsGoogleMaps() {
        let profile = ProviderAccessProfile.googleEntitled(membershipTier: .pro)
        let request = profile.providerRequest(
            capability: .placeSearch,
            freshness: .livePreferred
        )
        let selection = ProviderRoutingPolicy.select(for: request)

        XCTAssertEqual(request.membershipTier, .pro)
        XCTAssertEqual(request.preferredProvider, .googleMaps)
        XCTAssertEqual(request.meteredProviderEntitlements, [.googleMaps])
        XCTAssertEqual(selection.provider?.family, .googleMaps)
        XCTAssertEqual(selection.provider?.costClass, .meteredPremium)
    }

    func test_healthPrivacyStillBlocksRemoteProviderWithEntitlement() {
        let profile = ProviderAccessProfile.googleEntitled(membershipTier: .pro)
        let request = profile.providerRequest(
            capability: .routePlanning,
            privacyClass: .health
        )
        let selection = ProviderRoutingPolicy.select(for: request)

        XCTAssertEqual(request.privacyClass, .health)
        XCTAssertEqual(request.meteredProviderEntitlements, [.googleMaps])
        XCTAssertEqual(selection.provider?.family, .appleLocal)
        XCTAssertTrue(
            selection.skippedProviders.contains {
                $0.family == .googleMaps && $0.reason == .blockedByPrivacy
            }
        )
    }

    func test_crawlerAndMCPRemainDisabledUnlessProfileEnablesExperimentalProvider() {
        let crawler = experimentalDescriptor(family: .crawler, capability: .crawlerFetch)
        let mcp = experimentalDescriptor(family: .mcp, capability: .mcpTool)
        let disabledCrawlerProfile = ProviderAccessProfile.developerInternalDiagnostics(
            preferredProvider: .crawler,
            enabledExperimentalProviders: []
        )
        let enabledCrawlerProfile = ProviderAccessProfile.developerInternalDiagnostics(
            preferredProvider: .crawler,
            enabledExperimentalProviders: [.crawler]
        )
        let disabledMCPProfile = ProviderAccessProfile.developerInternalDiagnostics(
            preferredProvider: .mcp,
            enabledExperimentalProviders: []
        )
        let enabledMCPProfile = ProviderAccessProfile.developerInternalDiagnostics(
            preferredProvider: .mcp,
            enabledExperimentalProviders: [.mcp]
        )

        let blockedCrawler = ProviderRoutingPolicy.select(
            for: disabledCrawlerProfile.providerRequest(capability: .crawlerFetch),
            registry: [crawler]
        )
        let allowedCrawler = ProviderRoutingPolicy.select(
            for: enabledCrawlerProfile.providerRequest(capability: .crawlerFetch),
            registry: [crawler]
        )
        let blockedMCP = ProviderRoutingPolicy.select(
            for: disabledMCPProfile.providerRequest(capability: .mcpTool),
            registry: [mcp]
        )
        let allowedMCP = ProviderRoutingPolicy.select(
            for: enabledMCPProfile.providerRequest(capability: .mcpTool),
            registry: [mcp]
        )

        XCTAssertNil(blockedCrawler.provider)
        XCTAssertEqual(blockedCrawler.failureReason, .disabledByDefault)
        XCTAssertEqual(allowedCrawler.provider?.family, .crawler)
        XCTAssertNil(blockedMCP.provider)
        XCTAssertEqual(blockedMCP.failureReason, .disabledByDefault)
        XCTAssertEqual(allowedMCP.provider?.family, .mcp)
    }

    func test_cacheFallbackDisabled_isPreservedInGeneratedProviderRequest() {
        let profile = ProviderAccessProfile(
            membershipTier: .free,
            defaultRegion: .northAmerica,
            preferredProvider: .googleMaps,
            unavailableProviders: [.appleLocal],
            allowCacheFallback: false
        )
        let request = profile.providerRequest(capability: .routePlanning)
        let selection = ProviderRoutingPolicy.select(for: request)

        XCTAssertFalse(request.allowCacheFallback)
        XCTAssertNil(selection.provider)
        XCTAssertEqual(selection.failureReason, .blockedByCost)
        XCTAssertTrue(
            selection.skippedProviders.contains {
                $0.family == .cache && $0.reason == .cacheFallbackDisabled
            }
        )
    }

    func test_profileRoundTripsThroughCodableAndHashable() throws {
        let profile = ProviderAccessProfile(
            membershipTier: .pro,
            defaultRegion: .europe,
            preferredProvider: .googleMaps,
            meteredProviderEntitlements: [.googleMaps, .searchAPI],
            enabledExperimentalProviders: [.crawler],
            unavailableProviders: [.appleLocal],
            allowCacheFallback: false
        )

        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(ProviderAccessProfile.self, from: data)
        let set: Set<ProviderAccessProfile> = [profile, decoded]

        XCTAssertEqual(decoded, profile)
        XCTAssertEqual(set.count, 1)
    }

    private func experimentalDescriptor(
        family: ProviderFamily,
        capability: ProviderCapability
    ) -> MapProviderDescriptor {
        MapProviderDescriptor(
            providerID: "\(family.rawValue)-fixture",
            displayName: "\(family.rawValue) Fixture",
            family: family,
            supportedRegions: [.global],
            supportedCapabilities: [capability],
            minimumMembership: .pro,
            costClass: .meteredPremium,
            attributionRequired: true,
            supportsNativeSDK: false,
            supportsWebService: true,
            supportsExternalHandoff: false,
            cachePolicy: .noCache,
            priority: 1
        )
    }

    func test_freeLocalProfileBuildsSearchRequestWithoutMeteredOrCrawlerAccess() throws {
        let profile = ProviderAccessProfile.freeLocalDefault
        let request = profile.searchProviderRequest(
            traceID: "free-search",
            query: "late night ramen",
            resultDraft: try publicSearchDraft()
        )
        let decision = SearchProviderPolicy.evaluate(request)

        XCTAssertEqual(request.membershipTier, .free)
        XCTAssertNil(request.preferredProvider)
        XCTAssertTrue(request.meteredProviderEntitlements.isEmpty)
        XCTAssertTrue(request.enabledExperimentalProviders.isEmpty)
        XCTAssertNil(decision.result)
        XCTAssertEqual(decision.failureReason, .costBlocked)
        XCTAssertTrue(
            decision.skippedProviders.contains {
                $0.family == .searchAPI && $0.reason == .costBlocked
            }
        )
        XCTAssertTrue(
            decision.skippedProviders.contains {
                $0.family == .crawler && $0.reason == .unsupportedCapability
            }
        )
    }

    func test_searchEntitledProfileBuildsRequestThatPassesCostGate() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_100)
        let profile = ProviderAccessProfile(
            membershipTier: .plus,
            defaultRegion: .northAmerica,
            preferredProvider: .searchAPI,
            meteredProviderEntitlements: [.searchAPI]
        )
        let request = profile.searchProviderRequest(
            traceID: "search-entitled",
            query: "coffee nearby",
            freshness: .livePreferred,
            resultDraft: try publicSearchDraft(title: "Coffee nearby"),
            now: now
        )
        let decision = SearchProviderPolicy.evaluate(request)

        XCTAssertEqual(request.membershipTier, .plus)
        XCTAssertEqual(request.preferredProvider, .searchAPI)
        XCTAssertEqual(request.meteredProviderEntitlements, [.searchAPI])
        XCTAssertTrue(decision.isResolved)
        XCTAssertEqual(decision.selectedProvider?.family, .searchAPI)
        XCTAssertEqual(decision.result?.title, "Coffee nearby")
        XCTAssertEqual(decision.result?.fetchedAt, now)
        XCTAssertEqual(decision.trace.membershipTier, .plus)
    }

    func test_crawlerSearchRequestRequiresProfileEnablementRobotsAndSourcePolicy() throws {
        let blockedProfile = ProviderAccessProfile.developerInternalDiagnostics(
            preferredProvider: .crawler,
            enabledExperimentalProviders: []
        )
        let enabledProfile = ProviderAccessProfile.developerInternalDiagnostics(
            preferredProvider: .crawler,
            enabledExperimentalProviders: [.crawler]
        )

        let disabled = SearchProviderPolicy.evaluate(
            blockedProfile.searchProviderRequest(
                query: "menu",
                capability: .crawlerFetch,
                robotsState: .allowed,
                resultDraft: try publicSearchDraft()
            )
        )
        let robotsBlocked = SearchProviderPolicy.evaluate(
            enabledProfile.searchProviderRequest(
                query: "menu",
                capability: .crawlerFetch,
                robotsState: .disallowed,
                resultDraft: try publicSearchDraft()
            )
        )
        let sourceDenied = SearchProviderPolicy.evaluate(
            enabledProfile.searchProviderRequest(
                query: "app listing",
                capability: .crawlerFetch,
                robotsState: .allowed,
                resultDraft: try appleSearchDraft()
            )
        )
        let allowed = SearchProviderPolicy.evaluate(
            enabledProfile.searchProviderRequest(
                query: "menu",
                capability: .crawlerFetch,
                freshness: .liveRequired,
                robotsState: .allowed,
                resultDraft: try publicSearchDraft()
            )
        )

        XCTAssertEqual(disabled.failureReason, .disabledByDefault)
        XCTAssertEqual(robotsBlocked.failureReason, .robotsBlocked)
        XCTAssertEqual(sourceDenied.failureReason, .sourceDenied)
        XCTAssertTrue(allowed.isResolved)
        XCTAssertEqual(allowed.selectedProvider?.family, .crawler)
        XCTAssertEqual(allowed.result?.freshness, .liveRequired)
    }

    func test_healthPrivacyStillBlocksRemoteSearchWithEntitlementAndExperimentalAccess() throws {
        let profile = ProviderAccessProfile(
            membershipTier: .developerInternal,
            defaultRegion: .global,
            preferredProvider: .crawler,
            meteredProviderEntitlements: [.searchAPI, .crawler],
            enabledExperimentalProviders: [.crawler]
        )
        let request = profile.searchProviderRequest(
            query: "health adjacent public listing",
            capability: .crawlerFetch,
            privacyClass: .health,
            robotsState: .allowed,
            resultDraft: try publicSearchDraft()
        )
        let decision = SearchProviderPolicy.evaluate(request)

        XCTAssertEqual(request.privacyClass, .health)
        XCTAssertEqual(request.enabledExperimentalProviders, [.crawler])
        XCTAssertNil(decision.result)
        XCTAssertEqual(decision.failureReason, .privacyBlocked)
        XCTAssertEqual(decision.trace.costClass, .blockedByPrivacy)
    }

    func test_mcpGatewayRequestCarriesMembershipPrivacyAndAllowsReadOnlyTool() {
        let profile = ProviderAccessProfile.plusChinaGaode
        let server = enabledMCPServer(allowedToolIDs: ["read-events"])
        let request = profile.mcpGatewayRequest(
            traceID: "mcp-read-profile",
            serverID: "calendar",
            operation: .tool(readTool(serverID: "calendar")),
            privacyClass: .general
        )
        let decision = MCPGatewayPolicy.authorize(request, registry: [server])

        XCTAssertEqual(request.membershipTier, .plus)
        XCTAssertEqual(request.privacyClass, .general)
        XCTAssertTrue(decision.isAllowed)
        XCTAssertEqual(decision.audit.trace.membershipTier, .plus)
        XCTAssertEqual(decision.audit.trace.privacyClass, .general)
    }

    func test_mcpGatewayRequestKeepsConfirmationAtCallSite() {
        let profile = ProviderAccessProfile.developerInternalDiagnostics()
        let server = enabledMCPServer(allowedToolIDs: ["delete-event"])
        let destructive = destructiveTool(serverID: "calendar")

        let blocked = MCPGatewayPolicy.authorize(
            profile.mcpGatewayRequest(
                serverID: "calendar",
                operation: .tool(destructive)
            ),
            registry: [server]
        )
        let confirmation = MCPConfirmationArtifact(
            id: "confirm-delete",
            confirmedAt: Date(timeIntervalSince1970: 1_800_000_101),
            confirmedRiskClasses: [.write]
        )
        let allowed = MCPGatewayPolicy.authorize(
            profile.mcpGatewayRequest(
                serverID: "calendar",
                operation: .tool(destructive),
                confirmationArtifact: confirmation
            ),
            registry: [server]
        )

        XCTAssertFalse(blocked.isAllowed)
        XCTAssertTrue(blocked.requiresConfirmation)
        XCTAssertEqual(blocked.denialReason, .confirmationRequired)
        XCTAssertTrue(allowed.isAllowed)
        XCTAssertEqual(allowed.audit.trace.membershipTier, .developerInternal)
        XCTAssertEqual(allowed.audit.riskClasses, [.write])
    }

    func test_mcpGatewayRequestPreservesHealthBlockingInPolicy() {
        let profile = ProviderAccessProfile.developerInternalDiagnostics()
        let server = enabledMCPServer(
            allowedToolIDs: [],
            allowedResourceIDs: ["health-summary"],
            allowedPromptIDs: ["health-review"]
        )
        let resource = MCPResourceDescriptor(
            serverID: "calendar",
            resourceID: "health-summary",
            displayName: "Health Summary",
            domain: .health
        )
        let prompt = MCPPromptDescriptor(
            serverID: "calendar",
            promptID: "health-review",
            displayName: "Health Review",
            argumentNames: ["metric"],
            domain: .health,
            requiresUserReview: false
        )

        let resourceDecision = MCPGatewayPolicy.authorize(
            profile.mcpGatewayRequest(
                serverID: "calendar",
                operation: .resource(resource),
                privacyClass: .health
            ),
            registry: [server]
        )
        let promptDecision = MCPGatewayPolicy.authorize(
            profile.mcpGatewayRequest(
                serverID: "calendar",
                operation: .prompt(prompt),
                privacyClass: .health
            ),
            registry: [server]
        )

        XCTAssertEqual(resourceDecision.denialReason, .healthResourceBlocked)
        XCTAssertEqual(promptDecision.denialReason, .healthPromptBlocked)
        XCTAssertEqual(resourceDecision.audit.trace.failureReason, .blockedByPrivacy)
        XCTAssertEqual(promptDecision.audit.trace.failureReason, .blockedByPrivacy)
    }

    private func publicSearchDraft(
        title: String = "Public listing"
    ) throws -> SearchResultDraft {
        SearchResultDraft(
            sourceURL: try XCTUnwrap(URL(string: "https://example.com/listing")),
            title: title,
            snippet: "Public listing fixture.",
            attribution: "example.com",
            confidence: 0.78
        )
    }

    private func appleSearchDraft() throws -> SearchResultDraft {
        SearchResultDraft(
            sourceURL: try XCTUnwrap(URL(string: "https://apps.apple.com/app/example")),
            title: "App Store listing",
            snippet: "Denied source fixture.",
            attribution: "apps.apple.com",
            confidence: 0.9
        )
    }

    private func enabledMCPServer(
        allowedToolIDs: Set<String>,
        allowedResourceIDs: Set<String> = [],
        allowedPromptIDs: Set<String> = []
    ) -> MCPServerDescriptor {
        MCPServerDescriptor(
            serverID: "calendar",
            displayName: "Calendar MCP",
            isEnabled: true,
            descriptorTrust: .known,
            allowedToolIDs: allowedToolIDs,
            allowedResourceIDs: allowedResourceIDs,
            allowedPromptIDs: allowedPromptIDs
        )
    }

    private func readTool(serverID: String) -> MCPToolDescriptor {
        MCPToolDescriptor(
            serverID: serverID,
            toolID: "read-events",
            displayName: "Read Events",
            riskClasses: [.read],
            isReadOnlyHint: true
        )
    }

    private func destructiveTool(serverID: String) -> MCPToolDescriptor {
        MCPToolDescriptor(
            serverID: serverID,
            toolID: "delete-event",
            displayName: "Delete Event",
            riskClasses: [.write],
            isReadOnlyHint: false
        )
    }
}
