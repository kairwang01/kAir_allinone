//
//  ServerProviderDryRunPresentationTests.swift
//  kAirTests
//
//  A14 provider dry-run presentation: UI-safe copy and badge metadata only.
//

import XCTest
@testable import kAir

final class ServerProviderDryRunPresentationTests: XCTestCase {

    func test_localFallbackCopy_isAdvisoryAndShowsFallbackBadge() {
        let report = ServerProviderDryRunEvaluator.evaluate(
            capabilityLabel: "Route planning",
            candidates: [
                ServerProviderDryRunCandidate(
                    id: "google-blocked",
                    displayName: "Google Maps",
                    result: .blocked(.meteredEligibilityMissing(.googleMaps))
                ),
                ServerProviderDryRunCandidate(
                    id: "apple-local",
                    displayName: "Apple Local",
                    result: executableResult(
                        traceID: "a14-local",
                        providerFamily: .appleLocal,
                        capability: .routePlanning,
                        costClass: .freeLocal,
                        freshness: .livePreferred
                    )
                ),
            ]
        )

        let presentation = ServerProviderDryRunPresentationProjector.project(report)

        XCTAssertEqual(presentation.tone, .positive)
        XCTAssertTrue(presentation.summary.contains("Apple Local"))
        XCTAssertTrue(presentation.summary.contains("No provider was contacted"))
        let fallbackRow = tryUnwrap(row(.fallbackStatus, in: presentation))
        XCTAssertEqual(fallbackRow.fallbackReason, .localFallbackAfterRemoteCostOrPrivacyBlock)
        XCTAssertTrue(fallbackRow.detail.contains("Remote cost or privacy policy blocked"))
        XCTAssertTrue(fallbackRow.badges.contains { $0.label == "Local fallback" && $0.tone == .positive })
        XCTAssertTrue(presentation.rows.allSatisfy(\.isAdvisoryOnly))
    }

    func test_includedQuotaCopy_usesPositiveCostStatus() {
        let report = ServerProviderDryRunEvaluator.evaluate(
            capabilityLabel: "Local service lookup",
            requiredFreshness: .livePreferred,
            candidates: [
                ServerProviderDryRunCandidate(
                    id: "gaode",
                    displayName: "Gaode",
                    result: executableResult(
                        traceID: "a14-gaode",
                        providerFamily: .gaode,
                        capability: .localServiceSearch,
                        costClass: .includedQuota,
                        freshness: .livePreferred,
                        entitlements: [.gaode]
                    )
                ),
            ]
        )

        let presentation = ServerProviderDryRunPresentationProjector.project(report)

        XCTAssertEqual(presentation.selectedProviderFamily, .gaode)
        let costRow = tryUnwrap(row(.costStatus, in: presentation))
        XCTAssertEqual(costRow.costClass, .includedQuota)
        XCTAssertTrue(costRow.title.contains("included quota"))
        XCTAssertTrue(costRow.detail.contains("included provider quota"))
        XCTAssertTrue(costRow.badges.contains { $0.label == "Included quota" && $0.tone == .positive })
    }

