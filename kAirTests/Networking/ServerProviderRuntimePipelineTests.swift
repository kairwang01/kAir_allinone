//
//  ServerProviderRuntimePipelineTests.swift
//  kAirTests
//
//  A42 pipeline contract: one value-only entry point composes the existing
//  readiness, descriptor, invocation, dispatch, fixture-adapter, and receipt
//  layers without transport.
//

import XCTest
@testable import kAir

final class ServerProviderRuntimePipelineTests: XCTestCase {

    func test_pipelineProjectsPreparedRemoteFamiliesToFixtureReceipts() {
        let cases: [(ProviderFamily, ProviderCapability, ProviderCostClass, Set<ProviderFamily>, Set<ProviderFamily>, ServerSourcePolicy?, ServerConfirmationState)] = [
            (.googleMaps, .localServiceSearch, .meteredPremium, [.googleMaps], [], nil, .notRequired),
            (.gaode, .localServiceSearch, .includedQuota, [.gaode], [], nil, .notRequired),
            (
                .searchAPI,
                .webSearch,
                .meteredPremium,
                [.searchAPI],
                [],
                ServerSourcePolicy(
                    sourceState: .passed,
                    robotsState: .notApplicable,
                    attributionRequired: true,
                    sourceHost: "example.com"
                ),
                .notRequired
            ),
            (
                .crawler,
                .crawlerFetch,
                .meteredPremium,
                [.crawler],
                [.crawler],
                ServerSourcePolicy(
                    sourceState: .passed,
                    robotsState: .allowed,
                    attributionRequired: true,
                    sourceHost: "public.example.com"
                ),
                .notRequired
            ),
            (.mcp, .mcpTool, .includedQuota, [.mcp], [.mcp], nil, .confirmed(artifactID: "a42-confirm")),
        ]

        for (family, capability, costClass, entitlements, experimentalProviders, sourcePolicy, confirmation) in cases {
            let receipt = ServerProviderRuntimePipeline.run(
                readinessDecision: readyDecision(
                    traceID: "a42-\(family.rawValue)",
                    providerFamily: family,
                    capability: capability,
                    costClass: costClass,
                    sourcePolicy: sourcePolicy,
                    confirmationState: confirmation,
                    entitlements: entitlements,
                    enabledExperimentalProviders: experimentalProviders
                )
            )

            XCTAssertEqual(receipt.state, .fixtureProjected, family.rawValue)
            XCTAssertTrue(receipt.isFixtureProjected, family.rawValue)
            XCTAssertEqual(receipt.providerFamily, family, family.rawValue)
            XCTAssertEqual(receipt.capability, capability, family.rawValue)
            XCTAssertNil(receipt.audit.dispatchRejectionReason, family.rawValue)
            XCTAssertNil(receipt.audit.adapterRejectionReason, family.rawValue)
            XCTAssertEqual(receipt.audit.readinessState, .serverReady, family.rawValue)
            XCTAssertEqual(receipt.audit.lookupState, .descriptorAvailable, family.rawValue)
        }
    }

    func test_pipelinePreservesLocalOnlyReadinessAsNonSuccess() {
        for family in [ProviderFamily.appleLocal, .cache] {
            let receipt = ServerProviderRuntimePipeline.run(
                readinessDecision: readyDecision(
                    traceID: "a42-local-\(family.rawValue)",
                    providerFamily: family,
                    capability: .routePlanning,
                    costClass: .freeLocal,
                    freshness: .cachedOK
                )
            )

            XCTAssertEqual(receipt.state, .localOnly)
            XCTAssertFalse(receipt.isFixtureProjected)
            XCTAssertNil(receipt.providerFamily)
            XCTAssertEqual(receipt.audit.readinessState, .localOnly)
            XCTAssertEqual(receipt.audit.lookupState, .localOnly)
            XCTAssertEqual(receipt.audit.adapterRejectionReason, .boundaryNotPrepared)
        }
    }

    func test_pipelinePreservesPrivateRemoteBlock() throws {
        let receipt = ServerProviderRuntimePipeline.run(
            readinessDecision: try privateBlockedDecision()
        )

        XCTAssertEqual(receipt.state, .blocked)
        XCTAssertFalse(receipt.isFixtureProjected)
        XCTAssertNil(receipt.providerFamily)
        XCTAssertEqual(receipt.audit.readinessState, .blocked)
        XCTAssertEqual(receipt.audit.validatorDenialReason, .privacyBlocked)
        XCTAssertEqual(receipt.audit.adapterRejectionReason, .boundaryNotPrepared)
    }

    func test_pipelinePreservesConfirmationRequiredBoundary() {
        let receipt = ServerProviderRuntimePipeline.run(
            readinessDecision: readyDecision(
                traceID: "a42-confirmation-required",
                providerFamily: .mcp,
                capability: .mcpTool,
                costClass: .includedQuota,
                confirmationState: .requiredMissing,
                entitlements: [.mcp],
                enabledExperimentalProviders: [.mcp]
            )
        )

        XCTAssertEqual(receipt.state, .confirmationRequired)
        XCTAssertFalse(receipt.isFixtureProjected)
        XCTAssertNil(receipt.providerFamily)
        XCTAssertEqual(receipt.audit.readinessState, .confirmationRequired)
        XCTAssertEqual(receipt.audit.validatorDenialReason, .confirmationRequired)
        XCTAssertEqual(receipt.audit.adapterRejectionReason, .boundaryNotPrepared)
    }

