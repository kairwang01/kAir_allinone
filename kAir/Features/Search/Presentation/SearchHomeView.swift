//
//  SearchHomeView.swift
//  kAir
//
//  Third UI validation vertical for the kAir super-app. Search is a pure
//  caller of `ExecutionSurfaceShell` per search-ui-spec-v0.md §5 — no
//  private nav rail, no private empty state, no private trust vocabulary,
//  no in-surface search field. Parallel to `MusicHomeView`.
//
//  v0 is not yet wired into `AppBootstrap`; the surface takes a session and
//  a return-to-chat closure directly. When Search earns real chat-invoked
//  entry (v1+), this view will get a `bootstrap: AppBootstrap` reference
//  identical to `MusicHomeView`.
//

import SwiftUI

struct SearchHomeView: View {
    let session: SearchSession?
    let onReturnToChat: () -> Void

    var body: some View {
        ExecutionSurfaceShell(
            navRail: navRail(for: session),
            title: title(for: session),
            status: status(for: session),
            state: systemState(for: session),
            terminal: terminal(for: session),
            onReturnToChat: onReturnToChat,
            primary: {
                if let session {
                    SearchResultCard(session: session, onReturnToChat: onReturnToChat)
                } else {
                    EmptyView()
                }
            },
            supplementary: { EmptyView() }
        )
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Shell input builders

    private func navRail(for session: SearchSession?) -> ExecutionSurfaceNavRail {
        let isZh = session?.language.usesChineseCopy ?? false
        return ExecutionSurfaceNavRail(
            backToChatTitle: isZh ? "返回聊天" : "Back to chat",
            trustPills: session == nil ? [] : [.partnerFallback],
            isZh: isZh
        )
    }

    private func title(for session: SearchSession?) -> ExecutionSurfaceTitle {
        if let session {
            let isZh = session.language.usesChineseCopy
            return ExecutionSurfaceTitle(
                eyebrow: isZh ? "搜索 · 对话触发" : "Search · Chat-invoked",
                title: session.query,
                summary: session.summary
            )
        }
        return ExecutionSurfaceTitle(
            eyebrow: "Search · Chat-invoked",
            title: "No search in flight",
            summary: "Search is a chat-invoked layer. Ask something like “What is SwiftUI Observation?” to start a session."
        )
    }

    private func status(for session: SearchSession?) -> ExecutionSurfaceStatus {
        guard let session else { return .none }
        let isZh = session.language.usesChineseCopy
        let message = isZh
            ? "来源未接入 — 当前演示由本机数据驱动"
            : "Provider pending — this session is a local demo"
        return ExecutionSurfaceStatus(
            statusMessage: message,
            errorMessage: nil
        )
    }

    private func systemState(for session: SearchSession?) -> ExecutionSurfaceSystemState {
        session == nil ? .empty : .ready
    }

    private func terminal(for session: SearchSession?) -> ExecutionSurfaceTerminal? {
        // v0 does not wire deep-research completion; the row is dormant.
        // See search-ui-spec-v0.md §5.2.
        _ = session
        return nil
    }
}

// MARK: - Search-specific primary card (ActionCardShell-based)

private struct SearchResultCard: View {
    let session: SearchSession
    let onReturnToChat: () -> Void

    var body: some View {
        let content = SearchCardContent(
            taskKind: session.kind,
            title: session.headlineAnswer,
            subtitle: session.summary,
            reasonText: session.language.usesChineseCopy
                ? "来源 · \(session.sourceLabel)"
                : "Source · \(session.sourceLabel)",
            language: session.cardContentLanguage
        )
        ActionCardShell(
            headerLabelTitle: content.headerLabelTitle,
            headerLabelSystemImage: content.headerLabelSystemImage,
            trustPills: content.trustPills,
            isZh: content.language.usesChineseCopy,
            title: content.title,
            subtitle: content.subtitle,
            reasonText: content.reasonText,
            primaryActionTitle: content.primaryActionTitle,
            primaryEnabled: true,
            secondaryActionTitle: content.secondaryActionTitle,
            feedbackAffordanceLabel: content.feedbackAffordanceLabel,
            onCardTap: nil,
            onPrimaryAction: onReturnToChat,
            onSecondaryAction: onReturnToChat,
            onFeedback: { _ in },
            onDismiss: onReturnToChat
        )
    }
}
