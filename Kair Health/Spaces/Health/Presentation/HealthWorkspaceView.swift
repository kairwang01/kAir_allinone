//
//  HealthWorkspaceView.swift
//  Kair Health
//
//  First-class health workspace inside kAir.
//

import SwiftUI

struct HealthWorkspaceView: View {
    let bootstrap: AppBootstrap
    let store: HealthDashboardStore

    @State private var selectedTab: DashboardTab = .overview

    var body: some View {
        content
            .task {
                store.bootstrap()
            }
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

    @ViewBuilder
    private var content: some View {
        switch store.phase {
        case .loaded:
            if let dashboard = store.dashboard {
                loadedContent(dashboard)
            } else {
                stateScaffold(
                    title: "Preparing Health",
                    summary: "kAir is ready, but the local health snapshot is still being prepared.",
                    actionTitle: nil,
                    action: nil
                )
            }
        case .intro:
            stateScaffold(
                title: "Connect Apple Health",
                summary: "Health is a first-class surface in kAir. Authorize once and the app can read local HealthKit data directly on-device.",
                actionTitle: "Grant Access",
                action: store.requestAccess
            )
        case .authorizing:
            stateScaffold(
                title: "Authorizing",
                summary: "Requesting permission to read HealthKit on this device.",
                actionTitle: nil,
                action: nil
            )
        case .loading:
            stateScaffold(
                title: "Analyzing Local Data",
                summary: store.statusMessage,
                actionTitle: nil,
                action: nil
            )
        case .failed:
            stateScaffold(
                title: "Health Needs Attention",
                summary: store.errorMessage ?? "Unable to load local Apple Health data.",
                actionTitle: "Retry",
                action: store.refresh
            )
        }
    }

    private func loadedContent(_ dashboard: HealthDashboard) -> some View {
        currentDashboardView(dashboard)
            .safeAreaInset(edge: .top) {
                VStack(spacing: 12) {
                    KairSurface(style: .hero) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Health")
                                        .font(.title2.weight(.bold))
                                        .foregroundStyle(AppTheme.Palette.textPrimary)

                                    Text(dashboard.hero.summary)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.Palette.textSecondary)
                                }

                                Spacer(minLength: 12)

                                KairStatusPill(
                                    title: "On-device",
                                    systemImage: "lock.shield",
                                    tint: AppTheme.Palette.success
                                )
                            }

                            HStack(spacing: 8) {
                                KairStatusPill(
                                    title: dashboard.hero.band,
                                    systemImage: "waveform.path.ecg",
                                    tint: AppTheme.statusTint(for: dashboard.hero.band)
                                )
                                KairStatusPill(
                                    title: dashboard.generatedAt.formatted(.dateTime.hour().minute()),
                                    systemImage: "clock",
                                    tint: AppTheme.Palette.sky
                                )
                            }

                            Button {
                                bootstrap.closeSurface()
                            } label: {
                                Label("Ask in chat", systemImage: "bubble.left.and.bubble.right")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.Palette.textOnStrong)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(AppTheme.Palette.accentStrong)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    KairSurface(style: .sunken, padding: 8) {
                        Picker("Health Section", selection: $selectedTab) {
                            ForEach(DashboardTab.allCases) { tab in
                                Text(tab.title).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .padding(.horizontal, AppTheme.Metrics.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 4)
                .background(.ultraThinMaterial)
            }
    }

    @ViewBuilder
    private func currentDashboardView(_ dashboard: HealthDashboard) -> some View {
        switch selectedTab {
        case .overview:
            OverviewScreen(dashboard: dashboard, onRefresh: store.refresh)
        case .signals:
            SignalsScreen(dashboard: dashboard, onRefresh: store.refresh)
        case .data:
            DataLibraryScreen(dashboard: dashboard, onRefresh: store.refresh)
        }
    }

    private func stateScaffold(
        title: String,
        summary: String,
        actionTitle: String?,
        action: (() -> Void)?
    ) -> some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: AppTheme.Metrics.sectionSpacing) {
                    KairSurface(style: .hero) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Health")
                                .font(.largeTitle.weight(.bold))
                                .foregroundStyle(AppTheme.Palette.textPrimary)

                            Text("Local Apple Health, held inside the larger kAir shell.")
                                .font(.body)
                                .foregroundStyle(AppTheme.Palette.textSecondary)
                        }
                    }

                    KairSurface {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(title)
                                .font(.headline)
                                .foregroundStyle(AppTheme.Palette.textPrimary)

                            Text(summary)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.Palette.textSecondary)

                            if let actionTitle, let action {
                                Button(actionTitle, action: action)
                                    .buttonStyle(.borderedProminent)
                                    .tint(AppTheme.Palette.accentStrong)
                            } else {
                                ProgressView()
                                    .tint(AppTheme.Palette.accent)
                            }
                        }
                    }

                    KairSurface(style: .sunken) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("What stays true")
                                .font(.headline)
                                .foregroundStyle(AppTheme.Palette.textPrimary)

                            bullet("Apple Health data stays local to this device.")
                            bullet("Chat can summarize this workspace without replacing it.")
                            bullet("AI, Maps, and Store now sit beside Health, not under it.")
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Metrics.screenPadding)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Health")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func bullet(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(.subheadline)
            .foregroundStyle(AppTheme.Palette.textSecondary)
    }
}
