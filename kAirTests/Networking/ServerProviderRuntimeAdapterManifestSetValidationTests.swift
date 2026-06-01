//
//  ServerProviderRuntimeAdapterManifestSetValidationTests.swift
//  kAirTests
//
//  A75 manifest-backed adapter-set validation tests: value-only, no resolve calls.
//

import XCTest
@testable import kAir

@MainActor
final class ServerProviderRuntimeAdapterManifestSetValidationTests: XCTestCase {

    func test_readyRemoteAdapterSetValidatesOnlyWithManifestBackedInstallableDecisions() throws {
        let adapterSet = ServerProviderRuntimeAdapterSet(
            adapters: [
                ManifestSetResolveTrapServerProviderRuntimeAdapter(providerFamily: .googleMaps),
                ManifestSetResolveTrapServerProviderRuntimeAdapter(providerFamily: .gaode),
                ManifestSetResolveTrapServerProviderRuntimeAdapter(providerFamily: .searchAPI),
            ]
        )

        let validation = ServerProviderRuntimeAdapterManifestSetValidator.validate(
            adapterSet,
            decisionsByProviderFamily: manifestReadyDecisionsByFamily()
        )

        XCTAssertTrue(validation.isAccepted)
        XCTAssertEqual(validation.state, .accepted)
        XCTAssertEqual(validation.registeredProviderFamilies, [.gaode, .googleMaps, .searchAPI])
        XCTAssertEqual(validation.acceptedProviderFamilies, [.gaode, .googleMaps, .searchAPI])
        XCTAssertTrue(validation.rejectedProviderFamilies.isEmpty)
        XCTAssertEqual(validation.readinessValidation?.state, .accepted)
        XCTAssertEqual(validation.readinessValidation?.acceptedProviderFamilies, validation.acceptedProviderFamilies)
    }

    func test_missingLocalNonInstallableFamilyMismatchAndMissingUnderlyingDecisionRejectDistinctly() throws {
        let adapterSet = ServerProviderRuntimeAdapterSet(
            adapters: [
                ManifestSetResolveTrapServerProviderRuntimeAdapter(providerFamily: .appleLocal),
                ManifestSetResolveTrapServerProviderRuntimeAdapter(providerFamily: .searchAPI),
                ManifestSetResolveTrapServerProviderRuntimeAdapter(providerFamily: .crawler),
                ManifestSetResolveTrapServerProviderRuntimeAdapter(providerFamily: .googleMaps),
                ManifestSetResolveTrapServerProviderRuntimeAdapter(providerFamily: .mcp),
                ManifestSetResolveTrapServerProviderRuntimeAdapter(providerFamily: .cache),
            ]
        )
        var decisions = manifestReadyDecisionsByFamily()
        decisions[.searchAPI] = nil
        decisions[.crawler] = nonReadyManifestDecision(for: .crawler)
        decisions[.googleMaps] = try XCTUnwrap(decisions[.gaode])
        decisions[.mcp] = manifestDecision(
            try XCTUnwrap(decisions[.mcp]),
            installationDecision: nil
        )

        let validation = ServerProviderRuntimeAdapterManifestSetValidator.validate(
            adapterSet,
            decisionsByProviderFamily: decisions
        )

        XCTAssertFalse(validation.isAccepted)
        XCTAssertEqual(validation.state, .rejected)
        XCTAssertNil(validation.readinessValidation)
        XCTAssertEqual(validation.registeredProviderFamilies, [
            .appleLocal,
            .googleMaps,
            .searchAPI,
            .crawler,
            .mcp,
            .cache,
        ])
        XCTAssertEqual(validation.acceptedProviderFamilies, [])
        XCTAssertEqual(validation.rejectedProviderFamilies.map(\.providerFamily), [
            .appleLocal,
            .googleMaps,
            .searchAPI,
            .crawler,
            .mcp,
            .cache,
        ])
        XCTAssertEqual(validation.rejectedProviderFamilies.map(\.reason), [
            .localNoServerAdapter,
            .manifestInstallationFamilyMismatch,
            .missingManifestInstallationDecision,
            .manifestInstallationRejected,
            .missingInstallationDecision,
            .localNoServerAdapter,
        ])
        XCTAssertEqual(
            validation.rejectedProviderFamilies.first { $0.providerFamily == .crawler }?.manifestDecisionRejection,
            .installationRejected
        )
        XCTAssertEqual(
            validation.rejectedProviderFamilies.first { $0.providerFamily == .googleMaps }?.manifestDecisionProviderFamily,
            .gaode
        )
    }

