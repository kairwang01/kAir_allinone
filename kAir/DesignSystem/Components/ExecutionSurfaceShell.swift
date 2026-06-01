//
//  ExecutionSurfaceShell.swift
//  kAir
//
//  The single Execution Surface primitive for every chat-portaled
//  vertical (Maps, AI, Store, Health, Music, Search, …).
//
//  Contract:
//    - Docs/design/execution-surface-framework-v1.md §1–§11
//      (7 regions, 5 system states, one locked Back-to-chat path).
//    - Docs/design/super-app-visual-system-v1.md §5.2 / §9 (locked
//      state vocabulary + copy) and §14 / §16 (the T6 lock list this
//      type family must satisfy, and the A1 roadmap this file opens).
//
//  A1 — ExecutionSurfaceShell primitive:
//    - Skel introduced the shell type family.
//    - I1 migrated the built production callers: Maps, AI, Store,
//      and Health.
//    - Chat Home is unchanged; Music / Search are not implemented.
//
//  Every numeric / color / typography / elevation token resolves
//  through `AppTheme` (Contracts/Design/design-system-v1.md, ratified).
//  The primary region (3) is a caller-supplied slot that, per framework
//  §4, must host an `ActionCardShell`-based card.
//

import SwiftUI

// MARK: - Region (6) system state

/// The five — and only five — Execution Surface system states
/// (framework §3, visual-system §9.1). `.ready` is the single
/// non-terminal state; the other four are the degraded paths every
/// surface must handle. A vertical cannot add a sixth — that is a data
/// problem, not a new state.
///
/// T6 `ExecutionSurfaceShellValidationTests` asserts
/// `allCases.count == 5` (visual-system §14, framework §8 #1).
enum ExecutionSurfaceSystemState: String, CaseIterable, Hashable {
    case ready
    case loading
    case empty
    case error
    case permissionOrUnavailable

    /// State → SF Symbol, per visual-system §4.4.
    var iconSystemImage: String {
        switch self {
        case .ready:                   return "checkmark.circle"
        case .loading:                 return "hourglass"
        case .empty:                   return "tray"
        case .error:                   return "exclamationmark.triangle.fill"
        case .permissionOrUnavailable: return "lock.shield"
        }
    }

    /// State → tint role, per visual-system §4.4. Resolved through
    /// `AppTheme.Palette` (design-system-v1, ratified) — never a raw
    /// color.
    var tint: Color {
        switch self {
        case .ready:                   return AppTheme.Palette.success
        case .loading:                 return AppTheme.Palette.accentStrong
        case .empty:                   return AppTheme.Palette.textMuted
        case .error:                   return AppTheme.Palette.warning
        case .permissionOrUnavailable: return AppTheme.Palette.warning
        }
    }
}

// MARK: - Language

/// The two locked languages (visual-system §10.1). Kept local to the
/// shell so the locked-copy table has a deterministic input for the T6
/// "copy locked per zh/en" assertions. Verticals map their own language
/// value onto this at the I1 call site (there is no shared app-wide
/// language enum today — Maps/Music/Search each carry their own).
enum ExecutionSurfaceLanguage: String, CaseIterable, Hashable {
    case english
    case chinese
}

// MARK: - Locked copy

/// Frozen state + back-to-chat copy (visual-system §9.2). The shell owns
/// these strings; verticals cannot override them — except the `.error`
/// summary, which `ExecutionSurfaceStatus.errorMessage` replaces when
/// non-empty (§9.2 error-summary override rule, implemented in
/// `ExecutionSurfaceShellInputs.resolvedStateSummary`).
enum ExecutionSurfaceLockedCopy {
    static func backToChat(_ language: ExecutionSurfaceLanguage) -> String {
        switch language {
        case .english: return "Back to chat"
        case .chinese: return "返回聊天"
        }
    }

    static func stateTitle(_ state: ExecutionSurfaceSystemState,
                           _ language: ExecutionSurfaceLanguage) -> String {
        switch (state, language) {
        case (.ready, .english):                   return "Ready"
        case (.ready, .chinese):                   return "就绪"
        case (.loading, .english):                 return "Loading"
        case (.loading, .chinese):                 return "正在加载"
        case (.empty, .english):                   return "Nothing to show"
        case (.empty, .chinese):                   return "暂无结果"
        case (.error, .english):                   return "Something went wrong"
        case (.error, .chinese):                   return "出错了"
        case (.permissionOrUnavailable, .english): return "Permission or service unavailable"
        case (.permissionOrUnavailable, .chinese): return "权限或服务不可用"
        }
    }

