//
//  ServerProviderTransportAuditTraceStatusSourceProducerTests.swift
//  kAirTests
//
//  A141 transport audit event status-source proof tests.
//

import XCTest
@testable import kAir

@MainActor
final class ServerProviderTransportAuditTraceStatusSourceProducerTests: XCTestCase {

    func test_acceptedAuditEventsPackageRenderedStatusForAllFamilies() throws {
        let cases: [
            (
                name: String,
                event: ServerProviderTransportAuditEvent,
                expectedHint: ProviderStatusCardHint,
                expectedCostBadge: ProviderStatusBadgeKind,
                expectedFragments: [String]
            )
        ] = [
            (
                "search",
                acceptedEvent(
                    family: .searchAPI,
                    capability: .webSearch,
                    costClass: .meteredPremium,
                    sourcePolicySummary: sourcePolicy()
                ),
                .warning,
                .meteredPremium,
                ["searchAPI", "webSearch", "meteredPremium", "a141-status-source", "Rank: 1"]
            ),
            (
                "gaode",
                acceptedEvent(
                    family: .gaode,
                    capability: .placeSearch,
                    costClass: .includedQuota,
                    sourcePolicySummary: attributionPolicy()
                ),
                .normal,
                .includedQuota,
                ["gaode", "placeSearch", "includedQuota", "a141-status-source", "Rank: 1"]
            ),
            (
                "google",
                acceptedEvent(
                    family: .googleMaps,
                    capability: .routePlanning,
                    costClass: .meteredPremium,
                    sourcePolicySummary: attributionPolicy()
                ),
                .warning,
                .meteredPremium,
                ["googleMaps", "routePlanning", "meteredPremium", "a141-status-source", "Rank: 1"]
            ),
            (
                "crawler",
                acceptedEvent(
                    family: .crawler,
                    capability: .crawlerFetch,
                    costClass: .meteredPremium,
                    sourcePolicySummary: sourcePolicy(robotsState: .allowed),
                    enabledReservedProviderFamilies: [.crawler]
                ),
                .warning,
                .meteredPremium,
                ["crawler", "crawlerFetch", "meteredPremium", "a141-status-source", "Rank: 1"]
            ),
            (
                "mcp",
                acceptedEvent(
                    family: .mcp,
                    capability: .mcpTool,
                    costClass: .includedQuota,
                    confirmationState: .confirmed(artifactID: "a141-mcp-confirmed"),
                    enabledReservedProviderFamilies: [.mcp]
                ),
                .warning,
                .includedQuota,
                ["mcp", "mcpTool", "includedQuota", "a141-status-source", "Rank: 1"]
            ),
            (
                "remote model",
                acceptedEvent(
                    family: .remoteModel,
                    capability: .remoteModelCompletion,
                    costClass: .meteredPremium,
                    confirmationState: .confirmed(artifactID: "a141-remote-confirmed"),
                    requiresUserConfirmation: true
                ),
                .warning,
                .meteredPremium,
                [
                    "remoteModel",
                    "remoteModelCompletion",
                    "meteredPremium",
                    "a141-status-source",
                    "Rank: 1",
                ]
            ),
        ]
        let inputs = cases.map { testCase in
            ServerProviderTransportAuditTraceStatusSourceProducer.Input(
                recommendationID: "rec-\(testCase.name.replacingOccurrences(of: " ", with: "-"))",
                event: testCase.event
            )
        }
        let source = ServerProviderTransportAuditTraceStatusSourceProducer()
            .statusSource(
                inputs: inputs,
                renderedRecommendationIDs: inputs.map(\.recommendationID)
            )

        for testCase in cases {
            let recommendationID = "rec-\(testCase.name.replacingOccurrences(of: " ", with: "-"))"
            let presentation = try XCTUnwrap(
                source.providerStatusPresentation(for: recommendationID),
                testCase.name
            )

            XCTAssertEqual(presentation.cardHint, testCase.expectedHint, testCase.name)
            XCTAssertTrue(
                presentation.badges.map(\.kind).contains(.remoteProvider),
                testCase.name
            )
            XCTAssertTrue(
                presentation.badges.map(\.kind).contains(testCase.expectedCostBadge),
                testCase.name
            )
            XCTAssertTrue(
                presentation.badges.map(\.kind).contains(.liveFreshness),
                testCase.name
            )
            XCTAssertTrue(presentation.statusLine.contains("value-only metadata"), testCase.name)
            XCTAssertTrue(presentation.statusLine.contains("No provider transport has run"), testCase.name)
            XCTAssertTrue(presentation.statusLine.contains("Evaluation:"), testCase.name)
            for fragment in testCase.expectedFragments {
                XCTAssertTrue(presentation.statusLine.contains(fragment), "\(testCase.name): \(fragment)")
            }
            assertSafePresentation(presentation, testCase.name)
        }
    }