    func test_acceptedPathsPreserveReadinessValidationIncludingDuplicateFirstFamilyBehavior() {
        let adapterSet = ServerProviderRuntimeAdapterSet(
            adapters: [
                ManifestSetResolveTrapServerProviderRuntimeAdapter(providerFamily: .searchAPI),
                ManifestSetResolveTrapServerProviderRuntimeAdapter(providerFamily: .searchAPI),
                ManifestSetResolveTrapServerProviderRuntimeAdapter(providerFamily: .googleMaps),
            ]
        )

        let validation = ServerProviderRuntimeAdapterManifestSetValidator.validate(
            adapterSet,
            decisionsByProviderFamily: manifestReadyDecisionsByFamily()
        )

        XCTAssertTrue(validation.isAccepted)
        XCTAssertEqual(adapterSet.registeredProviderFamilies, [.googleMaps, .searchAPI])
        XCTAssertEqual(validation.registeredProviderFamilies, [.googleMaps, .searchAPI])
        XCTAssertEqual(validation.acceptedProviderFamilies, [.googleMaps, .searchAPI])
        XCTAssertEqual(validation.readinessValidation?.registeredProviderFamilies, [.googleMaps, .searchAPI])
        XCTAssertEqual(validation.readinessValidation?.acceptedProviderFamilies, [.googleMaps, .searchAPI])
        XCTAssertTrue(validation.readinessValidation?.rejectedProviderFamilies.isEmpty == true)
    }

    func test_readinessValidationRejectionOutputIsPreservedAfterManifestChecks() throws {
        let adapterSet = ServerProviderRuntimeAdapterSet(
            adapters: [
                ManifestSetResolveTrapServerProviderRuntimeAdapter(providerFamily: .googleMaps),
            ]
        )
        var decisions = manifestReadyDecisionsByFamily()
        let searchInstallation = try XCTUnwrap(decisions[.searchAPI]?.installationDecision)
        decisions[.googleMaps] = manifestDecision(
            try XCTUnwrap(decisions[.googleMaps]),
            installationDecision: searchInstallation
        )

        let validation = ServerProviderRuntimeAdapterManifestSetValidator.validate(
            adapterSet,
            decisionsByProviderFamily: decisions
        )

        XCTAssertFalse(validation.isAccepted)
        XCTAssertEqual(validation.state, .rejected)
        XCTAssertEqual(validation.acceptedProviderFamilies, [])
        XCTAssertEqual(validation.rejectedProviderFamilies.count, 1)
        XCTAssertEqual(validation.rejectedProviderFamilies.first?.reason, .readinessValidationRejected)
        XCTAssertEqual(validation.rejectedProviderFamilies.first?.installationDecisionProviderFamily, .searchAPI)
        XCTAssertEqual(validation.readinessValidation?.state, .rejected)
        XCTAssertEqual(
            validation.readinessValidation?.rejectedProviderFamilies.first?.reason,
            .installationDecisionFamilyMismatch
        )
    }

    func test_rejectedPathsNeverCallResolve() {
        let adapterSet = ServerProviderRuntimeAdapterSet(
            adapters: [
                ManifestSetResolveTrapServerProviderRuntimeAdapter(providerFamily: .crawler),
            ]
        )

        let validation = ServerProviderRuntimeAdapterManifestSetValidator.validate(
            adapterSet,
            decisionsByProviderFamily: [:]
        )

        XCTAssertEqual(validation.state, .rejected)
        XCTAssertEqual(validation.rejectedProviderFamilies.first?.reason, .missingManifestInstallationDecision)
    }

