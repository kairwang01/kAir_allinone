//
//  NextStepPromptBlock.swift
//  kAir
//
//  nextStepPrompt transcript block.
//  Visual contract: Contracts/UX/continuation-transcript-visual-v1.md §5.3.
//

import SwiftUI

struct NextStepPromptBlock: View {
    static let chipStripSpacing: CGFloat = 8
    static let eyebrowToStripGap: CGFloat = 8
    static let chipInternalSpacing: CGFloat = 6
    static let primaryHorizontalPadding: CGFloat = 16
    static let primaryVerticalPadding: CGFloat = 11
    static let secondaryHorizontalPadding: CGFloat = 12
    static let secondaryVerticalPadding: CGFloat = 8
    static let secondaryBorderWidth: CGFloat = 1
    static let primaryShadowOpacity: Double = 0.08
    static let primaryShadowBlur: CGFloat = 14
    static let primaryShadowOffsetY: CGFloat = 6
    static let eyebrowTracking: CGFloat = 1.2

    let payload: NextStepPromptPayload
    var onChipTap: (NextStepAction) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: Self.eyebrowToStripGap) {
            if let eyebrowText = (payload.eyebrowLocalized ?? payload.eyebrow),
               eyebrowText.isEmpty == false {
                Text(verbatim: eyebrowText.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(Self.eyebrowTracking)
                    .foregroundStyle(AppTheme.Palette.textMuted)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Self.chipStripSpacing) {
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
            HStack(spacing: Self.chipInternalSpacing) {
                if let glyph = chip.glyphName, glyph.isEmpty == false {
                    Image(systemName: glyph)
                }
                Text(verbatim: chip.labelLocalized ?? chip.label)
            }
            .font(isPrimary ? .subheadline.weight(.semibold) : .caption.weight(.semibold))
            .foregroundStyle(
                isPrimary ? AppTheme.Palette.textOnStrong : AppTheme.Palette.textPrimary
            )
            .padding(
                .horizontal,
                isPrimary ? Self.primaryHorizontalPadding : Self.secondaryHorizontalPadding
            )
            .padding(
                .vertical,
                isPrimary ? Self.primaryVerticalPadding : Self.secondaryVerticalPadding
            )
            .background(
                Capsule(style: .continuous)
                    .fill(isPrimary ? AppTheme.Palette.surfaceStrong : AppTheme.Palette.surface)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        isPrimary ? Color.clear : AppTheme.Palette.line,
                        lineWidth: Self.secondaryBorderWidth
                    )
            )
            .shadow(
                color: Color.black.opacity(isPrimary ? Self.primaryShadowOpacity : 0),
                radius: isPrimary ? Self.primaryShadowBlur : 0,
                x: 0,
                y: isPrimary ? Self.primaryShadowOffsetY : 0
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
