//
//  ServerProviderRenderedRuntimeStatusSourceTests.swift
//  kAirTests
//
//  A64 rendered runtime status source guard tests.
//

import XCTest
@testable import kAir

@MainActor
final class ServerProviderRenderedRuntimeStatusSourceTests: XCTestCase {

    func test_renderedIDsReturnWrappedProducerBuiltRuntimeStatus() throws {
        let renderedID = "a64-rendered-runtime"
        let secondaryID = "a64-rendered-runtime-secondary"
        let guardedSource = renderedSource(
            renderedIDs: [secondaryID, renderedID],
            renderedID: renderedID,
            secondaryID: secondaryID
        )

        let rendered = try XCTUnwrap(
            guardedSource.providerStatusPresentation(for: renderedID)
        )
        let secondary = try XCTUnwrap(
            guardedSource.providerStatusPresentation(for: secondaryID)
        )

        XCTAssertEqual(guardedSource.renderedRecommendationIDs, [renderedID, secondaryID])
        XCTAssertEqual(rendered.recommendationID, renderedID)
        XCTAssertEqual(rendered.cardHint, .warning)
        XCTAssertEqual(badge(.remoteProvider, in: rendered)?.tone, .neutral)
        XCTAssertEqual(badge(.meteredPremium, in: rendered)?.tone, .neutral)
        XCTAssertEqual(badge(.liveFreshness, in: rendered)?.tone, .positive)
        XCTAssertTrue(rendered.statusLine.contains("a64-runtime-injected.example.com"))
        XCTAssertEqual(secondary.recommendationID, secondaryID)
        XCTAssertEqual(secondary.cardHint, .normal)
        XCTAssertEqual(badge(.localProvider, in: secondary)?.tone, .positive)
        XCTAssertTrue(secondary.statusLine.contains("local-only"))
    }

    func test_hiddenWrappedStoreIDReturnsNilWhenNotRendered() {
        let renderedID = "a64-rendered-runtime"
        let secondaryID = "a64-rendered-runtime-secondary"
        let hiddenID = "a64-hidden-runtime"
        let guardedSource = renderedSource(
            renderedIDs: [renderedID],
            renderedID: renderedID,
            secondaryID: secondaryID,
            hiddenID: hiddenID
        )

        XCTAssertNotNil(guardedSource.providerStatusPresentation(for: renderedID))
        XCTAssertNil(guardedSource.providerStatusPresentation(for: secondaryID))
        XCTAssertNil(guardedSource.providerStatusPresentation(for: hiddenID))
        XCTAssertNil(guardedSource.providerStatusPresentation(for: "a64-missing-runtime"))
    }

    func test_duplicateRenderedIDsAreDeterministic() {
        let renderedID = "a64-rendered-runtime"
        let secondaryID = "a64-rendered-runtime-secondary"
        let guardedSource = renderedSource(
            renderedIDs: [secondaryID, renderedID, renderedID, secondaryID],
            renderedID: renderedID,
            secondaryID: secondaryID
        )

        XCTAssertEqual(guardedSource.renderedRecommendationIDs, [renderedID, secondaryID])
        XCTAssertNotNil(guardedSource.providerStatusPresentation(for: renderedID))
        XCTAssertNotNil(guardedSource.providerStatusPresentation(for: secondaryID))
    }

    func test_wrapperDoesNotMutateMatchingObjectOrInferFixtureID() {
        let renderedID = "a64-caller-rendered"
        let hiddenID = "a64-hidden-runtime"
        let fixtureBefore = RecommendationFixtures.placeRoute
        let guardedSource = renderedSource(
            renderedIDs: [renderedID],
            renderedID: renderedID,
            secondaryID: "a64-secondary-runtime",
            hiddenID: hiddenID
        )

        XCTAssertEqual(RecommendationFixtures.placeRoute, fixtureBefore)
        XCTAssertNotNil(guardedSource.providerStatusPresentation(for: renderedID))
        XCTAssertNil(guardedSource.providerStatusPresentation(for: RecommendationFixtures.placeRoute.id))
        XCTAssertNil(guardedSource.providerStatusPresentation(for: "a64-rendered-search-query"))
        XCTAssertNil(guardedSource.providerStatusPresentation(for: hiddenID))
    }

