//
//  ServerProviderSearchAPITransportLeaseTests.swift
//  kAirTests
//
//  A112 Search API vendor-authorized transport lease and budget guard tests.
//

import XCTest
@testable import kAir

final class ServerProviderSearchAPITransportLeaseTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func test_issuedLeasePreservesSafeMetadataWithoutTransportExecution() throws {
        let inputs = try leaseInputs(
            traceID: "a112-issued",
            sourceHost: "a112-issued.example.com",
            vendorID: "a112-issued-vendor"
        )

        let lease = ServerProviderSearchAPITransportLeaseGate.evaluate(
            payloadDecision: inputs.payloadDecision,
            dispatchReceipt: inputs.dispatchReceipt,
            authorization: inputs.authorization,
            requestedResultShape: .organicLinks,
            budgetContext: meteredBudget(
                id: "a112-budget-metered",
                vendorID: "a112-issued-vendor"
            )
        )
        let repeated = ServerProviderSearchAPITransportLeaseGate.evaluate(
            payloadDecision: inputs.payloadDecision,
            dispatchReceipt: inputs.dispatchReceipt,
            authorization: inputs.authorization,
            requestedResultShape: .organicLinks,
            budgetContext: meteredBudget(
                id: "a112-budget-metered",
                vendorID: "a112-issued-vendor"
            )
        )

