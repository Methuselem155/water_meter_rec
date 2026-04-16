"""
Gradio web UI for the OCR Extractor.

Run:
    python app.py
    python app.py --port 7861 --share
"""

import argparse
import json
import logging
import re
import tempfile
from pathlib import Path

import cv2
import gradio as gr
import numpy as np
from PIL import Image

from ocr_extractor import OCRExtractor, _find_dark_boundary
from serial_extractor import SerialExtractor

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _normalize_confidence(raw: float) -> float:
    """Normalize confidence to 0–1 range (Tesseract returns 0–100)."""
    if raw > 1.0:
        return round(raw / 100.0, 3)
    return round(float(raw), 3)


def _conf_bar(conf: float, width: int = 80) -> str:
    """Render a compact ASCII/emoji confidence bar."""
    pct  = int(conf * 100)
    fill = int(conf * width)
    bar  = "█" * fill + "░" * (width - fill)
    return f"{bar} {pct}%"


def _build_engine_table(engine_results: list[dict], integer_digits: int, fraction_digits: int) -> str:
    """
    Build an HTML table that shows each engine's reading and flags agreement.

    Colour coding:
      • Green  (✅) — selected winner AND all or most engines agree  → confirmed
      • Yellow (⚠️) — selected winner but engines disagree           → uncertain
      • Grey        — not selected (lower score than winner)
    """
    if not engine_results:
        return ""

    # Count how many engines produced the same reading as the winner
    winner_reading = next((e["reading"] for e in engine_results if e.get("winner")), "")
    agree_count    = sum(1 for e in engine_results if e.get("agrees"))
    confirmed      = agree_count >= 2  # ≥2 of 3 engines agree

    rows = []
    for e in engine_results:
        name     = e["name"]
        reading  = e.get("reading", e["raw_text"])
        conf     = e["confidence"]
        pct      = int(conf * 100)
        is_win   = e.get("winner", False)
        agrees   = e.get("agrees", False)

        # Choose row style
        if is_win and confirmed:
            row_style = "background:#1a3a1a; border-left:4px solid #00e676;"
            badge     = '<span style="color:#00e676;font-weight:700;">✅ CONFIRMED</span>'
        elif is_win:
            row_style = "background:#3a3a10; border-left:4px solid #ffd600;"
            badge     = '<span style="color:#ffd600;font-weight:700;">⚠️ UNCERTAIN</span>'
        elif agrees:
            row_style = "background:#1a2a1a; border-left:4px solid #66bb6a;"
            badge     = '<span style="color:#66bb6a;">✓ agrees</span>'
        else:
            row_style = "background:#1e1e1e; border-left:4px solid #444;"
            badge     = '<span style="color:#666;">differs</span>'

        # Confidence bar (colour by level)
        if pct >= 75:
            bar_color = "#00e676"
        elif pct >= 45:
            bar_color = "#ffd600"
        else:
            bar_color = "#ef5350"

        fill_pct  = pct
        bar_html  = (
            f'<div style="background:#333;border-radius:3px;height:8px;width:100%;">'
            f'<div style="background:{bar_color};width:{fill_pct}%;height:8px;border-radius:3px;"></div>'
            f'</div>'
            f'<small style="color:{bar_color};">{pct}%</small>'
        )

        # Reading cell — highlight unknown chars
        hl_reading = re.sub(r"\?", '<span style="color:#ef5350;font-weight:700;">?</span>', reading)

        rows.append(
            f'<tr style="{row_style};padding:4px;">'
            f'  <td style="padding:8px 12px;font-size:0.85rem;color:#aaa;white-space:nowrap;">{name}</td>'
            f'  <td style="padding:8px 12px;font-size:1.5rem;font-family:monospace;letter-spacing:0.1em;">{hl_reading}</td>'
            f'  <td style="padding:8px 12px;min-width:120px;">{bar_html}</td>'
            f'  <td style="padding:8px 12px;">{badge}</td>'
            f'</tr>'
        )

    header = (
        '<tr style="background:#111;color:#888;font-size:0.8rem;">'
        '<th style="padding:6px 12px;text-align:left;">Engine</th>'
        '<th style="padding:6px 12px;text-align:left;">Reading</th>'
        '<th style="padding:6px 12px;text-align:left;">Confidence</th>'
        '<th style="padding:6px 12px;text-align:left;">Status</th>'
        '</tr>'
    )

    confirmed_banner = ""
    if confirmed:
        confirmed_banner = (
            '<div style="background:#0d2b0d;border:1px solid #00e676;border-radius:6px;'
            'padding:8px 14px;margin-bottom:10px;color:#00e676;font-weight:700;font-size:1rem;">'
            f'✅ Reading confirmed — {agree_count}/{len(engine_results)} engines agree: '
            f'<span style="font-size:1.3rem;letter-spacing:0.12em;">{winner_reading}</span>'
            '</div>'
        )
    else:
        confirmed_banner = (
            '<div style="background:#2b2800;border:1px solid #ffd600;border-radius:6px;'
            'padding:8px 14px;margin-bottom:10px;color:#ffd600;font-size:0.95rem;">'
            f'⚠️ Engines disagree — review results below. Best guess: '
            f'<span style="font-size:1.2rem;letter-spacing:0.1em;">{winner_reading}</span>'
            '</div>'
        )

    table = (
        f'{confirmed_banner}'
        '<table style="width:100%;border-collapse:collapse;border-radius:8px;overflow:hidden;">'
        f'{header}{"".join(rows)}'
        '</table>'
    )
    return table


