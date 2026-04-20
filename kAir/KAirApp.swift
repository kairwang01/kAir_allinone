//
//  KAirApp.swift
//  kAir
//
//  Created by Kair on 2026/4/16.
//

import SwiftUI

@main
struct KAirApp: App {
    @UIApplicationDelegateAdaptor(KAirAppDelegate.self) private var appDelegate
    @State private var store = HealthDashboardStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
    }
}
