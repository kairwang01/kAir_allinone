//
//  ServerProviderRuntimeStatusSourceProducerTests.swift
//  kAirTests
//
//  A62 runtime receipt status source producer tests.
//

import XCTest
@testable import kAir

@MainActor
final class ServerProviderRuntimeStatusSourceProducerTests: XCTestCase {

    func test_precomputedReceiptsPackageByExplicitRecommendationIDs() throws {
        let routeID = "a62-route-status"
        let searchID = "a62-search-status"
        let producer = ServerProviderRuntimeStatusSourceProducer()
        let routeReceipt = pipelineReceipt(
            traceID: "a62-route-precomputed",
            providerFamily: .appleLocal,
            capability: .routePlanning,
            costClass: .freeLocal,
            freshness: .cachedOK
        )
        let searchReceipt = pipelineReceipt(
            traceID: "a62-search-precomputed",
            providerFamily: .searchAPI,
            capability: .webSearch,
            costClass: .meteredPremium,
            sourcePolicy: sourcePolicy(host: "precomputed.example.com"),
            entitlements: [.searchAPI]
        )

        let source = producer.statusSource(
            receipts: [
                .init(recommendationID: searchID, receipt: searchReceipt),
                .init(recommendationID: routeID, receipt: routeReceipt),
            ]
        )
        let routeStatus = try XCTUnwrap(source.providerStatusPresentation(for: routeID))
        let searchStatus = try XCTUnwrap(source.providerStatusPresentation(for: searchID))

        XCTAssertEqual(source.recommendationIDs, [routeID, searchID])
        XCTAssertEqual(routeStatus.recommendationID, routeID)
        XCTAssertEqual(routeStatus.cardHint, .normal)
        XCTAssertEqual(badge(.localProvider, in: routeStatus)?.tone, .positive)
        XCTAssertEqual(searchStatus.recommendationID, searchID)
        XCTAssertEqual(searchStatus.cardHint, .warning)
        XCTAssertEqual(badge(.remoteProvider, in: searchStatus)?.tone, .neutral)
        XCTAssertTrue(searchStatus.statusLine.contains("precomputed.example.com"))
        XCTAssertNil(source.providerStatusPresentation(for: "a62-route-precomputed"))
        XCTAssertNil(source.providerStatusPresentation(for: "a62-missing"))
    }

    func test_injectedPipelineInputBuildsStatusStoreAndPreservesInjectedAdapterMetadata() throws {
        let recommendationID = "a62-injected-search-status"
        let producer = ServerProviderRuntimeStatusSourceProducer()
        let adapterSet = ServerProviderRuntimeAdapterSet(
            adapters: [
                SourceMarkingServerProviderRuntimeAdapter(
                    providerFamily: .searchAPI,
                    marker: "a62-injected-source-marker.example.com"
                ),
            ]
        )

        let source = producer.statusSource(
            readinessDecisions: [
                .init(
                    recommendationID: recommendationID,
                    readinessDecision: serverReadyDecision(
                        traceID: "a62-injected-search",
                        providerFamily: .searchAPI,
                        capability: .webSearch,
                        costClass: .meteredPremium,
                        sourcePolicy: sourcePolicy(host: "original.example.com"),
                        entitlements: [.searchAPI]
                    )
                ),
            ],
            adapterSet: adapterSet
        )
        let status = try XCTUnwrap(source.providerStatusPresentation(for: recommendationID))

        XCTAssertEqual(source.recommendationIDs, [recommendationID])
        XCTAssertEqual(status.recommendationID, recommendationID)
        XCTAssertEqual(status.cardHint, .warning)
        XCTAssertEqual(badge(.remoteProvider, in: status)?.tone, .neutral)
        XCTAssertEqual(badge(.meteredPremium, in: status)?.tone, .neutral)
        XCTAssertEqual(badge(.liveFreshness, in: status)?.tone, .positive)
        XCTAssertTrue(status.statusLine.contains("a62-injected-source-marker.example.com"))
        XCTAssertFalse(status.statusLine.contains("original.example.com"))
        XCTAssertNil(source.providerStatusPresentation(for: "a62-injected-search"))
        XCTAssertNil(source.providerStatusPresentation(for: "a62-injected-missing"))
    }

