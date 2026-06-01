//
//  ServerProviderSearchAPIVendorPolicyTests.swift
//  kAirTests
//
//  A105 Search API vendor policy matrix proof.
//

import XCTest
@testable import kAir

final class ServerProviderSearchAPIVendorPolicyTests: XCTestCase {

    func test_vendorPolicyAcceptsEligibleMetadataWithoutRuntimeExecution() throws {
        let request = try preparedRequest()
        let context = ServerProviderSearchAPIVendorPolicyContext(
            request: request,
            quotaSnapshot: meteredQuota(),
            pageBodyRequirement: .snippetsOnly,
            allowedRetention: .ephemeralOnly,
            resultShape: .organicLinks
        )
        let vendor = vendorPolicy(
            id: "balanced-search",
            costClass: .meteredPremium,
            supportedFreshness: [.cachedOK, .livePreferred],
            pageBodyMode: .optional,
            requiredRetention: .ephemeralOnly,
            supportedResultShapes: [.organicLinks, .answerSummary]
        )

        let decision = ServerProviderSearchAPIVendorPolicy.evaluate(
            context: context,
            vendor: vendor
        )
        let repeated = ServerProviderSearchAPIVendorPolicy.evaluate(
            context: context,
            vendor: vendor
        )

        assertSendable(decision)
        XCTAssertEqual(decision, repeated)
        XCTAssertEqual(Set([decision]).count, 1)
        XCTAssertEqual(decision.state, .accepted)
        XCTAssertTrue(decision.isAccepted)
        XCTAssertNil(decision.rejection)
        XCTAssertEqual(decision.vendorID, "balanced-search")
        XCTAssertEqual(decision.providerFamily, .searchAPI)
        XCTAssertEqual(decision.capability, .webSearch)
        XCTAssertEqual(decision.costClass, .meteredPremium)
        XCTAssertEqual(decision.freshness, .livePreferred)
        XCTAssertEqual(decision.resultShape, .organicLinks)
        XCTAssertTrue(decision.statusLine.contains("approved metadata only"))
        XCTAssertTrue(decision.statusLine.contains("No provider runtime has run"))
    }

