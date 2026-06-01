//
//  ServerProviderRuntimeAdapterReadinessTests.swift
//  kAirTests
//
//  A66 readiness matrix tests: value-only, no provider runtime.
//

import XCTest
@testable import kAir

final class ServerProviderRuntimeAdapterReadinessTests: XCTestCase {

    func test_reportsCoverEveryProviderFamily() {
        let reports = ServerProviderRuntimeAdapterReadinessMatrix.reports()

        XCTAssertEqual(reports.map(\.providerFamily), ProviderFamily.allCases)
        XCTAssertEqual(Set(reports.map(\.providerFamily)), Set(ProviderFamily.allCases))
        XCTAssertEqual(reports.count, ProviderFamily.allCases.count)
    }

    func test_remoteProvidersNeedAllRequiredGatesExplicitlySatisfied() throws {
        for family in ProviderFamily.allCases where family.isRemote {
            let missing = ServerProviderRuntimeAdapterReadinessMatrix.report(for: family)
            let removedGate = try XCTUnwrap(missing.requiredGates.first)
            let almostSatisfied = missing.requiredGates.subtracting([removedGate])
            let partial = ServerProviderRuntimeAdapterReadinessMatrix.report(
                for: family,
                satisfiedGates: almostSatisfied
            )
            let ready = ServerProviderRuntimeAdapterReadinessMatrix.report(
                for: family,
                satisfiedGates: missing.requiredGates
            )

            XCTAssertTrue(missing.requiresServerSideAdapter)
            XCTAssertEqual(missing.state, .missingRequiredGates)
            XCTAssertFalse(missing.isReadyForServerAdapter)
            XCTAssertEqual(missing.missingGates, missing.requiredGates)
            XCTAssertEqual(partial.state, .missingRequiredGates)
            XCTAssertFalse(partial.isReadyForServerAdapter)
            XCTAssertEqual(ready.state, .readyForServerAdapter)
            XCTAssertTrue(ready.isReadyForServerAdapter)
            XCTAssertTrue(ready.missingGates.isEmpty)
        }
    }

    func test_remoteProviderFamiliesHaveDistinctGateSets() {
        let google = ServerProviderRuntimeAdapterReadinessMatrix.report(for: .googleMaps)
        let gaode = ServerProviderRuntimeAdapterReadinessMatrix.report(for: .gaode)
        let search = ServerProviderRuntimeAdapterReadinessMatrix.report(for: .searchAPI)
        let crawler = ServerProviderRuntimeAdapterReadinessMatrix.report(for: .crawler)
        let mcp = ServerProviderRuntimeAdapterReadinessMatrix.report(for: .mcp)

        assertCommonRemoteGates(google.requiredGates)
        XCTAssertTrue(google.requiredGates.contains(.paidAccessGate))
        XCTAssertTrue(google.requiredGates.contains(.regionPolicy))
        XCTAssertFalse(google.requiredGates.contains(.sourceAttribution))
        XCTAssertFalse(google.requiredGates.contains(.robotsAllow))
        XCTAssertFalse(google.requiredGates.contains(.toolResourceAllowlist))

        assertCommonRemoteGates(gaode.requiredGates)
        XCTAssertTrue(gaode.requiredGates.contains(.includedQuotaGate))
        XCTAssertTrue(gaode.requiredGates.contains(.regionPolicy))
        XCTAssertFalse(gaode.requiredGates.contains(.paidAccessGate))
        XCTAssertFalse(gaode.requiredGates.contains(.robotsAllow))

        assertCommonRemoteGates(search.requiredGates)
        XCTAssertTrue(search.requiredGates.contains(.paidAccessGate))
        XCTAssertTrue(search.requiredGates.contains(.sourceAttribution))
        XCTAssertTrue(search.requiredGates.contains(.freshCitation))
        XCTAssertFalse(search.requiredGates.contains(.robotsAllow))
        XCTAssertFalse(search.requiredGates.contains(.experimentalEnablement))

        assertCommonRemoteGates(crawler.requiredGates)
        XCTAssertTrue(crawler.requiredGates.contains(.paidAccessGate))
        XCTAssertTrue(crawler.requiredGates.contains(.sourceAttribution))
        XCTAssertTrue(crawler.requiredGates.contains(.sourceAllowlist))
        XCTAssertTrue(crawler.requiredGates.contains(.robotsAllow))
        XCTAssertTrue(crawler.requiredGates.contains(.rateLimit))
        XCTAssertTrue(crawler.requiredGates.contains(.pageRedaction))
        XCTAssertTrue(crawler.requiredGates.contains(.experimentalEnablement))

        assertCommonRemoteGates(mcp.requiredGates)
        XCTAssertTrue(mcp.requiredGates.contains(.includedQuotaGate))
        XCTAssertTrue(mcp.requiredGates.contains(.toolResourceAllowlist))
        XCTAssertTrue(mcp.requiredGates.contains(.humanReview))
        XCTAssertTrue(mcp.requiredGates.contains(.oauthIsolation))
        XCTAssertTrue(mcp.requiredGates.contains(.sandbox))
        XCTAssertTrue(mcp.requiredGates.contains(.injectionReview))
        XCTAssertTrue(mcp.requiredGates.contains(.experimentalEnablement))
        XCTAssertFalse(mcp.requiredGates.contains(.sourceAttribution))
        XCTAssertFalse(mcp.requiredGates.contains(.robotsAllow))

        XCTAssertNotEqual(google.requiredGates, gaode.requiredGates)
        XCTAssertNotEqual(search.requiredGates, crawler.requiredGates)
        XCTAssertNotEqual(crawler.requiredGates, mcp.requiredGates)
    }

