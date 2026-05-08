//
//  TelemetrySurfaceKind.swift
//  kAir
//
//  Temporary local mirror. Will be replaced with the canonical shared
//  `SurfaceKind` once it stabilizes (currently being introduced by the
//  feedback-runtime skeleton at `kAir/Core/Feedback/SurfaceKind.swift`).
//
//  This file exists only to unblock the telemetry skeleton's build
//  while the canonical shared `SurfaceKind` is in flight on a parallel
//  branch. The 8 cases here mirror the surface vocabulary frozen in
//  Contracts/UX/continuation-runtime-v1.md §2.1 and referenced by
//  Contracts/telemetry-contract-v1.md §4 (the `<kind>` placeholder in
//  `surface.<kind>.enter` / `surface.<kind>.return`).
//
//  Once the shared declaration lands, this enum will be deleted and
//  every reference rewritten to point at the canonical type. The
//  rewrite is purely mechanical (same case names, same raw values).
//

import Foundation

enum TelemetrySurfaceKind: String, Hashable, CaseIterable {
    case chat
    case health
    case ai
    case maps
    case store
    case music
    case video
    case search
}
