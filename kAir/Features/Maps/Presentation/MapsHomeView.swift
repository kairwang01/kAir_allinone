//
//  MapsHomeView.swift
//  kAir
//
//  Focused task page for chat-routed place, nearby, and route work.
//

import MapKit
import SwiftUI

struct MapsHomeView: View {
    let bootstrap: AppBootstrap

    @State private var displayMode: MapResultDisplayMode = .map
    @State private var manualInput = ""

    var body: some View {
        @Bindable var runtime = bootstrap.mapsRuntime
        let activeTask = runtime.activeTask

        ExecutionSurfaceShell(
            navRail: navRail(for: activeTask),
            title: title(for: activeTask),
            status: status(for: activeTask),
            state: systemState(for: activeTask),
            terminal: terminal(for: activeTask, runtime: runtime),
            onReturnToChat: bootstrap.returnToChat,
            primary: {
                if let activeTask, let primaryCandidate = activeTask.primaryCandidate {
                    AIDecisionCard(
                        task: activeTask,
                        primaryCandidate: primaryCandidate,
                        trustPills: trustPills(for: activeTask),
                        onOpenInMaps: {
                            _ = runtime.openPlaceInSystemMaps(primaryCandidate)
                        },
                        onDismiss: bootstrap.returnToChat
                    )
                }
            },
            supplementary: {
                if let activeTask {
                    if shouldShowLocationGate(for: activeTask) {
                        LocationGateCard(
                            task: activeTask,
                            manualInput: $manualInput,
                            onUseCurrentLocation: {
                                Task {
                                    _ = await runtime.useCurrentLocationForActiveTask()
                                }
                            },
                            onSubmitManualInput: {
                                let submitted = manualInput.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard submitted.isEmpty == false else { return }

                                Task {
                                    let didApply = await runtime.applyManualInput(submitted)
                                    if didApply {
                                        manualInput = ""
                                    }
                                }
                            }
                        )
                    }

                    if activeTask.taskType == .goToPlace || activeTask.taskType == .routeComparison {
                        RouteModeCard(
                            task: activeTask,
                            onSelectMode: { mode in
                                Task {
                                    await runtime.updateTransportMode(mode)
                                }
                            }
                        )
                    }

                    if activeTask.taskType == .nearbySearch || activeTask.taskType == .recommendation {
                        DisplayModeCard(
                            language: activeTask.language,
                            displayMode: $displayMode
                        )
                    }

                    if let navigationSession = runtime.navigationSession {
                        InAppNavigationCard(
                            session: navigationSession,
                            language: activeTask.language,
                            onStop: runtime.stopNavigation
                        )
                    }

                    if shouldShowMap(task: activeTask, displayMode: displayMode) {
                        MapPreviewCard(
                            task: activeTask,
                            navigationSession: runtime.navigationSession,
                            onNavigate: {
                                Task {
                                    _ = await runtime.startNavigationForActiveTask()
                                }
                            },
                            onOpenInMaps: { place in
                                _ = runtime.openPlaceInSystemMaps(place)
                            }
                        )
                    }

                    if let primaryCandidate = activeTask.primaryCandidate {
                        LookAroundCard(
                            place: primaryCandidate,
                            language: activeTask.language
                        )
                    }

                    if shouldShowList(task: activeTask, displayMode: displayMode) {
                        PlaceListCard(
                            task: activeTask,
                            onOpenInMaps: { place in
                                _ = runtime.openPlaceInSystemMaps(place)
                            },
                            onNavigate: { place in
                                Task {
                                    _ = await runtime.startNavigation(to: place, mode: activeTask.transportMode)
                                }
                            }
                        )
                    }

                    if activeTask.routeOptions.isEmpty == false {
                        RouteListCard(
                            task: activeTask,
                            onPreviewRoute: { mode in
                                Task {
                                    await runtime.updateTransportMode(mode)
                                }
                            },
                            onNavigate: { option in
                                Task {
                                    _ = await runtime.startNavigationForActiveTask(mode: option.mode)
                                }
                            }
                        )
                    }
                }
            }
        )
        .task(id: activeTask?.id) {
            guard let activeTask else {
                return
            }

            displayMode = activeTask.requestedDisplayMode
            await runtime.refreshActiveTask()
        }
        .navigationTitle(activeTask?.language.usesChineseCopy == true ? "地图任务" : "Maps")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: bootstrap.showProfile) {
                    Circle()
                        .fill(AppTheme.Palette.surfaceStrong)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Text("K")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.Palette.textOnStrong)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - ExecutionSurfaceShell inputs (Maps → framework mapping)

