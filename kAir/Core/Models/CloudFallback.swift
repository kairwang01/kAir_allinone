//
//  CloudFallback.swift
//  kAir
//
//  Protocol: a provider of last resort when the local InferenceAdapter
//  cannot serve a request. Kept as a distinct protocol (not a typealias)
//  so call sites and routing logic can treat local vs. cloud as
//  semantically different edges.
//

import Foundation

protocol CloudFallback: Sendable {
    func infer(_ request: InferenceRequest) async -> InferenceResult
}
