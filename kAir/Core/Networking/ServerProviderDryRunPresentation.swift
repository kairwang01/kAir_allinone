//
//  ServerProviderDryRunPresentation.swift
//  kAir
//
//  Pure A14 projection from dry-run provider reports into UI-safe copy and
//  badge metadata. This file does not render UI or contact providers.
//

import Foundation

enum ServerProviderDryRunPresentationTone: String, Codable, Hashable, Sendable, CaseIterable {
    case positive
    case neutral
    case warning
}

enum ServerProviderDryRunPresentationRowKind: String, Codable, Hashable, Sendable, CaseIterable {
    case selectedProvider
    case blockedCandidate
    case costStatus
    case freshnessStatus
    case sourceStatus
    case fallbackStatus
}

struct ServerProviderDryRunPresentationBadge: Hashable, Identifiable, Sendable {
    let id: String
    let label: String
    let tone: ServerProviderDryRunPresentationTone
    let systemImage: String
}

struct ServerProviderDryRunPresentationRow: Hashable, Identifiable, Sendable {
    let id: String
    let kind: ServerProviderDryRunPresentationRowKind
    let title: String
    let detail: String
    let badges: [ServerProviderDryRunPresentationBadge]
    let isAdvisoryOnly: Bool
    let providerFamily: ProviderFamily?
    let costClass: ProviderCostClass?
    let freshness: ProviderFreshness?
    let privacyClass: ProviderPrivacyClass?
    let sourcePolicy: ServerSourcePolicy?
    let validatorDenialReason: ServerProviderDenialReason?
    let factoryRejectionReason: ServerProviderEnvelopeFactoryRejectionReason?
    let fallbackReason: ServerProviderDryRunFallbackReason?
}

struct ServerProviderDryRunPresentation: Hashable, Identifiable, Sendable {
    let id: String
    let capabilityLabel: String
    let summary: String
    let tone: ServerProviderDryRunPresentationTone
    let rows: [ServerProviderDryRunPresentationRow]

    var hasSelection: Bool {
        rows.contains { $0.kind == .selectedProvider }
    }
}

enum ServerProviderDryRunPresentationProjector {
    nonisolated static func project(
        _ report: ServerProviderDryRunReport
    ) -> ServerProviderDryRunPresentation {
        var rows: [ServerProviderDryRunPresentationRow] = []

        if let selected = report.selected {
            rows.append(selectedProviderRow(selected))
            rows.append(contentsOf: selectedStatusRows(selected))
        }

        rows.append(
            contentsOf: report.candidates
                .filter { $0.candidateID != report.selected?.candidateID }
                .map { trace in blockedOrSecondaryRow(trace) }
        )

        return ServerProviderDryRunPresentation(
            id: "server-provider-dry-run-\(slug(report.capabilityLabel))",
            capabilityLabel: report.capabilityLabel,
            summary: summary(for: report),
            tone: tone(for: report),
            rows: rows
        )
    }

    nonisolated private static func selectedProviderRow(
        _ selected: ServerProviderDryRunSelectedTrace
    ) -> ServerProviderDryRunPresentationRow {
        ServerProviderDryRunPresentationRow(
            id: "selected-\(selected.candidateID)",
            kind: .selectedProvider,
            title: "Dry run: \(providerLabel(selected.providerFamily)) is the preferred route",
            detail: advisoryDetail(
                for: selected.fallbackReason == .localFallbackAfterRemoteCostOrPrivacyBlock
                    ? "Local fallback is preferred because a remote option is blocked by cost or privacy policy."
                    : "This provider path satisfies the dry-run policy checks."
            ),
            badges: [
                badge(for: selected.providerFamily),
                costBadge(for: selected.costClass),
                freshnessBadge(for: selected.freshness),
            ],
            isAdvisoryOnly: true,
            providerFamily: selected.providerFamily,
            costClass: selected.costClass,
            freshness: selected.freshness,
            privacyClass: selected.privacyClass,
            sourcePolicy: selected.sourcePolicy,
            validatorDenialReason: nil,
            factoryRejectionReason: nil,
            fallbackReason: selected.fallbackReason
        )
    }

