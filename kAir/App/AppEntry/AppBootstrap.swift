//
//  AppBootstrap.swift
//  kAir
//
//  Root shell bootstrap state.
//

import Foundation
import Observation

struct AppSurfaceReturnContext {
    let section: AppSection
    let musicSession: MusicPlaybackSession?
    let videoSession: VideoPlaybackSession?
}

@MainActor
@Observable
final class AppBootstrap {
    var currentSection: AppSection = .chat
    var presentedSurface: AppSection?
    var isProfilePresented = false
    var activeHealthSession: HealthRouteSession?
    var activeMusicSession: MusicPlaybackSession?
    var activeVideoSession: VideoPlaybackSession?
    var lastSurfaceEntryRequest: SurfaceEntryRequest?
    private(set) var surfaceEntryRequestsBySection: [AppSection: SurfaceEntryRequest] = [:]
    let healthStore: HealthDashboardStore
    let mapsRuntime: MapsRuntime
    let matchingReplayLab: MatchingReplayLab
    private var surfaceReturnHandler: ((AppSurfaceReturnContext) -> Void)?
    private var surfaceSilentExitHandler: ((AppSection) -> Void)?
    private var surfaceEntryEventHandler: ((SurfaceEntryEventPhase, SurfaceEntryRequest) -> Void)?
    private var surfaceEntryRequestProvider: ((AppSection) -> SurfaceEntryRequest?)?

    init(
        healthStore: HealthDashboardStore? = nil,
        mapsRuntime: MapsRuntime? = nil
    ) {
        self.healthStore = healthStore ?? HealthDashboardStore()
        self.mapsRuntime = mapsRuntime ?? .shared
        self.matchingReplayLab = MatchingReplayLab()
        Task { @MainActor in
            await RuntimeScenarioMatrixRunner.maybeRunOnStartup()
            ReplayEvidenceGenerator.runAndPrintEvidence(lab: self.matchingReplayLab)
            SurfaceEntryCanonicalFlowSeeder.seed(lab: self.matchingReplayLab)
            ReplayEvidenceGenerator.printSurfaceEntryChains(lab: self.matchingReplayLab)
            Self.runStartupTestSuites()
        }
    }

    @MainActor
    private static func runStartupTestSuites() {
        let p1 = RecommendationDecisionTests.runAll()
        print("[P1 Decision Tests] passed=\(p1.passedCount) failed=\(p1.failedCount)")
        for result in p1.results { print(result.line) }

        let p2 = EventLoopTests.runAll()
        print("[P2 Event Loop Tests] passed=\(p2.passedCount) failed=\(p2.failedCount)")
        for result in p2.results { print(result.line) }

        let t1 = SurfaceEntryProtocolTests.runAll()
        print("[T1 Surface Entry Contract Tests] passed=\(t1.passedCount) failed=\(t1.failedCount)")
        for result in t1.results { print(result.line) }

        let t2 = SurfaceEntryCanonicalFlowTests.runAll()
        print("[T2 Surface Entry Canonical Flow Tests] passed=\(t2.passedCount) failed=\(t2.failedCount)")
        for result in t2.results { print(result.line) }

        let t3 = ModelLayerStubTests.runAll()
        print("[T3 Model Layer Stub Tests] passed=\(t3.passedCount) failed=\(t3.failedCount)")
        for result in t3.results { print(result.line) }

        let t4 = MapActionCardCanonicalTests.runAll()
        print("[T4 Map Action Card Canonical Tests] passed=\(t4.passedCount) failed=\(t4.failedCount)")
        for result in t4.results { print(result.line) }

        let t5 = MapActionCardUIValidationTests.runAll()
        print("[T5 Map Action Card UI Validation Tests] passed=\(t5.passedCount) failed=\(t5.failedCount)")
        for result in t5.results { print(result.line) }

        let t6 = ExecutionSurfaceShellValidationTests.runAll()
        print("[T6 Execution Surface Shell Validation Tests] passed=\(t6.passedCount) failed=\(t6.failedCount)")
        for result in t6.results { print(result.line) }

        let t7 = MusicShellReuseTests.runAll()
        print("[T7 Music Shell Reuse Tests] passed=\(t7.passedCount) failed=\(t7.failedCount)")
        for result in t7.results { print(result.line) }

        let t8 = ShellExceptionGuardTests.runAll()
        print("[T8 Shell Exception Guard Tests] passed=\(t8.passedCount) failed=\(t8.failedCount)")
        for result in t8.results { print(result.line) }

        let t9 = SearchShellReuseTests.runAll()
        print("[T9 Search Shell Reuse Tests] passed=\(t9.passedCount) failed=\(t9.failedCount)")
        for result in t9.results { print(result.line) }

        let t10 = PostReturnContinuationUXTests.runAll()
        print("[T10 Post-Return Continuation UX Tests] passed=\(t10.passedCount) failed=\(t10.failedCount)")
        for result in t10.results { print(result.line) }

        let t11 = NegativeFeedbackUXTests.runAll()
        print("[T11 Negative Feedback UX Tests] passed=\(t11.passedCount) failed=\(t11.failedCount)")
        for result in t11.results { print(result.line) }

        let t12 = MixedRecommendationLayoutTests.runAll()
        print("[T12 Mixed Recommendation Layout Tests] passed=\(t12.passedCount) failed=\(t12.failedCount)")
        for result in t12.results { print(result.line) }
    }

