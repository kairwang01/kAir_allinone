//
//  HealthWorkspaceView.swift
//  kAir
//
//  Health Execution Surface — a pure caller of `ExecutionSurfaceShell`.
//
//  A1 step 3 / I1 (Health): the final, and first real-data, surface.
//  `HealthWorkspaceView` no longer renders a private `KAirPageHeader`
//  hero, a private "Ask in chat" return capsule, or its own navigation
//  title / per-phase scaffolds. It maps the real `HealthDashboardStore`
//  state machine onto the shared `ExecutionSurfaceShell`
//  (Docs/design/execution-surface-framework-v1.md §1–§11):
//
//    store.phase / supportsHealthData          →  shell state
//    ------------------------------------------------------------------
//    !supportsHealthData                        →  .permissionOrUnavailable
//    .intro (needs Apple Health authorization)  →  .permissionOrUnavailable
//    .authorizing / .loading                    →  .loading
//    .failed                                    →  .error (+ errorMessage)
//    .loaded, dashboard == nil                  →  .empty
//    .loaded, dashboard != nil                  →  .ready
//
//  Region map:
//    (1) back        → shell rail → AppBootstrap.recordSurfaceReturn(.completion)
//                      (removes the old "Ask in chat" → closeSurface() path)
//    (2) title       → "Health" + current health summary
//    (4) status      → store.statusMessage (or errorMessage in .error)
//    (5) trust pills → EMPTY. The frozen 7-case `ActionCardTrustPillKind`
//                      vocabulary (super-app §7) is Maps-centric; none of
//                      the cases truthfully describes "on-device / live
//                      HealthKit / authorization-pending", and stapling a
//                      Maps pill (e.g. `partnerFallback`) onto Health would
//                      misrepresent state. A health-appropriate pill is a
//                      v2 design-system addition; until then region 5
//                      collapses and the on-device / permission signal
//                      lives in region 4, region 6, and the dashboard's
//                      own "On-device" badges in supplementary.
//    (3) primary     → an `ActionCardShell`, per state:
//                        .ready                    → today's summary (DISABLED — read-only)
//                        permission (authorizable) → "Grant access" (enabled CTA → store.requestAccess)
//                        .error                    → "Retry" (enabled CTA → store.refresh)
//                        .loading/.empty/unavailable → none (shell region 6 carries it)
//    supplementary   → .ready: tab Picker + existing dashboard screens;
//                      otherwise the "What stays true" explanation card.
//
//  The `.ready` dashboard screens (OverviewScreen / SignalsScreen /
//  DataLibraryScreen) are each their own `ScrollView`, so the shell is
//  invoked with `scrolls: false` in `.ready`: the regions form a fixed
//  header and the dashboard owns the single scroll (no nested scroll).
//  Those dashboard children also disable their legacy navigation chrome
//  here; their default chrome remains intact for the pre-shell TabView
//  entry. Health is English-only in this build. The shared RootShellView
//  platform toolbar back is left in place (framework §2).
//

import SwiftUI

struct HealthWorkspaceView: View {
    let bootstrap: AppBootstrap
    let store: HealthDashboardStore

    @State private var selectedTab: DashboardTab = .overview

