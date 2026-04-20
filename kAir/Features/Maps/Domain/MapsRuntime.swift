//
//  MapsRuntime.swift
//  kAir
//
//  Local-first runtime for active map tasks, provider calls, and thread return.
//

import Foundation
import MapKit

@MainActor
@Observable
final class MapsRuntime {
    static let shared = MapsRuntime()

    private let provider: any MapProviding
    private let permissionManager: LocationPermissionManager
    private let persistence: MapTaskPersistence
    private var threadReturnHandler: ((MapTask) -> Void)?
    private var isReroutingNavigation = false
    private var observers: [UUID: @MainActor (MapsRuntime) -> Void] = [:]

    var activeTask: MapTask?
    var permissionState: MapPermissionState
    var lastManualLocation: MapPlaceCandidate?
    var isLoading = false
    var navigationSession: MapNavigationSession?

    init(
        provider: (any MapProviding)? = nil,
        permissionManager: LocationPermissionManager? = nil,
        persistence: MapTaskPersistence? = nil
    ) {
        self.provider = provider ?? AppleMapProvider()
        self.permissionManager = permissionManager ?? LocationPermissionManager()
        self.persistence = persistence ?? MapTaskPersistence()
        self.activeTask = self.persistence.loadActiveTask()
        self.lastManualLocation = self.persistence.loadLastManualLocation()
        self.permissionState = self.permissionManager.permissionState

        if var activeTask {
            activeTask.permissionState = self.permissionState
            self.activeTask = activeTask
        }
    }

    @discardableResult
    func addObserver(_ observer: @escaping @MainActor (MapsRuntime) -> Void) -> UUID {
        let token = UUID()
        observers[token] = observer
        observer(self)
        return token
    }

    func removeObserver(_ token: UUID) {
        observers[token] = nil
    }

    private func notifyObservers() {
        for observer in observers.values {
            observer(self)
        }
    }

    func registerThreadReturnHandler(_ handler: @escaping (MapTask) -> Void) {
        threadReturnHandler = handler
    }

    func present(task: MapTask) {
        stopNavigation()
        var task = task
        task.permissionState = permissionState
        task.generatedAt = .now
        activeTask = task
        persistence.saveActiveTask(task)
        notifyObservers()
    }

    func completeReturnToChat() {
        guard let activeTask else {
            return
        }

        stopNavigation()
        threadReturnHandler?(activeTask)
        self.activeTask = nil
        persistence.clearActiveTask()
        notifyObservers()
    }

    func resolvePlaces(matching query: String) async -> [MapPlaceCandidate] {
        do {
            return try await provider.resolvePlaces(matching: query, near: lastManualLocation)
        } catch {
            return []
        }
    }

    func recommendationCandidates(
        for query: String,
        language: MapsConversationLanguage
    ) async -> [MapPlaceCandidate] {
        let candidates = await resolvePlaces(matching: query)
        return candidates.enumerated().map { index, candidate in
            let reason = recommendationReason(
                for: candidate,
                query: query,
                language: language,
                index: index
            )
            return MapPlaceCandidate(
                id: candidate.id,
                title: candidate.title,
                subtitle: candidate.subtitle,
                coordinate: candidate.coordinate,
                distanceText: candidate.distanceText,
                reason: reason,
                isCurrentLocation: candidate.isCurrentLocation
            )
        }
    }

    func requestCurrentLocationAnchor(
        language: MapsConversationLanguage
    ) async -> MapPlaceCandidate? {
        permissionState = await permissionManager.requestWhenInUseAuthorizationIfNeeded()

        guard permissionState.canUseCurrentLocation else {
            return nil
        }

        do {
            let location = try await permissionManager.requestCurrentLocation()
            return MapPlaceCandidate.currentLocation(from: location, language: language)
        } catch {
            return nil
        }
    }

    func resolveManualLocation(
        query: String,
        language: MapsConversationLanguage
    ) async -> MapPlaceCandidate? {
        let candidates = await resolvePlaces(matching: query)
        guard let candidate = candidates.first else {
            return nil
        }

        rememberLastManualLocation(candidate)
        return candidate
    }

