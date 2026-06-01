//
//  DefaultCapabilityRegistryTests.swift
//  kAirTests
//
//  Pins the §3.1 shipped-stub registration behavior of the
//  composition-root factory introduced in Main C.
//
//  Coverage:
//    - The factory returns a registry with EXACTLY the three §3.1
//      shipped kinds registered (`.aiCompletion`, `.threadLookup`,
//      `.localStoreLookup`).
//    - The factory does NOT register §3.2 reserved kinds.
//    - Each registered adapter's `Self.capability` matches the kind it
//      was registered under (envelope/registry-key invariant).
//    - The published `shippedKinds` list matches `CapabilityKind`'s
//      `isShippedInV1`.
//    - Two factory calls produce independent registries (no shared
//      state).
//

import XCTest
@testable import kAir

@MainActor
final class DefaultCapabilityRegistryTests: XCTestCase {

    // MARK: - Shipped kinds present

    func test_makeWithShippedStubs_registersAllThreeShippedKinds() async throws {
        let registry = DefaultCapabilityRegistry.makeWithShippedStubs()

        XCTAssertNotNil(registry.adapter(for: .aiCompletion))
        XCTAssertNotNil(registry.adapter(for: .threadLookup))
        XCTAssertNotNil(registry.adapter(for: .localStoreLookup))
    }

    func test_makeWithShippedStubs_snapshotReportsThreeAvailable() async throws {
        let registry = DefaultCapabilityRegistry.makeWithShippedStubs()
        let snapshot = await registry.availabilitySnapshot()

        XCTAssertEqual(snapshot.count, 3)
        XCTAssertEqual(snapshot[.aiCompletion], true)
        XCTAssertEqual(snapshot[.threadLookup], true)
        XCTAssertEqual(snapshot[.localStoreLookup], true)
    }

    // MARK: - Reserved kinds absent (§3.2)

    func test_makeWithShippedStubs_doesNotRegisterReservedKinds() throws {
        let registry = DefaultCapabilityRegistry.makeWithShippedStubs()

        // §3.2 reserved kinds: no v1 adapter commitment, MUST NOT be
        // registered by the default factory.
        XCTAssertNil(registry.adapter(for: .placeSearch))
        XCTAssertNil(registry.adapter(for: .routePlanning))
        XCTAssertNil(registry.adapter(for: .musicPlayback))
        XCTAssertNil(registry.adapter(for: .videoPlayback))
        XCTAssertNil(registry.adapter(for: .healthRead))
        XCTAssertNil(registry.adapter(for: .healthWrite))
        XCTAssertNil(registry.adapter(for: .webSearch))
    }

    // MARK: - Adapter / kind correspondence

    func test_makeWithShippedStubs_adaptersHaveMatchingCapabilityKey() throws {
        // §5.4 envelope invariant analog: each registered adapter's
        // `static var capability` MUST equal the key it was looked up
        // by. This pins that registration uses the right adapter for
        // each kind.
        let registry = DefaultCapabilityRegistry.makeWithShippedStubs()

        for kind in DefaultCapabilityRegistry.shippedKinds {
            let adapter = try XCTUnwrap(
                registry.adapter(for: kind),
                "missing adapter for \(kind)"
            )
            XCTAssertEqual(
                type(of: adapter).capability,
                kind,
                "adapter registered under \(kind) reports capability \(type(of: adapter).capability)"
            )
        }
    }

    // MARK: - shippedKinds list shape

    func test_shippedKinds_matchesIsShippedInV1() throws {
        // The published list of shipped kinds must equal the set of
        // CapabilityKind cases for which `isShippedInV1` is true.
        let expected = Set(CapabilityKind.allCases.filter { $0.isShippedInV1 })
        XCTAssertEqual(Set(DefaultCapabilityRegistry.shippedKinds), expected)
        // Sanity: §3.1 is exactly three kinds.
        XCTAssertEqual(DefaultCapabilityRegistry.shippedKinds.count, 3)
    }

