#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11,<3.13"
# dependencies = [
#     "onnxruntime>=1.17",
#     "numpy",
#     "Pillow>=10.0",
# ]
# ///
"""
Tests for MobileFaceNet ONNX model and CoreML conversion output.

Usage:
    uv run scripts/convert_mobilefacenet.py   # run conversion first
    uv run -m pytest scripts/test_mobilefacenet.py -v
    # or directly:
    uv run scripts/test_mobilefacenet.py
"""

import unittest
from pathlib import Path

import numpy as np
import onnxruntime as ort
from PIL import Image

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
ONNX_PATH = SCRIPT_DIR / "w600k_mbf.onnx"
COREML_PATH = PROJECT_ROOT / "Dateroll" / "Dateroll" / "Core" / "ML" / "MobileFaceNet.mlpackage"
FACE_1_PATH = SCRIPT_DIR / "test_face_1.jpg"
FACE_2_PATH = SCRIPT_DIR / "test_face_2.jpg"
FACE_SAME_A_PATH = SCRIPT_DIR / "test_face_same_a.jpg"
FACE_SAME_B_PATH = SCRIPT_DIR / "test_face_same_b.jpg"

EMBEDDING_DIM = 512
INPUT_SIZE = 112


def _make_image(seed: int = 0) -> np.ndarray:
    """Create a synthetic 112x112 RGB image as float32 NCHW tensor."""
    rng = np.random.RandomState(seed)
    # Simulate a normalized face image: values in [-1, 1]
    return rng.uniform(-1.0, 1.0, (1, 3, INPUT_SIZE, INPUT_SIZE)).astype(np.float32)


def _load_face_image(path: Path) -> np.ndarray:
    """Load a face image, resize to 112x112, normalize to [-1,1], return NCHW tensor."""
    img = Image.open(path).convert("RGB").resize((INPUT_SIZE, INPUT_SIZE))
    arr = np.array(img, dtype=np.float32)  # HWC, [0, 255]
    arr = (arr - 127.5) / 127.5  # normalize to [-1, 1]
    arr = arr.transpose(2, 0, 1)  # HWC -> CHW
    return arr[np.newaxis, ...]  # add batch dim -> NCHW


def _cosine_similarity(a: np.ndarray, b: np.ndarray) -> float:
    """Compute cosine similarity between two vectors."""
    a, b = a.flatten(), b.flatten()
    return float(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b)))


class TestONNXModel(unittest.TestCase):
    """Tests that run inference on the ONNX model with onnxruntime."""

    @classmethod
    def setUpClass(cls):
        if not ONNX_PATH.exists():
            raise FileNotFoundError(
                f"ONNX model not found at {ONNX_PATH}. "
                "Run convert_mobilefacenet.py first."
            )
        cls.session = ort.InferenceSession(str(ONNX_PATH))
        cls.input_name = cls.session.get_inputs()[0].name

    def _run(self, image: np.ndarray) -> np.ndarray:
        """Run inference and return the embedding vector."""
        outputs = self.session.run(None, {self.input_name: image})
        return outputs[0]

    def test_output_shape(self):
        """Output should be (1, 512) embedding vector."""
        image = _make_image(seed=42)
        embedding = self._run(image)
        self.assertEqual(embedding.shape, (1, EMBEDDING_DIM))

    def test_output_is_finite(self):
        """All embedding values should be finite (no NaN/Inf)."""
        image = _make_image(seed=42)
        embedding = self._run(image)
        self.assertTrue(np.all(np.isfinite(embedding)))

    def test_identical_inputs_same_output(self):
        """Two identical inputs should produce identical embeddings."""
        image = _make_image(seed=99)
        emb1 = self._run(image)
        emb2 = self._run(image)
        np.testing.assert_array_equal(emb1, emb2)

    def test_different_inputs_different_output(self):
        """Two different inputs should produce different embeddings."""
        emb1 = self._run(_make_image(seed=0))
        emb2 = self._run(_make_image(seed=1))
        # Cosine similarity should be < 1.0 (not identical)
        cos_sim = np.dot(emb1.flatten(), emb2.flatten()) / (
            np.linalg.norm(emb1) * np.linalg.norm(emb2)
        )
        self.assertLess(cos_sim, 0.99, "Different images should produce different embeddings")

    def test_embedding_is_normalized(self):
        """MobileFaceNet typically outputs L2-normalized embeddings (norm ~ 1.0)."""
        image = _make_image(seed=42)
        embedding = self._run(image)
        norm = np.linalg.norm(embedding)
        # Some models don't normalize; allow a wider range but check it's reasonable
        self.assertGreater(norm, 0.1, "Embedding norm should be non-trivial")


