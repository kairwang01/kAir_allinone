//
//  ProfileAndSettingsView.swift
//  kAir
//
//  Profile and control surface for the rebuilt kAir shell.
//

import SwiftUI

struct ProfileAndSettingsView: View {
    let bootstrap: AppBootstrap

    @Environment(\.dismiss) private var dismiss

    @State private var localOnlyMode = true
    @State private var healthGrounding = true
    @State private var nearbyLayerEnabled = true
    @State private var storeSuggestionsEnabled = true

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: AppTheme.Metrics.sectionSpacing) {
                    KAirPageHeader(
                        title: "kAir",
                        summary: "Your all-in-one control surface.",
                        badges: [
                            KAirHeaderBadge(
                                title: bootstrap.currentSection.title,
                                systemImage: bootstrap.currentSection.systemImage,
                                tint: AppTheme.tint(for: bootstrap.currentSection)
                            ),
                            KAirHeaderBadge(
                                title: "Local-first",
                                systemImage: "lock.shield",
                                tint: AppTheme.Palette.success
                            )
                        ]
                    )

                    KAirSurface {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Identity")
                                .font(.headline)
                                .foregroundStyle(AppTheme.Palette.textPrimary)

                            deviceRow(title: "Profile", value: "kAir User")
                            deviceRow(title: "Current surface", value: bootstrap.currentSection.title)
                            deviceRow(title: "Health source", value: "Apple Health")
                        }
                    }

                    KAirSurface(style: .sunken) {
                        VStack(spacing: 14) {
                            ToggleRow(
                                title: "Local-only routing",
                                summary: "Keep health context and model selection device-first by default.",
                                isOn: $localOnlyMode
                            )
                            ToggleRow(
                                title: "Ground chat in health",
                                summary: "Let the chat thread use your local Apple Health snapshot for summaries and explanations.",
                                isOn: $healthGrounding
                            )
                            ToggleRow(
                                title: "Enable maps surface",
                                summary: "Allow nearby care, routes, and place recommendations to appear as part of the shell.",
                                isOn: $nearbyLayerEnabled
                            )
                            ToggleRow(
                                title: "Enable store curation",
                                summary: "Show product and bundle suggestions when they fit the current task.",
                                isOn: $storeSuggestionsEnabled
                            )
                        }
                    }

                    KAirSurface(style: .sunken) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Device")
                                .font(.headline)
                                .foregroundStyle(AppTheme.Palette.textPrimary)

                            deviceRow(title: "Health access", value: bootstrap.healthStore.supportsHealthData ? "Available" : "Unavailable")
                            deviceRow(title: "Privacy posture", value: "On-device")
                            deviceRow(title: "Commerce", value: "Catalog only")
                            deviceRow(title: "Nearby", value: nearbyLayerEnabled ? "Ready" : "Off")
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Metrics.screenPadding)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    bootstrap.isProfilePresented = false
                    dismiss()
                }
                .foregroundStyle(AppTheme.Palette.textPrimary)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func deviceRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppTheme.Palette.textSecondary)

            Spacer()

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textPrimary)
        }
    }
}

private struct ToggleRow: View {
    let title: String
    let summary: String
    @Binding var isOn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $isOn) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.textPrimary)
            }
            .tint(AppTheme.Palette.accentStrong)

            Text(summary)
                .font(.footnote)
                .foregroundStyle(AppTheme.Palette.textSecondary)
        }
    }
}