    var body: some View {
        ExecutionSurfaceShell(
            inputs: shellInputs,
            onReturnToChat: {
                // Explicit return to chat is `.completion` per
                // `post-return-and-continuation-ux-v1.md` §1.2.
                bootstrap.recordSurfaceReturn(.completion)
            },
            scrolls: shellState != .ready,
            primary: { primaryCard },
            supplementary: { supplementaryContent }
        )
        .task { store.bootstrap() }
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

    // MARK: - State mapping (store → shell)

    private var shellState: ExecutionSurfaceSystemState {
        if store.supportsHealthData == false { return .permissionOrUnavailable }
        switch store.phase {
        case .intro:                  return .permissionOrUnavailable
        case .authorizing, .loading:  return .loading
        case .failed:                 return .error
        case .loaded:                 return store.dashboard == nil ? .empty : .ready
        }
    }

    // MARK: - Shell inputs (regions 1, 2, 4, 5, 6)

    private var shellInputs: ExecutionSurfaceShellInputs {
        ExecutionSurfaceShellInputs(
            navRail: ExecutionSurfaceNavRail(),   // region 5 empty — see file header
            title: ExecutionSurfaceTitle(
                eyebrow: "Health",
                title: "Health",
                summary: titleSummary
            ),
            status: shellStatus,
            state: shellState,
            language: .english
        )
    }

    private var titleSummary: String {
        if shellState == .ready, let dashboard = store.dashboard {
            return dashboard.hero.summary
        }
        return "Local Apple Health, analyzed on-device inside the kAir shell."
    }

    private var shellStatus: ExecutionSurfaceStatus {
        if shellState == .error {
            return ExecutionSurfaceStatus(errorMessage: store.errorMessage)
        }
        return ExecutionSurfaceStatus(statusMessage: store.statusMessage)
    }

    // MARK: - Region (3) primary card

    @ViewBuilder
    private var primaryCard: some View {
        switch shellState {
        case .ready:
            if let dashboard = store.dashboard {
                ActionCardShell(object: Self.summaryObject(dashboard), state: .disabled)
            }
        case .permissionOrUnavailable:
            // Offer "Grant access" only when HealthKit can actually be
            // authorized; on an unsupported device the shell's locked
            // region-6 copy carries the message and no card renders.
            if store.supportsHealthData {
                ActionCardShell(
                    object: Self.grantAccessObject(),
                    onPrimaryTap: { store.requestAccess() }
                )
            }
        case .error:
            ActionCardShell(
                object: Self.retryObject(store.errorMessage),
                onPrimaryTap: { store.refresh() }
            )
        case .loading, .empty:
            EmptyView()
        }
    }

    private static func summaryObject(_ dashboard: HealthDashboard) -> MatchingObject {
        MatchingObject(
            id: "health-today",
            kind: .answerCard,
            title: dashboard.hero.band.isEmpty ? "Today's read" : "Today · \(dashboard.hero.band)",
            subtitleTokens: [dashboard.hero.recommendation],
            reasonText: "On-device · updated \(dashboard.generatedAt.formatted(.dateTime.hour().minute()))",
            primaryCTA: "Local read",
            secondaryCTA: nil
        )
    }

    private static func grantAccessObject() -> MatchingObject {
        MatchingObject(
            id: "health-grant-access",
            kind: .toolEntry,
            title: "Connect Apple Health",
            subtitleTokens: ["Authorize once — kAir reads and analyzes the data locally on this device."],
            reasonText: nil,
            primaryCTA: "Grant access",
            secondaryCTA: nil
        )
    }

    private static func retryObject(_ errorMessage: String?) -> MatchingObject {
        MatchingObject(
            id: "health-retry",
            kind: .toolEntry,
            title: "Health needs attention",
            subtitleTokens: [errorMessage ?? "Unable to load local Apple Health data."],
            reasonText: nil,
            primaryCTA: "Retry",
            secondaryCTA: nil
        )
    }

    // MARK: - Supplementary (the vertical's "rest of the page", framework §1)

    @ViewBuilder
    private var supplementaryContent: some View {
        if shellState == .ready, let dashboard = store.dashboard {
            VStack(spacing: 12) {
                KAirSurface(style: .sunken, padding: 8) {
                    Picker("Health Section", selection: $selectedTab) {
                        ForEach(DashboardTab.allCases) { tab in
                            Text(tab.title).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                dashboardScreen(dashboard)
            }
        } else {
            whatStaysTrueCard
        }
    }

    @ViewBuilder
    private func dashboardScreen(_ dashboard: HealthDashboard) -> some View {
        switch selectedTab {
        case .overview:
            OverviewScreen(dashboard: dashboard, onRefresh: store.refresh, showsNavigationChrome: false)
        case .signals:
            SignalsScreen(dashboard: dashboard, onRefresh: store.refresh, showsNavigationChrome: false)
        case .data:
            DataLibraryScreen(dashboard: dashboard, onRefresh: store.refresh, showsNavigationChrome: false)
        }
    }

    private var whatStaysTrueCard: some View {
        KAirSurface(style: .sunken) {
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

    private func bullet(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(.subheadline)
            .foregroundStyle(AppTheme.Palette.textSecondary)
    }
}

// MARK: - Previews

#Preview("Health · ready") {
    NavigationStack {
        HealthWorkspaceView(bootstrap: .preview, store: .preview)
    }
}
