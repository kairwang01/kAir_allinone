//
//  RetrievalCandidateProvider.swift
//  kAir
//
//  Query-aware retrieval over the shared matching corpus.
//

import Foundation

enum RetrievalProviderVariant: Hashable {
    case v3LexicalBaseline
    case v4FocusQueryHardening

    var versionID: String {
        switch self {
        case .v3LexicalBaseline:
            return "retrieval-provider-v3-lexical"
        case .v4FocusQueryHardening:
            return "retrieval-provider-v4-query-hardening"
        }
    }

    var enablesFocusWorkMusicInference: Bool {
        self == .v4FocusQueryHardening
    }

    var enablesNegatedCommuteSuppression: Bool {
        self == .v4FocusQueryHardening
    }
}

struct RetrievalCandidateProvider: CandidateProvider {
    let id = "retrieval"
    let variant: RetrievalProviderVariant
    var versionID: String { variant.versionID }

    private let seedProviders: [any CandidateProvider]
    private let maxCandidates: Int

    init(
        variant: RetrievalProviderVariant = .v4FocusQueryHardening,
        seedProviders: [any CandidateProvider] = .defaultMatchingProviders,
        maxCandidates: Int = 12
    ) {
        self.variant = variant
        self.seedProviders = seedProviders
        self.maxCandidates = max(6, maxCandidates)
    }

    func generateCandidates(for context: MatchingFeatureContext) -> [UnifiedMatchingCandidate] {
        let seedCandidates = seedProviders.flatMap { $0.generateCandidates(for: context) }
        guard seedCandidates.isEmpty == false else { return [] }

        let query = RetrievalQuery(
            context: context,
            variant: variant
        )
        let documents = seedCandidates.map(RetrievalDocument.init)
        let inverseDocumentFrequency = makeInverseDocumentFrequency(for: documents)

        let ranked = documents
            .map { document in
                score(
                    document: document,
                    query: query,
                    inverseDocumentFrequency: inverseDocumentFrequency,
                    context: context,
                    corpusSize: documents.count
                )
            }
            .sorted { lhs, rhs in
                if lhs.retrievalScore == rhs.retrievalScore {
                    return lhs.document.candidate.title < rhs.document.candidate.title
                }
                return lhs.retrievalScore > rhs.retrievalScore
            }

        return selectCandidates(from: ranked).map(\.candidate)
    }