    func test_pipelinePreservesDescriptorUnavailable() throws {
        let decision = serverReadyDecision(
            traceID: "a42-descriptor-mismatch",
            providerFamily: .googleMaps,
            capability: .localServiceSearch,
            costClass: .meteredPremium,
            entitlements: [.googleMaps]
        )
        let searchDescriptor = try XCTUnwrap(
            ServerProviderRuntimeRegistry.descriptors.first { $0.providerFamily == .searchAPI }
        )
        let mismatchLookup = ServerProviderRuntimeLookupResult(
            id: "a42-runtime-mismatch",
            state: .descriptorAvailable,
            descriptor: searchDescriptor,
            readinessDecision: decision,
            statusLine: "Mismatched descriptor fixture."
        )

        let receipt = ServerProviderRuntimePipeline.run(
            readinessDecision: decision,
            runtimeLookup: mismatchLookup
        )

        XCTAssertEqual(receipt.state, .descriptorUnavailable)
        XCTAssertFalse(receipt.isFixtureProjected)
        XCTAssertNil(receipt.providerFamily)
        XCTAssertEqual(receipt.audit.lookupState, .descriptorAvailable)
        XCTAssertEqual(receipt.audit.adapterRejectionReason, .boundaryNotPrepared)
    }

    func test_pipelinePreservesMalformedPlanAsPlanRejected() throws {
        let decision = serverReadyDecision(
            traceID: "a42-malformed-plan",
            providerFamily: .googleMaps,
            capability: .localServiceSearch,
            costClass: .meteredPremium,
            entitlements: [.googleMaps]
        )
        let descriptor = try XCTUnwrap(
            ServerProviderRuntimeRegistry.descriptors.first { $0.providerFamily == .googleMaps }
        )
        let malformedDescriptor = ServerProviderRuntimeDescriptor(
            id: " ",
            providerFamily: descriptor.providerFamily,
            displayName: descriptor.displayName,
            supportedCapabilities: descriptor.supportedCapabilities,
            requiredMembershipTier: descriptor.requiredMembershipTier,
            costClass: descriptor.costClass,
            requiresSourcePolicy: descriptor.requiresSourcePolicy,
            requiresRobotsAllow: descriptor.requiresRobotsAllow,
            requiresConfirmation: descriptor.requiresConfirmation,
            requiresExperimentalEnablement: descriptor.requiresExperimentalEnablement
        )
        let malformedLookup = ServerProviderRuntimeLookupResult(
            id: "a42-malformed-lookup",
            state: .descriptorAvailable,
            descriptor: malformedDescriptor,
            readinessDecision: decision,
            statusLine: "Malformed descriptor fixture."
        )

        let receipt = ServerProviderRuntimePipeline.run(
            readinessDecision: decision,
            runtimeLookup: malformedLookup
        )

        XCTAssertEqual(receipt.state, .planRejected)
        XCTAssertFalse(receipt.isFixtureProjected)
        XCTAssertNil(receipt.providerFamily)
        XCTAssertEqual(receipt.audit.dispatchRejectionReason, .missingDescriptorID)
        XCTAssertEqual(receipt.audit.adapterRejectionReason, .boundaryNotPrepared)
    }

    func test_pipelinePreservesUnregisteredAdapterAsUnavailable() {
        let readiness = syntheticServerReadyDecision(
            traceID: "a42-unregistered-cache",
            providerFamily: .cache,
            capability: .webSearch,
            costClass: .freeLocal
        )
        let lookup = ServerProviderRuntimeLookupResult(
            id: "a42-unregistered-lookup",
            state: .descriptorAvailable,
            descriptor: ServerProviderRuntimeDescriptor(
                id: "runtime-cache-test",
                providerFamily: .cache,
                displayName: "Cache Test",
                supportedCapabilities: [.webSearch],
                requiredMembershipTier: .free,
                costClass: .freeLocal,
                requiresSourcePolicy: false,
                requiresRobotsAllow: false,
                requiresConfirmation: false,
                requiresExperimentalEnablement: false
            ),
            readinessDecision: readiness,
            statusLine: "Synthetic cache descriptor fixture."
        )

        let receipt = ServerProviderRuntimePipeline.run(
            readinessDecision: readiness,
            runtimeLookup: lookup
        )

        XCTAssertEqual(receipt.state, .unavailable)
        XCTAssertFalse(receipt.isFixtureProjected)
        XCTAssertNil(receipt.providerFamily)
        XCTAssertEqual(receipt.audit.adapterRejectionReason, .unregisteredProvider)
        XCTAssertEqual(receipt.audit.readinessState, .serverReady)
    }

