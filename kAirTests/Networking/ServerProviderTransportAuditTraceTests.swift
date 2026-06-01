//
//  ServerProviderTransportAuditTraceTests.swift
//  kAirTests
//
//  A140 external provider transport audit trace contract tests.
//

import XCTest
@testable import kAir

final class ServerProviderTransportAuditTraceTests: XCTestCase {

    func test_acceptsAllPlannedProviderFamiliesAsValueOnlyAuditEvents() throws {
        let cases: [
            (
                name: String,
                request: ServerProviderTransportAuditRequest
            )
        ] = [
            (
                "search",
                request(
                    family: .searchAPI,
                    capability: .webSearch,
                    costClass: .meteredPremium,
                    sourcePolicySummary: sourcePolicy()
                )
            ),
            (
                "gaode",
                request(
                    family: .gaode,
                    capability: .placeSearch,
                    costClass: .includedQuota,
                    sourcePolicySummary: attributionPolicy()
                )
            ),
            (
                "google",
                request(
                    family: .googleMaps,
                    capability: .routePlanning,
                    costClass: .meteredPremium,
                    sourcePolicySummary: attributionPolicy()
                )
            ),
            (
                "crawler",
                request(
                    family: .crawler,
                    capability: .crawlerFetch,
                    costClass: .meteredPremium,
                    sourcePolicySummary: sourcePolicy(robotsState: .allowed),
                    enabledReservedProviderFamilies: [.crawler]
                )
            ),
            (
                "mcp",
                request(
                    family: .mcp,
                    capability: .mcpTool,
                    costClass: .includedQuota,
                    confirmationState: .confirmed(artifactID: "a140-mcp-confirmed"),
                    enabledReservedProviderFamilies: [.mcp]
                )
            ),
            (
                "remote model",
                request(
                    family: .remoteModel,
                    capability: .remoteModelCompletion,
                    costClass: .meteredPremium,
                    confirmationState: .confirmed(artifactID: "a140-model-confirmed"),
                    requiresUserConfirmation: true
                )
            ),
        ]

        for testCase in cases {
            let event = ServerProviderTransportAuditTraceBuilder.evaluate(testCase.request)
            let repeated = ServerProviderTransportAuditTraceBuilder.evaluate(testCase.request)
            let trace = try XCTUnwrap(event.trace, testCase.name)

            assertSendable(event)
            assertSendable(trace)
            XCTAssertEqual(event, repeated, testCase.name)
            XCTAssertTrue(event.isAccepted, testCase.name)
            XCTAssertEqual(event.state, .accepted, testCase.name)
            XCTAssertNil(event.rejectionReason, testCase.name)
            XCTAssertEqual(trace.providerFamily, testCase.request.providerFamily, testCase.name)
            XCTAssertEqual(trace.capability, testCase.request.capability, testCase.name)
            XCTAssertEqual(trace.membershipTier, .pro, testCase.name)
            XCTAssertEqual(trace.privacyClass, .general, testCase.name)
            XCTAssertEqual(trace.statusSourceID, "a140-status-source", testCase.name)
            XCTAssertEqual(trace.selectedStatusSourceRank, 1, testCase.name)
            XCTAssertEqual(
                trace.evaluationDimensions,
                ServerProviderTransportAuditEvaluationDimension.requiredSet,
                testCase.name
            )
            XCTAssertEqual(
                event.safeCopy.evaluationDimensionIDs,
                ServerProviderTransportAuditEvaluationDimension.requiredSet
                    .map(\.rawValue)
                    .sorted(),
                testCase.name
            )
            XCTAssertTrue(event.statusLine.contains("value-only metadata"), testCase.name)
            XCTAssertTrue(event.statusLine.contains("No provider transport has run"), testCase.name)
            assertSafeCopy(event, testCase.name)
        }
    }

