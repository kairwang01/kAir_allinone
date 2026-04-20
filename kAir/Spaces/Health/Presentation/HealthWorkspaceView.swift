//
//  HealthWorkspaceView.swift
//  kAir
//
//  Health is a chat-invoked execution surface — pure caller of
//  `ExecutionSurfaceShell` + `ActionCardShell` per
//  `execution-surface-framework-v1.md`. No private nav rail, no private
//  empty state, no private trust vocabulary, no grandfather slot.
//

import SwiftUI

struct HealthWorkspaceView: View {
    let bootstrap: AppBootstrap
    let store: HealthDashboardStore

    @State private var selectedTab: DashboardTab = .overview

    private var activeSession: HealthRouteSession? {
        bootstrap.activeHealthSession
    }

    private var isZh: Bool {
        activeSession?.language == .chinese
    }

    var body: some View {
        ExecutionSurfaceShell(
            navRail: navRail(),
            title: titleInputs(),
            status: statusInputs(),
            state: systemState(),
            terminal: nil,
            onReturnToChat: bootstrap.returnToChat,
            primary: {
                HealthStatusCard(
                    phase: store.phase,
                    isZh: isZh,
                    dashboard: store.dashboard,
                    session: activeSession,
                    insufficientState: currentInsufficientState,
                    onPrimary: primaryAction,
                    onDismiss: bootstrap.returnToChat
                )
            },
            supplementary: {
                if case .loaded = store.phase,
                   let dashboard = store.dashboard,
                   currentInsufficientState == nil {
                    dashboardContent(dashboard)
                }
            }
        )
        .task {
            store.bootstrap()
        }
        .task(id: activeSession?.topic.rawValue) {
            if let activeSession {
                selectedTab = activeSession.topic.preferredTab
            }
        }
        .navigationTitle("Health")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: bootstrap.showProfile) {
                    Circle()
                        .fill(AppTheme.Palette.surfaceStrong)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Text("K")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.Palette.textOnStrong)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Shell input builders

    private var currentInsufficientState: HealthInsufficientState? {
        guard case .loaded = store.phase, let dashboard = store.dashboard else {
            return nil
        }
        return insufficientState(for: dashboard, session: activeSession)
    }

    private func navRail() -> ExecutionSurfaceNavRail {
        ExecutionSurfaceNavRail(
            backToChatTitle: ExecutionSurfaceLockedCopy.backToChat(isZh: isZh),
            trustPills: [],
            isZh: isZh
        )
    }

    private func titleInputs() -> ExecutionSurfaceTitle {
        let eyebrow = isZh ? "健康 · 聊天触达" : "Health · Chat-invoked"

        if case .loaded = store.phase,
           let dashboard = store.dashboard,
           currentInsufficientState == nil {
            return ExecutionSurfaceTitle(
                eyebrow: eyebrow,
                title: dashboard.title,
                summary: dashboard.hero.summary
            )
        }

        if let session = activeSession {
            return ExecutionSurfaceTitle(
                eyebrow: eyebrow,
                title: session.topic.title(for: session.language),
                summary: introSummary(for: session)
            )
        }

        return ExecutionSurfaceTitle(
            eyebrow: eyebrow,
            title: isZh ? "健康" : "Health",
            summary: isZh
                ? "Health 是按需打开的本地工作区。问 kAir 一个与健康相关的问题，它会在这里落地。"
                : "Health is an on-demand local workspace inside kAir. Ask a health question to land it here."
        )
    }

    private func statusInputs() -> ExecutionSurfaceStatus {
        switch store.phase {
        case .authorizing:
            return ExecutionSurfaceStatus(
                statusMessage: isZh ? "正在请求 HealthKit 权限" : "Requesting HealthKit permission",
                errorMessage: nil
            )
        case .loading:
            return ExecutionSurfaceStatus(
                statusMessage: store.statusMessage,
                errorMessage: nil
            )
        case .failed:
            return ExecutionSurfaceStatus(
                statusMessage: nil,
                errorMessage: store.errorMessage
            )
        case .intro, .loaded:
            return .none
        }
    }

    private func systemState() -> ExecutionSurfaceSystemState {
        switch store.phase {
        case .intro:
            return .permissionOrUnavailable
        case .authorizing, .loading:
            return .loading
        case .failed:
            return .error
        case .loaded:
            guard store.dashboard != nil else { return .loading }
            return currentInsufficientState == nil ? .ready : .empty
        }
    }

    private var primaryAction: () -> Void {
        switch store.phase {
        case .intro:
            return store.requestAccess
        case .failed, .loaded:
            return store.refresh
        case .authorizing, .loading:
            return {}
        }
    }

