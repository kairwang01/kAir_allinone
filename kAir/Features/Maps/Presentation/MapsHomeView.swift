//
//  MapsHomeView.swift
//  kAir
//
//  Maps Execution Surface — a pure caller of `ExecutionSurfaceShell`.
//
//  A1 step 3 / I1 (Maps): `MapsHomeView` no longer renders a private
//  hero / back path / status strip. It maps its `MapsRouteSession` onto
//  the shared `ExecutionSurfaceShell` (Docs/design/execution-surface-
//  framework-v1.md §1–§11), supplying:
//    - region (2) title       ← session hero copy
//    - region (5) trust pills  ← stub/estimate/partner-pending state
//    - region (4) status strip ← "placeholder result" note
//    - region (3) primary card ← recommended route as an ActionCardShell
//    - supplementary           ← map canvas / metrics / route list / planner
//    - state                   ← session present → .ready, else → .empty
//    - onReturnToChat          ← AppBootstrap.recordSurfaceReturn(.completion)
//
//  The shell owns the authoritative `Back to chat` rail across every
//  state — the active-session view previously had no in-surface return
//  control (only RootShellView's platform toolbar). That platform back
//  is left in place for now; removing the shared RootShellView toolbar
//  is deferred until AI / Store / Health also migrate (framework §2
//  permits the rail to coexist with platform chrome).
//

import SwiftUI

struct MapsHomeView: View {
    let bootstrap: AppBootstrap

    private var activeSession: MapsRouteSession? {
        bootstrap.activeMapsSession
    }

    private var language: ExecutionSurfaceLanguage {
        activeSession?.language == .chinese ? .chinese : .english
    }

    var body: some View {
        ExecutionSurfaceShell(
            inputs: shellInputs,
            onReturnToChat: {
                // Explicit "Back to chat" is a `.completion` per
                // `post-return-and-continuation-ux-v1.md` §1.2.
                bootstrap.recordSurfaceReturn(.completion)
            },
            primary: { primaryCard },
            supplementary: { supplementaryContent }
        )
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

    // MARK: - Shell inputs (regions 1, 2, 4, 5, 6)

    private var shellInputs: ExecutionSurfaceShellInputs {
        if let session = activeSession {
            return ExecutionSurfaceShellInputs(
                navRail: ExecutionSurfaceNavRail(trustPills: Self.stubTrustPills),
                title: ExecutionSurfaceTitle(
                    eyebrow: language == .chinese ? "路线" : "Route",
                    title: session.heroTitle,
                    summary: session.heroSummary
                ),
                status: ExecutionSurfaceStatus(
                    statusMessage: language == .chinese
                        ? "本地占位结果 · 未接真实地图引擎"
                        : "Local placeholder result — real map engine not wired"
                ),
                state: .ready,
                language: language
            )
        } else {
            return ExecutionSurfaceShellInputs(
                title: ExecutionSurfaceTitle(
                    eyebrow: language == .chinese ? "地图" : "Maps",
                    title: "Maps",
                    summary: language == .chinese
                        ? "在聊天里说出目的地，并确认步行或驾车，路线结果会落在这里。"
                        : "Name a destination in chat and confirm walking or driving — the route result lands here."
                ),
                state: .empty,
                language: language
            )
        }
    }

    /// Maps v0.1 is entirely stub data, so the partner/source row
    /// truthfully advertises estimated/place-stub/partner-pending state
    /// (maps-ui-spec-v1 §1.5 / §2.4). All cases are drawn from the shared
    /// `ActionCardTrustPillKind` vocabulary — no Maps-private pill.
    private static let stubTrustPills: [ActionCardTrustPillKind] = [
        .placeResolutionStub,
        .etaConfidenceEstimate,
        .partnerFallback
    ]

    // MARK: - Region (3) primary card

    /// The recommended route as a first-class `ActionCardShell`
    /// (framework §4: region 3 must be an Action Card). It renders as
    /// disabled because v0.1 has already selected and displayed the
    /// placeholder route; real turn-by-turn navigation is future work,
    /// so the CTA must not imply an executable action. In the `.empty`
    /// state this collapses and the shell's locked empty region carries
    /// the message.
    @ViewBuilder
    private var primaryCard: some View {
        if let session = activeSession, let option = recommendedOption(in: session) {
            ActionCardShell(
                object: Self.routeObject(session: session, option: option),
                state: .disabled
            )
        } else {
            EmptyView()
        }
    }

    private func recommendedOption(in session: MapsRouteSession) -> MapsRouteOption? {
        session.routeOptions.first(where: { $0.recommended }) ?? session.routeOptions.first
    }

    private static func routeObject(session: MapsRouteSession, option: MapsRouteOption) -> MatchingObject {
        let isZH = session.language == .chinese
        return MatchingObject(
            id: "maps-route-\(option.id)",
            kind: .route,
            title: option.title,
            subtitleTokens: [
                option.eta,
                option.distance,
                isZH ? session.mode.chineseTitle : session.mode.title
            ],
            reasonText: option.emphasis,
            primaryCTA: isZH ? "路线已显示" : "Route shown",
            secondaryCTA: nil
        )
    }

    // MARK: - Supplementary (the vertical's "rest of the page", framework §1)

    @ViewBuilder
    private var supplementaryContent: some View {
        if let session = activeSession {
            VStack(spacing: AppTheme.Metrics.sectionSpacing) {
                RouteMapCanvas(session: session)
                RouteMetrics(session: session)

                VStack(spacing: 12) {
                    ForEach(session.routeOptions) { option in
                        RouteOptionCard(option: option, mode: session.mode, language: session.language)
                    }
                }

                PlannerWindowCard(session: session)
            }
        } else {
            EmptyView()
        }
    }
}

private struct RouteMapCanvas: View {
    let session: MapsRouteSession

    var body: some View {
        KAirSurface(style: .sunken) {
            VStack(alignment: .leading, spacing: 12) {
                Text(session.language == .chinese ? "地图画布" : "Map canvas")
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
                Text(session.language == .chinese ? "路线概览" : "Route snapshot")
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
    let language: MapsConversationLanguage

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
                    routeMetric(language == .chinese ? "预计" : "ETA", option.eta)
                    routeMetric(language == .chinese ? "距离" : "Distance", option.distance)
                    routeMetric(language == .chinese ? "原因" : "Why", option.emphasis)
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

// MARK: - Previews

#Preview("Maps · ready") {
    MapsPreviewHost(session: .mock(destination: "Blue Bottle", mode: .driving, language: .english))
}

#Preview("Maps · empty") {
    MapsPreviewHost(session: nil)
}

private struct MapsPreviewHost: View {
    let session: MapsRouteSession?
    @State private var bootstrap = AppBootstrap.preview

    var body: some View {
        NavigationStack {
            MapsHomeView(bootstrap: bootstrap)
        }
        .onAppear {
            if let session {
                bootstrap.openMaps(with: session)
            }
        }
    }
}
