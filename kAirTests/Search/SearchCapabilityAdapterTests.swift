//
//  SearchCapabilityAdapterTests.swift
//  kAirTests
//
//  A8 Search vertical adapter tests.
//

import XCTest
@testable import kAir

@MainActor
final class SearchCapabilityAdapterTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func test_searchIntent_lowersLifeServiceLookupToReadOnlyProviderRequest() throws {
        let intent = SearchIntent(
            query: "  late   night ramen  ",
            category: .lifeService,
            sourceMode: .searchAPI,
            privacyClass: .general,
            membershipTier: .plus,
            meteredProviderEntitlements: [.searchAPI],
            freshness: .livePreferred,
            requestedAt: now
        )
        let draft = try ramenDraft()

        let request = intent.providerRequest(resultDraft: draft, now: now)

        XCTAssertEqual(intent.query, "late night ramen")
        XCTAssertEqual(intent.capability, .webSearch)
        XCTAssertTrue(intent.isReadOnly)
        XCTAssertFalse(intent.canMutateMerchantState)
        XCTAssertFalse(intent.requiresUserConfirmation)
        XCTAssertFalse(intent.usesInAppCrawlerRuntime)
        XCTAssertEqual(request.capability, .localServiceSearch)
        XCTAssertEqual(request.preferredProvider, .searchAPI)
        XCTAssertEqual(request.privacyClass, .general)
        XCTAssertEqual(request.membershipTier, .plus)
        XCTAssertEqual(request.meteredProviderEntitlements, [.searchAPI])
    }

    func test_adapterAvailability_reflectsConfigurationOnly() async {
        let disabled = SearchCapabilityAdapter()
        let enabled = SearchCapabilityAdapter(
            configuration: .enabledFixture(now: now)
        )
        let disabledAvailable = await disabled.isAvailable()
        let enabledAvailable = await enabled.isAvailable()

        XCTAssertFalse(disabledAvailable)
        XCTAssertTrue(enabledAvailable)
    }

    func test_defaultConfigurationCarriesLocalOnlyProviderQuotaSnapshot() async {
        let configuration = SearchCapabilityAdapter.Configuration.disabled(now: now)
        let adapter = SearchCapabilityAdapter(configuration: configuration)
        let isAvailable = await adapter.isAvailable()

        XCTAssertEqual(
            configuration.providerQuotaSnapshot,
            ServerProviderQuotaSnapshot(providerAccessProfile: .freeLocalDefault)
        )
        XCTAssertEqual(configuration.providerQuotaSnapshot.allowedProviderFamilies, [.appleLocal, .cache])
        XCTAssertTrue(configuration.providerQuotaSnapshot.entitledProviderFamilies.isEmpty)
        XCTAssertTrue(configuration.providerQuotaSnapshot.meteredEligibleProviderFamilies.isEmpty)
        XCTAssertFalse(isAvailable)
    }

    func test_adapterResolve_returnsNormalizedWebSearchWithSourceAndConfidence() async throws {
        let query = "late night ramen"
        let adapter = SearchCapabilityAdapter(
            configuration: .enabledFixture(
                resultDrafts: [query: try ramenDraft()],
                now: now
            )
        )

        let result = try await adapter.resolve(
            CapabilityRequest(kind: .webSearch, inputText: query)
        )

        XCTAssertEqual(result.capability, .webSearch)
        XCTAssertEqual(result.source, .partner)
        XCTAssertEqual(result.confidence, 0.82)
        XCTAssertEqual(result.createdAt, now)
        XCTAssertTrue(
            NormalizedResult.variantMatchesCapability(result.payload, .webSearch)
        )

        guard case let .webSearch(hits) = result.payload else {
            return XCTFail("Expected webSearch payload")
        }
        XCTAssertEqual(hits.first?.title, "Late-night ramen hours")
        XCTAssertEqual(hits.first?.url, "https://example.com/ramen-hours")
        XCTAssertEqual(hits.first?.snippet, "Public listing with hours.")
    }

    func test_adapterDecisionUsesProviderAccessProfileForSearchEntitlement() throws {
        let query = "late night ramen"
        let adapter = SearchCapabilityAdapter(
            configuration: .enabledFixture(
                providerAccessProfile: ProviderAccessProfile(
                    membershipTier: .plus,
                    meteredProviderEntitlements: [.searchAPI]
                ),
                membershipTier: .free,
                meteredProviderEntitlements: [],
                resultDrafts: [query: try ramenDraft()],
                now: now
            )
        )
        let intent = try adapter.intent(from: CapabilityRequest(kind: .webSearch, inputText: query))

        let decision = adapter.decision(for: intent)

        XCTAssertEqual(intent.membershipTier, .plus)
        XCTAssertEqual(intent.meteredProviderEntitlements, [.searchAPI])
        XCTAssertTrue(decision.isResolved)
        XCTAssertEqual(decision.selectedProvider?.family, .searchAPI)
        XCTAssertEqual(decision.trace.membershipTier, .plus)
    }

    func test_providerAccessProfileDefaultsQuotaSnapshotThroughBridgeOnly() throws {
        let query = "late night ramen"
        let profile = ProviderAccessProfile(
            membershipTier: .plus,
            defaultRegion: .northAmerica,
            preferredProvider: .searchAPI,
            meteredProviderEntitlements: [.searchAPI]
        )
        let configuration = SearchCapabilityAdapter.Configuration.enabledFixture(
            providerAccessProfile: profile,
            resultDrafts: [query: try ramenDraft()],
            now: now
        )
        let adapter = SearchCapabilityAdapter(configuration: configuration)
        let intent = try adapter.intent(from: CapabilityRequest(kind: .webSearch, inputText: query))

        let decision = adapter.decision(for: intent)

        XCTAssertEqual(
            configuration.providerQuotaSnapshot,
            ServerProviderQuotaSnapshot(providerAccessProfile: profile)
        )
        XCTAssertEqual(configuration.providerQuotaSnapshot.allowedProviderFamilies, [.appleLocal, .cache])
        XCTAssertEqual(configuration.providerQuotaSnapshot.entitledProviderFamilies, [.searchAPI])
        XCTAssertTrue(configuration.providerQuotaSnapshot.meteredEligibleProviderFamilies.isEmpty)
        XCTAssertFalse(
            configuration.providerQuotaSnapshot.allowedProviderFamilies.contains(.searchAPI)
        )
        XCTAssertTrue(decision.isResolved)
        XCTAssertEqual(decision.selectedProvider?.family, .searchAPI)
    }

    func test_configurationStoresExplicitProviderQuotaSnapshotExactly() throws {
        let quota = ServerProviderQuotaSnapshot(
            providerAccessProfile: ProviderAccessProfile(
                membershipTier: .pro,
                meteredProviderEntitlements: [.searchAPI]
            ),
            allowedProviderFamilies: [.searchAPI],
            meteredEligibleProviderFamilies: [.searchAPI],
            disabledProviderFamilies: [.cache]
        )
        let configuration = SearchCapabilityAdapter.Configuration.enabledFixture(
            providerAccessProfile: .freeLocalDefault,
            providerQuotaSnapshot: quota,
            now: now
        )

        XCTAssertEqual(configuration.providerAccessProfile, .freeLocalDefault)
        XCTAssertEqual(configuration.providerQuotaSnapshot, quota)
        XCTAssertEqual(configuration.providerQuotaSnapshot.allowedProviderFamilies, [.searchAPI])
        XCTAssertEqual(configuration.providerQuotaSnapshot.entitledProviderFamilies, [.searchAPI])
        XCTAssertEqual(configuration.providerQuotaSnapshot.meteredEligibleProviderFamilies, [.searchAPI])
        XCTAssertEqual(configuration.providerQuotaSnapshot.disabledProviderFamilies, [.cache])
    }

    func test_dryRunPreview_profileOnlySearchIsBlockedByQuotaSnapshot() throws {
        let query = "late night ramen"
        let profile = ProviderAccessProfile(
            membershipTier: .plus,
            meteredProviderEntitlements: [.searchAPI]
        )
        let adapter = SearchCapabilityAdapter(
            configuration: .enabledFixture(
                providerAccessProfile: profile,
                resultDrafts: [query: try ramenDraft()],
                now: now
            )
        )
        let intent = try adapter.intent(from: CapabilityRequest(kind: .webSearch, inputText: query))

        let report = adapter.dryRunPreview(for: intent)

        XCTAssertEqual(report.status, .allCandidatesBlocked)
        XCTAssertNil(report.selected)
        XCTAssertEqual(report.candidates.count, 1)
        XCTAssertEqual(report.candidates[0].providerFamily, .searchAPI)
        XCTAssertEqual(report.candidates[0].fallbackReason, .factoryBlocked)
        XCTAssertEqual(report.candidates[0].factoryRejectionReason, .providerNotAllowed(.searchAPI))
    }

    func test_dryRunPreview_searchQuotaRequiresMeteredEligibility() throws {
        let query = "late night ramen"
        let profile = ProviderAccessProfile(
            membershipTier: .plus,
            meteredProviderEntitlements: [.searchAPI]
        )
        let quota = ServerProviderQuotaSnapshot(
            providerAccessProfile: profile,
            allowedProviderFamilies: [.searchAPI]
        )
        let adapter = SearchCapabilityAdapter(
            configuration: .enabledFixture(
                providerAccessProfile: profile,
                providerQuotaSnapshot: quota,
                resultDrafts: [query: try ramenDraft()],
                now: now
            )
        )
        let intent = try adapter.intent(from: CapabilityRequest(kind: .webSearch, inputText: query))

        let report = adapter.dryRunPreview(for: intent)

        XCTAssertEqual(report.status, .allCandidatesBlocked)
        XCTAssertNil(report.selected)
        XCTAssertEqual(report.candidates[0].providerFamily, .searchAPI)
        XCTAssertEqual(report.candidates[0].factoryRejectionReason, .meteredEligibilityMissing(.searchAPI))
    }

    func test_dryRunPreview_explicitSearchQuotaCanSelectEnvelope() throws {
        let query = "late night ramen"
        let profile = ProviderAccessProfile(
            membershipTier: .plus,
            meteredProviderEntitlements: [.searchAPI]
        )
        let quota = ServerProviderQuotaSnapshot(
            providerAccessProfile: profile,
            allowedProviderFamilies: [.searchAPI],
            meteredEligibleProviderFamilies: [.searchAPI]
        )
        let adapter = SearchCapabilityAdapter(
            configuration: .enabledFixture(
                providerAccessProfile: profile,
                providerQuotaSnapshot: quota,
                resultDrafts: [query: try ramenDraft()],
                now: now
            )
        )
        let intent = try adapter.intent(from: CapabilityRequest(kind: .webSearch, inputText: query))

        let report = adapter.dryRunPreview(for: intent)

        XCTAssertEqual(report.status, .selected)
        let selected = try XCTUnwrap(report.selected)
        XCTAssertEqual(selected.providerFamily, .searchAPI)
        XCTAssertEqual(selected.costClass, .meteredPremium)
        XCTAssertEqual(selected.freshness, .livePreferred)
        XCTAssertEqual(selected.sourcePolicy.sourceState, .passed)
        XCTAssertEqual(selected.sourcePolicy.sourceHost, "example.com")
        XCTAssertEqual(selected.fallbackReason, .selected)
        XCTAssertEqual(report.candidates[0].factoryRejectionReason, nil)
    }

    func test_dryRunPreview_acceptsPrecomputedDecisionWithoutCallingResolve() throws {
        let query = "late night ramen"
        let profile = ProviderAccessProfile(
            membershipTier: .plus,
            meteredProviderEntitlements: [.searchAPI]
        )
        let quota = ServerProviderQuotaSnapshot(
            providerAccessProfile: profile,
            allowedProviderFamilies: [.searchAPI],
            meteredEligibleProviderFamilies: [.searchAPI]
        )
        let adapter = SearchCapabilityAdapter(
            configuration: .enabledFixture(
                providerAccessProfile: profile,
                providerQuotaSnapshot: quota,
                resultDrafts: [query: try ramenDraft()],
                now: now
            )
        )
        let intent = try adapter.intent(from: CapabilityRequest(kind: .webSearch, inputText: query))
        let request = adapter.providerRequest(for: intent)
        let decision = adapter.decision(for: intent)

        let report = adapter.dryRunPreview(
            for: request,
            decision: decision,
            capabilityLabel: "Search preview"
        )

        XCTAssertEqual(report.capabilityLabel, "Search preview")
        XCTAssertEqual(report.status, .selected)
        XCTAssertEqual(report.selected?.providerFamily, .searchAPI)
        XCTAssertEqual(report.selected?.traceID, request.traceID)
    }

    func test_dryRunPresentation_selectedSearchPreservesRowsAndMetadata() throws {
        let query = "late night ramen"
        let profile = ProviderAccessProfile(
            membershipTier: .plus,
            meteredProviderEntitlements: [.searchAPI]
        )
        let quota = ServerProviderQuotaSnapshot(
            providerAccessProfile: profile,
            allowedProviderFamilies: [.searchAPI],
            meteredEligibleProviderFamilies: [.searchAPI]
        )
        let adapter = SearchCapabilityAdapter(
            configuration: .enabledFixture(
                providerAccessProfile: profile,
                providerQuotaSnapshot: quota,
                resultDrafts: [query: try ramenDraft()],
                now: now
            )
        )
        let intent = try adapter.intent(from: CapabilityRequest(kind: .webSearch, inputText: query))

        let presentation = adapter.dryRunPresentation(for: intent)

        XCTAssertTrue(presentation.hasSelection)
        XCTAssertEqual(presentation.tone, .warning)
        XCTAssertTrue(presentation.summary.contains("Search API"))
        let selectedRow = try XCTUnwrap(row(.selectedProvider, in: presentation))
        XCTAssertEqual(selectedRow.providerFamily, .searchAPI)
        XCTAssertEqual(selectedRow.costClass, .meteredPremium)
        XCTAssertEqual(selectedRow.freshness, .livePreferred)
        let costRow = try XCTUnwrap(row(.costStatus, in: presentation))
        XCTAssertEqual(costRow.costClass, .meteredPremium)
        let freshnessRow = try XCTUnwrap(row(.freshnessStatus, in: presentation))
        XCTAssertEqual(freshnessRow.freshness, .livePreferred)
        let sourceRow = try XCTUnwrap(row(.sourceStatus, in: presentation))
        XCTAssertEqual(sourceRow.sourcePolicy?.sourceState, .passed)
        XCTAssertEqual(sourceRow.sourcePolicy?.sourceHost, "example.com")
        XCTAssertTrue(presentation.rows.allSatisfy(\.isAdvisoryOnly))
    }

    func test_dryRunPresentation_blockedSearchPreservesFactoryRejection() throws {
        let query = "late night ramen"
        let profile = ProviderAccessProfile(
            membershipTier: .plus,
            meteredProviderEntitlements: [.searchAPI]
        )
        let adapter = SearchCapabilityAdapter(
            configuration: .enabledFixture(
                providerAccessProfile: profile,
                resultDrafts: [query: try ramenDraft()],
                now: now
            )
        )
        let intent = try adapter.intent(from: CapabilityRequest(kind: .webSearch, inputText: query))

        let presentation = adapter.dryRunPresentation(for: intent)

        XCTAssertFalse(presentation.hasSelection)
        XCTAssertEqual(presentation.tone, .warning)
        XCTAssertTrue(presentation.summary.contains("all provider candidates are blocked"))
        let blockedRow = try XCTUnwrap(row(.blockedCandidate, in: presentation))
        XCTAssertEqual(blockedRow.providerFamily, .searchAPI)
        XCTAssertEqual(blockedRow.factoryRejectionReason, .providerNotAllowed(.searchAPI))
        XCTAssertTrue(blockedRow.detail.contains("not allowed by the quota snapshot"))
        XCTAssertTrue(blockedRow.badges.contains { $0.label == "Search API" })
        XCTAssertTrue(presentation.rows.allSatisfy(\.isAdvisoryOnly))
    }

    func test_dryRunPresentation_acceptsPrecomputedReportAndKeepsCopyAdvisory() throws {
        let query = "late night ramen"
        let profile = ProviderAccessProfile(
            membershipTier: .plus,
            meteredProviderEntitlements: [.searchAPI]
        )
        let quota = ServerProviderQuotaSnapshot(
            providerAccessProfile: profile,
            allowedProviderFamilies: [.searchAPI],
            meteredEligibleProviderFamilies: [.searchAPI]
        )
        let adapter = SearchCapabilityAdapter(
            configuration: .enabledFixture(
                providerAccessProfile: profile,
                providerQuotaSnapshot: quota,
                resultDrafts: [query: try ramenDraft()],
                now: now
            )
        )
        let intent = try adapter.intent(from: CapabilityRequest(kind: .webSearch, inputText: query))
        let report = adapter.dryRunPreview(for: intent, capabilityLabel: "Search presentation")

        let presentation = adapter.dryRunPresentation(for: report)
        let copy = presentationCopy(in: presentation).joined(separator: "\n").lowercased()

        XCTAssertEqual(presentation.capabilityLabel, "Search presentation")
        XCTAssertTrue(copy.contains("dry run"))
        XCTAssertTrue(copy.contains("advisory"))
        for forbidden in ["completed", "complete", "done", "called", "booked", "ordered", "paid", "purchased", "crawled"] {
            XCTAssertFalse(copy.contains(forbidden), "Unexpected wording: \(forbidden)")
        }
    }

    func test_dryRunProviderStatusSource_selectedIntentUsesExplicitRecommendationID() throws {
        let query = "late night ramen"
        let recommendationID = "search-status-source-selected"
        let profile = ProviderAccessProfile(
            membershipTier: .plus,
            meteredProviderEntitlements: [.searchAPI]
        )
        let quota = ServerProviderQuotaSnapshot(
            providerAccessProfile: profile,
            allowedProviderFamilies: [.searchAPI],
            meteredEligibleProviderFamilies: [.searchAPI]
        )
        let adapter = SearchCapabilityAdapter(
            configuration: .enabledFixture(
                providerAccessProfile: profile,
                providerQuotaSnapshot: quota,
                resultDrafts: [query: try ramenDraft()],
                now: now
            )
        )
        let intent = try adapter.intent(from: CapabilityRequest(kind: .webSearch, inputText: query))

        let source = adapter.dryRunProviderStatusSource(
            forRecommendationID: recommendationID,
            intent: intent,
            capabilityLabel: "Search status"
        )
        let presentation = try XCTUnwrap(
            source.providerStatusPresentation(for: recommendationID)
        )

        XCTAssertEqual(source.recommendationIDs, [recommendationID])
        XCTAssertEqual(presentation.recommendationID, recommendationID)
        XCTAssertEqual(presentation.cardHint, .warning)
        XCTAssertEqual(badge(.remoteProvider, in: presentation)?.tone, .neutral)
        XCTAssertEqual(badge(.meteredPremium, in: presentation)?.tone, .neutral)
        XCTAssertEqual(badge(.liveFreshness, in: presentation)?.tone, .positive)
        XCTAssertTrue(presentation.statusLine.contains("premium metered"))
        XCTAssertTrue(presentation.statusLine.contains("example.com"))
        XCTAssertTrue(presentation.statusLine.contains("No provider was contacted"))
        XCTAssertNil(source.providerStatusPresentation(for: "late night ramen"))
        XCTAssertNil(source.providerStatusPresentation(for: "missing-search-status"))
    }

    func test_dryRunProviderStatusSource_reportInputPreservesBlockedFactoryReason() throws {
        let query = "late night ramen"
        let recommendationID = "search-status-source-blocked"
        let profile = ProviderAccessProfile(
            membershipTier: .plus,
            meteredProviderEntitlements: [.searchAPI]
        )
        let adapter = SearchCapabilityAdapter(
            configuration: .enabledFixture(
                providerAccessProfile: profile,
                resultDrafts: [query: try ramenDraft()],
                now: now
            )
        )
        let intent = try adapter.intent(from: CapabilityRequest(kind: .webSearch, inputText: query))
        let report = adapter.dryRunPreview(for: intent, capabilityLabel: "Blocked search")

        let source = adapter.dryRunProviderStatusSource(
            forRecommendationID: recommendationID,
            report: report
        )
        let presentation = try XCTUnwrap(
            source.providerStatusPresentation(for: recommendationID)
        )

        XCTAssertEqual(source.recommendationIDs, [recommendationID])
        XCTAssertEqual(presentation.cardHint, .disabled)
        XCTAssertEqual(badge(.termsBlocked, in: presentation)?.tone, .warning)
        XCTAssertTrue(presentation.statusLine.contains("all provider candidates are blocked"))
        XCTAssertTrue(presentation.statusLine.contains("Search API is not allowed"))
        XCTAssertTrue(presentation.statusLine.contains("not allowed by the quota snapshot"))
        XCTAssertNil(source.providerStatusPresentation(for: "missing-blocked-search"))
    }

    func test_dryRunProviderStatusSource_presentationInputDoesNotRequireMatchingObject() throws {
        let query = "late night ramen"
        let recommendationID = "caller-supplied-search-recommendation"
        let profile = ProviderAccessProfile(
            membershipTier: .plus,
            meteredProviderEntitlements: [.searchAPI]
        )
        let quota = ServerProviderQuotaSnapshot(
            providerAccessProfile: profile,
            allowedProviderFamilies: [.searchAPI],
            meteredEligibleProviderFamilies: [.searchAPI]
        )
        let adapter = SearchCapabilityAdapter(
            configuration: .enabledFixture(
                providerAccessProfile: profile,
                providerQuotaSnapshot: quota,
                resultDrafts: [query: try ramenDraft()],
                now: now
            )
        )
        let intent = try adapter.intent(from: CapabilityRequest(kind: .webSearch, inputText: query))
        let dryRunPresentation = adapter.dryRunPresentation(for: intent)

        let source = adapter.dryRunProviderStatusSource(
            forRecommendationID: recommendationID,
            presentation: dryRunPresentation
        )
        let presentation = try XCTUnwrap(
            source.providerStatusPresentation(for: recommendationID)
        )

        XCTAssertEqual(source.recommendationIDs, [recommendationID])
        XCTAssertEqual(presentation.recommendationID, recommendationID)
        XCTAssertEqual(presentation.cardHint, .warning)
        XCTAssertNil(source.providerStatusPresentation(for: RecommendationFixtures.placeRoute.id))
        XCTAssertNil(source.providerStatusPresentation(for: query))
    }

    func test_dryRunProviderStatusSource_copyStaysAdvisoryOnly() throws {
        let query = "late night ramen"
        let profile = ProviderAccessProfile(
            membershipTier: .plus,
            meteredProviderEntitlements: [.searchAPI]
        )
        let quota = ServerProviderQuotaSnapshot(
            providerAccessProfile: profile,
            allowedProviderFamilies: [.searchAPI],
            meteredEligibleProviderFamilies: [.searchAPI]
        )
        let selectedAdapter = SearchCapabilityAdapter(
            configuration: .enabledFixture(
                providerAccessProfile: profile,
                providerQuotaSnapshot: quota,
                resultDrafts: [query: try ramenDraft()],
                now: now
            )
        )
        let blockedAdapter = SearchCapabilityAdapter(
            configuration: .enabledFixture(
                providerAccessProfile: profile,
                resultDrafts: [query: try ramenDraft()],
                now: now
            )
        )
        let selectedIntent = try selectedAdapter.intent(
            from: CapabilityRequest(kind: .webSearch, inputText: query)
        )
        let blockedIntent = try blockedAdapter.intent(
            from: CapabilityRequest(kind: .webSearch, inputText: query)
        )
        let selectedSource = selectedAdapter.dryRunProviderStatusSource(
            forRecommendationID: "copy-selected",
            intent: selectedIntent
        )
        let blockedSource = blockedAdapter.dryRunProviderStatusSource(
            forRecommendationID: "copy-blocked",
            intent: blockedIntent
        )
        let presentations = try [
            selectedSource.providerStatusPresentation(for: "copy-selected"),
            blockedSource.providerStatusPresentation(for: "copy-blocked"),
        ].map { try XCTUnwrap($0) }
        let text = presentations
            .flatMap { [$0.statusLine] + $0.badges.map(\.label) }
            .joined(separator: "\n")
            .lowercased()

        XCTAssertTrue(text.contains("no provider was contacted"))
        for forbidden in [
            "completed",
            "complete",
            "done",
            "called",
            "provider contacted",
            "booked",
            "ordered",
            "paid",
            "purchased",
            "crawled",
        ] {
            XCTAssertFalse(text.contains(forbidden), "Unexpected wording: \(forbidden)")
        }
    }

    func test_dryRunProviderStatusSource_batchPresentationsMapsSelectedAndBlockedIDs() throws {
        let query = "late night ramen"
        let selectedID = "batch-selected"
        let blockedID = "batch-blocked"
        let profile = ProviderAccessProfile(
            membershipTier: .plus,
            meteredProviderEntitlements: [.searchAPI]
        )
        let quota = ServerProviderQuotaSnapshot(
            providerAccessProfile: profile,
            allowedProviderFamilies: [.searchAPI],
            meteredEligibleProviderFamilies: [.searchAPI]
        )
        let selectedAdapter = SearchCapabilityAdapter(
            configuration: .enabledFixture(
                providerAccessProfile: profile,
                providerQuotaSnapshot: quota,
                resultDrafts: [query: try ramenDraft()],
                now: now
            )
        )
        let blockedAdapter = SearchCapabilityAdapter(
            configuration: .enabledFixture(
                providerAccessProfile: profile,
                resultDrafts: [query: try ramenDraft()],
                now: now
            )
        )
        let selectedIntent = try selectedAdapter.intent(
            from: CapabilityRequest(kind: .webSearch, inputText: query)
        )
        let blockedIntent = try blockedAdapter.intent(
            from: CapabilityRequest(kind: .webSearch, inputText: query)
        )
        let selectedPresentation = selectedAdapter.dryRunPresentation(for: selectedIntent)
        let blockedPresentation = blockedAdapter.dryRunPresentation(for: blockedIntent)

        let source = selectedAdapter.dryRunProviderStatusSource(
            presentations: [
                (recommendationID: selectedID, presentation: selectedPresentation),
                (recommendationID: blockedID, presentation: blockedPresentation),
            ]
        )
        let selected = try XCTUnwrap(source.providerStatusPresentation(for: selectedID))
        let blocked = try XCTUnwrap(source.providerStatusPresentation(for: blockedID))

        XCTAssertEqual(source.recommendationIDs, [blockedID, selectedID])
        XCTAssertEqual(selected.recommendationID, selectedID)
        XCTAssertEqual(selected.cardHint, .warning)
        XCTAssertEqual(badge(.remoteProvider, in: selected)?.tone, .neutral)
        XCTAssertEqual(badge(.meteredPremium, in: selected)?.tone, .neutral)
        XCTAssertEqual(badge(.liveFreshness, in: selected)?.tone, .positive)
        XCTAssertTrue(selected.statusLine.contains("example.com"))
        XCTAssertEqual(blocked.recommendationID, blockedID)
        XCTAssertEqual(blocked.cardHint, .disabled)
        XCTAssertEqual(badge(.termsBlocked, in: blocked)?.tone, .warning)
        XCTAssertTrue(blocked.statusLine.contains("Search API is not allowed"))
        XCTAssertNil(source.providerStatusPresentation(for: "batch-missing"))
    }

    func test_dryRunProviderStatusSource_batchReportsKeepFirstDuplicateRecommendationID() throws {
        let query = "late night ramen"
        let duplicateID = "batch-duplicate"
        let profile = ProviderAccessProfile(
            membershipTier: .plus,
            meteredProviderEntitlements: [.searchAPI]
        )
        let quota = ServerProviderQuotaSnapshot(
            providerAccessProfile: profile,
            allowedProviderFamilies: [.searchAPI],
            meteredEligibleProviderFamilies: [.searchAPI]
        )
        let selectedAdapter = SearchCapabilityAdapter(
            configuration: .enabledFixture(
                providerAccessProfile: profile,
                providerQuotaSnapshot: quota,
                resultDrafts: [query: try ramenDraft()],
                now: now
            )
        )
        let blockedAdapter = SearchCapabilityAdapter(
            configuration: .enabledFixture(
                providerAccessProfile: profile,
                resultDrafts: [query: try ramenDraft()],
                now: now
            )
        )
        let selectedIntent = try selectedAdapter.intent(
            from: CapabilityRequest(kind: .webSearch, inputText: query)
        )
        let blockedIntent = try blockedAdapter.intent(
            from: CapabilityRequest(kind: .webSearch, inputText: query)
        )
        let selectedReport = selectedAdapter.dryRunPreview(for: selectedIntent)
        let blockedReport = blockedAdapter.dryRunPreview(for: blockedIntent)

        let source = selectedAdapter.dryRunProviderStatusSource(
            reports: [
                (recommendationID: duplicateID, report: selectedReport),
                (recommendationID: duplicateID, report: blockedReport),
            ]
        )
        let presentation = try XCTUnwrap(source.providerStatusPresentation(for: duplicateID))

        XCTAssertEqual(source.recommendationIDs, [duplicateID])
        XCTAssertEqual(presentation.cardHint, .warning)
        XCTAssertEqual(badge(.remoteProvider, in: presentation)?.tone, .neutral)
        XCTAssertEqual(badge(.meteredPremium, in: presentation)?.tone, .neutral)
        XCTAssertNil(badge(.termsBlocked, in: presentation))
        XCTAssertTrue(presentation.statusLine.contains("example.com"))
        XCTAssertFalse(presentation.statusLine.contains("Search API is not allowed"))
    }

    func test_dryRunProviderStatusSource_batchCopyStaysAdvisoryOnly() throws {
        let query = "late night ramen"
        let profile = ProviderAccessProfile(
            membershipTier: .plus,
            meteredProviderEntitlements: [.searchAPI]
        )
        let quota = ServerProviderQuotaSnapshot(
            providerAccessProfile: profile,
            allowedProviderFamilies: [.searchAPI],
            meteredEligibleProviderFamilies: [.searchAPI]
        )
        let selectedAdapter = SearchCapabilityAdapter(
            configuration: .enabledFixture(
                providerAccessProfile: profile,
                providerQuotaSnapshot: quota,
                resultDrafts: [query: try ramenDraft()],
                now: now
            )
        )
        let blockedAdapter = SearchCapabilityAdapter(
            configuration: .enabledFixture(
                providerAccessProfile: profile,
                resultDrafts: [query: try ramenDraft()],
                now: now
            )
        )
        let selectedIntent = try selectedAdapter.intent(
            from: CapabilityRequest(kind: .webSearch, inputText: query)
        )
        let blockedIntent = try blockedAdapter.intent(
            from: CapabilityRequest(kind: .webSearch, inputText: query)
        )
        let source = selectedAdapter.dryRunProviderStatusSource(
            reports: [
                (
                    recommendationID: "batch-copy-selected",
                    report: selectedAdapter.dryRunPreview(for: selectedIntent)
                ),
                (
                    recommendationID: "batch-copy-blocked",
                    report: blockedAdapter.dryRunPreview(for: blockedIntent)
                ),
            ]
        )
        let presentations = try [
            source.providerStatusPresentation(for: "batch-copy-selected"),
            source.providerStatusPresentation(for: "batch-copy-blocked"),
        ].map { try XCTUnwrap($0) }
        let text = presentations
            .flatMap { [$0.statusLine] + $0.badges.map(\.label) }
            .joined(separator: "\n")
            .lowercased()

        XCTAssertTrue(text.contains("no provider was contacted"))
        for forbidden in [
            "completed",
            "complete",
            "done",
            "called",
            "provider contacted",
            "booked",
            "ordered",
            "paid",
            "purchased",
            "crawled",
        ] {
            XCTAssertFalse(text.contains(forbidden), "Unexpected wording: \(forbidden)")
        }
    }

    func test_paidRemoteSearchWithoutEntitlement_isCostBlockedAndDoesNotNormalize() throws {
        let query = "late night ramen"
        let adapter = SearchCapabilityAdapter(
            configuration: .enabledFixture(
                meteredProviderEntitlements: [],
                resultDrafts: [query: try ramenDraft()],
                now: now
            )
        )
        let intent = try adapter.intent(from: CapabilityRequest(kind: .webSearch, inputText: query))

        let decision = adapter.decision(for: intent)

        XCTAssertFalse(decision.isResolved)
        XCTAssertEqual(decision.failureReason, .costBlocked)
        XCTAssertEqual(decision.trace.costClass, .blockedByCost)
        XCTAssertNil(ResultProjector.project(searchDecision: decision).normalizedResult)
    }

    func test_legacyConvenienceParametersCreateEquivalentProviderAccessProfile() throws {
        let query = "late night ramen"
        let adapter = SearchCapabilityAdapter(
            configuration: .enabledFixture(
                membershipTier: .plus,
                meteredProviderEntitlements: [.searchAPI],
                resultDrafts: [query: try ramenDraft()],
                now: now
            )
        )
        let intent = try adapter.intent(from: CapabilityRequest(kind: .webSearch, inputText: query))

        let decision = adapter.decision(for: intent)

        XCTAssertEqual(intent.membershipTier, .plus)
        XCTAssertEqual(intent.meteredProviderEntitlements, [.searchAPI])
        XCTAssertTrue(decision.isResolved)
        XCTAssertEqual(decision.selectedProvider?.family, .searchAPI)
    }

    func test_privateContext_blocksRemoteSearchProvider() throws {
        let query = "private appointment note"
        let adapter = SearchCapabilityAdapter(
            configuration: .enabledFixture(
                privacyClass: .private,
                providerAccessProfile: ProviderAccessProfile(
                    membershipTier: .pro,
                    meteredProviderEntitlements: [.searchAPI]
                ),
                resultDrafts: [query: try publicDraft(path: "private-topic")],
                now: now
            )
        )
        let intent = try adapter.intent(from: CapabilityRequest(kind: .webSearch, inputText: query))

        let decision = adapter.decision(for: intent)

        XCTAssertFalse(decision.isResolved)
        XCTAssertEqual(decision.failureReason, .privacyBlocked)
        XCTAssertEqual(decision.trace.costClass, .blockedByPrivacy)
    }

    func test_crawlerModeRequiresExplicitEnablementAndRobotsAllow() throws {
        let query = "public menu"
        let disabledCrawler = SearchCapabilityAdapter(
            configuration: .enabledFixture(
                sourceMode: .crawlerFetch,
                providerAccessProfile: ProviderAccessProfile.developerInternalDiagnostics(
                    preferredProvider: .crawler,
                    enabledExperimentalProviders: [],
                    meteredProviderEntitlements: [.crawler]
                ),
                robotsState: .allowed,
                resultDrafts: [query: try publicDraft(path: "menu")],
                now: now
            )
        )
        let disabledIntent = try disabledCrawler.intent(
            from: CapabilityRequest(kind: .webSearch, inputText: query)
        )

        let disabledDecision = disabledCrawler.decision(for: disabledIntent)

        XCTAssertFalse(disabledDecision.isResolved)
        XCTAssertEqual(disabledDecision.failureReason, .disabledByDefault)

        let robotsBlocked = SearchCapabilityAdapter(
            configuration: .enabledFixture(
                sourceMode: .crawlerFetch,
                providerAccessProfile: ProviderAccessProfile.developerInternalDiagnostics(
                    preferredProvider: .crawler,
                    enabledExperimentalProviders: [.crawler],
                    meteredProviderEntitlements: [.crawler]
                ),
                robotsState: .disallowed,
                resultDrafts: [query: try publicDraft(path: "menu")],
                now: now
            )
        )
        let robotsIntent = try robotsBlocked.intent(
            from: CapabilityRequest(kind: .webSearch, inputText: query)
        )

        let robotsDecision = robotsBlocked.decision(for: robotsIntent)

        XCTAssertFalse(robotsDecision.isResolved)
        XCTAssertEqual(robotsDecision.failureReason, .robotsBlocked)
    }

    func test_adapterCrawlerEnablementComesFromProviderAccessProfileButRobotsStayExplicit() throws {
        let query = "public menu"
        let adapter = SearchCapabilityAdapter(
            configuration: .enabledFixture(
                sourceMode: .crawlerFetch,
                providerAccessProfile: ProviderAccessProfile.developerInternalDiagnostics(
                    enabledExperimentalProviders: [.crawler],
                    meteredProviderEntitlements: [.crawler]
                ),
                robotsState: .allowed,
                resultDrafts: [query: try publicDraft(path: "menu")],
                now: now
            )
        )
        let intent = try adapter.intent(from: CapabilityRequest(kind: .webSearch, inputText: query))

        let decision = adapter.decision(for: intent)

        XCTAssertEqual(intent.enabledExperimentalProviders, [.crawler])
        XCTAssertEqual(intent.robotsState, .allowed)
        XCTAssertTrue(decision.isResolved)
        XCTAssertEqual(decision.selectedProvider?.family, .crawler)
    }

    func test_cacheFallback_returnsLocalNormalizedResultWithStaleLimitation() async throws {
        let query = "weekend brunch"
        let adapter = SearchCapabilityAdapter(
            configuration: .enabledFixture(
                membershipTier: .free,
                meteredProviderEntitlements: [],
                cachedResults: [query: try cachedResult(query: query)],
                now: now
            )
        )

        let result = try await adapter.resolve(
            CapabilityRequest(kind: .webSearch, inputText: query)
        )

        XCTAssertEqual(result.source, .local)
        guard case let .webSearch(hits) = result.payload else {
            return XCTFail("Expected webSearch payload")
        }
        XCTAssertEqual(hits.first?.title, "Weekend brunch")

        let intent = try adapter.intent(from: CapabilityRequest(kind: .webSearch, inputText: query))
        let decision = adapter.decision(for: intent)
        XCTAssertEqual(decision.selectedProvider?.providerID, "search-cache")
        XCTAssertTrue(decision.result?.limitations.contains(SearchProviderPolicy.staleCacheLimitation) == true)
    }

    private func row(
        _ kind: ServerProviderDryRunPresentationRowKind,
        in presentation: ServerProviderDryRunPresentation
    ) -> ServerProviderDryRunPresentationRow? {
        presentation.rows.first { $0.kind == kind }
    }

    private func presentationCopy(
        in presentation: ServerProviderDryRunPresentation
    ) -> [String] {
        [presentation.summary]
            + presentation.rows.flatMap { row in
                [row.title, row.detail] + row.badges.map(\.label)
            }
    }

    private func badge(
        _ kind: ProviderStatusBadgeKind,
        in presentation: ProviderStatusPresentation
    ) -> ProviderStatusBadgeModel? {
        presentation.badges.first { $0.kind == kind }
    }

    func test_invalidCapabilityOrEmptyQuery_isRejected() async {
        let adapter = SearchCapabilityAdapter(
            configuration: .enabledFixture(now: now)
        )

        await XCTAssertThrowsCapabilityError(.invalidRequest) {
            _ = try await adapter.resolve(CapabilityRequest(kind: .placeSearch, inputText: "ramen"))
        }
        await XCTAssertThrowsCapabilityError(.invalidRequest) {
            _ = try await adapter.resolve(CapabilityRequest(kind: .webSearch, inputText: "   "))
        }
    }

    private func ramenDraft() throws -> SearchResultDraft {
        try publicDraft(
            path: "ramen-hours",
            title: "Late-night ramen hours",
            snippet: "Public listing with hours.",
            confidence: 0.82
        )
    }

    private func publicDraft(
        path: String,
        title: String = "Public result",
        snippet: String = "Public snippet.",
        confidence: Double = 0.7
    ) throws -> SearchResultDraft {
        SearchResultDraft(
            sourceURL: try XCTUnwrap(URL(string: "https://example.com/\(path)")),
            title: title,
            snippet: snippet,
            attribution: "example.com",
            confidence: confidence,
            limitations: ["Verify public information before acting."]
        )
    }

    private func cachedResult(query: String) throws -> SearchResultEnvelope {
        SearchResultEnvelope(
            query: query,
            providerID: "previous-search-api",
            sourceURL: try XCTUnwrap(URL(string: "https://example.com/brunch")),
            title: "Weekend brunch",
            snippet: "Cached public result.",
            fetchedAt: Date(timeIntervalSince1970: 1_700_000_000),
            freshness: .cachedOK,
            costClass: .meteredPremium,
            confidence: 0.61,
            limitations: ["Older public listing."],
            attribution: "example.com"
        )
    }

    private func XCTAssertThrowsCapabilityError(
        _ expected: CapabilityError,
        operation: () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await operation()
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch let error as CapabilityError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("Expected CapabilityError, got \(error)", file: file, line: line)
        }
    }
}
