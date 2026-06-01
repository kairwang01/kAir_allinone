//
//  ServerProviderDryRunEvaluator.swift
//  kAir
//
//  Pure A13 evaluator for comparing server/provider envelope candidates.
//  This produces an audit-only plan and never executes a transport.
//

import Foundation

struct ServerProviderDryRunCandidate: Hashable, Sendable {
    let id: String
    let displayName: String
    let result: ServerProviderEnvelopeFactoryResult

    init(
        id: String,
        displayName: String,
        result: ServerProviderEnvelopeFactoryResult
    ) {
        self.id = id
        self.displayName = displayName
        self.result = result
    }
}

enum ServerProviderDryRunFallbackReason: String, Codable, Hashable, Sendable, CaseIterable {
    case selected
    case localFallbackAfterRemoteCostOrPrivacyBlock
    case factoryBlocked
    case validatorBlocked
    case freshnessRejected
    case lowerFreshness
    case higherCost
    case lowerPriority
}

enum ServerProviderDryRunReportStatus: String, Codable, Hashable, Sendable, CaseIterable {
    case selected
    case noCandidates
    case allCandidatesBlocked
    case freshnessUnsatisfied
}

struct ServerProviderDryRunCandidateTrace: Hashable, Sendable {
    let candidateID: String
    let displayName: String
    let isExecutable: Bool
    let traceID: String?
    let providerFamily: ProviderFamily?
    let capability: ProviderCapability?
    let privacyClass: ProviderPrivacyClass?
    let membershipTier: MembershipTier?
    let costClass: ProviderCostClass?
    let freshness: ProviderFreshness?
    let sourcePolicy: ServerSourcePolicy?
    let factoryRejectionReason: ServerProviderEnvelopeFactoryRejectionReason?
    let validatorDenialReason: ServerProviderDenialReason?
    let fallbackReason: ServerProviderDryRunFallbackReason
}

struct ServerProviderDryRunSelectedTrace: Hashable, Sendable {
    let candidateID: String
    let displayName: String
    let traceID: String
    let providerFamily: ProviderFamily
    let capability: ProviderCapability
    let privacyClass: ProviderPrivacyClass
    let membershipTier: MembershipTier
    let costClass: ProviderCostClass
    let freshness: ProviderFreshness
    let sourcePolicy: ServerSourcePolicy
    let fallbackReason: ServerProviderDryRunFallbackReason
}

struct ServerProviderDryRunReport: Hashable, Sendable {
    let capabilityLabel: String
    let requiredFreshness: ProviderFreshness
    let status: ServerProviderDryRunReportStatus
    let selected: ServerProviderDryRunSelectedTrace?
    let candidates: [ServerProviderDryRunCandidateTrace]

    var hasSelection: Bool {
        selected != nil
    }
}

enum ServerProviderDryRunEvaluator {
    static func evaluate(
        capabilityLabel: String,
        requiredFreshness: ProviderFreshness = .cachedOK,
        candidates: [ServerProviderDryRunCandidate]
    ) -> ServerProviderDryRunReport {
        guard candidates.isEmpty == false else {
            return ServerProviderDryRunReport(
                capabilityLabel: capabilityLabel,
                requiredFreshness: requiredFreshness,
                status: .noCandidates,
                selected: nil,
                candidates: []
            )
        }

        let hasRemoteCostOrPrivacyBlock = candidates.contains {
            remoteCostOrPrivacyBlocked(in: $0.result)
        }
        let rankedCandidates = candidates.enumerated().compactMap {
            rankableCandidate(
                index: $0.offset,
                candidate: $0.element,
                requiredFreshness: requiredFreshness,
                remoteCostOrPrivacyBlocked: hasRemoteCostOrPrivacyBlock
            )
        }
        let selectedCandidate = rankedCandidates.sorted(by: rankSort).first
        let selectedTrace = selectedCandidate.map {
            makeSelectedTrace(
                from: $0.candidate,
                localFallback: $0.localFallback
            )
        }
        let candidateTraces = candidates.map {
            makeCandidateTrace(
                for: $0,
                selectedID: selectedTrace?.candidateID,
                selectedEnvelope: selectedCandidate?.envelope,
                requiredFreshness: requiredFreshness,
                localFallbackSelected: selectedTrace?.fallbackReason == .localFallbackAfterRemoteCostOrPrivacyBlock
            )
        }

        return ServerProviderDryRunReport(
            capabilityLabel: capabilityLabel,
            requiredFreshness: requiredFreshness,
            status: status(
                selectedTrace: selectedTrace,
                hasExecutableCandidate: candidates.contains { $0.result.isExecutable }
            ),
            selected: selectedTrace,
            candidates: candidateTraces
        )
    }

