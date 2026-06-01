//
//  SearchIntentTests.swift
//  kAirTests
//
//  A33 SearchIntent access-profile lowering tests.
//

import XCTest
@testable import kAir

final class SearchIntentTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_200)

    func test_profileLoweringUsesMembershipAndSearchEntitlementFromProfile() throws {
        let intent = SearchIntent(
            query: "  coffee   nearby ",
            category: .lifeService,
            sourceMode: .searchAPI,
            privacyClass: .general,
            membershipTier: .free,
            meteredProviderEntitlements: [],
            freshness: .livePreferred,
            requestedAt: now
        )
        let profile = ProviderAccessProfile(
            membershipTier: .plus,
            defaultRegion: .northAmerica,
            preferredProvider: .googleMaps,
            meteredProviderEntitlements: [.searchAPI]
        )

        let request = intent.providerRequest(
            providerAccessProfile: profile,
            resultDraft: try publicDraft(title: "Coffee nearby"),
            now: now
        )
        let decision = SearchProviderPolicy.evaluate(request)

        XCTAssertEqual(request.query, "coffee nearby")
        XCTAssertEqual(request.capability, .localServiceSearch)
        XCTAssertEqual(request.membershipTier, .plus)
        XCTAssertEqual(request.meteredProviderEntitlements, [.searchAPI])
        XCTAssertEqual(request.preferredProvider, .searchAPI)
        XCTAssertTrue(decision.isResolved)
        XCTAssertEqual(decision.selectedProvider?.family, .searchAPI)
    }

    func test_profileLoweringUsesCrawlerEnablementAndKeepsRobotsExplicit() throws {
        let intent = SearchIntent(
            query: "public menu",
            sourceMode: .crawlerFetch,
            privacyClass: .general,
            membershipTier: .free,
            meteredProviderEntitlements: [],
            freshness: .liveRequired,
            robotsState: .allowed,
            requestedAt: now
        )
        let profile = ProviderAccessProfile.developerInternalDiagnostics(
            preferredProvider: .searchAPI,
            enabledExperimentalProviders: [.crawler],
            meteredProviderEntitlements: [.crawler]
        )

        let request = intent.providerRequest(
            providerAccessProfile: profile,
            resultDraft: try publicDraft(title: "Public menu"),
            now: now
        )
        let decision = SearchProviderPolicy.evaluate(request)

        XCTAssertEqual(request.membershipTier, .developerInternal)
        XCTAssertEqual(request.preferredProvider, .crawler)
        XCTAssertEqual(request.enabledExperimentalProviders, [.crawler])
        XCTAssertEqual(request.robotsState, .allowed)
        XCTAssertTrue(decision.isResolved)
        XCTAssertEqual(decision.selectedProvider?.family, .crawler)
    }

    func test_sourceModeOverridesProfilePreferredProvider() throws {
        let intent = SearchIntent(
            query: "weekend brunch",
            sourceMode: .cacheOnly,
            privacyClass: .general,
            requestedAt: now
        )
        let profile = ProviderAccessProfile(
            membershipTier: .pro,
            preferredProvider: .searchAPI,
            meteredProviderEntitlements: [.searchAPI]
        )

        let request = intent.providerRequest(
            providerAccessProfile: profile,
            cachedResult: try cachedResult(query: "weekend brunch"),
            now: now
        )
        let decision = SearchProviderPolicy.evaluate(request)

        XCTAssertEqual(request.preferredProvider, .cache)
        XCTAssertEqual(decision.selectedProvider?.family, .cache)
        XCTAssertEqual(decision.result?.providerID, "search-cache")
    }

    func test_privacyAndRobotsStayExplicitOnIntentNotProfile() throws {
        let intent = SearchIntent(
            query: "private listing",
            sourceMode: .crawlerFetch,
            privacyClass: .health,
            membershipTier: .free,
            robotsState: .disallowed,
            requestedAt: now
        )
        let profile = ProviderAccessProfile.developerInternalDiagnostics(
            enabledExperimentalProviders: [.crawler],
            meteredProviderEntitlements: [.crawler]
        )

        let request = intent.providerRequest(
            providerAccessProfile: profile,
            resultDraft: try publicDraft(),
            now: now
        )

        XCTAssertEqual(request.membershipTier, .developerInternal)
        XCTAssertEqual(request.privacyClass, .health)
        XCTAssertEqual(request.robotsState, .disallowed)
        XCTAssertEqual(request.preferredProvider, .crawler)
    }

    func test_legacyFixtureLoweringStillUsesSearchIntentFixtureFields() throws {
        let intent = SearchIntent(
            query: "late night ramen",
            sourceMode: .searchAPI,
            membershipTier: .plus,
            meteredProviderEntitlements: [.searchAPI],
            requestedAt: now
        )

        let request = intent.providerRequest(
            resultDraft: try publicDraft(title: "Late night ramen"),
            now: now
        )
        let decision = SearchProviderPolicy.evaluate(request)

        XCTAssertEqual(request.membershipTier, .plus)
        XCTAssertEqual(request.meteredProviderEntitlements, [.searchAPI])
        XCTAssertEqual(request.preferredProvider, .searchAPI)
        XCTAssertTrue(decision.isResolved)
    }

    private func publicDraft(
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

    private func cachedResult(query: String) throws -> SearchResultEnvelope {
        SearchResultEnvelope(
            query: query,
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
    }
}
