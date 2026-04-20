//
//  UnifiedActionCard.swift
//  kAir
//
//  Shared standard card for Phase 1 Action Cards feed. Delegates the full
//  visual treatment to `ActionCardShell` so Maps, Music, Store, and future
//  card kinds share one skeleton. Nothing here is allowed to extend the
//  7-region layout — this file is only a Unified→Shell adapter.
//

import SwiftUI

struct UnifiedActionCard: View {
    let candidate: UnifiedMatchingCandidate
    let reasonText: String?
    let primaryActionTitle: String
    let onPrimaryAction: () -> Void
    let secondaryActionTitle: String?
    let onSecondaryAction: (() -> Void)?
    let onCardTap: (() -> Void)?
    let onFeedback: (MatchingFeedbackKind) -> Void

    init(
        candidate: UnifiedMatchingCandidate,
        reasonText: String? = nil,
        primaryActionTitle: String = "View Details",
        onPrimaryAction: @escaping () -> Void,
        secondaryActionTitle: String? = nil,
        onSecondaryAction: (() -> Void)? = nil,
        onCardTap: (() -> Void)? = nil,
        onFeedback: @escaping (MatchingFeedbackKind) -> Void
    ) {
        self.candidate = candidate
        self.reasonText = reasonText
        self.primaryActionTitle = primaryActionTitle
        self.onPrimaryAction = onPrimaryAction
        self.secondaryActionTitle = secondaryActionTitle
        self.onSecondaryAction = onSecondaryAction
        self.onCardTap = onCardTap
        self.onFeedback = onFeedback
    }

    var body: some View {
        ActionCardShell(
            headerLabelTitle: candidate.objectKind.title,
            headerLabelSystemImage: candidate.objectKind.systemImage,
            trustPills: [],
            isZh: false,
            title: candidate.title,
            subtitle: candidate.summary,
            reasonText: reasonText,
            primaryActionTitle: primaryActionTitle,
            primaryEnabled: true,
            secondaryActionTitle: secondaryActionTitle,
            feedbackAffordanceLabel: "More options",
            onCardTap: onCardTap,
            onPrimaryAction: onPrimaryAction,
            onSecondaryAction: onSecondaryAction,
            onFeedback: onFeedback,
            onDismiss: { onFeedback(.dismiss) }
        )
    }
}
