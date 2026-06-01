//
//  ServerProviderRuntimeConnectorStatusSourceProducerTests.swift
//  kAirTests
//
//  A83 connector receipt status-source proof tests.
//

import XCTest
@testable import kAir

@MainActor
final class ServerProviderRuntimeConnectorStatusSourceProducerTests: XCTestCase {

    func test_acceptedReceiptsPackageByRenderedRecommendationIDAsAdvisoryStatus() throws {
        let source = ServerProviderRuntimeConnectorStatusSourceProducer().statusSource(
            receipts: [
                .init(
                    recommendationID: "rec-visible",
                    receipt: acceptedReceipt(
                        providerFamily: .searchAPI,
                        capability: .webSearch,
                        costClass: .meteredPremium,
                        freshness: .liveRequired
                    )
                ),
                .init(
                    recommendationID: "rec-hidden",
                    receipt: acceptedReceipt(
                        providerFamily: .gaode,
                        capability: .localServiceSearch,
                        costClass: .includedQuota,
                        freshness: .livePreferred
                    )
                ),
            ],
            renderedRecommendationIDs: ["rec-visible"]
        )

        let presentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-visible")
        )
        XCTAssertNil(source.providerStatusPresentation(for: "rec-hidden"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-missing"))
        XCTAssertEqual(source.renderedRecommendationIDs, ["rec-visible"])
        XCTAssertEqual(presentation.recommendationID, "rec-visible")
        XCTAssertEqual(presentation.cardHint, .warning)
        XCTAssertNotNil(badge(.remoteProvider, in: presentation))
        XCTAssertNotNil(badge(.meteredPremium, in: presentation))
        XCTAssertNotNil(badge(.liveFreshness, in: presentation))
        XCTAssertTrue(presentation.statusLine.contains("metadata only"))
        XCTAssertTrue(presentation.statusLine.contains("Provider family: searchAPI"))
        XCTAssertTrue(presentation.statusLine.contains("Cost: meteredPremium"))
        XCTAssertTrue(presentation.statusLine.contains("Freshness: liveRequired"))
        XCTAssertTrue(presentation.statusLine.contains("No provider runtime has run"))
    }

    func test_rejectedReceiptsPackageAsNonSuccessWithoutProviderMetadataLeakage() throws {
        let source = ServerProviderRuntimeConnectorStatusSourceProducer().statusSource(
            receipts: [
                .init(
                    recommendationID: "rec-planning",
                    receipt: rejectedReceipt(
                        invocationRejection: .planningRejected,
                        connectorRejection: nil,
                        connectorProviderFamily: .searchAPI
                    )
                ),
                .init(
                    recommendationID: "rec-mismatch",
                    receipt: rejectedReceipt(
                        invocationRejection: .connectorRejected,
                        connectorRejection: .connectorProviderFamilyMismatch,
                        connectorProviderFamily: .googleMaps
                    )
                ),
            ],
            renderedRecommendationIDs: ["rec-planning", "rec-mismatch"]
        )

        let planning = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-planning")
        )
        let mismatch = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-mismatch")
        )

