//
//  ServerProviderRuntimeAdapterSetReadinessValidationTests.swift
//  kAirTests
//
//  A68 adapter-set readiness validation tests: value-only, no resolve calls.
//

import XCTest
@testable import kAir

final class ServerProviderRuntimeAdapterSetReadinessValidationTests: XCTestCase {

    func test_readyRemoteAdapterSetValidatesWithoutCallingResolve() {
        let adapterSet = ServerProviderRuntimeAdapterSet(
            adapters: [
                ResolveTrapServerProviderRuntimeAdapter(providerFamily: .googleMaps),
                ResolveTrapServerProviderRuntimeAdapter(providerFamily: .gaode),
                ResolveTrapServerProviderRuntimeAdapter(providerFamily: .searchAPI),
            ]
        )

        let validation = ServerProviderRuntimeAdapterSetReadinessValidator.validate(
            adapterSet,
            decisionsByProviderFamily: readyDecisionsByFamily()
        )

        XCTAssertTrue(validation.isAccepted)
        XCTAssertEqual(validation.state, .accepted)
        XCTAssertEqual(validation.registeredProviderFamilies, [.gaode, .googleMaps, .searchAPI])
        XCTAssertEqual(validation.acceptedProviderFamilies, [.gaode, .googleMaps, .searchAPI])
        XCTAssertTrue(validation.rejectedProviderFamilies.isEmpty)
    }

    func test_missingRejectedLocalAndCacheFamiliesUseDeterministicReasons() {
        let adapterSet = ServerProviderRuntimeAdapterSet(
            adapters: [
                ResolveTrapServerProviderRuntimeAdapter(providerFamily: .appleLocal),
                ResolveTrapServerProviderRuntimeAdapter(providerFamily: .searchAPI),
                ResolveTrapServerProviderRuntimeAdapter(providerFamily: .crawler),
                ResolveTrapServerProviderRuntimeAdapter(providerFamily: .cache),
            ]
        )
        let decisions = [
            ProviderFamily.appleLocal: installationDecision(for: .appleLocal),
            .crawler: ServerProviderRuntimeAdapterInstallationGate.decision(
                for: .crawler,
                reportsByProviderFamily: [
                    .crawler: ServerProviderRuntimeAdapterReadinessMatrix.report(for: .crawler),
                ]
            ),
            .cache: installationDecision(for: .cache),
        ]

        let validation = ServerProviderRuntimeAdapterSetReadinessValidator.validate(
            adapterSet,
            decisionsByProviderFamily: decisions
        )

        XCTAssertFalse(validation.isAccepted)
        XCTAssertEqual(validation.state, .rejected)
        XCTAssertEqual(validation.registeredProviderFamilies, [.appleLocal, .searchAPI, .crawler, .cache])
        XCTAssertTrue(validation.acceptedProviderFamilies.isEmpty)
        XCTAssertEqual(validation.rejectedProviderFamilies.map(\.providerFamily), [
            .appleLocal,
            .searchAPI,
            .crawler,
            .cache,
        ])
        XCTAssertEqual(validation.rejectedProviderFamilies.map(\.reason), [
            .localNoServerAdapter,
            .missingInstallationDecision,
            .installationDecisionRejected,
            .localNoServerAdapter,
        ])
        XCTAssertEqual(
            validation.rejectedProviderFamilies.first { $0.providerFamily == .crawler }?.decisionRejection,
            .readinessMissingRequiredGates
        )
    }

