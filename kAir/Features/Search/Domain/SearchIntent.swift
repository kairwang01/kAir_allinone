//
//  SearchIntent.swift
//  kAir
//
//  Read-only Search vertical intent contract.
//

import Foundation

/// The first Search vertical contract. It describes a read-only public
/// information lookup and lowers into the already-reserved
/// `SearchProviderPolicy` request shape. It does not fetch, crawl, book,
/// order, pay, or open a partner app.
struct SearchIntent: Hashable, Sendable, Identifiable {
    enum Category: String, Hashable, Sendable, CaseIterable {
        case publicWeb
        case lifeService
        case menuOrHours

        var providerCapability: ProviderCapability {
            switch self {
            case .publicWeb:
                return .webSearch
            case .lifeService, .menuOrHours:
                return .localServiceSearch
            }
        }
    }

    enum SourceMode: String, Hashable, Sendable, CaseIterable {
        case searchAPI
        case crawlerFetch
        case cacheOnly

        var preferredProvider: ProviderFamily? {
            switch self {
            case .searchAPI:
                return .searchAPI
            case .crawlerFetch:
                return .crawler
            case .cacheOnly:
                return .cache
            }
        }

        func providerCapability(for category: Category) -> ProviderCapability {
            switch self {
            case .searchAPI, .cacheOnly:
                return category.providerCapability
            case .crawlerFetch:
                return .crawlerFetch
            }
        }
    }

    let id: String
    let query: String
    let category: Category
    let sourceMode: SourceMode
    let privacyClass: ProviderPrivacyClass
    let membershipTier: MembershipTier
    let meteredProviderEntitlements: Set<ProviderFamily>
    let enabledExperimentalProviders: Set<ProviderFamily>
    let freshness: ProviderFreshness
    let robotsState: SearchRobotsState
    let requestedAt: Date

    init(
        id: String? = nil,
        query: String,
        category: Category = .lifeService,
        sourceMode: SourceMode = .searchAPI,
        privacyClass: ProviderPrivacyClass = .general,
        membershipTier: MembershipTier = .free,
        meteredProviderEntitlements: Set<ProviderFamily> = [],
        enabledExperimentalProviders: Set<ProviderFamily> = [],
        freshness: ProviderFreshness = .cachedOK,
        robotsState: SearchRobotsState = .notApplicable,
        requestedAt: Date = Date()
    ) {
        let normalized = Self.normalizedQuery(query)
        self.id = id ?? "search-intent-\(normalized.replacingOccurrences(of: " ", with: "-"))"
        self.query = normalized
        self.category = category
        self.sourceMode = sourceMode
        self.privacyClass = privacyClass
        self.membershipTier = membershipTier
        self.meteredProviderEntitlements = meteredProviderEntitlements
        self.enabledExperimentalProviders = enabledExperimentalProviders
        self.freshness = freshness
        self.robotsState = robotsState
        self.requestedAt = requestedAt
    }

    var capability: CapabilityKind {
        .webSearch
    }

    var providerCapability: ProviderCapability {
        sourceMode.providerCapability(for: category)
    }

    var isReadOnly: Bool {
        true
    }

    var canMutateMerchantState: Bool {
        false
    }

    var requiresUserConfirmation: Bool {
        false
    }

    var usesInAppCrawlerRuntime: Bool {
        false
    }

    func providerRequest(
        traceID: String? = nil,
        resultDraft: SearchResultDraft? = nil,
        cachedResult: SearchResultEnvelope? = nil,
        now: Date? = nil
    ) -> SearchProviderRequest {
        let legacyFixtureProfile = ProviderAccessProfile(
            membershipTier: membershipTier,
            meteredProviderEntitlements: meteredProviderEntitlements,
            enabledExperimentalProviders: enabledExperimentalProviders
        )
        return providerRequest(
            providerAccessProfile: legacyFixtureProfile,
            traceID: traceID,
            resultDraft: resultDraft,
            cachedResult: cachedResult,
            now: now
        )
    }

    /// Lowers this read-only intent through the app/root provider-access profile.
    ///
    /// The profile supplies membership, entitlement, and experimental-provider
    /// defaults. The intent still owns query normalization, source mode, privacy,
    /// freshness, robots state, drafts, cache, and timestamp because these are
    /// task/source facts, not account defaults.
    func providerRequest(
        providerAccessProfile: ProviderAccessProfile,
        traceID: String? = nil,
        resultDraft: SearchResultDraft? = nil,
        cachedResult: SearchResultEnvelope? = nil,
        now: Date? = nil
    ) -> SearchProviderRequest {
        providerAccessProfile.searchProviderRequest(
            traceID: traceID ?? id,
            query: query,
            capability: providerCapability,
            privacyClass: privacyClass,
            freshness: freshness,
            robotsState: robotsState,
            resultDraft: resultDraft,
            cachedResult: cachedResult,
            preferredProviderOverride: sourceMode.preferredProvider,
            now: now ?? requestedAt
        )
    }

    static func normalizedQuery(_ query: String) -> String {
        query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }
}