    func test_meteredPremiumCopy_usesWarningCostStatus() {
        let report = ServerProviderDryRunEvaluator.evaluate(
            capabilityLabel: "Public search",
            requiredFreshness: .livePreferred,
            candidates: [
                ServerProviderDryRunCandidate(
                    id: "search-api",
                    displayName: "Search API",
                    result: executableResult(
                        traceID: "a14-metered",
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
            ]
        )

        let presentation = ServerProviderDryRunPresentationProjector.project(report)

        XCTAssertEqual(presentation.tone, .warning)
        let costRow = tryUnwrap(row(.costStatus, in: presentation))
        XCTAssertEqual(costRow.costClass, .meteredPremium)
        XCTAssertTrue(costRow.detail.contains("premium metered allowance"))
        XCTAssertTrue(costRow.badges.contains { $0.label == "Premium metered" && $0.tone == .warning })
        let sourceRow = tryUnwrap(row(.sourceStatus, in: presentation))
        XCTAssertEqual(sourceRow.sourcePolicy?.sourceHost, "example.com")
    }

    func test_liveRequiredStaleCacheRejectionCopy_isWarning() {
        let report = ServerProviderDryRunEvaluator.evaluate(
            capabilityLabel: "Web search",
            requiredFreshness: .liveRequired,
            candidates: [
                ServerProviderDryRunCandidate(
                    id: "cache",
                    displayName: "Local Cache",
                    result: executableResult(
                        traceID: "a14-cache",
                        providerFamily: .cache,
                        capability: .webSearch,
                        costClass: .freeLocal,
                        freshness: .cachedOK
                    )
                ),
            ]
        )

        let presentation = ServerProviderDryRunPresentationProjector.project(report)

        XCTAssertEqual(presentation.tone, .warning)
        XCTAssertTrue(presentation.summary.contains("liveRequired"))
        let rejected = tryUnwrap(presentation.rows.first)
        XCTAssertEqual(rejected.fallbackReason, .freshnessRejected)
        XCTAssertTrue(rejected.title.contains("Stale cache rejected"))
        XCTAssertTrue(rejected.detail.contains("live-required"))
        XCTAssertEqual(rejected.freshness, .cachedOK)
    }

    func test_allBlockedCopy_preservesFactoryReasons() {
        let report = ServerProviderDryRunEvaluator.evaluate(
            capabilityLabel: "Public lookup",
            candidates: [
                ServerProviderDryRunCandidate(
                    id: "search-api",
                    displayName: "Search API",
                    result: .blocked(.providerNotAllowed(.searchAPI))
                ),
                ServerProviderDryRunCandidate(
                    id: "crawler",
                    displayName: "Crawler",
                    result: .blocked(.sourcePolicyInsufficient)
                ),
            ]
        )

        let presentation = ServerProviderDryRunPresentationProjector.project(report)

        XCTAssertEqual(presentation.tone, .warning)
        XCTAssertTrue(presentation.summary.contains("all provider candidates are blocked"))
        XCTAssertEqual(
            Set(presentation.rows.compactMap(\.factoryRejectionReason)),
            [.providerNotAllowed(.searchAPI), .sourcePolicyInsufficient]
        )
        XCTAssertTrue(presentation.rows.allSatisfy { $0.kind == .blockedCandidate })
    }

    func test_healthPrivateRemotePrivacyBlockCopy_isPreserved() {
        let envelope = ServerProviderEnvelope(
            traceID: "a14-health",
            capability: .placeSearch,
            providerFamily: .googleMaps,
            privacyClass: .health,
            membershipTier: .pro,
            costClass: .meteredPremium,
            freshness: .livePreferred,
            meteredProviderEntitlements: [.googleMaps]
        )
        let validation = ServerProviderEnvelopeValidator.validate(envelope)
        let report = ServerProviderDryRunEvaluator.evaluate(
            capabilityLabel: "Health place lookup",
            candidates: [
                ServerProviderDryRunCandidate(
                    id: "health-google",
                    displayName: "Google Maps",
                    result: .blocked(
                        .validatorRejected(.privacyBlocked),
                        validation: validation
                    )
                ),
            ]
        )

        let presentation = ServerProviderDryRunPresentationProjector.project(report)

        let row = tryUnwrap(presentation.rows.first)
        XCTAssertEqual(row.providerFamily, .googleMaps)
        XCTAssertEqual(row.privacyClass, .health)
        XCTAssertEqual(row.validatorDenialReason, .privacyBlocked)
        XCTAssertTrue(row.title.contains("Privacy policy blocks"))
        XCTAssertTrue(row.detail.contains("cannot leave the local policy boundary"))
        XCTAssertTrue(row.badges.contains { $0.label == "Privacy blocked" && $0.tone == .warning })
    }

    func test_copyDoesNotUseCompletedOrActionDoneWording() {
        let reports = [
            ServerProviderDryRunEvaluator.evaluate(
                capabilityLabel: "Route planning",
                candidates: [
                    ServerProviderDryRunCandidate(
                        id: "apple-local",
                        displayName: "Apple Local",
                        result: executableResult(
                            traceID: "a14-copy-local",
                            providerFamily: .appleLocal,
                            capability: .routePlanning,
                            costClass: .freeLocal,
                            freshness: .cachedOK
                        )
                    ),
                ]
            ),
            ServerProviderDryRunEvaluator.evaluate(
                capabilityLabel: "Blocked lookup",
                candidates: [
                    ServerProviderDryRunCandidate(
                        id: "mcp",
                        displayName: "MCP",
                        result: .blocked(.confirmationMissing)
                    ),
                ]
            ),
        ]

        let text = reports
            .map(ServerProviderDryRunPresentationProjector.project)
            .flatMap(allCopy)
            .joined(separator: "\n")
            .lowercased()

        for forbidden in ["completed", "complete", "done", "called", "booked", "ordered", "paid", "purchased"] {
            XCTAssertFalse(text.contains(forbidden), "Unexpected wording: \(forbidden)")
        }
    }

    private func executableResult(
        traceID: String,
        providerFamily: ProviderFamily,
        capability: ProviderCapability,
        costClass: ProviderCostClass,
        freshness: ProviderFreshness,
        privacyClass: ProviderPrivacyClass = .general,
        membershipTier: MembershipTier = .pro,
        sourcePolicy: ServerSourcePolicy = .notApplicable,
        entitlements: Set<ProviderFamily> = [],
        enabledExperimentalProviders: Set<ProviderFamily> = []
    ) -> ServerProviderEnvelopeFactoryResult {
        let envelope = ServerProviderEnvelope(
            traceID: traceID,
            capability: capability,
            providerFamily: providerFamily,
            privacyClass: privacyClass,
            membershipTier: membershipTier,
            costClass: costClass,
            freshness: freshness,
            sourcePolicy: sourcePolicy,
            meteredProviderEntitlements: entitlements,
            enabledExperimentalProviders: enabledExperimentalProviders
        )
        let validation = ServerProviderEnvelopeValidator.validate(envelope)
        XCTAssertTrue(validation.isAllowed)
        return .executable(envelope: envelope, validation: validation)
    }

    private func row(
        _ kind: ServerProviderDryRunPresentationRowKind,
        in presentation: ServerProviderDryRunPresentation
    ) -> ServerProviderDryRunPresentationRow? {
        presentation.rows.first { $0.kind == kind }
    }

    private func allCopy(
        in presentation: ServerProviderDryRunPresentation
    ) -> [String] {
        [presentation.summary]
            + presentation.rows.flatMap { row in
                [row.title, row.detail] + row.badges.map(\.label)
            }
    }

    private func tryUnwrap<T>(
        _ value: T?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> T {
        guard let value else {
            XCTFail("Expected non-nil value", file: file, line: line)
            fatalError("Expected non-nil value")
        }
        return value
    }
}

private extension ServerProviderDryRunPresentation {
    var selectedProviderFamily: ProviderFamily? {
        rows.first { $0.kind == .selectedProvider }?.providerFamily
    }
}
