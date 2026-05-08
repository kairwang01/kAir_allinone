//
//  SurfaceKind.swift
//  kAir
//
//  Frozen vocabulary of execution-surface families used across the
//  app. Eight cases per Contracts/UX/continuation-runtime-v1.md §2.1.
//  Consumed by:
//    - ChatContinuationEvent (transcript continuation envelope)
//    - FeedbackEvent (feedback runtime envelope)
//    - TelemetryEvent surface-name helpers
//    - CapabilityKind.surfaceFamily
//
//  Adding a ninth case requires a v2 of continuation-runtime-v1.md
//  AND coordinated bumps of post-return-and-continuation-ux-v1.md,
//  feedback-runtime-v1.md, telemetry-contract-v1.md, and
//  capability-registry-and-adapter-contract-v1.md.
//

import Foundation

enum SurfaceKind: String, Hashable, CaseIterable {
    case chat
    case health
    case ai
    case maps
    case store
    case music
    case video
    case search
}
