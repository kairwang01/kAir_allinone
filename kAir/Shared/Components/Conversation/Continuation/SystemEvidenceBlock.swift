//
//  SystemEvidenceBlock.swift
//  kAir
//
//  systemEvidence transcript block.
//  Visual contract: Contracts/UX/continuation-transcript-visual-v1.md §5.2.
//

import SwiftUI

struct SystemEvidenceBlock: View {
    static let containerPadding: CGFloat = 12
    static let interRowSpacing: CGFloat = 8
    static let maxContentWidth: CGFloat = 560
    static let labelColumnWidth: CGFloat = 120
    static let pairValueMaxLineCount: Int = 3
    static let borderWidth: CGFloat = 0.8

    /// Eyebrow typography per `design-system-v1.md` §3.2. The previous
    /// `.font(.caption.weight(.bold))` + `.tracking(1.2)` pair was
    /// exactly the `eyebrow` token; this replaces it with the shared
    /// token. Exposed (internal) so the token-wiring test can assert
    /// `eyebrowTypography == AppTheme.Typography.eyebrow`.
    static let eyebrowTypography = AppTheme.Typography.eyebrow

    let payload: SystemEvidencePayload

    var body: some View {
        VStack(alignment: .leading, spacing: Self.interRowSpacing) {
            if let eyebrowText = (payload.eyebrowLocalized ?? payload.eyebrow),
               eyebrowText.isEmpty == false {
                Text(verbatim: eyebrowText.uppercased())
                    .kAirTypography(Self.eyebrowTypography)
                    .foregroundStyle(AppTheme.Palette.textMuted)
            }
            VStack(alignment: .leading, spacing: Self.interRowSpacing) {
                ForEach(Array(payload.pairs.enumerated()), id: \.offset) { _, pair in
                    pairRow(pair)
                }
            }
        }
        .padding(Self.containerPadding)
        .frame(maxWidth: Self.maxContentWidth, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Metrics.compactRadius, style: .continuous)
                .fill(AppTheme.Palette.backgroundInset)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Metrics.compactRadius, style: .continuous)
                .strokeBorder(AppTheme.Palette.line, lineWidth: Self.borderWidth)
        )
    }

    private func pairRow(_ pair: EvidencePair) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(verbatim: pair.labelLocalized ?? pair.label)
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.Palette.textMuted)
                .frame(width: Self.labelColumnWidth, alignment: .leading)
                .lineLimit(1)
            Text(verbatim: pair.valueLocalized ?? pair.value)
                .font(.body)
                .foregroundStyle(AppTheme.Palette.textPrimary)
                .lineLimit(Self.pairValueMaxLineCount)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview("evidence · 3 pairs") {
    SystemEvidenceBlock(payload: ContinuationFixtures.completionWithEvidence.evidence!)
        .padding(20)
        .background(AppTheme.Palette.backgroundEnd)
}
