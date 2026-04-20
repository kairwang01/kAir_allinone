//
//  MapActionCardView.swift
//  kAir
//
//  Renders a frozen `MapActionCardModel` as the user-visible Maps card in
//  Chat → Recommended Next. No business logic lives here — the view is a
//  thin projection of the model that delegates visual grammar to
//  `ActionCardShell` (the shared 7-region primitive).
//
//  Maps is allowed to bend on two dimensions only, per Maps UI Spec v1:
//    - the header label / icon (zh/en task-kind copy + task-kind glyph)
//    - the trust-pill array
//  Everything else comes from the shared shell and must not fork.
//

import SwiftUI

struct MapActionCardView: View {
    let model: MapActionCardModel
    let trustPills: [ActionCardTrustPillKind]
    let onImpression: () -> Void
    let onTap: () -> Void
    let onAccept: () -> Void
    let onSecondaryAction: (() -> Void)?
    let onDismiss: (MatchingFeedbackKind) -> Void

    init(
        model: MapActionCardModel,
        trustPills: [ActionCardTrustPillKind] = [],
        onImpression: @escaping () -> Void,
        onTap: @escaping () -> Void,
        onAccept: @escaping () -> Void,
        onSecondaryAction: (() -> Void)? = nil,
        onDismiss: @escaping (MatchingFeedbackKind) -> Void
    ) {
        self.model = model
        self.trustPills = trustPills
        self.onImpression = onImpression
        self.onTap = onTap
        self.onAccept = onAccept
        self.onSecondaryAction = onSecondaryAction
        self.onDismiss = onDismiss
    }

    var body: some View {
        ActionCardShell(
            headerLabelTitle: taskKindLabel,
            headerLabelSystemImage: taskKindSystemImage,
            trustPills: trustPills,
            isZh: model.language.usesChineseCopy,
            title: model.title,
            subtitle: model.subtitle,
            reasonText: model.reasonChipText,
            primaryActionTitle: model.primaryActionTitle,
            primaryEnabled: model.state != .accepted && model.state != .dismissed,
            secondaryActionTitle: model.secondaryActionTitle,
            feedbackAffordanceLabel: model.feedbackAffordanceLabel,
            onCardTap: onTap,
            onPrimaryAction: onAccept,
            onSecondaryAction: onSecondaryAction,
            onFeedback: { feedback in onDismiss(feedback) },
            onDismiss: { onDismiss(.dismiss) }
        )
        .opacity(model.state == .dismissed ? 0.4 : 1.0)
        .overlay(alignment: .topTrailing) { stateBadge }
        .onAppear(perform: onImpression)
    }

    // MARK: - State badge

    @ViewBuilder
    private var stateBadge: some View {
        switch model.state {
        case .loading:
            badge(text: model.language.usesChineseCopy ? "加载中" : "Loading")
        case .accepted:
            badge(text: model.language.usesChineseCopy ? "已接入" : "Accepted")
        case .dismissed:
            badge(text: model.language.usesChineseCopy ? "已忽略" : "Dismissed")
        case .recommended:
            EmptyView()
        }
    }

    private func badge(text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.7))
            )
            .padding(12)
    }

    // MARK: - Task-kind bindings (Maps-allowed divergence: copy + icon only)

    private var taskKindLabel: String {
        let zh = model.language.usesChineseCopy
        switch model.taskKind {
        case .goToPlace: return zh ? "去某地" : "Go to place"
        case .nearbySearch: return zh ? "附近探索" : "Nearby"
        case .routeCompare: return zh ? "路线查看" : "Route"
        }
    }

    private var taskKindSystemImage: String {
        switch model.taskKind {
        case .goToPlace: return "mappin.and.ellipse"
        case .nearbySearch: return "location.magnifyingglass"
        case .routeCompare: return "arrow.triangle.turn.up.right.diamond"
        }
    }
}