        for presentation in [planning, mismatch] {
            XCTAssertEqual(presentation.cardHint, .disabled)
            XCTAssertNotNil(badge(.unavailable, in: presentation))
            XCTAssertNil(badge(.remoteProvider, in: presentation))
            XCTAssertTrue(presentation.statusLine.contains("Connector receipt is unavailable"))
            XCTAssertTrue(presentation.statusLine.contains("No provider runtime has run"))
            XCTAssertFalse(presentation.statusLine.localizedCaseInsensitiveContains("searchapi"))
            XCTAssertFalse(presentation.statusLine.localizedCaseInsensitiveContains("googlemaps"))
            XCTAssertFalse(presentation.statusLine.localizedCaseInsensitiveContains("manifest"))
            XCTAssertFalse(presentation.statusLine.localizedCaseInsensitiveContains("authorization"))
            XCTAssertFalse(presentation.statusLine.localizedCaseInsensitiveContains("trace"))
        }
        XCTAssertTrue(planning.statusLine.contains("planningRejected"))
        XCTAssertTrue(mismatch.statusLine.contains("connectorProviderFamilyMismatch"))
    }

    func test_duplicateRecommendationIDsKeepFirstReceiptAndMissingIDsReturnNil() throws {
        let source = ServerProviderRuntimeConnectorStatusSourceProducer().statusSource(
            receipts: [
                .init(
                    recommendationID: "rec-duplicate",
                    receipt: acceptedReceipt(
                        providerFamily: .searchAPI,
                        capability: .webSearch,
                        costClass: .meteredPremium,
                        freshness: .liveRequired
                    )
                ),
                .init(
                    recommendationID: "rec-duplicate",
                    receipt: acceptedReceipt(
                        providerFamily: .gaode,
                        capability: .localServiceSearch,
                        costClass: .includedQuota,
                        freshness: .livePreferred
                    )
                ),
            ],
            renderedRecommendationIDs: ["rec-duplicate"]
        )

        let presentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-duplicate")
        )
        XCTAssertTrue(presentation.statusLine.contains("Provider family: searchAPI"))
        XCTAssertFalse(presentation.statusLine.contains("Provider family: gaode"))
        XCTAssertNotNil(badge(.meteredPremium, in: presentation))
        XCTAssertNil(badge(.includedQuota, in: presentation))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-missing"))
    }

    func test_statusSourceCopyStaysAdvisoryOnly() throws {
        let store = ServerProviderRuntimeConnectorReceiptStatusStore(
            receipts: [
                (
                    recommendationID: "rec-accepted",
                    receipt: acceptedReceipt(
                        providerFamily: .searchAPI,
                        capability: .webSearch,
                        costClass: .meteredPremium,
                        freshness: .livePreferred
                    )
                ),
                (
                    recommendationID: "rec-rejected",
                    receipt: rejectedReceipt(
                        invocationRejection: .connectorRejected,
                        connectorRejection: .connectorProviderFamilyMismatch,
                        connectorProviderFamily: .googleMaps
                    )
                ),
            ]
        )
        let accepted = try XCTUnwrap(
            store.providerStatusPresentation(for: "rec-accepted")
        )
        let rejected = try XCTUnwrap(
            store.providerStatusPresentation(for: "rec-rejected")
        )
        let text = [
            accepted.statusLine,
            rejected.statusLine,
            accepted.badges.map(\.label).joined(separator: " "),
            rejected.badges.map(\.label).joined(separator: " "),
        ]
            .joined(separator: "\n")
            .lowercased()

        XCTAssertTrue(text.contains("metadata only"))
        XCTAssertTrue(text.contains("no provider runtime has run"))
        for forbidden in sensitiveRuntimeFragments() + advisoryForbiddenFragments() {
            XCTAssertFalse(text.contains(forbidden), "Unexpected status-source wording: \(forbidden)")
        }
    }

    private func acceptedReceipt(
        providerFamily: ProviderFamily,
        capability: ProviderCapability,
        costClass: ProviderCostClass,
        freshness: ProviderFreshness
    ) -> ServerProviderRuntimeConnectorInvocationReceipt {
        ServerProviderRuntimeConnectorInvocationReceipt(
            id: "a83-accepted-\(providerFamily.rawValue)",
            state: .receiptPrepared,
            statusLine: "A83 accepted receipt fixture is metadata only. No provider runtime has run.",
            planningID: "a83-planning-\(providerFamily.rawValue)",
            planningState: .requestPrepared,
            planningRejection: nil,
            connectorProviderFamily: providerFamily,
            requestID: "a83-request-\(providerFamily.rawValue)",
            resultID: "a83-result-\(providerFamily.rawValue)",
            connectorResultState: .metadataPrepared,
            connectorRejection: nil,
            providerFamily: providerFamily,
            capability: capability,
            costClass: costClass,
            freshness: freshness,
            manifestID: "a83-manifest-\(providerFamily.rawValue)",
            authorizationID: "a83-authorization-\(providerFamily.rawValue)",
            boundaryID: "a83-boundary-\(providerFamily.rawValue)",
            traceID: "a83-trace-\(providerFamily.rawValue)",
            invocationRejection: nil
        )
    }

    private func rejectedReceipt(
        invocationRejection: ServerProviderRuntimeConnectorInvocationRejectionReason,
        connectorRejection: ServerProviderRuntimeConnectorRejectionReason?,
        connectorProviderFamily: ProviderFamily
    ) -> ServerProviderRuntimeConnectorInvocationReceipt {
        ServerProviderRuntimeConnectorInvocationReceipt(
            id: "a83-rejected-\(connectorProviderFamily.rawValue)-\(invocationRejection.rawValue)",
            state: .rejected,
            statusLine: "A83 rejected receipt fixture is metadata only. No provider runtime has run.",
            planningID: "a83-rejected-planning",
            planningState: .rejected,
            planningRejection: .nonPreparedBoundary,
            connectorProviderFamily: connectorProviderFamily,
            requestID: connectorRejection == nil ? nil : "a83-rejected-request",
            resultID: connectorRejection == nil ? nil : "a83-rejected-result",
            connectorResultState: connectorRejection == nil ? nil : .rejected,
            connectorRejection: connectorRejection,
            providerFamily: nil,
            capability: nil,
            costClass: nil,
            freshness: nil,
            manifestID: nil,
            authorizationID: nil,
            boundaryID: "a83-rejected-boundary",
            traceID: nil,
            invocationRejection: invocationRejection
        )
    }

    private func badge(
        _ kind: ProviderStatusBadgeKind,
        in presentation: ProviderStatusPresentation
    ) -> ProviderStatusBadgeModel? {
        presentation.badges.first { $0.kind == kind }
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
