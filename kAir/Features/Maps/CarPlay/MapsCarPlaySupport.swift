//
//  MapsCarPlaySupport.swift
//  kAir
//
//  CarPlay navigation scene and route guidance integration.
//

import CarPlay
import MapKit
import SwiftUI
import UIKit

final class KAirAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: nil,
            sessionRole: connectingSceneSession.role
        )

        if connectingSceneSession.role == .carTemplateApplication {
            configuration.sceneClass = CPTemplateApplicationScene.self
            configuration.delegateClass = MapsCarPlaySceneDelegate.self
        }

        return configuration
    }
}

@MainActor
final class MapsCarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate, CPMapTemplateDelegate {
    private let runtime = MapsRuntime.shared
    private var observerToken: UUID?
    private weak var interfaceController: CPInterfaceController?
    private weak var carWindow: CPWindow?
    private let mapTemplate = CPMapTemplate()
    private let mapViewController = MapsCarPlayMapViewController()
    private var currentTrip: CPTrip?
    private var previewSignature: String?
    private var activeCarPlayRouteId: String?
    private var carPlayNavigationSession: CPNavigationSession?
    private var maneuverRegistry: [String: CPManeuver] = [:]
    private var laneGuidanceRegistry: [String: CPLaneGuidance] = [:]

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController,
        to window: CPWindow
    ) {
        self.interfaceController = interfaceController
        self.carWindow = window

        window.rootViewController = mapViewController
        mapTemplate.mapDelegate = self
        mapTemplate.leadingNavigationBarButtons = [
            CPBarButton(title: "Route") { [weak self] _ in
                self?.showCurrentTripPreview()
            }
        ]
        mapTemplate.trailingNavigationBarButtons = [
            CPBarButton(title: "Stop") { [weak self] _ in
                self?.runtime.stopNavigation()
            }
        ]

        interfaceController.setRootTemplate(mapTemplate, animated: false) { _, _ in }
        observerToken = runtime.addObserver { [weak self] runtime in
            self?.syncFromRuntime(runtime)
        }
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController,
        from window: CPWindow
    ) {
        if let observerToken {
            runtime.removeObserver(observerToken)
        }
        observerToken = nil
        currentTrip = nil
        previewSignature = nil
        activeCarPlayRouteId = nil
        carPlayNavigationSession = nil
        maneuverRegistry.removeAll()
        laneGuidanceRegistry.removeAll()
        self.interfaceController = nil
        self.carWindow = nil
    }

    func mapTemplate(
        _ mapTemplate: CPMapTemplate,
        selectedPreviewFor trip: CPTrip,
        using routeChoice: CPRouteChoice
    ) {
        guard
            let routeId = routeChoice.userInfo as? String,
            let task = runtime.activeTask,
            let selectedRoute = task.routeOptions.first(where: { $0.id == routeId })
        else {
            return
        }

        Task {
            await runtime.updateTransportMode(selectedRoute.mode)
        }
    }

    func mapTemplate(
        _ mapTemplate: CPMapTemplate,
        startedTrip trip: CPTrip,
        using routeChoice: CPRouteChoice
    ) {
        guard
            let routeId = routeChoice.userInfo as? String,
            let task = runtime.activeTask,
            let selectedRoute = task.routeOptions.first(where: { $0.id == routeId })
        else {
            return
        }

        Task {
            _ = await runtime.startNavigationForActiveTask(mode: selectedRoute.mode)
        }
    }

    func mapTemplateDidCancelNavigation(_ mapTemplate: CPMapTemplate) {
        runtime.stopNavigation()
    }

    func mapTemplate(
        _ mapTemplate: CPMapTemplate,
        displayStyleFor maneuver: CPManeuver
    ) -> CPManeuverDisplayStyle {
        .symbolOnly
    }

    private func syncFromRuntime(_ runtime: MapsRuntime) {
        mapViewController.render(
            task: runtime.activeTask,
            navigationSession: runtime.navigationSession
        )

        guard
            let task = runtime.activeTask,
            task.hasUsableRoutes,
            let route = task.focusedRoute,
            let trip = makeTrip(for: task)
        else {
            mapTemplate.hideTripPreviews()
            if carPlayNavigationSession != nil {
                carPlayNavigationSession?.cancelTrip()
                carPlayNavigationSession = nil
            }
            currentTrip = nil
            previewSignature = nil
            activeCarPlayRouteId = nil
            maneuverRegistry.removeAll()
            laneGuidanceRegistry.removeAll()
            return
        }

        currentTrip = trip

        if let navigationSession = runtime.navigationSession {
            ensureActiveGuidance(
                task: task,
                route: route,
                trip: trip,
                navigationSession: navigationSession
            )
        } else {
            if carPlayNavigationSession != nil {
                carPlayNavigationSession?.cancelTrip()
                carPlayNavigationSession = nil
                activeCarPlayRouteId = nil
            }

            maneuverRegistry.removeAll()
            laneGuidanceRegistry.removeAll()
            showCurrentTripPreviewIfNeeded(task: task, trip: trip, route: route)
        }
    }

    private func showCurrentTripPreview() {
        guard
            let task = runtime.activeTask,
            let route = task.focusedRoute,
            let trip = currentTrip ?? makeTrip(for: task)
        else {
            return
        }

        currentTrip = trip
        showCurrentTripPreviewIfNeeded(task: task, trip: trip, route: route, force: true)
    }

    private func showCurrentTripPreviewIfNeeded(
        task: MapTask,
        trip: CPTrip,
        route: MapRouteOption,
        force: Bool = false
    ) {
        let signature = "\(task.id)-\(route.id)"
        guard force || previewSignature != signature else {
            if let estimates = route.travelEstimates {
                mapTemplate.updateEstimates(estimates, for: trip)
            }
            return
        }

        previewSignature = signature
        mapTemplate.showTripPreviews(
            [trip],
            textConfiguration: CPTripPreviewTextConfiguration(
                startButtonTitle: task.language.usesChineseCopy ? "开始导航" : "Start",
                additionalRoutesButtonTitle: task.language.usesChineseCopy ? "其他路线" : "Other routes",
                overviewButtonTitle: task.language.usesChineseCopy ? "总览" : "Overview"
            )
        )
        if let estimates = route.travelEstimates {
            mapTemplate.updateEstimates(estimates, for: trip)
        }
    }

    private func ensureActiveGuidance(
        task: MapTask,
        route: MapRouteOption,
        trip: CPTrip,
        navigationSession: MapNavigationSession
    ) {
        mapTemplate.hideTripPreviews()

        if carPlayNavigationSession == nil || activeCarPlayRouteId != navigationSession.routeId {
            carPlayNavigationSession?.cancelTrip()
            let startedSession = mapTemplate.startNavigationSession(for: trip)
            carPlayNavigationSession = startedSession
            activeCarPlayRouteId = navigationSession.routeId
            previewSignature = nil
            prepareGuidanceRegistry(for: route, language: task.language)
            startedSession.add(Array(maneuverRegistry.values))
            if laneGuidanceRegistry.isEmpty == false {
                startedSession.add(Array(laneGuidanceRegistry.values))
            }
        }

        guard let carPlayNavigationSession else {
            return
        }

        let currentStepId = navigationSession.currentStep?.id
        let nextStepIds = navigationSession.steps
            .dropFirst(navigationSession.currentStepIndex)
            .prefix(3)
            .map(\.id)
        let upcoming = nextStepIds.compactMap { maneuverRegistry[$0] }
        carPlayNavigationSession.upcomingManeuvers = upcoming
        carPlayNavigationSession.currentLaneGuidance = currentStepId.flatMap { laneGuidanceRegistry[$0] }
        carPlayNavigationSession.currentRoadNameVariants = [task.selectedDestination?.title ?? task.primaryCandidate?.title ?? "Route"]
        carPlayNavigationSession.maneuverState = maneuverState(for: navigationSession)

        if let currentManeuver = currentStepId.flatMap({ maneuverRegistry[$0] }),
           let currentStep = navigationSession.currentStep {
            carPlayNavigationSession.updateEstimates(
                CPTravelEstimates(
                    distanceRemaining: Measurement(
                        value: max(distanceToCurrentStep(from: navigationSession, step: currentStep), 0),
                        unit: UnitLength.meters
                    ),
                    timeRemaining: max(currentStep.expectedTravelTime, 0)
                ),
                for: currentManeuver
            )
        }

        if let routeEstimates = navigationSession.travelEstimates {
            mapTemplate.updateEstimates(routeEstimates, for: trip)
        }

        if navigationSession.hasArrived {
            carPlayNavigationSession.finishTrip()
            self.carPlayNavigationSession = nil
            activeCarPlayRouteId = nil
        }
    }

    private func prepareGuidanceRegistry(
        for route: MapRouteOption,
        language: MapsConversationLanguage
    ) {
        maneuverRegistry.removeAll()
        laneGuidanceRegistry.removeAll()

        for step in route.steps {
            let semantic = MapNavigationHeuristics.maneuver(for: step, language: language)
            let laneGuidance = MapNavigationHeuristics.laneGuidance(for: step, language: language)
            let maneuver = CPManeuver()
            maneuver.instructionVariants = laneGuidance?.instructionVariants ?? [step.instruction]
            maneuver.notificationInstructionVariants = maneuver.instructionVariants
            maneuver.maneuverType = semantic.carPlayManeuverType
            maneuver.trafficSide = .right
            maneuver.symbolImage = UIImage(systemName: semantic.symbolName)
            maneuver.userInfo = step.id

            if let laneGuidance {
                let carPlayGuidance = laneGuidance.carPlayGuidance
                maneuver.linkedLaneGuidance = carPlayGuidance
                laneGuidanceRegistry[step.id] = carPlayGuidance
            }

            maneuverRegistry[step.id] = maneuver
        }
    }

    private func makeTrip(for task: MapTask) -> CPTrip? {
        guard
            let origin = task.origin,
            let destination = task.selectedDestination ?? task.primaryCandidate,
            let originItem = origin.mapItem,
            let destinationItem = destination.mapItem
        else {
            return nil
        }

        let choices = task.routeOptions
            .filter(\.available)
            .prefix(3)
            .map { route -> CPRouteChoice in
                let choice = CPRouteChoice(
                    summaryVariants: [route.title, route.mode.title(for: task.language)],
                    additionalInformationVariants: ["\(route.etaText) · \(route.distanceText)", route.summary],
                    selectionSummaryVariants: [route.mode.title(for: task.language)]
                )
                choice.userInfo = route.id
                return choice
            }

        guard choices.isEmpty == false else {
            return nil
        }

        let trip = CPTrip(origin: originItem, destination: destinationItem, routeChoices: choices)
        trip.destinationNameVariants = [destination.title]
        return trip
    }

    private func maneuverState(for navigationSession: MapNavigationSession) -> CPManeuverState {
        guard let currentStep = navigationSession.currentStep else {
            return .continue
        }

        let remaining = distanceToCurrentStep(from: navigationSession, step: currentStep)
        switch remaining {
        case ..<30:
            return .execute
        case ..<120:
            return .prepare
        case ..<500:
            return .initial
        default:
            return .continue
        }
    }

    private func distanceToCurrentStep(
        from navigationSession: MapNavigationSession,
        step: MapRouteStep
    ) -> CLLocationDistance {
        guard
            let currentLocation = navigationSession.currentLocation?.clCoordinate,
            let target = step.maneuverCoordinate?.clCoordinate
        else {
            return navigationSession.remainingDistanceMeters
        }

        let current = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
        let destination = CLLocation(latitude: target.latitude, longitude: target.longitude)
        return current.distance(from: destination)
    }
}

