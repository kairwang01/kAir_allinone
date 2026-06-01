//
//  ServerProviderRuntimeConnectorTests.swift
//  kAirTests
//
//  A80 connector boundary skeleton tests.
//

import XCTest
@testable import kAir

@MainActor
final class ServerProviderRuntimeConnectorTests: XCTestCase {

    func test_connectorRequestsAndResultsAreValueOnlyAndEncodingDoesNotExposeSensitiveRuntimeFields() throws {
        let request = try connectorRequest(
            providerFamily: .searchAPI,
            capability: .webSearch,
            costClass: .meteredPremium,
            freshness: .livePreferred
        )
        let result = MetadataOnlyServerProviderRuntimeConnector(
            providerFamily: .searchAPI
        ).prepare(request)

        assertSendable(request)
        assertSendable(result)
        XCTAssertEqual(Set([request]).count, 1)
        XCTAssertEqual(Set([result]).count, 1)
        XCTAssertEqual(result.state, .metadataPrepared)
        XCTAssertEqual(result.providerFamily, .searchAPI)
        XCTAssertEqual(result.capability, .webSearch)
        XCTAssertEqual(result.costClass, .meteredPremium)
        XCTAssertEqual(result.freshness, .livePreferred)
        XCTAssertEqual(result.manifestID, request.manifestID)
        XCTAssertEqual(result.authorizationID, request.authorizationID)
        XCTAssertEqual(result.boundaryID, request.boundaryID)
        XCTAssertEqual(result.traceID, request.traceID)

        let encodedRequest = try encodedString(request)
        let encodedResult = try encodedString(result)
        let text = [
            encodedRequest,
            encodedResult,
            request.statusLine,
            request.description,
            result.statusLine,
            result.description,
        ]
            .joined(separator: "\n")
            .lowercased()

        XCTAssertTrue(text.contains("metadata only"))
        XCTAssertTrue(text.contains("no provider runtime has run"))
        for forbidden in sensitiveRuntimeFragments() {
            XCTAssertFalse(text.contains(forbidden), "Unexpected connector field: \(forbidden)")
        }
    }

    func test_connectorEligibilityIncludesOnlyRemoteProviderFamilies() throws {
        XCTAssertEqual(
            ServerProviderRuntimeConnectorCatalog.eligibleProviderFamilies,
            [.gaode, .googleMaps, .searchAPI, .crawler, .mcp]
        )

        for family in ProviderFamily.allCases where family.isRemote {
            XCTAssertTrue(ServerProviderRuntimeConnectorCatalog.isEligible(family))
            XCTAssertNotNil(
                try connectorRequest(
                    providerFamily: family,
                    capability: capability(for: family),
                    costClass: costClass(for: family),
                    freshness: .livePreferred
                )
            )
        }

        for family in [ProviderFamily.appleLocal, .cache] {
            XCTAssertFalse(ServerProviderRuntimeConnectorCatalog.isEligible(family))
            XCTAssertNil(
                ServerProviderRuntimeConnectorRequest(
                    providerFamily: family,
                    capability: .routePlanning,
                    costClass: .freeLocal,
                    freshness: .cachedOK,
                    manifest: try manifest(for: .searchAPI),
                    authorization: manifestSetUseAuthorization(
                        requestedProviderFamily: .searchAPI,
                        registered: [.searchAPI],
                        accepted: [.searchAPI]
                    ),
                    boundaryID: "a80-local-\(family.rawValue)",
                    traceID: "a80-local-\(family.rawValue)"
                )
            )
        }
    }

