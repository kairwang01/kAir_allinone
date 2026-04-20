//
//  SearchActionCardView.swift
//  kAir
//
//  Renders a `SearchCardContent` value (one of the three v0 Search task kinds)
//  as an Action Card in Chat → Recommended Next. Structurally identical to
//  `MusicActionCardView` and `MapActionCardView` — Search is only allowed to
//  bend on the header label / glyph (per search-ui-spec-v0.md §4). Every
//  other visual dimension comes from the shared shell.
//

import SwiftUI

struct SearchActionCardView: View {
    let content: SearchCardContent
    let onImpression: () -> Void
    let onTap: () -> Void
    let onAccept: () -> Void
    let onSecondaryAction: () -> Void
    let onDismiss: (MatchingFeedbackKind) -> Void

    init(
        content: SearchCardContent,
        onImpression: @escaping () -> Void,
        onTap: @escaping () -> Void,
        onAccept: @escaping () -> Void,
        onSecondaryAction: @escaping () -> Void,
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
