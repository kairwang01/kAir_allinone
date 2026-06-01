//
//  ResearchProvider.swift
//  kAir
//
//  Comment-first contract for academic / scholarly research sources
//  (Google Scholar, IEEE, arXiv, OpenAlex, Crossref, Semantic Scholar, PubMed).
//
//  Reserved interface R1 of `Docs/architecture/kair-architecture-redesign-v2.md`
//  §5.1. Academic search is a distinct provider family from the web `searchAPI`
//  (different sources, citation/DOI/peer-review semantics, paywall awareness),
//  so it gets its own vocabulary instead of growing the PM-owned, heavily-tested
//  `ProviderFamily` / `ProviderCapability` enums.
//
//  This file defines values and deterministic policy only. It does NOT call
//  arXiv/OpenAlex/Crossref/IEEE/PubMed/Scholar, run a crawler, store API keys,
//  or fetch any paper. Like every remote provider in kAir, real access is
//  server-mediated and deferred. It reuses the shared currency types
//  (`MembershipTier`, `ProviderCostClass`, `ProviderPrivacyClass`,
//  `ProviderFreshness`) from `ProviderRoutingPolicy.swift`.
//

import Foundation

/// Academic / scholarly sources kAir can reserve. All are remote services
/// except `.cache`. Read-only, citation-first.
enum ResearchSource: String, Codable, Hashable, Sendable, CaseIterable {
    case arxiv
    case openAlex
    case crossref
    case semanticScholar
    case pubmed
    case ieee
    case googleScholar
    case cache

    /// Whether using the source leaves the device. Only `.cache` is local.
    var isRemote: Bool {
        self != .cache
    }
}

/// Read-only scholarly capabilities. Full-text redistribution is intentionally
/// absent — kAir cites and summarizes, it does not rehost paywalled papers.
enum ResearchCapability: String, Codable, Hashable, Sendable, CaseIterable {
    case scholarlySearch
    case citationLookup
    case paperMetadata
    case abstractFetch
}

/// Why a research source was skipped during selection.
enum ResearchSourceSkipReason: String, Codable, Hashable, Sendable, CaseIterable {
    case unsupportedCapability
    /// Source has no official API and is disabled until explicitly enabled.
    case disabledByDefault
    /// Source's terms forbid programmatic access without a compliant path
    /// (e.g. Google Scholar). Blocked in v1 regardless of enablement.
    case complianceReviewRequired
    /// Non-general (private / health) query must not reach a remote source.
    case privacyBlocked
    /// Capability needs paywalled full text the source does not license.
    case paywallBlocked
    /// Membership tier or metered entitlement insufficient.
    case costBlocked
    /// No citation candidate available (no draft, no cache).
    case noResult
}

/// One skipped source and its reason.
struct ResearchSourceSkip: Codable, Hashable, Sendable {
    let sourceID: String
    let source: ResearchSource
    let reason: ResearchSourceSkipReason
}

/// Raw citation candidate supplied by a future adapter or fixture. Policy wraps
/// it in `ResearchCitation` only after capability / compliance / privacy /
/// paywall / cost gates pass.
struct ResearchCitationDraft: Codable, Hashable, Sendable {
    let title: String
    let authors: [String]
    let venue: String
    let year: Int?
    let doi: String?
    let url: URL
    let isPeerReviewed: Bool
    let isOpenAccess: Bool
    let abstractAvailable: Bool
    let confidence: Double
    let limitations: [String]

    init(
        title: String,
        authors: [String],
        venue: String,
        url: URL,
        year: Int? = nil,
        doi: String? = nil,
        isPeerReviewed: Bool = false,
        isOpenAccess: Bool = false,
        abstractAvailable: Bool = false,
        confidence: Double = 0.5,
        limitations: [String] = []
    ) {
        self.title = title
        self.authors = authors
        self.venue = venue
        self.url = url
        self.year = year
        self.doi = doi
        self.isPeerReviewed = isPeerReviewed
        self.isOpenAccess = isOpenAccess
        self.abstractAvailable = abstractAvailable
        self.confidence = confidence
        self.limitations = limitations
    }
}

