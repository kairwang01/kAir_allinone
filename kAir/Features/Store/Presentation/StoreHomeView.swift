//
//  StoreHomeView.swift
//  kAir
//
//  Store Execution Surface — a pure caller of `ExecutionSurfaceShell`.
//
//  A1 step 3 / I1 (Store): `StoreHomeView` no longer renders a private
//  `KAirPageHeader`, a hand-rolled inline "Back to chat" capsule, or its
//  own navigation title. It maps the curated store content onto the
//  shared `ExecutionSurfaceShell` (Docs/design/execution-surface-
//  framework-v1.md §1–§11), mirroring the Maps / AI migrations:
//    - region (2) title       ← "Store" + curation summary
//    - region (5) trust pills  ← `[.partnerFallback]` — commerce backend
//                                 (payments/cart/fulfillment) is not yet
//                                 wired, so the partner-pending pill is
//                                 truthful (framework §5)
//    - region (4) status strip ← "curated catalog, checkout not wired"
//    - region (3) primary card ← the featured collection as a DISABLED
//                                 `ActionCardShell` (no real CTA action —
//                                 checkout is intentionally unwired;
//                                 framework §4)
//    - supplementary           ← remaining collections + store rules +
//                                 commerce-status text
//    - state                   ← always `.ready` (static info surface)
//    - onReturnToChat          ← AppBootstrap.recordSurfaceReturn(.completion)
//
//  Store is English-only in this build; localizing it is out of scope
//  for this migration. The shared RootShellView platform toolbar back is
//  left in place until Health also migrates (framework §2).
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
        ExecutionSurfaceShell(
            inputs: shellInputs,
            onReturnToChat: {
                // Explicit "Back to chat" is `.completion` per
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
            navRail: ExecutionSurfaceNavRail(trustPills: [.partnerFallback]),
            title: ExecutionSurfaceTitle(
                eyebrow: "Store",
                title: "Store",
                summary: "Store should feel curated and context-aware, not like a generic marketplace pasted into a health app."
            ),
            status: ExecutionSurfaceStatus(
                statusMessage: "Curated catalog — checkout not yet wired"
            ),
            state: .ready,
            language: .english
        )
    }

    // MARK: - Region (3) primary card

    /// The featured collection rendered as a first-class `ActionCardShell`
    /// in the disabled state (framework §4 requires region 3 to be an
    /// Action Card). Disabled because checkout is intentionally unwired —
    /// there is no real CTA action, so the card must not look tappable.
    private var primaryCard: some View {
        ActionCardShell(
            object: Self.collectionObject(collections[0]),
            state: .disabled
        )
    }

    private static func collectionObject(_ collection: StoreCollection) -> MatchingObject {
        MatchingObject(
            id: "store-\(collection.title.lowercased())",
            kind: .toolEntry,
            title: collection.title,
            subtitleTokens: [collection.price],
            reasonText: collection.summary,
            primaryCTA: "Curated pick",
            secondaryCTA: nil
        )
    }

    // MARK: - Supplementary (the vertical's "rest of the page", framework §1)

    private var supplementaryContent: some View {
        VStack(spacing: AppTheme.Metrics.sectionSpacing) {
            VStack(spacing: 12) {
                ForEach(Array(collections.dropFirst())) { collection in
                    collectionCard(collection)
                }
            }

            storeRulesCard
            commerceStatusCard
        }
    }

    private func collectionCard(_ collection: StoreCollection) -> some View {
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

    private var storeRulesCard: some View {
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
    }

    private var commerceStatusCard: some View {
        KAirSurface(style: .sunken) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Commerce status")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Text("Catalog and curation are in place. Payments, cart, and fulfillment remain intentionally unimplemented in this rebuild.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)
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

// MARK: - Previews

#Preview("Store") {
    NavigationStack {
        StoreHomeView(bootstrap: .preview)
    }
}