    private struct RankableCandidate {
        let index: Int
        let candidate: ServerProviderDryRunCandidate
        let envelope: ServerProviderEnvelope
        let localFallback: Bool
    }

    private static func rankableCandidate(
        index: Int,
        candidate: ServerProviderDryRunCandidate,
        requiredFreshness: ProviderFreshness,
        remoteCostOrPrivacyBlocked: Bool
    ) -> RankableCandidate? {
        guard candidate.result.isExecutable,
              let envelope = candidate.result.envelope,
              freshness(envelope.freshness, satisfies: requiredFreshness) else {
            return nil
        }

        return RankableCandidate(
            index: index,
            candidate: candidate,
            envelope: envelope,
            localFallback: remoteCostOrPrivacyBlocked && envelope.providerFamily.isA13LocalOrCache
        )
    }

    nonisolated private static func rankSort(
        lhs: RankableCandidate,
        rhs: RankableCandidate
    ) -> Bool {
        let lhsKey = rankKey(lhs)
        let rhsKey = rankKey(rhs)
        if lhsKey.localFallback != rhsKey.localFallback {
            return lhsKey.localFallback < rhsKey.localFallback
        }
        if lhsKey.freshness != rhsKey.freshness {
            return lhsKey.freshness < rhsKey.freshness
        }
        if lhsKey.cost != rhsKey.cost {
            return lhsKey.cost < rhsKey.cost
        }
        return lhs.index < rhs.index
    }

    nonisolated private static func rankKey(
        _ candidate: RankableCandidate
    ) -> (localFallback: Int, freshness: Int, cost: Int) {
        (
            localFallback: candidate.localFallback ? 0 : 1,
            freshness: freshnessRank(candidate.envelope.freshness),
            cost: costRank(candidate.envelope.costClass)
        )
    }

    private static func makeSelectedTrace(
        from candidate: ServerProviderDryRunCandidate,
        localFallback: Bool
    ) -> ServerProviderDryRunSelectedTrace {
        let envelope = candidate.result.envelope!
        return ServerProviderDryRunSelectedTrace(
            candidateID: candidate.id,
            displayName: candidate.displayName,
            traceID: envelope.traceID,
            providerFamily: envelope.providerFamily,
            capability: envelope.capability,
            privacyClass: envelope.privacyClass,
            membershipTier: envelope.membershipTier,
            costClass: envelope.costClass,
            freshness: envelope.freshness,
            sourcePolicy: envelope.sourcePolicy,
            fallbackReason: localFallback
                ? .localFallbackAfterRemoteCostOrPrivacyBlock
                : .selected
        )
    }

    private static func makeCandidateTrace(
        for candidate: ServerProviderDryRunCandidate,
        selectedID: String?,
        selectedEnvelope: ServerProviderEnvelope?,
        requiredFreshness: ProviderFreshness,
        localFallbackSelected: Bool
    ) -> ServerProviderDryRunCandidateTrace {
        let result = candidate.result
        let envelope = result.envelope
        let audit = result.validation?.audit
        let providerFamily = envelope?.providerFamily
            ?? audit?.providerFamily
            ?? providerFamily(from: result.rejectionReason)
        let freshness = envelope?.freshness ?? audit?.trace.freshness
        return ServerProviderDryRunCandidateTrace(
            candidateID: candidate.id,
            displayName: candidate.displayName,
            isExecutable: result.isExecutable,
            traceID: envelope?.traceID ?? audit?.trace.traceID,
            providerFamily: providerFamily,
            capability: envelope?.capability ?? audit?.trace.capability,
            privacyClass: envelope?.privacyClass ?? audit?.trace.privacyClass,
            membershipTier: envelope?.membershipTier ?? audit?.trace.membershipTier,
            costClass: envelope?.costClass ?? audit?.trace.costClass,
            freshness: freshness,
            sourcePolicy: envelope?.sourcePolicy ?? audit?.sourcePolicy,
            factoryRejectionReason: result.rejectionReason,
            validatorDenialReason: result.validation?.denialReason,
            fallbackReason: fallbackReason(
                candidateID: candidate.id,
                selectedID: selectedID,
                result: result,
                selectedEnvelope: selectedEnvelope,
                actualFreshness: freshness,
                requiredFreshness: requiredFreshness,
                localFallbackSelected: localFallbackSelected
            )
        )
    }

