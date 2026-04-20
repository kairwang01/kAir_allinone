//
//  VideoHomeView.swift
//  kAir
//
//  Chat-invoked immersive video surface.
//

import SwiftUI

struct VideoHomeView: View {
    let bootstrap: AppBootstrap

    private var session: VideoPlaybackSession? {
        bootstrap.activeVideoSession
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: AppTheme.Metrics.sectionSpacing) {
                    KAirPageHeader(
                        title: "Video",
                        summary: "Video should open only when the request is better served visually. It remains a focused surface, then returns to the same thread.",
                        badges: [
                            KAirHeaderBadge(title: "Focused surface", systemImage: "play.rectangle", tint: AppTheme.Palette.warning),
                            KAirHeaderBadge(title: "Return to chat", systemImage: "arrow.uturn.backward.circle", tint: AppTheme.Palette.sky)
                        ]
                    )

                    if let session {
                        KAirSurface(style: .hero) {
                            VStack(alignment: .leading, spacing: 18) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: AppTheme.Metrics.cardRadius, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    AppTheme.Palette.surfaceStrong,
                                                    AppTheme.Palette.surface
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(height: 220)

                                    VStack(spacing: 12) {
                                        Image(systemName: session.category.systemImage)
                                            .font(.system(size: 36, weight: .semibold))
                                            .foregroundStyle(AppTheme.Palette.textOnStrong)

                                        Text(session.title)
                                            .font(.title2.weight(.semibold))
                                            .foregroundStyle(AppTheme.Palette.textOnStrong)

                                        Text(session.durationLabel)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(AppTheme.Palette.textOnStrong.opacity(0.82))
                                    }
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text(session.summary)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.Palette.textSecondary)

                                    HStack(spacing: 12) {
                                        videoMetric(title: "Category", value: session.category.title)
                                        videoMetric(title: "Duration", value: session.durationLabel)
                                        videoMetric(title: "Thread", value: "Kept")
                                    }
                                }
                            }
                        }

                        KAirSurface(style: .sunken) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Video contract")
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.Palette.textPrimary)

                                videoRule("Open only when the answer needs visuals, motion, or a longer walkthrough.")
                                videoRule("Return writes back a compact summary instead of spamming the thread.")
                                videoRule("The conversation remains the default home before and after playback.")
                            }
                        }
                    } else {
                        KAirSurface(style: .sunken) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("No active video")
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.Palette.textPrimary)

                                Text("Ask for a tutorial, demo, or workout video from chat to open this surface.")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.Palette.textSecondary)
                            }
                        }
                    }

                    Button {
                        bootstrap.returnToChat()
                    } label: {
                        KAirActionCapsule(
                            title: "Back to chat",
                            systemImage: "bubble.left.and.bubble.right"
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, AppTheme.Metrics.screenPadding)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Video")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func videoMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.Palette.textMuted)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Metrics.compactRadius, style: .continuous)
                .fill(AppTheme.Palette.surface)
        )
    }

    private func videoRule(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(.subheadline)
            .foregroundStyle(AppTheme.Palette.textSecondary)
    }
}
