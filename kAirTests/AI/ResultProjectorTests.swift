//
//  ResultProjectorTests.swift
//  kAirTests
//
//  A5d fixture-only provider projection: map/search/MCP decisions normalize
//  into one UI/recommendation envelope without provider runtime calls.
//

import XCTest
@testable import kAir

final class ResultProjectorTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func test_mapProviderFixtureProjectsToNormalizedRouteResult() {
        let selection = ProviderRoutingPolicy.select(
            for: ProviderRequest(
                traceID: "map-route",
                capability: .routePlanning,
                region: .northAmerica,
                membershipTier: .free
            )
        )

        let projection = ResultProjector.project(
            providerSelection: selection,
            createdAt: now
        )

        XCTAssertTrue(projection.isResolved)
        XCTAssertEqual(projection.status, .resolved)
        XCTAssertEqual(projection.surface, .maps)
        XCTAssertEqual(projection.capability, .routePlanning)
        XCTAssertEqual(projection.metadata.providerID, "apple-local")
        XCTAssertEqual(projection.metadata.providerFamily, .appleLocal)
        XCTAssertEqual(projection.metadata.costClass, .freeLocal)
        XCTAssertEqual(projection.metadata.trace.traceID, "map-route")
        XCTAssertEqual(projection.normalizedResult?.source, .local)
        XCTAssertEqual(projection.normalizedResult?.createdAt, now)
        XCTAssertTrue(
            NormalizedResult.variantMatchesCapability(
                tryUnwrap(projection.normalizedResult).payload,
                .routePlanning
            )
        )
        XCTAssertTrue(
            projection.metadata.limitations.contains {
                $0.contains("no real map SDK call")
            }
        )
    }

    func test_searchCitedFixtureProjectsToNormalizedWebSearch() throws {
        let sourceURL = try XCTUnwrap(URL(string: "https://example.com/food/ramen"))
        let draft = SearchResultDraft(
            sourceURL: sourceURL,
            title: "Ramen shops",
            snippet: "Public listing with cited hours.",
            attribution: "example.com",
            confidence: 0.84,
            limitations: ["Verify hours before visiting."]
        )
        let decision = SearchProviderPolicy.evaluate(
            SearchProviderRequest(
                traceID: "search-cited",
                query: "ramen near me",
                membershipTier: .plus,
                preferredProvider: .searchAPI,
                meteredProviderEntitlements: [.searchAPI],
                freshness: .livePreferred,
                resultDraft: draft,
                now: now
            )
        )

        let projection = ResultProjector.project(
            searchDecision: decision,
            createdAt: now
        )

        XCTAssertTrue(projection.isResolved)
        XCTAssertEqual(projection.surface, .search)
        XCTAssertEqual(projection.capability, .webSearch)
        XCTAssertEqual(projection.metadata.providerID, "search-api")
        XCTAssertEqual(projection.metadata.costClass, .meteredPremium)
        XCTAssertEqual(projection.metadata.freshness, .livePreferred)
        XCTAssertEqual(projection.metadata.trace.selectedProviderFamily, .searchAPI)
        XCTAssertEqual(projection.normalizedResult?.source, .partner)
        XCTAssertEqual(projection.normalizedResult?.confidence, 0.84)
        XCTAssertTrue(
            NormalizedResult.variantMatchesCapability(
                tryUnwrap(projection.normalizedResult).payload,
                .webSearch
            )
        )
    }

    func test_staleCacheFixtureProjectsAsLocalWebSearchWithLimitations() throws {
        let cached = SearchResultEnvelope(
            query: "brunch",
            providerID: "previous-search-api",
            sourceURL: try XCTUnwrap(URL(string: "https://example.com/brunch")),
            title: "Brunch",
            snippet: "Cached public result.",
            fetchedAt: Date(timeIntervalSince1970: 1_700_000_000),
            freshness: .cachedOK,
            costClass: .meteredPremium,
            confidence: 0.62,
            limitations: ["Older public listing."],
            attribution: "example.com"
        )
        let decision = SearchProviderPolicy.evaluate(
            SearchProviderRequest(
                traceID: "search-cache",
                query: "brunch",
                membershipTier: .free,
                preferredProvider: .searchAPI,
                cachedResult: cached,
                now: now
            )
        )

        let projection = ResultProjector.project(searchDecision: decision, createdAt: now)

        XCTAssertTrue(projection.isResolved)
        XCTAssertEqual(projection.metadata.providerID, "search-cache")
        XCTAssertEqual(projection.metadata.providerFamily, .cache)
        XCTAssertEqual(projection.metadata.costClass, .freeLocal)
        XCTAssertEqual(projection.metadata.freshness, .cachedOK)
        XCTAssertEqual(projection.normalizedResult?.source, .local)
        XCTAssertTrue(
            projection.metadata.limitations.contains(SearchProviderPolicy.staleCacheLimitation)
        )
    }

    func test_mcpBlockedFixtureProjectsWithoutNormalizedResult() {
        let decision = MCPGatewayPolicy.authorize(
            MCPGatewayRequest(
                traceID: "mcp-blocked",
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

        XCTAssertFalse(projection.isResolved)
        XCTAssertEqual(projection.status, .blocked)
        XCTAssertEqual(projection.surface, .chat)
        XCTAssertNil(projection.normalizedResult)
        XCTAssertNil(projection.metadata.providerID)
        XCTAssertEqual(projection.metadata.trace.traceID, "mcp-blocked")
        XCTAssertEqual(projection.metadata.trace.failureReason, .unavailable)
        XCTAssertTrue(
            projection.metadata.limitations.contains {
                $0.contains("MCP operation was not executed")
            }
        )
    }

    func test_projectionDoesNotExposeRawPromptHealthDataAPIKeyOrPersonalSecret() throws {
        let rawPrompt = "raw prompt: health blood_pressure sk-test-secret ssn 123"
        let sourceURL = try XCTUnwrap(URL(string: "https://example.com/public"))
        let draft = SearchResultDraft(
            sourceURL: sourceURL,
            title: "Public result",
            snippet: "Cited public information.",
            attribution: "example.com",
            confidence: 0.8
        )
        let decision = SearchProviderPolicy.evaluate(
            SearchProviderRequest(
                traceID: "search-sensitive",
                query: rawPrompt,
                membershipTier: .plus,
                preferredProvider: .searchAPI,
                meteredProviderEntitlements: [.searchAPI],
                resultDraft: draft,
                now: now
            )
        )

        let projection = ResultProjector.project(searchDecision: decision, createdAt: now)
        let exposedText = visibleProjectionText(projection)

        XCTAssertFalse(exposedText.contains(rawPrompt))
        XCTAssertFalse(exposedText.contains("blood_pressure"))
        XCTAssertFalse(exposedText.contains("sk-test-secret"))
        XCTAssertFalse(exposedText.contains("ssn 123"))
        XCTAssertTrue(projection.isResolved)
    }

    private func tryUnwrap<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) -> T {
        guard let value else {
            XCTFail("Expected non-nil value", file: file, line: line)
            fatalError("Expected non-nil value")
        }
        return value
    }

    private func visibleProjectionText(_ projection: ProjectedProviderResult) -> String {
        var parts = [
            projection.summaryTitle,
            projection.summarySubtitle,
            projection.metadata.providerID ?? "",
            projection.metadata.providerFamily?.rawValue ?? "",
            projection.metadata.costClass.rawValue,
            projection.metadata.freshness.rawValue,
        ]
        parts.append(contentsOf: projection.metadata.limitations)

        if let result = projection.normalizedResult {
            switch result.payload {
            case .webSearch(let hits):
                for hit in hits {
                    parts.append(hit.title)
                    parts.append(hit.url)
                    parts.append(hit.snippet ?? "")
                }
            case .placeSearch(let places):
                for place in places {
                    parts.append(place.name)
                    parts.append(place.address ?? "")
                }
            case .routePlanning(let route):
                parts.append(route.origin)
                parts.append(route.destination)
            case .aiCompletion(let completion):
                parts.append(completion.text)
                parts.append(completion.runtimeFamily ?? "")
            case .threadLookup(let thread):
                parts.append(thread.threadID)
                parts.append(thread.title ?? "")
            case .localStoreLookup(let item):
                parts.append(item.id)
                parts.append(item.title)
            case .musicPlayback(let track):
                parts.append(track.id)
                parts.append(track.title)
            case .videoPlayback(let video):
                parts.append(video.id)
                parts.append(video.title)
            case .healthRead(let snapshot):
                parts.append(snapshot.metricToken)
            case .healthWrite(let receipt):
                parts.append(receipt.metricToken)
            }
        }

        return parts.joined(separator: "\n")
    }
}
