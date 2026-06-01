//
//  ProviderStatusBadgeModelTests.swift
//  kAirTests
//
//  A5f provider/cost/freshness status binding. These tests verify the pure
//  badge view-model mapping without changing RecommendationRail layout.
//

import XCTest
@testable import kAir

@MainActor
final class ProviderStatusBadgeModelTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func test_freeLocalProviderMapsToTruthfulPositiveLocalBadges() {
        let item = recommendation(
            from: ResultProjector.project(
                providerSelection: ProviderRoutingPolicy.select(
                    for: ProviderRequest(
                        traceID: "status-local",
                        capability: .routePlanning,
                        region: .northAmerica,
                        membershipTier: .free
                    )
                ),
                createdAt: now
            )
        )

        let presentation = ProviderStatusBadgeResolver.presentation(for: item)

        XCTAssertEqual(presentation.cardHint, .normal)
        XCTAssertEqual(badge(.localProvider, in: presentation)?.tone, .positive)
        XCTAssertEqual(badge(.freeLocal, in: presentation)?.tone, .positive)
        XCTAssertTrue(presentation.statusLine.contains("apple-local"))
        XCTAssertTrue(presentation.statusLine.contains(ProviderCostClass.freeLocal.rawValue))
        XCTAssertTrue(presentation.statusLine.contains(ProviderFreshness.cachedOK.rawValue))
    }

    func test_meteredPremiumProviderMapsToNeutralCostAndRemoteProvider() throws {
        let item = recommendation(
            from: ResultProjector.project(
                searchDecision: SearchProviderPolicy.evaluate(
                    SearchProviderRequest(
                        traceID: "status-premium",
                        query: "public cafe hours",
                        membershipTier: .plus,
                        preferredProvider: .searchAPI,
                        meteredProviderEntitlements: [.searchAPI],
                        freshness: .livePreferred,
                        resultDraft: SearchResultDraft(
                            sourceURL: try XCTUnwrap(URL(string: "https://example.com/cafe")),
                            title: "Cafe hours",
                            snippet: "Public cafe hours.",
                            attribution: "example.com",
                            confidence: 0.8
                        ),
                        now: now
                    )
                ),
                createdAt: now
            )
        )

        let presentation = ProviderStatusBadgeResolver.presentation(for: item)

        XCTAssertEqual(presentation.cardHint, .normal)
        XCTAssertEqual(badge(.remoteProvider, in: presentation)?.tone, .neutral)
        XCTAssertEqual(badge(.meteredPremium, in: presentation)?.tone, .neutral)
        XCTAssertEqual(badge(.liveFreshness, in: presentation)?.tone, .positive)
        XCTAssertTrue(presentation.statusLine.contains("search-api"))
        XCTAssertTrue(presentation.statusLine.contains(ProviderCostClass.meteredPremium.rawValue))
    }

    func test_staleCacheMapsToWarningAndNeverPositive() throws {
        let cached = SearchResultEnvelope(
            query: "brunch",
            providerID: "previous-search-api",
            sourceURL: try XCTUnwrap(URL(string: "https://example.com/brunch")),
            title: "Brunch listing",
            snippet: "Cached public result.",
            fetchedAt: Date(timeIntervalSince1970: 1_700_000_000),
            freshness: .cachedOK,
            costClass: .meteredPremium,
            confidence: 0.61,
            limitations: ["Older public listing."],
            attribution: "example.com"
        )
        let item = recommendation(
            from: ResultProjector.project(
                searchDecision: SearchProviderPolicy.evaluate(
                    SearchProviderRequest(
                        traceID: "status-cache",
                        query: "brunch",
                        membershipTier: .free,
                        preferredProvider: .searchAPI,
                        cachedResult: cached,
                        now: now
                    )
                ),
                createdAt: now
            )
        )

        let presentation = ProviderStatusBadgeResolver.presentation(for: item)

        XCTAssertEqual(presentation.cardHint, .normal)
        XCTAssertEqual(badge(.cacheProvider, in: presentation)?.tone, .neutral)
        XCTAssertEqual(badge(.staleCache, in: presentation)?.tone, .warning)
        XCTAssertFalse(presentation.badges.contains { $0.tone == .positive })
        XCTAssertEqual(presentation.statusLine, SearchProviderPolicy.staleCacheLimitation)
    }

    func test_privacyBlockedMapsToWarningDisabledStatus() throws {
        let item = recommendation(
            from: ResultProjector.project(
                searchDecision: SearchProviderPolicy.evaluate(
                    SearchProviderRequest(
                        traceID: "status-privacy-blocked",
                        query: "private note",
                        privacyClass: .private,
                        membershipTier: .pro,
                        preferredProvider: .searchAPI,
                        meteredProviderEntitlements: [.searchAPI],
                        resultDraft: SearchResultDraft(
                            sourceURL: try XCTUnwrap(URL(string: "https://example.com/private")),
                            title: "Private result",
                            snippet: "Should be blocked.",
                            attribution: "example.com",
                            confidence: 0.7
                        ),
                        now: now
                    )
                ),
                createdAt: now
            )
        )

        let presentation = ProviderStatusBadgeResolver.presentation(for: item)

        XCTAssertEqual(presentation.cardHint, .disabled)
        XCTAssertEqual(badge(.privacyBlocked, in: presentation)?.tone, .warning)
        XCTAssertFalse(presentation.badges.contains { $0.tone == .positive })
        XCTAssertTrue(item.object.activationPrompt.isEmpty)
    }

    func test_mcpBlockedMapsToWarningDisabledStatus() {
        let decision = MCPGatewayPolicy.authorize(
            MCPGatewayRequest(
                traceID: "status-mcp-blocked",
                serverID: "unknown",
                operation: .tool(
                    MCPToolDescriptor(
                        serverID: "unknown",
                        toolID: "read-events",
                        displayName: "Read Events",
                        riskClasses: [.read],
                        isReadOnlyHint: true
                    )
                )
            ),
            registry: []
        )
        let item = recommendation(from: ResultProjector.project(mcpDecision: decision))

        let presentation = ProviderStatusBadgeResolver.presentation(for: item)

        XCTAssertEqual(presentation.cardHint, .disabled)
        XCTAssertEqual(badge(.termsBlocked, in: presentation)?.tone, .warning)
        XCTAssertFalse(presentation.badges.contains { $0.tone == .positive })
        XCTAssertEqual(item.object.primaryCTA, "Unavailable")
        XCTAssertTrue(presentation.statusLine.contains("MCP operation was not executed"))
    }

    func test_dryRunLocalFallbackMapsToNormalLocalStatus() {
        let dryRun = dryRunPresentation(
            capabilityLabel: "Route planning",
            candidates: [
                ServerProviderDryRunCandidate(
                    id: "google-blocked",
                    displayName: "Google Maps",
                    result: .blocked(.meteredEligibilityMissing(.googleMaps))
                ),
                ServerProviderDryRunCandidate(
                    id: "apple-local",
                    displayName: "Apple Local",
                    result: executableResult(
                        traceID: "dry-local",
                        providerFamily: .appleLocal,
                        capability: .routePlanning,
                        costClass: .freeLocal,
                        freshness: .livePreferred
                    )
                ),
            ]
        )

        let presentation = ProviderStatusBadgeResolver.presentation(
            recommendationID: "dry-local",
            for: dryRun
        )

        XCTAssertEqual(presentation.cardHint, .normal)
        XCTAssertEqual(badge(.localProvider, in: presentation)?.tone, .positive)
        XCTAssertEqual(badge(.freeLocal, in: presentation)?.tone, .positive)
        XCTAssertEqual(badge(.liveFreshness, in: presentation)?.tone, .positive)
        XCTAssertTrue(presentation.statusLine.contains("Local fallback"))
        XCTAssertTrue(presentation.statusLine.contains("Remote cost or privacy policy blocked"))
        XCTAssertTrue(presentation.statusLine.contains("No provider was contacted"))
    }

    func test_dryRunIncludedQuotaMapsToNormalStatus() {
        let dryRun = dryRunPresentation(
            capabilityLabel: "Local service lookup",
            requiredFreshness: .livePreferred,
            candidates: [
                ServerProviderDryRunCandidate(
                    id: "gaode",
                    displayName: "Gaode",
                    result: executableResult(
                        traceID: "dry-gaode",
                        providerFamily: .gaode,
                        capability: .localServiceSearch,
                        costClass: .includedQuota,
                        freshness: .livePreferred,
                        entitlements: [.gaode]
                    )
                ),
            ]
        )

        let presentation = ProviderStatusBadgeResolver.presentation(
            recommendationID: "dry-included",
            for: dryRun
        )

        XCTAssertEqual(presentation.cardHint, .normal)
        XCTAssertEqual(badge(.remoteProvider, in: presentation)?.tone, .neutral)
        XCTAssertEqual(badge(.includedQuota, in: presentation)?.tone, .neutral)
        XCTAssertEqual(badge(.liveFreshness, in: presentation)?.tone, .positive)
        XCTAssertTrue(presentation.statusLine.contains("included quota"))
        XCTAssertTrue(presentation.statusLine.contains("included provider quota"))
    }

    func test_dryRunMeteredPremiumMapsToWarningStatus() {
        let dryRun = dryRunPresentation(
            capabilityLabel: "Public search",
            requiredFreshness: .livePreferred,
            candidates: [
                ServerProviderDryRunCandidate(
                    id: "search-api",
                    displayName: "Search API",
                    result: executableResult(
                        traceID: "dry-metered",
                        providerFamily: .searchAPI,
                        capability: .webSearch,
                        costClass: .meteredPremium,
                        freshness: .livePreferred,
                        sourcePolicy: ServerSourcePolicy(
                            sourceState: .passed,
                            robotsState: .notApplicable,
                            attributionRequired: true,
                            sourceHost: "example.com"
                        ),
                        entitlements: [.searchAPI]
                    )
                ),
            ]
        )

        let presentation = ProviderStatusBadgeResolver.presentation(
            recommendationID: "dry-metered",
            for: dryRun
        )

        XCTAssertEqual(presentation.cardHint, .warning)
        XCTAssertEqual(badge(.remoteProvider, in: presentation)?.tone, .neutral)
        XCTAssertEqual(badge(.meteredPremium, in: presentation)?.tone, .neutral)
        XCTAssertTrue(presentation.statusLine.contains("premium metered"))
        XCTAssertTrue(presentation.statusLine.contains("example.com"))
    }

    func test_dryRunStaleCacheRejectionMapsToWarningStatus() {
        let dryRun = dryRunPresentation(
            capabilityLabel: "Web search",
            requiredFreshness: .liveRequired,
            candidates: [
                ServerProviderDryRunCandidate(
                    id: "cache",
                    displayName: "Local Cache",
                    result: executableResult(
                        traceID: "dry-cache",
                        providerFamily: .cache,
                        capability: .webSearch,
                        costClass: .freeLocal,
                        freshness: .cachedOK
                    )
                ),
            ]
        )

        let presentation = ProviderStatusBadgeResolver.presentation(
            recommendationID: "dry-cache",
            for: dryRun
        )

        XCTAssertEqual(presentation.cardHint, .warning)
        XCTAssertEqual(badge(.cacheProvider, in: presentation)?.tone, .neutral)
        XCTAssertEqual(badge(.staleCache, in: presentation)?.tone, .warning)
        XCTAssertTrue(presentation.statusLine.contains("Stale cache rejected"))
        XCTAssertTrue(presentation.statusLine.contains("live-required"))
    }

    func test_dryRunAllBlockedMapsToDisabledStatusAndPreservesReasons() {
        let dryRun = dryRunPresentation(
            capabilityLabel: "Public lookup",
            candidates: [
                ServerProviderDryRunCandidate(
                    id: "search-api",
                    displayName: "Search API",
                    result: .blocked(.providerNotAllowed(.searchAPI))
                ),
                ServerProviderDryRunCandidate(
                    id: "crawler",
                    displayName: "Crawler",
                    result: .blocked(.sourcePolicyInsufficient)
                ),
            ]
        )

        let presentation = ProviderStatusBadgeResolver.presentation(
            recommendationID: "dry-all-blocked",
            for: dryRun
        )

        XCTAssertEqual(presentation.cardHint, .disabled)
        XCTAssertEqual(badge(.termsBlocked, in: presentation)?.tone, .warning)
        XCTAssertTrue(presentation.statusLine.contains("all provider candidates are blocked"))
        XCTAssertTrue(presentation.statusLine.contains("Search API is not allowed"))
        XCTAssertTrue(presentation.statusLine.contains("Source policy metadata is insufficient"))
    }

    func test_dryRunHealthPrivacyBlockMapsToPrivacyBlockedStatus() {
        let envelope = ServerProviderEnvelope(
            traceID: "dry-health",
            capability: .placeSearch,
            providerFamily: .googleMaps,
            privacyClass: .health,
            membershipTier: .pro,
            costClass: .meteredPremium,
            freshness: .livePreferred,
            meteredProviderEntitlements: [.googleMaps]
        )
        let validation = ServerProviderEnvelopeValidator.validate(envelope)
        let dryRun = dryRunPresentation(
            capabilityLabel: "Health place lookup",
            candidates: [
                ServerProviderDryRunCandidate(
                    id: "health-google",
                    displayName: "Google Maps",
                    result: .blocked(
                        .validatorRejected(.privacyBlocked),
                        validation: validation
                    )
                ),
            ]
        )

        let presentation = ProviderStatusBadgeResolver.presentation(
            recommendationID: "dry-health",
            for: dryRun
        )

        XCTAssertEqual(presentation.cardHint, .disabled)
        XCTAssertEqual(badge(.privacyBlocked, in: presentation)?.tone, .warning)
        XCTAssertFalse(presentation.badges.contains { $0.tone == .positive })
        XCTAssertTrue(presentation.statusLine.contains("Privacy policy blocks"))
        XCTAssertTrue(presentation.statusLine.contains("cannot leave the local policy boundary"))
    }

    func test_dryRunStatusBridgeDoesNotUseCompletedOrActionDoneWording() {
        let dryRuns = [
            dryRunPresentation(
                capabilityLabel: "Route planning",
                candidates: [
                    ServerProviderDryRunCandidate(
                        id: "apple-local",
                        displayName: "Apple Local",
                        result: executableResult(
                            traceID: "dry-copy-local",
                            providerFamily: .appleLocal,
                            capability: .routePlanning,
                            costClass: .freeLocal,
                            freshness: .cachedOK
                        )
                    ),
                ]
            ),
            dryRunPresentation(
                capabilityLabel: "Blocked lookup",
                candidates: [
                    ServerProviderDryRunCandidate(
                        id: "mcp",
                        displayName: "MCP",
                        result: .blocked(.confirmationMissing)
                    ),
                ]
            ),
        ]

        let text = dryRuns
            .map {
                ProviderStatusBadgeResolver.presentation(
                    recommendationID: $0.id,
                    for: $0
                )
            }
            .flatMap { [$0.statusLine] + $0.badges.map(\.label) }
            .joined(separator: "\n")
            .lowercased()

        for forbidden in ["completed", "complete", "done", "called", "booked", "ordered", "paid", "purchased"] {
            XCTAssertFalse(text.contains(forbidden), "Unexpected wording: \(forbidden)")
        }
    }

    func test_searchDryRunProviderStatusStoreSelectedPresentationMapsByRecommendationID() throws {
        let dryRun = dryRunPresentation(
            capabilityLabel: "Public search",
            requiredFreshness: .livePreferred,
            candidates: [
                ServerProviderDryRunCandidate(
                    id: "search-api",
                    displayName: "Search API",
                    result: executableResult(
                        traceID: "search-dry-store-selected",
                        providerFamily: .searchAPI,
                        capability: .webSearch,
                        costClass: .meteredPremium,
                        freshness: .livePreferred,
                        sourcePolicy: ServerSourcePolicy(
                            sourceState: .passed,
                            robotsState: .notApplicable,
                            attributionRequired: true,
                            sourceHost: "example.com"
                        ),
                        entitlements: [.searchAPI]
                    )
                ),
            ]
        )
        let store = SearchDryRunProviderStatusStore(
            presentationsByRecommendationID: ["search-rec": dryRun]
        )

        let presentation = try XCTUnwrap(
            store.providerStatusPresentation(for: "search-rec")
        )

        XCTAssertEqual(store.recommendationIDs, ["search-rec"])
        XCTAssertEqual(presentation.recommendationID, "search-rec")
        XCTAssertEqual(presentation.cardHint, .warning)
        XCTAssertEqual(badge(.remoteProvider, in: presentation)?.tone, .neutral)
        XCTAssertEqual(badge(.meteredPremium, in: presentation)?.tone, .neutral)
        XCTAssertEqual(badge(.liveFreshness, in: presentation)?.tone, .positive)
        XCTAssertTrue(presentation.statusLine.contains("premium metered"))
        XCTAssertTrue(presentation.statusLine.contains("example.com"))
        XCTAssertTrue(presentation.statusLine.contains("No provider was contacted"))
    }

    func test_searchDryRunProviderStatusStoreBlockedPresentationPreservesFactoryRejectionReason() throws {
        let dryRun = dryRunPresentation(
            capabilityLabel: "Public lookup",
            candidates: [
                ServerProviderDryRunCandidate(
                    id: "search-api",
                    displayName: "Search API",
                    result: .blocked(.providerNotAllowed(.searchAPI))
                ),
            ]
        )
        let store = SearchDryRunProviderStatusStore(
            presentations: [(recommendationID: "blocked-search-rec", presentation: dryRun)]
        )

        let presentation = try XCTUnwrap(
            store.providerStatusPresentation(for: "blocked-search-rec")
        )

        XCTAssertEqual(presentation.recommendationID, "blocked-search-rec")
        XCTAssertEqual(presentation.cardHint, .disabled)
        XCTAssertEqual(badge(.termsBlocked, in: presentation)?.tone, .warning)
        XCTAssertTrue(presentation.statusLine.contains("all provider candidates are blocked"))
        XCTAssertTrue(presentation.statusLine.contains("Search API is not allowed"))
        XCTAssertNil(store.providerStatusPresentation(for: "missing-search-rec"))
    }

    func test_searchDryRunProviderStatusStoreMissingIDsReturnNilAndRecommendationIDsAreSorted() {
        let store = SearchDryRunProviderStatusStore(
            presentationsByRecommendationID: [
                "z-rec": dryRunPresentation(
                    capabilityLabel: "Blocked lookup",
                    candidates: [
                        ServerProviderDryRunCandidate(
                            id: "search-api",
                            displayName: "Search API",
                            result: .blocked(.providerNotAllowed(.searchAPI))
                        ),
                    ]
                ),
                "a-rec": dryRunPresentation(
                    capabilityLabel: "Local fallback",
                    candidates: [
                        ServerProviderDryRunCandidate(
                            id: "apple-local",
                            displayName: "Apple Local",
                            result: executableResult(
                                traceID: "search-dry-store-sorted-local",
                                providerFamily: .appleLocal,
                                capability: .routePlanning,
                                costClass: .freeLocal,
                                freshness: .cachedOK
                            )
                        ),
                    ]
                ),
            ]
        )

        XCTAssertEqual(store.recommendationIDs, ["a-rec", "z-rec"])
        XCTAssertNil(store.providerStatusPresentation(for: "missing-rec"))
    }

    func test_searchDryRunProviderStatusStoreTupleInitKeepsFirstPresentationForDuplicateIDs() throws {
        let first = dryRunPresentation(
            capabilityLabel: "First search",
            requiredFreshness: .livePreferred,
            candidates: [
                ServerProviderDryRunCandidate(
                    id: "search-api",
                    displayName: "Search API",
                    result: executableResult(
                        traceID: "search-dry-store-duplicate-first",
                        providerFamily: .searchAPI,
                        capability: .webSearch,
                        costClass: .meteredPremium,
                        freshness: .livePreferred,
                        sourcePolicy: ServerSourcePolicy(
                            sourceState: .passed,
                            robotsState: .notApplicable,
                            attributionRequired: true,
                            sourceHost: "first.example.com"
                        ),
                        entitlements: [.searchAPI]
                    )
                ),
            ]
        )
        let second = dryRunPresentation(
            capabilityLabel: "Second blocked search",
            candidates: [
                ServerProviderDryRunCandidate(
                    id: "search-api",
                    displayName: "Search API",
                    result: .blocked(.providerNotAllowed(.searchAPI))
                ),
            ]
        )
        let store = SearchDryRunProviderStatusStore(
            presentations: [
                (recommendationID: "duplicate-search-rec", presentation: first),
                (recommendationID: "duplicate-search-rec", presentation: second),
            ]
        )

        let presentation = try XCTUnwrap(
            store.providerStatusPresentation(for: "duplicate-search-rec")
        )

        XCTAssertEqual(store.recommendationIDs, ["duplicate-search-rec"])
        XCTAssertEqual(presentation.cardHint, .warning)
        XCTAssertEqual(badge(.remoteProvider, in: presentation)?.tone, .neutral)
        XCTAssertEqual(badge(.meteredPremium, in: presentation)?.tone, .neutral)
        XCTAssertNil(badge(.termsBlocked, in: presentation))
        XCTAssertTrue(presentation.statusLine.contains("first.example.com"))
        XCTAssertFalse(presentation.statusLine.contains("Search API is not allowed"))
    }

    func test_searchDryRunProviderStatusStoreCopyStaysAdvisoryOnly() throws {
        let store = SearchDryRunProviderStatusStore(
            presentations: [
                (
                    recommendationID: "copy-selected",
                    presentation: dryRunPresentation(
                        capabilityLabel: "Public search",
                        requiredFreshness: .livePreferred,
                        candidates: [
                            ServerProviderDryRunCandidate(
                                id: "search-api",
                                displayName: "Search API",
                                result: executableResult(
                                    traceID: "search-dry-store-copy-selected",
                                    providerFamily: .searchAPI,
                                    capability: .webSearch,
                                    costClass: .meteredPremium,
                                    freshness: .livePreferred,
                                    entitlements: [.searchAPI]
                                )
                            ),
                        ]
                    )
                ),
                (
                    recommendationID: "copy-blocked",
                    presentation: dryRunPresentation(
                        capabilityLabel: "Blocked lookup",
                        candidates: [
                            ServerProviderDryRunCandidate(
                                id: "search-api",
                                displayName: "Search API",
                                result: .blocked(.providerNotAllowed(.searchAPI))
                            ),
                        ]
                    )
                ),
            ]
        )
        let presentations = try ["copy-selected", "copy-blocked"].map { id in
            try XCTUnwrap(store.providerStatusPresentation(for: id))
        }
        let text = presentations
            .flatMap { [$0.statusLine] + $0.badges.map(\.label) }
            .joined(separator: "\n")
            .lowercased()

        XCTAssertTrue(text.contains("no provider was contacted"))
        for forbidden in [
            "completed",
            "complete",
            "done",
            "called",
            "booked",
            "ordered",
            "paid",
            "purchased",
            "crawled",
        ] {
            XCTAssertFalse(text.contains(forbidden), "Unexpected wording: \(forbidden)")
        }
    }

    func test_runtimeReceiptFixtureProvidersMapToProviderStatusWithoutExecutionWording() {
        let google = ProviderStatusBadgeResolver.presentation(
            recommendationID: "receipt-google",
            for: runtimeReceipt(
                traceID: "receipt-google",
                providerFamily: .googleMaps,
                capability: .localServiceSearch,
                costClass: .meteredPremium,
                entitlements: [.googleMaps]
            )
        )
        XCTAssertEqual(google.cardHint, .warning)
        XCTAssertEqual(badge(.remoteProvider, in: google)?.tone, .neutral)
        XCTAssertEqual(badge(.meteredPremium, in: google)?.tone, .neutral)
        XCTAssertTrue(google.statusLine.contains("googleMaps"))
        XCTAssertTrue(google.statusLine.contains("No provider runtime has run"))

        let gaode = ProviderStatusBadgeResolver.presentation(
            recommendationID: "receipt-gaode",
            for: runtimeReceipt(
                traceID: "receipt-gaode",
                providerFamily: .gaode,
                capability: .localServiceSearch,
                costClass: .includedQuota,
                entitlements: [.gaode]
            )
        )
        XCTAssertEqual(gaode.cardHint, .normal)
        XCTAssertEqual(badge(.remoteProvider, in: gaode)?.tone, .neutral)
        XCTAssertEqual(badge(.includedQuota, in: gaode)?.tone, .neutral)
        XCTAssertTrue(gaode.statusLine.contains("gaode"))

        let search = ProviderStatusBadgeResolver.presentation(
            recommendationID: "receipt-search",
            for: runtimeReceipt(
                traceID: "receipt-search",
                providerFamily: .searchAPI,
                capability: .webSearch,
                costClass: .meteredPremium,
                sourcePolicy: ServerSourcePolicy(
                    sourceState: .passed,
                    robotsState: .notApplicable,
                    attributionRequired: true,
                    sourceHost: "example.com"
                ),
                entitlements: [.searchAPI]
            )
        )
        XCTAssertEqual(search.cardHint, .warning)
        XCTAssertTrue(search.statusLine.contains("example.com"))
        XCTAssertEqual(badge(.liveFreshness, in: search)?.tone, .positive)

        let crawler = ProviderStatusBadgeResolver.presentation(
            recommendationID: "receipt-crawler",
            for: runtimeReceipt(
                traceID: "receipt-crawler",
                providerFamily: .crawler,
                capability: .crawlerFetch,
                costClass: .meteredPremium,
                sourcePolicy: ServerSourcePolicy(
                    sourceState: .passed,
                    robotsState: .allowed,
                    attributionRequired: true,
                    sourceHost: "public.example.com"
                ),
                entitlements: [.crawler],
                enabledExperimentalProviders: [.crawler]
            )
        )
        XCTAssertEqual(crawler.cardHint, .warning)
        XCTAssertTrue(crawler.statusLine.contains("public.example.com"))
        XCTAssertTrue(crawler.statusLine.contains("robots allowed"))

        let mcp = ProviderStatusBadgeResolver.presentation(
            recommendationID: "receipt-mcp",
            for: runtimeReceipt(
                traceID: "receipt-mcp",
                providerFamily: .mcp,
                capability: .mcpTool,
                costClass: .includedQuota,
                confirmationState: .confirmed(artifactID: "receipt-confirmed"),
                entitlements: [.mcp],
                enabledExperimentalProviders: [.mcp]
            )
        )
        XCTAssertEqual(mcp.cardHint, .normal)
        XCTAssertEqual(badge(.remoteProvider, in: mcp)?.tone, .neutral)
        XCTAssertEqual(badge(.includedQuota, in: mcp)?.tone, .neutral)
        XCTAssertTrue(mcp.statusLine.contains("mcp"))
    }

    func test_runtimeReceiptLocalAndCacheMapToNormalLocalStatus() {
        let local = ProviderStatusBadgeResolver.presentation(
            recommendationID: "receipt-local",
            for: nonFixtureReceipt(
                traceID: "receipt-local",
                providerFamily: .appleLocal,
                capability: .routePlanning,
                costClass: .freeLocal,
                freshness: .cachedOK
            )
        )

        XCTAssertEqual(local.cardHint, .normal)
        XCTAssertEqual(badge(.localProvider, in: local)?.tone, .positive)
        XCTAssertEqual(badge(.freeLocal, in: local)?.tone, .positive)
        XCTAssertTrue(local.statusLine.contains("local-only"))
        XCTAssertTrue(local.statusLine.contains("stays on device"))

        let cache = ProviderStatusBadgeResolver.presentation(
            recommendationID: "receipt-cache",
            for: nonFixtureReceipt(
                traceID: "receipt-cache",
                providerFamily: .cache,
                capability: .webSearch,
                costClass: .freeLocal,
                freshness: .cachedOK
            )
        )

        XCTAssertEqual(cache.cardHint, .normal)
        XCTAssertEqual(badge(.cacheProvider, in: cache)?.tone, .neutral)
        XCTAssertEqual(badge(.freeLocal, in: cache)?.tone, .positive)
        XCTAssertTrue(cache.statusLine.contains("Local cache route"))
    }

    func test_runtimeReceiptBlockedConfirmationAndUnavailableMapToDisabledStatus() throws {
        let blocked = ProviderStatusBadgeResolver.presentation(
            recommendationID: "receipt-blocked",
            for: ServerProviderRuntimeReceiptProjector.project(
                ServerProviderRuntimeAdapterRegistry.resolve(
                    ServerProviderRuntimeDispatcher.prepare(
                        ServerProviderRuntimeInvocationPlanner.makePlan(
                            readinessDecision: try privateBlockedDecision()
                        )
                    )
                )
            )
        )
        XCTAssertEqual(blocked.cardHint, .disabled)
        XCTAssertEqual(badge(.privacyBlocked, in: blocked)?.tone, .warning)
        XCTAssertTrue(blocked.statusLine.contains("privacyBlocked"))

        let confirmation = ProviderStatusBadgeResolver.presentation(
            recommendationID: "receipt-confirmation",
            for: nonFixtureReceipt(
                traceID: "receipt-confirmation",
                providerFamily: .mcp,
                capability: .mcpTool,
                costClass: .includedQuota,
                confirmationState: .requiredMissing,
                entitlements: [.mcp],
                enabledExperimentalProviders: [.mcp]
            )
        )
        XCTAssertEqual(confirmation.cardHint, .disabled)
        XCTAssertEqual(badge(.unavailable, in: confirmation)?.tone, .warning)
        XCTAssertTrue(confirmation.statusLine.contains("Confirmation is required"))

        let base = preparedRuntimeBoundary(
            traceID: "receipt-unregistered",
            providerFamily: .googleMaps,
            capability: .localServiceSearch,
            costClass: .meteredPremium,
            entitlements: [.googleMaps]
        )
        let unregistered = ProviderStatusBadgeResolver.presentation(
            recommendationID: "receipt-unregistered",
            for: ServerProviderRuntimeReceiptProjector.project(
                ServerProviderRuntimeAdapterRegistry.resolve(
                    malformedRuntimeBoundary(from: base, providerFamily: .some(.cache))
                )
            )
        )
        XCTAssertEqual(unregistered.cardHint, .disabled)
        XCTAssertEqual(badge(.unavailable, in: unregistered)?.tone, .warning)
        XCTAssertTrue(unregistered.statusLine.contains("unregisteredProvider"))
    }

    func test_runtimeReceiptDescriptorPlanAndNotPreparedMapToWarningStatus() throws {
        let descriptor = ProviderStatusBadgeResolver.presentation(
            recommendationID: "receipt-descriptor",
            for: try descriptorUnavailableReceipt()
        )
        XCTAssertEqual(descriptor.cardHint, .warning)
        XCTAssertEqual(badge(.unavailable, in: descriptor)?.tone, .warning)
        XCTAssertTrue(descriptor.statusLine.contains("descriptor metadata"))

        let plan = ProviderStatusBadgeResolver.presentation(
            recommendationID: "receipt-plan",
            for: planRejectedReceipt()
        )
        XCTAssertEqual(plan.cardHint, .warning)
        XCTAssertEqual(badge(.unavailable, in: plan)?.tone, .warning)
        XCTAssertTrue(plan.statusLine.contains("rejected plan metadata"))

        let base = preparedRuntimeBoundary(
            traceID: "receipt-not-prepared",
            providerFamily: .googleMaps,
            capability: .localServiceSearch,
            costClass: .meteredPremium,
            entitlements: [.googleMaps]
        )
        let notPrepared = ProviderStatusBadgeResolver.presentation(
            recommendationID: "receipt-not-prepared",
            for: ServerProviderRuntimeReceiptProjector.project(
                ServerProviderRuntimeAdapterRegistry.resolve(
                    malformedRuntimeBoundary(from: base, id: " ")
                )
            )
        )
        XCTAssertEqual(notPrepared.cardHint, .warning)
        XCTAssertEqual(badge(.unavailable, in: notPrepared)?.tone, .warning)
        XCTAssertTrue(notPrepared.statusLine.contains("missingBoundaryID"))
    }

    func test_runtimeReceiptStatusBridgeDoesNotUseCompletedOrActionDoneWording() throws {
        let presentations = [
            ProviderStatusBadgeResolver.presentation(
                recommendationID: "receipt-copy-fixture",
                for: runtimeReceipt(
                    traceID: "receipt-copy-fixture",
                    providerFamily: .googleMaps,
                    capability: .localServiceSearch,
                    costClass: .meteredPremium,
                    entitlements: [.googleMaps]
                )
            ),
            ProviderStatusBadgeResolver.presentation(
                recommendationID: "receipt-copy-local",
                for: nonFixtureReceipt(
                    traceID: "receipt-copy-local",
                    providerFamily: .appleLocal,
                    capability: .routePlanning,
                    costClass: .freeLocal,
                    freshness: .cachedOK
                )
            ),
            ProviderStatusBadgeResolver.presentation(
                recommendationID: "receipt-copy-blocked",
                for: ServerProviderRuntimeReceiptProjector.project(
                    ServerProviderRuntimeAdapterRegistry.resolve(
                        ServerProviderRuntimeDispatcher.prepare(
                            ServerProviderRuntimeInvocationPlanner.makePlan(
                                readinessDecision: try privateBlockedDecision()
                            )
                        )
                    )
                )
            ),
        ]
        let text = presentations
            .flatMap { [$0.statusLine] + $0.badges.map(\.label) }
            .joined(separator: "\n")
            .lowercased()

        for forbidden in [
            "completed",
            "complete",
            "done",
            "called",
            "contacted",
            "fetched",
            "invoked",
            "booked",
            "ordered",
            "paid",
            "purchased",
        ] {
            XCTAssertFalse(text.contains(forbidden), "Unexpected wording: \(forbidden)")
        }
    }

    func test_runtimeReceiptStatusBridgeDoesNotChangeFrozenRailContracts() {
        let presentation = ProviderStatusBadgeResolver.presentation(
            recommendationID: "receipt-contract",
            for: runtimeReceipt(
                traceID: "receipt-contract",
                providerFamily: .searchAPI,
                capability: .webSearch,
                costClass: .meteredPremium,
                sourcePolicy: ServerSourcePolicy(
                    sourceState: .passed,
                    robotsState: .notApplicable,
                    attributionRequired: true,
                    sourceHost: "example.com"
                ),
                entitlements: [.searchAPI]
            )
        )

        XCTAssertEqual(presentation.recommendationID, "receipt-contract")
        XCTAssertEqual(ActionCardTrustPillKind.allCases.count, 7)
        XCTAssertEqual(MatchingObjectKind.allCases.count, 9)
        XCTAssertEqual(RecommendationRail.maxSlateSize, 3)
    }

    func test_runtimeReceiptStatusStoreReturnsPresentationForKnownIDAndNilForUnknownID() throws {
        let store = RuntimeReceiptProviderStatusStore(
            receipts: [
                (
                    recommendationID: "receipt-known",
                    receipt: runtimeReceipt(
                        traceID: "receipt-known",
                        providerFamily: .searchAPI,
                        capability: .webSearch,
                        costClass: .meteredPremium,
                        sourcePolicy: ServerSourcePolicy(
                            sourceState: .passed,
                            robotsState: .notApplicable,
                            attributionRequired: true,
                            sourceHost: "example.com"
                        ),
                        entitlements: [.searchAPI]
                    )
                ),
            ]
        )

        let presentation = try XCTUnwrap(
            store.providerStatusPresentation(for: "receipt-known")
        )

        XCTAssertEqual(store.recommendationIDs, ["receipt-known"])
        XCTAssertEqual(presentation.recommendationID, "receipt-known")
        XCTAssertEqual(presentation.cardHint, .warning)
        XCTAssertEqual(badge(.remoteProvider, in: presentation)?.tone, .neutral)
        XCTAssertEqual(badge(.meteredPremium, in: presentation)?.tone, .neutral)
        XCTAssertTrue(presentation.statusLine.contains("example.com"))
        XCTAssertNil(store.providerStatusPresentation(for: "receipt-missing"))
    }

    func test_runtimeReceiptStatusStoreUsesFirstReceiptForDuplicateRecommendationID() throws {
        let first = nonFixtureReceipt(
            traceID: "receipt-duplicate-local",
            providerFamily: .appleLocal,
            capability: .routePlanning,
            costClass: .freeLocal,
            freshness: .cachedOK
        )
        let second = runtimeReceipt(
            traceID: "receipt-duplicate-google",
            providerFamily: .googleMaps,
            capability: .localServiceSearch,
            costClass: .meteredPremium,
            entitlements: [.googleMaps]
        )
        let store = RuntimeReceiptProviderStatusStore(
            receipts: [
                (recommendationID: "receipt-duplicate", receipt: first),
                (recommendationID: "receipt-duplicate", receipt: second),
            ]
        )

        let presentation = try XCTUnwrap(
            store.providerStatusPresentation(for: "receipt-duplicate")
        )

        XCTAssertEqual(store.recommendationIDs, ["receipt-duplicate"])
        XCTAssertEqual(presentation.cardHint, .normal)
        XCTAssertEqual(badge(.localProvider, in: presentation)?.tone, .positive)
        XCTAssertEqual(badge(.freeLocal, in: presentation)?.tone, .positive)
        XCTAssertNil(badge(.remoteProvider, in: presentation))
        XCTAssertTrue(presentation.statusLine.contains("local-only"))
    }

    func test_runtimeReceiptStatusStoreProjectsFixtureLocalBlockedConfirmationNotPreparedAndUnavailableReceipts() throws {
        let notPreparedBase = preparedRuntimeBoundary(
            traceID: "receipt-store-not-prepared",
            providerFamily: .googleMaps,
            capability: .localServiceSearch,
            costClass: .meteredPremium,
            entitlements: [.googleMaps]
        )
        let unavailableBase = preparedRuntimeBoundary(
            traceID: "receipt-store-unavailable",
            providerFamily: .googleMaps,
            capability: .localServiceSearch,
            costClass: .meteredPremium,
            entitlements: [.googleMaps]
        )
        let store = RuntimeReceiptProviderStatusStore(
            receipts: [
                (
                    recommendationID: "receipt-fixture",
                    receipt: runtimeReceipt(
                        traceID: "receipt-fixture",
                        providerFamily: .googleMaps,
                        capability: .localServiceSearch,
                        costClass: .meteredPremium,
                        entitlements: [.googleMaps]
                    )
                ),
                (
                    recommendationID: "receipt-local",
                    receipt: nonFixtureReceipt(
                        traceID: "receipt-store-local",
                        providerFamily: .appleLocal,
                        capability: .routePlanning,
                        costClass: .freeLocal,
                        freshness: .cachedOK
                    )
                ),
                (
                    recommendationID: "receipt-blocked",
                    receipt: ServerProviderRuntimeReceiptProjector.project(
                        ServerProviderRuntimeAdapterRegistry.resolve(
                            ServerProviderRuntimeDispatcher.prepare(
                                ServerProviderRuntimeInvocationPlanner.makePlan(
                                    readinessDecision: try privateBlockedDecision()
                                )
                            )
                        )
                    )
                ),
                (
                    recommendationID: "receipt-confirmation",
                    receipt: nonFixtureReceipt(
                        traceID: "receipt-store-confirmation",
                        providerFamily: .mcp,
                        capability: .mcpTool,
                        costClass: .includedQuota,
                        confirmationState: .requiredMissing,
                        entitlements: [.mcp],
                        enabledExperimentalProviders: [.mcp]
                    )
                ),
                (
                    recommendationID: "receipt-not-prepared",
                    receipt: ServerProviderRuntimeReceiptProjector.project(
                        ServerProviderRuntimeAdapterRegistry.resolve(
                            malformedRuntimeBoundary(from: notPreparedBase, id: " ")
                        )
                    )
                ),
                (
                    recommendationID: "receipt-unavailable",
                    receipt: ServerProviderRuntimeReceiptProjector.project(
                        ServerProviderRuntimeAdapterRegistry.resolve(
                            malformedRuntimeBoundary(
                                from: unavailableBase,
                                providerFamily: .some(.cache)
                            )
                        )
                    )
                ),
            ]
        )

        let fixture = try XCTUnwrap(store.providerStatusPresentation(for: "receipt-fixture"))
        XCTAssertEqual(fixture.cardHint, .warning)
        XCTAssertEqual(badge(.remoteProvider, in: fixture)?.tone, .neutral)
        XCTAssertEqual(badge(.meteredPremium, in: fixture)?.tone, .neutral)

        let local = try XCTUnwrap(store.providerStatusPresentation(for: "receipt-local"))
        XCTAssertEqual(local.cardHint, .normal)
        XCTAssertEqual(badge(.localProvider, in: local)?.tone, .positive)
        XCTAssertEqual(badge(.freeLocal, in: local)?.tone, .positive)

        let blocked = try XCTUnwrap(store.providerStatusPresentation(for: "receipt-blocked"))
        XCTAssertEqual(blocked.cardHint, .disabled)
        XCTAssertEqual(badge(.privacyBlocked, in: blocked)?.tone, .warning)

        let confirmation = try XCTUnwrap(
            store.providerStatusPresentation(for: "receipt-confirmation")
        )
        XCTAssertEqual(confirmation.cardHint, .disabled)
        XCTAssertEqual(badge(.unavailable, in: confirmation)?.tone, .warning)

        let notPrepared = try XCTUnwrap(
            store.providerStatusPresentation(for: "receipt-not-prepared")
        )
        XCTAssertEqual(notPrepared.cardHint, .warning)
        XCTAssertEqual(badge(.unavailable, in: notPrepared)?.tone, .warning)
        XCTAssertTrue(notPrepared.statusLine.contains("missingBoundaryID"))

        let unavailable = try XCTUnwrap(
            store.providerStatusPresentation(for: "receipt-unavailable")
        )
        XCTAssertEqual(unavailable.cardHint, .disabled)
        XCTAssertEqual(badge(.unavailable, in: unavailable)?.tone, .warning)
        XCTAssertTrue(unavailable.statusLine.contains("unregisteredProvider"))
    }

    func test_runtimeReceiptStatusStoreDoesNotChangeFrozenRailContractsOrMatchingObjectFields() {
        let object = RecommendationFixtures.placeRoute
        let objectBeforeLookup = object
        let store = RuntimeReceiptProviderStatusStore(
            receiptsByRecommendationID: [
                object.id: runtimeReceipt(
                    traceID: "receipt-matching-object",
                    providerFamily: .searchAPI,
                    capability: .webSearch,
                    costClass: .meteredPremium,
                    sourcePolicy: ServerSourcePolicy(
                        sourceState: .passed,
                        robotsState: .notApplicable,
                        attributionRequired: true,
                        sourceHost: "example.com"
                    ),
                    entitlements: [.searchAPI]
                ),
            ]
        )

        _ = store.providerStatusPresentation(for: object.id)

        XCTAssertEqual(ActionCardTrustPillKind.allCases.count, 7)
        XCTAssertEqual(MatchingObjectKind.allCases.count, 9)
        XCTAssertEqual(RecommendationRail.maxSlateSize, 3)
        XCTAssertEqual(object, objectBeforeLookup)
        XCTAssertEqual(object.id, objectBeforeLookup.id)
        XCTAssertEqual(object.kind, objectBeforeLookup.kind)
        XCTAssertEqual(object.title, objectBeforeLookup.title)
        XCTAssertEqual(object.subtitleTokens, objectBeforeLookup.subtitleTokens)
        XCTAssertEqual(object.reasonText, objectBeforeLookup.reasonText)
        XCTAssertEqual(object.primaryCTA, objectBeforeLookup.primaryCTA)
        XCTAssertEqual(object.secondaryCTA, objectBeforeLookup.secondaryCTA)
        XCTAssertEqual(object.activationPrompt, objectBeforeLookup.activationPrompt)
        XCTAssertEqual(object.preferredSection, objectBeforeLookup.preferredSection)
    }

    func test_runtimeReceiptStatusStoreCopyDoesNotUseCompletedOrActionDoneWording() throws {
        let blockedReceipt = ServerProviderRuntimeReceiptProjector.project(
            ServerProviderRuntimeAdapterRegistry.resolve(
                ServerProviderRuntimeDispatcher.prepare(
                    ServerProviderRuntimeInvocationPlanner.makePlan(
                        readinessDecision: try privateBlockedDecision()
                    )
                )
            )
        )
        let unavailableBase = preparedRuntimeBoundary(
            traceID: "receipt-copy-store-unavailable",
            providerFamily: .googleMaps,
            capability: .localServiceSearch,
            costClass: .meteredPremium,
            entitlements: [.googleMaps]
        )
        let store = RuntimeReceiptProviderStatusStore(
            receipts: [
                (
                    recommendationID: "receipt-copy-fixture",
                    receipt: runtimeReceipt(
                        traceID: "receipt-copy-store-fixture",
                        providerFamily: .googleMaps,
                        capability: .localServiceSearch,
                        costClass: .meteredPremium,
                        entitlements: [.googleMaps]
                    )
                ),
                (
                    recommendationID: "receipt-copy-local",
                    receipt: nonFixtureReceipt(
                        traceID: "receipt-copy-store-local",
                        providerFamily: .appleLocal,
                        capability: .routePlanning,
                        costClass: .freeLocal,
                        freshness: .cachedOK
                    )
                ),
                (recommendationID: "receipt-copy-blocked", receipt: blockedReceipt),
                (
                    recommendationID: "receipt-copy-unavailable",
                    receipt: ServerProviderRuntimeReceiptProjector.project(
                        ServerProviderRuntimeAdapterRegistry.resolve(
                            malformedRuntimeBoundary(
                                from: unavailableBase,
                                providerFamily: .some(.cache)
                            )
                        )
                    )
                ),
            ]
        )
        let presentations = try [
            "receipt-copy-fixture",
            "receipt-copy-local",
            "receipt-copy-blocked",
            "receipt-copy-unavailable",
        ].map { id in
            try XCTUnwrap(store.providerStatusPresentation(for: id))
        }
        let text = presentations
            .flatMap { [$0.statusLine] + $0.badges.map(\.label) }
            .joined(separator: "\n")
            .lowercased()

        for forbidden in [
            "completed",
            "complete",
            "done",
            "called",
            "contacted",
            "fetched",
            "invoked",
            "booked",
            "ordered",
            "paid",
            "purchased",
        ] {
            XCTAssertFalse(text.contains(forbidden), "Unexpected wording: \(forbidden)")
        }
    }

    func test_providerStatusMultiplexerPrefersRuntimeReceiptSourceOverProjectedSource() throws {
        let projection = ResultProjector.project(
            providerSelection: ProviderRoutingPolicy.select(
                for: ProviderRequest(
                    traceID: "multiplexer-projected",
                    capability: .routePlanning,
                    region: .northAmerica,
                    membershipTier: .free
                )
            ),
            createdAt: now
        )
        let projectedProvider = ProjectedRecommendationProvider(projections: [projection])
        let recommendationID = try XCTUnwrap(
            projectedProvider.projectedRecommendations().first?.id
        )
        let runtimeStore = RuntimeReceiptProviderStatusStore(
            receiptsByRecommendationID: [
                recommendationID: runtimeReceipt(
                    traceID: "multiplexer-runtime",
                    providerFamily: .googleMaps,
                    capability: .localServiceSearch,
                    costClass: .meteredPremium,
                    entitlements: [.googleMaps]
                ),
            ]
        )
        let multiplexer = ProviderStatusSourceMultiplexer(
            sources: [runtimeStore, projectedProvider]
        )

        let presentation = try XCTUnwrap(
            multiplexer.providerStatusPresentation(for: recommendationID)
        )

        XCTAssertEqual(presentation.cardHint, .warning)
        XCTAssertEqual(badge(.remoteProvider, in: presentation)?.tone, .neutral)
        XCTAssertEqual(badge(.meteredPremium, in: presentation)?.tone, .neutral)
        XCTAssertTrue(presentation.statusLine.contains("Runtime receipt"))
        XCTAssertFalse(presentation.statusLine.contains("apple-local"))
    }

    func test_providerStatusMultiplexerFallsBackToProjectedSourceOnRuntimeMiss() throws {
        let projection = ResultProjector.project(
            providerSelection: ProviderRoutingPolicy.select(
                for: ProviderRequest(
                    traceID: "multiplexer-fallback",
                    capability: .routePlanning,
                    region: .northAmerica,
                    membershipTier: .free
                )
            ),
            createdAt: now
        )
        let projectedProvider = ProjectedRecommendationProvider(projections: [projection])
        let recommendationID = try XCTUnwrap(
            projectedProvider.projectedRecommendations().first?.id
        )
        let runtimeStore = RuntimeReceiptProviderStatusStore(receipts: [])
        let multiplexer = ProviderStatusSourceMultiplexer(
            sources: [runtimeStore, projectedProvider]
        )

        let presentation = try XCTUnwrap(
            multiplexer.providerStatusPresentation(for: recommendationID)
        )

        XCTAssertEqual(presentation.cardHint, .normal)
        XCTAssertEqual(badge(.localProvider, in: presentation)?.tone, .positive)
        XCTAssertEqual(badge(.freeLocal, in: presentation)?.tone, .positive)
        XCTAssertTrue(presentation.statusLine.contains("apple-local"))
    }

    func test_providerStatusMultiplexerReturnsNilForAllSourceMissAndEmptySources() {
        let runtimeStore = RuntimeReceiptProviderStatusStore(receipts: [])
        let projectedProvider = ProjectedRecommendationProvider(projections: [])
        let allMissMultiplexer = ProviderStatusSourceMultiplexer(
            sources: [runtimeStore, projectedProvider]
        )
        let emptyMultiplexer = ProviderStatusSourceMultiplexer(sources: [])

        XCTAssertNil(allMissMultiplexer.providerStatusPresentation(for: "missing"))
        XCTAssertNil(emptyMultiplexer.providerStatusPresentation(for: "missing"))
    }

    func test_providerStatusMultiplexerSourceOrderIsDeterministic() throws {
        let recommendationID = "multiplexer-ordered"
        let localStore = RuntimeReceiptProviderStatusStore(
            receiptsByRecommendationID: [
                recommendationID: nonFixtureReceipt(
                    traceID: "multiplexer-ordered-local",
                    providerFamily: .appleLocal,
                    capability: .routePlanning,
                    costClass: .freeLocal,
                    freshness: .cachedOK
                ),
            ]
        )
        let remoteStore = RuntimeReceiptProviderStatusStore(
            receiptsByRecommendationID: [
                recommendationID: runtimeReceipt(
                    traceID: "multiplexer-ordered-remote",
                    providerFamily: .googleMaps,
                    capability: .localServiceSearch,
                    costClass: .meteredPremium,
                    entitlements: [.googleMaps]
                ),
            ]
        )
        let localFirst = ProviderStatusSourceMultiplexer(sources: [localStore, remoteStore])
        let remoteFirst = ProviderStatusSourceMultiplexer(sources: [remoteStore, localStore])

        let localPresentation = try XCTUnwrap(
            localFirst.providerStatusPresentation(for: recommendationID)
        )
        let remotePresentation = try XCTUnwrap(
            remoteFirst.providerStatusPresentation(for: recommendationID)
        )

        XCTAssertEqual(localPresentation.cardHint, .normal)
        XCTAssertEqual(badge(.localProvider, in: localPresentation)?.tone, .positive)
        XCTAssertNil(badge(.remoteProvider, in: localPresentation))
        XCTAssertEqual(remotePresentation.cardHint, .warning)
        XCTAssertEqual(badge(.remoteProvider, in: remotePresentation)?.tone, .neutral)
        XCTAssertEqual(badge(.meteredPremium, in: remotePresentation)?.tone, .neutral)
    }

    func test_providerStatusMultiplexerDoesNotChangeFrozenRailContractsOrMatchingObjectFields() {
        let object = RecommendationFixtures.placeRoute
        let objectBeforeLookup = object
        let store = RuntimeReceiptProviderStatusStore(
            receiptsByRecommendationID: [
                object.id: runtimeReceipt(
                    traceID: "multiplexer-matching-object",
                    providerFamily: .searchAPI,
                    capability: .webSearch,
                    costClass: .meteredPremium,
                    sourcePolicy: ServerSourcePolicy(
                        sourceState: .passed,
                        robotsState: .notApplicable,
                        attributionRequired: true,
                        sourceHost: "example.com"
                    ),
                    entitlements: [.searchAPI]
                ),
            ]
        )
        let multiplexer = ProviderStatusSourceMultiplexer(sources: [store])

        _ = multiplexer.providerStatusPresentation(for: object.id)

        XCTAssertEqual(ActionCardTrustPillKind.allCases.count, 7)
        XCTAssertEqual(MatchingObjectKind.allCases.count, 9)
        XCTAssertEqual(RecommendationRail.maxSlateSize, 3)
        XCTAssertEqual(object, objectBeforeLookup)
        XCTAssertEqual(object.id, objectBeforeLookup.id)
        XCTAssertEqual(object.kind, objectBeforeLookup.kind)
        XCTAssertEqual(object.title, objectBeforeLookup.title)
        XCTAssertEqual(object.subtitleTokens, objectBeforeLookup.subtitleTokens)
        XCTAssertEqual(object.reasonText, objectBeforeLookup.reasonText)
        XCTAssertEqual(object.primaryCTA, objectBeforeLookup.primaryCTA)
        XCTAssertEqual(object.secondaryCTA, objectBeforeLookup.secondaryCTA)
        XCTAssertEqual(object.activationPrompt, objectBeforeLookup.activationPrompt)
        XCTAssertEqual(object.preferredSection, objectBeforeLookup.preferredSection)
    }

    func test_providerStatusMultiplexerCopyDoesNotUseCompletedOrActionDoneWording() throws {
        let projection = ResultProjector.project(
            providerSelection: ProviderRoutingPolicy.select(
                for: ProviderRequest(
                    traceID: "multiplexer-copy-projected",
                    capability: .routePlanning,
                    region: .northAmerica,
                    membershipTier: .free
                )
            ),
            createdAt: now
        )
        let projectedProvider = ProjectedRecommendationProvider(projections: [projection])
        let projectedID = try XCTUnwrap(
            projectedProvider.projectedRecommendations().first?.id
        )
        let runtimeID = "multiplexer-copy-runtime"
        let runtimeStore = RuntimeReceiptProviderStatusStore(
            receiptsByRecommendationID: [
                runtimeID: runtimeReceipt(
                    traceID: "multiplexer-copy-runtime",
                    providerFamily: .googleMaps,
                    capability: .localServiceSearch,
                    costClass: .meteredPremium,
                    entitlements: [.googleMaps]
                ),
            ]
        )
        let multiplexer = ProviderStatusSourceMultiplexer(
            sources: [runtimeStore, projectedProvider]
        )
        let presentations = try [runtimeID, projectedID].map { id in
            try XCTUnwrap(multiplexer.providerStatusPresentation(for: id))
        }
        let text = presentations
            .flatMap { [$0.statusLine] + $0.badges.map(\.label) }
            .joined(separator: "\n")
            .lowercased()

        for forbidden in [
            "completed",
            "complete",
            "done",
            "called",
            "contacted",
            "fetched",
            "invoked",
            "booked",
            "ordered",
            "paid",
            "purchased",
        ] {
            XCTAssertFalse(text.contains(forbidden), "Unexpected wording: \(forbidden)")
        }
    }

    func test_pipelineGeneratedReceiptsFeedStatusStoreAndCompactDisplays() throws {
        let cases: [
            (
                id: String,
                receipt: ServerProviderRuntimeReceipt,
                cardHint: ProviderStatusCardHint,
                treatment: ProviderStatusCompactCellTreatment,
                badgeKind: ProviderStatusBadgeKind,
                statusSnippet: String
            )
        ] = [
            (
                id: "pipeline-status-fixture",
                receipt: pipelineReceipt(
                    traceID: "pipeline-status-fixture",
                    providerFamily: .searchAPI,
                    capability: .webSearch,
                    costClass: .meteredPremium,
                    sourcePolicy: ServerSourcePolicy(
                        sourceState: .passed,
                        robotsState: .notApplicable,
                        attributionRequired: true,
                        sourceHost: "example.com"
                    ),
                    entitlements: [.searchAPI]
                ),
                cardHint: .warning,
                treatment: .warning,
                badgeKind: .remoteProvider,
                statusSnippet: "fixture metadata"
            ),
            (
                id: "pipeline-status-local",
                receipt: pipelineReceipt(
                    traceID: "pipeline-status-local",
                    providerFamily: .appleLocal,
                    capability: .routePlanning,
                    costClass: .freeLocal,
                    freshness: .cachedOK
                ),
                cardHint: .normal,
                treatment: .normal,
                badgeKind: .localProvider,
                statusSnippet: "local-only"
            ),
            (
                id: "pipeline-status-blocked",
                receipt: try pipelinePrivateBlockedReceipt(),
                cardHint: .disabled,
                treatment: .disabled,
                badgeKind: .privacyBlocked,
                statusSnippet: "blocked by policy"
            ),
            (
                id: "pipeline-status-confirmation",
                receipt: pipelineReceipt(
                    traceID: "pipeline-status-confirmation",
                    providerFamily: .mcp,
                    capability: .mcpTool,
                    costClass: .includedQuota,
                    confirmationState: .requiredMissing,
                    entitlements: [.mcp],
                    enabledExperimentalProviders: [.mcp]
                ),
                cardHint: .disabled,
                treatment: .disabled,
                badgeKind: .unavailable,
                statusSnippet: "Confirmation is required"
            ),
            (
                id: "pipeline-status-descriptor",
                receipt: try pipelineDescriptorUnavailableReceipt(),
                cardHint: .warning,
                treatment: .warning,
                badgeKind: .unavailable,
                statusSnippet: "missing descriptor metadata"
            ),
            (
                id: "pipeline-status-plan",
                receipt: try pipelinePlanRejectedReceipt(),
                cardHint: .warning,
                treatment: .warning,
                badgeKind: .unavailable,
                statusSnippet: "rejected plan metadata"
            ),
            (
                id: "pipeline-status-unavailable",
                receipt: pipelineUnavailableReceipt(),
                cardHint: .disabled,
                treatment: .disabled,
                badgeKind: .unavailable,
                statusSnippet: "no registered adapter"
            ),
        ]
        let store = RuntimeReceiptProviderStatusStore(
            receipts: cases.map { (recommendationID: $0.id, receipt: $0.receipt) }
        )

        XCTAssertEqual(store.recommendationIDs, cases.map { $0.id }.sorted())

        for testCase in cases {
            let presentation = try XCTUnwrap(
                store.providerStatusPresentation(for: testCase.id),
                testCase.id
            )
            let compact = try XCTUnwrap(
                ProviderStatusCompactCellDisplay.make(from: presentation),
                testCase.id
            )

            XCTAssertEqual(presentation.recommendationID, testCase.id)
            XCTAssertEqual(presentation.cardHint, testCase.cardHint, testCase.id)
            XCTAssertTrue(
                presentation.statusLine.contains(testCase.statusSnippet),
                testCase.id
            )
            XCTAssertNotNil(badge(testCase.badgeKind, in: presentation), testCase.id)
            XCTAssertEqual(compact.recommendationID, testCase.id)
            XCTAssertEqual(compact.statusLine, presentation.statusLine)
            XCTAssertEqual(compact.treatment, testCase.treatment, testCase.id)
            XCTAssertEqual(compact.badges, presentation.badges)
        }

        XCTAssertNil(store.providerStatusPresentation(for: "pipeline-status-missing"))
    }

    func test_pipelineGeneratedReceiptStatusStoreKeepsFirstReceiptForDuplicateRecommendationID() throws {
        let recommendationID = "pipeline-status-duplicate"
        let store = RuntimeReceiptProviderStatusStore(
            receipts: [
                (
                    recommendationID: recommendationID,
                    receipt: pipelineReceipt(
                        traceID: "pipeline-status-duplicate-local",
                        providerFamily: .appleLocal,
                        capability: .routePlanning,
                        costClass: .freeLocal,
                        freshness: .cachedOK
                    )
                ),
                (
                    recommendationID: recommendationID,
                    receipt: pipelineReceipt(
                        traceID: "pipeline-status-duplicate-remote",
                        providerFamily: .googleMaps,
                        capability: .localServiceSearch,
                        costClass: .meteredPremium,
                        entitlements: [.googleMaps]
                    )
                ),
            ]
        )

        let presentation = try XCTUnwrap(
            store.providerStatusPresentation(for: recommendationID)
        )

        XCTAssertEqual(store.recommendationIDs, [recommendationID])
        XCTAssertEqual(presentation.cardHint, .normal)
        XCTAssertEqual(badge(.localProvider, in: presentation)?.tone, .positive)
        XCTAssertNil(badge(.remoteProvider, in: presentation))
        XCTAssertTrue(presentation.statusLine.contains("local-only"))
        XCTAssertFalse(presentation.statusLine.contains("fixture metadata"))
    }

    func test_pipelineGeneratedReceiptsComposeThroughStatusMultiplexerInSourceOrder() throws {
        let recommendationID = "pipeline-status-multiplexer"
        let runtimeStore = RuntimeReceiptProviderStatusStore(
            receiptsByRecommendationID: [
                recommendationID: pipelineReceipt(
                    traceID: "pipeline-status-multiplexer-runtime",
                    providerFamily: .searchAPI,
                    capability: .webSearch,
                    costClass: .meteredPremium,
                    sourcePolicy: ServerSourcePolicy(
                        sourceState: .passed,
                        robotsState: .notApplicable,
                        attributionRequired: true,
                        sourceHost: "example.com"
                    ),
                    entitlements: [.searchAPI]
                ),
            ]
        )
        let fixedProvider = FixedProviderStatusProvider(
            presentationsByRecommendationID: [
                recommendationID: ProviderStatusPresentation(
                    recommendationID: recommendationID,
                    badges: [
                        ProviderStatusBadgeModel(
                            kind: .localProvider,
                            label: "Local provider",
                            systemImage: "iphone",
                            tone: .positive
                        ),
                    ],
                    statusLine: "Fixed fallback provider status.",
                    cardHint: .normal
                ),
            ]
        )
        let runtimeFirst = ProviderStatusSourceMultiplexer(
            sources: [runtimeStore, fixedProvider]
        )
        let fixedFirst = ProviderStatusSourceMultiplexer(
            sources: [fixedProvider, runtimeStore]
        )

        let runtimeFirstPresentation = try XCTUnwrap(
            runtimeFirst.providerStatusPresentation(for: recommendationID)
        )
        let fixedFirstPresentation = try XCTUnwrap(
            fixedFirst.providerStatusPresentation(for: recommendationID)
        )

        XCTAssertEqual(runtimeFirstPresentation.cardHint, .warning)
        XCTAssertEqual(badge(.remoteProvider, in: runtimeFirstPresentation)?.tone, .neutral)
        XCTAssertTrue(runtimeFirstPresentation.statusLine.contains("Runtime receipt"))
        XCTAssertEqual(fixedFirstPresentation.cardHint, .normal)
        XCTAssertEqual(badge(.localProvider, in: fixedFirstPresentation)?.tone, .positive)
        XCTAssertEqual(fixedFirstPresentation.statusLine, "Fixed fallback provider status.")
    }

    func test_injectedPipelineReceiptFeedsStatusStoreByExplicitRecommendationID() throws {
        let recommendationID = "a61-injected-status-search"
        let receipt = injectedPipelineReceipt(
            traceID: "a61-injected-search",
            marker: "a61-injected-status-marker",
            providerFamily: .searchAPI,
            capability: .webSearch,
            costClass: .meteredPremium,
            sourcePolicy: ServerSourcePolicy(
                sourceState: .passed,
                robotsState: .notApplicable,
                attributionRequired: true,
                sourceHost: "example.com"
            ),
            entitlements: [.searchAPI]
        )
        let store = RuntimeReceiptProviderStatusStore(
            receipts: [(recommendationID: recommendationID, receipt: receipt)]
        )

        let presentation = try XCTUnwrap(
            store.providerStatusPresentation(for: recommendationID)
        )

        XCTAssertEqual(store.recommendationIDs, [recommendationID])
        XCTAssertEqual(receipt.state, .fixtureProjected)
        XCTAssertTrue(receipt.adapterResultID.contains("a61-injected-status-marker"))
        XCTAssertEqual(presentation.recommendationID, recommendationID)
        XCTAssertEqual(presentation.cardHint, .warning)
        XCTAssertEqual(badge(.remoteProvider, in: presentation)?.tone, .neutral)
        XCTAssertEqual(badge(.meteredPremium, in: presentation)?.tone, .neutral)
        XCTAssertEqual(badge(.liveFreshness, in: presentation)?.tone, .positive)
        XCTAssertTrue(presentation.statusLine.contains("Runtime receipt is projected"))
        XCTAssertTrue(presentation.statusLine.contains("No provider runtime has run"))
        XCTAssertNil(store.providerStatusPresentation(for: "a61-injected-status-missing"))
    }

    func test_injectedPipelineReceiptStatusStoreComposesThroughMultiplexerInSourceOrder() throws {
        let recommendationID = "a61-injected-status-multiplexer"
        let receipt = injectedPipelineReceipt(
            traceID: "a61-injected-multiplexer",
            marker: "a61-injected-multiplexer-marker",
            providerFamily: .searchAPI,
            capability: .webSearch,
            costClass: .meteredPremium,
            sourcePolicy: ServerSourcePolicy(
                sourceState: .passed,
                robotsState: .notApplicable,
                attributionRequired: true,
                sourceHost: "example.com"
            ),
            entitlements: [.searchAPI]
        )
        let runtimeStore = RuntimeReceiptProviderStatusStore(
            receiptsByRecommendationID: [recommendationID: receipt]
        )
        let fixedProvider = FixedProviderStatusProvider(
            presentationsByRecommendationID: [
                recommendationID: ProviderStatusPresentation(
                    recommendationID: recommendationID,
                    badges: [
                        ProviderStatusBadgeModel(
                            kind: .localProvider,
                            label: "Local provider",
                            systemImage: "iphone",
                            tone: .positive
                        ),
                    ],
                    statusLine: "Fixed fallback provider status.",
                    cardHint: .normal
                ),
            ]
        )
        let runtimeFirst = ProviderStatusSourceMultiplexer(
            sources: [runtimeStore, fixedProvider]
        )
        let fixedFirst = ProviderStatusSourceMultiplexer(
            sources: [fixedProvider, runtimeStore]
        )
        let missFirst = ProviderStatusSourceMultiplexer(
            sources: [
                RuntimeReceiptProviderStatusStore(receipts: []),
                fixedProvider,
            ]
        )

        let runtimeFirstPresentation = try XCTUnwrap(
            runtimeFirst.providerStatusPresentation(for: recommendationID)
        )
        let fixedFirstPresentation = try XCTUnwrap(
            fixedFirst.providerStatusPresentation(for: recommendationID)
        )

        XCTAssertEqual(runtimeFirstPresentation.cardHint, .warning)
        XCTAssertEqual(badge(.remoteProvider, in: runtimeFirstPresentation)?.tone, .neutral)
        XCTAssertTrue(runtimeFirstPresentation.statusLine.contains("Runtime receipt"))
        XCTAssertFalse(runtimeFirstPresentation.statusLine.contains("Fixed fallback"))
        XCTAssertEqual(fixedFirstPresentation.cardHint, .normal)
        XCTAssertEqual(badge(.localProvider, in: fixedFirstPresentation)?.tone, .positive)
        XCTAssertEqual(fixedFirstPresentation.statusLine, "Fixed fallback provider status.")
        XCTAssertEqual(
            missFirst.providerStatusPresentation(for: recommendationID)?.statusLine,
            "Fixed fallback provider status."
        )
        XCTAssertNil(runtimeFirst.providerStatusPresentation(for: "a61-injected-missing"))
    }

    func test_injectedPipelineReceiptStatusCopyDoesNotClaimProviderAction() {
        let receipt = injectedPipelineReceipt(
            traceID: "a61-injected-copy",
            marker: "a61-injected-copy-marker",
            providerFamily: .searchAPI,
            capability: .webSearch,
            costClass: .meteredPremium,
            sourcePolicy: ServerSourcePolicy(
                sourceState: .passed,
                robotsState: .notApplicable,
                attributionRequired: true,
                sourceHost: "example.com"
            ),
            entitlements: [.searchAPI]
        )
        let store = RuntimeReceiptProviderStatusStore(
            receiptsByRecommendationID: ["a61-injected-copy": receipt]
        )
        let presentation = store.providerStatusPresentation(for: "a61-injected-copy")
        let text = [
            presentation?.statusLine,
            presentation?.badges.map(\.label).joined(separator: "\n"),
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
        .lowercased()

        XCTAssertTrue(text.contains("runtime receipt"))
        XCTAssertTrue(text.contains("no provider runtime has run"))
        for forbidden in [
            "completed",
            "complete",
            "done",
            "called",
            "contacted",
            "fetched",
            "invoked",
            "booked",
            "booking",
            "ordered",
            "ordering",
            "paid",
            "payment",
            "purchased",
            "crawled",
            "crawling",
        ] {
            XCTAssertFalse(text.contains(forbidden), "Unexpected wording: \(forbidden)")
        }
    }

    func test_pipelineGeneratedReceiptStatusDoesNotMutateRecommendationOrLayoutContracts() {
        let object = RecommendationFixtures.placeRoute
        let objectBeforeLookup = object
        let store = RuntimeReceiptProviderStatusStore(
            receiptsByRecommendationID: [
                object.id: pipelineReceipt(
                    traceID: "pipeline-status-matching-object",
                    providerFamily: .searchAPI,
                    capability: .webSearch,
                    costClass: .meteredPremium,
                    sourcePolicy: ServerSourcePolicy(
                        sourceState: .passed,
                        robotsState: .notApplicable,
                        attributionRequired: true,
                        sourceHost: "example.com"
                    ),
                    entitlements: [.searchAPI]
                ),
            ]
        )
        let multiplexer = ProviderStatusSourceMultiplexer(sources: [store])

        _ = store.providerStatusPresentation(for: object.id)
        _ = multiplexer.providerStatusPresentation(for: object.id)

        XCTAssertEqual(ActionCardTrustPillKind.allCases.count, 7)
        XCTAssertEqual(MatchingObjectKind.allCases.count, 9)
        XCTAssertEqual(RecommendationRail.maxSlateSize, 3)
        XCTAssertEqual(object, objectBeforeLookup)
        XCTAssertEqual(object.id, objectBeforeLookup.id)
        XCTAssertEqual(object.kind, objectBeforeLookup.kind)
        XCTAssertEqual(object.title, objectBeforeLookup.title)
        XCTAssertEqual(object.subtitleTokens, objectBeforeLookup.subtitleTokens)
        XCTAssertEqual(object.reasonText, objectBeforeLookup.reasonText)
        XCTAssertEqual(object.primaryCTA, objectBeforeLookup.primaryCTA)
        XCTAssertEqual(object.secondaryCTA, objectBeforeLookup.secondaryCTA)
        XCTAssertEqual(object.activationPrompt, objectBeforeLookup.activationPrompt)
        XCTAssertEqual(object.preferredSection, objectBeforeLookup.preferredSection)
    }

    func test_pipelineGeneratedReceiptStatusCopyDoesNotUseCompletedOrActionDoneWording() throws {
        let receipts = [
            pipelineReceipt(
                traceID: "pipeline-status-copy-fixture",
                providerFamily: .googleMaps,
                capability: .localServiceSearch,
                costClass: .meteredPremium,
                entitlements: [.googleMaps]
            ),
            pipelineReceipt(
                traceID: "pipeline-status-copy-local",
                providerFamily: .appleLocal,
                capability: .routePlanning,
                costClass: .freeLocal,
                freshness: .cachedOK
            ),
            try pipelinePrivateBlockedReceipt(),
            pipelineReceipt(
                traceID: "pipeline-status-copy-confirmation",
                providerFamily: .mcp,
                capability: .mcpTool,
                costClass: .includedQuota,
                confirmationState: .requiredMissing,
                entitlements: [.mcp],
                enabledExperimentalProviders: [.mcp]
            ),
            try pipelineDescriptorUnavailableReceipt(),
            try pipelinePlanRejectedReceipt(),
            pipelineUnavailableReceipt(),
        ]
        let presentations = receipts.enumerated().map { index, receipt in
            ProviderStatusBadgeResolver.presentation(
                recommendationID: "pipeline-status-copy-\(index)",
                for: receipt
            )
        }
        let text = presentations
            .flatMap { [$0.statusLine] + $0.badges.map(\.label) }
            .joined(separator: "\n")
            .lowercased()

        for forbidden in [
            "completed",
            "complete",
            "done",
            "called",
            "contacted",
            "fetched",
            "invoked",
            "booked",
            "ordered",
            "paid",
            "purchased",
        ] {
            XCTAssertFalse(text.contains(forbidden), "Unexpected wording: \(forbidden)")
        }
    }

    func test_searchAPIAdapterStatusStorePreparedRequestMapsByRecommendationID() throws {
        let decision = try searchAPIAdapterRequestDecision()
        let store = SearchAPIAdapterProviderStatusStore(
            valuesByRecommendationID: [
                "a87-request": .requestDecision(decision),
            ]
        )

        let presentation = try XCTUnwrap(
            store.providerStatusPresentation(for: "a87-request")
        )

        XCTAssertEqual(store.recommendationIDs, ["a87-request"])
        XCTAssertEqual(presentation.recommendationID, "a87-request")
        XCTAssertEqual(presentation.cardHint, .warning)
        XCTAssertEqual(badge(.remoteProvider, in: presentation)?.tone, .neutral)
        XCTAssertEqual(badge(.meteredPremium, in: presentation)?.tone, .neutral)
        XCTAssertEqual(badge(.liveFreshness, in: presentation)?.tone, .positive)
        XCTAssertTrue(presentation.statusLine.contains("Search API adapter request"))
        XCTAssertTrue(presentation.statusLine.contains("Citation required for example.com"))
        XCTAssertTrue(presentation.statusLine.contains("No provider runtime has run"))
        XCTAssertNil(store.providerStatusPresentation(for: "a87-missing"))
    }

    func test_searchAPIAdapterStatusStoreNormalizedResultMapsByRecommendationID() throws {
        let receipt = try searchAPIAdapterResultReceipt()
        let store = SearchAPIAdapterProviderStatusStore(
            values: [
                (recommendationID: "a87-result", value: .resultReceipt(receipt)),
            ]
        )

        let presentation = try XCTUnwrap(
            store.providerStatusPresentation(for: "a87-result")
        )

        XCTAssertEqual(store.recommendationIDs, ["a87-result"])
        XCTAssertEqual(presentation.cardHint, .warning)
        XCTAssertEqual(badge(.remoteProvider, in: presentation)?.tone, .neutral)
        XCTAssertEqual(badge(.meteredPremium, in: presentation)?.tone, .neutral)
        XCTAssertEqual(badge(.liveFreshness, in: presentation)?.tone, .positive)
        XCTAssertTrue(presentation.statusLine.contains("normalized from cited metadata"))
        XCTAssertTrue(presentation.statusLine.contains("Citations: 1 source(s), including example.com"))
        XCTAssertTrue(presentation.statusLine.contains("No provider runtime has run"))
    }

    func test_searchAPIAdapterStatusStoreRejectedValuesStayNonSuccessWithoutProviderBadges() throws {
        let privateDecision = ServerProviderSearchAPIAdapterContract.prepareRequest(
            envelope: searchAPIAdapterEnvelope(privacyClass: .private),
            connectorReceipt: searchAPIAdapterConnectorReceipt(),
            query: ServerProviderSearchAPIAdapterQuery(text: "public coffee")
        )
        let citationMissingReceipt = try searchAPIAdapterRejectedResultReceipt()
        let store = SearchAPIAdapterProviderStatusStore(
            values: [
                (recommendationID: "a87-private", value: .requestDecision(privateDecision)),
                (recommendationID: "a87-citation", value: .resultReceipt(citationMissingReceipt)),
            ]
        )

        let privatePresentation = try XCTUnwrap(
            store.providerStatusPresentation(for: "a87-private")
        )
        let citationPresentation = try XCTUnwrap(
            store.providerStatusPresentation(for: "a87-citation")
        )

        XCTAssertEqual(privatePresentation.cardHint, .disabled)
        XCTAssertEqual(badge(.privacyBlocked, in: privatePresentation)?.tone, .warning)
        XCTAssertNil(badge(.remoteProvider, in: privatePresentation))
        XCTAssertNil(badge(.meteredPremium, in: privatePresentation))
        XCTAssertTrue(privatePresentation.statusLine.contains("privacyBlocked"))
        XCTAssertTrue(privatePresentation.statusLine.contains("No provider runtime has run"))

        XCTAssertEqual(citationPresentation.cardHint, .disabled)
        XCTAssertEqual(badge(.termsBlocked, in: citationPresentation)?.tone, .warning)
        XCTAssertNil(badge(.remoteProvider, in: citationPresentation))
        XCTAssertNil(badge(.meteredPremium, in: citationPresentation))
        XCTAssertTrue(citationPresentation.statusLine.contains("resultCitationMissing"))
        XCTAssertTrue(citationPresentation.statusLine.contains("No provider runtime has run"))
    }

    func test_searchAPIAdapterStatusStoreKeepsFirstValueForDuplicateRecommendationID() throws {
        let first = try searchAPIAdapterRequestDecision(
            costClass: .includedQuota,
            freshness: .cachedOK
        )
        let second = try searchAPIAdapterResultReceipt()
        let store = SearchAPIAdapterProviderStatusStore(
            values: [
                (recommendationID: "a87-duplicate", value: .requestDecision(first)),
                (recommendationID: "a87-duplicate", value: .resultReceipt(second)),
            ]
        )

        let presentation = try XCTUnwrap(
            store.providerStatusPresentation(for: "a87-duplicate")
        )

        XCTAssertEqual(store.recommendationIDs, ["a87-duplicate"])
        XCTAssertEqual(presentation.cardHint, .normal)
        XCTAssertEqual(badge(.includedQuota, in: presentation)?.tone, .neutral)
        XCTAssertNil(badge(.meteredPremium, in: presentation))
        XCTAssertTrue(presentation.statusLine.contains("Search API adapter request"))
        XCTAssertFalse(presentation.statusLine.contains("normalized from cited metadata"))
    }

    func test_searchAPIAdapterStatusStoreEncodingAndCopyDoNotExposeRuntimeFields() throws {
        let prepared = try searchAPIAdapterRequestDecision()
        let normalized = try searchAPIAdapterResultReceipt()
        let blocked = ServerProviderSearchAPIAdapterContract.prepareRequest(
            envelope: searchAPIAdapterEnvelope(entitlements: []),
            connectorReceipt: searchAPIAdapterConnectorReceipt(),
            query: ServerProviderSearchAPIAdapterQuery(text: "public coffee")
        )
        let citationMissing = try searchAPIAdapterRejectedResultReceipt()
        let values: [SearchAPIAdapterProviderStatusValue] = [
            .requestDecision(prepared),
            .resultReceipt(normalized),
            .requestDecision(blocked),
            .resultReceipt(citationMissing),
        ]
        let store = SearchAPIAdapterProviderStatusStore(
            values: values.enumerated().map { index, value in
                (recommendationID: "a87-copy-\(index)", value: value)
            }
        )
        let presentations = try values.indices.map { index in
            try XCTUnwrap(store.providerStatusPresentation(for: "a87-copy-\(index)"))
        }
        let text = (
            try values.map(encodedString)
                + presentations.flatMap { [$0.statusLine] + $0.badges.map(\.label) }
        )
            .joined(separator: "\n")
            .lowercased()

        XCTAssertTrue(text.contains("metadata only"))
        XCTAssertTrue(text.contains("no provider runtime has run"))
        for forbidden in searchAPIAdapterForbiddenFragments() {
            XCTAssertFalse(text.contains(forbidden), "Unexpected wording or field: \(forbidden)")
        }
    }

    func test_compactCellDisplayNilStatusPreservesAbsentBinding() {
        XCTAssertNil(ProviderStatusCompactCellDisplay.make(from: nil))

        let empty = ProviderStatusPresentation(
            recommendationID: "compact-empty",
            badges: [],
            statusLine: "   ",
            cardHint: .normal
        )

        XCTAssertNil(ProviderStatusCompactCellDisplay.make(from: empty))
    }

    func test_compactCellDisplayMapsNormalWarningAndDisabledHints() throws {
        let normal = try XCTUnwrap(
            ProviderStatusCompactCellDisplay.make(
                from: compactPresentation(
                    recommendationID: "compact-normal",
                    statusLine: "Local provider status.",
                    cardHint: .normal
                )
            )
        )
        let warning = try XCTUnwrap(
            ProviderStatusCompactCellDisplay.make(
                from: compactPresentation(
                    recommendationID: "compact-warning",
                    statusLine: "Premium provider is metered.",
                    cardHint: .warning
                )
            )
        )
        let disabled = try XCTUnwrap(
            ProviderStatusCompactCellDisplay.make(
                from: compactPresentation(
                    recommendationID: "compact-disabled",
                    statusLine: "Provider policy blocks this route.",
                    cardHint: .disabled
                )
            )
        )

        XCTAssertEqual(normal.treatment, .normal)
        XCTAssertEqual(warning.treatment, .warning)
        XCTAssertEqual(disabled.treatment, .disabled)
        XCTAssertEqual(ProviderStatusCompactCellTreatment.allCases, [.normal, .warning, .disabled])
    }

    func test_compactCellDisplayPreservesStatusLineBadgePayloadAndAccessibilityCopy() throws {
        let presentation = compactPresentation(
            recommendationID: "compact-copy",
            badges: [
                ProviderStatusBadgeModel(
                    kind: .remoteProvider,
                    label: "Remote fixture",
                    systemImage: "network",
                    tone: .neutral
                ),
                ProviderStatusBadgeModel(
                    kind: .meteredPremium,
                    label: "Metered premium",
                    systemImage: "creditcard",
                    tone: .warning
                ),
            ],
            statusLine: "  Runtime receipt fixture; no provider runtime has run.  ",
            cardHint: .warning
        )

        let display = try XCTUnwrap(ProviderStatusCompactCellDisplay.make(from: presentation))

        XCTAssertEqual(display.id, "compact-provider-status-compact-copy")
        XCTAssertEqual(display.recommendationID, "compact-copy")
        XCTAssertEqual(display.statusLine, "Runtime receipt fixture; no provider runtime has run.")
        XCTAssertEqual(display.badges.map(\.kind), [.remoteProvider, .meteredPremium])
        XCTAssertTrue(display.accessibilityLabel.contains("Runtime receipt fixture"))
        XCTAssertTrue(display.accessibilityLabel.contains("Remote fixture"))
        XCTAssertTrue(display.accessibilityLabel.contains("Metered premium"))
    }

    func test_compactCellDisplayDoesNotChangeFrozenRailContractsOrMatchingObjectFields() throws {
        let object = RecommendationFixtures.placeRoute
        let objectBeforeLookup = object
        let display = try XCTUnwrap(
            ProviderStatusCompactCellDisplay.make(
                from: compactPresentation(
                    recommendationID: object.id,
                    statusLine: "Local-only provider metadata.",
                    cardHint: .normal
                )
            )
        )

        XCTAssertEqual(display.recommendationID, object.id)
        XCTAssertEqual(ProviderStatusBadgeKind.allCases.count, 12)
        XCTAssertEqual(ProviderStatusCardHint.allCases, [.normal, .warning, .disabled])
        XCTAssertEqual(ActionCardTrustPillKind.allCases.count, 7)
        XCTAssertEqual(MatchingObjectKind.allCases.count, 9)
        XCTAssertEqual(RecommendationRail.maxSlateSize, 3)
        XCTAssertEqual(object, objectBeforeLookup)
        XCTAssertEqual(object.id, objectBeforeLookup.id)
        XCTAssertEqual(object.kind, objectBeforeLookup.kind)
        XCTAssertEqual(object.title, objectBeforeLookup.title)
        XCTAssertEqual(object.subtitleTokens, objectBeforeLookup.subtitleTokens)
        XCTAssertEqual(object.reasonText, objectBeforeLookup.reasonText)
        XCTAssertEqual(object.primaryCTA, objectBeforeLookup.primaryCTA)
        XCTAssertEqual(object.secondaryCTA, objectBeforeLookup.secondaryCTA)
        XCTAssertEqual(object.activationPrompt, objectBeforeLookup.activationPrompt)
        XCTAssertEqual(object.preferredSection, objectBeforeLookup.preferredSection)
    }

    func test_compactCellDisplayCopyDoesNotClaimExecutionOrProviderContact() throws {
        let runtimePresentation = ProviderStatusBadgeResolver.presentation(
            recommendationID: "compact-runtime-copy",
            for: runtimeReceipt(
                traceID: "compact-runtime-copy",
                providerFamily: .googleMaps,
                capability: .localServiceSearch,
                costClass: .meteredPremium,
                entitlements: [.googleMaps]
            )
        )
        let blockedPresentation = ProviderStatusBadgeResolver.presentation(
            recommendationID: "compact-blocked-copy",
            for: ServerProviderRuntimeReceiptProjector.project(
                ServerProviderRuntimeAdapterRegistry.resolve(
                    ServerProviderRuntimeDispatcher.prepare(
                        ServerProviderRuntimeInvocationPlanner.makePlan(
                            readinessDecision: try privateBlockedDecision()
                        )
                    )
                )
            )
        )
        let displays = try [runtimePresentation, blockedPresentation].map { presentation in
            try XCTUnwrap(ProviderStatusCompactCellDisplay.make(from: presentation))
        }
        let text = displays
            .flatMap { display in
                [display.statusLine, display.accessibilityLabel]
                    + display.badges.map { badge in badge.label }
            }
            .joined(separator: "\n")
            .lowercased()

        for forbidden in [
            "completed",
            "complete",
            "done",
            "called",
            "contacted",
            "provider contacted",
            "fetched",
            "invoked",
            "booked",
            "ordered",
            "paid",
            "purchased",
        ] {
            XCTAssertFalse(text.contains(forbidden), "Unexpected wording: \(forbidden)")
        }
    }

    func test_statusBindingDoesNotChangeFrozenRailContracts() {
        XCTAssertEqual(ProviderStatusBadgeKind.allCases.count, 12)
        XCTAssertEqual(ProviderStatusCardHint.allCases.count, 3)
        XCTAssertEqual(ActionCardTrustPillKind.allCases.count, 7)
        XCTAssertEqual(MatchingObjectKind.allCases.count, 9)
        XCTAssertEqual(RecommendationRail.maxSlateSize, 3)

        let projections = (0..<5).map { index in
            ResultProjector.project(
                providerSelection: ProviderRoutingPolicy.select(
                    for: ProviderRequest(
                        traceID: "status-cap-\(index)",
                        capability: .routePlanning,
                        region: .northAmerica,
                        membershipTier: .free
                    )
                ),
                createdAt: now
            )
        }
        let provider = ProjectedRecommendationProvider(projections: projections)

        XCTAssertEqual(provider.recommendedMatches().count, RecommendationRail.maxSlateSize)
    }

    private func compactPresentation(
        recommendationID: String,
        badges: [ProviderStatusBadgeModel] = [
            ProviderStatusBadgeModel(
                kind: .localProvider,
                label: "Local",
                systemImage: "iphone",
                tone: .positive
            ),
        ],
        statusLine: String,
        cardHint: ProviderStatusCardHint
    ) -> ProviderStatusPresentation {
        ProviderStatusPresentation(
            recommendationID: recommendationID,
            badges: badges,
            statusLine: statusLine,
            cardHint: cardHint
        )
    }

    private func searchAPIAdapterRequestDecision(
        costClass: ProviderCostClass = .meteredPremium,
        freshness: ProviderFreshness = .livePreferred
    ) throws -> ServerProviderSearchAPIAdapterRequestDecision {
        let decision = ServerProviderSearchAPIAdapterContract.prepareRequest(
            envelope: searchAPIAdapterEnvelope(
                costClass: costClass,
                freshness: freshness
            ),
            connectorReceipt: searchAPIAdapterConnectorReceipt(
                costClass: costClass,
                freshness: freshness
            ),
            query: ServerProviderSearchAPIAdapterQuery(text: "public coffee"),
            resultLimit: 4
        )
        XCTAssertEqual(decision.state, .requestPrepared)
        XCTAssertNotNil(decision.request)
        return decision
    }

    private func searchAPIAdapterResultReceipt(
        freshness: ProviderFreshness = .livePreferred
    ) throws -> ServerProviderSearchAPIAdapterResultReceipt {
        let request = try XCTUnwrap(
            searchAPIAdapterRequestDecision(freshness: freshness).request
        )
        let receipt = ServerProviderSearchAPIAdapterContract.normalizeResult(
            request: request,
            candidate: ServerProviderSearchAPIAdapterResultCandidate(
                title: "Coffee options",
                snippet: "Public summary with cited source metadata.",
                freshness: freshness,
                citations: [
                    ServerProviderSearchAPIAdapterCitation(
                        sourceURL: try XCTUnwrap(URL(string: "https://example.com/coffee")),
                        title: "Coffee source",
                        attribution: "Public Source"
                    ),
                ],
                limitations: ["Read-only public information."]
            )
        )
        XCTAssertEqual(receipt.state, .resultNormalized)
        XCTAssertNotNil(receipt.result)
        return receipt
    }

    private func searchAPIAdapterRejectedResultReceipt() throws -> ServerProviderSearchAPIAdapterResultReceipt {
        let request = try XCTUnwrap(searchAPIAdapterRequestDecision().request)
        let receipt = ServerProviderSearchAPIAdapterContract.normalizeResult(
            request: request,
            candidate: ServerProviderSearchAPIAdapterResultCandidate(
                title: "Coffee options",
                snippet: "Public summary.",
                freshness: .livePreferred,
                citations: []
            )
        )
        XCTAssertEqual(receipt.state, .rejected)
        XCTAssertEqual(receipt.rejection, .resultCitationMissing)
        return receipt
    }

    private func searchAPIAdapterEnvelope(
        privacyClass: ProviderPrivacyClass = .general,
        costClass: ProviderCostClass = .meteredPremium,
        freshness: ProviderFreshness = .livePreferred,
        entitlements: Set<ProviderFamily> = [.searchAPI]
    ) -> ServerProviderEnvelope {
        ServerProviderEnvelope(
            traceID: "a87-search-api-trace",
            capability: .webSearch,
            providerFamily: .searchAPI,
            privacyClass: privacyClass,
            membershipTier: .plus,
            costClass: costClass,
            freshness: freshness,
            sourcePolicy: ServerSourcePolicy(
                sourceState: .passed,
                robotsState: .notApplicable,
                attributionRequired: true,
                sourceHost: "example.com"
            ),
            confirmationState: .notRequired,
            meteredProviderEntitlements: entitlements,
            enabledExperimentalProviders: []
        )
    }

    private func searchAPIAdapterConnectorReceipt(
        costClass: ProviderCostClass = .meteredPremium,
        freshness: ProviderFreshness = .livePreferred
    ) -> ServerProviderRuntimeConnectorInvocationReceipt {
        ServerProviderRuntimeConnectorInvocationReceipt(
            id: "a87-search-api-connector-receipt",
            state: .receiptPrepared,
            statusLine: "A87 connector receipt fixture is metadata only. No provider runtime has run.",
            planningID: "a87-search-api-planning",
            planningState: .requestPrepared,
            planningRejection: nil,
            connectorProviderFamily: .searchAPI,
            requestID: "a87-search-api-connector-request",
            resultID: "a87-search-api-connector-result",
            connectorResultState: .metadataPrepared,
            connectorRejection: nil,
            providerFamily: .searchAPI,
            capability: .webSearch,
            costClass: costClass,
            freshness: freshness,
            manifestID: "provider-runtime-adapter-manifest-searchAPI",
            authorizationID: "a87-search-api-authorization",
            boundaryID: "a87-search-api-boundary",
            traceID: "a87-search-api-trace",
            invocationRejection: nil
        )
    }

    private func encodedString<T: Encodable>(
        _ value: T
    ) throws -> String {
        try XCTUnwrap(
            String(data: JSONEncoder().encode(value), encoding: .utf8)
        )
    }

    private func searchAPIAdapterForbiddenFragments() -> [String] {
        [
            "end" + "point",
            "api" + "key",
            "api" + "_" + "key",
            "bear" + "er",
            "tok" + "en",
            "oa" + "uth",
            "s" + "dk",
            "raw" + "prompt",
            "raw prompt",
            "raw" + " page",
            "raw" + "content",
            "raw" + "source",
            "hea" + "lthkit",
            "blood",
            "secret",
            "merchant",
            "order",
            "pay" + "ment",
            "provider raw",
            "completed",
            "complete",
            "done",
            "call" + "ed",
            "contact" + "ed",
            "fetch" + "ed",
            "crawl" + "ed",
            "book" + "ed",
            "paid",
        ]
    }

    private func recommendation(from projection: ProjectedProviderResult) -> ProjectedRecommendation {
        ResultRecommendationProjector.project(projection)
    }

    private func dryRunPresentation(
        capabilityLabel: String,
        requiredFreshness: ProviderFreshness = .cachedOK,
        candidates: [ServerProviderDryRunCandidate]
    ) -> ServerProviderDryRunPresentation {
        ServerProviderDryRunPresentationProjector.project(
            ServerProviderDryRunEvaluator.evaluate(
                capabilityLabel: capabilityLabel,
                requiredFreshness: requiredFreshness,
                candidates: candidates
            )
        )
    }

    private func executableResult(
        traceID: String,
        providerFamily: ProviderFamily,
        capability: ProviderCapability,
        costClass: ProviderCostClass,
        freshness: ProviderFreshness,
        privacyClass: ProviderPrivacyClass = .general,
        membershipTier: MembershipTier = .pro,
        sourcePolicy: ServerSourcePolicy? = nil,
        entitlements: Set<ProviderFamily> = [],
        enabledExperimentalProviders: Set<ProviderFamily> = []
    ) -> ServerProviderEnvelopeFactoryResult {
        let envelope = ServerProviderEnvelope(
            traceID: traceID,
            capability: capability,
            providerFamily: providerFamily,
            privacyClass: privacyClass,
            membershipTier: membershipTier,
            costClass: costClass,
            freshness: freshness,
            sourcePolicy: sourcePolicy ?? .notApplicable,
            meteredProviderEntitlements: entitlements,
            enabledExperimentalProviders: enabledExperimentalProviders
        )
        let validation = ServerProviderEnvelopeValidator.validate(envelope)
        XCTAssertTrue(validation.isAllowed)
        return .executable(envelope: envelope, validation: validation)
    }

    private func runtimeReceipt(
        traceID: String,
        providerFamily: ProviderFamily,
        capability: ProviderCapability,
        costClass: ProviderCostClass,
        sourcePolicy: ServerSourcePolicy? = nil,
        confirmationState: ServerConfirmationState = .notRequired,
        entitlements: Set<ProviderFamily> = [],
        enabledExperimentalProviders: Set<ProviderFamily> = []
    ) -> ServerProviderRuntimeReceipt {
        ServerProviderRuntimeReceiptProjector.project(
            ServerProviderRuntimeAdapterRegistry.resolve(
                preparedRuntimeBoundary(
                    traceID: traceID,
                    providerFamily: providerFamily,
                    capability: capability,
                    costClass: costClass,
                    sourcePolicy: sourcePolicy,
                    confirmationState: confirmationState,
                    entitlements: entitlements,
                    enabledExperimentalProviders: enabledExperimentalProviders
                )
            )
        )
    }

    private func nonFixtureReceipt(
        traceID: String,
        providerFamily: ProviderFamily,
        capability: ProviderCapability,
        costClass: ProviderCostClass,
        freshness: ProviderFreshness = .livePreferred,
        sourcePolicy: ServerSourcePolicy? = nil,
        confirmationState: ServerConfirmationState = .notRequired,
        entitlements: Set<ProviderFamily> = [],
        enabledExperimentalProviders: Set<ProviderFamily> = []
    ) -> ServerProviderRuntimeReceipt {
        ServerProviderRuntimeReceiptProjector.project(
            ServerProviderRuntimeAdapterRegistry.resolve(
                boundaryFromRuntimeReadiness(
                    traceID: traceID,
                    providerFamily: providerFamily,
                    capability: capability,
                    costClass: costClass,
                    freshness: freshness,
                    sourcePolicy: sourcePolicy,
                    confirmationState: confirmationState,
                    entitlements: entitlements,
                    enabledExperimentalProviders: enabledExperimentalProviders
                )
            )
        )
    }

    private func pipelineReceipt(
        traceID: String,
        providerFamily: ProviderFamily,
        capability: ProviderCapability,
        costClass: ProviderCostClass,
        freshness: ProviderFreshness = .livePreferred,
        sourcePolicy: ServerSourcePolicy? = nil,
        confirmationState: ServerConfirmationState = .notRequired,
        entitlements: Set<ProviderFamily> = [],
        enabledExperimentalProviders: Set<ProviderFamily> = []
    ) -> ServerProviderRuntimeReceipt {
        ServerProviderRuntimePipeline.run(
            readinessDecision: runtimeReadyDecision(
                traceID: traceID,
                providerFamily: providerFamily,
                capability: capability,
                costClass: costClass,
                freshness: freshness,
                sourcePolicy: sourcePolicy,
                confirmationState: confirmationState,
                entitlements: entitlements,
                enabledExperimentalProviders: enabledExperimentalProviders
            )
        )
    }

    private func injectedPipelineReceipt(
        traceID: String,
        marker: String,
        providerFamily: ProviderFamily,
        capability: ProviderCapability,
        costClass: ProviderCostClass,
        freshness: ProviderFreshness = .livePreferred,
        sourcePolicy: ServerSourcePolicy? = nil,
        confirmationState: ServerConfirmationState = .notRequired,
        entitlements: Set<ProviderFamily> = [],
        enabledExperimentalProviders: Set<ProviderFamily> = []
    ) -> ServerProviderRuntimeReceipt {
        let adapterSet = ServerProviderRuntimeAdapterSet(
            adapters: [
                MarkerServerProviderRuntimeAdapter(
                    providerFamily: providerFamily,
                    marker: marker
                ),
            ]
        )
        return ServerProviderRuntimePipeline.run(
            readinessDecision: runtimeReadyDecision(
                traceID: traceID,
                providerFamily: providerFamily,
                capability: capability,
                costClass: costClass,
                freshness: freshness,
                sourcePolicy: sourcePolicy,
                confirmationState: confirmationState,
                entitlements: entitlements,
                enabledExperimentalProviders: enabledExperimentalProviders
            ),
            adapterSet: adapterSet
        )
    }

    private func pipelinePrivateBlockedReceipt() throws -> ServerProviderRuntimeReceipt {
        ServerProviderRuntimePipeline.run(
            readinessDecision: try privateBlockedDecision()
        )
    }

    private func pipelineDescriptorUnavailableReceipt() throws -> ServerProviderRuntimeReceipt {
        let decision = serverRuntimeReadyDecision(
            traceID: "pipeline-status-descriptor-mismatch",
            providerFamily: .googleMaps,
            capability: .localServiceSearch,
            costClass: .meteredPremium,
            entitlements: [.googleMaps]
        )
        let searchDescriptor = try XCTUnwrap(
            ServerProviderRuntimeRegistry.descriptors.first { $0.providerFamily == .searchAPI }
        )
        let mismatchLookup = ServerProviderRuntimeLookupResult(
            id: "pipeline-status-runtime-mismatch",
            state: .descriptorAvailable,
            descriptor: searchDescriptor,
            readinessDecision: decision,
            statusLine: "Mismatched descriptor fixture."
        )
        return ServerProviderRuntimePipeline.run(
            readinessDecision: decision,
            runtimeLookup: mismatchLookup
        )
    }

    private func pipelinePlanRejectedReceipt() throws -> ServerProviderRuntimeReceipt {
        let decision = serverRuntimeReadyDecision(
            traceID: "pipeline-status-plan-rejected",
            providerFamily: .googleMaps,
            capability: .localServiceSearch,
            costClass: .meteredPremium,
            entitlements: [.googleMaps]
        )
        let descriptor = try XCTUnwrap(
            ServerProviderRuntimeRegistry.descriptors.first { $0.providerFamily == .googleMaps }
        )
        let malformedDescriptor = ServerProviderRuntimeDescriptor(
            id: " ",
            providerFamily: descriptor.providerFamily,
            displayName: descriptor.displayName,
            supportedCapabilities: descriptor.supportedCapabilities,
            requiredMembershipTier: descriptor.requiredMembershipTier,
            costClass: descriptor.costClass,
            requiresSourcePolicy: descriptor.requiresSourcePolicy,
            requiresRobotsAllow: descriptor.requiresRobotsAllow,
            requiresConfirmation: descriptor.requiresConfirmation,
            requiresExperimentalEnablement: descriptor.requiresExperimentalEnablement
        )
        let malformedLookup = ServerProviderRuntimeLookupResult(
            id: "pipeline-status-malformed-lookup",
            state: .descriptorAvailable,
            descriptor: malformedDescriptor,
            readinessDecision: decision,
            statusLine: "Malformed descriptor fixture."
        )
        return ServerProviderRuntimePipeline.run(
            readinessDecision: decision,
            runtimeLookup: malformedLookup
        )
    }

    private func pipelineUnavailableReceipt() -> ServerProviderRuntimeReceipt {
        let decision = syntheticServerReadyDecision(
            traceID: "pipeline-status-unregistered-cache",
            providerFamily: .cache,
            capability: .webSearch,
            costClass: .freeLocal
        )
        let lookup = ServerProviderRuntimeLookupResult(
            id: "pipeline-status-unregistered-lookup",
            state: .descriptorAvailable,
            descriptor: ServerProviderRuntimeDescriptor(
                id: "runtime-cache-test",
                providerFamily: .cache,
                displayName: "Cache Test",
                supportedCapabilities: [.webSearch],
                requiredMembershipTier: .free,
                costClass: .freeLocal,
                requiresSourcePolicy: false,
                requiresRobotsAllow: false,
                requiresConfirmation: false,
                requiresExperimentalEnablement: false
            ),
            readinessDecision: decision,
            statusLine: "Synthetic cache descriptor fixture."
        )
        return ServerProviderRuntimePipeline.run(
            readinessDecision: decision,
            runtimeLookup: lookup
        )
    }

    private func descriptorUnavailableReceipt() throws -> ServerProviderRuntimeReceipt {
        let decision = serverRuntimeReadyDecision(
            traceID: "receipt-descriptor-mismatch",
            providerFamily: .googleMaps,
            capability: .localServiceSearch,
            costClass: .meteredPremium,
            entitlements: [.googleMaps]
        )
        let searchDescriptor = try XCTUnwrap(
            ServerProviderRuntimeRegistry.descriptors.first { $0.providerFamily == .searchAPI }
        )
        let mismatchLookup = ServerProviderRuntimeLookupResult(
            id: "receipt-runtime-mismatch",
            state: .descriptorAvailable,
            descriptor: searchDescriptor,
            readinessDecision: decision,
            statusLine: "Mismatched descriptor fixture."
        )
        return ServerProviderRuntimeReceiptProjector.project(
            ServerProviderRuntimeAdapterRegistry.resolve(
                ServerProviderRuntimeDispatcher.prepare(
                    ServerProviderRuntimeInvocationPlanner.makePlan(
                        readinessDecision: decision,
                        runtimeLookup: mismatchLookup
                    )
                )
            )
        )
    }

    private func planRejectedReceipt() -> ServerProviderRuntimeReceipt {
        let goodPlan = ServerProviderRuntimeInvocationPlanner.makePlan(
            readinessDecision: runtimeReadyDecision(
                traceID: "receipt-plan-rejected",
                providerFamily: .googleMaps,
                capability: .localServiceSearch,
                costClass: .meteredPremium,
                entitlements: [.googleMaps]
            )
        )
        let malformedPlan = ServerProviderRuntimeInvocationPlan(
            id: goodPlan.id,
            state: goodPlan.state,
            statusLine: goodPlan.statusLine,
            traceID: goodPlan.traceID,
            providerFamily: goodPlan.providerFamily,
            capability: goodPlan.capability,
            costClass: goodPlan.costClass,
            freshness: goodPlan.freshness,
            sourcePolicy: goodPlan.sourcePolicy,
            confirmationState: goodPlan.confirmationState,
            descriptorID: nil,
            audit: goodPlan.audit
        )
        return ServerProviderRuntimeReceiptProjector.project(
            ServerProviderRuntimeAdapterRegistry.resolve(
                ServerProviderRuntimeDispatcher.prepare(malformedPlan)
            )
        )
    }

    private func malformedRuntimeBoundary(
        from boundary: ServerProviderRuntimeDispatchBoundary,
        id: String? = nil,
        planID: String? = nil,
        traceID: String?? = nil,
        providerFamily: ProviderFamily?? = nil,
        capability: ProviderCapability?? = nil,
        descriptorID: String?? = nil
    ) -> ServerProviderRuntimeDispatchBoundary {
        ServerProviderRuntimeDispatchBoundary(
            id: id ?? boundary.id,
            state: boundary.state,
            statusLine: boundary.statusLine,
            planID: planID ?? boundary.planID,
            traceID: traceID ?? boundary.traceID,
            providerFamily: providerFamily ?? boundary.providerFamily,
            capability: capability ?? boundary.capability,
            descriptorID: descriptorID ?? boundary.descriptorID,
            costClass: boundary.costClass,
            freshness: boundary.freshness,
            sourcePolicy: boundary.sourcePolicy,
            confirmationState: boundary.confirmationState,
            audit: boundary.audit
        )
    }

    private func preparedRuntimeBoundary(
        traceID: String,
        providerFamily: ProviderFamily,
        capability: ProviderCapability,
        costClass: ProviderCostClass,
        sourcePolicy: ServerSourcePolicy? = nil,
        confirmationState: ServerConfirmationState = .notRequired,
        entitlements: Set<ProviderFamily> = [],
        enabledExperimentalProviders: Set<ProviderFamily> = []
    ) -> ServerProviderRuntimeDispatchBoundary {
        let boundary = boundaryFromRuntimeReadiness(
            traceID: traceID,
            providerFamily: providerFamily,
            capability: capability,
            costClass: costClass,
            sourcePolicy: sourcePolicy,
            confirmationState: confirmationState,
            entitlements: entitlements,
            enabledExperimentalProviders: enabledExperimentalProviders
        )
        XCTAssertEqual(boundary.state, .prepared)
        return boundary
    }

    private func boundaryFromRuntimeReadiness(
        traceID: String,
        providerFamily: ProviderFamily,
        capability: ProviderCapability,
        costClass: ProviderCostClass,
        freshness: ProviderFreshness = .livePreferred,
        sourcePolicy: ServerSourcePolicy? = nil,
        confirmationState: ServerConfirmationState = .notRequired,
        entitlements: Set<ProviderFamily> = [],
        enabledExperimentalProviders: Set<ProviderFamily> = []
    ) -> ServerProviderRuntimeDispatchBoundary {
        ServerProviderRuntimeDispatcher.prepare(
            ServerProviderRuntimeInvocationPlanner.makePlan(
                readinessDecision: runtimeReadyDecision(
                    traceID: traceID,
                    providerFamily: providerFamily,
                    capability: capability,
                    costClass: costClass,
                    freshness: freshness,
                    sourcePolicy: sourcePolicy,
                    confirmationState: confirmationState,
                    entitlements: entitlements,
                    enabledExperimentalProviders: enabledExperimentalProviders
                )
            )
        )
    }

    private func serverRuntimeReadyDecision(
        traceID: String,
        providerFamily: ProviderFamily,
        capability: ProviderCapability,
        costClass: ProviderCostClass,
        sourcePolicy: ServerSourcePolicy? = nil,
        confirmationState: ServerConfirmationState = .notRequired,
        entitlements: Set<ProviderFamily> = [],
        enabledExperimentalProviders: Set<ProviderFamily> = []
    ) -> ServerProviderExecutionReadinessDecision {
        let decision = runtimeReadyDecision(
            traceID: traceID,
            providerFamily: providerFamily,
            capability: capability,
            costClass: costClass,
            sourcePolicy: sourcePolicy,
            confirmationState: confirmationState,
            entitlements: entitlements,
            enabledExperimentalProviders: enabledExperimentalProviders
        )
        XCTAssertEqual(decision.state, .serverReady)
        return decision
    }

    private func runtimeReadyDecision(
        traceID: String,
        providerFamily: ProviderFamily,
        capability: ProviderCapability,
        costClass: ProviderCostClass,
        freshness: ProviderFreshness = .livePreferred,
        sourcePolicy: ServerSourcePolicy? = nil,
        confirmationState: ServerConfirmationState = .notRequired,
        entitlements: Set<ProviderFamily> = [],
        enabledExperimentalProviders: Set<ProviderFamily> = []
    ) -> ServerProviderExecutionReadinessDecision {
        let envelope = ServerProviderEnvelope(
            traceID: traceID,
            capability: capability,
            providerFamily: providerFamily,
            privacyClass: .general,
            membershipTier: .pro,
            costClass: costClass,
            freshness: freshness,
            sourcePolicy: sourcePolicy ?? .notApplicable,
            confirmationState: confirmationState,
            meteredProviderEntitlements: entitlements,
            enabledExperimentalProviders: enabledExperimentalProviders
        )
        let validation = ServerProviderEnvelopeValidator.validate(envelope)
        let result: ServerProviderEnvelopeFactoryResult = validation.isAllowed
            ? .executable(envelope: envelope, validation: validation)
            : .blocked(
                .validatorRejected(validation.denialReason ?? .unsupportedCapability),
                validation: validation
            )
        return ServerProviderExecutionGate.evaluate(result)
    }

    private func syntheticServerReadyDecision(
        traceID: String,
        providerFamily: ProviderFamily,
        capability: ProviderCapability,
        costClass: ProviderCostClass
    ) -> ServerProviderExecutionReadinessDecision {
        let envelope = ServerProviderEnvelope(
            traceID: traceID,
            capability: capability,
            providerFamily: providerFamily,
            privacyClass: .general,
            membershipTier: .pro,
            costClass: costClass,
            freshness: .livePreferred
        )
        let validation = ServerProviderEnvelopeValidator.validate(envelope)

        return ServerProviderExecutionReadinessDecision(
            id: "server-provider-execution-\(traceID)",
            state: .serverReady,
            statusLine: "Synthetic server-ready decision for pipeline status audit.",
            sendReadyEnvelope: envelope,
            providerFamily: providerFamily,
            capability: capability,
            privacyClass: envelope.privacyClass,
            membershipTier: envelope.membershipTier,
            costClass: envelope.costClass,
            freshness: envelope.freshness,
            sourcePolicy: envelope.sourcePolicy,
            confirmationState: envelope.confirmationState,
            factoryRejectionReason: nil,
            validatorDenialReason: validation.denialReason,
            validation: validation,
            audit: validation.audit
        )
    }

    private func privateBlockedDecision() throws -> ServerProviderExecutionReadinessDecision {
        let envelope = ServerProviderEnvelope(
            traceID: "receipt-private-block",
            capability: .placeSearch,
            providerFamily: .googleMaps,
            privacyClass: .health,
            membershipTier: .pro,
            costClass: .meteredPremium,
            freshness: .livePreferred,
            meteredProviderEntitlements: [.googleMaps]
        )
        let validation = ServerProviderEnvelopeValidator.validate(envelope)
        return ServerProviderExecutionGate.evaluate(
            .blocked(
                .validatorRejected(try XCTUnwrap(validation.denialReason)),
                validation: validation
            )
        )
    }

    private func badge(
        _ kind: ProviderStatusBadgeKind,
        in presentation: ProviderStatusPresentation
    ) -> ProviderStatusBadgeModel? {
        presentation.badges.first { $0.kind == kind }
    }
}

