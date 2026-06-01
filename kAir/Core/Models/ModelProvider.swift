//
//  ModelProvider.swift
//  kAir
//
//  Planned path for provider abstraction.
//

import Foundation

// Architecture note:
// `ModelProvider` is the runtime-agnostic generation and embedding
// surface. It hides Foundation Models, Core ML, MLX, llama.cpp/GGUF,
// ExecuTorch specialists, and remote paid model gateways behind one
// request/response contract.
//
// Future provider contract:
// - availability: installed, downloading, compiling, unavailable,
//   requires purchase, remote-only, or failed.
// - generate: accepts `ModelRequest` with task, privacy class, schema,
//   budget, and cancellation id.
// - embed: optional for providers that support local embeddings.
// - metrics: latency, memory pressure, token counts if available, and
//   structured-output validity.
//
// Provider boundaries:
// - Provider does not choose capability.
// - Provider does not decide whether an action is safe.
// - Provider does not write memory.
// - Provider does not own StoreKit entitlement.
// - Provider does not hold API keys in app bundle.
//
// Runtime guidance:
// - Foundation Models: preferred Apple-native structured generation
//   when available.
// - Core ML: compiled local specialists and embeddings.
// - MLX: research and Apple Silicon local experiments.
// - llama.cpp/GGUF: optional grammar-constrained local routing.
// - ExecuTorch: non-generative edge classifiers/rerankers.
// - Remote gateway: paid market models through server-side transport.
//
// First implementation gate:
// - Add protocol and pure request/response value types.
// - Add fake provider tests before any real runtime is wired.
