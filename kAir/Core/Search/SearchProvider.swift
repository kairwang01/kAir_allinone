//
//  SearchProvider.swift
//  kAir
//
//  Comment-first scaffold for public information search and crawler-safe
//  life-service lookup.
//

import Foundation

/// Search/crawler policy types for
/// `Docs/architecture/kair-provider-routing-mcp-search-v1.md` §6.
///
/// This file intentionally defines values and deterministic policy only. It
/// does not fetch web pages, call search APIs, run crawlers, or store API keys.
enum SearchRobotsState: String, Codable, Hashable, Sendable, CaseIterable {
    case notApplicable
    case allowed
    case disallowed
    case unknown
}

enum SearchProviderSkipReason: String, Codable, Hashable, Sendable, CaseIterable {
    case unsupportedCapability
    case disabledByDefault
    case sourceDenied
    case robotsBlocked
    case privacyBlocked
    case costBlocked
    case noCachedResult
}

struct SearchProviderSkip: Codable, Hashable, Sendable {
    let providerID: String
    let family: ProviderFamily
    let reason: SearchProviderSkipReason
}

/// Candidate text supplied by a future adapter or fixture. Policy wraps it in
/// `SearchResultEnvelope` only after source/privacy/cost gates pass.
struct SearchResultDraft: Codable, Hashable, Sendable {
    let sourceURL: URL
    let title: String
    let snippet: String
    let attribution: String
    let confidence: Double
    let limitations: [String]

    init(
        sourceURL: URL,
        title: String,
        snippet: String,
        attribution: String,
        confidence: Double,
        limitations: [String] = []
    ) {
        self.sourceURL = sourceURL
        self.title = title
        self.snippet = snippet
        self.attribution = attribution
        self.confidence = confidence
        self.limitations = limitations
    }
}

/// Normalized, cited result envelope consumed by result projection/UI layers.
struct SearchResultEnvelope: Codable, Hashable, Sendable {
    let query: String
    let providerID: String
    let sourceURL: URL
    let title: String
    let snippet: String
    let fetchedAt: Date
    let freshness: ProviderFreshness
    let costClass: ProviderCostClass
    let confidence: Double
    let limitations: [String]
    let attribution: String

    var isStaleCache: Bool {
        freshness == .cachedOK && limitations.contains(SearchProviderPolicy.staleCacheLimitation)
    }

    func routedThroughCache(
        providerID: String,
        fetchedAt: Date,
        limitations extraLimitations: [String]
    ) -> SearchResultEnvelope {
        SearchResultEnvelope(
            query: query,
            providerID: providerID,
            sourceURL: sourceURL,
            title: title,
            snippet: snippet,
            fetchedAt: fetchedAt,
            freshness: .cachedOK,
            costClass: .freeLocal,
            confidence: confidence,
            limitations: Array(Set(limitations + extraLimitations)).sorted(),
            attribution: attribution
        )
    }
}

/// Provider descriptor for search API, crawler, and cache paths.
struct SearchProviderDescriptor: Codable, Hashable, Sendable, Identifiable {
    let providerID: String
    let displayName: String
    let family: ProviderFamily
    let supportedCapabilities: Set<ProviderCapability>
    let minimumMembership: MembershipTier
    let costClass: ProviderCostClass
    let requiresRobotsAllow: Bool
    let allowedSourceHosts: Set<String>
    let deniedSourceHosts: Set<String>
    let priority: Int

    var id: String { providerID }

    func supports(capability: ProviderCapability) -> Bool {
        supportedCapabilities.contains(capability)
    }
}

struct SearchProviderRequest: Codable, Hashable, Sendable {
    let traceID: String
    let query: String
    let capability: ProviderCapability
    let privacyClass: ProviderPrivacyClass
    let membershipTier: MembershipTier
    let preferredProvider: ProviderFamily?
    let meteredProviderEntitlements: Set<ProviderFamily>
    let enabledExperimentalProviders: Set<ProviderFamily>
    let freshness: ProviderFreshness
    let robotsState: SearchRobotsState
    let resultDraft: SearchResultDraft?
    let cachedResult: SearchResultEnvelope?
    let now: Date

    init(
        traceID: String = "search-trace",
        query: String,
        capability: ProviderCapability = .webSearch,
        privacyClass: ProviderPrivacyClass = .general,
        membershipTier: MembershipTier = .free,
        preferredProvider: ProviderFamily? = nil,
        meteredProviderEntitlements: Set<ProviderFamily> = [],
        enabledExperimentalProviders: Set<ProviderFamily> = [],
        freshness: ProviderFreshness = .cachedOK,
        robotsState: SearchRobotsState = .notApplicable,
        resultDraft: SearchResultDraft? = nil,
        cachedResult: SearchResultEnvelope? = nil,
        now: Date = Date()
    ) {
        self.traceID = traceID
        self.query = query
        self.capability = capability
        self.privacyClass = privacyClass
        self.membershipTier = membershipTier
        self.preferredProvider = preferredProvider
        self.meteredProviderEntitlements = meteredProviderEntitlements
        self.enabledExperimentalProviders = enabledExperimentalProviders
        self.freshness = freshness
        self.robotsState = robotsState
        self.resultDraft = resultDraft
        self.cachedResult = cachedResult
        self.now = now
    }
}