    private func score(
        document: RetrievalDocument,
        query: RetrievalQuery,
        inverseDocumentFrequency: [String: Double],
        context: MatchingFeatureContext,
        corpusSize: Int
    ) -> RetrievedCandidate {
        let matchedTokens = Array(
            Set(document.tokens.keys).intersection(query.tokens.keys)
        )
        .sorted { lhs, rhs in
            let lhsWeight = inverseDocumentFrequency[lhs, default: 1]
            let rhsWeight = inverseDocumentFrequency[rhs, default: 1]
            if lhsWeight == rhsWeight {
                return lhs < rhs
            }
            return lhsWeight > rhsWeight
        }

        let promptLexicalScore = weightedLexicalScore(
            queryTokens: query.promptTokens,
            documentTokens: document.tokens,
            inverseDocumentFrequency: inverseDocumentFrequency
        )
        let contextLexicalScore = weightedLexicalScore(
            queryTokens: query.contextTokens,
            documentTokens: document.tokens,
            inverseDocumentFrequency: inverseDocumentFrequency
        )
        let phraseScore = promptPhraseScore(
            phrases: query.promptPhrases,
            documentText: document.normalizedText
        )

        let tagOverlap = normalizedOverlap(
            lhs: query.intentTags,
            rhs: document.candidate.tags
        )
        let recencyOverlap = normalizedOverlap(
            lhs: query.softRecencyTags,
            rhs: document.candidate.tags
        )
        let longTermOverlap = normalizedOverlap(
            lhs: query.softLongTermTags,
            rhs: document.candidate.tags
        )
        let objectAffinity = context.objectTypeAffinity[document.candidate.objectKind, default: 0.35]
        let activeSurfaceBoost = activeSurfaceBoost(
            for: document.candidate,
            activeSurface: context.activeSurface,
            affinity: query.activeSurfaceAffinity
        )
        let suppressionPenalty = query.suppressionPenalty(for: document.candidate)
        let promptEvidenceScore = min(
            1,
            max(
                promptLexicalScore,
                tagOverlap * 0.78,
                phraseScore * 0.92
            )
        )
        let contextSupport = min(
            0.10,
            contextLexicalScore * 0.04 +
                recencyOverlap * 0.025 +
                longTermOverlap * 0.015 +
                objectAffinity * 0.015 +
                activeSurfaceBoost * 0.015
        )

        let retrievalScore = min(
            0.99,
            max(
                0.08,
                0.08 +
                    promptLexicalScore * 0.42 +
                    phraseScore * 0.14 +
                    tagOverlap * 0.24 +
                    contextSupport -
                    suppressionPenalty
            )
        )

        var coarseReasonTags: [MatchingCoarseReasonTag] = [.context]
        if recencyOverlap > 0 || longTermOverlap > 0 {
            coarseReasonTags.append(.behavior)
        }
        if document.candidate.constraints.allowedDayparts?.contains(context.daypart) == true {
            coarseReasonTags.append(.temporal)
        }
        if document.candidate.retrieval.availability != .available {
            coarseReasonTags.append(.availability)
        }

        let metadata = [
            MatchingDebugField(key: "seed_provider", value: document.candidate.providerID),
            MatchingDebugField(key: "source_pool", value: document.candidate.sourcePool),
            MatchingDebugField(key: "corpus_size", value: "\(corpusSize)"),
            MatchingDebugField(key: "lexical_score", value: format(promptEvidenceScore)),
            MatchingDebugField(key: "prompt_evidence_score", value: format(promptEvidenceScore)),
            MatchingDebugField(key: "prompt_lexical_score", value: format(promptLexicalScore)),
            MatchingDebugField(key: "context_lexical_score", value: format(contextLexicalScore)),
            MatchingDebugField(key: "phrase_score", value: format(phraseScore)),
            MatchingDebugField(key: "context_support", value: format(contextSupport)),
            MatchingDebugField(key: "tag_overlap", value: format(tagOverlap)),
            MatchingDebugField(key: "recency_overlap", value: format(recencyOverlap)),
            MatchingDebugField(key: "long_term_overlap", value: format(longTermOverlap)),
            MatchingDebugField(key: "object_affinity", value: format(objectAffinity)),
            MatchingDebugField(key: "active_surface_boost", value: format(activeSurfaceBoost)),
            MatchingDebugField(key: "suppression_penalty", value: format(suppressionPenalty)),
            MatchingDebugField(key: "prompt_tags", value: query.intentTags.map(\.rawValue).sorted().joined(separator: ",")),
            MatchingDebugField(key: "soft_recency_tags", value: query.softRecencyTags.map(\.rawValue).sorted().joined(separator: ",")),
            MatchingDebugField(key: "soft_long_term_tags", value: query.softLongTermTags.map(\.rawValue).sorted().joined(separator: ",")),
            MatchingDebugField(key: "suppressed_tags", value: query.suppressedTags.map(\.rawValue).sorted().joined(separator: ",")),
            MatchingDebugField(key: "suppressed_surfaces", value: query.suppressedSurfaces.map(\.rawValue).sorted().joined(separator: ",")),
            MatchingDebugField(key: "suppressed_candidates", value: query.suppressedCandidateIDs.sorted().joined(separator: ",")),
            MatchingDebugField(key: "active_surface_mode", value: query.activeSurfaceMode),
            MatchingDebugField(key: "query_blocks", value: query.blockedContextSources.joined(separator: ",")),
            MatchingDebugField(key: "query_variant", value: variant.versionID),
            MatchingDebugField(
                key: "matched_terms",
                value: matchedTokens.prefix(6).joined(separator: ",")
            ),
        ]

        let candidate = materializeCandidate(
            from: document.candidate,
            retrieval: MatchingRetrievalDescriptor(
                providerID: id,
                retrievalScore: retrievalScore,
                freshnessHours: document.candidate.retrieval.freshnessHours,
                availability: document.candidate.retrieval.availability,
                coarseReasonTags: orderedUnique(coarseReasonTags),
                metadata: metadata
            )
        )

        if query.suppressedCandidateIDs.contains(document.candidate.id) {
            let candidate = materializeCandidate(
                from: document.candidate,
                retrieval: MatchingRetrievalDescriptor(
                    providerID: id,
                    retrievalScore: 0,
                    freshnessHours: document.candidate.retrieval.freshnessHours,
                    availability: document.candidate.retrieval.availability,
                    coarseReasonTags: [.behavior],
                    metadata: [MatchingDebugField(key: "hard_blocked", value: "true")]
                )
            )
            return RetrievedCandidate(candidate: candidate, document: document, retrievalScore: 0)
        }

        return RetrievedCandidate(
            candidate: candidate,
            document: document,
            retrievalScore: retrievalScore
        )
    }

    private func selectCandidates(
        from ranked: [RetrievedCandidate]
    ) -> [RetrievedCandidate] {
        var selected: [RetrievedCandidate] = []
        var objectKindCounts: [MatchingObjectKind: Int] = [:]
        var sourcePoolCounts: [String: Int] = [:]

        for entry in ranked {
            let objectKindCount = objectKindCounts[entry.candidate.objectKind, default: 0]
            let sourcePoolCount = sourcePoolCounts[entry.candidate.sourcePool, default: 0]

            if objectKindCount >= 3 || sourcePoolCount >= 3 {
                continue
            }

            selected.append(entry)
            objectKindCounts[entry.candidate.objectKind, default: 0] += 1
            sourcePoolCounts[entry.candidate.sourcePool, default: 0] += 1

            if selected.count >= maxCandidates {
                return selected
            }
        }

        if selected.count >= maxCandidates {
            return selected
        }

        for entry in ranked where selected.contains(where: { $0.candidate.id == entry.candidate.id }) == false {
            selected.append(entry)
            if selected.count >= maxCandidates {
                break
            }
        }

        return selected
    }

