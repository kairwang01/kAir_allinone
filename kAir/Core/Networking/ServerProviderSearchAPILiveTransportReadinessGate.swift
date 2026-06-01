//
//  ServerProviderSearchAPILiveTransportReadinessGate.swift
//  kAir
//
//  A145 value-only readiness gate for the A144 Search API live transport
//  boundary. The gate validates planning evidence only; it does not expose a
//  callable remote path.
//

import Foundation

enum ServerProviderSearchAPILiveTransportReadinessState:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case readyForPlanning
    case rejected
}

enum ServerProviderSearchAPILiveTransportReadinessRejection:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case staleBoundaryID
    case callableRuntimeEntrypoint
    case liveProviderPathEnabled
    case duplicateEvidenceID
    case unknownEvidenceTarget
    case unsafeMaterialDetected
    case missingEvidence
}

struct ServerProviderSearchAPILiveTransportReadinessEvidenceTarget:
    Codable,
    Hashable,
    Sendable
{
    let checkpoint: ServerProviderSearchAPILiveTransportBoundaryCheckpoint?
    let readinessItem: ServerProviderSearchAPILiveTransportReadinessItem?
    let unknownID: String?

    static func checkpoint(
        _ checkpoint: ServerProviderSearchAPILiveTransportBoundaryCheckpoint
    ) -> Self {
        Self(checkpoint: checkpoint, readinessItem: nil, unknownID: nil)
    }

    static func readinessItem(
        _ item: ServerProviderSearchAPILiveTransportReadinessItem
    ) -> Self {
        Self(checkpoint: nil, readinessItem: item, unknownID: nil)
    }

    static func unknown(_ id: String) -> Self {
        Self(checkpoint: nil, readinessItem: nil, unknownID: id)
    }

    var targetID: String {
        if let checkpoint {
            return checkpoint.rawValue
        }
        if let readinessItem {
            return readinessItem.rawValue
        }
        return unknownID ?? "unknown"
    }

    var isUnknown: Bool {
        checkpoint == nil && readinessItem == nil
    }
}

struct ServerProviderSearchAPILiveTransportReadinessEvidence:
    Codable,
    Hashable,
    Identifiable,
    Sendable
{
    let id: String
    let target: ServerProviderSearchAPILiveTransportReadinessEvidenceTarget
    let unsafeMaterialMarkers: [String]

    init(
        id: String,
        target: ServerProviderSearchAPILiveTransportReadinessEvidenceTarget,
        unsafeMaterialMarkers: [String] = []
    ) {
        self.id = id
        self.target = target
        self.unsafeMaterialMarkers = unsafeMaterialMarkers
    }

    var normalizedID: String {
        id.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasUnsafeMaterial: Bool {
        unsafeMaterialMarkers.isEmpty == false
    }
}

struct ServerProviderSearchAPILiveTransportReadinessRequest:
    Codable,
    Hashable,
    Sendable
{
    let boundaryDocument: ServerProviderSearchAPILiveTransportBoundaryDocument
    let evidence: [ServerProviderSearchAPILiveTransportReadinessEvidence]
    let liveProviderPathEnabled: Bool

    init(
        boundaryDocument: ServerProviderSearchAPILiveTransportBoundaryDocument =
            ServerProviderSearchAPILiveTransportBoundary.planningDocument(),
        evidence: [ServerProviderSearchAPILiveTransportReadinessEvidence],
        liveProviderPathEnabled: Bool = false
    ) {
        self.boundaryDocument = boundaryDocument
        self.evidence = evidence
        self.liveProviderPathEnabled = liveProviderPathEnabled
    }
}

struct ServerProviderSearchAPILiveTransportReadinessDecision:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let boundaryID: String
    let state: ServerProviderSearchAPILiveTransportReadinessState
    let rejection: ServerProviderSearchAPILiveTransportReadinessRejection?
    let missingCheckpointIDs: [String]
    let missingReadinessItemIDs: [String]
    let coveredCheckpointIDs: [String]
    let coveredReadinessItemIDs: [String]
    let acceptedEvidenceIDs: [String]
    let duplicateEvidenceID: String?
    let unknownEvidenceID: String?
    let unsafeEvidenceID: String?
    let runtimeEntryPointName: String?
    let liveProviderPathEnabled: Bool

    var isReadyForPlanning: Bool {
        state == .readyForPlanning
            && rejection == nil
            && runtimeEntryPointName == nil
            && liveProviderPathEnabled == false
    }

    var statusLine: String {
        if isReadyForPlanning {
            return "Search API live transport readiness evidence is satisfied for planning only; live provider path remains disabled."
        }
        return "Search API live transport readiness evidence is not satisfied; live provider path remains disabled."
    }

    var safeCopy: ServerProviderSearchAPILiveTransportReadinessSafeCopy {
        ServerProviderSearchAPILiveTransportReadinessSafeCopy(
            id: id,
            state: state.rawValue,
            rejection: rejection?.rawValue,
            boundaryIsCurrent: boundaryID == ServerProviderSearchAPILiveTransportReadinessGate.expectedBoundaryID,
            statusLine: statusLine,
            missingCheckpointIDs: missingCheckpointIDs,
            missingReadinessItemIDs: missingReadinessItemIDs,
            coveredCheckpointIDs: coveredCheckpointIDs,
            coveredReadinessItemIDs: coveredReadinessItemIDs,
            acceptedEvidenceIDs: isReadyForPlanning ? acceptedEvidenceIDs : [],
            hasRuntimeEntrypoint: runtimeEntryPointName != nil,
            liveProviderPathEnabled: liveProviderPathEnabled
        )
    }

    var description: String {
        "SearchAPILiveTransportReadinessDecision(id: \(id), state: \(state.rawValue), rejection: \(rejection?.rawValue ?? "none"), ready: \(isReadyForPlanning))"
    }
}