    static func stateSummary(_ state: ExecutionSurfaceSystemState,
                             _ language: ExecutionSurfaceLanguage) -> String {
        switch (state, language) {
        case (.ready, _):
            return ""
        case (.loading, .english):
            return "Preparing this task — you can come back in a moment."
        case (.loading, .chinese):
            return "正在准备这次任务，稍后回来即可。"
        case (.empty, .english):
            return "No matches this time. Return to chat and try a different phrasing."
        case (.empty, .chinese):
            return "这次没有匹配到内容，可以返回聊天换个说法再试。"
        case (.error, .english):
            return "Something went wrong — returning to chat is safe."
        case (.error, .chinese):
            return "出现了问题，可以返回聊天继续。"
        case (.permissionOrUnavailable, .english):
            return "This needs a permission or a service that is not ready. Return to chat or adjust in another card."
        case (.permissionOrUnavailable, .chinese):
            return "需要权限或服务暂不可用。可以返回聊天，或者在其他卡片中调整。"
        }
    }
}

// MARK: - Region input types

/// Region (1) nav rail + the source of the region (5) partner/source
/// pills (framework §1 type table). The back-to-chat copy + style are
/// locked, so the rail itself only carries the trust-pill selection,
/// drawn from the shared `ActionCardTrustPillKind` vocabulary (T8 guard:
/// no surface-private pill type).
struct ExecutionSurfaceNavRail: Equatable, Hashable {
    var trustPills: [ActionCardTrustPillKind]

    init(trustPills: [ActionCardTrustPillKind] = []) {
        self.trustPills = trustPills
    }
}

/// Region (2) task title — eyebrow + display title + body summary
/// (framework §1, visual-system §2). Copy only; the shell owns type.
struct ExecutionSurfaceTitle: Equatable, Hashable {
    var eyebrow: String
    var title: String
    var summary: String

    init(eyebrow: String, title: String, summary: String) {
        self.eyebrow = eyebrow
        self.title = title
        self.summary = summary
    }
}

/// Region (4) status strip — status message OR error message, never
/// both (framework §1). Error wins over status; see `statusRegion`.
struct ExecutionSurfaceStatus: Equatable, Hashable {
    var statusMessage: String?
    var errorMessage: String?

    init(statusMessage: String? = nil, errorMessage: String? = nil) {
        self.statusMessage = statusMessage
        self.errorMessage = errorMessage
    }
}

/// Region (7) terminal-state row — the surface-local "done" banner
/// (framework §6). Optional; title + glyph only. Rendered with the
/// `success` tint per visual-system §8.
struct ExecutionSurfaceTerminal: Equatable, Hashable {
    var title: String
    var systemImage: String

    init(title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }
}

// MARK: - Inputs aggregate

/// The 7 regions' data, 1:1 with the framework regions (framework §8
/// T6 #4). `Equatable` so the T6 lock test can assert "a Maps surface
/// and a Music surface with identical inputs produce identical shell
/// inputs." The primary / supplementary slots are *views*, not data,
/// and are passed to the shell separately.
struct ExecutionSurfaceShellInputs: Equatable, Hashable {
    var navRail: ExecutionSurfaceNavRail
    var title: ExecutionSurfaceTitle
    var status: ExecutionSurfaceStatus
    var state: ExecutionSurfaceSystemState
    var terminal: ExecutionSurfaceTerminal?
    var language: ExecutionSurfaceLanguage

    init(navRail: ExecutionSurfaceNavRail = ExecutionSurfaceNavRail(),
         title: ExecutionSurfaceTitle,
         status: ExecutionSurfaceStatus = ExecutionSurfaceStatus(),
         state: ExecutionSurfaceSystemState,
         terminal: ExecutionSurfaceTerminal? = nil,
         language: ExecutionSurfaceLanguage = .english) {
        self.navRail = navRail
        self.title = title
        self.status = status
        self.state = state
        self.terminal = terminal
        self.language = language
    }

    /// The region (6) summary, applying the visual-system §9.2
    /// error-summary override: when `state == .error` and
    /// `status.errorMessage` is non-empty, that message replaces the
    /// locked error summary. Every other state uses the locked summary
    /// verbatim (an empty `errorMessage` falls back to locked copy).
    var resolvedStateSummary: String {
        if state == .error, let message = status.errorMessage, message.isEmpty == false {
            return message
        }
        return ExecutionSurfaceLockedCopy.stateSummary(state, language)
    }
}

/// The single accessibility identifier shared by every back-to-chat
/// control on every surface (framework §2: "identical across all
/// verticals"). Region (1), region (6), and region (7) all carry it.
let executionSurfaceBackToChatAccessibilityIdentifier = "execution-surface-back-to-chat"