    private func navRail(for task: MapTask?) -> ExecutionSurfaceNavRail {
        let isZh = task?.language.usesChineseCopy == true
        return ExecutionSurfaceNavRail(
            backToChatTitle: isZh ? "返回聊天" : "Back to chat",
            trustPills: trustPills(for: task),
            isZh: isZh
        )
    }

    private func title(for task: MapTask?) -> ExecutionSurfaceTitle {
        guard let task else {
            return ExecutionSurfaceTitle(
                eyebrow: "Maps",
                title: "Maps",
                summary: "Maps is not a home tab. It opens only as a focused task page after chat decides that spatial context matters."
            )
        }
        return ExecutionSurfaceTitle(
            eyebrow: task.taskType.title(for: task.language),
            title: task.headerTitle,
            summary: task.headerSummary
        )
    }

    private func status(for task: MapTask?) -> ExecutionSurfaceStatus {
        guard let task else { return .none }
        return ExecutionSurfaceStatus(
            statusMessage: task.statusMessage,
            errorMessage: task.errorMessage
        )
    }

    private func systemState(for task: MapTask?) -> ExecutionSurfaceSystemState {
        guard let task else { return .empty }
        if task.errorMessage?.isEmpty == false {
            return .error
        }
        if task.permissionState == .denied || task.permissionState == .manualOnly {
            return .permissionOrUnavailable
        }
        return .ready
    }

    private func terminal(for task: MapTask?, runtime: MapsRuntime) -> ExecutionSurfaceTerminal? {
        guard let task, runtime.navigationSession?.hasArrived == true else { return nil }
        return ExecutionSurfaceTerminal(
            title: task.language.usesChineseCopy ? "已到达" : "Arrived",
            systemImage: "flag.checkered"
        )
    }

    private func trustPills(for task: MapTask?) -> [ActionCardTrustPillKind] {
        guard let task else { return [] }
        let etaConfidence: MapActionCardTrustConfidence
        switch task.taskType {
        case .nearbySearch, .recommendation:
            etaConfidence = .unavailable
        case .goToPlace, .routeComparison:
            etaConfidence = .estimated
        }
        let metadata = MapActionCardTrustMetadata(
            placeResolution: .estimated,
            etaConfidence: etaConfidence,
            distanceConfidence: .estimated,
            partnerState: .pending,
            permissionState: task.permissionState
        )
        return metadata.pills
    }

    private func shouldShowLocationGate(for task: MapTask) -> Bool {
        task.manualInputKind != nil || task.origin == nil && (task.taskType == .nearbySearch || task.taskType == .routeComparison)
    }

    private func shouldShowMap(task: MapTask, displayMode: MapResultDisplayMode) -> Bool {
        switch task.taskType {
        case .goToPlace, .routeComparison:
            return task.visiblePlaces.isEmpty == false
        case .nearbySearch, .recommendation:
            return displayMode == .map && task.visiblePlaces.isEmpty == false
        }
    }

    private func shouldShowList(task: MapTask, displayMode: MapResultDisplayMode) -> Bool {
        switch task.taskType {
        case .goToPlace:
            return task.primaryCandidate != nil
        case .nearbySearch, .recommendation:
            return displayMode == .list && task.visiblePlaces.isEmpty == false
        case .routeComparison:
            return false
        }
    }
}

