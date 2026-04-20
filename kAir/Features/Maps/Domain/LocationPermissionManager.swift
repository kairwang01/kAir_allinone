//
//  LocationPermissionManager.swift
//  kAir
//
//  While-in-use location authorization only. No background tracking.
//

import CoreLocation
import Foundation

enum LocationPermissionError: Error {
    case servicesDisabled
    case permissionDenied
    case unableToResolveLocation
}

@MainActor
final class LocationPermissionManager: NSObject, CLLocationManagerDelegate {
    private let manager: CLLocationManager
    private var authorizationContinuation: CheckedContinuation<MapPermissionState, Never>?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var liveUpdateHandler: ((CLLocation) -> Void)?

    init(manager: CLLocationManager = CLLocationManager()) {
        self.manager = manager
        super.init()
        self.manager.delegate = self
        self.manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        self.manager.distanceFilter = 8
    }

    var permissionState: MapPermissionState {
        Self.permissionState(for: manager.authorizationStatus)
    }

    func requestWhenInUseAuthorizationIfNeeded() async -> MapPermissionState {
        guard CLLocationManager.locationServicesEnabled() else {
            return .manualOnly
        }

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return .authorizedWhenInUse
        case .restricted, .denied:
            return .denied
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                authorizationContinuation = continuation
                manager.requestWhenInUseAuthorization()
            }
        @unknown default:
            return .unknown
        }
    }

    func requestCurrentLocation() async throws -> CLLocation {
        guard CLLocationManager.locationServicesEnabled() else {
            throw LocationPermissionError.servicesDisabled
        }

        let permission = await requestWhenInUseAuthorizationIfNeeded()
        guard permission == .authorizedWhenInUse else {
            throw LocationPermissionError.permissionDenied
        }

        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    func startContinuousLocationUpdates(
        handler: @escaping (CLLocation) -> Void
    ) async -> MapPermissionState {
        guard CLLocationManager.locationServicesEnabled() else {
            return .manualOnly
        }

        let permission = await requestWhenInUseAuthorizationIfNeeded()
        guard permission == .authorizedWhenInUse else {
            return permission
        }

        liveUpdateHandler = handler
        manager.startUpdatingLocation()
        return permission
    }

    func stopContinuousLocationUpdates() {
        liveUpdateHandler = nil
        manager.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard let authorizationContinuation else {
            return
        }

        self.authorizationContinuation = nil
        authorizationContinuation.resume(returning: Self.permissionState(for: manager.authorizationStatus))
    }

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        if let latestLocation = locations.last {
            liveUpdateHandler?(latestLocation)
        }

        guard let locationContinuation else {
            return
        }

        self.locationContinuation = nil

        guard let location = locations.last else {
            locationContinuation.resume(throwing: LocationPermissionError.unableToResolveLocation)
            return
        }

        locationContinuation.resume(returning: location)
    }

    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        guard let locationContinuation else {
            return
        }

        self.locationContinuation = nil
        locationContinuation.resume(throwing: error)
    }

    private static func permissionState(for status: CLAuthorizationStatus) -> MapPermissionState {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            return .authorizedWhenInUse
        case .restricted, .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .unknown
        }
    }
}
