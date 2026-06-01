//
//  ServerProviderRuntimeConnectorPlannerTests.swift
//  kAirTests
//
//  A81 connector request planner proof tests.
//

import XCTest
@testable import kAir

@MainActor
final class ServerProviderRuntimeConnectorPlannerTests: XCTestCase {

    func test_preparedSameFamilyRemoteBoundaryProducesConnectorRequestWithCopiedMetadata() throws {
        let boundary = dispatchBoundary(
            providerFamily: .searchAPI,
            capability: .webSearch,
            costClass: .meteredPremium,
            freshness: .liveRequired,
            traceID: "a81-trace-search"
        )
        let searchManifest = try manifest(for: .searchAPI)
        let authorization = manifestSetUseAuthorization(
            requestedProviderFamily: .searchAPI,
            registered: [.searchAPI],
            accepted: [.searchAPI]
        )

        let result = ServerProviderRuntimeConnectorPlanner.plan(
            boundary: boundary,
            manifest: searchManifest,
            authorization: authorization
        )

        assertSendable(result)
        XCTAssertEqual(Set([result]).count, 1)
        XCTAssertEqual(result.state, .requestPrepared)
        XCTAssertTrue(result.isRequestPrepared)
        XCTAssertNil(result.rejection)
        XCTAssertEqual(result.boundaryID, boundary.id)
        XCTAssertEqual(result.planID, boundary.planID)
        XCTAssertEqual(result.providerFamily, .searchAPI)
        XCTAssertEqual(result.capability, .webSearch)
        XCTAssertEqual(result.costClass, .meteredPremium)
        XCTAssertEqual(result.freshness, .liveRequired)
        XCTAssertEqual(result.manifestID, searchManifest.id)
        XCTAssertEqual(result.authorizationID, authorization.id)
        XCTAssertEqual(result.traceID, "a81-trace-search")

        let request = try XCTUnwrap(result.request)
        XCTAssertEqual(result.requestID, request.id)
        XCTAssertEqual(request.providerFamily, .searchAPI)
        XCTAssertEqual(request.capability, .webSearch)
        XCTAssertEqual(request.costClass, .meteredPremium)
        XCTAssertEqual(request.freshness, .liveRequired)
        XCTAssertEqual(request.manifestID, searchManifest.id)
        XCTAssertEqual(request.authorizationID, authorization.id)
        XCTAssertEqual(request.boundaryID, boundary.id)
        XCTAssertEqual(request.traceID, "a81-trace-search")
    }

    func test_rejectedPlanningReasonsAreDeterministicAndDoNotPrepareRequests() throws {
        let searchManifest = try manifest(for: .searchAPI)
        let authorization = manifestSetUseAuthorization(
            requestedProviderFamily: .searchAPI,
            registered: [.searchAPI],
            accepted: [.searchAPI]
        )
        let rejectedAuthorization = rejectedManifestSetUseAuthorization(
            requestedProviderFamily: .searchAPI,
            rejection: .manifestValidationRejected
        )

        let cases: [(ServerProviderRuntimeDispatchBoundary, ServerProviderRuntimeAdapterManifest, ServerProviderRuntimeAdapterManifestSetUseAuthorization, ServerProviderRuntimeConnectorPlanningRejectionReason)] = [
            (
                dispatchBoundary(
                    state: .localOnly,
                    providerFamily: nil,
                    capability: nil,
                    costClass: nil,
                    freshness: nil,
                    traceID: nil
                ),
                searchManifest,
                authorization,
                .nonPreparedBoundary
            ),
            (
                dispatchBoundary(
                    providerFamily: nil,
                    capability: .webSearch,
                    costClass: .meteredPremium,
                    freshness: .livePreferred
                ),
                searchManifest,
                authorization,
                .missingRequestedProviderFamily
            ),
            (
                dispatchBoundary(
                    providerFamily: .cache,
                    capability: .routePlanning,
                    costClass: .freeLocal,
                    freshness: .cachedOK
                ),
                searchManifest,
                authorization,
                .localNoConnector
            ),
            (
                dispatchBoundary(
                    providerFamily: .searchAPI,
                    capability: .webSearch,
                    costClass: .meteredPremium,
                    freshness: .livePreferred
                ),
                try self.manifest(for: .googleMaps),
                authorization,
                .manifestProviderFamilyMismatch
            ),
            (
                dispatchBoundary(
                    providerFamily: .searchAPI,
                    capability: .webSearch,
                    costClass: .meteredPremium,
                    freshness: .livePreferred
                ),
                searchManifest,
                manifestSetUseAuthorization(
                    requestedProviderFamily: .googleMaps,
                    registered: [.googleMaps],
                    accepted: [.googleMaps]
                ),
                .authorizationProviderFamilyMismatch
            ),
            (
                dispatchBoundary(
                    providerFamily: .searchAPI,
                    capability: .webSearch,
                    costClass: .meteredPremium,
                    freshness: .livePreferred
                ),
                searchManifest,
                rejectedAuthorization,
                .authorizationRejected
            ),
            (
                dispatchBoundary(
                    providerFamily: .searchAPI,
                    capability: nil,
                    costClass: .meteredPremium,
                    freshness: .livePreferred
                ),
                searchManifest,
                authorization,
                .missingBoundaryMetadata
            ),
        ]

        for (boundary, manifest, authorization, rejection) in cases {
            let result = ServerProviderRuntimeConnectorPlanner.plan(
                boundary: boundary,
                manifest: manifest,
                authorization: authorization
            )

            XCTAssertEqual(result.state, .rejected)
            XCTAssertFalse(result.isRequestPrepared)
            XCTAssertNil(result.request)
            XCTAssertNil(result.requestID)
            XCTAssertNil(result.traceID)
            XCTAssertEqual(result.rejection, rejection)
            XCTAssertTrue(result.statusLine.contains("metadata only"))
            XCTAssertTrue(result.statusLine.contains("No provider runtime has run"))
        }
    }