    func refreshActiveTask() async {
        guard var task = activeTask else {
            return
        }

        isLoading = true
        defer {
            isLoading = false
            persistence.saveActiveTask(task)
            activeTask = task
            notifyObservers()
        }

        task.permissionState = permissionState
        task.errorMessage = nil

        switch task.taskType {
        case .goToPlace:
            task = await refreshGoToTask(task)
        case .nearbySearch:
            task = await refreshNearbyTask(task)
        case .recommendation:
            task = await refreshRecommendationTask(task)
        case .routeComparison:
            task = await refreshRouteTask(task)
        }
    }

    func updateTransportMode(_ mode: MapTransportMode) async {
        guard var task = activeTask else {
            return
        }

        task.transportMode = mode
        activeTask = task
        persistence.saveActiveTask(task)
        notifyObservers()
        await refreshActiveTask()
    }

    func applyManualInput(_ query: String) async -> Bool {
        guard var task = activeTask else {
            return false
        }

        guard let manualInputKind = task.manualInputKind else {
            return false
        }

        guard let place = await resolveManualLocation(query: query, language: task.language) else {
            task.errorMessage = task.language.usesChineseCopy
                ? "没有找到这个地点。你可以换区域、换关键词，或输入更具体的位置。"
                : "That place could not be resolved. Try a different area, keyword, or more specific location."
            activeTask = task
            persistence.saveActiveTask(task)
            notifyObservers()
            return false
        }

        task.manualInputKind = nil
        task.errorMessage = nil

        switch manualInputKind {
        case .anchor:
            task.origin = place
        case .origin:
            task.origin = place
        case .destination:
            task.selectedDestination = place
            task.destinationCandidates = [place]
        }

        activeTask = task
        persistence.saveActiveTask(task)
        notifyObservers()
        await refreshActiveTask()
        return true
    }

    func useCurrentLocationForActiveTask() async -> Bool {
        guard var task = activeTask else {
            return false
        }

        guard let anchor = await requestCurrentLocationAnchor(language: task.language) else {
            task.permissionState = permissionState == .denied ? .manualOnly : permissionState
            task.manualInputKind = task.taskType == .routeComparison ? .origin : .anchor
            activeTask = task
            persistence.saveActiveTask(task)
            notifyObservers()
            return false
        }

        task.origin = anchor
        task.manualInputKind = nil
        activeTask = task
        persistence.saveActiveTask(task)
        notifyObservers()
        await refreshActiveTask()
        return true
    }

    func rememberLastManualLocation(_ place: MapPlaceCandidate) {
        lastManualLocation = place
        persistence.saveLastManualLocation(place)
        notifyObservers()
    }

    @discardableResult
    func startNavigationForActiveTask(mode: MapTransportMode? = nil) async -> Bool {
        guard let activeTask else {
            return false
        }

        guard let destination = activeTask.selectedDestination ?? activeTask.primaryCandidate else {
            return false
        }

        if activeTask.selectedDestination?.id != destination.id || activeTask.hasUsableRoutes == false {
            return await startNavigation(to: destination, mode: mode)
        }

        var task = activeTask
        let permission = await permissionManager.requestWhenInUseAuthorizationIfNeeded()
        permissionState = permission
        task.permissionState = permission

        guard permission.canUseCurrentLocation else {
            task.errorMessage = task.language.usesChineseCopy
                ? "应用内导航需要当前位置权限。你仍然可以打开外部地图。"
                : "In-app navigation needs current location permission. You can still open an external maps app."
            task.statusMessage = nil
            self.activeTask = task
            persistence.saveActiveTask(task)
            notifyObservers()
            return false
        }

        guard let currentLocation = try? await permissionManager.requestCurrentLocation() else {
            task.errorMessage = task.language.usesChineseCopy
                ? "当前位置暂时不可用，应用内导航还不能开始。"
                : "The current location is unavailable right now, so in-app navigation cannot start yet."
            self.activeTask = task
            persistence.saveActiveTask(task)
            notifyObservers()
            return false
        }

        task.origin = MapPlaceCandidate.currentLocation(from: currentLocation, language: task.language)
        task.transportMode = mode ?? task.transportMode ?? task.focusedRoute?.mode ?? .driving
        task = await refreshRouteTask(task)
        self.activeTask = task
        persistence.saveActiveTask(task)
        notifyObservers()

        guard let route = task.focusedRoute, route.available else {
            return false
        }

        navigationSession = makeNavigationSession(
            task: task,
            route: route,
            currentLocation: currentLocation,
            statusMessage: task.language.usesChineseCopy
                ? "应用内导航已开始，会跟随你的当前位置持续更新。"
                : "In-app navigation started and now follows your live location."
        )

        permissionState = await permissionManager.startContinuousLocationUpdates { [weak self] location in
            Task { @MainActor in
                self?.handleNavigationLocationUpdate(location)
            }
        }
        notifyObservers()
        return true
    }