    nonisolated private static func selectedStatusRows(
        _ selected: ServerProviderDryRunSelectedTrace
    ) -> [ServerProviderDryRunPresentationRow] {
        var rows: [ServerProviderDryRunPresentationRow] = [
            statusRow(
                id: "cost-\(selected.candidateID)",
                kind: .costStatus,
                title: costTitle(selected.costClass),
                detail: advisoryDetail(for: costDetail(selected.costClass)),
                badges: [costBadge(for: selected.costClass)],
                selected: selected
            ),
            statusRow(
                id: "freshness-\(selected.candidateID)",
                kind: .freshnessStatus,
                title: freshnessTitle(selected.freshness),
                detail: advisoryDetail(for: freshnessDetail(selected.freshness)),
                badges: [freshnessBadge(for: selected.freshness)],
                selected: selected
            ),
        ]

        if selected.fallbackReason == .localFallbackAfterRemoteCostOrPrivacyBlock {
            rows.append(
                statusRow(
                    id: "fallback-\(selected.candidateID)",
                    kind: .fallbackStatus,
                    title: "Local fallback is active for the dry run",
                    detail: advisoryDetail(
                        for: "Remote cost or privacy policy blocked a candidate, so the local route is preferred."
                    ),
                    badges: [fallbackBadge()],
                    selected: selected
                )
            )
        }

        if selected.sourcePolicy.sourceState != .notApplicable {
            rows.append(
                statusRow(
                    id: "source-\(selected.candidateID)",
                    kind: .sourceStatus,
                    title: sourceTitle(selected.sourcePolicy),
                    detail: advisoryDetail(for: sourceDetail(selected.sourcePolicy)),
                    badges: [sourceBadge(for: selected.sourcePolicy)],
                    selected: selected
                )
            )
        }

        return rows
    }

    nonisolated private static func statusRow(
        id: String,
        kind: ServerProviderDryRunPresentationRowKind,
        title: String,
        detail: String,
        badges: [ServerProviderDryRunPresentationBadge],
        selected: ServerProviderDryRunSelectedTrace
    ) -> ServerProviderDryRunPresentationRow {
        ServerProviderDryRunPresentationRow(
            id: id,
            kind: kind,
            title: title,
            detail: detail,
            badges: badges,
            isAdvisoryOnly: true,
            providerFamily: selected.providerFamily,
            costClass: selected.costClass,
            freshness: selected.freshness,
            privacyClass: selected.privacyClass,
            sourcePolicy: selected.sourcePolicy,
            validatorDenialReason: nil,
            factoryRejectionReason: nil,
            fallbackReason: selected.fallbackReason
        )
    }

    nonisolated private static func blockedOrSecondaryRow(
        _ trace: ServerProviderDryRunCandidateTrace
    ) -> ServerProviderDryRunPresentationRow {
        ServerProviderDryRunPresentationRow(
            id: "candidate-\(trace.candidateID)",
            kind: .blockedCandidate,
            title: blockedTitle(for: trace),
            detail: advisoryDetail(for: blockedDetail(for: trace)),
            badges: blockedBadges(for: trace),
            isAdvisoryOnly: true,
            providerFamily: trace.providerFamily,
            costClass: trace.costClass,
            freshness: trace.freshness,
            privacyClass: trace.privacyClass,
            sourcePolicy: trace.sourcePolicy,
            validatorDenialReason: trace.validatorDenialReason,
            factoryRejectionReason: trace.factoryRejectionReason,
            fallbackReason: trace.fallbackReason
        )
    }

    nonisolated private static func summary(
        for report: ServerProviderDryRunReport
    ) -> String {
        switch report.status {
        case .selected:
            guard let selected = report.selected else {
                return "Dry run: provider route is advisory only. No provider was contacted."
            }
            return "Dry run: \(providerLabel(selected.providerFamily)) is preferred for \(report.capabilityLabel). No provider was contacted."
        case .noCandidates:
            return "Dry run: no provider candidates were available for \(report.capabilityLabel)."
        case .allCandidatesBlocked:
            return "Dry run: all provider candidates are blocked for \(report.capabilityLabel)."
        case .freshnessUnsatisfied:
            return "Dry run: provider candidates do not satisfy \(report.requiredFreshness.rawValue) freshness."
        }
    }

    nonisolated private static func tone(
        for report: ServerProviderDryRunReport
    ) -> ServerProviderDryRunPresentationTone {
        switch report.status {
        case .selected:
            return report.selected?.costClass == .meteredPremium ? .warning : .positive
        case .noCandidates, .allCandidatesBlocked, .freshnessUnsatisfied:
            return .warning
        }
    }

