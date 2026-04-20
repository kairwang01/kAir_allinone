//
//  MapsRouteModels.swift
//  kAir
//
//  Shared local-first models for chat-to-maps task routing.
//

import CoreLocation
import Foundation

enum MapsConversationLanguage: String, Codable, Hashable {
    case chinese
    case english

    var usesChineseCopy: Bool {
        self == .chinese
    }
}

enum MapTaskType: String, Codable, Hashable {
    case goToPlace
    case nearbySearch
    case recommendation
    case routeComparison

    func title(for language: MapsConversationLanguage) -> String {
        switch (self, language) {
        case (.goToPlace, .chinese):
            return "去某个地点"
        case (.nearbySearch, .chinese):
            return "附近搜索"
        case (.recommendation, .chinese):
            return "地点推荐"
        case (.routeComparison, .chinese):
            return "路线比较"
        case (.goToPlace, .english):
            return "Go somewhere"
        case (.nearbySearch, .english):
            return "Nearby search"
        case (.recommendation, .english):
            return "Place recommendation"
        case (.routeComparison, .english):
            return "Route comparison"
        }
    }
}

enum MapTransportMode: String, Codable, CaseIterable, Hashable {
    case walking
    case driving
    case transit

    func title(for language: MapsConversationLanguage) -> String {
        switch (self, language) {
        case (.walking, .chinese):
            return "步行"
        case (.driving, .chinese):
            return "驾车"
        case (.transit, .chinese):
            return "公交"
        case (.walking, .english):
            return "Walking"
        case (.driving, .english):
            return "Driving"
        case (.transit, .english):
            return "Transit"
        }
    }

    var systemImage: String {
        switch self {
        case .walking:
            return "figure.walk"
        case .driving:
            return "car.fill"
        case .transit:
            return "tram.fill"
        }
    }
}

enum MapPermissionState: String, Codable, Hashable {
    case unknown
    case notDetermined
    case authorizedWhenInUse
    case denied
    case manualOnly

    var canUseCurrentLocation: Bool {
        self == .authorizedWhenInUse
    }
}

enum MapTaskEntryMode: String, Codable, Hashable {
    case chatAnswer
    case confirmCard
    case directOpenMaps
    case actionOpenMaps
}

enum MapManualInputKind: String, Codable, Hashable {
    case anchor
    case origin
    case destination

    func prompt(for language: MapsConversationLanguage) -> String {
        switch (self, language) {
        case (.anchor, .chinese):
            return "输入区域，例如 Downtown Toronto 或 Union Station。"
        case (.origin, .chinese):
            return "输入起点，例如家、公司或一个具体地名。"
        case (.destination, .chinese):
            return "输入目的地名称或更具体的地点。"
        case (.anchor, .english):
            return "Enter an area, for example Downtown Toronto or Union Station."
        case (.origin, .english):
            return "Enter a starting point, such as home, work, or a named place."
        case (.destination, .english):
            return "Enter a destination name or a more specific place."
        }
    }
}

enum MapResultDisplayMode: String, Codable, Hashable {
    case map
    case list
}

struct MapCoordinate: Codable, Hashable {
    let latitude: Double
    let longitude: Double

    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct MapPlaceCandidate: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let coordinate: MapCoordinate?
    let distanceText: String?
    let reason: String?
    let isCurrentLocation: Bool

    init(
        id: String = UUID().uuidString,
        title: String,
        subtitle: String,
        coordinate: MapCoordinate? = nil,
        distanceText: String? = nil,
        reason: String? = nil,
        isCurrentLocation: Bool = false
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.coordinate = coordinate
        self.distanceText = distanceText
        self.reason = reason
        self.isCurrentLocation = isCurrentLocation
    }

    static func currentLocationPlaceholder(language: MapsConversationLanguage) -> MapPlaceCandidate {
        MapPlaceCandidate(
            title: language.usesChineseCopy ? "当前位置" : "Current location",
            subtitle: language.usesChineseCopy ? "按需申请前台定位" : "Requested only when needed",
            isCurrentLocation: true
        )
    }

    static func currentLocation(
        from location: CLLocation,
        language: MapsConversationLanguage
    ) -> MapPlaceCandidate {
        let coordinate = MapCoordinate(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )

        return MapPlaceCandidate(
            title: language.usesChineseCopy ? "当前位置" : "Current location",
            subtitle: String(
                format: language.usesChineseCopy
                    ? "约 %.4f, %.4f"
                    : "Approx. %.4f, %.4f",
                coordinate.latitude,
                coordinate.longitude
            ),
            coordinate: coordinate,
            isCurrentLocation: true
        )
    }
}

