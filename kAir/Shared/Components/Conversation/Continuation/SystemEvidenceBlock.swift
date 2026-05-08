//
//  SystemEvidenceBlock.swift
//  kAir
//
//  Interface draft for the systemEvidence transcript block.
//  Visual contract: Contracts/UX/continuation-transcript-visual-v1.md §5.2.
//
//  I1-prep level.
//

import SwiftUI

struct SystemEvidenceBlock: View {
    let payload: SystemEvidencePayload

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let eyebrow = (payload.eyebrowLocalized ?? payload.eyebrow), eyebrow.isEmpty == false {
                Text(eyebrow.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(AppTheme.Palette.textMuted)
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(payload.pairs.enumerated()), id: \.offset) { _, pair in
                    pairRow(pair)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: 560, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Metrics.compactRadius, style: .continuous)
                .fill(AppTheme.Palette.backgroundInset)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Metrics.compactRadius, style: .continuous)
                .strokeBorder(AppTheme.Palette.line, lineWidth: 0.8)
        )
    }

    private func pairRow(_ pair: EvidencePair) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(pair.labelLocalized ?? pair.label)
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.Palette.textMuted)
                .frame(width: 120, alignment: .leading)
                .lineLimit(1)
            Text(pair.valueLocalized ?? pair.value)
                .font(.body)
                .foregroundStyle(AppTheme.Palette.textPrimary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview("evidence · 3 pairs") {
    SystemEvidenceBlock(payload: ContinuationFixtures.completionWithEvidence.evidence!)
        .padding(20)
        .background(AppTheme.Palette.backgroundEnd)
}