    func test_rejectsMissingPolicyUnsupportedCostPrivacyReservedConfirmationAndUnsafeMaterial() {
        let cases: [
            (
                name: String,
                request: ServerProviderTransportAuditRequest,
                expected: ServerProviderTransportAuditRejectionReason
            )
        ] = [
            (
                "missing rendered id",
                request(renderedRecommendationID: " ", family: .searchAPI, sourcePolicySummary: sourcePolicy()),
                .missingRenderedRecommendationID
            ),
            (
                "missing status source",
                request(family: .searchAPI, sourcePolicySummary: sourcePolicy(), statusSourceID: ""),
                .missingStatusSource
            ),
            (
                "missing privacy policy",
                request(family: .searchAPI, privacyClass: nil, sourcePolicySummary: sourcePolicy()),
                .missingPrivacyPolicy
            ),
            (
                "missing source policy",
                request(family: .searchAPI, sourcePolicySummary: nil),
                .missingSourcePolicy
            ),
            (
                "missing citation policy",
                request(
                    family: .searchAPI,
                    sourcePolicySummary: sourcePolicy(citationPolicyPresent: false)
                ),
                .missingCitationPolicy
            ),
            (
                "missing attribution policy",
                request(
                    family: .googleMaps,
                    capability: .placeSearch,
                    costClass: .meteredPremium,
                    sourcePolicySummary: attributionPolicy(attributionPolicyPresent: false)
                ),
                .missingAttributionPolicy
            ),
            (
                "unsupported capability",
                request(
                    family: .googleMaps,
                    capability: .webSearch,
                    costClass: .meteredPremium,
                    sourcePolicySummary: attributionPolicy()
                ),
                .unsupportedCapability
            ),
            (
                "blocked cost",
                request(
                    family: .searchAPI,
                    costClass: .blockedByCost,
                    sourcePolicySummary: sourcePolicy()
                ),
                .blockedCostClass
            ),
            (
                "blocked privacy",
                request(
                    family: .searchAPI,
                    privacyClass: .health,
                    sourcePolicySummary: sourcePolicy()
                ),
                .blockedPrivacyClass
            ),
            (
                "disabled crawler",
                request(
                    family: .crawler,
                    capability: .crawlerFetch,
                    costClass: .meteredPremium,
                    sourcePolicySummary: sourcePolicy(robotsState: .allowed)
                ),
                .reservedProviderDisabled
            ),
            (
                "disabled mcp",
                request(
                    family: .mcp,
                    capability: .mcpTool,
                    costClass: .includedQuota,
                    confirmationState: .confirmed(artifactID: "a140-mcp-confirmed")
                ),
                .reservedProviderDisabled
            ),
            (
                "confirmation missing",
                request(
                    family: .mcp,
                    capability: .mcpTool,
                    costClass: .includedQuota,
                    confirmationState: .requiredMissing,
                    enabledReservedProviderFamilies: [.mcp]
                ),
                .userConfirmationMissing
            ),
            (
                "missing dimension",
                request(
                    family: .searchAPI,
                    sourcePolicySummary: sourcePolicy(),
                    evaluationDimensions: [.latency, .cost]
                ),
                .missingEvaluationDimension
            ),
            (
                "unsafe material",
                request(
                    family: .searchAPI,
                    sourcePolicySummary: sourcePolicy(),
                    unsafeRuntimeMaterial: unsafeFragments()
                ),
                .unsafeRuntimeMaterial
            ),
        ]

        for testCase in cases {
            let event = ServerProviderTransportAuditTraceBuilder.evaluate(testCase.request)

            XCTAssertFalse(event.isAccepted, testCase.name)
            XCTAssertEqual(event.state, .rejected, testCase.name)
            XCTAssertNil(event.trace, testCase.name)
            XCTAssertEqual(event.rejectionReason, testCase.expected, testCase.name)
            XCTAssertEqual(event.safeCopy.rejectionReason, testCase.expected, testCase.name)
            XCTAssertTrue(event.statusLine.contains(testCase.expected.rawValue), testCase.name)
            XCTAssertTrue(event.statusLine.contains("No provider transport has run"), testCase.name)
            assertSafeCopy(event, testCase.name)
        }
    }

    func test_safeCopyAndEncodingAreStableAndDoNotCarryRuntimeMaterial() throws {
        let request = request(
            family: .searchAPI,
            capability: .localServiceSearch,
            costClass: .meteredPremium,
            sourcePolicySummary: sourcePolicy(),
            selectedStatusSourceRank: 2
        )
        let event = ServerProviderTransportAuditTraceBuilder.evaluate(request)
        let repeated = ServerProviderTransportAuditTraceBuilder.evaluate(request)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let encoded = String(
            decoding: try encoder.encode(event.safeCopy),
            as: UTF8.self
        )
        let repeatedEncoded = String(
            decoding: try encoder.encode(repeated.safeCopy),
            as: UTF8.self
        )

        XCTAssertEqual(event.safeCopy, repeated.safeCopy)
        XCTAssertEqual(encoded, repeatedEncoded)
        XCTAssertEqual(event.safeCopy.renderedRecommendationID, "a140-card")
        XCTAssertEqual(event.safeCopy.statusSourceID, "a140-status-source")
        XCTAssertEqual(event.safeCopy.selectedStatusSourceRank, 2)
        XCTAssertEqual(event.safeCopy.sourcePolicyID, "a140-source-policy")
        assertSafeString(encoded, "encoded safe copy")
        assertSafeCopy(event, "event")
    }