    private func materializeCandidate(
        from candidate: UnifiedMatchingCandidate,
        retrieval: MatchingRetrievalDescriptor
    ) -> UnifiedMatchingCandidate {
        UnifiedMatchingCandidate(
            id: candidate.id,
            title: candidate.title,
            summary: candidate.summary,
            objectKind: candidate.objectKind,
            preferredSection: candidate.preferredSection,
            activationPrompt: candidate.activationPrompt,
            tags: candidate.tags,
            sourcePool: candidate.sourcePool,
            domainKey: candidate.domainKey,
            semanticKey: candidate.semanticKey,
            providerID: id,
            retrieval: retrieval,
            constraints: candidate.constraints,
            utilityProfile: candidate.utilityProfile
        )
    }

    private func activeSurfaceBoost(
        for candidate: UnifiedMatchingCandidate,
        activeSurface: AppSection,
        affinity: Double
    ) -> Double {
        guard activeSurface != .chat, affinity > 0 else { return 0 }
        return candidate.preferredSection == activeSurface ? affinity : 0
    }

    private func normalizedOverlap<T: Hashable>(
        lhs: Set<T>,
        rhs: Set<T>
    ) -> Double {
        guard lhs.isEmpty == false, rhs.isEmpty == false else { return 0 }
        let shared = lhs.intersection(rhs).count
        return Double(shared) / Double(max(lhs.count, rhs.count))
    }

    private func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func weightedLexicalScore(
        queryTokens: [String: Double],
        documentTokens: [String: Double],
        inverseDocumentFrequency: [String: Double]
    ) -> Double {
        guard queryTokens.isEmpty == false else { return 0 }

        let lexicalNumerator = queryTokens.reduce(0.0) { partial, entry in
            let token = entry.key
            let queryWeight = entry.value
            let documentWeight = documentTokens[token, default: 0]
            let inverseFrequency = inverseDocumentFrequency[token, default: 1]
            return partial + min(queryWeight, documentWeight) * inverseFrequency * lexicalSignalWeight(for: token)
        }
        let lexicalDenominator = max(
            1,
            queryTokens.reduce(0.0) { partial, entry in
                partial + entry.value * inverseDocumentFrequency[entry.key, default: 1] * lexicalSignalWeight(for: entry.key)
            }
        )

        return min(1, lexicalNumerator / lexicalDenominator)
    }

    private func promptPhraseScore(
        phrases: [String],
        documentText: String
    ) -> Double {
        guard phrases.isEmpty == false, documentText.isEmpty == false else { return 0 }
        let matchedPhraseCount = phrases.reduce(0) { partial, phrase in
            partial + (documentText.contains(phrase) ? 1 : 0)
        }
        guard matchedPhraseCount > 0 else { return 0 }
        return min(1, Double(matchedPhraseCount) / Double(min(phrases.count, 3)))
    }

    private func lexicalSignalWeight(
        for token: String
    ) -> Double {
        if token.count <= 1 {
            return 0.04
        }
        if lowSignalLexicalTokens.contains(token) {
            return 0.08
        }
        return 1
    }

    private func makeInverseDocumentFrequency(
        for documents: [RetrievalDocument]
    ) -> [String: Double] {
        let documentFrequencies = documents.reduce(into: [String: Int]()) { partial, document in
            for token in document.tokens.keys {
                partial[token, default: 0] += 1
            }
        }

        let documentCount = Double(max(documents.count, 1))
        return documentFrequencies.mapValues { documentFrequency in
            let frequency = Double(documentFrequency)
            return log((documentCount + 1) / (frequency + 0.5)) + 1
        }
    }
}

private struct RetrievalQuery {
    let variant: RetrievalProviderVariant
    let tokens: [String: Double]
    let promptTokens: [String: Double]
    let contextTokens: [String: Double]
    let promptPhrases: [String]
    let intentTags: Set<MatchingIntentTag>
    let softRecencyTags: Set<MatchingIntentTag>
    let softLongTermTags: Set<MatchingIntentTag>
    let suppressedTags: Set<MatchingIntentTag>
    let suppressedSurfaces: Set<AppSection>
    let suppressedCandidateIDs: Set<String>
    let tagSuppressionWeights: [MatchingIntentTag: Double]
    let surfaceSuppressionWeights: [AppSection: Double]
    let candidateSuppressionWeights: [String: Double]
    let activeSurfaceAffinity: Double
    let activeSurfaceMode: String
    let blockedContextSources: [String]

