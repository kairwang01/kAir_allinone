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
    /// account deletion). The full client implementation ships behind this flag
    /// but is **OFF for the v1 App Store submission**: v1 is local-first and
    /// fully usable without an account, and the kAir server's `/v1/auth/*` is
    /// not yet live. Flip to `true` once the server agent confirms the auth
    /// endpoints are deployed — that activates the Account section in Settings
    /// (sign-in + Sign in with Apple + Delete Account / 5.1.1(v)) with no other
    /// code change. Keeping it off keeps the shipped build's every surface
    /// functional for review (Apple 2.1).
    static let serverAuthEnabled = false

    /// Server-backed provider runtime (cost-routed remote models, search,
    /// research, MCP) over `/v1/kair/*`. Same rationale as `serverAuthEnabled`:
    /// implemented + tested client-side, but OFF for v1 so the shipped build
    /// stays on-device-only (Apple Foundation Models + deterministic fallback)
    /// until the server is live. Flip to `true` when `/v1/kair/*` is deployed.
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