    func test_pipelineUsesInjectedAdapterSetForPreparedSearchReceipt() {
        let readiness = serverReadyDecision(
            traceID: "a60-injected-search",
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
                    marker: "pipeline-injected-search-a60"
                ),
            ]
        )

        let receipt = ServerProviderRuntimePipeline.run(
            readinessDecision: readiness,
            adapterSet: adapterSet
        )

        XCTAssertEqual(receipt.state, .fixtureProjected)
        XCTAssertTrue(receipt.isFixtureProjected)
        XCTAssertEqual(receipt.providerFamily, .searchAPI)
        XCTAssertEqual(receipt.capability, .webSearch)
        XCTAssertEqual(receipt.audit.readinessState, .serverReady)
        XCTAssertEqual(receipt.audit.lookupState, .descriptorAvailable)
        XCTAssertNil(receipt.audit.adapterRejectionReason)
        XCTAssertTrue(receipt.adapterResultID.contains("pipeline-injected-search-a60"))
    }

    func test_pipelineDefaultPathIgnoresInjectedAdapterMarkers() {
        let readiness = serverReadyDecision(
            traceID: "a60-default-search",
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
                    marker: "pipeline-default-ignored-a60"
                ),
            ]
        )

        let injected = ServerProviderRuntimePipeline.run(
            readinessDecision: readiness,
            adapterSet: adapterSet
        )
        let defaultReceipt = ServerProviderRuntimePipeline.run(
            readinessDecision: readiness
        )

        XCTAssertEqual(injected.state, .fixtureProjected)
        XCTAssertEqual(defaultReceipt.state, .fixtureProjected)
        XCTAssertTrue(injected.adapterResultID.contains("pipeline-default-ignored-a60"))
        XCTAssertFalse(defaultReceipt.adapterResultID.contains("pipeline-default-ignored-a60"))
        XCTAssertEqual(defaultReceipt.audit.adapterRejectionReason, nil)
    }

    func test_pipelineAuthorizedAdapterSetValidationAllowsInjectedAdapterFixturePath() {
        let readiness = serverReadyDecision(
            traceID: "a70-authorized-search",
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
                    marker: "pipeline-authorized-search-a70"
                ),
            ]
        )

        let receipt = ServerProviderRuntimePipeline.run(
            readinessDecision: readiness,
            adapterSet: adapterSet,
            validation: adapterSetValidation(
                state: .accepted,
                registered: [.searchAPI],
                accepted: [.searchAPI]
            )
        )

        XCTAssertEqual(receipt.state, .fixtureProjected)
        XCTAssertTrue(receipt.isFixtureProjected)
        XCTAssertEqual(receipt.providerFamily, .searchAPI)
        XCTAssertEqual(receipt.capability, .webSearch)
        XCTAssertNil(receipt.audit.adapterRejectionReason)
        XCTAssertTrue(receipt.adapterResultID.contains("pipeline-authorized-search-a70"))
    }

    func test_pipelineManifestBackedAuthorizationAllowsInjectedAdapterOnlyForSameFamily() {
        let readiness = serverReadyDecision(
            traceID: "a77-authorized-search",
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
                    marker: "pipeline-manifest-authorized-search-a77"
                ),
            ]
        )

        let receipt = ServerProviderRuntimePipeline.run(
            readinessDecision: readiness,
            adapterSet: adapterSet,
            authorization: manifestSetUseAuthorization(
                requestedProviderFamily: .searchAPI,
                registered: [.searchAPI],
                accepted: [.searchAPI]
            )
        )

        XCTAssertEqual(receipt.state, .fixtureProjected)
        XCTAssertTrue(receipt.isFixtureProjected)
        XCTAssertEqual(receipt.providerFamily, .searchAPI)
        XCTAssertEqual(receipt.capability, .webSearch)
        XCTAssertNil(receipt.audit.adapterRejectionReason)
        XCTAssertTrue(receipt.adapterResultID.contains("pipeline-manifest-authorized-search-a77"))
    }

    func test_pipelineManifestBackedAuthorizationRejectsBeforeInjectedAdapterResolve() {
        let googleReadiness = serverReadyDecision(
            traceID: "a77-rejected-google",
            providerFamily: .googleMaps,
            capability: .localServiceSearch,
            costClass: .meteredPremium,
            entitlements: [.googleMaps]
        )
        let searchReadiness = serverReadyDecision(
            traceID: "a77-mismatch-search",
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
        let cacheReadiness = syntheticServerReadyDecision(
            traceID: "a77-local-cache",
            providerFamily: .cache,
            capability: .webSearch,
            costClass: .freeLocal
        )
        let cacheLookup = syntheticRuntimeLookup(
            id: "a77-cache-runtime",
            readiness: cacheReadiness,
            providerFamily: .cache,
            capability: .webSearch,
            costClass: .freeLocal
        )
        let missingFamilyPlan = invocationPlan(
            withProviderFamily: nil,
            from: googleReadiness
        )
        let rejectedA69 = ServerProviderRuntimeAdapterSetUseGate.authorize(
            requestedProviderFamily: .mcp,
            validation: adapterSetValidation(
                state: .accepted,
                registered: [.googleMaps],
                accepted: [.googleMaps]
            )
        )

        let cases: [(ServerProviderRuntimeReceipt, String)] = [
            (
                ServerProviderRuntimePipeline.run(
                    invocationPlan: missingFamilyPlan,
                    adapterSet: ServerProviderRuntimeAdapterSet(
                        adapters: [TrapServerProviderRuntimeAdapter(providerFamily: .googleMaps)]
                    ),
                    authorization: manifestSetUseAuthorization(
                        requestedProviderFamily: .googleMaps,
                        registered: [.googleMaps],
                        accepted: [.googleMaps]
                    )
                ),
                "missingRequestedProviderFamily"
            ),
            (
                ServerProviderRuntimePipeline.run(
                    readinessDecision: cacheReadiness,
                    runtimeLookup: cacheLookup,
                    adapterSet: ServerProviderRuntimeAdapterSet(
                        adapters: [TrapServerProviderRuntimeAdapter(providerFamily: .cache)]
                    ),
                    authorization: manifestSetUseAuthorization(
                        requestedProviderFamily: .cache,
                        state: .rejected,
                        rejection: .localNoServerAdapter
                    )
                ),
                "localNoServerAdapter"
            ),
            (
                ServerProviderRuntimePipeline.run(
                    readinessDecision: googleReadiness,
                    adapterSet: ServerProviderRuntimeAdapterSet(
                        adapters: [TrapServerProviderRuntimeAdapter(providerFamily: .googleMaps)]
                    ),
                    authorization: rejectedManifestSetUseAuthorization(
                        requestedProviderFamily: .googleMaps,
                        rejection: .manifestValidationRejected
                    )
                ),
                "manifestAuthorizationRejected"
            ),
            (
                ServerProviderRuntimePipeline.run(
                    readinessDecision: searchReadiness,
                    adapterSet: ServerProviderRuntimeAdapterSet(
                        adapters: [TrapServerProviderRuntimeAdapter(providerFamily: .searchAPI)]
                    ),
                    authorization: manifestSetUseAuthorization(
                        requestedProviderFamily: .googleMaps,
                        registered: [.googleMaps],
                        accepted: [.googleMaps]
                    )
                ),
                "requestedProviderFamilyMismatch"
            ),
            (
                ServerProviderRuntimePipeline.run(
                    readinessDecision: googleReadiness,
                    adapterSet: ServerProviderRuntimeAdapterSet(
                        adapters: [TrapServerProviderRuntimeAdapter(providerFamily: .googleMaps)]
                    ),
                    authorization: manifestSetUseAuthorization(
                        requestedProviderFamily: .googleMaps,
                        readinessAuthorization: nil
                    )
                ),
                "missingReadinessAuthorization"
            ),
            (
                ServerProviderRuntimePipeline.run(
                    readinessDecision: serverReadyDecision(
                        traceID: "a77-rejected-mcp",
                        providerFamily: .mcp,
                        capability: .mcpTool,
                        costClass: .includedQuota,
                        confirmationState: .confirmed(artifactID: "a77-mcp"),
                        entitlements: [.mcp],
                        enabledExperimentalProviders: [.mcp]
                    ),
                    adapterSet: ServerProviderRuntimeAdapterSet(
                        adapters: [TrapServerProviderRuntimeAdapter(providerFamily: .mcp)]
                    ),
                    authorization: manifestSetUseAuthorization(
                        requestedProviderFamily: .mcp,
                        readinessAuthorization: rejectedA69
                    )
                ),
                "readinessAuthorizationRejected"
            ),
        ]

        for (receipt, reason) in cases {
            assertManifestUnauthorizedAdapterSetReceipt(receipt, reason: reason)
        }
    }

    func test_pipelineManifestBackedPathPreservesDefaultAndA70Overloads() {
        let readiness = serverReadyDecision(
            traceID: "a77-preserve-search",
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
                    marker: "pipeline-a77-preserve"
                ),
            ]
        )

        let defaultReceipt = ServerProviderRuntimePipeline.run(
            readinessDecision: readiness
        )
        let a70Receipt = ServerProviderRuntimePipeline.run(
            readinessDecision: readiness,
            adapterSet: adapterSet,
            validation: adapterSetValidation(
                state: .accepted,
                registered: [.searchAPI],
                accepted: [.searchAPI]
            )
        )

        XCTAssertEqual(defaultReceipt.state, .fixtureProjected)
        XCTAssertFalse(defaultReceipt.adapterResultID.contains("pipeline-a77-preserve"))
        XCTAssertEqual(a70Receipt.state, .fixtureProjected)
        XCTAssertTrue(a70Receipt.adapterResultID.contains("pipeline-a77-preserve"))
    }

    func test_pipelineRejectedValidationBlocksInjectedAdapterResolve() {
        let readiness = serverReadyDecision(
            traceID: "a70-rejected-validation-search",
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
                TrapServerProviderRuntimeAdapter(providerFamily: .searchAPI),
            ]
        )

        let receipt = ServerProviderRuntimePipeline.run(
            readinessDecision: readiness,
            adapterSet: adapterSet,
            validation: adapterSetValidation(
                state: .rejected,
                registered: [.searchAPI],
                accepted: [.searchAPI],
                rejected: [adapterSetRejection(for: .mcp)]
            )
        )

        assertUnauthorizedAdapterSetReceipt(
            receipt,
            reason: .validationRejected
        )
        XCTAssertEqual(receipt.audit.boundaryState, .prepared)
    }

    func test_pipelineMissingRequestedProviderFamilyBlocksInjectedAdapterResolve() {
        let adapterSet = ServerProviderRuntimeAdapterSet(
            adapters: [
                TrapServerProviderRuntimeAdapter(providerFamily: .googleMaps),
            ]
        )
        let goodPlan = ServerProviderRuntimeInvocationPlanner.makePlan(
            readinessDecision: serverReadyDecision(
                traceID: "a70-missing-family",
                providerFamily: .googleMaps,
                capability: .localServiceSearch,
                costClass: .meteredPremium,
                entitlements: [.googleMaps]
            )
        )
        let missingFamilyPlan = ServerProviderRuntimeInvocationPlan(
            id: goodPlan.id,
            state: goodPlan.state,
            statusLine: goodPlan.statusLine,
            traceID: goodPlan.traceID,
            providerFamily: nil,
            capability: goodPlan.capability,
            costClass: goodPlan.costClass,
            freshness: goodPlan.freshness,
            sourcePolicy: goodPlan.sourcePolicy,
            confirmationState: goodPlan.confirmationState,
            descriptorID: goodPlan.descriptorID,
            audit: goodPlan.audit
        )

        let receipt = ServerProviderRuntimePipeline.run(
            invocationPlan: missingFamilyPlan,
            adapterSet: adapterSet,
            validation: adapterSetValidation(
                state: .accepted,
                registered: [.googleMaps],
                accepted: [.googleMaps]
            )
        )

        assertUnauthorizedAdapterSetReceipt(
            receipt,
            reason: .missingRequestedProviderFamily
        )
        XCTAssertEqual(receipt.audit.boundaryState, .planRejected)
        XCTAssertEqual(receipt.audit.dispatchRejectionReason, .missingProviderFamily)
    }

    func test_pipelineUnregisteredLocalAndNotAcceptedFamiliesBlockInjectedAdapterResolve() {
        let searchReadiness = serverReadyDecision(
            traceID: "a70-not-accepted-search",
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
        let googleReadiness = serverReadyDecision(
            traceID: "a70-unregistered-google",
            providerFamily: .googleMaps,
            capability: .localServiceSearch,
            costClass: .meteredPremium,
            entitlements: [.googleMaps]
        )
        let cacheReadiness = syntheticServerReadyDecision(
            traceID: "a70-local-cache",
            providerFamily: .cache,
            capability: .webSearch,
            costClass: .freeLocal
        )
        let cacheLookup = syntheticRuntimeLookup(
            id: "a70-cache-runtime",
            readiness: cacheReadiness,
            providerFamily: .cache,
            capability: .webSearch,
            costClass: .freeLocal
        )
        let cases: [(ServerProviderRuntimeReceipt, ServerProviderRuntimeAdapterSetUseRejectionReason)] = [
            (
                ServerProviderRuntimePipeline.run(
                    readinessDecision: googleReadiness,
                    adapterSet: ServerProviderRuntimeAdapterSet(
                        adapters: [
                            TrapServerProviderRuntimeAdapter(providerFamily: .googleMaps),
                        ]
                    ),
                    validation: adapterSetValidation(
                        state: .accepted,
                        registered: [.searchAPI],
                        accepted: [.searchAPI]
                    )
                ),
                .unregisteredProviderFamily
            ),
            (
                ServerProviderRuntimePipeline.run(
                    readinessDecision: cacheReadiness,
                    runtimeLookup: cacheLookup,
                    adapterSet: ServerProviderRuntimeAdapterSet(
                        adapters: [
                            TrapServerProviderRuntimeAdapter(providerFamily: .cache),
                        ]
                    ),
                    validation: adapterSetValidation(
                        state: .accepted,
                        registered: [.cache],
                        accepted: [.cache]
                    )
                ),
                .localNoServerAdapter
            ),
            (
                ServerProviderRuntimePipeline.run(
                    readinessDecision: searchReadiness,
                    adapterSet: ServerProviderRuntimeAdapterSet(
                        adapters: [
                            TrapServerProviderRuntimeAdapter(providerFamily: .searchAPI),
                        ]
                    ),
                    validation: adapterSetValidation(
                        state: .accepted,
                        registered: [.searchAPI],
                        accepted: []
                    )
                ),
                .providerFamilyNotAccepted
            ),
        ]

        for (receipt, reason) in cases {
            assertUnauthorizedAdapterSetReceipt(receipt, reason: reason)
        }
    }

    func test_pipelineAdapterSetPreservesNonPreparedReceiptStates() throws {
        let adapterSet = ServerProviderRuntimeAdapterSet(
            adapters: [
                MarkerServerProviderRuntimeAdapter(
                    providerFamily: .googleMaps,
                    marker: "pipeline-nonprepared-google-a60"
                ),
                MarkerServerProviderRuntimeAdapter(
                    providerFamily: .mcp,
                    marker: "pipeline-nonprepared-mcp-a60"
                ),
            ]
        )
        let descriptorUnavailable = descriptorUnavailableReadinessAndLookup()
        let cases: [(ServerProviderRuntimeReceipt, ServerProviderRuntimeReceiptState)] = [
            (
                ServerProviderRuntimePipeline.run(
                    readinessDecision: readyDecision(
                        traceID: "a60-local-only",
                        providerFamily: .appleLocal,
                        capability: .routePlanning,
                        costClass: .freeLocal,
                        freshness: .cachedOK
                    ),
                    adapterSet: adapterSet
                ),
                .localOnly
            ),
            (
                ServerProviderRuntimePipeline.run(
                    readinessDecision: readyDecision(
                        traceID: "a60-confirmation",
                        providerFamily: .mcp,
                        capability: .mcpTool,
                        costClass: .includedQuota,
                        confirmationState: .requiredMissing,
                        entitlements: [.mcp],
                        enabledExperimentalProviders: [.mcp]
                    ),
                    adapterSet: adapterSet
                ),
                .confirmationRequired
            ),
            (
                ServerProviderRuntimePipeline.run(
                    readinessDecision: try privateBlockedDecision(),
                    adapterSet: adapterSet
                ),
                .blocked
            ),
            (
                ServerProviderRuntimePipeline.run(
                    readinessDecision: descriptorUnavailable.readiness,
                    runtimeLookup: descriptorUnavailable.lookup,
                    adapterSet: adapterSet
                ),
                .descriptorUnavailable
            ),
            (
                ServerProviderRuntimePipeline.run(
                    invocationPlan: malformedPlan(),
                    adapterSet: adapterSet
                ),
                .planRejected
            ),
        ]

        for (receipt, expectedState) in cases {
            XCTAssertEqual(receipt.state, expectedState)
            XCTAssertFalse(receipt.isFixtureProjected)
            XCTAssertNil(receipt.providerFamily)
            XCTAssertEqual(receipt.audit.adapterRejectionReason, .boundaryNotPrepared)
            XCTAssertFalse(receipt.adapterResultID.contains("pipeline-nonprepared-google-a60"))
            XCTAssertFalse(receipt.adapterResultID.contains("pipeline-nonprepared-mcp-a60"))
        }
    }

    func test_pipelineReceiptEncodingDoesNotExposeSensitiveRuntimeFields() throws {
        let receipts = [
            ServerProviderRuntimePipeline.run(
                readinessDecision: readyDecision(
                    traceID: "a42-encoding-search",
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
            ServerProviderRuntimePipeline.run(
                readinessDecision: readyDecision(
                    traceID: "a42-encoding-confirmation",
                    providerFamily: .mcp,
                    capability: .mcpTool,
                    costClass: .includedQuota,
                    confirmationState: .requiredMissing,
                    entitlements: [.mcp],
                    enabledExperimentalProviders: [.mcp]
                )
            ),
            ServerProviderRuntimePipeline.run(readinessDecision: try privateBlockedDecision()),
            ServerProviderRuntimePipeline.run(
                readinessDecision: serverReadyDecision(
                    traceID: "a70-encoding-unauthorized",
                    providerFamily: .googleMaps,
                    capability: .localServiceSearch,
                    costClass: .meteredPremium,
                    entitlements: [.googleMaps]
                ),
                adapterSet: ServerProviderRuntimeAdapterSet(
                    adapters: [
                        TrapServerProviderRuntimeAdapter(providerFamily: .googleMaps),
                    ]
                ),
                validation: adapterSetValidation(
                    state: .accepted,
                    registered: [.searchAPI],
                    accepted: [.searchAPI]
                )
            ),
            ServerProviderRuntimePipeline.run(
                readinessDecision: serverReadyDecision(
                    traceID: "a77-encoding-unauthorized",
                    providerFamily: .googleMaps,
                    capability: .localServiceSearch,
                    costClass: .meteredPremium,
                    entitlements: [.googleMaps]
                ),
                adapterSet: ServerProviderRuntimeAdapterSet(
                    adapters: [
                        TrapServerProviderRuntimeAdapter(providerFamily: .googleMaps),
                    ]
                ),
                authorization: rejectedManifestSetUseAuthorization(
                    requestedProviderFamily: .googleMaps,
                    rejection: .manifestValidationRejected
                )
            ),
        ]
        let data = try JSONEncoder().encode(receipts)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        let lowercased = ([json] + receipts.map(\.statusLine))
            .joined(separator: "\n")
            .lowercased()

        let forbiddenFragments = [
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
            "booking",
            "order",
            "pay" + "ment",
            "mer" + "chant",
            "transport",
            "completed",
            "action done",
            "provider contact",
            "provider contacted",
        ]

        for fragment in forbiddenFragments {
            XCTAssertFalse(lowercased.contains(fragment), "Unexpected receipt field: \(fragment)")
        }
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
            traceID: "a42-private-block",
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

    private func descriptorUnavailableReadinessAndLookup() -> (
        readiness: ServerProviderExecutionReadinessDecision,
        lookup: ServerProviderRuntimeLookupResult
    ) {
        let readiness = serverReadyDecision(
            traceID: "a60-descriptor-unavailable",
            providerFamily: .googleMaps,
            capability: .localServiceSearch,
            costClass: .meteredPremium,
            entitlements: [.googleMaps]
        )
        let lookup = ServerProviderRuntimeLookupResult(
            id: "a60-runtime-unavailable",
            state: .unsupportedProvider,
            descriptor: nil,
            readinessDecision: readiness,
            statusLine: "No injected descriptor fixture."
        )
        return (readiness, lookup)
    }

    private func malformedPlan() -> ServerProviderRuntimeInvocationPlan {
        let goodPlan = ServerProviderRuntimeInvocationPlanner.makePlan(
            readinessDecision: readyDecision(
                traceID: "a60-plan-rejected",
                providerFamily: .googleMaps,
                capability: .localServiceSearch,
                costClass: .meteredPremium,
                entitlements: [.googleMaps]
            )
        )
        return ServerProviderRuntimeInvocationPlan(
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
    }

    private func invocationPlan(
        withProviderFamily providerFamily: ProviderFamily?,
        from readiness: ServerProviderExecutionReadinessDecision
    ) -> ServerProviderRuntimeInvocationPlan {
        let plan = ServerProviderRuntimeInvocationPlanner.makePlan(
            readinessDecision: readiness
        )
        return ServerProviderRuntimeInvocationPlan(
            id: plan.id,
            state: plan.state,
            statusLine: plan.statusLine,
            traceID: plan.traceID,
            providerFamily: providerFamily,
            capability: plan.capability,
            costClass: plan.costClass,
            freshness: plan.freshness,
            sourcePolicy: plan.sourcePolicy,
            confirmationState: plan.confirmationState,
            descriptorID: plan.descriptorID,
            audit: plan.audit
        )
    }

    private func adapterSetValidation(
        state: ServerProviderRuntimeAdapterSetReadinessValidationState,
        registered: [ProviderFamily],
        accepted: [ProviderFamily],
        rejected: [ServerProviderRuntimeAdapterSetReadinessRejection] = []
    ) -> ServerProviderRuntimeAdapterSetReadinessValidation {
        ServerProviderRuntimeAdapterSetReadinessValidation(
            id: "a70-adapter-set-readiness-validation-\(state.rawValue)",
            state: state,
            registeredProviderFamilies: registered,
            acceptedProviderFamilies: accepted,
            rejectedProviderFamilies: rejected
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

    private func manifestSetUseAuthorization(
        requestedProviderFamily: ProviderFamily?,
        state: ServerProviderRuntimeAdapterManifestSetUseAuthorizationState,
        rejection: ServerProviderRuntimeAdapterManifestSetUseRejectionReason?
    ) -> ServerProviderRuntimeAdapterManifestSetUseAuthorization {
        ServerProviderRuntimeAdapterManifestSetUseAuthorization(
            id: "a77-manifest-set-use-\(requestedProviderFamily?.rawValue ?? "missing")",
            state: state,
            requestedProviderFamily: requestedProviderFamily,
            rejection: rejection,
            manifestValidationID: "a77-manifest-set-validation",
            manifestValidationState: state == .authorized ? .accepted : .rejected,
            manifestAcceptedProviderFamilies: requestedProviderFamily.map { [$0] } ?? [],
            readinessValidationID: nil,
            readinessValidationState: nil,
            readinessAuthorization: nil,
            readinessAuthorizationState: nil,
            readinessAuthorizationRejection: nil
        )
    }

    private func manifestSetUseAuthorization(
        requestedProviderFamily: ProviderFamily?,
        readinessAuthorization: ServerProviderRuntimeAdapterSetUseAuthorization?
    ) -> ServerProviderRuntimeAdapterManifestSetUseAuthorization {
        ServerProviderRuntimeAdapterManifestSetUseAuthorization(
            id: "a77-manifest-set-use-\(requestedProviderFamily?.rawValue ?? "missing")",
            state: .authorized,
            requestedProviderFamily: requestedProviderFamily,
            rejection: nil,
            manifestValidationID: "a77-manifest-set-validation",
            manifestValidationState: .accepted,
            manifestAcceptedProviderFamilies: requestedProviderFamily.map { [$0] } ?? [],
            readinessValidationID: readinessAuthorization?.validationID,
            readinessValidationState: readinessAuthorization?.validationState,
            readinessAuthorization: readinessAuthorization,
            readinessAuthorizationState: readinessAuthorization?.state,
            readinessAuthorizationRejection: readinessAuthorization?.rejection
        )
    }

    private func rejectedManifestSetUseAuthorization(
        requestedProviderFamily: ProviderFamily?,
        rejection: ServerProviderRuntimeAdapterManifestSetUseRejectionReason
    ) -> ServerProviderRuntimeAdapterManifestSetUseAuthorization {
        manifestSetUseAuthorization(
            requestedProviderFamily: requestedProviderFamily,
            state: .rejected,
            rejection: rejection
        )
    }

    private func manifestSetValidation(
        state: ServerProviderRuntimeAdapterManifestSetValidationState,
        registered: [ProviderFamily],
        accepted: [ProviderFamily],
        readinessValidation: ServerProviderRuntimeAdapterSetReadinessValidation?
    ) -> ServerProviderRuntimeAdapterManifestSetValidation {
        ServerProviderRuntimeAdapterManifestSetValidation(
            id: "a77-manifest-set-validation-\(state.rawValue)",
            state: state,
            registeredProviderFamilies: registered,
            acceptedProviderFamilies: accepted,
            rejectedProviderFamilies: [],
            readinessValidation: readinessValidation
        )
    }

    private func adapterSetRejection(
        for providerFamily: ProviderFamily
    ) -> ServerProviderRuntimeAdapterSetReadinessRejection {
        ServerProviderRuntimeAdapterSetReadinessRejection(
            id: "a70-adapter-set-rejection-\(providerFamily.rawValue)",
            providerFamily: providerFamily,
            reason: .missingInstallationDecision,
            decisionID: nil,
            decisionProviderFamily: nil,
            decisionState: nil,
            decisionRejection: nil
        )
    }

    private func assertUnauthorizedAdapterSetReceipt(
        _ receipt: ServerProviderRuntimeReceipt,
        reason: ServerProviderRuntimeAdapterSetUseRejectionReason,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(receipt.state, .unavailable, file: file, line: line)
        XCTAssertFalse(receipt.isFixtureProjected, file: file, line: line)
        XCTAssertNil(receipt.traceID, file: file, line: line)
        XCTAssertNil(receipt.providerFamily, file: file, line: line)
        XCTAssertNil(receipt.capability, file: file, line: line)
        XCTAssertNil(receipt.descriptorID, file: file, line: line)
        XCTAssertNil(receipt.costClass, file: file, line: line)
        XCTAssertNil(receipt.freshness, file: file, line: line)
        XCTAssertEqual(receipt.audit.adapterRejectionReason, .adapterSetUseNotAuthorized, file: file, line: line)
        XCTAssertTrue(receipt.statusLine.contains("not authorized"), file: file, line: line)
        XCTAssertTrue(receipt.statusLine.contains(reason.rawValue), file: file, line: line)
    }

    private func assertManifestUnauthorizedAdapterSetReceipt(
        _ receipt: ServerProviderRuntimeReceipt,
        reason: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(receipt.state, .unavailable, file: file, line: line)
        XCTAssertFalse(receipt.isFixtureProjected, file: file, line: line)
        XCTAssertNil(receipt.traceID, file: file, line: line)
        XCTAssertNil(receipt.providerFamily, file: file, line: line)
        XCTAssertNil(receipt.capability, file: file, line: line)
        XCTAssertNil(receipt.descriptorID, file: file, line: line)
        XCTAssertNil(receipt.costClass, file: file, line: line)
        XCTAssertNil(receipt.freshness, file: file, line: line)
        XCTAssertEqual(receipt.audit.adapterRejectionReason, .adapterSetUseNotAuthorized, file: file, line: line)
        XCTAssertTrue(receipt.statusLine.contains("not authorized"), file: file, line: line)
        XCTAssertTrue(receipt.statusLine.contains(reason), file: file, line: line)
    }

    private func syntheticRuntimeLookup(
        id: String,
        readiness: ServerProviderExecutionReadinessDecision,
        providerFamily: ProviderFamily,
        capability: ProviderCapability,
        costClass: ProviderCostClass
    ) -> ServerProviderRuntimeLookupResult {
        ServerProviderRuntimeLookupResult(
            id: id,
            state: .descriptorAvailable,
            descriptor: ServerProviderRuntimeDescriptor(
                id: "runtime-\(providerFamily.rawValue)-a70",
                providerFamily: providerFamily,
                displayName: "A70 \(providerFamily.rawValue)",
                supportedCapabilities: [capability],
                requiredMembershipTier: .free,
                costClass: costClass,
                requiresSourcePolicy: false,
                requiresRobotsAllow: false,
                requiresConfirmation: false,
                requiresExperimentalEnablement: false
            ),
            readinessDecision: readiness,
            statusLine: "Synthetic runtime descriptor for A70 authorization."
        )
    }

    private func syntheticServerReadyDecision(
        traceID: String,
        providerFamily: ProviderFamily,
        capability: ProviderCapability,
        costClass: ProviderCostClass
    ) -> ServerProviderExecutionReadinessDecision {
        let envelope = ServerProviderEnvelope(
            traceID: traceID,
            capability: capability,
            providerFamily: providerFamily,
            privacyClass: .general,
            membershipTier: .pro,
            costClass: costClass,
            freshness: .livePreferred
        )
        let validation = ServerProviderEnvelopeValidator.validate(envelope)

        return ServerProviderExecutionReadinessDecision(
            id: "server-provider-execution-\(traceID)",
            state: .serverReady,
            statusLine: "Synthetic server-ready decision for pipeline adapter audit.",
            sendReadyEnvelope: envelope,
            providerFamily: providerFamily,
            capability: capability,
            privacyClass: envelope.privacyClass,
            membershipTier: envelope.membershipTier,
            costClass: envelope.costClass,
            freshness: envelope.freshness,
            sourcePolicy: envelope.sourcePolicy,
            confirmationState: envelope.confirmationState,
            factoryRejectionReason: nil,
            validatorDenialReason: validation.denialReason,
            validation: validation,
            audit: validation.audit
        )
    }
}

private struct TrapServerProviderRuntimeAdapter: ServerProviderRuntimeAdapter {
    let providerFamily: ProviderFamily

    func resolve(
        _ boundary: ServerProviderRuntimeDispatchBoundary
    ) -> ServerProviderRuntimeAdapterResult {
        XCTFail("Authorized pipeline handoff must not resolve unauthorized injected adapters.")
        return FixtureServerProviderRuntimeAdapter(providerFamily: providerFamily)
            .resolve(boundary)
    }
}

private struct MarkerServerProviderRuntimeAdapter: ServerProviderRuntimeAdapter {
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
            sourcePolicy: result.sourcePolicy,
            confirmationState: result.confirmationState,
            audit: result.audit
        )
    }
}