        assertSendable(lease)
        XCTAssertEqual(lease, repeated)
        XCTAssertEqual(Set([lease]).count, 1)
        XCTAssertTrue(lease.isIssued)
        XCTAssertEqual(lease.state, .issued)
        XCTAssertNil(lease.rejection)
        XCTAssertNil(lease.payloadRejection)
        XCTAssertNil(lease.dispatchRejection)
        XCTAssertNil(lease.authorizationRejection)
        XCTAssertEqual(lease.payloadDecisionID, inputs.payloadDecision.id)
        XCTAssertEqual(lease.payloadID, inputs.payloadDecision.payload?.id)
        XCTAssertEqual(lease.dispatchReceiptID, inputs.dispatchReceipt.id)
        XCTAssertEqual(lease.authorizationID, inputs.authorization.id)
        XCTAssertEqual(lease.budgetID, "a112-budget-metered")
        XCTAssertEqual(lease.vendorID, "a112-issued-vendor")
        XCTAssertEqual(lease.providerFamily, .searchAPI)
        XCTAssertEqual(lease.capability, .webSearch)
        XCTAssertEqual(lease.costClass, .meteredPremium)
        XCTAssertEqual(lease.freshness, .livePreferred)
        XCTAssertEqual(lease.resultShape, .organicLinks)
        XCTAssertEqual(lease.resultLimit, 4)
        XCTAssertEqual(lease.sourceState, .passed)
        XCTAssertEqual(lease.citationRequired, true)
        XCTAssertTrue(lease.statusLine.contains("verified metadata only"))
        XCTAssertTrue(lease.statusLine.contains("No transport or provider runtime has run"))
        XCTAssertFalse(lease.description.contains("public coffee"))
    }

    func test_rejectionMatrixPreservesExplicitReasonsBeforeTransport() throws {
        let inputs = try leaseInputs(
            traceID: "a112-matrix",
            sourceHost: "a112-matrix.example.com",
            vendorID: "a112-matrix-vendor"
        )
        let includedInputs = try leaseInputs(
            traceID: "a112-included-quota",
            sourceHost: "a112-included.example.com",
            vendorID: "a112-included-vendor",
            costClass: .includedQuota,
            freshness: .cachedOK
        )
        let rejectedPayload = try rejectedPayloadDecision()
        let missingPayload = copy(inputs.payloadDecision, payload: nil)
        let blockedDispatch = try blockedDispatchReceipt()
        let rejectedAuthorization = try vendorBlockedAuthorization()
        let unsafeSourcePolicy = sourcePolicy(
            sourceState: .blocked,
            attributionRequired: true
        )
        let missingCitationPolicy = sourcePolicy(
            sourceState: .passed,
            attributionRequired: false
        )

        let cases: [
            (
                String,
                ServerProviderSearchAPIAdapterPayloadDecision?,
                ServerProviderSearchAPIAdapterPayloadDispatchReceipt?,
                ServerProviderSearchAPIVendorPolicyDispatchAuthorization?,
                ServerProviderSearchAPIVendorResultShape,
                ServerProviderSearchAPITransportBudgetContext,
                ServerProviderSearchAPITransportLeaseRejectionReason
            )
        ] = [
            (
                "missing payload decision",
                nil,
                inputs.dispatchReceipt,
                inputs.authorization,
                .organicLinks,
                meteredBudget(),
                .missingPayloadDecision
            ),
            (
                "rejected payload",
                rejectedPayload,
                inputs.dispatchReceipt,
                inputs.authorization,
                .organicLinks,
                meteredBudget(),
                .payloadNotPrepared
            ),
            (
                "missing payload",
                missingPayload,
                inputs.dispatchReceipt,
                inputs.authorization,
                .organicLinks,
                meteredBudget(),
                .missingPayload
            ),
            (
                "missing dispatch",
                inputs.payloadDecision,
                nil,
                inputs.authorization,
                .organicLinks,
                meteredBudget(),
                .missingDispatchReceipt
            ),
            (
                "blocked dispatch",
                inputs.payloadDecision,
                blockedDispatch,
                inputs.authorization,
                .organicLinks,
                meteredBudget(),
                .dispatchNotEligible
            ),
            (
                "missing authorization",
                inputs.payloadDecision,
                inputs.dispatchReceipt,
                nil,
                .organicLinks,
                meteredBudget(),
                .missingAuthorization
            ),
            (
                "rejected authorization",
                inputs.payloadDecision,
                inputs.dispatchReceipt,
                rejectedAuthorization,
                .organicLinks,
                meteredBudget(),
                .authorizationNotAccepted
            ),
            (
                "payload dispatch mismatch",
                inputs.payloadDecision,
                copy(inputs.dispatchReceipt, payloadID: "a112-wrong-payload"),
                inputs.authorization,
                .organicLinks,
                meteredBudget(),
                .payloadDispatchMismatch
            ),
            (
                "dispatch authorization mismatch",
                inputs.payloadDecision,
                inputs.dispatchReceipt,
                copy(inputs.authorization, dispatchReceiptID: "a112-wrong-dispatch"),
                .organicLinks,
                meteredBudget(),
                .dispatchAuthorizationMismatch
            ),
            (
                "provider mismatch",
                copy(
                    inputs.payloadDecision,
                    payload: copy(payload(inputs), providerFamily: .googleMaps)
                ),
                inputs.dispatchReceipt,
                inputs.authorization,
                .organicLinks,
                meteredBudget(),
                .providerFamilyMismatch
            ),
            (
                "capability mismatch",
                copy(
                    inputs.payloadDecision,
                    payload: copy(payload(inputs), capability: .localServiceSearch)
                ),
                inputs.dispatchReceipt,
                inputs.authorization,
                .organicLinks,
                meteredBudget(),
                .capabilityMismatch
            ),
            (
                "cost mismatch",
                copy(
                    inputs.payloadDecision,
                    payload: copy(payload(inputs), costClass: .includedQuota)
                ),
                inputs.dispatchReceipt,
                inputs.authorization,
                .organicLinks,
                meteredBudget(),
                .costClassMismatch
            ),
            (
                "freshness mismatch",
                copy(
                    inputs.payloadDecision,
                    payload: copy(payload(inputs), freshness: .cachedOK)
                ),
                inputs.dispatchReceipt,
                inputs.authorization,
                .organicLinks,
                meteredBudget(),
                .freshnessMismatch
            ),
            (
                "result shape mismatch",
                inputs.payloadDecision,
                inputs.dispatchReceipt,
                inputs.authorization,
                .answerSummary,
                meteredBudget(),
                .resultShapeMismatch
            ),
            (
                "source blocked",
                copy(inputs.payloadDecision, payload: copy(payload(inputs), sourcePolicy: unsafeSourcePolicy)),
                copy(inputs.dispatchReceipt, sourcePolicy: unsafeSourcePolicy),
                inputs.authorization,
                .organicLinks,
                meteredBudget(),
                .sourcePolicyInsufficient
            ),
            (
                "citation missing",
                copy(
                    inputs.payloadDecision,
                    payload: copy(payload(inputs), sourcePolicy: missingCitationPolicy)
                ),
                copy(inputs.dispatchReceipt, sourcePolicy: missingCitationPolicy),
                inputs.authorization,
                .organicLinks,
                meteredBudget(),
                .citationPolicyMissing
            ),
            (
                "provider not allowed",
                inputs.payloadDecision,
                inputs.dispatchReceipt,
                inputs.authorization,
                .organicLinks,
                budget(
                    allowed: [],
                    entitled: [.searchAPI],
                    meteredEligible: [.searchAPI],
                    allowedCostClasses: [.meteredPremium]
                ),
                .providerNotAllowed
            ),
            (
                "provider disabled",
                inputs.payloadDecision,
                inputs.dispatchReceipt,
                inputs.authorization,
                .organicLinks,
                budget(
                    allowed: [.searchAPI],
                    entitled: [.searchAPI],
                    meteredEligible: [.searchAPI],
                    disabled: [.searchAPI],
                    allowedCostClasses: [.meteredPremium]
                ),
                .providerDisabled
            ),
            (
                "entitlement missing",
                inputs.payloadDecision,
                inputs.dispatchReceipt,
                inputs.authorization,
                .organicLinks,
                budget(
                    allowed: [.searchAPI],
                    entitled: [],
                    meteredEligible: [.searchAPI],
                    allowedCostClasses: [.meteredPremium]
                ),
                .entitlementMissing
            ),
            (
                "explicit budget denied",
                inputs.payloadDecision,
                inputs.dispatchReceipt,
                inputs.authorization,
                .organicLinks,
                budget(
                    allowed: [.searchAPI],
                    entitled: [.searchAPI],
                    meteredEligible: [.searchAPI],
                    metadataCostClass: .meteredPremium,
                    allowedCostClasses: [.includedQuota]
                ),
                .explicitBudgetDenied
            ),
            (
                "metered eligibility missing",
                inputs.payloadDecision,
                inputs.dispatchReceipt,
                inputs.authorization,
                .organicLinks,
                budget(
                    allowed: [.searchAPI],
                    entitled: [.searchAPI],
                    meteredEligible: [],
                    allowedCostClasses: [.meteredPremium]
                ),
                .meteredEligibilityMissing
            ),
            (
                "included quota exhausted",
                includedInputs.payloadDecision,
                includedInputs.dispatchReceipt,
                includedInputs.authorization,
                .organicLinks,
                includedBudget(remaining: 0),
                .includedQuotaExhausted
            ),
        ]

        for (id, payloadDecision, dispatchReceipt, authorization, resultShape, budgetContext, expected) in cases {
            let lease = ServerProviderSearchAPITransportLeaseGate.evaluate(
                payloadDecision: payloadDecision,
                dispatchReceipt: dispatchReceipt,
                authorization: authorization,
                requestedResultShape: resultShape,
                budgetContext: budgetContext
            )

            XCTAssertFalse(lease.isIssued, id)
            XCTAssertEqual(lease.state, .rejected, id)
            XCTAssertEqual(lease.rejection, expected, id)
            XCTAssertNil(lease.providerFamily, id)
            XCTAssertNil(lease.capability, id)
            XCTAssertNil(lease.costClass, id)
            XCTAssertNil(lease.freshness, id)
            XCTAssertNil(lease.resultShape, id)
            XCTAssertNil(lease.resultLimit, id)
            XCTAssertTrue(lease.statusLine.contains(expected.rawValue), id)
            XCTAssertTrue(
                lease.statusLine.contains("No transport or provider runtime has run"),
                id
            )
        }
    }

    func test_includedQuotaLeaseUsesBudgetContextWithoutMeteredFallback() throws {
        let inputs = try leaseInputs(
            traceID: "a112-included-issued",
            sourceHost: "a112-included-issued.example.com",
            vendorID: "a112-included-issued-vendor",
            costClass: .includedQuota,
            freshness: .cachedOK
        )
        let lease = ServerProviderSearchAPITransportLeaseGate.evaluate(
            payloadDecision: inputs.payloadDecision,
            dispatchReceipt: inputs.dispatchReceipt,
            authorization: inputs.authorization,
            requestedResultShape: .organicLinks,
            budgetContext: includedBudget(
                id: "a112-budget-included",
                vendorID: "a112-included-issued-vendor",
                remaining: 1
            )
        )

        XCTAssertTrue(lease.isIssued)
        XCTAssertEqual(lease.state, .issued)
        XCTAssertEqual(lease.budgetID, "a112-budget-included")
        XCTAssertEqual(lease.costClass, .includedQuota)
        XCTAssertEqual(lease.freshness, .cachedOK)
        XCTAssertNil(lease.rejection)
        XCTAssertTrue(lease.statusLine.contains("verified metadata only"))
        XCTAssertFalse(lease.statusLine.localizedCaseInsensitiveContains("meteredPremium"))
    }

    func test_meteredEntitlementBudgetContextsIssueIncludedAndMeteredLeases() throws {
        let cases: [
            (
                id: String,
                costClass: ProviderCostClass,
                freshness: ProviderFreshness,
                membershipTier: MembershipTier,
                estimatedUnits: Int,
                remainingUnits: Int
            )
        ] = [
            ("included", .includedQuota, .cachedOK, .plus, 3, 21),
            ("metered", .meteredPremium, .livePreferred, .pro, 5, 34),
        ]

        for testCase in cases {
            let vendorID = "a122-\(testCase.id)-vendor"
            let inputs = try leaseInputs(
                traceID: "a122-\(testCase.id)",
                sourceHost: "a122-\(testCase.id).example.com",
                vendorID: vendorID,
                costClass: testCase.costClass,
                freshness: testCase.freshness
            )
            let decision = meteredUsageDecision(
                id: "a122-\(testCase.id)",
                vendorID: vendorID,
                estimatedUnits: testCase.estimatedUnits,
                costClass: testCase.costClass,
                freshness: testCase.freshness,
                membershipTier: testCase.membershipTier,
                remainingUnits: testCase.remainingUnits
            )
            let budgetContext = try XCTUnwrap(
                decision.transportBudgetContext(id: "a122-\(testCase.id)-budget"),
                testCase.id
            )

            XCTAssertTrue(decision.isAccepted, testCase.id)
            XCTAssertEqual(budgetContext.meteredDecisionID, decision.id, testCase.id)
            XCTAssertEqual(budgetContext.providerFamily, .searchAPI, testCase.id)
            XCTAssertEqual(budgetContext.vendorID, vendorID, testCase.id)
            XCTAssertEqual(budgetContext.capability, .webSearch, testCase.id)
            XCTAssertEqual(budgetContext.costClass, testCase.costClass, testCase.id)
            XCTAssertEqual(budgetContext.freshness, testCase.freshness, testCase.id)
            XCTAssertEqual(budgetContext.allowedCostClasses, [testCase.costClass], testCase.id)

            let lease = ServerProviderSearchAPITransportLeaseGate.evaluate(
                payloadDecision: inputs.payloadDecision,
                dispatchReceipt: inputs.dispatchReceipt,
                authorization: inputs.authorization,
                requestedResultShape: .organicLinks,
                budgetContext: budgetContext
            )

            XCTAssertTrue(lease.isIssued, testCase.id)
            XCTAssertEqual(lease.state, .issued, testCase.id)
            XCTAssertEqual(lease.budgetID, "a122-\(testCase.id)-budget", testCase.id)
            XCTAssertEqual(lease.vendorID, vendorID, testCase.id)
            XCTAssertEqual(lease.providerFamily, .searchAPI, testCase.id)
            XCTAssertEqual(lease.capability, .webSearch, testCase.id)
            XCTAssertEqual(lease.costClass, testCase.costClass, testCase.id)
            XCTAssertEqual(lease.freshness, testCase.freshness, testCase.id)
            XCTAssertNil(lease.rejection, testCase.id)
            XCTAssertTrue(lease.statusLine.contains("verified metadata only"), testCase.id)
            XCTAssertTrue(
                lease.statusLine.contains("No transport or provider runtime has run"),
                testCase.id
            )
        }
    }

    func test_rejectedMeteredEntitlementDecisionsDoNotBuildLeaseBudgetContext() {
        let cases: [
            (
                id: String,
                decision: ServerProviderMeteredUsageDecision,
                expected: ServerProviderMeteredUsageDenialReason
            )
        ] = [
            (
                "missing entitlement",
                meteredUsageDecision(
                    id: "a122-entitlement-missing",
                    hasEntitlement: false
                ),
                .entitlementMissing
            ),
            (
                "private context",
                meteredUsageDecision(
                    id: "a122-private",
                    privacyClass: .private
                ),
                .privacyBlocked
            ),
            (
                "health context",
                meteredUsageDecision(
                    id: "a122-health",
                    privacyClass: .health
                ),
                .healthContextBlocked
            ),
            (
                "over quota",
                meteredUsageDecision(
                    id: "a122-over-quota",
                    estimatedUnits: 12,
                    remainingUnits: 11
                ),
                .overQuota
            ),
            (
                "stale snapshot",
                meteredUsageDecision(
                    id: "a122-stale",
                    sourceTimestamp: now.addingTimeInterval(-700),
                    staleAfter: 600
                ),
                .staleSnapshot
            ),
            (
                "provider mismatch",
                meteredUsageDecision(
                    id: "a122-provider-mismatch",
                    snapshotProviderFamily: .googleMaps
                ),
                .providerFamilyMismatch
            ),
            (
                "vendor mismatch",
                meteredUsageDecision(
                    id: "a122-vendor-mismatch",
                    vendorID: "a122-request-vendor",
                    snapshotVendorID: "a122-snapshot-vendor"
                ),
                .vendorMismatch
            ),
        ]

        for testCase in cases {
            XCTAssertFalse(testCase.decision.isAccepted, testCase.id)
            XCTAssertEqual(testCase.decision.state, .rejected, testCase.id)
            XCTAssertEqual(testCase.decision.denialReason, testCase.expected, testCase.id)
            XCTAssertNil(testCase.decision.transportBudgetContext(), testCase.id)
            XCTAssertNil(testCase.decision.quotaSnapshotForProvider(), testCase.id)
            XCTAssertTrue(
                testCase.decision.statusLine.contains("No transport or provider runtime has run"),
                testCase.id
            )
        }
    }

    func test_budgetMetadataMismatchBlocksLeaseWithoutGenericFallback() throws {
        let inputs = try leaseInputs(
            traceID: "a122-mismatch",
            sourceHost: "a122-mismatch.example.com",
            vendorID: "a122-runtime-vendor"
        )
        let genericBudget = ServerProviderSearchAPITransportBudgetContext(
            id: "a122-generic-budget",
            quotaSnapshot: ServerProviderQuotaSnapshot(
                allowedProviderFamilies: [.searchAPI],
                entitledProviderFamilies: [.searchAPI],
                meteredEligibleProviderFamilies: [.searchAPI]
            ),
            allowedCostClasses: [.meteredPremium]
        )
        let providerMismatchBudget = try XCTUnwrap(
            meteredUsageDecision(
                id: "a122-provider-budget",
                providerFamily: .googleMaps,
                snapshotProviderFamily: .googleMaps,
                vendorID: "a122-runtime-vendor"
            )
                .transportBudgetContext(id: "a122-provider-mismatch-budget")
        )
        let vendorMismatchBudget = try XCTUnwrap(
            meteredUsageDecision(
                id: "a122-vendor-budget",
                vendorID: "a122-budget-vendor"
            )
                .transportBudgetContext(id: "a122-vendor-mismatch-budget")
        )
        let costMismatchBudget = try XCTUnwrap(
            meteredUsageDecision(
                id: "a122-cost-budget",
                vendorID: "a122-runtime-vendor",
                costClass: .includedQuota
            )
                .transportBudgetContext(id: "a122-cost-mismatch-budget")
        )

        let cases: [
            (
                id: String,
                budgetContext: ServerProviderSearchAPITransportBudgetContext,
                expected: ServerProviderSearchAPITransportLeaseRejectionReason
            )
        ] = [
            ("generic budget", genericBudget, .meteredEntitlementMissing),
            ("provider mismatch", providerMismatchBudget, .providerFamilyMismatch),
            ("vendor mismatch", vendorMismatchBudget, .vendorMismatch),
            ("cost mismatch", costMismatchBudget, .costClassMismatch),
        ]

        for testCase in cases {
            let lease = ServerProviderSearchAPITransportLeaseGate.evaluate(
                payloadDecision: inputs.payloadDecision,
                dispatchReceipt: inputs.dispatchReceipt,
                authorization: inputs.authorization,
                requestedResultShape: .organicLinks,
                budgetContext: testCase.budgetContext
            )

            XCTAssertFalse(lease.isIssued, testCase.id)
            XCTAssertEqual(lease.state, .rejected, testCase.id)
            XCTAssertEqual(lease.rejection, testCase.expected, testCase.id)
            XCTAssertNil(lease.providerFamily, testCase.id)
            XCTAssertNil(lease.capability, testCase.id)
            XCTAssertNil(lease.costClass, testCase.id)
            XCTAssertNil(lease.freshness, testCase.id)
            XCTAssertTrue(lease.statusLine.contains(testCase.expected.rawValue), testCase.id)
            XCTAssertTrue(
                lease.statusLine.contains("No transport or provider runtime has run"),
                testCase.id
            )
        }
    }

    func test_leaseEncodingAndDebugCopyDoNotLeakSensitiveRuntimeFields() throws {
        let inputs = try leaseInputs(
            traceID: "a112-copy",
            sourceHost: "a112-copy.example.com",
            vendorID: "a112-copy-vendor"
        )
        let issued = ServerProviderSearchAPITransportLeaseGate.evaluate(
            payloadDecision: inputs.payloadDecision,
            dispatchReceipt: inputs.dispatchReceipt,
            authorization: inputs.authorization,
            requestedResultShape: .organicLinks,
            budgetContext: meteredBudget(vendorID: "a112-copy-vendor")
        )
        let rejected = ServerProviderSearchAPITransportLeaseGate.evaluate(
            payloadDecision: inputs.payloadDecision,
            dispatchReceipt: inputs.dispatchReceipt,
            authorization: nil,
            requestedResultShape: .organicLinks,
            budgetContext: meteredBudget(vendorID: "a112-copy-vendor")
        )
        let text = [
            try encodedString(issued),
            try encodedString(rejected),
            issued.description,
            rejected.description,
            issued.statusLine,
            rejected.statusLine,
        ]
            .joined(separator: "\n")
            .lowercased()

        XCTAssertTrue(text.contains("metadata"))
        XCTAssertTrue(text.contains("no transport or provider runtime has run"))
        XCTAssertFalse(text.contains("public coffee"))
        XCTAssertFalse(text.contains("a112-copy.example.com"))
        for forbidden in sensitiveRuntimeFragments() + executionClaimFragments() {
            XCTAssertFalse(text.contains(forbidden), "Unexpected lease wording: \(forbidden)")
        }
    }

    private struct LeaseInputs {
        let request: ServerProviderSearchAPIAdapterRequest
        let payloadDecision: ServerProviderSearchAPIAdapterPayloadDecision
        let dispatchReceipt: ServerProviderSearchAPIAdapterPayloadDispatchReceipt
        let authorization: ServerProviderSearchAPIVendorPolicyDispatchAuthorization
    }

    private func leaseInputs(
        traceID: String,
        sourceHost: String,
        vendorID: String,
        capability: ProviderCapability = .webSearch,
        costClass: ProviderCostClass = .meteredPremium,
        freshness: ProviderFreshness = .livePreferred
    ) throws -> LeaseInputs {
        let request = try preparedRequest(
            traceID: traceID,
            sourceHost: sourceHost,
            capability: capability,
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
                capability: capability,
                costClass: costClass,
                freshness: freshness
            ),
            requestedResultShape: .organicLinks
        )

        XCTAssertEqual(payloadDecision.state, .payloadPrepared)
        XCTAssertEqual(dispatchReceipt.state, .dispatchEligible)
        XCTAssertEqual(authorization.state, .authorized)
        return LeaseInputs(
            request: request,
            payloadDecision: payloadDecision,
            dispatchReceipt: dispatchReceipt,
            authorization: authorization
        )
    }

    private func preparedRequest(
        traceID: String,
        sourceHost: String,
        capability: ProviderCapability = .webSearch,
        costClass: ProviderCostClass = .meteredPremium,
        freshness: ProviderFreshness = .livePreferred
    ) throws -> ServerProviderSearchAPIAdapterRequest {
        let decision = ServerProviderSearchAPIAdapterContract.prepareRequest(
            envelope: searchEnvelope(
                traceID: traceID,
                capability: capability,
                costClass: costClass,
                freshness: freshness,
                sourceHost: sourceHost
            ),
            connectorReceipt: connectorReceipt(
                traceID: traceID,
                capability: capability,
                costClass: costClass,
                freshness: freshness
            ),
            query: ServerProviderSearchAPIAdapterQuery(text: "public coffee"),
            resultLimit: 4
        )
        XCTAssertEqual(decision.state, .requestPrepared)
        return try XCTUnwrap(decision.request)
    }

    private func rejectedPayloadDecision() throws -> ServerProviderSearchAPIAdapterPayloadDecision {
        let decision = ServerProviderSearchAPIAdapterContract.prepareRequest(
            envelope: searchEnvelope(
                traceID: "a112-rejected-payload",
                privacyClass: .private,
                sourceHost: "a112-rejected-payload.example.com"
            ),
            connectorReceipt: connectorReceipt(traceID: "a112-rejected-payload"),
            query: ServerProviderSearchAPIAdapterQuery(text: "public coffee")
        )
        let payloadDecision = ServerProviderSearchAPIAdapterPayloadBuilder.build(
            from: decision
        )

        XCTAssertEqual(decision.state, .rejected)
        XCTAssertEqual(payloadDecision.state, .rejected)
        XCTAssertEqual(payloadDecision.rejection, .requestDecisionRejected)
        return payloadDecision
    }

    private func blockedDispatchReceipt() throws -> ServerProviderSearchAPIAdapterPayloadDispatchReceipt {
        let request = try preparedRequest(
            traceID: "a112-blocked-dispatch-baseline",
            sourceHost: "a112-blocked-dispatch-baseline.example.com"
        )
        let receipt = ServerProviderSearchAPIAdapterPayloadDispatchGate.evaluate(
            payloadDecision: try rejectedPayloadDecision(),
            request: request
        )

        XCTAssertEqual(receipt.state, .blocked)
        XCTAssertEqual(receipt.rejection, .payloadDecisionRejected)
        return receipt
    }

    private func vendorBlockedAuthorization() throws -> ServerProviderSearchAPIVendorPolicyDispatchAuthorization {
        let inputs = try leaseInputs(
            traceID: "a112-vendor-blocked",
            sourceHost: "a112-vendor-blocked.example.com",
            vendorID: "a112-vendor-blocked-bootstrap"
        )
        let authorization = ServerProviderSearchAPIVendorPolicyDispatchAuthorizationGate.authorize(
            dispatchReceipt: inputs.dispatchReceipt,
            vendorDecision: rejectedVendorDecision(vendorID: "a112-private-vendor"),
            requestedResultShape: .organicLinks
        )

        XCTAssertEqual(authorization.state, .rejected)
        XCTAssertEqual(authorization.rejection, .vendorPolicyNotAccepted)
        return authorization
    }

    private func acceptedVendorDecision(
        vendorID: String,
        providerFamily: ProviderFamily = .searchAPI,
        capability: ProviderCapability = .webSearch,
        costClass: ProviderCostClass = .meteredPremium,
        freshness: ProviderFreshness = .livePreferred,
        resultShape: ServerProviderSearchAPIVendorResultShape = .organicLinks
    ) -> ServerProviderSearchAPIVendorPolicyDecision {
        let decision = ServerProviderSearchAPIVendorPolicy.evaluate(
            context: ServerProviderSearchAPIVendorPolicyContext(
                providerFamily: providerFamily,
                capability: capability,
                privacyClass: .general,
                costClass: costClass,
                freshness: freshness,
                citationRequired: true,
                sourceHostRequired: true,
                pageBodyRequirement: .snippetsOnly,
                allowedRetention: .ephemeralOnly,
                resultShape: resultShape,
                quotaSnapshot: quotaSnapshot(for: costClass)
            ),
            vendor: vendorPolicy(
                id: vendorID,
                costClass: costClass,
                supportedFreshness: [.cachedOK, .livePreferred, .liveRequired],
                supportedResultShapes: [.organicLinks, .answerSummary, .documentSnippets]
            )
        )
        XCTAssertEqual(decision.state, .accepted)
        return decision
    }

    private func rejectedVendorDecision(
        vendorID: String
    ) -> ServerProviderSearchAPIVendorPolicyDecision {
        let decision = ServerProviderSearchAPIVendorPolicy.evaluate(
            context: ServerProviderSearchAPIVendorPolicyContext(
                providerFamily: .searchAPI,
                capability: .webSearch,
                privacyClass: .private,
                costClass: .meteredPremium,
                freshness: .livePreferred,
                citationRequired: true,
                sourceHostRequired: true,
                pageBodyRequirement: .snippetsOnly,
                allowedRetention: .ephemeralOnly,
                resultShape: .organicLinks,
                quotaSnapshot: quotaSnapshot(for: .meteredPremium)
            ),
            vendor: vendorPolicy(id: vendorID, costClass: .meteredPremium)
        )
        XCTAssertEqual(decision.state, .rejected)
        XCTAssertEqual(decision.rejection, .privacyBlocked)
        return decision
    }

    private func vendorPolicy(
        id: String,
        costClass: ProviderCostClass,
        supportedFreshness: Set<ProviderFreshness> = [.cachedOK, .livePreferred, .liveRequired],
        supportedResultShapes: Set<ServerProviderSearchAPIVendorResultShape> = [
            .organicLinks,
            .answerSummary,
            .documentSnippets,
        ]
    ) -> ServerProviderSearchAPIVendorPolicyDescriptor {
        ServerProviderSearchAPIVendorPolicyDescriptor(
            id: id,
            costClass: costClass,
            supportedFreshness: supportedFreshness,
            citationSupport: ServerProviderSearchAPIVendorCitationSupport(
                supportsCitations: true,
                supportsSourceHost: true,
                supportsAttribution: true
            ),
            pageBodyMode: .optional,
            requiredRetention: .ephemeralOnly,
            supportedResultShapes: supportedResultShapes
        )
    }

    private func quotaSnapshot(
        for costClass: ProviderCostClass
    ) -> ServerProviderQuotaSnapshot {
        switch costClass {
        case .includedQuota:
            return ServerProviderQuotaSnapshot(
                allowedProviderFamilies: [.searchAPI],
                entitledProviderFamilies: [.searchAPI],
                remainingIncludedQuota: [.searchAPI: 2]
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

    private func meteredBudget(
        id: String = "a112-budget-metered",
        vendorID: String = "a112-matrix-vendor",
        providerFamily: ProviderFamily = .searchAPI,
        capability: ProviderCapability = .webSearch,
        costClass: ProviderCostClass = .meteredPremium,
        freshness: ProviderFreshness = .livePreferred
    ) -> ServerProviderSearchAPITransportBudgetContext {
        budget(
            id: id,
            allowed: [.searchAPI],
            entitled: [.searchAPI],
            meteredEligible: [.searchAPI],
            metadataProviderFamily: providerFamily,
            metadataVendorID: vendorID,
            metadataCapability: capability,
            metadataCostClass: costClass,
            metadataFreshness: freshness,
            allowedCostClasses: [.meteredPremium]
        )
    }

    private func includedBudget(
        id: String = "a112-budget-included",
        vendorID: String = "a112-included-vendor",
        freshness: ProviderFreshness = .cachedOK,
        remaining: Int
    ) -> ServerProviderSearchAPITransportBudgetContext {
        ServerProviderSearchAPITransportBudgetContext(
            id: id,
            quotaSnapshot: ServerProviderQuotaSnapshot(
                allowedProviderFamilies: [.searchAPI],
                entitledProviderFamilies: [.searchAPI],
                remainingIncludedQuota: [.searchAPI: remaining]
            ),
            allowedCostClasses: [.includedQuota],
            meteredDecisionID: "\(id)-metered-decision",
            providerFamily: .searchAPI,
            vendorID: vendorID,
            capability: .webSearch,
            costClass: .includedQuota,
            freshness: freshness
        )
    }

    private func budget(
        id: String? = nil,
        allowed: Set<ProviderFamily>,
        entitled: Set<ProviderFamily>,
        meteredEligible: Set<ProviderFamily> = [],
        disabled: Set<ProviderFamily> = [],
        metadataProviderFamily: ProviderFamily = .searchAPI,
        metadataVendorID: String = "a112-matrix-vendor",
        metadataCapability: ProviderCapability = .webSearch,
        metadataCostClass: ProviderCostClass = .meteredPremium,
        metadataFreshness: ProviderFreshness = .livePreferred,
        allowedCostClasses: Set<ProviderCostClass>
    ) -> ServerProviderSearchAPITransportBudgetContext {
        ServerProviderSearchAPITransportBudgetContext(
            id: id ?? "a112-budget-\(allowedCostClasses.map(\.rawValue).sorted().joined(separator: "-"))",
            quotaSnapshot: ServerProviderQuotaSnapshot(
                allowedProviderFamilies: allowed,
                entitledProviderFamilies: entitled,
                meteredEligibleProviderFamilies: meteredEligible,
                disabledProviderFamilies: disabled
            ),
            allowedCostClasses: allowedCostClasses,
            meteredDecisionID: "\(id ?? "a112-budget")-metered-decision",
            providerFamily: metadataProviderFamily,
            vendorID: metadataVendorID,
            capability: metadataCapability,
            costClass: metadataCostClass,
            freshness: metadataFreshness
        )
    }

    private func meteredUsageDecision(
        id: String,
        providerFamily: ProviderFamily = .searchAPI,
        snapshotProviderFamily: ProviderFamily? = nil,
        vendorID: String = "a122-search-vendor",
        snapshotVendorID: String? = nil,
        capability: ProviderCapability = .webSearch,
        estimatedUnits: Int = 4,
        costClass: ProviderCostClass = .meteredPremium,
        privacyClass: ProviderPrivacyClass = .general,
        freshness: ProviderFreshness = .livePreferred,
        membershipTier: MembershipTier = .plus,
        hasEntitlement: Bool = true,
        remainingUnits: Int = 40,
        sourceTimestamp: Date? = nil,
        staleAfter: TimeInterval = 600
    ) -> ServerProviderMeteredUsageDecision {
        ServerProviderMeteredEntitlementLedger.evaluate(
            request: ServerProviderMeteredUsageRequest(
                id: id,
                traceID: "\(id)-trace",
                providerFamily: providerFamily,
                vendorID: vendorID,
                capability: capability,
                estimatedUnits: estimatedUnits,
                costClass: costClass,
                privacyClass: privacyClass,
                freshness: freshness,
                membershipTier: membershipTier,
                currencyCode: "usd",
                unitLabel: "search-unit",
                userFacingReason: "public-info lookup"
            ),
            snapshot: ServerProviderMeteredEntitlementSnapshot(
                id: "\(id)-snapshot",
                providerFamily: snapshotProviderFamily ?? providerFamily,
                vendorID: snapshotVendorID ?? vendorID,
                capability: capability,
                costClass: costClass,
                isVendorEnabled: true,
                membershipTier: membershipTier,
                minimumMembershipTier: .plus,
                hasEntitlement: hasEntitlement,
                quotaPeriodID: "a122-2026-05",
                includedUnits: 100,
                usedUnits: 12,
                reservedUnits: 8,
                remainingUnits: remainingUnits,
                currencyCode: "usd",
                unitLabel: "search-unit",
                sourceTimestamp: sourceTimestamp ?? now,
                staleAfter: staleAfter
            ),
            now: now
        )
    }

    private func searchEnvelope(
        traceID: String,
        providerFamily: ProviderFamily = .searchAPI,
        capability: ProviderCapability = .webSearch,
        privacyClass: ProviderPrivacyClass = .general,
        costClass: ProviderCostClass = .meteredPremium,
        freshness: ProviderFreshness = .livePreferred,
        sourceHost: String
    ) -> ServerProviderEnvelope {
        ServerProviderEnvelope(
            traceID: traceID,
            capability: capability,
            providerFamily: providerFamily,
            privacyClass: privacyClass,
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
        )
    }

    private func connectorReceipt(
        traceID: String,
        providerFamily: ProviderFamily = .searchAPI,
        capability: ProviderCapability = .webSearch,
        costClass: ProviderCostClass = .meteredPremium,
        freshness: ProviderFreshness = .livePreferred
    ) -> ServerProviderRuntimeConnectorInvocationReceipt {
        ServerProviderRuntimeConnectorInvocationReceipt(
            id: "a112-connector-receipt-\(traceID)",
            state: .receiptPrepared,
            statusLine: "A112 connector receipt fixture is metadata only. No provider runtime has run.",
            planningID: "a112-planning-\(traceID)",
            planningState: .requestPrepared,
            planningRejection: nil,
            connectorProviderFamily: providerFamily,
            requestID: "a112-connector-request-\(traceID)",
            resultID: "a112-connector-result-\(traceID)",
            connectorResultState: .metadataPrepared,
            connectorRejection: nil,
            providerFamily: providerFamily,
            capability: capability,
            costClass: costClass,
            freshness: freshness,
            manifestID: "provider-runtime-adapter-manifest-searchAPI",
            authorizationID: "a112-authorization-\(traceID)",
            boundaryID: "a112-boundary-\(traceID)",
            traceID: traceID,
            invocationRejection: nil
        )
    }

    private func sourcePolicy(
        sourceState: ServerSourcePolicyState,
        attributionRequired: Bool
    ) -> ServerProviderSearchAPIAdapterSourcePolicySnapshot {
        ServerProviderSearchAPIAdapterSourcePolicySnapshot(
            sourcePolicy: ServerSourcePolicy(
                sourceState: sourceState,
                attributionRequired: attributionRequired,
                sourceHost: "a112-policy.example.com"
            )
        )
    }

    private func payload(
        _ inputs: LeaseInputs
    ) -> ServerProviderSearchAPIAdapterTransportPayload {
        inputs.payloadDecision.payload!
    }

    private func copy(
        _ decision: ServerProviderSearchAPIAdapterPayloadDecision,
        id: String? = nil,
        payload: ServerProviderSearchAPIAdapterTransportPayload?
    ) -> ServerProviderSearchAPIAdapterPayloadDecision {
        ServerProviderSearchAPIAdapterPayloadDecision(
            id: id ?? decision.id,
            state: decision.state,
            statusLine: decision.statusLine,
            requestID: decision.requestID,
            payload: payload,
            rejection: decision.rejection,
            requestDecisionRejection: decision.requestDecisionRejection
        )
    }

    private func copy(
        _ payload: ServerProviderSearchAPIAdapterTransportPayload,
        providerFamily: ProviderFamily? = nil,
        capability: ProviderCapability? = nil,
        costClass: ProviderCostClass? = nil,
        freshness: ProviderFreshness? = nil,
        sourcePolicy: ServerProviderSearchAPIAdapterSourcePolicySnapshot? = nil
    ) -> ServerProviderSearchAPIAdapterTransportPayload {
        ServerProviderSearchAPIAdapterTransportPayload(
            id: payload.id,
            requestID: payload.requestID,
            traceID: payload.traceID,
            providerFamily: providerFamily ?? payload.providerFamily,
            capability: capability ?? payload.capability,
            costClass: costClass ?? payload.costClass,
            freshness: freshness ?? payload.freshness,
            resultLimit: payload.resultLimit,
            query: payload.query,
            sourcePolicy: sourcePolicy ?? payload.sourcePolicy
        )
    }

    private func copy(
        _ receipt: ServerProviderSearchAPIAdapterPayloadDispatchReceipt,
        payloadID: String? = nil,
        sourcePolicy: ServerProviderSearchAPIAdapterSourcePolicySnapshot? = nil
    ) -> ServerProviderSearchAPIAdapterPayloadDispatchReceipt {
        ServerProviderSearchAPIAdapterPayloadDispatchReceipt(
            id: receipt.id,
            state: receipt.state,
            statusLine: receipt.statusLine,
            payloadDecisionID: receipt.payloadDecisionID,
            payloadID: payloadID ?? receipt.payloadID,
            requestID: receipt.requestID,
            traceID: receipt.traceID,
            providerFamily: receipt.providerFamily,
            capability: receipt.capability,
            freshness: receipt.freshness,
            costClass: receipt.costClass,
            resultLimit: receipt.resultLimit,
            sourcePolicy: sourcePolicy ?? receipt.sourcePolicy,
            rejection: receipt.rejection,
            payloadDecisionRejection: receipt.payloadDecisionRejection,
            requestDecisionRejection: receipt.requestDecisionRejection
        )
    }

    private func copy(
        _ authorization: ServerProviderSearchAPIVendorPolicyDispatchAuthorization,
        dispatchReceiptID: String
    ) -> ServerProviderSearchAPIVendorPolicyDispatchAuthorization {
        ServerProviderSearchAPIVendorPolicyDispatchAuthorization(
            id: "\(authorization.id)-copy",
            state: authorization.state,
            statusLine: authorization.statusLine,
            dispatchReceiptID: dispatchReceiptID,
            dispatchState: authorization.dispatchState,
            dispatchRejection: authorization.dispatchRejection,
            vendorDecisionID: authorization.vendorDecisionID,
            vendorDecisionState: authorization.vendorDecisionState,
            vendorPolicyRejection: authorization.vendorPolicyRejection,
            vendorID: authorization.vendorID,
            providerFamily: authorization.providerFamily,
            capability: authorization.capability,
            costClass: authorization.costClass,
            freshness: authorization.freshness,
            resultShape: authorization.resultShape,
            rejection: authorization.rejection
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
