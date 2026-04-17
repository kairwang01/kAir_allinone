//
//  LocalHealthAnalyzer.swift
//  Kair Health
//
//  Created by Codex on 2026/4/16.
//

import Foundation

enum LocalHealthAnalyzer {
    static func makeDashboard(from dataset: LocalHealthDataset) -> HealthDashboard {
        let sleepSummary = buildSleepSummary(from: dataset.sleepSegments)
        let enrichedSignals = dataset.signals.map { enrich(signal: $0) }
        let signalMap = Dictionary(uniqueKeysWithValues: enrichedSignals.map { ($0.id, $0) })

        let respiratory = respiratoryInsight(from: signalMap, sleepSummary: sleepSummary)
        let recovery = recoveryInsight(from: signalMap, sleepSummary: sleepSummary, profile: dataset.profile)
        let activity = activityInsight(from: signalMap, workouts: dataset.workouts)
        let metabolic = metabolicInsight(from: signalMap, profile: dataset.profile)
        let insights = [recovery, respiratory, activity, metabolic]
        let assessment = CoreMLService.shared.predictAssessment(from: dataset)
        let predictions = assessment?.predictions ?? []
        let modelSummary = assessment?.modelSummary

        let heuristicScore = clamp(
            recovery.score * 0.35 +
            respiratory.score * 0.25 +
            activity.score * 0.20 +
            metabolic.score * 0.20
        )
        let topPrediction = predictions.first
        let overallScore = topPrediction?.probability ?? heuristicScore
        let confidence = confidenceScore(
            from: dataset.dataSources,
            sleepSummary: sleepSummary,
            signals: enrichedSignals,
            topPrediction: topPrediction
        )
        let band = topPrediction?.band ?? bandLabel(for: overallScore)
        let topInsight = insights.max(by: { $0.score < $1.score }) ?? recovery
        let hero = AnalysisHero(
            overallScore: overallScore,
            confidence: confidence,
            band: band,
            summary: summaryCopy(
                topPrediction: topPrediction,
                overallScore: overallScore,
                topInsight: topInsight,
                sleepSummary: sleepSummary
            ),
            recommendation: recommendationCopy(predictionID: topPrediction?.id, focusID: topInsight.id),
            availabilitySummary: availabilitySummary(from: dataset, predictions: predictions)
        )

        var notes = [
            "kAir reads Apple Health directly through HealthKit on-device. No export file is needed.",
            "The risk layer now runs a distilled local model bundle inside the app. No network connection is required for prediction.",
            "This app summarizes patterns in local wellness data. It does not diagnose disease or replace clinical judgment.",
        ]
        if let modelSummary {
            notes.append("Current bundle: \(modelSummary.engine) · \(modelSummary.sampleCount) training windows · \(modelSummary.featureCount) local features.")
        } else {
            notes.append("If the embedded model bundle is missing, kAir falls back to the local heuristic wellness score.")
        }

        return HealthDashboard(
            title: "kAir",
            subtitle: "Local Apple Health analysis. No import flow.",
            generatedAt: dataset.generatedAt,
            analysisWindow: dataset.analysisWindow,
            hero: hero,
            predictions: predictions,
            modelSummary: modelSummary,
            insights: insights,
            signals: enrichedSignals,
            sleepSummary: sleepSummary,
            profile: dataset.profile,
            dataSources: dataset.dataSources.sorted { $0.sampleCount > $1.sampleCount },
            workouts: dataset.workouts,
            ecgReadings: dataset.ecgReadings,
            notes: notes
        )
    }

    private static func availabilitySummary(from dataset: LocalHealthDataset, predictions: [ConditionPrediction]) -> String {
        let connectedDomains = dataset.dataSources.filter { $0.sampleCount > 0 }.count
        if predictions.isEmpty {
            return "\(connectedDomains) connected health domains, \(dataset.workouts.count) recent workouts, \(dataset.ecgReadings.count) ECG readings."
        }
        return "\(predictions.count) local models, \(connectedDomains) connected health domains, \(dataset.workouts.count) recent workouts."
    }

