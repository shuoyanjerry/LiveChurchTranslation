#!/usr/bin/env python3

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
import onnxruntime as ort
import soundfile as sf
from transformers import WhisperFeatureExtractor

SAMPLE_RATE = 16_000
SAMPLE_COUNT = 8 * SAMPLE_RATE
EXPECTED_SHA256 = "2bb026316b14a660486a75b1733cd3fbab8c2fd0314dc9af7be49f8cca967e4f"
COORDINATES = [(0, 0), (0, 399), (0, 799), (7, 123), (20, 400), (40, 600),
               (60, 799), (79, 0), (79, 799)]


def sine_wave() -> np.ndarray:
    sample = np.arange(2 * SAMPLE_RATE, dtype=np.float64)
    return (0.25 * np.sin(2 * np.pi * 440 * sample / SAMPLE_RATE)).astype(np.float32)


def mixed_wave() -> np.ndarray:
    sample = np.arange(10 * SAMPLE_RATE, dtype=np.float64)
    time = sample / SAMPLE_RATE
    carrier = (0.16 * np.sin(2 * np.pi * (150 * time + 18 * time * time))
               + 0.10 * np.sin(2 * np.pi * 420 * time)
               + 0.06 * np.sin(2 * np.pi * 910 * time))
    envelope = 0.35 + 0.65 * np.square(np.sin(np.pi * 2.7 * time))
    audio = (carrier * envelope).astype(np.float32)
    audio[(time >= 4.15) & (time < 4.55)] = 0
    audio[(time >= 7.20) & (time < 7.48)] = 0
    audio[:2 * SAMPLE_RATE] = 0.9
    return audio


def last_eight_seconds(audio: np.ndarray) -> np.ndarray:
    audio = np.asarray(audio, dtype=np.float32)
    if len(audio) > SAMPLE_COUNT:
        return audio[-SAMPLE_COUNT:]
    if len(audio) < SAMPLE_COUNT:
        return np.pad(audio, (SAMPLE_COUNT - len(audio), 0), mode="constant")
    return audio


def feature_function():
    extractor = WhisperFeatureExtractor(chunk_length=8)

    def extract(audio: np.ndarray) -> np.ndarray:
        result = extractor(
            last_eight_seconds(audio),
            sampling_rate=SAMPLE_RATE,
            return_tensors="np",
            padding="max_length",
            max_length=SAMPLE_COUNT,
            truncation=True,
            do_normalize=True,
        )
        return result.input_features[0].astype(np.float32)

    return extract


def feature_case(name: str, audio: np.ndarray, extract) -> dict:
    features = extract(audio)
    return {
        "name": name,
        "sampleCount": len(audio),
        "selected": [float(features[mel, frame]) for mel, frame in COORDINATES],
        "statistics": {
            "minimum": float(features.min()),
            "maximum": float(features.max()),
            "mean": float(features.mean()),
            "standardDeviation": float(features.std()),
            "sum": float(features.sum(dtype=np.float64)),
        },
    }


def model_probability(model_path: Path, audio: np.ndarray, extract) -> float:
    digest = hashlib.sha256(model_path.read_bytes()).hexdigest()
    if digest != EXPECTED_SHA256:
        raise ValueError(f"Unexpected model SHA-256: {digest}")
    options = ort.SessionOptions()
    options.execution_mode = ort.ExecutionMode.ORT_SEQUENTIAL
    options.inter_op_num_threads = 1
    options.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
    session = ort.InferenceSession(str(model_path), sess_options=options)
    output = session.run(None, {"input_features": extract(audio)[None]})
    return float(output[0][0].item())


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", type=Path, default=root / ".artifacts/model-smoke/smart-turn/smart-turn-v3.2-cpu.onnx")
    parser.add_argument("--wave", type=Path, default=root / ".artifacts/model-smoke/theology.wav")
    parser.add_argument("--output", type=Path, default=root / "Tests/SemanticEndpointSmartTurnTests/Fixtures/whisper_feature_goldens.json")
    arguments = parser.parse_args()
    extract = feature_function()
    waves = [("silence", np.zeros(SAMPLE_RATE, dtype=np.float32)),
             ("sine", sine_wave()), ("mixed", mixed_wave())]
    theology, sample_rate = sf.read(arguments.wave, dtype="float32")
    if sample_rate != SAMPLE_RATE or theology.ndim != 1:
        raise ValueError("Theology fixture must be 16 kHz mono audio.")
    payload = {
        "generator": "transformers 4.57.1 WhisperFeatureExtractor(chunk_length=8, do_normalize=true)",
        "realModelParity": {
            "waveFile": arguments.wave.name,
            "probability": model_probability(arguments.model, theology, extract),
            "absoluteTolerance": 0.0002,
        },
        "coordinates": COORDINATES,
        "cases": [feature_case(name, audio, extract) for name, audio in waves],
    }
    arguments.output.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
