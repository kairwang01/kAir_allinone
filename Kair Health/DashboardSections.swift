//
//  DashboardSections.swift
//  Kair Health
//
//  Created by Codex on 2026/4/16.
//

import Charts
import SwiftUI

struct OverviewScreen: View {
    let dashboard: HealthDashboard
    let onRefresh: () -> Void
    @State private var selectedSignalID = "heart_rate"

    private var selectedSignal: SignalSeries? {
        dashboard.signals.first(where: { $0.id == selectedSignalID }) ?? dashboard.signals.first
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HeroCard(hero: dashboard.hero, dashboard: dashboard)

                if !dashboard.predictions.isEmpty {
                    GlassCard {
                        SectionEyebrow(title: "Condition Models", subtitle: "Local disease predictions")
                        VStack(spacing: 12) {
                            ForEach(dashboard.predictions) { prediction in
                                ConditionPredictionRow(prediction: prediction)
                            }
                        }
                    }
                }

                GlassCard {
                    SectionEyebrow(title: "Focus", subtitle: "Local analysis drivers")
                    VStack(spacing: 12) {
                        ForEach(dashboard.insights) { insight in
                            InsightRow(insight: insight)
                        }
                    }
                }

                if let selectedSignal {
                    GlassCard {
                        SectionEyebrow(title: "Trend Focus", subtitle: selectedSignal.label)

                        Picker("Signal", selection: $selectedSignalID) {
                            ForEach(dashboard.signals) { signal in
                                Text(signal.label).tag(signal.id)
                            }
                        }
                        .pickerStyle(.segmented)

                        SignalChart(series: selectedSignal)
                            .frame(height: 220)

                        Text(selectedSignal.highlight)
                            .font(.subheadline)
                            .foregroundStyle(HealthPalette.ink)
                    }
                }

                GlassCard {
                    SectionEyebrow(title: "Sleep", subtitle: "Nightly recovery context")
                    Text(dashboard.sleepSummary.summary)
                        .font(.body)
                        .foregroundStyle(HealthPalette.ink)

                    LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
                        MetricTile(title: "Nights", value: "\(dashboard.sleepSummary.nightsTracked)", accent: HealthPalette.sky)
                        MetricTile(title: "Avg Sleep", value: "\(dashboard.sleepSummary.averageHours.formattedOneDecimal) h", accent: HealthPalette.mint)
                        MetricTile(title: "Latest Night", value: "\(dashboard.sleepSummary.latestHours.formattedOneDecimal) h", accent: HealthPalette.cyan)
                        MetricTile(title: "Debt", value: "\(dashboard.sleepSummary.debtHours.formattedOneDecimal) h", accent: HealthPalette.amber)
                    }
                }

                if !dashboard.notes.isEmpty {
                    GlassCard {
                        SectionEyebrow(title: "Notes", subtitle: "How this app reads your data")
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(dashboard.notes, id: \.self) { note in
                                Label(note, systemImage: "checkmark.circle")
                                    .font(.subheadline)
                                    .foregroundStyle(HealthPalette.mutedInk)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .background(HealthScreenBackground())
        .navigationTitle("Health")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Refresh health analysis")
            }
        }
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            if dashboard.signals.contains(where: { $0.id == selectedSignalID }) == false {
                selectedSignalID = dashboard.signals.first?.id ?? "heart_rate"
            }
        }
    }
}

struct SignalsScreen: View {
    let dashboard: HealthDashboard
    let onRefresh: () -> Void
    @State private var selectedSignalID = "heart_rate"

