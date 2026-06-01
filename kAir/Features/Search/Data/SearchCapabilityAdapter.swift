//
//  SearchCapabilityAdapter.swift
//  kAir
//
//  Read-only Search adapter facade. No network or crawler runtime.
//

import Foundation

@MainActor
final class SearchCapabilityAdapter: CapabilityAdapter {
    static let capability: CapabilityKind = .webSearch

    struct Configuration: Hashable, Sendable {
        var isEnabled: Bool
        var category: SearchIntent.Category
        var sourceMode: SearchIntent.SourceMode
        var privacyClass: ProviderPrivacyClass
        var providerAccessProfile: ProviderAccessProfile
        var providerQuotaSnapshot: ServerProviderQuotaSnapshot
        var freshness: ProviderFreshness
        var robotsState: SearchRobotsState
        var resultDrafts: [String: SearchResultDraft]
        var cachedResults: [String: SearchResultEnvelope]
        var registry: [SearchProviderDescriptor]
        var now: Date

        init(
            isEnabled: Bool = false,
            category: SearchIntent.Category = .lifeService,
            sourceMode: SearchIntent.SourceMode = .searchAPI,
            privacyClass: ProviderPrivacyClass = .general,
            providerAccessProfile: ProviderAccessProfile? = nil,
            providerQuotaSnapshot: ServerProviderQuotaSnapshot? = nil,
            membershipTier: MembershipTier = .free,
            meteredProviderEntitlements: Set<ProviderFamily> = [],
            enabledExperimentalProviders: Set<ProviderFamily> = [],
            freshness: ProviderFreshness = .cachedOK,
            robotsState: SearchRobotsState = .notApplicable,
            resultDrafts: [String: SearchResultDraft] = [:],
            cachedResults: [String: SearchResultEnvelope] = [:],
            registry: [SearchProviderDescriptor],
            now: Date = Date()
        ) {
            let resolvedProviderAccessProfile = providerAccessProfile ?? ProviderAccessProfile(
                membershipTier: membershipTier,
                meteredProviderEntitlements: meteredProviderEntitlements,
                enabledExperimentalProviders: enabledExperimentalProviders
            )
            self.isEnabled = isEnabled
            self.category = category
            self.sourceMode = sourceMode
            self.privacyClass = privacyClass
            self.providerAccessProfile = resolvedProviderAccessProfile
            self.providerQuotaSnapshot = providerQuotaSnapshot ?? ServerProviderQuotaSnapshot(
                providerAccessProfile: resolvedProviderAccessProfile
            )
            self.freshness = freshness
            self.robotsState = robotsState
            self.resultDrafts = Self.normalized(resultDrafts)
            self.cachedResults = Self.normalized(cachedResults)
            self.registry = registry
            self.now = now
        }

        @MainActor
        static func disabled(now: Date = Date()) -> Configuration {
            Configuration(
                registry: SearchProviderDescriptor.defaultRegistry,
                now: now
            )
        }

        @MainActor
        static func enabledFixture(
            category: SearchIntent.Category = .lifeService,
            sourceMode: SearchIntent.SourceMode = .searchAPI,
            privacyClass: ProviderPrivacyClass = .general,
            providerAccessProfile: ProviderAccessProfile? = nil,
            providerQuotaSnapshot: ServerProviderQuotaSnapshot? = nil,
            membershipTier: MembershipTier = .plus,
            meteredProviderEntitlements: Set<ProviderFamily> = [.searchAPI],
            enabledExperimentalProviders: Set<ProviderFamily> = [],
            freshness: ProviderFreshness = .livePreferred,
            robotsState: SearchRobotsState = .notApplicable,
            resultDrafts: [String: SearchResultDraft] = [:],
            cachedResults: [String: SearchResultEnvelope] = [:],
            registry: [SearchProviderDescriptor]? = nil,
            now: Date
        ) -> Configuration {
            Configuration(
                isEnabled: true,
                category: category,
                sourceMode: sourceMode,
                privacyClass: privacyClass,
                providerAccessProfile: providerAccessProfile,
                providerQuotaSnapshot: providerQuotaSnapshot,
                membershipTier: membershipTier,
                meteredProviderEntitlements: meteredProviderEntitlements,
                enabledExperimentalProviders: enabledExperimentalProviders,
                freshness: freshness,
                robotsState: robotsState,
                resultDrafts: resultDrafts,
                cachedResults: cachedResults,
                registry: registry ?? SearchProviderDescriptor.defaultRegistry,
                now: now
            )
        }

        private static func normalized<T>(_ values: [String: T]) -> [String: T] {
            Dictionary(
                uniqueKeysWithValues: values.map { key, value in
                    (SearchIntent.normalizedQuery(key), value)
                }
            )
        }
    }

    let configuration: Configuration

    init() {
        self.configuration = .disabled()
    }

    init(configuration: Configuration) {
        self.configuration = configuration
    }

    func isAvailable() async -> Bool {
        configuration.isEnabled
    }

    func resolve(_ request: CapabilityRequest) async throws -> NormalizedResult {
        guard request.kind == Self.capability else {
            throw CapabilityError.invalidRequest
        }
        guard await isAvailable() else {
            throw CapabilityError.unavailable
        }
        let intent = try intent(from: request)
        let decision = decision(for: intent)
        let projection = ResultProjector.project(
            searchDecision: decision,
            createdAt: configuration.now
        )

        guard let result = projection.normalizedResult else {
            throw error(for: decision.failureReason)
        }
        guard result.capability == Self.capability,
              NormalizedResult.variantMatchesCapability(result.payload, Self.capability) else {
            throw CapabilityError.partnerFailure
        }
        return result
    }