/// Normalized, always-cited research result consumed by projection / UI layers.
/// Every citation carries a source URL (and a DOI when available) — a research
/// result without a citation is never produced.
struct ResearchCitation: Codable, Hashable, Sendable {
    let query: String
    let sourceID: String
    let title: String
    let authors: [String]
    let venue: String
    let year: Int?
    let doi: String?
    let url: URL
    let isPeerReviewed: Bool
    let isOpenAccess: Bool
    let abstractAvailable: Bool
    let fetchedAt: Date
    let freshness: ProviderFreshness
    let costClass: ProviderCostClass
    let confidence: Double
    let limitations: [String]

    /// Every research result must be citable (a source URL, optionally a DOI).
    var isCited: Bool {
        url.absoluteString.isEmpty == false
    }

    var isStaleCache: Bool {
        freshness == .cachedOK && limitations.contains(ResearchProviderPolicy.staleCacheLimitation)
    }

    func routedThroughCache(
        sourceID: String,
        fetchedAt: Date,
        limitations extraLimitations: [String]
    ) -> ResearchCitation {
        ResearchCitation(
            query: query,
            sourceID: sourceID,
            title: title,
            authors: authors,
            venue: venue,
            year: year,
            doi: doi,
            url: url,
            isPeerReviewed: isPeerReviewed,
            isOpenAccess: isOpenAccess,
            abstractAvailable: abstractAvailable,
            fetchedAt: fetchedAt,
            freshness: .cachedOK,
            costClass: .freeLocal,
            confidence: confidence,
            limitations: Array(Set(limitations + extraLimitations)).sorted()
        )
    }
}

/// Descriptor for one academic source. `privacyClass` marks health-adjacent
/// sources (PubMed) so telemetry/routing can treat them as sensitive.
struct ResearchSourceDescriptor: Codable, Hashable, Sendable, Identifiable {
    let source: ResearchSource
    let displayName: String
    let supportedCapabilities: Set<ResearchCapability>
    let minimumMembership: MembershipTier
    let costClass: ProviderCostClass
    /// `false` for sources without an official API (Google Scholar).
    let hasOfficialAPI: Bool
    /// Terms require a compliant access path that does not exist in v1.
    let requiresComplianceReview: Bool
    /// Full text is paywalled — `abstractFetch` is unavailable from this source.
    let fullTextPaywalled: Bool
    let privacyClass: ProviderPrivacyClass
    let priority: Int

    var id: String { source.rawValue }

    var isRemote: Bool { source.isRemote }

    func supports(capability: ResearchCapability) -> Bool {
        supportedCapabilities.contains(capability)
    }
}

/// Request consumed by `ResearchProviderPolicy`. The `now:` and `*Draft`
/// injection keeps evaluation deterministic and free of clock/network.
struct ResearchProviderRequest: Codable, Hashable, Sendable {
    let traceID: String
    let query: String
    let capability: ResearchCapability
    let privacyClass: ProviderPrivacyClass
    let membershipTier: MembershipTier
    let preferredSource: ResearchSource?
    let meteredEntitlements: Set<ResearchSource>
    let enabledExperimentalSources: Set<ResearchSource>
    let freshness: ProviderFreshness
    let citationDraft: ResearchCitationDraft?
    let cachedCitation: ResearchCitation?
    let now: Date