    func test_vendorPolicyRejectionMatrixPreservesExplicitReasons() {
        let baseContext = vendorContext()
        let baseVendor = vendorPolicy()
        let cases: [(String, ServerProviderSearchAPIVendorPolicyContext, ServerProviderSearchAPIVendorPolicyDescriptor, ServerProviderSearchAPIVendorPolicyRejectionReason)] = [
            (
                "disabled vendor",
                baseContext,
                vendorPolicy(isEnabled: false),
                .vendorDisabled
            ),
            (
                "provider disabled",
                vendorContext(quotaSnapshot: meteredQuota(disabled: true)),
                baseVendor,
                .providerDisabled
            ),
            (
                "provider not allowed",
                vendorContext(quotaSnapshot: ServerProviderQuotaSnapshot()),
                baseVendor,
                .providerNotAllowed
            ),
            (
                "entitlement missing",
                vendorContext(
                    quotaSnapshot: ServerProviderQuotaSnapshot(
                        allowedProviderFamilies: [.searchAPI],
                        meteredEligibleProviderFamilies: [.searchAPI]
                    )
                ),
                baseVendor,
                .entitlementMissing
            ),
            (
                "included quota exhausted",
                vendorContext(
                    costClass: .includedQuota,
                    quotaSnapshot: includedQuota(remaining: 0)
                ),
                vendorPolicy(costClass: .includedQuota),
                .includedQuotaExhausted
            ),
            (
                "metered eligibility missing",
                vendorContext(
                    quotaSnapshot: ServerProviderQuotaSnapshot(
                        allowedProviderFamilies: [.searchAPI],
                        entitledProviderFamilies: [.searchAPI]
                    )
                ),
                baseVendor,
                .meteredEligibilityMissing
            ),
            (
                "cost class mismatch",
                vendorContext(costClass: .includedQuota, quotaSnapshot: includedQuota()),
                baseVendor,
                .costClassMismatch
            ),
            (
                "unsupported cost class",
                vendorContext(costClass: .blockedByCost, quotaSnapshot: meteredQuota()),
                vendorPolicy(costClass: .blockedByCost),
                .unsupportedCostClass
            ),
            (
                "unsupported freshness",
                vendorContext(freshness: .liveRequired),
                vendorPolicy(supportedFreshness: [.cachedOK]),
                .unsupportedFreshness
            ),
            (
                "citation missing",
                baseContext,
                vendorPolicy(
                    citationSupport: ServerProviderSearchAPIVendorCitationSupport(
                        supportsCitations: false,
                        supportsSourceHost: true,
                        supportsAttribution: true
                    )
                ),
                .citationSupportMissing
            ),
            (
                "source missing",
                baseContext,
                vendorPolicy(
                    citationSupport: ServerProviderSearchAPIVendorCitationSupport(
                        supportsCitations: true,
                        supportsSourceHost: false,
                        supportsAttribution: true
                    )
                ),
                .sourceSupportMissing
            ),
            (
                "attribution missing",
                baseContext,
                vendorPolicy(
                    citationSupport: ServerProviderSearchAPIVendorCitationSupport(
                        supportsCitations: true,
                        supportsSourceHost: true,
                        supportsAttribution: false
                    )
                ),
                .attributionSupportMissing
            ),
            (
                "page body not allowed",
                vendorContext(pageBodyRequirement: .snippetsOnly),
                vendorPolicy(pageBodyMode: .required),
                .pageBodyNotAllowed
            ),
            (
                "page body required unsupported",
                vendorContext(pageBodyRequirement: .required),
                vendorPolicy(pageBodyMode: .unavailable),
                .pageBodyRequiredUnsupported
            ),
            (
                "retention conflict",
                vendorContext(allowedRetention: .ephemeralOnly),
                vendorPolicy(requiredRetention: .shortTermCache),
                .retentionConflict
            ),
            (
                "privacy blocked",
                vendorContext(privacyClass: .private),
                baseVendor,
                .privacyBlocked
            ),
            (
                "health blocked",
                vendorContext(privacyClass: .health),
                baseVendor,
                .privacyBlocked
            ),
            (
                "unsupported result shape",
                vendorContext(resultShape: .localBusiness),
                vendorPolicy(supportedResultShapes: [.organicLinks]),
                .unsupportedResultShape
            ),
            (
                "provider family mismatch",
                vendorContext(providerFamily: .googleMaps),
                baseVendor,
                .providerFamilyMismatch
            ),
            (
                "unsupported capability",
                vendorContext(capability: .routePlanning),
                baseVendor,
                .unsupportedCapability
            ),
        ]

        for (id, context, vendor, expected) in cases {
            let decision = ServerProviderSearchAPIVendorPolicy.evaluate(
                context: context,
                vendor: vendor
            )

            XCTAssertEqual(decision.state, .rejected, id)
            XCTAssertFalse(decision.isAccepted, id)
            XCTAssertEqual(decision.rejection, expected, id)
            XCTAssertNil(decision.providerFamily, id)
            XCTAssertNil(decision.capability, id)
            XCTAssertNil(decision.costClass, id)
            XCTAssertNil(decision.freshness, id)
            XCTAssertNil(decision.resultShape, id)
            XCTAssertTrue(decision.statusLine.contains(expected.rawValue), id)
            XCTAssertTrue(decision.statusLine.contains("No provider runtime has run"), id)
        }
    }

    func test_vendorPolicySupportsIncludedQuotaAndLongerAllowedRetention() {
        let context = vendorContext(
            costClass: .includedQuota,
            pageBodyRequirement: .required,
            allowedRetention: .persistentCache,
            resultShape: .answerSummary,
            quotaSnapshot: includedQuota(remaining: 2)
        )
        let vendor = vendorPolicy(
            costClass: .includedQuota,
            supportedFreshness: [.cachedOK, .livePreferred],
            pageBodyMode: .optional,
            requiredRetention: .shortTermCache,
            supportedResultShapes: [.answerSummary]
        )

        let decision = ServerProviderSearchAPIVendorPolicy.evaluate(
            context: context,
            vendor: vendor
        )

        XCTAssertEqual(decision.state, .accepted)
        XCTAssertEqual(decision.costClass, .includedQuota)
        XCTAssertEqual(decision.resultShape, .answerSummary)
    }