private struct FixedProviderStatusProvider: ProviderStatusProviding {
    let presentationsByRecommendationID: [String: ProviderStatusPresentation]

    func providerStatusPresentation(
        for recommendationID: String
    ) -> ProviderStatusPresentation? {
        presentationsByRecommendationID[recommendationID]
    }
}

private struct MarkerServerProviderRuntimeAdapter: ServerProviderRuntimeAdapter {
    let providerFamily: ProviderFamily
    let marker: String

    func resolve(
        _ boundary: ServerProviderRuntimeDispatchBoundary
    ) -> ServerProviderRuntimeAdapterResult {
        let result = FixtureServerProviderRuntimeAdapter(providerFamily: providerFamily)
            .resolve(boundary)
        guard result.state == .acceptedFixture else {
            return result
        }
        return ServerProviderRuntimeAdapterResult(
            id: "\(marker)-\(result.id)",
            state: result.state,
            statusLine: result.statusLine,
            boundaryID: result.boundaryID,
            planID: result.planID,
            traceID: result.traceID,
            providerFamily: result.providerFamily,
            capability: result.capability,
            descriptorID: result.descriptorID,
            costClass: result.costClass,
            freshness: result.freshness,
            sourcePolicy: result.sourcePolicy,
            confirmationState: result.confirmationState,
            audit: result.audit
        )
    }
}