    func test_evaluationDimensionsAreReviewLabelsNotMeasurements() throws {
        let event = ServerProviderTransportAuditTraceBuilder.evaluate(
            request(
                family: .remoteModel,
                capability: .remoteModelCompletion,
                costClass: .meteredPremium,
                confirmationState: .confirmed(artifactID: "a140-remote-confirmed"),
                requiresUserConfirmation: true
            )
        )
        let trace = try XCTUnwrap(event.trace)

        XCTAssertEqual(
            trace.evaluationDimensions,
            [
                .latency,
                .cost,
                .sourceQuality,
                .citationAttribution,
                .privacy,
                .fallback,
                .userConfirmation,
                .safety,
            ]
        )
        XCTAssertEqual(
            event.safeCopy.evaluationDimensionIDs,
            [
                "citationAttribution",
                "cost",
                "fallback",
                "latency",
                "privacy",
                "safety",
                "sourceQuality",
                "userConfirmation",
            ]
        )
        assertSafeCopy(event, "remote model")
    }

    private func request(
        renderedRecommendationID: String = "a140-card",
        family: ServerProviderTransportAuditFamily,
        capability: ServerProviderTransportAuditCapability = .webSearch,
        membershipTier: MembershipTier = .pro,
        costClass: ProviderCostClass = .meteredPremium,
        privacyClass: ProviderPrivacyClass? = .general,
        sourcePolicySummary: ServerProviderTransportAuditSourcePolicySummary? = nil,
        statusSourceID: String = "a140-status-source",
        selectedStatusSourceRank: Int = 1,
        confirmationState: ServerConfirmationState = .notRequired,
        requiresUserConfirmation: Bool = false,
        enabledReservedProviderFamilies: Set<ServerProviderTransportAuditFamily> = [],
        evaluationDimensions: Set<ServerProviderTransportAuditEvaluationDimension> =
            ServerProviderTransportAuditEvaluationDimension.requiredSet,
        unsafeRuntimeMaterial: [String] = []
    ) -> ServerProviderTransportAuditRequest {
        ServerProviderTransportAuditRequest(
            renderedRecommendationID: renderedRecommendationID,
            providerFamily: family,
            capability: capability,
            membershipTier: membershipTier,
            costClass: costClass,
            privacyClass: privacyClass,
            sourcePolicySummary: sourcePolicySummary,
            statusSourceID: statusSourceID,
            selectedStatusSourceRank: selectedStatusSourceRank,
            confirmationState: confirmationState,
            requiresUserConfirmation: requiresUserConfirmation,
            enabledReservedProviderFamilies: enabledReservedProviderFamilies,
            evaluationDimensions: evaluationDimensions,
            unsafeRuntimeMaterial: unsafeRuntimeMaterial
        )
    }

    private func sourcePolicy(
        robotsState: SearchRobotsState = .notApplicable,
        citationPolicyPresent: Bool = true,
        attributionPolicyPresent: Bool = true
    ) -> ServerProviderTransportAuditSourcePolicySummary {
        ServerProviderTransportAuditSourcePolicySummary(
            id: "a140-source-policy",
            sourceState: .passed,
            robotsState: robotsState,
            sourcePolicyRequired: true,
            citationPolicyRequired: true,
            citationPolicyPresent: citationPolicyPresent,
            attributionPolicyRequired: true,
            attributionPolicyPresent: attributionPolicyPresent
        )
    }

    private func attributionPolicy(
        attributionPolicyPresent: Bool = true
    ) -> ServerProviderTransportAuditSourcePolicySummary {
        ServerProviderTransportAuditSourcePolicySummary(
            id: "a140-attribution-policy",
            sourceState: .notApplicable,
            sourcePolicyRequired: false,
            citationPolicyRequired: false,
            citationPolicyPresent: false,
            attributionPolicyRequired: true,
            attributionPolicyPresent: attributionPolicyPresent
        )
    }

    private func unsafeFragments() -> [String] {
        [
            "http" + "s://provider.example/item",
            "api" + "Key=secret",
            "O" + "Auth bearer",
            "URL" + "Session live client",
            "S" + "DK handle",
            "MCP" + "Client descriptor",
            "Store" + "Kit receipt",
            "book" + "ing id",
            "pay" + "ment token",
            "raw" + "Query text",
            "raw" + "Page body",
            "provider" + "Payload body",
            "exec" + "ution complete",
        ]
    }

    private func assertSafeCopy(
        _ event: ServerProviderTransportAuditEvent,
        _ label: String
    ) {
        assertSafeString(event.statusLine, "\(label) status")
        assertSafeString(event.description, "\(label) description")
        let encoded = String(
            decoding: try! JSONEncoder().encode(event.safeCopy),
            as: UTF8.self
        )
        assertSafeString(encoded, "\(label) safe copy")
    }

    private func assertSafeString(
        _ value: String,
        _ label: String
    ) {
        for fragment in unsafeFragments() {
            XCTAssertFalse(
                value.lowercased().contains(fragment.lowercased()),
                "\(label) contains \(fragment)"
            )
        }
    }

    private func assertSendable<T: Sendable>(
        _ value: T,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        _ = value
        XCTAssertTrue(true, file: file, line: line)
    }
}