private struct AIDecisionCard: View {
    let task: MapTask
    let primaryCandidate: MapPlaceCandidate
    let trustPills: [ActionCardTrustPillKind]
    let onOpenInMaps: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ActionCardShell(
            headerLabelTitle: task.language.usesChineseCopy ? "AI 决策结果" : "AI decision",
            headerLabelSystemImage: "sparkles",
            trustPills: trustPills,
            isZh: task.language.usesChineseCopy,
            title: primaryCandidate.title,
            subtitle: cardSubtitle,
            reasonText: primaryCandidate.subtitle.isEmpty ? nil : primaryCandidate.subtitle,
            primaryActionTitle: task.language.usesChineseCopy ? "在 Apple 地图里查看" : "Open in Apple Maps",
            primaryEnabled: true,
            secondaryActionTitle: nil,
            feedbackAffordanceLabel: task.language.usesChineseCopy ? "反馈选项" : "Feedback options",
            onCardTap: nil,
            onPrimaryAction: onOpenInMaps,
            onSecondaryAction: nil,
            onFeedback: { _ in },
            onDismiss: onDismiss
        )
    }

    private var cardSubtitle: String {
        task.language.usesChineseCopy
            ? "聊天已经把“\(task.query)”落成具体目的地，并把实时地图作为下一步。"
            : "Chat resolved “\(task.query)” into a concrete destination and promoted the live map as the next step."
    }
}

private struct LocationGateCard: View {
    let task: MapTask
    @Binding var manualInput: String
    let onUseCurrentLocation: () -> Void
    let onSubmitManualInput: () -> Void

    var body: some View {
        KAirSurface(style: .sunken) {
            VStack(alignment: .leading, spacing: 14) {
                Text(task.language.usesChineseCopy ? "位置与区域" : "Location and area")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Text(
                    task.manualInputKind?.prompt(for: task.language)
                    ?? (task.language.usesChineseCopy
                        ? "先确定用当前位置还是手动地点。"
                        : "Choose whether to use your current location or a manual place.")
                )
                .font(.subheadline)
                .foregroundStyle(AppTheme.Palette.textSecondary)

                HStack(spacing: 10) {
                    Button(action: onUseCurrentLocation) {
                        KAirActionCapsule(
                            title: task.language.usesChineseCopy ? "使用当前位置" : "Use current location",
                            systemImage: "location"
                        )
                    }
                    .buttonStyle(.plain)

                    Text(task.language.usesChineseCopy ? "或" : "or")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textMuted)
                }

                HStack(spacing: 10) {
                    TextField(
                        task.language.usesChineseCopy ? "手动输入地点" : "Enter a place manually",
                        text: $manualInput
                    )
                    .textFieldStyle(.roundedBorder)

                    Button(task.language.usesChineseCopy ? "应用" : "Apply", action: onSubmitManualInput)
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.Palette.accentStrong)
                }

                Text(
                    task.language.usesChineseCopy
                        ? "不申请后台定位；没有位置权限时也不会出现空白地图。"
                        : "No background location is requested, and the page still works without location permission."
                )
                .font(.caption)
                .foregroundStyle(AppTheme.Palette.textMuted)
            }
        }
    }
}

private struct RouteModeCard: View {
    let task: MapTask
    let onSelectMode: (MapTransportMode) -> Void

