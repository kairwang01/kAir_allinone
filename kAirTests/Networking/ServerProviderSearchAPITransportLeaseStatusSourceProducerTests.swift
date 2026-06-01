//
//  ServerProviderSearchAPITransportLeaseStatusSourceProducerTests.swift
//  kAirTests
//
//  A113 Search API transport lease status-source proof tests.
//

import XCTest
@testable import kAir

@MainActor
final class ServerProviderSearchAPITransportLeaseStatusSourceProducerTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func test_leasesPackageRenderedIssuedAndRejectedStatus() throws {
        let issued = issuedLease(
            id: "a113-issued-lease",
            vendorID: "a113-balanced-vendor",
            budgetID: "a113-budget-metered"
        )
        let rejected = rejectedLease(
            id: "a113-rejected-budget",
            budgetID: "a113-budget-included-empty",
            reason: .includedQuotaExhausted,
            vendorID: "a113-budget-vendor"
        )
        let hidden = issuedLease(
            id: "a113-hidden-lease",
            vendorID: "a113-hidden-vendor",
            budgetID: "a113-hidden-budget"
        )
        let source = ServerProviderSearchAPITransportLeaseStatusSourceProducer()
            .statusSource(
                leases: [
                    .init(recommendationID: "rec-issued", lease: issued),
                    .init(recommendationID: "rec-rejected", lease: rejected),
                    .init(recommendationID: "rec-hidden", lease: hidden),
                ],
                renderedRecommendationIDs: [
                    "rec-rejected",
                    "rec-issued",
                    "rec-issued",
                ]
            )
        let baseline = SearchAPITransportLeaseProviderStatusStore(
            leases: [
                (recommendationID: "rec-issued", lease: issued),
                (recommendationID: "rec-rejected", lease: rejected),
                (recommendationID: "rec-hidden", lease: hidden),
            ]
        )