struct ServerProviderSearchAPILiveTransportReadinessSafeCopy:
    Codable,
    Hashable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let state: String
    let rejection: String?
    let boundaryIsCurrent: Bool
    let statusLine: String
    let missingCheckpointIDs: [String]
    let missingReadinessItemIDs: [String]
    let coveredCheckpointIDs: [String]
    let coveredReadinessItemIDs: [String]
    let acceptedEvidenceIDs: [String]
    let hasRuntimeEntrypoint: Bool
    let liveProviderPathEnabled: Bool

    var description: String {
        "SearchAPILiveTransportReadinessSafeCopy(id: \(id), state: \(state), rejection: \(rejection ?? "none"), readyEvidence: \(acceptedEvidenceIDs.count))"
    }
}

enum ServerProviderSearchAPILiveTransportReadinessGate {
    static let expectedBoundaryID = "a144-search-api-live-transport-boundary"

    static func requiredEvidence(
        idPrefix: String = "a145"
    ) -> [ServerProviderSearchAPILiveTransportReadinessEvidence] {
        let checkpointEvidence = ServerProviderSearchAPILiveTransportBoundaryCheckpoint.requiredChain
            .map { checkpoint in
                ServerProviderSearchAPILiveTransportReadinessEvidence(
                    id: "\(idPrefix)-checkpoint-\(checkpoint.rawValue)",
                    target: .checkpoint(checkpoint)
                )
            }
        let readinessEvidence = ServerProviderSearchAPILiveTransportReadinessItem.requiredSet
            .map { item in
                ServerProviderSearchAPILiveTransportReadinessEvidence(
                    id: "\(idPrefix)-readiness-\(item.rawValue)",
                    target: .readinessItem(item)
                )
            }
        return checkpointEvidence + readinessEvidence
    }

