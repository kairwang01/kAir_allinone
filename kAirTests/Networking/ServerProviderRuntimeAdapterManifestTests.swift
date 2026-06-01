//
//  ServerProviderRuntimeAdapterManifestTests.swift
//  kAirTests
//
//  A73 manifest catalog tests: value-only, no provider runtime.
//

import XCTest
@testable import kAir

@MainActor
final class ServerProviderRuntimeAdapterManifestTests: XCTestCase {

    func test_catalogIncludesExactlyRemoteProviderFamiliesAndExcludesLocalFamilies() {
        let manifests = ServerProviderRuntimeAdapterManifestCatalog.manifests
        let remoteFamilies = ProviderFamily.allCases.filter(\.isRemote)

        XCTAssertEqual(manifests.map(\.providerFamily), remoteFamilies)
        XCTAssertEqual(
            manifests.map(\.providerFamily),
            [.gaode, .googleMaps, .searchAPI, .crawler, .mcp]
        )
        XCTAssertEqual(manifests.count, 5)
        XCTAssertEqual(Set(manifests.map(\.providerFamily)).count, manifests.count)
        XCTAssertNil(ServerProviderRuntimeAdapterManifestCatalog.manifest(for: .appleLocal))
        XCTAssertNil(ServerProviderRuntimeAdapterManifestCatalog.manifest(for: .cache))
    }

    func test_manifestsMirrorReadinessMatrixRequiredGatesAndDescriptorMetadata() {
        for manifest in ServerProviderRuntimeAdapterManifestCatalog.manifests {
            let report = ServerProviderRuntimeAdapterReadinessMatrix.report(
                for: manifest.providerFamily
            )

            XCTAssertTrue(report.requiresServerSideAdapter)
            XCTAssertEqual(
                manifest.id,
                "provider-runtime-adapter-manifest-\(manifest.providerFamily.rawValue)"
            )
            XCTAssertEqual(manifest.displayName, report.displayName)
            XCTAssertEqual(manifest.supportedCapabilities, report.supportedCapabilities)
            XCTAssertEqual(manifest.requiredMembershipTier, report.requiredMembershipTier)
            XCTAssertEqual(manifest.costClass, report.costClass)
            XCTAssertEqual(manifest.requiredReadinessGates, report.requiredGates)
            XCTAssertEqual(
                manifest.requiresRegionPolicy,
                report.requiredGates.contains(.regionPolicy)
            )
            XCTAssertEqual(
                manifest.requiresSourcePolicy,
                report.requiredGates.contains(.sourceAttribution)
            )
            XCTAssertEqual(
                manifest.requiresRobotsAllow,
                report.requiredGates.contains(.robotsAllow)
            )
            XCTAssertEqual(
                manifest.requiresMCPToolResourceAllowlist,
                report.requiredGates.contains(.toolResourceAllowlist)
            )
            XCTAssertEqual(
                manifest.requiresHumanReview,
                report.requiredGates.contains(.humanReview)
            )
            XCTAssertEqual(
                manifest.requiresExperimentalEnablement,
                report.requiredGates.contains(.experimentalEnablement)
            )
        }
    }

