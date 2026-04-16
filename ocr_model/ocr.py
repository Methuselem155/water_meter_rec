#!/usr/bin/env python3
"""
CLI entry-point for the OCR extractor.

Usage
-----
    python ocr.py --image path/to/image.png
    python ocr.py --image path/to/image.jpg --confidence 75 --visualize
    python ocr.py --image path/to/image.png --output result.json --annotated annotated.png
"""

import argparse
import json
import logging
import sys
from pathlib import Path

from ocr_extractor import OCRExtractor
from serial_extractor import SerialExtractor


def parse_args(argv=None):
    parser = argparse.ArgumentParser(
        description="Extract text from an image using OCR.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "--image", "-i",
        required=True,
        metavar="PATH",
        help="Path to input image (PNG, JPG, BMP, TIFF) or a base64-encoded string.",
    )
    parser.add_argument(
        "--output", "-o",
        metavar="PATH",
        default=None,
        help="Write JSON result to this file (default: print to stdout).",
    )
    parser.add_argument(
        "--annotated", "-a",
        metavar="PATH",
        default=None,
        help="Save annotated image (bounding boxes) to this path.",
    )
    parser.add_argument(
        "--visualize", "-v",
        action="store_true",
        help="Open a window showing the annotated image (requires GUI).",
    )
    parser.add_argument(
        "--confidence", "-c",
        type=float,
        default=60.0,
        metavar="FLOAT",
        help="Confidence threshold (0–100). Characters below this are filtered. Default: 60.",
    )
    parser.add_argument(
        "--blur-threshold", "-b",
        type=float,
        default=40.0,
        metavar="FLOAT",
        help="Laplacian-variance threshold for blur detection. 0 = disabled. Default: 40.",
    )
    parser.add_argument(
        "--meter",
        action="store_true",
        help="Use meter mode (EasyOCR, splits into integer + fraction zones).",
    )
    parser.add_argument(
        "--serial",
        action="store_true",
        help="Extract serial number from the meter image.",
    )
    parser.add_argument(
        "--positional-split",
        action="store_true",
        help="Split meter image at exactly 5/8 width (first 5 digits = integer, last 3 = fraction). "
             "Use when image is a tight crop of the digit display.",
    )
    parser.add_argument(
        "--integer-digits",
        type=int,
        default=5,
        metavar="INT",
        help="Number of integer digits in meter mode. Default: 5.",
    )
    parser.add_argument(
        "--fraction-digits",
        type=int,
        default=3,
        metavar="INT",
        help="Number of fraction digits in meter mode. Default: 3.",
    )
    parser.add_argument(
        "--no-boxes",
        action="store_true",
        help="Omit bounding_boxes from the JSON output (reduces verbosity).",
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        help="Enable debug logging and save annotated segmentation images to --debug-dir.",
    )
    parser.add_argument(
        "--debug-dir",
        metavar="DIR",
        default="debug_output",
        help="Directory for debug segmentation images (default: debug_output). "
             "Only used when --debug is set.",
    )
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)

    logging.basicConfig(
        level=logging.DEBUG if args.debug else logging.WARNING,
        format="%(levelname)s %(name)s: %(message)s",
    )

    try:
        extractor = OCRExtractor(
            confidence_threshold=args.confidence,
            blur_threshold=args.blur_threshold,
        )
    except EnvironmentError as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        sys.exit(1)

    debug_dir = args.debug_dir if args.debug else None

    try:
        if args.meter:
            meter_result = extractor.extract_meter_reading(
                args.image,
                integer_digits=args.integer_digits,
                fraction_digits=args.fraction_digits,
                positional_split=args.positional_split,
                debug_dir=debug_dir,
            )
        else:
            meter_result = None if args.serial else extractor.extract(args.image)
    except FileNotFoundError as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        sys.exit(1)
    except ValueError as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        sys.exit(1)

    # Serial extraction
    serial_result = None
    if args.serial:
        try:
            serial_extractor = SerialExtractor(blur_threshold=args.blur_threshold)
            serial_result = serial_extractor.extract_serial_number(
                args.image, debug_dir=debug_dir,
            )
        except FileNotFoundError as exc:
            print(f"[ERROR] {exc}", file=sys.stderr)
            sys.exit(1)
        except ValueError as exc:
            print(f"[ERROR] {exc}", file=sys.stderr)
            sys.exit(1)

    # Build result
    if args.meter and args.serial:
        result = {"meter_reading": meter_result, "serial_number": serial_result}
    elif args.serial:
        result = serial_result
    elif args.meter:
        result = meter_result
    else:
        result = meter_result

    if args.no_boxes:
        result.pop("bounding_boxes", None)

    json_str = json.dumps(result, indent=2, ensure_ascii=False)

    if args.output:
        Path(args.output).write_text(json_str, encoding="utf-8")
        print(f"Result written to {args.output}")
    else:
        print(json_str)

    if args.annotated or args.visualize:
        try:
            extractor.visualize(
                args.image,
                output_path=args.annotated,
                show=args.visualize,
                meter_mode=args.meter,
            )
        except Exception as exc:  # noqa: BLE001
            print(f"[WARNING] Could not generate annotated image: {exc}", file=sys.stderr)

    # Exit code precedence: 3 (serial null) > 2 (low quality) > 0
    if args.serial:
        serial_number_value = None
        if args.meter and args.serial:
            # combined result: {"meter_reading": ..., "serial_number": <serial_result_dict>}
            serial_result_dict = result.get("serial_number") or {}
            if isinstance(serial_result_dict, dict):
                serial_number_value = serial_result_dict.get("serial_number")
        elif isinstance(result, dict):
            serial_number_value = result.get("serial_number")
        if serial_number_value is None:
            print(
                "[WARNING] Serial number could not be extracted.",
                file=sys.stderr,
            )
            sys.exit(3)

    # Exit with a non-zero code when the image is flagged low quality
    if result.get("low_quality"):
        print(
            "[WARNING] Image quality is low — results may be unreliable.",
            file=sys.stderr,
        )
        sys.exit(2)


if __name__ == "__main__":
    main()