    func showProfile() {
        isProfilePresented = true
    }

    func registerSurfaceReturnHandler(_ handler: @escaping (AppSurfaceReturnContext) -> Void) {
        surfaceReturnHandler = handler
    }

    func registerSurfaceSilentExitHandler(_ handler: @escaping (AppSection) -> Void) {
        surfaceSilentExitHandler = handler
    }

    func registerSurfaceEntryEventHandler(
        _ handler: @escaping (SurfaceEntryEventPhase, SurfaceEntryRequest) -> Void
    ) {
        surfaceEntryEventHandler = handler
    }

    func registerSurfaceEntryRequestProvider(
        _ provider: @escaping (AppSection) -> SurfaceEntryRequest?
    ) {
        surfaceEntryRequestProvider = provider
    }

    func currentEntryRequest(for section: AppSection) -> SurfaceEntryRequest? {
        surfaceEntryRequestsBySection[section]
    }

    func openSurface(_ section: AppSection) {
        openSurface(section, request: nil)
    }

    private func openSurface(_ section: AppSection, request providedRequest: SurfaceEntryRequest?) {
        guard section != .chat else {
            closeSurface()
            return
        }

        let request = resolveEntryRequest(for: section, provided: providedRequest)
        surfaceEntryEventHandler?(.requested, request)

        currentSection = section
        presentedSurface = section
        surfaceEntryRequestsBySection[section] = request
        lastSurfaceEntryRequest = request

        surfaceEntryEventHandler?(.started, request)
    }

    func open(request: SurfaceEntryRequest) {
        openSurface(request.surfaceType, request: request)
    }

    private func resolveEntryRequest(
        for section: AppSection,
        provided: SurfaceEntryRequest?
    ) -> SurfaceEntryRequest {
        if let provided, provided.surfaceType == section {
            return provided
        }
        if let richer = surfaceEntryRequestProvider?(section),
           richer.surfaceType == section {
            return richer
        }
        return SurfaceEntryRequest(
            surfaceType: section,
            entryIntent: SurfaceEntryIntent(section: section)
        )
    }

    func openMaps(with task: MapTask? = nil) {
        if let task {
            mapsRuntime.present(task: task)
        }
        let request = buildMapsEntryRequest(for: task)
        openSurface(.maps, request: request)
    }

    func openHealth(with session: HealthRouteSession? = nil) {
        if let session {
            activeHealthSession = session
        }
        let request = buildHealthEntryRequest(for: session)
        openSurface(.health, request: request)
    }

    func startMusic(with session: MusicPlaybackSession) {
        activeMusicSession = session
    }

    func openMusic(with session: MusicPlaybackSession? = nil) {
        if let session {
            activeMusicSession = session
        }
        let request = buildMusicEntryRequest(for: session)
        openSurface(.music, request: request)
    }

    func stopMusic() {
        activeMusicSession = nil
        if presentedSurface == .music {
            presentedSurface = nil
            currentSection = .chat
        }
    }

    func openVideo(with session: VideoPlaybackSession? = nil) {
        if let session {
            activeVideoSession = session
        }
        let request = buildVideoEntryRequest(for: session)
        openSurface(.video, request: request)
    }

    // MARK: - Request builders (adapter layer, no business-logic changes)

