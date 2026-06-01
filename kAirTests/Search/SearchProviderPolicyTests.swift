//
//  SearchProviderPolicyTests.swift
//  kAirTests
//
//  A5c search/crawler reservation contracts: cited envelopes, freshness,
//  source policy, robots policy, privacy, cost, and cache fallback.
//

import XCTest
@testable import kAir

final class SearchProviderPolicyTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func test_citedSuccess_buildsSearchResultEnvelope() throws {
        let sourceURL = try XCTUnwrap(URL(string: "https://example.com/restaurants/ramen"))
        let draft = SearchResultDraft(
            sourceURL: sourceURL,
            title: "Late-night ramen",
            snippet: "Open public listing with hours and neighborhood context.",
            attribution: "example.com",
            confidence: 0.82,
            limitations: ["Public web result; verify before booking."]
        )

        let decision = SearchProviderPolicy.evaluate(
            SearchProviderRequest(
                traceID: "search-success",
                query: "late night ramen near me",
                privacyClass: .general,
                membershipTier: .plus,
                preferredProvider: .searchAPI,
                meteredProviderEntitlements: [.searchAPI],
                freshness: .livePreferred,
                resultDraft: draft,
                now: now
            )
        )

        XCTAssertTrue(decision.isResolved)
        XCTAssertEqual(decision.selectedProvider?.family, .searchAPI)
        XCTAssertEqual(decision.result?.query, "late night ramen near me")
        XCTAssertEqual(decision.result?.providerID, "search-api")
        XCTAssertEqual(decision.result?.sourceURL, sourceURL)
        XCTAssertEqual(decision.result?.fetchedAt, now)
        XCTAssertEqual(decision.result?.freshness, .livePreferred)
        XCTAssertEqual(decision.result?.costClass, .meteredPremium)
        XCTAssertEqual(decision.result?.confidence, 0.82)
        XCTAssertEqual(decision.result?.attribution, "example.com")
        XCTAssertEqual(decision.trace.selectedProviderFamily, .searchAPI)
    }

    func test_robotsBlocked_preventsCrawlerResult() throws {
        let draft = SearchResultDraft(
            sourceURL: try XCTUnwrap(URL(string: "https://public.example.com/menu")),
            title: "Menu",
            snippet: "Public menu fixture.",
            attribution: "public.example.com",
            confidence: 0.72
        )

        let decision = SearchProviderPolicy.evaluate(
            SearchProviderRequest(
                query: "menu",
                capability: .crawlerFetch,
                membershipTier: .developerInternal,
                preferredProvider: .crawler,
                meteredProviderEntitlements: [.crawler],
                enabledExperimentalProviders: [.crawler],
                robotsState: .disallowed,
                resultDraft: draft,
                now: now
            )
        )

        XCTAssertNil(decision.result)
        XCTAssertEqual(decision.failureReason, .robotsBlocked)
        XCTAssertTrue(
            decision.skippedProviders.contains {
                $0.family == .crawler && $0.reason == .robotsBlocked
            }
        )
        XCTAssertEqual(decision.trace.failureReason, .unavailable)
    }

    func test_sourceDenied_blocksCrawlerForAppleSites() throws {
        let draft = SearchResultDraft(
            sourceURL: try XCTUnwrap(URL(string: "https://apps.apple.com/app/example")),
            title: "App Store listing",
            snippet: "Denied source fixture.",
            attribution: "apps.apple.com",
            confidence: 0.9
        )

        let decision = SearchProviderPolicy.evaluate(
            SearchProviderRequest(
                query: "app store listing",
                capability: .crawlerFetch,
                membershipTier: .developerInternal,
                preferredProvider: .crawler,
                meteredProviderEntitlements: [.crawler],
                enabledExperimentalProviders: [.crawler],
                robotsState: .allowed,
                resultDraft: draft,
                now: now
            )
        )

        XCTAssertNil(decision.result)
        XCTAssertEqual(decision.failureReason, .sourceDenied)
        XCTAssertTrue(
            decision.skippedProviders.contains {
                $0.family == .crawler && $0.reason == .sourceDenied
            }
        )
    }

    func test_costBlocked_meteredSearchRequiresEntitlement() throws {
        let draft = SearchResultDraft(
            sourceURL: try XCTUnwrap(URL(string: "https://example.com/coffee")),
            title: "Coffee",
            snippet: "Public coffee fixture.",
            attribution: "example.com",
            confidence: 0.74
        )

        let decision = SearchProviderPolicy.evaluate(
            SearchProviderRequest(
                query: "coffee nearby",
                membershipTier: .plus,
                preferredProvider: .searchAPI,
                resultDraft: draft,
                now: now
            )
        )

        XCTAssertNil(decision.result)
        XCTAssertEqual(decision.failureReason, .costBlocked)
        XCTAssertEqual(decision.trace.costClass, .blockedByCost)
        XCTAssertTrue(
            decision.skippedProviders.contains {
                $0.family == .searchAPI && $0.reason == .costBlocked
            }
        )
    }

    func test_privacyBlocked_remoteSearchCannotServePrivateContext() throws {
        let draft = SearchResultDraft(
            sourceURL: try XCTUnwrap(URL(string: "https://example.com/private-topic")),
            title: "Private topic",
            snippet: "Should not route remotely.",
            attribution: "example.com",
            confidence: 0.7
        )

        let decision = SearchProviderPolicy.evaluate(
            SearchProviderRequest(
                query: "private health-adjacent note",
                privacyClass: .private,
                membershipTier: .pro,
                preferredProvider: .searchAPI,
                meteredProviderEntitlements: [.searchAPI],
                resultDraft: draft,
                now: now
            )
        )

        XCTAssertNil(decision.result)
        XCTAssertEqual(decision.failureReason, .privacyBlocked)
        XCTAssertEqual(decision.trace.costClass, .blockedByPrivacy)
    }

    func test_staleCacheFallback_marksLimitationsAndUsesCacheProvider() throws {
        let cached = SearchResultEnvelope(
            query: "weekend brunch",
            providerID: "previous-search-api",
            sourceURL: try XCTUnwrap(URL(string: "https://example.com/brunch")),
            title: "Weekend brunch",
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
                query: "weekend brunch",
                membershipTier: .free,
                preferredProvider: .searchAPI,
                cachedResult: cached,
                now: now
            )
        )

        XCTAssertEqual(decision.selectedProvider?.family, .cache)
        XCTAssertEqual(decision.result?.providerID, "search-cache")
        XCTAssertEqual(decision.result?.costClass, .freeLocal)
        XCTAssertEqual(decision.result?.fetchedAt, now)
        XCTAssertEqual(decision.result?.freshness, .cachedOK)
        XCTAssertEqual(decision.result?.isStaleCache, true)
        XCTAssertTrue(
            decision.skippedProviders.contains {
                $0.family == .searchAPI && $0.reason == .costBlocked
            }
        )
    }
}
