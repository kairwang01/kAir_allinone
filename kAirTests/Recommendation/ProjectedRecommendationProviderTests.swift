//
//  ProjectedRecommendationProviderTests.swift
//  kAirTests
//
//  A5e deterministic seam: provider/search/MCP projections become
//  recommendation/chat-consumable fixtures without changing UI layout.
//

import XCTest
@testable import kAir

@MainActor
final class ProjectedRecommendationProviderTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func test_resolvedMapProjectionBuildsRouteRecommendationAndChatStoreCanConsumeIt() {
        let providerSelection = ProviderRoutingPolicy.select(
            for: ProviderRequest(
                traceID: "map-rec",
                capability: .routePlanning,
                region: .northAmerica,
                membershipTier: .free
            )
        )
        let projection = ResultProjector.project(
            providerSelection: providerSelection,
            createdAt: now
        )
        let provider = ProjectedRecommendationProvider(projections: [projection])

        let item = tryUnwrap(provider.projectedRecommendations().first)
        let object = item.object

        XCTAssertEqual(item.state, .ready)
        XCTAssertTrue(item.isActionable)
        XCTAssertEqual(object.kind, .route)
        XCTAssertEqual(object.preferredSection, .maps)
        XCTAssertFalse(object.activationPrompt.isEmpty)
        XCTAssertEqual(item.metadata.providerID, "apple-local")
        XCTAssertEqual(item.metadata.costClass, .freeLocal)
        XCTAssertEqual(item.metadata.trace.traceID, "map-rec")
        XCTAssertLessThanOrEqual(object.subtitleTokens.count, 2)

        let store = ChatStore(recommendationProvider: provider)
        XCTAssertEqual(store.recommendedMatches, [object])
    }

    func test_resolvedSearchProjectionBuildsSearchRecommendationAndPreservesMetadata() throws {
        let searchDecision = SearchProviderPolicy.evaluate(
            SearchProviderRequest(
                traceID: "search-rec",
                query: "public ramen hours",
                membershipTier: .plus,
                preferredProvider: .searchAPI,
                meteredProviderEntitlements: [.searchAPI],
                freshness: .livePreferred,
                resultDraft: SearchResultDraft(
                    sourceURL: try XCTUnwrap(URL(string: "https://example.com/ramen")),
                    title: "Ramen hours",
                    snippet: "Public result with hours.",
                    attribution: "example.com",
                    confidence: 0.83,
                    limitations: ["Verify hours before visiting."]
                ),
                now: now
            )
        )
        let projection = ResultProjector.project(searchDecision: searchDecision, createdAt: now)

        let item = ResultRecommendationProjector.project(projection)

        XCTAssertEqual(item.state, .ready)
        XCTAssertTrue(item.isActionable)
        XCTAssertEqual(item.object.kind, .searchResult)
        XCTAssertEqual(item.object.preferredSection, .search)
        XCTAssertTrue(item.object.activationPrompt.hasPrefix("Review cited result:"))
        XCTAssertEqual(item.metadata.providerID, "search-api")
        XCTAssertEqual(item.metadata.providerFamily, .searchAPI)
        XCTAssertEqual(item.metadata.costClass, .meteredPremium)
        XCTAssertEqual(item.metadata.freshness, .livePreferred)
        XCTAssertEqual(item.metadata.trace.selectedProviderFamily, .searchAPI)
        XCTAssertLessThanOrEqual(item.object.subtitleTokens.count, 2)
    }

    func test_staleCacheProjectionRemainsReadyButCarriesStaleLimitation() throws {
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
        let decision = SearchProviderPolicy.evaluate(
            SearchProviderRequest(
                traceID: "cache-rec",
                query: "brunch",
                membershipTier: .free,
                preferredProvider: .searchAPI,
                cachedResult: cached,
                now: now
            )
        )
        let projection = ResultProjector.project(searchDecision: decision, createdAt: now)

        let item = ResultRecommendationProjector.project(projection)

        XCTAssertEqual(item.state, .ready)
        XCTAssertEqual(item.object.kind, .searchResult)
        XCTAssertEqual(item.metadata.providerID, "search-cache")
        XCTAssertEqual(item.metadata.providerFamily, .cache)
        XCTAssertEqual(item.metadata.costClass, .freeLocal)
        XCTAssertEqual(item.metadata.freshness, .cachedOK)
        XCTAssertTrue(item.metadata.limitations.contains(SearchProviderPolicy.staleCacheLimitation))
    }

    func test_blockedMCPProjectionBecomesNonActionableBlockedRecommendation() {
        let decision = MCPGatewayPolicy.authorize(
            MCPGatewayRequest(
                traceID: "mcp-rec",
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
        let projection = ResultProjector.project(mcpDecision: decision)

        let item = ResultRecommendationProjector.project(projection)

        XCTAssertEqual(item.state, .blocked)
        XCTAssertFalse(item.isActionable)
        XCTAssertEqual(item.object.kind, .toolEntry)
        XCTAssertEqual(item.object.primaryCTA, "Unavailable")
        XCTAssertEqual(item.object.activationPrompt, "")
        XCTAssertNil(item.object.preferredSection)
        XCTAssertNotEqual(item.object.primaryCTA, "Open")
        XCTAssertNotEqual(item.object.primaryCTA, "Review result")
        XCTAssertNil(item.metadata.providerID)
        XCTAssertEqual(item.metadata.trace.failureReason, .unavailable)
    }

    func test_projectedProviderCapsSlateAndKeepsMetadataLookupByRecommendationID() {
        let projections = (0..<5).map { index in
            ResultProjector.project(
                providerSelection: ProviderRoutingPolicy.select(
                    for: ProviderRequest(
                        traceID: "route-\(index)",
                        capability: .routePlanning,
                        region: .northAmerica,
                        membershipTier: .free
                    )
                ),
                createdAt: now
            )
        }
        let provider = ProjectedRecommendationProvider(projections: projections)

        let items = provider.projectedRecommendations()
        XCTAssertEqual(items.count, ProjectedRecommendationProvider.maxProjectedSlateSize)
        XCTAssertEqual(provider.recommendedMatches(), items.map(\.object))

        let first = tryUnwrap(items.first)
        let metadata = tryUnwrap(provider.metadata(for: first.id))
        XCTAssertEqual(metadata.providerID, "apple-local")
        XCTAssertEqual(metadata.trace.traceID, "route-0")
    }

    private func tryUnwrap<T>(
        _ value: T?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> T {
        guard let value else {
            XCTFail("Expected non-nil value", file: file, line: line)
            fatalError("Expected non-nil value")
        }
        return value
    }
}