    var body: some View {
        KAirSurface {
            VStack(alignment: .leading, spacing: 12) {
                Text(task.language.usesChineseCopy ? "路线方式" : "Route modes")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Picker(
                    task.language.usesChineseCopy ? "交通方式" : "Transport mode",
                    selection: Binding(
                        get: { task.transportMode ?? .driving },
                        set: onSelectMode
                    )
                ) {
                    ForEach(MapTransportMode.allCases, id: \.self) { mode in
                        Text(mode.title(for: task.language)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
}

private struct DisplayModeCard: View {
    let language: MapsConversationLanguage
    @Binding var displayMode: MapResultDisplayMode

    var body: some View {
        KAirSurface(style: .sunken, padding: 8) {
            Picker(
                language.usesChineseCopy ? "显示方式" : "Display mode",
                selection: $displayMode
            ) {
                Text(language.usesChineseCopy ? "地图" : "Map").tag(MapResultDisplayMode.map)
                Text(language.usesChineseCopy ? "列表" : "List").tag(MapResultDisplayMode.list)
            }
            .pickerStyle(.segmented)
        }
    }
}

private struct InAppNavigationCard: View {
    let session: MapNavigationSession
    let language: MapsConversationLanguage
    let onStop: () -> Void

    var body: some View {
        KAirSurface(style: .hero) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(language.usesChineseCopy ? "应用内导航" : "In-app navigation")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text(session.nextInstruction)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        if let detail = session.nextInstructionDetail, detail.isEmpty == false {
                            Text(detail)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.Palette.textSecondary)
                        }
                    }

                    Spacer(minLength: 12)

                    KAirStatusPill(
                        title: session.mode.title(for: language),
                        systemImage: session.mode.systemImage,
                        tint: session.hasArrived ? AppTheme.Palette.success : AppTheme.Palette.accentStrong
                    )
                }

                ProgressView(value: session.progressFraction)
                    .tint(AppTheme.Palette.accentStrong)

                HStack(spacing: 10) {
                    metric(language.usesChineseCopy ? "剩余距离" : "Remaining", session.remainingDistanceText)
                    metric(language.usesChineseCopy ? "剩余时间" : "ETA", session.remainingETA)
                    metric(language.usesChineseCopy ? "目的地" : "Destination", session.destination.title)
                }

                if let currentStep = session.currentStep,
                   let laneGuidance = MapNavigationHeuristics.laneGuidance(for: currentStep, language: language) {
                    LaneGuidanceStrip(
                        guidance: laneGuidance,
                        language: language
                    )
                }

                HStack(spacing: 10) {
                    Button(action: onStop) {
                        KAirActionCapsule(
                            title: language.usesChineseCopy ? "结束导航" : "Stop navigation",
                            systemImage: "xmark"
                        )
                    }
                    .buttonStyle(.plain)

                    if let statusMessage = session.statusMessage, statusMessage.isEmpty == false {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(AppTheme.Palette.textMuted)
                    }
                }
            }
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.Palette.textMuted)

            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(
                cornerRadius: AppTheme.Metrics.compactRadius,
                style: .continuous
            )
            .fill(Color.white.opacity(0.66))
        )
    }
}

private struct LaneGuidanceStrip: View {
    let guidance: MapLaneGuidanceModel
    let language: MapsConversationLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(language.usesChineseCopy ? "车道级指引" : "Lane guidance")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textMuted)

            HStack(spacing: 8) {
                ForEach(guidance.lanes) { lane in
                    LaneGuidanceBox(lane: lane)
                }
            }

            Text(guidance.instructionVariants.first ?? "")
                .font(.caption)
                .foregroundStyle(AppTheme.Palette.textSecondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(
                cornerRadius: AppTheme.Metrics.compactRadius,
                style: .continuous
            )
            .fill(Color.white.opacity(0.66))
        )
    }
}

private struct LaneGuidanceBox: View {
    let lane: MapLaneDescriptor

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(lane.directions.enumerated()), id: \.offset) { _, direction in
                Image(systemName: symbol(for: direction))
                    .font(.callout.weight(.bold))
                    .foregroundStyle(color(for: lane.status, highlighted: direction == lane.highlightedDirection))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 64)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
            .fill(background(for: lane.status))
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
            .strokeBorder(border(for: lane.status), lineWidth: 1)
        )
    }

    private func symbol(for direction: MapLaneDirection) -> String {
        switch direction {
        case .left:
            return "arrow.turn.up.left"
        case .slightLeft:
            return "arrow.up.left"
        case .straight:
            return "arrow.up"
        case .slightRight:
            return "arrow.up.right"
        case .right:
            return "arrow.turn.up.right"
        case .uTurn:
            return "arrow.uturn.left"
        }
    }

    private func color(for status: MapLaneStatus, highlighted: Bool) -> Color {
        if highlighted {
            return status == .preferred ? AppTheme.Palette.success : AppTheme.Palette.accentStrong
        }

        switch status {
        case .notGood:
            return AppTheme.Palette.textMuted
        case .good:
            return AppTheme.Palette.textPrimary
        case .preferred:
            return AppTheme.Palette.success
        }
    }

    private func background(for status: MapLaneStatus) -> Color {
        switch status {
        case .notGood:
            return Color.white.opacity(0.55)
        case .good:
            return AppTheme.Palette.sky.opacity(0.12)
        case .preferred:
            return AppTheme.Palette.success.opacity(0.14)
        }
    }

    private func border(for status: MapLaneStatus) -> Color {
        switch status {
        case .notGood:
            return Color.black.opacity(0.08)
        case .good:
            return AppTheme.Palette.sky.opacity(0.24)
        case .preferred:
            return AppTheme.Palette.success.opacity(0.4)
        }
    }
}

