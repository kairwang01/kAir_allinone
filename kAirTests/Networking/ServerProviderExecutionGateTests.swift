//
//  ServerProviderExecutionGateTests.swift
//  kAirTests
//
//  A16 final readiness gate: pure decisions before any provider runtime.
//

import XCTest
@testable import kAir

final class ServerProviderExecutionGateTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_200_000)

    func test_localAppleAndCacheRemainLocalOnlyAndNeverExposeSendReadyEnvelope() {
        for family in [ProviderFamily.appleLocal, .cache] {
            let result = executableResult(
                traceID: "a16-local-\(family.rawValue)",
                providerFamily: family,
                capability: .routePlanning,
                costClass: .freeLocal,
                freshness: .cachedOK
            )

            let decision = ServerProviderExecutionGate.evaluate(result)

            XCTAssertEqual(decision.state, .localOnly)
            XCTAssertFalse(decision.isServerReady)
            XCTAssertNil(decision.sendReadyEnvelope)
            XCTAssertEqual(decision.providerFamily, family)
            XCTAssertEqual(decision.costClass, .freeLocal)
            XCTAssertTrue(decision.statusLine.contains("Local-only"))
            XCTAssertTrue(decision.statusLine.contains("No server transport will run"))
        }
    }

    func test_googleGaodeAndSearchBecomeServerReadyOnlyWhenFactoryExecutable() throws {
        let googleRequest = ProviderRequest(
            traceID: "a16-google",
            capability: .localServiceSearch,
            region: .northAmerica,
            membershipTier: .pro,
            preferredProvider: .googleMaps,
            meteredProviderEntitlements: [.googleMaps],
            freshness: .liveRequired
        )
        let googleSelection = ProviderRoutingPolicy.select(for: googleRequest)
        let googleBlocked = ServerProviderEnvelopeFactory.makeEnvelope(
            for: googleRequest,
            selection: googleSelection,
            quotaSnapshot: ServerProviderQuotaSnapshot(
                allowedProviderFamilies: [.googleMaps],
                entitledProviderFamilies: [.googleMaps]
            )
        )
        let googleBlockedDecision = ServerProviderExecutionGate.evaluate(googleBlocked)
        XCTAssertEqual(googleBlockedDecision.state, .blocked)
        XCTAssertFalse(googleBlockedDecision.isServerReady)
        XCTAssertEqual(googleBlockedDecision.factoryRejectionReason, .meteredEligibilityMissing(.googleMaps))

        let googleAllowed = ServerProviderEnvelopeFactory.makeEnvelope(
            for: googleRequest,
            selection: googleSelection,
            quotaSnapshot: ServerProviderQuotaSnapshot(
                allowedProviderFamilies: [.googleMaps],
                entitledProviderFamilies: [.googleMaps],
                meteredEligibleProviderFamilies: [.googleMaps]
            )
        )
        assertServerReady(
            ServerProviderExecutionGate.evaluate(googleAllowed),
            family: .googleMaps,
            costClass: .meteredPremium
        )

        let gaodeRequest = ProviderRequest(
            traceID: "a16-gaode",
            capability: .localServiceSearch,
            region: .china,
            membershipTier: .plus,
            preferredProvider: .gaode,
            freshness: .livePreferred
        )
        let gaodeAllowed = ServerProviderEnvelopeFactory.makeEnvelope(
            for: gaodeRequest,
            selection: ProviderRoutingPolicy.select(for: gaodeRequest),
            quotaSnapshot: ServerProviderQuotaSnapshot(
                allowedProviderFamilies: [.gaode],
                entitledProviderFamilies: [.gaode],
                remainingIncludedQuota: [.gaode: 2]
            )
        )
        assertServerReady(
            ServerProviderExecutionGate.evaluate(gaodeAllowed),
            family: .gaode,
            costClass: .includedQuota
        )

        let search = try resolvedSearchAPI()
        let searchAllowed = ServerProviderEnvelopeFactory.makeEnvelope(
            for: search.request,
            decision: search.decision,
            quotaSnapshot: ServerProviderQuotaSnapshot(
                allowedProviderFamilies: [.searchAPI],
                entitledProviderFamilies: [.searchAPI],
                meteredEligibleProviderFamilies: [.searchAPI]
            )
        )
        let searchDecision = ServerProviderExecutionGate.evaluate(searchAllowed)
        assertServerReady(searchDecision, family: .searchAPI, costClass: .meteredPremium)
        XCTAssertEqual(searchDecision.sourcePolicy?.sourceHost, "example.com")
    }

    func test_healthPrivateRemotePrivacyBlockIsBlockedAndPreserved() throws {
        let envelope = ServerProviderEnvelope(
            traceID: "a16-health",
            capability: .placeSearch,
            providerFamily: .googleMaps,
            privacyClass: .health,
            membershipTier: .pro,
            costClass: .meteredPremium,
            freshness: .livePreferred,
            meteredProviderEntitlements: [.googleMaps]
        )
        let validation = ServerProviderEnvelopeValidator.validate(envelope)
        let result = ServerProviderEnvelopeFactoryResult.blocked(
            .validatorRejected(try XCTUnwrap(validation.denialReason)),
            validation: validation
        )

        let decision = ServerProviderExecutionGate.evaluate(result)

        XCTAssertEqual(decision.state, .blocked)
        XCTAssertFalse(decision.isServerReady)
        XCTAssertNil(decision.sendReadyEnvelope)
        XCTAssertEqual(decision.providerFamily, .googleMaps)
        XCTAssertEqual(decision.privacyClass, .health)
        XCTAssertEqual(decision.validatorDenialReason, .privacyBlocked)
        XCTAssertEqual(decision.audit?.trace.costClass, .blockedByPrivacy)
        XCTAssertTrue(decision.statusLine.contains("privacy policy blocks remote routing"))
    }

    func test_crawlerSourceAndRobotsBlocksRemainDistinguishable() throws {
        let robotsBlocked = blockedFromEnvelope(
            remoteEnvelope(
                traceID: "a16-crawler-robots",
                providerFamily: .crawler,
                capability: .crawlerFetch,
                membershipTier: .pro,
                costClass: .meteredPremium,
                sourcePolicy: ServerSourcePolicy(
                    sourceState: .passed,
                    robotsState: .disallowed,
                    attributionRequired: true,
                    sourceHost: "public.example.com"
                ),
                entitlements: [.crawler],
                enabledExperimentalProviders: [.crawler]
            )
        )
        let robotsDecision = ServerProviderExecutionGate.evaluate(robotsBlocked)
        XCTAssertEqual(robotsDecision.state, .blocked)
        XCTAssertEqual(robotsDecision.validatorDenialReason, .crawlerRobotsBlocked)
        XCTAssertEqual(robotsDecision.sourcePolicy?.robotsState, .disallowed)
        XCTAssertTrue(robotsDecision.statusLine.contains("crawler robots policy is blocked"))

        let sourceBlocked = blockedFromEnvelope(
            remoteEnvelope(
                traceID: "a16-crawler-source",
                providerFamily: .crawler,
                capability: .crawlerFetch,
                membershipTier: .pro,
                costClass: .meteredPremium,
                sourcePolicy: ServerSourcePolicy(
                    sourceState: .unknown,
                    robotsState: .allowed,
                    attributionRequired: true,
                    sourceHost: "unknown.example.com"
                ),
                entitlements: [.crawler],
                enabledExperimentalProviders: [.crawler]
            )
        )
        let sourceDecision = ServerProviderExecutionGate.evaluate(sourceBlocked)
        XCTAssertEqual(sourceDecision.state, .blocked)
        XCTAssertEqual(sourceDecision.validatorDenialReason, .crawlerSourceBlocked)
        XCTAssertEqual(sourceDecision.sourcePolicy?.sourceState, .unknown)
        XCTAssertTrue(sourceDecision.statusLine.contains("crawler source policy has not passed"))
    }

    func test_mcpDisabledAndConfirmationRequiredRemainDistinguishable() throws {
        let disabled = blockedFromEnvelope(
            remoteEnvelope(
                traceID: "a16-mcp-disabled",
                providerFamily: .mcp,
                capability: .mcpTool,
                membershipTier: .pro,
                costClass: .includedQuota,
                entitlements: [.mcp]
            )
        )
        let disabledDecision = ServerProviderExecutionGate.evaluate(disabled)
        XCTAssertEqual(disabledDecision.state, .blocked)
        XCTAssertEqual(disabledDecision.validatorDenialReason, .mcpDisabled)
        XCTAssertTrue(disabledDecision.statusLine.contains("MCP is disabled by default"))

        let confirmation = blockedFromEnvelope(
            remoteEnvelope(
                traceID: "a16-mcp-confirmation",
                providerFamily: .mcp,
                capability: .mcpTool,
                membershipTier: .pro,
                costClass: .includedQuota,
                confirmationState: .requiredMissing,
                entitlements: [.mcp],
                enabledExperimentalProviders: [.mcp]
            )
        )
        let confirmationDecision = ServerProviderExecutionGate.evaluate(confirmation)
        XCTAssertEqual(confirmationDecision.state, .confirmationRequired)
        XCTAssertEqual(confirmationDecision.validatorDenialReason, .confirmationRequired)
        XCTAssertNil(confirmationDecision.sendReadyEnvelope)
        XCTAssertTrue(confirmationDecision.statusLine.contains("Confirmation is required"))

        let missingConfirmationDecision = ServerProviderExecutionGate.evaluate(
            .blocked(.confirmationMissing)
        )
        XCTAssertEqual(missingConfirmationDecision.state, .confirmationRequired)
        XCTAssertEqual(missingConfirmationDecision.factoryRejectionReason, .confirmationMissing)
    }

    func test_factoryBlockedReasonsRemainDistinguishable() {
        let cases: [(ServerProviderEnvelopeFactoryRejectionReason, String)] = [
            (.providerNotAllowed(.googleMaps), "Google Maps is not allowed"),
            (.entitlementMissing(.searchAPI), "Search API entitlement is missing"),
            (.includedQuotaExhausted(.gaode), "Gaode included quota is exhausted"),
            (.sourcePolicyInsufficient, "source policy metadata is insufficient"),
        ]

        for (reason, expectedCopy) in cases {
            let decision = ServerProviderExecutionGate.evaluate(.blocked(reason))

            XCTAssertEqual(decision.state, .blocked)
            XCTAssertFalse(decision.isServerReady)
            XCTAssertNil(decision.sendReadyEnvelope)
            XCTAssertEqual(decision.factoryRejectionReason, reason)
            XCTAssertTrue(decision.statusLine.contains(expectedCopy))
        }
    }

    func test_readinessCopyDoesNotUseCompletedOrActionDoneWording() throws {
        let decisions = [
            ServerProviderExecutionGate.evaluate(
                executableResult(
                    traceID: "a16-copy-local",
                    providerFamily: .appleLocal,
                    capability: .routePlanning,
                    costClass: .freeLocal,
                    freshness: .cachedOK
                )
            ),
            ServerProviderExecutionGate.evaluate(
                executableResult(
                    traceID: "a16-copy-search",
                    providerFamily: .searchAPI,
                    capability: .webSearch,
                    costClass: .meteredPremium,
                    freshness: .livePreferred,
                    sourcePolicy: ServerSourcePolicy(
                        sourceState: .passed,
                        robotsState: .notApplicable,
                        attributionRequired: true,
                        sourceHost: "example.com"
                    ),
                    entitlements: [.searchAPI]
                )
            ),
            ServerProviderExecutionGate.evaluate(.blocked(.providerDisabled(.crawler))),
            ServerProviderExecutionGate.evaluate(.blocked(.confirmationMissing)),
        ]

        let text = decisions
            .map(\.statusLine)
            .joined(separator: "\n")
            .lowercased()

        for forbidden in ["completed", "complete", "done", "called", "booked", "ordered", "paid", "purchased"] {
            XCTAssertFalse(text.contains(forbidden), "Unexpected wording: \(forbidden)")
        }
    }

    private func assertServerReady(
        _ decision: ServerProviderExecutionReadinessDecision,
        family: ProviderFamily,
        costClass: ProviderCostClass,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(decision.state, .serverReady, file: file, line: line)
        XCTAssertTrue(decision.isServerReady, file: file, line: line)
        XCTAssertEqual(decision.sendReadyEnvelope?.providerFamily, family, file: file, line: line)
        XCTAssertEqual(decision.providerFamily, family, file: file, line: line)
        XCTAssertEqual(decision.costClass, costClass, file: file, line: line)
        XCTAssertNil(decision.validatorDenialReason, file: file, line: line)
        XCTAssertTrue(decision.statusLine.contains("ready after policy checks"), file: file, line: line)
    }

    private func resolvedSearchAPI() throws -> (
        request: SearchProviderRequest,
        decision: SearchProviderDecision
    ) {
        let draft = SearchResultDraft(
            sourceURL: try publicURL(host: "example.com", path: "/ramen"),
            title: "Late-night ramen",
            snippet: "Open public listing with hours.",
            attribution: "example.com",
            confidence: 0.82
        )
        let request = SearchProviderRequest(
            traceID: "a16-search",
            query: "late night ramen",
            membershipTier: .plus,
            preferredProvider: .searchAPI,
            meteredProviderEntitlements: [.searchAPI],
            freshness: .livePreferred,
            resultDraft: draft,
            now: now
        )
        let decision = SearchProviderPolicy.evaluate(request)
        XCTAssertTrue(decision.isResolved)
        XCTAssertEqual(decision.selectedProvider?.family, .searchAPI)
        return (request, decision)
    }

    private func blockedFromEnvelope(
        _ envelope: ServerProviderEnvelope,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> ServerProviderEnvelopeFactoryResult {
        let validation = ServerProviderEnvelopeValidator.validate(envelope)
        XCTAssertFalse(validation.isAllowed, file: file, line: line)
        let denialReason = validation.denialReason ?? .unsupportedCapability
        return .blocked(.validatorRejected(denialReason), validation: validation)
    }

    private func executableResult(
        traceID: String,
        providerFamily: ProviderFamily,
        capability: ProviderCapability,
        costClass: ProviderCostClass,
        freshness: ProviderFreshness,
        privacyClass: ProviderPrivacyClass = .general,
        membershipTier: MembershipTier = .pro,
        sourcePolicy: ServerSourcePolicy? = nil,
        confirmationState: ServerConfirmationState = .notRequired,
        entitlements: Set<ProviderFamily> = [],
        enabledExperimentalProviders: Set<ProviderFamily> = []
    ) -> ServerProviderEnvelopeFactoryResult {
        let envelope = remoteEnvelope(
            traceID: traceID,
            providerFamily: providerFamily,
            capability: capability,
            privacyClass: privacyClass,
            membershipTier: membershipTier,
            costClass: costClass,
            freshness: freshness,
            sourcePolicy: sourcePolicy,
            confirmationState: confirmationState,
            entitlements: entitlements,
            enabledExperimentalProviders: enabledExperimentalProviders
        )
        let validation = ServerProviderEnvelopeValidator.validate(envelope)
        XCTAssertTrue(validation.isAllowed)
        return .executable(envelope: envelope, validation: validation)
    }

    private func remoteEnvelope(
        traceID: String,
        providerFamily: ProviderFamily,
        capability: ProviderCapability,
        privacyClass: ProviderPrivacyClass = .general,
        membershipTier: MembershipTier,
        costClass: ProviderCostClass,
        freshness: ProviderFreshness = .livePreferred,
        sourcePolicy: ServerSourcePolicy? = nil,
        confirmationState: ServerConfirmationState = .notRequired,
        entitlements: Set<ProviderFamily> = [],
        enabledExperimentalProviders: Set<ProviderFamily> = []
    ) -> ServerProviderEnvelope {
        ServerProviderEnvelope(
            traceID: traceID,
            capability: capability,
            providerFamily: providerFamily,
            privacyClass: privacyClass,
            membershipTier: membershipTier,
            costClass: costClass,
            freshness: freshness,
            sourcePolicy: sourcePolicy ?? ServerSourcePolicy(sourceState: .notApplicable),
            confirmationState: confirmationState,
            meteredProviderEntitlements: entitlements,
            enabledExperimentalProviders: enabledExperimentalProviders
        )
    }

    private func publicURL(host: String, path: String) throws -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        return try XCTUnwrap(components.url)
    }
}
