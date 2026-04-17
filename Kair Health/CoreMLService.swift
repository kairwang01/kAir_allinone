//
//  CoreMLService.swift
//  Kair Health
//
//  Created by Codex on 2026/4/16.
//

import Foundation

/// Loads the distilled on-device risk bundle and executes the compact models locally in Swift.
final class CoreMLService {
    static let shared = CoreMLService()

    private let bundle: CompactModelBundle?
    private let featureIndex: [String: FeatureDescriptor]

    private init(appBundle: Bundle = .main) {
        self.bundle = Self.loadBundle(from: appBundle)
        self.featureIndex = Self.makeFeatureIndex()
    }

    func predictRisk(from dataset: LocalHealthDataset) -> Double? {
        predictAssessment(from: dataset)?.predictions.first?.probability
    }

    func predictAssessment(from dataset: LocalHealthDataset) -> OnDeviceRiskAssessment? {
        guard let bundle else { return nil }

        let rawFeatures = extractFeatures(from: dataset)
        let standardizedFeatures = bundle.standardizedFeatures(from: rawFeatures)
        let predictions = bundle.models
            .map { model in
                buildPrediction(for: model, standardizedFeatures: standardizedFeatures)
            }
            .sorted { $0.probability > $1.probability }

        return OnDeviceRiskAssessment(
            predictions: predictions,
            modelSummary: OnDeviceModelSummary(
                version: bundle.bundleVersion,
                engine: bundle.engine,
                generatedAt: bundle.generatedAtDate,
                sampleCount: bundle.sampleCount,
                featureCount: bundle.featureOrder.count,
                dataWindowDays: bundle.dataWindowDays,
                signalWindowDays: bundle.signalWindowDays
            )
        )
    }

    private func buildPrediction(
        for model: CompactDiseaseModel,
        standardizedFeatures: [String: Double]
    ) -> ConditionPrediction {
        var logit = model.intercept
        var contributions: [FeatureContribution] = []

        for featureName in bundle?.featureOrder ?? [] {
            let standardizedValue = standardizedFeatures[featureName] ?? 0.0
            let coefficient = model.coefficients[featureName] ?? 0.0
            let contribution = standardizedValue * coefficient
            logit += contribution
            if coefficient != 0 {
                contributions.append(
                    FeatureContribution(
                        featureName: featureName,
                        standardizedValue: standardizedValue,
                        contribution: contribution
                    )
                )
            }
        }

        let probability = Self.sigmoid(logit)
        let drivers = driverCopy(from: contributions)
        let band = bandLabel(for: probability, threshold: model.threshold)

        return ConditionPrediction(
            id: model.id,
            title: model.label,
            probability: probability,
            threshold: model.threshold,
            band: band,
            summary: summaryCopy(for: model.label, probability: probability, threshold: model.threshold, drivers: drivers),
            drivers: drivers,
            metrics: PredictionMetrics(
                rocAUC: model.metrics.rocAUC,
                averagePrecision: model.metrics.averagePrecision,
                accuracy: model.metrics.accuracy
            )
        )
    }

