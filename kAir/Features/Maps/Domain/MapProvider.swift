//
//  MapProvider.swift
//  kAir
//
//  Product-facing map provider abstraction plus Apple MapKit adapter.
//

import CoreLocation
import Foundation
import MapKit

protocol MapProviding {
    func resolvePlaces(
        matching query: String,
        near anchor: MapPlaceCandidate?
    ) async throws -> [MapPlaceCandidate]

    func searchNearby(
        query: String,
        around anchor: MapPlaceCandidate
    ) async throws -> [MapPlaceCandidate]

    func calculateRoutes(
        from origin: MapPlaceCandidate,
        to destination: MapPlaceCandidate,
        preferredMode: MapTransportMode?
    ) async -> [MapRouteOption]
}

struct AppleMapProvider: MapProviding {
    func resolvePlaces(
        matching query: String,
        near anchor: MapPlaceCandidate? = nil
    ) async throws -> [MapPlaceCandidate] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query

        if let anchor = anchor?.coordinate?.clCoordinate {
            request.region = MKCoordinateRegion(
                center: anchor,
                latitudinalMeters: 12_000,
                longitudinalMeters: 12_000
            )
        }

        let response = try await MKLocalSearch(request: request).start()
        return deduplicatedCandidates(from: response.mapItems)
    }

    func searchNearby(
        query: String,
        around anchor: MapPlaceCandidate
    ) async throws -> [MapPlaceCandidate] {
        guard let center = anchor.coordinate?.clCoordinate else {
            return []
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: 8_000,
            longitudinalMeters: 8_000
        )

        let response = try await MKLocalSearch(request: request).start()
        let distanceFormatter = LengthFormatter()
        distanceFormatter.unitStyle = .short

        return deduplicatedCandidates(from: response.mapItems).map { candidate in
            guard
                let coordinate = candidate.coordinate?.clCoordinate
            else {
                return candidate
            }

            let placeLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let anchorLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
            let distance = placeLocation.distance(from: anchorLocation)

            return MapPlaceCandidate(
                id: candidate.id,
                title: candidate.title,
                subtitle: candidate.subtitle,
                coordinate: candidate.coordinate,
                distanceText: distanceFormatter.string(fromMeters: distance),
                reason: candidate.reason,
                isCurrentLocation: candidate.isCurrentLocation
            )
        }
    }

    func calculateRoutes(
        from origin: MapPlaceCandidate,
        to destination: MapPlaceCandidate,
        preferredMode: MapTransportMode?
    ) async -> [MapRouteOption] {
        let modes = preferredMode.map { [$0] } ?? MapTransportMode.allCases
        var options: [MapRouteOption] = []

        for mode in modes {
            do {
                let routes = try await calculateRoutes(
                    from: origin,
                    to: destination,
                    transportType: mode
                )
                options.append(contentsOf: routes)
            } catch {
                options.append(
                    MapRouteOption(
                        id: "\(mode.rawValue)-unavailable",
                        mode: mode,
                        title: mode.title(for: .english),
                        summary: "This route mode is unavailable for the selected origin and destination.",
                        etaText: "--",
                        distanceText: "--",
                        distanceMeters: 0,
                        expectedTravelTime: 0,
                        emphasis: "Unavailable",
                        recommended: false,
                        available: false,
                        rankingValue: .greatestFiniteMagnitude,
                        polylineCoordinates: [],
                        steps: []
                    )
                )
            }
        }

        let sorted = options.sorted { lhs, rhs in
            switch (lhs.available, rhs.available) {
            case (true, false):
                return true
            case (false, true):
                return false
            default:
                return lhs.rankingValue < rhs.rankingValue
            }
        }

        var didAssignRecommendation = false
        return sorted.map { option in
            guard option.available else { return option }
            if didAssignRecommendation {
                return option
            }

            didAssignRecommendation = true
            return MapRouteOption(
                id: option.id,
                mode: option.mode,
                title: option.title,
                summary: option.summary,
                etaText: option.etaText,
                distanceText: option.distanceText,
                distanceMeters: option.distanceMeters,
                expectedTravelTime: option.expectedTravelTime,
                emphasis: option.emphasis,
                recommended: true,
                available: option.available,
                rankingValue: option.rankingValue,
                polylineCoordinates: option.polylineCoordinates,
                steps: option.steps
            )
        }
    }

    private func calculateRoutes(
        from origin: MapPlaceCandidate,
        to destination: MapPlaceCandidate,
        transportType: MapTransportMode
    ) async throws -> [MapRouteOption] {
        guard
            let originCoordinate = origin.coordinate?.clCoordinate,
            let destinationCoordinate = destination.coordinate?.clCoordinate
        else {
            return []
        }

        let request = MKDirections.Request()
        request.source = MKMapItem(
            location: CLLocation(latitude: originCoordinate.latitude, longitude: originCoordinate.longitude),
            address: nil
        )
        request.destination = MKMapItem(
            location: CLLocation(latitude: destinationCoordinate.latitude, longitude: destinationCoordinate.longitude),
            address: nil
        )
        request.transportType = transportType.transportType
        request.requestsAlternateRoutes = false

        let response = try await MKDirections(request: request).calculate()
        guard response.routes.isEmpty == false else {
            return []
        }

        let measurementFormatter = LengthFormatter()
        measurementFormatter.unitStyle = .short
        let dateComponentsFormatter = DateComponentsFormatter()
        dateComponentsFormatter.allowedUnits = [.hour, .minute]
        dateComponentsFormatter.unitsStyle = .abbreviated

        return response.routes.map { route in
            let etaText = dateComponentsFormatter.string(from: route.expectedTravelTime) ?? "--"
            let distanceText = measurementFormatter.string(fromMeters: route.distance)

            return MapRouteOption(
                id: "\(transportType.rawValue)-\(route.name)-\(Int(route.distance))",
                mode: transportType,
                title: route.name.isEmpty ? transportType.title(for: .english) : route.name,
                summary: route.advisoryNotices.first ?? defaultRouteSummary(for: transportType),
                etaText: etaText,
                distanceText: distanceText,
                distanceMeters: route.distance,
                expectedTravelTime: route.expectedTravelTime,
                emphasis: route.steps.isEmpty
                    ? "Direct"
                    : "\(route.steps.count) steps",
                recommended: false,
                available: true,
                rankingValue: route.expectedTravelTime,
                polylineCoordinates: route.polyline
                    .coordinates
                    .map { coordinate in
                        MapCoordinate(
                            latitude: coordinate.latitude,
                            longitude: coordinate.longitude
                        )
                    },
                steps: buildRouteSteps(from: route)
            )
        }
    }

    private func buildRouteSteps(from route: MKRoute) -> [MapRouteStep] {
        let distanceFormatter = LengthFormatter()
        distanceFormatter.unitStyle = .short

        return route.steps.compactMap { step in
            let coordinates = step.polyline.coordinates.map { coordinate in
                MapCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
            }
            let trimmedInstruction = step.instructions.trimmingCharacters(in: .whitespacesAndNewlines)

            guard coordinates.isEmpty == false || trimmedInstruction.isEmpty == false else {
                return nil
            }

            return MapRouteStep(
                id: UUID().uuidString,
                instruction: trimmedInstruction,
                notice: step.notice,
                distanceMeters: step.distance,
                distanceText: distanceFormatter.string(fromMeters: step.distance),
                expectedTravelTime: step.transportType == .walking ? step.distance / 1.35 : 0,
                polylineCoordinates: coordinates
            )
        }
    }

    private func deduplicatedCandidates(from items: [MKMapItem]) -> [MapPlaceCandidate] {
        var seen = Set<String>()
        var candidates: [MapPlaceCandidate] = []

        for item in items {
            let title = item.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Place"
            let subtitle = item.addressRepresentations?.cityWithContext ?? ""
            let key = "\(title.lowercased())|\(subtitle.lowercased())"

            guard seen.insert(key).inserted else { continue }

            let coordinate = MapCoordinate(
                latitude: item.location.coordinate.latitude,
                longitude: item.location.coordinate.longitude
            )

            candidates.append(
                MapPlaceCandidate(
                    title: title,
                    subtitle: subtitle.isEmpty
                        ? item.addressRepresentations?.fullAddress(includingRegion: true, singleLine: true) ?? ""
                        : subtitle,
                    coordinate: coordinate
                )
            )
        }

        return Array(candidates.prefix(5))
    }

    private func defaultRouteSummary(for mode: MapTransportMode) -> String {
        switch mode {
        case .walking:
            return "Walking route prepared."
        case .driving:
            return "Driving route prepared."
        case .transit:
            return "Transit route prepared."
        }
    }
}