    private static func summaryCopy(
        topPrediction: ConditionPrediction?,
        overallScore: Double,
        topInsight: InsightCard,
        sleepSummary: SleepSummary
    ) -> String {
        if let topPrediction {
            if overallScore < topPrediction.threshold * 0.75 {
                return "The local model stack keeps the current outlook below watch threshold. \(topPrediction.title) is still the leading modeled watchpoint, with \(topInsight.title.lowercased()) explaining most of the signal drift."
            }
            if overallScore < topPrediction.threshold {
                return "The local model stack is leaning toward \(topPrediction.title.lowercased()), while \(topInsight.title.lowercased()) remains the main explanatory signal cluster."
            }
            return "The on-device model crossed the watch threshold for \(topPrediction.title.lowercased()). \(topInsight.title) is the clearest supporting signal pattern in the local data."
        }
        if overallScore < 0.25 {
            return "The on-device risk model indicates stability. The strongest remaining watchpoint is \(topInsight.title.lowercased())."
        }
        if overallScore < 0.45 {
            return "The on-device risk model flagged \(topInsight.title) as the main watchpoint, alongside \(sleepSummary.averageHours.formattedOneDecimal) h/night of recent sleep."
        }
        return "The on-device prediction leans guarded. \(topInsight.title) is leading the current risk profile and deserves closer follow-up."
    }

    private static func recommendationCopy(predictionID: String?, focusID: String) -> String {
        switch predictionID {
        case "heart_disease":
            return "Keep watching HRV, resting heart rate, and exertional symptoms together. Seek care promptly for chest pain, fainting, or unexplained shortness of breath."
        case "diabetes":
            return "Focus on movement volume, body-weight trend, and sleep regularity together. If risk stays elevated, pair this with formal glucose or HbA1c testing."
        case "sleep_apnea":
            return "Track overnight oxygenation, sleep efficiency, and daytime fatigue together. Persistent snoring or morning headaches are good reasons to pursue a sleep evaluation."
        default:
            break
        }

        switch focusID {
        case "recovery":
            return "Prioritize sleep regularity, recovery days, and resting-heart-rate follow-up if the trend keeps rising."
        case "respiratory":
            return "Keep watching oxygen saturation and nighttime recovery. Seek clinical care for shortness of breath, chest pain, or persistent low oxygen."
        case "activity":
            return "Aim for steadier daily movement, not just isolated high-output days."
        case "metabolic":
            return "Track weight, cardio fitness, and movement volume together rather than relying on any single metric."
        default:
            return "Keep reviewing the weekly trend and compare it against symptoms and recovery context."
        }
    }

    private static func confidenceScore(
        from sources: [DataSourceStatus],
        sleepSummary: SleepSummary,
        signals: [SignalSeries],
        topPrediction: ConditionPrediction?
    ) -> Double {
        let connected = Double(sources.filter { $0.sampleCount > 0 }.count)
        let sourceScore = connected / Double(max(sources.count, 1))
        let signalScore = Double(signals.filter { !$0.samples.isEmpty }.count) / Double(max(signals.count, 1))
        let sleepBonus = sleepSummary.nightsTracked >= 4 ? 0.10 : 0.0
        let modelScore = topPrediction.map {
            ($0.metrics.rocAUC + $0.metrics.averagePrecision + $0.metrics.accuracy) / 3.0
        } ?? 0.0
        let modelWeight = topPrediction == nil ? 0.0 : 0.20
        return clamp(sourceScore * 0.45 + signalScore * 0.25 + sleepBonus + modelScore * modelWeight)
    }