    func test_localAppleAndCacheAreNoServerAdapterPaths() {
        for family in [ProviderFamily.appleLocal, .cache] {
            let report = ServerProviderRuntimeAdapterReadinessMatrix.report(for: family)

            XCTAssertEqual(report.state, .localNoServerAdapter)
            XCTAssertFalse(report.requiresServerSideAdapter)
            XCTAssertFalse(report.isReadyForServerAdapter)
            XCTAssertTrue(report.requiredGates.isEmpty)
            XCTAssertTrue(report.satisfiedGates.isEmpty)
            XCTAssertTrue(report.missingGates.isEmpty)
            XCTAssertEqual(report.requiredMembershipTier, .free)
            XCTAssertEqual(report.costClass, .freeLocal)
            XCTAssertNil(report.descriptorID)
        }
    }

    func test_reportsDeriveExistingRuntimeDescriptorPolicy() throws {
        for descriptor in ServerProviderRuntimeRegistry.descriptors {
            let report = ServerProviderRuntimeAdapterReadinessMatrix.report(
                for: descriptor.providerFamily
            )

            XCTAssertEqual(report.descriptorID, descriptor.id)
            XCTAssertEqual(report.displayName, descriptor.displayName)
            XCTAssertEqual(report.supportedCapabilities, descriptor.supportedCapabilities)
            XCTAssertEqual(report.requiredMembershipTier, descriptor.requiredMembershipTier)
            XCTAssertEqual(report.costClass, descriptor.costClass)

            if descriptor.requiresSourcePolicy {
                XCTAssertTrue(report.requiredGates.contains(.sourceAttribution))
            }
            if descriptor.requiresRobotsAllow {
                XCTAssertTrue(report.requiredGates.contains(.robotsAllow))
            }
            if descriptor.requiresConfirmation {
                XCTAssertTrue(report.requiredGates.contains(.humanReview))
            }
            if descriptor.requiresExperimentalEnablement {
                XCTAssertTrue(report.requiredGates.contains(.experimentalEnablement))
            }
        }
    }

    func test_encodingDoesNotExposeSensitiveRuntimeFields() throws {
        let satisfied = Dictionary(
            uniqueKeysWithValues: ProviderFamily.allCases.map { family in
                let report = ServerProviderRuntimeAdapterReadinessMatrix.report(for: family)
                return (family, report.requiredGates)
            }
        )
        let reports = ServerProviderRuntimeAdapterReadinessMatrix.reports(
            satisfiedGatesByProviderFamily: satisfied
        )
        let data = try JSONEncoder().encode(reports)
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

    private func assertCommonRemoteGates(
        _ gates: Set<ServerProviderRuntimeAdapterReadinessGate>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(gates.contains(.serverMediation), file: file, line: line)
        XCTAssertTrue(gates.contains(.privacyAllowance), file: file, line: line)
        XCTAssertTrue(gates.contains(.auditTrace), file: file, line: line)
        XCTAssertTrue(gates.contains(.responseRedaction), file: file, line: line)
        XCTAssertTrue(gates.contains(.iosBundleFree), file: file, line: line)
    }
}
