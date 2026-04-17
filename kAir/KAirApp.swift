//
//  KAirApp.swift
//  kAir
//
//  Created by Kair on 2026/4/16.
//

import SwiftUI

@main
struct KAirApp: App {
    @State private var store = HealthDashboardStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
    }
}