    nonisolated private static func blockedTitle(
        for trace: ServerProviderDryRunCandidateTrace
    ) -> String {
        if trace.validatorDenialReason == .privacyBlocked {
            return "Privacy policy blocks this dry-run candidate"
        }
        if trace.fallbackReason == .freshnessRejected {
            return "Stale cache rejected for live-required work"
        }
        return "\(trace.displayName) is not preferred in this dry run"
    }

    nonisolated private static func blockedDetail(
        for trace: ServerProviderDryRunCandidateTrace
    ) -> String {
        if trace.validatorDenialReason == .privacyBlocked {
            return "Health or private context cannot leave the local policy boundary."
        }
        if let factoryReason = trace.factoryRejectionReason {
            return factoryDetail(for: factoryReason)
        }
        switch trace.fallbackReason {
        case .freshnessRejected:
            return "Cached freshness does not satisfy the live-required setting."
        case .higherCost:
            return "A lower-cost provider satisfies the same freshness requirement."
        case .lowerFreshness:
            return "A fresher provider satisfies this dry-run requirement."
        case .lowerPriority:
            return "Another provider has a stronger dry-run ranking."
        case .factoryBlocked, .validatorBlocked,
             .localFallbackAfterRemoteCostOrPrivacyBlock, .selected:
            return "Policy keeps this candidate as advisory metadata only."
        }
    }

    nonisolated private static func factoryDetail(
        for reason: ServerProviderEnvelopeFactoryRejectionReason
    ) -> String {
        switch reason {
        case .upstreamUnresolved:
            return "Upstream provider policy did not resolve this candidate."
        case .providerNotAllowed(let family):
            return "\(providerLabel(family)) is not allowed by the quota snapshot."
        case .providerDisabled(let family):
            return "\(providerLabel(family)) is disabled by the quota snapshot."
        case .entitlementMissing(let family):
            return "\(providerLabel(family)) requires an entitlement before it can be preferred."
        case .includedQuotaExhausted(let family):
            return "\(providerLabel(family)) has no included quota remaining."
        case .meteredEligibilityMissing(let family):
            return "\(providerLabel(family)) requires metered eligibility."
        case .experimentalProviderDisabled(let family):
            return "\(providerLabel(family)) requires explicit experimental enablement."
        case .sourcePolicyInsufficient:
            return "Source policy metadata is insufficient for this candidate."
        case .confirmationMissing:
            return "Required confirmation metadata is missing."
        case .validatorRejected(let reason):
            return validatorDetail(for: reason)
        }
    }

    nonisolated private static func validatorDetail(
        for reason: ServerProviderDenialReason
    ) -> String {
        switch reason {
        case .privacyBlocked:
            return "Privacy policy blocks remote routing for this context."
        case .missingEntitlement:
            return "Provider entitlement is missing."
        case .crawlerRobotsBlocked:
            return "Crawler robots policy is not allowed."
        case .crawlerSourceBlocked, .sourcePolicyBlocked:
            return "Source policy does not pass."
        case .mcpDisabled:
            return "MCP is disabled by default."
        case .confirmationRequired:
            return "Confirmation metadata is required."
        case .missingTraceID:
            return "Trace metadata is missing."
        case .unsupportedCapability:
            return "Provider does not support this capability."
        case .blockedCostClass:
            return "Cost class is blocked."
        case .membershipTierTooLow:
            return "Membership tier is too low."
        case .experimentalProviderDisabled:
            return "Experimental provider is disabled."
        }
    }

    nonisolated private static func blockedBadges(
        for trace: ServerProviderDryRunCandidateTrace
    ) -> [ServerProviderDryRunPresentationBadge] {
        var badges: [ServerProviderDryRunPresentationBadge] = []
        if let family = trace.providerFamily {
            badges.append(badge(for: family))
        }
        if let costClass = trace.costClass {
            badges.append(costBadge(for: costClass))
        }
        if let freshness = trace.freshness {
            badges.append(freshnessBadge(for: freshness))
        }
        if trace.validatorDenialReason == .privacyBlocked {
            badges.append(
                ServerProviderDryRunPresentationBadge(
                    id: "privacy-blocked",
                    label: "Privacy blocked",
                    tone: .warning,
                    systemImage: "lock.shield"
                )
            )
        }
        if badges.isEmpty {
            badges.append(
                ServerProviderDryRunPresentationBadge(
                    id: "policy-blocked",
                    label: "Policy blocked",
                    tone: .warning,
                    systemImage: "exclamationmark.triangle"
                )
            )
        }
        return deduplicated(badges)
    }