        let issuedPresentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-issued")
        )
        let rejectedPresentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-rejected")
        )

        XCTAssertEqual(source.renderedRecommendationIDs, ["rec-issued", "rec-rejected"])
        XCTAssertEqual(issuedPresentation, baseline.providerStatusPresentation(for: "rec-issued"))
        XCTAssertEqual(rejectedPresentation, baseline.providerStatusPresentation(for: "rec-rejected"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-hidden"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-missing"))

        XCTAssertEqual(issuedPresentation.cardHint, .warning)
        XCTAssertEqual(badge(.remoteProvider, in: issuedPresentation)?.tone, .neutral)
        XCTAssertEqual(badge(.meteredPremium, in: issuedPresentation)?.tone, .neutral)
        XCTAssertEqual(badge(.liveFreshness, in: issuedPresentation)?.tone, .positive)
        XCTAssertTrue(issuedPresentation.statusLine.contains("transport lease ready"))
        XCTAssertTrue(issuedPresentation.statusLine.contains("a113-issued-lease"))
        XCTAssertTrue(issuedPresentation.statusLine.contains("a113-balanced-vendor"))
        XCTAssertTrue(issuedPresentation.statusLine.contains("a113-budget-metered"))
        XCTAssertTrue(issuedPresentation.statusLine.contains("searchAPI"))
        XCTAssertTrue(issuedPresentation.statusLine.contains("webSearch"))
        XCTAssertTrue(issuedPresentation.statusLine.contains("meteredPremium"))
        XCTAssertTrue(issuedPresentation.statusLine.contains("livePreferred"))
        XCTAssertTrue(issuedPresentation.statusLine.contains("organicLinks"))
        XCTAssertTrue(issuedPresentation.statusLine.contains("Result limit: 4"))
        XCTAssertTrue(issuedPresentation.statusLine.contains("Source policy: passed"))
        XCTAssertTrue(issuedPresentation.statusLine.contains("Citation required: true"))
        XCTAssertTrue(issuedPresentation.statusLine.contains("No transport or provider runtime has run"))

        XCTAssertEqual(rejectedPresentation.cardHint, .disabled)
        XCTAssertEqual(badge(.costBlocked, in: rejectedPresentation)?.tone, .warning)
        XCTAssertNil(badge(.remoteProvider, in: rejectedPresentation))
        XCTAssertNil(badge(.meteredPremium, in: rejectedPresentation))
        XCTAssertTrue(rejectedPresentation.statusLine.contains("includedQuotaExhausted"))
        XCTAssertTrue(rejectedPresentation.statusLine.contains("a113-budget-included-empty"))
        XCTAssertTrue(rejectedPresentation.statusLine.contains("No transport or provider runtime has run"))
    }

    func test_rejectionMatrixPreservesLeaseAndNestedReasonsAsAdvisoryCopy() throws {
        let cases: [
            (
                String,
                ServerProviderSearchAPITransportLease,
                ProviderStatusBadgeKind
            )
        ] = [
            (
                "missing-payload",
                rejectedLease(reason: .missingPayloadDecision),
                .unavailable
            ),
            (
                "payload-rejected",
                rejectedLease(
                    reason: .payloadNotPrepared,
                    payloadRejection: .requestDecisionRejected
                ),
                .unavailable
            ),
            (
                "dispatch-rejected",
                rejectedLease(
                    reason: .dispatchNotEligible,
                    dispatchRejection: .payloadDecisionRejected
                ),
                .unavailable
            ),
            (
                "authorization-rejected",
                rejectedLease(
                    reason: .authorizationNotAccepted,
                    authorizationRejection: .vendorPolicyNotAccepted
                ),
                .unavailable
            ),
            (
                "quota",
                rejectedLease(reason: .includedQuotaExhausted),
                .costBlocked
            ),
            (
                "metered",
                rejectedLease(reason: .meteredEligibilityMissing),
                .costBlocked
            ),
            (
                "metered-entitlement",
                rejectedLease(reason: .meteredEntitlementMissing),
                .costBlocked
            ),
            (
                "budget",
                rejectedLease(reason: .explicitBudgetDenied),
                .costBlocked
            ),
            (
                "provider",
                rejectedLease(reason: .providerFamilyMismatch),
                .termsBlocked
            ),
            (
                "vendor",
                rejectedLease(reason: .vendorMismatch),
                .termsBlocked
            ),
            (
                "capability",
                rejectedLease(reason: .capabilityMismatch),
                .termsBlocked
            ),
            (
                "cost",
                rejectedLease(reason: .costClassMismatch),
                .costBlocked
            ),
            (
                "freshness",
                rejectedLease(reason: .freshnessMismatch),
                .staleCache
            ),
            (
                "source",
                rejectedLease(reason: .sourcePolicyInsufficient),
                .termsBlocked
            ),
            (
                "citation",
                rejectedLease(reason: .citationPolicyMissing),
                .termsBlocked
            ),
        ]
        let source = ServerProviderSearchAPITransportLeaseStatusSourceProducer()
            .statusSource(
                leases: cases.map { entry in
                    .init(recommendationID: "rec-\(entry.0)", lease: entry.1)
                },
                renderedRecommendationIDs: cases.map { entry in "rec-\(entry.0)" }
            )

        for (id, lease, expectedBadgeKind) in cases {
            let presentation = try XCTUnwrap(
                source.providerStatusPresentation(for: "rec-\(id)"),
                id
            )

            XCTAssertEqual(lease.state, .rejected, id)
            XCTAssertEqual(presentation.cardHint, .disabled, id)
            XCTAssertEqual(badge(expectedBadgeKind, in: presentation)?.tone, .warning, id)
            XCTAssertNil(badge(.remoteProvider, in: presentation), id)
            XCTAssertNil(badge(.meteredPremium, in: presentation), id)
            XCTAssertTrue(presentation.statusLine.contains("blocked by metadata policy"), id)
            XCTAssertTrue(
                presentation.statusLine.contains(try XCTUnwrap(lease.rejection).rawValue),
                id
            )
            if let payloadRejection = lease.payloadRejection {
                XCTAssertTrue(presentation.statusLine.contains(payloadRejection.rawValue), id)
            }
            if let dispatchRejection = lease.dispatchRejection {
                XCTAssertTrue(presentation.statusLine.contains(dispatchRejection.rawValue), id)
            }
            if let authorizationRejection = lease.authorizationRejection {
                XCTAssertTrue(presentation.statusLine.contains(authorizationRejection.rawValue), id)
            }
            XCTAssertTrue(
                presentation.statusLine.contains("No transport or provider runtime has run"),
                id
            )
        }
    }

    func test_meteredEntitlementDerivedLeasesPackageIssuedAndNewRejectionStatus() throws {
        let included = try meteredDerivedLease(
            id: "a123-included",
            vendorID: "a123-included-vendor",
            costClass: .includedQuota,
            freshness: .cachedOK,
            membershipTier: .plus
        )
        let metered = try meteredDerivedLease(
            id: "a123-metered",
            vendorID: "a123-metered-vendor",
            costClass: .meteredPremium,
            freshness: .livePreferred,
            membershipTier: .pro
        )
        let missingEntitlement = try leaseFromBudgetContext(
            id: "a123-generic-budget",
            runtimeVendorID: "a123-generic-runtime-vendor",
            budgetContext: ServerProviderSearchAPITransportBudgetContext(
                id: "a123-generic-budget",
                quotaSnapshot: ServerProviderQuotaSnapshot(
                    allowedProviderFamilies: [.searchAPI],
                    entitledProviderFamilies: [.searchAPI],
                    meteredEligibleProviderFamilies: [.searchAPI]
                ),
                allowedCostClasses: [.meteredPremium]
            )
        )
        let vendorMismatch = try leaseFromBudgetContext(
            id: "a123-vendor-mismatch",
            runtimeVendorID: "a123-runtime-vendor",
            budgetContext: try XCTUnwrap(
                meteredUsageDecision(
                    id: "a123-budget-vendor",
                    vendorID: "a123-budget-vendor"
                )
                    .transportBudgetContext(id: "a123-vendor-mismatch-budget")
            )
        )
        let hidden = try meteredDerivedLease(
            id: "a123-hidden",
            vendorID: "a123-hidden-vendor",
            costClass: .meteredPremium,
            freshness: .livePreferred,
            membershipTier: .pro
        )
        let source = ServerProviderSearchAPITransportLeaseStatusSourceProducer()
            .statusSource(
                leases: [
                    .init(recommendationID: "rec-included", lease: included),
                    .init(recommendationID: "rec-metered", lease: metered),
                    .init(recommendationID: "rec-missing", lease: missingEntitlement),
                    .init(recommendationID: "rec-vendor", lease: vendorMismatch),
                    .init(recommendationID: "rec-hidden", lease: hidden),
                ],
                renderedRecommendationIDs: [
                    "rec-vendor",
                    "rec-metered",
                    "rec-included",
                    "rec-missing",
                ]
            )

        let includedStatus = try XCTUnwrap(source.providerStatusPresentation(for: "rec-included"))
        let meteredStatus = try XCTUnwrap(source.providerStatusPresentation(for: "rec-metered"))
        let missingStatus = try XCTUnwrap(source.providerStatusPresentation(for: "rec-missing"))
        let vendorStatus = try XCTUnwrap(source.providerStatusPresentation(for: "rec-vendor"))
        let selectedText = [
            includedStatus.statusLine,
            meteredStatus.statusLine,
            missingStatus.statusLine,
            vendorStatus.statusLine,
        ]
            .joined(separator: "\n")
            .lowercased()

        XCTAssertEqual(
            source.renderedRecommendationIDs,
            ["rec-included", "rec-metered", "rec-missing", "rec-vendor"]
        )
        XCTAssertNil(source.providerStatusPresentation(for: "rec-hidden"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-unknown"))

        XCTAssertTrue(included.isIssued)
        XCTAssertEqual(includedStatus.cardHint, .normal)
        XCTAssertEqual(badge(.includedQuota, in: includedStatus)?.tone, .neutral)
        XCTAssertNil(badge(.meteredPremium, in: includedStatus))
        XCTAssertTrue(includedStatus.statusLine.contains("a123-included-vendor"))
        XCTAssertTrue(includedStatus.statusLine.contains("a123-included-budget"))
        XCTAssertTrue(includedStatus.statusLine.contains("includedQuota"))

        XCTAssertTrue(metered.isIssued)
        XCTAssertEqual(meteredStatus.cardHint, .warning)
        XCTAssertEqual(badge(.remoteProvider, in: meteredStatus)?.tone, .neutral)
        XCTAssertEqual(badge(.meteredPremium, in: meteredStatus)?.tone, .neutral)
        XCTAssertEqual(badge(.liveFreshness, in: meteredStatus)?.tone, .positive)
        XCTAssertTrue(meteredStatus.statusLine.contains("a123-metered-vendor"))
        XCTAssertTrue(meteredStatus.statusLine.contains("a123-metered-budget"))
        XCTAssertTrue(meteredStatus.statusLine.contains("meteredPremium"))

        XCTAssertEqual(missingEntitlement.rejection, .meteredEntitlementMissing)
        XCTAssertEqual(missingStatus.cardHint, .disabled)
        XCTAssertEqual(badge(.costBlocked, in: missingStatus)?.tone, .warning)
        XCTAssertTrue(missingStatus.statusLine.contains("meteredEntitlementMissing"))
        XCTAssertTrue(missingStatus.statusLine.contains("a123-generic-budget"))
        XCTAssertNil(badge(.remoteProvider, in: missingStatus))

        XCTAssertEqual(vendorMismatch.rejection, .vendorMismatch)
        XCTAssertEqual(vendorStatus.cardHint, .disabled)
        XCTAssertEqual(badge(.termsBlocked, in: vendorStatus)?.tone, .warning)
        XCTAssertTrue(vendorStatus.statusLine.contains("vendorMismatch"))
        XCTAssertTrue(vendorStatus.statusLine.contains("a123-vendor-mismatch-budget"))
        XCTAssertFalse(vendorStatus.statusLine.contains("a123-budget-vendor"))

        XCTAssertFalse(selectedText.contains("public coffee"))
        XCTAssertFalse(selectedText.contains("a123-hidden-vendor"))
        XCTAssertFalse(selectedText.contains("a123-hidden-budget"))
        for forbidden in sensitiveRuntimeFragments() + executionClaimFragments() {
            XCTAssertFalse(selectedText.contains(forbidden), "Unexpected lease status wording: \(forbidden)")
        }
    }

    func test_duplicateIDsKeepFirstLeaseAndRenderedGuardHidesUnrenderedLeases() throws {
        let first = issuedLease(
            id: "a113-first-lease",
            vendorID: "a113-first-vendor",
            budgetID: "a113-budget-included",
            costClass: .includedQuota,
            freshness: .cachedOK
        )
        let second = issuedLease(
            id: "a113-second-lease",
            vendorID: "a113-second-vendor",
            budgetID: "a113-budget-metered",
            costClass: .meteredPremium,
            freshness: .livePreferred
        )
        let hidden = issuedLease(
            id: "a113-hidden-lease",
            vendorID: "a113-hidden-vendor",
            budgetID: "a113-hidden-budget"
        )
        let store = SearchAPITransportLeaseProviderStatusStore(
            leases: [
                (recommendationID: "rec-duplicate", lease: first),
                (recommendationID: "rec-duplicate", lease: second),
                (recommendationID: "rec-hidden", lease: hidden),
            ]
        )
        let source = ServerProviderRenderedRuntimeStatusSource(
            source: store,
            renderedRecommendationIDs: ["rec-duplicate"]
        )

        let presentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-duplicate")
        )

        XCTAssertEqual(store.recommendationIDs, ["rec-duplicate", "rec-hidden"])
        XCTAssertEqual(source.renderedRecommendationIDs, ["rec-duplicate"])
        XCTAssertEqual(presentation.cardHint, .normal)
        XCTAssertEqual(badge(.includedQuota, in: presentation)?.tone, .neutral)
        XCTAssertNil(badge(.meteredPremium, in: presentation))
        XCTAssertNil(badge(.liveFreshness, in: presentation))
        XCTAssertTrue(presentation.statusLine.contains("a113-first-vendor"))
        XCTAssertTrue(presentation.statusLine.contains("a113-budget-included"))
        XCTAssertFalse(presentation.statusLine.contains("a113-second-vendor"))
        XCTAssertFalse(presentation.statusLine.contains("a113-budget-metered"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-hidden"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-missing"))
    }

    func test_statusSourceCopyAndLeaseDebugTextDoNotLeakSensitiveRuntimeFields() throws {
        let issued = issuedLease(
            id: "a113-copy-issued",
            vendorID: "a113-copy-vendor",
            budgetID: "a113-copy-budget"
        )
        let rejected = rejectedLease(
            id: "a113-copy-rejected",
            reason: .dispatchNotEligible,
            payloadRejection: .requestDecisionRejected,
            dispatchRejection: .payloadDecisionRejected,
            authorizationRejection: .dispatchNotEligible
        )
        let source = ServerProviderSearchAPITransportLeaseStatusSourceProducer()
            .statusSource(
                leases: [
                    .init(recommendationID: "rec-copy-issued", lease: issued),
                    .init(recommendationID: "rec-copy-rejected", lease: rejected),
                ],
                renderedRecommendationIDs: ["rec-copy-issued", "rec-copy-rejected"]
            )
        let issuedPresentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-copy-issued")
        )
        let rejectedPresentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-copy-rejected")
        )
        let text = [
            try encodedString(issued),
            try encodedString(rejected),
            issued.description,
            rejected.description,
            issuedPresentation.statusLine,
            rejectedPresentation.statusLine,
        ]
            .joined(separator: "\n")
            .lowercased()

        XCTAssertTrue(text.contains("metadata"))
        XCTAssertTrue(text.contains("no transport or provider runtime has run"))
        XCTAssertFalse(text.contains("public coffee"))
        XCTAssertFalse(text.contains("a113-source.example.com"))
        for forbidden in sensitiveRuntimeFragments() + executionClaimFragments() {
            XCTAssertFalse(text.contains(forbidden), "Unexpected lease status wording: \(forbidden)")
        }
    }

    private func issuedLease(
        id: String = "a113-issued-lease",
        vendorID: String = "a113-vendor",
        budgetID: String = "a113-budget",
        costClass: ProviderCostClass = .meteredPremium,
        freshness: ProviderFreshness = .livePreferred
    ) -> ServerProviderSearchAPITransportLease {
        ServerProviderSearchAPITransportLease(
            id: id,
            state: .issued,
            statusLine: "Search API transport lease is issued from verified metadata only. No transport or provider runtime has run.",
            payloadDecisionID: "\(id)-payload-decision",
            payloadID: "\(id)-payload",
            dispatchReceiptID: "\(id)-dispatch",
            authorizationID: "\(id)-authorization",
            budgetID: budgetID,
            vendorID: vendorID,
            providerFamily: .searchAPI,
            capability: .webSearch,
            costClass: costClass,
            freshness: freshness,
            resultShape: .organicLinks,
            resultLimit: 4,
            sourceState: .passed,
            citationRequired: true,
            rejection: nil,
            payloadRejection: nil,
            dispatchRejection: nil,
            authorizationRejection: nil
        )
    }

    private func rejectedLease(
        id: String = "a113-rejected-lease",
        budgetID: String = "a113-budget",
        reason: ServerProviderSearchAPITransportLeaseRejectionReason,
        payloadRejection: ServerProviderSearchAPIAdapterPayloadRejectionReason? = nil,
        dispatchRejection: ServerProviderSearchAPIAdapterPayloadDispatchRejectionReason? = nil,
        authorizationRejection: ServerProviderSearchAPIVendorPolicyDispatchAuthorizationRejectionReason? = nil,
        vendorID: String? = "a113-rejected-vendor"
    ) -> ServerProviderSearchAPITransportLease {
        ServerProviderSearchAPITransportLease(
            id: "\(id)-\(reason.rawValue)",
            state: .rejected,
            statusLine: "Search API transport lease is blocked by metadata policy: \(reason.rawValue). No transport or provider runtime has run.",
            payloadDecisionID: "\(id)-payload-decision",
            payloadID: "\(id)-payload",
            dispatchReceiptID: "\(id)-dispatch",
            authorizationID: "\(id)-authorization",
            budgetID: budgetID,
            vendorID: vendorID,
            providerFamily: nil,
            capability: nil,
            costClass: nil,
            freshness: nil,
            resultShape: nil,
            resultLimit: nil,
            sourceState: nil,
            citationRequired: nil,
            rejection: reason,
            payloadRejection: payloadRejection,
            dispatchRejection: dispatchRejection,
            authorizationRejection: authorizationRejection
        )
    }

    private struct LeaseInputs {
        let payloadDecision: ServerProviderSearchAPIAdapterPayloadDecision
        let dispatchReceipt: ServerProviderSearchAPIAdapterPayloadDispatchReceipt
        let authorization: ServerProviderSearchAPIVendorPolicyDispatchAuthorization
    }

    private func meteredDerivedLease(
        id: String,
        vendorID: String,
        costClass: ProviderCostClass,
        freshness: ProviderFreshness,
        membershipTier: MembershipTier
    ) throws -> ServerProviderSearchAPITransportLease {
        let inputs = try leaseInputs(
            traceID: id,
            sourceHost: "\(id).example.com",
            vendorID: vendorID,
            costClass: costClass,
            freshness: freshness
        )
        let decision = meteredUsageDecision(
            id: id,
            vendorID: vendorID,
            costClass: costClass,
            freshness: freshness,
            membershipTier: membershipTier
        )
        let budgetContext = try XCTUnwrap(
            decision.transportBudgetContext(id: "\(id)-budget")
        )
        let lease = ServerProviderSearchAPITransportLeaseGate.evaluate(
            payloadDecision: inputs.payloadDecision,
            dispatchReceipt: inputs.dispatchReceipt,
            authorization: inputs.authorization,
            requestedResultShape: .organicLinks,
            budgetContext: budgetContext
        )

        XCTAssertTrue(decision.isAccepted, id)
        XCTAssertTrue(lease.isIssued, id)
        return lease
    }

    private func leaseFromBudgetContext(
        id: String,
        runtimeVendorID: String,
        budgetContext: ServerProviderSearchAPITransportBudgetContext
    ) throws -> ServerProviderSearchAPITransportLease {
        let inputs = try leaseInputs(
            traceID: id,
            sourceHost: "\(id).example.com",
            vendorID: runtimeVendorID
        )
        return ServerProviderSearchAPITransportLeaseGate.evaluate(
            payloadDecision: inputs.payloadDecision,
            dispatchReceipt: inputs.dispatchReceipt,
            authorization: inputs.authorization,
            requestedResultShape: .organicLinks,
            budgetContext: budgetContext
        )
    }

    private func leaseInputs(
        traceID: String,
        sourceHost: String,
        vendorID: String,
        costClass: ProviderCostClass = .meteredPremium,
        freshness: ProviderFreshness = .livePreferred
    ) throws -> LeaseInputs {
        let request = try preparedRequest(
            traceID: traceID,
            sourceHost: sourceHost,
            costClass: costClass,
            freshness: freshness
        )
        let payloadDecision = ServerProviderSearchAPIAdapterPayloadBuilder.build(from: request)
        let dispatchReceipt = ServerProviderSearchAPIAdapterPayloadDispatchGate.evaluate(
            payloadDecision: payloadDecision,
            request: request
        )
        let authorization = ServerProviderSearchAPIVendorPolicyDispatchAuthorizationGate.authorize(
            dispatchReceipt: dispatchReceipt,
            vendorDecision: acceptedVendorDecision(
                vendorID: vendorID,
                costClass: costClass,
                freshness: freshness
            ),
            requestedResultShape: .organicLinks
        )

        XCTAssertEqual(payloadDecision.state, .payloadPrepared, traceID)
        XCTAssertEqual(dispatchReceipt.state, .dispatchEligible, traceID)
        XCTAssertEqual(authorization.state, .authorized, traceID)
        return LeaseInputs(
            payloadDecision: payloadDecision,
            dispatchReceipt: dispatchReceipt,
            authorization: authorization
        )
    }

    private func preparedRequest(
        traceID: String,
        sourceHost: String,
        costClass: ProviderCostClass,
        freshness: ProviderFreshness
    ) throws -> ServerProviderSearchAPIAdapterRequest {
        let decision = ServerProviderSearchAPIAdapterContract.prepareRequest(
            envelope: ServerProviderEnvelope(
                traceID: traceID,
                capability: .webSearch,
                providerFamily: .searchAPI,
                privacyClass: .general,
                membershipTier: .plus,
                costClass: costClass,
                freshness: freshness,
                sourcePolicy: ServerSourcePolicy(
                    sourceState: .passed,
                    attributionRequired: true,
                    sourceHost: sourceHost
                ),
                confirmationState: .notRequired,
                meteredProviderEntitlements: [.searchAPI],
                enabledExperimentalProviders: []
            ),
            connectorReceipt: connectorReceipt(
                traceID: traceID,
                costClass: costClass,
                freshness: freshness
            ),
            query: ServerProviderSearchAPIAdapterQuery(text: "public coffee"),
            resultLimit: 4
        )
        XCTAssertEqual(decision.state, .requestPrepared, traceID)
        return try XCTUnwrap(decision.request)
    }

    private func connectorReceipt(
        traceID: String,
        costClass: ProviderCostClass,
        freshness: ProviderFreshness
    ) -> ServerProviderRuntimeConnectorInvocationReceipt {
        ServerProviderRuntimeConnectorInvocationReceipt(
            id: "a123-connector-\(traceID)",
            state: .receiptPrepared,
            statusLine: "A123 connector receipt fixture is metadata only. No provider runtime has run.",
            planningID: "a123-planning-\(traceID)",
            planningState: .requestPrepared,
            planningRejection: nil,
            connectorProviderFamily: .searchAPI,
            requestID: "a123-request-\(traceID)",
            resultID: "a123-result-\(traceID)",
            connectorResultState: .metadataPrepared,
            connectorRejection: nil,
            providerFamily: .searchAPI,
            capability: .webSearch,
            costClass: costClass,
            freshness: freshness,
            manifestID: "provider-runtime-adapter-manifest-searchAPI",
            authorizationID: "a123-authorization-\(traceID)",
            boundaryID: "a123-boundary-\(traceID)",
            traceID: traceID,
            invocationRejection: nil
        )
    }

    private func acceptedVendorDecision(
        vendorID: String,
        costClass: ProviderCostClass,
        freshness: ProviderFreshness
    ) -> ServerProviderSearchAPIVendorPolicyDecision {
        let decision = ServerProviderSearchAPIVendorPolicy.evaluate(
            context: ServerProviderSearchAPIVendorPolicyContext(
                providerFamily: .searchAPI,
                capability: .webSearch,
                privacyClass: .general,
                costClass: costClass,
                freshness: freshness,
                citationRequired: true,
                sourceHostRequired: true,
                pageBodyRequirement: .snippetsOnly,
                allowedRetention: .ephemeralOnly,
                resultShape: .organicLinks,
                quotaSnapshot: quotaSnapshot(for: costClass)
            ),
            vendor: ServerProviderSearchAPIVendorPolicyDescriptor(
                id: vendorID,
                costClass: costClass,
                supportedFreshness: [.cachedOK, .livePreferred, .liveRequired],
                citationSupport: ServerProviderSearchAPIVendorCitationSupport(
                    supportsCitations: true,
                    supportsSourceHost: true,
                    supportsAttribution: true
                ),
                pageBodyMode: .optional,
                requiredRetention: .ephemeralOnly,
                supportedResultShapes: [.organicLinks, .answerSummary]
            )
        )
        XCTAssertEqual(decision.state, .accepted, vendorID)
        return decision
    }

    private func quotaSnapshot(
        for costClass: ProviderCostClass
    ) -> ServerProviderQuotaSnapshot {
        switch costClass {
        case .includedQuota:
            return ServerProviderQuotaSnapshot(
                allowedProviderFamilies: [.searchAPI],
                entitledProviderFamilies: [.searchAPI],
                remainingIncludedQuota: [.searchAPI: 4]
            )
        case .meteredPremium:
            return ServerProviderQuotaSnapshot(
                allowedProviderFamilies: [.searchAPI],
                entitledProviderFamilies: [.searchAPI],
                meteredEligibleProviderFamilies: [.searchAPI]
            )
        case .freeLocal, .blockedByCost, .blockedByPrivacy, .blockedByTerms:
            return ServerProviderQuotaSnapshot()
        }
    }

    private func meteredUsageDecision(
        id: String,
        vendorID: String,
        costClass: ProviderCostClass = .meteredPremium,
        freshness: ProviderFreshness = .livePreferred,
        membershipTier: MembershipTier = .plus
    ) -> ServerProviderMeteredUsageDecision {
        ServerProviderMeteredEntitlementLedger.evaluate(
            request: ServerProviderMeteredUsageRequest(
                id: id,
                traceID: "\(id)-trace",
                providerFamily: .searchAPI,
                vendorID: vendorID,
                capability: .webSearch,
                estimatedUnits: 3,
                costClass: costClass,
                privacyClass: .general,
                freshness: freshness,
                membershipTier: membershipTier,
                currencyCode: "usd",
                unitLabel: "search-unit",
                userFacingReason: "public-info lookup"
            ),
            snapshot: ServerProviderMeteredEntitlementSnapshot(
                id: "\(id)-snapshot",
                providerFamily: .searchAPI,
                vendorID: vendorID,
                capability: .webSearch,
                costClass: costClass,
                isVendorEnabled: true,
                membershipTier: membershipTier,
                minimumMembershipTier: .plus,
                hasEntitlement: true,
                quotaPeriodID: "a123-2026-05",
                includedUnits: 40,
                usedUnits: 5,
                reservedUnits: 2,
                remainingUnits: 20,
                currencyCode: "usd",
                unitLabel: "search-unit",
                sourceTimestamp: now,
                staleAfter: 600
            ),
            now: now
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
        try XCTUnwrap(
            String(data: JSONEncoder().encode(value), encoding: .utf8)
        )
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
            "source" + "host",
            "a113-source.example.com",
            "hea" + "lthkit",
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