    @ViewBuilder
    private func dashboardContent(_ dashboard: HealthDashboard) -> some View {
        KAirSurface(style: .sunken, padding: 8) {
            Picker("Health Section", selection: $selectedTab) {
                ForEach(DashboardTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
        }

        switch selectedTab {
        case .overview:
            OverviewScreen(dashboard: dashboard, onRefresh: store.refresh)
        case .signals:
            SignalsScreen(dashboard: dashboard, onRefresh: store.refresh)
        case .data:
            DataLibraryScreen(dashboard: dashboard, onRefresh: store.refresh)
        }
    }

    // MARK: - Intro summary

    private func introSummary(for session: HealthRouteSession?) -> String {
        guard let session else {
            return isZh
                ? "Health 是按需打开的本地工作区。授权后会在这里给出结论、依据和限制说明。"
                : "Health is an on-demand workspace inside kAir. After authorization it stays local and answers here."
        }
        switch session.language {
        case .chinese:
            return "你刚刚问的是\(session.topic.title(for: .chinese))状态查询。授权后，Health 会在本地读取 Apple Health，并在这个页面里给出结论、依据和限制说明。"
        case .english:
            return "You just asked for a \(session.topic.title(for: .english).lowercased()) check. After authorization, Health will stay local to this device and answer here with a conclusion, evidence, and limitations."
        }
    }

    // MARK: - Insufficient-state detection (topic-focused gaps)

    private func insufficientState(
        for dashboard: HealthDashboard,
        session: HealthRouteSession?
    ) -> HealthInsufficientState? {
        let topic = session?.topic ?? .overall
        let language = session?.language
        let signalIDs = Set(dashboard.signals.filter { $0.samples.isEmpty == false }.map(\.id))

        switch topic {
        case .sleep:
            guard dashboard.sleepSummary.nightsTracked == 0 else { return nil }
            return HealthInsufficientState(
                title: localized("More sleep data needed", chinese: "需要更多睡眠数据", language: language),
                summary: localized(
                    "Health did not find recent sleep segments in Apple Health, so it cannot ground a sleep answer yet.",
                    chinese: "Health 还没有在 Apple Health 里找到最近的睡眠片段，因此现在还不能给出有依据的睡眠结论。",
                    language: language
                )
            )
        case .ecg:
            guard dashboard.ecgReadings.isEmpty else { return nil }
            return HealthInsufficientState(
                title: localized("No recent ECG data", chinese: "缺少最近 ECG 数据", language: language),
                summary: localized(
                    "This request focused on ECG, but there are no recent ECG readings available in the local Health window.",
                    chinese: "这次查询聚焦 ECG，但当前本地 Health 窗口里没有可用的近期 ECG 记录。",
                    language: language
                )
            )
        case .heart:
            let hasHeart = signalIDs.contains("heart_rate")
                || signalIDs.contains("resting_heart_rate")
                || dashboard.ecgReadings.isEmpty == false
            guard hasHeart == false else { return nil }
            return HealthInsufficientState(
                title: localized("Heart data is too thin", chinese: "心率数据不足", language: language),
                summary: localized(
                    "Health did not find enough recent heart-rate evidence to support this focused heart check.",
                    chinese: "Health 还没有找到足够的近期心率证据，无法支撑这次聚焦心率的查询。",
                    language: language
                )
            )
        case .recovery:
            let hasRecovery = signalIDs.contains("hrv")
                || signalIDs.contains("resting_heart_rate")
                || dashboard.sleepSummary.nightsTracked > 0
            guard hasRecovery == false else { return nil }
            return HealthInsufficientState(
                title: localized("Recovery data is too thin", chinese: "恢复数据不足", language: language),
                summary: localized(
                    "Health needs recent HRV, resting heart rate, or sleep evidence before it can judge recovery.",
                    chinese: "Health 需要最近的 HRV、静息心率或睡眠证据，才能判断恢复情况。",
                    language: language
                )
            )
        case .activity:
            let hasActivity = signalIDs.contains("steps") || dashboard.workouts.isEmpty == false
            guard hasActivity == false else { return nil }
            return HealthInsufficientState(
                title: localized("Activity data is too thin", chinese: "活动数据不足", language: language),
                summary: localized(
                    "Health did not find enough recent steps or workouts to ground an activity view yet.",
                    chinese: "Health 还没有找到足够的近期步数或训练记录，因此暂时不能给出有依据的活动视图。",
                    language: language
                )
            )
        case .overall:
            let connectedDomains = dashboard.dataSources.filter { $0.sampleCount > 0 }.count
            let hasOverallCoverage = connectedDomains >= 2
                || dashboard.sleepSummary.nightsTracked > 0
                || dashboard.workouts.isEmpty == false
                || dashboard.ecgReadings.isEmpty == false
            guard hasOverallCoverage == false else { return nil }
            return HealthInsufficientState(
                title: localized("Not enough local health evidence yet", chinese: "本地健康证据还不够", language: language),
                summary: localized(
                    "Health loaded successfully, but the recent local data is still too sparse for a reliable overall health view.",
                    chinese: "Health 已经打开，但最近的本地数据仍然太稀疏，暂时不足以支撑可靠的整体健康判断。",
                    language: language
                )
            )
        }
    }

    private func localized(
        _ english: String,
        chinese: String,
        language: HealthConversationLanguage?
    ) -> String {
        language == .chinese ? chinese : english
    }
}

// MARK: - Health-specific primary card (ActionCardShell-based)

private struct HealthStatusCard: View {
    let phase: HealthDashboardStore.Phase
    let isZh: Bool
    let dashboard: HealthDashboard?
    let session: HealthRouteSession?
    let insufficientState: HealthInsufficientState?
    let onPrimary: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ActionCardShell(
            headerLabelTitle: headerLabel,
            headerLabelSystemImage: headerGlyph,
            trustPills: [],
            isZh: isZh,
            title: cardTitle,
            subtitle: cardSubtitle,
            reasonText: reasonText,
            primaryActionTitle: primaryTitle,
            primaryEnabled: primaryEnabled,
            secondaryActionTitle: nil,
            feedbackAffordanceLabel: isZh ? "反馈选项" : "Feedback options",
            onCardTap: nil,
            onPrimaryAction: onPrimary,
            onSecondaryAction: nil,
            onFeedback: { _ in },
            onDismiss: onDismiss
        )
    }

    private var headerLabel: String {
        switch phase {
        case .intro:
            return isZh ? "连接 Apple Health" : "Connect Apple Health"
        case .authorizing:
            return isZh ? "正在授权" : "Authorizing"
        case .loading:
            return isZh ? "正在分析" : "Analyzing"
        case .failed:
            return isZh ? "需要处理" : "Needs attention"
        case .loaded:
            if insufficientState != nil {
                return isZh ? "数据不足" : "Data too thin"
            }
            return isZh ? "健康快照" : "Health snapshot"
        }
    }

    private var headerGlyph: String {
        switch phase {
        case .intro, .failed:
            return "lock.shield"
        case .authorizing, .loading:
            return "hourglass"
        case .loaded:
            return insufficientState == nil ? "heart.text.square" : "tray"
        }
    }

    private var cardTitle: String {
        if let insufficientState {
            return insufficientState.title
        }
        if let session {
            return session.topic.title(for: session.language)
        }
        return isZh ? "整体健康" : "Overall Health"
    }

    private var cardSubtitle: String {
        switch phase {
        case .intro:
            if let session {
                switch session.language {
                case .chinese:
                    return "授权后，Health 会基于本地 Apple Health 数据回答「\(session.originalPrompt)」。"
                case .english:
                    return "After authorization, Health will answer “\(session.originalPrompt)” locally from Apple Health."
                }
            }
            return isZh
                ? "授权后，Health 会在本地读取 Apple Health 数据并在此回答。"
                : "After authorization, Health reads Apple Health locally and answers here."
        case .authorizing:
            return isZh
                ? "正在请求 HealthKit 权限，这一步只会在设备上完成。"
                : "Requesting HealthKit permission. This step runs only on this device."
        case .loading:
            return isZh
                ? "正在分析本地 Apple Health 数据，所有推理都在设备上进行。"
                : "Analyzing local Apple Health data. All inference stays on this device."
        case .failed:
            return isZh
                ? "本地 Apple Health 数据暂时无法读取。可以重试，也可以返回聊天。"
                : "Local Apple Health data could not be read. Retry here or return to chat."
        case .loaded:
            if let insufficientState {
                return insufficientState.summary
            }
            if let dashboard {
                return dashboard.hero.summary
            }
            return isZh
                ? "kAir 已经就绪，正在准备本地健康快照。"
                : "kAir is ready. Preparing the local health snapshot."
        }
    }

    private var reasonText: String? {
        isZh
            ? "范围 · 仅本地  /  线程 · 同一会话  /  输出 · 摘要而非原始数据"
            : "Scope · Local only  /  Thread · Same conversation  /  Output · Summary only"
    }

    private var primaryTitle: String {
        switch phase {
        case .intro:
            return isZh ? "授权访问" : "Grant Access"
        case .authorizing:
            return isZh ? "正在授权…" : "Authorizing…"
        case .loading:
            return isZh ? "分析中…" : "Analyzing…"
        case .failed:
            return isZh ? "重试" : "Retry"
        case .loaded:
            return isZh ? "重新加载" : "Refresh"
        }
    }

    private var primaryEnabled: Bool {
        switch phase {
        case .authorizing, .loading:
            return false
        default:
            return true
        }
    }
}

// MARK: - Insufficient-state data (kept internal — the title/summary flow into the
// primary card's body; the shell renders the canonical empty-state region copy.)

private struct HealthInsufficientState {
    let title: String
    let summary: String
}
