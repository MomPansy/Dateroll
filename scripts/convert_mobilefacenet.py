#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11,<3.13"
# dependencies = [
#     "coremltools>=7.0,<8.0",
#     "onnx>=1.15",
#     "onnxruntime>=1.17",
#     "onnx2torch>=1.5",
#     "torch>=2.0",
#     "numpy<2.0",
# ]
# ///
"""
Download MobileFaceNet ONNX model (from InsightFace buffalo_sc) and convert to CoreML.

Pipeline: ONNX -> PyTorch (via onnx2torch) -> CoreML (via coremltools)

Usage:
    uv run scripts/convert_mobilefacenet.py

Output:
    Dateroll/Dateroll/Core/ML/MobileFaceNet.mlmodel
"""

import urllib.request
from pathlib import Path

import coremltools as ct
import numpy as np
import onnx
import onnx2torch
import torch

# --- Config ---
MODEL_URL = "https://huggingface.co/WePrompt/buffalo_sc/resolve/main/w600k_mbf.onnx"
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
ONNX_PATH = SCRIPT_DIR / "w600k_mbf.onnx"
COREML_DIR = PROJECT_ROOT / "Dateroll" / "Dateroll" / "Core" / "ML"
COREML_PATH = COREML_DIR / "MobileFaceNet.mlpackage"


def download_model():
    """Download the MobileFaceNet ONNX model if not already present."""
    if ONNX_PATH.exists():
        print(f"ONNX model already exists at {ONNX_PATH}")
        return

    print(f"Downloading MobileFaceNet ONNX model from {MODEL_URL}...")
    urllib.request.urlretrieve(MODEL_URL, str(ONNX_PATH))
    print(f"Downloaded to {ONNX_PATH} ({ONNX_PATH.stat().st_size / 1e6:.1f} MB)")


def verify_onnx():
    """Verify the ONNX model is valid and print its input/output shapes."""
    model = onnx.load(str(ONNX_PATH))
    onnx.checker.check_model(model)

    for inp in model.graph.input:
        shape = [d.dim_value for d in inp.type.tensor_type.shape.dim]
        print(f"  Input:  {inp.name} -> {shape}")
    for out in model.graph.output:
        shape = [d.dim_value for d in out.type.tensor_type.shape.dim]
        print(f"  Output: {out.name} -> {shape}")

    return model


def convert_to_coreml():
    """Convert ONNX -> PyTorch -> CoreML with image input."""
    print("Loading ONNX model into PyTorch...")
    onnx_model = onnx.load(str(ONNX_PATH))
    pt_model = onnx2torch.convert(onnx_model)
    pt_model.eval()

    # Trace the model with a dummy input
    dummy_input = torch.randn(1, 3, 112, 112)
    traced = torch.jit.trace(pt_model, dummy_input)

    print("Converting PyTorch -> CoreML...")
    # The bias/scale normalizes [0,255] pixel values to [-1,1] range expected by the model
    mlmodel = ct.convert(
        traced,
        inputs=[
            ct.ImageType(
                name="faceImage",
                shape=(1, 3, 112, 112),
                scale=1.0 / 127.5,
                bias=[-1.0, -1.0, -1.0],
                color_layout=ct.colorlayout.RGB,
            )
        ],
        minimum_deployment_target=ct.target.iOS17,
    )

    # Add metadata
    mlmodel.author = "InsightFace (buffalo_sc)"
    mlmodel.short_description = (
        "MobileFaceNet face embedding model. "
        "Input: 112x112 RGB image. Output: 512-dim embedding vector."
    )
    mlmodel.license = "Non-commercial research only (InsightFace license)"

    # Ensure output directory exists
    COREML_DIR.mkdir(parents=True, exist_ok=True)

    mlmodel.save(str(COREML_PATH))

    # .mlpackage is a directory; sum all file sizes
    total_bytes = sum(f.stat().st_size for f in COREML_PATH.rglob("*") if f.is_file())
    print(f"Saved CoreML model to {COREML_PATH} ({total_bytes / 1e6:.1f} MB)")

    return mlmodel


def main():
    print("=== MobileFaceNet ONNX -> CoreML Converter ===\n")

    download_model()
    print()

    print("Verifying ONNX model...")
    verify_onnx()
    print()

    convert_to_coreml()
    print()

    print("Done! CoreML model ready for Xcode integration.")


if __name__ == "__main__":
    main()
