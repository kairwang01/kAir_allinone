//
//  ServerProviderRuntimeAdapterTests.swift
//  kAirTests
//
//  A20 adapter protocol/result contract: fixture-only result, no provider runtime.
//

import XCTest
@testable import kAir

final class ServerProviderRuntimeAdapterTests: XCTestCase {

    func test_fixtureAcceptsGoogleGaodeAndSearchOnlyFromPreparedBoundaries() {
        assertAcceptedFixture(
            boundary: prepared(
                traceID: "a20-google",
                providerFamily: .googleMaps,
                capability: .localServiceSearch,
                costClass: .meteredPremium,
                entitlements: [.googleMaps]
            ),
            adapterFamily: .googleMaps,
            capability: .localServiceSearch
        )

        assertAcceptedFixture(
            boundary: prepared(
                traceID: "a20-gaode",
                providerFamily: .gaode,
                capability: .localServiceSearch,
                costClass: .includedQuota,
                entitlements: [.gaode]
            ),
            adapterFamily: .gaode,
            capability: .localServiceSearch
        )

        assertAcceptedFixture(
            boundary: prepared(
                traceID: "a20-search",
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
            adapterFamily: .searchAPI,
            capability: .webSearch
        )
    }

    func test_fixtureAcceptsCrawlerAndMCPOnlyFromPreparedBoundaries() {
        let crawler = assertAcceptedFixture(
            boundary: prepared(
                traceID: "a20-crawler",
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
            adapterFamily: .crawler,
            capability: .crawlerFetch
        )
        XCTAssertEqual(crawler.sourcePolicy?.robotsState, .allowed)

        let mcp = assertAcceptedFixture(
            boundary: prepared(
                traceID: "a20-mcp",
                providerFamily: .mcp,
                capability: .mcpTool,
                costClass: .includedQuota,
                confirmationState: .confirmed(artifactID: "confirm-a20"),
                entitlements: [.mcp],
                enabledExperimentalProviders: [.mcp]
            ),
            adapterFamily: .mcp,
            capability: .mcpTool
        )
        XCTAssertEqual(mcp.confirmationState, .confirmed(artifactID: "confirm-a20"))
    }

    func test_localAppleAndCacheBoundariesDoNotReachFixtureAcceptance() {
        for family in [ProviderFamily.appleLocal, .cache] {
            let boundary = boundaryFromReadiness(
                traceID: "a20-local-\(family.rawValue)",
                providerFamily: family,
                capability: .routePlanning,
                costClass: .freeLocal,
                freshness: .cachedOK
            )
            let result = FixtureServerProviderRuntimeAdapter(providerFamily: .googleMaps)
                .resolve(boundary)

            XCTAssertEqual(result.state, .localOnly)
            XCTAssertFalse(result.isAcceptedFixture)
            XCTAssertNil(result.descriptorID)
            XCTAssertNil(result.providerFamily)
            XCTAssertEqual(result.audit.adapterRejectionReason, .boundaryNotPrepared)
            XCTAssertEqual(result.audit.boundaryState, .localOnly)
            XCTAssertTrue(result.statusLine.contains("Local-only"))
        }
    }

    func test_privateRemoteBlockedBoundaryDoesNotReachFixtureAcceptance() throws {
        let boundary = ServerProviderRuntimeDispatcher.prepare(
            ServerProviderRuntimeInvocationPlanner.makePlan(
                readinessDecision: try privateBlockedDecision()
            )
        )
        let result = FixtureServerProviderRuntimeAdapter(providerFamily: .googleMaps)
            .resolve(boundary)

        XCTAssertEqual(result.state, .blocked)
        XCTAssertFalse(result.isAcceptedFixture)
        XCTAssertNil(result.descriptorID)
        XCTAssertNil(result.providerFamily)
        XCTAssertEqual(result.audit.validatorDenialReason, .privacyBlocked)
        XCTAssertEqual(result.audit.adapterRejectionReason, .boundaryNotPrepared)
        XCTAssertTrue(result.statusLine.contains("boundary is blocked"))
        XCTAssertTrue(result.statusLine.contains("privacy policy blocks remote routing"))
    }

    func test_confirmationRequiredBoundaryDoesNotReachFixtureAcceptance() {
        let boundary = boundaryFromReadiness(
            traceID: "a20-confirmation",
            providerFamily: .mcp,
            capability: .mcpTool,
            costClass: .includedQuota,
            confirmationState: .requiredMissing,
            entitlements: [.mcp],
            enabledExperimentalProviders: [.mcp]
        )
        let result = FixtureServerProviderRuntimeAdapter(providerFamily: .mcp)
            .resolve(boundary)

        XCTAssertEqual(result.state, .confirmationRequired)
        XCTAssertFalse(result.isAcceptedFixture)
        XCTAssertNil(result.descriptorID)
        XCTAssertNil(result.providerFamily)
        XCTAssertEqual(result.audit.adapterRejectionReason, .boundaryNotPrepared)
        XCTAssertTrue(result.statusLine.contains("withheld until confirmation"))
    }

    func test_descriptorUnavailableBoundaryDoesNotReachFixtureAcceptance() throws {
        let decision = serverReadyDecision(
            traceID: "a20-mismatch",
            providerFamily: .googleMaps,
            capability: .localServiceSearch,
            costClass: .meteredPremium,
            entitlements: [.googleMaps]
        )
        let searchDescriptor = try XCTUnwrap(
            ServerProviderRuntimeRegistry.descriptors.first { $0.providerFamily == .searchAPI }
        )
        let mismatchLookup = ServerProviderRuntimeLookupResult(
            id: "a20-runtime-mismatch",
            state: .descriptorAvailable,
            descriptor: searchDescriptor,
            readinessDecision: decision,
            statusLine: "Mismatched descriptor fixture."
        )
        let boundary = ServerProviderRuntimeDispatcher.prepare(
            ServerProviderRuntimeInvocationPlanner.makePlan(
                readinessDecision: decision,
                runtimeLookup: mismatchLookup
            )
        )

        let result = FixtureServerProviderRuntimeAdapter(providerFamily: .googleMaps)
            .resolve(boundary)

        XCTAssertEqual(result.state, .descriptorUnavailable)
        XCTAssertFalse(result.isAcceptedFixture)
        XCTAssertNil(result.descriptorID)
        XCTAssertNil(result.providerFamily)
        XCTAssertEqual(result.audit.adapterRejectionReason, .boundaryNotPrepared)
        XCTAssertTrue(result.statusLine.contains("descriptor metadata is unavailable"))
    }

    func test_planRejectedBoundaryDoesNotReachFixtureAcceptance() {
        let goodPlan = ServerProviderRuntimeInvocationPlanner.makePlan(
            readinessDecision: readyDecision(
                traceID: "a20-plan-rejected-base",
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
            providerFamily: .googleMaps,
            capability: .localServiceSearch,
            costClass: goodPlan.costClass,
            freshness: goodPlan.freshness,
            sourcePolicy: goodPlan.sourcePolicy,
            confirmationState: goodPlan.confirmationState,
            descriptorID: nil,
            audit: goodPlan.audit
        )
        let rejected = ServerProviderRuntimeDispatcher.prepare(malformedPlan)

        let result = FixtureServerProviderRuntimeAdapter(providerFamily: .googleMaps)
            .resolve(rejected)

        XCTAssertEqual(rejected.state, .planRejected)
        XCTAssertEqual(result.state, .planRejected)
        XCTAssertFalse(result.isAcceptedFixture)
        XCTAssertNil(result.descriptorID)
        XCTAssertEqual(result.audit.dispatchRejectionReason, .missingDescriptorID)
        XCTAssertEqual(result.audit.adapterRejectionReason, .boundaryNotPrepared)
        XCTAssertTrue(result.statusLine.contains("plan metadata was rejected"))
    }

    func test_malformedPreparedBoundaryMetadataIsRejected() {
        let goodBoundary = prepared(
            traceID: "a20-malformed-base",
            providerFamily: .googleMaps,
            capability: .localServiceSearch,
            costClass: .meteredPremium,
            entitlements: [.googleMaps]
        )

        let cases: [(ServerProviderRuntimeDispatchBoundary, ServerProviderRuntimeAdapterRejectionReason)] = [
            (malformedBoundary(from: goodBoundary, id: " "), .missingBoundaryID),
            (malformedBoundary(from: goodBoundary, planID: " "), .missingPlanID),
            (malformedBoundary(from: goodBoundary, traceID: .some(nil)), .missingTraceID),
            (malformedBoundary(from: goodBoundary, providerFamily: .some(nil)), .missingProviderFamily),
            (malformedBoundary(from: goodBoundary, capability: .some(nil)), .missingCapability),
            (malformedBoundary(from: goodBoundary, descriptorID: .some(nil)), .missingDescriptorID),
        ]

        for (boundary, rejection) in cases {
            let result = FixtureServerProviderRuntimeAdapter(providerFamily: .googleMaps)
                .resolve(boundary)

            XCTAssertEqual(result.state, .notPrepared)
            XCTAssertFalse(result.isAcceptedFixture)
            XCTAssertEqual(result.audit.adapterRejectionReason, rejection)
            XCTAssertTrue(result.statusLine.contains("dispatch metadata is invalid"))
        }
    }

    func test_providerMismatchBoundaryDoesNotReachFixtureAcceptance() {
        let boundary = prepared(
            traceID: "a20-provider-mismatch",
            providerFamily: .googleMaps,
            capability: .localServiceSearch,
            costClass: .meteredPremium,
            entitlements: [.googleMaps]
        )

        let result = FixtureServerProviderRuntimeAdapter(providerFamily: .gaode)
            .resolve(boundary)

        XCTAssertEqual(result.state, .notPrepared)
        XCTAssertFalse(result.isAcceptedFixture)
        XCTAssertNil(result.providerFamily)
        XCTAssertEqual(result.audit.adapterRejectionReason, .providerMismatch)
        XCTAssertTrue(result.statusLine.contains("provider family does not match adapter"))
    }

    func test_adapterResultEncodingDoesNotExposeSensitiveRuntimeFields() throws {
        let results = [
            FixtureServerProviderRuntimeAdapter(providerFamily: .searchAPI).resolve(
                prepared(
                    traceID: "a20-encoding-search",
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
            FixtureServerProviderRuntimeAdapter(providerFamily: .mcp).resolve(
                boundaryFromReadiness(
                    traceID: "a20-encoding-confirmation",
                    providerFamily: .mcp,
                    capability: .mcpTool,
                    costClass: .includedQuota,
                    confirmationState: .requiredMissing,
                    entitlements: [.mcp],
                    enabledExperimentalProviders: [.mcp]
                )
            ),
            FixtureServerProviderRuntimeAdapter(providerFamily: .googleMaps).resolve(
                ServerProviderRuntimeDispatcher.prepare(
                    ServerProviderRuntimeInvocationPlanner.makePlan(
                        readinessDecision: try privateBlockedDecision()
                    )
                )
            ),
        ]
        let data = try JSONEncoder().encode(results)
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
        ]

        for fragment in forbiddenFragments {
            XCTAssertFalse(lowercased.contains(fragment), "Unexpected adapter result field: \(fragment)")
        }
    }

    func test_adapterResultStatusDoesNotUseCompletedOrActionDoneWordingOrImplyProviderContact() throws {
        let results = [
            FixtureServerProviderRuntimeAdapter(providerFamily: .googleMaps).resolve(
                prepared(
                    traceID: "a20-copy-accepted",
                    providerFamily: .googleMaps,
                    capability: .localServiceSearch,
                    costClass: .meteredPremium,
                    entitlements: [.googleMaps]
                )
            ),
            FixtureServerProviderRuntimeAdapter(providerFamily: .googleMaps).resolve(
                boundaryFromReadiness(
                    traceID: "a20-copy-local",
                    providerFamily: .appleLocal,
                    capability: .routePlanning,
                    costClass: .freeLocal,
                    freshness: .cachedOK
                )
            ),
            FixtureServerProviderRuntimeAdapter(providerFamily: .mcp).resolve(
                boundaryFromReadiness(
                    traceID: "a20-copy-confirmation",
                    providerFamily: .mcp,
                    capability: .mcpTool,
                    costClass: .includedQuota,
                    confirmationState: .requiredMissing,
                    entitlements: [.mcp],
                    enabledExperimentalProviders: [.mcp]
                )
            ),
            FixtureServerProviderRuntimeAdapter(providerFamily: .googleMaps).resolve(
                ServerProviderRuntimeDispatcher.prepare(
                    ServerProviderRuntimeInvocationPlanner.makePlan(
                        readinessDecision: try privateBlockedDecision()
                    )
                )
            ),
        ]
        let text = results
            .map(\.statusLine)
            .joined(separator: "\n")
            .lowercased()

        for forbidden in [
            "completed",
            "complete",
            "done",
            "called",
            "contacted",
            "booked",
            "ordered",
            "paid",
            "purchased",
        ] {
            XCTAssertFalse(text.contains(forbidden), "Unexpected wording: \(forbidden)")
        }
    }

    @discardableResult
    private func assertAcceptedFixture(
        boundary: ServerProviderRuntimeDispatchBoundary,
        adapterFamily: ProviderFamily,
        capability: ProviderCapability,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> ServerProviderRuntimeAdapterResult {
        let result = FixtureServerProviderRuntimeAdapter(providerFamily: adapterFamily)
            .resolve(boundary)

        XCTAssertEqual(result.state, .acceptedFixture, file: file, line: line)
        XCTAssertTrue(result.isAcceptedFixture, file: file, line: line)
        XCTAssertEqual(result.boundaryID, boundary.id, file: file, line: line)
        XCTAssertEqual(result.planID, boundary.planID, file: file, line: line)
        XCTAssertEqual(result.traceID, boundary.traceID, file: file, line: line)
        XCTAssertEqual(result.providerFamily, adapterFamily, file: file, line: line)
        XCTAssertEqual(result.capability, capability, file: file, line: line)
        XCTAssertEqual(result.descriptorID, boundary.descriptorID, file: file, line: line)
        XCTAssertEqual(result.audit.boundaryState, .prepared, file: file, line: line)
        XCTAssertNil(result.audit.adapterRejectionReason, file: file, line: line)
        XCTAssertTrue(result.statusLine.contains("metadata only"), file: file, line: line)
        return result
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
            traceID: "a20-private-block",
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
