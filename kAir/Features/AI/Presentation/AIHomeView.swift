//
//  AIHomeView.swift
//  kAir
//
//  All-in-one AI surface for kAir.
//

import SwiftUI

struct AIHomeView: View {
    let bootstrap: AppBootstrap
    @State private var isReplayExpanded = true

    private let models: [AIModelCard] = [
        AIModelCard(
            id: "orchestrator",
            title: "kAir Orchestrator",
            summary: "Primary conversation and routing layer for the all-in-one shell.",
            footprint: "4.1 GB",
            status: "Active"
        ),
        AIModelCard(
            id: "health-explainer",
            title: "Health Explainer",
            summary: "Grounds health summaries in the local Apple Health snapshot.",
            footprint: "780 MB",
            status: "Grounded"
        ),
        AIModelCard(
            id: "planner",
            title: "Surface Planner",
            summary: "Decides when to open Health, Maps, Music, Video, or Store instead of keeping everything in chat.",
            footprint: "1.3 GB",
            status: "Standby"
        )
    ]

    private let tools: [AIRouteCard] = [
        AIRouteCard(title: "Health", summary: "Explain signals, trends, and watchpoints with evidence.", tint: AppTheme.Palette.success),
        AIRouteCard(title: "Maps", summary: "Stage nearby places and routes without leaving the shell.", tint: AppTheme.Palette.warning),
        AIRouteCard(title: "Music", summary: "Keep audio in a persistent player while chat stays primary.", tint: AppTheme.Palette.accent),
        AIRouteCard(title: "Video", summary: "Open a visual response only when the request needs a focused surface.", tint: AppTheme.Palette.sky),
        AIRouteCard(title: "Store", summary: "Curate recommendations only when the task is purchase-adjacent.", tint: AppTheme.Palette.accent),
        AIRouteCard(title: "Memory", summary: "Keep shared context narrow, local, and reversible.", tint: AppTheme.Palette.sky)
    ]

    private let matchingLayers: [AIMatchingLayerCard] = [
        AIMatchingLayerCard(
            title: "User Context",
            summary: "Unify session memory, daypart, recent behavior, and live thread signals into one local matching context.",
            systemImage: "person.crop.circle.badge.clock",
            tint: AppTheme.Palette.accentStrong
        ),
        AIMatchingLayerCard(
            title: "Recall Towers",
            summary: "Recall places, songs, videos, tools, and search-style objects from multiple candidate pools.",
            systemImage: "square.stack.3d.up",
            tint: AppTheme.Palette.warning
        ),
        AIMatchingLayerCard(
            title: "Business Rankers",
            summary: "Score memorization and generalization separately, then respect each surface's own objective.",
            systemImage: "slider.horizontal.3",
            tint: AppTheme.Palette.sky
        ),
        AIMatchingLayerCard(
            title: "LLM Orchestration",
            summary: "Use the model to explain, route, and compose actions on top of retrieval and ranking, not instead of them.",
            systemImage: "sparkles.rectangle.stack",
            tint: AppTheme.Palette.success
        )
    ]

    var body: some View {
        @Bindable var bootstrap = bootstrap
        let replayComparison = bootstrap.matchingReplayLab.latestComparison
        let batchReport = bootstrap.matchingReplayLab.latestBatchReport

        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: AppTheme.Metrics.sectionSpacing) {
                    KAirPageHeader(
                        title: "AI",
                        summary: "The AI layer is a quiet runtime: route first, explain second, and only surface depth when the task asks for it.",
                        badges: [
                            KAirHeaderBadge(title: "Local-first", systemImage: "lock.shield", tint: AppTheme.Palette.success),
                            KAirHeaderBadge(title: "Health grounded", systemImage: "heart.text.square", tint: AppTheme.Palette.sky)
                        ]
                    )

                    KAirSurface {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Runtime")
                                .font(.headline)
                                .foregroundStyle(AppTheme.Palette.textPrimary)

                            HStack(spacing: 12) {
                                runtimeMetric(title: "Primary", value: "kAir Orchestrator")
                                runtimeMetric(title: "Cloud", value: "Off")
                                runtimeMetric(title: "Fallback", value: "Planner")
                            }
                        }
                    }

