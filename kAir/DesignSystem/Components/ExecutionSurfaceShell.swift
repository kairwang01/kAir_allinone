//
//  ExecutionSurfaceShell.swift
//  kAir
//
//  Shared primitive behind every Execution Surface the chat can portal into:
//  Maps, Music, Video, Health workspace, and any future vertical that reaches
//  the user via a fullScreenCover from RootShellView.
//
//  The shell freezes the 7 regions defined in `execution-surface-framework-v1.md`:
//
//      1. Nav rail              — Back-to-chat + trust pills + (optional) a11y pill
//      2. Task title region     — eyebrow + title + summary
//      3. Primary action region — the vertical's main card (content supplied by caller)
//      4. Status region         — optional inline status strip
//      5. Partner / source row  — trust pills driven by ActionCardTrustPillKind
//      6. State region          — loading / empty / error / permission degradations
//      7. Terminal-state row    — "surface completed" signals (e.g. "Playback ended")
//
//  Callers (MapsHomeView, MusicHomeView, future Video / Store surfaces) must
//  not introduce their own back button, their own trust vocabulary, or their
//  own empty-state grammar. Vertical-specific cards are allowed **only** inside
//  region 3 — everything else is frozen.
//

import SwiftUI

/// The four system states every Execution Surface must render. These are the
/// states required by `execution-surface-framework-v1.md`. Verticals cannot
/// invent new state names — if a condition doesn't map to one of these four,
/// it's a data issue, not a new state.
enum ExecutionSurfaceSystemState: String, CaseIterable, Hashable, Sendable {
    case ready
    case loading
    case empty
    case error
    case permissionOrUnavailable
}

/// Pure-data descriptor for the nav rail. Verticals supply the back-to-chat
/// copy (zh/en) and zero-or-more trust pills. The rail itself, the leading
/// glyph, the spacing, and the shadow are locked.
struct ExecutionSurfaceNavRail: Hashable {
    let backToChatTitle: String
    let trustPills: [ActionCardTrustPillKind]
    let isZh: Bool

    init(
        backToChatTitle: String,
        trustPills: [ActionCardTrustPillKind] = [],
        isZh: Bool = false
    ) {
        self.backToChatTitle = backToChatTitle
        self.trustPills = trustPills
        self.isZh = isZh
    }
}

/// Eyebrow + title + summary. Every surface has a task in flight; this is
/// where it is announced. `statusMessage` and `errorMessage` belong to the
/// status region — keep them out of the title.
struct ExecutionSurfaceTitle: Hashable {
    let eyebrow: String
    let title: String
    let summary: String

    init(eyebrow: String, title: String, summary: String) {
        self.eyebrow = eyebrow
        self.title = title
        self.summary = summary
    }
}

/// Optional status strip — non-error inline status (e.g. "Loading routes…",
/// "Paused for now"). When both `statusMessage` and `errorMessage` are set,
/// the error wins (rule from `maps-ui-spec-v1.md` §2.2).
struct ExecutionSurfaceStatus: Hashable {
    let statusMessage: String?
    let errorMessage: String?

    static let none = ExecutionSurfaceStatus(statusMessage: nil, errorMessage: nil)

    init(statusMessage: String? = nil, errorMessage: String? = nil) {
        self.statusMessage = statusMessage
        self.errorMessage = errorMessage
    }
}

/// Terminal-state row: the short signal that this task has *finished* its
/// own lifecycle inside the surface (e.g. "Playback ended" for Music,
/// "Arrived" for Maps, "Episode complete" for Video). Optional.
struct ExecutionSurfaceTerminal: Hashable {
    let title: String
    let systemImage: String

    init(title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }
}

struct ExecutionSurfaceShell<Primary: View, Supplementary: View>: View {
    let navRail: ExecutionSurfaceNavRail
    let title: ExecutionSurfaceTitle
    let status: ExecutionSurfaceStatus
    let state: ExecutionSurfaceSystemState
    let terminal: ExecutionSurfaceTerminal?
    let primary: Primary
    let supplementary: Supplementary
    let onReturnToChat: () -> Void