    func test_rejectedAuditEventsMapToStableDisabledStatus() throws {
        let cases: [
            (
                name: String,
                event: ServerProviderTransportAuditEvent,
                expectedBadge: ProviderStatusBadgeKind
            )
        ] = [
            (
                "missing source",
                rejectedEvent(sourcePolicySummary: nil),
                .termsBlocked
            ),
            (
                "blocked privacy",
                rejectedEvent(privacyClass: .health, sourcePolicySummary: sourcePolicy()),
                .privacyBlocked
            ),
            (
                "blocked cost",
                rejectedEvent(costClass: .blockedByCost, sourcePolicySummary: sourcePolicy()),
                .costBlocked
            ),
            (
                "reserved disabled",
                rejectedEvent(
                    family: .crawler,
                    capability: .crawlerFetch,
                    sourcePolicySummary: sourcePolicy(robotsState: .allowed)
                ),
                .unavailable
            ),
            (
                "confirmation missing",
                rejectedEvent(
                    family: .mcp,
                    capability: .mcpTool,
                    costClass: .includedQuota,
                    confirmationState: .requiredMissing,
                    enabledReservedProviderFamilies: [.mcp]
                ),
                .termsBlocked
            ),
            (
                "dimension missing",
                rejectedEvent(
                    sourcePolicySummary: sourcePolicy(),
                    evaluationDimensions: [.latency, .cost]
                ),
                .termsBlocked
            ),
            (
                "unsafe material",
                rejectedEvent(
                    sourcePolicySummary: sourcePolicy(),
                    unsafeRuntimeMaterial: unsafeFragments()
                ),
                .termsBlocked
            ),
        ]
        let inputs = cases.map { testCase in
            ServerProviderTransportAuditTraceStatusSourceProducer.Input(
                recommendationID: "rec-\(testCase.name.replacingOccurrences(of: " ", with: "-"))",
                event: testCase.event
            )
        }
        let source = ServerProviderTransportAuditTraceStatusSourceProducer()
            .statusSource(
                inputs: inputs,
                renderedRecommendationIDs: inputs.map(\.recommendationID)
            )

        for testCase in cases {
            let recommendationID = "rec-\(testCase.name.replacingOccurrences(of: " ", with: "-"))"
            let presentation = try XCTUnwrap(
                source.providerStatusPresentation(for: recommendationID),
                testCase.name
            )

            XCTAssertEqual(presentation.cardHint, .disabled, testCase.name)
            XCTAssertEqual(presentation.badges.map(\.kind), [testCase.expectedBadge], testCase.name)
            XCTAssertTrue(presentation.statusLine.contains("blocked by value-only policy"), testCase.name)
            XCTAssertTrue(presentation.statusLine.contains(testCase.event.rejectionReason!.rawValue), testCase.name)
            XCTAssertTrue(presentation.statusLine.contains("No provider transport has run"), testCase.name)
            assertSafePresentation(presentation, testCase.name)
        }
    }

