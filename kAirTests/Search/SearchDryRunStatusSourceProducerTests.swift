//
//  SearchDryRunStatusSourceProducerTests.swift
//  kAirTests
//
//  A55 Search dry-run status source producer tests.
//

import XCTest
@testable import kAir

@MainActor
final class SearchDryRunStatusSourceProducerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func test_reportInputsPackageSelectedAndBlockedBySuppliedIDs() throws {
        let query = "late night ramen"
        let selectedID = "producer-selected"
        let blockedID = "producer-blocked"
        let reports = try selectedAndBlockedReports(query: query)
        let producer = SearchDryRunStatusSourceProducer()
        let packagingAdapter = SearchCapabilityAdapter(configuration: .disabled(now: now))

        let source = producer.statusSource(
            adapter: packagingAdapter,
            reports: [
                .init(recommendationID: selectedID, report: reports.selected),
                .init(recommendationID: blockedID, report: reports.blocked),
            ]
        )
        let selected = try XCTUnwrap(source.providerStatusPresentation(for: selectedID))
        let blocked = try XCTUnwrap(source.providerStatusPresentation(for: blockedID))

        XCTAssertEqual(source.recommendationIDs, [blockedID, selectedID])
        XCTAssertEqual(selected.recommendationID, selectedID)
        XCTAssertEqual(selected.cardHint, .warning)
        XCTAssertEqual(badge(.remoteProvider, in: selected)?.tone, .neutral)
        XCTAssertEqual(badge(.meteredPremium, in: selected)?.tone, .neutral)
        XCTAssertTrue(selected.statusLine.contains("example.com"))
        XCTAssertEqual(blocked.recommendationID, blockedID)
        XCTAssertEqual(blocked.cardHint, .disabled)
        XCTAssertEqual(badge(.termsBlocked, in: blocked)?.tone, .warning)
        XCTAssertTrue(blocked.statusLine.contains("Search API is not allowed"))
        XCTAssertNil(source.providerStatusPresentation(for: query))
        XCTAssertNil(source.providerStatusPresentation(for: "producer-missing"))
    }

    func test_presentationInputsDoNotRequireMatchingObjectOrMutateRecommendationFixture() throws {
        let query = "late night ramen"
        let recommendationID = "producer-caller-supplied"
        let fixtureBefore = RecommendationFixtures.placeRoute
        let adapter = try selectedAdapter(query: query)
        let intent = try adapter.intent(
            from: CapabilityRequest(kind: .webSearch, inputText: query)
        )
        let presentation = adapter.dryRunPresentation(for: intent)
        let producer = SearchDryRunStatusSourceProducer()
        let packagingAdapter = SearchCapabilityAdapter(configuration: .disabled(now: now))

        let source = producer.statusSource(
            adapter: packagingAdapter,
            presentations: [
                .init(recommendationID: recommendationID, presentation: presentation),
            ]
        )
        let status = try XCTUnwrap(source.providerStatusPresentation(for: recommendationID))

        XCTAssertEqual(RecommendationFixtures.placeRoute, fixtureBefore)
        XCTAssertEqual(status.recommendationID, recommendationID)
        XCTAssertEqual(status.cardHint, .warning)
        XCTAssertNil(source.providerStatusPresentation(for: RecommendationFixtures.placeRoute.id))
        XCTAssertNil(source.providerStatusPresentation(for: query))
    }

    func test_duplicateIDsKeepFirstInputAndMissingIDsReturnNil() throws {
        let query = "late night ramen"
        let duplicateID = "producer-duplicate"
        let reports = try selectedAndBlockedReports(query: query)
        let producer = SearchDryRunStatusSourceProducer()
        let packagingAdapter = SearchCapabilityAdapter(configuration: .disabled(now: now))

        let source = producer.statusSource(
            adapter: packagingAdapter,
            reports: [
                .init(recommendationID: duplicateID, report: reports.selected),
                .init(recommendationID: duplicateID, report: reports.blocked),
            ]
        )
        let presentation = try XCTUnwrap(source.providerStatusPresentation(for: duplicateID))

        XCTAssertEqual(source.recommendationIDs, [duplicateID])
        XCTAssertEqual(presentation.cardHint, .warning)
        XCTAssertEqual(badge(.remoteProvider, in: presentation)?.tone, .neutral)
        XCTAssertNil(badge(.termsBlocked, in: presentation))
        XCTAssertTrue(presentation.statusLine.contains("example.com"))
        XCTAssertFalse(presentation.statusLine.contains("Search API is not allowed"))
        XCTAssertNil(source.providerStatusPresentation(for: "missing-duplicate"))
    }

    func test_copyStaysAdvisoryOnly() throws {
        let reports = try selectedAndBlockedReports(query: "late night ramen")
        let producer = SearchDryRunStatusSourceProducer()
        let packagingAdapter = SearchCapabilityAdapter(configuration: .disabled(now: now))

        let source = producer.statusSource(
            adapter: packagingAdapter,
            reports: [
                .init(recommendationID: "producer-copy-selected", report: reports.selected),
                .init(recommendationID: "producer-copy-blocked", report: reports.blocked),
            ]
        )
        let presentations = try [
            source.providerStatusPresentation(for: "producer-copy-selected"),
            source.providerStatusPresentation(for: "producer-copy-blocked"),
        ].map { try XCTUnwrap($0) }
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
            "provider contacted",
            "booked",
            "ordered",
            "paid",
            "purchased",
            "crawled",
        ] {
            XCTAssertFalse(text.contains(forbidden), "Unexpected wording: \(forbidden)")
        }
    }

    private func selectedAndBlockedReports(
        query: String
    ) throws -> (selected: ServerProviderDryRunReport, blocked: ServerProviderDryRunReport) {
        let selectedAdapter = try selectedAdapter(query: query)
        let blockedAdapter = try blockedAdapter(query: query)
        let selectedIntent = try selectedAdapter.intent(
            from: CapabilityRequest(kind: .webSearch, inputText: query)
        )
        let blockedIntent = try blockedAdapter.intent(
            from: CapabilityRequest(kind: .webSearch, inputText: query)
        )

        return (
            selected: selectedAdapter.dryRunPreview(for: selectedIntent),
            blocked: blockedAdapter.dryRunPreview(for: blockedIntent)
        )
    }

    private func selectedAdapter(query: String) throws -> SearchCapabilityAdapter {
        let profile = ProviderAccessProfile(
            membershipTier: .plus,
            meteredProviderEntitlements: [.searchAPI]
        )
        let quota = ServerProviderQuotaSnapshot(
            providerAccessProfile: profile,
            allowedProviderFamilies: [.searchAPI],
            meteredEligibleProviderFamilies: [.searchAPI]
        )
        return SearchCapabilityAdapter(
            configuration: .enabledFixture(
                providerAccessProfile: profile,
                providerQuotaSnapshot: quota,
                resultDrafts: [query: try ramenDraft()],
                now: now
            )
        )
    }

    private func blockedAdapter(query: String) throws -> SearchCapabilityAdapter {
        let profile = ProviderAccessProfile(
            membershipTier: .plus,
            meteredProviderEntitlements: [.searchAPI]
        )
        return SearchCapabilityAdapter(
            configuration: .enabledFixture(
                providerAccessProfile: profile,
                resultDrafts: [query: try ramenDraft()],
                now: now
            )
        )
    }

    private func badge(
        _ kind: ProviderStatusBadgeKind,
        in presentation: ProviderStatusPresentation
    ) -> ProviderStatusBadgeModel? {
        presentation.badges.first { $0.kind == kind }
    }

    private func ramenDraft() throws -> SearchResultDraft {
        SearchResultDraft(
            sourceURL: try XCTUnwrap(URL(string: "https://example.com/ramen-hours")),
            title: "Late-night ramen hours",
            snippet: "Public listing with hours.",
            attribution: "example.com",
            confidence: 0.82,
            limitations: ["Verify public information before acting."]
        )
    }
}