    private static func buildSleepSummary(from segments: [SleepSegment]) -> SleepSummary {
        let asleepSegments = segments.filter { $0.state == .asleep }
        let inBedSegments = segments.filter { $0.state == .inBed }
        let groupedSleep = Dictionary(grouping: asleepSegments) { segment in
            Calendar.autoupdatingCurrent.startOfDay(for: segment.endDate)
        }
        let groupedInBed = Dictionary(grouping: inBedSegments) { segment in
            Calendar.autoupdatingCurrent.startOfDay(for: segment.endDate)
        }

        let nightlySleep = groupedSleep.mapValues { nightlySegments in
            nightlySegments.reduce(0.0) { partial, segment in
                partial + segment.endDate.timeIntervalSince(segment.startDate) / 3600.0
            }
        }
        let nightlyInBed = groupedInBed.mapValues { nightlySegments in
            nightlySegments.reduce(0.0) { partial, segment in
                partial + segment.endDate.timeIntervalSince(segment.startDate) / 3600.0
            }
        }

        let orderedNights = nightlySleep.keys.sorted()
        let hours = orderedNights.compactMap { nightlySleep[$0] }
        let averageHours = mean(hours)
        let latestHours = hours.last ?? 0.0
        let debtHours = max(0.0, Double(hours.count) * 7.0 - hours.reduce(0.0, +))

        let efficiencies = orderedNights.compactMap { night -> Double? in
            guard let asleep = nightlySleep[night],
                  let inBed = nightlyInBed[night],
                  inBed > 0 else {
                return nil
            }
            return asleep / inBed
        }

        let summary: String
        if hours.isEmpty {
            summary = "No readable sleep segments were found in the recent Apple Health window."
        } else if averageHours >= 7.0 && debtHours < 1.5 {
            summary = "Sleep is broadly stable with \(averageHours.formattedOneDecimal) h/night on average."
        } else {
            summary = "Sleep averaged \(averageHours.formattedOneDecimal) h/night with \(debtHours.formattedOneDecimal) h of recent debt."
        }

        return SleepSummary(
            nightsTracked: hours.count,
            averageHours: averageHours,
            latestHours: latestHours,
            debtHours: debtHours,
            efficiency: efficiencies.isEmpty ? nil : mean(efficiencies),
            summary: summary
        )
    }

    private static func respiratoryInsight(
        from signals: [String: SignalSeries],
        sleepSummary: SleepSummary
    ) -> InsightCard {
        let spo2Values = values(for: signals["spo2"])
        let respiratoryValues = values(for: signals["respiratory_rate"])
        let meanSpO2 = mean(spo2Values)
        let minSpO2 = spo2Values.min() ?? 97.0
        let meanRespiratoryRate = mean(respiratoryValues)

        var score = 0.16
        score += normalizedPenalty(97.0 - meanSpO2, scale: 3.0, weight: 0.22)
        score += normalizedPenalty(94.0 - minSpO2, scale: 4.0, weight: 0.28)
        score += normalizedPenalty(meanRespiratoryRate - 18.0, scale: 6.0, weight: 0.14)
        score += normalizedPenalty(sleepSummary.debtHours - 3.0, scale: 6.0, weight: 0.08)
        score = clamp(score)

        let summary: String
        if spo2Values.isEmpty {
            summary = "No recent blood-oxygen data was available, so this watchpoint relies on the remaining local recovery signals."
        } else {
            summary = "SpO₂ averaged \(meanSpO2.formattedOneDecimal)% with a low of \(minSpO2.formattedOneDecimal)% in the recent window."
        }

        return InsightCard(
            id: "respiratory",
            title: "Respiratory Watch",
            score: score,
            band: bandLabel(for: score),
            accentToken: "respiratory",
            summary: summary
        )
    }

