//
//  DashboardSections.swift
//  kAir
//
//  Created by Codex on 2026/4/16.
//

import Charts
import SwiftUI

struct OverviewScreen: View {
    // MARK: - Box-4 color tokens (Tier 3.4 migration)
    //
    // Tier 3.4 migration (audit §8.1 box 4): `OverviewScreen`'s 6
    // §6-alias call sites are migrated to the `AppTheme.Palette`
    // contract tokens those aliases resolve to. These `static let`s
    // are wiring pins referencing EXISTING contract tokens — NOT new
    // color tokens — and dedup the inline references for the
    // token-wiring test.
    //
    //   HealthPalette.ink      = AppTheme.Palette.textPrimary
    //   HealthPalette.mutedInk = AppTheme.Palette.textSecondary
    //   HealthPalette.mint     = AppTheme.Palette.success
    //   HealthPalette.cyan     = AppTheme.Palette.sky      ← NOTE: the
    //       box-4 alias `cyan` maps to the FROZEN `Palette.sky` role.
    //       This is DISTINCT from `HealthPalette.sky` (the §7 local
    //       `Color(0.54,0.60,0.68)` variant) — see the inline
    //       exception note on the "Nights" MetricTile below.
    //   HealthPalette.amber    = AppTheme.Palette.warning
    //
    // `OverviewScreen` has zero `HealthPalette.color(for:)` /
    // `statusColor(for:)` calls — this slice is resolver-free. The 1
    // §7-out-of-scope reference (`HealthPalette.sky` on the "Nights"
    // tile) is NOT migrated; see the inline exception note.
    static let inkColor = AppTheme.Palette.textPrimary
    static let mutedInkColor = AppTheme.Palette.textSecondary
    static let successAccent = AppTheme.Palette.success
    static let skyAccent = AppTheme.Palette.sky
    static let warningAccent = AppTheme.Palette.warning

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
                            .foregroundStyle(Self.inkColor)
                    }
                }

                GlassCard {
                    SectionEyebrow(title: "Sleep", subtitle: "Nightly recovery context")
                    Text(dashboard.sleepSummary.summary)
                        .font(.body)
                        .foregroundStyle(Self.inkColor)

                    LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
                        // Intentional Tier-3.4 exception: `HealthPalette.sky`
                        // is the §7-out-of-scope local `Color(0.54,0.60,0.68)`
                        // variant — NOT a §6 box-4 alias, no `AppTheme.Palette`
                        // counterpart. DISTINCT from the box-4 alias `cyan`
                        // (which maps to the frozen `Palette.sky` role and IS
                        // migrated on the "Latest Night" tile below).
                        MetricTile(title: "Nights", value: "\(dashboard.sleepSummary.nightsTracked)", accent: HealthPalette.sky)
                        MetricTile(title: "Avg Sleep", value: "\(dashboard.sleepSummary.averageHours.formattedOneDecimal) h", accent: Self.successAccent)
                        MetricTile(title: "Latest Night", value: "\(dashboard.sleepSummary.latestHours.formattedOneDecimal) h", accent: Self.skyAccent)
                        MetricTile(title: "Debt", value: "\(dashboard.sleepSummary.debtHours.formattedOneDecimal) h", accent: Self.warningAccent)
                    }
                }

                if !dashboard.notes.isEmpty {
                    GlassCard {
                        SectionEyebrow(title: "Notes", subtitle: "How this app reads your data")
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(dashboard.notes, id: \.self) { note in
                                Label(note, systemImage: "checkmark.circle")
                                    .font(.subheadline)
                                    .foregroundStyle(Self.mutedInkColor)
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
    // MARK: - Box-4 color tokens (Tier 3.2 migration)
    //
    // Tier 3.2 migration (audit §8.1 box 4): `DataLibraryScreen`'s
    // 23 §6-alias call sites are migrated to the `AppTheme.Palette`
    // contract tokens those aliases resolve to. These `static let`s
    // are wiring pins referencing EXISTING contract tokens — NOT new
    // color tokens — and they dedup the 23 inline references into 5
    // named constants for the token-wiring test.
    //
    //   HealthPalette.ink      = AppTheme.Palette.textPrimary
    //   HealthPalette.mutedInk = AppTheme.Palette.textSecondary
    //   HealthPalette.mint     = AppTheme.Palette.success
    //   HealthPalette.amber    = AppTheme.Palette.warning
    //   HealthPalette.coral    = AppTheme.Palette.danger
    //
    // The 2 §7-out-of-scope references (`HealthPalette.sky` on the
    // "Version" MetricTile, `HealthPalette.plum` on the ECG card
    // fill) are NOT migrated — they have no `AppTheme.Palette`
    // counterpart; see the inline exception comments. The 3
    // `HealthPalette.color(for:)` resolver calls are also untouched
    // (a resolver is not a box-4 alias call site; per Tier 3.2
    // scope, `color(for:)` is out of scope).
    static let inkColor = AppTheme.Palette.textPrimary
    static let mutedInkColor = AppTheme.Palette.textSecondary
    static let successAccent = AppTheme.Palette.success
    static let warningAccent = AppTheme.Palette.warning
    static let dangerAccent = AppTheme.Palette.danger

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
                            .foregroundStyle(Self.inkColor)

                        LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
                            // Intentional Tier-3.2 exception: `HealthPalette.sky`
                            // is the §7-out-of-scope local `Color(0.54,0.60,0.68)`
                            // variant — NOT a §6 box-4 alias, no `AppTheme.Palette`
                            // counterpart. Left as-is (see the CapsuleChip /
                            // MetricTile exception notes in HealthDashboardStyle.swift).
                            MetricTile(title: "Version", value: modelSummary.version, accent: HealthPalette.sky)
                            MetricTile(title: "Features", value: "\(modelSummary.featureCount)", accent: Self.successAccent)
                            MetricTile(title: "Training Windows", value: "\(modelSummary.sampleCount)", accent: Self.warningAccent)
                            MetricTile(title: "Signal Window", value: "\(modelSummary.signalWindowDays) d", accent: Self.dangerAccent)
                        }

                        VStack(spacing: 12) {
                            ForEach(dashboard.predictions) { prediction in
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(prediction.title)
                                            .font(.headline)
                                            .foregroundStyle(Self.inkColor)
                                        Text(prediction.summary)
                                            .font(.footnote)
                                            .foregroundStyle(Self.mutedInkColor)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(prediction.probability.formattedPercent0)
                                            .font(.title3.monospacedDigit().weight(.bold))
                                            .foregroundStyle(HealthPalette.color(for: prediction.id))
                                        Text("ROC \(prediction.metrics.rocAUC.formattedOneDecimal)")
                                            .font(.footnote)
                                            .foregroundStyle(Self.mutedInkColor)
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
                        .foregroundStyle(Self.inkColor)

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
                                        .foregroundStyle(Self.inkColor)
                                    Text(source.summary)
                                        .font(.footnote)
                                        .foregroundStyle(Self.mutedInkColor)
                                    if let lastSampleDate = source.lastSampleDate {
                                        Text("Latest \(lastSampleDate, format: .dateTime.month(.abbreviated).day().hour().minute())")
                                            .font(.caption)
                                            .foregroundStyle(Self.mutedInkColor)
                                    }
                                }
                                Spacer()
                                Text("\(source.sampleCount)")
                                    .font(.headline.monospacedDigit())
                                    .foregroundStyle(Self.inkColor)
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
                                            .foregroundStyle(Self.inkColor)
                                        Text(workout.startDate, format: .dateTime.month(.abbreviated).day().hour().minute())
                                            .font(.footnote)
                                            .foregroundStyle(Self.mutedInkColor)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("\(workout.durationMinutes.formattedOneDecimal) min")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Self.inkColor)
                                        if let distance = workout.distanceKilometers {
                                            Text("\(distance.formattedOneDecimal) km")
                                                .font(.footnote)
                                                .foregroundStyle(Self.mutedInkColor)
                                        } else if let calories = workout.energyKilocalories {
                                            Text("\(calories.formattedOneDecimal) kcal")
                                                .font(.footnote)
                                                .foregroundStyle(Self.mutedInkColor)
                                        }
                                    }
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .fill(Self.warningAccent.opacity(0.10))
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
                                            .foregroundStyle(Self.inkColor)
                                        Text(reading.startDate, format: .dateTime.month(.abbreviated).day().hour().minute())
                                            .font(.footnote)
                                            .foregroundStyle(Self.mutedInkColor)
                                        Text(reading.symptomsStatus)
                                            .font(.footnote)
                                            .foregroundStyle(Self.mutedInkColor)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(reading.averageHeartRate.map { "\($0.formattedOneDecimal) bpm" } ?? "—")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Self.inkColor)
                                        Text(reading.samplingFrequencyHertz.map { "\($0.formattedOneDecimal) Hz" } ?? "—")
                                            .font(.footnote)
                                            .foregroundStyle(Self.mutedInkColor)
                                    }
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        // Intentional Tier-3.2 exception: `HealthPalette.plum`
                                        // is a §7-out-of-scope local color — NOT a §6 box-4
                                        // alias, no `AppTheme.Palette` counterpart. Left as-is.
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
    // MARK: - Box-4 color tokens (Tier 3.3 migration)
    //
    // Tier 3.3 migration (audit §8.1 box 4): `HealthAccessIntroScreen`'s
    // 7 §6-alias call sites (across 6 lines) are migrated to the
    // `AppTheme.Palette` contract tokens those aliases resolve to.
    // These `static let`s are wiring pins referencing EXISTING
    // contract tokens — NOT new color tokens — and they dedup the
    // inline references into 3 named constants for the token-wiring
    // test.
    //
    //   HealthPalette.ink      = AppTheme.Palette.textPrimary
    //   HealthPalette.mutedInk = AppTheme.Palette.textSecondary
    //   HealthPalette.mint     = AppTheme.Palette.success
    //
    // This slice is fully resolver-free: `HealthAccessIntroScreen`
    // has zero `HealthPalette.color(for:)` / `statusColor(for:)`
    // calls and zero §7-out-of-scope references — every
    // `HealthPalette.*` site here is a clean box-4 migration.
    static let inkColor = AppTheme.Palette.textPrimary
    static let mutedInkColor = AppTheme.Palette.textSecondary
    static let chipAccent = AppTheme.Palette.success

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
                        CapsuleChip(title: "Local Apple Health access", color: Self.chipAccent)
                        Text("kAir")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(Self.inkColor)
                        Text("Read and analyze Apple Health data directly on-device.")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Self.inkColor)
                        Text(statusMessage)
                            .font(.body)
                            .foregroundStyle(Self.mutedInkColor)

                        VStack(alignment: .leading, spacing: 10) {
                            Label("No XML export", systemImage: "checkmark.circle")
                            Label("No import flow", systemImage: "checkmark.circle")
                            Label("Trends, workouts, sleep, and ECG summaries pulled locally", systemImage: "checkmark.circle")
                        }
                        .font(.subheadline)
                        .foregroundStyle(Self.inkColor)

                        Button(action: action) {
                            Text(supportsHealthData ? "Connect Apple Health" : "HealthKit Unavailable")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(supportsHealthData ? Self.inkColor : Self.mutedInkColor)
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
    // MARK: - Box-4 color tokens (Tier 3.6 migration)
    //
    // Tier 3.6 migration (audit §8.1 box 4): `FailureStateScreen`'s
    // 4 §6-alias occurrences are migrated to the `AppTheme.Palette`
    // contract tokens those aliases resolve to. These `static let`s
    // are wiring pins referencing EXISTING contract tokens — NOT new
    // color tokens — and dedup the inline references for the
    // token-wiring test.
    //
    //   HealthPalette.ink      = AppTheme.Palette.textPrimary
    //   HealthPalette.mutedInk = AppTheme.Palette.textSecondary
    //   HealthPalette.coral    = AppTheme.Palette.danger
    //
    // This slice is fully clean: `FailureStateScreen` has zero
    // `HealthPalette.color(for:)` / `statusColor(for:)` calls and
    // zero §7-out-of-scope references — every `HealthPalette.*` site
    // is a clean box-4 migration, no exceptions.
    static let inkColor = AppTheme.Palette.textPrimary
    static let mutedInkColor = AppTheme.Palette.textSecondary
    static let dangerAccent = AppTheme.Palette.danger

    let message: String
    let retry: () -> Void

    var body: some View {
        ZStack {
            HealthScreenBackground()

            GlassCard {
                VStack(alignment: .leading, spacing: 18) {
                    CapsuleChip(title: "Load failed", color: Self.dangerAccent)
                    Text("kAir couldn’t read the local HealthKit data.")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(Self.inkColor)
                    Text(message)
                        .font(.body)
                        .foregroundStyle(Self.mutedInkColor)

                    Button(action: retry) {
                        Text("Try Again")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Self.inkColor)
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
                // Tier 2 migration (audit §8.1 box 3): the previous
                // `.font(.caption.weight(.bold))` + `.tracking(1.1)`
                // pair used the eyebrow font but an off-spec
                // tracking (`1.1`). Routed through the shared
                // `eyebrow` token (tracking `1.2`). `HeroCard` is a
                // `private` struct, so the wiring is build-proven
                // (no test-reachable `static`). The
                // `.foregroundStyle(HealthPalette.mutedInk)` is left
                // untouched — `HealthPalette` is out of Tier-2 scope
                // (audit Tier 4).
                Text("On-Device Model Stack")
                    .kAirTypography(AppTheme.Typography.eyebrow)
                    .foregroundStyle(HealthPalette.mutedInk)

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
    // Tier 3.5 migration (audit §8.1 box 4): `RiskOrb`'s 5 §6-alias
    // occurrences are migrated to the `AppTheme.Palette` contract
    // tokens those aliases resolve to:
    //
    //   HealthPalette.ink      → AppTheme.Palette.textPrimary    (×2)
    //   HealthPalette.mutedInk → AppTheme.Palette.textSecondary  (×1)
    //   HealthPalette.mint     → AppTheme.Palette.success        (×1)
    //   HealthPalette.cyan     → AppTheme.Palette.sky            (×1)
    //
    // `RiskOrb` is a `private` struct, so — like `HeroCard` (PR #40)
    // — the wiring is build-proven (no test-reachable `static`); the
    // tokens are referenced inline. The migration's visual safety is
    // proven by the box-4 alias-equivalence tests, which assert each
    // `HealthPalette` alias is `==` to its `AppTheme.Palette` target.
    //
    // `RiskOrb` has zero `HealthPalette.color(for:)` /
    // `statusColor(for:)` calls — this slice is resolver-free. The 1
    // §7-out-of-scope reference (`HealthPalette.plum` in the
    // AngularGradient) is NOT migrated; see the inline exception note.
    let value: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppTheme.Palette.textPrimary.opacity(0.08), lineWidth: 16)

            Circle()
                .trim(from: 0, to: value)
                .stroke(
                    AngularGradient(
                        // `HealthPalette.plum` is an intentional Tier-3.5
                        // exception: it is the §7-out-of-scope local
                        // `Color(0.43, 0.40, 0.50)` — NOT a §6 box-4 alias,
                        // no `AppTheme.Palette` counterpart. The other two
                        // gradient stops (`mint`, `cyan`) ARE box-4 aliases
                        // and are migrated.
                        colors: [
                            AppTheme.Palette.success,
                            AppTheme.Palette.sky,
                            HealthPalette.plum,
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 6) {
                Text("Current")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.textSecondary)
                Text(value.formattedPercent0)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(AppTheme.Palette.textPrimary)
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
