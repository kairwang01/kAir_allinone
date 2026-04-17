//
//  TodayHomeView.swift
//  Kair Health
//
//  Health-first home screen for the all-in-one shell.
//

import SwiftUI

struct TodayHomeView: View {
    let dashboard: HealthDashboard
    let onRefresh: () -> Void
    let onOpenCoach: () -> Void
    let onOpenHealth: () -> Void

    private var leadingInsight: InsightCard? {
        dashboard.insights.max(by: { $0.score < $1.score })
    }

    private var connectedDomains: Int {
        dashboard.dataSources.filter { $0.sampleCount > 0 }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Metrics.sectionSpacing) {
                heroCard
                changesCard
                nextStepCard
                contextCard
            }
            .padding(.horizontal, AppTheme.Metrics.screenPadding)
            .padding(.vertical, 20)
        }
        .background(AppBackground())
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Refresh health snapshot")
            }
        }
    }

    private var heroCard: some View {
        KairSurface(style: .hero) {
            VStack(alignment: .leading, spacing: 16) {
                Text("TODAY")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Palette.textMuted)
                    .tracking(1.1)

                Text(dashboard.hero.summary)
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Text(dashboard.hero.recommendation)
                    .font(.body)
                    .foregroundStyle(AppTheme.Palette.textSecondary)

                HStack(spacing: 10) {
                    KairStatusPill(
                        title: dashboard.hero.band,
                        systemImage: "heart.fill",
                        tint: AppTheme.statusTint(for: dashboard.hero.band)
                    )
                    KairStatusPill(
                        title: "Confidence \(Int((dashboard.hero.confidence * 100).rounded()))%",
                        systemImage: "checkmark.shield.fill",
                        tint: AppTheme.Palette.accent
                    )
                    KairStatusPill(
                        title: "On-device",
                        systemImage: "lock.shield.fill",
                        tint: AppTheme.Palette.success
                    )
                }
            }
        }
    }

    private var changesCard: some View {
        KairSurface {
            VStack(alignment: .leading, spacing: 14) {
                Text("WHAT CHANGED")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Palette.textMuted)
                    .tracking(1.1)

                ForEach(dashboard.insights) { insight in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(insight.title)
                                .font(.headline)
                                .foregroundStyle(AppTheme.Palette.textPrimary)
                            Spacer()
                            KairStatusPill(
                                title: insight.band,
                                systemImage: "waveform.path.ecg",
                                tint: AppTheme.statusTint(for: insight.band)
                            )
                        }

                        Text(insight.summary)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(AppTheme.tint(for: insight.accentToken).opacity(0.10))
                    )
                }
            }
        }
    }

    private var nextStepCard: some View {
        KairSurface {
            VStack(alignment: .leading, spacing: 14) {
                Text("NEXT STEP")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Palette.textMuted)
                    .tracking(1.1)

                Text("The strongest current focus is \(leadingInsight?.title.lowercased() ?? "recent health trends"). Ask Coach for a plain-language explanation or open Health to inspect the underlying context.")
                    .font(.body)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                HStack(spacing: 12) {
                    Button("Ask Coach") {
                        onOpenCoach()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.Palette.accent)

                    Button("Open Health") {
                        onOpenHealth()
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.Palette.danger)
                }
            }
        }
    }

    private var contextCard: some View {
        KairSurface {
            VStack(alignment: .leading, spacing: 14) {
                Text("RECENT CONTEXT")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Palette.textMuted)
                    .tracking(1.1)

                LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
                    metricTile(
                        title: "Sleep",
                        value: "\(dashboard.sleepSummary.averageHours.formattedOneDecimal) h",
                        tint: AppTheme.Palette.success
                    )
                    metricTile(
                        title: "Domains",
                        value: "\(connectedDomains)",
                        tint: AppTheme.Palette.accent
                    )
                    metricTile(
                        title: "Workouts",
                        value: "\(dashboard.workouts.count)",
                        tint: AppTheme.Palette.warning
                    )
                    metricTile(
                        title: "ECG",
                        value: "\(dashboard.ecgReadings.count)",
                        tint: AppTheme.Palette.accentStrong
                    )
                }

                Text("Latest refresh: \(dashboard.generatedAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Palette.textSecondary)
            }
        }
    }

    private func metricTile(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.Palette.textSecondary)

            Text(value)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(tint.opacity(0.10))
        )
    }
}

#Preview {
    NavigationStack {
        TodayHomeView(
            dashboard: .preview,
            onRefresh: {},
            onOpenCoach: {},
            onOpenHealth: {}
        )
    }
}