    private static func recoveryInsight(
        from signals: [String: SignalSeries],
        sleepSummary: SleepSummary,
        profile: UserCharacteristicsSnapshot
    ) -> InsightCard {
        let hrvValues = values(for: signals["hrv"])
        let hrvSlope = slope(for: hrvValues)
        let restingValues = values(for: signals["resting_heart_rate"])
        let restingHeartRate = restingValues.last ?? profile.restingHeartRate ?? 60.0
        let meanHRV = mean(hrvValues)

        var score = 0.20
        score += normalizedPenalty(40.0 - meanHRV, scale: 25.0, weight: 0.28)
        score += normalizedPenalty(-hrvSlope, scale: 5.0, weight: 0.16)
        score += normalizedPenalty(restingHeartRate - 64.0, scale: 14.0, weight: 0.18)
        score += normalizedPenalty(sleepSummary.debtHours, scale: 8.0, weight: 0.16)
        score = clamp(score)

        let summary: String
        if hrvValues.isEmpty {
            summary = "HRV is missing in the local window, so recovery load falls back to sleep and resting-heart-rate context."
        } else {
            summary = "HRV averaged \(meanHRV.formattedOneDecimal) ms while resting heart rate sits near \(restingHeartRate.formattedOneDecimal) bpm."
        }

        return InsightCard(
            id: "recovery",
            title: "Recovery Load",
            score: score,
            band: bandLabel(for: score),
            accentToken: "recovery",
            summary: summary
        )
    }

    private static func activityInsight(
        from signals: [String: SignalSeries],
        workouts: [WorkoutSummary]
    ) -> InsightCard {
        let stepValues = values(for: signals["steps"])
        let dailySteps = dailyTotals(from: signals["steps"])
        let meanDailySteps = mean(dailySteps)
        let stepVariability = coefficientOfVariation(for: dailySteps)
        let workoutCount = Double(workouts.count)

        var score = 0.18
        score += normalizedPenalty(7000.0 - meanDailySteps, scale: 7000.0, weight: 0.30)
        score += normalizedPenalty(stepVariability - 0.6, scale: 0.7, weight: 0.12)
        score += normalizedPenalty(2.0 - workoutCount, scale: 3.0, weight: 0.10)
        score = clamp(score)

        let maxStepBucket = stepValues.max() ?? 0.0
        let summary = dailySteps.isEmpty
            ? "Movement data is sparse in the recent window."
            : "Recent movement averaged \(meanDailySteps.formatted(.number.precision(.fractionLength(0)))) steps/day with \(workouts.count) logged workouts."

        return InsightCard(
            id: "activity",
            title: "Activity Consistency",
            score: score,
            band: bandLabel(for: score),
            accentToken: "activity",
            summary: maxStepBucket > 0 ? summary : "Movement activity is currently thin, which lowers confidence in this track."
        )
    }

    private static func metabolicInsight(
        from signals: [String: SignalSeries],
        profile: UserCharacteristicsSnapshot
    ) -> InsightCard {
        let dailySteps = dailyTotals(from: signals["steps"])
        let meanDailySteps = mean(dailySteps)
        let bmi = profile.bodyMassIndex ?? 0.0
        let vo2Max = profile.vo2Max ?? 0.0
        let restingHeartRate = profile.restingHeartRate ?? values(for: signals["resting_heart_rate"]).last ?? 60.0

        var score = 0.14
        score += normalizedPenalty(bmi - 25.0, scale: 8.0, weight: 0.22)
        score += normalizedPenalty(35.0 - vo2Max, scale: 15.0, weight: 0.22)
        score += normalizedPenalty(6000.0 - meanDailySteps, scale: 6000.0, weight: 0.18)
        score += normalizedPenalty(restingHeartRate - 70.0, scale: 18.0, weight: 0.08)
        score = clamp(score)

        let summary: String
        if profile.bodyMassIndex == nil && profile.vo2Max == nil {
            summary = "Metabolic track is estimated mostly from movement volume because body-composition and VO₂ data are missing."
        } else {
            summary = "BMI \(bmi.formattedOneDecimal), VO₂ Max \(vo2Max.formattedOneDecimal), and daily movement shape the current metabolic trend."
        }

        return InsightCard(
            id: "metabolic",
            title: "Metabolic Track",
            score: score,
            band: bandLabel(for: score),
            accentToken: "metabolic",
            summary: summary
        )
    }