@MainActor
private final class MapsCarPlayMapViewController: UIViewController, MKMapViewDelegate {
    private let mapView = MKMapView(frame: .zero)
    private let emptyStateLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.delegate = self
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.pointOfInterestFilter = .excludingAll
        view.addSubview(mapView)

        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyStateLabel.text = "Continue on iPhone to prepare a route."
        emptyStateLabel.textColor = .secondaryLabel
        emptyStateLabel.font = .preferredFont(forTextStyle: .headline)
        emptyStateLabel.numberOfLines = 0
        emptyStateLabel.textAlignment = .center
        view.addSubview(emptyStateLabel)

        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateLabel.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.66)
        ])
    }

    func render(task: MapTask?, navigationSession: MapNavigationSession?) {
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)

        guard let task else {
            emptyStateLabel.isHidden = false
            return
        }

        emptyStateLabel.isHidden = task.visiblePlaces.isEmpty

        if let route = task.focusedRoute, route.polylineCoordinates.count > 1 {
            let polyline = MKPolyline(
                coordinates: route.polylineCoordinates.map(\.clCoordinate),
                count: route.polylineCoordinates.count
            )
            mapView.addOverlay(polyline)
        }

        let visiblePlaces = task.visiblePlaces
        for place in visiblePlaces {
            guard let coordinate = place.coordinate?.clCoordinate else { continue }
            let annotation = MKPointAnnotation()
            annotation.title = place.title
            annotation.subtitle = place.subtitle
            annotation.coordinate = coordinate
            mapView.addAnnotation(annotation)
        }

        if let currentLocation = navigationSession?.currentLocation?.clCoordinate {
            let annotation = MKPointAnnotation()
            annotation.title = "Current location"
            annotation.coordinate = currentLocation
            mapView.addAnnotation(annotation)
            let camera = MKMapCamera(
                lookingAtCenter: currentLocation,
                fromDistance: 1800,
                pitch: 50,
                heading: 0
            )
            mapView.setCamera(camera, animated: true)
            return
        }

        let coordinates = visiblePlaces.compactMap(\.coordinate?.clCoordinate)
        guard coordinates.isEmpty == false else {
            return
        }

        let points = coordinates.map(MKMapPoint.init)
        var rect = MKMapRect(origin: points[0], size: .init(width: 0, height: 0))
        for point in points.dropFirst() {
            rect = rect.union(MKMapRect(origin: point, size: .init(width: 0, height: 0)))
        }
        mapView.setVisibleMapRect(
            rect.insetBy(dx: -(rect.size.width * 0.4 + 600), dy: -(rect.size.height * 0.4 + 600)),
            animated: true
        )
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let polyline = overlay as? MKPolyline else {
            return MKOverlayRenderer(overlay: overlay)
        }

        let renderer = MKPolylineRenderer(polyline: polyline)
        renderer.lineWidth = 8
        renderer.strokeColor = UIColor.systemBlue
        return renderer
    }
}