    init(
        context: MatchingFeatureContext,
        variant: RetrievalProviderVariant
    ) {
        self.variant = variant
        var promptTokenWeights: [String: Double] = [:]
        var contextTokenWeights: [String: Double] = [:]
        var blockedContextSources: [String] = []
        let promptText = context.recentPrompt ?? ""
        let promptTerms = tokenize(promptText)
        let lowInformationPrompt = promptTerms.count <= 3

        let promptPrimaryTags = Self.primaryPromptTags(
            for: promptText,
            variant: variant,
            daypart: context.daypart
        )
        let promptSoftTags = Self.softPromptTags(
            for: promptText,
            primaryTags: promptPrimaryTags,
            fallbackTags: context.sessionIntentTags
        )
        let suppressedFromPrompt = Self.promptSuppressions(
            for: promptText,
            variant: variant
        )
        let explicitSuppressions = Self.explicitSuppressions(from: context.behaviorLog)
        let suppressedTags = suppressedFromPrompt.tags.union(explicitSuppressions.tags)
        let suppressedSurfaces = suppressedFromPrompt.surfaces.union(explicitSuppressions.surfaces)
        let suppressedCandidateIDs = explicitSuppressions.candidateIDs
        let filteredPromptTags = promptSoftTags.subtracting(suppressedTags)
        let promptIntentTags = filteredPromptTags.isEmpty ? context.sessionIntentTags.subtracting(suppressedTags) : filteredPromptTags

        Self.add(
            text: promptText,
            weight: 4.8,
            to: &promptTokenWeights
        )

        Self.add(
            tags: promptIntentTags,
            weight: 2.4,
            to: &promptTokenWeights
        )

        let softRecencyTags = Self.filteredRecentBehaviorTags(
            from: context,
            promptTags: promptIntentTags,
            suppressedTags: suppressedTags,
            lowInformationPrompt: lowInformationPrompt
        )
        if softRecencyTags.isEmpty == false {
            Self.add(
                tags: softRecencyTags,
                weight: 0.85,
                to: &contextTokenWeights
            )
        } else if context.recencyTags.isEmpty == false {
            blockedContextSources.append("behavior_raw")
        }

        let softLongTermTags = Self.filteredLongTermTags(
            from: context,
            promptTags: promptIntentTags,
            recentTags: softRecencyTags,
            suppressedTags: suppressedTags,
            lowInformationPrompt: lowInformationPrompt
        )
        if softLongTermTags.isEmpty == false {
            Self.add(
                tags: softLongTermTags,
                weight: 0.45,
                to: &contextTokenWeights
            )
        } else if context.longTermTags.isEmpty == false {
            blockedContextSources.append("long_term_drift")
        }

        let activeSurface = Self.eligibleActiveSurface(
            context: context,
            prompt: promptText,
            promptTags: promptIntentTags,
            suppressedSurfaces: suppressedSurfaces,
            lowInformationPrompt: lowInformationPrompt
        )
        let activeSurfaceAffinity: Double
        let activeSurfaceMode: String
        if let activeSurface {
            Self.add(
                text: activeSurface.rawValue,
                weight: 0.35,
                to: &contextTokenWeights
            )
            Self.add(
                text: activeSurface.title,
                weight: 0.35,
                to: &contextTokenWeights
            )
            activeSurfaceAffinity = lowInformationPrompt ? 0.4 : 0.25
            activeSurfaceMode = lowInformationPrompt ? "low-info" : "continuation"
        } else {
            if context.activeSurface != .chat {
                blockedContextSources.append("active_surface")
            }
            activeSurfaceAffinity = 0
            activeSurfaceMode = "blocked"
        }

        Self.add(
            text: context.daypart.rawValue,
            weight: 0.5,
            to: &contextTokenWeights
        )
        Self.add(
            text: context.motionContext.rawValue,
            weight: 0.5,
            to: &contextTokenWeights
        )
        if context.motionContext == .walking {
            Self.add(text: "nearby", weight: 0.8, to: &contextTokenWeights)
            Self.add(text: "audio", weight: 0.8, to: &contextTokenWeights)
            Self.add(tags: [.localDiscovery, .entertainment], weight: 0.5, to: &contextTokenWeights)
        }

        self.tokens = Self.mergedTokens(promptTokenWeights, contextTokenWeights)
        self.promptTokens = promptTokenWeights
        self.contextTokens = contextTokenWeights
        self.promptPhrases = Self.promptPhrases(for: promptText)
        self.intentTags = promptIntentTags
        self.softRecencyTags = softRecencyTags
        self.softLongTermTags = softLongTermTags
        self.suppressedTags = suppressedTags
        self.suppressedSurfaces = suppressedSurfaces
        self.suppressedCandidateIDs = suppressedCandidateIDs
        self.tagSuppressionWeights = explicitSuppressions.tagWeights
        self.surfaceSuppressionWeights = explicitSuppressions.surfaceWeights
        self.candidateSuppressionWeights = explicitSuppressions.candidateWeights
        self.activeSurfaceAffinity = activeSurfaceAffinity
        self.activeSurfaceMode = activeSurfaceMode
        self.blockedContextSources = orderedUnique(blockedContextSources)
    }

    func suppressionPenalty(
        for candidate: UnifiedMatchingCandidate
    ) -> Double {
        var penalty = 0.0
        let promptExplicitlyRequestsCandidateFamily = intentTags.isDisjoint(with: candidate.tags) == false

        if let candidateWeight = candidateSuppressionWeights[candidate.id], candidateWeight > 0 {
            penalty += promptExplicitlyRequestsCandidateFamily ? candidateWeight * 0.24 : candidateWeight * 0.56
        }

        let suppressedTagOverlap = normalizedOverlap(lhs: suppressedTags, rhs: candidate.tags)
        if suppressedTagOverlap > 0 {
            let weightedTagSuppression = weightedSuppressionOverlap(for: candidate.tags)
            penalty += promptExplicitlyRequestsCandidateFamily
                ? suppressedTagOverlap * weightedTagSuppression * 0.12
                : suppressedTagOverlap * weightedTagSuppression * 0.32
        }

        if let preferredSection = candidate.preferredSection,
           suppressedSurfaces.contains(preferredSection) {
            let surfaceWeight = surfaceSuppressionWeights[preferredSection, default: 0.7]
            penalty += promptExplicitlyRequestsCandidateFamily ? surfaceWeight * 0.08 : surfaceWeight * 0.20
        }

        return min(0.72, penalty)
    }

