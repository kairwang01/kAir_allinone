//
//  FeatureFlag.swift
//  kAir
//
//  Planned path for staged rollout and local feature toggles.
//

import Foundation

enum FeatureFlag {
    static let allInOneShellEnabled = true

    /// Server-backed account login (register / sign-in / Sign in with Apple /
    /// account deletion). The client is implemented and the current staging
    /// server exposes `/v1/auth/*`, but this remains **OFF for the v1 App Store
    /// submission**: v1 is local-first and fully usable without an account.
    /// Flip to `true` only in staging or after the public domain/production
    /// rollout is ready; that activates the Account section in Settings with no
    /// client-side key material.
    static let serverAuthEnabled = false

    /// Server-backed provider runtime (cost-routed remote models, search,
    /// research, MCP) over `/v1/kair/*`. In staging, this enables the
    /// server-backed text generator for general chat and lets the existing
    /// `ChatStore` replacement path consume `/v1/kair/model` responses. It stays
    /// OFF for v1 shipping builds so Health/private contexts remain on-device
    /// and every reachable surface works without network or account setup.
    static let serverProvidersEnabled = false

    /// The capability surfaces shown in the shipped v1 navigation. v1 ships the
    /// two genuinely on-device features — Chat (Apple Foundation Models) and
    /// Health (Apple HealthKit). Maps / Search / Store / AI are contract-first
    /// previews over stub data (no live map engine, crawler, commerce, or cloud
    /// inference yet), so they are withheld from the shipped build to keep every
    /// reachable surface genuinely functional (Apple 2.1) and free of fabricated
    /// data. They remain in the codebase + tests and are re-enabled per-surface
    /// as each becomes real (Maps → MapKit/Apple Maps; Search/Store → the server
    /// once `serverProvidersEnabled`).
    static let v1EnabledSurfaces: Set<AppSection> = [.chat, .health]
}
