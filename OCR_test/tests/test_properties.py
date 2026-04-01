"""
tests/test_properties.py
=========================
Property-based tests for ocr_extractor.py using Hypothesis.

**Validates: Requirements – Digit Extraction Algorithm, combine_text spec**

Run with:
    pytest tests/test_properties.py -v
"""

import os
import sys

import pytest
from hypothesis import given, settings
from hypothesis import strategies as st

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from ocr_extractor import combine_text, extract_digits


def _make_bbox():
    return [[0, 0], [100, 0], [100, 30], [0, 30]]


# ---------------------------------------------------------------------------
# Strategies
# ---------------------------------------------------------------------------

text_strategy = st.text(min_size=0, max_size=500)

ocr_tuple_strategy = st.tuples(
    st.just(_make_bbox()),
    st.text(min_size=1, max_size=50),
    st.floats(min_value=0.0, max_value=1.0, allow_nan=False, allow_infinity=False),
)


# ---------------------------------------------------------------------------
# Property tests: extract_digits
# ---------------------------------------------------------------------------

@given(text_strategy)
@settings(max_examples=300)
def test_extract_digits_only_digits_and_spaces(s):
    """
    **Validates: Requirements – Digit Extraction Algorithm**

    For any string s, every character in extract_digits(s) is a digit or space.
    """
    result = extract_digits(s)
    for ch in result:
        assert ch.isdigit() or ch == " ", (
            f"Unexpected character {ch!r} in extract_digits({s!r}) = {result!r}"
        )


@given(text_strategy)
@settings(max_examples=300)
def test_extract_digits_subset_of_input(s):
    """
    **Validates: Requirements – Digit Extraction Algorithm**

    For any string s, each token in extract_digits(s) is a substring of s.
    """
    result = extract_digits(s)
    if not result:
        return
    for token in result.split():
        assert token in s, (
            f"Token {token!r} not found in original input {s!r}"
        )


# ---------------------------------------------------------------------------
# Property tests: combine_text
# ---------------------------------------------------------------------------

@given(st.lists(ocr_tuple_strategy, min_size=0, max_size=20))
@settings(max_examples=300)
def test_combine_text_length_invariant(ocr_results):
    """
    **Validates: Requirements – combine_text spec**

    For any list of OCR tuples, len(combine_text(results)) >= count of
    non-empty text fields, because each non-empty fragment contributes at
    least one character to the output.
    """
    result = combine_text(ocr_results)
    non_empty_count = sum(1 for _, text, _ in ocr_results if text)
    assert len(result) >= non_empty_count, (
        f"combine_text returned {result!r} (len={len(result)}) "
        f"but there are {non_empty_count} non-empty fragments"
    )
