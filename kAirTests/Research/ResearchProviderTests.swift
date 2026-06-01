//
//  ResearchProviderTests.swift
//  kAirTests
//
//  Reserved interface R1 (kair-architecture-redesign-v2.md §5.1): academic /
//  scholarly research sources. Coverage: citation-first invariant, Google
//  Scholar compliance block, IEEE paywall + metered gating, PubMed membership +
//  health-adjacency, the remote-privacy gate (cache still works), disabled-by-
//  default, and preferred-source ordering. Pure policy — no network, no keys.
//

import XCTest
@testable import kAir

final class ResearchProviderTests: XCTestCase {

    // MARK: - Free official-API source resolves, always cited

    func test_arxiv_freeSource_resolvesWithCitation() {
        let decision = ResearchProviderPolicy.evaluate(
            Self.request(membershipTier: .free, citationDraft: Self.draft())
        )
        XCTAssertTrue(decision.isResolved)
        XCTAssertEqual(decision.selectedSource?.source, .arxiv)
        XCTAssertEqual(decision.citation?.sourceID, ResearchSource.arxiv.rawValue)
        XCTAssertEqual(decision.citation?.isCited, true)   // cite-first invariant
        XCTAssertNil(decision.failureReason)
    }

    func test_resolvedCitation_alwaysCarriesSourceURL() {
        let decision = ResearchProviderPolicy.evaluate(
            Self.request(citationDraft: Self.draft())
        )
        XCTAssertNotNil(decision.citation)
        XCTAssertFalse(decision.citation?.url.absoluteString.isEmpty ?? true)
    }

    // MARK: - Google Scholar: no official API -> compliance-blocked in v1

    func test_googleScholar_isComplianceBlocked_evenWhenEnabledAndEntitled() {
        let decision = ResearchProviderPolicy.evaluate(
            Self.request(
                preferredSource: .googleScholar,
                membershipTier: .developerInternal,
                meteredEntitlements: [.googleScholar],
                enabledExperimentalSources: [.googleScholar],
                citationDraft: Self.draft()
            )
        )
        XCTAssertNotEqual(decision.selectedSource?.source, .googleScholar)
        XCTAssertTrue(decision.skippedSources.contains {
            $0.source == .googleScholar && $0.reason == .complianceReviewRequired
        })
    }

    // MARK: - IEEE: paywalled full text, metered premium

    func test_ieee_abstractFetch_isPaywallBlocked() {
        let decision = ResearchProviderPolicy.evaluate(
            Self.request(
                capability: .abstractFetch,
                membershipTier: .pro,
                meteredEntitlements: [.ieee],
                citationDraft: Self.draft()
            ),
            registry: [Self.descriptor(.ieee)]
        )
        XCTAssertFalse(decision.isResolved)
        XCTAssertEqual(decision.failureReason, .paywallBlocked)
    }

    func test_ieee_paperMetadata_resolvesWithEntitlement_carriesPaywallLimitation() {
        let decision = ResearchProviderPolicy.evaluate(
            Self.request(
                capability: .paperMetadata,
                membershipTier: .pro,
                meteredEntitlements: [.ieee],
                citationDraft: Self.draft()
            ),
            registry: [Self.descriptor(.ieee)]
        )
        XCTAssertTrue(decision.isResolved)
        XCTAssertEqual(decision.selectedSource?.source, .ieee)
        XCTAssertEqual(
            decision.citation?.limitations.contains { $0.localizedCaseInsensitiveContains("paywalled") },
            true
        )
    }

    func test_ieee_withoutEntitlement_isCostBlocked() {
        let decision = ResearchProviderPolicy.evaluate(
            Self.request(capability: .paperMetadata, membershipTier: .pro, citationDraft: Self.draft()),
            registry: [Self.descriptor(.ieee)]
        )
        XCTAssertFalse(decision.isResolved)
        XCTAssertEqual(decision.failureReason, .costBlocked)
    }

    // MARK: - PubMed: membership-gated + health-adjacent privacy class

    func test_pubmed_requiresPlusMembership() {
        let free = ResearchProviderPolicy.evaluate(
            Self.request(membershipTier: .free, citationDraft: Self.draft()),
            registry: [Self.descriptor(.pubmed)]
        )
        XCTAssertEqual(free.failureReason, .costBlocked)

        let plus = ResearchProviderPolicy.evaluate(
            Self.request(membershipTier: .plus, citationDraft: Self.draft()),
            registry: [Self.descriptor(.pubmed)]
        )
        XCTAssertTrue(plus.isResolved)
        XCTAssertEqual(plus.selectedSource?.source, .pubmed)
    }

    func test_pubmed_isMarkedHealthAdjacent() {
        let pubmed = ResearchSourceDescriptor.defaultRegistry.first { $0.source == .pubmed }
        XCTAssertNotEqual(pubmed?.privacyClass, .general)
        XCTAssertEqual(pubmed?.privacyClass.allowsRemoteProvider, false)
    }

    // MARK: - Privacy gate: non-general query never reaches a remote source

