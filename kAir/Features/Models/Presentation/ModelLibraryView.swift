//
//  ModelLibraryView.swift
//  kAir
//
//  Local model library shell.
//

import SwiftUI

struct ModelLibraryView: View {
    @State private var store: ModelLibraryStore

    @MainActor
    init() {
        _store = State(initialValue: ModelLibraryStore())
    }

    @MainActor
    init(store: ModelLibraryStore) {
        _store = State(initialValue: store)
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: AppTheme.Metrics.sectionSpacing) {
                    KAirPageHeader(
                        title: "Model Library",
                        summary: "Catalog rows are state-driven. Downloads, purchase, runtime activation, and uninstall remain disabled until their backend contracts are wired.",
                        badges: [
                            KAirHeaderBadge(title: store.catalogCountText, systemImage: "square.grid.2x2", tint: AppTheme.Palette.accent),
                            KAirHeaderBadge(title: store.localOnlyCountText, systemImage: "cpu", tint: AppTheme.Palette.success),
                            KAirHeaderBadge(title: store.backendStatus.title, systemImage: "wrench.and.screwdriver", tint: AppTheme.Palette.warning)
                        ]
                    )

                    runtimePolicyCard

                    LazyVStack(spacing: 14) {
                        ForEach(store.rows) { row in
                            modelRow(row)
                        }
                    }

                    KAirSurface(style: .sunken) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Truthful backend status")
                                .font(.headline)
                                .foregroundStyle(AppTheme.Palette.textPrimary)

                            Text(store.backendStatus.summary)
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

    private var runtimePolicyCard: some View {
        KAirSurface {
            VStack(alignment: .leading, spacing: 14) {
                Text("Runtime policy")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                    ],
                    spacing: 12
                ) {
                    runtimeMetric(
                        title: "Catalog",
                        value: store.catalogCountText,
                        tint: AppTheme.Palette.accent
                    )
                    runtimeMetric(
                        title: "Execution",
                        value: store.localOnlyCountText,
                        tint: AppTheme.Palette.success
                    )
                    runtimeMetric(
                        title: "Paid",
                        value: store.paidCountText,
                        tint: AppTheme.Palette.warning
                    )
                }
            }
        }
    }

    private func modelRow(_ row: ModelLibraryStore.Row) -> some View {
        let state = row.statePresentation
        let action = row.actionPresentation

        return KAirSurface(style: .sunken) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(row.title)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(row.summary)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    KAirStatusPill(
                        title: state.title,
                        systemImage: state.systemImage,
                        tint: tint(for: state.tone)
                    )
                }

                Text(state.summary)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)

                if let progress = state.progress {
                    ProgressView(value: progress)
                        .tint(tint(for: state.tone))
                        .accessibilityLabel(state.title)
                }

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10),
                    ],
                    spacing: 10
                ) {
                    ForEach(row.specs) { spec in
                        modelSpec(title: spec.title, value: spec.value)
                    }
                }

                HStack(alignment: .top, spacing: 10) {
                    Label(row.trustLine, systemImage: "checkmark.shield")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Label(row.capabilityLine, systemImage: "slider.horizontal.3")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider()
                    .overlay(AppTheme.Palette.line)

                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(action.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text(action.summary)
                            .font(.caption)
                            .foregroundStyle(AppTheme.Palette.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Button(action.title) {}
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.bordered)
                        .disabled(action.isEnabled == false)
                }
            }
        }
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

    private func tint(for tone: ModelLibraryStore.PresentationTone) -> Color {
        switch tone {
        case .neutral:
            return AppTheme.Palette.accent
        case .positive:
            return AppTheme.Palette.success
        case .warning:
            return AppTheme.Palette.warning
        case .danger:
            return AppTheme.Palette.danger
        case .progress:
            return AppTheme.Palette.sky
        case .muted:
            return AppTheme.Palette.textMuted
        }
    }
}

#Preview("Model Library") {
    NavigationStack {
        ModelLibraryView()
    }
}

#Preview("Model Library State Coverage") {
    NavigationStack {
        ModelLibraryView(
            store: ModelLibraryStore(
                catalog: ModelLibraryPreviewFixtures.catalog,
                entitlements: [
                    "premium-entitled": .entitled,
                ],
                backendStates: [
                    "active-router": .active,
                    "installed-planner": .installed,
                    "failed-embedder": .failed(reason: .compileFailed),
                    "unavailable-health": .unavailable(reason: .deviceUnsupported),
                    "premium-entitled": .eligible,
                ]
            )
        )
    }
}

private enum ModelLibraryPreviewFixtures {
    static let catalog: [ModelCatalogEntry] = [
        entry(id: "active-router", name: "Active Router", role: .router),
        entry(id: "installed-planner", name: "Installed Planner", role: .planner),
        entry(id: "failed-embedder", name: "Failed Embedder", role: .embedder),
        entry(id: "unavailable-health", name: "Unavailable Health", role: .health),
        entry(id: "placeholder-download", name: "Download Placeholder", role: .planner, download: true),
        entry(
            id: "premium-locked",
            name: "Paid Locked",
            role: .premium,
            runtime: .remoteGateway,
            productID: "com.kair.preview.locked"
        ),
        entry(
            id: "premium-entitled",
            name: "Gateway Pending",
            role: .premium,
            runtime: .remoteGateway,
            productID: "com.kair.preview.entitled"
        ),
    ]

    private static func entry(
        id: String,
        name: String,
        role: ModelRole,
        runtime: ModelRuntimeFamily = .coreML,
        download: Bool = false,
        productID: String? = nil
    ) -> ModelCatalogEntry {
        ModelCatalogEntry(
            id: id,
            displayName: name,
            role: role,
            runtimeFamily: runtime,
            version: "1.0.0",
            diskSizeBytes: runtime == .remoteGateway ? 0 : 120_000_000,
            estimatedMemoryBytes: runtime == .remoteGateway ? 0 : 240_000_000,
            minimumDeviceClass: "A16",
            minimumOS: "17.0",
            license: "preview",
            statusCopy: "Preview fixture for Model Library state coverage.",
            downloadURL: download ? URL(string: "https://models.kair.local/\(id).mlpackage") : nil,
            checksum: download ? "sha256:\(id)" : nil,
            signature: download ? "ed25519:\(id)" : nil,
            priceProductID: productID,
            privacyClassAllowed: role == .health ? ["health"] : ["general"],
            supportsStructuredOutput: role != .embedder,
            supportsToolCalling: role == .router || role == .planner || role == .premium
        )
    }
}