    private var selectedSignal: SignalSeries? {
        dashboard.signals.first(where: { $0.id == selectedSignalID }) ?? dashboard.signals.first
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let selectedSignal {
                    GlassCard {
                        SectionEyebrow(title: "Signals", subtitle: "Direct local HealthKit trends")

                        Picker("Signal", selection: $selectedSignalID) {
                            ForEach(dashboard.signals) { signal in
                                Text(signal.label).tag(signal.id)
                            }
                        }
                        .pickerStyle(.segmented)

                        SignalChart(series: selectedSignal)
                            .frame(height: 260)

                        if let normalRange = selectedSignal.normalRange {
                            CapsuleChip(
                                title: "Expected \(normalRange.lowerBound.formattedOneDecimal)-\(normalRange.upperBound.formattedOneDecimal) \(selectedSignal.unit)",
                                color: HealthPalette.sky
                            )
                        }

                        Text(selectedSignal.highlight)
                            .font(.body)
                            .foregroundStyle(HealthPalette.ink)
                        Text(selectedSignal.detail)
                            .font(.subheadline)
                            .foregroundStyle(HealthPalette.mutedInk)
                    }
                }

                GlassCard {
                    SectionEyebrow(title: "Profile", subtitle: "Current Apple Health context")
                    LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
                        MetricTile(title: "Age", value: dashboard.profile.ageYears.map(String.init) ?? "—", accent: HealthPalette.sky)
                        MetricTile(title: "Sex", value: dashboard.profile.biologicalSex ?? "—", accent: HealthPalette.plum)
                        MetricTile(title: "BMI", value: dashboard.profile.bodyMassIndex.map { $0.formattedOneDecimal } ?? "—", accent: HealthPalette.amber)
                        MetricTile(title: "Weight", value: dashboard.profile.weightKilograms.map { "\($0.formattedOneDecimal) kg" } ?? "—", accent: HealthPalette.coral)
                        MetricTile(title: "Height", value: dashboard.profile.heightCentimeters.map { "\($0.formattedOneDecimal) cm" } ?? "—", accent: HealthPalette.cyan)
                        MetricTile(title: "VO₂ Max", value: dashboard.profile.vo2Max.map { $0.formattedOneDecimal } ?? "—", accent: HealthPalette.mint)
                    }
                }

