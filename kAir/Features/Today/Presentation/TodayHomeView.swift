//
//  TodayHomeView.swift
//  kAir
//
//  Health-first home screen for the all-in-one shell.
//

import SwiftUI

struct TodayHomeView: View {
    /// Eyebrow typography per `design-system-v1.md` §3.2.
    ///
    /// Tier 2 migration (audit §8.1 box 3): the four section-label
    /// `Text`s ("TODAY", "WHAT CHANGED", "NEXT STEP", "RECENT
    /// CONTEXT") each used `.font(.caption.weight(.bold))` +
    /// `.tracking(1.1)` — the eyebrow font with an off-spec tracking
    /// (`1.1`). All four now route through the shared `eyebrow`
    /// token (tracking `1.2`). Exposed (internal) for the
    /// token-wiring test.
    static let eyebrowTypography = AppTheme.Typography.eyebrow

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
        KAirSurface(style: .hero) {
            VStack(alignment: .leading, spacing: 16) {
                Text("TODAY")
                    .kAirTypography(Self.eyebrowTypography)
                    .foregroundStyle(AppTheme.Palette.textMuted)

                Text(dashboard.hero.summary)
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Text(dashboard.hero.recommendation)
                    .font(.body)
                    .foregroundStyle(AppTheme.Palette.textSecondary)

                HStack(spacing: 10) {
                    KAirStatusPill(
                        title: dashboard.hero.band,
                        systemImage: "heart.fill",
                        tint: AppTheme.statusTint(for: dashboard.hero.band)
                    )
                    KAirStatusPill(
                        title: "Confidence \(Int((dashboard.hero.confidence * 100).rounded()))%",
                        systemImage: "checkmark.shield.fill",
                        tint: AppTheme.Palette.accent
                    )
                    KAirStatusPill(
                        title: "On-device",
                        systemImage: "lock.shield.fill",
                        tint: AppTheme.Palette.success
                    )
                }
            }
        }
    }

    private var changesCard: some View {
        KAirSurface {
            VStack(alignment: .leading, spacing: 14) {
                Text("WHAT CHANGED")
                    .kAirTypography(Self.eyebrowTypography)
                    .foregroundStyle(AppTheme.Palette.textMuted)

                ForEach(dashboard.insights) { insight in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(insight.title)
                                .font(.headline)
                                .foregroundStyle(AppTheme.Palette.textPrimary)
                            Spacer()
                            KAirStatusPill(
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
        KAirSurface {
            VStack(alignment: .leading, spacing: 14) {
                Text("NEXT STEP")
                    .kAirTypography(Self.eyebrowTypography)
                    .foregroundStyle(AppTheme.Palette.textMuted)

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
        KAirSurface {
            VStack(alignment: .leading, spacing: 14) {
                Text("RECENT CONTEXT")
                    .kAirTypography(Self.eyebrowTypography)
                    .foregroundStyle(AppTheme.Palette.textMuted)

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