    func test_duplicateIDsKeepFirstAndHiddenMissingStayNil() throws {
        let first = acceptedEvent(
            family: .searchAPI,
            capability: .webSearch,
            costClass: .meteredPremium,
            sourcePolicySummary: sourcePolicy()
        )
        let stale = rejectedEvent(
            family: .googleMaps,
            capability: .placeSearch,
            costClass: .meteredPremium,
            privacyClass: .health,
            sourcePolicySummary: attributionPolicy()
        )
        let hidden = acceptedEvent(
            family: .remoteModel,
            capability: .remoteModelCompletion,
            costClass: .meteredPremium,
            confirmationState: .confirmed(artifactID: "a141-hidden-confirmed"),
            requiresUserConfirmation: true
        )
        let source = ServerProviderTransportAuditTraceStatusSourceProducer()
            .statusSource(
                inputs: [
                    .init(recommendationID: "rec-visible", event: first),
                    .init(recommendationID: "rec-visible", event: stale),
                    .init(recommendationID: "rec-hidden", event: hidden),
                ],
                renderedRecommendationIDs: ["rec-visible"]
            )

        let presentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-visible")
        )
        XCTAssertTrue(presentation.statusLine.contains("searchAPI"))
        XCTAssertTrue(presentation.statusLine.contains("webSearch"))
        XCTAssertTrue(presentation.statusLine.contains("meteredPremium"))
        XCTAssertFalse(presentation.statusLine.contains("googleMaps"))
        XCTAssertFalse(presentation.statusLine.contains("placeSearch"))
        XCTAssertFalse(presentation.statusLine.contains("blockedPrivacyClass"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-hidden"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-missing"))
        assertSafePresentation(presentation, "first-wins")
    }

    func test_statusCopyDoesNotCarryRuntimeFragments() throws {
        let event = acceptedEvent(
            family: .searchAPI,
            capability: .localServiceSearch,
            costClass: .meteredPremium,
            sourcePolicySummary: sourcePolicy(),
            selectedStatusSourceRank: 2
        )
        let store = ServerProviderTransportAuditEventStatusStore(
            events: [(recommendationID: "rec-safe", event: event)]
        )
        let presentation = try XCTUnwrap(
            store.providerStatusPresentation(for: "rec-safe")
        )

        XCTAssertTrue(presentation.statusLine.contains("Rank: 2"))
        XCTAssertEqual(presentation.cardHint, .warning)
        assertSafePresentation(presentation, "safe projection")
        assertSafeString(event.description, "event description")
        let encoded = String(
            decoding: try JSONEncoder().encode(event.safeCopy),
            as: UTF8.self
        )
        assertSafeString(encoded, "encoded safe copy")
    }

    private func acceptedEvent(
        family: ServerProviderTransportAuditFamily,
        capability: ServerProviderTransportAuditCapability,
        membershipTier: MembershipTier = .pro,
        costClass: ProviderCostClass,
        privacyClass: ProviderPrivacyClass? = .general,
        sourcePolicySummary: ServerProviderTransportAuditSourcePolicySummary? = nil,
        statusSourceID: String = "a141-status-source",
        selectedStatusSourceRank: Int = 1,
        confirmationState: ServerConfirmationState = .notRequired,
        requiresUserConfirmation: Bool = false,
        enabledReservedProviderFamilies: Set<ServerProviderTransportAuditFamily> = [],
        evaluationDimensions: Set<ServerProviderTransportAuditEvaluationDimension> =
            ServerProviderTransportAuditEvaluationDimension.requiredSet
    ) -> ServerProviderTransportAuditEvent {
        let event = ServerProviderTransportAuditTraceBuilder.evaluate(
            request(
                family: family,
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
                evaluationDimensions: evaluationDimensions
            )
        )
        XCTAssertTrue(event.isAccepted)
        return event
    }

    private func rejectedEvent(
        family: ServerProviderTransportAuditFamily = .searchAPI,
        capability: ServerProviderTransportAuditCapability = .webSearch,
        membershipTier: MembershipTier = .pro,
        costClass: ProviderCostClass = .meteredPremium,
        privacyClass: ProviderPrivacyClass? = .general,
        sourcePolicySummary: ServerProviderTransportAuditSourcePolicySummary? = nil,
        statusSourceID: String = "a141-status-source",
        selectedStatusSourceRank: Int = 1,
        confirmationState: ServerConfirmationState = .notRequired,
        requiresUserConfirmation: Bool = false,
        enabledReservedProviderFamilies: Set<ServerProviderTransportAuditFamily> = [],
        evaluationDimensions: Set<ServerProviderTransportAuditEvaluationDimension> =
            ServerProviderTransportAuditEvaluationDimension.requiredSet,
        unsafeRuntimeMaterial: [String] = []
    ) -> ServerProviderTransportAuditEvent {
        let event = ServerProviderTransportAuditTraceBuilder.evaluate(
            request(
                family: family,
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
        )
        XCTAssertFalse(event.isAccepted)
        return event
    }

    private func request(
        family: ServerProviderTransportAuditFamily,
        capability: ServerProviderTransportAuditCapability,
        membershipTier: MembershipTier,
        costClass: ProviderCostClass,
        privacyClass: ProviderPrivacyClass?,
        sourcePolicySummary: ServerProviderTransportAuditSourcePolicySummary?,
        statusSourceID: String,
        selectedStatusSourceRank: Int,
        confirmationState: ServerConfirmationState,
        requiresUserConfirmation: Bool,
        enabledReservedProviderFamilies: Set<ServerProviderTransportAuditFamily>,
        evaluationDimensions: Set<ServerProviderTransportAuditEvaluationDimension>,
        unsafeRuntimeMaterial: [String] = []
    ) -> ServerProviderTransportAuditRequest {
        ServerProviderTransportAuditRequest(
            renderedRecommendationID: "a141-card",
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
        robotsState: SearchRobotsState = .notApplicable
    ) -> ServerProviderTransportAuditSourcePolicySummary {
        ServerProviderTransportAuditSourcePolicySummary(
            id: "a141-source-policy",
            sourceState: .passed,
            robotsState: robotsState,
            sourcePolicyRequired: true,
            citationPolicyRequired: true,
            citationPolicyPresent: true,
            attributionPolicyRequired: true,
            attributionPolicyPresent: true
        )
    }

    private func attributionPolicy() -> ServerProviderTransportAuditSourcePolicySummary {
        ServerProviderTransportAuditSourcePolicySummary(
            id: "a141-attribution-policy",
            sourceState: .notApplicable,
            sourcePolicyRequired: false,
            citationPolicyRequired: false,
            citationPolicyPresent: false,
            attributionPolicyRequired: true,
            attributionPolicyPresent: true
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

    private func assertSafePresentation(
        _ presentation: ProviderStatusPresentation,
        _ label: String
    ) {
        assertSafeString(presentation.statusLine, "\(label) status")
        for badge in presentation.badges {
            assertSafeString(badge.label, "\(label) badge label")
            assertSafeString(badge.systemImage, "\(label) badge icon")
        }
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
}
