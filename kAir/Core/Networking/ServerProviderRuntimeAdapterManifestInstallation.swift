//
//  ServerProviderRuntimeAdapterManifestInstallation.swift
//  kAir
//
//  Value-only manifest-backed installation planning for future adapters.
//

import Foundation

enum ServerProviderRuntimeAdapterManifestInstallationState: String, Codable, Hashable, Sendable, CaseIterable {
    case installable
    case rejected
}

enum ServerProviderRuntimeAdapterManifestInstallationRejection: String, Codable, Hashable, Sendable, CaseIterable {
    case localNoServerAdapter
    case missingManifest
    case manifestProviderFamilyMismatch
    case manifestReadinessFamilyMismatch
    case manifestReadinessGateDrift
    case installationRejected
}

struct ServerProviderRuntimeAdapterManifestInstallationDecision:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let providerFamily: ProviderFamily
    let state: ServerProviderRuntimeAdapterManifestInstallationState
    let rejection: ServerProviderRuntimeAdapterManifestInstallationRejection?
    let manifestID: String?
    let manifestProviderFamily: ProviderFamily?
    let manifestRequiredGates: Set<ServerProviderRuntimeAdapterReadinessGate>
    let readinessReportID: String?
    let readinessReportFamily: ProviderFamily?
    let readinessState: ServerProviderRuntimeAdapterReadinessState?
    let readinessRequiredGates: Set<ServerProviderRuntimeAdapterReadinessGate>
    let missingGates: Set<ServerProviderRuntimeAdapterReadinessGate>
    let installationDecision: ServerProviderRuntimeAdapterInstallationDecision?

    var isInstallable: Bool {
        state == .installable
            && installationDecision?.isInstallable == true
    }

    var statusLine: String {
        switch state {
        case .installable:
            return "Manifest-backed adapter installation is value-ready for \(providerFamily.rawValue). Metadata only; no provider runtime has run."
        case .rejected:
            return "Manifest-backed adapter installation is rejected for \(providerFamily.rawValue): \(rejection?.rawValue ?? "unknown"). Metadata only; no provider runtime has run."
        }
    }

    var description: String {
        "ServerProviderRuntimeAdapterManifestInstallationDecision(id: \(id), providerFamily: \(providerFamily.rawValue), state: \(state.rawValue), rejection: \(rejection?.rawValue ?? "none"))"
    }
}

@MainActor
enum ServerProviderRuntimeAdapterManifestInstallationPlanner {
    static func decisions(
        for providerFamilies: [ProviderFamily],
        reportsByProviderFamily: [ProviderFamily: ServerProviderRuntimeAdapterReadinessReport]
    ) -> [ServerProviderRuntimeAdapterManifestInstallationDecision] {
        decisions(
            for: providerFamilies,
            reportsByProviderFamily: reportsByProviderFamily,
            manifestsByProviderFamily: defaultManifestsByProviderFamily()
        )
    }

    static func decisions(
        for providerFamilies: [ProviderFamily],
        reportsByProviderFamily: [ProviderFamily: ServerProviderRuntimeAdapterReadinessReport],
        manifestsByProviderFamily: [ProviderFamily: ServerProviderRuntimeAdapterManifest]
    ) -> [ServerProviderRuntimeAdapterManifestInstallationDecision] {
        providerFamilies.map { providerFamily in
            decision(
                for: providerFamily,
                reportsByProviderFamily: reportsByProviderFamily,
                manifestsByProviderFamily: manifestsByProviderFamily
            )
        }
    }

    static func decision(
        for providerFamily: ProviderFamily,
        reportsByProviderFamily: [ProviderFamily: ServerProviderRuntimeAdapterReadinessReport]
    ) -> ServerProviderRuntimeAdapterManifestInstallationDecision {
        decision(
            for: providerFamily,
            reportsByProviderFamily: reportsByProviderFamily,
            manifestsByProviderFamily: defaultManifestsByProviderFamily()
        )
    }

