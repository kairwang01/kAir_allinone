//
//  HealthToolAdapter.swift
//  Kair Health
//
//  Minimal bridge for exposing local Health workspace capabilities to chat.
//  This adapter only returns summarized workspace output and never forwards
//  raw HealthKit samples to the general chat layer.
//

import Foundation
import HealthKit

protocol HealthWorkspaceDataProviding {
    func loadDashboard() async throws -> HealthWorkspaceDashboard
}

struct LiveHealthWorkspaceDataProvider: HealthWorkspaceDataProviding {
    private let service: HealthKitService

    init(service: HealthKitService = HealthKitService()) {
        self.service = service
    }

    func loadDashboard() async throws -> HealthWorkspaceDashboard {
        try await service.loadDashboard()
    }
}

struct PreviewHealthWorkspaceDataProvider: HealthWorkspaceDataProviding {
    func loadDashboard() async throws -> HealthWorkspaceDashboard {
        .preview
    }
}

protocol HealthToolAdapting {
    var supportedIntents: [HealthToolIntent] { get }
    func perform(_ request: HealthToolRequest) async throws -> HealthToolResponse
}

enum HealthToolAdapterError: LocalizedError {
    case accessRequired
    case healthDataUnavailable
    case localAnalysisFailed(String)

    var errorDescription: String? {
        switch self {
        case .accessRequired:
            "Health access is required before the local Health workspace can answer this request."
        case .healthDataUnavailable:
            "Health data is not available on this device."
        case .localAnalysisFailed(let message):
            message
        }
    }
}

struct HealthToolAdapter: HealthToolAdapting {
    private let provider: any HealthWorkspaceDataProviding

    init(provider: any HealthWorkspaceDataProviding = LiveHealthWorkspaceDataProvider()) {
        self.provider = provider
    }

    var supportedIntents: [HealthToolIntent] {
        HealthToolIntent.allCases
    }

    func perform(_ request: HealthToolRequest) async throws -> HealthToolResponse {
        do {
            let dashboard = try await provider.loadDashboard()
            let snapshot = HealthWorkspaceSnapshot(
                dashboard: dashboard,
                maxHighlights: request.maxItems
            )
            return makeResponse(for: request.intent, snapshot: snapshot)
        } catch {
            throw map(error)
        }
    }

    private func makeResponse(
        for intent: HealthToolIntent,
        snapshot: HealthWorkspaceSnapshot
    ) -> HealthToolResponse {
        switch intent {
        case .workspaceSummary:
            return HealthToolResponse(
                intent: intent,
                title: intent.title,
                summary: snapshot.summary,
                highlights: [
                    snapshot.availabilitySummary,
                    snapshot.recommendation,
                    snapshot.privacyBoundary.summary,
                ],
                generatedAt: snapshot.generatedAt,
                privacyBoundary: snapshot.privacyBoundary
            )
        case .focusAreas:
            return HealthToolResponse(
                intent: intent,
                title: intent.title,
                summary: "Current local focus areas from the Health workspace.",
                highlights: snapshot.focusAreas,
                generatedAt: snapshot.generatedAt,
                privacyBoundary: snapshot.privacyBoundary
            )
        case .trendHighlights:
            return HealthToolResponse(
                intent: intent,
                title: intent.title,
                summary: "Recent summarized health trends derived locally from HealthKit.",
                highlights: snapshot.trendHighlights.map { "\($0.title): \($0.summary)" },
                generatedAt: snapshot.generatedAt,
                privacyBoundary: snapshot.privacyBoundary
            )
        case .modelWatchlist:
            return HealthToolResponse(
                intent: intent,
                title: intent.title,
                summary: "Local watchpoints from the on-device Health workspace.",
                highlights: snapshot.modelWatchpoints.map { "\($0.title) [\($0.band)]: \($0.summary)" },
                generatedAt: snapshot.generatedAt,
                privacyBoundary: snapshot.privacyBoundary
            )
        }
    }

    private func map(_ error: Error) -> HealthToolAdapterError {
        if let serviceError = error as? HealthKitService.ServiceError {
            switch serviceError {
            case .healthDataUnavailable:
                return .healthDataUnavailable
            }
        }

        if let healthError = error as? HKError,
           healthError.code == .errorAuthorizationDenied {
            return .accessRequired
        }

        if let localized = error as? LocalizedError,
           let message = localized.errorDescription {
            return .localAnalysisFailed(message)
        }

        return .localAnalysisFailed(error.localizedDescription)
    }
}