private extension MapRouteOption {
    var travelEstimates: CPTravelEstimates? {
        CPTravelEstimates(
            distanceRemaining: Measurement(value: distanceMeters, unit: UnitLength.meters),
            timeRemaining: expectedTravelTime
        )
    }
}

private extension MapNavigationSession {
    var travelEstimates: CPTravelEstimates? {
        CPTravelEstimates(
            distanceRemaining: Measurement(value: remainingDistanceMeters, unit: UnitLength.meters),
            timeRemaining: max(remainingETAInterval, 0)
        )
    }

    private var remainingETAInterval: TimeInterval {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        guard formatter.string(from: remainingDistanceMeters / 18) != nil else {
            return 0
        }
        return remainingDistanceMeters / 18
    }
}

private extension MapPlaceCandidate {
    var mapItem: MKMapItem? {
        guard let coordinate = coordinate?.clCoordinate else {
            return nil
        }

        let item = MKMapItem(
            location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
            address: nil
        )
        item.name = title
        return item
    }
}

private extension MapManeuverSemantic {
    var carPlayManeuverType: CPManeuverType {
        switch self {
        case .start:
            return .startRoute
        case .straight:
            return .straightAhead
        case .keepLeft:
            return .keepLeft
        case .keepRight:
            return .keepRight
        case .turnLeft:
            return .leftTurn
        case .turnRight:
            return .rightTurn
        case .slightLeft:
            return .slightLeftTurn
        case .slightRight:
            return .slightRightTurn
        case .uTurn:
            return .uTurn
        case .offRampLeft:
            return .highwayOffRampLeft
        case .offRampRight:
            return .highwayOffRampRight
        case .arrive:
            return .arriveAtDestination
        case .roundabout:
            return .enterRoundabout
        }
    }

