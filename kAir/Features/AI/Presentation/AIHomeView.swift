//
//  AIHomeView.swift
//  kAir
//
//  AI Execution Surface — a pure caller of `ExecutionSurfaceShell`.
//
//  A1 step 3 / I1 (AI): `AIHomeView` no longer renders a private
//  `KAirPageHeader`, a private "Handoff" return card, or its own
//  navigation title. It maps the static AI-runtime content onto the
//  shared `ExecutionSurfaceShell` (Docs/design/execution-surface-
//  framework-v1.md §1–§11), mirroring the Maps migration:
//    - region (2) title       ← "AI" + runtime summary
//    - region (4) status strip ← "local runtime, cloud off" note
//    - region (3) primary card ← the orchestrator as a disabled
//                                 `ActionCardShell` (framework §4)
//    - supplementary           ← runtime metrics + remaining models +
//                                 surface-routing list
//    - state                   ← always `.ready` (AI is a static info
//                                 surface; it has no empty/error path)
//    - onReturnToChat          ← AppBootstrap.recordSurfaceReturn(.completion)
//
//  Region (5) emits no trust pills: AI has no stub / partner / permission
//  state to advertise from the shared `ActionCardTrustPillKind`
//  vocabulary, so the partner row collapses (framework §5).
//
//  AI is English-only in this build; localizing it is out of scope for
//  this migration. The shell's back-to-chat copy therefore renders in
//  English (`.english`). The shared RootShellView platform toolbar back
//  is left in place until Store / Health also migrate (framework §2).
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
        ExecutionSurfaceShell(
            inputs: shellInputs,
            onReturnToChat: {
                // Explicit return to chat is `.completion` per
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
        ExecutionSurfaceShellInputs(
            navRail: ExecutionSurfaceNavRail(),
            title: ExecutionSurfaceTitle(
                eyebrow: "AI",
                title: "AI",
                summary: "The AI layer is a quiet runtime: route first, explain second, and only surface depth when the task asks for it."
            ),
            status: ExecutionSurfaceStatus(
                statusMessage: "Local runtime — cloud inference off"
            ),
            state: .ready,
            language: .english
        )
    }

    // MARK: - Region (3) primary card

    /// The orchestrator (the primary, active model) rendered as a
    /// first-class `ActionCardShell` in the disabled state (framework §4
    /// requires region 3 to be an Action Card). Disabled reflects that
    /// the local runtime is already grounded and active — there is no
    /// pending action to take here, so the CTA must not be interactive.
    private var primaryCard: some View {
        ActionCardShell(
            object: Self.runtimeObject(models[0]),
            state: .disabled
        )
    }

    private static func runtimeObject(_ model: AIModelCard) -> MatchingObject {
        MatchingObject(
            id: "ai-runtime-\(model.id)",
            kind: .toolEntry,
            title: model.title,
            subtitleTokens: [model.footprint, model.status],
            reasonText: model.summary,
            primaryCTA: "Runtime active",
            secondaryCTA: nil
        )
    }

    // MARK: - Supplementary (the vertical's "rest of the page", framework §1)

    private var supplementaryContent: some View {
        VStack(spacing: AppTheme.Metrics.sectionSpacing) {
            runtimeCard

            VStack(spacing: 12) {
                ForEach(Array(models.dropFirst())) { model in
                    modelCard(model)
                }
            }

            surfaceRoutingCard
        }
    }

    private var runtimeCard: some View {
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
    }

    private func modelCard(_ model: AIModelCard) -> some View {
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

    private var surfaceRoutingCard: some View {
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

// MARK: - Previews

#Preview("AI") {
    NavigationStack {
        AIHomeView(bootstrap: .preview)
    }
}
