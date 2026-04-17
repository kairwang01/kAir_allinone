//
//  SpacesHomeView.swift
//  Kair Health
//
//  Root Spaces hub with Health as a subordinate entry.
//

import SwiftUI

struct SpacesHomeView: View {
    let healthStore: HealthDashboardStore

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: AppTheme.Metrics.sectionSpacing) {
                    KairSurface(style: .hero) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Spaces")
                                .font(.largeTitle.weight(.bold))
                                .foregroundStyle(AppTheme.Palette.textPrimary)

                            Text("Health lives here as a focused workspace instead of owning the app home.")
                                .font(.body)
                                .foregroundStyle(AppTheme.Palette.textSecondary)

                            KairStatusPill(
                                title: "Chat-first shell",
                                systemImage: "square.stack.3d.up.fill",
                                tint: AppTheme.Palette.accent
                            )
                        }
                    }

                    NavigationLink {
                        HealthWorkspaceView(
                            bootstrap: AppBootstrap(healthStore: healthStore),
                            store: healthStore
                        )
                    } label: {
                        KairSurface {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Health")
                                            .font(.title3.weight(.semibold))
                                            .foregroundStyle(AppTheme.Palette.textPrimary)

                                        Text("Trend analysis, signals, and data coverage stay local to this device.")
                                            .font(.subheadline)
                                            .foregroundStyle(AppTheme.Palette.textSecondary)
                                    }

                                    Spacer()

                                    KairStatusPill(
                                        title: healthStatusTitle,
                                        systemImage: healthStatusImage,
                                        tint: healthStatusTint
                                    )
                                }

                                HStack(spacing: 12) {
                                    spaceMetric(
                                        title: "Privacy",
                                        value: "On-device",
                                        tint: AppTheme.Palette.success
                                    )
                                    spaceMetric(
                                        title: "Entry",
                                        value: "Workspace",
                                        tint: AppTheme.Palette.accent
                                    )
                                    spaceMetric(
                                        title: "Data",
                                        value: "HealthKit",
                                        tint: AppTheme.Palette.warning
                                    )
                                }

                                Label("Open Health workspace", systemImage: "arrow.right.circle.fill")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(AppTheme.Palette.accent)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    KairSurface(style: .sunken) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Coming Next")
                                .font(.headline)
                                .foregroundStyle(AppTheme.Palette.textPrimary)

                            VStack(spacing: 10) {
                                placeholderRow(
                                    title: "Recovery",
                                    summary: "Daily body readiness and local habit prompts."
                                )
                                placeholderRow(
                                    title: "Journal",
                                    summary: "Personal notes and memory capture around conversations."
                                )
                                placeholderRow(
                                    title: "Coach",
                                    summary: "Task-oriented workflows layered on top of chat."
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Metrics.screenPadding)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Spaces")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var healthStatusTitle: String {
        switch healthStore.phase {
        case .intro:
            return "Setup"
        case .authorizing, .loading:
            return "Loading"
        case .loaded:
            return "Ready"
        case .failed:
            return "Retry"
        }
    }

    private var healthStatusImage: String {
        switch healthStore.phase {
        case .intro:
            return "bolt.heart"
        case .authorizing, .loading:
            return "clock.arrow.circlepath"
        case .loaded:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    private var healthStatusTint: Color {
        switch healthStore.phase {
        case .intro:
            return AppTheme.Palette.warning
        case .authorizing, .loading:
            return AppTheme.Palette.accent
        case .loaded:
            return AppTheme.Palette.success
        case .failed:
            return AppTheme.Palette.danger
        }
    }

    private func spaceMetric(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.Palette.textMuted)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(
                cornerRadius: AppTheme.Metrics.compactRadius,
                style: .continuous
            )
            .fill(AppTheme.Palette.surface)
        )
    }

    private func placeholderRow(title: String, summary: String) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Text(summary)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Palette.textSecondary)
            }

            Spacer()

            Text("Soon")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textMuted)
        }
    }
}