    func test_specialFlagsMatchProviderFamilyPolicy() throws {
        let gaode = try manifest(for: .gaode)
        XCTAssertEqual(gaode.requiredMembershipTier, .plus)
        XCTAssertEqual(gaode.costClass, .includedQuota)
        XCTAssertTrue(gaode.supportedCapabilities.isSuperset(of: [.placeSearch, .routePlanning]))
        XCTAssertTrue(gaode.requiresRegionPolicy)
        XCTAssertFalse(gaode.requiresSourcePolicy)
        XCTAssertFalse(gaode.requiresRobotsAllow)
        XCTAssertFalse(gaode.requiresMCPToolResourceAllowlist)
        XCTAssertFalse(gaode.requiresHumanReview)
        XCTAssertFalse(gaode.requiresExperimentalEnablement)

        let google = try manifest(for: .googleMaps)
        XCTAssertEqual(google.requiredMembershipTier, .plus)
        XCTAssertEqual(google.costClass, .meteredPremium)
        XCTAssertTrue(google.supportedCapabilities.isSuperset(of: [.placeSearch, .routePlanning]))
        XCTAssertTrue(google.requiresRegionPolicy)
        XCTAssertFalse(google.requiresSourcePolicy)
        XCTAssertFalse(google.requiresRobotsAllow)
        XCTAssertFalse(google.requiresMCPToolResourceAllowlist)
        XCTAssertFalse(google.requiresHumanReview)
        XCTAssertFalse(google.requiresExperimentalEnablement)

        let search = try manifest(for: .searchAPI)
        XCTAssertEqual(search.requiredMembershipTier, .plus)
        XCTAssertEqual(search.costClass, .meteredPremium)
        XCTAssertTrue(search.supportedCapabilities.contains(.webSearch))
        XCTAssertFalse(search.requiresRegionPolicy)
        XCTAssertTrue(search.requiresSourcePolicy)
        XCTAssertFalse(search.requiresRobotsAllow)
        XCTAssertFalse(search.requiresMCPToolResourceAllowlist)
        XCTAssertFalse(search.requiresHumanReview)
        XCTAssertFalse(search.requiresExperimentalEnablement)

        let crawler = try manifest(for: .crawler)
        XCTAssertEqual(crawler.requiredMembershipTier, .pro)
        XCTAssertEqual(crawler.costClass, .meteredPremium)
        XCTAssertTrue(crawler.supportedCapabilities.contains(.crawlerFetch))
        XCTAssertFalse(crawler.requiresRegionPolicy)
        XCTAssertTrue(crawler.requiresSourcePolicy)
        XCTAssertTrue(crawler.requiresRobotsAllow)
        XCTAssertFalse(crawler.requiresMCPToolResourceAllowlist)
        XCTAssertFalse(crawler.requiresHumanReview)
        XCTAssertTrue(crawler.requiresExperimentalEnablement)

        let mcp = try manifest(for: .mcp)
        XCTAssertEqual(mcp.requiredMembershipTier, .pro)
        XCTAssertEqual(mcp.costClass, .includedQuota)
        XCTAssertTrue(mcp.supportedCapabilities.contains(.mcpTool))
        XCTAssertFalse(mcp.requiresRegionPolicy)
        XCTAssertFalse(mcp.requiresSourcePolicy)
        XCTAssertFalse(mcp.requiresRobotsAllow)
        XCTAssertTrue(mcp.requiresMCPToolResourceAllowlist)
        XCTAssertTrue(mcp.requiresHumanReview)
        XCTAssertTrue(mcp.requiresExperimentalEnablement)
    }

    func test_encodingDescriptionAndStatusTextDoNotExposeSensitiveRuntimeFields() throws {
        let manifests = ServerProviderRuntimeAdapterManifestCatalog.manifests
        let data = try JSONEncoder().encode(manifests)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        let text = (
            [json]
                + manifests.map(\.statusLine)
                + manifests.map { String(describing: $0) }
        )
        .joined(separator: "\n")
        .lowercased()

        for fragment in forbiddenSensitiveFragments() {
            XCTAssertFalse(text.contains(fragment), "Unexpected manifest text field: \(fragment)")
        }
    }

    func test_lookupAndBatchSelectionAreDeterministicDuplicateSafeAndNilForLocalFamilies() throws {
        XCTAssertNil(ServerProviderRuntimeAdapterManifestCatalog.manifest(for: .appleLocal))
        XCTAssertNil(ServerProviderRuntimeAdapterManifestCatalog.manifest(for: .cache))

        let selected = ServerProviderRuntimeAdapterManifestCatalog.manifests(
            for: [.mcp, .mcp, .appleLocal, .searchAPI, .mcp, .cache, .crawler]
        )

        XCTAssertEqual(selected.map(\.providerFamily), [.mcp, .searchAPI, .crawler])
        XCTAssertEqual(
            ServerProviderRuntimeAdapterManifestCatalog.manifests.map(\.providerFamily),
            [.gaode, .googleMaps, .searchAPI, .crawler, .mcp]
        )
        XCTAssertEqual(try manifest(for: .mcp), selected[0])
        XCTAssertEqual(try manifest(for: .searchAPI), selected[1])
        XCTAssertEqual(try manifest(for: .crawler), selected[2])
    }

    private func manifest(
        for providerFamily: ProviderFamily
    ) throws -> ServerProviderRuntimeAdapterManifest {
        try XCTUnwrap(ServerProviderRuntimeAdapterManifestCatalog.manifest(for: providerFamily))
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
