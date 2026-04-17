//
//  MapsHomeView.swift
//  Kair Health
//
//  Nearby places and route shell for kAir.
//

import SwiftUI

struct MapsHomeView: View {
    let bootstrap: AppBootstrap

    private let places: [NearbyPlace] = [
        NearbyPlace(title: "Open Pharmacy", subtitle: "14 min walk · pickup and supplements", status: "Open now", tint: AppTheme.Palette.warning),
        NearbyPlace(title: "Recovery Clinic", subtitle: "11 min drive · massage and physio", status: "Book", tint: AppTheme.Palette.success),
        NearbyPlace(title: "Quiet Gym", subtitle: "8 min drive · low traffic right now", status: "Low crowd", tint: AppTheme.Palette.sky),
        NearbyPlace(title: "Late Grocery", subtitle: "12 min walk · hydration and snacks", status: "Open late", tint: AppTheme.Palette.accent)
    ]

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: AppTheme.Metrics.sectionSpacing) {
                    KairSurface(style: .hero) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Maps")
                                .font(.largeTitle.weight(.bold))
                                .foregroundStyle(AppTheme.Palette.textPrimary)

                            Text("Nearby care, movement, and errands should live inside the same shell as the conversation and health data.")
                                .font(.body)
                                .foregroundStyle(AppTheme.Palette.textSecondary)

                            HStack(spacing: 8) {
                                KairStatusPill(
                                    title: "Task-first",
                                    systemImage: "scope",
                                    tint: AppTheme.Palette.warning
                                )
                                KairStatusPill(
                                    title: "Private",
                                    systemImage: "lock",
                                    tint: AppTheme.Palette.success
                                )
                            }
                        }
                    }

                    KairSurface {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Nearby right now")
                                .font(.headline)
                                .foregroundStyle(AppTheme.Palette.textPrimary)

                            HStack(spacing: 12) {
                                metric(title: "Clinics", value: "2")
                                metric(title: "Walkable", value: "3")
                                metric(title: "Late open", value: "2")
                            }
                        }
                    }

                    VStack(spacing: 12) {
                        ForEach(places) { place in
                            KairSurface(style: .sunken) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(place.title)
                                            .font(.title3.weight(.semibold))
                                            .foregroundStyle(AppTheme.Palette.textPrimary)

                                        Text(place.subtitle)
                                            .font(.subheadline)
                                            .foregroundStyle(AppTheme.Palette.textSecondary)
                                    }

                                    Spacer()

                                    KairStatusPill(
                                        title: place.status,
                                        systemImage: "mappin.and.ellipse",
                                        tint: place.tint
                                    )
                                }
                            }
                        }
                    }

                    KairSurface(style: .sunken) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Map canvas")
                                .font(.headline)
                                .foregroundStyle(AppTheme.Palette.textPrimary)

                            Text("Live map rendering, device location, and navigation execution are still placeholders. This rebuild focuses first on the product surface and route logic.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.Palette.textSecondary)

                            Button {
                                bootstrap.closeSurface()
                            } label: {
                                Label("Open chat", systemImage: "bubble.left.and.bubble.right")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.Palette.textOnStrong)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(AppTheme.Palette.accentStrong)
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
        .navigationTitle("Maps")
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

    private func metric(title: String, value: String) -> some View {
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

private struct NearbyPlace: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let status: String
    let tint: Color
}