    func test_authorizedInjectedPipelineInputBuildsStatusStoreAndPreservesInjectedAdapterMetadata() throws {
        let recommendationID = "a71-authorized-search-status"
        let producer = ServerProviderRuntimeStatusSourceProducer()
        let adapterSet = ServerProviderRuntimeAdapterSet(
            adapters: [
                SourceMarkingServerProviderRuntimeAdapter(
                    providerFamily: .searchAPI,
                    marker: "a71-authorized-source-marker.example.com"
                ),
            ]
        )

        let source = producer.statusSource(
            readinessDecisions: [
                .init(
                    recommendationID: recommendationID,
                    readinessDecision: serverReadyDecision(
                        traceID: "a71-authorized-search",
                        providerFamily: .searchAPI,
                        capability: .webSearch,
                        costClass: .meteredPremium,
                        sourcePolicy: sourcePolicy(host: "a71-original.example.com"),
                        entitlements: [.searchAPI]
                    )
                ),
            ],
            adapterSet: adapterSet,
            validation: adapterSetValidation(
                state: .accepted,
                registered: [.searchAPI],
                accepted: [.searchAPI]
            )
        )
        let status = try XCTUnwrap(source.providerStatusPresentation(for: recommendationID))

        XCTAssertEqual(source.recommendationIDs, [recommendationID])
        XCTAssertEqual(status.recommendationID, recommendationID)
        XCTAssertEqual(status.cardHint, .warning)
        XCTAssertEqual(badge(.remoteProvider, in: status)?.tone, .neutral)
        XCTAssertEqual(badge(.meteredPremium, in: status)?.tone, .neutral)
        XCTAssertEqual(badge(.liveFreshness, in: status)?.tone, .positive)
        XCTAssertTrue(status.statusLine.contains("a71-authorized-source-marker.example.com"))
        XCTAssertFalse(status.statusLine.contains("a71-original.example.com"))
        XCTAssertNil(source.providerStatusPresentation(for: "a71-authorized-search"))
        XCTAssertNil(source.providerStatusPresentation(for: "a71-authorized-missing"))
    }

    func test_rejectedValidationPackagesNonSuccessStatusWithoutResolvingInjectedAdapter() throws {
        let recommendationID = "a71-rejected-search-status"
        let producer = ServerProviderRuntimeStatusSourceProducer()
        let adapterSet = ServerProviderRuntimeAdapterSet(
            adapters: [
                TrapServerProviderRuntimeAdapter(providerFamily: .searchAPI),
            ]
        )

        let source = producer.statusSource(
            readinessDecisions: [
                .init(
                    recommendationID: recommendationID,
                    readinessDecision: serverReadyDecision(
                        traceID: "a71-rejected-search",
                        providerFamily: .searchAPI,
                        capability: .webSearch,
                        costClass: .meteredPremium,
                        sourcePolicy: sourcePolicy(host: "a71-rejected.example.com"),
                        entitlements: [.searchAPI]
                    )
                ),
            ],
            adapterSet: adapterSet,
            validation: adapterSetValidation(
                state: .rejected,
                registered: [.searchAPI],
                accepted: [.searchAPI],
                rejected: [adapterSetRejection(for: .mcp)]
            )
        )
        let status = try XCTUnwrap(source.providerStatusPresentation(for: recommendationID))

        XCTAssertEqual(source.recommendationIDs, [recommendationID])
        XCTAssertEqual(status.recommendationID, recommendationID)
        XCTAssertEqual(status.cardHint, .disabled)
        XCTAssertEqual(badge(.unavailable, in: status)?.tone, .warning)
        XCTAssertNil(badge(.remoteProvider, in: status))
        XCTAssertTrue(status.statusLine.contains("Runtime receipt is unavailable"))
        XCTAssertTrue(status.statusLine.contains("adapterSetUseNotAuthorized"))
        XCTAssertFalse(status.statusLine.contains("a71-rejected.example.com"))
        XCTAssertNil(source.providerStatusPresentation(for: "a71-rejected-search"))
        XCTAssertNil(source.providerStatusPresentation(for: "a71-rejected-missing"))
    }

