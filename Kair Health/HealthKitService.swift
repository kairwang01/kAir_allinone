//
//  HealthKitService.swift
//  Kair Health
//
//  Created by Codex on 2026/4/16.
//

import Foundation
import HealthKit

final class HealthKitService {
    enum ServiceError: LocalizedError {
        case healthDataUnavailable

        var errorDescription: String? {
            switch self {
            case .healthDataUnavailable:
                "HealthKit is not available on this device."
            }
        }
    }

    private struct QuantityDefinition {
        let id: String
        let title: String
        let identifier: HKQuantityTypeIdentifier
        let unit: HKUnit
        let statisticsOptions: HKStatisticsOptions
        let interval: DateComponents
        let normalRange: ClosedRange<Double>?
        let multiplier: Double
        let summary: String
    }

    private struct SourceDefinition {
        let id: String
        let title: String
        let kind: SourceKind
        let sampleType: HKSampleType?
    }

    private let healthStore = HKHealthStore()
    private let calendar = Calendar.autoupdatingCurrent

    private static let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
    private static let hrvUnit = HKUnit.secondUnit(with: .milli)
    private static let respiratoryUnit = HKUnit.count().unitDivided(by: .minute())
    private static let stepsUnit = HKUnit.count()
    private static let kilocalorieUnit = HKUnit.kilocalorie()
    private static let heightUnit = HKUnit.meterUnit(with: .centi)
    private static let weightUnit = HKUnit.gramUnit(with: .kilo)
    private static let vo2MaxUnit = HKUnit.literUnit(with: .milli)
        .unitDivided(by: HKUnit.gramUnit(with: .kilo))
        .unitDivided(by: .minute())

    private static let chartDefinitions: [QuantityDefinition] = [
        QuantityDefinition(
            id: "heart_rate",
            title: "Heart Rate",
            identifier: .heartRate,
            unit: heartRateUnit,
            statisticsOptions: .discreteAverage,
            interval: DateComponents(hour: 6),
            normalRange: 45...100,
            multiplier: 1.0,
            summary: "Averages local heart-rate samples into six-hour buckets."
        ),
        QuantityDefinition(
            id: "hrv",
            title: "HRV",
            identifier: .heartRateVariabilitySDNN,
            unit: hrvUnit,
            statisticsOptions: .discreteAverage,
            interval: DateComponents(hour: 6),
            normalRange: 20...80,
            multiplier: 1.0,
            summary: "Uses Apple Watch SDNN measurements already stored in Health."
        ),
        QuantityDefinition(
            id: "spo2",
            title: "SpO₂",
            identifier: .oxygenSaturation,
            unit: .percent(),
            statisticsOptions: .discreteAverage,
            interval: DateComponents(hour: 6),
            normalRange: 95...100,
            multiplier: 100.0,
            summary: "Reads blood-oxygen values directly from HealthKit and converts them to percent."
        ),
        QuantityDefinition(
            id: "steps",
            title: "Steps",
            identifier: .stepCount,
            unit: stepsUnit,
            statisticsOptions: .cumulativeSum,
            interval: DateComponents(hour: 6),
            normalRange: nil,
            multiplier: 1.0,
            summary: "Sums step-count samples into six-hour movement buckets."
        ),
        QuantityDefinition(
            id: "respiratory_rate",
            title: "Respiratory Rate",
            identifier: .respiratoryRate,
            unit: respiratoryUnit,
            statisticsOptions: .discreteAverage,
            interval: DateComponents(day: 1),
            normalRange: 12...18,
            multiplier: 1.0,
            summary: "Shows recent respiratory-rate trends from Apple Health."
        ),
        QuantityDefinition(
            id: "resting_heart_rate",
            title: "Resting Heart Rate",
            identifier: .restingHeartRate,
            unit: heartRateUnit,
            statisticsOptions: .discreteAverage,
            interval: DateComponents(day: 1),
            normalRange: 45...75,
            multiplier: 1.0,
            summary: "Tracks the resting-heart-rate baseline stored by Apple Watch."
        ),
    ]

    private var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()

        for definition in Self.chartDefinitions {
            if let type = HKObjectType.quantityType(forIdentifier: definition.identifier) {
                types.insert(type)
            }
        }

        for identifier in [
            HKQuantityTypeIdentifier.activeEnergyBurned,
            .bodyMass,
            .height,
            .vo2Max,
            .distanceWalkingRunning,
        ] {
            if let type = HKObjectType.quantityType(forIdentifier: identifier) {
                types.insert(type)
            }
        }

