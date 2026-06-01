//
//  ServerProviderRuntimeAdapterReadinessGate.swift
//  kAir
//
//  Value-only installation gate for future provider adapters.
//

import Foundation

enum ServerProviderRuntimeAdapterInstallationState: String, Codable, Hashable, Sendable, CaseIterable {
    case installable
    case rejected
}

enum ServerProviderRuntimeAdapterInstallationRejection: String, Codable, Hashable, Sendable, CaseIterable {
    case localNoServerAdapter
    case missingReadinessReport
    case readinessReportFamilyMismatch
    case readinessReportNotReady
    case readinessMissingRequiredGates
}

struct ServerProviderRuntimeAdapterInstallationDecision: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let providerFamily: ProviderFamily
    let state: ServerProviderRuntimeAdapterInstallationState
    let rejection: ServerProviderRuntimeAdapterInstallationRejection?
    let readinessReportID: String?
    let readinessReportFamily: ProviderFamily?
    let readinessState: ServerProviderRuntimeAdapterReadinessState?
    let missingGates: Set<ServerProviderRuntimeAdapterReadinessGate>

    var isInstallable: Bool {
        state == .installable
    }
}

enum ServerProviderRuntimeAdapterInstallationGate {
    static func decisions(
        for providerFamilies: [ProviderFamily],
        reportsByProviderFamily: [ProviderFamily: ServerProviderRuntimeAdapterReadinessReport]
    ) -> [ServerProviderRuntimeAdapterInstallationDecision] {
        providerFamilies.map { family in
            decision(
                for: family,
                reportsByProviderFamily: reportsByProviderFamily
            )
        }
    }

    static func decision(
        for providerFamily: ProviderFamily,
        reportsByProviderFamily: [ProviderFamily: ServerProviderRuntimeAdapterReadinessReport]
    ) -> ServerProviderRuntimeAdapterInstallationDecision {
        let report = reportsByProviderFamily[providerFamily]

        guard providerFamily.isRemote else {
            return rejected(
                providerFamily: providerFamily,
                report: report,
                rejection: .localNoServerAdapter,
                missingGates: []
            )
        }

        guard let report else {
            return rejected(
                providerFamily: providerFamily,
                report: nil,
                rejection: .missingReadinessReport,
                missingGates: []
            )
        }

        guard report.providerFamily == providerFamily else {
            return rejected(
                providerFamily: providerFamily,
                report: report,
                rejection: .readinessReportFamilyMismatch,
                missingGates: report.missingGates
            )
        }

        guard report.requiresServerSideAdapter else {
            return rejected(
                providerFamily: providerFamily,
                report: report,
                rejection: .localNoServerAdapter,
                missingGates: report.missingGates
            )
        }

        guard report.missingGates.isEmpty else {
            return rejected(
                providerFamily: providerFamily,
                report: report,
                rejection: .readinessMissingRequiredGates,
                missingGates: report.missingGates
            )
        }

        guard report.state == .readyForServerAdapter else {
            return rejected(
                providerFamily: providerFamily,
                report: report,
                rejection: .readinessReportNotReady,
                missingGates: report.missingGates
            )
        }

        return ServerProviderRuntimeAdapterInstallationDecision(
            id: "provider-runtime-adapter-installation-\(providerFamily.rawValue)",
            providerFamily: providerFamily,
            state: .installable,
            rejection: nil,
            readinessReportID: report.id,
            readinessReportFamily: report.providerFamily,
            readinessState: report.state,
            missingGates: []
        )
    }

    private static func rejected(
        providerFamily: ProviderFamily,
        report: ServerProviderRuntimeAdapterReadinessReport?,
        rejection: ServerProviderRuntimeAdapterInstallationRejection,
        missingGates: Set<ServerProviderRuntimeAdapterReadinessGate>
    ) -> ServerProviderRuntimeAdapterInstallationDecision {
        ServerProviderRuntimeAdapterInstallationDecision(
            id: "provider-runtime-adapter-installation-\(providerFamily.rawValue)",
            providerFamily: providerFamily,
            state: .rejected,
            rejection: rejection,
            readinessReportID: report?.id,
            readinessReportFamily: report?.providerFamily,
            readinessState: report?.state,
            missingGates: missingGates
        )
    }
}