    func test_vendorPolicyEncodingAndDebugCopyDoNotExposeSensitiveRuntimeFields() throws {
        let request = try preparedRequest()
        let context = ServerProviderSearchAPIVendorPolicyContext(
            request: request,
            quotaSnapshot: meteredQuota()
        )
        let accepted = ServerProviderSearchAPIVendorPolicy.evaluate(
            context: context,
            vendor: vendorPolicy(id: "safe-vendor")
        )
        let rejected = ServerProviderSearchAPIVendorPolicy.evaluate(
            context: vendorContext(privacyClass: .private),
            vendor: vendorPolicy(id: "blocked-vendor")
        )
        let text = [
            try encodedString(accepted),
            try encodedString(rejected),
            try encodedString(vendorPolicy(id: "encoded-vendor")),
            accepted.description,
            rejected.description,
            accepted.statusLine,
            rejected.statusLine,
        ]
            .joined(separator: "\n")
            .lowercased()

        XCTAssertTrue(text.contains("metadata only"))
        XCTAssertTrue(text.contains("no provider runtime has run"))
        XCTAssertFalse(text.contains("public coffee"))
        for forbidden in sensitiveRuntimeFragments() + executionClaimFragments() {
            XCTAssertFalse(text.contains(forbidden), "Unexpected vendor policy field or wording: \(forbidden)")
        }
    }

    private func preparedRequest(
        freshness: ProviderFreshness = .livePreferred
    ) throws -> ServerProviderSearchAPIAdapterRequest {
        let decision = ServerProviderSearchAPIAdapterContract.prepareRequest(
            envelope: searchEnvelope(freshness: freshness),
            connectorReceipt: connectorReceipt(freshness: freshness),
            query: ServerProviderSearchAPIAdapterQuery(text: "public coffee"),
            resultLimit: 4
        )
        XCTAssertEqual(decision.state, .requestPrepared)
        return try XCTUnwrap(decision.request)
    }

    private func vendorContext(
        providerFamily: ProviderFamily = .searchAPI,
        capability: ProviderCapability = .webSearch,
        privacyClass: ProviderPrivacyClass = .general,
        costClass: ProviderCostClass = .meteredPremium,
        freshness: ProviderFreshness = .livePreferred,
        citationRequired: Bool = true,
        sourceHostRequired: Bool = true,
        pageBodyRequirement: ServerProviderSearchAPIPageBodyRequirement = .snippetsOnly,
        allowedRetention: ServerProviderSearchAPIRetentionLevel = .ephemeralOnly,
        resultShape: ServerProviderSearchAPIVendorResultShape = .organicLinks,
        quotaSnapshot: ServerProviderQuotaSnapshot = ServerProviderQuotaSnapshot(
            allowedProviderFamilies: [.searchAPI],
            entitledProviderFamilies: [.searchAPI],
            meteredEligibleProviderFamilies: [.searchAPI]
        )
    ) -> ServerProviderSearchAPIVendorPolicyContext {
        ServerProviderSearchAPIVendorPolicyContext(
            providerFamily: providerFamily,
            capability: capability,
            privacyClass: privacyClass,
            costClass: costClass,
            freshness: freshness,
            citationRequired: citationRequired,
            sourceHostRequired: sourceHostRequired,
            pageBodyRequirement: pageBodyRequirement,
            allowedRetention: allowedRetention,
            resultShape: resultShape,
            quotaSnapshot: quotaSnapshot
        )
    }

