//
//  ServerProviderRuntimeAdapterRegistryTests.swift
//  kAirTests
//
//  A21 adapter registry contract: fixture selection only, no provider runtime.
//

import XCTest
@testable import kAir

final class ServerProviderRuntimeAdapterRegistryTests: XCTestCase {

    func test_registryAcceptsPreparedGoogleGaodeAndSearch() {
        assertRegistryAccepted(
            boundary: prepared(
                traceID: "a21-google",
                providerFamily: .googleMaps,
                capability: .localServiceSearch,
                costClass: .meteredPremium,
                entitlements: [.googleMaps]
            ),
            family: .googleMaps,
            capability: .localServiceSearch
        )

        assertRegistryAccepted(
            boundary: prepared(
                traceID: "a21-gaode",
                providerFamily: .gaode,
                capability: .localServiceSearch,
                costClass: .includedQuota,
                entitlements: [.gaode]
            ),
            family: .gaode,
            capability: .localServiceSearch
        )

        assertRegistryAccepted(
            boundary: prepared(
                traceID: "a21-search",
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

    func test_registryAcceptsPreparedCrawlerAndMCP() {
        let crawler = assertRegistryAccepted(
            boundary: prepared(
                traceID: "a21-crawler",
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

        let mcp = assertRegistryAccepted(
            boundary: prepared(
                traceID: "a21-mcp",
                providerFamily: .mcp,
                capability: .mcpTool,
                costClass: .includedQuota,
                confirmationState: .confirmed(artifactID: "confirm-a21"),
                entitlements: [.mcp],
                enabledExperimentalProviders: [.mcp]
            ),
            family: .mcp,
            capability: .mcpTool
        )
        XCTAssertEqual(mcp.confirmationState, .confirmed(artifactID: "confirm-a21"))
    }

    func test_registryDoesNotSelectAdapterForLocalAppleOrCache() {
        for family in [ProviderFamily.appleLocal, .cache] {
            let boundary = boundaryFromReadiness(
                traceID: "a21-local-\(family.rawValue)",
                providerFamily: family,
                capability: .routePlanning,
                costClass: .freeLocal,
                freshness: .cachedOK
            )
            let result = ServerProviderRuntimeAdapterRegistry.resolve(boundary)

            XCTAssertEqual(result.state, .localOnly)
            XCTAssertFalse(result.isAcceptedFixture)
            XCTAssertNil(result.providerFamily)
            XCTAssertNil(result.descriptorID)
            XCTAssertEqual(result.audit.adapterRejectionReason, .boundaryNotPrepared)
            XCTAssertEqual(result.audit.boundaryState, .localOnly)
            XCTAssertTrue(result.statusLine.contains("Local-only"))
        }
    }

    func test_registryDoesNotSelectAdapterForPrivateRemoteBlockedBoundary() throws {
        let boundary = ServerProviderRuntimeDispatcher.prepare(
            ServerProviderRuntimeInvocationPlanner.makePlan(
                readinessDecision: try privateBlockedDecision()
            )
        )

        let result = ServerProviderRuntimeAdapterRegistry.resolve(boundary)

        XCTAssertEqual(result.state, .blocked)
        XCTAssertFalse(result.isAcceptedFixture)
        XCTAssertNil(result.providerFamily)
        XCTAssertNil(result.descriptorID)
        XCTAssertEqual(result.audit.validatorDenialReason, .privacyBlocked)
        XCTAssertEqual(result.audit.adapterRejectionReason, .boundaryNotPrepared)
        XCTAssertTrue(result.statusLine.contains("boundary is blocked"))
        XCTAssertTrue(result.statusLine.contains("privacy policy blocks remote routing"))
    }

    func test_registryDoesNotSelectAdapterForConfirmationRequiredBoundary() {
        let boundary = boundaryFromReadiness(
            traceID: "a21-confirmation",
            providerFamily: .mcp,
            capability: .mcpTool,
            costClass: .includedQuota,
            confirmationState: .requiredMissing,
            entitlements: [.mcp],
            enabledExperimentalProviders: [.mcp]
        )

        let result = ServerProviderRuntimeAdapterRegistry.resolve(boundary)

        XCTAssertEqual(result.state, .confirmationRequired)
        XCTAssertFalse(result.isAcceptedFixture)
        XCTAssertNil(result.providerFamily)
        XCTAssertNil(result.descriptorID)
        XCTAssertEqual(result.audit.adapterRejectionReason, .boundaryNotPrepared)
        XCTAssertTrue(result.statusLine.contains("withheld until confirmation"))
    }

    func test_registryDoesNotSelectAdapterForDescriptorUnavailableBoundary() throws {
        let decision = serverReadyDecision(
            traceID: "a21-mismatch",
            providerFamily: .googleMaps,
            capability: .localServiceSearch,
            costClass: .meteredPremium,
            entitlements: [.googleMaps]
        )
        let searchDescriptor = try XCTUnwrap(
            ServerProviderRuntimeRegistry.descriptors.first { $0.providerFamily == .searchAPI }
        )
        let mismatchLookup = ServerProviderRuntimeLookupResult(
            id: "a21-runtime-mismatch",
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

        let result = ServerProviderRuntimeAdapterRegistry.resolve(boundary)

        XCTAssertEqual(result.state, .descriptorUnavailable)
        XCTAssertFalse(result.isAcceptedFixture)
        XCTAssertNil(result.providerFamily)
        XCTAssertNil(result.descriptorID)
        XCTAssertEqual(result.audit.adapterRejectionReason, .boundaryNotPrepared)
        XCTAssertTrue(result.statusLine.contains("descriptor metadata is unavailable"))
    }

    func test_registryDoesNotSelectAdapterForPlanRejectedBoundary() {
        let goodPlan = ServerProviderRuntimeInvocationPlanner.makePlan(
            readinessDecision: readyDecision(
                traceID: "a21-plan-rejected-base",
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
        let boundary = ServerProviderRuntimeDispatcher.prepare(malformedPlan)

        let result = ServerProviderRuntimeAdapterRegistry.resolve(boundary)

        XCTAssertEqual(boundary.state, .planRejected)
        XCTAssertEqual(result.state, .planRejected)
        XCTAssertFalse(result.isAcceptedFixture)
        XCTAssertNil(result.providerFamily)
        XCTAssertNil(result.descriptorID)
        XCTAssertEqual(result.audit.dispatchRejectionReason, .missingDescriptorID)
        XCTAssertEqual(result.audit.adapterRejectionReason, .boundaryNotPrepared)
        XCTAssertTrue(result.statusLine.contains("plan metadata was rejected"))
    }

    func test_registryRejectsMalformedPreparedMetadata() {
        let goodBoundary = prepared(
            traceID: "a21-malformed-base",
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
            let result = ServerProviderRuntimeAdapterRegistry.resolve(boundary)

            XCTAssertEqual(result.state, .notPrepared)
            XCTAssertFalse(result.isAcceptedFixture)
            XCTAssertEqual(result.audit.adapterRejectionReason, rejection)
            XCTAssertTrue(
                result.statusLine.contains("invalid")
                    || result.statusLine.contains("missing")
            )
        }
    }

    func test_registryRejectsUnregisteredProviderFamily() {
        for family in [ProviderFamily.appleLocal, .cache] {
            let boundary = malformedBoundary(
                from: prepared(
                    traceID: "a21-unregistered-\(family.rawValue)",
                    providerFamily: .googleMaps,
                    capability: .localServiceSearch,
                    costClass: .meteredPremium,
                    entitlements: [.googleMaps]
                ),
                providerFamily: .some(family)
            )

            let result = ServerProviderRuntimeAdapterRegistry.resolve(boundary)

            XCTAssertEqual(result.state, .notPrepared)
            XCTAssertFalse(result.isAcceptedFixture)
            XCTAssertNil(result.providerFamily)
            XCTAssertNil(result.descriptorID)
            XCTAssertEqual(result.audit.adapterRejectionReason, .unregisteredProvider)
            XCTAssertTrue(result.statusLine.contains("not registered"))
        }
    }

    func test_registryResultEncodingDoesNotExposeSensitiveRuntimeFields() throws {
        let results = [
            ServerProviderRuntimeAdapterRegistry.resolve(
                prepared(
                    traceID: "a21-encoding-search",
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
            ServerProviderRuntimeAdapterRegistry.resolve(
                boundaryFromReadiness(
                    traceID: "a21-encoding-confirmation",
                    providerFamily: .mcp,
                    capability: .mcpTool,
                    costClass: .includedQuota,
                    confirmationState: .requiredMissing,
                    entitlements: [.mcp],
                    enabledExperimentalProviders: [.mcp]
                )
            ),
            ServerProviderRuntimeAdapterRegistry.resolve(
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
            XCTAssertFalse(lowercased.contains(fragment), "Unexpected registry result field: \(fragment)")
        }
    }

    func test_registryStatusDoesNotUseCompletedOrActionDoneWordingOrImplyProviderContact() throws {
        let results = [
            ServerProviderRuntimeAdapterRegistry.resolve(
                prepared(
                    traceID: "a21-copy-accepted",
                    providerFamily: .googleMaps,
                    capability: .localServiceSearch,
                    costClass: .meteredPremium,
                    entitlements: [.googleMaps]
                )
            ),
            ServerProviderRuntimeAdapterRegistry.resolve(
                boundaryFromReadiness(
                    traceID: "a21-copy-local",
                    providerFamily: .appleLocal,
                    capability: .routePlanning,
                    costClass: .freeLocal,
                    freshness: .cachedOK
                )
            ),
            ServerProviderRuntimeAdapterRegistry.resolve(
                boundaryFromReadiness(
                    traceID: "a21-copy-confirmation",
                    providerFamily: .mcp,
                    capability: .mcpTool,
                    costClass: .includedQuota,
                    confirmationState: .requiredMissing,
                    entitlements: [.mcp],
                    enabledExperimentalProviders: [.mcp]
                )
            ),
            ServerProviderRuntimeAdapterRegistry.resolve(
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

    func test_adapterSetResolvesPreparedSearchWithInjectedAdapter() {
        let boundary = prepared(
            traceID: "a59-injected-search",
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
        let adapterSet = ServerProviderRuntimeAdapterSet(
            adapters: [
                MarkerServerProviderRuntimeAdapter(
                    providerFamily: .searchAPI,
                    marker: "injected-search-a59"
                ),
            ]
        )

        let result = adapterSet.resolve(boundary)
        let defaultResult = ServerProviderRuntimeAdapterRegistry.resolve(boundary)

        XCTAssertEqual(adapterSet.registeredProviderFamilies, [.searchAPI])
        XCTAssertEqual(result.state, .acceptedFixture)
        XCTAssertEqual(result.providerFamily, .searchAPI)
        XCTAssertEqual(result.capability, .webSearch)
        XCTAssertEqual(result.descriptorID, boundary.descriptorID)
        XCTAssertTrue(result.statusLine.contains("injected-search-a59"))
        XCTAssertFalse(defaultResult.statusLine.contains("injected-search-a59"))
    }

    func test_adapterSetRejectsMissingInjectedProviderFamily() {
        let boundary = prepared(
            traceID: "a59-missing-family",
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
        let adapterSet = ServerProviderRuntimeAdapterSet(
            adapters: [
                MarkerServerProviderRuntimeAdapter(
                    providerFamily: .googleMaps,
                    marker: "injected-google-a59"
                ),
            ]
        )

        let result = adapterSet.resolve(boundary)

        XCTAssertEqual(result.state, .notPrepared)
        XCTAssertFalse(result.isAcceptedFixture)
        XCTAssertNil(result.providerFamily)
        XCTAssertNil(result.descriptorID)
        XCTAssertEqual(result.audit.adapterRejectionReason, .unregisteredProvider)
        XCTAssertTrue(result.statusLine.contains("not registered"))
    }

    func test_adapterSetDuplicateProviderFamiliesKeepFirstAdapter() {
        let boundary = prepared(
            traceID: "a59-duplicate-search",
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
        let adapterSet = ServerProviderRuntimeAdapterSet(
            adapters: [
                MarkerServerProviderRuntimeAdapter(
                    providerFamily: .searchAPI,
                    marker: "first-injected-search-a59"
                ),
                MarkerServerProviderRuntimeAdapter(
                    providerFamily: .searchAPI,
                    marker: "second-injected-search-a59"
                ),
            ]
        )

        let result = adapterSet.resolve(boundary)

        XCTAssertEqual(adapterSet.registeredProviderFamilies, [.searchAPI])
        XCTAssertEqual(result.state, .acceptedFixture)
        XCTAssertTrue(result.statusLine.contains("first-injected-search-a59"))
        XCTAssertFalse(result.statusLine.contains("second-injected-search-a59"))
    }

    func test_adapterSetDoesNotSelectInjectedAdapterForNonPreparedBoundaries() throws {
        let adapterSet = ServerProviderRuntimeAdapterSet(
            adapters: [
                MarkerServerProviderRuntimeAdapter(
                    providerFamily: .googleMaps,
                    marker: "blocked-injected-google-a59"
                ),
                MarkerServerProviderRuntimeAdapter(
                    providerFamily: .mcp,
                    marker: "confirmation-injected-mcp-a59"
                ),
            ]
        )
        let cases: [(ServerProviderRuntimeDispatchBoundary, ServerProviderRuntimeAdapterResultState)] = [
            (
                boundaryFromReadiness(
                    traceID: "a59-local-only",
                    providerFamily: .appleLocal,
                    capability: .routePlanning,
                    costClass: .freeLocal,
                    freshness: .cachedOK
                ),
                .localOnly
            ),
            (
                boundaryFromReadiness(
                    traceID: "a59-confirmation",
                    providerFamily: .mcp,
                    capability: .mcpTool,
                    costClass: .includedQuota,
                    confirmationState: .requiredMissing,
                    entitlements: [.mcp],
                    enabledExperimentalProviders: [.mcp]
                ),
                .confirmationRequired
            ),
            (
                ServerProviderRuntimeDispatcher.prepare(
                    ServerProviderRuntimeInvocationPlanner.makePlan(
                        readinessDecision: try privateBlockedDecision()
                    )
                ),
                .blocked
            ),
            (
                descriptorUnavailableBoundary(),
                .descriptorUnavailable
            ),
            (
                planRejectedBoundary(),
                .planRejected
            ),
        ]

        for (boundary, expectedState) in cases {
            let result = adapterSet.resolve(boundary)

            XCTAssertEqual(result.state, expectedState)
            XCTAssertFalse(result.isAcceptedFixture)
            XCTAssertNil(result.providerFamily)
            XCTAssertNil(result.descriptorID)
            XCTAssertEqual(result.audit.adapterRejectionReason, .boundaryNotPrepared)
            XCTAssertFalse(result.statusLine.contains("blocked-injected-google-a59"))
            XCTAssertFalse(result.statusLine.contains("confirmation-injected-mcp-a59"))
        }
    }

    @discardableResult
    private func assertRegistryAccepted(
        boundary: ServerProviderRuntimeDispatchBoundary,
        family: ProviderFamily,
        capability: ProviderCapability,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> ServerProviderRuntimeAdapterResult {
        let result = ServerProviderRuntimeAdapterRegistry.resolve(boundary)

        XCTAssertEqual(result.state, .acceptedFixture, file: file, line: line)
        XCTAssertTrue(result.isAcceptedFixture, file: file, line: line)
        XCTAssertEqual(result.boundaryID, boundary.id, file: file, line: line)
        XCTAssertEqual(result.providerFamily, family, file: file, line: line)
        XCTAssertEqual(result.capability, capability, file: file, line: line)
        XCTAssertEqual(result.descriptorID, boundary.descriptorID, file: file, line: line)
        XCTAssertEqual(result.audit.boundaryState, .prepared, file: file, line: line)
        XCTAssertNil(result.audit.adapterRejectionReason, file: file, line: line)
        XCTAssertTrue(result.statusLine.contains("metadata only"), file: file, line: line)
        return result
    }

    private func descriptorUnavailableBoundary() -> ServerProviderRuntimeDispatchBoundary {
        let decision = serverReadyDecision(
            traceID: "a59-descriptor-unavailable",
            providerFamily: .googleMaps,
            capability: .localServiceSearch,
            costClass: .meteredPremium,
            entitlements: [.googleMaps]
        )
        let mismatchLookup = ServerProviderRuntimeLookupResult(
            id: "a59-runtime-mismatch",
            state: .unsupportedProvider,
            descriptor: nil,
            readinessDecision: decision,
            statusLine: "No injected descriptor fixture."
        )
        return ServerProviderRuntimeDispatcher.prepare(
            ServerProviderRuntimeInvocationPlanner.makePlan(
                readinessDecision: decision,
                runtimeLookup: mismatchLookup
            )
        )
    }

    private func planRejectedBoundary() -> ServerProviderRuntimeDispatchBoundary {
        let goodPlan = ServerProviderRuntimeInvocationPlanner.makePlan(
            readinessDecision: readyDecision(
                traceID: "a59-plan-rejected",
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
        return ServerProviderRuntimeDispatcher.prepare(malformedPlan)
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
            traceID: "a21-private-block",
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

private struct MarkerServerProviderRuntimeAdapter: ServerProviderRuntimeAdapter {
    let providerFamily: ProviderFamily
    let marker: String

    func resolve(
        _ boundary: ServerProviderRuntimeDispatchBoundary
    ) -> ServerProviderRuntimeAdapterResult {
        var result = FixtureServerProviderRuntimeAdapter(providerFamily: providerFamily)
            .resolve(boundary)
        if result.state == .acceptedFixture {
            result = ServerProviderRuntimeAdapterResult(
                id: result.id,
                state: result.state,
                statusLine: "\(marker) accepted prepared metadata only. No provider runtime has run.",
                boundaryID: result.boundaryID,
                planID: result.planID,
                traceID: result.traceID,
                providerFamily: result.providerFamily,
                capability: result.capability,
                descriptorID: result.descriptorID,
                costClass: result.costClass,
                freshness: result.freshness,
                sourcePolicy: result.sourcePolicy,
                confirmationState: result.confirmationState,
                audit: result.audit
            )
        }
        return result
    }
}
