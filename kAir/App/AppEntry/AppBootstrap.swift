//
//  AppBootstrap.swift
//  kAir
//
//  Root shell bootstrap state.
//

import Foundation
import Observation

@MainActor
@Observable
final class AppBootstrap {
    var currentSection: AppSection = .chat
    var presentedSurface: AppSection?
    var isProfilePresented = false
    var activeMapsSession: MapsRouteSession?
    let healthStore: HealthDashboardStore

    init(healthStore: HealthDashboardStore? = nil) {
        self.healthStore = healthStore ?? HealthDashboardStore()
    }

    func showProfile() {
        isProfilePresented = true
    }

    func openSurface(_ section: AppSection) {
        guard section != .chat else {
            closeSurface()
            return
        }

        currentSection = section
        presentedSurface = section
    }

    func openMaps(with session: MapsRouteSession? = nil) {
        if let session {
            activeMapsSession = session
        }
        openSurface(.maps)
    }

    func closeSurface() {
        currentSection = .chat
        presentedSurface = nil
    }

    static var preview: AppBootstrap {
        AppBootstrap(healthStore: .preview)
    }
}