                GlassCard {
                    SectionEyebrow(title: "Coverage", subtitle: "Recent Apple Health domains")
                    VStack(spacing: 12) {
                        ForEach(dashboard.dataSources.prefix(6)) { source in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(source.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(HealthPalette.ink)
                                    Text(source.summary)
                                        .font(.footnote)
                                        .foregroundStyle(HealthPalette.mutedInk)
                                }
                                Spacer()
                                Text("\(source.sampleCount)")
                                    .font(.headline.monospacedDigit())
                                    .foregroundStyle(HealthPalette.color(for: source.id))
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .background(HealthScreenBackground())
        .navigationTitle("Signals")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if dashboard.signals.contains(where: { $0.id == selectedSignalID }) == false {
                selectedSignalID = dashboard.signals.first?.id ?? "heart_rate"
            }
        }
    }
}

struct DataLibraryScreen: View {
    let dashboard: HealthDashboard
    let onRefresh: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let modelSummary = dashboard.modelSummary {
                    GlassCard {
                        SectionEyebrow(title: "Model Bundle", subtitle: "Embedded on-device prediction stack")
                        Text("kAir ships a compact local model bundle and executes it inside the app. The disease predictions below are generated without network access.")
                            .font(.body)
                            .foregroundStyle(HealthPalette.ink)

                        LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
                            MetricTile(title: "Version", value: modelSummary.version, accent: HealthPalette.sky)
                            MetricTile(title: "Features", value: "\(modelSummary.featureCount)", accent: HealthPalette.mint)
                            MetricTile(title: "Training Windows", value: "\(modelSummary.sampleCount)", accent: HealthPalette.amber)
                            MetricTile(title: "Signal Window", value: "\(modelSummary.signalWindowDays) d", accent: HealthPalette.coral)
                        }

                        VStack(spacing: 12) {
                            ForEach(dashboard.predictions) { prediction in
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(prediction.title)
                                            .font(.headline)
                                            .foregroundStyle(HealthPalette.ink)
                                        Text(prediction.summary)
                                            .font(.footnote)
                                            .foregroundStyle(HealthPalette.mutedInk)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(prediction.probability.formattedPercent0)
                                            .font(.title3.monospacedDigit().weight(.bold))
                                            .foregroundStyle(HealthPalette.color(for: prediction.id))
                                        Text("ROC \(prediction.metrics.rocAUC.formattedOneDecimal)")
                                            .font(.footnote)
                                            .foregroundStyle(HealthPalette.mutedInk)
                                    }
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .fill(HealthPalette.color(for: prediction.id).opacity(0.10))
                                )
                            }
                        }
                    }
                }

                GlassCard {
                    SectionEyebrow(title: "Connected Data", subtitle: "Direct Apple Health access")
                    Text("kAir reads local HealthKit data after permission is granted. There is no export or import step in this app flow.")
                        .font(.body)
                        .foregroundStyle(HealthPalette.ink)

                    VStack(spacing: 12) {
                        ForEach(dashboard.dataSources) { source in
                            HStack(alignment: .top, spacing: 12) {
                                Circle()
                                    .fill(HealthPalette.color(for: source.id))
                                    .frame(width: 10, height: 10)
                                    .padding(.top, 6)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(source.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(HealthPalette.ink)
                                    Text(source.summary)
                                        .font(.footnote)
                                        .foregroundStyle(HealthPalette.mutedInk)
                                    if let lastSampleDate = source.lastSampleDate {
                                        Text("Latest \(lastSampleDate, format: .dateTime.month(.abbreviated).day().hour().minute())")
                                            .font(.caption)
                                            .foregroundStyle(HealthPalette.mutedInk)
                                    }
                                }
                                Spacer()
                                Text("\(source.sampleCount)")
                                    .font(.headline.monospacedDigit())
                                    .foregroundStyle(HealthPalette.ink)
                            }
                        }
                    }
                }

                GlassCard {
                    SectionEyebrow(title: "Workouts", subtitle: "Recent exercise saved in Health")
                    if dashboard.workouts.isEmpty {
                        EmptyStateRow(
                            title: "No recent workouts",
                            detail: "When workouts exist in Apple Health, they appear here without a manual sync step."
                        )
                    } else {
                        VStack(spacing: 12) {
                            ForEach(dashboard.workouts) { workout in
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(workout.activity)
                                            .font(.headline)
                                            .foregroundStyle(HealthPalette.ink)
                                        Text(workout.startDate, format: .dateTime.month(.abbreviated).day().hour().minute())
                                            .font(.footnote)
                                            .foregroundStyle(HealthPalette.mutedInk)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("\(workout.durationMinutes.formattedOneDecimal) min")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(HealthPalette.ink)
                                        if let distance = workout.distanceKilometers {
                                            Text("\(distance.formattedOneDecimal) km")
                                                .font(.footnote)
                                                .foregroundStyle(HealthPalette.mutedInk)
                                        } else if let calories = workout.energyKilocalories {
                                            Text("\(calories.formattedOneDecimal) kcal")
                                                .font(.footnote)
                                                .foregroundStyle(HealthPalette.mutedInk)
                                        }
                                    }
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .fill(HealthPalette.amber.opacity(0.10))
                                )
                            }
                        }
                    }
                }

                GlassCard {
                    SectionEyebrow(title: "Electrocardiograms", subtitle: "Apple Watch ECG summaries")
                    if dashboard.ecgReadings.isEmpty {
                        EmptyStateRow(
                            title: "No ECG readings",
                            detail: "When Apple Watch ECG readings are stored locally, kAir can summarize their classifications here."
                        )
                    } else {
                        VStack(spacing: 12) {
                            ForEach(dashboard.ecgReadings) { reading in
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(reading.classification)
                                            .font(.headline)
                                            .foregroundStyle(HealthPalette.ink)
                                        Text(reading.startDate, format: .dateTime.month(.abbreviated).day().hour().minute())
                                            .font(.footnote)
                                            .foregroundStyle(HealthPalette.mutedInk)
                                        Text(reading.symptomsStatus)
                                            .font(.footnote)
                                            .foregroundStyle(HealthPalette.mutedInk)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(reading.averageHeartRate.map { "\($0.formattedOneDecimal) bpm" } ?? "—")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(HealthPalette.ink)
                                        Text(reading.samplingFrequencyHertz.map { "\($0.formattedOneDecimal) Hz" } ?? "—")
                                            .font(.footnote)
                                            .foregroundStyle(HealthPalette.mutedInk)
                                    }
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .fill(HealthPalette.plum.opacity(0.10))
                                )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .background(HealthScreenBackground())
        .navigationTitle("Coverage")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HealthAccessIntroScreen: View {
    let statusMessage: String
    let supportsHealthData: Bool
    let action: () -> Void

    var body: some View {
        ZStack {
            HealthScreenBackground()

            VStack(spacing: 24) {
                Spacer()

                GlassCard {
                    VStack(alignment: .leading, spacing: 18) {
                        CapsuleChip(title: "Local Apple Health access", color: HealthPalette.mint)
                        Text("kAir")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(HealthPalette.ink)
                        Text("Read and analyze Apple Health data directly on-device.")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(HealthPalette.ink)
                        Text(statusMessage)
                            .font(.body)
                            .foregroundStyle(HealthPalette.mutedInk)

                        VStack(alignment: .leading, spacing: 10) {
                            Label("No XML export", systemImage: "checkmark.circle")
                            Label("No import flow", systemImage: "checkmark.circle")
                            Label("Trends, workouts, sleep, and ECG summaries pulled locally", systemImage: "checkmark.circle")
                        }
                        .font(.subheadline)
                        .foregroundStyle(HealthPalette.ink)

                        Button(action: action) {
                            Text(supportsHealthData ? "Connect Apple Health" : "HealthKit Unavailable")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(supportsHealthData ? HealthPalette.ink : HealthPalette.mutedInk)
                                )
                        }
                        .disabled(!supportsHealthData)
                    }
                }

                Spacer()
            }
            .padding(20)
        }
    }
}

struct LoadingStateScreen: View {
    let title: String
    let message: String

    var body: some View {
        ZStack {
            HealthScreenBackground()

            GlassCard {
                VStack(spacing: 18) {
                    ProgressView()
                        .controlSize(.large)
                    Text(title)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(HealthPalette.ink)
                    Text(message)
                        .multilineTextAlignment(.center)
                        .font(.body)
                        .foregroundStyle(HealthPalette.mutedInk)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(20)
        }
    }
}

struct FailureStateScreen: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ZStack {
            HealthScreenBackground()

            GlassCard {
                VStack(alignment: .leading, spacing: 18) {
                    CapsuleChip(title: "Load failed", color: HealthPalette.coral)
                    Text("kAir couldn’t read the local HealthKit data.")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(HealthPalette.ink)
                    Text(message)
                        .font(.body)
                        .foregroundStyle(HealthPalette.mutedInk)

                    Button(action: retry) {
                        Text("Try Again")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(HealthPalette.ink)
                            )
                    }
                }
            }
            .padding(20)
        }
    }
}

