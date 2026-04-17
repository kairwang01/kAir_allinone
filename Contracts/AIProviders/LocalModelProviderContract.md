# Local Model Provider Contract

Purpose:
- Define a common capability surface for local AI runtimes.

Planned provider families:
- Apple on-device Foundation Models
- GGUF or llama.cpp-based chat runtimes
- Core ML specialized models
- ONNX Runtime specialized models

Capability fields to standardize:
- `id`
- `displayName`
- `runtimeFamily`
- `taskTypes`
- `supportedLanguages`
- `minimumDeviceClass`
- `estimatedMemoryMB`
- `diskSizeMB`
- `supportsStreaming`
- `supportsToolCalling`
- `supportsStructuredOutput`

Rules:
- The chat shell should not bind directly to one provider.
- Health analysis models remain separate from general chat models.