    @discardableResult
    func startNavigation(
        to destination: MapPlaceCandidate,
        mode: MapTransportMode? = nil
    ) async -> Bool {
        guard let activeTask else {
            return false
        }

        let routeTask = MapTask(
            threadId: activeTask.threadId,
            taskType: .routeComparison,
            query: destination.title,
            origin: activeTask.origin,
            destinationCandidates: [destination],
            selectedDestination: destination,
            transportMode: mode ?? activeTask.transportMode ?? .driving,
            permissionState: permissionState,
            entryMode: .actionOpenMaps,
            resultSummary: activeTask.language.usesChineseCopy
                ? "已切换到应用内导航。"
                : "Switched into in-app navigation.",
            language: activeTask.language,
            requestedDisplayMode: .map
        )
        present(task: routeTask)
        return await startNavigationForActiveTask(mode: mode)
    }

    func stopNavigation() {
        navigationSession = nil
        permissionManager.stopContinuousLocationUpdates()
        notifyObservers()
    }

    @discardableResult
    func openPlaceInSystemMaps(_ place: MapPlaceCandidate) -> Bool {
        SystemMapsLauncher.openPlace(place)
    }

    private func refreshGoToTask(_ task: MapTask) async -> MapTask {
        guard task.selectedDestination != nil else {
            return task
        }

        var task = task
        if task.origin == nil, permissionState.canUseCurrentLocation {
            task.origin = await requestCurrentLocationAnchor(language: task.language)
        }

        if task.origin != nil {
            task.transportMode = task.transportMode ?? .driving
            task = await refreshRouteTask(task)
        } else {
            task.statusMessage = task.language.usesChineseCopy
                ? "先确定从当前位置还是手动起点出发，然后再比较路线。"
                : "Choose whether to start from your current location or a manual origin before comparing routes."
            task.resultSummary = task.language.usesChineseCopy
                ? "已确认目的地，可继续补起点。"
                : "Destination confirmed. You can now add an origin."
        }

        return task
    }

    private func refreshNearbyTask(_ task: MapTask) async -> MapTask {
        var task = task
        var anchor = task.origin

        if anchor == nil, permissionState.canUseCurrentLocation {
            anchor = await requestCurrentLocationAnchor(language: task.language)
        }

        guard let anchor else {
            task.errorMessage = task.language.usesChineseCopy
                ? "还没有可用区域。请使用当前位置，或手动输入地点。"
                : "No usable search area is available yet. Use your current location or enter a place manually."
            task.manualInputKind = .anchor
            task.nearbyResults = []
            task.resultSummary = task.language.usesChineseCopy
                ? "附近搜索仍在等待区域。"
                : "Nearby search is still waiting for an area."
            return task
        }

        task.origin = anchor

        do {
            task.nearbyResults = try await provider.searchNearby(query: task.query, around: anchor)
            task.statusMessage = task.language.usesChineseCopy
                ? "已在 Maps 里展示附近结果。"
                : "Nearby results are ready in Maps."
            task.resultSummary = task.language.usesChineseCopy
                ? "已查看 \(task.nearbyResults.count) 个\(task.query)附近结果。"
                : "Reviewed \(task.nearbyResults.count) nearby \(task.query) results."
            if task.nearbyResults.isEmpty {
                task.errorMessage = task.language.usesChineseCopy
                    ? "这一带没有找到结果。你可以换区域、换关键词，或手动输入地点。"
                    : "No results were found in this area. Try a different region, keyword, or manual place."
            }
        } catch {
            task.nearbyResults = []
            task.errorMessage = task.language.usesChineseCopy
                ? "附近搜索暂时失败。你可以换关键词，或改成手动地点。"
                : "Nearby search failed for now. Try another keyword or switch to a manual place."
        }

        return task
    }