// MARK: - ExecutionSurfaceShell

/// The frozen 7-region Execution Surface shell. Verticals are *pure
/// callers*: they supply `inputs`, an `onReturnToChat` closure (which at
/// the I1 call site forwards to `AppBootstrap.recordSurfaceReturn(...)`),
/// and the region (3) primary slot (an `ActionCardShell`-based card).
/// Verticals may not re-implement the nav rail, the state vocabulary,
/// the back-to-chat copy, or the status strip (framework §4).
struct ExecutionSurfaceShell<Primary: View, Supplementary: View>: View {
    private let inputs: ExecutionSurfaceShellInputs
    private let onReturnToChat: () -> Void
    /// When `true` (default) the shell wraps its region stack in a
    /// `ScrollView`. A vertical whose primary content is itself a
    /// scrolling view — e.g. Health's `.ready` dashboard, where
    /// `OverviewScreen` / `SignalsScreen` / `DataLibraryScreen` each host
    /// their own `ScrollView` — passes `false`, so the regions form a
    /// fixed header and the caller's `supplementary` owns the single
    /// scroll (no nested vertical scroll). This changes no region, copy,
    /// state, or the `ExecutionSurfaceShellInputs` shape; Maps / AI /
    /// Store keep the default.
    private let scrolls: Bool
    private let primary: Primary
    private let supplementary: Supplementary

    init(inputs: ExecutionSurfaceShellInputs,
         onReturnToChat: @escaping () -> Void,
         scrolls: Bool = true,
         @ViewBuilder primary: () -> Primary,
         @ViewBuilder supplementary: () -> Supplementary) {
        self.inputs = inputs
        self.onReturnToChat = onReturnToChat
        self.scrolls = scrolls
        self.primary = primary()
        self.supplementary = supplementary()
    }

    private var language: ExecutionSurfaceLanguage { inputs.language }

    var body: some View {
        Group {
            if scrolls {
                ScrollView { regionStack }
            } else {
                // Fixed header + caller-owned scroll: the `supplementary`
                // provides the single scrolling region (Health `.ready`).
                regionStack
            }
        }
        .background(AppTheme.Palette.backgroundStart.ignoresSafeArea())
    }