    private func normalizedOverlap<T: Hashable>(
        lhs: Set<T>,
        rhs: Set<T>
    ) -> Double {
        guard lhs.isEmpty == false, rhs.isEmpty == false else { return 0 }
        let shared = lhs.intersection(rhs).count
        return Double(shared) / Double(max(lhs.count, rhs.count))
    }

    private static func add(
        text: String?,
        weight: Double,
        to tokens: inout [String: Double]
    ) {
        guard let text, text.isEmpty == false else { return }
        for token in tokenize(text) {
            tokens[token, default: 0] += weight
        }
    }

    private static func add(
        tags: Set<MatchingIntentTag>,
        weight: Double,
        to tokens: inout [String: Double]
    ) {
        for tag in tags {
            add(text: tag.rawValue, weight: weight, to: &tokens)
            for synonym in tagSynonyms(for: tag) {
                add(text: synonym, weight: weight * 0.7, to: &tokens)
            }
        }
    }

    private static func mergedTokens(
        _ lhs: [String: Double],
        _ rhs: [String: Double]
    ) -> [String: Double] {
        rhs.reduce(into: lhs) { partial, entry in
            partial[entry.key, default: 0] += entry.value
        }
    }

    private static func promptPhrases(
        for prompt: String
    ) -> [String] {
        let promptTokens = tokenize(prompt)
        guard promptTokens.count >= 2 else { return [] }

        var phrases: [String] = []
        for phraseLength in stride(from: 3, through: 2, by: -1) {
            guard promptTokens.count >= phraseLength else { continue }
            for start in 0...(promptTokens.count - phraseLength) {
                let window = Array(promptTokens[start..<(start + phraseLength)])
                guard window.contains(where: { lowSignalLexicalTokens.contains($0) == false }) else {
                    continue
                }
                phrases.append(window.joined(separator: " "))
            }
        }

        var seen: Set<String> = []
        return phrases.filter { seen.insert($0).inserted }
    }

    private func weightedSuppressionOverlap(
        for candidateTags: Set<MatchingIntentTag>
    ) -> Double {
        let overlappingTags = candidateTags.intersection(suppressedTags)
        guard overlappingTags.isEmpty == false else { return 0 }

        let totalWeight = overlappingTags.reduce(0.0) { partial, tag in
            partial + tagSuppressionWeights[tag, default: 0.7]
        }
        return totalWeight / Double(overlappingTags.count)
    }

    private static func primaryPromptTags(
        for prompt: String,
        variant: RetrievalProviderVariant,
        daypart: MatchingDaypart
    ) -> Set<MatchingIntentTag> {
        let normalized = prompt.lowercased()
        let promptTokens = tokenize(normalized)
        var scores: [MatchingIntentTag: Double] = [:]

        if daypart == .night && promptTokens.count <= 3 {
            scores[.relaxation, default: 0] += 0.8
            scores[.entertainment, default: 0] += 0.6
        }

        accumulate(
            [.localDiscovery: ["dinner", "restaurant", "cafe", "place", "spot", "meet", "area", "neighborhood", "pharmacy"]],
            in: promptTokens,
            into: &scores,
            weight: 1.2
        )
        accumulate(
            [.navigation: ["route", "routes", "navigate", "traffic", "head out", "leave"]],
            in: promptTokens,
            into: &scores,
            weight: 1.1
        )
        accumulate(
            [.navigation: ["parking", "drive"]],
            in: promptTokens,
            into: &scores,
            weight: 0.45
        )
        accumulate(
            [.planning: ["tonight", "plan", "reservation", "decide", "compare", "first", "next step"]],
            in: promptTokens,
            into: &scores,
            weight: 1.0
        )
        accumulate(
            [.focus: ["focus", "deep work", "work session", "concentrate"]],
            in: promptTokens,
            into: &scores,
            weight: 1.2
        )
        accumulate(
            [.relaxation: ["calm", "quiet", "ambient", "wind down"]],
            in: promptTokens,
            into: &scores,
            weight: 0.9
        )
        accumulate(
            [.entertainment: ["music", "playlist", "song", "play"]],
            in: promptTokens,
            into: &scores,
            weight: 1.0
        )
        accumulate(
            [.learning: ["video", "tutorial", "guide", "how to", "show me", "visual"]],
            in: promptTokens,
            into: &scores,
            weight: 1.2
        )
        accumulate(
            [.shopping: ["store", "shop", "buy", "gear", "purchase"]],
            in: promptTokens,
            into: &scores,
            weight: 1.1
        )
        accumulate(
            [.health: ["health", "sleep", "recovery", "workout", "stretch", "yoga"]],
            in: promptTokens,
            into: &scores,
            weight: 1.1
        )
        accumulate(
            [.social: ["friend", "friends", "group", "share", "meet"]],
            in: promptTokens,
            into: &scores,
            weight: 0.9
        )
        accumulate(
            [.search: ["search", "look up", "why", "explain", "facts", "proof", "summary"]],
            in: promptTokens,
            into: &scores,
            weight: 1.0
        )
        accumulate(
            [.ai: ["ai", "runtime", "model", "agent", "routing logic", "orchestration"]],
            in: promptTokens,
            into: &scores,
            weight: 1.2
        )
        accumulate(
            [.commute: ["commute", "drive", "car", "head out", "leave"]],
            in: promptTokens,
            into: &scores,
            weight: 1.0
        )

        if containsAnyPhrase(promptTokens, ["parking"]),
           containsAnyPhrase(promptTokens, ["route"]) == false,
           containsAnyPhrase(promptTokens, ["routes"]) == false,
           containsAnyPhrase(promptTokens, ["navigate"]) == false {
            scores[.navigation, default: 0] -= 0.35
        }
        if containsAnyPhrase(promptTokens, ["dinner", "restaurant", "cafe", "spot"]) {
            scores[.localDiscovery, default: 0] += 0.45
        }
        if containsAnyPhrase(promptTokens, ["why", "explain"]) {
            scores[.search, default: 0] += 0.35
            scores[.learning, default: 0] += 0.15
            scores[.navigation, default: 0] -= 0.2
        }
        if containsAnyPhrase(promptTokens, ["open"]),
           containsAnyPhrase(promptTokens, ["health", "store", "ai"]) {
            scores[.planning, default: 0] += 0.2
        }

        if variant.enablesFocusWorkMusicInference,
           containsAnyPhrase(promptTokens, ["work music", "music for work", "while i work", "deep work music"]) {
            scores[.focus, default: 0] += 1.3
            scores[.entertainment, default: 0] += 0.15
        }

        if variant.enablesNegatedCommuteSuppression,
           containsAnyPhrase(promptTokens, ["not driving", "not a driving session", "not a commute", "not commuting"]) {
            scores[.commute, default: 0] -= 0.9
            scores[.navigation, default: 0] -= 0.45
        }

        let primary = scores.compactMap { entry -> MatchingIntentTag? in
            entry.value >= 1.0 ? entry.key : nil
        }
        return Set(primary)
    }