                    VStack(spacing: 12) {
                        ForEach(models) { model in
                            KAirSurface(style: .sunken) {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(model.title)
                                                .font(.title3.weight(.semibold))
                                                .foregroundStyle(AppTheme.Palette.textPrimary)

                                            Text(model.summary)
                                                .font(.subheadline)
                                                .foregroundStyle(AppTheme.Palette.textSecondary)
                                        }

                                        Spacer()

                                        KAirStatusPill(
                                            title: model.status,
                                            systemImage: "cpu",
                                            tint: AppTheme.Palette.sky
                                        )
                                    }

                                    Text(model.footprint)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(AppTheme.Palette.textMuted)
                                }
                            }
                        }
                    }

                    KAirSurface(style: .sunken) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Surface Routing")
                                .font(.headline)
                                .foregroundStyle(AppTheme.Palette.textPrimary)

                            VStack(spacing: 10) {
                                ForEach(tools) { tool in
                                    HStack(alignment: .top) {
                                        Circle()
                                            .fill(tool.tint)
                                            .frame(width: 10, height: 10)
                                            .padding(.top, 5)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(tool.title)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(AppTheme.Palette.textPrimary)

                                            Text(tool.summary)
                                                .font(.footnote)
                                                .foregroundStyle(AppTheme.Palette.textSecondary)
                                        }

                                        Spacer()
                                    }
                                }
                            }
                        }
                    }

                    KAirSurface(style: .sunken) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Unified Matching Engine")
                                .font(.headline)
                                .foregroundStyle(AppTheme.Palette.textPrimary)

                            Text("Recommendation is now treated as an app-wide matching layer. It does not only choose content. It also proposes the next surface, service, tool, or answer shape.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.Palette.textSecondary)

                            Text("North star: task progression. Secondary metrics: engagement, latency, diversity, and cross-surface utility.")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(AppTheme.Palette.textMuted)

                            VStack(spacing: 10) {
                                ForEach(matchingLayers) { layer in
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: layer.systemImage)
                                            .font(.headline)
                                            .foregroundStyle(layer.tint)
                                            .frame(width: 20)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(layer.title)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(AppTheme.Palette.textPrimary)

                                            Text(layer.summary)
                                                .font(.footnote)
                                                .foregroundStyle(AppTheme.Palette.textSecondary)
                                        }

                                        Spacer()
                                    }
                                }
                            }
                        }
                    }

                    KAirSurface(style: .sunken) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Replay Comparison")
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.Palette.textPrimary)

                                Spacer()

                                if let replayComparison {
                                    KAirStatusPill(
                                        title: replayComparison.verdict.title,
                                        systemImage: "arrow.left.arrow.right.circle",
                                        tint: replayComparison.verdict == .candidateCloser ? AppTheme.Palette.success : AppTheme.Palette.warning
                                    )
                                } else {
                                    KAirStatusPill(
                                        title: "Waiting",
                                        systemImage: "clock.arrow.circlepath",
                                        tint: AppTheme.Palette.sky
                                    )
                                }
                            }

                            Text("Run the same replay snapshot through baseline and candidate strategies, then compare the result against the real downstream events.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.Palette.textSecondary)

                            if isReplayExpanded {
                                if let replayComparison {
                                    ReplayComparisonPanel(comparison: replayComparison)
                                } else {
                                    ReplayComparisonWaitingView(
                                        scenarioCount: bootstrap.matchingReplayLab.scenarios.count
                                    )
                                }

                                if let batchReport {
                                    ReplayBatchReportPanel(report: batchReport)
                                }
                            }

                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isReplayExpanded.toggle()
                                }
                            } label: {
                                Label(
                                    isReplayExpanded ? "Collapse replay lab" : "Expand replay lab",
                                    systemImage: isReplayExpanded ? "chevron.up" : "chevron.down"
                                )
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(AppTheme.Palette.textPrimary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    KAirSurface(style: .sunken) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Handoff")
                                .font(.headline)
                                .foregroundStyle(AppTheme.Palette.textPrimary)

                            Button {
                                bootstrap.returnToChat()
                            } label: {
                                KAirActionCapsule(
                                    title: "Back to chat",
                                    systemImage: "bubble.left.and.bubble.right"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Metrics.screenPadding)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("AI")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: bootstrap.showProfile) {
                    Circle()
                        .fill(AppTheme.Palette.surfaceStrong)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Text("K")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.Palette.textOnStrong)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func runtimeMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.Palette.textMuted)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Metrics.compactRadius, style: .continuous)
                .fill(AppTheme.Palette.surface)
        )
    }
}