struct MapRouteStep: Identifiable, Codable, Hashable {
    let id: String
    let instruction: String
    let notice: String?
    let distanceMeters: Double
    let distanceText: String
    let expectedTravelTime: TimeInterval
    let polylineCoordinates: [MapCoordinate]

    var maneuverCoordinate: MapCoordinate? {
        polylineCoordinates.last
    }
}

struct MapRouteOption: Identifiable, Codable, Hashable {
    let id: String
    let mode: MapTransportMode
    let title: String
    let summary: String
    let etaText: String
    let distanceText: String
    let distanceMeters: Double
    let expectedTravelTime: TimeInterval
    let emphasis: String
    let recommended: Bool
    let available: Bool
    let rankingValue: Double
    let polylineCoordinates: [MapCoordinate]
    let steps: [MapRouteStep]
}

struct MapNavigationSession: Identifiable, Hashable {
    let id: String
    let routeId: String
    let mode: MapTransportMode
    let destination: MapPlaceCandidate
    let routeCoordinates: [MapCoordinate]
    let steps: [MapRouteStep]
    let startedAt: Date
    var currentLocation: MapCoordinate?
    var currentStepIndex: Int
    var remainingDistanceMeters: Double
    var remainingDistanceText: String
    var remainingETA: String
    var nextInstruction: String
    var nextInstructionDetail: String?
    var progressFraction: Double
    var hasArrived: Bool
    var statusMessage: String?

    init(
        id: String = UUID().uuidString,
        routeId: String,
        mode: MapTransportMode,
        destination: MapPlaceCandidate,
        routeCoordinates: [MapCoordinate],
        steps: [MapRouteStep],
        startedAt: Date = .now,
        currentLocation: MapCoordinate? = nil,
        currentStepIndex: Int = 0,
        remainingDistanceMeters: Double = 0,
        remainingDistanceText: String = "--",
        remainingETA: String = "--",
        nextInstruction: String = "",
        nextInstructionDetail: String? = nil,
        progressFraction: Double = 0,
        hasArrived: Bool = false,
        statusMessage: String? = nil
    ) {
        self.id = id
        self.routeId = routeId
        self.mode = mode
        self.destination = destination
        self.routeCoordinates = routeCoordinates
        self.steps = steps
        self.startedAt = startedAt
        self.currentLocation = currentLocation
        self.currentStepIndex = currentStepIndex
        self.remainingDistanceMeters = remainingDistanceMeters
        self.remainingDistanceText = remainingDistanceText
        self.remainingETA = remainingETA
        self.nextInstruction = nextInstruction
        self.nextInstructionDetail = nextInstructionDetail
        self.progressFraction = progressFraction
        self.hasArrived = hasArrived
        self.statusMessage = statusMessage
    }
}

struct MapTask: Identifiable, Codable, Hashable {
    let id: String
    let threadId: UUID
    let taskType: MapTaskType
    let query: String
    var origin: MapPlaceCandidate?
    var destinationCandidates: [MapPlaceCandidate]
    var selectedDestination: MapPlaceCandidate?
    var transportMode: MapTransportMode?
    var permissionState: MapPermissionState
    var entryMode: MapTaskEntryMode
    var resultSummary: String
    let language: MapsConversationLanguage
    var nearbyResults: [MapPlaceCandidate]
    var routeOptions: [MapRouteOption]
    var manualInputKind: MapManualInputKind?
    var statusMessage: String?
    var errorMessage: String?
    var requestedDisplayMode: MapResultDisplayMode
    var generatedAt: Date

    init(
        id: String = UUID().uuidString,
        threadId: UUID,
        taskType: MapTaskType,
        query: String,
        origin: MapPlaceCandidate? = nil,
        destinationCandidates: [MapPlaceCandidate] = [],
        selectedDestination: MapPlaceCandidate? = nil,
        transportMode: MapTransportMode? = nil,
        permissionState: MapPermissionState = .unknown,
        entryMode: MapTaskEntryMode,
        resultSummary: String = "",
        language: MapsConversationLanguage,
        nearbyResults: [MapPlaceCandidate] = [],
        routeOptions: [MapRouteOption] = [],
        manualInputKind: MapManualInputKind? = nil,
        statusMessage: String? = nil,
        errorMessage: String? = nil,
        requestedDisplayMode: MapResultDisplayMode = .map,
        generatedAt: Date = .now
    ) {
        self.id = id
        self.threadId = threadId
        self.taskType = taskType
        self.query = query
        self.origin = origin
        self.destinationCandidates = destinationCandidates
        self.selectedDestination = selectedDestination
        self.transportMode = transportMode
        self.permissionState = permissionState
        self.entryMode = entryMode
        self.resultSummary = resultSummary
        self.language = language
        self.nearbyResults = nearbyResults
        self.routeOptions = routeOptions
        self.manualInputKind = manualInputKind
        self.statusMessage = statusMessage
        self.errorMessage = errorMessage
        self.requestedDisplayMode = requestedDisplayMode
        self.generatedAt = generatedAt
    }

