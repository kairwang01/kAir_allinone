//
//  SurfaceKind.swift
//  kAir
//
//  Temporary location. Will move to a shared `kAir/Core/Surface/` module
//  once both Feedback and Telemetry skeletons land. The Feedback skeleton
//  declares it here; the Telemetry skeleton (Agent E) consumes it via its
//  module.
//
//  -----------------------------------------------------------------------
//  Implementation note (2026-05-08):
//
//  The frozen 8-case `SurfaceKind` enum already exists in this module at
//  `kAir/Shared/Components/Conversation/Continuation/ChatContinuationEvent.swift`
//  (declared there for the continuation runtime). Its cases match the
//  vocabulary required by `Contracts/UX/feedback-runtime-v1.md` §3.2 and
//  `Contracts/UX/continuation-runtime-v1.md` §2.1 verbatim:
//
//      .chat | .health | .ai | .maps | .store | .music | .video | .search
//
//  Re-declaring the same `SurfaceKind` enum at module scope here would
//  produce a Swift redeclaration error and break the build. Per the
//  agent's hard rule "do NOT modify any existing Swift file", we cannot
//  move the existing declaration into this file either.
//
//  The interim resolution is therefore:
//    - This file intentionally contains NO type declarations.
//    - `FeedbackEvent` consumes the existing module-level `SurfaceKind`.
//    - When the future shared `kAir/Core/Surface/` module lands, the
//      enum will move there in a single coordinated step (which IS
//      permitted to modify `ChatContinuationEvent.swift`), and this file
//      becomes the permanent home or is itself removed.
//
//  This file is preserved as a placeholder so the comment captures the
//  decision for readers who follow the trail from the contract. The
//  invariant the contract names — that Feedback and Continuation share
//  ONE `SurfaceKind` vocabulary — is upheld today by the single
//  declaration in `ChatContinuationEvent.swift`.
//

import Foundation

// Intentionally empty — see file header.