    func decision(for intent: SearchIntent) -> SearchProviderDecision {
        SearchProviderPolicy.evaluate(
            providerRequest(for: intent),
            registry: configuration.registry
        )
    }

    func dryRunPreview(
        for intent: SearchIntent,
        capabilityLabel: String = "Search"
    ) -> ServerProviderDryRunReport {
        let request = providerRequest(for: intent)
        let decision = SearchProviderPolicy.evaluate(
            request,
            registry: configuration.registry
        )
        return dryRunPreview(
            for: request,
            decision: decision,
            capabilityLabel: capabilityLabel
        )
    }

    func dryRunPreview(
        for request: SearchProviderRequest,
        decision: SearchProviderDecision,
        capabilityLabel: String = "Search"
    ) -> ServerProviderDryRunReport {
        let result = ServerProviderEnvelopeFactory.makeEnvelope(
            for: request,
            decision: decision,
            quotaSnapshot: configuration.providerQuotaSnapshot
        )
        let candidate = ServerProviderDryRunCandidate(
            id: decision.selectedProvider?.providerID ?? "search-policy-decision",
            displayName: decision.selectedProvider?.displayName ?? "Search policy decision",
            result: result
        )
        return ServerProviderDryRunEvaluator.evaluate(
            capabilityLabel: capabilityLabel,
            requiredFreshness: request.freshness,
            candidates: [candidate]
        )
    }

    func dryRunPresentation(
        for intent: SearchIntent,
        capabilityLabel: String = "Search"
    ) -> ServerProviderDryRunPresentation {
        dryRunPresentation(
            for: dryRunPreview(
                for: intent,
                capabilityLabel: capabilityLabel
            )
        )
    }

    func dryRunPresentation(
        for report: ServerProviderDryRunReport
    ) -> ServerProviderDryRunPresentation {
        ServerProviderDryRunPresentationProjector.project(report)
    }

    func dryRunProviderStatusSource(
        forRecommendationID recommendationID: String,
        intent: SearchIntent,
        capabilityLabel: String = "Search"
    ) -> SearchDryRunProviderStatusStore {
        dryRunProviderStatusSource(
            forRecommendationID: recommendationID,
            presentation: dryRunPresentation(
                for: intent,
                capabilityLabel: capabilityLabel
            )
        )
    }

    func dryRunProviderStatusSource(
        forRecommendationID recommendationID: String,
        report: ServerProviderDryRunReport
    ) -> SearchDryRunProviderStatusStore {
        dryRunProviderStatusSource(
            forRecommendationID: recommendationID,
            presentation: dryRunPresentation(for: report)
        )
    }

    func dryRunProviderStatusSource(
        forRecommendationID recommendationID: String,
        presentation: ServerProviderDryRunPresentation
    ) -> SearchDryRunProviderStatusStore {
        SearchDryRunProviderStatusStore(
            presentationsByRecommendationID: [
                recommendationID: presentation,
            ]
        )
    }

    func dryRunProviderStatusSource(
        presentations: [(recommendationID: String, presentation: ServerProviderDryRunPresentation)]
    ) -> SearchDryRunProviderStatusStore {
        SearchDryRunProviderStatusStore(presentations: presentations)
    }

    func dryRunProviderStatusSource(
        reports: [(recommendationID: String, report: ServerProviderDryRunReport)]
    ) -> SearchDryRunProviderStatusStore {
        dryRunProviderStatusSource(
            presentations: reports.map { entry in
                (
                    recommendationID: entry.recommendationID,
                    presentation: dryRunPresentation(for: entry.report)
                )
            }
        )
    }

    func providerRequest(for intent: SearchIntent) -> SearchProviderRequest {
        intent.providerRequest(
            providerAccessProfile: configuration.providerAccessProfile,
            resultDraft: configuration.resultDrafts[intent.query],
            cachedResult: configuration.cachedResults[intent.query],
            now: configuration.now
        )
    }

    func intent(from request: CapabilityRequest) throws -> SearchIntent {
        let query = SearchIntent.normalizedQuery(request.inputText ?? "")
        guard query.isEmpty == false else {
            throw CapabilityError.invalidRequest
        }

        return SearchIntent(
            query: query,
            category: configuration.category,
            sourceMode: configuration.sourceMode,
            privacyClass: configuration.privacyClass,
            membershipTier: configuration.providerAccessProfile.membershipTier,
            meteredProviderEntitlements: configuration.providerAccessProfile
                .meteredProviderEntitlements,
            enabledExperimentalProviders: configuration.providerAccessProfile
                .enabledExperimentalProviders,
            freshness: configuration.freshness,
            robotsState: configuration.robotsState,
            requestedAt: configuration.now
        )
    }

    private func error(for reason: SearchProviderSkipReason?) -> CapabilityError {
        switch reason {
        case .unsupportedCapability:
            return .invalidRequest
        case .privacyBlocked, .costBlocked, .disabledByDefault,
             .sourceDenied, .robotsBlocked, .noCachedResult, nil:
            return .unavailable
        }
    }
}