struct SearchProviderDecision: Hashable, Sendable {
    let selectedProvider: SearchProviderDescriptor?
    let result: SearchResultEnvelope?
    let skippedProviders: [SearchProviderSkip]
    let failureReason: SearchProviderSkipReason?
    let trace: ProviderTrace

    var isResolved: Bool {
        selectedProvider != nil && result != nil
    }
}

enum SearchProviderPolicy {
    nonisolated static let staleCacheLimitation = "Result is from cache and may be stale."
    private static let crawlerLimitation = "Crawler result is read-only and source-policy checked."

    static func evaluate(
        _ request: SearchProviderRequest,
        registry: [SearchProviderDescriptor] = SearchProviderDescriptor.defaultRegistry
    ) -> SearchProviderDecision {
        var skipped: [SearchProviderSkip] = []
        let ordered = orderedProviders(for: request, registry: registry)

        for descriptor in ordered {
            if let skip = skipReason(for: descriptor, request: request) {
                skipped.append(
                    SearchProviderSkip(
                        providerID: descriptor.providerID,
                        family: descriptor.family,
                        reason: skip
                    )
                )
                continue
            }

            guard let result = makeResult(for: descriptor, request: request) else {
                skipped.append(
                    SearchProviderSkip(
                        providerID: descriptor.providerID,
                        family: descriptor.family,
                        reason: .noCachedResult
                    )
                )
                continue
            }

            return makeDecision(
                provider: descriptor,
                result: result,
                skipped: skipped,
                failureReason: nil,
                request: request
            )
        }

        return makeDecision(
            provider: nil,
            result: nil,
            skipped: skipped,
            failureReason: dominantFailureReason(from: skipped),
            request: request
        )
    }

    private static func orderedProviders(
        for request: SearchProviderRequest,
        registry: [SearchProviderDescriptor]
    ) -> [SearchProviderDescriptor] {
        let base = registry.sorted { lhs, rhs in
            lhs.priority < rhs.priority
        }

        guard let preferred = request.preferredProvider else { return base }

        return base.sorted { lhs, rhs in
            if lhs.family == preferred, rhs.family != preferred { return true }
            if rhs.family == preferred, lhs.family != preferred { return false }
            return lhs.priority < rhs.priority
        }
    }

    private static func skipReason(
        for descriptor: SearchProviderDescriptor,
        request: SearchProviderRequest
    ) -> SearchProviderSkipReason? {
        guard descriptor.supports(capability: request.capability) else {
            return .unsupportedCapability
        }
        if descriptor.family.isDisabledByDefault,
           request.enabledExperimentalProviders.contains(descriptor.family) == false {
            return .disabledByDefault
        }
        guard sourceIsAllowed(for: descriptor, draft: request.resultDraft, cached: request.cachedResult) else {
            return .sourceDenied
        }
        if descriptor.requiresRobotsAllow, request.robotsState != .allowed {
            return .robotsBlocked
        }
        if descriptor.family.isRemote, request.privacyClass.allowsRemoteProvider == false {
            return .privacyBlocked
        }
        guard request.membershipTier >= descriptor.minimumMembership else {
            return .costBlocked
        }
        if descriptor.costClass == .meteredPremium,
           request.membershipTier != .developerInternal,
           request.meteredProviderEntitlements.contains(descriptor.family) == false {
            return .costBlocked
        }
        return nil
    }

    private static func makeResult(
        for descriptor: SearchProviderDescriptor,
        request: SearchProviderRequest
    ) -> SearchResultEnvelope? {
        if descriptor.family == .cache {
            return request.cachedResult?.routedThroughCache(
                providerID: descriptor.providerID,
                fetchedAt: request.now,
                limitations: [staleCacheLimitation]
            )
        }

        guard let draft = request.resultDraft else { return nil }
        let limitations = descriptor.family == .crawler
            ? draft.limitations + [crawlerLimitation]
            : draft.limitations

        return SearchResultEnvelope(
            query: request.query,
            providerID: descriptor.providerID,
            sourceURL: draft.sourceURL,
            title: draft.title,
            snippet: draft.snippet,
            fetchedAt: request.now,
            freshness: request.freshness,
            costClass: descriptor.costClass,
            confidence: draft.confidence,
            limitations: limitations,
            attribution: draft.attribution
        )
    }