    // MARK: - Independence

    func test_makeWithShippedStubs_returnsIndependentRegistries() throws {
        // The factory MUST NOT share state across calls. Each
        // invocation produces a fresh `CapabilityRegistry`.
        let r1 = DefaultCapabilityRegistry.makeWithShippedStubs()
        let r2 = DefaultCapabilityRegistry.makeWithShippedStubs()
        XCTAssertFalse(r1 === r2)

        // Adapters are also fresh instances (no accidental singleton
        // promotion of the stubs).
        let a1 = try XCTUnwrap(r1.adapter(for: .aiCompletion))
        let a2 = try XCTUnwrap(r2.adapter(for: .aiCompletion))
        XCTAssertFalse(a1 === a2)
    }

    // MARK: - Reserved Search composition

    func test_makeWithShippedStubs_reservedSearchNilBehavesLikeDefaultRegistry() async throws {
        let registry = DefaultCapabilityRegistry.makeWithShippedStubs(
            reservedSearchAdapter: nil
        )
        let snapshot = await registry.availabilitySnapshot()

        XCTAssertEqual(snapshot.count, 3)
        XCTAssertEqual(snapshot[.aiCompletion], true)
        XCTAssertEqual(snapshot[.threadLookup], true)
        XCTAssertEqual(snapshot[.localStoreLookup], true)
        XCTAssertNil(registry.adapter(for: .webSearch))
    }

    func test_makeWithShippedStubs_registersReservedSearchOnlyWhenSupplied() async throws {
        let configuration = DefaultCapabilityRegistry.makeReservedSearchConfiguration(
            isEnabled: true
        )
        let searchAdapter = SearchCapabilityAdapter(configuration: configuration)

        let registry = DefaultCapabilityRegistry.makeWithShippedStubs(
            reservedSearchAdapter: searchAdapter
        )
        let registeredSearchAdapter = try XCTUnwrap(
            registry.adapter(for: .webSearch) as? SearchCapabilityAdapter
        )
        let snapshot = await registry.availabilitySnapshot()

        XCTAssertTrue(registeredSearchAdapter === searchAdapter)
        XCTAssertEqual(type(of: registeredSearchAdapter).capability, .webSearch)
        XCTAssertEqual(snapshot.count, 4)
        XCTAssertEqual(snapshot[.aiCompletion], true)
        XCTAssertEqual(snapshot[.threadLookup], true)
        XCTAssertEqual(snapshot[.localStoreLookup], true)
        XCTAssertEqual(snapshot[.webSearch], true)
    }

    func test_makeWithShippedStubs_reservedSearchAvailabilityReflectsConfiguration() async throws {
        let configuration = DefaultCapabilityRegistry.makeReservedSearchConfiguration(
            isEnabled: false
        )
        let searchAdapter = SearchCapabilityAdapter(configuration: configuration)

        let registry = DefaultCapabilityRegistry.makeWithShippedStubs(
            reservedSearchAdapter: searchAdapter
        )
        let snapshot = await registry.availabilitySnapshot()

        XCTAssertNotNil(registry.adapter(for: .webSearch))
        XCTAssertEqual(snapshot.count, 4)
        XCTAssertEqual(snapshot[.webSearch], false)
    }

    // MARK: - Reserved Search factory

    func test_reservedSearchConfiguration_doesNotRegisterWebSearchInDefaultRegistry() throws {
        _ = DefaultCapabilityRegistry.makeReservedSearchConfiguration()

        let registry = DefaultCapabilityRegistry.makeWithShippedStubs()
        XCTAssertNil(registry.adapter(for: .webSearch))
        XCTAssertEqual(Set(DefaultCapabilityRegistry.shippedKinds), [
            .aiCompletion,
            .threadLookup,
            .localStoreLookup,
        ])
    }