private struct ReplayComparisonPanel: View {
    let comparison: MatchingReplayComparison

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ReplayScenarioSummary(comparison: comparison)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    ReplayRunColumn(run: comparison.baselineRun)
                    ReplayRunColumn(run: comparison.candidateRun)
                }

                VStack(spacing: 12) {
                    ReplayRunColumn(run: comparison.baselineRun)
                    ReplayRunColumn(run: comparison.candidateRun)
                }
            }

            ReplayDiffSummaryView(comparison: comparison)
            ReplayGroundTruthView(comparison: comparison)
        }
    }
}

private struct ReplayComparisonWaitingView: View {
    let scenarioCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No finalized comparison yet.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textPrimary)

            Text("The harness needs one completed recommendation cycle before it can compare baseline and candidate on the same historical frame.")
                .font(.footnote)
                .foregroundStyle(AppTheme.Palette.textSecondary)

            Text("Tracked scenarios: \(scenarioCount)")
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.Palette.textMuted)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Metrics.compactRadius, style: .continuous)
                .fill(AppTheme.Palette.surface)
        )
    }
}

private struct ReplayScenarioSummary: View {
    let comparison: MatchingReplayComparison

    private var promptText: String {
        comparison.scenario.snapshot.recentPrompt ?? "No explicit prompt"
    }

    private var affinityList: [String] {
        comparison.candidateRun.context.objectTypeAffinity
            .filter { $0.value > 0.05 }
            .sorted { lhs, rhs in
                lhs.value > rhs.value
            }
            .prefix(3)
            .map { entry in
                "\(entry.key.title) \(Int(entry.value * 100))%"
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Scenario")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textPrimary)

            Text(promptText)
                .font(.footnote)
                .foregroundStyle(AppTheme.Palette.textPrimary)

            HStack(spacing: 8) {
                ReplayMetricChip(title: comparison.candidateRun.context.daypart.rawValue.capitalized)
                ReplayMetricChip(title: comparison.candidateRun.context.motionContext.rawValue.capitalized)
                ReplayMetricChip(title: comparison.candidateRun.context.locationState.rawValue.capitalized)
                ReplayMetricChip(title: comparison.candidateRun.context.healthAvailability.rawValue.capitalized)
            }

            if comparison.scenario.recentEventsWindow.isEmpty == false {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recent events")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textMuted)

                    Text(
                        comparison.scenario.recentEventsWindow
                            .suffix(4)
                            .map { "\($0.stage.rawValue) \($0.subject.rawValue)" }
                            .joined(separator: " • ")
                    )
                    .font(.caption)
                    .foregroundStyle(AppTheme.Palette.textSecondary)
                }
            }

            if affinityList.isEmpty == false {
                Text("Current affinity: \(affinityList.joined(separator: " • "))")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Palette.textSecondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Metrics.compactRadius, style: .continuous)
                .fill(AppTheme.Palette.surface)
        )
    }
}

private struct ReplayRunColumn: View {
    let run: MatchingReplayRun

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(run.roleTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Spacer()

                Text(run.strategy.scorerVersion)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.Palette.textMuted)
            }

            Text("Providers: \(run.strategy.providerVersions.joined(separator: ", "))")
                .font(.caption)
                .foregroundStyle(AppTheme.Palette.textSecondary)

            Text("Feature schema: \(run.strategy.featureSchemaVersion)")
                .font(.caption)
                .foregroundStyle(AppTheme.Palette.textSecondary)

            VStack(spacing: 8) {
                ForEach(Array(run.recommendations.prefix(5))) { recommendation in
                    ReplayRecommendationRow(recommendation: recommendation)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Metrics.compactRadius, style: .continuous)
                .fill(AppTheme.Palette.surface)
        )
    }
}

private struct ReplayRecommendationRow: View {
    let recommendation: UnifiedMatchRecommendation

