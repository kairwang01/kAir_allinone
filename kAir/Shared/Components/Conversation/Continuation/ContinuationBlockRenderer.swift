//
//  ContinuationBlockRenderer.swift
//  kAir
//
//  Single mapping layer from ChatContinuationEvent to the three transcript
//  block views.
//
//  Per Contracts/UX/continuation-transcript-visual-v1.md:
//    §3   stack order: summary → evidence → nextStep
//    §6   inter-block gap: 12pt
//    §7   suppression: dismiss / acceptNoEntry render zero output
//
//  This is the ONLY entry point for projecting an envelope into the view
//  tree. Per-vertical / per-surface branching is forbidden.
//

import SwiftUI

struct ContinuationBlockRenderer: View {
    static let interBlockGap: CGFloat = 12

    let event: ChatContinuationEvent
    var onChipTap: (NextStepAction) -> Void = { _ in }

    var body: some View {
        if event.renderEligible {
            VStack(alignment: .leading, spacing: Self.interBlockGap) {
                if let summary = event.summary {
                    SystemSummaryBlock(payload: summary)
                }
                if let evidence = event.evidence {
                    SystemEvidenceBlock(payload: evidence)
                }
                if let nextStep = event.nextStep {
                    NextStepPromptBlock(payload: nextStep, onChipTap: onChipTap)
                }
            }
        } else {
            EmptyView()
        }
    }
}

enum ContinuationBlockKind: Hashable {
    case summary
    case evidence
    case nextStep
}

extension ContinuationBlockRenderer {
    /// Ordered list of block kinds this renderer would produce for the event.
    /// Empty when `renderEligible == false`.
    /// Used by the contract tests to verify stack order and suppression
    /// without a full SwiftUI view introspection.
    var blockKindSequence: [ContinuationBlockKind] {
        guard event.renderEligible else { return [] }
        var kinds: [ContinuationBlockKind] = []
        if event.summary != nil { kinds.append(.summary) }
        if event.evidence != nil { kinds.append(.evidence) }
        if event.nextStep != nil { kinds.append(.nextStep) }
        return kinds
    }
}

extension ConversationMessage {
    /// Block-kind sequence the transcript render path would produce for this
    /// message. Returns empty for messages without a continuation event.
    /// Used by the integration tests to assert the chain
    /// `ConversationMessage → ContinuationBlockRenderer → blocks`
    /// without requiring SwiftUI view introspection.
    var continuationBlockKinds: [ContinuationBlockKind] {
        guard let event = continuationEvent else { return [] }
        return ContinuationBlockRenderer(event: event).blockKindSequence
    }
}

#Preview("completion · all three blocks") {
    ContinuationBlockRenderer(event: ContinuationFixtures.completionFull)
        .padding(20)
        .background(AppTheme.Palette.backgroundEnd)
}

#Preview("completion · summary only") {
    ContinuationBlockRenderer(event: ContinuationFixtures.completionSummaryOnly)
        .padding(20)
        .background(AppTheme.Palette.backgroundEnd)
}

#Preview("completion · summary + evidence") {
    ContinuationBlockRenderer(event: ContinuationFixtures.completionWithEvidence)
        .padding(20)
        .background(AppTheme.Palette.backgroundEnd)
}

#Preview("completion · Mode A") {
    ContinuationBlockRenderer(event: ContinuationFixtures.completionWithNextStepStrip)
        .padding(20)
        .background(AppTheme.Palette.backgroundEnd)
}

#Preview("completion · Mode B") {
    ContinuationBlockRenderer(event: ContinuationFixtures.completionWithNextStepPrimary)
        .padding(20)
        .background(AppTheme.Palette.backgroundEnd)
}

#Preview("abandon · summary only") {
    ContinuationBlockRenderer(event: ContinuationFixtures.abandonSummaryOnly)
        .padding(20)
        .background(AppTheme.Palette.backgroundEnd)
}

#Preview("abandon · with chip strip") {
    ContinuationBlockRenderer(event: ContinuationFixtures.abandonWithStrip)
        .padding(20)
        .background(AppTheme.Palette.backgroundEnd)
}

#Preview("dismiss · suppressed") {
    VStack(alignment: .leading, spacing: 8) {
        Text("Renderer below should produce zero blocks for .dismiss:")
            .font(.caption)
            .foregroundStyle(AppTheme.Palette.textMuted)
        ContinuationBlockRenderer(event: ContinuationFixtures.dismissSuppressed)
            .border(Color.red.opacity(0.3), width: 0.5)
    }
    .padding(20)
    .background(AppTheme.Palette.backgroundEnd)
}

#Preview("acceptNoEntry · suppressed") {
    VStack(alignment: .leading, spacing: 8) {
        Text("Renderer below should produce zero blocks for .acceptNoEntry:")
            .font(.caption)
            .foregroundStyle(AppTheme.Palette.textMuted)
        ContinuationBlockRenderer(event: ContinuationFixtures.acceptNoEntrySuppressed)
            .border(Color.red.opacity(0.3), width: 0.5)
    }
    .padding(20)
    .background(AppTheme.Palette.backgroundEnd)
}
