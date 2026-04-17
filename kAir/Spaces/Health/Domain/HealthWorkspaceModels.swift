//
//  HealthWorkspaceModels.swift
//  kAir
//
//  Workspace boundary for the Health space.
//  This layer intentionally adapts the existing dashboard domain instead of
//  moving the old implementation on day one.
//

import Foundation

typealias HealthWorkspaceDashboard = HealthDashboard
typealias HealthWorkspaceInsight = InsightCard
typealias HealthWorkspaceSignal = SignalSeries
typealias HealthWorkspaceModelWatchpoint = ConditionPrediction
typealias HealthWorkspaceModelSummary = OnDeviceModelSummary

enum HealthConversationLanguage: String, Hashable {
    case chinese
    case english
}

enum HealthFocusedTopic: String, Hashable {
    case overall
    case sleep
    case heart
    case recovery
    case activity
    case ecg

    func title(for language: HealthConversationLanguage) -> String {
        switch (self, language) {
        case (.overall, .chinese):
            "整体健康"
        case (.sleep, .chinese):
            "睡眠"
        case (.heart, .chinese):
            "心率"
        case (.recovery, .chinese):
            "恢复"
        case (.activity, .chinese):
            "步数与活动"
        case (.ecg, .chinese):
            "ECG"
        case (.overall, .english):
            "Overall Health"
        case (.sleep, .english):
            "Sleep"
        case (.heart, .english):
            "Heart Rate"
        case (.recovery, .english):
            "Recovery"
        case (.activity, .english):
            "Activity"
        case (.ecg, .english):
            "ECG"
        }
    }

    var systemImage: String {
        switch self {
        case .overall:
            "heart.text.square"
        case .sleep:
            "bed.double.fill"
        case .heart:
            "waveform.path.ecg"
        case .recovery:
            "figure.cooldown"
        case .activity:
            "figure.walk"
        case .ecg:
            "waveform.ecg"
        }
    }

    var preferredTab: DashboardTab {
        switch self {
        case .overall, .recovery:
            .overview
        case .sleep, .heart, .activity:
            .signals
        case .ecg:
            .data
        }
    }
}

struct HealthRouteSession: Hashable {
    let topic: HealthFocusedTopic
    let language: HealthConversationLanguage
    let originalPrompt: String
    let generatedAt: Date

    init(
        topic: HealthFocusedTopic,
        language: HealthConversationLanguage,
        originalPrompt: String,
        generatedAt: Date = .now
    ) {
        self.topic = topic
        self.language = language
        self.originalPrompt = originalPrompt
        self.generatedAt = generatedAt
    }
}

enum HealthWorkspacePrivacyBoundary: String {
    case localOnly
    case redactedForChat

    var summary: String {
        switch self {
        case .localOnly:
            "Health analysis runs locally on-device."
        case .redactedForChat:
            "Only summarized health output is exposed outside the workspace."
        }
    }
}

struct HealthWorkspaceTrendHighlight: Identifiable {
    let id: String
    let title: String
    let summary: String
}

struct HealthWorkspaceWatchpoint: Identifiable {
    let id: String
    let title: String
    let band: String
    let summary: String
}

struct HealthWorkspaceSnapshot {
    let title: String
    let generatedAt: Date
    let summary: String
    let recommendation: String
    let availabilitySummary: String
    let focusAreas: [String]
    let trendHighlights: [HealthWorkspaceTrendHighlight]
    let modelWatchpoints: [HealthWorkspaceWatchpoint]
    let notes: [String]
    let privacyBoundary: HealthWorkspacePrivacyBoundary

    init(
        dashboard: HealthWorkspaceDashboard,
        maxHighlights: Int = 3
    ) {
        title = dashboard.title
        generatedAt = dashboard.generatedAt
        summary = dashboard.hero.summary
        recommendation = dashboard.hero.recommendation
        availabilitySummary = dashboard.hero.availabilitySummary
        focusAreas = dashboard.insights
            .prefix(maxHighlights)
            .map { "\($0.title): \($0.summary)" }
        trendHighlights = dashboard.signals
            .prefix(maxHighlights)
            .map {
                HealthWorkspaceTrendHighlight(
                    id: $0.id,
                    title: $0.label,
                    summary: $0.highlight
                )
            }
        modelWatchpoints = dashboard.predictions
            .prefix(maxHighlights)
            .map {
                HealthWorkspaceWatchpoint(
                    id: $0.id,
                    title: $0.title,
                    band: $0.band,
                    summary: $0.summary
                )
            }
        notes = Array(dashboard.notes.prefix(maxHighlights))
        privacyBoundary = .redactedForChat
    }
}

enum HealthToolIntent: String, CaseIterable, Identifiable {
    case workspaceSummary
    case focusAreas
    case trendHighlights
    case modelWatchlist

    var id: String { rawValue }

    var title: String {
        switch self {
        case .workspaceSummary:
            "Health Summary"
        case .focusAreas:
            "Focus Areas"
        case .trendHighlights:
            "Trend Highlights"
        case .modelWatchlist:
            "Model Watchlist"
        }
    }
}

struct HealthToolRequest {
    let intent: HealthToolIntent
    let maxItems: Int

