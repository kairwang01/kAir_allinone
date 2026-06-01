//
//  ServerProviderSearchAPILiveProviderInvocationEnvelopeStatusSourceProducerTests.swift
//  kAirTests
//
//  A166 Search API live provider invocation envelope status-source proof tests.
//

import XCTest
@testable import kAir

@MainActor
final class ServerProviderSearchAPILiveProviderInvocationEnvelopeStatusSourceProducerTests:
    XCTestCase
{

    func test_preparedAndRejectedEnvelopesPackageRenderedStatus() throws {
        let prepared = preparedEnvelope(envelopeID: "primary-envelope")
        let rejected = rejectedEnvelope(serverSecretMode: .clientProvided)
        let source = ServerProviderSearchAPILiveProviderInvocationEnvelopeStatusSourceProducer()
            .statusSource(
                inputs: [
                    .init(
                        recommendationID: "rec-prepared",
                        statusSourceID: "a166-source",
                        statusSourceRank: 3,
                        decision: prepared
                    ),
                    .init(
                        recommendationID: "rec-rejected",
                        statusSourceID: "a166-source",
                        statusSourceRank: 3,
                        decision: rejected
                    ),
                ],
                renderedRecommendationIDs: ["rec-rejected", "rec-prepared"]
            )

        let preparedPresentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-prepared")
        )
        XCTAssertEqual(source.renderedRecommendationIDs, ["rec-prepared", "rec-rejected"])
        XCTAssertEqual(preparedPresentation.cardHint, .warning)
        XCTAssertEqual(
            preparedPresentation.badges.map(\.kind),
            [.remoteProvider, .meteredPremium, .includedQuota, .liveFreshness]
        )
        XCTAssertEqual(badge(.remoteProvider, in: preparedPresentation)?.label, "Search API envelope")
        XCTAssertEqual(badge(.meteredPremium, in: preparedPresentation)?.label, "Cost unit request")
        XCTAssertEqual(badge(.includedQuota, in: preparedPresentation)?.label, "Envelope policy")
        XCTAssertEqual(badge(.liveFreshness, in: preparedPresentation)?.label, "Source retained")
        XCTAssertTrue(preparedPresentation.statusLine.contains("invocation envelope is advisory only"))
        XCTAssertTrue(preparedPresentation.statusLine.contains("Envelope: primary-envelope"))
        XCTAssertTrue(preparedPresentation.statusLine.contains("Preflight: a166-preflight"))
        XCTAssertTrue(preparedPresentation.statusLine.contains("Adapter: a166-adapter"))
        XCTAssertTrue(preparedPresentation.statusLine.contains("Vendor: a166-vendor"))
        XCTAssertTrue(preparedPresentation.statusLine.contains("Budget: a166-budget-snapshot"))
        XCTAssertTrue(preparedPresentation.statusLine.contains("Status source: a166-source"))
        XCTAssertTrue(preparedPresentation.statusLine.contains("Rank: 3"))
        XCTAssertTrue(preparedPresentation.statusLine.contains("Source: passed"))
        XCTAssertTrue(preparedPresentation.statusLine.contains("Retention: ephemeralOnly"))
        XCTAssertTrue(preparedPresentation.statusLine.contains("isRuntimeCallable false"))
        XCTAssertTrue(preparedPresentation.statusLine.contains("isExecutable false"))
        XCTAssertTrue(preparedPresentation.statusLine.contains("No transport or provider runtime has run"))
        assertSafePresentation(preparedPresentation, "prepared")

        let rejectedPresentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-rejected")
        )
        XCTAssertEqual(rejected.state, .rejected)
        XCTAssertEqual(rejectedPresentation.cardHint, .disabled)
        XCTAssertEqual(rejectedPresentation.badges.map(\.kind), [.termsBlocked])
        XCTAssertEqual(badge(.termsBlocked, in: rejectedPresentation)?.label, "Provider blocked")
        XCTAssertTrue(rejectedPresentation.statusLine.contains("disabled by envelope policy"))
        XCTAssertTrue(rejectedPresentation.statusLine.contains("serverSecretModeNotServerOwned"))
        XCTAssertTrue(rejectedPresentation.statusLine.contains("Status source: a166-source"))
        XCTAssertTrue(rejectedPresentation.statusLine.contains("isRuntimeCallable false"))
        XCTAssertTrue(rejectedPresentation.statusLine.contains("isExecutable false"))
        XCTAssertTrue(rejectedPresentation.statusLine.contains("No transport or provider runtime has run"))
        assertSafePresentation(rejectedPresentation, "rejected")
    }

    func test_duplicateRecommendationIDsKeepFirstAndHiddenMissingStayNil() throws {
        let first = preparedEnvelope(envelopeID: "first-envelope")
        let second = rejectedEnvelope(envelopeID: "second-envelope", quotaRateClass: .unavailable)
        let hidden = preparedEnvelope(envelopeID: "hidden-envelope")
        let source = ServerProviderSearchAPILiveProviderInvocationEnvelopeStatusSourceProducer()
            .statusSource(
                inputs: [
                    .init(
                        recommendationID: "rec-visible",
                        statusSourceID: "a166-first",
                        statusSourceRank: 1,
                        decision: first
                    ),
                    .init(
                        recommendationID: "rec-visible",
                        statusSourceID: "a166-second",
                        statusSourceRank: 2,
                        decision: second
                    ),
                    .init(
                        recommendationID: "rec-hidden",
                        statusSourceID: "a166-hidden",
                        statusSourceRank: 3,
                        isVisible: false,
                        decision: hidden
                    ),
                ],
                renderedRecommendationIDs: ["rec-visible", "rec-hidden"]
            )

        let presentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-visible")
        )

        XCTAssertEqual(source.renderedRecommendationIDs, ["rec-hidden", "rec-visible"])
        XCTAssertEqual(presentation.cardHint, .warning)
        XCTAssertTrue(presentation.statusLine.contains("first-envelope"))
        XCTAssertTrue(presentation.statusLine.contains("a166-first"))
        XCTAssertFalse(presentation.statusLine.contains("second-envelope"))
        XCTAssertFalse(presentation.statusLine.contains("a166-second"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-hidden"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-missing"))
        assertSafePresentation(presentation, "first-wins")
    }

    func test_rejectionReasonsMapToStableBadges() throws {
        let duplicateInput = envelopeInput(preflightDecision: acceptedPreflightDecision())
        let cases: [
            (
                name: String,
                decision: ServerProviderSearchAPILiveProviderInvocationEnvelopeDecision,
                expectedReason: ServerProviderSearchAPILiveProviderInvocationEnvelopeRejectionReason,
                expectedBadge: ProviderStatusBadgeKind
            )
        ] = [
            (
                "stale",
                rejectedEnvelope(preflightExpiresAt: Date(timeIntervalSince1970: 1_700)),
                .staleOrExpiredPreflight,
                .staleCache
            ),
            (
                "cost",
                rejectedEnvelope(budgetSnapshotID: ""),
                .missingBudgetSnapshot,
                .costBlocked
            ),
            (
                "source",
                rejectedEnvelope(sourceState: .unknown),
                .unsafeSourceOrRetentionPolicy,
                .termsBlocked
            ),
            (
                "region",
                rejectedEnvelope(region: .europe),
                .unsupportedRegion,
                .termsBlocked
            ),
            (
                "duplicate",
                ServerProviderSearchAPILiveProviderInvocationEnvelope.evaluate(
                    input: duplicateInput,
                    existingEnvelopeIDs: [duplicateInput.envelopeID]
                ),
                .duplicateEnvelopeID,
                .unavailable
            ),
            (
                "executable",
                rejectedEnvelope(executableFlag: true),
                .executableFlagTrue,
                .unavailable
            ),
        ]
        let source = ServerProviderSearchAPILiveProviderInvocationEnvelopeStatusSourceProducer()
            .statusSource(
                inputs: cases.map { testCase in
                    .init(
                        recommendationID: "rec-\(testCase.name)",
                        statusSourceID: "a166-\(testCase.name)",
                        statusSourceRank: 1,
                        decision: testCase.decision
                    )
                },
                renderedRecommendationIDs: cases.map { "rec-\($0.name)" }
            )

        for testCase in cases {
            let presentation = try XCTUnwrap(
                source.providerStatusPresentation(for: "rec-\(testCase.name)"),
                testCase.name
            )
            XCTAssertEqual(testCase.decision.state, .rejected, testCase.name)
            XCTAssertTrue(
                testCase.decision.rejectionReasons.contains(testCase.expectedReason),
                testCase.name
            )
            XCTAssertEqual(presentation.cardHint, .disabled, testCase.name)
            XCTAssertEqual(presentation.badges.map(\.kind), [testCase.expectedBadge], testCase.name)
            XCTAssertTrue(
                presentation.statusLine.contains(testCase.expectedReason.rawValue),
                testCase.name
            )
            XCTAssertTrue(
                presentation.statusLine.contains("disabled by envelope policy"),
                testCase.name
            )
            XCTAssertTrue(
                presentation.statusLine.contains("isRuntimeCallable false"),
                testCase.name
            )
            XCTAssertTrue(
                presentation.statusLine.contains("isExecutable false"),
                testCase.name
            )
            assertSafePresentation(presentation, testCase.name)
        }
    }

    func test_statusCopyDebugAndEncodedCopyDoNotLeakRuntimeFields() throws {
        let prepared = preparedEnvelope(envelopeID: "safe-envelope")
        let rejected = rejectedEnvelope(serverSecretMode: .clientProvided)
        let source = ServerProviderSearchAPILiveProviderInvocationEnvelopeStatusSourceProducer()
            .statusSource(
                inputs: [
                    .init(
                        recommendationID: "rec-safe",
                        statusSourceID: "a166-safe",
                        statusSourceRank: 1,
                        decision: prepared
                    ),
                    .init(
                        recommendationID: "rec-blocked",
                        statusSourceID: "a166-blocked",
                        statusSourceRank: 2,
                        decision: rejected
                    ),
                ],
                renderedRecommendationIDs: ["rec-safe", "rec-blocked"]
            )
        let preparedPresentation = try XCTUnwrap(source.providerStatusPresentation(for: "rec-safe"))
        let rejectedPresentation = try XCTUnwrap(source.providerStatusPresentation(for: "rec-blocked"))
        let text = [
            try encodedString(prepared.safeCopy),
            try encodedString(rejected.safeCopy),
            prepared.description,
            rejected.description,
            String(describing: preparedPresentation),
            String(describing: rejectedPresentation),
            preparedPresentation.statusLine,
            rejectedPresentation.statusLine,
            preparedPresentation.badges.map(\.label).joined(separator: " "),
            rejectedPresentation.badges.map(\.label).joined(separator: " "),
        ]
            .joined(separator: "\n")
            .lowercased()

        XCTAssertTrue(text.contains("metadata"))
        XCTAssertTrue(text.contains("isruntimecallable"))
        XCTAssertTrue(text.contains("isexecutable"))
        XCTAssertTrue(text.contains("false"))
        XCTAssertTrue(text.contains("no transport or provider runtime has run"))
        XCTAssertFalse(prepared.isRuntimeCallable)
        XCTAssertFalse(prepared.isExecutable)
        XCTAssertFalse(rejected.isRuntimeCallable)
        XCTAssertFalse(rejected.isExecutable)
        for forbidden in sensitiveRuntimeFragments() + successClaimFragments() {
            XCTAssertFalse(
                text.contains(forbidden),
                "Unexpected status-source wording: \(forbidden)"
            )
        }
    }

    private func preparedEnvelope(
        envelopeID: String = "a166-envelope"
    ) -> ServerProviderSearchAPILiveProviderInvocationEnvelopeDecision {
        let decision = ServerProviderSearchAPILiveProviderInvocationEnvelope.evaluate(
            input: envelopeInput(
                preflightDecision: acceptedPreflightDecision(),
                envelopeID: envelopeID
            )
        )
        XCTAssertEqual(decision.state, .prepared)
        XCTAssertFalse(decision.isRuntimeCallable)
        XCTAssertFalse(decision.isExecutable)
        return decision
    }

    private func rejectedEnvelope(
        envelopeID: String = "a166-envelope",
        sourceState: ServerSourcePolicyState = .passed,
        region: ProviderRegion = .northAmerica,
        budgetSnapshotID: String = "a166-budget-snapshot",
        quotaRateClass: ServerProviderSearchAPILiveVendorQPSClass = .standard,
        serverSecretMode: ServerProviderSearchAPILiveTransportAdapterSecretMode = .serverOwned,
        preflightExpiresAt: Date = Date(timeIntervalSince1970: 3_000),
        executableFlag: Bool = false
    ) -> ServerProviderSearchAPILiveProviderInvocationEnvelopeDecision {
        let decision = ServerProviderSearchAPILiveProviderInvocationEnvelope.evaluate(
            input: envelopeInput(
                preflightDecision: acceptedPreflightDecision(),
                envelopeID: envelopeID,
                sourceState: sourceState,
                region: region,
                budgetSnapshotID: budgetSnapshotID,
                quotaRateClass: quotaRateClass,
                serverSecretMode: serverSecretMode,
                preflightExpiresAt: preflightExpiresAt,
                executableFlag: executableFlag
            )
        )
        XCTAssertEqual(decision.state, .rejected)
        XCTAssertFalse(decision.isRuntimeCallable)
        XCTAssertFalse(decision.isExecutable)
        return decision
    }

    private func envelopeInput(
        preflightDecision: ServerProviderSearchAPILiveProviderInvocationPreflightDecision,
        envelopeID: String = "a166-envelope",
        sourceState: ServerSourcePolicyState = .passed,
        region: ProviderRegion = .northAmerica,
        budgetSnapshotID: String = "a166-budget-snapshot",
        quotaRateClass: ServerProviderSearchAPILiveVendorQPSClass = .standard,
        serverSecretMode: ServerProviderSearchAPILiveTransportAdapterSecretMode = .serverOwned,
        issuedAt: Date = Date(timeIntervalSince1970: 2_000),
        preflightExpiresAt: Date = Date(timeIntervalSince1970: 3_000),
        envelopeExpiresAt: Date = Date(timeIntervalSince1970: 2_600),
        executableFlag: Bool = false
    ) -> ServerProviderSearchAPILiveProviderInvocationEnvelopeInput {
        ServerProviderSearchAPILiveProviderInvocationEnvelopeInput(
            envelopeID: envelopeID,
            preflightID: "a166-preflight",
            preflightDecision: preflightDecision,
            selectedAdapterID: "a166-adapter",
            selectedVendorDecisionID: "a150-selection-a166-vendor",
            selectedVendorID: "a166-vendor",
            resultShape: .organicLinks,
            freshness: .livePreferred,
            searchContextClass: .compactContext,
            pageContentRequirement: .snippetsOnly,
            retentionClass: .ephemeralOnly,
            sourceState: sourceState,
            region: region,
            membershipTier: .plus,
            budgetSnapshotID: budgetSnapshotID,
            costUnit: .request,
            quotaRateClass: quotaRateClass,
            transportLeaseID: "a122-lease",
            transportRequestID: "a126-transport-request",
            auditTraceID: "a140-audit-trace",
            serverSecretMode: serverSecretMode,
            issuedAt: issuedAt,
            preflightExpiresAt: preflightExpiresAt,
            envelopeExpiresAt: envelopeExpiresAt,
            userFacingPurpose: "public-info lookup",
            executableFlag: executableFlag
        )
    }

    private func acceptedPreflightDecision() -> ServerProviderSearchAPILiveProviderInvocationPreflightDecision {
        let decision = ServerProviderSearchAPILiveProviderInvocationPreflight.evaluate(
            input: preflightInput(adapterDecision: acceptedAdapterDecision())
        )
        XCTAssertEqual(decision.state, .accepted)
        XCTAssertFalse(decision.isRuntimeCallable)
        return decision
    }

    private func preflightInput(
        adapterDecision: ServerProviderSearchAPILiveTransportAdapterInterfaceDecision
    ) -> ServerProviderSearchAPILiveProviderInvocationPreflightInput {
        ServerProviderSearchAPILiveProviderInvocationPreflightInput(
            preflightID: "a166-preflight",
            adapterInterfaceDecision: adapterDecision,
            selectedDescriptorID: "a166-adapter",
            selectedVendorDecisionID: "a150-selection-a166-vendor",
            selectedVendorID: "a166-vendor",
            meteredDecisionID: "a117-metered-decision",
            leaseID: "a122-lease",
            leaseMeteredDecisionID: "a117-metered-decision",
            transportRequestID: "a126-transport-request",
            transportLeaseID: "a122-lease",
            auditTraceID: "a140-audit-trace",
            auditTransportRequestID: "a126-transport-request",
            providerFamily: .searchAPI,
            capability: .webSearch,
            adapterResultShape: .organicLinks,
            adapterFreshness: .livePreferred,
            resultShape: .organicLinks,
            freshness: .livePreferred,
            costClass: .meteredPremium,
            costUnit: .request,
            searchContextClass: .compactContext,
            pageContentRequirement: .snippetsOnly,
            retentionClass: .ephemeralOnly,
            region: .northAmerica,
            membershipTier: .plus,
            budgetSnapshotID: "a166-budget-snapshot",
            userFacingPurpose: "public-info lookup"
        )
    }

    private func acceptedAdapterDecision() -> ServerProviderSearchAPILiveTransportAdapterInterfaceDecision {
        let decision = ServerProviderSearchAPILiveTransportAdapterInterface.evaluate(
            request: interfaceRequest(),
            descriptors: [adapterDescriptor()]
        )
        XCTAssertEqual(decision.state, .accepted)
        XCTAssertFalse(decision.isRuntimeCallable)
        return decision
    }

    private func interfaceRequest() -> ServerProviderSearchAPILiveTransportAdapterInterfaceRequest {
        ServerProviderSearchAPILiveTransportAdapterInterfaceRequest(
            selectedVendorDecisionID: "a150-selection-a166-vendor",
            selectedVendorID: "a166-vendor",
            meteredDecisionID: "a117-metered-decision",
            leaseID: "a122-lease",
            transportRequestID: "a126-transport-request",
            auditTraceID: "a140-audit-trace",
            expectedResultShape: .organicLinks,
            expectedFreshness: .livePreferred,
            expectedCostClass: .meteredPremium,
            expectedCostUnit: .request,
            region: .northAmerica,
            userFacingPurpose: "public-info lookup"
        )
    }

    private func adapterDescriptor() -> ServerProviderSearchAPILiveTransportAdapterDescriptor {
        ServerProviderSearchAPILiveTransportAdapterDescriptor(
            id: "a166-adapter",
            vendorID: "a166-vendor",
            supportedResultShapes: [.organicLinks, .answerSummary],
            supportedFreshness: [.cachedOK, .livePreferred],
            costUnit: .request,
            searchContextClass: .compactContext,
            pageContentMode: .optional,
            retentionClass: .ephemeralOnly,
            citationSupport: .full,
            qpsClass: .standard,
            allowedRegions: [.global, .northAmerica],
            killSwitchID: "a166-kill-switch",
            retryPolicyID: "a166-retry-policy"
        )
    }

    private func badge(
        _ kind: ProviderStatusBadgeKind,
        in presentation: ProviderStatusPresentation
    ) -> ProviderStatusBadgeModel? {
        presentation.badges.first { $0.kind == kind }
    }

    private func encodedString<T: Encodable>(
        _ value: T
    ) throws -> String {
        try XCTUnwrap(String(data: JSONEncoder().encode(value), encoding: .utf8))
    }

    private func assertSafePresentation(
        _ presentation: ProviderStatusPresentation,
        _ label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let text = [
            presentation.statusLine,
            presentation.badges.map(\.label).joined(separator: " "),
            presentation.badges.map(\.systemImage).joined(separator: " "),
            presentation.cardHint.rawValue,
        ]
            .joined(separator: "\n")
            .lowercased()
        for forbidden in sensitiveRuntimeFragments() + successClaimFragments() {
            XCTAssertFalse(
                text.contains(forbidden),
                "Unexpected \(label) presentation wording: \(forbidden)",
                file: file,
                line: line
            )
        }
    }

    private func sensitiveRuntimeFragments() -> [String] {
        [
            "http" + "://",
            "https" + "://",
            "end" + "point",
            "api" + "key",
            "api" + "_" + "key",
            "bear" + "er",
            "tok" + "en",
            "cred" + "ential",
            "o" + "auth",
            "url" + "session",
            "url" + "request",
            "s" + "dk",
            "client" + "handle",
            "raw" + "query",
            "raw" + " query",
            "raw" + "page",
            "raw" + " page",
            "provider" + "payload",
            "provider" + " payload",
            "store" + "kit",
            "pay" + "ment",
            "ord" + "er",
            "book" + "ing",
            "crawl" + "er runtime",
            "m" + "cp runtime",
            "maps" + " " + "s" + "dk",
            "hidden " + "app" + "-control",
            "provider" + " call",
        ]
    }

    private func successClaimFragments() -> [String] {
        [
            "exec" + "ution",
            "exec" + "ute",
            "complete" + "d",
            "comple" + "tion",
        ]
    }
}
