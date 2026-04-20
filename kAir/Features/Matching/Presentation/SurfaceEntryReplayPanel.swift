//
//  SurfaceEntryReplayPanel.swift
//  kAir
//
//  Developer-facing panel that renders the surface-entry contract feed:
//  three entry events (requested / started / returned) grouped by
//  requestId, with filters, invariant badges, and a per-chain detail
//  sheet that shows the full request and return payload.
//

import SwiftUI

struct SurfaceEntryReplayPanel: View {
    let lab: MatchingReplayLab

    @State private var surfaceFilter: AppSection? = nil
    @State private var intentFilter: SurfaceEntryIntent? = nil
    @State private var recommendationFilter: RecommendationFilter = .any
    @State private var returnedOnly = false
    @State private var outcomeFilter: SurfaceEntryTerminalOutcome? = nil
    @State private var selectedChain: SurfaceEntryChain?

    enum RecommendationFilter: String, CaseIterable, Identifiable {
        case any, recommendationOnly, directOpenOnly
        var id: String { rawValue }
        var label: String {
            switch self {
            case .any: return "All"
            case .recommendationOnly: return "Rec only"
            case .directOpenOnly: return "Direct only"
            }
        }
    }

    private var chains: [SurfaceEntryChain] {
        let filter = SurfaceEntryChainFilter(
            surfaceType: surfaceFilter,
            entryIntent: intentFilter,
            hasRecommendation: {
                switch recommendationFilter {
                case .any: return nil
                case .recommendationOnly: return true
                case .directOpenOnly: return false
                }
            }(),
            returnedOnly: returnedOnly,
            terminalOutcome: outcomeFilter
        )
        return filter.apply(to: lab.surfaceEntryChains)
    }

    private var summary: SurfaceEntryInvariantSummary {
        lab.surfaceEntryInvariantSummary
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    InvariantSummaryCard(summary: summary)
                    FilterBar(
                        surfaceFilter: $surfaceFilter,
                        intentFilter: $intentFilter,
                        recommendationFilter: $recommendationFilter,
                        returnedOnly: $returnedOnly,
                        outcomeFilter: $outcomeFilter
                    )
                    ChainCountHeader(
                        shown: chains.count,
                        total: lab.surfaceEntryChains.count
                    )
                    if chains.isEmpty {
                        EmptyChainsCard(total: lab.surfaceEntryChains.count)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(chains) { chain in
                                Button {
                                    selectedChain = chain
                                } label: {
                                    ChainRowCard(chain: chain)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Surface Entry Replay")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedChain) { chain in
            NavigationStack {
                ChainDetailView(chain: chain)
            }
        }
    }
}

// MARK: - Summary

private struct InvariantSummaryCard: View {
    let summary: SurfaceEntryInvariantSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Invariants")
                    .font(.headline)
                Spacer()
                Text("\(summary.totalChains) chain\(summary.totalChains == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            InvariantRow(
                label: "requested → started paired",
                passed: summary.requestedStartedPairedPassed,
                detail: "\(summary.requestedStartedPairedCount)/\(summary.totalChains)"
            )
            InvariantRow(
                label: "returned links by requestId",
                passed: summary.returnedLinkedPassed,
                detail: "\(summary.returnedLinkedCount)/\(summary.totalChains)"
            )
            InvariantRow(
                label: "return payload consistent",
                passed: summary.payloadConsistentPassed,
                detail: "\(summary.payloadConsistentCount)/\(summary.totalChains)"
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.black.opacity(0.06))
        )
    }
}

private struct InvariantRow: View {
    let label: String
    let passed: Bool
    let detail: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: passed ? "checkmark.circle.fill" : "xmark.octagon.fill")
                .foregroundStyle(passed ? Color.green : Color.red)
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(detail)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Filters