    private var subScoreText: String {
        let breakdown = recommendation.breakdown
        return "E \(format(breakdown.globalEligibility)) • D \(format(breakdown.domainUtility)) • N \(format(breakdown.nextStepValue))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text("#\(recommendation.rank)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.textMuted)

                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.candidate.title)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textPrimary)
                        .lineLimit(1)

                    Text(recommendation.candidate.objectKind.title)
                        .font(.caption)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(format(recommendation.breakdown.finalScore))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Text("Conf \(format(recommendation.breakdown.confidence))")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Palette.textMuted)
                }
            }

            Text(subScoreText)
                .font(.caption)
                .foregroundStyle(AppTheme.Palette.textSecondary)

            Text(recommendation.breakdown.debugPayload.policyVersion)
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppTheme.Palette.textMuted)

            if recommendation.breakdown.reasonCodes.isEmpty == false {
                Text(
                    recommendation.breakdown.reasonCodes
                        .prefix(3)
                        .map(\.userFacingText)
                        .joined(separator: " • ")
                )
                .font(.caption)
                .foregroundStyle(AppTheme.Palette.textSecondary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
    }

    private func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}

private struct ReplayDiffSummaryView: View {
    let comparison: MatchingReplayComparison

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Diff")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textPrimary)

            HStack(spacing: 8) {
                ReplayMetricChip(title: "Top-k overlap \(comparison.diffSummary.topKOverlap)")
                ReplayMetricChip(title: "Added \(comparison.diffSummary.addedCandidateIDs.count)")
                ReplayMetricChip(title: "Removed \(comparison.diffSummary.removedCandidateIDs.count)")
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(comparison.diffSummary.rankShifts.prefix(5)) { shift in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(shift.title)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(AppTheme.Palette.textPrimary)

                            Spacer()

                            Text(rankSummary(for: shift))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(AppTheme.Palette.textMuted)
                        }

                        Text(
                            "Score \(format(shift.baselineScore)) → \(format(shift.candidateScore)) • Confidence \(format(shift.baselineConfidence)) → \(format(shift.candidateConfidence))"
                        )
                        .font(.caption)
                        .foregroundStyle(AppTheme.Palette.textSecondary)

                        if shift.reasonDelta.isEmpty == false {
                            Text(shift.reasonDelta.map(\.userFacingText).joined(separator: " • "))
                                .font(.caption)
                                .foregroundStyle(AppTheme.Palette.textSecondary)
                        }
                    }
                }
            }

            if comparison.diffSummary.typeDeltas.isEmpty == false {
                Text(
                    comparison.diffSummary.typeDeltas
                        .map { "\($0.objectKind.title) \($0.baselineCount)→\($0.candidateCount)" }
                        .joined(separator: " • ")
                )
                .font(.caption)
                .foregroundStyle(AppTheme.Palette.textSecondary)
            }

            Text(
                "Alignment: baseline \(comparison.baselineAlignment.level.title), candidate \(comparison.candidateAlignment.level.title)"
            )
            .font(.caption.weight(.medium))
            .foregroundStyle(AppTheme.Palette.textMuted)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Metrics.compactRadius, style: .continuous)
                .fill(AppTheme.Palette.surface)
        )
    }

    private func rankSummary(for shift: MatchingReplayRankShift) -> String {
        let baseline = shift.baselineRank.map(String.init) ?? "–"
        let candidate = shift.candidateRank.map(String.init) ?? "–"
        return "\(baseline) → \(candidate)"
    }

    private func format(_ value: Double?) -> String {
        guard let value else { return "–" }
        return String(format: "%.2f", value)
    }
}

private struct ReplayGroundTruthView: View {
    let comparison: MatchingReplayComparison

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ground Truth")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textPrimary)

            HStack(spacing: 8) {
                ReplayMetricChip(title: comparison.observedOutcome.didAccept ? "Accepted" : "No accept")
                ReplayMetricChip(title: comparison.observedOutcome.didComplete ? "Completed" : "No completion")
                ReplayMetricChip(title: comparison.observedOutcome.hadExplicitDismiss ? "Dismissed" : "No dismiss")
            }

            Text(
                "Downstream value \(String(format: "%.2f", comparison.observedOutcome.totalDownstreamValue)) • Verdict \(comparison.verdict.title)"
            )
            .font(.caption)
            .foregroundStyle(AppTheme.Palette.textSecondary)