private struct MapPreviewCard: View {
    let task: MapTask
    let navigationSession: MapNavigationSession?
    let onNavigate: () -> Void
    let onOpenInMaps: (MapPlaceCandidate) -> Void

    @State private var position: MapCameraPosition = .automatic

    private var places: [MapPlaceCandidate] {
        task.visiblePlaces.filter { $0.coordinate != nil }
    }

    private var focusedRoute: MapRouteOption? {
        task.focusedRoute
    }

    private var focusPlace: MapPlaceCandidate? {
        task.selectedDestination ?? task.primaryCandidate
    }

    var body: some View {
        KAirSurface(style: .sunken) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(task.language.usesChineseCopy ? "实时地图" : "Live map")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text(
                            task.language.usesChineseCopy
                                ? "地图会围绕 AI 当前选定的地点和路线自动聚焦。"
                                : "The map automatically frames the location and route the AI is working with."
                        )
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                    }

                    Spacer(minLength: 12)

                    if let focusedRoute, focusedRoute.available {
                        KAirStatusPill(
                            title: focusedRoute.mode.title(for: task.language),
                            systemImage: focusedRoute.mode.systemImage,
                            tint: AppTheme.Palette.accentStrong
                        )
                    }
                }

                if places.isEmpty {
                    PlaceholderMapCanvas(task: task)
                } else {
                    ZStack(alignment: .topTrailing) {
                        Map(position: $position, interactionModes: .all) {
                            if task.permissionState.canUseCurrentLocation {
                                UserAnnotation()
                            }

                            if let focusedRoute, focusedRoute.polylineCoordinates.count > 1 {
                                MapPolyline(
                                    coordinates: focusedRoute.polylineCoordinates.map(\.clCoordinate)
                                )
                                .stroke(
                                    AppTheme.Palette.accentStrong,
                                    style: StrokeStyle(
                                        lineWidth: 6,
                                        lineCap: .round,
                                        lineJoin: .round
                                    )
                                )
                            }

                            if let origin = task.origin,
                               let coordinate = origin.coordinate?.clCoordinate {
                                Annotation(
                                    task.language.usesChineseCopy ? "起点" : "Origin",
                                    coordinate: coordinate
                                ) {
                                    MapPointBadge(
                                        tint: AppTheme.Palette.sky,
                                        systemImage: origin.isCurrentLocation ? "location.fill" : "circle.fill"
                                    )
                                }
                            }

                            ForEach(places) { place in
                                if let coordinate = place.coordinate?.clCoordinate {
                                    Annotation(place.title, coordinate: coordinate) {
                                        MapPointBadge(
                                            tint: place.id == focusPlace?.id
                                                ? AppTheme.Palette.warning
                                                : AppTheme.Palette.accentStrong,
                                            systemImage: place.isCurrentLocation
                                                ? "location.fill"
                                                : "mappin.and.ellipse"
                                        )
                                    }
                                }
                            }
                        }
                        .mapStyle(.standard(elevation: .realistic))
                        .frame(height: 320)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: AppTheme.Metrics.cardRadius,
                                style: .continuous
                            )
                        )
                        .overlay(
                            RoundedRectangle(
                                cornerRadius: AppTheme.Metrics.cardRadius,
                                style: .continuous
                            )
                            .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
                        )
                        .task(id: task.id) {
                            updatePosition()
                        }
                        .onChange(of: task.generatedAt) { _, _ in
                            updatePosition()
                        }
                        .onChange(of: navigationSession?.currentLocation) { _, _ in
                            updatePosition()
                        }

                        VStack(spacing: 10) {
                            Button(action: updatePosition) {
                                MapOverlayButton(
                                    systemImage: "scope",
                                    label: task.language.usesChineseCopy ? "重置视角" : "Reset"
                                )
                            }

                            if focusPlace != nil {
                                Button(action: onNavigate) {
                                    MapOverlayButton(
                                        systemImage: "arrow.triangle.turn.up.right.diamond.fill",
                                        label: task.language.usesChineseCopy ? "应用内导航" : "Navigate here",
                                        emphasized: true
                                    )
                                }
                            }
                        }
                        .padding(14)
                    }
                }

                if let focusPlace {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(focusPlace.title)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(AppTheme.Palette.textPrimary)

                            if focusPlace.subtitle.isEmpty == false {
                                Text(focusPlace.subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.Palette.textSecondary)
                            }
                        }

                        Spacer(minLength: 12)

                        Button {
                            onOpenInMaps(focusPlace)
                        } label: {
                            KAirActionCapsule(
                                title: task.language.usesChineseCopy ? "打开地图" : "Open map",
                                systemImage: "map",
                                emphasized: false
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let focusedRoute, focusedRoute.available {
                    HStack(spacing: 10) {
                        routeMetric(
                            task.language.usesChineseCopy ? "预计" : "ETA",
                            focusedRoute.etaText
                        )
                        routeMetric(
                            task.language.usesChineseCopy ? "距离" : "Distance",
                            focusedRoute.distanceText
                        )
                        routeMetric(
                            task.language.usesChineseCopy ? "模式" : "Mode",
                            focusedRoute.mode.title(for: task.language)
                        )
                    }
                }
            }
        }
    }

    private func routeMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.Palette.textMuted)

            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(
                cornerRadius: AppTheme.Metrics.compactRadius,
                style: .continuous
            )
            .fill(Color.white.opacity(0.72))
        )
    }

    private func updatePosition() {
        if let navigationLocation = navigationSession?.currentLocation?.clCoordinate {
            position = .camera(
                MapCamera(
                    centerCoordinate: navigationLocation,
                    distance: 1_600,
                    heading: 0,
                    pitch: 52
                )
            )
            return
        }

        if let rect = routeBoundingRect {
            position = .rect(rect)
            return
        }

        if let region = coordinateRegion {
            position = .region(region)
        } else {
            position = .automatic
        }
    }

    private var routeBoundingRect: MKMapRect? {
        guard let focusedRoute, focusedRoute.polylineCoordinates.count > 1 else {
            return nil
        }

        return mapRect(for: focusedRoute.polylineCoordinates.map(\.clCoordinate))
    }

    private var coordinateRegion: MKCoordinateRegion? {
        let coordinates = places.compactMap(\.coordinate?.clCoordinate)
        guard let rect = mapRect(for: coordinates) else {
            return nil
        }

        return MKCoordinateRegion(rect)
    }

    private func mapRect(for coordinates: [CLLocationCoordinate2D]) -> MKMapRect? {
        guard coordinates.isEmpty == false else {
            return nil
        }

        let points = coordinates.map(MKMapPoint.init)
        var rect = MKMapRect(origin: points[0], size: .init(width: 0, height: 0))

        for point in points.dropFirst() {
            rect = rect.union(
                MKMapRect(origin: point, size: .init(width: 0, height: 0))
            )
        }

        return rect.insetBy(
            dx: -(rect.size.width * 0.35 + 800),
            dy: -(rect.size.height * 0.35 + 800)
        )
    }
}