    func test_copyStaysAdvisoryOnly() throws {
        let renderedID = "a64-rendered-copy"
        let secondaryID = "a64-rendered-copy-secondary"
        let guardedSource = renderedSource(
            renderedIDs: [renderedID, secondaryID],
            renderedID: renderedID,
            secondaryID: secondaryID
        )
        let presentations = try [
            guardedSource.providerStatusPresentation(for: renderedID),
            guardedSource.providerStatusPresentation(for: secondaryID),
        ].map { try XCTUnwrap($0) }
        let text = presentations
            .flatMap { [$0.statusLine] + $0.badges.map(\.label) }
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

    private func renderedSource(
        renderedIDs: [String],
        renderedID: String,
        secondaryID: String,
        hiddenID: String? = nil
    ) -> ServerProviderRenderedRuntimeStatusSource {
        let producer = ServerProviderRuntimeStatusSourceProducer()
        var inputs: [ServerProviderRuntimeStatusSourceProducer.PipelineInput] = [
            .init(
                recommendationID: renderedID,
                readinessDecision: searchReadinessDecision(
                    traceID: "a64-rendered-runtime",
                    sourceHost: "a64-original.example.com"
                )
            ),
        ]
        if let hiddenID {
            inputs.append(
                .init(
                    recommendationID: hiddenID,
                    readinessDecision: searchReadinessDecision(
                        traceID: "a64-hidden-runtime",
                        sourceHost: "a64-hidden.example.com"
                    )
                )
            )
        }
        let source = producer.statusSource(
            readinessDecisions: inputs,
            adapterSet: ServerProviderRuntimeAdapterSet(
                adapters: [
                    SourceMarkingServerProviderRuntimeAdapterForRenderedStatus(
                        providerFamily: .searchAPI,
                        marker: "a64-runtime-injected.example.com"
                    ),
                ]
            )
        )
        let combinedSource = RuntimeReceiptProviderStatusStore(
            receipts: [
                (
                    recommendationID: secondaryID,
                    receipt: localReceipt(traceID: "a64-rendered-runtime-secondary")
                ),
            ]
        )
        let multiplexer = ProviderStatusSourceMultiplexer(
            sources: [source, combinedSource]
        )
        return ServerProviderRenderedRuntimeStatusSource(
            source: multiplexer,
            renderedRecommendationIDs: renderedIDs
        )
    }

    private func searchReadinessDecision(
        traceID: String,
        sourceHost: String
    ) -> ServerProviderExecutionReadinessDecision {
        let envelope = ServerProviderEnvelope(
            traceID: traceID,
            capability: .webSearch,
            providerFamily: .searchAPI,
            privacyClass: .general,
            membershipTier: .pro,
            costClass: .meteredPremium,
            freshness: .livePreferred,
            sourcePolicy: ServerSourcePolicy(
                sourceState: .passed,
                robotsState: .notApplicable,
                attributionRequired: true,
                sourceHost: sourceHost
            ),
            meteredProviderEntitlements: [.searchAPI]
        )
        let validation = ServerProviderEnvelopeValidator.validate(envelope)
        XCTAssertTrue(validation.isAllowed)
        return ServerProviderExecutionGate.evaluate(
            .executable(envelope: envelope, validation: validation)
        )
    }

    private func localReceipt(traceID: String) -> ServerProviderRuntimeReceipt {
        let envelope = ServerProviderEnvelope(
            traceID: traceID,
            capability: .routePlanning,
            providerFamily: .appleLocal,
            privacyClass: .general,
            membershipTier: .free,
            costClass: .freeLocal,
            freshness: .cachedOK
        )
        let validation = ServerProviderEnvelopeValidator.validate(envelope)
        XCTAssertTrue(validation.isAllowed)
        return ServerProviderRuntimePipeline.run(
            readinessDecision: ServerProviderExecutionGate.evaluate(
                .executable(envelope: envelope, validation: validation)
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

private struct SourceMarkingServerProviderRuntimeAdapterForRenderedStatus:
    ServerProviderRuntimeAdapter
{
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
            sourcePolicy: markedSourcePolicy(result.sourcePolicy),
            confirmationState: result.confirmationState,
            audit: result.audit
        )
    }

    private func markedSourcePolicy(
        _ policy: ServerSourcePolicy?
    ) -> ServerSourcePolicy? {
        guard let policy else {
            return nil
        }
        return ServerSourcePolicy(
            sourceState: policy.sourceState,
            robotsState: policy.robotsState,
            attributionRequired: policy.attributionRequired,
            sourceHost: marker
        )
    }
}
