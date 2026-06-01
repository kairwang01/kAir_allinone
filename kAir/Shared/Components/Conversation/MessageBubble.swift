//
//  MessageBubble.swift
//  kAir
//
//  Shared message and tool-result rendering primitives.
//

import SwiftUI

struct MessageBubble: View {
    let message: ConversationMessage

    var body: some View {
        Group {
            switch message.role {
            case .system:
                SystemEventRow(message: message)
            case .assistant, .user:
                HStack(alignment: .top, spacing: 14) {
                    if message.role.alignsTrailing {
                        Spacer(minLength: 52)
                    }

                    VStack(
                        alignment: message.role.alignsTrailing ? .trailing : .leading,
                        spacing: 10
                    ) {
                        // Minimalist bubbles (Doubao/Yuanbao style): no per-message
                        // author, timestamp, or jargon tag chips — alignment + bubble
                        // styling already convey who is speaking.
                        if message.text.isEmpty == false {
                            textContent
                        }

                        if message.toolResults.isEmpty == false {
                            VStack(spacing: 12) {
                                ForEach(message.toolResults) { result in
                                    ConversationToolResultCard(result: result)
                                }
                            }
                        }
                    }
                    .frame(
                        maxWidth: .infinity,
                        alignment: message.role.alignsTrailing ? .trailing : .leading
                    )

                    if message.role.alignsTrailing == false {
                        Spacer(minLength: 52)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var textContent: some View {
        switch message.role {
        case .assistant:
            Text(message.text)
                .font(.body)
                .foregroundStyle(AppTheme.Palette.textPrimary)
                .lineSpacing(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: 560, alignment: .leading)
        case .user:
            Text(message.text)
                .font(.body)
                .foregroundStyle(AppTheme.Palette.textOnStrong)
                .multilineTextAlignment(.trailing)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(
                        cornerRadius: 24,
                        style: .continuous
                    )
                    .fill(AppTheme.Palette.surfaceStrong)
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: 24,
                        style: .continuous
                    )
                    .strokeBorder(AppTheme.Palette.surfaceStrong, lineWidth: 1)
                )
        case .system:
            EmptyView()
        }
    }
}

private struct SystemEventRow: View {
    let message: ConversationMessage

    var body: some View {
        HStack {
            Spacer()

            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.caption.weight(.semibold))

                Text(message.text)
                    .font(.caption.weight(.medium))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(AppTheme.Palette.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.58))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(AppTheme.Palette.line, lineWidth: 1)
            )

            Spacer()
        }
    }
}

private struct ConversationToolResultCard: View {
    let result: ConversationToolResult

    private let columns = [
        GridItem(.adaptive(minimum: 92), spacing: 8)
    ]

    var body: some View {
        KAirSurface(style: .sunken, padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(stateTint)
                            .frame(width: 8, height: 8)

                        Text(result.title)
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)
                    }

                    Spacer(minLength: 12)

                    Text(stateTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(stateTint)
                }

                Text(result.summary)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)

                if result.metrics.isEmpty == false {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                        ForEach(result.metrics) { metric in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(metric.key)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(AppTheme.Palette.textMuted)

                                Text(metric.value)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.Palette.textPrimary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(
                                RoundedRectangle(
                                    cornerRadius: AppTheme.Metrics.compactRadius,
                                    style: .continuous
                                )
                                .fill(Color.white.opacity(0.66))
                            )
                        }
                    }
                }

                if let footer = result.footer, footer.isEmpty == false {
                    Text(footer)
                        .font(.caption)
                        .foregroundStyle(AppTheme.Palette.textMuted)
                }
            }
        }
    }

    private var stateTitle: String {
        switch result.state {
        case .ready:
            return "Ready"
        case .working:
            return "Working"
        case .warning:
            return "Attention"
        }
    }

    private var stateTint: Color {
        switch result.state {
        case .ready:
            return AppTheme.Palette.success
        case .working:
            return AppTheme.Palette.warning
        case .warning:
            return AppTheme.Palette.danger
        }
    }
}
