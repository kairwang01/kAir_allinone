//
//  ModelRouter.swift
//  kAir
//
//  Protocol: decide whether a request should be served by the local
//  adapter, the cloud fallback, or fail directly. Does not carry or
//  produce inference results.
//

import Foundation

protocol ModelRouter: Sendable {
    func route(_ request: ModelRoutingRequest) -> ModelRoutingDecision
}