    func test_encodingDescriptionAndStatusTextDoNotExposeSensitiveRuntimeFields() throws {
        let acceptedSet = ServerProviderRuntimeAdapterSet(
            adapters: [
                ManifestSetResolveTrapServerProviderRuntimeAdapter(providerFamily: .googleMaps),
                ManifestSetResolveTrapServerProviderRuntimeAdapter(providerFamily: .mcp),
            ]
        )
        let rejectedSet = ServerProviderRuntimeAdapterSet(
            adapters: [
                ManifestSetResolveTrapServerProviderRuntimeAdapter(providerFamily: .cache),
                ManifestSetResolveTrapServerProviderRuntimeAdapter(providerFamily: .crawler),
            ]
        )
        let accepted = ServerProviderRuntimeAdapterManifestSetValidator.validate(
            acceptedSet,
            decisionsByProviderFamily: manifestReadyDecisionsByFamily()
        )
        let rejected = ServerProviderRuntimeAdapterManifestSetValidator.validate(
            rejectedSet,
            decisionsByProviderFamily: [:]
        )
        let data = try JSONEncoder().encode([accepted, rejected])
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        let text = [
            json,
            accepted.statusLine,
            rejected.statusLine,
            String(describing: accepted),
            String(describing: rejected),
        ]
        .joined(separator: "\n")
        .lowercased()

        for fragment in forbiddenSensitiveFragments() {
            XCTAssertFalse(text.contains(fragment), "Unexpected manifest-set-validation text field: \(fragment)")
        }
    }

    private func manifestReadyDecisionsByFamily() -> [ProviderFamily: ServerProviderRuntimeAdapterManifestInstallationDecision] {
        Dictionary(
            uniqueKeysWithValues: ServerProviderRuntimeAdapterManifestInstallationPlanner.decisions(
                for: ProviderFamily.allCases,
                reportsByProviderFamily: readyReportsByFamily()
            )
            .map { decision in
                (decision.providerFamily, decision)
            }
        )
    }

    private func nonReadyManifestDecision(
        for providerFamily: ProviderFamily
    ) -> ServerProviderRuntimeAdapterManifestInstallationDecision {
        ServerProviderRuntimeAdapterManifestInstallationPlanner.decision(
            for: providerFamily,
            reportsByProviderFamily: [
                providerFamily: ServerProviderRuntimeAdapterReadinessMatrix.report(for: providerFamily),
            ]
        )
    }

    private func readyReportsByFamily() -> [ProviderFamily: ServerProviderRuntimeAdapterReadinessReport] {
        Dictionary(
            uniqueKeysWithValues: ProviderFamily.allCases.map { family in
                let report = ServerProviderRuntimeAdapterReadinessMatrix.report(for: family)
                return (
                    family,
                    ServerProviderRuntimeAdapterReadinessMatrix.report(
                        for: family,
                        satisfiedGates: report.requiredGates
                    )
                )
            }
        )
    }

    private func manifestDecision(
        _ decision: ServerProviderRuntimeAdapterManifestInstallationDecision,
        installationDecision: ServerProviderRuntimeAdapterInstallationDecision?
    ) -> ServerProviderRuntimeAdapterManifestInstallationDecision {
        ServerProviderRuntimeAdapterManifestInstallationDecision(
            id: decision.id,
            providerFamily: decision.providerFamily,
            state: decision.state,
            rejection: decision.rejection,
            manifestID: decision.manifestID,
            manifestProviderFamily: decision.manifestProviderFamily,
            manifestRequiredGates: decision.manifestRequiredGates,
            readinessReportID: decision.readinessReportID,
            readinessReportFamily: decision.readinessReportFamily,
            readinessState: decision.readinessState,
            readinessRequiredGates: decision.readinessRequiredGates,
            missingGates: decision.missingGates,
            installationDecision: installationDecision
        )
    }

    private func forbiddenSensitiveFragments() -> [String] {
        [
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
            "book" + "ing",
            "ord" + "er",
            "pay" + "ment",
            "oauth" + "secret",
            "secret",
            "private" + "data",
        ]
    }
}

private struct ManifestSetResolveTrapServerProviderRuntimeAdapter: ServerProviderRuntimeAdapter {
    let providerFamily: ProviderFamily

    nonisolated func resolve(
        _ boundary: ServerProviderRuntimeDispatchBoundary
    ) -> ServerProviderRuntimeAdapterResult {
        XCTFail("Manifest-backed adapter set validation must not call resolve(_:).")
        return FixtureServerProviderRuntimeAdapter(providerFamily: providerFamily)
            .resolve(boundary)
    }
}
