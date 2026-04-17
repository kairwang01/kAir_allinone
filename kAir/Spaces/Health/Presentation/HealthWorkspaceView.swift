//
//  HealthWorkspaceView.swift
//  kAir
//
//  First-class health workspace inside kAir.
//

import SwiftUI

struct HealthWorkspaceView: View {
    let bootstrap: AppBootstrap
    let store: HealthDashboardStore

    @State private var selectedTab: DashboardTab = .overview

    private var activeSession: HealthRouteSession? {
        bootstrap.activeHealthSession
    }

    var body: some View {
        content
            .task {
                store.bootstrap()
            }
            .task(id: activeSession?.topic.rawValue) {
                if let activeSession {
                    selectedTab = activeSession.topic.preferredTab
                }
            }
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

    @ViewBuilder
    private var content: some View {
        switch store.phase {
        case .loaded:
            if let dashboard = store.dashboard {
                if let insufficientState = insufficientState(for: dashboard, session: activeSession) {
                    stateScaffold(
                        title: insufficientState.title,
                        summary: insufficientState.summary,
                        metrics: insufficientState.metrics,
                        limitation: insufficientState.limitation,
                        actionTitle: activeSession?.language == .chinese ? "重新加载" : "Refresh",
                        action: store.refresh
                    )
                } else {
                    loadedContent(dashboard)
                }
            } else {
                stateScaffold(
                    title: "Preparing Health",
                    summary: "kAir is ready, but the local health snapshot is still being prepared.",
                    metrics: defaultStateMetrics(language: activeSession?.language),
                    limitation: "The thread remains intact while Health prepares the local workspace.",
                    actionTitle: nil,
                    action: nil
                )
            }
        case .intro:
            stateScaffold(
                title: "Connect Apple Health",
                summary: introSummary(for: activeSession),
                metrics: introMetrics(for: activeSession),
                limitation: introLimitation(for: activeSession?.language),
                actionTitle: activeSession?.language == .chinese ? "授权访问" : "Grant Access",
                action: store.requestAccess
            )
        case .authorizing:
            stateScaffold(
                title: "Authorizing",
                summary: "Requesting permission to read HealthKit on this device.",
                metrics: defaultStateMetrics(language: activeSession?.language),
                limitation: introLimitation(for: activeSession?.language),
                actionTitle: nil,
                action: nil
            )
        case .loading:
            stateScaffold(
                title: "Analyzing Local Data",
                summary: store.statusMessage,
                metrics: defaultStateMetrics(language: activeSession?.language),
                limitation: introLimitation(for: activeSession?.language),
                actionTitle: nil,
                action: nil
            )
        case .failed:
            stateScaffold(
                title: "Health Needs Attention",
                summary: store.errorMessage ?? "Unable to load local Apple Health data.",
                metrics: defaultStateMetrics(language: activeSession?.language),
                limitation: "Health data stays on this device even when loading fails.",
                actionTitle: activeSession?.language == .chinese ? "重试" : "Retry",
                action: store.refresh
            )
        }
    }

    private func loadedContent(_ dashboard: HealthDashboard) -> some View {
        currentDashboardView(dashboard)
            .safeAreaInset(edge: .top) {
                VStack(spacing: 12) {
                    KAirSurface(style: .hero) {
                        VStack(alignment: .leading, spacing: 14) {
                            KAirPageHeader(
                                title: "Health",
                                summary: dashboard.hero.summary,
                                badges: headerBadges(for: dashboard)
                            )

                            Button {
                                bootstrap.closeSurface()
                            } label: {
                                KAirActionCapsule(
                                    title: backToChatTitle(for: activeSession?.language),
                                    systemImage: "bubble.left.and.bubble.right"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    KAirSurface(style: .sunken, padding: 8) {
                        Picker("Health Section", selection: $selectedTab) {
                            ForEach(DashboardTab.allCases) { tab in
                                Text(tab.title).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .padding(.horizontal, AppTheme.Metrics.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 4)
                .background(Color.white)
            }
    }

    @ViewBuilder
    private func currentDashboardView(_ dashboard: HealthDashboard) -> some View {
        switch selectedTab {
        case .overview:
            OverviewScreen(dashboard: dashboard, onRefresh: store.refresh)
        case .signals:
            SignalsScreen(dashboard: dashboard, onRefresh: store.refresh)
        case .data:
            DataLibraryScreen(dashboard: dashboard, onRefresh: store.refresh)
        }
    }

    private func stateScaffold(
        title: String,
        summary: String,
        metrics: [HealthStateMetric],
        limitation: String?,
        actionTitle: String?,
        action: (() -> Void)?
    ) -> some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: AppTheme.Metrics.sectionSpacing) {
                    KAirSurface(style: .hero) {
                        KAirPageHeader(
                            title: "Health",
                            summary: "An on-demand local Health workspace inside the larger kAir shell.",
                            badges: [
                                KAirHeaderBadge(title: "Local-only", systemImage: "lock.shield", tint: AppTheme.Palette.success)
                            ]
                        )
                    }

                    KAirSurface {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(title)
                                .font(.headline)
                                .foregroundStyle(AppTheme.Palette.textPrimary)

                            Text(summary)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.Palette.textSecondary)

                            if metrics.isEmpty == false {
                                LazyVGrid(
                                    columns: [GridItem(.adaptive(minimum: 120), spacing: 8)],
                                    alignment: .leading,
                                    spacing: 8
                                ) {
                                    ForEach(metrics) { metric in
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
                                            .fill(AppTheme.Palette.surface)
                                        )
                                    }
                                }
                            }

                            if let limitation, limitation.isEmpty == false {
                                Text(limitation)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.Palette.textMuted)
                            }

                            if let actionTitle, let action {
                                Button(actionTitle, action: action)
                                    .buttonStyle(.borderedProminent)
                                    .tint(AppTheme.Palette.accentStrong)
                            } else {
                                ProgressView()
                                    .tint(AppTheme.Palette.accent)
                            }
                        }
                    }

                    KAirSurface(style: .sunken) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("What stays true")
                                .font(.headline)
                                .foregroundStyle(AppTheme.Palette.textPrimary)

                            bullet("Apple Health data stays local to this device.")
                            bullet("Chat can summarize this workspace without replacing it.")
                            bullet("AI, Maps, and Store now sit beside Health, not under it.")
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Metrics.screenPadding)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Health")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func headerBadges(for dashboard: HealthDashboard) -> [KAirHeaderBadge] {
        var badges = [
            KAirHeaderBadge(title: "On-device", systemImage: "lock.shield", tint: AppTheme.Palette.success),
            KAirHeaderBadge(title: dashboard.hero.band, systemImage: "waveform.path.ecg", tint: AppTheme.statusTint(for: dashboard.hero.band)),
            KAirHeaderBadge(title: dashboard.generatedAt.formatted(.dateTime.hour().minute()), systemImage: "clock", tint: AppTheme.Palette.sky)
        ]

        if let activeSession {
            badges.insert(
                KAirHeaderBadge(
                    title: activeSession.topic.title(for: activeSession.language),
                    systemImage: activeSession.topic.systemImage,
                    tint: AppTheme.Palette.warning
                ),
                at: 1
            )
        }

        return badges
    }

    private func backToChatTitle(for language: HealthConversationLanguage?) -> String {
        switch language {
        case .chinese:
            return "返回聊天"
        case .english, .none:
            return "Back to chat"
        }
    }

    private func introSummary(for session: HealthRouteSession?) -> String {
        guard let session else {
            return "Health is an on-demand workspace inside kAir. Authorize only when you want this thread to use local HealthKit data."
        }

        switch session.language {
        case .chinese:
            return "你刚刚问的是\(session.topic.title(for: .chinese))状态查询。授权后，Health 会在本地读取 Apple Health，并在这个页面里给出结论、依据和限制说明。"
        case .english:
            return "You just asked for a \(session.topic.title(for: .english).lowercased()) check. After authorization, Health will stay local to this device and answer here with a conclusion, evidence, and limitations."
        }
    }

    private func introMetrics(for session: HealthRouteSession?) -> [HealthStateMetric] {
        let language = session?.language
        var metrics = defaultStateMetrics(language: language)

        if let session {
            switch session.language {
            case .chinese:
                metrics.insert(.init(key: "主题", value: session.topic.title(for: .chinese)), at: 0)
                metrics[1] = .init(key: "线程", value: "同一会话")
            case .english:
                metrics.insert(.init(key: "Topic", value: session.topic.title(for: .english)), at: 0)
            }
        }

        return metrics
    }

    private func introLimitation(for language: HealthConversationLanguage?) -> String {
        switch language {
        case .chinese:
            return "聊天层只保留摘要；原始 Health 数据不会离开这台设备。"
        case .english, .none:
            return "Chat keeps only the summary. Raw Health data does not leave this device."
        }
    }

    private func defaultStateMetrics(language: HealthConversationLanguage?) -> [HealthStateMetric] {
        switch language {
        case .chinese:
            return [
                .init(key: "范围", value: "仅本地"),
                .init(key: "线程", value: "同一会话"),
                .init(key: "输出", value: "摘要而非原始数据")
            ]
        case .english, .none:
            return [
                .init(key: "Scope", value: "Local only"),
                .init(key: "Thread", value: "Same conversation"),
                .init(key: "Output", value: "Summary only")
            ]
        }
    }

    private func insufficientState(
        for dashboard: HealthDashboard,
        session: HealthRouteSession?
    ) -> HealthInsufficientState? {
        let topic = session?.topic ?? .overall
        let language = session?.language
        let connectedDomains = dashboard.dataSources.filter { $0.sampleCount > 0 }.count
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
                ),
                metrics: [
                    metric("Sleep nights", chineseKey: "睡眠夜数", value: "\(dashboard.sleepSummary.nightsTracked)", language: language),
                    metric("Connected domains", chineseKey: "已连接域", value: "\(connectedDomains)", language: language),
                    metric("Thread", chineseKey: "线程", value: localized("Same conversation", chinese: "同一会话", language: language), language: language)
                ],
                limitation: localized(
                    "A reliable sleep answer needs recent sleep segments from Apple Health.",
                    chinese: "想得到可靠的睡眠回答，至少需要最近的 Apple Health 睡眠片段。",
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
                ),
                metrics: [
                    metric("ECG readings", chineseKey: "ECG 记录", value: "\(dashboard.ecgReadings.count)", language: language),
                    metric("Connected domains", chineseKey: "已连接域", value: "\(connectedDomains)", language: language),
                    metric("Thread", chineseKey: "线程", value: localized("Same conversation", chinese: "同一会话", language: language), language: language)
                ],
                limitation: localized(
                    "Health can only ground ECG answers from ECG data that already exists locally in Apple Health.",
                    chinese: "Health 只能基于本地 Apple Health 里已有的 ECG 数据来完成这类回答。",
                    language: language
                )
            )
        case .heart:
            guard signalIDs.contains("heart_rate") || signalIDs.contains("resting_heart_rate") || dashboard.ecgReadings.isEmpty == false else {
                return HealthInsufficientState(
                    title: localized("Heart data is too thin", chinese: "心率数据不足", language: language),
                    summary: localized(
                        "Health did not find enough recent heart-rate evidence to support this focused heart check.",
                        chinese: "Health 还没有找到足够的近期心率证据，无法支撑这次聚焦心率的查询。",
                        language: language
                    ),
                    metrics: [
                        metric("Heart signals", chineseKey: "心率信号", value: "0", language: language),
                        metric("ECG readings", chineseKey: "ECG 记录", value: "\(dashboard.ecgReadings.count)", language: language),
                        metric("Connected domains", chineseKey: "已连接域", value: "\(connectedDomains)", language: language)
                    ],
                    limitation: localized(
                        "A heart-focused answer needs recent heart-rate, resting-heart-rate, or ECG evidence.",
                        chinese: "想得到可靠的心率回答，至少需要近期心率、静息心率或 ECG 证据。",
                        language: language
                    )
                )
            }
            return nil
        case .recovery:
            guard signalIDs.contains("hrv") || signalIDs.contains("resting_heart_rate") || dashboard.sleepSummary.nightsTracked > 0 else {
                return HealthInsufficientState(
                    title: localized("Recovery data is too thin", chinese: "恢复数据不足", language: language),
                    summary: localized(
                        "Health needs recent HRV, resting heart rate, or sleep evidence before it can judge recovery.",
                        chinese: "Health 需要最近的 HRV、静息心率或睡眠证据，才能判断恢复情况。",
                        language: language
                    ),
                    metrics: [
                        metric("Sleep nights", chineseKey: "睡眠夜数", value: "\(dashboard.sleepSummary.nightsTracked)", language: language),
                        metric("Recovery signals", chineseKey: "恢复信号", value: "\(signalIDs.intersection(["hrv", "resting_heart_rate"]).count)", language: language),
                        metric("Connected domains", chineseKey: "已连接域", value: "\(connectedDomains)", language: language)
                    ],
                    limitation: localized(
                        "Recovery answers are limited without sleep or cardiovascular recovery signals.",
                        chinese: "如果没有睡眠或恢复相关心血管信号，恢复结论会不可靠。",
                        language: language
                    )
                )
            }
            return nil
        case .activity:
            guard signalIDs.contains("steps") || dashboard.workouts.isEmpty == false else {
                return HealthInsufficientState(
                    title: localized("Activity data is too thin", chinese: "活动数据不足", language: language),
                    summary: localized(
                        "Health did not find enough recent steps or workouts to ground an activity view yet.",
                        chinese: "Health 还没有找到足够的近期步数或训练记录，因此暂时不能给出有依据的活动视图。",
                        language: language
                    ),
                    metrics: [
                        metric("Workouts", chineseKey: "训练", value: "\(dashboard.workouts.count)", language: language),
                        metric("Steps signal", chineseKey: "步数信号", value: signalIDs.contains("steps") ? "1" : "0", language: language),
                        metric("Connected domains", chineseKey: "已连接域", value: "\(connectedDomains)", language: language)
                    ],
                    limitation: localized(
                        "A focused activity answer needs recent steps or workouts in Apple Health.",
                        chinese: "想得到可靠的活动回答，至少需要 Apple Health 里的近期步数或训练数据。",
                        language: language
                    )
                )
            }
            return nil
        case .overall:
            let hasOverallCoverage = connectedDomains >= 2 ||
                dashboard.sleepSummary.nightsTracked > 0 ||
                dashboard.workouts.isEmpty == false ||
                dashboard.ecgReadings.isEmpty == false
            guard hasOverallCoverage else {
                return HealthInsufficientState(
                    title: localized("Not enough local health evidence yet", chinese: "本地健康证据还不够", language: language),
                    summary: localized(
                        "Health loaded successfully, but the recent local data is still too sparse for a reliable overall health view.",
                        chinese: "Health 已经打开，但最近的本地数据仍然太稀疏，暂时不足以支撑可靠的整体健康判断。",
                        language: language
                    ),
                    metrics: [
                        metric("Connected domains", chineseKey: "已连接域", value: "\(connectedDomains)", language: language),
                        metric("Sleep nights", chineseKey: "睡眠夜数", value: "\(dashboard.sleepSummary.nightsTracked)", language: language),
                        metric("Workouts", chineseKey: "训练", value: "\(dashboard.workouts.count)", language: language)
                    ],
                    limitation: localized(
                        "The page will stay in this thread, but it needs more recent Health data before the overall conclusion becomes reliable.",
                        chinese: "页面仍然属于同一会话，但要让整体结论可靠，还需要更多近期 Health 数据。",
                        language: language
                    )
                )
            }
            return nil
        }
    }

    private func metric(
        _ key: String,
        chineseKey: String,
        value: String,
        language: HealthConversationLanguage?
    ) -> HealthStateMetric {
        HealthStateMetric(
            key: language == .chinese ? chineseKey : key,
            value: value
        )
    }

    private func localized(
        _ english: String,
        chinese: String,
        language: HealthConversationLanguage?
    ) -> String {
        language == .chinese ? chinese : english
    }

    private func bullet(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(.subheadline)
            .foregroundStyle(AppTheme.Palette.textSecondary)
    }
}

private struct HealthStateMetric: Identifiable {
    let key: String
    let value: String

    var id: String { key }
}

private struct HealthInsufficientState {
    let title: String
    let summary: String
    let metrics: [HealthStateMetric]
    let limitation: String
}