    nonisolated private static func badge(
        for family: ProviderFamily
    ) -> ServerProviderDryRunPresentationBadge {
        switch family {
        case .appleLocal:
            return ServerProviderDryRunPresentationBadge(
                id: "provider-apple-local",
                label: "Apple Local",
                tone: .positive,
                systemImage: "iphone"
            )
        case .cache:
            return ServerProviderDryRunPresentationBadge(
                id: "provider-cache",
                label: "Local cache",
                tone: .neutral,
                systemImage: "archivebox"
            )
        case .gaode:
            return remoteBadge(id: "provider-gaode", label: "Gaode")
        case .googleMaps:
            return remoteBadge(id: "provider-google-maps", label: "Google Maps")
        case .searchAPI:
            return remoteBadge(id: "provider-search-api", label: "Search API")
        case .crawler:
            return remoteBadge(id: "provider-crawler", label: "Crawler")
        case .mcp:
            return remoteBadge(id: "provider-mcp", label: "MCP")
        }
    }

    nonisolated private static func remoteBadge(
        id: String,
        label: String
    ) -> ServerProviderDryRunPresentationBadge {
        ServerProviderDryRunPresentationBadge(
            id: id,
            label: label,
            tone: .neutral,
            systemImage: "network"
        )
    }

    nonisolated private static func costBadge(
        for costClass: ProviderCostClass
    ) -> ServerProviderDryRunPresentationBadge {
        switch costClass {
        case .freeLocal:
            return ServerProviderDryRunPresentationBadge(
                id: "cost-free-local",
                label: "Free local",
                tone: .positive,
                systemImage: "checkmark.shield"
            )
        case .includedQuota:
            return ServerProviderDryRunPresentationBadge(
                id: "cost-included-quota",
                label: "Included quota",
                tone: .positive,
                systemImage: "checkmark.seal"
            )
        case .meteredPremium:
            return ServerProviderDryRunPresentationBadge(
                id: "cost-metered-premium",
                label: "Premium metered",
                tone: .warning,
                systemImage: "creditcard"
            )
        case .blockedByCost:
            return blockedBadge(id: "cost-blocked", label: "Cost blocked")
        case .blockedByPrivacy:
            return blockedBadge(id: "privacy-blocked-cost", label: "Privacy blocked")
        case .blockedByTerms:
            return blockedBadge(id: "terms-blocked", label: "Terms blocked")
        }
    }

    nonisolated private static func blockedBadge(
        id: String,
        label: String
    ) -> ServerProviderDryRunPresentationBadge {
        ServerProviderDryRunPresentationBadge(
            id: id,
            label: label,
            tone: .warning,
            systemImage: "exclamationmark.triangle"
        )
    }

    nonisolated private static func freshnessBadge(
        for freshness: ProviderFreshness
    ) -> ServerProviderDryRunPresentationBadge {
        switch freshness {
        case .cachedOK:
            return ServerProviderDryRunPresentationBadge(
                id: "freshness-cached-ok",
                label: "Cached OK",
                tone: .neutral,
                systemImage: "archivebox"
            )
        case .livePreferred:
            return ServerProviderDryRunPresentationBadge(
                id: "freshness-live-preferred",
                label: "Live preferred",
                tone: .positive,
                systemImage: "dot.radiowaves.left.and.right"
            )
        case .liveRequired:
            return ServerProviderDryRunPresentationBadge(
                id: "freshness-live-required",
                label: "Live required",
                tone: .positive,
                systemImage: "bolt.badge.checkmark"
            )
        }
    }

    nonisolated private static func fallbackBadge() -> ServerProviderDryRunPresentationBadge {
        ServerProviderDryRunPresentationBadge(
            id: "fallback-local",
            label: "Local fallback",
            tone: .positive,
            systemImage: "arrow.uturn.backward.circle"
        )
    }