    private func refreshRecommendationTask(_ task: MapTask) async -> MapTask {
        var task = task
        if task.destinationCandidates.isEmpty {
            task.destinationCandidates = await recommendationCandidates(
                for: task.query,
                language: task.language
            )
        }

        task.resultSummary = task.language.usesChineseCopy
            ? "已在 Maps 查看推荐地点的空间分布。"
            : "Viewed the recommendation spread in Maps."
        return task
    }

    private func refreshRouteTask(_ task: MapTask) async -> MapTask {
        var task = task

        guard let destination = task.selectedDestination else {
            task.errorMessage = task.language.usesChineseCopy
                ? "目的地还没有确认。"
                : "The destination has not been confirmed yet."
            return task
        }

        var origin = task.origin
        if origin == nil, permissionState.canUseCurrentLocation {
            origin = await requestCurrentLocationAnchor(language: task.language)
        }

        guard let origin else {
            task.routeOptions = []
            task.manualInputKind = .origin
            task.statusMessage = task.language.usesChineseCopy
                ? "要比较路线，还需要一个起点。"
                : "A starting point is still needed before routes can be compared."
            task.resultSummary = task.language.usesChineseCopy
                ? "路线比较仍在等待起点。"
                : "Route comparison is still waiting for an origin."
            return task
        }

        task.origin = origin
        task.transportMode = task.transportMode ?? .driving
        let options = await provider.calculateRoutes(
            from: origin,
            to: destination,
            preferredMode: nil
        )
        task.routeOptions = localizedRouteOptions(options, language: task.language)

        if task.routeOptions.contains(where: \.available) {
            let highlighted = task.routeOptions.first(where: { $0.mode == task.transportMode && $0.available })
                ?? task.routeOptions.first(where: \.recommended)
                ?? task.routeOptions.first(where: \.available)
            if let highlighted {
                task.resultSummary = task.language.usesChineseCopy
                    ? "已比较路线，当前聚焦 \(highlighted.mode.title(for: task.language))，约 \(highlighted.etaText)。"
                    : "Compared routes. The current focus is \(highlighted.mode.title(for: task.language)) at about \(highlighted.etaText)."
            }
            task.statusMessage = task.language.usesChineseCopy
                ? "路线结果已更新，可切换步行、驾车或公交。"
                : "Route results are ready. You can switch between walking, driving, and transit."
        } else {
            task.errorMessage = task.language.usesChineseCopy
                ? "当前方式没有可用路线。你可以切换其他方式，或先查看地点详情。"
                : "No routes are available for the current setup. Try another mode or fall back to place details."
            task.resultSummary = task.language.usesChineseCopy
                ? "当前没有可用路线，已保留地点信息。"
                : "No routes are available right now, but the place details are still kept."
        }

        return task
    }

    private func localizedRouteOptions(
        _ options: [MapRouteOption],
        language: MapsConversationLanguage
    ) -> [MapRouteOption] {
        options.map { option in
            MapRouteOption(
                id: option.id,
                mode: option.mode,
                title: option.mode.title(for: language),
                summary: localizedRouteSummary(option.summary, language: language, mode: option.mode),
                etaText: option.etaText,
                distanceText: option.distanceText,
                distanceMeters: option.distanceMeters,
                expectedTravelTime: option.expectedTravelTime,
                emphasis: option.emphasis,
                recommended: option.recommended,
                available: option.available,
                rankingValue: option.rankingValue,
                polylineCoordinates: option.polylineCoordinates,
                steps: option.steps
            )
        }
    }