private struct MapPointBadge: View {
    let tint: Color
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.caption.weight(.bold))
            .foregroundStyle(Color.white)
            .frame(width: 28, height: 28)
            .background(
                Circle()
                    .fill(tint)
            )
            .overlay(
                Circle()
                    .strokeBorder(Color.white.opacity(0.9), lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 4)
    }
}

private struct MapOverlayButton: View {
    let systemImage: String
    let label: String
    var emphasized = false

    var body: some View {
        Label(label, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(emphasized ? Color.white : AppTheme.Palette.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(emphasized ? AppTheme.Palette.accentStrong : Color.white.opacity(0.92))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.black.opacity(emphasized ? 0 : 0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 6)
    }
}

private struct PlaceholderMapCanvas: View {
    let task: MapTask

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.82),
                            AppTheme.Palette.backgroundInset
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 220)

            VStack(spacing: 10) {
                Image(systemName: "map")
                    .font(.title)
                    .foregroundStyle(AppTheme.Palette.textSecondary)

                Text(
                    task.language.usesChineseCopy
                        ? "位置尚未完整，先用任务卡继续补参数。"
                        : "The location details are still incomplete. Keep filling the task from the cards above."
                )
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.Palette.textSecondary)
                .padding(.horizontal, 28)
            }
        }
    }
}

