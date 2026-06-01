//
//  ServerProviderRuntimeRegistryTests.swift
//  kAirTests
//
//  A17 runtime registry contract: metadata lookup only, no provider runtime.
//

import XCTest
@testable import kAir

final class ServerProviderRuntimeRegistryTests: XCTestCase {

    func test_googleGaodeAndSearchDescriptorsResolveFromServerReadyDecisions() {
        assertDescriptor(
            for: serverReadyDecision(
                providerFamily: .googleMaps,
                capability: .localServiceSearch,
                costClass: .meteredPremium,
                entitlements: [.googleMaps]
            ),
            family: .googleMaps,
            requiredTier: .plus,
            costClass: .meteredPremium,
            capability: .localServiceSearch
        )

        assertDescriptor(
            for: serverReadyDecision(
                providerFamily: .gaode,
                capability: .localServiceSearch,
                costClass: .includedQuota,
                entitlements: [.gaode]
            ),
            family: .gaode,
            requiredTier: .plus,
            costClass: .includedQuota,
            capability: .localServiceSearch
        )

        assertDescriptor(
            for: serverReadyDecision(
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
            requiredTier: .plus,
            costClass: .meteredPremium,
            capability: .webSearch
        )

        let search = ServerProviderRuntimeRegistry.lookup(
            for: serverReadyDecision(
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
        )
        XCTAssertEqual(search.descriptor?.requiresSourcePolicy, true)
        XCTAssertEqual(search.descriptor?.requiresRobotsAllow, false)
    }

    func test_crawlerAndMCPDescriptorsResolveOnlyAfterReadiness() {
        let crawler = ServerProviderRuntimeRegistry.lookup(
            for: serverReadyDecision(
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
            )
        )
        XCTAssertEqual(crawler.state, .descriptorAvailable)
        XCTAssertEqual(crawler.descriptor?.providerFamily, .crawler)
        XCTAssertEqual(crawler.descriptor?.requiresSourcePolicy, true)
        XCTAssertEqual(crawler.descriptor?.requiresRobotsAllow, true)
        XCTAssertEqual(crawler.descriptor?.requiresExperimentalEnablement, true)

        let mcp = ServerProviderRuntimeRegistry.lookup(
            for: serverReadyDecision(
                providerFamily: .mcp,
                capability: .mcpTool,
                costClass: .includedQuota,
                confirmationState: .confirmed(artifactID: "confirm-a17"),
                entitlements: [.mcp],
                enabledExperimentalProviders: [.mcp]
            )
        )
        XCTAssertEqual(mcp.state, .descriptorAvailable)
        XCTAssertEqual(mcp.descriptor?.providerFamily, .mcp)
        XCTAssertEqual(mcp.descriptor?.requiresConfirmation, true)
        XCTAssertEqual(mcp.descriptor?.requiresExperimentalEnablement, true)
    }

    func test_localAppleAndCacheReadinessReturnNoRuntimeDescriptor() {
        for family in [ProviderFamily.appleLocal, .cache] {
            let lookup = ServerProviderRuntimeRegistry.lookup(
                for: readyDecision(
                    providerFamily: family,
                    capability: .routePlanning,
                    costClass: .freeLocal,
                    freshness: .cachedOK
                )
            )

            XCTAssertEqual(lookup.state, .localOnly)
            XCTAssertFalse(lookup.hasDescriptor)
            XCTAssertNil(lookup.descriptor)
            XCTAssertTrue(lookup.statusLine.contains("Local-only"))
        }
    }

    func test_healthPrivateBlockedReadinessReturnsNoRuntimeDescriptor() throws {
        let envelope = ServerProviderEnvelope(
            traceID: "a17-health",
            capability: .placeSearch,
            providerFamily: .googleMaps,
            privacyClass: .health,
            membershipTier: .pro,
            costClass: .meteredPremium,
            freshness: .livePreferred,
            meteredProviderEntitlements: [.googleMaps]
        )
        let validation = ServerProviderEnvelopeValidator.validate(envelope)
        let readiness = ServerProviderExecutionGate.evaluate(
            .blocked(
                .validatorRejected(try XCTUnwrap(validation.denialReason)),
                validation: validation
            )
        )

        let lookup = ServerProviderRuntimeRegistry.lookup(for: readiness)

        XCTAssertEqual(lookup.state, .blocked)
        XCTAssertFalse(lookup.hasDescriptor)
        XCTAssertEqual(lookup.readinessDecision.validatorDenialReason, .privacyBlocked)
        XCTAssertTrue(lookup.statusLine.contains("readiness is blocked"))
        XCTAssertTrue(lookup.statusLine.contains("privacy policy blocks remote routing"))
    }

    func test_confirmationRequiredReadinessReturnsNoRuntimeDescriptor() {
        let lookup = ServerProviderRuntimeRegistry.lookup(
            for: readyDecision(
                providerFamily: .mcp,
                capability: .mcpTool,
                costClass: .includedQuota,
                confirmationState: .requiredMissing,
                entitlements: [.mcp],
                enabledExperimentalProviders: [.mcp]
            )
        )

        XCTAssertEqual(lookup.state, .confirmationRequired)
        XCTAssertFalse(lookup.hasDescriptor)
        XCTAssertNil(lookup.descriptor)
        XCTAssertTrue(lookup.statusLine.contains("withheld until confirmation"))
    }

    func test_descriptorsDoNotStoreSensitiveRuntimeFields() throws {
        let data = try JSONEncoder().encode(ServerProviderRuntimeRegistry.descriptors)
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
            XCTAssertFalse(lowercased.contains(fragment), "Unexpected descriptor field: \(fragment)")
        }
    }

    private func assertDescriptor(
        for decision: ServerProviderExecutionReadinessDecision,
        family: ProviderFamily,
        requiredTier: MembershipTier,
        costClass: ProviderCostClass,
        capability: ProviderCapability,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let lookup = ServerProviderRuntimeRegistry.lookup(for: decision)

        XCTAssertEqual(lookup.state, .descriptorAvailable, file: file, line: line)
        XCTAssertTrue(lookup.hasDescriptor, file: file, line: line)
        XCTAssertEqual(lookup.descriptor?.providerFamily, family, file: file, line: line)
        XCTAssertEqual(lookup.descriptor?.requiredMembershipTier, requiredTier, file: file, line: line)
        XCTAssertEqual(lookup.descriptor?.costClass, costClass, file: file, line: line)
        XCTAssertEqual(
            lookup.descriptor?.supportedCapabilities.contains(capability),
            true,
            file: file,
            line: line
        )
        XCTAssertTrue(lookup.statusLine.contains("metadata only"), file: file, line: line)
    }

    private func serverReadyDecision(
        providerFamily: ProviderFamily,
        capability: ProviderCapability,
        costClass: ProviderCostClass,
        sourcePolicy: ServerSourcePolicy? = nil,
        confirmationState: ServerConfirmationState = .notRequired,
        entitlements: Set<ProviderFamily> = [],
        enabledExperimentalProviders: Set<ProviderFamily> = []
    ) -> ServerProviderExecutionReadinessDecision {
        let decision = readyDecision(
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
            traceID: "a17-\(providerFamily.rawValue)-\(capability.rawValue)",
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
}