    func test_connectorRequestRejectsMismatchedManifestOrAuthorization() throws {
        let searchAuthorization = manifestSetUseAuthorization(
            requestedProviderFamily: .searchAPI,
            registered: [.searchAPI],
            accepted: [.searchAPI]
        )
        let rejectedAuthorization = rejectedManifestSetUseAuthorization(
            requestedProviderFamily: .searchAPI,
            rejection: .manifestValidationRejected
        )

        XCTAssertNil(
            ServerProviderRuntimeConnectorRequest(
                providerFamily: .searchAPI,
                capability: .webSearch,
                costClass: .meteredPremium,
                freshness: .livePreferred,
                manifest: try manifest(for: .googleMaps),
                authorization: searchAuthorization,
                boundaryID: "a80-manifest-mismatch",
                traceID: "a80-manifest-mismatch"
            )
        )
        XCTAssertNil(
            ServerProviderRuntimeConnectorRequest(
                providerFamily: .searchAPI,
                capability: .webSearch,
                costClass: .meteredPremium,
                freshness: .livePreferred,
                manifest: try manifest(for: .searchAPI),
                authorization: manifestSetUseAuthorization(
                    requestedProviderFamily: .googleMaps,
                    registered: [.googleMaps],
                    accepted: [.googleMaps]
                ),
                boundaryID: "a80-authorization-mismatch",
                traceID: "a80-authorization-mismatch"
            )
        )
        XCTAssertNil(
            ServerProviderRuntimeConnectorRequest(
                providerFamily: .searchAPI,
                capability: .webSearch,
                costClass: .meteredPremium,
                freshness: .livePreferred,
                manifest: try manifest(for: .searchAPI),
                authorization: rejectedAuthorization,
                boundaryID: "a80-authorization-rejected",
                traceID: "a80-authorization-rejected"
            )
        )
    }

    func test_metadataOnlyConnectorRejectsProviderFamilyMismatchWithoutProviderMetadata() throws {
        let request = try connectorRequest(
            providerFamily: .searchAPI,
            capability: .webSearch,
            costClass: .meteredPremium,
            freshness: .livePreferred
        )

        let result = MetadataOnlyServerProviderRuntimeConnector(
            providerFamily: .googleMaps
        ).prepare(request)

        XCTAssertEqual(result.state, .rejected)
        XCTAssertEqual(result.rejection, .connectorProviderFamilyMismatch)
        XCTAssertEqual(result.requestID, request.id)
        XCTAssertNil(result.providerFamily)
        XCTAssertNil(result.capability)
        XCTAssertNil(result.costClass)
        XCTAssertNil(result.freshness)
        XCTAssertNil(result.manifestID)
        XCTAssertNil(result.authorizationID)
        XCTAssertNil(result.traceID)
        XCTAssertTrue(result.statusLine.contains("metadata only"))
        XCTAssertTrue(result.statusLine.contains("No provider runtime has run"))
    }

    func test_connectorStatusDoesNotImplyProviderContactActionCompletionOrCrawling() throws {
        let request = try connectorRequest(
            providerFamily: .crawler,
            capability: .crawlerFetch,
            costClass: .meteredPremium,
            freshness: .livePreferred
        )
        let result = MetadataOnlyServerProviderRuntimeConnector(
            providerFamily: .crawler
        ).prepare(request)
        let rejected = MetadataOnlyServerProviderRuntimeConnector(
            providerFamily: .mcp
        ).prepare(request)
        let text = [
            request.statusLine,
            result.statusLine,
            rejected.statusLine,
        ]
            .joined(separator: "\n")
            .lowercased()

        XCTAssertTrue(text.contains("metadata only"))
        XCTAssertTrue(text.contains("no provider runtime has run"))
        for forbidden in advisoryForbiddenFragments() {
            XCTAssertFalse(text.contains(forbidden), "Unexpected connector wording: \(forbidden)")
        }
    }

    private func connectorRequest(
        providerFamily: ProviderFamily,
        capability: ProviderCapability,
        costClass: ProviderCostClass,
        freshness: ProviderFreshness
    ) throws -> ServerProviderRuntimeConnectorRequest {
        try XCTUnwrap(
            ServerProviderRuntimeConnectorRequest(
                providerFamily: providerFamily,
                capability: capability,
                costClass: costClass,
                freshness: freshness,
                manifest: try manifest(for: providerFamily),
                authorization: manifestSetUseAuthorization(
                    requestedProviderFamily: providerFamily,
                    registered: [providerFamily],
                    accepted: [providerFamily]
                ),
                boundaryID: "a80-boundary-\(providerFamily.rawValue)",
                traceID: "a80-trace-\(providerFamily.rawValue)"
            )
        )
    }

    private func manifest(
        for providerFamily: ProviderFamily
    ) throws -> ServerProviderRuntimeAdapterManifest {
        try XCTUnwrap(
            ServerProviderRuntimeAdapterManifestCatalog.manifest(for: providerFamily)
        )
    }

    private func capability(
        for providerFamily: ProviderFamily
    ) -> ProviderCapability {
        switch providerFamily {
        case .gaode, .googleMaps:
            return .localServiceSearch
        case .searchAPI:
            return .webSearch
        case .crawler:
            return .crawlerFetch
        case .mcp:
            return .mcpTool
        case .appleLocal, .cache:
            return .routePlanning
        }
    }