        if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleepType)
        }
        if let sexType = HKObjectType.characteristicType(forIdentifier: .biologicalSex) {
            types.insert(sexType)
        }
        if let dobType = HKObjectType.characteristicType(forIdentifier: .dateOfBirth) {
            types.insert(dobType)
        }

        types.insert(HKObjectType.workoutType())
        types.insert(HKObjectType.activitySummaryType())
        types.insert(HKObjectType.electrocardiogramType())

        return types
    }

    func authorizationRequestStatus() async throws -> HKAuthorizationRequestStatus {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw ServiceError.healthDataUnavailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            healthStore.getRequestStatusForAuthorization(
                toShare: Set<HKSampleType>(),
                read: readTypes
            ) { status, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: status)
                }
            }
        }
    }

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw ServiceError.healthDataUnavailable
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: nil, read: readTypes) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func loadDashboard(now: Date = .now) async throws -> HealthDashboard {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw ServiceError.healthDataUnavailable
        }

        let analysisStart = calendar.date(byAdding: .day, value: -28, to: now) ?? now
        let chartStart = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let analysisWindow = DateInterval(start: analysisStart, end: now)

        async let profileTask = fetchProfile()
        async let sleepTask = fetchSleepSegments(from: analysisStart, to: now)
        async let workoutsTask = fetchWorkouts(from: analysisStart, to: now)
        async let ecgTask = fetchECGs(from: analysisStart, to: now)
        async let sourceTask = fetchSourceSummaries(from: analysisStart, to: now)

        let signals = await fetchSignals(from: chartStart, to: now)
        let profile = (try? await profileTask) ?? UserCharacteristicsSnapshot(
            ageYears: nil,
            biologicalSex: nil,
            heightCentimeters: nil,
            weightKilograms: nil,
            bodyMassIndex: nil,
            restingHeartRate: nil,
            vo2Max: nil
        )
        let sleepSegments = (try? await sleepTask) ?? []
        let workouts = (try? await workoutsTask) ?? []
        let ecgReadings = (try? await ecgTask) ?? []
        let dataSources = (try? await sourceTask) ?? []

        let dataset = LocalHealthDataset(
            generatedAt: now,
            analysisWindow: analysisWindow,
            signals: signals,
            sleepSegments: sleepSegments,
            profile: profile,
            dataSources: dataSources,
            workouts: workouts,
            ecgReadings: ecgReadings
        )
        return LocalHealthAnalyzer.makeDashboard(from: dataset)
    }

    private func fetchSignals(from startDate: Date, to endDate: Date) async -> [SignalSeries] {
        let definitions = Self.chartDefinitions
        let results = await withTaskGroup(of: SignalSeries?.self) { group in
            for definition in definitions {
                group.addTask {
                    try? await self.fetchQuantitySeries(definition, from: startDate, to: endDate)
                }
            }
            
            var collected: [SignalSeries?] = []
            for await result in group {
                collected.append(result)
            }
            return collected
        }
        
        return results.compactMap { $0 }.filter { !$0.samples.isEmpty }
    }

    private func fetchQuantitySeries(
        _ definition: QuantityDefinition,
        from startDate: Date,
        to endDate: Date
    ) async throws -> SignalSeries {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: definition.identifier) else {
            return SignalSeries(
                id: definition.id,
                label: definition.title,
                unit: "",
                highlight: "",
                detail: definition.summary,
                normalRange: definition.normalRange,
                samples: []
            )
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let anchorDate = calendar.startOfDay(for: startDate)

        let points: [SignalSample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: definition.statisticsOptions,
                anchorDate: anchorDate,
                intervalComponents: definition.interval
            )

            query.initialResultsHandler = { _, collection, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                var collected: [SignalSample] = []
                collection?.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    let quantity: HKQuantity?
                    if definition.statisticsOptions.contains(.cumulativeSum) {
                        quantity = statistics.sumQuantity()
                    } else {
                        quantity = statistics.averageQuantity()
                    }

                    guard let quantity else { return }
                    let rawValue = quantity.doubleValue(for: definition.unit) * definition.multiplier
                    guard rawValue.isFinite else { return }
                    collected.append(SignalSample(timestamp: statistics.startDate, value: rawValue))
                }

                continuation.resume(returning: collected)
            }

            healthStore.execute(query)
        }

        return SignalSeries(
            id: definition.id,
            label: definition.title,
            unit: definition.id == "spo2" ? "%" : definition.id == "steps" ? "steps" : definition.id == "respiratory_rate" ? "br/min" : "bpm",
            highlight: "",
            detail: definition.summary,
            normalRange: definition.normalRange,
            samples: points
        )
    }

    private func fetchProfile() async throws -> UserCharacteristicsSnapshot {
        async let heightTask = latestQuantityValue(for: .height, unit: Self.heightUnit)
        async let weightTask = latestQuantityValue(for: .bodyMass, unit: Self.weightUnit)
        async let restingTask = latestQuantityValue(for: .restingHeartRate, unit: Self.heartRateUnit)
        async let vo2Task = latestQuantityValue(for: .vo2Max, unit: Self.vo2MaxUnit)

        let ageYears = ageFromHealthKit()
        let biologicalSex = biologicalSexDescription()
        let heightCentimeters = try? await heightTask
        let weightKilograms = try? await weightTask
        let restingHeartRate = try? await restingTask
        let vo2Max = try? await vo2Task
        let bodyMassIndex: Double?
        if let heightCentimeters, let weightKilograms, heightCentimeters > 0 {
            let heightMeters = heightCentimeters / 100.0
            bodyMassIndex = weightKilograms / (heightMeters * heightMeters)
        } else {
            bodyMassIndex = nil
        }

        return UserCharacteristicsSnapshot(
            ageYears: ageYears,
            biologicalSex: biologicalSex,
            heightCentimeters: heightCentimeters,
            weightKilograms: weightKilograms,
            bodyMassIndex: bodyMassIndex,
            restingHeartRate: restingHeartRate,
            vo2Max: vo2Max
        )
    }

    private func ageFromHealthKit(referenceDate: Date = .now) -> Int? {
        guard let components = try? healthStore.dateOfBirthComponents(),
              let birthDate = calendar.date(from: components) else {
            return nil
        }
        let years = calendar.dateComponents([.year], from: birthDate, to: referenceDate).year
        return years
    }

    private func biologicalSexDescription() -> String? {
        guard let sexObject = try? healthStore.biologicalSex() else { return nil }
        switch sexObject.biologicalSex {
        case .female:
            return "F"
        case .male:
            return "M"
        case .other:
            return "Other"
        case .notSet:
            return nil
        @unknown default:
            return nil
        }
    }

    private func latestQuantityValue(
        for identifier: HKQuantityTypeIdentifier,
        unit: HKUnit
    ) async throws -> Double? {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            return nil
        }

        let samples = try await fetchSamples(
            sampleType: quantityType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
        )

        guard let sample = samples.first as? HKQuantitySample else { return nil }
        return sample.quantity.doubleValue(for: unit)
    }

    private func fetchSleepSegments(from startDate: Date, to endDate: Date) async throws -> [SleepSegment] {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return []
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let samples = try await fetchSamples(
            sampleType: sleepType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        )

        return samples.compactMap { sample in
            guard let category = sample as? HKCategorySample else { return nil }
            return SleepSegment(
                startDate: category.startDate,
                endDate: category.endDate,
                state: sleepState(for: category.value)
            )
        }
    }

    private func sleepState(for rawValue: Int) -> SleepState {
        switch rawValue {
        case 0:
            .inBed
        case 1, 3, 4, 5:
            .asleep
        case 2:
            .awake
        default:
            .unknown
        }
    }

    private func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [WorkoutSummary] {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let samples = try await fetchSamples(
            sampleType: HKObjectType.workoutType(),
            predicate: predicate,
            limit: 12,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
        )

        return samples.compactMap { sample in
            guard let workout = sample as? HKWorkout else { return nil }
            return WorkoutSummary(
                id: workout.uuid.uuidString,
                activity: activityName(for: workout.workoutActivityType),
                startDate: workout.startDate,
                durationMinutes: workout.duration / 60.0,
                energyKilocalories: workout.totalEnergyBurned?.doubleValue(for: Self.kilocalorieUnit),
                distanceKilometers: workout.totalDistance?.doubleValue(for: HKUnit.meterUnit(with: .kilo))
            )
        }
    }

    private func fetchECGs(from startDate: Date, to endDate: Date) async throws -> [ECGReading] {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let samples = try await fetchSamples(
            sampleType: HKObjectType.electrocardiogramType(),
            predicate: predicate,
            limit: 6,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
        )

        return samples.compactMap { sample in
            guard let ecg = sample as? HKElectrocardiogram else { return nil }
            return ECGReading(
                id: ecg.uuid.uuidString,
                startDate: ecg.startDate,
                classification: ecgClassificationText(for: ecg.classification),
                averageHeartRate: ecg.averageHeartRate?.doubleValue(for: Self.heartRateUnit),
                symptomsStatus: ecgSymptomsText(for: ecg.symptomsStatus),
                samplingFrequencyHertz: ecg.samplingFrequency?.doubleValue(for: .hertz())
            )
        }
    }

    private func fetchSourceSummaries(from startDate: Date, to endDate: Date) async throws -> [DataSourceStatus] {
        let sources: [SourceDefinition] = [
            SourceDefinition(id: "heart_rate", title: "Heart Rate", kind: .quantity, sampleType: HKObjectType.quantityType(forIdentifier: .heartRate)),
            SourceDefinition(id: "hrv", title: "Heart Rate Variability", kind: .quantity, sampleType: HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)),
            SourceDefinition(id: "spo2", title: "Blood Oxygen", kind: .quantity, sampleType: HKObjectType.quantityType(forIdentifier: .oxygenSaturation)),
            SourceDefinition(id: "respiratory_rate", title: "Respiratory Rate", kind: .quantity, sampleType: HKObjectType.quantityType(forIdentifier: .respiratoryRate)),
            SourceDefinition(id: "steps", title: "Step Count", kind: .quantity, sampleType: HKObjectType.quantityType(forIdentifier: .stepCount)),
            SourceDefinition(id: "active_energy", title: "Active Energy", kind: .quantity, sampleType: HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)),
            SourceDefinition(id: "body_mass", title: "Body Mass", kind: .quantity, sampleType: HKObjectType.quantityType(forIdentifier: .bodyMass)),
            SourceDefinition(id: "vo2max", title: "VO₂ Max", kind: .quantity, sampleType: HKObjectType.quantityType(forIdentifier: .vo2Max)),
            SourceDefinition(id: "sleep", title: "Sleep Analysis", kind: .category, sampleType: HKObjectType.categoryType(forIdentifier: .sleepAnalysis)),
            SourceDefinition(id: "workouts", title: "Workouts", kind: .workout, sampleType: HKObjectType.workoutType()),
            SourceDefinition(id: "ecg", title: "Electrocardiograms", kind: .electrocardiogram, sampleType: HKObjectType.electrocardiogramType()),
        ]

        return await withTaskGroup(of: DataSourceStatus?.self) { group in
            for definition in sources {
                guard let sampleType = definition.sampleType else { continue }
                group.addTask {
                    let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
                    let samples = (try? await self.fetchSamples(
                        sampleType: sampleType,
                        predicate: predicate,
                        limit: HKObjectQueryNoLimit,
                        sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
                    )) ?? []

                    let latestDate = samples.first?.endDate
                    let summary = samples.isEmpty
                        ? "No local samples found in the analysis window"
                        : "\(samples.count) samples in the analysis window"

                    return DataSourceStatus(
                        id: definition.id,
                        title: definition.title,
                        kind: definition.kind,
                        sampleCount: samples.count,
                        lastSampleDate: latestDate,
                        summary: summary
                    )
                }
            }

            var summaries: [DataSourceStatus] = []
            for await status in group {
                if let status {
                    summaries.append(status)
                }
            }
            return summaries.sorted { $0.id < $1.id } // Ensuring consistent order as before
        }
    }

    private func fetchSamples(
        sampleType: HKSampleType,
        predicate: NSPredicate?,
        limit: Int,
        sortDescriptors: [NSSortDescriptor]?
    ) async throws -> [HKSample] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: predicate,
                limit: limit,
                sortDescriptors: sortDescriptors
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples ?? [])
                }
            }
            healthStore.execute(query)
        }
    }

    private func activityName(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running:
            "Running"
        case .walking:
            "Walking"
        case .hiking:
            "Hiking"
        case .cycling:
            "Cycling"
        case .swimming:
            "Swimming"
        case .traditionalStrengthTraining:
            "Strength Training"
        case .functionalStrengthTraining:
            "Functional Strength"
        case .highIntensityIntervalTraining:
            "HIIT"
        case .yoga:
            "Yoga"
        case .mindAndBody:
            "Mind & Body"
        case .mixedCardio:
            "Mixed Cardio"
        default:
            "Workout"
        }
    }

    private func ecgClassificationText(for classification: HKElectrocardiogram.Classification) -> String {
        switch classification {
        case .notSet:
            "Not set"
        case .sinusRhythm:
            "Sinus Rhythm"
        case .atrialFibrillation:
            "Atrial Fibrillation"
        case .inconclusiveLowHeartRate:
            "Inconclusive Low Heart Rate"
        case .inconclusiveHighHeartRate:
            "Inconclusive High Heart Rate"
        case .inconclusivePoorReading:
            "Poor Reading"
        case .inconclusiveOther:
            "Inconclusive"
        case .unrecognized:
            "Unrecognized"
        @unknown default:
            "Unknown"
        }
    }

    private func ecgSymptomsText(for status: HKElectrocardiogram.SymptomsStatus) -> String {
        switch status {
        case .notSet:
            "No symptoms logged"
        case .none:
            "No symptoms logged"
        case .present:
            "Symptoms noted"
        @unknown default:
            "Unknown"
        }
    }
}