private struct PlaceListCard: View {
    let task: MapTask
    let onOpenInMaps: (MapPlaceCandidate) -> Void
    let onNavigate: (MapPlaceCandidate) -> Void

    private var places: [MapPlaceCandidate] {
        task.visiblePlaces
    }

    var body: some View {
        KAirSurface {
            VStack(alignment: .leading, spacing: 14) {
                Text(task.language.usesChineseCopy ? "地点列表" : "Places")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                ForEach(places) { place in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(place.title)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(AppTheme.Palette.textPrimary)

                                Text(place.subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.Palette.textSecondary)
                            }

                            Spacer(minLength: 12)

                            if let distanceText = place.distanceText {
                                KAirStatusPill(
                                    title: distanceText,
                                    systemImage: "ruler",
                                    tint: AppTheme.Palette.sky
                                )
                            }
                        }

                        if let reason = place.reason, reason.isEmpty == false {
                            Text(reason)
                                .font(.caption)
                                .foregroundStyle(AppTheme.Palette.textMuted)
                        }

                        HStack(spacing: 10) {
                            Button {
                                onOpenInMaps(place)
                            } label: {
                                KAirActionCapsule(
                                    title: task.language.usesChineseCopy ? "打开地图" : "Open map",
                                    systemImage: "map",
                                    emphasized: false
                                )
                            }
                            .buttonStyle(.plain)

                            if place.isCurrentLocation == false {
                                Button {
                                    onNavigate(place)
                                } label: {
                                    KAirActionCapsule(
                                        title: task.language.usesChineseCopy ? "在应用内导航" : "Navigate in app",
                                        systemImage: "arrow.triangle.turn.up.right.diamond.fill"
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(
                            cornerRadius: AppTheme.Metrics.compactRadius,
                            style: .continuous
                        )
                        .fill(Color.white.opacity(0.66))
                    )
                }
            }
        }
    }
}

private struct RouteListCard: View {
    let task: MapTask
    let onPreviewRoute: (MapTransportMode) -> Void
    let onNavigate: (MapRouteOption) -> Void