    func test_mismatchedDecisionFamilyIsRejectedForRegisteredFamily() throws {
        let adapterSet = ServerProviderRuntimeAdapterSet(
            adapters: [
                ResolveTrapServerProviderRuntimeAdapter(providerFamily: .googleMaps),
            ]
        )
        let searchDecision = installationDecision(for: .searchAPI)

        let validation = ServerProviderRuntimeAdapterSetReadinessValidator.validate(
            adapterSet,
            decisionsByProviderFamily: [
                .googleMaps: searchDecision,
            ]
        )

        XCTAssertFalse(validation.isAccepted)
        XCTAssertEqual(validation.acceptedProviderFamilies, [])
        XCTAssertEqual(validation.rejectedProviderFamilies.count, 1)
        let rejection = try XCTUnwrap(validation.rejectedProviderFamilies.first)
        XCTAssertEqual(rejection.providerFamily, .googleMaps)
        XCTAssertEqual(rejection.reason, .installationDecisionFamilyMismatch)
        XCTAssertEqual(rejection.decisionProviderFamily, .searchAPI)
        XCTAssertEqual(rejection.decisionState, .installable)
    }

    func test_duplicateAdaptersRemainDeterministicThroughSetFirstFamilyBehavior() {
        let adapterSet = ServerProviderRuntimeAdapterSet(
            adapters: [
                ResolveTrapServerProviderRuntimeAdapter(providerFamily: .searchAPI),
                ResolveTrapServerProviderRuntimeAdapter(providerFamily: .searchAPI),
                ResolveTrapServerProviderRuntimeAdapter(providerFamily: .googleMaps),
            ]
        )

        let validation = ServerProviderRuntimeAdapterSetReadinessValidator.validate(
            adapterSet,
            decisionsByProviderFamily: readyDecisionsByFamily()
        )

        XCTAssertEqual(adapterSet.registeredProviderFamilies, [.googleMaps, .searchAPI])
        XCTAssertEqual(validation.registeredProviderFamilies, [.googleMaps, .searchAPI])
        XCTAssertEqual(validation.acceptedProviderFamilies, [.googleMaps, .searchAPI])
        XCTAssertTrue(validation.rejectedProviderFamilies.isEmpty)
    }

    func test_encodedValidationResultsDoNotExposeSensitiveRuntimeFields() throws {
        let adapterSet = ServerProviderRuntimeAdapterSet(
            adapters: [
                ResolveTrapServerProviderRuntimeAdapter(providerFamily: .googleMaps),
                ResolveTrapServerProviderRuntimeAdapter(providerFamily: .mcp),
            ]
        )
        let validation = ServerProviderRuntimeAdapterSetReadinessValidator.validate(
            adapterSet,
            decisionsByProviderFamily: readyDecisionsByFamily()
        )

        let data = try JSONEncoder().encode(validation)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        let lowercased = json.lowercased()
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
            "mer" + "chant",
            "pay" + "ment",
            "book" + "ing",
            "ord" + "er",
        ]

        for fragment in forbiddenFragments {
            XCTAssertFalse(lowercased.contains(fragment), "Unexpected encoded field: \(fragment)")
        }
    }

    private func readyDecisionsByFamily() -> [ProviderFamily: ServerProviderRuntimeAdapterInstallationDecision] {
        Dictionary(
            uniqueKeysWithValues: ProviderFamily.allCases.map { family in
                (family, installationDecision(for: family))
            }
        )
    }

    private func installationDecision(
        for providerFamily: ProviderFamily
    ) -> ServerProviderRuntimeAdapterInstallationDecision {
        let report = ServerProviderRuntimeAdapterReadinessMatrix.report(for: providerFamily)
        let readyReport = ServerProviderRuntimeAdapterReadinessMatrix.report(
            for: providerFamily,
            satisfiedGates: report.requiredGates
        )
        return ServerProviderRuntimeAdapterInstallationGate.decision(
            for: providerFamily,
            reportsByProviderFamily: [
                providerFamily: readyReport,
            ]
        )
    }
}

private struct ResolveTrapServerProviderRuntimeAdapter: ServerProviderRuntimeAdapter {
    let providerFamily: ProviderFamily

    nonisolated func resolve(
        _ boundary: ServerProviderRuntimeDispatchBoundary
    ) -> ServerProviderRuntimeAdapterResult {
        XCTFail("Adapter set readiness validation must not call resolve(_:).")
        return FixtureServerProviderRuntimeAdapter(providerFamily: providerFamily)
            .resolve(boundary)
    }
}