# ---------------------------------------------------------------------------
# Core callback
# ---------------------------------------------------------------------------

def run_ocr(
    meter_image: Image.Image | None,
    serial_image: Image.Image | None,
    meter_mode: bool,
    integer_digits: int,
    fraction_digits: int,
    confidence_threshold: float,
    blur_threshold: float,
    positional_split: bool,
) -> tuple[str, str, str, Image.Image | None, Image.Image | None, str]:
    """
    Returns:
      json_output, reading_display, serial_display,
      annotated_meter, annotated_serial, engine_table_html
    """
    if meter_image is None and serial_image is None:
        empty = json.dumps({"error": "No image provided."}, indent=2)
        return empty, "", "", None, None, ""

    extractor = OCRExtractor(
        confidence_threshold=confidence_threshold,
        blur_threshold=blur_threshold,
    )

    reading_display       = ""
    serial_display        = ""
    annotated_meter_pil   = None
    annotated_serial_pil  = None
    display_result: dict  = {}
    serial_result_data: dict = {}
    engine_table_html     = ""

    # ── Meter reading image ──────────────────────────────────────────────────
    if meter_image is not None:
        bgr_meter = cv2.cvtColor(np.array(meter_image.convert("RGB")), cv2.COLOR_RGB2BGR)

        if meter_mode:
            raw = extractor.extract_meter_reading(
                bgr_meter,
                integer_digits=int(integer_digits),
                fraction_digits=int(fraction_digits),
                positional_split=positional_split,
            )
            integer_part  = raw.get("integer_part", "") or ""
            fraction_part = raw.get("fraction_part", "") or ""
            raw_text      = raw.get("raw_text", "") or ""
            low_quality   = raw.get("low_quality", False)
            confidence    = _normalize_confidence(raw.get("confidence", 0.0))
            eng_results   = raw.get("engine_results", [])

            int_clean   = re.sub(r"[^0-9]", "", integer_part)
            dec_clean   = re.sub(r"[^0-9]", "", fraction_part)
            has_uncertain = "?" in integer_part

            reading_value: float | None = None
            if int_clean:
                try:
                    combined = f"{int_clean}.{dec_clean}" if dec_clean else int_clean
                    reading_value = float(combined)
                except ValueError:
                    pass

            reading_display = f"{int_clean}.{dec_clean}" if int_clean else ""

            display_result = {
                "integer_reading":       int_clean or None,
                "decimal_reading":       dec_clean or None,
                "decimal_estimated":     True,
                "readingValue":          reading_value,
                "serialNumberExtracted": None,
                "confidence":            confidence,
                "rawText":               raw_text,
                "ocrEngine":             "ensemble",
                "success":               bool(int_clean and not has_uncertain and not low_quality),
            }

            # Build engine comparison table
            engine_table_html = _build_engine_table(
                eng_results, int(integer_digits), int(fraction_digits)
            )

        else:
            raw           = extractor.extract(bgr_meter)
            extracted     = raw.get("extracted_text", "") or ""
            confidence    = _normalize_confidence(raw.get("confidence", 0.0))
            reading_display = extracted

            display_result = {
                "integer_reading":       None,
                "decimal_reading":       None,
                "decimal_estimated":     False,
                "readingValue":          None,
                "serialNumberExtracted": None,
                "confidence":            confidence,
                "rawText":               extracted,
                "ocrEngine":             "easyocr",
                "success":               bool(extracted),
            }

        annotated_bgr = extractor.visualize(bgr_meter, meter_mode=meter_mode)
        annotated_meter_pil = Image.fromarray(cv2.cvtColor(annotated_bgr, cv2.COLOR_BGR2RGB))

    # ── Serial number image ──────────────────────────────────────────────────
    if serial_image is not None:
        bgr_serial  = cv2.cvtColor(np.array(serial_image.convert("RGB")), cv2.COLOR_RGB2BGR)
        raw_serial  = SerialExtractor(blur_threshold=blur_threshold).extract_serial_number(bgr_serial)
        serial      = raw_serial.get("serial_number")
        conf_serial = float(raw_serial.get("confidence", 0.0))

        serial_display = serial or "Not detected"

        serial_result_data = {
            "readingValue":          None,
            "serialNumberExtracted": serial,
            "confidence":            conf_serial,
            "rawText":               serial or "",
            "ocrEngine":             "easyocr",
            "success":               bool(serial),
        }

        annotated_serial = bgr_serial.copy()
        bb = raw_serial.get("bounding_box")
        if bb:
            x, y, w, h = bb["x"], bb["y"], bb["width"], bb["height"]
            cv2.rectangle(annotated_serial, (x, y), (x + w, y + h), (255, 165, 0), 2)
            cv2.putText(annotated_serial, serial_display, (x, max(y - 6, 12)),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 165, 0), 2, cv2.LINE_AA)
        annotated_serial_pil = Image.fromarray(cv2.cvtColor(annotated_serial, cv2.COLOR_BGR2RGB))

    # ── Build combined JSON result ───────────────────────────────────────────
    if display_result and serial_result_data:
        combined = {
            "integer_reading":       display_result.get("integer_reading"),
            "decimal_reading":       display_result.get("decimal_reading"),
            "decimal_estimated":     display_result.get("decimal_estimated", True),
            "readingValue":          display_result.get("readingValue"),
            "serialNumberExtracted": serial_result_data.get("serialNumberExtracted"),
            "confidence":            display_result.get("confidence"),
            "rawText":               display_result.get("rawText"),
            "ocrEngine":             "ensemble",
            "success":               display_result.get("success", False),
        }
    elif display_result:
        combined = display_result
    elif serial_result_data:
        combined = serial_result_data
    else:
        combined = {}

    json_output = json.dumps(combined, indent=2, ensure_ascii=False)
    return json_output, reading_display, serial_display, annotated_meter_pil, annotated_serial_pil, engine_table_html


# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------

def build_ui() -> gr.Blocks:
    with gr.Blocks(title="OCR Extractor", theme=gr.themes.Soft()) as demo:
        gr.Markdown(
            """
            # 🔢 OCR Extractor
            Upload an image of the meter display and/or serial number label.
            In **Meter Mode** the reading is compared across three OCR engines —
            results are highlighted **green** when engines agree (confirmed) or
            **yellow** when they disagree (needs review).
            """
        )

        with gr.Row():
            # ── Left column: inputs ─────────────────────────────────────────
            with gr.Column(scale=1):
                with gr.Row():
                    meter_image_input = gr.Image(
                        type="pil",
                        label="📟 Consumption Digits Image",
                        sources=["upload", "clipboard"],
                    )
                    serial_image_input = gr.Image(
                        type="pil",
                        label="🔢 Serial Number Image",
                        sources=["upload", "clipboard"],
                    )

                meter_mode_cb = gr.Checkbox(
                    value=True,
                    label="⚡ Meter Mode  (5 integer + 3 fraction digits)",
                )

                with gr.Accordion("Meter digit counts", open=False):
                    integer_slider = gr.Slider(
                        minimum=1, maximum=9, value=5, step=1,
                        label="Integer digits (black background)",
                    )
                    fraction_slider = gr.Slider(
                        minimum=1, maximum=6, value=3, step=1,
                        label="Fraction digits (coloured background)",
                    )

                with gr.Accordion("Advanced options", open=False):
                    confidence_slider = gr.Slider(
                        minimum=0, maximum=100, value=60, step=1,
                        label="Confidence threshold",
                    )
                    blur_slider = gr.Slider(
                        minimum=0, maximum=200, value=40, step=1,
                        label="Blur detection threshold  (0 = disabled)",
                    )
                    positional_split_cb = gr.Checkbox(
                        value=True,
                        label="📐 Positional split  (first 5 digits = integer, last 3 = fraction)",
                    )

                run_btn = gr.Button("Extract", variant="primary", size="lg")

            # ── Right column: outputs ───────────────────────────────────────
            with gr.Column(scale=1):
                reading_output = gr.Textbox(
                    label="📟 Best Meter Reading",
                    lines=1,
                    max_lines=1,
                    interactive=False,
                    placeholder="e.g.  01001.397",
                    elem_id="reading-box",
                )
                serial_output = gr.Textbox(
                    label="🔢 Serial Number",
                    lines=1,
                    max_lines=1,
                    interactive=False,
                    placeholder="e.g. I20BA008111",
                    elem_id="serial-box",
                )
                with gr.Row():
                    annotated_meter_output = gr.Image(
                        type="pil",
                        label="Annotated Meter Image",
                    )
                    annotated_serial_output = gr.Image(
                        type="pil",
                        label="Annotated Serial Image",
                    )

        # ── Engine comparison panel (full width) ────────────────────────────
        with gr.Row():
            engine_panel = gr.HTML(
                label="Engine Comparison",
                elem_id="engine-panel",
            )

        # ── JSON result ─────────────────────────────────────────────────────
        with gr.Row():
            json_output = gr.Code(
                language="json",
                label="Full JSON Result",
                lines=12,
            )

        run_btn.click(
            fn=run_ocr,
            inputs=[
                meter_image_input,
                serial_image_input,
                meter_mode_cb,
                integer_slider,
                fraction_slider,
                confidence_slider,
                blur_slider,
                positional_split_cb,
            ],
            outputs=[
                json_output,
                reading_output,
                serial_output,
                annotated_meter_output,
                annotated_serial_output,
                engine_panel,
            ],
        )

        # ── Custom CSS ──────────────────────────────────────────────────────
        gr.HTML("""
        <style>
          /* Main reading display */
          #reading-box textarea {
            font-size: 2.4rem !important;
            font-weight: 700 !important;
            text-align: center !important;
            letter-spacing: 0.15em !important;
            color: #00e676 !important;
            background: #1a1a2e !important;
            border: 2px solid #00e676 !important;
            border-radius: 8px !important;
            padding: 12px !important;
          }
          /* Serial display */
          #serial-box textarea {
            font-size: 2.4rem !important;
            font-weight: 700 !important;
            text-align: center !important;
            letter-spacing: 0.15em !important;
            color: #40c4ff !important;
            background: #1a1a2e !important;
            border: 2px solid #40c4ff !important;
            border-radius: 8px !important;
            padding: 12px !important;
          }
          /* Engine comparison panel */
          #engine-panel {
            border-radius: 10px;
            overflow: hidden;
          }
        </style>
        """)

    return demo


# ---------------------------------------------------------------------------
# Entry-point
# ---------------------------------------------------------------------------

def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--port",  type=int, default=7860)
    p.add_argument("--share", action="store_true")
    p.add_argument("--debug", action="store_true")
    return p.parse_args()


if __name__ == "__main__":
    args = parse_args()
    logging.basicConfig(level=logging.DEBUG if args.debug else logging.WARNING)
    demo = build_ui()
    demo.launch(server_port=args.port, share=args.share)