    var body: some View {
        KAirSurface {
            VStack(alignment: .leading, spacing: 14) {
                Text(task.language.usesChineseCopy ? "路线结果" : "Route results")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                ForEach(task.routeOptions) { option in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(option.title)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(AppTheme.Palette.textPrimary)

                                Text(option.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.Palette.textSecondary)
                            }

                            Spacer(minLength: 12)

                            KAirStatusPill(
                                title: task.transportMode == option.mode
                                    ? (task.language.usesChineseCopy ? "当前" : "Current")
                                    : option.recommended
                                    ? (task.language.usesChineseCopy ? "推荐" : "Best")
                                    : option.mode.title(for: task.language),
                                systemImage: option.mode.systemImage,
                                tint: task.transportMode == option.mode
                                    ? AppTheme.Palette.accentStrong
                                    : option.recommended
                                    ? AppTheme.Palette.success
                                    : AppTheme.Palette.warning
                            )
                        }

                        HStack(spacing: 10) {
                            metric(
                                task.language.usesChineseCopy ? "预计" : "ETA",
                                option.etaText
                            )
                            metric(
                                task.language.usesChineseCopy ? "距离" : "Distance",
                                option.distanceText
                            )
                            metric(
                                task.language.usesChineseCopy ? "说明" : "Why",
                                option.emphasis
                            )
                        }

                        if option.available {
                            HStack(spacing: 10) {
                                Button {
                                    onPreviewRoute(option.mode)
                                } label: {
                                    KAirActionCapsule(
                                        title: task.language.usesChineseCopy ? "预览这条路线" : "Preview route",
                                        systemImage: "waveform.path.ecg",
                                        emphasized: false
                                    )
                                }
                                .buttonStyle(.plain)

                                Button {
                                    onNavigate(option)
                                } label: {
                                    KAirActionCapsule(
                                        title: task.language.usesChineseCopy ? "开始应用内导航" : "Start in-app navigation",
                                        systemImage: "arrow.triangle.turn.up.right.diamond.fill"
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(
                            cornerRadius: AppTheme.Metrics.compactRadius,
                            style: .continuous
                        )
                        .fill(Color.white.opacity(0.66))
                    )
                }
            }
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.Palette.textMuted)

            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct LookAroundCard: View {
    let place: MapPlaceCandidate
    let language: MapsConversationLanguage

    @State private var scene: MKLookAroundScene?
    @State private var isLoading = false

    var body: some View {
        KAirSurface(style: .sunken) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(language.usesChineseCopy ? "街景预览" : "Look Around")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text(
                            language.usesChineseCopy
                                ? "如果该地点支持 Apple Look Around，这里会给出街景预览。"
                                : "If Apple Look Around is available for this destination, a street-level preview appears here."
                        )
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                    }

                    Spacer(minLength: 12)

                    if isLoading {
                        ProgressView()
                            .tint(AppTheme.Palette.accentStrong)
                    }
                }

                if let scene {
                    LookAroundPreview(initialScene: scene, allowsNavigation: true, showsRoadLabels: true)
                        .frame(height: 180)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: AppTheme.Metrics.cardRadius,
                                style: .continuous
                            )
                        )
                } else {
                    RoundedRectangle(cornerRadius: AppTheme.Metrics.cardRadius, style: .continuous)
                        .fill(Color.white.opacity(0.7))
                        .frame(height: 140)
                        .overlay {
                            Text(
                                language.usesChineseCopy
                                    ? "这个地点暂时没有可用街景。"
                                    : "Look Around is not available for this place right now."
                            )
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                            .padding(.horizontal, 20)
                            .multilineTextAlignment(.center)
                        }
                }
            }
        }
        .task(id: place.id) {
            await loadLookAround()
        }
    }

    private func loadLookAround() async {
        guard let coordinate = place.coordinate?.clCoordinate else {
            scene = nil
            return
        }

        isLoading = true
        defer { isLoading = false }

        let request = MKLookAroundSceneRequest(coordinate: coordinate)
        scene = try? await request.scene
    }
}

private struct WarningCard: View {
    let language: MapsConversationLanguage
    let message: String

    var body: some View {
        KAirSurface(style: .sunken) {
            VStack(alignment: .leading, spacing: 10) {
                Text(language.usesChineseCopy ? "下一步" : "Next step")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)

                Text(
                    language.usesChineseCopy
                        ? "你可以换区域、换关键词、切换路线方式，或退回只看地点详情。"
                        : "Try a different area, another keyword, another route mode, or fall back to place details."
                )
                .font(.caption)
                .foregroundStyle(AppTheme.Palette.textMuted)
            }
        }
    }
}

