//
//  ContentView.swift
//  kAir
//
//  Created by Kair on 2026/4/16.
//

import SwiftUI

struct ContentView: View {
    let store: HealthDashboardStore
    @State private var selectedTab: DashboardTab = .overview
    @State private var bootstrap: AppBootstrap

    init(store: HealthDashboardStore) {
        self.store = store
        _bootstrap = State(initialValue: AppBootstrap(healthStore: store))
    }

    var body: some View {
        Group {
            if FeatureFlag.allInOneShellEnabled {
                RootShellView(bootstrap: bootstrap)
            } else {
                switch store.phase {
                case .intro:
                    HealthAccessIntroScreen(
                        statusMessage: store.statusMessage,
                        supportsHealthData: store.supportsHealthData,
                        action: store.requestAccess
                    )
                case .authorizing:
                    LoadingStateScreen(
                        title: "Authorizing Apple Health",
                        message: "Requesting access to the local HealthKit store…"
                    )
                case .loading:
                    LoadingStateScreen(
                        title: "Analyzing Local Data",
                        message: store.statusMessage
                    )
                case .loaded:
                    if let dashboard = store.dashboard {
                        liveDashboard(dashboard)
                    } else {
                        LoadingStateScreen(
                            title: "Preparing Dashboard",
                            message: "kAir is waiting for local Apple Health data."
                        )
                    }
                case .failed:
                    FailureStateScreen(
                        message: store.errorMessage ?? "Unable to load Apple Health data.",
                        retry: store.refresh
                    )
                }
            }
        }
        .task {
            store.bootstrap()
        }
    }

    private func liveDashboard(_ dashboard: HealthDashboard) -> some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                OverviewScreen(dashboard: dashboard, onRefresh: store.refresh)
            }
            .tabItem {
                Label(DashboardTab.overview.title, systemImage: DashboardTab.overview.systemImage)
            }
            .tag(DashboardTab.overview)

            NavigationStack {
                SignalsScreen(dashboard: dashboard, onRefresh: store.refresh)
            }
            .tabItem {
                Label(DashboardTab.signals.title, systemImage: DashboardTab.signals.systemImage)
            }
            .tag(DashboardTab.signals)

            NavigationStack {
                DataLibraryScreen(dashboard: dashboard, onRefresh: store.refresh)
            }
            .tabItem {
                Label(DashboardTab.data.title, systemImage: DashboardTab.data.systemImage)
            }
            .tag(DashboardTab.data)
        }
        .tint(HealthPalette.mint)
    }
}

#Preview {
    ContentView(store: .preview)
}