private struct HeroCard: View {
    let hero: AnalysisHero
    let dashboard: HealthDashboard

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                Text("On-Device Model Stack")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(HealthPalette.mutedInk)
                    .tracking(1.1)

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 20) {
                        summaryCopy
                        Spacer(minLength: 8)
                        RiskOrb(value: hero.overallScore)
                    }

                    VStack(alignment: .leading, spacing: 20) {
                        summaryCopy
                        RiskOrb(value: hero.overallScore)
                    }
                }

                Text(hero.recommendation)
                    .font(.subheadline)
                    .foregroundStyle(HealthPalette.mutedInk)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        CapsuleChip(title: hero.band, color: HealthPalette.color(for: "overall"))
                        CapsuleChip(title: "\(hero.confidence.formattedPercent0) confidence", color: HealthPalette.sky)
                        CapsuleChip(title: hero.availabilitySummary, color: HealthPalette.cyan)
                    }
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(HealthPalette.heroGradient)
                    .opacity(0.72)
            )
        }
    }

    private var summaryCopy: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(dashboard.predictions.first.map { "\($0.title) Risk Model" } ?? "On-Device Risk Prediction")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(HealthPalette.ink)
            Text(hero.overallScore.formattedPercent1)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(HealthPalette.ink)
            Text("\(dashboard.analysisWindow.start, format: .dateTime.month(.wide).day()) - \(dashboard.analysisWindow.end, format: .dateTime.month(.wide).day())")
                .font(.headline)
                .foregroundStyle(HealthPalette.mutedInk)
            Text(hero.summary)
                .font(.subheadline)
                .foregroundStyle(HealthPalette.ink.opacity(0.84))
        }
    }
}