    init(
        navRail: ExecutionSurfaceNavRail,
        title: ExecutionSurfaceTitle,
        status: ExecutionSurfaceStatus = .none,
        state: ExecutionSurfaceSystemState = .ready,
        terminal: ExecutionSurfaceTerminal? = nil,
        onReturnToChat: @escaping () -> Void,
        @ViewBuilder primary: () -> Primary,
        @ViewBuilder supplementary: () -> Supplementary
    ) {
        self.navRail = navRail
        self.title = title
        self.status = status
        self.state = state
        self.terminal = terminal
        self.onReturnToChat = onReturnToChat
        self.primary = primary()
        self.supplementary = supplementary()
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: AppTheme.Metrics.sectionSpacing) {
                    heroRegion

                    primary

                    if state != .ready {
                        stateRegion
                    }

                    supplementary

                    if let terminal {
                        terminalRow(terminal)
                    }
                }
                .padding(.horizontal, AppTheme.Metrics.screenPadding)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: - Hero region (nav rail + title + status)

    private var heroRegion: some View {
        KAirSurface(style: .hero) {
            VStack(alignment: .leading, spacing: 16) {
                navRailRegion

                titleRegion

                if navRail.trustPills.isEmpty == false {
                    partnerSourceRow
                }

                if let statusStrip = statusStripView {
                    statusStrip
                }
            }
        }
    }

    // MARK: - Region 1: Nav rail