    private func vendorPolicy(
        id: String = "test-vendor",
        isEnabled: Bool = true,
        costClass: ProviderCostClass = .meteredPremium,
        supportedFreshness: Set<ProviderFreshness> = [.cachedOK, .livePreferred, .liveRequired],
        citationSupport: ServerProviderSearchAPIVendorCitationSupport = .full,
        pageBodyMode: ServerProviderSearchAPIVendorPageBodyMode = .optional,
        requiredRetention: ServerProviderSearchAPIRetentionLevel = .ephemeralOnly,
        supportedResultShapes: Set<ServerProviderSearchAPIVendorResultShape> = [
            .organicLinks,
            .answerSummary,
            .documentSnippets,
        ]
    ) -> ServerProviderSearchAPIVendorPolicyDescriptor {
        ServerProviderSearchAPIVendorPolicyDescriptor(
            id: id,
            isEnabled: isEnabled,
            costClass: costClass,
            supportedFreshness: supportedFreshness,
            citationSupport: citationSupport,
            pageBodyMode: pageBodyMode,
            requiredRetention: requiredRetention,
            supportedResultShapes: supportedResultShapes
        )
    }

    private func meteredQuota(
        disabled: Bool = false
    ) -> ServerProviderQuotaSnapshot {
        ServerProviderQuotaSnapshot(
            allowedProviderFamilies: [.searchAPI],
            entitledProviderFamilies: [.searchAPI],
            meteredEligibleProviderFamilies: [.searchAPI],
            disabledProviderFamilies: disabled ? [.searchAPI] : []
        )
    }

    private func includedQuota(
        remaining: Int = 1
    ) -> ServerProviderQuotaSnapshot {
        ServerProviderQuotaSnapshot(
            allowedProviderFamilies: [.searchAPI],
            entitledProviderFamilies: [.searchAPI],
            remainingIncludedQuota: [.searchAPI: remaining]
        )
    }

    private func searchEnvelope(
        freshness: ProviderFreshness = .livePreferred
    ) -> ServerProviderEnvelope {
        ServerProviderEnvelope(
            traceID: "a105-search-trace",
            capability: .webSearch,
            providerFamily: .searchAPI,
            privacyClass: .general,
            membershipTier: .plus,
            costClass: .meteredPremium,
            freshness: freshness,
            sourcePolicy: ServerSourcePolicy(
                sourceState: .passed,
                attributionRequired: true,
                sourceHost: "example.com"
            ),
            confirmationState: .notRequired,
            meteredProviderEntitlements: [.searchAPI],
            enabledExperimentalProviders: []
        )
    }

    private func connectorReceipt(
        freshness: ProviderFreshness = .livePreferred
    ) -> ServerProviderRuntimeConnectorInvocationReceipt {
        ServerProviderRuntimeConnectorInvocationReceipt(
            id: "a105-connector-receipt",
            state: .receiptPrepared,
            statusLine: "A105 connector receipt fixture is metadata only. No provider runtime has run.",
            planningID: "a105-planning",
            planningState: .requestPrepared,
            planningRejection: nil,
            connectorProviderFamily: .searchAPI,
            requestID: "a105-connector-request",
            resultID: "a105-connector-result",
            connectorResultState: .metadataPrepared,
            connectorRejection: nil,
            providerFamily: .searchAPI,
            capability: .webSearch,
            costClass: .meteredPremium,
            freshness: freshness,
            manifestID: "provider-runtime-adapter-manifest-searchAPI",
            authorizationID: "a105-authorization",
            boundaryID: "a105-boundary",
            traceID: "a105-search-trace",
            invocationRejection: nil
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
            "api" + "key",
            "api" + "_" + "key",
            "bear" + "er",
            "tok" + "en",
            "oa" + "uth",
            "s" + "dk",
            "raw" + "prompt",
            "raw prompt",
            "raw" + " page",
            "raw" + "content",
            "raw" + "source",
            "healthkit",
            "blood",
            "secret",
            "merchant",
            "order",
            "pay" + "ment",
            "provider" + " raw",
        ]
    }

    private func executionClaimFragments() -> [String] {
        [
            "completed",
            "contact" + "ed",
            "fetch" + "ed",
            "crawl" + "ed",
            "book" + "ed",
            "ordered",
            "paid",
        ]
    }
}
