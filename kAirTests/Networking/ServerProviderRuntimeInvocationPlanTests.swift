//
//  ServerProviderRuntimeInvocationPlanTests.swift
//  kAirTests
//
//  A18 invocation-plan contract: value-only planning, no provider runtime.
//

import XCTest
@testable import kAir

final class ServerProviderRuntimeInvocationPlanTests: XCTestCase {

    func test_googleGaodeAndSearchProduceValueOnlyPlansAfterReadinessAndDescriptorLookup() {
        assertPlanned(
            decision: serverReadyDecision(
                traceID: "a18-google",
                providerFamily: .googleMaps,
                capability: .localServiceSearch,
                costClass: .meteredPremium,
                entitlements: [.googleMaps]
            ),
            family: .googleMaps,
            capability: .localServiceSearch
        )

        assertPlanned(
            decision: serverReadyDecision(
                traceID: "a18-gaode",
                providerFamily: .gaode,
                capability: .localServiceSearch,
                costClass: .includedQuota,
                entitlements: [.gaode]
            ),
            family: .gaode,
            capability: .localServiceSearch
        )

        assertPlanned(
            decision: serverReadyDecision(
                traceID: "a18-search",
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

    func test_crawlerAndMCPProducePlansOnlyAfterReadinessAndDescriptorLookup() {
        let crawler = assertPlanned(
            decision: serverReadyDecision(
                traceID: "a18-crawler",
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

        let mcp = assertPlanned(
            decision: serverReadyDecision(
                traceID: "a18-mcp",
                providerFamily: .mcp,
                capability: .mcpTool,
                costClass: .includedQuota,
                confirmationState: .confirmed(artifactID: "confirm-a18"),
                entitlements: [.mcp],
                enabledExperimentalProviders: [.mcp]
            ),
            family: .mcp,
            capability: .mcpTool
        )
        XCTAssertEqual(mcp.confirmationState, .confirmed(artifactID: "confirm-a18"))
    }

    func test_localAppleAndCacheReadinessDoNotProduceInvocationPlans() {
        for family in [ProviderFamily.appleLocal, .cache] {
            let decision = readyDecision(
                traceID: "a18-local-\(family.rawValue)",
                providerFamily: family,
                capability: .routePlanning,
                costClass: .freeLocal,
                freshness: .cachedOK
            )
            let plan = ServerProviderRuntimeInvocationPlanner.makePlan(readinessDecision: decision)

            XCTAssertEqual(plan.state, .localOnly)
            XCTAssertFalse(plan.isPlanned)
            XCTAssertNil(plan.descriptorID)
            XCTAssertEqual(plan.providerFamily, family)
            XCTAssertEqual(plan.audit.readinessState, .localOnly)
            XCTAssertTrue(plan.statusLine.contains("Local-only"))
        }
    }

    func test_privateRemoteReadinessBlockDoesNotProduceInvocationPlan() throws {
        let envelope = ServerProviderEnvelope(
            traceID: "a18-private-block",
            capability: .placeSearch,
            providerFamily: .googleMaps,
            privacyClass: .health,
            membershipTier: .pro,
            costClass: .meteredPremium,
            freshness: .livePreferred,
            meteredProviderEntitlements: [.googleMaps]
        )
        let validation = ServerProviderEnvelopeValidator.validate(envelope)
        let decision = ServerProviderExecutionGate.evaluate(
            .blocked(
                .validatorRejected(try XCTUnwrap(validation.denialReason)),
                validation: validation
            )
        )

        let plan = ServerProviderRuntimeInvocationPlanner.makePlan(readinessDecision: decision)

        XCTAssertEqual(plan.state, .blocked)
        XCTAssertFalse(plan.isPlanned)
        XCTAssertNil(plan.descriptorID)
        XCTAssertEqual(plan.providerFamily, .googleMaps)
        XCTAssertEqual(plan.audit.validatorDenialReason, .privacyBlocked)
        XCTAssertTrue(plan.statusLine.contains("readiness is blocked"))
        XCTAssertTrue(plan.statusLine.contains("privacy policy blocks remote routing"))
    }

    func test_confirmationRequiredReadinessDoesNotProduceInvocationPlan() {
        let decision = readyDecision(
            traceID: "a18-confirmation",
            providerFamily: .mcp,
            capability: .mcpTool,
            costClass: .includedQuota,
            confirmationState: .requiredMissing,
            entitlements: [.mcp],
            enabledExperimentalProviders: [.mcp]
        )
        let plan = ServerProviderRuntimeInvocationPlanner.makePlan(readinessDecision: decision)

        XCTAssertEqual(plan.state, .confirmationRequired)
        XCTAssertFalse(plan.isPlanned)
        XCTAssertNil(plan.descriptorID)
        XCTAssertEqual(plan.audit.readinessState, .confirmationRequired)
        XCTAssertEqual(plan.audit.lookupState, .confirmationRequired)
        XCTAssertTrue(plan.statusLine.contains("withheld until confirmation"))
    }

    func test_descriptorProviderMismatchDoesNotProduceInvocationPlan() throws {
        let decision = serverReadyDecision(
            traceID: "a18-mismatch",
            providerFamily: .googleMaps,
            capability: .localServiceSearch,
            costClass: .meteredPremium,
            entitlements: [.googleMaps]
        )
        let searchDescriptor = try XCTUnwrap(
            ServerProviderRuntimeRegistry.descriptors.first { $0.providerFamily == .searchAPI }
        )
        let mismatchLookup = ServerProviderRuntimeLookupResult(
            id: "runtime-mismatch",
            state: .descriptorAvailable,
            descriptor: searchDescriptor,
            readinessDecision: decision,
            statusLine: "Mismatched descriptor fixture."
        )

        let plan = ServerProviderRuntimeInvocationPlanner.makePlan(
            readinessDecision: decision,
            runtimeLookup: mismatchLookup
        )

        XCTAssertEqual(plan.state, .descriptorUnavailable)
        XCTAssertFalse(plan.isPlanned)
        XCTAssertNil(plan.descriptorID)
        XCTAssertEqual(plan.providerFamily, .googleMaps)
        XCTAssertEqual(plan.capability, .localServiceSearch)
        XCTAssertTrue(plan.statusLine.contains("did not match readiness"))
    }

    func test_planEncodingDoesNotExposeSensitiveRuntimeFields() throws {
        let plans = [
            ServerProviderRuntimeInvocationPlanner.makePlan(
                readinessDecision: serverReadyDecision(
                    traceID: "a18-encoding-search",
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
            ServerProviderRuntimeInvocationPlanner.makePlan(
                readinessDecision: readyDecision(
                    traceID: "a18-encoding-confirmation",
                    providerFamily: .mcp,
                    capability: .mcpTool,
                    costClass: .includedQuota,
                    confirmationState: .requiredMissing,
                    entitlements: [.mcp],
                    enabledExperimentalProviders: [.mcp]
                )
            ),
            ServerProviderRuntimeInvocationPlanner.makePlan(
                readinessDecision: try privateBlockedDecision()
            ),
        ]
        let data = try JSONEncoder().encode(plans)
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
            XCTAssertFalse(lowercased.contains(fragment), "Unexpected plan field: \(fragment)")
        }
    }

    func test_planStatusCopyDoesNotUseCompletedOrActionDoneWording() throws {
        let plans = [
            ServerProviderRuntimeInvocationPlanner.makePlan(
                readinessDecision: serverReadyDecision(
                    traceID: "a18-copy-planned",
                    providerFamily: .googleMaps,
                    capability: .localServiceSearch,
                    costClass: .meteredPremium,
                    entitlements: [.googleMaps]
                )
            ),
            ServerProviderRuntimeInvocationPlanner.makePlan(
                readinessDecision: readyDecision(
                    traceID: "a18-copy-local",
                    providerFamily: .appleLocal,
                    capability: .routePlanning,
                    costClass: .freeLocal,
                    freshness: .cachedOK
                )
            ),
            ServerProviderRuntimeInvocationPlanner.makePlan(
                readinessDecision: readyDecision(
                    traceID: "a18-copy-confirmation",
                    providerFamily: .mcp,
                    capability: .mcpTool,
                    costClass: .includedQuota,
                    confirmationState: .requiredMissing,
                    entitlements: [.mcp],
                    enabledExperimentalProviders: [.mcp]
                )
            ),
            ServerProviderRuntimeInvocationPlanner.makePlan(
                readinessDecision: try privateBlockedDecision()
            ),
        ]
        let text = plans
            .map(\.statusLine)
            .joined(separator: "\n")
            .lowercased()

        for forbidden in ["completed", "complete", "done", "called", "booked", "ordered", "paid", "purchased"] {
            XCTAssertFalse(text.contains(forbidden), "Unexpected wording: \(forbidden)")
        }
    }

    @discardableResult
    private func assertPlanned(
        decision: ServerProviderExecutionReadinessDecision,
        family: ProviderFamily,
        capability: ProviderCapability,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> ServerProviderRuntimeInvocationPlan {
        let lookup = ServerProviderRuntimeRegistry.lookup(for: decision)
        let plan = ServerProviderRuntimeInvocationPlanner.makePlan(
            readinessDecision: decision,
            runtimeLookup: lookup
        )

        XCTAssertEqual(plan.state, .planned, file: file, line: line)
        XCTAssertTrue(plan.isPlanned, file: file, line: line)
        XCTAssertEqual(plan.providerFamily, family, file: file, line: line)
        XCTAssertEqual(plan.capability, capability, file: file, line: line)
        XCTAssertEqual(plan.descriptorID, lookup.descriptor?.id, file: file, line: line)
        XCTAssertEqual(plan.audit.readinessState, .serverReady, file: file, line: line)
        XCTAssertEqual(plan.audit.lookupState, .descriptorAvailable, file: file, line: line)
        XCTAssertTrue(plan.statusLine.contains("metadata only"), file: file, line: line)
        return plan
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
            traceID: "a18-private-block-encoding",
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
