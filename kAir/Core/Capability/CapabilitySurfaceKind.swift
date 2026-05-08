//
//  CapabilitySurfaceKind.swift
//  kAir
//
//  Temporary local mirror. Will consolidate with the shared `SurfaceKind`
//  once it stabilizes (also temporarily declared by Agent D's feedback
//  skeleton).
//
//  The 8 frozen surface families per Contracts/UX/continuation-runtime-v1.md
//  §2.1. Adding a new surface requires a v2 of that contract.
//

import Foundation

/// 8 frozen cases mirroring continuation-runtime-v1 §2.1.
enum CapabilitySurfaceKind: String, Hashable, CaseIterable {
    case chat
    case health
    case ai
    case maps
    case store
    case music
    case video
    case search
}