    private func extractFeatures(from dataset: LocalHealthDataset) -> [String: Double?] {
        let signalMap = Dictionary(uniqueKeysWithValues: dataset.signals.map { ($0.id, $0) })
        let heartRate = sortedValues(for: signalMap["heart_rate"])
        let hrv = sortedValues(for: signalMap["hrv"])
        let spo2 = sortedValues(for: signalMap["spo2"])
        let restingHeartRate = sortedValues(for: signalMap["resting_heart_rate"])
        let stepBuckets = sortedValues(for: signalMap["steps"])
        let dailySteps = dailyTotals(from: signalMap["steps"])
        let sleepStats = sleepFeatures(from: dataset.sleepSegments)

        let analysisDays = max(Int(round(dataset.analysisWindow.duration / 86_400)), 1)
        let totalWorkoutMinutes = dataset.workouts.reduce(0.0) { partial, workout in
            partial + workout.durationMinutes
        }

        return [
            "age": dataset.profile.ageYears.map(Double.init),
            "sex_code": sexCode(from: dataset.profile.biologicalSex),
            "height_cm": dataset.profile.heightCentimeters,
            "weight_kg": dataset.profile.weightKilograms,
            "bmi": dataset.profile.bodyMassIndex,
            "resting_hr_baseline": mean(restingHeartRate) ?? dataset.profile.restingHeartRate,
            "sleep_average_hours": sleepStats.averageHours,
            "sleep_latest_hours": sleepStats.latestHours,
            "sleep_debt_hours": sleepStats.debtHours,
            "sleep_efficiency": sleepStats.efficiency,
            "workout_count_28d": Double(dataset.workouts.count),
            "workout_minutes_mean_28d": totalWorkoutMinutes / Double(analysisDays),
            "workout_minutes_total_28d": totalWorkoutMinutes,
            "heart_rate_mean": mean(heartRate),
            "heart_rate_std": standardDeviation(heartRate),
            "heart_rate_min": heartRate.min(),
            "heart_rate_max": heartRate.max(),
            "heart_rate_last": heartRate.last,
            "heart_rate_trend": slope(for: heartRate),
            "hrv_mean": mean(hrv),
            "hrv_std": standardDeviation(hrv),
            "hrv_min": hrv.min(),
            "hrv_max": hrv.max(),
            "hrv_last": hrv.last,
            "hrv_trend": slope(for: hrv),
            "spo2_mean": mean(spo2),
            "spo2_std": standardDeviation(spo2),
            "spo2_min": spo2.min(),
            "spo2_max": spo2.max(),
            "spo2_last": spo2.last,
            "spo2_trend": slope(for: spo2),
            "steps_daily_mean": mean(dailySteps),
            "steps_daily_std": standardDeviation(dailySteps),
            "steps_daily_max": dailySteps.max(),
            "steps_daily_last": dailySteps.last,
            "steps_daily_trend": slope(for: dailySteps),
            "steps_daily_cv": coefficientOfVariation(for: dailySteps),
            "spo2_low_buckets": spo2.isEmpty ? nil : Double(spo2.filter { $0 < 95.0 }.count),
            "spo2_critical_buckets": spo2.isEmpty ? nil : Double(spo2.filter { $0 < 92.0 }.count),
            "hrv_low_buckets": hrv.isEmpty ? nil : Double(hrv.filter { $0 < 20.0 }.count),
            "tachycardia_buckets": heartRate.isEmpty ? nil : Double(heartRate.filter { $0 > 100.0 }.count),
            "high_step_buckets": stepBuckets.isEmpty ? nil : Double(stepBuckets.filter { $0 > 500.0 }.count),
        ]
    }

    private func driverCopy(from contributions: [FeatureContribution]) -> [String] {
        let positive = contributions
            .filter { $0.contribution > 0.01 }
            .sorted { $0.contribution > $1.contribution }
        let ranked = positive.isEmpty
            ? contributions.sorted { abs($0.contribution) > abs($1.contribution) }
            : positive

        return ranked.prefix(3).map { contribution in
            let descriptor = featureIndex[contribution.featureName] ?? FeatureDescriptor(
                label: contribution.featureName.replacingOccurrences(of: "_", with: " "),
                positiveQualifier: "higher",
                negativeQualifier: "lower"
            )
            let qualifier = contribution.standardizedValue >= 0 ? descriptor.positiveQualifier : descriptor.negativeQualifier
            return "\(qualifier) \(descriptor.label.lowercased())"
        }
    }

    private func summaryCopy(
        for label: String,
        probability: Double,
        threshold: Double,
        drivers: [String]
    ) -> String {
        let lead = drivers.isEmpty ? "local signal patterns" : drivers.joined(separator: ", ")
        if probability < threshold * 0.75 {
            return "\(label) stays below its local watch threshold. Main signal pattern: \(lead)."
        }
        if probability < threshold {
            return "\(label) is approaching its local watch threshold. Main signal pattern: \(lead)."
        }
        return "\(label) crossed its local watch threshold. Main signal pattern: \(lead)."
    }

    private func sexCode(from biologicalSex: String?) -> Double? {
        switch biologicalSex?.lowercased() {
        case "m":
            1.0
        case "f":
            0.0
        default:
            nil
        }
    }

    private func sortedValues(for series: SignalSeries?) -> [Double] {
        series?.samples
            .sorted { $0.timestamp < $1.timestamp }
            .map(\.value) ?? []
    }

