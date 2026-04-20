//
//  InferenceAdapter.swift
//  kAir
//
//  Protocol: a provider that can run a single InferenceRequest and
//  return an InferenceResult. Implementations are expected to be
//  local (on-device). Kept deliberately separate from CloudFallback.
//

import Foundation

protocol InferenceAdapter: Sendable {
    func infer(_ request: InferenceRequest) async -> InferenceResult
}
