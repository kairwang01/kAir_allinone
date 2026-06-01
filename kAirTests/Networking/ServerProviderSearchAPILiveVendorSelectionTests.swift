//
//  ServerProviderSearchAPILiveVendorSelectionTests.swift
//  kAirTests
//
//  A150 Search API live vendor candidate selection matrix proof tests.
//

import XCTest
@testable import kAir

final class ServerProviderSearchAPILiveVendorSelectionTests: XCTestCase {

    func test_selectsFirstEligibleCandidateFromSafeMetadataOnly() throws {
        let request = selectionRequest(maxUnitMicros: 1_000)
        let first = candidate(
            id: "balanced-search",
            displayName: "Balanced Search",
            estimatedUnitMicros: 750,
            supportsAnswerGeneration: false
        )
        let second = candidate(
            id: "answer-search",
            displayName: "Answer Search",
            estimatedUnitMicros: 500,
            supportsAnswerGeneration: true
        )

        let decision = ServerProviderSearchAPILiveVendorSelection.evaluate(
            request: request,
            candidates: [first, second]
        )
        let repeated = ServerProviderSearchAPILiveVendorSelection.evaluate(
            request: request,
            candidates: [first, second]
        )

        assertSendable(decision)
        assertSendable(decision.safeCopy)
        XCTAssertEqual(decision, repeated)
        XCTAssertEqual(Set([decision]).count, 1)
        XCTAssertEqual(decision.state, .selected)
        XCTAssertTrue(decision.isSelected)
        XCTAssertEqual(decision.selectedCandidateID, "balanced-search")
        XCTAssertTrue(decision.rejectionReasons.isEmpty)
        XCTAssertTrue(decision.duplicateCandidateIDs.isEmpty)
        XCTAssertEqual(decision.candidateSummaries.map(\.id), ["balanced-search", "answer-search"])
        XCTAssertEqual(decision.candidateSummaries.map(\.isEligible), [true, true])
        XCTAssertEqual(decision.candidateSummaries.first?.costUnit, .request)
        XCTAssertEqual(decision.candidateSummaries.first?.estimatedUnitMicros, 750)
        XCTAssertEqual(decision.candidateSummaries.first?.latencyClass, .balanced)
        XCTAssertFalse(decision.candidateSummaries.first?.supportsAnswerGeneration ?? true)
        XCTAssertEqual(decision.safeCopy.selectedCandidateID, "balanced-search")
        XCTAssertTrue(decision.statusLine.contains("policy metadata only"))
        XCTAssertTrue(decision.statusLine.contains("No transport or provider runtime has run"))
    }

