//
//  ServerProviderRuntimeReceiptTests.swift
//  kAirTests
//
//  A22 receipt projection contract: UI/audit-safe metadata only.
//

import XCTest
@testable import kAir

final class ServerProviderRuntimeReceiptTests: XCTestCase {

    func test_receiptProjectsAcceptedGoogleGaodeAndSearchRegistryResults() {
        assertFixtureReceipt(
            result: registryResult(
                traceID: "a22-google",
                providerFamily: .googleMaps,
                capability: .localServiceSearch,
                costClass: .meteredPremium,
                entitlements: [.googleMaps]
            ),
            family: .googleMaps,
            capability: .localServiceSearch
        )

        assertFixtureReceipt(
            result: registryResult(
                traceID: "a22-gaode",
                providerFamily: .gaode,
                capability: .localServiceSearch,
                costClass: .includedQuota,
                entitlements: [.gaode]
            ),
            family: .gaode,
            capability: .localServiceSearch
        )

        assertFixtureReceipt(
            result: registryResult(
                traceID: "a22-search",
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
            family: .searchAPI,
            capability: .webSearch
        )
    }

    func test_receiptProjectsAcceptedCrawlerAndMCPRegistryResults() {
        let crawler = assertFixtureReceipt(
            result: registryResult(
                traceID: "a22-crawler",
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
            ),
            family: .crawler,
            capability: .crawlerFetch
        )
        XCTAssertEqual(crawler.sourcePolicy?.robotsState, .allowed)

        let mcp = assertFixtureReceipt(
            result: registryResult(
                traceID: "a22-mcp",
                providerFamily: .mcp,
                capability: .mcpTool,
                costClass: .includedQuota,
                confirmationState: .confirmed(artifactID: "confirm-a22"),
                entitlements: [.mcp],
                enabledExperimentalProviders: [.mcp]
            ),
            family: .mcp,
            capability: .mcpTool
        )
        XCTAssertEqual(mcp.confirmationState, .confirmed(artifactID: "confirm-a22"))
    }

    func test_receiptProjectsLocalAppleAndCacheAsLocalOnly() {
        for family in [ProviderFamily.appleLocal, .cache] {
            let result = ServerProviderRuntimeAdapterRegistry.resolve(
                boundaryFromReadiness(
                    traceID: "a22-local-\(family.rawValue)",
                    providerFamily: family,
                    capability: .routePlanning,
                    costClass: .freeLocal,
                    freshness: .cachedOK
                )
            )
            let receipt = ServerProviderRuntimeReceiptProjector.project(result)

            XCTAssertEqual(receipt.state, .localOnly)
            XCTAssertFalse(receipt.isFixtureProjected)
            XCTAssertNil(receipt.providerFamily)
            XCTAssertNil(receipt.capability)
            XCTAssertNil(receipt.descriptorID)
            XCTAssertEqual(receipt.audit.adapterResultState, .localOnly)
            XCTAssertEqual(receipt.audit.adapterRejectionReason, .boundaryNotPrepared)
            XCTAssertTrue(receipt.statusLine.contains("local-only"))
        }
    }

    func test_receiptProjectsPrivateRemoteBlockedAsBlocked() throws {
        let result = ServerProviderRuntimeAdapterRegistry.resolve(
            ServerProviderRuntimeDispatcher.prepare(
                ServerProviderRuntimeInvocationPlanner.makePlan(
                    readinessDecision: try privateBlockedDecision()
                )
            )
        )
        let receipt = ServerProviderRuntimeReceiptProjector.project(result)

        XCTAssertEqual(receipt.state, .blocked)
        XCTAssertFalse(receipt.isFixtureProjected)
        XCTAssertNil(receipt.providerFamily)
        XCTAssertNil(receipt.descriptorID)
        XCTAssertEqual(receipt.audit.validatorDenialReason, .privacyBlocked)
        XCTAssertEqual(receipt.audit.adapterRejectionReason, .boundaryNotPrepared)
        XCTAssertTrue(receipt.statusLine.contains("blocked"))
    }

    func test_receiptProjectsConfirmationRequiredAsConfirmationRequired() {
        let result = ServerProviderRuntimeAdapterRegistry.resolve(
            boundaryFromReadiness(
                traceID: "a22-confirmation",
                providerFamily: .mcp,
                capability: .mcpTool,
                costClass: .includedQuota,
                confirmationState: .requiredMissing,
                entitlements: [.mcp],
                enabledExperimentalProviders: [.mcp]
            )
        )
        let receipt = ServerProviderRuntimeReceiptProjector.project(result)

        XCTAssertEqual(receipt.state, .confirmationRequired)
        XCTAssertFalse(receipt.isFixtureProjected)
        XCTAssertNil(receipt.providerFamily)
        XCTAssertNil(receipt.descriptorID)
        XCTAssertEqual(receipt.audit.adapterRejectionReason, .boundaryNotPrepared)
        XCTAssertTrue(receipt.statusLine.contains("confirmation"))
    }

    func test_receiptProjectsDescriptorUnavailableAsDescriptorUnavailable() throws {
        let decision = serverReadyDecision(
            traceID: "a22-mismatch",
            providerFamily: .googleMaps,
            capability: .localServiceSearch,
            costClass: .meteredPremium,
            entitlements: [.googleMaps]
        )
        let searchDescriptor = try XCTUnwrap(
            ServerProviderRuntimeRegistry.descriptors.first { $0.providerFamily == .searchAPI }
        )
        let mismatchLookup = ServerProviderRuntimeLookupResult(
            id: "a22-runtime-mismatch",
            state: .descriptorAvailable,
            descriptor: searchDescriptor,
            readinessDecision: decision,
            statusLine: "Mismatched descriptor fixture."
        )
        let result = ServerProviderRuntimeAdapterRegistry.resolve(
            ServerProviderRuntimeDispatcher.prepare(
                ServerProviderRuntimeInvocationPlanner.makePlan(
                    readinessDecision: decision,
                    runtimeLookup: mismatchLookup
                )
            )
        )
        let receipt = ServerProviderRuntimeReceiptProjector.project(result)

        XCTAssertEqual(receipt.state, .descriptorUnavailable)
        XCTAssertFalse(receipt.isFixtureProjected)
        XCTAssertNil(receipt.providerFamily)
        XCTAssertNil(receipt.descriptorID)
        XCTAssertEqual(receipt.audit.adapterRejectionReason, .boundaryNotPrepared)
        XCTAssertTrue(receipt.statusLine.contains("descriptor metadata is unavailable"))
    }

    func test_receiptProjectsPlanRejectedAsPlanRejected() {
        let goodPlan = ServerProviderRuntimeInvocationPlanner.makePlan(
            readinessDecision: readyDecision(
                traceID: "a22-plan-rejected-base",
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
        let result = ServerProviderRuntimeAdapterRegistry.resolve(
            ServerProviderRuntimeDispatcher.prepare(malformedPlan)
        )
        let receipt = ServerProviderRuntimeReceiptProjector.project(result)

        XCTAssertEqual(receipt.state, .planRejected)
        XCTAssertFalse(receipt.isFixtureProjected)
        XCTAssertNil(receipt.providerFamily)
        XCTAssertNil(receipt.descriptorID)
        XCTAssertEqual(receipt.audit.dispatchRejectionReason, .missingDescriptorID)
        XCTAssertEqual(receipt.audit.adapterRejectionReason, .boundaryNotPrepared)
        XCTAssertTrue(receipt.statusLine.contains("plan metadata was rejected"))
    }

    func test_receiptProjectsMalformedAndUnregisteredAdapterResultsAsNonSuccess() {
        let goodBoundary = prepared(
            traceID: "a22-malformed-base",
            providerFamily: .googleMaps,
            capability: .localServiceSearch,
            costClass: .meteredPremium,
            entitlements: [.googleMaps]
        )
        let malformed = ServerProviderRuntimeAdapterRegistry.resolve(
            malformedBoundary(from: goodBoundary, id: " ")
        )
        let malformedReceipt = ServerProviderRuntimeReceiptProjector.project(malformed)

        XCTAssertEqual(malformedReceipt.state, .notPrepared)
        XCTAssertFalse(malformedReceipt.isFixtureProjected)
        XCTAssertNil(malformedReceipt.providerFamily)
        XCTAssertNil(malformedReceipt.descriptorID)
        XCTAssertEqual(malformedReceipt.audit.adapterRejectionReason, .missingBoundaryID)
        XCTAssertTrue(malformedReceipt.statusLine.contains("not prepared"))

        let unregistered = ServerProviderRuntimeAdapterRegistry.resolve(
            malformedBoundary(from: goodBoundary, providerFamily: .some(.cache))
        )
        let unregisteredReceipt = ServerProviderRuntimeReceiptProjector.project(unregistered)

        XCTAssertEqual(unregisteredReceipt.state, .unavailable)
        XCTAssertFalse(unregisteredReceipt.isFixtureProjected)
        XCTAssertNil(unregisteredReceipt.providerFamily)
        XCTAssertNil(unregisteredReceipt.descriptorID)
        XCTAssertEqual(unregisteredReceipt.audit.adapterRejectionReason, .unregisteredProvider)
        XCTAssertTrue(unregisteredReceipt.statusLine.contains("registered adapter"))
    }

    func test_receiptEncodingDoesNotExposeSensitiveRuntimeFields() throws {
        let receipts = [
            ServerProviderRuntimeReceiptProjector.project(
                registryResult(
                    traceID: "a22-encoding-search",
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
            ServerProviderRuntimeReceiptProjector.project(
                ServerProviderRuntimeAdapterRegistry.resolve(
                    boundaryFromReadiness(
                        traceID: "a22-encoding-confirmation",
                        providerFamily: .mcp,
                        capability: .mcpTool,
                        costClass: .includedQuota,
                        confirmationState: .requiredMissing,
                        entitlements: [.mcp],
                        enabledExperimentalProviders: [.mcp]
                    )
                )
            ),
            ServerProviderRuntimeReceiptProjector.project(
                ServerProviderRuntimeAdapterRegistry.resolve(
                    ServerProviderRuntimeDispatcher.prepare(
                        ServerProviderRuntimeInvocationPlanner.makePlan(
                            readinessDecision: try privateBlockedDecision()
                        )
                    )
                )
            ),
        ]
        let data = try JSONEncoder().encode(receipts)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        let lowercased = json.lowercased()

        let forbiddenFragments = [
            "endpoint",
            "url",
            "api" + "key",
            "api" + "_" + "key",
            "bear" + "er",
            "tok" + "en",
            "creden" + "tial",
            "prompt",
            "rawcontent",
            "rawsource",
            "health",
            "booking",
            "order",
            "payment",
            "merchant",
            "transport",
        ]

        for fragment in forbiddenFragments {
            XCTAssertFalse(lowercased.contains(fragment), "Unexpected receipt field: \(fragment)")
        }
    }

    func test_receiptStatusDoesNotUseCompletedOrActionDoneWordingOrImplyProviderContact() throws {
        let receipts = [
            ServerProviderRuntimeReceiptProjector.project(
                registryResult(
                    traceID: "a22-copy-accepted",
                    providerFamily: .googleMaps,
                    capability: .localServiceSearch,
                    costClass: .meteredPremium,
                    entitlements: [.googleMaps]
                )
            ),
            ServerProviderRuntimeReceiptProjector.project(
                ServerProviderRuntimeAdapterRegistry.resolve(
                    boundaryFromReadiness(
                        traceID: "a22-copy-local",
                        providerFamily: .appleLocal,
                        capability: .routePlanning,
                        costClass: .freeLocal,
                        freshness: .cachedOK
                    )
                )
            ),
            ServerProviderRuntimeReceiptProjector.project(
                ServerProviderRuntimeAdapterRegistry.resolve(
                    boundaryFromReadiness(
                        traceID: "a22-copy-confirmation",
                        providerFamily: .mcp,
                        capability: .mcpTool,
                        costClass: .includedQuota,
                        confirmationState: .requiredMissing,
                        entitlements: [.mcp],
                        enabledExperimentalProviders: [.mcp]
                    )
                )
            ),
            ServerProviderRuntimeReceiptProjector.project(
                ServerProviderRuntimeAdapterRegistry.resolve(
                    ServerProviderRuntimeDispatcher.prepare(
                        ServerProviderRuntimeInvocationPlanner.makePlan(
                            readinessDecision: try privateBlockedDecision()
                        )
                    )
                )
            ),
        ]
        let text = receipts
            .map(\.statusLine)
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

    @discardableResult
    private func assertFixtureReceipt(
        result: ServerProviderRuntimeAdapterResult,
        family: ProviderFamily,
        capability: ProviderCapability,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> ServerProviderRuntimeReceipt {
        let receipt = ServerProviderRuntimeReceiptProjector.project(result)

        XCTAssertEqual(result.state, .acceptedFixture, file: file, line: line)
        XCTAssertEqual(receipt.state, .fixtureProjected, file: file, line: line)
        XCTAssertTrue(receipt.isFixtureProjected, file: file, line: line)
        XCTAssertEqual(receipt.adapterResultID, result.id, file: file, line: line)
        XCTAssertEqual(receipt.boundaryID, result.boundaryID, file: file, line: line)
        XCTAssertEqual(receipt.planID, result.planID, file: file, line: line)
        XCTAssertEqual(receipt.traceID, result.traceID, file: file, line: line)
        XCTAssertEqual(receipt.providerFamily, family, file: file, line: line)
        XCTAssertEqual(receipt.capability, capability, file: file, line: line)
        XCTAssertEqual(receipt.descriptorID, result.descriptorID, file: file, line: line)
        XCTAssertEqual(receipt.costClass, result.costClass, file: file, line: line)
        XCTAssertEqual(receipt.freshness, result.freshness, file: file, line: line)
        XCTAssertEqual(receipt.confirmationState, result.confirmationState, file: file, line: line)
        XCTAssertEqual(receipt.audit.adapterResultState, .acceptedFixture, file: file, line: line)
        XCTAssertNil(receipt.audit.adapterRejectionReason, file: file, line: line)
        XCTAssertTrue(receipt.statusLine.contains("metadata only"), file: file, line: line)
        return receipt
    }

    private func registryResult(
        traceID: String,
        providerFamily: ProviderFamily,
        capability: ProviderCapability,
        costClass: ProviderCostClass,
        sourcePolicy: ServerSourcePolicy? = nil,
        confirmationState: ServerConfirmationState = .notRequired,
        entitlements: Set<ProviderFamily> = [],
        enabledExperimentalProviders: Set<ProviderFamily> = []
    ) -> ServerProviderRuntimeAdapterResult {
        ServerProviderRuntimeAdapterRegistry.resolve(
            prepared(
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
    }

    private func malformedBoundary(
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

    private func prepared(
        traceID: String,
        providerFamily: ProviderFamily,
        capability: ProviderCapability,
        costClass: ProviderCostClass,
        sourcePolicy: ServerSourcePolicy? = nil,
        confirmationState: ServerConfirmationState = .notRequired,
        entitlements: Set<ProviderFamily> = [],
        enabledExperimentalProviders: Set<ProviderFamily> = []
    ) -> ServerProviderRuntimeDispatchBoundary {
        let boundary = boundaryFromReadiness(
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

    private func boundaryFromReadiness(
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
                readinessDecision: readyDecision(
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

    private func serverReadyDecision(
        traceID: String,
        providerFamily: ProviderFamily,
        capability: ProviderCapability,
        costClass: ProviderCostClass,
        sourcePolicy: ServerSourcePolicy? = nil,
        confirmationState: ServerConfirmationState = .notRequired,
        entitlements: Set<ProviderFamily> = [],
        enabledExperimentalProviders: Set<ProviderFamily> = []
    ) -> ServerProviderExecutionReadinessDecision {
        let decision = readyDecision(
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

    private func readyDecision(
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
            sourcePolicy: sourcePolicy ?? ServerSourcePolicy(sourceState: .notApplicable),
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

    private func privateBlockedDecision() throws -> ServerProviderExecutionReadinessDecision {
        let envelope = ServerProviderEnvelope(
            traceID: "a22-private-block",
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
}