    init(intent: HealthToolIntent, maxItems: Int = 3) {
        self.intent = intent
        self.maxItems = max(1, maxItems)
    }
}

struct HealthToolResponse {
    let intent: HealthToolIntent
    let title: String
    let summary: String
    let highlights: [String]
    let generatedAt: Date
    let privacyBoundary: HealthWorkspacePrivacyBoundary
}

enum HealthWorkspaceMigrationPhase: String {
    case adoptNow
    case keepLegacyUntilReplacement
}

struct HealthWorkspaceMigrationItem: Identifiable {
    let id: String
    let symbol: String
    let currentFile: String
    let targetBoundary: String
    let phase: HealthWorkspaceMigrationPhase
    let note: String
}

enum HealthWorkspaceMigrationPlan {
    static let modelsToMigrate: [HealthWorkspaceMigrationItem] = [
        HealthWorkspaceMigrationItem(
            id: "dashboard-root",
            symbol: "HealthDashboard, AnalysisHero",
            currentFile: "HealthDashboardModels.swift",
            targetBoundary: "Spaces/Health/Domain/HealthWorkspaceModels.swift",
            phase: .adoptNow,
            note: "Top-level workspace read model should move first so new callers stop importing the old root path."
        ),
        HealthWorkspaceMigrationItem(
            id: "insight-risk",
            symbol: "ConditionPrediction, PredictionMetrics, InsightCard, OnDeviceModelSummary, OnDeviceRiskAssessment",
            currentFile: "HealthDashboardModels.swift",
            targetBoundary: "Spaces/Health/Domain/HealthWorkspaceModels.swift",
            phase: .adoptNow,
            note: "These are workspace-facing result models and should become Health-owned types once downstream references are updated."
        ),
        HealthWorkspaceMigrationItem(
            id: "signals-profile",
            symbol: "SignalSeries, SignalSample, SleepSummary, UserCharacteristicsSnapshot, DataSourceStatus, SourceKind",
            currentFile: "HealthDashboardModels.swift",
            targetBoundary: "Spaces/Health/Domain/HealthWorkspaceModels.swift",
            phase: .adoptNow,
            note: "These define summarized health data, not raw HealthKit records, so they fit the workspace boundary."
        ),
        HealthWorkspaceMigrationItem(
            id: "dataset-internals",
            symbol: "WorkoutSummary, ECGReading, SleepSegment, SleepState, LocalHealthDataset",
            currentFile: "HealthDashboardModels.swift",
            targetBoundary: "Spaces/Health/Domain/HealthWorkspaceModels.swift",
            phase: .keepLegacyUntilReplacement,
            note: "Keep these with the legacy pipeline until the analyzer and service layers move behind workspace-owned protocols."
        ),
    ]

    static let legacyDependencies: [HealthWorkspaceMigrationItem] = [
        HealthWorkspaceMigrationItem(
            id: "dashboard-store",
            symbol: "HealthDashboardStore",
            currentFile: "HealthDashboardStore.swift",
            targetBoundary: "Spaces/Health/Presentation",
            phase: .keepLegacyUntilReplacement,
            note: "Still owns authorization, loading, and refresh flow for the existing UI."
        ),
        HealthWorkspaceMigrationItem(
            id: "healthkit-service",
            symbol: "HealthKitService",
            currentFile: "HealthKitService.swift",
            targetBoundary: "Spaces/Health/Data",
            phase: .keepLegacyUntilReplacement,
            note: "Continue using it as the HealthKit acquisition backend until a workspace data provider replaces direct service access."
        ),
        HealthWorkspaceMigrationItem(
            id: "local-analyzer",
            symbol: "LocalHealthAnalyzer",
            currentFile: "LocalHealthAnalyzer.swift",
            targetBoundary: "Spaces/Health/Data",
            phase: .keepLegacyUntilReplacement,
            note: "Still owns local feature summarization and copy generation."
        ),
        HealthWorkspaceMigrationItem(
            id: "coreml-runtime",
            symbol: "CoreMLService",
            currentFile: "CoreMLService.swift",
            targetBoundary: "Spaces/Health/Data",
            phase: .keepLegacyUntilReplacement,
            note: "Remains the on-device model runtime until inference is extracted behind a workspace protocol."
        ),
        HealthWorkspaceMigrationItem(
            id: "legacy-ui",
            symbol: "DashboardSections",
            currentFile: "DashboardSections.swift",
            targetBoundary: "Spaces/Health/Presentation",
            phase: .keepLegacyUntilReplacement,
            note: "Current workspace UI reuses these screens instead of duplicating presentation immediately."
        ),
        HealthWorkspaceMigrationItem(
            id: "legacy-shell",
            symbol: "ContentView",
            currentFile: "ContentView.swift",
            targetBoundary: "Spaces/Health/Presentation",
            phase: .keepLegacyUntilReplacement,
            note: "HealthWorkspaceView currently mounts the old dashboard shell as workspace content."
        ),
    ]
}

enum HealthWorkspaceSection: String, CaseIterable, Identifiable {
    case overview
    case signals
    case coverage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview:
            "Overview"
        case .signals:
            "Signals"
        case .coverage:
            "Coverage"
        }
    }
}
