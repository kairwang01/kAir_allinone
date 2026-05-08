//
//  NextStepPromptBlock.swift
//  kAir
//
//  Interface draft for the nextStepPrompt transcript block.
//  Visual contract: Contracts/UX/continuation-transcript-visual-v1.md §5.3.
//
//  I1-prep level.
//

import SwiftUI

struct NextStepPromptBlock: View {
    let payload: NextStepPromptPayload
    var onChipTap: (NextStepAction) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let eyebrow = (payload.eyebrowLocalized ?? payload.eyebrow), eyebrow.isEmpty == false {
                Text(eyebrow.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(AppTheme.Palette.textMuted)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if let primary = payload.primary, payload.mode == .primaryWithSecondary {
                        chipView(primary, isPrimary: true)
                    }
                    ForEach(Array(payload.secondaryChips.enumerated()), id: \.offset) { _, chip in
                        chipView(chip, isPrimary: false)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func chipView(_ chip: NextStepChip, isPrimary: Bool) -> some View {
        Button {
            onChipTap(chip.action)
        } label: {
            HStack(spacing: 6) {
                if let glyph = chip.glyphName, glyph.isEmpty == false {
                    Image(systemName: glyph)
                }
                Text(chip.labelLocalized ?? chip.label)
            }
            .font(isPrimary ? .subheadline.weight(.semibold) : .caption.weight(.semibold))
            .foregroundStyle(
                isPrimary ? AppTheme.Palette.textOnStrong : AppTheme.Palette.textPrimary
            )
            .padding(.horizontal, isPrimary ? 16 : 12)
            .padding(.vertical, isPrimary ? 11 : 8)
            .background(
                Capsule(style: .continuous)
                    .fill(isPrimary ? AppTheme.Palette.surfaceStrong : AppTheme.Palette.surface)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        isPrimary ? Color.clear : AppTheme.Palette.line,
                        lineWidth: 1
                    )
            )
            .shadow(
                color: Color.black.opacity(isPrimary ? 0.08 : 0),
                radius: isPrimary ? 14 : 0,
                x: 0,
                y: isPrimary ? 6 : 0
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview("Mode A · chip strip") {
    NextStepPromptBlock(payload: ContinuationFixtures.completionWithNextStepStrip.nextStep!)
        .padding(20)
        .background(AppTheme.Palette.backgroundEnd)
}

#Preview("Mode B · primary + secondary") {
    NextStepPromptBlock(payload: ContinuationFixtures.completionWithNextStepPrimary.nextStep!)
        .padding(20)
        .background(AppTheme.Palette.backgroundEnd)
}
