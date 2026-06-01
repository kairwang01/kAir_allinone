//
//  ServerProviderRuntimeConnectorInvocationTests.swift
//  kAirTests
//
//  A82 connector invocation receipt proof tests.
//

import Foundation
import XCTest
@testable import kAir

@MainActor
final class ServerProviderRuntimeConnectorInvocationTests: XCTestCase {

    func test_acceptedPlanningWithSameFamilyConnectorProducesReceiptWithResultMetadata() throws {
        let planning = try connectorPlanning(
            providerFamily: .searchAPI,
            capability: .webSearch,
            costClass: .meteredPremium,
            freshness: .liveRequired,
            traceID: "a82-trace-search"
        )
        let connector = CountingConnector(providerFamily: .searchAPI)

        let receipt = ServerProviderRuntimeConnectorInvoker.invoke(
            planningResult: planning,
            connector: connector
        )

        assertSendable(receipt)
        XCTAssertEqual(Set([receipt]).count, 1)
        XCTAssertEqual(connector.prepareCallCount, 1)
        XCTAssertEqual(receipt.state, .receiptPrepared)
        XCTAssertNil(receipt.invocationRejection)
        XCTAssertEqual(receipt.planningID, planning.id)
        XCTAssertEqual(receipt.planningState, .requestPrepared)
        XCTAssertEqual(receipt.connectorProviderFamily, .searchAPI)
        XCTAssertEqual(receipt.requestID, planning.requestID)
        XCTAssertEqual(receipt.connectorResultState, .metadataPrepared)
        XCTAssertEqual(receipt.connectorRejection, nil)
        XCTAssertEqual(receipt.providerFamily, .searchAPI)
        XCTAssertEqual(receipt.capability, .webSearch)
        XCTAssertEqual(receipt.costClass, .meteredPremium)
        XCTAssertEqual(receipt.freshness, .liveRequired)
        XCTAssertEqual(receipt.manifestID, planning.manifestID)
        XCTAssertEqual(receipt.authorizationID, planning.authorizationID)
        XCTAssertEqual(receipt.boundaryID, planning.boundaryID)
        XCTAssertEqual(receipt.traceID, "a82-trace-search")
        XCTAssertNotNil(receipt.resultID)
        XCTAssertTrue(receipt.statusLine.contains("metadata-only connector output"))
        XCTAssertTrue(receipt.statusLine.contains("No provider runtime has run"))
    }

