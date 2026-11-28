# 1. Use LiteRT-LM for On-Device AI Inference on Android

* **Status:** Accepted
* **Date:** 2026-11-26
* **Deciders:** Development Team, AI Engineering Agent
* **Tags:** ai-runtime, android, gemma-4, performance

## Context & Problem Statement
Quill & Papyrus AI currently runs local Gemma 4 models (`E2B` and `E4B`) on Android using `llama_flutter_android` (`llama.cpp`) with `.gguf` weights, and on Windows Desktop using a local `llama-server.exe` process with `.gguf` weights.

On Android, `llama_flutter_android` primarily executes on CPU, requires manual prompt-template formatting (which has caused empty/fallback responses when Gemma 4 turn markers mismatch), and does not leverage Google's mobile-specific Gemma 4 optimizations (GPU/NPU delegation, mixed-bit quantization, and Multi-Token Prediction).

Hard constraints:
* The Android release build MUST remain strictly air-gapped (zero `android.permission.INTERNET` in `AndroidManifest.xml`).
* Windows Desktop continues to use local `llama-server.exe` / LM Studio `.gguf` models.
* `AiService` must retain deterministic offline fallback when no local model file is present or during `flutter test`.

## Considered Options
* **Option 1:** Keep `llama_flutter_android` (`.gguf`) on Android and patch the Gemma 4 prompt template.
  * **Pros:** Single `.gguf` model format shared across Windows and Android; no dependency swap.
  * **Cons:** Slower CPU-bound inference and higher thermal load on Android; lacks native LiteRT GPU/NPU delegates and Gemma 4 `.litertlm` multimodal/MTP optimizations.
* **Option 2:** Replace `llama_flutter_android` with `flutter_litert_lm` (Google LiteRT-LM) on Android for `.litertlm` bundles, while keeping `llama-server.exe` (`.gguf`) on Windows Desktop.
  * **Pros:** Hardware-accelerated GPU (OpenCL) / NPU / CPU (XNNPACK) execution on Android; native Gemma 4 chat template handling inside the `.litertlm` bundle; lower memory footprint and faster decode speeds; ready for future on-device multimodal (vision/audio) support.
  * **Cons:** Split model formats (`.litertlm` on Android vs. `.gguf` on Windows); adds `flutter_litert_lm` dependency and removes `llama_flutter_android`.

## Decision Outcome
* **Chosen Option:** Option 2 (`flutter_litert_lm` on Android, `llama-server.exe` on Windows) because it delivers substantially faster, more reliable Gemma 4 inference on Android while preserving Windows `.gguf` compatibility and the strict air-gap guarantee.

### Positive Consequences
* Faster, cooler on-device Gemma 4 E2B/E4B inference on Android via GPU/NPU delegates.
* Eliminates manual `<start_of_turn>` prompt-template mismatches on Android because LiteRT-LM manages conversation turns natively.
* Users can delete large `.gguf` files on Android and use smaller, memory-mapped `.litertlm` bundles.

### Negative Consequences & Trade-offs
* Android and Windows use different local model file formats (`.litertlm` vs. `.gguf`).
* Android manifest merger must be verified after adding `flutter_litert_lm` to guarantee no `INTERNET` permission is introduced.