    private static func softPromptTags(
        for prompt: String,
        primaryTags: Set<MatchingIntentTag>,
        fallbackTags: Set<MatchingIntentTag>
    ) -> Set<MatchingIntentTag> {
        let promptTokens = tokenize(prompt.lowercased())
        if primaryTags.isEmpty == false {
            var tags = primaryTags
            if containsAnyPhrase(promptTokens, ["parking", "reservation", "book"]) {
                tags.insert(.planning)
            }
            return tags
        }

        let inferred = fallbackTags
        if inferred.isEmpty == false {
            return inferred
        }

        return [.planning, .search]
    }

    private static func filteredRecentBehaviorTags(
        from context: MatchingFeatureContext,
        promptTags: Set<MatchingIntentTag>,
        suppressedTags: Set<MatchingIntentTag>,
        lowInformationPrompt: Bool
    ) -> Set<MatchingIntentTag> {
        let candidateTags = Dictionary(grouping: context.behaviorLog.suffix(8).compactMap { event -> Set<MatchingIntentTag>? in
            switch event.stage {
            case .click, .accept, .completion:
                return event.tags
            case .impression, .dismiss, .abandon:
                return nil
            }
        }.flatMap(Array.init), by: { $0 })
        let recencyTags = Set(
            candidateTags.compactMap { entry -> MatchingIntentTag? in
                let alignedWithPrompt = promptTags.contains(entry.key)
                if alignedWithPrompt {
                    return entry.key
                }
                if lowInformationPrompt, entry.value.count >= 2 {
                    return entry.key
                }
                return nil
            }
        )

        return recencyTags.subtracting(suppressedTags)
    }

    private static func filteredLongTermTags(
        from context: MatchingFeatureContext,
        promptTags: Set<MatchingIntentTag>,
        recentTags: Set<MatchingIntentTag>,
        suppressedTags: Set<MatchingIntentTag>,
        lowInformationPrompt: Bool
    ) -> Set<MatchingIntentTag> {
        let allowed = lowInformationPrompt
            ? context.longTermTags.intersection(recentTags.union(promptTags))
            : context.longTermTags.intersection(promptTags.union(recentTags))
        return allowed.subtracting(suppressedTags)
    }

    private static func eligibleActiveSurface(
        context: MatchingFeatureContext,
        prompt: String,
        promptTags: Set<MatchingIntentTag>,
        suppressedSurfaces: Set<AppSection>,
        lowInformationPrompt: Bool
    ) -> AppSection? {
        guard context.activeSurface != .chat else { return nil }
        guard suppressedSurfaces.contains(context.activeSurface) == false else { return nil }

        let normalized = prompt.lowercased()
        let continuationCue = containsAny(
            normalized,
            ["already", "still", "keep", "continue", "return", "back", "while i'm in", "while i am in", "on ai", "on maps", "in music"]
        )
        if continuationCue {
            return context.activeSurface
        }

        if lowInformationPrompt,
           context.crossSurfaceTransitions[context.activeSurface, default: 0] > 0,
           surfaceIntentTags(for: context.activeSurface).isDisjoint(with: promptTags) == false {
            return context.activeSurface
        }

        return nil
    }