    private static func enrich(signal: SignalSeries) -> SignalSeries {
        let sorted = signal.samples.sorted { $0.timestamp < $1.timestamp }
        let values = sorted.map(\.value)
        guard !values.isEmpty else { return signal }

        let latest = values.last ?? 0.0
        let meanValue = mean(values)
        let minValue = values.min() ?? latest
        let maxValue = values.max() ?? latest

        let highlight: String
        switch signal.id {
        case "heart_rate":
            highlight = "Recent mean \(meanValue.formattedOneDecimal) bpm, peak \(maxValue.formattedOneDecimal) bpm, latest \(latest.formattedOneDecimal) bpm."
        case "hrv":
            highlight = "Recent mean \(meanValue.formattedOneDecimal) ms with a low of \(minValue.formattedOneDecimal) ms."
        case "spo2":
            highlight = "Recent mean \(meanValue.formattedOneDecimal)% with a nadir of \(minValue.formattedOneDecimal)%."
        case "steps":
            let daily = dailyTotals(from: signal)
            highlight = "Average \(mean(daily).formatted(.number.precision(.fractionLength(0)))) steps/day across the recent window."
        case "respiratory_rate":
            highlight = "Recent respiratory rate averages \(meanValue.formattedOneDecimal) breaths/min."
        case "resting_heart_rate":
            highlight = "Resting heart rate most recently sits near \(latest.formattedOneDecimal) bpm."
        default:
            highlight = "Recent trend is centered near \(meanValue.formattedOneDecimal) \(signal.unit)."
        }

        return SignalSeries(
            id: signal.id,
            label: signal.label,
            unit: signal.unit,
            highlight: highlight,
            detail: signal.detail,
            normalRange: signal.normalRange,
            samples: sorted
        )
    }

    private static func dailyTotals(from signal: SignalSeries?) -> [Double] {
        guard let signal else { return [] }
        let grouped = Dictionary(grouping: signal.samples) { sample in
            Calendar.autoupdatingCurrent.startOfDay(for: sample.timestamp)
        }
        return grouped.keys.sorted().map { date in
            grouped[date, default: []].reduce(0.0) { partial, sample in
                partial + sample.value
            }
        }
    }

    private static func values(for signal: SignalSeries?) -> [Double] {
        signal?.samples.map(\.value) ?? []
    }

    private static func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0.0 }
        return values.reduce(0.0, +) / Double(values.count)
    }

    private static func coefficientOfVariation(for values: [Double]) -> Double {
        guard values.count > 1 else { return 0.0 }
        let average = mean(values)
        guard average > 0 else { return 0.0 }
        let variance = values.reduce(0.0) { partial, value in
            partial + pow(value - average, 2)
        } / Double(values.count)
        return sqrt(variance) / average
    }

    private static func slope(for values: [Double]) -> Double {
        guard values.count > 1 else { return 0.0 }
        let xValues = Array(0..<values.count).map(Double.init)
        let xMean = mean(xValues)
        let yMean = mean(values)

        let numerator = zip(xValues, values).reduce(0.0) { partial, pair in
            partial + (pair.0 - xMean) * (pair.1 - yMean)
        }
        let denominator = xValues.reduce(0.0) { partial, value in
            partial + pow(value - xMean, 2)
        }
        guard denominator != 0 else { return 0.0 }
        return numerator / denominator
    }

    private static func normalizedPenalty(_ rawValue: Double, scale: Double, weight: Double) -> Double {
        guard rawValue > 0, scale > 0 else { return 0.0 }
        return min(rawValue / scale, 1.0) * weight
    }

    private static func bandLabel(for score: Double) -> String {
        switch score {
        case ..<0.25:
            "Stable"
        case ..<0.45:
            "Watch"
        case ..<0.65:
            "Guarded"
        default:
            "Elevated"
        }
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0.0), 0.95)
    }
}