            if comparison.observedOutcome.events.isEmpty == false {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(comparison.observedOutcome.events.prefix(5)), id: \.id) { event in
                        Text(eventSummary(for: event))
                            .font(.caption)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Metrics.compactRadius, style: .continuous)
                .fill(AppTheme.Palette.surface)
        )
    }

    private func eventSummary(for event: MatchingBehaviorEvent) -> String {
        var parts = ["\(event.stage.rawValue) \(event.subject.rawValue)"]
        if let objectKind = event.objectKind {
            parts.append(objectKind.title)
        }
        if let candidateID = event.candidateID {
            parts.append(candidateID)
        }
        return parts.joined(separator: " • ")
    }
}

private struct ReplayMetricChip: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.medium))
            .foregroundStyle(AppTheme.Palette.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.82))
            )
    }
}

private struct ReplayBatchReportPanel: View {
    let report: MatchingReplayBatchReport

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Batch Replay")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Spacer()

                KAirStatusPill(
                    title: report.offlineGate.status.title,
                    systemImage: "checklist",
                    tint: gateTint
                )
            }

            Text(
                "Tracked \(report.trackedScenarioCount) scenarios • Evaluated \(report.evaluatedScenarioCount)"
            )
            .font(.caption)
            .foregroundStyle(AppTheme.Palette.textSecondary)

            ReplayBatchAggregateView(report: report)
            ReplayOfflineGateView(gate: report.offlineGate)

            if report.sliceGroups.isEmpty == false {
                ReplaySliceAnalysisView(groups: report.sliceGroups)
            }

            ReplayTopCasesView(
                title: "Top improvements",
                cases: report.topImprovements,
                emptyTitle: "No material improvements yet."
            )

            ReplayTopCasesView(
                title: "Top regressions",
                cases: report.topRegressions,
                emptyTitle: "No material regressions yet."
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Metrics.compactRadius, style: .continuous)
                .fill(AppTheme.Palette.surface)
        )
    }

    private var gateTint: Color {
        switch report.offlineGate.status {
        case .pass:
            return AppTheme.Palette.success
        case .fail:
            return AppTheme.Palette.warning
        case .insufficientData:
            return AppTheme.Palette.sky
        }
    }
}

private struct ReplayBatchAggregateView: View {
    let report: MatchingReplayBatchReport

    private var metrics: [ReplayAggregateMetric] {
        let aggregate = report.aggregateMetrics
        return [
            ReplayAggregateMetric(
                title: "Completed hit@k",
                baseline: aggregate.baselineCompletedPathHitRate,
                candidate: aggregate.candidateCompletedPathHitRate,
                style: .higherIsBetter
            ),
            ReplayAggregateMetric(
                title: "Task-family+",
                baseline: aggregate.baselineTaskFamilyAlignmentRate,
                candidate: aggregate.candidateTaskFamilyAlignmentRate,
                style: .higherIsBetter
            ),
            ReplayAggregateMetric(
                title: "Direct match",
                baseline: aggregate.baselineDirectMatchRate,
                candidate: aggregate.candidateDirectMatchRate,
                style: .higherIsBetter
            ),
            ReplayAggregateMetric(
                title: "Avg progression",
                baseline: aggregate.baselineAverageTaskProgressionAlignment,
                candidate: aggregate.candidateAverageTaskProgressionAlignment,
                style: .higherIsBetter
            ),
            ReplayAggregateMetric(
                title: "Not aligned",
                baseline: aggregate.baselineNotAlignedRate,
                candidate: aggregate.candidateNotAlignedRate,
                style: .lowerIsBetter
            ),
            ReplayAggregateMetric(
                title: "Type concentration",
                baseline: aggregate.baselineObjectTypeConcentration,
                candidate: aggregate.candidateObjectTypeConcentration,
                style: .lowerIsBetter
            ),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Aggregate")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textMuted)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 136), spacing: 10)],
                spacing: 10
            ) {
                ForEach(metrics) { metric in
                    ReplayAggregateMetricCard(metric: metric)
                }
            }

            Text("Avg top-k overlap \(replayPercent(report.aggregateMetrics.averageTopKOverlap)) • Avg rank shift \(replayDecimal(report.aggregateMetrics.averageAbsoluteRankShift))")
                .font(.caption)
                .foregroundStyle(AppTheme.Palette.textSecondary)
        }
    }
}