private struct ConditionPredictionRow: View {
    let prediction: ConditionPrediction

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(prediction.title)
                        .font(.headline)
                        .foregroundStyle(HealthPalette.ink)
                    Text("Local threshold \(prediction.threshold.formattedPercent0)")
                        .font(.footnote)
                        .foregroundStyle(HealthPalette.mutedInk)
                }
                Spacer()
                CapsuleChip(title: prediction.band, color: HealthPalette.color(for: prediction.id))
                Text(prediction.probability.formattedPercent1)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(HealthPalette.color(for: prediction.id))
            }

            Text(prediction.summary)
                .font(.subheadline)
                .foregroundStyle(HealthPalette.ink)

            if !prediction.drivers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(prediction.drivers, id: \.self) { driver in
                            CapsuleChip(title: driver, color: HealthPalette.color(for: prediction.id))
                        }
                    }
                }
            }

            Text("ROC \(prediction.metrics.rocAUC.formattedOneDecimal) · AP \(prediction.metrics.averagePrecision.formattedOneDecimal) · ACC \(prediction.metrics.accuracy.formattedOneDecimal)")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(HealthPalette.mutedInk)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(HealthPalette.color(for: prediction.id).opacity(0.10))
        )
    }
}

private struct RiskOrb: View {
    let value: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(HealthPalette.ink.opacity(0.08), lineWidth: 16)

            Circle()
                .trim(from: 0, to: value)
                .stroke(
                    AngularGradient(
                        colors: [HealthPalette.mint, HealthPalette.cyan, HealthPalette.plum],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 6) {
                Text("Current")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(HealthPalette.mutedInk)
                Text(value.formattedPercent0)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(HealthPalette.ink)
            }
        }
        .frame(width: 144, height: 144)
    }
}

private struct InsightRow: View {
    let insight: InsightCard

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(insight.title)
                    .font(.headline)
                    .foregroundStyle(HealthPalette.ink)
                Spacer()
                CapsuleChip(title: insight.band, color: HealthPalette.color(for: insight.accentToken))
                Text(insight.score.formattedPercent1)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(HealthPalette.color(for: insight.accentToken))
            }
            Text(insight.summary)
                .font(.subheadline)
                .foregroundStyle(HealthPalette.mutedInk)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(HealthPalette.color(for: insight.accentToken).opacity(0.10))
        )
    }
}

private struct SignalChart: View {
    let series: SignalSeries
    @State private var selectedDate: Date?

    var body: some View {
        if series.samples.isEmpty {
            EmptyStateRow(
                title: "No samples available",
                detail: "This signal has no readable local Apple Health data in the recent window."
            )
        } else {
            Chart(series.samples) { sample in
                AreaMark(
                    x: .value("Time", sample.timestamp),
                    y: .value(series.label, sample.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [HealthPalette.color(for: series.id).opacity(0.24), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Time", sample.timestamp),
                    y: .value(series.label, sample.value)
                )
                .foregroundStyle(HealthPalette.color(for: series.id))
                .lineStyle(.init(lineWidth: 3, lineCap: .round))

                PointMark(
                    x: .value("Time", sample.timestamp),
                    y: .value(series.label, sample.value)
                )
                .foregroundStyle(HealthPalette.ink.opacity(0.72))
                .symbolSize(34)
                
                if let selectedDate,
                   let sample = series.samples.min(by: { abs($0.timestamp.timeIntervalSince(selectedDate)) < abs($1.timestamp.timeIntervalSince(selectedDate)) }) {
                    RuleMark(x: .value("Selected Time", sample.timestamp))
                        .foregroundStyle(HealthPalette.mutedInk)
                        .annotation(position: .top) {
                            VStack(spacing: 2) {
                                Text("\(sample.value.formattedOneDecimal) \(series.unit)")
                                    .font(.caption.bold())
                                    .foregroundStyle(HealthPalette.ink)
                                Text(sample.timestamp, format: .dateTime.month(.abbreviated).day().hour().minute())
                                    .font(.caption2)
                                    .foregroundStyle(HealthPalette.mutedInk)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(HealthPalette.ink.opacity(0.05))
                            .cornerRadius(6)
                        }
                }
            }
            .chartXSelection(value: $selectedDate)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date, format: .dateTime.month(.abbreviated).day().hour())
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        }
    }
}

private struct EmptyStateRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(HealthPalette.ink)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(HealthPalette.mutedInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(HealthPalette.sky.opacity(0.10))
        )
    }
}