    func test_manifestBackedAuthorizedInjectedPipelineInputBuildsStatusStoreAndPreservesInjectedAdapterMetadata() throws {
        let recommendationID = "a78-manifest-authorized-search-status"
        let producer = ServerProviderRuntimeStatusSourceProducer()
        let adapterSet = ServerProviderRuntimeAdapterSet(
            adapters: [
                SourceMarkingServerProviderRuntimeAdapter(
                    providerFamily: .searchAPI,
                    marker: "a78-manifest-authorized-source-marker.example.com"
                ),
            ]
        )

        let source = producer.statusSource(
            manifestBackedReadinessDecisions: [
                .init(
                    recommendationID: recommendationID,
                    readinessDecision: serverReadyDecision(
                        traceID: "a78-manifest-authorized-search",
                        providerFamily: .searchAPI,
                        capability: .webSearch,
                        costClass: .meteredPremium,
                        sourcePolicy: sourcePolicy(host: "a78-manifest-original.example.com"),
                        entitlements: [.searchAPI]
                    ),
                    authorization: manifestSetUseAuthorization(
                        requestedProviderFamily: .searchAPI,
                        registered: [.searchAPI],
                        accepted: [.searchAPI]
                    )
                ),
            ],
            adapterSet: adapterSet
        )
        let status = try XCTUnwrap(source.providerStatusPresentation(for: recommendationID))

        XCTAssertEqual(source.recommendationIDs, [recommendationID])
        XCTAssertEqual(status.recommendationID, recommendationID)
        XCTAssertEqual(status.cardHint, .warning)
        XCTAssertEqual(badge(.remoteProvider, in: status)?.tone, .neutral)
        XCTAssertEqual(badge(.meteredPremium, in: status)?.tone, .neutral)
        XCTAssertEqual(badge(.liveFreshness, in: status)?.tone, .positive)
        XCTAssertTrue(status.statusLine.contains("a78-manifest-authorized-source-marker.example.com"))
        XCTAssertFalse(status.statusLine.contains("a78-manifest-original.example.com"))
        XCTAssertNil(source.providerStatusPresentation(for: "a78-manifest-authorized-search"))
        XCTAssertNil(source.providerStatusPresentation(for: "a78-manifest-authorized-missing"))
    }

    func test_manifestBackedRejectedAuthorizationPackagesNonSuccessStatusWithoutResolvingInjectedAdapter() throws {
        let recommendationID = "a78-manifest-rejected-search-status"
        let producer = ServerProviderRuntimeStatusSourceProducer()
        let adapterSet = ServerProviderRuntimeAdapterSet(
            adapters: [
                TrapServerProviderRuntimeAdapter(providerFamily: .searchAPI),
            ]
        )

        let source = producer.statusSource(
            manifestBackedReadinessDecisions: [
                .init(
                    recommendationID: recommendationID,
                    readinessDecision: serverReadyDecision(
                        traceID: "a78-manifest-rejected-search",
                        providerFamily: .searchAPI,
                        capability: .webSearch,
                        costClass: .meteredPremium,
                        sourcePolicy: sourcePolicy(host: "a78-manifest-rejected.example.com"),
                        entitlements: [.searchAPI]
                    ),
                    authorization: rejectedManifestSetUseAuthorization(
                        requestedProviderFamily: .searchAPI,
                        rejection: .manifestValidationRejected
                    )
                ),
            ],
            adapterSet: adapterSet
        )
        let status = try XCTUnwrap(source.providerStatusPresentation(for: recommendationID))

        XCTAssertEqual(source.recommendationIDs, [recommendationID])
        XCTAssertEqual(status.recommendationID, recommendationID)
        XCTAssertEqual(status.cardHint, .disabled)
        XCTAssertEqual(badge(.unavailable, in: status)?.tone, .warning)
        XCTAssertNil(badge(.remoteProvider, in: status))
        XCTAssertTrue(status.statusLine.contains("Runtime receipt is unavailable"))
        XCTAssertTrue(status.statusLine.contains("adapterSetUseNotAuthorized"))
        XCTAssertFalse(status.statusLine.contains("a78-manifest-rejected.example.com"))
        XCTAssertNil(source.providerStatusPresentation(for: "a78-manifest-rejected-search"))
        XCTAssertNil(source.providerStatusPresentation(for: "a78-manifest-rejected-missing"))
    }

