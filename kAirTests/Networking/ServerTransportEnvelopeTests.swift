//
//  ServerTransportEnvelopeTests.swift
//  kAirTests
//
//  A11 server/provider envelope contract: pure values, privacy/cost/source
//  gates, fixture transport only.
//

import XCTest
@testable import kAir

final class ServerTransportEnvelopeTests: XCTestCase {

    func test_localEnvelope_isAllowedWithoutRemoteEntitlement() {
        let envelope = ServerProviderEnvelope(
            traceID: "server-local",
            capability: .routePlanning,
            providerFamily: .appleLocal,
            membershipTier: .free,
            costClass: .freeLocal
        )

        let response = MockServerTransport().send(envelope)

        XCTAssertTrue(response.isAccepted)
        XCTAssertEqual(response.status, .acceptedFixture)
        XCTAssertEqual(response.audit.trace.selectedProviderFamily, .appleLocal)
        XCTAssertEqual(response.audit.trace.costClass, .freeLocal)
        XCTAssertNil(response.audit.denialReason)
    }

    func test_googleGaodeAndSearch_requireEntitlementBeforeFixtureAcceptance() {
        assertRemoteEntitlementGate(
            providerFamily: .googleMaps,
            capability: .localServiceSearch,
            membershipTier: .plus,
            costClass: .meteredPremium
        )
        assertRemoteEntitlementGate(
            providerFamily: .gaode,
            capability: .localServiceSearch,
            membershipTier: .plus,
            costClass: .includedQuota
        )
        assertRemoteEntitlementGate(
            providerFamily: .searchAPI,
            capability: .webSearch,
            membershipTier: .plus,
            costClass: .meteredPremium
        )
    }

    func test_privateAndHealthContexts_blockRemoteProviderEnvelope() {
        for privacyClass in [ProviderPrivacyClass.private, .health] {
            let envelope = remoteEnvelope(
                traceID: "server-privacy-\(privacyClass.rawValue)",
                providerFamily: .googleMaps,
                capability: .placeSearch,
                privacyClass: privacyClass,
                membershipTier: .pro,
                costClass: .meteredPremium,
                entitlements: [.googleMaps]
            )

            let decision = ServerProviderEnvelopeValidator.validate(envelope)

            XCTAssertFalse(decision.isAllowed)
            XCTAssertEqual(decision.denialReason, .privacyBlocked)
            XCTAssertEqual(decision.audit.trace.costClass, .blockedByPrivacy)
            XCTAssertEqual(decision.audit.trace.failureReason, .blockedByPrivacy)
        }
    }

    func test_crawlerEnvelope_requiresRobotsAllowedAndSourcePass() {
        let robotsBlocked = remoteEnvelope(
            traceID: "server-crawler-robots",
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
        let robotsDecision = ServerProviderEnvelopeValidator.validate(robotsBlocked)

        XCTAssertFalse(robotsDecision.isAllowed)
        XCTAssertEqual(robotsDecision.denialReason, .crawlerRobotsBlocked)
        XCTAssertEqual(robotsDecision.audit.trace.failureReason, .unavailable)

        let sourceBlocked = remoteEnvelope(
            traceID: "server-crawler-source",
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
        let sourceDecision = ServerProviderEnvelopeValidator.validate(sourceBlocked)

        XCTAssertFalse(sourceDecision.isAllowed)
        XCTAssertEqual(sourceDecision.denialReason, .crawlerSourceBlocked)
    }

    func test_mcpEnvelope_isDisabledByDefault() {
        let envelope = remoteEnvelope(
            traceID: "server-mcp-default",
            providerFamily: .mcp,
            capability: .mcpTool,
            membershipTier: .pro,
            costClass: .includedQuota,
            entitlements: [.mcp]
        )

        let response = MockServerTransport().send(envelope)

        XCTAssertFalse(response.isAccepted)
        XCTAssertEqual(response.status, .blocked)
        XCTAssertEqual(response.audit.denialReason, .mcpDisabled)
        XCTAssertEqual(response.audit.trace.failureReason, .disabledByDefault)
    }

    func test_envelopeEncoding_doesNotExposeCredentialFields() throws {
        let envelope = remoteEnvelope(
            traceID: "server-encoding",
            providerFamily: .googleMaps,
            capability: .placeSearch,
            membershipTier: .pro,
            costClass: .meteredPremium,
            entitlements: [.googleMaps]
        )

        let data = try JSONEncoder().encode(envelope)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        let lowercased = json.lowercased()

        let forbiddenFragments = [
            "api" + "key",
            "api" + "_" + "key",
            "bear" + "er",
            "sec" + "ret",
            "to" + "ken",
            "creden" + "tial",
        ]
        for fragment in forbiddenFragments {
            XCTAssertFalse(lowercased.contains(fragment))
        }
    }

    private func assertRemoteEntitlementGate(
        providerFamily: ProviderFamily,
        capability: ProviderCapability,
        membershipTier: MembershipTier,
        costClass: ProviderCostClass,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let blocked = remoteEnvelope(
            traceID: "server-\(providerFamily.rawValue)-blocked",
            providerFamily: providerFamily,
            capability: capability,
            membershipTier: membershipTier,
            costClass: costClass
        )
        let blockedDecision = ServerProviderEnvelopeValidator.validate(blocked)

        XCTAssertFalse(blockedDecision.isAllowed, file: file, line: line)
        XCTAssertEqual(blockedDecision.denialReason, .missingEntitlement, file: file, line: line)
        XCTAssertEqual(blockedDecision.audit.trace.costClass, .blockedByCost, file: file, line: line)

        let allowed = remoteEnvelope(
            traceID: "server-\(providerFamily.rawValue)-allowed",
            providerFamily: providerFamily,
            capability: capability,
            membershipTier: membershipTier,
            costClass: costClass,
            entitlements: [providerFamily]
        )
        let allowedDecision = ServerProviderEnvelopeValidator.validate(allowed)

        XCTAssertTrue(allowedDecision.isAllowed, file: file, line: line)
        XCTAssertEqual(allowedDecision.audit.trace.selectedProviderFamily, providerFamily, file: file, line: line)
        XCTAssertNil(allowedDecision.denialReason, file: file, line: line)
    }

    private func remoteEnvelope(
        traceID: String,
        providerFamily: ProviderFamily,
        capability: ProviderCapability,
        privacyClass: ProviderPrivacyClass = .general,
        membershipTier: MembershipTier,
        costClass: ProviderCostClass,
        sourcePolicy: ServerSourcePolicy = .notApplicable,
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
            freshness: .livePreferred,
            sourcePolicy: sourcePolicy,
            confirmationState: confirmationState,
            meteredProviderEntitlements: entitlements,
            enabledExperimentalProviders: enabledExperimentalProviders
        )
    }
}