    func test_rejectionMatrixPreservesStableReasons() {
        let baseRequest = selectionRequest()
        let baseCandidate = candidate()
        let cases: [
            (
                id: String,
                request: ServerProviderSearchAPILiveVendorSelectionRequest,
                candidates: [ServerProviderSearchAPILiveVendorCandidate],
                expected: ServerProviderSearchAPILiveVendorSelectionRejectionReason
            )
        ] = [
            (
                "empty candidate list",
                baseRequest,
                [],
                .candidateListEmpty
            ),
            (
                "disabled vendor",
                baseRequest,
                [
                    candidate(
                        isEnabled: false,
                        disabledReason: .policyReviewRequired
                    ),
                ],
                .vendorDisabled
            ),
            (
                "over budget",
                selectionRequest(maxUnitMicros: 100),
                [candidate(estimatedUnitMicros: 500)],
                .unitPriceTooHigh
            ),
            (
                "missing citation support",
                baseRequest,
                [
                    candidate(
                        citationSupport: ServerProviderSearchAPIVendorCitationSupport(
                            supportsCitations: false,
                            supportsSourceHost: true,
                            supportsAttribution: true
                        )
                    ),
                ],
                .citationSupportMissing
            ),
            (
                "missing source support",
                baseRequest,
                [
                    candidate(
                        citationSupport: ServerProviderSearchAPIVendorCitationSupport(
                            supportsCitations: true,
                            supportsSourceHost: false,
                            supportsAttribution: true
                        )
                    ),
                ],
                .sourceSupportMissing
            ),
            (
                "page body policy mismatch",
                selectionRequest(pageBodyRequirement: .snippetsOnly),
                [candidate(pageBodyMode: .required)],
                .pageBodyPolicyMismatch
            ),
            (
                "retention conflict",
                selectionRequest(allowedRetention: .ephemeralOnly),
                [candidate(requiredRetention: .shortTermCache)],
                .retentionConflict
            ),
            (
                "unsupported region",
                selectionRequest(region: .china),
                [candidate(allowedRegions: [.northAmerica])],
                .unsupportedRegion
            ),
            (
                "health privacy block",
                selectionRequest(privacyClass: .health),
                [baseCandidate],
                .privacyBlocked
            ),
            (
                "unsupported freshness",
                selectionRequest(freshness: .liveRequired),
                [candidate(supportedFreshness: [.cachedOK])],
                .unsupportedFreshness
            ),
            (
                "unsupported result shape",
                selectionRequest(resultShape: .localBusiness),
                [candidate(supportedResultShapes: [.organicLinks])],
                .unsupportedResultShape
            ),
            (
                "missing quota",
                selectionRequest(quotaSnapshot: ServerProviderQuotaSnapshot()),
                [baseCandidate],
                .providerNotAllowed
            ),
            (
                "qps unavailable",
                baseRequest,
                [candidate(qpsClass: .unavailable)],
                .qpsUnavailable
            ),
            (
                "capability mismatch",
                selectionRequest(desiredCapability: .localServiceSearch),
                [candidate(capability: .webSearch)],
                .unsupportedCapability
            ),
            (
                "cost class mismatch",
                selectionRequest(costClass: .includedQuota, quotaSnapshot: Self.includedQuota()),
                [baseCandidate],
                .costClassMismatch
            ),
        ]

        for testCase in cases {
            let decision = ServerProviderSearchAPILiveVendorSelection.evaluate(
                request: testCase.request,
                candidates: testCase.candidates
            )

            XCTAssertEqual(decision.state, .rejected, testCase.id)
            XCTAssertFalse(decision.isSelected, testCase.id)
            XCTAssertNil(decision.selectedCandidateID, testCase.id)
            XCTAssertTrue(decision.rejectionReasons.contains(testCase.expected), testCase.id)
            XCTAssertTrue(decision.statusLine.contains("metadata policy"), testCase.id)
            XCTAssertTrue(
                decision.statusLine.contains("No transport or provider runtime has run"),
                testCase.id
            )
        }
    }

    func test_duplicateCandidateIDsKeepFirstOccurrence() {
        let request = selectionRequest(maxUnitMicros: 1_000)
        let first = candidate(
            id: "duplicate-vendor",
            displayName: "First Vendor",
            estimatedUnitMicros: 900,
            supportsAnswerGeneration: false
        )
        let duplicate = candidate(
            id: "duplicate vendor",
            displayName: "Later Vendor",
            estimatedUnitMicros: 100,
            supportsAnswerGeneration: true
        )

        let selected = ServerProviderSearchAPILiveVendorSelection.evaluate(
            request: request,
            candidates: [first, duplicate]
        )

        XCTAssertEqual(selected.state, .selected)
        XCTAssertEqual(selected.selectedCandidateID, "duplicate-vendor")
        XCTAssertEqual(selected.duplicateCandidateIDs, ["duplicate-vendor"])
        XCTAssertEqual(selected.candidateSummaries.count, 1)
        XCTAssertEqual(selected.candidateSummaries[0].displayName, "First Vendor")
        XCTAssertEqual(selected.candidateSummaries[0].estimatedUnitMicros, 900)
        XCTAssertFalse(selected.candidateSummaries[0].supportsAnswerGeneration)

        let blockedFirst = candidate(
            id: "blocked-duplicate",
            displayName: "Blocked First",
            isEnabled: false,
            disabledReason: .vendorPaused
        )
        let laterEligible = candidate(
            id: "blocked duplicate",
            displayName: "Later Eligible"
        )
        let rejected = ServerProviderSearchAPILiveVendorSelection.evaluate(
            request: request,
            candidates: [blockedFirst, laterEligible]
        )

        XCTAssertEqual(rejected.state, .rejected)
        XCTAssertNil(rejected.selectedCandidateID)
        XCTAssertEqual(rejected.duplicateCandidateIDs, ["blocked-duplicate"])
        XCTAssertTrue(rejected.rejectionReasons.contains(.duplicateCandidateID))
        XCTAssertTrue(rejected.rejectionReasons.contains(.vendorDisabled))
    }

