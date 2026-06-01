//
//  SearchRenderedDryRunStatusSourceTests.swift
//  kAirTests
//
//  A57 Search rendered dry-run status source guard tests.
//

import XCTest
@testable import kAir

@MainActor
final class SearchRenderedDryRunStatusSourceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func test_renderedSelectedAndBlockedIDsReturnWrappedProducerStatus() throws {
        let selectedID = "rendered-selected"
        let blockedID = "rendered-blocked"
        let guardedSource = try renderedSource(
            renderedIDs: [selectedID, blockedID],
            selectedID: selectedID,
            blockedID: blockedID
        )

        let selected = try XCTUnwrap(
            guardedSource.providerStatusPresentation(for: selectedID)
        )
        let blocked = try XCTUnwrap(
            guardedSource.providerStatusPresentation(for: blockedID)
        )

        XCTAssertEqual(guardedSource.renderedRecommendationIDs, [blockedID, selectedID])
        XCTAssertEqual(selected.recommendationID, selectedID)
        XCTAssertEqual(selected.cardHint, .warning)
        XCTAssertEqual(badge(.remoteProvider, in: selected)?.tone, .neutral)
        XCTAssertEqual(badge(.meteredPremium, in: selected)?.tone, .neutral)
        XCTAssertTrue(selected.statusLine.contains("example.com"))
        XCTAssertEqual(blocked.recommendationID, blockedID)
        XCTAssertEqual(blocked.cardHint, .disabled)
        XCTAssertEqual(badge(.termsBlocked, in: blocked)?.tone, .warning)
        XCTAssertTrue(blocked.statusLine.contains("Search API is not allowed"))
    }

    func test_hiddenWrappedStoreIDReturnsNilWhenNotRendered() throws {
        let selectedID = "rendered-selected"
        let blockedID = "rendered-blocked"
        let hiddenID = "hidden-search-status"
        let guardedSource = try renderedSource(
            renderedIDs: [selectedID, blockedID],
            selectedID: selectedID,
            blockedID: blockedID,
            hiddenID: hiddenID
        )

        XCTAssertNil(guardedSource.providerStatusPresentation(for: hiddenID))
        XCTAssertNil(guardedSource.providerStatusPresentation(for: "missing-search-status"))
    }

    func test_duplicateRenderedIDsAreDeterministic() throws {
        let selectedID = "rendered-selected"
        let blockedID = "rendered-blocked"
        let guardedSource = try renderedSource(
            renderedIDs: [selectedID, selectedID, blockedID, selectedID],
            selectedID: selectedID,
            blockedID: blockedID
        )

        XCTAssertEqual(guardedSource.renderedRecommendationIDs, [blockedID, selectedID])
        XCTAssertNotNil(guardedSource.providerStatusPresentation(for: selectedID))
        XCTAssertNotNil(guardedSource.providerStatusPresentation(for: blockedID))
    }

    func test_wrapperDoesNotMutateMatchingObjectOrInferFixtureID() throws {
        let selectedID = "caller-selected"
        let blockedID = "caller-blocked"
        let fixtureBefore = RecommendationFixtures.placeRoute
        let guardedSource = try renderedSource(
            renderedIDs: [selectedID],
            selectedID: selectedID,
            blockedID: blockedID
        )

        XCTAssertEqual(RecommendationFixtures.placeRoute, fixtureBefore)
        XCTAssertNotNil(guardedSource.providerStatusPresentation(for: selectedID))
        XCTAssertNil(guardedSource.providerStatusPresentation(for: RecommendationFixtures.placeRoute.id))
        XCTAssertNil(guardedSource.providerStatusPresentation(for: "late night ramen"))
    }

    private func renderedSource(
        renderedIDs: [String],
        selectedID: String,
        blockedID: String,
        hiddenID: String? = nil
    ) throws -> SearchRenderedDryRunStatusSource {
        let producer = SearchDryRunStatusSourceProducer()
        let packagingAdapter = SearchCapabilityAdapter(configuration: .disabled(now: now))
        var inputs: [SearchDryRunStatusSourceProducer.ReportInput] = [
            .init(recommendationID: selectedID, report: try selectedReport()),
            .init(recommendationID: blockedID, report: try blockedReport()),
        ]
        if let hiddenID {
            inputs.append(.init(recommendationID: hiddenID, report: try selectedReport()))
        }
        let source = producer.statusSource(
            adapter: packagingAdapter,
            reports: inputs
        )
        return SearchRenderedDryRunStatusSource(
            source: source,
            renderedRecommendationIDs: renderedIDs
        )
    }

    private func selectedReport() throws -> ServerProviderDryRunReport {
        let adapter = try selectedAdapter()
        let intent = try adapter.intent(
            from: CapabilityRequest(kind: .webSearch, inputText: "late night ramen")
        )
        return adapter.dryRunPreview(for: intent)
    }

    private func blockedReport() throws -> ServerProviderDryRunReport {
        let adapter = try blockedAdapter()
        let intent = try adapter.intent(
            from: CapabilityRequest(kind: .webSearch, inputText: "late night ramen")
        )
        return adapter.dryRunPreview(for: intent)
    }

    private func selectedAdapter() throws -> SearchCapabilityAdapter {
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
                resultDrafts: ["late night ramen": try ramenDraft()],
                now: now
            )
        )
    }

    private func blockedAdapter() throws -> SearchCapabilityAdapter {
        let profile = ProviderAccessProfile(
            membershipTier: .plus,
            meteredProviderEntitlements: [.searchAPI]
        )
        return SearchCapabilityAdapter(
            configuration: .enabledFixture(
                providerAccessProfile: profile,
                resultDrafts: ["late night ramen": try ramenDraft()],
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