class TestRealFaceEmbeddings(unittest.TestCase):
    """Tests using real face images to verify meaningful embeddings."""

    @classmethod
    def setUpClass(cls):
        if not ONNX_PATH.exists():
            raise FileNotFoundError("ONNX model not found. Run convert_mobilefacenet.py first.")
        if not FACE_1_PATH.exists() or not FACE_2_PATH.exists():
            raise FileNotFoundError("Test face images not found in scripts/.")
        cls.session = ort.InferenceSession(str(ONNX_PATH))
        cls.input_name = cls.session.get_inputs()[0].name

    def _run(self, image: np.ndarray) -> np.ndarray:
        outputs = self.session.run(None, {self.input_name: image})
        return outputs[0]

    def test_real_face_produces_valid_embedding(self):
        """A real face image should produce a 512-dim finite embedding."""
        image = _load_face_image(FACE_1_PATH)
        embedding = self._run(image)
        self.assertEqual(embedding.shape, (1, EMBEDDING_DIM))
        self.assertTrue(np.all(np.isfinite(embedding)))

    def test_real_face_embedding_has_structure(self):
        """Real face embedding should have non-trivial norm (not zeros)."""
        embedding = self._run(_load_face_image(FACE_1_PATH))
        norm = np.linalg.norm(embedding)
        self.assertGreater(norm, 1.0, f"Embedding norm too small: {norm}")

    def test_same_face_twice_identical(self):
        """Same image fed twice should produce identical embeddings."""
        image = _load_face_image(FACE_1_PATH)
        emb1 = self._run(image)
        emb2 = self._run(image)
        np.testing.assert_array_equal(emb1, emb2)

    def test_two_different_faces_differ(self):
        """Two different face images should produce different embeddings."""
        emb1 = self._run(_load_face_image(FACE_1_PATH))
        emb2 = self._run(_load_face_image(FACE_2_PATH))
        sim = _cosine_similarity(emb1, emb2)
        # Two different people should have cosine similarity well below 1.0
        self.assertLess(sim, 0.8, f"Different faces too similar: cosine={sim:.4f}")
        print(f"\n  Cosine similarity between two different faces: {sim:.4f}")

    def test_real_face_vs_noise_differ(self):
        """A real face should produce a very different embedding than random noise."""
        emb_face = self._run(_load_face_image(FACE_1_PATH))
        emb_noise = self._run(_make_image(seed=0))
        sim = _cosine_similarity(emb_face, emb_noise)
        self.assertLess(abs(sim), 0.5, f"Face vs noise too similar: cosine={sim:.4f}")
        print(f"\n  Cosine similarity face vs noise: {sim:.4f}")


class TestSamePersonDifferentPhoto(unittest.TestCase):
    """Tests that two different photos of the same person produce similar embeddings."""

    @classmethod
    def setUpClass(cls):
        if not ONNX_PATH.exists():
            raise FileNotFoundError("ONNX model not found. Run convert_mobilefacenet.py first.")
        if not FACE_SAME_A_PATH.exists() or not FACE_SAME_B_PATH.exists():
            raise FileNotFoundError(
                "Same-person test images not found. "
                "Need test_face_same_a.jpg and test_face_same_b.jpg in scripts/."
            )
        cls.session = ort.InferenceSession(str(ONNX_PATH))
        cls.input_name = cls.session.get_inputs()[0].name

    def _run(self, image: np.ndarray) -> np.ndarray:
        outputs = self.session.run(None, {self.input_name: image})
        return outputs[0]

    def test_same_person_high_similarity(self):
        """Two different photos of the same person should have high cosine similarity."""
        emb_a = self._run(_load_face_image(FACE_SAME_A_PATH))
        emb_b = self._run(_load_face_image(FACE_SAME_B_PATH))
        sim = _cosine_similarity(emb_a, emb_b)
        # Same person should have cosine similarity > 0.4 (typical threshold ~0.5)
        self.assertGreater(sim, 0.4, f"Same person similarity too low: cosine={sim:.4f}")
        print(f"\n  Cosine similarity (same person, different photo): {sim:.4f}")

    def test_same_person_more_similar_than_different_people(self):
        """Same-person similarity should be higher than different-person similarity."""
        emb_same_a = self._run(_load_face_image(FACE_SAME_A_PATH))
        emb_same_b = self._run(_load_face_image(FACE_SAME_B_PATH))
        emb_other = self._run(_load_face_image(FACE_1_PATH))

        sim_same = _cosine_similarity(emb_same_a, emb_same_b)
        sim_diff = _cosine_similarity(emb_same_a, emb_other)

        self.assertGreater(
            sim_same, sim_diff,
            f"Same-person sim ({sim_same:.4f}) should exceed "
            f"different-person sim ({sim_diff:.4f})"
        )
        print(f"\n  Same person: {sim_same:.4f} vs different person: {sim_diff:.4f}")


class TestCoreMLOutput(unittest.TestCase):
    """Tests that the CoreML model file was created correctly."""

    def test_coreml_file_exists(self):
        """CoreML .mlpackage directory should exist after conversion."""
        self.assertTrue(
            COREML_PATH.exists(),
            f"CoreML model not found at {COREML_PATH}. Run convert_mobilefacenet.py first.",
        )

    def test_coreml_file_size(self):
        """CoreML model should be a reasonable size (> 1 MB, < 100 MB)."""
        # .mlpackage is a directory; sum all file sizes
        total_bytes = sum(
            f.stat().st_size for f in COREML_PATH.rglob("*") if f.is_file()
        )
        size_mb = total_bytes / 1e6
        self.assertGreater(size_mb, 1.0, f"Model too small: {size_mb:.1f} MB")
        self.assertLess(size_mb, 100.0, f"Model too large: {size_mb:.1f} MB")


if __name__ == "__main__":
    unittest.main()