    private func localizedRouteSummary(
        _ summary: String,
        language: MapsConversationLanguage,
        mode: MapTransportMode
    ) -> String {
        guard language.usesChineseCopy else {
            return summary
        }

        switch mode {
        case .walking:
            return "已生成步行方式。"
        case .driving:
            return "已生成驾车方式。"
        case .transit:
            return "已生成公交方式。"
        }
    }

    private func handleNavigationLocationUpdate(_ location: CLLocation) {
        guard let activeTask, let navigationSession else {
            return
        }

        let updatedSession = updatedNavigationSession(
            navigationSession,
            task: activeTask,
            location: location
        )
        self.navigationSession = updatedSession
        notifyObservers()

        if updatedSession.hasArrived {
            permissionManager.stopContinuousLocationUpdates()
            var task = activeTask
            task.statusMessage = task.language.usesChineseCopy
                ? "已到达目的地，应用内导航已结束。"
                : "You have arrived. In-app navigation has ended."
            task.resultSummary = task.language.usesChineseCopy
                ? "已在应用内导航到达 \(updatedSession.destination.title)。"
                : "Arrived at \(updatedSession.destination.title) with in-app navigation."
            self.activeTask = task
            persistence.saveActiveTask(task)
            notifyObservers()
            return
        }

        guard shouldRerouteNavigation(updatedSession, location: location) else {
            return
        }

        Task { @MainActor in
            await rerouteNavigation(from: location)
        }
    }

    private func rerouteNavigation(from location: CLLocation) async {
        guard
            isReroutingNavigation == false,
            var activeTask,
            let navigationSession
        else {
            return
        }

        guard navigationSession.mode != .transit else {
            return
        }

        isReroutingNavigation = true
        defer { isReroutingNavigation = false }

        activeTask.origin = MapPlaceCandidate.currentLocation(from: location, language: activeTask.language)
        activeTask.transportMode = navigationSession.mode
        activeTask.statusMessage = activeTask.language.usesChineseCopy
            ? "已根据当前位置重新规划路线。"
            : "The route has been recalculated from your current location."
        activeTask.errorMessage = nil

        let options = await provider.calculateRoutes(
            from: activeTask.origin ?? navigationSession.destination,
            to: navigationSession.destination,
            preferredMode: navigationSession.mode
        )
        activeTask.routeOptions = localizedRouteOptions(options, language: activeTask.language)
        self.activeTask = activeTask
        persistence.saveActiveTask(activeTask)
        notifyObservers()

        guard let route = activeTask.focusedRoute, route.available else {
            var session = navigationSession
            session.statusMessage = activeTask.language.usesChineseCopy
                ? "当前位置无法重新规划路线。"
                : "A refreshed route could not be prepared from the current location."
            self.navigationSession = session
            notifyObservers()
            return
        }

        self.navigationSession = makeNavigationSession(
            task: activeTask,
            route: route,
            currentLocation: location,
            statusMessage: activeTask.statusMessage
        )
        notifyObservers()
    }

    private func makeNavigationSession(
        task: MapTask,
        route: MapRouteOption,
        currentLocation: CLLocation,
        statusMessage: String?
    ) -> MapNavigationSession {
        let destination = task.selectedDestination ?? task.primaryCandidate ?? MapPlaceCandidate(
            title: task.language.usesChineseCopy ? "目的地" : "Destination",
            subtitle: ""
        )

        let seed = MapNavigationSession(
            routeId: route.id,
            mode: route.mode,
            destination: destination,
            routeCoordinates: route.polylineCoordinates,
            steps: route.steps,
            statusMessage: statusMessage
        )

        return updatedNavigationSession(seed, task: task, location: currentLocation, statusMessage: statusMessage)
    }

