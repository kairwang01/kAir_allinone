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
            ShellChrome(
                bootstrap: bootstrap,
                bottomPadding: 108
            ) {
                ChatHomeView(bootstrap: bootstrap)
            }
        }
        .fullScreenCover(item: presentedSurface) { surface in
            NavigationStack {
                ShellChrome(
                    bootstrap: bootstrap,
                    bottomPadding: 20,
                    hidesMiniPlayerWhilePresenting: surface == .music
                ) {
                    PresentedSurfaceView(surface: surface, bootstrap: bootstrap)
                }
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
            case .music:
                MusicHomeView(bootstrap: bootstrap)
            case .video:
                VideoHomeView(bootstrap: bootstrap)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    bootstrap.returnToChat()
                } label: {
                    Label("Back to chat", systemImage: "chevron.left")
                        .foregroundStyle(AppTheme.Palette.textPrimary)
                }
            }
        }
    }
}

private struct ShellChrome<Content: View>: View {
    let bootstrap: AppBootstrap
    let bottomPadding: CGFloat
    let hidesMiniPlayerWhilePresenting: Bool
    let content: Content

    init(
        bootstrap: AppBootstrap,
        bottomPadding: CGFloat,
        hidesMiniPlayerWhilePresenting: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.bootstrap = bootstrap
        self.bottomPadding = bottomPadding
        self.hidesMiniPlayerWhilePresenting = hidesMiniPlayerWhilePresenting
        self.content = content()
    }

    var body: some View {
        content
            .overlay(alignment: .bottom) {
                if let session = bootstrap.activeMusicSession, hidesMiniPlayerWhilePresenting == false {
                    ShellMiniPlayer(
                        session: session,
                        onOpen: {
                            bootstrap.openMusic()
                        },
                        onStop: bootstrap.stopMusic
                    )
                    .padding(.horizontal, AppTheme.Metrics.screenPadding)
                    .padding(.bottom, bottomPadding)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: bootstrap.activeMusicSession)
    }
}

private struct ShellMiniPlayer: View {
    let session: MusicPlaybackSession
    let onOpen: () -> Void
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.Palette.accent.opacity(0.18))
                            .frame(width: 42, height: 42)

                        Image(systemName: session.mood.systemImage)
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.textPrimary)
                            .lineLimit(1)

                        Text(session.subtitle)
                            .font(.caption)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button(action: onStop) {
                Image(systemName: "stop.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.Palette.textPrimary)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(AppTheme.Palette.surface)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardRadius, style: .continuous)
                .fill(Color.white.opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardRadius, style: .continuous)
                .strokeBorder(AppTheme.Palette.line, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 10)
    }
}