    private func dailyTotals(from signal: SignalSeries?) -> [Double] {
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

    private func sleepFeatures(from segments: [SleepSegment]) -> SleepFeatureSnapshot {
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
        let orderedNights = nightlySleep.keys.sorted()
        let sleepHours = orderedNights.compactMap { nightlySleep[$0] }
        let sleepEfficiencies = orderedNights.compactMap { night -> Double? in
            guard let asleep = nightlySleep[night],
                  let inBed = groupedInBed[night]?.reduce(0.0, { partial, segment in
                      partial + segment.endDate.timeIntervalSince(segment.startDate) / 3600.0
                  }),
                  inBed > 0 else {
                return nil
            }
            return asleep / inBed
        }

        return SleepFeatureSnapshot(
            averageHours: mean(sleepHours),
            latestHours: sleepHours.last,
            debtHours: sleepHours.isEmpty ? nil : max(0.0, Double(sleepHours.count) * 7.0 - sleepHours.reduce(0.0, +)),
            efficiency: mean(sleepEfficiencies)
        )
    }

    private func mean(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0.0, +) / Double(values.count)
    }

    private func standardDeviation(_ values: [Double]) -> Double? {
        guard values.count > 1, let average = mean(values) else { return nil }
        let variance = values.reduce(0.0) { partial, value in
            partial + pow(value - average, 2)
        } / Double(values.count)
        return sqrt(variance)
    }

    private func coefficientOfVariation(for values: [Double]) -> Double? {
        guard values.count > 1, let average = mean(values), average > 0 else { return nil }
        let variance = values.reduce(0.0) { partial, value in
            partial + pow(value - average, 2)
        } / Double(values.count)
        return sqrt(variance) / average
    }

    private func slope(for values: [Double]) -> Double? {
        guard values.count > 1 else { return nil }
        let xValues = Array(0..<values.count).map(Double.init)
        guard let xMean = mean(xValues), let yMean = mean(values) else { return nil }
        let numerator = zip(xValues, values).reduce(0.0) { partial, pair in
            partial + (pair.0 - xMean) * (pair.1 - yMean)
        }
        let denominator = xValues.reduce(0.0) { partial, value in
            partial + pow(value - xMean, 2)
        }
        guard denominator != 0 else { return nil }
        return numerator / denominator
    }

    private func bandLabel(for probability: Double, threshold: Double) -> String {
        if probability < threshold * 0.55 {
            return "Stable"
        }
        if probability < threshold {
            return "Watch"
        }
        if probability < min(0.90, threshold + 0.18) {
            return "Guarded"
        }
        return "Elevated"
    }

    private static func sigmoid(_ value: Double) -> Double {
        let clipped = min(max(value, -18.0), 18.0)
        return 1.0 / (1.0 + exp(-clipped))
    }

    private static func loadBundle(from appBundle: Bundle) -> CompactModelBundle? {
        guard let url = appBundle.url(
            forResource: "compact-model-bundle",
            withExtension: "json",
            subdirectory: "OnDeviceModels"
        ) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(CompactModelBundle.self, from: data)
        } catch {
            return nil
        }
    }

    private static func makeFeatureIndex() -> [String: FeatureDescriptor] {
        [
            "age": FeatureDescriptor(label: "age", positiveQualifier: "higher", negativeQualifier: "lower"),
            "bmi": FeatureDescriptor(label: "BMI", positiveQualifier: "higher", negativeQualifier: "lower"),
            "resting_hr_baseline": FeatureDescriptor(label: "resting heart rate", positiveQualifier: "higher", negativeQualifier: "lower"),
            "sleep_average_hours": FeatureDescriptor(label: "sleep duration", positiveQualifier: "higher", negativeQualifier: "lower"),
            "sleep_latest_hours": FeatureDescriptor(label: "latest sleep duration", positiveQualifier: "higher", negativeQualifier: "lower"),
            "sleep_debt_hours": FeatureDescriptor(label: "sleep debt", positiveQualifier: "higher", negativeQualifier: "lower"),
            "sleep_efficiency": FeatureDescriptor(label: "sleep efficiency", positiveQualifier: "higher", negativeQualifier: "lower"),
            "workout_count_28d": FeatureDescriptor(label: "workout count", positiveQualifier: "more", negativeQualifier: "fewer"),
            "workout_minutes_mean_28d": FeatureDescriptor(label: "average workout minutes", positiveQualifier: "higher", negativeQualifier: "lower"),
            "workout_minutes_total_28d": FeatureDescriptor(label: "total workout minutes", positiveQualifier: "higher", negativeQualifier: "lower"),
            "heart_rate_mean": FeatureDescriptor(label: "heart rate", positiveQualifier: "higher", negativeQualifier: "lower"),
            "heart_rate_min": FeatureDescriptor(label: "minimum heart rate", positiveQualifier: "higher", negativeQualifier: "lower"),
            "heart_rate_max": FeatureDescriptor(label: "peak heart rate", positiveQualifier: "higher", negativeQualifier: "lower"),
            "heart_rate_last": FeatureDescriptor(label: "latest heart rate", positiveQualifier: "higher", negativeQualifier: "lower"),
            "heart_rate_trend": FeatureDescriptor(label: "heart-rate trend", positiveQualifier: "higher", negativeQualifier: "lower"),
            "hrv_mean": FeatureDescriptor(label: "HRV", positiveQualifier: "higher", negativeQualifier: "lower"),
            "hrv_low_buckets": FeatureDescriptor(label: "low-HRV windows", positiveQualifier: "more", negativeQualifier: "fewer"),
            "hrv_trend": FeatureDescriptor(label: "HRV trend", positiveQualifier: "higher", negativeQualifier: "lower"),
            "spo2_mean": FeatureDescriptor(label: "blood oxygen", positiveQualifier: "higher", negativeQualifier: "lower"),
            "spo2_low_buckets": FeatureDescriptor(label: "low-oxygen windows", positiveQualifier: "more", negativeQualifier: "fewer"),
            "spo2_critical_buckets": FeatureDescriptor(label: "critical oxygen windows", positiveQualifier: "more", negativeQualifier: "fewer"),
            "steps_daily_mean": FeatureDescriptor(label: "daily steps", positiveQualifier: "higher", negativeQualifier: "lower"),
            "steps_daily_last": FeatureDescriptor(label: "latest daily steps", positiveQualifier: "higher", negativeQualifier: "lower"),
            "steps_daily_trend": FeatureDescriptor(label: "daily-step trend", positiveQualifier: "higher", negativeQualifier: "lower"),
            "tachycardia_buckets": FeatureDescriptor(label: "high-heart-rate windows", positiveQualifier: "more", negativeQualifier: "fewer"),
            "weight_kg": FeatureDescriptor(label: "weight", positiveQualifier: "higher", negativeQualifier: "lower"),
        ]
    }
}

