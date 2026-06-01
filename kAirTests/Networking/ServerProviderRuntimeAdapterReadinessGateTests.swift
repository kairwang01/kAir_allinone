//
//  ServerProviderRuntimeAdapterReadinessGateTests.swift
//  kAirTests
//
//  A67 installation gate tests: value-only, no provider runtime.
//

import XCTest
@testable import kAir

final class ServerProviderRuntimeAdapterReadinessGateTests: XCTestCase {

    func test_remoteFamiliesAreInstallableOnlyWithReadySameFamilyReports() throws {
        let reports = readyReportsByFamily()

        for family in remoteFamilies {
            let decision = ServerProviderRuntimeAdapterInstallationGate.decision(
                for: family,
                reportsByProviderFamily: reports
            )

            XCTAssertEqual(decision.providerFamily, family)
            XCTAssertEqual(decision.state, .installable)
            XCTAssertTrue(decision.isInstallable)
            XCTAssertNil(decision.rejection)
            XCTAssertEqual(decision.readinessReportFamily, family)
            XCTAssertEqual(decision.readinessState, .readyForServerAdapter)
            XCTAssertTrue(decision.missingGates.isEmpty)
        }
    }

    func test_missingNonReadyAndMismatchedReportsAreRejected() {
        let readyReports = readyReportsByFamily()
        let missing = ServerProviderRuntimeAdapterInstallationGate.decision(
            for: .searchAPI,
            reportsByProviderFamily: [:]
        )
        let nonReady = ServerProviderRuntimeAdapterInstallationGate.decision(
            for: .crawler,
            reportsByProviderFamily: [
                .crawler: ServerProviderRuntimeAdapterReadinessMatrix.report(for: .crawler),
            ]
        )
        let mismatch = ServerProviderRuntimeAdapterInstallationGate.decision(
            for: .googleMaps,
            reportsByProviderFamily: [
                .googleMaps: readyReports[.searchAPI]!,
            ]
        )

        XCTAssertEqual(missing.state, .rejected)
        XCTAssertFalse(missing.isInstallable)
        XCTAssertEqual(missing.rejection, .missingReadinessReport)
        XCTAssertNil(missing.readinessReportID)
        XCTAssertTrue(missing.missingGates.isEmpty)

        XCTAssertEqual(nonReady.state, .rejected)
        XCTAssertFalse(nonReady.isInstallable)
        XCTAssertEqual(nonReady.rejection, .readinessMissingRequiredGates)
        XCTAssertEqual(
            nonReady.missingGates,
            ServerProviderRuntimeAdapterReadinessMatrix.report(for: .crawler).requiredGates
        )

        XCTAssertEqual(mismatch.state, .rejected)
        XCTAssertFalse(mismatch.isInstallable)
        XCTAssertEqual(mismatch.rejection, .readinessReportFamilyMismatch)
        XCTAssertEqual(mismatch.readinessReportFamily, .searchAPI)
        XCTAssertEqual(mismatch.readinessState, .readyForServerAdapter)
    }

    func test_localFamiliesAreRejectedAsNoServerAdapterPaths() {
        let reports = readyReportsByFamily()

        for family in [ProviderFamily.appleLocal, .cache] {
            let decision = ServerProviderRuntimeAdapterInstallationGate.decision(
                for: family,
                reportsByProviderFamily: reports
            )

            XCTAssertEqual(decision.providerFamily, family)
            XCTAssertEqual(decision.state, .rejected)
            XCTAssertFalse(decision.isInstallable)
            XCTAssertEqual(decision.rejection, .localNoServerAdapter)
            XCTAssertTrue(decision.missingGates.isEmpty)
        }
    }

    func test_batchDecisionsPreserveInputOrderAndDuplicates() {
        let reports = readyReportsByFamily()
        let requested: [ProviderFamily] = [
            .searchAPI,
            .appleLocal,
            .mcp,
            .searchAPI,
            .cache,
        ]

        let decisions = ServerProviderRuntimeAdapterInstallationGate.decisions(
            for: requested,
            reportsByProviderFamily: reports
        )

        XCTAssertEqual(decisions.map(\.providerFamily), requested)
        XCTAssertEqual(decisions.map(\.state), [
            .installable,
            .rejected,
            .installable,
            .installable,
            .rejected,
        ])
        XCTAssertEqual(decisions[1].rejection, .localNoServerAdapter)
        XCTAssertEqual(decisions[4].rejection, .localNoServerAdapter)
    }

    func test_decisionsEncodingDoesNotExposeSensitiveRuntimeFields() throws {
        let decisions = ServerProviderRuntimeAdapterInstallationGate.decisions(
            for: ProviderFamily.allCases,
            reportsByProviderFamily: readyReportsByFamily()
        )
        let data = try JSONEncoder().encode(decisions)
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

    private var remoteFamilies: [ProviderFamily] {
        ProviderFamily.allCases.filter(\.isRemote)
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
}
