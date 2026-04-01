"""
tests/test_ocr_extractor.py
============================
Unit tests and property-based tests for ocr_extractor.py.

Run with:
    pytest tests/ -v

Property-based tests use the Hypothesis library to verify that certain
mathematical properties hold for *all* inputs, not just the examples we
thought of manually.
"""

import os
import sys
import tempfile
from unittest.mock import MagicMock, patch

import numpy as np
import pytest
from hypothesis import given, settings
from hypothesis import strategies as st

# Make sure the project root is on the path so we can import ocr_extractor
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from ocr_extractor import (
    combine_text,
    extract_digits,
    print_results,
    save_results,
    validate_image,
    draw_bounding_boxes,
    OCREngine,
    ProcessingConfig,
)


# ===========================================================================
# Helpers
# ===========================================================================

def _make_bbox():
    """Return a minimal EasyOCR-style bounding box."""
    return [[0, 0], [100, 0], [100, 30], [0, 30]]


# ===========================================================================
# Unit Tests: validate_image
# ===========================================================================

class TestValidateImage:
    """Tests for the InputValidator component."""

    def test_valid_png_returns_absolute_path(self, tmp_image_path):
        """A valid PNG file should return its absolute path."""
        result = validate_image(tmp_image_path)
        assert os.path.isabs(result)
        assert result == os.path.abspath(tmp_image_path)

    def test_valid_jpg_returns_absolute_path(self, tmp_jpg_path):
        """A valid JPG file should return its absolute path."""
        result = validate_image(tmp_jpg_path)
        assert os.path.isabs(result)

    def test_missing_file_raises_file_not_found(self, tmp_path):
        """A path that does not exist should raise FileNotFoundError."""
        missing = str(tmp_path / "does_not_exist.png")
        with pytest.raises(FileNotFoundError):
            validate_image(missing)

    def test_wrong_extension_raises_value_error(self, tmp_path):
        """A file with an unsupported extension should raise ValueError."""
        bmp_file = tmp_path / "image.bmp"
        bmp_file.write_bytes(b"fake bmp content")
        with pytest.raises(ValueError, match="Unsupported format"):
            validate_image(str(bmp_file))

    def test_txt_extension_raises_value_error(self, tmp_path):
        """A .txt file should raise ValueError."""
        txt_file = tmp_path / "notes.txt"
        txt_file.write_text("hello")
        with pytest.raises(ValueError):
            validate_image(str(txt_file))

    def test_jpeg_extension_is_accepted(self, tmp_path):
        """The .jpeg extension (not just .jpg) should be accepted."""
        import cv2
        img = np.ones((50, 50, 3), dtype=np.uint8) * 128
        jpeg_path = str(tmp_path / "image.jpeg")
        cv2.imwrite(jpeg_path, img)
        result = validate_image(jpeg_path)
        assert result.endswith(".jpeg")

    def test_relative_path_is_resolved(self, tmp_path):
        """A relative path should be resolved to an absolute path."""
        import cv2
        # Create the image inside the current working directory so relpath works
        cwd_tmp = os.path.join(os.getcwd(), "test_rel_image.png")
        img = np.ones((50, 50, 3), dtype=np.uint8) * 200
        cv2.imwrite(cwd_tmp, img)
        try:
            rel = os.path.relpath(cwd_tmp)
            result = validate_image(rel)
            assert os.path.isabs(result)
        finally:
            if os.path.exists(cwd_tmp):
                os.remove(cwd_tmp)


# ===========================================================================
# Unit Tests: combine_text
# ===========================================================================

class TestCombineText:
    """Tests for the TextProcessor.combine_text function."""

    def test_empty_list_returns_empty_string(self):
        """combine_text([]) should return ''."""
        assert combine_text([]) == ""

    def test_single_result_returns_text(self):
        """A single OCR result should return just its text."""
        results = [(_make_bbox(), "Hello", 0.99)]
        assert combine_text(results) == "Hello"

    def test_multiple_results_joined_with_space(self):
        """Multiple results should be joined with a single space."""
        results = [
            (_make_bbox(), "Hello", 0.99),
            (_make_bbox(), "World", 0.95),
        ]
        assert combine_text(results) == "Hello World"

    def test_three_fragments_joined_correctly(self):
        """Three fragments should produce a space-separated string."""
        results = [
            (_make_bbox(), "Invoice", 0.98),
            (_make_bbox(), "1042", 0.97),
            (_make_bbox(), "USD", 0.96),
        ]
        assert combine_text(results) == "Invoice 1042 USD"

    def test_preserves_fragment_content(self, sample_ocr_results):
        """All text fragments from the fixture should appear in the output."""
        result = combine_text(sample_ocr_results)
        assert "Hello" in result
        assert "World" in result
        assert "42" in result


