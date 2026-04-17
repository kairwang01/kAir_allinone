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
                    bootstrap.closeSurface()
                }
            }
        )

        NavigationStack {
            ChatHomeView(bootstrap: bootstrap)
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
            case .store:
                StoreHomeView(bootstrap: bootstrap)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    bootstrap.closeSurface()
                } label: {
                    Label("Chat", systemImage: "chevron.left")
                        .foregroundStyle(AppTheme.Palette.textPrimary)
                }
            }
        }
    }
}
