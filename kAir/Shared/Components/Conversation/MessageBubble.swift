//
//  MessageBubble.swift
//  kAir
//
//  Shared message and tool-result rendering primitives.
//

import SwiftUI

struct MessageBubble: View {
    let message: ConversationMessage
    var onAction: ((ConversationToolAction) -> Void)? = nil

    var body: some View {
        Group {
            switch message.role {
            case .system:
                VStack(spacing: 12) {
                    SystemEventRow(message: message)

                    if message.toolResults.isEmpty == false {
                        VStack(spacing: 12) {
                            ForEach(message.toolResults) { result in
                                ConversationToolResultCard(
                                    result: result,
                                    onAction: onAction
                                )
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            case .assistant, .user:
                HStack(alignment: .top, spacing: 14) {
                    if message.role.alignsTrailing {
                        Spacer(minLength: 52)
                    }

                    VStack(
                        alignment: message.role.alignsTrailing ? .trailing : .leading,
                        spacing: 10
                    ) {
                        metadataRow

                        if message.tags.isEmpty == false {
                            tagRow
                        }

                        if message.text.isEmpty == false {
                            textContent
                        }

                        if message.toolResults.isEmpty == false {
                            VStack(spacing: 12) {
                                ForEach(message.toolResults) { result in
                                    ConversationToolResultCard(
                                        result: result,
                                        onAction: onAction
                                    )
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
                .padding(.vertical, 2)
            }
        }
    }

    private var metadataRow: some View {
        HStack(spacing: 8) {
            Text(message.author)
                .font(.caption.weight(.semibold))

            Text(
                message.timestamp.formatted(
                    .dateTime
                        .hour()
                        .minute()
                )
            )
            .font(.caption)
        }
        .foregroundStyle(AppTheme.Palette.textMuted)
    }

    private var tagRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(message.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(AppTheme.Palette.surfaceElevated)
                        )
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
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(
                        cornerRadius: 22,
                        style: .continuous
                    )
                    .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: 22,
                        style: .continuous
                    )
                    .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
        case .user:
            Text(message.text)
                .font(.body)
                .foregroundStyle(AppTheme.Palette.textOnStrong)
                .multilineTextAlignment(.trailing)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(
                        cornerRadius: 22,
                        style: .continuous
                    )
                    .fill(Color(red: 0.18, green: 0.19, blue: 0.21))
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: 22,
                        style: .continuous
                    )
                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
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
                Image(systemName: systemImage)
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
                    .fill(Color.white.opacity(0.82))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(AppTheme.Palette.line, lineWidth: 1)
            )

            Spacer()
        }
    }

    private var systemImage: String {
        if message.tags.contains("Reference") {
            return "paperclip"
        }
        return "arrow.triangle.branch"
    }
}

private struct ConversationToolResultCard: View {
    let result: ConversationToolResult
    var onAction: ((ConversationToolAction) -> Void)? = nil

    private let columns = [
        GridItem(.adaptive(minimum: 92), spacing: 8)
    ]

    var body: some View {
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
                            .fill(Color(uiColor: .systemGray6))
                        )
                    }
                }
            }

            if let footer = result.footer, footer.isEmpty == false {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Palette.textMuted)
            }

            if result.actions.isEmpty == false {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(result.actions) { action in
                        Button {
                            onAction?(action)
                        } label: {
                            KAirActionCapsule(
                                title: action.title,
                                systemImage: action.systemImage,
                                emphasized: action.style == .primary
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
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