    var symbolName: String {
        switch self {
        case .start:
            return "arrow.up.circle.fill"
        case .straight:
            return "arrow.up"
        case .keepLeft:
            return "arrow.up.left"
        case .keepRight:
            return "arrow.up.right"
        case .turnLeft:
            return "arrow.turn.up.left"
        case .turnRight:
            return "arrow.turn.up.right"
        case .slightLeft:
            return "arrow.up.left"
        case .slightRight:
            return "arrow.up.right"
        case .uTurn:
            return "arrow.uturn.left"
        case .offRampLeft:
            return "arrow.up.left.circle"
        case .offRampRight:
            return "arrow.up.right.circle"
        case .arrive:
            return "flag.checkered"
        case .roundabout:
            return "arrow.trianglehead.2.clockwise.rotate.90"
        }
    }
}

private extension MapLaneGuidanceModel {
    var carPlayGuidance: CPLaneGuidance {
        let guidance = CPLaneGuidance()
        guidance.instructionVariants = instructionVariants
        guidance.lanes = lanes.map(\.carPlayLane)
        return guidance
    }
}

private extension MapLaneDescriptor {
    var carPlayLane: CPLane {
        let allAngles = directions.map(\.angleMeasurement)
        if let highlightedDirection {
            let remainingAngles = directions
                .filter { $0 != highlightedDirection }
                .map(\.angleMeasurement)
            return CPLane(
                angles: remainingAngles,
                highlightedAngle: highlightedDirection.angleMeasurement,
                isPreferred: status == .preferred
            )
        }

        return CPLane(angles: allAngles)
    }
}

private extension MapLaneDirection {
    var angleMeasurement: Measurement<UnitAngle> {
        switch self {
        case .left:
            return Measurement(value: -90, unit: UnitAngle.degrees)
        case .slightLeft:
            return Measurement(value: -35, unit: UnitAngle.degrees)
        case .straight:
            return Measurement(value: 0, unit: UnitAngle.degrees)
        case .slightRight:
            return Measurement(value: 35, unit: UnitAngle.degrees)
        case .right:
            return Measurement(value: 90, unit: UnitAngle.degrees)
        case .uTurn:
            return Measurement(value: 180, unit: UnitAngle.degrees)
        }
    }
}
