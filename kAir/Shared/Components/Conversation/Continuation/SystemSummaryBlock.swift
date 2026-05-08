//
//  SystemSummaryBlock.swift
//  kAir
//
//  systemSummary transcript block.
//  Visual contract: Contracts/UX/continuation-transcript-visual-v1.md §5.1.
//

import SwiftUI

struct SystemSummaryBlock: View {
    static let containerPadding: CGFloat = 20
    static let headerToTitleGap: CGFloat = 4
    static let titleToSummaryGap: CGFloat = 8
    static let summaryToMetricsGap: CGFloat = 12
    static let metricsToFooterGap: CGFloat = 12
    static let stateDotDiameter: CGFloat = 8
    static let maxContentWidth: CGFloat = 560
    static let metricTileMinWidth: CGFloat = 92
    static let metricTilePadding: CGFloat = 8
    static let metricTileSpacing: CGFloat = 8
    static let shadowOpacity: Double = 0.06
    static let shadowBlur: CGFloat = 12
    static let shadowOffsetY: CGFloat = 6
    static let borderWidth: CGFloat = 0.8
    static let eyebrowGlyphPointSize: CGFloat = 12
    static let eyebrowTracking: CGFloat = 1.2

    let payload: SystemSummaryPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
            Spacer().frame(height: Self.headerToTitleGap)
            Text(verbatim: payload.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer().frame(height: Self.titleToSummaryGap)
            Text(verbatim: payload.summary)
                .font(.body)
                .foregroundStyle(AppTheme.Palette.textPrimary)
                .lineSpacing(3)
                .lineLimit(2)
                .truncationMode(.tail)
            if payload.metrics.isEmpty == false {
                Spacer().frame(height: Self.summaryToMetricsGap)
                metricGrid
            }
            if let footer = payload.footer, footer.isEmpty == false {
                Spacer().frame(height: Self.metricsToFooterGap)
                Text(verbatim: footer)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.Palette.textMuted)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(Self.containerPadding)
        .frame(maxWidth: Self.maxContentWidth, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardRadius, style: .continuous)
                .fill(AppTheme.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardRadius, style: .continuous)
                .strokeBorder(AppTheme.Palette.line, lineWidth: Self.borderWidth)
        )
        .shadow(
            color: Color.black.opacity(Self.shadowOpacity),
            radius: Self.shadowBlur,
            x: 0,
            y: Self.shadowOffsetY
        )
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
                    .font(.system(size: Self.eyebrowGlyphPointSize, weight: .semibold))
                    .foregroundStyle(AppTheme.Palette.textMuted)
            }
            Text(verbatim: (eyebrow.labelLocalized ?? eyebrow.label).uppercased())
                .font(.caption.weight(.bold))
                .tracking(Self.eyebrowTracking)
                .foregroundStyle(AppTheme.Palette.textMuted)
        }
    }

    private var stateDot: some View {
        Circle()
            .fill(Self.stateDotColor(for: payload.outcomeTone))
            .frame(width: Self.stateDotDiameter, height: Self.stateDotDiameter)
    }

    /// Maps the outcome tone to its visual-v1 §7 dot color.
    /// Exposed at static scope so contract tests can verify the mapping
    /// without instantiating the view.
    static func stateDotColor(for tone: OutcomeTone) -> Color {
        switch tone {
        case .completion:
            return AppTheme.Palette.success
        case .abandon:
            return AppTheme.Palette.warning
        }
    }

    private var metricGrid: some View {
        let columns = [
            GridItem(.adaptive(minimum: Self.metricTileMinWidth), spacing: Self.metricTileSpacing)
        ]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: Self.metricTileSpacing) {
            ForEach(Array(payload.metrics.enumerated()), id: \.offset) { _, metric in
                metricTile(metric)
            }
        }
    }

    private func metricTile(_ metric: Metric) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: metric.keyLocalized ?? metric.key)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textMuted)
                .lineLimit(1)
            Text(verbatim: metric.valueLocalized ?? metric.value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textPrimary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Self.metricTilePadding)
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

#Preview("completion · with all metrics") {
    SystemSummaryBlock(payload: ContinuationFixtures.completionFull.summary!)
        .padding(20)
        .background(AppTheme.Palette.backgroundEnd)
}