    private var navRailRegion: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: onReturnToChat) {
                KAirActionCapsule(
                    title: navRail.backToChatTitle,
                    systemImage: "chevron.left",
                    emphasized: false
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(navRail.backToChatTitle)
            .accessibilityIdentifier("execution-surface-back-to-chat")

            Spacer(minLength: 8)
        }
    }

    // MARK: - Region 2: Task title

    private var titleRegion: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.eyebrow.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1.0)
                .foregroundStyle(AppTheme.Palette.textMuted)

            Text(title.title)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AppTheme.Palette.textPrimary)

            Text(title.summary)
                .font(.body)
                .foregroundStyle(AppTheme.Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Region 5: Partner / source row (trust pills)

    private var partnerSourceRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(navRail.trustPills, id: \.self) { pill in
                    ActionCardTrustPill(kind: pill, isZh: navRail.isZh)
                }
            }
        }
        .accessibilityLabel(
            navRail.isZh ? "数据信任标签" : "Data trust labels"
        )
        .accessibilityIdentifier("execution-surface-trust-row")
    }

    // MARK: - Region 4: Status strip

    private var statusStripView: AnyView? {
        if let errorMessage = status.errorMessage, errorMessage.isEmpty == false {
            return AnyView(
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.warning)

                    Text(errorMessage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.warning)

                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.Metrics.compactRadius, style: .continuous)
                        .fill(AppTheme.Palette.warning.opacity(0.08))
                )
                .accessibilityIdentifier("execution-surface-error-strip")
            )
        }

        if let statusMessage = status.statusMessage, statusMessage.isEmpty == false {
            return AnyView(
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textMuted)

                    Text(statusMessage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textMuted)

                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.Metrics.compactRadius, style: .continuous)
                        .fill(Color.white.opacity(0.72))
                )
                .accessibilityIdentifier("execution-surface-status-strip")
            )
        }

        return nil
    }

    // MARK: - Region 6: State region

    private var stateRegion: some View {
        KAirSurface(style: .sunken) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: stateSystemImage)
                        .font(.headline)
                        .foregroundStyle(stateTint)

                    Text(stateTitleCopy)
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Spacer(minLength: 0)
                }

                Text(stateSummaryCopy)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)

                Button(action: onReturnToChat) {
                    KAirActionCapsule(
                        title: navRail.backToChatTitle,
                        systemImage: "bubble.left.and.bubble.right"
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityIdentifier("execution-surface-state-region-\(state.rawValue)")
    }

    private var stateSystemImage: String {
        switch state {
        case .ready:
            return "checkmark.circle"
        case .loading:
            return "hourglass"
        case .empty:
            return "tray"
        case .error:
            return "exclamationmark.triangle.fill"
        case .permissionOrUnavailable:
            return "lock.shield"
        }
    }

    private var stateTint: Color {
        switch state {
        case .ready:
            return AppTheme.Palette.success
        case .loading:
            return AppTheme.Palette.accentStrong
        case .empty:
            return AppTheme.Palette.textMuted
        case .error, .permissionOrUnavailable:
            return AppTheme.Palette.warning
        }
    }

    private var stateTitleCopy: String {
        ExecutionSurfaceLockedCopy.stateTitle(state, isZh: navRail.isZh)
    }

    private var stateSummaryCopy: String {
        ExecutionSurfaceLockedCopy.stateSummary(
            state,
            isZh: navRail.isZh,
            errorOverride: status.errorMessage
        )
    }

    // MARK: - Region 7: Terminal state row

    private func terminalRow(_ terminal: ExecutionSurfaceTerminal) -> some View {
        KAirSurface(style: .sunken) {
            HStack(spacing: 12) {
                Image(systemName: terminal.systemImage)
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.success)

                Text(terminal.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Spacer(minLength: 0)

                Button(action: onReturnToChat) {
                    KAirActionCapsule(
                        title: navRail.backToChatTitle,
                        systemImage: "bubble.left.and.bubble.right",
                        emphasized: false
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityIdentifier("execution-surface-terminal-row")
    }
}

// MARK: - Convenience for surfaces that don't need a secondary region

extension ExecutionSurfaceShell where Supplementary == EmptyView {
    init(
        navRail: ExecutionSurfaceNavRail,
        title: ExecutionSurfaceTitle,
        status: ExecutionSurfaceStatus = .none,
        state: ExecutionSurfaceSystemState = .ready,
        terminal: ExecutionSurfaceTerminal? = nil,
        onReturnToChat: @escaping () -> Void,
        @ViewBuilder primary: () -> Primary
    ) {
        self.init(
            navRail: navRail,
            title: title,
            status: status,
            state: state,
            terminal: terminal,
            onReturnToChat: onReturnToChat,
            primary: primary,
            supplementary: { EmptyView() }
        )
    }
}

// MARK: - Locked copy (source of truth for T6 + `execution-surface-framework-v1.md`)

/// Named accessors for the copy that belongs to the shell itself. The shell's
/// private computed vars delegate here, and T6 asserts against these helpers
/// — same source of truth as the rendering, no divergence possible.
enum ExecutionSurfaceLockedCopy {
    static func backToChat(isZh: Bool) -> String {
        isZh ? "返回聊天" : "Back to chat"
    }

    static func stateTitle(
        _ state: ExecutionSurfaceSystemState,
        isZh: Bool
    ) -> String {
        switch state {
        case .ready:
            return isZh ? "就绪" : "Ready"
        case .loading:
            return isZh ? "正在加载" : "Loading"
        case .empty:
            return isZh ? "暂无结果" : "Nothing to show"
        case .error:
            return isZh ? "出错了" : "Something went wrong"
        case .permissionOrUnavailable:
            return isZh ? "权限或服务不可用" : "Permission or service unavailable"
        }
    }

    static func stateSummary(
        _ state: ExecutionSurfaceSystemState,
        isZh: Bool,
        errorOverride: String? = nil
    ) -> String {
        switch state {
        case .ready:
            return ""
        case .loading:
            return isZh
                ? "正在准备这次任务，稍后回来即可。"
                : "Preparing this task — you can come back in a moment."
        case .empty:
            return isZh
                ? "这次没有匹配到内容，可以返回聊天换个说法再试。"
                : "No matches this time. Return to chat and try a different phrasing."
        case .error:
            if let errorOverride, errorOverride.isEmpty == false {
                return errorOverride
            }
            return isZh
                ? "出现了问题，可以返回聊天继续。"
                : "Something went wrong — returning to chat is safe."
        case .permissionOrUnavailable:
            return isZh
                ? "需要权限或服务暂不可用。可以返回聊天，或者在其他卡片中调整。"
                : "This needs a permission or a service that is not ready. Return to chat or adjust in another card."
        }
    }
}

// MARK: - Canonical inputs for contract tests

/// Exposes the view-model inputs a host supplied to the shell, in a form
/// tests can assert against without rendering the view. Use this from
/// `ExecutionSurfaceShellValidationTests` to lock the shared contract.
struct ExecutionSurfaceShellInputs: Hashable {
    let navRail: ExecutionSurfaceNavRail
    let title: ExecutionSurfaceTitle
    let status: ExecutionSurfaceStatus
    let state: ExecutionSurfaceSystemState
    let terminal: ExecutionSurfaceTerminal?
}