    func test_nonGeneralQuery_blocksRemoteSources() {
        let decision = ResearchProviderPolicy.evaluate(
            Self.request(privacyClass: .health, membershipTier: .pro, citationDraft: Self.draft()),
            registry: [Self.descriptor(.arxiv)]
        )
        XCTAssertFalse(decision.isResolved)
        XCTAssertEqual(decision.failureReason, .privacyBlocked)
    }

    func test_nonGeneralQuery_cacheStillReturnsCachedCitation() {
        let decision = ResearchProviderPolicy.evaluate(
            Self.request(privacyClass: .health, cachedCitation: Self.cached()),
            registry: [Self.descriptor(.cache)]
        )
        XCTAssertTrue(decision.isResolved)
        XCTAssertEqual(decision.selectedSource?.source, .cache)
        XCTAssertEqual(decision.citation?.costClass, .freeLocal)
        XCTAssertEqual(decision.citation?.isStaleCache, true)
    }

    // MARK: - No-official-API source is disabled until explicitly enabled

    func test_noOfficialAPISource_isDisabledUntilEnabled() {
        let experimental = ResearchSourceDescriptor(
            source: .googleScholar,            // reuse a case; override the flags
            displayName: "Experimental Source",
            supportedCapabilities: [.scholarlySearch],
            minimumMembership: .free,
            costClass: .includedQuota,
            hasOfficialAPI: false,
            requiresComplianceReview: false,   // NOT compliance-blocked here
            fullTextPaywalled: false,
            privacyClass: .general,
            priority: 5
        )
        let disabled = ResearchProviderPolicy.evaluate(
            Self.request(citationDraft: Self.draft()),
            registry: [experimental]
        )
        XCTAssertEqual(disabled.failureReason, .disabledByDefault)

        let enabled = ResearchProviderPolicy.evaluate(
            Self.request(enabledExperimentalSources: [.googleScholar], citationDraft: Self.draft()),
            registry: [experimental]
        )
        XCTAssertTrue(enabled.isResolved)
    }

    // MARK: - No candidate -> unresolved

    func test_noDraftNoCache_isUnresolved() {
        let decision = ResearchProviderPolicy.evaluate(
            Self.request(),
            registry: [Self.descriptor(.arxiv)]
        )
        XCTAssertFalse(decision.isResolved)
        XCTAssertEqual(decision.failureReason, .noResult)
    }

    // MARK: - Preferred source ordering + registry sanity

    func test_preferredSource_isTriedFirst() {
        let decision = ResearchProviderPolicy.evaluate(
            Self.request(preferredSource: .semanticScholar, citationDraft: Self.draft())
        )
        XCTAssertEqual(decision.selectedSource?.source, .semanticScholar)
    }

    func test_defaultRegistry_sourceIdsAreUnique() {
        let ids = ResearchSourceDescriptor.defaultRegistry.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    // MARK: - Fixtures

    private static func draft() -> ResearchCitationDraft {
        ResearchCitationDraft(
            title: "On-Device Agents",
            authors: ["A. Researcher"],
            venue: "arXiv",
            url: URL(string: "https://arxiv.org/abs/2511.22138")!,
            year: 2025,
            doi: "10.48550/arXiv.2511.22138",
            isPeerReviewed: false,
            isOpenAccess: true,
            abstractAvailable: true,
            confidence: 0.8
        )
    }

    private static func cached() -> ResearchCitation {
        ResearchCitation(
            query: "prev",
            sourceID: "prev",
            title: "Cached Paper",
            authors: ["B. Author"],
            venue: "OpenAlex",
            year: 2024,
            doi: nil,
            url: URL(string: "https://openalex.org/W123")!,
            isPeerReviewed: true,
            isOpenAccess: true,
            abstractAvailable: false,
            fetchedAt: Date(timeIntervalSince1970: 1_700_000_000),
            freshness: .cachedOK,
            costClass: .includedQuota,
            confidence: 0.6,
            limitations: []
        )
    }

    private static func descriptor(_ source: ResearchSource) -> ResearchSourceDescriptor {
        ResearchSourceDescriptor.defaultRegistry.first { $0.source == source }!
    }

    private static func request(
        capability: ResearchCapability = .scholarlySearch,
        privacyClass: ProviderPrivacyClass = .general,
        preferredSource: ResearchSource? = nil,
        membershipTier: MembershipTier = .free,
        meteredEntitlements: Set<ResearchSource> = [],
        enabledExperimentalSources: Set<ResearchSource> = [],
        citationDraft: ResearchCitationDraft? = nil,
        cachedCitation: ResearchCitation? = nil
    ) -> ResearchProviderRequest {
        ResearchProviderRequest(
            query: "on-device agents",
            capability: capability,
            privacyClass: privacyClass,
            membershipTier: membershipTier,
            preferredSource: preferredSource,
            meteredEntitlements: meteredEntitlements,
            enabledExperimentalSources: enabledExperimentalSources,
            freshness: .livePreferred,
            citationDraft: citationDraft,
            cachedCitation: cachedCitation,
            now: Date(timeIntervalSince1970: 1_700_000_100)
        )
    }
}