    func test_decisionAndSafeCopyAreCodableAndDoNotExposeRuntimeFields() throws {
        let accepted = ServerProviderSearchAPILiveVendorSelection.evaluate(
            request: selectionRequest(),
            candidates: [candidate(id: "safe-vendor")]
        )
        let rejected = ServerProviderSearchAPILiveVendorSelection.evaluate(
            request: selectionRequest(privacyClass: .private),
            candidates: [candidate(id: "blocked-vendor")]
        )

        let encodedDecision = try encodedString(accepted)
        let decodedDecision = try JSONDecoder().decode(
            ServerProviderSearchAPILiveVendorSelectionDecision.self,
            from: try JSONEncoder().encode(accepted)
        )
        XCTAssertEqual(decodedDecision, accepted)
        XCTAssertEqual(decodedDecision.safeCopy, accepted.safeCopy)

        let text = [
            encodedDecision,
            try encodedString(accepted.safeCopy),
            try encodedString(rejected.safeCopy),
            accepted.description,
            rejected.description,
            accepted.statusLine,
            rejected.statusLine,
            accepted.safeCopy.description,
            rejected.safeCopy.description,
        ]
            .joined(separator: "\n")
            .lowercased()

        XCTAssertTrue(text.contains("policy metadata only"))
        XCTAssertTrue(text.contains("no transport or provider runtime has run"))
        for fragment in forbiddenRuntimeFragments() {
            XCTAssertFalse(
                text.contains(fragment),
                "Unexpected live vendor selection copy fragment: \(fragment)"
            )
        }
    }

    private func selectionRequest(
        desiredCapability: ProviderCapability = .webSearch,
        resultShape: ServerProviderSearchAPIVendorResultShape = .organicLinks,
        freshness: ProviderFreshness = .livePreferred,
        privacyClass: ProviderPrivacyClass = .general,
        costClass: ProviderCostClass = .meteredPremium,
        membershipTier: MembershipTier = .plus,
        region: ProviderRegion = .northAmerica,
        pageBodyRequirement: ServerProviderSearchAPIPageBodyRequirement = .snippetsOnly,
        allowedRetention: ServerProviderSearchAPIRetentionLevel = .ephemeralOnly,
        maxUnitMicros: Int = 1_000,
        quotaSnapshot: ServerProviderQuotaSnapshot = meteredQuota()
    ) -> ServerProviderSearchAPILiveVendorSelectionRequest {
        ServerProviderSearchAPILiveVendorSelectionRequest(
            desiredCapability: desiredCapability,
            resultShape: resultShape,
            freshness: freshness,
            privacyClass: privacyClass,
            costClass: costClass,
            membershipTier: membershipTier,
            region: region,
            citationRequired: true,
            sourceHostRequired: true,
            attributionRequired: true,
            pageBodyRequirement: pageBodyRequirement,
            allowedRetention: allowedRetention,
            maxUnitMicros: maxUnitMicros,
            quotaSnapshot: quotaSnapshot,
            userFacingPurpose: "public-info lookup"
        )
    }

