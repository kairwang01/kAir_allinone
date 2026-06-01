//
//  RootShellView.swift
//  kAir
//
//  Chat-first shell with integrated capability surfaces.
//

import SwiftUI

struct RootShellView: View {
    let bootstrap: AppBootstrap

    init(bootstrap: AppBootstrap) {
        self.bootstrap = bootstrap
    }

    init(store: HealthDashboardStore, dashboard _: HealthDashboard) {
        self.bootstrap = AppBootstrap(healthStore: store)
    }

    var body: some View {
        @Bindable var bootstrap = bootstrap
        let presentedSurface = Binding(
            get: { bootstrap.presentedSurface },
            set: { newValue in
                if let newValue {
                    bootstrap.openSurface(newValue)
                } else {
                    // Main D: the system gesture (swipe-down on the
                    // fullScreenCover) sets this to nil. Per
                    // `post-return-and-continuation-ux-v1.md` §1.2,
                    // a silent / swipe-style exit is an `.abandon`
                    // outcome. Explicit back buttons route through
                    // `recordSurfaceReturn(.completion)` directly from
                    // each ExecutionSurfaceShell rail.
                    bootstrap.recordSurfaceReturn(.abandon)
                }
            }
        )

        NavigationStack {
            ChatHomeView(bootstrap: bootstrap)
        }
        .onAppear {
            SurfaceRouter.applyPendingAppIntentRoute(to: bootstrap)
        }
        .onReceive(NotificationCenter.default.publisher(for: SurfaceRouter.routeRequestedNotification)) { _ in
            SurfaceRouter.applyPendingAppIntentRoute(to: bootstrap)
        }
        .fullScreenCover(item: presentedSurface) { surface in
            NavigationStack {
                PresentedSurfaceView(surface: surface, bootstrap: bootstrap)
            }
        }
        .sheet(isPresented: $bootstrap.isProfilePresented) {
            NavigationStack {
                ProfileAndSettingsView(bootstrap: bootstrap)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
}

#Preview {
    RootShellPreview()
}

private struct RootShellPreview: View {
    @State private var bootstrap = AppBootstrap.preview

    var body: some View {
        RootShellView(bootstrap: bootstrap)
    }
}

private struct PresentedSurfaceView: View {
    let surface: AppSection
    let bootstrap: AppBootstrap

    var body: some View {
        Group {
            switch surface {
            case .chat:
                ChatHomeView(bootstrap: bootstrap)
            case .health:
                HealthWorkspaceView(bootstrap: bootstrap, store: bootstrap.healthStore)
            case .ai:
                AIHomeView(bootstrap: bootstrap)
            case .maps:
                MapsHomeView(bootstrap: bootstrap)
            case .search:
                SearchHomeView {
                    bootstrap.recordSurfaceReturn(.completion)
                }
            case .store:
                StoreHomeView(bootstrap: bootstrap)
            }
        }
    }
}