    init(
        traceID: String = "research-trace",
        query: String,
        capability: ResearchCapability = .scholarlySearch,
        privacyClass: ProviderPrivacyClass = .general,
        membershipTier: MembershipTier = .free,
        preferredSource: ResearchSource? = nil,
        meteredEntitlements: Set<ResearchSource> = [],
        enabledExperimentalSources: Set<ResearchSource> = [],
        freshness: ProviderFreshness = .cachedOK,
        citationDraft: ResearchCitationDraft? = nil,
        cachedCitation: ResearchCitation? = nil,
        now: Date = Date()
    ) {
        self.traceID = traceID
        self.query = query
        self.capability = capability
        self.privacyClass = privacyClass
        self.membershipTier = membershipTier
        self.preferredSource = preferredSource
        self.meteredEntitlements = meteredEntitlements
        self.enabledExperimentalSources = enabledExperimentalSources
        self.freshness = freshness
        self.citationDraft = citationDraft
        self.cachedCitation = cachedCitation
        self.now = now
    }
}

/// Non-PII research route audit. Records routing metadata only.
struct ResearchProviderTrace: Codable, Hashable, Sendable {
    let traceID: String
    let capability: ResearchCapability
    let selectedSourceID: String?
    let selectedSource: ResearchSource?
    let skippedSources: [ResearchSourceSkip]
    let costClass: ProviderCostClass
    let privacyClass: ProviderPrivacyClass
    let membershipTier: MembershipTier
    let freshness: ProviderFreshness
    let failureReason: ResearchSourceSkipReason?
}

/// Final research route outcome.
struct ResearchProviderDecision: Hashable, Sendable {
    let selectedSource: ResearchSourceDescriptor?
    let citation: ResearchCitation?
    let skippedSources: [ResearchSourceSkip]
    let failureReason: ResearchSourceSkipReason?
    let trace: ResearchProviderTrace

    var isResolved: Bool {
        selectedSource != nil && citation != nil
    }
}

/// Pure academic-source selection. No side effects, no network, no API keys.
enum ResearchProviderPolicy {
    nonisolated static let staleCacheLimitation = "Citation is from cache and may be out of date."
    private static let paywallLimitation = "Full text is paywalled; only metadata/citation is available."

    static func evaluate(
        _ request: ResearchProviderRequest,
        registry: [ResearchSourceDescriptor] = ResearchSourceDescriptor.defaultRegistry
    ) -> ResearchProviderDecision {
        var skipped: [ResearchSourceSkip] = []
        let ordered = orderedSources(for: request, registry: registry)

        for descriptor in ordered {
            if let skip = skipReason(for: descriptor, request: request) {
                skipped.append(
                    ResearchSourceSkip(
                        sourceID: descriptor.id,
                        source: descriptor.source,
                        reason: skip
                    )
                )
                continue
            }

            guard let citation = makeCitation(for: descriptor, request: request) else {
                skipped.append(
                    ResearchSourceSkip(
                        sourceID: descriptor.id,
                        source: descriptor.source,
                        reason: .noResult
                    )
                )
                continue
            }

            return makeDecision(
                source: descriptor,
                citation: citation,
                skipped: skipped,
                failureReason: nil,
                request: request
            )
        }

        return makeDecision(
            source: nil,
            citation: nil,
            skipped: skipped,
            failureReason: dominantFailureReason(from: skipped),
            request: request
        )
    }

    private static func orderedSources(
        for request: ResearchProviderRequest,
        registry: [ResearchSourceDescriptor]
    ) -> [ResearchSourceDescriptor] {
        let base = registry.sorted { $0.priority < $1.priority }
        guard let preferred = request.preferredSource else { return base }
        return base.sorted { lhs, rhs in
            if lhs.source == preferred, rhs.source != preferred { return true }
            if rhs.source == preferred, lhs.source != preferred { return false }
            return lhs.priority < rhs.priority
        }
    }

