//
//  ServerProviderRuntimeDispatchTests.swift
//  kAirTests
//
//  A19 dispatch-boundary contract: value-only preparation, no provider runtime.
//

import XCTest
@testable import kAir

final class ServerProviderRuntimeDispatchTests: XCTestCase {

    func test_googleGaodeAndSearchPreparedOnlyFromPlannedState() {
        assertPrepared(
            plan: planned(
                traceID: "a19-google",
                providerFamily: .googleMaps,
                capability: .localServiceSearch,
                costClass: .meteredPremium,
                entitlements: [.googleMaps]
            ),
            family: .googleMaps,
            capability: .localServiceSearch
        )

        assertPrepared(
            plan: planned(
                traceID: "a19-gaode",
                providerFamily: .gaode,
                capability: .localServiceSearch,
                costClass: .includedQuota,
                entitlements: [.gaode]
            ),
            family: .gaode,
            capability: .localServiceSearch
        )

        assertPrepared(
            plan: planned(
                traceID: "a19-search",
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

    func test_crawlerAndMCPPreparedOnlyAfterPlannedState() {
        let crawler = assertPrepared(
            plan: planned(
                traceID: "a19-crawler",
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

        let mcp = assertPrepared(
            plan: planned(
                traceID: "a19-mcp",
                providerFamily: .mcp,
                capability: .mcpTool,
                costClass: .includedQuota,
                confirmationState: .confirmed(artifactID: "confirm-a19"),
                entitlements: [.mcp],
                enabledExperimentalProviders: [.mcp]
            ),
            family: .mcp,
            capability: .mcpTool
        )
        XCTAssertEqual(mcp.confirmationState, .confirmed(artifactID: "confirm-a19"))
    }

    func test_localAppleAndCachePlansAreNotPrepared() {
        for family in [ProviderFamily.appleLocal, .cache] {
            let plan = planFromReadiness(
                traceID: "a19-local-\(family.rawValue)",
                providerFamily: family,
                capability: .routePlanning,
                costClass: .freeLocal,
                freshness: .cachedOK
            )
            let boundary = ServerProviderRuntimeDispatcher.prepare(plan)

            XCTAssertEqual(boundary.state, .localOnly)
            XCTAssertFalse(boundary.isPrepared)
            XCTAssertNil(boundary.descriptorID)
            XCTAssertNil(boundary.providerFamily)
            XCTAssertEqual(boundary.audit.planState, .localOnly)
            XCTAssertEqual(boundary.audit.rejectionReason, .planNotPlanned)
            XCTAssertTrue(boundary.statusLine.contains("Local-only"))
        }
    }

    func test_privateRemoteBlockedPlanIsNotPrepared() throws {
        let plan = ServerProviderRuntimeInvocationPlanner.makePlan(
            readinessDecision: try privateBlockedDecision()
        )
        let boundary = ServerProviderRuntimeDispatcher.prepare(plan)

        XCTAssertEqual(boundary.state, .blocked)
        XCTAssertFalse(boundary.isPrepared)
        XCTAssertNil(boundary.descriptorID)
        XCTAssertNil(boundary.providerFamily)
        XCTAssertEqual(boundary.audit.validatorDenialReason, .privacyBlocked)
        XCTAssertEqual(boundary.audit.rejectionReason, .planNotPlanned)
        XCTAssertTrue(boundary.statusLine.contains("plan is blocked"))
        XCTAssertTrue(boundary.statusLine.contains("privacy policy blocks remote routing"))
    }

    func test_confirmationRequiredPlanIsNotPrepared() {
        let plan = planFromReadiness(
            traceID: "a19-confirmation",
            providerFamily: .mcp,
            capability: .mcpTool,
            costClass: .includedQuota,
            confirmationState: .requiredMissing,
            entitlements: [.mcp],
            enabledExperimentalProviders: [.mcp]
        )
        let boundary = ServerProviderRuntimeDispatcher.prepare(plan)

        XCTAssertEqual(boundary.state, .confirmationRequired)
        XCTAssertFalse(boundary.isPrepared)
        XCTAssertNil(boundary.descriptorID)
        XCTAssertNil(boundary.providerFamily)
        XCTAssertEqual(boundary.audit.rejectionReason, .planNotPlanned)
        XCTAssertTrue(boundary.statusLine.contains("withheld until confirmation"))
    }

    func test_descriptorUnavailablePlanIsNotPrepared() throws {
        let decision = serverReadyDecision(
            traceID: "a19-mismatch",
            providerFamily: .googleMaps,
            capability: .localServiceSearch,
            costClass: .meteredPremium,
            entitlements: [.googleMaps]
        )
        let searchDescriptor = try XCTUnwrap(
            ServerProviderRuntimeRegistry.descriptors.first { $0.providerFamily == .searchAPI }
        )
        let mismatchLookup = ServerProviderRuntimeLookupResult(
            id: "a19-runtime-mismatch",
            state: .descriptorAvailable,
            descriptor: searchDescriptor,
            readinessDecision: decision,
            statusLine: "Mismatched descriptor fixture."
        )
        let plan = ServerProviderRuntimeInvocationPlanner.makePlan(
            readinessDecision: decision,
            runtimeLookup: mismatchLookup
        )

        let boundary = ServerProviderRuntimeDispatcher.prepare(plan)

        XCTAssertEqual(boundary.state, .descriptorUnavailable)
        XCTAssertFalse(boundary.isPrepared)
        XCTAssertNil(boundary.descriptorID)
        XCTAssertNil(boundary.providerFamily)
        XCTAssertEqual(boundary.audit.rejectionReason, .planNotPlanned)
        XCTAssertTrue(boundary.statusLine.contains("descriptor metadata is unavailable"))
    }

    func test_malformedPlannedMetadataIsRejected() {
        let goodPlan = planned(
            traceID: "a19-malformed-base",
            providerFamily: .googleMaps,
            capability: .localServiceSearch,
            costClass: .meteredPremium,
            entitlements: [.googleMaps]
        )

        let cases: [(ServerProviderRuntimeInvocationPlan, ServerProviderRuntimeDispatchRejectionReason)] = [
            (
                malformedPlan(from: goodPlan, traceID: .some(nil)),
                .missingTraceID
            ),
            (
                malformedPlan(from: goodPlan, providerFamily: .some(nil)),
                .missingProviderFamily
            ),
            (
                malformedPlan(from: goodPlan, capability: .some(nil)),
                .missingCapability
            ),
            (
                malformedPlan(from: goodPlan, descriptorID: .some(nil)),
                .missingDescriptorID
            ),
            (
                malformedPlan(from: goodPlan, id: " "),
                .missingPlanID
            ),
        ]

        for (plan, rejection) in cases {
            let boundary = ServerProviderRuntimeDispatcher.prepare(plan)

            XCTAssertEqual(boundary.state, .planRejected)
            XCTAssertFalse(boundary.isPrepared)
            XCTAssertEqual(boundary.audit.rejectionReason, rejection)
            XCTAssertTrue(boundary.statusLine.contains("plan metadata is invalid"))
        }
    }

    func test_dispatchBoundaryEncodingDoesNotExposeSensitiveRuntimeFields() throws {
        let boundaries = [
            ServerProviderRuntimeDispatcher.prepare(
                planned(
                    traceID: "a19-encoding-search",
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
            ServerProviderRuntimeDispatcher.prepare(
                planFromReadiness(
                    traceID: "a19-encoding-confirmation",
                    providerFamily: .mcp,
                    capability: .mcpTool,
                    costClass: .includedQuota,
                    confirmationState: .requiredMissing,
                    entitlements: [.mcp],
                    enabledExperimentalProviders: [.mcp]
                )
            ),
            ServerProviderRuntimeDispatcher.prepare(
                ServerProviderRuntimeInvocationPlanner.makePlan(
                    readinessDecision: try privateBlockedDecision()
                )
            ),
        ]
        let data = try JSONEncoder().encode(boundaries)
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
            XCTAssertFalse(lowercased.contains(fragment), "Unexpected dispatch field: \(fragment)")
        }
    }

    func test_dispatchStatusCopyDoesNotUseCompletedOrActionDoneWording() throws {
        let boundaries = [
            ServerProviderRuntimeDispatcher.prepare(
                planned(
                    traceID: "a19-copy-prepared",
                    providerFamily: .googleMaps,
                    capability: .localServiceSearch,
                    costClass: .meteredPremium,
                    entitlements: [.googleMaps]
                )
            ),
            ServerProviderRuntimeDispatcher.prepare(
                planFromReadiness(
                    traceID: "a19-copy-local",
                    providerFamily: .appleLocal,
                    capability: .routePlanning,
                    costClass: .freeLocal,
                    freshness: .cachedOK
                )
            ),
            ServerProviderRuntimeDispatcher.prepare(
                planFromReadiness(
                    traceID: "a19-copy-confirmation",
                    providerFamily: .mcp,
                    capability: .mcpTool,
                    costClass: .includedQuota,
                    confirmationState: .requiredMissing,
                    entitlements: [.mcp],
                    enabledExperimentalProviders: [.mcp]
                )
            ),
            ServerProviderRuntimeDispatcher.prepare(
                ServerProviderRuntimeInvocationPlanner.makePlan(
                    readinessDecision: try privateBlockedDecision()
                )
            ),
        ]
        let text = boundaries
            .map(\.statusLine)
            .joined(separator: "\n")
            .lowercased()

        for forbidden in ["completed", "complete", "done", "called", "booked", "ordered", "paid", "purchased"] {
            XCTAssertFalse(text.contains(forbidden), "Unexpected wording: \(forbidden)")
        }
    }

    @discardableResult
    private func assertPrepared(
        plan: ServerProviderRuntimeInvocationPlan,
        family: ProviderFamily,
        capability: ProviderCapability,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> ServerProviderRuntimeDispatchBoundary {
        let boundary = ServerProviderRuntimeDispatcher.prepare(plan)

        XCTAssertEqual(boundary.state, .prepared, file: file, line: line)
        XCTAssertTrue(boundary.isPrepared, file: file, line: line)
        XCTAssertEqual(boundary.planID, plan.id, file: file, line: line)
        XCTAssertEqual(boundary.traceID, plan.traceID, file: file, line: line)
        XCTAssertEqual(boundary.providerFamily, family, file: file, line: line)
        XCTAssertEqual(boundary.capability, capability, file: file, line: line)
        XCTAssertEqual(boundary.descriptorID, plan.descriptorID, file: file, line: line)
        XCTAssertEqual(boundary.audit.planState, .planned, file: file, line: line)
        XCTAssertNil(boundary.audit.rejectionReason, file: file, line: line)
        XCTAssertTrue(boundary.statusLine.contains("metadata only"), file: file, line: line)
        return boundary
    }

    private func malformedPlan(
        from plan: ServerProviderRuntimeInvocationPlan,
        id: String? = nil,
        traceID: String?? = nil,
        providerFamily: ProviderFamily?? = nil,
        capability: ProviderCapability?? = nil,
        descriptorID: String?? = nil
    ) -> ServerProviderRuntimeInvocationPlan {
        ServerProviderRuntimeInvocationPlan(
            id: id ?? plan.id,
            state: plan.state,
            statusLine: plan.statusLine,
            traceID: traceID ?? plan.traceID,
            providerFamily: providerFamily ?? plan.providerFamily,
            capability: capability ?? plan.capability,
            costClass: plan.costClass,
            freshness: plan.freshness,
            sourcePolicy: plan.sourcePolicy,
            confirmationState: plan.confirmationState,
            descriptorID: descriptorID ?? plan.descriptorID,
            audit: plan.audit
        )
    }

    private func planned(
        traceID: String,
        providerFamily: ProviderFamily,
        capability: ProviderCapability,
        costClass: ProviderCostClass,
        sourcePolicy: ServerSourcePolicy? = nil,
        confirmationState: ServerConfirmationState = .notRequired,
        entitlements: Set<ProviderFamily> = [],
        enabledExperimentalProviders: Set<ProviderFamily> = []
    ) -> ServerProviderRuntimeInvocationPlan {
        let plan = planFromReadiness(
            traceID: traceID,
            providerFamily: providerFamily,
            capability: capability,
            costClass: costClass,
            sourcePolicy: sourcePolicy,
            confirmationState: confirmationState,
            entitlements: entitlements,
            enabledExperimentalProviders: enabledExperimentalProviders
        )
        XCTAssertEqual(plan.state, .planned)
        return plan
    }

    private func planFromReadiness(
        traceID: String,
        providerFamily: ProviderFamily,
        capability: ProviderCapability,
        costClass: ProviderCostClass,
        freshness: ProviderFreshness = .livePreferred,
        sourcePolicy: ServerSourcePolicy? = nil,
        confirmationState: ServerConfirmationState = .notRequired,
        entitlements: Set<ProviderFamily> = [],
        enabledExperimentalProviders: Set<ProviderFamily> = []
    ) -> ServerProviderRuntimeInvocationPlan {
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
            traceID: "a19-private-block",
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