@MainActor
enum SystemMapsLauncher {
    @discardableResult
    static func openNavigation(
        from origin: MapPlaceCandidate?,
        to destination: MapPlaceCandidate,
        mode: MapTransportMode?
    ) -> Bool {
        guard let destinationItem = mapItem(for: destination) else {
            return false
        }

        let launchOptions = [
            MKLaunchOptionsDirectionsModeKey: directionsMode(for: mode),
            MKLaunchOptionsMapTypeKey: MKMapType.standard.rawValue
        ] as [String: Any]

        if let originItem = origin.flatMap(mapItem(for:)) {
            return MKMapItem.openMaps(with: [originItem, destinationItem], launchOptions: launchOptions)
        }

        return destinationItem.openInMaps(launchOptions: launchOptions)
    }

    @discardableResult
    static func openPlace(_ place: MapPlaceCandidate) -> Bool {
        guard let item = mapItem(for: place) else {
            return false
        }
        return item.openInMaps(launchOptions: [MKLaunchOptionsMapTypeKey: MKMapType.standard.rawValue])
    }

    private static func directionsMode(for mode: MapTransportMode?) -> String {
        switch mode {
        case .walking:
            return MKLaunchOptionsDirectionsModeWalking
        case .driving, .none:
            return MKLaunchOptionsDirectionsModeDriving
        case .transit:
            return MKLaunchOptionsDirectionsModeTransit
        }
    }

    private static func mapItem(for place: MapPlaceCandidate) -> MKMapItem? {
        guard let coordinate = place.coordinate?.clCoordinate else {
            return nil
        }

        let item = MKMapItem(
            location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
            address: nil
        )
        item.name = place.title
        return item
    }
}

private extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        var coordinates = Array(
            repeating: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            count: pointCount
        )
        getCoordinates(&coordinates, range: NSRange(location: 0, length: pointCount))
        return coordinates
    }
}

private extension MapTransportMode {
    var transportType: MKDirectionsTransportType {
        switch self {
        case .walking:
            return .walking
        case .driving:
            return .automobile
        case .transit:
            return .transit
        }
    }
}
