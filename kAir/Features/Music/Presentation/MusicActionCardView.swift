//
//  MusicActionCardView.swift
//  kAir
//
//  Renders a `MusicCardContent` value (one of the three v0 Music task kinds)
//  as an Action Card in Chat → Recommended Next. This view is a thin
//  projection of content onto `ActionCardShell` — Music is allowed to bend
//  only on the header label / glyph (per music-ui-spec-v0.md §3). Every
//  other visual dimension comes from the shared shell.
//

import SwiftUI

struct MusicActionCardView: View {
    let content: MusicCardContent
    let onImpression: () -> Void
    let onTap: () -> Void
    let onAccept: () -> Void
    let onSecondaryAction: (() -> Void)?
    let onDismiss: (MatchingFeedbackKind) -> Void

    init(
        content: MusicCardContent,
        onImpression: @escaping () -> Void,
        onTap: @escaping () -> Void,
        onAccept: @escaping () -> Void,
        onSecondaryAction: (() -> Void)? = nil,
        onDismiss: @escaping (MatchingFeedbackKind) -> Void
    ) {
        self.content = content
        self.onImpression = onImpression
        self.onTap = onTap
        self.onAccept = onAccept
        self.onSecondaryAction = onSecondaryAction
        self.onDismiss = onDismiss
    }

    var body: some View {
        ActionCardShell(
            headerLabelTitle: content.headerLabelTitle,
            headerLabelSystemImage: content.headerLabelSystemImage,
            trustPills: content.trustPills,
            isZh: content.language.usesChineseCopy,
            title: content.title,
            subtitle: content.subtitle,
            reasonText: content.reasonText,
            primaryActionTitle: content.primaryActionTitle,
            primaryEnabled: true,
            secondaryActionTitle: content.secondaryActionTitle,
            feedbackAffordanceLabel: content.feedbackAffordanceLabel,
            onCardTap: onTap,
            onPrimaryAction: onAccept,
            onSecondaryAction: onSecondaryAction,
            onFeedback: { feedback in onDismiss(feedback) },
            onDismiss: { onDismiss(.dismiss) }
        )
        .onAppear(perform: onImpression)
    }
}