    func test_duplicateIDsKeepFirstReceiptAndMissingIDsReturnNil() throws {
        let recommendationID = "a62-duplicate-status"
        let producer = ServerProviderRuntimeStatusSourceProducer()

        let source = producer.statusSource(
            receipts: [
                .init(
                    recommendationID: recommendationID,
                    receipt: pipelineReceipt(
                        traceID: "a62-duplicate-local",
                        providerFamily: .appleLocal,
                        capability: .routePlanning,
                        costClass: .freeLocal,
                        freshness: .cachedOK
                    )
                ),
                .init(
                    recommendationID: recommendationID,
                    receipt: pipelineReceipt(
                        traceID: "a62-duplicate-search",
                        providerFamily: .searchAPI,
                        capability: .webSearch,
                        costClass: .meteredPremium,
                        sourcePolicy: sourcePolicy(host: "duplicate.example.com"),
                        entitlements: [.searchAPI]
                    )
                ),
            ]
        )
        let status = try XCTUnwrap(source.providerStatusPresentation(for: recommendationID))

        XCTAssertEqual(source.recommendationIDs, [recommendationID])
        XCTAssertEqual(status.cardHint, .normal)
        XCTAssertEqual(badge(.localProvider, in: status)?.tone, .positive)
        XCTAssertNil(badge(.remoteProvider, in: status))
        XCTAssertTrue(status.statusLine.contains("local-only"))
        XCTAssertFalse(status.statusLine.contains("duplicate.example.com"))
        XCTAssertNil(source.providerStatusPresentation(for: "a62-duplicate-missing"))
    }

    func test_authorizedProducerDuplicateIDsKeepFirstReceiptAndMissingIDsReturnNil() throws {
        let recommendationID = "a71-duplicate-authorized-status"
        let producer = ServerProviderRuntimeStatusSourceProducer()
        let adapterSet = ServerProviderRuntimeAdapterSet(
            adapters: [
                SourceMarkingServerProviderRuntimeAdapter(
                    providerFamily: .searchAPI,
                    marker: "a71-duplicate-authorized-marker.example.com"
                ),
            ]
        )

        let source = producer.statusSource(
            readinessDecisions: [
                .init(
                    recommendationID: recommendationID,
                    readinessDecision: serverReadyDecision(
                        traceID: "a71-duplicate-authorized",
                        providerFamily: .searchAPI,
                        capability: .webSearch,
                        costClass: .meteredPremium,
                        sourcePolicy: sourcePolicy(host: "a71-duplicate-authorized-original.example.com"),
                        entitlements: [.searchAPI]
                    )
                ),
                .init(
                    recommendationID: recommendationID,
                    readinessDecision: serverReadyDecision(
                        traceID: "a71-duplicate-unauthorized",
                        providerFamily: .googleMaps,
                        capability: .localServiceSearch,
                        costClass: .meteredPremium,
                        entitlements: [.googleMaps]
                    )
                ),
            ],
            adapterSet: adapterSet,
            validation: adapterSetValidation(
                state: .accepted,
                registered: [.searchAPI],
                accepted: [.searchAPI]
            )
        )
        let status = try XCTUnwrap(source.providerStatusPresentation(for: recommendationID))

        XCTAssertEqual(source.recommendationIDs, [recommendationID])
        XCTAssertEqual(status.cardHint, .warning)
        XCTAssertEqual(badge(.remoteProvider, in: status)?.tone, .neutral)
        XCTAssertTrue(status.statusLine.contains("a71-duplicate-authorized-marker.example.com"))
        XCTAssertFalse(status.statusLine.contains("adapterSetUseNotAuthorized"))
        XCTAssertNil(source.providerStatusPresentation(for: "a71-duplicate-missing"))
    }