# ===========================================================================
# Unit Tests: extract_digits
# ===========================================================================

class TestExtractDigits:
    """Tests for the TextProcessor.extract_digits function."""

    def test_empty_string_returns_empty(self):
        """extract_digits('') should return ''."""
        assert extract_digits("") == ""

    def test_no_digits_returns_empty(self):
        """A string with no digits should return ''."""
        assert extract_digits("Hello World") == ""

    def test_only_digits_returns_them(self):
        """A string of only digits should return those digits."""
        assert extract_digits("12345") == "12345"

    def test_mixed_text_extracts_digits(self):
        """Digits embedded in text should be extracted."""
        result = extract_digits("Invoice 1042 Total 99 USD")
        assert result == "1042 99"

    def test_decimal_number_splits_on_dot(self):
        """'99.50' should yield '99' and '50' as separate matches."""
        result = extract_digits("Price: 99.50")
        assert result == "99 50"

    def test_multiple_digit_groups(self):
        """Multiple digit groups should all be captured."""
        result = extract_digits("a1b2c3")
        assert result == "1 2 3"

    def test_leading_trailing_digits(self):
        """Digits at the start and end of the string should be captured."""
        result = extract_digits("42 hello 7")
        assert result == "42 7"

    def test_only_spaces_returns_empty(self):
        """A string of only spaces has no digits."""
        assert extract_digits("   ") == ""


# ===========================================================================
# Unit Tests: save_results
# ===========================================================================

class TestSaveResults:
    """Tests for the OutputHandler.save_results function."""

    def test_creates_file_with_correct_content(self, tmp_output_path):
        """save_results should create a .txt file containing both sections."""
        save_results("Hello World", "42", tmp_output_path)

        assert os.path.exists(tmp_output_path)
        content = open(tmp_output_path, encoding="utf-8").read()
        assert "Hello World" in content
        assert "42" in content

    def test_file_is_utf8_encoded(self, tmp_output_path):
        """The output file should be readable as UTF-8."""
        save_results("Café résumé", "0", tmp_output_path)
        content = open(tmp_output_path, encoding="utf-8").read()
        assert "Café" in content

    def test_permission_error_is_handled_gracefully(self, capsys):
        """A PermissionError should be caught and a warning printed."""
        with patch("builtins.open", side_effect=PermissionError("denied")):
            # Should NOT raise – just print a warning
            save_results("text", "1", "/fake/path/results.txt")

        captured = capsys.readouterr()
        assert "Warning" in captured.out or "Permission" in captured.out

    def test_empty_strings_still_creates_file(self, tmp_output_path):
        """Even with empty text and digits, the file should be created."""
        save_results("", "", tmp_output_path)
        assert os.path.exists(tmp_output_path)


# ===========================================================================
# Unit Tests: draw_bounding_boxes
# ===========================================================================

class TestDrawBoundingBoxes:
    """Tests for the Visualizer.draw_bounding_boxes function."""

    def test_returns_ndarray(self):
        """draw_bounding_boxes should return a NumPy array."""
        image = np.zeros((100, 100, 3), dtype=np.uint8)
        results = [(_make_bbox(), "Hi", 0.9)]
        annotated = draw_bounding_boxes(image, results)
        assert isinstance(annotated, np.ndarray)

    def test_does_not_modify_original(self):
        """The original image should be unchanged after annotation."""
        image = np.zeros((100, 100, 3), dtype=np.uint8)
        original_copy = image.copy()
        draw_bounding_boxes(image, [(_make_bbox(), "Hi", 0.9)])
        np.testing.assert_array_equal(image, original_copy)

    def test_empty_results_returns_copy(self):
        """With no OCR results, the returned image should equal the original."""
        image = np.ones((50, 50, 3), dtype=np.uint8) * 128
        annotated = draw_bounding_boxes(image, [])
        np.testing.assert_array_equal(annotated, image)


# ===========================================================================
# Unit Tests: OCREngine (mocked)
# ===========================================================================

