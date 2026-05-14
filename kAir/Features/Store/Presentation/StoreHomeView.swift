//
//  StoreHomeView.swift
//  kAir
//
//  Curated store surface for kAir.
//

import SwiftUI

struct StoreHomeView: View {
    let bootstrap: AppBootstrap

    private let collections: [StoreCollection] = [
        StoreCollection(title: "Recovery", summary: "Sleep, magnesium, and soft-support bundles.", price: "From $24"),
        StoreCollection(title: "Wearables", summary: "Rings, bands, and sensors that fit kAir's product logic.", price: "From $199"),
        StoreCollection(title: "Nutrition", summary: "Low-noise essentials instead of a loud supplement wall.", price: "From $18")
    ]

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: AppTheme.Metrics.sectionSpacing) {
                    KAirPageHeader(
                        title: "Store",
                        summary: "Store should feel curated and context-aware, not like a generic marketplace pasted into a health app.",
                        badges: [
                            KAirHeaderBadge(title: "Curated", systemImage: "sparkles", tint: AppTheme.Palette.accent),
                            KAirHeaderBadge(title: "Checkout later", systemImage: "bag", tint: AppTheme.Palette.warning)
                        ]
                    )

                    VStack(spacing: 12) {
                        ForEach(collections) { collection in
                            KAirSurface(style: .sunken) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(collection.title)
                                            .font(.title3.weight(.semibold))
                                            .foregroundStyle(AppTheme.Palette.textPrimary)

                                        Text(collection.summary)
                                            .font(.subheadline)
                                            .foregroundStyle(AppTheme.Palette.textSecondary)
                                    }

                                    Spacer()

                                    Text(collection.price)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.Palette.textPrimary)
                                }
                            }
                        }
                    }

                    KAirSurface {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Store rules")
                                .font(.headline)
                                .foregroundStyle(AppTheme.Palette.textPrimary)

                            ruleRow("Recommendations should follow health context, not interrupt it.")
                            ruleRow("High-trust categories first: recovery, wearables, nutrition.")
                            ruleRow("No aggressive discounts, countdowns, or marketplace clutter.")
                        }
                    }

                    KAirSurface(style: .sunken) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Commerce status")
                                .font(.headline)
                                .foregroundStyle(AppTheme.Palette.textPrimary)

                            Text("Catalog and curation are in place. Payments, cart, and fulfillment remain intentionally unimplemented in this rebuild.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.Palette.textSecondary)

                            Button {
                                // Main D: explicit "Back to chat" is
                                // `.completion` per
                                // `post-return-and-continuation-ux-v1.md`
                                // §1.2.
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
                .padding(.horizontal, AppTheme.Metrics.screenPadding)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Store")
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

    private func ruleRow(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(.subheadline)
            .foregroundStyle(AppTheme.Palette.textSecondary)
    }
}

private struct StoreCollection: Identifiable {
    let id = UUID()
    let title: String
    let summary: String
    let price: String
}