    private func candidate(
        id: String = "test-vendor",
        displayName: String = "Test Vendor",
        providerFamily: ProviderFamily = .searchAPI,
        capability: ProviderCapability = .webSearch,
        costClass: ProviderCostClass = .meteredPremium,
        supportedResultShapes: Set<ServerProviderSearchAPIVendorResultShape> = [
            .organicLinks,
            .answerSummary,
        ],
        supportedFreshness: Set<ProviderFreshness> = [
            .cachedOK,
            .livePreferred,
        ],
        citationSupport: ServerProviderSearchAPIVendorCitationSupport = .full,
        pageBodyMode: ServerProviderSearchAPIVendorPageBodyMode = .optional,
        requiredRetention: ServerProviderSearchAPIRetentionLevel = .ephemeralOnly,
        costUnit: ServerProviderSearchAPILiveVendorCostUnit = .request,
        estimatedUnitMicros: Int = 500,
        quotaClass: ServerProviderSearchAPILiveVendorQuotaClass = .metered,
        qpsClass: ServerProviderSearchAPILiveVendorQPSClass = .standard,
        allowedRegions: Set<ProviderRegion> = [.global, .northAmerica],
        latencyClass: ServerProviderSearchAPILiveVendorLatencyClass = .balanced,
        supportsAnswerGeneration: Bool = true,
        minimumMembershipTier: MembershipTier = .plus,
        isEnabled: Bool = true,
        disabledReason: ServerProviderSearchAPILiveVendorDisabledReason? = nil
    ) -> ServerProviderSearchAPILiveVendorCandidate {
        ServerProviderSearchAPILiveVendorCandidate(
            id: id,
            displayName: displayName,
            providerFamily: providerFamily,
            capability: capability,
            costClass: costClass,
            supportedResultShapes: supportedResultShapes,
            supportedFreshness: supportedFreshness,
            citationSupport: citationSupport,
            pageBodyMode: pageBodyMode,
            requiredRetention: requiredRetention,
            costUnit: costUnit,
            estimatedUnitMicros: estimatedUnitMicros,
            quotaClass: quotaClass,
            qpsClass: qpsClass,
            allowedRegions: allowedRegions,
            latencyClass: latencyClass,
            supportsAnswerGeneration: supportsAnswerGeneration,
            minimumMembershipTier: minimumMembershipTier,
            isEnabled: isEnabled,
            disabledReason: disabledReason
        )
    }

    private static func meteredQuota() -> ServerProviderQuotaSnapshot {
        ServerProviderQuotaSnapshot(
            allowedProviderFamilies: [.searchAPI],
            entitledProviderFamilies: [.searchAPI],
            meteredEligibleProviderFamilies: [.searchAPI]
        )
    }

    private static func includedQuota() -> ServerProviderQuotaSnapshot {
        ServerProviderQuotaSnapshot(
            allowedProviderFamilies: [.searchAPI],
            entitledProviderFamilies: [.searchAPI],
            remainingIncludedQuota: [.searchAPI: 2]
        )
    }

    private func encodedString<T: Encodable>(
        _ value: T
    ) throws -> String {
        try XCTUnwrap(String(data: JSONEncoder().encode(value), encoding: .utf8))
    }

    private func assertSendable<T: Sendable>(
        _ value: T,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        _ = value
        XCTAssertTrue(true, file: file, line: line)
    }

    private func forbiddenRuntimeFragments() -> [String] {
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
            "crawl" + "er runtime",
            "m" + "cp runtime",
            "maps" + " " + "s" + "dk",
            "pay" + "ment",
            "book" + "ing",
            "ord" + "er",
            "hidden app" + "-control",
            "exec" + "ution",
            "exec" + "ute",
            "complete" + "d",
            "comple" + "tion",
        ]
    }
}