private struct FilterBar: View {
    @Binding var surfaceFilter: AppSection?
    @Binding var intentFilter: SurfaceEntryIntent?
    @Binding var recommendationFilter: SurfaceEntryReplayPanel.RecommendationFilter
    @Binding var returnedOnly: Bool
    @Binding var outcomeFilter: SurfaceEntryTerminalOutcome?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Filters")
                .font(.subheadline.weight(.semibold))
            FilterScrollRow(title: "Surface") {
                FilterChip(title: "All", isOn: surfaceFilter == nil) {
                    surfaceFilter = nil
                }
                ForEach(AppSection.allCases, id: \.self) { section in
                    FilterChip(
                        title: section.rawValue,
                        isOn: surfaceFilter == section
                    ) {
                        surfaceFilter = surfaceFilter == section ? nil : section
                    }
                }
            }
            FilterScrollRow(title: "Intent") {
                FilterChip(title: "All", isOn: intentFilter == nil) {
                    intentFilter = nil
                }
                ForEach(SurfaceEntryIntent.allCases, id: \.self) { intent in
                    FilterChip(
                        title: intent.rawValue,
                        isOn: intentFilter == intent
                    ) {
                        intentFilter = intentFilter == intent ? nil : intent
                    }
                }
            }
            FilterScrollRow(title: "Recommendation") {
                ForEach(SurfaceEntryReplayPanel.RecommendationFilter.allCases) { option in
                    FilterChip(
                        title: option.label,
                        isOn: recommendationFilter == option
                    ) {
                        recommendationFilter = option
                    }
                }
            }
            FilterScrollRow(title: "Outcome") {
                FilterChip(title: "All", isOn: outcomeFilter == nil) {
                    outcomeFilter = nil
                }
                ForEach([
                    SurfaceEntryTerminalOutcome.completion,
                    .abandon,
                    .dismiss,
                    .returnedOnly,
                    .inFlight
                ], id: \.self) { outcome in
                    FilterChip(
                        title: outcome.rawValue,
                        isOn: outcomeFilter == outcome
                    ) {
                        outcomeFilter = outcomeFilter == outcome ? nil : outcome
                    }
                }
            }
            Toggle("Returned only", isOn: $returnedOnly)
                .font(.subheadline)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.black.opacity(0.06))
        )
    }
}

private struct FilterScrollRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    content
                }
            }
        }
    }
}

private struct FilterChip: View {
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(isOn ? Color.accentColor.opacity(0.2) : Color.black.opacity(0.05))
                )
                .overlay(
                    Capsule().strokeBorder(
                        isOn ? Color.accentColor : Color.black.opacity(0.08),
                        lineWidth: 1
                    )
                )
                .foregroundStyle(isOn ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Row

private struct ChainCountHeader: View {
    let shown: Int
    let total: Int

    var body: some View {
        HStack {
            Text("Chains")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text("\(shown) of \(total)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

private struct EmptyChainsCard: View {
    let total: Int

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(total == 0 ? "No entry chains yet" : "No chains match the current filters")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
        )
    }
}

private struct ChainRowCard: View {
    let chain: SurfaceEntryChain

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SurfaceBadge(section: chain.surfaceType)
                IntentBadge(intent: chain.entryIntent)
                Spacer()
                InvariantBadge(passed: chain.invariants.allPassed)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("req")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(shortId(chain.requestId))
                    .font(.footnote.monospaced())
                    .foregroundStyle(.primary)
                if chain.hasRecommendation {
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text("rec \(shortId(chain.sourceRecommendationId ?? ""))")
                        .font(.footnote.monospaced())
                        .foregroundStyle(Color.accentColor)
                } else {
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text("direct")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            HStack(spacing: 12) {
                PhaseDot(label: "requested", timestamp: chain.requestedAt)
                PhaseDot(label: "started", timestamp: chain.startedAt)
                PhaseDot(label: "returned", timestamp: chain.returnedAt)
                Spacer()
                OutcomePill(outcome: chain.terminalOutcome)
            }
            if let objectType = chain.objectType {
                Text("\(objectType) • \(chain.objectId ?? "—")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.black.opacity(0.05))
        )
    }

    private func shortId(_ id: String) -> String {
        guard !id.isEmpty else { return "—" }
        if id.count <= 10 { return id }
        return String(id.prefix(10))
    }
}

private struct SurfaceBadge: View {
    let section: AppSection
    var body: some View {
        Text(section.rawValue)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.blue.opacity(0.12)))
            .foregroundStyle(Color.blue)
    }
}

private struct IntentBadge: View {
    let intent: SurfaceEntryIntent
    var body: some View {
        Text(intent.rawValue)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.purple.opacity(0.1)))
            .foregroundStyle(Color.purple)
    }
}

private struct InvariantBadge: View {
    let passed: Bool
    var body: some View {
        Image(systemName: passed ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
            .foregroundStyle(passed ? Color.green : Color.orange)
    }
}

private struct PhaseDot: View {
    let label: String
    let timestamp: Date?
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(timestamp == nil ? Color.black.opacity(0.12) : Color.green)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption2)
                .foregroundStyle(timestamp == nil ? .secondary : .primary)
        }
    }
}

private struct OutcomePill: View {
    let outcome: SurfaceEntryTerminalOutcome
    var body: some View {
        Text(outcome.rawValue)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.15)))
            .foregroundStyle(color)
    }

    private var color: Color {
        switch outcome {
        case .completion: return .green
        case .abandon: return .orange
        case .dismiss: return .red
        case .returnedOnly: return .blue
        case .inFlight: return .gray
        }
    }
}