    private static func skipReason(
        for descriptor: ResearchSourceDescriptor,
        request: ResearchProviderRequest
    ) -> ResearchSourceSkipReason? {
        guard descriptor.supports(capability: request.capability) else {
            return .unsupportedCapability
        }
        // Sources whose terms forbid programmatic access stay blocked in v1
        // (no compliant path exists yet), even if experimentally enabled.
        if descriptor.requiresComplianceReview {
            return .complianceReviewRequired
        }
        // Sources without an official API are disabled until explicitly enabled.
        if descriptor.hasOfficialAPI == false,
           request.enabledExperimentalSources.contains(descriptor.source) == false {
            return .disabledByDefault
        }
        // No private / health query reaches a remote research source.
        if descriptor.isRemote, request.privacyClass.allowsRemoteProvider == false {
            return .privacyBlocked
        }
        // Paywalled sources cannot satisfy full-text / abstract fetch.
        if descriptor.fullTextPaywalled, request.capability == .abstractFetch {
            return .paywallBlocked
        }
        guard request.membershipTier >= descriptor.minimumMembership else {
            return .costBlocked
        }
        if descriptor.costClass == .meteredPremium,
           request.membershipTier != .developerInternal,
           request.meteredEntitlements.contains(descriptor.source) == false {
            return .costBlocked
        }
        return nil
    }

    private static func makeCitation(
        for descriptor: ResearchSourceDescriptor,
        request: ResearchProviderRequest
    ) -> ResearchCitation? {
        if descriptor.source == .cache {
            return request.cachedCitation?.routedThroughCache(
                sourceID: descriptor.id,
                fetchedAt: request.now,
                limitations: [staleCacheLimitation]
            )
        }

        guard let draft = request.citationDraft else { return nil }
        let limitations = descriptor.fullTextPaywalled
            ? draft.limitations + [paywallLimitation]
            : draft.limitations

        return ResearchCitation(
            query: request.query,
            sourceID: descriptor.id,
            title: draft.title,
            authors: draft.authors,
            venue: draft.venue,
            year: draft.year,
            doi: draft.doi,
            url: draft.url,
            isPeerReviewed: draft.isPeerReviewed,
            isOpenAccess: draft.isOpenAccess,
            abstractAvailable: draft.abstractAvailable,
            fetchedAt: request.now,
            freshness: request.freshness,
            costClass: descriptor.costClass,
            confidence: draft.confidence,
            limitations: Array(Set(limitations)).sorted()
        )
    }

    private static func makeDecision(
        source: ResearchSourceDescriptor?,
        citation: ResearchCitation?,
        skipped: [ResearchSourceSkip],
        failureReason: ResearchSourceSkipReason?,
        request: ResearchProviderRequest
    ) -> ResearchProviderDecision {
        let trace = ResearchProviderTrace(
            traceID: request.traceID,
            capability: request.capability,
            selectedSourceID: source?.id,
            selectedSource: source?.source,
            skippedSources: skipped,
            costClass: source?.costClass ?? costClass(for: failureReason),
            privacyClass: request.privacyClass,
            membershipTier: request.membershipTier,
            freshness: citation?.freshness ?? request.freshness,
            failureReason: failureReason
        )
        return ResearchProviderDecision(
            selectedSource: source,
            citation: citation,
            skippedSources: skipped,
            failureReason: failureReason,
            trace: trace
        )
    }

    private static func dominantFailureReason(
        from skipped: [ResearchSourceSkip]
    ) -> ResearchSourceSkipReason? {
        let priority: [ResearchSourceSkipReason] = [
            .privacyBlocked,
            .complianceReviewRequired,
            .paywallBlocked,
            .costBlocked,
            .disabledByDefault,
            .unsupportedCapability,
            .noResult,
        ]
        for reason in priority where skipped.contains(where: { $0.reason == reason }) {
            return reason
        }
        return nil
    }

    private static func costClass(for failureReason: ResearchSourceSkipReason?) -> ProviderCostClass {
        switch failureReason {
        case .privacyBlocked:
            return .blockedByPrivacy
        case .costBlocked:
            return .blockedByCost
        case .complianceReviewRequired, .paywallBlocked, .disabledByDefault,
             .unsupportedCapability, .noResult, nil:
            return .blockedByTerms
        }
    }
}