    func test_authorizedProducerDuplicateIDsKeepFirstUnauthorizedReceipt() throws {
        let recommendationID = "a71-duplicate-unauthorized-status"
        let producer = ServerProviderRuntimeStatusSourceProducer()
        let adapterSet = ServerProviderRuntimeAdapterSet(
            adapters: [
                SourceMarkingServerProviderRuntimeAdapter(
                    providerFamily: .searchAPI,
                    marker: "a71-duplicate-second-authorized.example.com"
                ),
            ]
        )

        let source = producer.statusSource(
            readinessDecisions: [
                .init(
                    recommendationID: recommendationID,
                    readinessDecision: serverReadyDecision(
                        traceID: "a71-duplicate-first-unauthorized",
                        providerFamily: .googleMaps,
                        capability: .localServiceSearch,
                        costClass: .meteredPremium,
                        entitlements: [.googleMaps]
                    )
                ),
                .init(
                    recommendationID: recommendationID,
                    readinessDecision: serverReadyDecision(
                        traceID: "a71-duplicate-second-authorized",
                        providerFamily: .searchAPI,
                        capability: .webSearch,
                        costClass: .meteredPremium,
                        sourcePolicy: sourcePolicy(host: "a71-duplicate-second-original.example.com"),
                        entitlements: [.searchAPI]
                    )
                ),
            ],
            adapterSet: adapterSet,
            validation: adapterSetValidation(
                state: .accepted,
                registered: [.searchAPI],
                accepted: [.searchAPI]
            )
        )
        let status = try XCTUnwrap(source.providerStatusPresentation(for: recommendationID))

        XCTAssertEqual(source.recommendationIDs, [recommendationID])
        XCTAssertEqual(status.cardHint, .disabled)
        XCTAssertEqual(badge(.unavailable, in: status)?.tone, .warning)
        XCTAssertTrue(status.statusLine.contains("adapterSetUseNotAuthorized"))
        XCTAssertFalse(status.statusLine.contains("a71-duplicate-second-authorized.example.com"))
        XCTAssertNil(source.providerStatusPresentation(for: "a71-duplicate-unauthorized-missing"))
    }

    func test_manifestBackedProducerDuplicateIDsKeepFirstReceiptAndMissingIDsReturnNil() throws {
        let recommendationID = "a78-duplicate-manifest-status"
        let producer = ServerProviderRuntimeStatusSourceProducer()
        let adapterSet = ServerProviderRuntimeAdapterSet(
            adapters: [
                SourceMarkingServerProviderRuntimeAdapter(
                    providerFamily: .searchAPI,
                    marker: "a78-duplicate-manifest-first-marker.example.com"
                ),
            ]
        )

        let source = producer.statusSource(
            manifestBackedReadinessDecisions: [
                .init(
                    recommendationID: recommendationID,
                    readinessDecision: serverReadyDecision(
                        traceID: "a78-duplicate-manifest-first",
                        providerFamily: .searchAPI,
                        capability: .webSearch,
                        costClass: .meteredPremium,
                        sourcePolicy: sourcePolicy(host: "a78-duplicate-manifest-first-original.example.com"),
                        entitlements: [.searchAPI]
                    ),
                    authorization: manifestSetUseAuthorization(
                        requestedProviderFamily: .searchAPI,
                        registered: [.searchAPI],
                        accepted: [.searchAPI]
                    )
                ),
                .init(
                    recommendationID: recommendationID,
                    readinessDecision: serverReadyDecision(
                        traceID: "a78-duplicate-manifest-second",
                        providerFamily: .googleMaps,
                        capability: .localServiceSearch,
                        costClass: .meteredPremium,
                        entitlements: [.googleMaps]
                    ),
                    authorization: rejectedManifestSetUseAuthorization(
                        requestedProviderFamily: .googleMaps,
                        rejection: .manifestValidationRejected
                    )
                ),
            ],
            adapterSet: adapterSet
        )
        let status = try XCTUnwrap(source.providerStatusPresentation(for: recommendationID))

        XCTAssertEqual(source.recommendationIDs, [recommendationID])
        XCTAssertEqual(status.cardHint, .warning)
        XCTAssertEqual(badge(.remoteProvider, in: status)?.tone, .neutral)
        XCTAssertTrue(status.statusLine.contains("a78-duplicate-manifest-first-marker.example.com"))
        XCTAssertFalse(status.statusLine.contains("adapterSetUseNotAuthorized"))
        XCTAssertNil(source.providerStatusPresentation(for: "a78-duplicate-manifest-missing"))
    }