    static func decision(
        for providerFamily: ProviderFamily,
        reportsByProviderFamily: [ProviderFamily: ServerProviderRuntimeAdapterReadinessReport],
        manifestsByProviderFamily: [ProviderFamily: ServerProviderRuntimeAdapterManifest]
    ) -> ServerProviderRuntimeAdapterManifestInstallationDecision {
        guard providerFamily.isRemote else {
            return rejected(
                providerFamily: providerFamily,
                manifest: manifestsByProviderFamily[providerFamily],
                report: nil,
                rejection: .localNoServerAdapter,
                installationDecision: nil
            )
        }

        guard let manifest = manifestsByProviderFamily[providerFamily] else {
            return rejected(
                providerFamily: providerFamily,
                manifest: nil,
                report: nil,
                rejection: .missingManifest,
                installationDecision: nil
            )
        }

        guard manifest.providerFamily == providerFamily else {
            return rejected(
                providerFamily: providerFamily,
                manifest: manifest,
                report: nil,
                rejection: .manifestProviderFamilyMismatch,
                installationDecision: nil
            )
        }

        guard let report = reportsByProviderFamily[providerFamily] else {
            return fromInstallationGate(
                providerFamily: providerFamily,
                manifest: manifest,
                reportsByProviderFamily: reportsByProviderFamily
            )
        }

        guard report.providerFamily == manifest.providerFamily else {
            return rejected(
                providerFamily: providerFamily,
                manifest: manifest,
                report: report,
                rejection: .manifestReadinessFamilyMismatch,
                installationDecision: nil
            )
        }

        guard report.requiredGates == manifest.requiredReadinessGates else {
            return rejected(
                providerFamily: providerFamily,
                manifest: manifest,
                report: report,
                rejection: .manifestReadinessGateDrift,
                installationDecision: nil
            )
        }

        return fromInstallationGate(
            providerFamily: providerFamily,
            manifest: manifest,
            reportsByProviderFamily: reportsByProviderFamily
        )
    }

    private static func fromInstallationGate(
        providerFamily: ProviderFamily,
        manifest: ServerProviderRuntimeAdapterManifest,
        reportsByProviderFamily: [ProviderFamily: ServerProviderRuntimeAdapterReadinessReport]
    ) -> ServerProviderRuntimeAdapterManifestInstallationDecision {
        let installation = ServerProviderRuntimeAdapterInstallationGate.decision(
            for: providerFamily,
            reportsByProviderFamily: reportsByProviderFamily
        )
        let report = reportsByProviderFamily[providerFamily]

        if installation.isInstallable {
            return ServerProviderRuntimeAdapterManifestInstallationDecision(
                id: "provider-runtime-adapter-manifest-installation-\(providerFamily.rawValue)",
                providerFamily: providerFamily,
                state: .installable,
                rejection: nil,
                manifestID: manifest.id,
                manifestProviderFamily: manifest.providerFamily,
                manifestRequiredGates: manifest.requiredReadinessGates,
                readinessReportID: report?.id,
                readinessReportFamily: report?.providerFamily,
                readinessState: report?.state,
                readinessRequiredGates: report?.requiredGates ?? [],
                missingGates: installation.missingGates,
                installationDecision: installation
            )
        }

        return rejected(
            providerFamily: providerFamily,
            manifest: manifest,
            report: report,
            rejection: .installationRejected,
            installationDecision: installation
        )
    }

    private static func rejected(
        providerFamily: ProviderFamily,
        manifest: ServerProviderRuntimeAdapterManifest?,
        report: ServerProviderRuntimeAdapterReadinessReport?,
        rejection: ServerProviderRuntimeAdapterManifestInstallationRejection,
        installationDecision: ServerProviderRuntimeAdapterInstallationDecision?
    ) -> ServerProviderRuntimeAdapterManifestInstallationDecision {
        ServerProviderRuntimeAdapterManifestInstallationDecision(
            id: "provider-runtime-adapter-manifest-installation-\(providerFamily.rawValue)",
            providerFamily: providerFamily,
            state: .rejected,
            rejection: rejection,
            manifestID: manifest?.id,
            manifestProviderFamily: manifest?.providerFamily,
            manifestRequiredGates: manifest?.requiredReadinessGates ?? [],
            readinessReportID: report?.id,
            readinessReportFamily: report?.providerFamily,
            readinessState: report?.state,
            readinessRequiredGates: report?.requiredGates ?? [],
            missingGates: installationDecision?.missingGates ?? report?.missingGates ?? [],
            installationDecision: installationDecision
        )
    }

    private static func defaultManifestsByProviderFamily() -> [ProviderFamily: ServerProviderRuntimeAdapterManifest] {
        Dictionary(
            uniqueKeysWithValues: ServerProviderRuntimeAdapterManifestCatalog.manifests.map { manifest in
                (manifest.providerFamily, manifest)
            }
        )
    }
}