extension ResearchSourceDescriptor {
    /// Reserved fixture registry. Real source access is server-mediated and
    /// deferred; this proves the policy + lets UI bind without hardcoding.
    ///
    /// Free official-API sources (arXiv, OpenAlex, Crossref, Semantic Scholar)
    /// ship at low tiers; PubMed is health-adjacent (`.private`); IEEE is
    /// metered with paywalled full text; Google Scholar has no official API and
    /// is compliance-blocked in v1.
    static let defaultRegistry: [ResearchSourceDescriptor] = [
        ResearchSourceDescriptor(
            source: .arxiv,
            displayName: "arXiv",
            supportedCapabilities: [.scholarlySearch, .citationLookup, .paperMetadata, .abstractFetch],
            minimumMembership: .free,
            costClass: .includedQuota,
            hasOfficialAPI: true,
            requiresComplianceReview: false,
            fullTextPaywalled: false,
            privacyClass: .general,
            priority: 10
        ),
        ResearchSourceDescriptor(
            source: .openAlex,
            displayName: "OpenAlex",
            supportedCapabilities: [.scholarlySearch, .citationLookup, .paperMetadata],
            minimumMembership: .free,
            costClass: .includedQuota,
            hasOfficialAPI: true,
            requiresComplianceReview: false,
            fullTextPaywalled: false,
            privacyClass: .general,
            priority: 12
        ),
        ResearchSourceDescriptor(
            source: .crossref,
            displayName: "Crossref",
            supportedCapabilities: [.citationLookup, .paperMetadata],
            minimumMembership: .free,
            costClass: .includedQuota,
            hasOfficialAPI: true,
            requiresComplianceReview: false,
            fullTextPaywalled: false,
            privacyClass: .general,
            priority: 14
        ),
        ResearchSourceDescriptor(
            source: .semanticScholar,
            displayName: "Semantic Scholar",
            supportedCapabilities: [.scholarlySearch, .citationLookup, .paperMetadata, .abstractFetch],
            minimumMembership: .free,
            costClass: .includedQuota,
            hasOfficialAPI: true,
            requiresComplianceReview: false,
            fullTextPaywalled: false,
            privacyClass: .general,
            priority: 16
        ),
        ResearchSourceDescriptor(
            source: .pubmed,
            displayName: "PubMed",
            supportedCapabilities: [.scholarlySearch, .citationLookup, .paperMetadata, .abstractFetch],
            minimumMembership: .plus,
            costClass: .includedQuota,
            hasOfficialAPI: true,
            requiresComplianceReview: false,
            fullTextPaywalled: false,
            privacyClass: .private,
            priority: 20
        ),
        ResearchSourceDescriptor(
            source: .ieee,
            displayName: "IEEE Xplore",
            supportedCapabilities: [.scholarlySearch, .citationLookup, .paperMetadata, .abstractFetch],
            minimumMembership: .pro,
            costClass: .meteredPremium,
            hasOfficialAPI: true,
            requiresComplianceReview: false,
            fullTextPaywalled: true,
            privacyClass: .general,
            priority: 30
        ),
        ResearchSourceDescriptor(
            source: .googleScholar,
            displayName: "Google Scholar",
            supportedCapabilities: [.scholarlySearch, .citationLookup],
            minimumMembership: .pro,
            costClass: .meteredPremium,
            hasOfficialAPI: false,
            requiresComplianceReview: true,
            fullTextPaywalled: false,
            privacyClass: .general,
            priority: 40
        ),
        ResearchSourceDescriptor(
            source: .cache,
            displayName: "Research Cache",
            supportedCapabilities: [.scholarlySearch, .citationLookup, .paperMetadata, .abstractFetch],
            minimumMembership: .free,
            costClass: .freeLocal,
            hasOfficialAPI: true,
            requiresComplianceReview: false,
            fullTextPaywalled: false,
            privacyClass: .general,
            priority: 100
        ),
    ]
}