    func test_manifestBackedProducerStatusTextStaysAdvisoryAndDoesNotLeakSensitiveRuntimeFields() throws {
        let producer = ServerProviderRuntimeStatusSourceProducer()
        let adapterSet = ServerProviderRuntimeAdapterSet(
            adapters: [
                SourceMarkingServerProviderRuntimeAdapter(
                    providerFamily: .searchAPI,
                    marker: "a78-copy-manifest-source.example.com"
                ),
            ]
        )
        let source = producer.statusSource(
            manifestBackedReadinessDecisions: [
                .init(
                    recommendationID: "a78-copy-manifest-authorized",
                    readinessDecision: serverReadyDecision(
                        traceID: "a78-copy-manifest-authorized",
                        providerFamily: .searchAPI,
                        capability: .webSearch,
                        costClass: .meteredPremium,
                        sourcePolicy: sourcePolicy(host: "a78-copy-manifest-original.example.com"),
                        entitlements: [.searchAPI]
                    ),
                    authorization: manifestSetUseAuthorization(
                        requestedProviderFamily: .searchAPI,
                        registered: [.searchAPI],
                        accepted: [.searchAPI]
                    )
                ),
                .init(
                    recommendationID: "a78-copy-manifest-rejected",
                    readinessDecision: serverReadyDecision(
                        traceID: "a78-copy-manifest-rejected",
                        providerFamily: .googleMaps,
                        capability: .localServiceSearch,
                        costClass: .meteredPremium,
                        entitlements: [.googleMaps]
                    ),
                    authorization: rejectedManifestSetUseAuthorization(
                        requestedProviderFamily: .googleMaps,
                        rejection: .manifestValidationRejected
                    )
                ),
            ],
            adapterSet: adapterSet
        )
        let presentations = try [
            source.providerStatusPresentation(for: "a78-copy-manifest-authorized"),
            source.providerStatusPresentation(for: "a78-copy-manifest-rejected"),
        ].map { try XCTUnwrap($0) }
        let text = presentations
            .flatMap { [$0.statusLine] + $0.badges.map(\.label) }
            .joined(separator: "\n")
            .lowercased()

        XCTAssertTrue(text.contains("runtime receipt"))
        XCTAssertTrue(text.contains("no provider runtime has run"))
        XCTAssertTrue(text.contains("adaptersetusenotauthorized"))
        for forbidden in [
            "completed",
            "complete",
            "done",
            "called",
            "contacted",
            "fetched",
            "invoked",
            "booked",
            "book" + "ing",
            "ordered",
            "ordering",
            "paid",
            "pay" + "ment",
            "purchased",
            "crawled",
            "crawling",
            "end" + "point",
            "url",
            "api" + "key",
            "api" + "_" + "key",
            "bear" + "er",
            "tok" + "en",
            "creden" + "tial",
            "prompt",
            "raw" + "content",
            "raw" + "source",
            "hea" + "lth",
            "merchant",
            "oauth",
            "secret",
        ] {
            XCTAssertFalse(text.contains(forbidden), "Unexpected wording: \(forbidden)")
        }
    }