    private func updatedNavigationSession(
        _ session: MapNavigationSession,
        task: MapTask,
        location: CLLocation,
        statusMessage: String? = nil
    ) -> MapNavigationSession {
        var updated = session
        updated.currentLocation = MapCoordinate(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )

        let destinationDistance = distance(from: location, to: session.destination.coordinate)
        if destinationDistance <= 25 {
            updated.currentStepIndex = max(session.steps.count - 1, 0)
            updated.remainingDistanceMeters = 0
            updated.remainingDistanceText = formatDistance(0)
            updated.remainingETA = formatETA(0)
            updated.nextInstruction = task.language.usesChineseCopy
                ? "已到达目的地"
                : "Arrived at destination"
            updated.nextInstructionDetail = session.destination.title
            updated.progressFraction = 1
            updated.hasArrived = true
            updated.statusMessage = task.language.usesChineseCopy
                ? "导航已完成。"
                : "Navigation complete."
            return updated
        }

        let stepIndex = nextStepIndex(for: location, steps: session.steps)
        let nextStep = session.steps.indices.contains(stepIndex) ? session.steps[stepIndex] : nil
        let distanceToManeuver = nextStep.flatMap { distance(from: location, to: $0.maneuverCoordinate) } ?? destinationDistance
        let tailDistance = session.steps.dropFirst(min(stepIndex + 1, session.steps.count)).reduce(0) { partial, step in
            partial + max(step.distanceMeters, 0)
        }
        let remainingDistance = nextStep == nil ? destinationDistance : max(distanceToManeuver + tailDistance, destinationDistance)

        let activeRoute = task.routeOptions.first(where: { $0.id == session.routeId }) ?? task.focusedRoute
        let totalDistance = max(activeRoute?.distanceMeters ?? remainingDistance, 1)
        let totalETA = activeRoute?.expectedTravelTime ?? 0

        updated.currentStepIndex = stepIndex
        updated.remainingDistanceMeters = remainingDistance
        updated.remainingDistanceText = formatDistance(remainingDistance)
        updated.remainingETA = formatETA(totalETA > 0 ? totalETA * remainingDistance / totalDistance : 0)
        updated.progressFraction = min(max(1 - remainingDistance / totalDistance, 0), 1)
        updated.hasArrived = false
        updated.statusMessage = statusMessage

        if let nextStep {
            updated.nextInstruction = nextStep.instruction.isEmpty
                ? (task.language.usesChineseCopy ? "沿当前路线继续前进" : "Continue on the current route")
                : nextStep.instruction

            var details: [String] = []
            details.append(
                task.language.usesChineseCopy
                    ? "\(formatDistance(distanceToManeuver)) 后"
                    : "\(formatDistance(distanceToManeuver)) ahead"
            )
            if let notice = nextStep.notice, notice.isEmpty == false {
                details.append(notice)
            }
            updated.nextInstructionDetail = details.joined(separator: " · ")
        } else {
            updated.nextInstruction = task.language.usesChineseCopy
                ? "继续前往目的地"
                : "Continue to the destination"
            updated.nextInstructionDetail = updated.remainingDistanceText
        }

        return updated
    }

    private func nextStepIndex(
        for location: CLLocation,
        steps: [MapRouteStep]
    ) -> Int {
        guard steps.isEmpty == false else {
            return 0
        }

        for (index, step) in steps.enumerated() {
            let maneuverDistance = distance(from: location, to: step.maneuverCoordinate)
            if maneuverDistance > 22 {
                return index
            }
        }

        return max(steps.count - 1, 0)
    }

    private func shouldRerouteNavigation(
        _ session: MapNavigationSession,
        location: CLLocation
    ) -> Bool {
        guard session.hasArrived == false else {
            return false
        }

        guard session.routeCoordinates.count > 1 else {
            return false
        }

        let offRouteDistance = distanceFromRoute(
            location.coordinate,
            route: session.routeCoordinates.map(\.clCoordinate)
        )
        return offRouteDistance > 70
    }

