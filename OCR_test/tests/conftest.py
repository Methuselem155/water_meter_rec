"""
Shared pytest fixtures for EasyOCR Text Extractor tests.
"""
import os
import tempfile
import numpy as np
import pytest


@pytest.fixture
def tmp_image_path(tmp_path):
    """Create a temporary valid PNG image file for testing."""
    import cv2
    img = np.ones((100, 100, 3), dtype=np.uint8) * 255  # white image
    img_path = str(tmp_path / "test_image.png")
    cv2.imwrite(img_path, img)
    return img_path


@pytest.fixture
def tmp_jpg_path(tmp_path):
    """Create a temporary valid JPG image file for testing."""
    import cv2
    img = np.ones((100, 100, 3), dtype=np.uint8) * 200
    img_path = str(tmp_path / "test_image.jpg")
    cv2.imwrite(img_path, img)
    return img_path


@pytest.fixture
def sample_ocr_results():
    """Sample EasyOCR-style results: list of (bbox, text, confidence) tuples."""
    bbox = [[0, 0], [100, 0], [100, 30], [0, 30]]
    return [
        (bbox, "Hello", 0.99),
        (bbox, "World", 0.95),
        (bbox, "42", 0.98),
    ]


@pytest.fixture
def tmp_output_path(tmp_path):
    """Provide a writable output .txt path."""
    return str(tmp_path / "results.txt")
