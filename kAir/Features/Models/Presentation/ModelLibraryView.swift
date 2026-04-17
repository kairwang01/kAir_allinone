//
//  ModelLibraryView.swift
//  kAir
//
//  Local model library shell.
//

import SwiftUI

struct ModelLibraryView: View {
    private let installedModels: [ModelCard] = [
        ModelCard(
            id: "mix-8b",
            title: "Local Mix 8B",
            summary: "General chat and routing model for the app shell.",
            footprint: "4.1 GB",
            contextWindow: "64K",
            status: "Active"
        ),
        ModelCard(
            id: "health-ranker",
            title: "Health Ranker",
            summary: "Reserved for Health space scoring and trend summarization.",
            footprint: "780 MB",
            contextWindow: "8K",
            status: "Space-only"
        ),
        ModelCard(
            id: "tool-planner",
            title: "Tool Planner",
            summary: "Draft routing and action plans before tool execution.",
            footprint: "1.3 GB",
            contextWindow: "16K",
            status: "Standby"
        )
    ]

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: AppTheme.Metrics.sectionSpacing) {
                    KAirPageHeader(
                        title: "Model Library",
                        summary: "The app shell is ready for local-first routing, but model install, download, and execution details remain intentionally stubbed.",
                        badges: [
                            KAirHeaderBadge(title: "On-device", systemImage: "cpu", tint: AppTheme.Palette.accent),
                            KAirHeaderBadge(title: "No cloud fallback", systemImage: "lock.shield", tint: AppTheme.Palette.warning)
                        ]
                    )

                    KAirSurface {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Runtime Policy")
                                .font(.headline)
                                .foregroundStyle(AppTheme.Palette.textPrimary)

                            HStack(spacing: 12) {
                                runtimeMetric(
                                    title: "Primary Route",
                                    value: "Local-first",
                                    tint: AppTheme.Palette.accent
                                )
                                runtimeMetric(
                                    title: "Fallback",
                                    value: "Disabled",
                                    tint: AppTheme.Palette.warning
                                )
                                runtimeMetric(
                                    title: "Privacy",
                                    value: "On-device",
                                    tint: AppTheme.Palette.success
                                )
                            }
                        }
                    }

                    VStack(spacing: 14) {
                        ForEach(installedModels) { model in
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
                                            systemImage: "cpu.fill",
                                            tint: AppTheme.Palette.accent
                                        )
                                    }

                                    HStack(spacing: 12) {
                                        modelSpec(title: "Footprint", value: model.footprint)
                                        modelSpec(title: "Context", value: model.contextWindow)
                                    }
                                }
                            }
                        }
                    }

                    KAirSurface(style: .sunken) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Still Placeholder")
                                .font(.headline)
                                .foregroundStyle(AppTheme.Palette.textPrimary)

                            Text("Remote catalogs, downloads, benchmarking, and uninstall flows are not implemented in this pass.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.Palette.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Metrics.screenPadding)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Models")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func runtimeMetric(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.Palette.textMuted)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(
                cornerRadius: AppTheme.Metrics.compactRadius,
                style: .continuous
            )
            .fill(AppTheme.Palette.surface)
        )
    }

    private func modelSpec(title: String, value: String) -> some View {
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
            RoundedRectangle(
                cornerRadius: AppTheme.Metrics.compactRadius,
                style: .continuous
            )
            .fill(AppTheme.Palette.surface)
        )
    }
}

private struct ModelCard: Identifiable {
    let id: String
    let title: String
    let summary: String
    let footprint: String
    let contextWindow: String
    let status: String
}