    func test_reservedSearchConfiguration_isDisabledByDefaultAndCarriesProfile() {
        let profile = ProviderAccessProfile(
            membershipTier: .plus,
            defaultRegion: .northAmerica,
            preferredProvider: .searchAPI,
            meteredProviderEntitlements: [.searchAPI]
        )

        let configuration = DefaultCapabilityRegistry.makeReservedSearchConfiguration(
            providerAccessProfile: profile
        )

        XCTAssertFalse(configuration.isEnabled)
        XCTAssertEqual(configuration.providerAccessProfile, profile)
        XCTAssertEqual(
            configuration.providerQuotaSnapshot,
            ServerProviderQuotaSnapshot(providerAccessProfile: profile)
        )
        XCTAssertFalse(
            configuration.providerQuotaSnapshot.allowedProviderFamilies.contains(.searchAPI)
        )
        XCTAssertTrue(configuration.providerQuotaSnapshot.meteredEligibleProviderFamilies.isEmpty)
        XCTAssertEqual(configuration.privacyClass, .general)
        XCTAssertEqual(configuration.sourceMode, .searchAPI)
        XCTAssertEqual(configuration.robotsState, .notApplicable)
    }

    func test_reservedSearchConfiguration_preservesExplicitQuotaSnapshot() {
        let quota = ServerProviderQuotaSnapshot(
            providerAccessProfile: ProviderAccessProfile(
                membershipTier: .pro,
                meteredProviderEntitlements: [.searchAPI]
            ),
            allowedProviderFamilies: [.searchAPI],
            meteredEligibleProviderFamilies: [.searchAPI],
            disabledProviderFamilies: [.cache]
        )

        let configuration = DefaultCapabilityRegistry.makeReservedSearchConfiguration(
            providerAccessProfile: .freeLocalDefault,
            providerQuotaSnapshot: quota
        )

        XCTAssertEqual(configuration.providerAccessProfile, .freeLocalDefault)
        XCTAssertEqual(configuration.providerQuotaSnapshot, quota)
        XCTAssertEqual(configuration.providerQuotaSnapshot.allowedProviderFamilies, [.searchAPI])
        XCTAssertEqual(configuration.providerQuotaSnapshot.entitledProviderFamilies, [.searchAPI])
        XCTAssertEqual(configuration.providerQuotaSnapshot.meteredEligibleProviderFamilies, [.searchAPI])
        XCTAssertEqual(configuration.providerQuotaSnapshot.disabledProviderFamilies, [.cache])
    }

    func test_reservedSearchConfiguration_preservesExplicitSourcePrivacyRobotsAndFixtures() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_300)
        let draft = SearchResultDraft(
            sourceURL: try XCTUnwrap(URL(string: "https://example.com/menu")),
            title: "Public menu",
            snippet: "Public menu fixture.",
            attribution: "example.com",
            confidence: 0.82
        )
        let profile = ProviderAccessProfile.developerInternalDiagnostics(
            enabledExperimentalProviders: [.crawler],
            meteredProviderEntitlements: [.crawler]
        )

        let configuration = DefaultCapabilityRegistry.makeReservedSearchConfiguration(
            isEnabled: true,
            providerAccessProfile: profile,
            category: .menuOrHours,
            sourceMode: .crawlerFetch,
            privacyClass: .private,
            freshness: .liveRequired,
            robotsState: .allowed,
            resultDrafts: ["Public   Menu": draft],
            registry: SearchProviderDescriptor.defaultRegistry,
            now: now
        )

        XCTAssertTrue(configuration.isEnabled)
        XCTAssertEqual(configuration.providerAccessProfile, profile)
        XCTAssertEqual(configuration.category, .menuOrHours)
        XCTAssertEqual(configuration.sourceMode, .crawlerFetch)
        XCTAssertEqual(configuration.privacyClass, .private)
        XCTAssertEqual(configuration.freshness, .liveRequired)
        XCTAssertEqual(configuration.robotsState, .allowed)
        XCTAssertEqual(configuration.resultDrafts["Public Menu"], draft)
        XCTAssertEqual(configuration.now, now)
    }
}