// MARK: - Detail

private struct ChainDetailView: View {
    let chain: SurfaceEntryChain

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DetailSection(title: "Identity") {
                    KeyValueRow(key: "requestId", value: chain.requestId)
                    if let rec = chain.sourceRecommendationId {
                        KeyValueRow(key: "sourceRecommendationId", value: rec)
                    } else {
                        KeyValueRow(key: "sourceRecommendationId", value: "— (direct open)")
                    }
                    KeyValueRow(key: "surface_type", value: chain.surfaceType.rawValue)
                    KeyValueRow(key: "entry_intent", value: chain.entryIntent.rawValue)
                    if let objectType = chain.objectType {
                        KeyValueRow(key: "object_type", value: objectType)
                    }
                    KeyValueRow(key: "object_id", value: chain.objectId ?? "—")
                }
                if chain.normalizedArgs.isEmpty == false {
                    DetailSection(title: "normalized_args") {
                        ForEach(
                            chain.normalizedArgs.sorted(by: { $0.key < $1.key }),
                            id: \.key
                        ) { key, value in
                            KeyValueRow(key: key, value: value)
                        }
                    }
                }
                DetailSection(title: "Timeline") {
                    TimelineRow(
                        label: "requested",
                        timestamp: chain.requestedAt,
                        color: .green
                    )
                    TimelineRow(
                        label: "started",
                        timestamp: chain.startedAt,
                        color: .green
                    )
                    TimelineRow(
                        label: "returned",
                        timestamp: chain.returnedAt,
                        color: .blue
                    )
                    KeyValueRow(key: "outcome", value: chain.terminalOutcome.rawValue)
                }
                DetailSection(title: "Invariants") {
                    InvariantRow(
                        label: "requested → started paired",
                        passed: chain.invariants.requestedStartedPaired,
                        detail: ""
                    )
                    InvariantRow(
                        label: "returned links by requestId",
                        passed: chain.invariants.returnedLinksByRequestId,
                        detail: ""
                    )
                    InvariantRow(
                        label: "return payload consistent",
                        passed: chain.invariants.payloadLinksMatchChain,
                        detail: ""
                    )
                }
                if let payload = chain.returnPayload {
                    DetailSection(title: "Return payload") {
                        KeyValueRow(key: "executedCandidateId", value: payload.executedCandidateId)
                        KeyValueRow(key: "outcome", value: payload.outcome.rawValue)
                        KeyValueRow(key: "duration", value: String(format: "%.2fs", payload.duration))
                        KeyValueRow(
                            key: "sourceRequestId",
                            value: payload.sourceRequestId ?? "—"
                        )
                        KeyValueRow(
                            key: "sourceRecommendationId",
                            value: payload.sourceRecommendationId ?? "—"
                        )
                        KeyValueRow(
                            key: "downstreamValue",
                            value: String(format: "%.2f", payload.returnContextDelta.downstreamValue)
                        )
                        KeyValueRow(
                            key: "completionScore",
                            value: String(format: "%.2f", payload.returnContextDelta.completionScore)
                        )
                        if let summary = payload.returnContextDelta.summary {
                            KeyValueRow(key: "summary", value: summary)
                        }
                    }
                }
                if chain.request != nil, let handoff = chain.request?.handoffContext {
                    DetailSection(title: "Handoff context") {
                        KeyValueRow(
                            key: "sourceMessagePreview",
                            value: handoff.sourceMessagePreview ?? "—"
                        )
                        KeyValueRow(
                            key: "returnThreadId",
                            value: handoff.returnThreadId ?? "—"
                        )
                        KeyValueRow(
                            key: "priorContextStateSummary",
                            value: handoff.priorContextStateSummary ?? "—"
                        )
                    }
                }
                DetailSection(title: "Raw events (\(chain.events.count))") {
                    ForEach(chain.events) { event in
                        HStack {
                            Text(event.type.rawValue)
                                .font(.caption.monospaced())
                            Spacer()
                            Text(formatTimestamp(event.timestamp))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Chain")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
}

private struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            VStack(alignment: .leading, spacing: 6) {
                content
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.05))
            )
        }
    }
}

private struct KeyValueRow: View {
    let key: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(key)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(minWidth: 110, alignment: .leading)
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(.primary)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }
}

private struct TimelineRow: View {
    let label: String
    let timestamp: Date?
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(timestamp == nil ? Color.black.opacity(0.12) : color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.caption.weight(.medium))
            Spacer()
            Text(timestamp.map { formatTimestamp($0) } ?? "—")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
}
