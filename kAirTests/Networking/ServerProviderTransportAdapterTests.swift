//
//  ServerProviderTransportAdapterTests.swift
//  kAirTests
//
//  A135 value-only external provider transport adapter preflight tests.
//

import XCTest
@testable import kAir

final class ServerProviderTransportAdapterTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func test_defaultDescriptorsRepresentExternalProvidersWithoutRuntimeMaterial() {
        let descriptors = ServerProviderTransportAdapterDescriptor.defaultRegistry

        XCTAssertEqual(descriptors.count, 5)
        XCTAssertEqual(
            Set(descriptors.map(\.providerFamily)),
            [.searchAPI, .gaode, .googleMaps, .crawler, .mcp]
        )
        XCTAssertTrue(ServerProviderTransportAdapterDescriptor.searchAPI.requiresIssuedLease)
        XCTAssertTrue(ServerProviderTransportAdapterDescriptor.searchAPI.requiresMeteredDecision)
        XCTAssertTrue(ServerProviderTransportAdapterDescriptor.googleMaps.requiresMeteredEligibility)
        XCTAssertTrue(ServerProviderTransportAdapterDescriptor.gaode.requiresIncludedQuota)
        XCTAssertTrue(ServerProviderTransportAdapterDescriptor.crawler.requiresExperimentalEnablement)
        XCTAssertTrue(ServerProviderTransportAdapterDescriptor.mcp.requiresExperimentalEnablement)
        XCTAssertTrue(ServerProviderTransportAdapterDescriptor.mcp.requiresConfirmation)
        for descriptor in descriptors {
            XCTAssertEqual(descriptor.allowedPrivacyClasses, [.general], descriptor.id)
            assertSafeCopy(descriptor.description, descriptor.id)
        }
    }

    func test_preflightAcceptsEligibleSearchMapsCrawlerAndMCPMetadataOnly() {
        let cases: [
            (
                String,
                ServerProviderTransportAdapterDescriptor,
                ServerProviderTransportAdapterPreflightRequest
            )
        ] = [
            (
                "search",
                .searchAPI,
                preflightRequest(
                    id: "a135-search-accepted",
                    descriptor: .searchAPI,
                    sourcePolicy: publicSourcePolicy(),
                    meteredDecision: meteredDecision(
                        id: "a135-search-metered",
                        vendorID: "a135-search-vendor"
                    ),
                    transportLease: searchLease(
                        id: "a135-search-lease",
                        vendorID: "a135-search-vendor"
                    ),
                    expectedVendorID: "a135-search-vendor",
                    budgetEvidenceExpiresAt: now.addingTimeInterval(60)
                )
            ),
            (
                "gaode",
                .gaode,
                preflightRequest(
                    id: "a135-gaode-accepted",
                    descriptor: .gaode,
                    capability: .localServiceSearch,
                    sourcePolicy: attributionOnlyPolicy()
                )
            ),
            (
                "google",
                .googleMaps,
                preflightRequest(
                    id: "a135-google-accepted",
                    descriptor: .googleMaps,
                    capability: .placeSearch,
                    sourcePolicy: attributionOnlyPolicy()
                )
            ),
            (
                "crawler",
                .crawler,
                preflightRequest(
                    id: "a135-crawler-accepted",
                    descriptor: .crawler,
                    capability: .crawlerFetch,
                    membershipTier: .pro,
                    sourcePolicy: publicCrawlerPolicy(),
                    experimentalEnabled: true
                )
            ),
            (
                "mcp",
                .mcp,
                preflightRequest(
                    id: "a135-mcp-accepted",
                    descriptor: .mcp,
                    capability: .mcpTool,
                    membershipTier: .pro,
                    confirmationState: .confirmed(artifactID: "a135-mcp-confirmation"),
                    experimentalEnabled: true
                )
            ),
        ]

        for (name, descriptor, request) in cases {
            let decision = ValueOnlyServerProviderTransportAdapter(descriptor: descriptor)
                .preflight(request)
            let repeated = ValueOnlyServerProviderTransportAdapter(descriptor: descriptor)
                .preflight(request)

            XCTAssertEqual(decision, repeated, name)
            XCTAssertTrue(decision.isAccepted, name)
            XCTAssertNil(decision.rejectionReason, name)
            XCTAssertEqual(decision.providerFamily, descriptor.providerFamily, name)
            XCTAssertEqual(decision.capability, request.envelope.capability, name)
            XCTAssertEqual(decision.costClass, descriptor.costClass, name)
            XCTAssertTrue(decision.statusLine.contains("value-only metadata"), name)
            XCTAssertTrue(decision.statusLine.contains("No provider transport has run"), name)
            assertSafeCopy(decision.statusLine, name)
            assertSafeCopy(decision.description, name)
        }
    }

    func test_preflightRejectsPolicyBudgetAndLeaseFailuresBeforeRuntime() {
        let cases: [
            (
                String,
                ServerProviderTransportAdapterDescriptor,
                ServerProviderTransportAdapterPreflightRequest,
                ServerProviderTransportAdapterPreflightRejectionReason
            )
        ] = [
            (
                "membership too low",
                .searchAPI,
                preflightRequest(
                    id: "a135-membership-low",
                    descriptor: .searchAPI,
                    membershipTier: .free,
                    sourcePolicy: publicSourcePolicy()
                ),
                .membershipTierTooLow
            ),
            (
                "missing entitlement",
                .searchAPI,
                preflightRequest(
                    id: "a135-missing-entitlement",
                    descriptor: .searchAPI,
                    sourcePolicy: publicSourcePolicy(),
                    entitled: false
                ),
                .missingEntitlement
            ),
            (
                "health privacy",
                .googleMaps,
                preflightRequest(
                    id: "a135-health-blocked",
                    descriptor: .googleMaps,
                    capability: .placeSearch,
                    privacyClass: .health,
                    sourcePolicy: attributionOnlyPolicy()
                ),
                .privacyBlocked
            ),
            (
                "source missing",
                .searchAPI,
                preflightRequest(
                    id: "a135-source-missing",
                    descriptor: .searchAPI,
                    sourcePolicy: ServerSourcePolicy(
                        sourceState: .unknown,
                        robotsState: .notApplicable,
                        attributionRequired: true
                    )
                ),
                .sourcePolicyMissing
            ),
            (
                "attribution missing",
                .googleMaps,
                preflightRequest(
                    id: "a135-attribution-missing",
                    descriptor: .googleMaps,
                    capability: .placeSearch,
                    sourcePolicy: .notApplicable
                ),
                .attributionMissing
            ),
            (
                "crawler disabled",
                .crawler,
                preflightRequest(
                    id: "a135-crawler-disabled",
                    descriptor: .crawler,
                    capability: .crawlerFetch,
                    membershipTier: .pro,
                    sourcePolicy: publicCrawlerPolicy(),
                    experimentalEnabled: false
                ),
                .experimentalProviderDisabled
            ),
            (
                "mcp disabled",
                .mcp,
                preflightRequest(
                    id: "a135-mcp-disabled",
                    descriptor: .mcp,
                    capability: .mcpTool,
                    membershipTier: .pro,
                    confirmationState: .confirmed(artifactID: "a135-mcp-confirmed"),
                    experimentalEnabled: false
                ),
                .experimentalProviderDisabled
            ),
            (
                "unsupported capability",
                .googleMaps,
                preflightRequest(
                    id: "a135-unsupported-capability",
                    descriptor: .googleMaps,
                    capability: .webSearch,
                    sourcePolicy: attributionOnlyPolicy()
                ),
                .unsupportedCapability
            ),
            (
                "blocked cost",
                .searchAPI,
                preflightRequest(
                    id: "a135-blocked-cost",
                    descriptor: .searchAPI,
                    costClass: .blockedByCost,
                    sourcePolicy: publicSourcePolicy()
                ),
                .blockedCostClass
            ),
            (
                "stale budget",
                .searchAPI,
                preflightRequest(
                    id: "a135-stale-budget",
                    descriptor: .searchAPI,
                    sourcePolicy: publicSourcePolicy(),
                    meteredDecision: meteredDecision(
                        id: "a135-stale-metered",
                        vendorID: "a135-stale-vendor"
                    ),
                    transportLease: searchLease(
                        id: "a135-stale-lease",
                        vendorID: "a135-stale-vendor"
                    ),
                    expectedVendorID: "a135-stale-vendor",
                    budgetEvidenceExpiresAt: now.addingTimeInterval(-1)
                ),
                .staleBudgetEvidence
            ),
            (
                "lease mismatch",
                .searchAPI,
                preflightRequest(
                    id: "a135-lease-mismatch",
                    descriptor: .searchAPI,
                    sourcePolicy: publicSourcePolicy(),
                    meteredDecision: meteredDecision(
                        id: "a135-lease-metered",
                        vendorID: "a135-lease-vendor"
                    ),
                    transportLease: searchLease(
                        id: "a135-lease-mismatch",
                        vendorID: "a135-other-vendor"
                    ),
                    expectedVendorID: "a135-lease-vendor",
                    budgetEvidenceExpiresAt: now.addingTimeInterval(60)
                ),
                .transportLeaseMismatch
            ),
        ]

        for (name, descriptor, request, expectedReason) in cases {
            let decision = ValueOnlyServerProviderTransportAdapter(descriptor: descriptor)
                .preflight(request)

            XCTAssertFalse(decision.isAccepted, name)
            XCTAssertEqual(decision.state, .rejected, name)
            XCTAssertEqual(decision.rejectionReason, expectedReason, name)
            XCTAssertTrue(decision.statusLine.contains(expectedReason.rawValue), name)
            XCTAssertTrue(decision.statusLine.contains("No provider transport has run"), name)
            assertSafeCopy(decision.statusLine, name)
            assertSafeCopy(decision.description, name)
        }
    }

    func test_preflightEncodedDebugAndStatusCopiesStayValueOnly() throws {
        let accepted = ValueOnlyServerProviderTransportAdapter(descriptor: .searchAPI)
            .preflight(
                preflightRequest(
                    id: "a135-safe-copy",
                    descriptor: .searchAPI,
                    sourcePolicy: publicSourcePolicy(),
                    meteredDecision: meteredDecision(
                        id: "a135-safe-metered",
                        vendorID: "a135-safe-vendor"
                    ),
                    transportLease: searchLease(
                        id: "a135-safe-lease",
                        vendorID: "a135-safe-vendor"
                    ),
                    expectedVendorID: "a135-safe-vendor",
                    budgetEvidenceExpiresAt: now.addingTimeInterval(60)
                )
            )
        let rejected = ValueOnlyServerProviderTransportAdapter(descriptor: .mcp)
            .preflight(
                preflightRequest(
                    id: "a135-safe-rejected",
                    descriptor: .mcp,
                    capability: .mcpTool,
                    membershipTier: .pro,
                    experimentalEnabled: false
                )
            )
        let encodedDescriptors = try JSONEncoder().encode(
            ServerProviderTransportAdapterDescriptor.defaultRegistry
        )
        let encodedDecisions = try JSONEncoder().encode([accepted, rejected])
        let text = [
            String(data: encodedDescriptors, encoding: .utf8),
            String(data: encodedDecisions, encoding: .utf8),
            accepted.description,
            rejected.description,
            accepted.statusLine,
            rejected.statusLine,
        ]
            .compactMap { $0 }
            .joined(separator: "\n")
            .lowercased()

        assertSafeCopy(text, "encoded/debug/status copy")
    }

    private func preflightRequest(
        id: String,
        descriptor: ServerProviderTransportAdapterDescriptor,
        capability: ProviderCapability? = nil,
        privacyClass: ProviderPrivacyClass = .general,
        membershipTier: MembershipTier? = nil,
        costClass: ProviderCostClass? = nil,
        sourcePolicy: ServerSourcePolicy = .notApplicable,
        confirmationState: ServerConfirmationState = .notRequired,
        entitled: Bool = true,
        experimentalEnabled: Bool = false,
        meteredDecision: ServerProviderMeteredUsageDecision? = nil,
        transportLease: ServerProviderSearchAPITransportLease? = nil,
        expectedVendorID: String? = nil,
        budgetEvidenceExpiresAt: Date? = nil
    ) -> ServerProviderTransportAdapterPreflightRequest {
        let family = descriptor.providerFamily
        let resolvedCapability = capability ?? defaultCapability(for: descriptor)
        let resolvedMembership = membershipTier ?? descriptor.minimumMembershipTier
        let resolvedCost = costClass ?? descriptor.costClass
        let enabledExperimentalProviders: Set<ProviderFamily> = experimentalEnabled ? [family] : []
        let remainingIncludedQuota: [ProviderFamily: Int] = resolvedCost == .includedQuota
            ? [family: 5]
            : [:]
        let meteredEligible: Set<ProviderFamily> = resolvedCost == .meteredPremium
            ? [family]
            : []
        let entitlementSet: Set<ProviderFamily> = entitled ? [family] : []
        let profile = ProviderAccessProfile(
            membershipTier: resolvedMembership,
            meteredProviderEntitlements: entitlementSet,
            enabledExperimentalProviders: enabledExperimentalProviders
        )
        let quotaSnapshot = ServerProviderQuotaSnapshot(
            allowedProviderFamilies: [family],
            entitledProviderFamilies: entitlementSet,
            remainingIncludedQuota: remainingIncludedQuota,
            meteredEligibleProviderFamilies: meteredEligible,
            enabledExperimentalProviderFamilies: enabledExperimentalProviders
        )
        let envelope = ServerProviderEnvelope(
            traceID: "\(id)-trace",
            capability: resolvedCapability,
            providerFamily: family,
            privacyClass: privacyClass,
            membershipTier: resolvedMembership,
            costClass: resolvedCost,
            freshness: .livePreferred,
            sourcePolicy: sourcePolicy,
            confirmationState: confirmationState,
            meteredProviderEntitlements: entitlementSet,
            enabledExperimentalProviders: enabledExperimentalProviders
        )
        return ServerProviderTransportAdapterPreflightRequest(
            id: id,
            envelope: envelope,
            quotaSnapshot: quotaSnapshot,
            providerAccessProfile: profile,
            meteredDecision: meteredDecision,
            transportLease: transportLease,
            expectedVendorID: expectedVendorID,
            budgetEvidenceExpiresAt: budgetEvidenceExpiresAt,
            now: now
        )
    }

    private func publicSourcePolicy() -> ServerSourcePolicy {
        ServerSourcePolicy(
            sourceState: .passed,
            robotsState: .notApplicable,
            attributionRequired: true,
            sourceHost: "a135-public.example.com"
        )
    }

    private func defaultCapability(
        for descriptor: ServerProviderTransportAdapterDescriptor
    ) -> ProviderCapability {
        switch descriptor.providerFamily {
        case .searchAPI:
            return .webSearch
        case .gaode, .googleMaps:
            return .localServiceSearch
        case .crawler:
            return .crawlerFetch
        case .mcp:
            return .mcpTool
        case .appleLocal, .cache:
            return descriptor.supportedCapabilities.sorted { $0.rawValue < $1.rawValue }[0]
        }
    }

    private func publicCrawlerPolicy() -> ServerSourcePolicy {
        ServerSourcePolicy(
            sourceState: .passed,
            robotsState: .allowed,
            attributionRequired: true,
            sourceHost: "a135-crawler.example.com"
        )
    }

    private func attributionOnlyPolicy() -> ServerSourcePolicy {
        ServerSourcePolicy(
            sourceState: .notApplicable,
            robotsState: .notApplicable,
            attributionRequired: true
        )
    }

    private func meteredDecision(
        id: String,
        vendorID: String
    ) -> ServerProviderMeteredUsageDecision {
        let request = ServerProviderMeteredUsageRequest(
            id: id,
            traceID: "\(id)-trace",
            providerFamily: .searchAPI,
            vendorID: vendorID,
            capability: .webSearch,
            estimatedUnits: 4,
            costClass: .meteredPremium,
            freshness: .livePreferred,
            membershipTier: .plus,
            currencyCode: "usd",
            unitLabel: "search-unit",
            userFacingReason: "public info lookup"
        )
        let snapshot = ServerProviderMeteredEntitlementSnapshot(
            id: "\(id)-snapshot",
            providerFamily: .searchAPI,
            vendorID: vendorID,
            capability: .webSearch,
            costClass: .meteredPremium,
            membershipTier: .plus,
            minimumMembershipTier: .plus,
            quotaPeriodID: "\(id)-quota",
            includedUnits: 100,
            usedUnits: 10,
            reservedUnits: 4,
            remainingUnits: 86,
            currencyCode: "usd",
            unitLabel: "search-unit",
            sourceTimestamp: now,
            staleAfter: 600
        )
        let decision = ServerProviderMeteredEntitlementLedger.evaluate(
            request: request,
            snapshot: snapshot,
            now: now
        )

        XCTAssertTrue(decision.isAccepted)
        return decision
    }

    private func searchLease(
        id: String,
        vendorID: String,
        costClass: ProviderCostClass = .meteredPremium
    ) -> ServerProviderSearchAPITransportLease {
        ServerProviderSearchAPITransportLease(
            id: id,
            state: .issued,
            statusLine: "Search API transport lease is issued from verified metadata only. No transport or provider runtime has run.",
            payloadDecisionID: "\(id)-payload-decision",
            payloadID: "\(id)-payload",
            dispatchReceiptID: "\(id)-dispatch",
            authorizationID: "\(id)-authorization",
            budgetID: "\(id)-budget",
            vendorID: vendorID,
            providerFamily: .searchAPI,
            capability: .webSearch,
            costClass: costClass,
            freshness: .livePreferred,
            resultShape: .organicLinks,
            resultLimit: 5,
            sourceState: .passed,
            citationRequired: true,
            rejection: nil,
            payloadRejection: nil,
            dispatchRejection: nil,
            authorizationRejection: nil
        )
    }

    private func assertSafeCopy(
        _ text: String,
        _ context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let lowercased = text.lowercased()
        for fragment in forbiddenFragments() {
            XCTAssertFalse(
                lowercased.contains(fragment),
                "\(context): \(fragment)",
                file: file,
                line: line
            )
        }
    }

    private func forbiddenFragments() -> [String] {
        [
            "end" + "point",
            "http" + "://",
            "https" + "://",
            "api" + "key",
            "api" + "_" + "key",
            "bear" + "er",
            "tok" + "en",
            "creden" + "tial",
            "oa" + "uth",
            "url" + "session",
            "urlrequest",
            "s" + "dk",
            "raw" + " query",
            "raw" + " page",
            "raw" + "source",
            "source body",
            "citation url",
            "source-host",
            "store" + "kit",
            "pay" + "ment",
            "order",
            "book" + "ing",
            "hidden app",
            "completed",
            "complete",
            "done",
            "executed",
            "execution",
            "called provider",
            "provider call",
            "crawler runtime",
            "mcp runtime",
            "maps sdk",
        ]
    }
}
