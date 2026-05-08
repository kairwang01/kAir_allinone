//
//  SystemSummaryBlock.swift
//  kAir
//
//  Interface draft for the systemSummary transcript block.
//  Visual contract: Contracts/UX/continuation-transcript-visual-v1.md §5.1.
//
//  I1-prep: signature + layout shell, sufficient for #Preview.
//  Edge-case truncation, accessibility, and motion are I1's concern.
//

import SwiftUI

struct SystemSummaryBlock: View {
    let payload: SystemSummaryPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
            Spacer().frame(height: 4)
            Text(payload.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer().frame(height: 8)
            Text(payload.summary)
                .font(.body)
                .foregroundStyle(AppTheme.Palette.textPrimary)
                .lineSpacing(3)
                .lineLimit(2)
                .truncationMode(.tail)
            if payload.metrics.isEmpty == false {
                Spacer().frame(height: 12)
                metricGrid
            }
            if let footer = payload.footer, footer.isEmpty == false {
                Spacer().frame(height: 12)
                Text(footer)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.Palette.textMuted)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(20)
        .frame(maxWidth: 560, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardRadius, style: .continuous)
                .fill(AppTheme.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardRadius, style: .continuous)
                .strokeBorder(AppTheme.Palette.line, lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
    }

    @ViewBuilder
    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            if let eyebrow = payload.eyebrow {
                eyebrowView(eyebrow)
            }
            Spacer(minLength: 8)
            stateDot
        }
    }

    @ViewBuilder
    private func eyebrowView(_ eyebrow: EyebrowDescriptor) -> some View {
        HStack(spacing: 6) {
            if let glyph = eyebrow.glyphName, glyph.isEmpty == false {
                Image(systemName: glyph)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.Palette.textMuted)
            }
            Text((eyebrow.labelLocalized ?? eyebrow.label).uppercased())
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(AppTheme.Palette.textMuted)
        }
    }

    private var stateDot: some View {
        Circle()
            .fill(stateDotColor)
            .frame(width: 8, height: 8)
    }

    private var stateDotColor: Color {
        switch payload.outcomeTone {
        case .completion:
            return AppTheme.Palette.success
        case .abandon:
            return AppTheme.Palette.warning
        }
    }

    private var metricGrid: some View {
        let columns = [GridItem(.adaptive(minimum: 92), spacing: 8)]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(Array(payload.metrics.enumerated()), id: \.offset) { _, metric in
                metricTile(metric)
            }
        }
    }

    private func metricTile(_ metric: Metric) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(metric.keyLocalized ?? metric.key)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textMuted)
                .lineLimit(1)
            Text(metric.valueLocalized ?? metric.value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textPrimary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Metrics.compactRadius, style: .continuous)
                .fill(AppTheme.Palette.backgroundInset)
        )
    }
}

#Preview("completion · summary only") {
    SystemSummaryBlock(payload: ContinuationFixtures.completionSummaryOnly.summary!)
        .padding(20)
        .background(AppTheme.Palette.backgroundEnd)
}

#Preview("abandon · summary only") {
    SystemSummaryBlock(payload: ContinuationFixtures.abandonSummaryOnly.summary!)
        .padding(20)
        .background(AppTheme.Palette.backgroundEnd)
}