    private func buildMapsEntryRequest(for task: MapTask?) -> SurfaceEntryRequest? {
        guard let task else { return nil }
        let intent: SurfaceEntryIntent = {
            switch task.taskType {
            case .goToPlace:
                return .navigate
            case .nearbySearch:
                return .discoverNearby
            case .recommendation, .routeComparison:
                return .reviewRoute
            }
        }()
        var args: [String: String] = [
            "query": task.query,
            "task_type": task.taskType.rawValue,
            "language": task.language.usesChineseCopy ? "zh" : "en",
            "entry_mode": task.entryMode.rawValue,
        ]
        if let mode = task.transportMode {
            args["transport_mode"] = mode.rawValue
        }
        if let destination = task.selectedDestination {
            args["destination_title"] = destination.title
        }
        return SurfaceEntryRequest(
            surfaceType: .maps,
            entryIntent: intent,
            sourceThreadId: task.threadId.uuidString,
            objectType: MatchingObjectKind.place.rawValue,
            objectId: task.id,
            normalizedArgs: args,
            handoffContext: SurfaceEntryHandoffContext(
                sourceMessagePreview: task.query,
                returnThreadId: task.threadId.uuidString,
                priorContextStateSummary: task.resultSummary.isEmpty ? nil : task.resultSummary
            )
        )
    }

    private func buildMusicEntryRequest(for session: MusicPlaybackSession?) -> SurfaceEntryRequest? {
        guard let session else { return nil }
        let args: [String: String] = [
            "mood": session.mood.rawValue,
            "query": session.query,
            "title": session.title,
            "source": session.sourceLabel,
        ]
        return SurfaceEntryRequest(
            surfaceType: .music,
            entryIntent: .playMusic,
            objectType: MatchingObjectKind.song.rawValue,
            objectId: session.id.uuidString,
            normalizedArgs: args,
            handoffContext: SurfaceEntryHandoffContext(
                sourceMessagePreview: session.query,
                returnThreadId: nil,
                priorContextStateSummary: session.subtitle
            )
        )
    }

    private func buildVideoEntryRequest(for session: VideoPlaybackSession?) -> SurfaceEntryRequest? {
        guard let session else { return nil }
        let args: [String: String] = [
            "category": session.category.rawValue,
            "query": session.query,
            "title": session.title,
            "duration": session.durationLabel,
        ]
        return SurfaceEntryRequest(
            surfaceType: .video,
            entryIntent: .watchVideo,
            objectType: MatchingObjectKind.video.rawValue,
            objectId: session.id.uuidString,
            normalizedArgs: args,
            handoffContext: SurfaceEntryHandoffContext(
                sourceMessagePreview: session.query,
                returnThreadId: nil,
                priorContextStateSummary: session.summary
            )
        )
    }

    private func buildHealthEntryRequest(for session: HealthRouteSession?) -> SurfaceEntryRequest? {
        guard let session else { return nil }
        let args: [String: String] = [
            "topic": session.topic.rawValue,
            "language": session.language == .chinese ? "zh" : "en",
            "original_prompt": session.originalPrompt,
        ]
        return SurfaceEntryRequest(
            surfaceType: .health,
            entryIntent: .openHealth,
            objectType: MatchingObjectKind.answerCard.rawValue,
            objectId: nil,
            normalizedArgs: args,
            handoffContext: SurfaceEntryHandoffContext(
                sourceMessagePreview: session.originalPrompt,
                returnThreadId: nil,
                priorContextStateSummary: nil
            )
        )
    }

    func closeSurface(
        notifyingReturn: Bool = false,
        notifyingSilentExit: Bool = true
    ) {
        let closingSection = presentedSurface
        let returnContext = closingSection.map {
            AppSurfaceReturnContext(
                section: $0,
                musicSession: activeMusicSession,
                videoSession: activeVideoSession
            )
        }

        if notifyingReturn, let returnContext {
            surfaceReturnHandler?(returnContext)
        } else if notifyingReturn == false, notifyingSilentExit, let closingSection {
            surfaceSilentExitHandler?(closingSection)
        }

        if let closingSection,
           let request = surfaceEntryRequestsBySection[closingSection] {
            surfaceEntryEventHandler?(.returned, request)
            surfaceEntryRequestsBySection[closingSection] = nil
        }

        currentSection = .chat
        presentedSurface = nil
        activeHealthSession = nil

        if closingSection == .video {
            activeVideoSession = nil
        }
    }

    func returnToChat() {
        guard let presentedSurface else {
            closeSurface()
            return
        }

        if presentedSurface == .maps {
            mapsRuntime.completeReturnToChat()
        }

        closeSurface(notifyingReturn: true)
    }

    static var preview: AppBootstrap {
        AppBootstrap(healthStore: .preview)
    }
}
