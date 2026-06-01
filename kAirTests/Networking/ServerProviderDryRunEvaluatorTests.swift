//
//  ServerProviderDryRunEvaluatorTests.swift
//  kAirTests
//
//  A13 dry-run evaluation: compare factory results, preserve rejection
//  reasons, and produce an audit-only provider plan without execution.
//

import XCTest
@testable import kAir

final class ServerProviderDryRunEvaluatorTests: XCTestCase {

    func test_localFallbackWinsWhenRemoteCandidateIsCostBlocked() {
        let local = ServerProviderDryRunCandidate(
            id: "apple-local",
            displayName: "Apple Local",
            result: executableResult(
                traceID: "a13-local",
                providerFamily: .appleLocal,
                capability: .routePlanning,
                costClass: .freeLocal,
                freshness: .livePreferred
            )
        )
        let remoteBlocked = ServerProviderDryRunCandidate(
            id: "google-blocked",
            displayName: "Google Maps",
            result: .blocked(.meteredEligibilityMissing(.googleMaps))
        )

        let report = ServerProviderDryRunEvaluator.evaluate(
            capabilityLabel: "Route planning",
            candidates: [remoteBlocked, local]
        )

        XCTAssertEqual(report.status, .selected)
        XCTAssertEqual(report.selected?.providerFamily, .appleLocal)
        XCTAssertEqual(report.selected?.fallbackReason, .localFallbackAfterRemoteCostOrPrivacyBlock)
        XCTAssertEqual(report.candidates.first { $0.candidateID == "google-blocked" }?.providerFamily, .googleMaps)
        XCTAssertEqual(
            report.candidates.first { $0.candidateID == "google-blocked" }?.factoryRejectionReason,
            .meteredEligibilityMissing(.googleMaps)
        )
    }

    func test_includedQuotaProviderWinsOverMeteredPremiumWhenFreshnessMatches() {
        let gaode = ServerProviderDryRunCandidate(
            id: "gaode",
            displayName: "Gaode",
            result: executableResult(
                traceID: "a13-gaode",
                providerFamily: .gaode,
                capability: .localServiceSearch,
                costClass: .includedQuota,
                freshness: .livePreferred,
                entitlements: [.gaode]
            )
        )
        let google = ServerProviderDryRunCandidate(
            id: "google",
            displayName: "Google Maps",
            result: executableResult(
                traceID: "a13-google",
                providerFamily: .googleMaps,
                capability: .localServiceSearch,
                costClass: .meteredPremium,
                freshness: .livePreferred,
                entitlements: [.googleMaps]
            )
        )

        let report = ServerProviderDryRunEvaluator.evaluate(
            capabilityLabel: "Local service lookup",
            requiredFreshness: .livePreferred,
            candidates: [google, gaode]
        )

        XCTAssertEqual(report.selected?.providerFamily, .gaode)
        XCTAssertEqual(report.selected?.costClass, .includedQuota)
        XCTAssertEqual(report.candidates.first { $0.candidateID == "google" }?.fallbackReason, .higherCost)
    }

    func test_liveRequiredRejectsStaleCacheCandidate() {
        let staleCache = ServerProviderDryRunCandidate(
            id: "cache",
            displayName: "Local Cache",
            result: executableResult(
                traceID: "a13-cache",
                providerFamily: .cache,
                capability: .webSearch,
                costClass: .freeLocal,
                freshness: .cachedOK
            )
        )

        let report = ServerProviderDryRunEvaluator.evaluate(
            capabilityLabel: "Web search",
            requiredFreshness: .liveRequired,
            candidates: [staleCache]
        )

        XCTAssertNil(report.selected)
        XCTAssertEqual(report.status, .freshnessUnsatisfied)
        XCTAssertEqual(report.candidates.first?.fallbackReason, .freshnessRejected)
        XCTAssertEqual(report.candidates.first?.freshness, .cachedOK)
    }

    func test_allCandidatesBlockedPreservesEveryRejectionReason() {
        let notAllowed = ServerProviderDryRunCandidate(
            id: "not-allowed",
            displayName: "Search API",
            result: .blocked(.providerNotAllowed(.searchAPI))
        )
        let sourceInsufficient = ServerProviderDryRunCandidate(
            id: "source-missing",
            displayName: "Crawler",
            result: .blocked(.sourcePolicyInsufficient)
        )
        let confirmationMissing = ServerProviderDryRunCandidate(
            id: "confirmation-missing",
            displayName: "MCP",
            result: .blocked(.confirmationMissing)
        )

        let report = ServerProviderDryRunEvaluator.evaluate(
            capabilityLabel: "Public lookup",
            candidates: [notAllowed, sourceInsufficient, confirmationMissing]
        )

        XCTAssertFalse(report.hasSelection)
        XCTAssertEqual(report.status, .allCandidatesBlocked)
        XCTAssertEqual(
            Set(report.candidates.compactMap(\.factoryRejectionReason)),
            [
                .providerNotAllowed(.searchAPI),
                .sourcePolicyInsufficient,
                .confirmationMissing,
            ]
        )
        XCTAssertTrue(report.candidates.allSatisfy { $0.fallbackReason == .factoryBlocked })
    }

    func test_healthRemoteValidatorBlockIsPreservedInDryRunOutput() {
        let healthRemoteEnvelope = ServerProviderEnvelope(
            traceID: "a13-health",
            capability: .placeSearch,
            providerFamily: .googleMaps,
            privacyClass: .health,
            membershipTier: .pro,
            costClass: .meteredPremium,
            freshness: .livePreferred,
            meteredProviderEntitlements: [.googleMaps]
        )
        let validation = ServerProviderEnvelopeValidator.validate(healthRemoteEnvelope)
        let healthRemote = ServerProviderDryRunCandidate(
            id: "health-google",
            displayName: "Google Health Block",
            result: .blocked(
                .validatorRejected(.privacyBlocked),
                validation: validation
            )
        )

        let report = ServerProviderDryRunEvaluator.evaluate(
            capabilityLabel: "Health place lookup",
            candidates: [healthRemote]
        )

        XCTAssertNil(report.selected)
        XCTAssertEqual(report.status, .allCandidatesBlocked)
        XCTAssertEqual(report.candidates.first?.providerFamily, .googleMaps)
        XCTAssertEqual(report.candidates.first?.privacyClass, .health)
        XCTAssertEqual(report.candidates.first?.validatorDenialReason, .privacyBlocked)
        XCTAssertEqual(report.candidates.first?.fallbackReason, .validatorBlocked)
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
}
