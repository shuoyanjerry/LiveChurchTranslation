# Third-party notices

Live Church Translation downloads or embeds the following pinned components.
Model weights are not committed to this repository.

| Component | Pinned version | License | Distribution |
| --- | --- | --- | --- |
| sherpa-onnx | 1.13.6 | Apache-2.0 | SwiftPM static XCFramework |
| ONNX Runtime | 1.27.1 | MIT | Exact-pinned SwiftPM static XCFramework |
| libfvad | commit `532ab666c20d3cfda38bca63abbb0f152706c369` | BSD-3-Clause + patent grant | Vendored unmodified C source |
| Pipecat Smart Turn v3.2 CPU | HF commit `f766f81d3cfdf7737ac64aad813d91bbfd56bf93` | BSD-2-Clause | Optional local model; not committed |
| llama.cpp | b10549 | MIT | Bundled Apple Silicon helper and libraries |
| Qwen3-ASR 0.6B INT8 export | 2026-03-25 / HF commit `68818b2` | Apache-2.0 | First-run download |
| Hy-MT2 1.8B Q4_K_M | HF commit `1cd5208` | Apache-2.0 | First-run download |

The llama.cpp MIT license is copied into the app alongside its runtime. Model
download manifests pin immutable revisions, byte counts, and SHA-256 digests.
