//
//  ProviderRoutingPolicyTests.swift
//  kAirTests
//
//  A5b provider routing contracts: membership/cost/privacy aware provider
//  choice, cache fallback, and non-PII provider trace.
//

import XCTest
@testable import kAir

final class ProviderRoutingPolicyTests: XCTestCase {

    func test_localDefault_usesAppleLocalForFreeUser() {
        let selection = ProviderRoutingPolicy.select(
            for: ProviderRequest(
                capability: .routePlanning,
                region: .northAmerica,
                membershipTier: .free
            )
        )

        XCTAssertEqual(selection.provider?.family, .appleLocal)
        XCTAssertEqual(selection.provider?.costClass, .freeLocal)
        XCTAssertEqual(selection.failureReason, nil)
        XCTAssertEqual(selection.trace.selectedProviderFamily, .appleLocal)
    }

    func test_gaodeMemberRoute_selectsGaodeForChinaPreference() {
        let selection = ProviderRoutingPolicy.select(
            for: ProviderRequest(
                capability: .routePlanning,
                region: .china,
                membershipTier: .plus,
                preferredProvider: .gaode
            )
        )

        XCTAssertEqual(selection.provider?.family, .gaode)
        XCTAssertEqual(selection.provider?.costClass, .includedQuota)
        XCTAssertEqual(selection.trace.membershipTier, .plus)
    }

    func test_googleMemberRoute_requiresMeteredEntitlement() {
        let selection = ProviderRoutingPolicy.select(
            for: ProviderRequest(
                capability: .placeSearch,
                region: .northAmerica,
                membershipTier: .pro,
                preferredProvider: .googleMaps,
                meteredProviderEntitlements: [.googleMaps],
                freshness: .livePreferred
            )
        )

        XCTAssertEqual(selection.provider?.family, .googleMaps)
        XCTAssertEqual(selection.provider?.costClass, .meteredPremium)
        XCTAssertEqual(selection.trace.freshness, .livePreferred)
    }

    func test_costBlockedPremiumRoute_fallsBackToAppleLocalAndRecordsSkip() {
        let selection = ProviderRoutingPolicy.select(
            for: ProviderRequest(
                capability: .placeSearch,
                region: .northAmerica,
                membershipTier: .free,
                preferredProvider: .googleMaps
            )
        )

        XCTAssertEqual(selection.provider?.family, .appleLocal)
        XCTAssertTrue(
            selection.skippedProviders.contains {
                $0.family == .googleMaps && $0.reason == .blockedByCost
            }
        )
        XCTAssertEqual(selection.trace.selectedProviderFamily, .appleLocal)
    }

    func test_privacyBlockedRemoteRoute_fallsBackToAppleLocalAndRecordsSkip() {
        let selection = ProviderRoutingPolicy.select(
            for: ProviderRequest(
                capability: .routePlanning,
                region: .northAmerica,
                privacyClass: .health,
                membershipTier: .pro,
                preferredProvider: .googleMaps,
                meteredProviderEntitlements: [.googleMaps]
            )
        )

        XCTAssertEqual(selection.provider?.family, .appleLocal)
        XCTAssertTrue(
            selection.skippedProviders.contains {
                $0.family == .googleMaps && $0.reason == .blockedByPrivacy
            }
        )
        XCTAssertEqual(selection.trace.privacyClass, .health)
    }

    func test_cacheFallback_whenAppleUnavailableAndPremiumBlocked() {
        let selection = ProviderRoutingPolicy.select(
            for: ProviderRequest(
                capability: .routePlanning,
                region: .northAmerica,
                membershipTier: .free,
                preferredProvider: .googleMaps,
                unavailableProviders: [.appleLocal]
            )
        )

        XCTAssertEqual(selection.provider?.family, .cache)
        XCTAssertEqual(selection.provider?.cachePolicy, .staleAllowedWithBadge)
        XCTAssertTrue(
            selection.skippedProviders.contains {
                $0.family == .appleLocal && $0.reason == .unavailable
            }
        )
        XCTAssertTrue(
            selection.skippedProviders.contains {
                $0.family == .googleMaps && $0.reason == .blockedByCost
            }
        )
    }