    private func distance(
        from location: CLLocation,
        to coordinate: MapCoordinate?
    ) -> CLLocationDistance {
        guard let coordinate = coordinate?.clCoordinate else {
            return .greatestFiniteMagnitude
        }

        let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return location.distance(from: target)
    }

    private func distanceFromRoute(
        _ coordinate: CLLocationCoordinate2D,
        route: [CLLocationCoordinate2D]
    ) -> CLLocationDistance {
        guard route.count > 1 else {
            return .greatestFiniteMagnitude
        }

        let target = MKMapPoint(coordinate)
        var minimumDistance = CLLocationDistance.greatestFiniteMagnitude

        for index in 0..<(route.count - 1) {
            let start = MKMapPoint(route[index])
            let end = MKMapPoint(route[index + 1])
            minimumDistance = min(
                minimumDistance,
                distanceFromMapPoint(
                    target,
                    toSegmentFrom: start,
                    to: end,
                    latitude: coordinate.latitude
                )
            )
        }

        return minimumDistance
    }

    private func distanceFromMapPoint(
        _ point: MKMapPoint,
        toSegmentFrom start: MKMapPoint,
        to end: MKMapPoint,
        latitude: CLLocationDegrees
    ) -> CLLocationDistance {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy

        let projection: Double
        if lengthSquared == 0 {
            projection = 0
        } else {
            projection = max(
                0,
                min(
                    1,
                    ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared
                )
            )
        }

        let projectedPoint = MKMapPoint(
            x: start.x + projection * dx,
            y: start.y + projection * dy
        )
        let deltaX = point.x - projectedPoint.x
        let deltaY = point.y - projectedPoint.y
        let mapPointDistance = hypot(deltaX, deltaY)
        return mapPointDistance * MKMetersPerMapPointAtLatitude(latitude)
    }

    private func formatDistance(_ distance: CLLocationDistance) -> String {
        let formatter = LengthFormatter()
        formatter.unitStyle = .short
        return formatter.string(fromMeters: max(distance, 0))
    }

    private func formatETA(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: max(interval, 0)) ?? "--"
    }

    private func recommendationReason(
        for candidate: MapPlaceCandidate,
        query: String,
        language: MapsConversationLanguage,
        index: Int
    ) -> String {
        if let distanceText = candidate.distanceText {
            return language.usesChineseCopy
                ? "和“\(query)”匹配，距离锚点约 \(distanceText)。"
                : "Matches “\(query)” and sits about \(distanceText) from the anchor."
        }

        if index == 0 {
            return language.usesChineseCopy
                ? "这是最直接的匹配项，适合先比较。"
                : "This is the most direct match and a good first comparison point."
        }

        return language.usesChineseCopy
            ? "可作为备选地点继续比较。"
            : "Useful as a backup candidate for comparison."
    }
}

struct MapTaskPersistence {
    private let defaults: UserDefaults
    private let activeTaskKey = "com.kair.maps.active-task"
    private let lastManualLocationKey = "com.kair.maps.last-manual-location"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadActiveTask() -> MapTask? {
        guard let data = defaults.data(forKey: activeTaskKey) else {
            return nil
        }

        return try? JSONDecoder().decode(MapTask.self, from: data)
    }

    func saveActiveTask(_ task: MapTask) {
        guard let data = try? JSONEncoder().encode(task) else {
            return
        }
        defaults.set(data, forKey: activeTaskKey)
    }

    func clearActiveTask() {
        defaults.removeObject(forKey: activeTaskKey)
    }

    func loadLastManualLocation() -> MapPlaceCandidate? {
        guard let data = defaults.data(forKey: lastManualLocationKey) else {
            return nil
        }

        return try? JSONDecoder().decode(MapPlaceCandidate.self, from: data)
    }

    func saveLastManualLocation(_ location: MapPlaceCandidate) {
        guard let data = try? JSONEncoder().encode(location) else {
            return
        }
        defaults.set(data, forKey: lastManualLocationKey)
    }
}
