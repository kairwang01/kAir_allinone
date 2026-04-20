//
//  MusicHomeView.swift
//  kAir
//
//  Second UI validation vertical for the kAir super-app. Music is a pure
//  caller of `ExecutionSurfaceShell` per music-ui-spec-v0.md §4 — no private
//  nav rail, no private empty state, no private trust vocabulary. The only
//  Music-specific affordance inside the primary region is `Stop playback`.
//

import SwiftUI

struct MusicHomeView: View {
    let bootstrap: AppBootstrap

    private var session: MusicPlaybackSession? {
        bootstrap.activeMusicSession
    }

    var body: some View {
        ExecutionSurfaceShell(
            navRail: navRail(for: session),
            title: title(for: session),
            status: status(for: session),
            state: systemState(for: session),
            terminal: terminal(for: session),
            onReturnToChat: bootstrap.returnToChat,
            primary: {
                if let session {
                    MusicNowPlayingCard(
                        session: session,
                        onStop: bootstrap.stopMusic
                    )
                } else {
                    EmptyView()
                }
            },
            supplementary: { EmptyView() }
        )
        .navigationTitle("Music")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Shell input builders

    private func navRail(for session: MusicPlaybackSession?) -> ExecutionSurfaceNavRail {
        ExecutionSurfaceNavRail(
            backToChatTitle: "Back to chat",
            trustPills: session == nil ? [] : [.partnerFallback],
            isZh: false
        )
    }

    private func title(for session: MusicPlaybackSession?) -> ExecutionSurfaceTitle {
        if let session {
            return ExecutionSurfaceTitle(
                eyebrow: "Music · Chat-invoked",
                title: session.title,
                summary: session.subtitle
            )
        }
        return ExecutionSurfaceTitle(
            eyebrow: "Music · Chat-invoked",
            title: "No music in flight",
            summary: "Music is a chat-invoked layer. Ask for something like “Play focus music” to start a session."
        )
    }

    private func status(for session: MusicPlaybackSession?) -> ExecutionSurfaceStatus {
        guard let session else { return .none }
        return ExecutionSurfaceStatus(
            statusMessage: "Streaming pending — demo session for \(session.mood.title)",
            errorMessage: nil
        )
    }

    private func systemState(for session: MusicPlaybackSession?) -> ExecutionSurfaceSystemState {
        session == nil ? .empty : .ready
    }

    private func terminal(for session: MusicPlaybackSession?) -> ExecutionSurfaceTerminal? {
        // v0 does not wire playback-ended detection; the row is dormant until
        // Music earns a real streaming lifecycle. See music-ui-spec-v0.md §4.2.
        _ = session
        return nil
    }
}

// MARK: - Music-specific primary card (ActionCardShell-based)

private struct MusicNowPlayingCard: View {
    let session: MusicPlaybackSession
    let onStop: () -> Void

    var body: some View {
        ActionCardShell(
            headerLabelTitle: "Now playing",
            headerLabelSystemImage: "waveform",
            trustPills: [.partnerFallback],
            isZh: false,
            title: session.title,
            subtitle: session.subtitle,
            reasonText: "Mode · \(session.mood.title)  /  Source · \(session.sourceLabel)",
            primaryActionTitle: "Stop playback",
            primaryEnabled: true,
            secondaryActionTitle: nil,
            feedbackAffordanceLabel: "Feedback options",
            onCardTap: nil,
            onPrimaryAction: onStop,
            onSecondaryAction: nil,
            onFeedback: { _ in },
            onDismiss: onStop
        )
    }
}