class TestOCREngine:
    """Tests for OCREngine – EasyOCR is mocked to avoid slow initialisation."""

    def test_extract_returns_list(self):
        """OCREngine.extract should return the list from reader.readtext."""
        fake_results = [(_make_bbox(), "Test", 0.99)]

        with patch("easyocr.Reader") as MockReader:
            mock_reader_instance = MagicMock()
            mock_reader_instance.readtext.return_value = fake_results
            MockReader.return_value = mock_reader_instance

            engine = OCREngine(languages=["en"])
            image = np.zeros((50, 50), dtype=np.uint8)
            results = engine.extract(image)

        assert results == fake_results

    def test_reader_initialised_once(self):
        """easyocr.Reader should be called exactly once during __init__."""
        with patch("easyocr.Reader") as MockReader:
            MockReader.return_value = MagicMock()
            engine = OCREngine(languages=["en"])
            assert MockReader.call_count == 1


# ===========================================================================
# Property-Based Tests (Hypothesis)
# ===========================================================================

# Strategy: generate arbitrary Unicode strings (text)
text_strategy = st.text(min_size=0, max_size=500)

# Strategy: generate valid OCR result tuples
ocr_tuple_strategy = st.tuples(
    st.just(_make_bbox()),                          # bbox (fixed shape)
    st.text(min_size=1, max_size=50),               # text fragment
    st.floats(min_value=0.0, max_value=1.0,
              allow_nan=False, allow_infinity=False),  # confidence
)


class TestExtractDigitsProperties:
    """
    Property-based tests for extract_digits.

    Validates: Requirements – Digit Extraction Algorithm
    """

    @given(text_strategy)
    @settings(max_examples=300)
    def test_output_contains_only_digits_and_spaces(self, text):
        """
        **Validates: Requirements – Digit Extraction Algorithm**

        Property: For any string s, every character in extract_digits(s)
        is either a digit (0-9) or a space.
        """
        result = extract_digits(text)
        for ch in result:
            assert ch.isdigit() or ch == " ", (
                f"Unexpected character {ch!r} in extract_digits({text!r}) = {result!r}"
            )

    @given(text_strategy)
    @settings(max_examples=300)
    def test_every_digit_sequence_appears_in_input(self, text):
        """
        **Validates: Requirements – Digit Extraction Algorithm**

        Property: Every digit sequence returned by extract_digits(s)
        must be a substring of the original string s.
        """
        result = extract_digits(text)
        if not result:
            return  # nothing to check

        for seq in result.split():
            assert seq in text, (
                f"Digit sequence {seq!r} not found in original text {text!r}"
            )

    @given(text_strategy)
    @settings(max_examples=200)
    def test_no_digits_in_input_means_empty_output(self, text):
        """
        **Validates: Requirements – Digit Extraction Algorithm**

        Property: If the input contains no digit characters, the output
        must be the empty string.
        """
        # Only test strings that genuinely have no digits
        if any(ch.isdigit() for ch in text):
            return  # skip inputs that do have digits

        assert extract_digits(text) == ""


class TestCombineTextProperties:
    """
    Property-based tests for combine_text.

    Validates: Requirements – combine_text spec
    """

    @given(st.lists(ocr_tuple_strategy, min_size=0, max_size=20))
    @settings(max_examples=300)
    def test_output_length_gte_non_empty_fragment_count(self, ocr_results):
        """
        **Validates: Requirements – combine_text spec**

        Property: The length of combine_text(results) is at least as large
        as the number of non-empty text fragments in the input.

        Rationale: each non-empty fragment contributes at least one character
        to the output, so the output cannot be shorter than the fragment count.
        """
        result = combine_text(ocr_results)
        non_empty_count = sum(1 for _, text, _ in ocr_results if text)
        assert len(result) >= non_empty_count, (
            f"combine_text returned {result!r} (len={len(result)}) "
            f"but there are {non_empty_count} non-empty fragments"
        )

    @given(st.lists(ocr_tuple_strategy, min_size=1, max_size=20))
    @settings(max_examples=200)
    def test_all_fragments_present_in_output(self, ocr_results):
        """
        **Validates: Requirements – combine_text spec**

        Property: Every text fragment from the input tuples appears
        somewhere in the combined output string.
        """
        result = combine_text(ocr_results)
        for _, text, _ in ocr_results:
            assert text in result, (
                f"Fragment {text!r} not found in combine_text output {result!r}"
            )

    @given(st.lists(ocr_tuple_strategy, min_size=0, max_size=20))
    @settings(max_examples=200)
    def test_empty_input_returns_empty_string(self, _ocr_results):
        """
        **Validates: Requirements – combine_text spec**

        Property: combine_text([]) always returns "".
        """
        assert combine_text([]) == ""