    func test_copyStaysAdvisoryOnly() throws {
        let producer = ServerProviderRuntimeStatusSourceProducer()
        let source = producer.statusSource(
            receipts: [
                .init(
                    recommendationID: "a62-copy-search",
                    receipt: pipelineReceipt(
                        traceID: "a62-copy-search",
                        providerFamily: .searchAPI,
                        capability: .webSearch,
                        costClass: .meteredPremium,
                        sourcePolicy: sourcePolicy(host: "copy.example.com"),
                        entitlements: [.searchAPI]
                    )
                ),
                .init(
                    recommendationID: "a62-copy-local",
                    receipt: pipelineReceipt(
                        traceID: "a62-copy-local",
                        providerFamily: .appleLocal,
                        capability: .routePlanning,
                        costClass: .freeLocal,
                        freshness: .cachedOK
                    )
                ),
            ]
        )
        let presentations = try [
            source.providerStatusPresentation(for: "a62-copy-search"),
            source.providerStatusPresentation(for: "a62-copy-local"),
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
            "book" + "ing",
            "ordered",
            "ordering",
            "paid",
            "pay" + "ment",
            "purchased",
            "crawled",
            "crawling",
        ] {
            XCTAssertFalse(text.contains(forbidden), "Unexpected wording: \(forbidden)")
        }
    }

    private func pipelineReceipt(
        traceID: String,
        providerFamily: ProviderFamily,
        capability: ProviderCapability,
        costClass: ProviderCostClass,
        freshness: ProviderFreshness = .livePreferred,
        sourcePolicy: ServerSourcePolicy? = nil,
        entitlements: Set<ProviderFamily> = []
    ) -> ServerProviderRuntimeReceipt {
        ServerProviderRuntimePipeline.run(
            readinessDecision: readyDecision(
                traceID: traceID,
                providerFamily: providerFamily,
                capability: capability,
                costClass: costClass,
                freshness: freshness,
                sourcePolicy: sourcePolicy,
                entitlements: entitlements
            )
        )
    }

    private func serverReadyDecision(
        traceID: String,
        providerFamily: ProviderFamily,
        capability: ProviderCapability,
        costClass: ProviderCostClass,
        sourcePolicy: ServerSourcePolicy? = nil,
        entitlements: Set<ProviderFamily> = []
    ) -> ServerProviderExecutionReadinessDecision {
        let decision = readyDecision(
            traceID: traceID,
            providerFamily: providerFamily,
            capability: capability,
            costClass: costClass,
            sourcePolicy: sourcePolicy,
            entitlements: entitlements
        )
        XCTAssertEqual(decision.state, .serverReady)
        return decision
    }

