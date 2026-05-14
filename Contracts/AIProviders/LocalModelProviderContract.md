# Local Model Provider Contract

Status: pre-canonical draft (not subject to the v1 ratification sweep)
— this document predates the canonical contract format used by the
`Contracts/UX/...` and `Contracts/*-v1.md` documents (no §1 purpose /
scope, no §8 change process, no ratification checklist). It is
retained for vocabulary / planning reference but is NOT a ratification
candidate in its current shape. A future PR may reformat it; until
then, no normative weight is implied by its presence under `Contracts/`.

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
