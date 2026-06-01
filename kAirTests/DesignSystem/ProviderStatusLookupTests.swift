//
//  ProviderStatusLookupTests.swift
//  kAirTests
//
//  A5g provider status lookup seam. Verifies non-invasive status lookup by
//  recommendation id without changing rail layout or MatchingObject data.
//

import XCTest
@testable import kAir

@MainActor
final class ProviderStatusLookupTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func test_projectedProviderStatusLookup_hitsForKnownRecommendationID() {
        let provider = projectedProvider(traceID: "lookup-hit")
        let object = tryUnwrap(provider.recommendedMatches().first)

        let presentation = tryUnwrap(
            provider.providerStatusPresentation(for: object.id)
        )

        XCTAssertEqual(presentation.recommendationID, object.id)
        XCTAssertTrue(presentation.statusLine.contains("apple-local"))
        XCTAssertEqual(
            presentation.badges.first { $0.kind == .localProvider }?.tone,
            .positive
        )
    }

    func test_projectedProviderStatusLookup_missesForUnknownRecommendationID() {
        let provider = projectedProvider(traceID: "lookup-miss")

        XCTAssertNil(provider.providerStatusPresentation(for: "missing-rec"))
    }

    func test_chatStoreDefaultProviderDoesNotExposeFakeProviderStatus() {
        let store = ChatStore()
        let object = tryUnwrap(store.recommendedMatches.first)

        XCTAssertNil(store.providerStatusPresentation(for: object.id))
    }

    func test_chatStoreProjectedProviderExposesStatusAlignedWithRecommendationID() {
        let provider = projectedProvider(traceID: "lookup-chat")
        let store = ChatStore(recommendationProvider: provider)
        let object = tryUnwrap(store.recommendedMatches.first)

        let presentation = tryUnwrap(
            store.providerStatusPresentation(for: object.id)
        )

        XCTAssertEqual(presentation.recommendationID, object.id)
        XCTAssertEqual(presentation.id, "provider-status-\(object.id)")
        XCTAssertEqual(presentation.cardHint, .normal)
        XCTAssertEqual(presentation.badges.first?.kind, .localProvider)
    }

    func test_chatStoreExplicitStatusSourceOverridesProjectedProviderForRenderedID() {
        let provider = projectedProvider(traceID: "lookup-explicit-override")
        let object = tryUnwrap(provider.recommendedMatches().first)
        let override = FixedProviderStatusProvider(
            presentationsByRecommendationID: [
                object.id: overridePresentation(for: object.id),
            ]
        )
        let source = ProviderStatusSourceMultiplexer(
            sources: [override, provider]
        )
        let store = ChatStore(
            recommendationProvider: provider,
            providerStatusProvider: source
        )

        let presentation = tryUnwrap(
            store.providerStatusPresentation(for: object.id)
        )

        XCTAssertEqual(presentation.recommendationID, object.id)
        XCTAssertEqual(presentation.cardHint, .warning)
        XCTAssertEqual(presentation.badges.first?.kind, .remoteProvider)
        XCTAssertTrue(presentation.statusLine.contains("Explicit status source"))
        XCTAssertFalse(presentation.statusLine.contains("apple-local"))
    }

    func test_chatStoreExplicitStatusSourceFiltersUnknownRecommendationID() {
        let provider = projectedProvider(traceID: "lookup-explicit-unknown")
        let source = FixedProviderStatusProvider(
            presentationsByRecommendationID: [
                "stale-rec": overridePresentation(for: "stale-rec"),
            ]
        )
        let store = ChatStore(
            recommendationProvider: provider,
            providerStatusProvider: source
        )

        XCTAssertNil(store.providerStatusPresentation(for: "stale-rec"))
    }

    func test_chatStoreExplicitStatusSourceFiltersAcceptedNonRenderedRecommendationID() {
        let provider = projectedProvider(traceID: "lookup-explicit-accepted")
        let object = tryUnwrap(provider.recommendedMatches().first)
        let source = FixedProviderStatusProvider(
            presentationsByRecommendationID: [
                object.id: overridePresentation(for: object.id),
            ]
        )
        let store = ChatStore(
            recommendationProvider: provider,
            providerStatusProvider: source
        )

        XCTAssertNotNil(store.providerStatusPresentation(for: object.id))
        _ = store.prepareRecommendationForAccept(object)

        XCTAssertFalse(store.recommendedMatches.contains(object))
        XCTAssertNil(store.providerStatusPresentation(for: object.id))
    }

    func test_chatStoreExplicitStatusSourceDoesNotChangeRailCapOrMatchingObjectFields() {
        let provider = projectedProvider(traceID: "lookup-explicit-contract")
        let object = tryUnwrap(provider.recommendedMatches().first)
        let objectBeforeLookup = object
        let source = FixedProviderStatusProvider(
            presentationsByRecommendationID: [
                object.id: overridePresentation(for: object.id),
            ]
        )
        let store = ChatStore(
            recommendationProvider: provider,
            providerStatusProvider: source
        )

        _ = store.providerStatusPresentation(for: object.id)

        XCTAssertEqual(store.recommendedMatches.count, 1)
        XCTAssertLessThanOrEqual(store.recommendedMatches.count, RecommendationRail.maxSlateSize)
        XCTAssertEqual(ActionCardTrustPillKind.allCases.count, 7)
        XCTAssertEqual(MatchingObjectKind.allCases.count, 9)
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

    func test_statusLookupDoesNotChangeRailCapOrMatchingObjectVocabulary() {
        let projections = (0..<5).map { index in
            ResultProjector.project(
                providerSelection: ProviderRoutingPolicy.select(
                    for: ProviderRequest(
                        traceID: "lookup-cap-\(index)",
                        capability: .routePlanning,
                        region: .northAmerica,
                        membershipTier: .free
                    )
                ),
                createdAt: now
            )
        }
        let provider = ProjectedRecommendationProvider(projections: projections)
        let store = ChatStore(recommendationProvider: provider)

        XCTAssertEqual(store.recommendedMatches.count, RecommendationRail.maxSlateSize)
        XCTAssertEqual(MatchingObjectKind.allCases.count, 9)
        XCTAssertEqual(ActionCardTrustPillKind.allCases.count, 7)

        for object in store.recommendedMatches {
            XCTAssertNotNil(store.providerStatusPresentation(for: object.id))
        }
    }

    private func projectedProvider(traceID: String) -> ProjectedRecommendationProvider {
        ProjectedRecommendationProvider(
            projections: [
                ResultProjector.project(
                    providerSelection: ProviderRoutingPolicy.select(
                        for: ProviderRequest(
                            traceID: traceID,
                            capability: .routePlanning,
                            region: .northAmerica,
                            membershipTier: .free
                        )
                    ),
                    createdAt: now
                ),
            ]
        )
    }

    private func overridePresentation(for recommendationID: String) -> ProviderStatusPresentation {
        ProviderStatusPresentation(
            recommendationID: recommendationID,
            badges: [
                ProviderStatusBadgeModel(
                    kind: .remoteProvider,
                    label: "Explicit source",
                    systemImage: "network",
                    tone: .neutral
                ),
                ProviderStatusBadgeModel(
                    kind: .meteredPremium,
                    label: "Premium metered",
                    systemImage: "creditcard",
                    tone: .neutral
                ),
            ],
            statusLine: "Explicit status source selected by composition order.",
            cardHint: .warning
        )
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

private struct FixedProviderStatusProvider: ProviderStatusProviding {
    let presentationsByRecommendationID: [String: ProviderStatusPresentation]

    func providerStatusPresentation(
        for recommendationID: String
    ) -> ProviderStatusPresentation? {
        presentationsByRecommendationID[recommendationID]
    }
}
