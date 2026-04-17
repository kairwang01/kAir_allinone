//
//  HealthDashboardModels.swift
//  Kair Health
//
//  Created by Codex on 2026/4/16.
//

import Foundation

enum DashboardTab: String, CaseIterable, Identifiable {
    case overview
    case signals
    case data

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview:
            "Overview"
        case .signals:
            "Signals"
        case .data:
            "Data"
        }
    }

    var systemImage: String {
        switch self {
        case .overview:
            "waveform.path.ecg.rectangle"
        case .signals:
            "heart.text.square"
        case .data:
            "shippingbox"
        }
    }
}

struct HealthDashboard {
    let title: String
    let subtitle: String
    let generatedAt: Date
    let analysisWindow: DateInterval
    let hero: AnalysisHero
    let predictions: [ConditionPrediction]
    let modelSummary: OnDeviceModelSummary?
    let insights: [InsightCard]
    let signals: [SignalSeries]
    let sleepSummary: SleepSummary
    let profile: UserCharacteristicsSnapshot
    let dataSources: [DataSourceStatus]
    let workouts: [WorkoutSummary]
    let ecgReadings: [ECGReading]
    let notes: [String]
}

struct AnalysisHero {
    let overallScore: Double
    let confidence: Double
    let band: String
    let summary: String
    let recommendation: String
    let availabilitySummary: String
}

struct ConditionPrediction: Identifiable {
    let id: String
    let title: String
    let probability: Double
    let threshold: Double
    let band: String
    let summary: String
    let drivers: [String]
    let metrics: PredictionMetrics
}

struct PredictionMetrics {
    let rocAUC: Double
    let averagePrecision: Double
    let accuracy: Double
}

struct OnDeviceModelSummary {
    let version: String
    let engine: String
    let generatedAt: Date?
    let sampleCount: Int
    let featureCount: Int
    let dataWindowDays: Int
    let signalWindowDays: Int
}

struct OnDeviceRiskAssessment {
    let predictions: [ConditionPrediction]
    let modelSummary: OnDeviceModelSummary
}

struct InsightCard: Identifiable {
    let id: String
    let title: String
    let score: Double
    let band: String
    let accentToken: String
    let summary: String
}

struct SignalSeries: Identifiable {
    let id: String
    let label: String
    let unit: String
    let highlight: String
    let detail: String
    let normalRange: ClosedRange<Double>?
    let samples: [SignalSample]
}

struct SignalSample: Identifiable {
    let timestamp: Date
    let value: Double

    var id: Date { timestamp }
}

struct SleepSummary {
    let nightsTracked: Int
    let averageHours: Double
    let latestHours: Double
    let debtHours: Double
    let efficiency: Double?
    let summary: String
}

struct UserCharacteristicsSnapshot {
    let ageYears: Int?
    let biologicalSex: String?
    let heightCentimeters: Double?
    let weightKilograms: Double?
    let bodyMassIndex: Double?
    let restingHeartRate: Double?
    let vo2Max: Double?
}

struct DataSourceStatus: Identifiable {
    let id: String
    let title: String
    let kind: SourceKind
    let sampleCount: Int
    let lastSampleDate: Date?
    let summary: String
}

enum SourceKind {
    case quantity
    case category
    case workout
    case electrocardiogram
}

struct WorkoutSummary: Identifiable {
    let id: String
    let activity: String
    let startDate: Date
    let durationMinutes: Double
    let energyKilocalories: Double?
    let distanceKilometers: Double?
}

struct ECGReading: Identifiable {
    let id: String
    let startDate: Date
    let classification: String
    let averageHeartRate: Double?
    let symptomsStatus: String
    let samplingFrequencyHertz: Double?
}

struct SleepSegment: Identifiable {
    let startDate: Date
    let endDate: Date
    let state: SleepState

    var id: String {
        "\(startDate.timeIntervalSince1970)-\(endDate.timeIntervalSince1970)-\(state.rawValue)"
    }
}

enum SleepState: String {
    case asleep
    case inBed
    case awake
    case unknown
}

struct LocalHealthDataset {
    let generatedAt: Date
    let analysisWindow: DateInterval
    let signals: [SignalSeries]
    let sleepSegments: [SleepSegment]
    let profile: UserCharacteristicsSnapshot
    let dataSources: [DataSourceStatus]
    let workouts: [WorkoutSummary]
    let ecgReadings: [ECGReading]
}