private struct CompactModelBundle: Decodable {
    let bundleVersion: String
    let engine: String
    let generatedAt: String
    let sampleCount: Int
    let featureCount: Int
    let dataWindowDays: Int
    let signalWindowDays: Int
    let preprocessing: CompactPreprocessing
    let models: [CompactDiseaseModel]

    var featureOrder: [String] { preprocessing.featureOrder }

    var generatedAtDate: Date? {
        Self.isoParser.date(from: generatedAt)
    }

    func standardizedFeatures(from rawFeatures: [String: Double?]) -> [String: Double] {
        var values: [String: Double] = [:]
        for (index, featureName) in preprocessing.featureOrder.enumerated() {
            let fallback = preprocessing.medians[index]
            let raw = rawFeatures[featureName] ?? nil
            let value = (raw?.isFinite == true ? raw! : fallback)
            let mean = preprocessing.means[index]
            let scale = preprocessing.scales[index] == 0 ? 1.0 : preprocessing.scales[index]
            values[featureName] = (value - mean) / scale
        }
        return values
    }

    private static let isoParser: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private enum CodingKeys: String, CodingKey {
        case bundleVersion = "bundle_version"
        case engine
        case generatedAt = "generated_at"
        case sampleCount = "sample_count"
        case featureCount = "feature_count"
        case dataWindowDays = "data_window_days"
        case signalWindowDays = "signal_window_days"
        case preprocessing
        case models
    }
}

private struct CompactPreprocessing: Decodable {
    let featureOrder: [String]
    let medians: [Double]
    let means: [Double]
    let scales: [Double]

    private enum CodingKeys: String, CodingKey {
        case featureOrder = "feature_order"
        case medians
        case means
        case scales
    }
}

private struct CompactDiseaseModel: Decodable {
    let id: String
    let label: String
    let threshold: Double
    let intercept: Double
    let coefficients: [String: Double]
    let metrics: CompactMetrics
}

private struct CompactMetrics: Decodable {
    let rocAUC: Double
    let averagePrecision: Double
    let accuracy: Double

    private enum CodingKeys: String, CodingKey {
        case rocAUC = "roc_auc"
        case averagePrecision = "average_precision"
        case accuracy
    }
}

private struct SleepFeatureSnapshot {
    let averageHours: Double?
    let latestHours: Double?
    let debtHours: Double?
    let efficiency: Double?
}

private struct FeatureDescriptor {
    let label: String
    let positiveQualifier: String
    let negativeQualifier: String
}

private struct FeatureContribution {
    let featureName: String
    let standardizedValue: Double
    let contribution: Double
}