    private func readyDecision(
        traceID: String,
        providerFamily: ProviderFamily,
        capability: ProviderCapability,
        costClass: ProviderCostClass,
        freshness: ProviderFreshness = .livePreferred,
        sourcePolicy: ServerSourcePolicy? = nil,
        entitlements: Set<ProviderFamily> = []
    ) -> ServerProviderExecutionReadinessDecision {
        let envelope = ServerProviderEnvelope(
            traceID: traceID,
            capability: capability,
            providerFamily: providerFamily,
            privacyClass: .general,
            membershipTier: .pro,
            costClass: costClass,
            freshness: freshness,
            sourcePolicy: sourcePolicy ?? ServerSourcePolicy(sourceState: .notApplicable),
            meteredProviderEntitlements: entitlements
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

    private func sourcePolicy(host: String) -> ServerSourcePolicy {
        ServerSourcePolicy(
            sourceState: .passed,
            robotsState: .notApplicable,
            attributionRequired: true,
            sourceHost: host
        )
    }

    private func adapterSetValidation(
        state: ServerProviderRuntimeAdapterSetReadinessValidationState,
        registered: [ProviderFamily],
        accepted: [ProviderFamily],
        rejected: [ServerProviderRuntimeAdapterSetReadinessRejection] = []
    ) -> ServerProviderRuntimeAdapterSetReadinessValidation {
        ServerProviderRuntimeAdapterSetReadinessValidation(
            id: "a71-adapter-set-readiness-validation-\(state.rawValue)",
            state: state,
            registeredProviderFamilies: registered,
            acceptedProviderFamilies: accepted,
            rejectedProviderFamilies: rejected
        )
    }

    private func adapterSetRejection(
        for providerFamily: ProviderFamily
    ) -> ServerProviderRuntimeAdapterSetReadinessRejection {
        ServerProviderRuntimeAdapterSetReadinessRejection(
            id: "a71-adapter-set-rejection-\(providerFamily.rawValue)",
            providerFamily: providerFamily,
            reason: .missingInstallationDecision,
            decisionID: nil,
            decisionProviderFamily: nil,
            decisionState: nil,
            decisionRejection: nil
        )
    }

    private func manifestSetUseAuthorization(
        requestedProviderFamily: ProviderFamily?,
        registered: [ProviderFamily]? = nil,
        accepted: [ProviderFamily]? = nil
    ) -> ServerProviderRuntimeAdapterManifestSetUseAuthorization {
        let family = requestedProviderFamily ?? .googleMaps
        let registeredFamilies = registered ?? [family]
        let acceptedFamilies = accepted ?? [family]
        return ServerProviderRuntimeAdapterManifestSetUseGate.authorize(
            requestedProviderFamily: requestedProviderFamily,
            validation: manifestSetValidation(
                state: .accepted,
                registered: registeredFamilies,
                accepted: acceptedFamilies,
                readinessValidation: adapterSetValidation(
                    state: .accepted,
                    registered: registeredFamilies,
                    accepted: acceptedFamilies
                )
            )
        )
    }

    private func rejectedManifestSetUseAuthorization(
        requestedProviderFamily: ProviderFamily?,
        rejection: ServerProviderRuntimeAdapterManifestSetUseRejectionReason
    ) -> ServerProviderRuntimeAdapterManifestSetUseAuthorization {
        ServerProviderRuntimeAdapterManifestSetUseAuthorization(
            id: "a78-manifest-set-use-\(requestedProviderFamily?.rawValue ?? "missing")",
            state: .rejected,
            requestedProviderFamily: requestedProviderFamily,
            rejection: rejection,
            manifestValidationID: "a78-manifest-set-validation",
            manifestValidationState: .rejected,
            manifestAcceptedProviderFamilies: requestedProviderFamily.map { [$0] } ?? [],
            readinessValidationID: nil,
            readinessValidationState: nil,
            readinessAuthorization: nil,
            readinessAuthorizationState: nil,
            readinessAuthorizationRejection: nil
        )
    }

    private func manifestSetValidation(
        state: ServerProviderRuntimeAdapterManifestSetValidationState,
        registered: [ProviderFamily],
        accepted: [ProviderFamily],
        readinessValidation: ServerProviderRuntimeAdapterSetReadinessValidation?
    ) -> ServerProviderRuntimeAdapterManifestSetValidation {
        ServerProviderRuntimeAdapterManifestSetValidation(
            id: "a78-manifest-set-validation-\(state.rawValue)",
            state: state,
            registeredProviderFamilies: registered,
            acceptedProviderFamilies: accepted,
            rejectedProviderFamilies: [],
            readinessValidation: readinessValidation
        )
    }

    private func badge(
        _ kind: ProviderStatusBadgeKind,
        in presentation: ProviderStatusPresentation
    ) -> ProviderStatusBadgeModel? {
        presentation.badges.first { $0.kind == kind }
    }
}

private struct TrapServerProviderRuntimeAdapter: ServerProviderRuntimeAdapter {
    let providerFamily: ProviderFamily

    func resolve(
        _ boundary: ServerProviderRuntimeDispatchBoundary
    ) -> ServerProviderRuntimeAdapterResult {
        XCTFail("Authorized status-source producer must not resolve unauthorized injected adapters.")
        return FixtureServerProviderRuntimeAdapter(providerFamily: providerFamily)
            .resolve(boundary)
    }
}

private struct SourceMarkingServerProviderRuntimeAdapter: ServerProviderRuntimeAdapter {
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