    private func costClass(
        for providerFamily: ProviderFamily
    ) -> ProviderCostClass {
        switch providerFamily {
        case .gaode, .mcp:
            return .includedQuota
        case .googleMaps, .searchAPI, .crawler:
            return .meteredPremium
        case .appleLocal, .cache:
            return .freeLocal
        }
    }

    private func manifestSetUseAuthorization(
        requestedProviderFamily: ProviderFamily?,
        registered: [ProviderFamily],
        accepted: [ProviderFamily]
    ) -> ServerProviderRuntimeAdapterManifestSetUseAuthorization {
        ServerProviderRuntimeAdapterManifestSetUseGate.authorize(
            requestedProviderFamily: requestedProviderFamily,
            validation: manifestSetValidation(
                state: .accepted,
                registered: registered,
                accepted: accepted,
                readinessValidation: adapterSetValidation(
                    state: .accepted,
                    registered: registered,
                    accepted: accepted
                )
            )
        )
    }

    private func rejectedManifestSetUseAuthorization(
        requestedProviderFamily: ProviderFamily?,
        rejection: ServerProviderRuntimeAdapterManifestSetUseRejectionReason
    ) -> ServerProviderRuntimeAdapterManifestSetUseAuthorization {
        ServerProviderRuntimeAdapterManifestSetUseAuthorization(
            id: "a80-manifest-set-use-\(requestedProviderFamily?.rawValue ?? "missing")",
            state: .rejected,
            requestedProviderFamily: requestedProviderFamily,
            rejection: rejection,
            manifestValidationID: "a80-manifest-set-validation",
            manifestValidationState: .rejected,
            manifestAcceptedProviderFamilies: requestedProviderFamily.map { [$0] } ?? [],
            readinessValidationID: nil,
            readinessValidationState: nil,
            readinessAuthorization: nil,
            readinessAuthorizationState: nil,
            readinessAuthorizationRejection: nil
        )
    }

    private func manifestSetValidation(
        state: ServerProviderRuntimeAdapterManifestSetValidationState,
        registered: [ProviderFamily],
        accepted: [ProviderFamily],
        readinessValidation: ServerProviderRuntimeAdapterSetReadinessValidation?
    ) -> ServerProviderRuntimeAdapterManifestSetValidation {
        ServerProviderRuntimeAdapterManifestSetValidation(
            id: "a80-manifest-set-validation-\(state.rawValue)",
            state: state,
            registeredProviderFamilies: registered,
            acceptedProviderFamilies: accepted,
            rejectedProviderFamilies: [],
            readinessValidation: readinessValidation
        )
    }

    private func adapterSetValidation(
        state: ServerProviderRuntimeAdapterSetReadinessValidationState,
        registered: [ProviderFamily],
        accepted: [ProviderFamily]
    ) -> ServerProviderRuntimeAdapterSetReadinessValidation {
        ServerProviderRuntimeAdapterSetReadinessValidation(
            id: "a80-adapter-set-readiness-validation-\(state.rawValue)",
            state: state,
            registeredProviderFamilies: registered,
            acceptedProviderFamilies: accepted,
            rejectedProviderFamilies: []
        )
    }

    private func encodedString<T: Encodable>(
        _ value: T
    ) throws -> String {
        try XCTUnwrap(
            String(data: JSONEncoder().encode(value), encoding: .utf8)
        )
    }

    private func assertSendable<T: Sendable>(
        _ value: T,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        _ = value
    }

    private func sensitiveRuntimeFragments() -> [String] {
        [
            "end" + "point",
            "url",
            "api" + "key",
            "api" + "_" + "key",
            "bear" + "er",
            "tok" + "en",
            "creden" + "tial",
            "s" + "dk",
            "prompt",
            "raw" + "content",
            "raw" + "source",
            "hea" + "lth",
            "private",
            "merchant",
            "order",
            "pay" + "ment",
        ]
    }

    private func advisoryForbiddenFragments() -> [String] {
        [
            "completed",
            "complete",
            "done",
            "call" + "ed",
            "contact" + "ed",
            "fetch" + "ed",
            "invoked",
            "crawl" + "ed",
            "crawl" + "ing",
            "book" + "ed",
            "book" + "ing",
            "ordered",
            "ordering",
            "paid",
            "pay" + "ment",
        ]
    }
}
