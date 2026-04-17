//
//  HealthDashboardStore.swift
//  kAir
//
//  Created by Codex on 2026/4/16.
//

import Foundation
import HealthKit
import Observation

@MainActor
@Observable
final class HealthDashboardStore {
    enum Phase {
        case intro
        case authorizing
        case loading
        case loaded
        case failed
    }

    private let service: HealthKitService?
    private var hasBootstrapped = false

    var phase: Phase = .intro
    var dashboard: HealthDashboard?
    var errorMessage: String?
    var statusMessage = "kAir reads Apple Health directly from this iPhone. No XML export or manual import is required."
    let supportsHealthData: Bool

    init(
        service: HealthKitService?,
        supportsHealthData: Bool = HKHealthStore.isHealthDataAvailable()
    ) {
        self.service = service
        self.supportsHealthData = supportsHealthData
    }

    init(
        supportsHealthData: Bool = HKHealthStore.isHealthDataAvailable()
    ) {
        self.service = HealthKitService()
        self.supportsHealthData = supportsHealthData
    }

    static var preview: HealthDashboardStore {
        let store = HealthDashboardStore(service: nil, supportsHealthData: true)
        store.phase = .loaded
        store.dashboard = .preview
        return store
    }

    func bootstrap() {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        Task {
            await prepareInitialState()
        }
    }

    func requestAccess() {
        Task {
            await requestAccessAndRefresh()
        }
    }

    func refresh() {
        Task {
            await refreshDashboard()
        }
    }

    private func prepareInitialState() async {
        guard supportsHealthData else {
            phase = .failed
            errorMessage = "HealthKit is not available on this device."
            return
        }
        guard let service else {
            phase = .loaded
            dashboard = .preview
            return
        }

        phase = .loading
        errorMessage = nil
        statusMessage = "Checking Apple Health access…"

        do {
            let requestStatus = try await service.authorizationRequestStatus()
            switch requestStatus {
            case .shouldRequest:
                phase = .intro
                statusMessage = "Grant Apple Health access once, then kAir will read and analyze the data locally on-device."
            case .unknown:
                phase = .intro
                statusMessage = "Apple Health authorization status is not determined yet."
            case .unnecessary:
                await refreshDashboard()
            @unknown default:
                phase = .intro
                statusMessage = "Connect Apple Health to begin local analysis."
            }
        } catch {
            phase = .intro
            statusMessage = "Connect Apple Health to begin local analysis."
        }
    }

    private func requestAccessAndRefresh() async {
        guard let service else { return }

        phase = .authorizing
        errorMessage = nil
        statusMessage = "Requesting Apple Health access…"

        do {
            try await service.requestAuthorization()
            await refreshDashboard()
        } catch {
            if Self.isAuthorizationDenied(error) {
                phase = .intro
                errorMessage = nil
                statusMessage = "Health access was not granted. You can authorize it later when you want local evidence and trends."
            } else {
                phase = .failed
                errorMessage = Self.userFacingError(for: error)
            }
        }
    }

    private func refreshDashboard() async {
        guard let service else {
            phase = .loaded
            dashboard = .preview
            return
        }

        phase = .loading
        errorMessage = nil
        statusMessage = "Analyzing local Apple Health data…"

        do {
            let dashboard = try await service.loadDashboard()
            self.dashboard = dashboard
            phase = .loaded
            statusMessage = "Last refreshed \(dashboard.generatedAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))"
        } catch {
            if Self.isAuthorizationDenied(error) {
                phase = .intro
                dashboard = nil
                errorMessage = nil
                statusMessage = "Authorize Apple Health when you want kAir to ground this thread in local evidence."
            } else {
                phase = .failed
                errorMessage = Self.userFacingError(for: error)
            }
        }
    }

    private static func userFacingError(for error: Error) -> String {
        if let localized = error as? LocalizedError, let message = localized.errorDescription {
            return message
        }
        return error.localizedDescription
    }

    private static func isAuthorizationDenied(_ error: Error) -> Bool {
        if let healthError = error as? HKError {
            return healthError.code == .errorAuthorizationDenied
        }

        let nsError = error as NSError
        return nsError.domain == HKError.errorDomain &&
            nsError.code == HKError.Code.errorAuthorizationDenied.rawValue
    }
}