    func test_missingBoundaryMetadataCoversTraceCapabilityCostAndFreshness() throws {
        let manifest = try manifest(for: .searchAPI)
        let authorization = manifestSetUseAuthorization(
            requestedProviderFamily: .searchAPI,
            registered: [.searchAPI],
            accepted: [.searchAPI]
        )
        let boundaries = [
            dispatchBoundary(
                providerFamily: .searchAPI,
                capability: .webSearch,
                costClass: .meteredPremium,
                freshness: .livePreferred,
                traceID: " "
            ),
            dispatchBoundary(
                providerFamily: .searchAPI,
                capability: nil,
                costClass: .meteredPremium,
                freshness: .livePreferred
            ),
            dispatchBoundary(
                providerFamily: .searchAPI,
                capability: .webSearch,
                costClass: nil,
                freshness: .livePreferred
            ),
            dispatchBoundary(
                providerFamily: .searchAPI,
                capability: .webSearch,
                costClass: .meteredPremium,
                freshness: nil
            ),
        ]

        for boundary in boundaries {
            let result = ServerProviderRuntimeConnectorPlanner.plan(
                boundary: boundary,
                manifest: manifest,
                authorization: authorization
            )

            XCTAssertEqual(result.state, .rejected)
            XCTAssertEqual(result.rejection, .missingBoundaryMetadata)
            XCTAssertNil(result.request)
        }
    }

    func test_planningOutputEncodingAndCopyStayAdvisoryAndValueOnly() throws {
        let accepted = ServerProviderRuntimeConnectorPlanner.plan(
            boundary: dispatchBoundary(
                providerFamily: .searchAPI,
                capability: .webSearch,
                costClass: .meteredPremium,
                freshness: .livePreferred,
                traceID: "a81-advisory-search"
            ),
            manifest: try manifest(for: .searchAPI),
            authorization: manifestSetUseAuthorization(
                requestedProviderFamily: .searchAPI,
                registered: [.searchAPI],
                accepted: [.searchAPI]
            )
        )
        let rejected = ServerProviderRuntimeConnectorPlanner.plan(
            boundary: dispatchBoundary(
                state: .blocked,
                providerFamily: nil,
                capability: nil,
                costClass: nil,
                freshness: nil,
                traceID: nil
            ),
            manifest: try manifest(for: .searchAPI),
            authorization: manifestSetUseAuthorization(
                requestedProviderFamily: .searchAPI,
                registered: [.searchAPI],
                accepted: [.searchAPI]
            )
        )
        let text = [
            try encodedString(accepted),
            try encodedString(rejected),
            accepted.statusLine,
            accepted.description,
            rejected.statusLine,
            rejected.description,
        ]
            .joined(separator: "\n")
            .lowercased()

        XCTAssertTrue(text.contains("metadata only"))
        XCTAssertTrue(text.contains("no provider runtime has run"))
        for forbidden in sensitiveRuntimeFragments() + advisoryForbiddenFragments() {
            XCTAssertFalse(text.contains(forbidden), "Unexpected planner field or wording: \(forbidden)")
        }
    }

    private func dispatchBoundary(
        state: ServerProviderRuntimeDispatchState = .prepared,
        providerFamily: ProviderFamily?,
        capability: ProviderCapability?,
        costClass: ProviderCostClass?,
        freshness: ProviderFreshness?,
        traceID: String? = "a81-trace",
        id: String = "a81-boundary"
    ) -> ServerProviderRuntimeDispatchBoundary {
        ServerProviderRuntimeDispatchBoundary(
            id: id,
            state: state,
            statusLine: "A81 dispatch fixture is metadata only. No provider runtime has run.",
            planID: "a81-plan-\(id)",
            traceID: traceID,
            providerFamily: providerFamily,
            capability: capability,
            descriptorID: state == .prepared ? "a81-descriptor-\(id)" : nil,
            costClass: costClass,
            freshness: freshness,
            sourcePolicy: nil,
            confirmationState: nil,
            audit: ServerProviderRuntimeDispatchAudit(
                planID: "a81-plan-\(id)",
                planState: state == .prepared ? .planned : .blocked,
                readinessID: "a81-readiness-\(id)",
                lookupID: "a81-lookup-\(id)",
                readinessState: state == .prepared ? .serverReady : .blocked,
                lookupState: state == .prepared ? .descriptorAvailable : .blocked,
                rejectionReason: state == .prepared ? nil : .planNotPlanned,
                factoryRejectionReason: nil,
                validatorDenialReason: nil
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
            id: "a81-manifest-set-use-\(requestedProviderFamily?.rawValue ?? "missing")",
            state: .rejected,
            requestedProviderFamily: requestedProviderFamily,
            rejection: rejection,
            manifestValidationID: "a81-manifest-set-validation",
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
            id: "a81-manifest-set-validation-\(state.rawValue)",
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
            id: "a81-adapter-set-readiness-validation-\(state.rawValue)",
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
            "oauth",
            "s" + "dk",
            "prompt",
            "raw" + "content",
            "raw" + "source",
            "hea" + "lth",
            "private",
            "merchant",
            "order",
            "pay" + "ment",
            "providerresult",
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
