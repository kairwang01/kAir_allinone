//
//  MapsHomeView.swift
//  kAir
//
//  Nearby places and route shell for kAir.
//

import SwiftUI

struct MapsHomeView: View {
    let bootstrap: AppBootstrap

    private var activeSession: MapsRouteSession? {
        bootstrap.activeMapsSession
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: AppTheme.Metrics.sectionSpacing) {
                    if let activeSession {
                        RouteHero(session: activeSession)
                        RouteMapCanvas(session: activeSession)
                        RouteMetrics(session: activeSession)

                        VStack(spacing: 12) {
                            ForEach(activeSession.routeOptions) { option in
                                RouteOptionCard(option: option, mode: activeSession.mode)
                            }
                        }

                        PlannerWindowCard(session: activeSession)
                    } else {
                        MapsEmptyState(bootstrap: bootstrap)
                    }
                }
                .padding(.horizontal, AppTheme.Metrics.screenPadding)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(activeSession?.language == .chinese ? "路线" : "Maps")
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
}

private struct RouteHero: View {
    let session: MapsRouteSession

    var body: some View {
        KAirPageHeader(
            title: session.heroTitle,
            summary: session.heroSummary,
            badges: [
                KAirHeaderBadge(
                    title: session.language == .chinese ? "本地规划" : "Local planning",
                    systemImage: "sparkles.rectangle.stack",
                    tint: AppTheme.Palette.warning
                ),
                KAirHeaderBadge(
                    title: session.language == .chinese ? session.mode.chineseTitle : session.mode.title,
                    systemImage: session.mode.systemImage,
                    tint: AppTheme.Palette.sky
                ),
                KAirHeaderBadge(
                    title: session.language == .chinese ? "私有" : "Private",
                    systemImage: "lock",
                    tint: AppTheme.Palette.success
                )
            ]
        )
    }
}

private struct RouteMapCanvas: View {
    let session: MapsRouteSession

    var body: some View {
        KAirSurface(style: .sunken) {
            VStack(alignment: .leading, spacing: 12) {
                Text(session.language == .chinese ? "Map canvas" : "Map canvas")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Text(session.mapSummary)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)

                ZStack {
                    RoundedRectangle(cornerRadius: AppTheme.Metrics.cardRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.78),
                                    AppTheme.Palette.backgroundInset
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 210)

                    RouteLineShape(curveDepth: 28)
                        .stroke(AppTheme.Palette.success, style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                        .frame(height: 170)
                        .padding(.horizontal, 28)

                    RouteLineShape(curveDepth: -18)
                        .stroke(AppTheme.Palette.warning.opacity(0.9), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round, dash: [14, 9]))
                        .frame(height: 170)
                        .padding(.horizontal, 28)

                    VStack {
                        HStack {
                            Circle()
                                .fill(AppTheme.Palette.surfaceStrong)
                                .frame(width: 18, height: 18)
                            Spacer()
                            Circle()
                                .fill(AppTheme.Palette.warning)
                                .frame(width: 18, height: 18)
                        }
                        .padding(.horizontal, 34)
                        .padding(.top, 34)

                        Spacer()
                    }
                    .frame(height: 210)
                }
            }
        }
    }
}

private struct RouteMetrics: View {
    let session: MapsRouteSession

    var body: some View {
        KAirSurface {
            VStack(alignment: .leading, spacing: 14) {
                Text(session.language == .chinese ? "Route snapshot" : "Route snapshot")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                HStack(spacing: 12) {
                    metric(
                        title: session.language == .chinese ? "目的地" : "Destination",
                        value: session.destination
                    )
                    metric(
                        title: session.language == .chinese ? "模式" : "Mode",
                        value: session.language == .chinese ? session.mode.chineseTitle : session.mode.title
                    )
                    metric(
                        title: session.language == .chinese ? "生成时间" : "Generated",
                        value: session.generatedAt.formatted(.dateTime.hour().minute())
                    )
                }
            }
        }
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.Palette.textMuted)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textPrimary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Metrics.compactRadius, style: .continuous)
                .fill(AppTheme.Palette.surface)
        )
    }
}

private struct RouteOptionCard: View {
    let option: MapsRouteOption
    let mode: MapsTravelMode

    private var tint: Color {
        option.recommended ? AppTheme.Palette.success : AppTheme.Palette.warning
    }

    var body: some View {
        KAirSurface(style: .sunken) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(option.title)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text(option.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }

                    Spacer(minLength: 12)

                    KAirStatusPill(
                        title: option.badge,
                        systemImage: mode.systemImage,
                        tint: tint
                    )
                }

                HStack(spacing: 12) {
                    routeMetric("ETA", option.eta)
                    routeMetric("Distance", option.distance)
                    routeMetric("Why", option.emphasis)
                }
            }
        }
    }

    private func routeMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.Palette.textMuted)

            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textPrimary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Metrics.compactRadius, style: .continuous)
                .fill(Color.white.opacity(0.62))
        )
    }
}

private struct PlannerWindowCard: View {
    let session: MapsRouteSession

    var body: some View {
        KAirSurface(style: .sunken) {
            VStack(alignment: .leading, spacing: 10) {
                Text(session.plannerTitle)
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Text(session.plannerSummary)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)

                HStack(spacing: 8) {
                    KAirStatusPill(
                        title: session.language == .chinese ? "占位中" : "Placeholder",
                        systemImage: "cpu",
                        tint: AppTheme.Palette.warning
                    )

                    KAirStatusPill(
                        title: session.language == .chinese ? "后接 LLM" : "LLM next",
                        systemImage: "arrow.triangle.branch",
                        tint: AppTheme.Palette.sky
                    )
                }
            }
        }
    }
}

private struct MapsEmptyState: View {
    let bootstrap: AppBootstrap

    var body: some View {
        VStack(spacing: AppTheme.Metrics.sectionSpacing) {
            KAirSurface(style: .hero) {
                KAirPageHeader(
                    title: "Maps",
                    summary: "Say “我想去超市” in chat, then confirm whether you want to walk or drive. That conversation will stage a route result here.",
                    badges: [
                        KAirHeaderBadge(title: "Chat-first", systemImage: "bubble.left", tint: AppTheme.Palette.warning),
                        KAirHeaderBadge(title: "LLM window", systemImage: "cpu", tint: AppTheme.Palette.sky)
                    ]
                )
            }

            KAirSurface(style: .sunken) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("v0.1 flow")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Text("1. User types a destination in chat.\n2. kAir asks whether to drive or walk.\n3. The app stages two placeholder routes.\n4. Maps becomes the focused surface for the result.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.textSecondary)

                    Button {
                        // Main D: explicit "Back to chat" is a
                        // `.completion` per
                        // `post-return-and-continuation-ux-v1.md` §1.2.
                        bootstrap.recordSurfaceReturn(.completion)
                    } label: {
                        KAirActionCapsule(
                            title: "Back to chat",
                            systemImage: "bubble.left.and.bubble.right"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct RouteLineShape: Shape {
    let curveDepth: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 12, y: rect.maxY - 24))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.midY + curveDepth),
            control1: CGPoint(x: rect.minX + 54, y: rect.maxY - 80),
            control2: CGPoint(x: rect.midX - 56, y: rect.midY + 48)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX - 12, y: rect.minY + 28),
            control1: CGPoint(x: rect.midX + 50, y: rect.midY - 50),
            control2: CGPoint(x: rect.maxX - 74, y: rect.minY + 88)
        )
        return path
    }
}