    private static func explicitSuppressions(
        from behaviorLog: [MatchingBehaviorEvent]
    ) -> (
        tags: Set<MatchingIntentTag>,
        surfaces: Set<AppSection>,
        candidateIDs: Set<String>,
        tagWeights: [MatchingIntentTag: Double],
        surfaceWeights: [AppSection: Double],
        candidateWeights: [String: Double]
    ) {
        var tags: Set<MatchingIntentTag> = []
        var surfaces: Set<AppSection> = []
        var candidateIDs: Set<String> = []
        var tagWeights: [MatchingIntentTag: Double] = [:]
        var surfaceWeights: [AppSection: Double] = [:]
        var candidateWeights: [String: Double] = [:]

        let recentEvents = Array(behaviorLog.suffix(12))
        let totalEventCount = Double(max(recentEvents.count, 1))

        for (index, event) in recentEvents.enumerated() where event.stage == .dismiss || event.stage == .abandon {
            let recencyWeight = 0.55 + (Double(index + 1) / totalEventCount) * 0.45
            let eventWeight = min(1, suppressionWeight(for: event.feedback) * recencyWeight)

            switch event.feedback {
            case .notInterested:
                if let candidateID = event.candidateID {
                    candidateIDs.insert(candidateID)
                }
            case .lessLikeThis:
                tags.formUnion(event.tags)
                if let surface = event.surface {
                    surfaces.insert(surface)
                }
            case .notNow:
                if let surface = event.surface {
                    surfaces.insert(surface)
                }
            case .alreadyDone:
                if let candidateID = event.candidateID {
                    candidateIDs.insert(candidateID)
                }
            case .none, .dismiss:
                tags.formUnion(event.tags)
            }

            for tag in event.tags {
                tagWeights[tag] = max(tagWeights[tag, default: 0], eventWeight)
            }
            if let surface = event.surface {
                surfaceWeights[surface] = max(surfaceWeights[surface, default: 0], eventWeight)
            }
            if let candidateID = event.candidateID {
                candidateWeights[candidateID] = max(candidateWeights[candidateID, default: 0], eventWeight)
            }
        }

        return (tags, surfaces, candidateIDs, tagWeights, surfaceWeights, candidateWeights)
    }

    private static func promptSuppressions(
        for prompt: String,
        variant: RetrievalProviderVariant
    ) -> (
        tags: Set<MatchingIntentTag>,
        surfaces: Set<AppSection>
    ) {
        let normalized = prompt.lowercased()
        var tags: Set<MatchingIntentTag> = []
        var surfaces: Set<AppSection> = []

        if containsAnyPhrase(normalized, ["music can wait", "playlist can wait", "no playlist", "not another playlist", "don't play music"]) {
            surfaces.insert(.music)
        }
        if containsAnyPhrase(normalized, ["not another tutorial", "not another video", "video can wait"]) {
            surfaces.insert(.video)
        }
        if containsAnyPhrase(normalized, ["don't open ai", "don't need to open ai", "ai can wait"]) {
            surfaces.insert(.ai)
        }
        if containsAnyPhrase(normalized, ["search can wait", "no more search results", "stop circling in search", "not a search answer"]) {
            tags.insert(.search)
        }
        if containsAnyPhrase(normalized, ["don't open health", "not the health surface", "health can wait"]) {
            surfaces.insert(.health)
        }
        if containsAnyPhrase(normalized, ["not the route screen yet", "not another map explanation"]) {
            surfaces.insert(.maps)
        }

        if variant.enablesNegatedCommuteSuppression,
           containsAnyPhrase(normalized, ["not driving", "not a driving session", "not a commute", "not commuting"]) {
            tags.insert(.commute)
        }

        return (tags, surfaces)
    }

    private static func accumulate(
        _ mapping: [MatchingIntentTag: [String]],
        in promptTokens: [String],
        into scores: inout [MatchingIntentTag: Double],
        weight: Double
    ) {
        for (tag, keywords) in mapping where containsAnyPhrase(promptTokens, keywords) {
            scores[tag, default: 0] += weight
        }
    }

    private static func containsAny(
        _ text: String,
        _ needles: [String]
    ) -> Bool {
        needles.contains(where: text.contains)
    }

    private static func containsAnyPhrase(
        _ promptTokens: [String],
        _ phrases: [String]
    ) -> Bool {
        phrases.contains { phrase in
            let phraseTokens = tokenize(phrase)
            return containsPhrase(promptTokens, phraseTokens: phraseTokens)
        }
    }

    private static func containsAnyPhrase(
        _ normalizedText: String,
        _ phrases: [String]
    ) -> Bool {
        phrases.contains(where: normalizedText.contains)
    }

    private static func containsPhrase(
        _ promptTokens: [String],
        phraseTokens: [String]
    ) -> Bool {
        guard phraseTokens.isEmpty == false else { return false }
        guard promptTokens.count >= phraseTokens.count else { return false }

        if phraseTokens.count == 1 {
            return promptTokens.contains(phraseTokens[0])
        }

        for start in 0...(promptTokens.count - phraseTokens.count) {
            let window = Array(promptTokens[start..<(start + phraseTokens.count)])
            if window == phraseTokens {
                return true
            }
        }

        return false
    }

    private static func suppressionWeight(
        for feedback: MatchingFeedbackKind?
    ) -> Double {
        switch feedback {
        case .dismiss:
            return 0.5
        case .notInterested:
            return 1.0
        case .lessLikeThis:
            return 0.9
        case .alreadyDone:
            return 0.78
        case .notNow:
            return 0.62
        case .none:
            return 0.5
        }
    }

