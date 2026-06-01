//
//  ServerProviderRuntimeAdapterManifestInstallationTests.swift
//  kAirTests
//
//  A74 manifest-backed installation planner tests: value-only.
//

import XCTest
@testable import kAir

@MainActor
final class ServerProviderRuntimeAdapterManifestInstallationTests: XCTestCase {

    func test_remoteFamiliesAreInstallableOnlyWithManifestAndReadySameFamilyReports() throws {
        let decisions = ServerProviderRuntimeAdapterManifestInstallationPlanner.decisions(
            for: remoteFamilies,
            reportsByProviderFamily: readyReportsByFamily()
        )

        XCTAssertEqual(decisions.map(\.providerFamily), remoteFamilies)
        for decision in decisions {
            let manifest = try manifest(for: decision.providerFamily)
            let installation = try XCTUnwrap(decision.installationDecision)

            XCTAssertEqual(decision.state, .installable)
            XCTAssertTrue(decision.isInstallable)
            XCTAssertNil(decision.rejection)
            XCTAssertEqual(decision.manifestID, manifest.id)
            XCTAssertEqual(decision.manifestProviderFamily, decision.providerFamily)
            XCTAssertEqual(decision.manifestRequiredGates, manifest.requiredReadinessGates)
            XCTAssertEqual(decision.readinessReportFamily, decision.providerFamily)
            XCTAssertEqual(decision.readinessState, .readyForServerAdapter)
            XCTAssertEqual(decision.readinessRequiredGates, manifest.requiredReadinessGates)
            XCTAssertTrue(decision.missingGates.isEmpty)
            XCTAssertEqual(installation.state, .installable)
            XCTAssertTrue(installation.isInstallable)
        }
    }

    func test_localAndMissingManifestRequestsAreRejectedBeforeReadinessReportsAreConsidered() throws {
        let readyReports = readyReportsByFamily()
        let local = ServerProviderRuntimeAdapterManifestInstallationPlanner.decision(
            for: .appleLocal,
            reportsByProviderFamily: readyReports
        )
        let cache = ServerProviderRuntimeAdapterManifestInstallationPlanner.decision(
            for: .cache,
            reportsByProviderFamily: readyReports
        )
        let missingManifest = ServerProviderRuntimeAdapterManifestInstallationPlanner.decision(
            for: .searchAPI,
            reportsByProviderFamily: readyReports,
            manifestsByProviderFamily: manifestsByFamily(excluding: [.searchAPI])
        )

        XCTAssertEqual(local.state, .rejected)
        XCTAssertEqual(local.rejection, .localNoServerAdapter)
        XCTAssertNil(local.manifestID)
        XCTAssertNil(local.readinessReportID)
        XCTAssertNil(local.installationDecision)

        XCTAssertEqual(cache.state, .rejected)
        XCTAssertEqual(cache.rejection, .localNoServerAdapter)
        XCTAssertNil(cache.manifestID)
        XCTAssertNil(cache.readinessReportID)
        XCTAssertNil(cache.installationDecision)

        XCTAssertEqual(missingManifest.state, .rejected)
        XCTAssertEqual(missingManifest.rejection, .missingManifest)
        XCTAssertNil(missingManifest.manifestID)
        XCTAssertNil(missingManifest.readinessReportID)
        XCTAssertNil(missingManifest.installationDecision)
    }

    func test_manifestReadinessFamilyMismatchAndGateDriftAreRejectedDistinctly() throws {
        let readyReports = readyReportsByFamily()
        let mismatch = ServerProviderRuntimeAdapterManifestInstallationPlanner.decision(
            for: .googleMaps,
            reportsByProviderFamily: [
                .googleMaps: try XCTUnwrap(readyReports[.searchAPI]),
            ]
        )
        let searchManifest = try manifest(for: .searchAPI)
        let driftManifest = manifestWithGateDrift(searchManifest)
        let drift = ServerProviderRuntimeAdapterManifestInstallationPlanner.decision(
            for: .searchAPI,
            reportsByProviderFamily: readyReports,
            manifestsByProviderFamily: manifestsByFamily(overriding: driftManifest)
        )

        XCTAssertEqual(mismatch.state, .rejected)
        XCTAssertEqual(mismatch.rejection, .manifestReadinessFamilyMismatch)
        XCTAssertEqual(mismatch.manifestProviderFamily, .googleMaps)
        XCTAssertEqual(mismatch.readinessReportFamily, .searchAPI)
        XCTAssertNil(mismatch.installationDecision)

        XCTAssertEqual(drift.state, .rejected)
        XCTAssertEqual(drift.rejection, .manifestReadinessGateDrift)
        XCTAssertEqual(drift.manifestProviderFamily, .searchAPI)
        XCTAssertEqual(drift.readinessReportFamily, .searchAPI)
        XCTAssertNotEqual(drift.manifestRequiredGates, drift.readinessRequiredGates)
        XCTAssertNil(drift.installationDecision)
    }