    private static func fallbackReason(
        candidateID: String,
        selectedID: String?,
        result: ServerProviderEnvelopeFactoryResult,
        selectedEnvelope: ServerProviderEnvelope?,
        actualFreshness: ProviderFreshness?,
        requiredFreshness: ProviderFreshness,
        localFallbackSelected: Bool
    ) -> ServerProviderDryRunFallbackReason {
        if candidateID == selectedID {
            return localFallbackSelected
                ? .localFallbackAfterRemoteCostOrPrivacyBlock
                : .selected
        }
        if case .validatorRejected = result.rejectionReason {
            return .validatorBlocked
        }
        if result.rejectionReason != nil {
            return .factoryBlocked
        }
        guard let actualFreshness else {
            return .lowerPriority
        }
        if freshness(actualFreshness, satisfies: requiredFreshness) == false {
            return .freshnessRejected
        }
        guard let selectedID, let selectedEnvelope, let envelope = result.envelope else {
            return .lowerPriority
        }
        _ = selectedID
        if freshnessRank(actualFreshness) > freshnessRank(selectedEnvelope.freshness) {
            return .lowerFreshness
        }
        if costRank(envelope.costClass) > costRank(selectedEnvelope.costClass) {
            return .higherCost
        }
        return .lowerPriority
    }

    private static func status(
        selectedTrace: ServerProviderDryRunSelectedTrace?,
        hasExecutableCandidate: Bool
    ) -> ServerProviderDryRunReportStatus {
        if selectedTrace != nil { return .selected }
        return hasExecutableCandidate ? .freshnessUnsatisfied : .allCandidatesBlocked
    }

    private static func remoteCostOrPrivacyBlocked(
        in result: ServerProviderEnvelopeFactoryResult
    ) -> Bool {
        switch result.rejectionReason {
        case .entitlementMissing, .includedQuotaExhausted,
             .meteredEligibilityMissing:
            return true
        case .validatorRejected(.privacyBlocked):
            return true
        default:
            return result.validation?.denialReason == .privacyBlocked
        }
    }

    private static func providerFamily(
        from reason: ServerProviderEnvelopeFactoryRejectionReason?
    ) -> ProviderFamily? {
        switch reason {
        case .providerNotAllowed(let family),
             .providerDisabled(let family),
             .entitlementMissing(let family),
             .includedQuotaExhausted(let family),
             .meteredEligibilityMissing(let family),
             .experimentalProviderDisabled(let family):
            return family
        case .upstreamUnresolved, .sourcePolicyInsufficient,
             .confirmationMissing, .validatorRejected, nil:
            return nil
        }
    }

    private static func freshness(
        _ actual: ProviderFreshness,
        satisfies required: ProviderFreshness
    ) -> Bool {
        switch required {
        case .cachedOK:
            return true
        case .livePreferred:
            return actual == .livePreferred || actual == .liveRequired
        case .liveRequired:
            return actual == .liveRequired
        }
    }

    nonisolated private static func freshnessRank(_ freshness: ProviderFreshness) -> Int {
        switch freshness {
        case .liveRequired:
            return 0
        case .livePreferred:
            return 1
        case .cachedOK:
            return 2
        }
    }

    nonisolated private static func costRank(_ costClass: ProviderCostClass) -> Int {
        switch costClass {
        case .freeLocal:
            return 0
        case .includedQuota:
            return 1
        case .meteredPremium:
            return 2
        case .blockedByCost:
            return 3
        case .blockedByPrivacy:
            return 4
        case .blockedByTerms:
            return 5
        }
    }
}

private extension ProviderFamily {
    var isA13LocalOrCache: Bool {
        self == .appleLocal || self == .cache
    }
}