    private static func surfaceIntentTags(
        for surface: AppSection
    ) -> Set<MatchingIntentTag> {
        switch surface {
        case .chat:
            return [.planning, .search]
        case .maps:
            return [.navigation, .localDiscovery, .planning, .commute]
        case .music:
            return [.focus, .relaxation, .entertainment, .commute]
        case .video:
            return [.learning]
        case .health:
            return [.health, .ai]
        case .ai:
            return [.ai, .search, .learning]
        case .store:
            return [.shopping, .health]
        }
    }
}

private struct RetrievalDocument {
    let candidate: UnifiedMatchingCandidate
    let tokens: [String: Double]
    let normalizedText: String

    nonisolated init(candidate: UnifiedMatchingCandidate) {
        self.candidate = candidate

        var tokens: [String: Double] = [:]
        Self.add(text: candidate.title, weight: 4.0, to: &tokens)
        Self.add(text: candidate.summary, weight: 2.4, to: &tokens)
        Self.add(text: candidate.activationPrompt, weight: 3.0, to: &tokens)
        Self.add(text: candidate.semanticKey, weight: 1.8, to: &tokens)
        Self.add(text: candidate.domainKey, weight: 1.2, to: &tokens)
        Self.add(text: candidate.objectKind.rawValue, weight: 1.4, to: &tokens)
        Self.add(text: candidate.sourcePool, weight: 1.0, to: &tokens)

        if let preferredSection = candidate.preferredSection {
            Self.add(text: preferredSection.rawValue, weight: 1.2, to: &tokens)
            Self.add(text: preferredSection.title, weight: 1.2, to: &tokens)
        }

        for tag in candidate.tags {
            Self.add(text: tag.rawValue, weight: 1.8, to: &tokens)
            for synonym in tagSynonyms(for: tag) {
                Self.add(text: synonym, weight: 1.1, to: &tokens)
            }
        }

        self.tokens = tokens
        self.normalizedText = [
            candidate.title,
            candidate.summary,
            candidate.activationPrompt,
            candidate.semanticKey,
            candidate.domainKey,
        ]
        .joined(separator: " ")
        .lowercased()
    }

    private static func add(
        text: String,
        weight: Double,
        to tokens: inout [String: Double]
    ) {
        for token in tokenize(text) {
            tokens[token, default: 0] += weight
        }
    }
}

private struct RetrievedCandidate {
    let candidate: UnifiedMatchingCandidate
    let document: RetrievalDocument
    let retrievalScore: Double
}

private func orderedUnique<T: Hashable>(
    _ values: [T]
) -> [T] {
    var seen: Set<T> = []
    var ordered: [T] = []

    for value in values where seen.insert(value).inserted {
        ordered.append(value)
    }

    return ordered
}

private func tokenize(_ text: String) -> [String] {
    let normalized = text
        .lowercased()
        .replacingOccurrences(of: "-", with: " ")
        .replacingOccurrences(of: "_", with: " ")

    let pattern = #"[a-z0-9]+|[\p{Han}]+"#
    guard let expression = try? NSRegularExpression(pattern: pattern) else {
        return []
    }

    let range = NSRange(normalized.startIndex..., in: normalized)
    return expression.matches(in: normalized, range: range).compactMap { match in
        guard let range = Range(match.range, in: normalized) else { return nil }
        return String(normalized[range])
    }
}

private let lowSignalLexicalTokens: Set<String> = [
    "a", "an", "and", "are", "as", "at", "back", "be", "before", "but", "by",
    "can", "choose", "decide", "did", "do", "does", "for", "from", "go", "i",
    "if", "in", "is", "it", "just", "me", "my", "need", "now", "of", "on",
    "open", "or", "out", "right", "should", "show", "so", "still", "that",
    "the", "this", "to", "today", "want", "while", "with"
]

private func tagSynonyms(
    for tag: MatchingIntentTag
) -> [String] {
    switch tag {
    case .navigation:
        return ["map", "maps", "route", "navigate", "parking", "nearby", "地图", "路线", "导航", "停车", "附近"]
    case .localDiscovery:
        return ["place", "restaurant", "cafe", "destination", "地点", "餐厅", "咖啡", "目的地"]
    case .planning:
        return ["plan", "schedule", "tonight", "reservation", "安排", "计划", "今晚", "订位"]
    case .focus:
        return ["focus", "deep work", "study", "专注", "学习", "工作"]
    case .relaxation:
        return ["relax", "calm", "wind down", "ambient", "放松", "安静", "舒缓"]
    case .entertainment:
        return ["music", "playlist", "song", "video", "娱乐", "音乐", "歌单", "视频"]
    case .learning:
        return ["tutorial", "guide", "how to", "explain", "教程", "指南", "解释"]
    case .shopping:
        return ["buy", "shop", "store", "购买", "商店", "下单"]
    case .health:
        return ["health", "sleep", "recovery", "workout", "健康", "睡眠", "恢复", "运动"]
    case .social:
        return ["friend", "group", "share", "朋友", "聚会", "分享"]
    case .search:
        return ["search", "find", "look up", "查找", "搜索", "查"]
    case .ai:
        return ["ai", "model", "agent", "runtime", "模型", "智能体", "运行时"]
    case .commute:
        return ["drive", "car", "commute", "通勤", "开车", "路上"]
    }
}