    static func decision(
        request: ServerProviderSearchAPILiveTransportReadinessRequest
    ) -> ServerProviderSearchAPILiveTransportReadinessDecision {
        let boundary = request.boundaryDocument

        if request.liveProviderPathEnabled {
            return rejected(
                boundary: boundary,
                evidence: request.evidence,
                rejection: .liveProviderPathEnabled,
                liveProviderPathEnabled: request.liveProviderPathEnabled
            )
        }

        guard boundary.id == expectedBoundaryID else {
            return rejected(
                boundary: boundary,
                evidence: request.evidence,
                rejection: .staleBoundaryID
            )
        }

        guard boundary.runtimeEntryPointName == nil, boundary.isRuntimeCallable == false else {
            return rejected(
                boundary: boundary,
                evidence: request.evidence,
                rejection: .callableRuntimeEntrypoint
            )
        }

        if let duplicateID = firstDuplicateEvidenceID(request.evidence) {
            return rejected(
                boundary: boundary,
                evidence: request.evidence,
                rejection: .duplicateEvidenceID,
                duplicateEvidenceID: duplicateID
            )
        }

        if let unknownEvidence = request.evidence.first(where: { $0.target.isUnknown }) {
            return rejected(
                boundary: boundary,
                evidence: request.evidence,
                rejection: .unknownEvidenceTarget,
                unknownEvidenceID: unknownEvidence.normalizedID
            )
        }

        if let unsafeEvidence = request.evidence.first(where: \.hasUnsafeMaterial) {
            return rejected(
                boundary: boundary,
                evidence: request.evidence,
                rejection: .unsafeMaterialDetected,
                unsafeEvidenceID: unsafeEvidence.normalizedID
            )
        }

        let coveredCheckpoints = checkpointIDsCovered(by: request.evidence)
        let coveredReadinessItems = readinessItemIDsCovered(by: request.evidence)
        let missingCheckpoints = requiredCheckpointIDs.filter { coveredCheckpoints.contains($0) == false }
        let missingReadinessItems = requiredReadinessItemIDs.filter { coveredReadinessItems.contains($0) == false }

        guard missingCheckpoints.isEmpty, missingReadinessItems.isEmpty else {
            return rejected(
                boundary: boundary,
                evidence: request.evidence,
                rejection: .missingEvidence,
                missingCheckpointIDs: missingCheckpoints,
                missingReadinessItemIDs: missingReadinessItems
            )
        }

        return ServerProviderSearchAPILiveTransportReadinessDecision(
            id: "a145-search-api-live-transport-readiness",
            boundaryID: boundary.id,
            state: .readyForPlanning,
            rejection: nil,
            missingCheckpointIDs: [],
            missingReadinessItemIDs: [],
            coveredCheckpointIDs: requiredCheckpointIDs,
            coveredReadinessItemIDs: requiredReadinessItemIDs,
            acceptedEvidenceIDs: request.evidence.map(\.normalizedID),
            duplicateEvidenceID: nil,
            unknownEvidenceID: nil,
            unsafeEvidenceID: nil,
            runtimeEntryPointName: boundary.runtimeEntryPointName,
            liveProviderPathEnabled: request.liveProviderPathEnabled
        )
    }

    private static var requiredCheckpointIDs: [String] {
        ServerProviderSearchAPILiveTransportBoundaryCheckpoint.requiredChain.map(\.rawValue)
    }

    private static var requiredReadinessItemIDs: [String] {
        ServerProviderSearchAPILiveTransportReadinessItem.requiredSet.map(\.rawValue)
    }

    private static func rejected(
        boundary: ServerProviderSearchAPILiveTransportBoundaryDocument,
        evidence: [ServerProviderSearchAPILiveTransportReadinessEvidence],
        rejection: ServerProviderSearchAPILiveTransportReadinessRejection,
        missingCheckpointIDs: [String] = [],
        missingReadinessItemIDs: [String] = [],
        duplicateEvidenceID: String? = nil,
        unknownEvidenceID: String? = nil,
        unsafeEvidenceID: String? = nil,
        liveProviderPathEnabled: Bool = false
    ) -> ServerProviderSearchAPILiveTransportReadinessDecision {
        ServerProviderSearchAPILiveTransportReadinessDecision(
            id: "a145-search-api-live-transport-readiness",
            boundaryID: boundary.id,
            state: .rejected,
            rejection: rejection,
            missingCheckpointIDs: missingCheckpointIDs,
            missingReadinessItemIDs: missingReadinessItemIDs,
            coveredCheckpointIDs: checkpointIDsCovered(by: evidence),
            coveredReadinessItemIDs: readinessItemIDsCovered(by: evidence),
            acceptedEvidenceIDs: [],
            duplicateEvidenceID: duplicateEvidenceID,
            unknownEvidenceID: unknownEvidenceID,
            unsafeEvidenceID: unsafeEvidenceID,
            runtimeEntryPointName: boundary.runtimeEntryPointName,
            liveProviderPathEnabled: liveProviderPathEnabled
        )
    }

    private static func firstDuplicateEvidenceID(
        _ evidence: [ServerProviderSearchAPILiveTransportReadinessEvidence]
    ) -> String? {
        var seen = Set<String>()
        for item in evidence {
            let normalizedID = item.normalizedID
            if seen.contains(normalizedID) {
                return normalizedID
            }
            seen.insert(normalizedID)
        }
        return nil
    }

    private static func checkpointIDsCovered(
        by evidence: [ServerProviderSearchAPILiveTransportReadinessEvidence]
    ) -> [String] {
        ServerProviderSearchAPILiveTransportBoundaryCheckpoint.requiredChain
            .compactMap { checkpoint in
                evidence.contains(where: { $0.target.checkpoint == checkpoint })
                    ? checkpoint.rawValue
                    : nil
            }
    }

    private static func readinessItemIDsCovered(
        by evidence: [ServerProviderSearchAPILiveTransportReadinessEvidence]
    ) -> [String] {
        ServerProviderSearchAPILiveTransportReadinessItem.requiredSet
            .compactMap { item in
                evidence.contains(where: { $0.target.readinessItem == item })
                    ? item.rawValue
                    : nil
            }
    }
}
