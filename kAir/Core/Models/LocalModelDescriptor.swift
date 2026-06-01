//
//  LocalModelDescriptor.swift
//  kAir
//
//  Planned path for installed model metadata.
//

import Foundation

// Architecture note:
// `LocalModelDescriptor` is the stable metadata shape for bundled,
// installed, downloadable, paid, and unavailable models. UI and routing
// policy read descriptors; concrete providers stay hidden behind
// `ModelProvider`.
//
// Target fields:
// - id, display name, version, role, runtime family.
// - supported languages and task types.
// - disk size, estimated memory, minimum OS, minimum device class.
// - privacy classes allowed: general, health-local-only, social,
//   commerce, private.
// - structured-output and tool-calling capability.
// - download URL, checksum, signature, license, and catalog source.
// - StoreKit product id when paid.
// - installed path and compiled artifact path when local.
//
// Rules:
// - Descriptor metadata is not proof that a model is installed.
// - Descriptor metadata is not proof that a paid model is entitled.
// - Health specialist descriptors must default to local-only routing.
// - Remote market models still get descriptors, but never local file
//   paths and never app-bundled API keys.
//
// First implementation gate:
// - Add descriptor value type and validation tests for required fields,
//   checksum presence on downloadable models, and health-local-only
//   privacy class.