    private static func makeDecision(
        provider: SearchProviderDescriptor?,
        result: SearchResultEnvelope?,
        skipped: [SearchProviderSkip],
        failureReason: SearchProviderSkipReason?,
        request: SearchProviderRequest
    ) -> SearchProviderDecision {
        let trace = ProviderTrace(
            traceID: request.traceID,
            capability: request.capability,
            selectedProviderID: provider?.providerID,
            selectedProviderFamily: provider?.family,
            skippedProviders: skipped.map {
                ProviderSkip(
                    providerID: $0.providerID,
                    family: $0.family,
                    reason: providerSkipReason(for: $0.reason)
                )
            },
            costClass: provider?.costClass ?? costClass(for: failureReason),
            privacyClass: request.privacyClass,
            membershipTier: request.membershipTier,
            freshness: result?.freshness ?? request.freshness,
            failureReason: failureReason.map(providerSkipReason(for:))
        )

        return SearchProviderDecision(
            selectedProvider: provider,
            result: result,
            skippedProviders: skipped,
            failureReason: failureReason,
            trace: trace
        )
    }

    private static func sourceIsAllowed(
        for descriptor: SearchProviderDescriptor,
        draft: SearchResultDraft?,
        cached: SearchResultEnvelope?
    ) -> Bool {
        guard let sourceURL = draft?.sourceURL ?? cached?.sourceURL,
              let host = sourceURL.host?.lowercased() else {
            return descriptor.family == .cache
        }
        let denied = descriptor.deniedSourceHosts.contains { hostMatches(host, rule: $0) }
        if denied { return false }
        guard descriptor.allowedSourceHosts.isEmpty == false else { return true }
        return descriptor.allowedSourceHosts.contains { hostMatches(host, rule: $0) }
    }

    private static func hostMatches(_ host: String, rule: String) -> Bool {
        let normalizedRule = rule.lowercased()
        return host == normalizedRule || host.hasSuffix("." + normalizedRule)
    }

    private static func dominantFailureReason(
        from skipped: [SearchProviderSkip]
    ) -> SearchProviderSkipReason? {
        let priority: [SearchProviderSkipReason] = [
            .privacyBlocked,
            .costBlocked,
            .robotsBlocked,
            .sourceDenied,
            .disabledByDefault,
            .unsupportedCapability,
            .noCachedResult,
        ]
        for reason in priority where skipped.contains(where: { $0.reason == reason }) {
            return reason
        }
        return nil
    }

    nonisolated private static func providerSkipReason(
        for reason: SearchProviderSkipReason
    ) -> ProviderSkipReason {
        switch reason {
        case .unsupportedCapability:
            return .unsupportedCapability
        case .disabledByDefault:
            return .disabledByDefault
        case .privacyBlocked:
            return .blockedByPrivacy
        case .costBlocked:
            return .blockedByCost
        case .sourceDenied, .robotsBlocked, .noCachedResult:
            return .unavailable
        }
    }

    private static func costClass(
        for reason: SearchProviderSkipReason?
    ) -> ProviderCostClass {
        switch reason {
        case .privacyBlocked:
            return .blockedByPrivacy
        case .costBlocked:
            return .blockedByCost
        case .sourceDenied, .robotsBlocked, .disabledByDefault,
             .unsupportedCapability, .noCachedResult, nil:
            return .blockedByTerms
        }
    }
}

extension SearchProviderDescriptor {
    static let defaultRegistry: [SearchProviderDescriptor] = [
        SearchProviderDescriptor(
            providerID: "search-api",
            displayName: "Search API",
            family: .searchAPI,
            supportedCapabilities: [.webSearch, .localServiceSearch],
            minimumMembership: .plus,
            costClass: .meteredPremium,
            requiresRobotsAllow: false,
            allowedSourceHosts: [],
            deniedSourceHosts: ["apple.com", "apps.apple.com"],
            priority: 10
        ),
        SearchProviderDescriptor(
            providerID: "crawler",
            displayName: "Crawler",
            family: .crawler,
            supportedCapabilities: [.crawlerFetch, .localServiceSearch],
            minimumMembership: .pro,
            costClass: .meteredPremium,
            requiresRobotsAllow: true,
            allowedSourceHosts: [],
            deniedSourceHosts: ["apple.com", "apps.apple.com"],
            priority: 20
        ),
        SearchProviderDescriptor(
            providerID: "search-cache",
            displayName: "Search Cache",
            family: .cache,
            supportedCapabilities: [.webSearch, .localServiceSearch, .crawlerFetch],
            minimumMembership: .free,
            costClass: .freeLocal,
            requiresRobotsAllow: false,
            allowedSourceHosts: [],
            deniedSourceHosts: [],
            priority: 100
        ),
    ]
}