    nonisolated private static func sourceBadge(
        for sourcePolicy: ServerSourcePolicy
    ) -> ServerProviderDryRunPresentationBadge {
        switch sourcePolicy.sourceState {
        case .passed:
            return ServerProviderDryRunPresentationBadge(
                id: "source-passed",
                label: "Source policy passed",
                tone: .positive,
                systemImage: "checkmark.seal"
            )
        case .blocked:
            return blockedBadge(id: "source-blocked", label: "Source blocked")
        case .unknown:
            return blockedBadge(id: "source-unknown", label: "Source unknown")
        case .notApplicable:
            return ServerProviderDryRunPresentationBadge(
                id: "source-not-applicable",
                label: "No source check",
                tone: .neutral,
                systemImage: "minus.circle"
            )
        }
    }

    nonisolated private static func costTitle(_ costClass: ProviderCostClass) -> String {
        switch costClass {
        case .freeLocal:
            return "Cost status: free local"
        case .includedQuota:
            return "Cost status: included quota"
        case .meteredPremium:
            return "Cost status: premium metered"
        case .blockedByCost:
            return "Cost status: blocked by cost"
        case .blockedByPrivacy:
            return "Cost status: blocked by privacy"
        case .blockedByTerms:
            return "Cost status: blocked by terms"
        }
    }

    nonisolated private static func costDetail(_ costClass: ProviderCostClass) -> String {
        switch costClass {
        case .freeLocal:
            return "Local processing has no remote provider cost."
        case .includedQuota:
            return "This route fits the included provider quota."
        case .meteredPremium:
            return "This route may consume premium metered allowance."
        case .blockedByCost:
            return "Cost policy blocks this route."
        case .blockedByPrivacy:
            return "Privacy policy blocks this route."
        case .blockedByTerms:
            return "Provider terms block this route."
        }
    }

    nonisolated private static func freshnessTitle(_ freshness: ProviderFreshness) -> String {
        switch freshness {
        case .cachedOK:
            return "Freshness status: cached allowed"
        case .livePreferred:
            return "Freshness status: live preferred"
        case .liveRequired:
            return "Freshness status: live required"
        }
    }

    nonisolated private static func freshnessDetail(_ freshness: ProviderFreshness) -> String {
        switch freshness {
        case .cachedOK:
            return "Cached information can satisfy this dry-run route."
        case .livePreferred:
            return "Live information is preferred for this route."
        case .liveRequired:
            return "Live information is required for this route."
        }
    }

    nonisolated private static func sourceTitle(_ sourcePolicy: ServerSourcePolicy) -> String {
        switch sourcePolicy.sourceState {
        case .passed:
            return "Source status: policy passed"
        case .blocked:
            return "Source status: blocked"
        case .unknown:
            return "Source status: unknown"
        case .notApplicable:
            return "Source status: not required"
        }
    }

    nonisolated private static func sourceDetail(_ sourcePolicy: ServerSourcePolicy) -> String {
        switch sourcePolicy.sourceState {
        case .passed:
            return "Source and robots metadata passed for host \(sourcePolicy.sourceHost ?? "unknown")."
        case .blocked:
            return "Source policy blocks this route."
        case .unknown:
            return "Source policy has not been proven."
        case .notApplicable:
            return "No public source check is required for this route."
        }
    }

    nonisolated private static func providerLabel(_ family: ProviderFamily) -> String {
        switch family {
        case .appleLocal:
            return "Apple Local"
        case .gaode:
            return "Gaode"
        case .googleMaps:
            return "Google Maps"
        case .searchAPI:
            return "Search API"
        case .crawler:
            return "Crawler"
        case .mcp:
            return "MCP"
        case .cache:
            return "Local cache"
        }
    }

    nonisolated private static func advisoryDetail(for detail: String) -> String {
        "\(detail) Advisory only; no provider was contacted."
    }

    nonisolated private static func slug(_ value: String) -> String {
        let normalized = value
            .lowercased()
            .map { character in
                character.isLetter || character.isNumber ? String(character) : "-"
            }
            .joined()
        return normalized
            .split(separator: "-")
            .joined(separator: "-")
    }

    nonisolated private static func deduplicated(
        _ badges: [ServerProviderDryRunPresentationBadge]
    ) -> [ServerProviderDryRunPresentationBadge] {
        var seen: Set<String> = []
        var output: [ServerProviderDryRunPresentationBadge] = []
        for badge in badges where seen.insert(badge.id).inserted {
            output.append(badge)
        }
        return output
    }
}