    var needsManualInput: Bool {
        manualInputKind != nil
    }

    var hasResolvedDestination: Bool {
        selectedDestination != nil
    }

    var headerTitle: String {
        switch taskType {
        case .goToPlace:
            if let selectedDestination {
                return language.usesChineseCopy
                    ? "去 \(selectedDestination.title)"
                    : "Go to \(selectedDestination.title)"
            }
        case .nearbySearch:
            return language.usesChineseCopy
                ? "\(query) 附近结果"
                : "Nearby \(query)"
        case .recommendation:
            return language.usesChineseCopy
                ? "\(query) 推荐"
                : "\(query) recommendations"
        case .routeComparison:
            if let selectedDestination {
                return language.usesChineseCopy
                    ? "去 \(selectedDestination.title) 怎么走"
                    : "Best route to \(selectedDestination.title)"
            }
        }

        return taskType.title(for: language)
    }

    var headerSummary: String {
        if let errorMessage, errorMessage.isEmpty == false {
            return errorMessage
        }

        if let statusMessage, statusMessage.isEmpty == false {
            return statusMessage
        }

        switch taskType {
        case .goToPlace:
            if selectedDestination != nil {
                return language.usesChineseCopy
                    ? "AI 已锁定目的地，实时地图会继续补起点、路线和导航动作。"
                    : "AI has locked the destination, and the live map continues with origin, route, and navigation steps."
            }

            return language.usesChineseCopy
                ? "先在聊天里确认具体地点，再进入 Maps。"
                : "Confirm the exact place in chat before opening Maps."
        case .nearbySearch:
            return language.usesChineseCopy
                ? "附近搜索只在任务成立时进入 Maps，没有位置权限时也支持手动区域。"
                : "Nearby search opens Maps only when it helps. Manual area input still works without location access."
        case .recommendation:
            return language.usesChineseCopy
                ? "聊天先给出少量候选，只有在需要看空间分布时才打开 Maps。"
                : "Chat keeps recommendations lightweight and opens Maps only when spatial comparison helps."
        case .routeComparison:
            return language.usesChineseCopy
                ? "比较步行、驾车和公交，并始终保留返回原聊天线程的入口。"
                : "Compare walking, driving, and transit while keeping a clear return path back to the same chat thread."
        }
    }

    var visiblePlaces: [MapPlaceCandidate] {
        switch taskType {
        case .goToPlace, .routeComparison:
            var places: [MapPlaceCandidate] = []
            if let origin {
                places.append(origin)
            }
            if let selectedDestination {
                places.append(selectedDestination)
            }
            return places
        case .nearbySearch, .recommendation:
            if nearbyResults.isEmpty == false {
                return nearbyResults
            }
            return destinationCandidates
        }
    }

    var primaryCandidate: MapPlaceCandidate? {
        selectedDestination ?? destinationCandidates.first ?? nearbyResults.first
    }

    var hasUsableRoutes: Bool {
        routeOptions.contains(where: \.available)
    }

    var focusedRoute: MapRouteOption? {
        if let transportMode,
           let matchingRoute = routeOptions.first(where: { $0.mode == transportMode && $0.available }) {
            return matchingRoute
        }

        return routeOptions.first(where: \.recommended) ?? routeOptions.first(where: \.available)
    }

    func summaryForChatReturn() -> String {
        if resultSummary.isEmpty == false {
            return resultSummary
        }

        switch taskType {
        case .goToPlace:
            if let selectedDestination {
                return language.usesChineseCopy
                    ? "已在 Maps 里确认目的地：\(selectedDestination.title)。"
                    : "Confirmed the destination in Maps: \(selectedDestination.title)."
            }
        case .nearbySearch:
            return language.usesChineseCopy
                ? "已在 Maps 查看 \(nearbyResults.count) 个附近结果。"
                : "Reviewed \(nearbyResults.count) nearby results in Maps."
        case .recommendation:
            return language.usesChineseCopy
                ? "已在 Maps 对比推荐地点的空间分布。"
                : "Compared the recommended places on the map."
        case .routeComparison:
            if let bestRoute = routeOptions.first(where: \.recommended) {
                return language.usesChineseCopy
                    ? "已在 Maps 比较路线，当前推荐 \(bestRoute.mode.title(for: language))，约 \(bestRoute.etaText)。"
                    : "Compared routes in Maps. The current recommendation is \(bestRoute.mode.title(for: language)) at about \(bestRoute.etaText)."
            }
        }

        return language.usesChineseCopy
            ? "已从 Maps 返回当前聊天线程。"
            : "Returned from Maps to the current chat thread."
    }
}
