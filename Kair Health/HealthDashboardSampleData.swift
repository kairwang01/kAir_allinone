//
//  HealthDashboardSampleData.swift
//  Kair Health
//
//  Created by Codex on 2026/4/16.
//

import Foundation

extension HealthDashboard {
    static let preview = HealthDashboard(
        title: "Kair Health",
        subtitle: "Direct local Apple Health analysis with no import step.",
        generatedAt: iso("2026-04-16T16:30:00-04:00"),
        analysisWindow: DateInterval(
            start: iso("2026-03-20T00:00:00-04:00"),
            end: iso("2026-04-16T16:30:00-04:00")
        ),
        hero: AnalysisHero(
            overallScore: 0.34,
            confidence: 0.74,
            band: "Watch",
            summary: "The local model stack is leaning toward sleep apnea, while respiratory watch remains the clearest explanatory signal cluster.",
            recommendation: "Track overnight oxygenation, sleep efficiency, and daytime fatigue together. Persistent snoring or morning headaches are good reasons to pursue a sleep evaluation.",
            availabilitySummary: "3 local models, 10 connected health domains, 6 recent workouts."
        ),
        predictions: [
            ConditionPrediction(
                id: "sleep_apnea",
                title: "Sleep Apnea",
                probability: 0.34,
                threshold: 0.61,
                band: "Watch",
                summary: "Sleep Apnea stays below its local watch threshold. Main signal pattern: lower blood oxygen, lower sleep efficiency, higher bmi.",
                drivers: ["lower blood oxygen", "lower sleep efficiency", "higher bmi"],
                metrics: PredictionMetrics(rocAUC: 0.96, averagePrecision: 0.88, accuracy: 0.94)
            ),
            ConditionPrediction(
                id: "heart_disease",
                title: "Heart Disease",
                probability: 0.27,
                threshold: 0.62,
                band: "Stable",
                summary: "Heart Disease stays below its local watch threshold. Main signal pattern: lower hrv, more high-heart-rate windows, higher bmi.",
                drivers: ["lower hrv", "more high-heart-rate windows", "higher bmi"],
                metrics: PredictionMetrics(rocAUC: 0.85, averagePrecision: 0.69, accuracy: 0.87)
            ),
            ConditionPrediction(
                id: "diabetes",
                title: "Diabetes / Prediabetes",
                probability: 0.18,
                threshold: 0.74,
                band: "Stable",
                summary: "Diabetes / Prediabetes stays below its local watch threshold. Main signal pattern: higher bmi, lower sleep efficiency, lower daily steps.",
                drivers: ["higher bmi", "lower sleep efficiency", "lower daily steps"],
                metrics: PredictionMetrics(rocAUC: 0.94, averagePrecision: 0.83, accuracy: 0.92)
            ),
        ],
        modelSummary: OnDeviceModelSummary(
            version: "ios-compact-risk-v1",
            engine: "kair-health-on-device-linear",
            generatedAt: iso("2026-04-16T17:59:17-04:00"),
            sampleCount: 300,
            featureCount: 42,
            dataWindowDays: 28,
            signalWindowDays: 7
        ),
        insights: [
            InsightCard(
                id: "recovery",
                title: "Recovery Load",
                score: 0.46,
                band: "Watch",
                accentToken: "recovery",
                summary: "HRV drifted lower late in the week while resting heart rate stayed slightly above baseline."
            ),
            InsightCard(
                id: "respiratory",
                title: "Respiratory Watch",
                score: 0.24,
                band: "Stable",
                accentToken: "respiratory",
                summary: "Average SpO₂ stayed near 97%, with only a few low outliers and no severe sustained drops."
            ),
            InsightCard(
                id: "activity",
                title: "Activity Consistency",
                score: 0.37,
                band: "Watch",
                accentToken: "activity",
                summary: "Movement volume was strong on workout days, but step totals were inconsistent across the week."
            ),
            InsightCard(
                id: "metabolic",
                title: "Metabolic Track",
                score: 0.22,
                band: "Stable",
                accentToken: "metabolic",
                summary: "BMI and cardio fitness proxy stay close to the lower-risk range with current movement patterns."
            ),
        ],
        signals: [
            SignalSeries(
                id: "heart_rate",
                label: "Heart Rate",
                unit: "bpm",
                highlight: "7-day mean 71 bpm, peak 119 bpm, latest 73 bpm.",
                detail: "Hourly aggregates read directly from HealthKit heart-rate samples.",
                normalRange: 45...100,
                samples: [
                    SignalSample(timestamp: iso("2026-04-10T00:00:00-04:00"), value: 59),
                    SignalSample(timestamp: iso("2026-04-10T12:00:00-04:00"), value: 78),
                    SignalSample(timestamp: iso("2026-04-11T00:00:00-04:00"), value: 63),
                    SignalSample(timestamp: iso("2026-04-11T12:00:00-04:00"), value: 72),
                    SignalSample(timestamp: iso("2026-04-12T00:00:00-04:00"), value: 61),
                    SignalSample(timestamp: iso("2026-04-12T12:00:00-04:00"), value: 109),
                    SignalSample(timestamp: iso("2026-04-13T00:00:00-04:00"), value: 64),
                    SignalSample(timestamp: iso("2026-04-13T12:00:00-04:00"), value: 120),
                    SignalSample(timestamp: iso("2026-04-14T00:00:00-04:00"), value: 61),
                    SignalSample(timestamp: iso("2026-04-14T12:00:00-04:00"), value: 76),
                    SignalSample(timestamp: iso("2026-04-15T00:00:00-04:00"), value: 60),
                    SignalSample(timestamp: iso("2026-04-15T12:00:00-04:00"), value: 73),
                ]
            ),
            SignalSeries(
                id: "hrv",
                label: "HRV",
                unit: "ms",
                highlight: "7-day mean 45 ms with a late-week low of 21 ms.",
                detail: "Hourly SDNN averages derived from local Apple Watch HRV entries.",
                normalRange: 20...80,
                samples: [
                    SignalSample(timestamp: iso("2026-04-10T00:00:00-04:00"), value: 58),
                    SignalSample(timestamp: iso("2026-04-10T12:00:00-04:00"), value: 44),
                    SignalSample(timestamp: iso("2026-04-11T00:00:00-04:00"), value: 31),
                    SignalSample(timestamp: iso("2026-04-11T12:00:00-04:00"), value: 45),
                    SignalSample(timestamp: iso("2026-04-12T00:00:00-04:00"), value: 48),
                    SignalSample(timestamp: iso("2026-04-12T12:00:00-04:00"), value: 35),
                    SignalSample(timestamp: iso("2026-04-13T00:00:00-04:00"), value: 44),
                    SignalSample(timestamp: iso("2026-04-13T12:00:00-04:00"), value: 21),
                    SignalSample(timestamp: iso("2026-04-14T00:00:00-04:00"), value: 33),
                    SignalSample(timestamp: iso("2026-04-14T12:00:00-04:00"), value: 28),
                ]
            ),
            SignalSeries(
                id: "spo2",
                label: "SpO₂",
                unit: "%",
                highlight: "Mean 96.8%, nadir 93.0%.",
                detail: "Apple Watch oxygen-saturation samples averaged into hourly buckets.",
                normalRange: 95...100,
                samples: [
                    SignalSample(timestamp: iso("2026-04-10T00:00:00-04:00"), value: 98),
                    SignalSample(timestamp: iso("2026-04-10T12:00:00-04:00"), value: 97),
                    SignalSample(timestamp: iso("2026-04-11T00:00:00-04:00"), value: 97),
                    SignalSample(timestamp: iso("2026-04-11T12:00:00-04:00"), value: 96),
                    SignalSample(timestamp: iso("2026-04-12T00:00:00-04:00"), value: 93),
                    SignalSample(timestamp: iso("2026-04-12T12:00:00-04:00"), value: 96),
                    SignalSample(timestamp: iso("2026-04-13T00:00:00-04:00"), value: 95),
                    SignalSample(timestamp: iso("2026-04-13T12:00:00-04:00"), value: 94),
                    SignalSample(timestamp: iso("2026-04-14T00:00:00-04:00"), value: 95),
                    SignalSample(timestamp: iso("2026-04-14T12:00:00-04:00"), value: 100),
                ]
            ),
            SignalSeries(
                id: "steps",
                label: "Steps",
                unit: "steps",
                highlight: "Average 6,300 steps/day with one 11,000-step peak day.",
                detail: "Hourly step totals built from local Apple Health step-count samples.",
                normalRange: nil,
                samples: [
                    SignalSample(timestamp: iso("2026-04-10T00:00:00-04:00"), value: 42),
                    SignalSample(timestamp: iso("2026-04-10T12:00:00-04:00"), value: 510),
                    SignalSample(timestamp: iso("2026-04-11T00:00:00-04:00"), value: 0),
                    SignalSample(timestamp: iso("2026-04-11T12:00:00-04:00"), value: 0),
                    SignalSample(timestamp: iso("2026-04-12T00:00:00-04:00"), value: 37),
                    SignalSample(timestamp: iso("2026-04-12T12:00:00-04:00"), value: 4680),
                    SignalSample(timestamp: iso("2026-04-13T00:00:00-04:00"), value: 15),
                    SignalSample(timestamp: iso("2026-04-13T12:00:00-04:00"), value: 2500),
                    SignalSample(timestamp: iso("2026-04-14T00:00:00-04:00"), value: 0),
                    SignalSample(timestamp: iso("2026-04-14T12:00:00-04:00"), value: 1800),
                ]
            ),
            SignalSeries(
                id: "respiratory_rate",
                label: "Respiratory Rate",
                unit: "br/min",
                highlight: "Recent mean 15.8 breaths/min.",
                detail: "Respiratory-rate samples are averaged directly from HealthKit.",
                normalRange: 12...18,
                samples: [
                    SignalSample(timestamp: iso("2026-04-10T00:00:00-04:00"), value: 14.8),
                    SignalSample(timestamp: iso("2026-04-11T00:00:00-04:00"), value: 15.3),
                    SignalSample(timestamp: iso("2026-04-12T00:00:00-04:00"), value: 16.1),
                    SignalSample(timestamp: iso("2026-04-13T00:00:00-04:00"), value: 16.4),
                    SignalSample(timestamp: iso("2026-04-14T00:00:00-04:00"), value: 16.0),
                ]
            ),
        ],
        sleepSummary: SleepSummary(
            nightsTracked: 7,
            averageHours: 6.7,
            latestHours: 6.2,
            debtHours: 2.1,
            efficiency: 0.88,
            summary: "Sleep averaged 6.7 h/night over the tracked week, with mild sleep debt and decent time-in-bed efficiency."
        ),
        profile: UserCharacteristicsSnapshot(
            ageYears: 24,
            biologicalSex: "M",
            heightCentimeters: 177,
            weightKilograms: 78.2,
            bodyMassIndex: 24.9,
            restingHeartRate: 60,
            vo2Max: 39.4
        ),
        dataSources: [
            DataSourceStatus(id: "heart_rate", title: "Heart Rate", kind: .quantity, sampleCount: 66023, lastSampleDate: iso("2026-04-16T15:54:00-04:00"), summary: "66023 samples in the analysis window"),
            DataSourceStatus(id: "hrv", title: "Heart Rate Variability", kind: .quantity, sampleCount: 1735, lastSampleDate: iso("2026-04-16T10:02:00-04:00"), summary: "1735 samples in the analysis window"),
            DataSourceStatus(id: "spo2", title: "Blood Oxygen", kind: .quantity, sampleCount: 4305, lastSampleDate: iso("2026-04-16T07:31:00-04:00"), summary: "4305 samples in the analysis window"),
            DataSourceStatus(id: "sleep", title: "Sleep Analysis", kind: .category, sampleCount: 54, lastSampleDate: iso("2026-04-16T07:12:00-04:00"), summary: "54 sleep segments in the analysis window"),
            DataSourceStatus(id: "workouts", title: "Workouts", kind: .workout, sampleCount: 6, lastSampleDate: iso("2026-04-14T20:55:00-04:00"), summary: "6 workouts in the analysis window"),
            DataSourceStatus(id: "ecg", title: "Electrocardiograms", kind: .electrocardiogram, sampleCount: 2, lastSampleDate: iso("2026-04-13T20:15:00-04:00"), summary: "2 ECG readings saved locally"),
        ],
        workouts: [
            WorkoutSummary(id: "w1", activity: "Running", startDate: iso("2026-04-14T20:55:00-04:00"), durationMinutes: 41, energyKilocalories: 412, distanceKilometers: 6.8),
            WorkoutSummary(id: "w2", activity: "Walking", startDate: iso("2026-04-12T19:40:00-04:00"), durationMinutes: 58, energyKilocalories: 246, distanceKilometers: 4.7),
            WorkoutSummary(id: "w3", activity: "Strength Training", startDate: iso("2026-04-10T18:05:00-04:00"), durationMinutes: 37, energyKilocalories: 218, distanceKilometers: nil),
        ],
        ecgReadings: [
            ECGReading(id: "e1", startDate: iso("2026-04-13T20:15:00-04:00"), classification: "Sinus Rhythm", averageHeartRate: 68, symptomsStatus: "No symptoms logged", samplingFrequencyHertz: 512),
            ECGReading(id: "e2", startDate: iso("2026-03-31T21:02:00-04:00"), classification: "Sinus Rhythm", averageHeartRate: 64, symptomsStatus: "Symptoms noted", samplingFrequencyHertz: 512),
        ],
        notes: [
            "Kair Health reads Apple Health locally through HealthKit. No export file or import workflow is required.",
            "The preview reflects the embedded compact on-device model bundle used by the iOS app.",
            "These insights are heuristic wellness summaries, not clinical diagnoses.",
        ]
    )
}

private func iso(_ value: String) -> Date {
    if let date = ISO8601DateFormatter.fractional.date(from: value) {
        return date
    }
    if let date = ISO8601DateFormatter.standard.date(from: value) {
        return date
    }
    preconditionFailure("Invalid ISO8601 date: \(value)")
}

private extension ISO8601DateFormatter {
    static let standard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
        return formatter
    }()

    static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withColonSeparatorInTimeZone]
        return formatter
    }()
}