private struct ReplayOfflineGateView: View {
    let gate: MatchingReplayOfflineGate

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Offline gate")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textMuted)

            Text(gate.summary)
                .font(.footnote)
                .foregroundStyle(AppTheme.Palette.textPrimary)

            ForEach(gate.reasons, id: \.self) { reason in
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Palette.textSecondary)
            }
        }
    }
}

private struct ReplaySliceAnalysisView: View {
    let groups: [MatchingReplaySliceGroup]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Slice analysis")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textMuted)

            VStack(spacing: 10) {
                ForEach(groups.prefix(6)) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(group.dimension.title)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        ForEach(group.rows.prefix(3)) { row in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.title)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(AppTheme.Palette.textPrimary)

                                    Text("\(row.scenarioCount) scenarios")
                                        .font(.caption2)
                                        .foregroundStyle(AppTheme.Palette.textMuted)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Prog \(replayPercent(row.baselineAverageTaskProgressionAlignment)) → \(replayPercent(row.candidateAverageTaskProgressionAlignment))")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.Palette.textSecondary)

                                    Text("Complete \(replayPercent(row.baselineCompletedPathHitRate)) → \(replayPercent(row.candidateCompletedPathHitRate))")
                                        .font(.caption2)
                                        .foregroundStyle(AppTheme.Palette.textMuted)
                                }
                            }
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.72))
                    )
                }
            }
        }
    }
}

private struct ReplayTopCasesView: View {
    let title: String
    let cases: [MatchingReplayCaseDelta]
    let emptyTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textMuted)

            if cases.isEmpty {
                Text(emptyTitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Palette.textSecondary)
            } else {
                ForEach(cases.prefix(4)) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.prompt)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(AppTheme.Palette.textPrimary)
                                .lineLimit(1)

                            Spacer()

                            Text(item.delta >= 0 ? "+\(replayDecimal(item.delta))" : replayDecimal(item.delta))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(item.delta >= 0 ? AppTheme.Palette.success : AppTheme.Palette.warning)
                        }

                        Text(
                            "\(item.primaryObjectKind?.title ?? "Unknown") • \(item.baselineAlignment.title) → \(item.candidateAlignment.title) • overlap \(item.topKOverlap)"
                        )
                        .font(.caption2)
                        .foregroundStyle(AppTheme.Palette.textMuted)
                    }
                }
            }
        }
    }
}

private struct ReplayAggregateMetric: Identifiable {
    enum Style {
        case higherIsBetter
        case lowerIsBetter
    }

    let id = UUID()
    let title: String
    let baseline: Double
    let candidate: Double
    let style: Style

    var delta: Double {
        candidate - baseline
    }

    var tint: Color {
        switch style {
        case .higherIsBetter:
            return delta >= 0 ? AppTheme.Palette.success : AppTheme.Palette.warning
        case .lowerIsBetter:
            return delta <= 0 ? AppTheme.Palette.success : AppTheme.Palette.warning
        }
    }
}

private struct ReplayAggregateMetricCard: View {
    let metric: ReplayAggregateMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(metric.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textPrimary)

            Text("\(replayPercent(metric.baseline)) → \(replayPercent(metric.candidate))")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textPrimary)

            Text(metric.delta >= 0 ? "+\(replayDecimal(metric.delta))" : replayDecimal(metric.delta))
                .font(.caption)
                .foregroundStyle(metric.tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
    }
}

private func replayPercent(_ value: Double) -> String {
    String(format: "%.0f%%", value * 100)
}

private func replayDecimal(_ value: Double) -> String {
    String(format: "%.2f", value)
}

private struct AIModelCard: Identifiable {
    let id: String
    let title: String
    let summary: String
    let footprint: String
    let status: String
}

private struct AIRouteCard: Identifiable {
    let id = UUID()
    let title: String
    let summary: String
    let tint: Color
}

private struct AIMatchingLayerCard: Identifiable {
    let id = UUID()
    let title: String
    let summary: String
    let systemImage: String
    let tint: Color
}
