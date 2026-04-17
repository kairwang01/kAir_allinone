//
//  AIHomeView.swift
//  kAir
//
//  All-in-one AI surface for kAir.
//

import SwiftUI

struct AIHomeView: View {
    let bootstrap: AppBootstrap

    private let models: [AIModelCard] = [
        AIModelCard(
            id: "orchestrator",
            title: "kAir Orchestrator",
            summary: "Primary conversation and routing layer for the all-in-one shell.",
            footprint: "4.1 GB",
            status: "Active"
        ),
        AIModelCard(
            id: "health-explainer",
            title: "Health Explainer",
            summary: "Grounds health summaries in the local Apple Health snapshot.",
            footprint: "780 MB",
            status: "Grounded"
        ),
        AIModelCard(
            id: "planner",
            title: "Surface Planner",
            summary: "Decides when to open Health, Maps, or Store instead of keeping everything in chat.",
            footprint: "1.3 GB",
            status: "Standby"
        )
    ]

    private let tools: [AIRouteCard] = [
        AIRouteCard(title: "Health", summary: "Explain signals, trends, and watchpoints with evidence.", tint: AppTheme.Palette.success),
        AIRouteCard(title: "Maps", summary: "Stage nearby places and routes without leaving the shell.", tint: AppTheme.Palette.warning),
        AIRouteCard(title: "Store", summary: "Curate recommendations only when the task is purchase-adjacent.", tint: AppTheme.Palette.accent),
        AIRouteCard(title: "Memory", summary: "Keep shared context narrow, local, and reversible.", tint: AppTheme.Palette.sky)
    ]

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: AppTheme.Metrics.sectionSpacing) {
                    KAirPageHeader(
                        title: "AI",
                        summary: "The AI layer is a quiet runtime: route first, explain second, and only surface depth when the task asks for it.",
                        badges: [
                            KAirHeaderBadge(title: "Local-first", systemImage: "lock.shield", tint: AppTheme.Palette.success),
                            KAirHeaderBadge(title: "Health grounded", systemImage: "heart.text.square", tint: AppTheme.Palette.sky)
                        ]
                    )

                    KAirSurface {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Runtime")
                                .font(.headline)
                                .foregroundStyle(AppTheme.Palette.textPrimary)

                            HStack(spacing: 12) {
                                runtimeMetric(title: "Primary", value: "kAir Orchestrator")
                                runtimeMetric(title: "Cloud", value: "Off")
                                runtimeMetric(title: "Fallback", value: "Planner")
                            }
                        }
                    }

                    VStack(spacing: 12) {
                        ForEach(models) { model in
                            KAirSurface(style: .sunken) {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(model.title)
                                                .font(.title3.weight(.semibold))
                                                .foregroundStyle(AppTheme.Palette.textPrimary)

                                            Text(model.summary)
                                                .font(.subheadline)
                                                .foregroundStyle(AppTheme.Palette.textSecondary)
                                        }

                                        Spacer()

                                        KAirStatusPill(
                                            title: model.status,
                                            systemImage: "cpu",
                                            tint: AppTheme.Palette.sky
                                        )
                                    }

                                    Text(model.footprint)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(AppTheme.Palette.textMuted)
                                }
                            }
                        }
                    }

                    KAirSurface(style: .sunken) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Surface Routing")
                                .font(.headline)
                                .foregroundStyle(AppTheme.Palette.textPrimary)

                            VStack(spacing: 10) {
                                ForEach(tools) { tool in
                                    HStack(alignment: .top) {
                                        Circle()
                                            .fill(tool.tint)
                                            .frame(width: 10, height: 10)
                                            .padding(.top, 5)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(tool.title)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(AppTheme.Palette.textPrimary)

                                            Text(tool.summary)
                                                .font(.footnote)
                                                .foregroundStyle(AppTheme.Palette.textSecondary)
                                        }

                                        Spacer()
                                    }
                                }
                            }
                        }
                    }

                    KAirSurface(style: .sunken) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Handoff")
                                .font(.headline)
                                .foregroundStyle(AppTheme.Palette.textPrimary)

                            Button {
                                bootstrap.closeSurface()
                            } label: {
                                KAirActionCapsule(
                                    title: "Return to chat",
                                    systemImage: "bubble.left.and.bubble.right"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Metrics.screenPadding)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("AI")
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

    private func runtimeMetric(title: String, value: String) -> some View {
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
}

private struct AIModelCard: Identifiable {
    let id: String
    let title: String
    let summary: String
    let footprint: String
    let status: String
}

private struct AIRouteCard: Identifiable {
    let id = UUID()
    let title: String
    let summary: String
    let tint: Color
}