    func test_existingInstallationGateSemanticsArePreservedAfterManifestValidation() throws {
        let missingReport = ServerProviderRuntimeAdapterManifestInstallationPlanner.decision(
            for: .searchAPI,
            reportsByProviderFamily: [:]
        )
        let nonReady = ServerProviderRuntimeAdapterManifestInstallationPlanner.decision(
            for: .crawler,
            reportsByProviderFamily: [
                .crawler: ServerProviderRuntimeAdapterReadinessMatrix.report(for: .crawler),
            ]
        )
        let ready = ServerProviderRuntimeAdapterManifestInstallationPlanner.decision(
            for: .mcp,
            reportsByProviderFamily: readyReportsByFamily()
        )

        XCTAssertEqual(missingReport.state, .rejected)
        XCTAssertEqual(missingReport.rejection, .installationRejected)
        XCTAssertEqual(missingReport.installationDecision?.state, .rejected)
        XCTAssertEqual(missingReport.installationDecision?.rejection, .missingReadinessReport)
        XCTAssertNil(missingReport.readinessReportID)

        XCTAssertEqual(nonReady.state, .rejected)
        XCTAssertEqual(nonReady.rejection, .installationRejected)
        XCTAssertEqual(nonReady.installationDecision?.state, .rejected)
        XCTAssertEqual(nonReady.installationDecision?.rejection, .readinessMissingRequiredGates)
        XCTAssertEqual(
            nonReady.missingGates,
            ServerProviderRuntimeAdapterReadinessMatrix.report(for: .crawler).requiredGates
        )

        XCTAssertEqual(ready.state, .installable)
        XCTAssertTrue(ready.isInstallable)
        XCTAssertEqual(ready.installationDecision?.state, .installable)
        XCTAssertTrue(ready.installationDecision?.isInstallable == true)
        XCTAssertNil(ready.installationDecision?.rejection)
    }

    func test_batchDecisionsPreserveInputOrderAndDuplicates() {
        let requested: [ProviderFamily] = [
            .searchAPI,
            .appleLocal,
            .mcp,
            .searchAPI,
            .cache,
        ]
        let decisions = ServerProviderRuntimeAdapterManifestInstallationPlanner.decisions(
            for: requested,
            reportsByProviderFamily: readyReportsByFamily()
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
        XCTAssertEqual(decisions[0], decisions[3])
    }

    func test_encodingDescriptionAndStatusTextDoNotExposeSensitiveRuntimeFields() throws {
        let decisions = ServerProviderRuntimeAdapterManifestInstallationPlanner.decisions(
            for: ProviderFamily.allCases,
            reportsByProviderFamily: readyReportsByFamily()
        )
        let data = try JSONEncoder().encode(decisions)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        let text = (
            [json]
                + decisions.map(\.statusLine)
                + decisions.map { String(describing: $0) }
        )
        .joined(separator: "\n")
        .lowercased()

        for fragment in forbiddenSensitiveFragments() {
            XCTAssertFalse(text.contains(fragment), "Unexpected manifest-installation text field: \(fragment)")
        }
    }

    private var remoteFamilies: [ProviderFamily] {
        ProviderFamily.allCases.filter(\.isRemote)
    }

    private func manifest(
        for providerFamily: ProviderFamily
    ) throws -> ServerProviderRuntimeAdapterManifest {
        try XCTUnwrap(ServerProviderRuntimeAdapterManifestCatalog.manifest(for: providerFamily))
    }

    private func manifestsByFamily(
        excluding excludedFamilies: Set<ProviderFamily> = []
    ) -> [ProviderFamily: ServerProviderRuntimeAdapterManifest] {
        Dictionary(
            uniqueKeysWithValues: ServerProviderRuntimeAdapterManifestCatalog.manifests
                .filter { excludedFamilies.contains($0.providerFamily) == false }
                .map { manifest in
                    (manifest.providerFamily, manifest)
                }
        )
    }

    private func manifestsByFamily(
        overriding override: ServerProviderRuntimeAdapterManifest
    ) -> [ProviderFamily: ServerProviderRuntimeAdapterManifest] {
        var manifests = manifestsByFamily()
        manifests[override.providerFamily] = override
        return manifests
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

    private func manifestWithGateDrift(
        _ manifest: ServerProviderRuntimeAdapterManifest
    ) -> ServerProviderRuntimeAdapterManifest {
        ServerProviderRuntimeAdapterManifest(
            id: "\(manifest.id)-gate-drift",
            providerFamily: manifest.providerFamily,
            displayName: manifest.displayName,
            supportedCapabilities: manifest.supportedCapabilities,
            requiredMembershipTier: manifest.requiredMembershipTier,
            costClass: manifest.costClass,
            requiredReadinessGates: manifest.requiredReadinessGates.subtracting([.freshCitation]),
            requiresRegionPolicy: manifest.requiresRegionPolicy,
            requiresSourcePolicy: manifest.requiresSourcePolicy,
            requiresRobotsAllow: manifest.requiresRobotsAllow,
            requiresMCPToolResourceAllowlist: manifest.requiresMCPToolResourceAllowlist,
            requiresHumanReview: manifest.requiresHumanReview,
            requiresExperimentalEnablement: manifest.requiresExperimentalEnablement
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