    func test_rejectedPlanningReturnsReceiptWithoutCallingConnector() throws {
        let planning = ServerProviderRuntimeConnectorPlanner.plan(
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
        let connector = CountingConnector(providerFamily: .searchAPI)

        let receipt = ServerProviderRuntimeConnectorInvoker.invoke(
            planningResult: planning,
            connector: connector
        )

        XCTAssertEqual(connector.prepareCallCount, 0)
        XCTAssertEqual(receipt.state, .rejected)
        XCTAssertEqual(receipt.invocationRejection, .planningRejected)
        XCTAssertEqual(receipt.planningRejection, .nonPreparedBoundary)
        XCTAssertEqual(receipt.connectorProviderFamily, .searchAPI)
        XCTAssertNil(receipt.requestID)
        XCTAssertNil(receipt.resultID)
        XCTAssertNil(receipt.connectorResultState)
        XCTAssertNil(receipt.connectorRejection)
        XCTAssertNil(receipt.providerFamily)
        XCTAssertNil(receipt.capability)
        XCTAssertNil(receipt.costClass)
        XCTAssertNil(receipt.freshness)
        XCTAssertNil(receipt.manifestID)
        XCTAssertNil(receipt.authorizationID)
        XCTAssertNil(receipt.traceID)
        XCTAssertEqual(receipt.boundaryID, planning.boundaryID)
    }

    func test_connectorFamilyMismatchReturnsRejectedReceiptWithoutProviderMetadata() throws {
        let planning = try connectorPlanning(
            providerFamily: .searchAPI,
            capability: .webSearch,
            costClass: .meteredPremium,
            freshness: .livePreferred,
            traceID: "a82-trace-mismatch"
        )
        let connector = CountingConnector(providerFamily: .googleMaps)

        let receipt = ServerProviderRuntimeConnectorInvoker.invoke(
            planningResult: planning,
            connector: connector
        )

        XCTAssertEqual(connector.prepareCallCount, 1)
        XCTAssertEqual(receipt.state, .rejected)
        XCTAssertEqual(receipt.invocationRejection, .connectorRejected)
        XCTAssertEqual(receipt.connectorProviderFamily, .googleMaps)
        XCTAssertEqual(receipt.connectorResultState, .rejected)
        XCTAssertEqual(receipt.connectorRejection, .connectorProviderFamilyMismatch)
        XCTAssertEqual(receipt.requestID, planning.requestID)
        XCTAssertNotNil(receipt.resultID)
        XCTAssertNil(receipt.providerFamily)
        XCTAssertNil(receipt.capability)
        XCTAssertNil(receipt.costClass)
        XCTAssertNil(receipt.freshness)
        XCTAssertNil(receipt.manifestID)
        XCTAssertNil(receipt.authorizationID)
        XCTAssertNil(receipt.traceID)
        XCTAssertEqual(receipt.boundaryID, planning.boundaryID)
    }

    func test_invocationReceiptEncodingAndCopyStayAdvisoryAndValueOnly() throws {
        let acceptedPlanning = try connectorPlanning(
            providerFamily: .searchAPI,
            capability: .webSearch,
            costClass: .meteredPremium,
            freshness: .livePreferred,
            traceID: "a82-advisory-search"
        )
        let accepted = ServerProviderRuntimeConnectorInvoker.invoke(
            planningResult: acceptedPlanning,
            connector: CountingConnector(providerFamily: .searchAPI)
        )
        let mismatch = ServerProviderRuntimeConnectorInvoker.invoke(
            planningResult: acceptedPlanning,
            connector: CountingConnector(providerFamily: .googleMaps)
        )
        let rejectedPlanning = ServerProviderRuntimeConnectorPlanner.plan(
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
        let rejected = ServerProviderRuntimeConnectorInvoker.invoke(
            planningResult: rejectedPlanning,
            connector: CountingConnector(providerFamily: .searchAPI)
        )
        let text = [
            try encodedString(accepted),
            try encodedString(mismatch),
            try encodedString(rejected),
            accepted.statusLine,
            accepted.description,
            mismatch.statusLine,
            mismatch.description,
            rejected.statusLine,
            rejected.description,
        ]
            .joined(separator: "\n")
            .lowercased()

        XCTAssertTrue(text.contains("metadata"))
        XCTAssertTrue(text.contains("no provider runtime has run"))
        for forbidden in sensitiveRuntimeFragments() + advisoryForbiddenFragments() {
            XCTAssertFalse(text.contains(forbidden), "Unexpected invocation field or wording: \(forbidden)")
        }
    }

    private func connectorPlanning(
        providerFamily: ProviderFamily,
        capability: ProviderCapability,
        costClass: ProviderCostClass,
        freshness: ProviderFreshness,
        traceID: String
    ) throws -> ServerProviderRuntimeConnectorPlanningResult {
        let planning = ServerProviderRuntimeConnectorPlanner.plan(
            boundary: dispatchBoundary(
                providerFamily: providerFamily,
                capability: capability,
                costClass: costClass,
                freshness: freshness,
                traceID: traceID
            ),
            manifest: try manifest(for: providerFamily),
            authorization: manifestSetUseAuthorization(
                requestedProviderFamily: providerFamily,
                registered: [providerFamily],
                accepted: [providerFamily]
            )
        )
        XCTAssertEqual(planning.state, .requestPrepared)
        return planning
    }

    private func dispatchBoundary(
        state: ServerProviderRuntimeDispatchState = .prepared,
        providerFamily: ProviderFamily?,
        capability: ProviderCapability?,
        costClass: ProviderCostClass?,
        freshness: ProviderFreshness?,
        traceID: String?,
        id: String = "a82-boundary"
    ) -> ServerProviderRuntimeDispatchBoundary {
        ServerProviderRuntimeDispatchBoundary(
            id: id,
            state: state,
            statusLine: "A82 dispatch fixture is metadata only. No provider runtime has run.",
            planID: "a82-plan-\(id)",
            traceID: traceID,
            providerFamily: providerFamily,
            capability: capability,
            descriptorID: state == .prepared ? "a82-descriptor-\(id)" : nil,
            costClass: costClass,
            freshness: freshness,
            sourcePolicy: nil,
            confirmationState: nil,
            audit: ServerProviderRuntimeDispatchAudit(
                planID: "a82-plan-\(id)",
                planState: state == .prepared ? .planned : .blocked,
                readinessID: "a82-readiness-\(id)",
                lookupID: "a82-lookup-\(id)",
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

    private func manifestSetValidation(
        state: ServerProviderRuntimeAdapterManifestSetValidationState,
        registered: [ProviderFamily],
        accepted: [ProviderFamily],
        readinessValidation: ServerProviderRuntimeAdapterSetReadinessValidation?
    ) -> ServerProviderRuntimeAdapterManifestSetValidation {
        ServerProviderRuntimeAdapterManifestSetValidation(
            id: "a82-manifest-set-validation-\(state.rawValue)",
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
            id: "a82-adapter-set-readiness-validation-\(state.rawValue)",
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

private final class CountingConnector: ServerProviderRuntimeConnector, @unchecked Sendable {
    let providerFamily: ProviderFamily

    private let lock = NSLock()
    private var count = 0

    nonisolated init(providerFamily: ProviderFamily) {
        self.providerFamily = providerFamily
    }

    var prepareCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    nonisolated func prepare(
        _ request: ServerProviderRuntimeConnectorRequest
    ) -> ServerProviderRuntimeConnectorResult {
        lock.lock()
        count += 1
        lock.unlock()

        return MetadataOnlyServerProviderRuntimeConnector(
            providerFamily: providerFamily
        ).prepare(request)
    }
}