    func test_noProvider_whenCacheFallbackDisabledAndOnlyPremiumBlocked() {
        let selection = ProviderRoutingPolicy.select(
            for: ProviderRequest(
                capability: .routePlanning,
                region: .northAmerica,
                membershipTier: .free,
                preferredProvider: .googleMaps,
                unavailableProviders: [.appleLocal],
                allowCacheFallback: false
            )
        )

        XCTAssertNil(selection.provider)
        XCTAssertEqual(selection.failureReason, .blockedByCost)
        XCTAssertEqual(selection.trace.failureReason, .blockedByCost)
        XCTAssertEqual(selection.trace.costClass, .blockedByCost)
    }

    func test_privateContextCannotRouteToRemoteProvider() {
        let selection = ProviderRoutingPolicy.select(
            for: ProviderRequest(
                capability: .placeSearch,
                region: .northAmerica,
                privacyClass: .private,
                membershipTier: .pro,
                preferredProvider: .googleMaps,
                meteredProviderEntitlements: [.googleMaps]
            )
        )

        XCTAssertNotEqual(selection.provider?.family, .googleMaps)
        XCTAssertTrue(
            selection.skippedProviders.contains {
                $0.family == .googleMaps && $0.reason == .blockedByPrivacy
            }
        )
    }

    func test_traceContainsProviderDecisionWithoutUserContent() {
        let selection = ProviderRoutingPolicy.select(
            for: ProviderRequest(
                traceID: "trace-provider-1",
                capability: .localServiceSearch,
                region: .china,
                membershipTier: .plus,
                preferredProvider: .gaode
            )
        )

        let trace = selection.trace
        XCTAssertEqual(trace.traceID, "trace-provider-1")
        XCTAssertEqual(trace.capability, .localServiceSearch)
        XCTAssertEqual(trace.selectedProviderFamily, .gaode)
        XCTAssertEqual(trace.selectedProviderID, "gaode")
        XCTAssertEqual(trace.costClass, .includedQuota)
        XCTAssertEqual(trace.privacyClass, .general)
        XCTAssertEqual(trace.membershipTier, .plus)
        XCTAssertEqual(trace.failureReason, nil)
    }

    func test_disabledByDefaultProviderCannotBeSelectedWithoutEnablement() {
        let crawler = MapProviderDescriptor(
            providerID: "crawler-fixture",
            displayName: "Crawler Fixture",
            family: .crawler,
            supportedRegions: [.global],
            supportedCapabilities: [.crawlerFetch],
            minimumMembership: .pro,
            costClass: .meteredPremium,
            attributionRequired: true,
            supportsNativeSDK: false,
            supportsWebService: true,
            supportsExternalHandoff: false,
            cachePolicy: .noCache,
            priority: 1
        )

        let blocked = ProviderRoutingPolicy.select(
            for: ProviderRequest(
                capability: .crawlerFetch,
                membershipTier: .developerInternal,
                preferredProvider: .crawler,
                meteredProviderEntitlements: [.crawler]
            ),
            registry: [crawler]
        )

        XCTAssertNil(blocked.provider)
        XCTAssertEqual(blocked.failureReason, .disabledByDefault)

        let enabled = ProviderRoutingPolicy.select(
            for: ProviderRequest(
                capability: .crawlerFetch,
                membershipTier: .developerInternal,
                preferredProvider: .crawler,
                meteredProviderEntitlements: [.crawler],
                enabledExperimentalProviders: [.crawler]
            ),
            registry: [crawler]
        )

        XCTAssertEqual(enabled.provider?.family, .crawler)
    }
}