    private var regionStack: some View {
        VStack(alignment: .leading, spacing: AppTheme.Metrics.sectionSpacing) {
            navRailRegion       // (1)
            titleRegion         // (2)
            partnerRegion       // (5)
            statusRegion        // (4)
            primaryRegion       // (3)
            stateRegion         // (6) — only when state != .ready
            supplementary       // vertical "rest of page" below state
            terminalRegion      // (7) — optional, final row per §6
        }
        .padding(.horizontal, AppTheme.Metrics.screenPadding)
        .padding(.vertical, AppTheme.Metrics.sectionSpacing)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Region (1) — nav rail

    private var navRailRegion: some View {
        HStack {
            backToChatButton()
            Spacer(minLength: 0)
        }
    }

    /// The locked back-to-chat capsule (framework §2): fixed copy, fixed
    /// `KAirActionCapsule` style (`emphasized: false`), one shared
    /// accessibility identifier, routes to `onReturnToChat`.
    private func backToChatButton() -> some View {
        Button(action: onReturnToChat) {
            KAirActionCapsule(
                title: ExecutionSurfaceLockedCopy.backToChat(language),
                systemImage: "chevron.left",
                emphasized: false
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(executionSurfaceBackToChatAccessibilityIdentifier)
        .accessibilityLabel(Text(ExecutionSurfaceLockedCopy.backToChat(language)))
    }

    // MARK: Region (2) — task title

    private var titleRegion: some View {
        VStack(alignment: .leading, spacing: 8) {
            if inputs.title.eyebrow.isEmpty == false {
                Text(inputs.title.eyebrow.uppercased())
                    .kAirTypography(AppTheme.Typography.eyebrow)
                    .foregroundStyle(AppTheme.Palette.textMuted)
            }

            Text(inputs.title.title)
                .kAirTypography(AppTheme.Typography.display)
                .foregroundStyle(AppTheme.Palette.textPrimary)

            if inputs.title.summary.isEmpty == false {
                Text(inputs.title.summary)
                    .kAirTypography(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Region (5) — partner / source row

    @ViewBuilder
    private var partnerRegion: some View {
        if inputs.navRail.trustPills.isEmpty == false {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ActionCardShell.trustPillSpacing) {
                    ForEach(inputs.navRail.trustPills, id: \.self) { pill in
                        ActionCardTrustPill(kind: pill)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: Region (4) — status strip (status OR error, never both)

    @ViewBuilder
    private var statusRegion: some View {
        if let error = inputs.status.errorMessage, error.isEmpty == false {
            statusStrip(
                text: error,
                tint: AppTheme.Palette.warning,
                systemImage: "exclamationmark.triangle.fill"
            )
        } else if let status = inputs.status.statusMessage, status.isEmpty == false {
            statusStrip(
                text: status,
                tint: AppTheme.Palette.textMuted,
                systemImage: "info.circle"
            )
        }
    }

    private func statusStrip(text: String, tint: Color, systemImage: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
            Text(text)
                .kAirTypography(AppTheme.Typography.chip)
            Spacer(minLength: 0)
        }
        .foregroundStyle(tint)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Region (3) — primary action (caller-supplied ActionCardShell)

    private var primaryRegion: some View {
        primary
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Region (6) — system-state region (collapses when .ready)

    @ViewBuilder
    private var stateRegion: some View {
        if inputs.state != .ready {
            KAirSurface(style: .sunken) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: inputs.state.iconSystemImage)
                            .font(.headline)
                            .foregroundStyle(inputs.state.tint)
                        Text(ExecutionSurfaceLockedCopy.stateTitle(inputs.state, language))
                            .kAirTypography(AppTheme.Typography.sectionTitle)
                            .foregroundStyle(AppTheme.Palette.textPrimary)
                    }

                    if inputs.resolvedStateSummary.isEmpty == false {
                        Text(inputs.resolvedStateSummary)
                            .kAirTypography(AppTheme.Typography.body)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }

                    backToChatButton()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: Region (7) — terminal-state row (optional)

    @ViewBuilder
    private var terminalRegion: some View {
        if let terminal = inputs.terminal {
            KAirSurface(style: .sunken) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: terminal.systemImage)
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.success)
                        Text(terminal.title)
                            .kAirTypography(AppTheme.Typography.sectionTitle)
                            .foregroundStyle(AppTheme.Palette.textPrimary)
                    }

                    backToChatButton()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Convenience init (no supplementary region)

extension ExecutionSurfaceShell where Supplementary == EmptyView {
    init(inputs: ExecutionSurfaceShellInputs,
         onReturnToChat: @escaping () -> Void,
         @ViewBuilder primary: () -> Primary) {
        self.init(
            inputs: inputs,
            onReturnToChat: onReturnToChat,
            primary: primary,
            supplementary: { EmptyView() }
        )
    }
}

// MARK: - Previews
//
// Skel exercise only. These previews host an existing `ActionCardShell`
// fixture in the primary slot to prove region (3) accepts the shared
// card primitive. No surface is migrated by this file.

#Preview("ready · en") {
    ExecutionSurfaceShell(
        inputs: ExecutionSurfaceShellInputs(
            navRail: ExecutionSurfaceNavRail(trustPills: [.placeResolutionStub, .partnerFallback]),
            title: ExecutionSurfaceTitle(
                eyebrow: "Maps",
                title: "Route to Blue Bottle",
                summary: "Two candidate routes are ready. Pick one to open it in Maps."
            ),
            status: ExecutionSurfaceStatus(statusMessage: "Using estimated ETA"),
            state: .ready,
            language: .english
        ),
        onReturnToChat: {}
    ) {
        ActionCardShell(object: RecommendationFixtures.placeRoute)
    }
}

#Preview("permission · zh") {
    ExecutionSurfaceShell(
        inputs: ExecutionSurfaceShellInputs(
            navRail: ExecutionSurfaceNavRail(trustPills: [.locationPermissionDenied]),
            title: ExecutionSurfaceTitle(
                eyebrow: "地图",
                title: "附近的咖啡馆",
                summary: "需要定位权限来查找附近地点。"
            ),
            state: .permissionOrUnavailable,
            language: .chinese
        ),
        onReturnToChat: {}
    ) {
        ActionCardShell(object: RecommendationFixtures.placeRoute)
    }
}

#Preview("error · terminal · en") {
    ExecutionSurfaceShell(
        inputs: ExecutionSurfaceShellInputs(
            title: ExecutionSurfaceTitle(
                eyebrow: "Maps",
                title: "Route to Blue Bottle",
                summary: "We hit a problem talking to the routing provider."
            ),
            status: ExecutionSurfaceStatus(errorMessage: "Routing provider timed out."),
            state: .error,
            terminal: ExecutionSurfaceTerminal(title: "Arrived", systemImage: "flag.checkered"),
            language: .english
        ),
        onReturnToChat: {}
    ) {
        ActionCardShell(object: RecommendationFixtures.placeRoute)
    }
}
