const pptxgen = require("pptxgenjs");
const pres = new pptxgen();
pres.layout = "LAYOUT_16x9";
pres.title = "Water Meter App — Pitch Deck";

// ── Palette ───────────────────────────────────────────────────────────────────
const NAVY   = "003366";
const TEAL   = "0070C0";
const MINT   = "00A896";
const DBLUE  = "001D3D";
const LGRAY  = "D0E4EF";
const BGRAY  = "EBF4FA";
const WHITE  = "FFFFFF";
const DGRAY  = "4A5568";
const AMBER  = "D97706";
const RED    = "C0392B";

// Real WASAC water meter photo from the project
const METER_IMG = "C:\\Users\\Methuselem\\water-meter\\claude_model\\sample1.jpg";

// Transparency levels (0=opaque, 100=invisible)
// Dark slides: 84 — meter barely visible beneath dark overlay
// Light slides: 88 — very subtle watermark behind content
const T_DARK  = 84;
const T_LIGHT = 88;

const makeSh = () => ({ type: "outer", blur: 7, offset: 3, angle: 135, color: "000000", opacity: 0.13 });

// ── Helpers ───────────────────────────────────────────────────────────────────

// Full-slide meter watermark (always first element after background)
function addMeterBg(sl, transparency) {
  sl.addImage({ path: METER_IMG, x: 0, y: 0, w: 10, h: 5.625, transparency });
}

function addHeader(sl, tag, title, sub) {
  sl.addShape(pres.shapes.RECTANGLE, { x: 0, y: 0, w: 10, h: 1.15, fill: { color: DBLUE }, line: { color: DBLUE } });
  sl.addShape(pres.shapes.RECTANGLE, { x: 0, y: 0, w: 0.18, h: 5.625, fill: { color: MINT }, line: { color: MINT } });
  sl.addText(tag, {
    x: 0.32, y: 0.06, w: 9.5, h: 0.32,
    fontSize: 9, bold: true, color: MINT, charSpacing: 3, fontFace: "Arial", align: "left", margin: 0,
  });
  sl.addText(title, {
    x: 0.32, y: 0.38, w: 9.5, h: 0.52,
    fontSize: 26, bold: true, color: WHITE, fontFace: "Arial", align: "left", margin: 0,
  });
  if (sub) sl.addText(sub, {
    x: 0.32, y: 0.9, w: 9.5, h: 0.28,
    fontSize: 11, color: LGRAY, fontFace: "Arial", align: "left", margin: 0,
  });
}

function addFooter(sl) {
  sl.addShape(pres.shapes.RECTANGLE, { x: 0, y: 5.34, w: 10, h: 0.285, fill: { color: NAVY }, line: { color: NAVY } });
  sl.addText("Water Meter App  |  Methuselem MUNYANEZA  |  Reg. 222015751  |  University of Rwanda  |  WASAC Rwanda  |  2026", {
    x: 0.22, y: 5.35, w: 9.6, h: 0.26,
    fontSize: 8.5, color: LGRAY, fontFace: "Arial", align: "left", margin: 0,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// SLIDE 1 — TITLE
// ─────────────────────────────────────────────────────────────────────────────
{
  const sl = pres.addSlide();
  sl.background = { color: DBLUE };
  addMeterBg(sl, T_DARK);

  // Dark semi-transparent overlay to ensure text readability
  sl.addShape(pres.shapes.RECTANGLE, { x: 0, y: 0, w: 10, h: 5.625, fill: { color: DBLUE, transparency: 30 }, line: { color: DBLUE } });

  // Decorative circles
  sl.addShape(pres.shapes.OVAL, { x: 6.8, y: -1.0, w: 5.2, h: 5.2, fill: { color: "002855", transparency: 40 }, line: { color: "002855" } });
  sl.addShape(pres.shapes.OVAL, { x: 7.4, y: 2.8,  w: 3.0, h: 3.0, fill: { color: "012244", transparency: 40 }, line: { color: "012244" } });
  sl.addShape(pres.shapes.OVAL, { x: 6.2, y: 3.8,  w: 1.2, h: 1.2, fill: { color: MINT, transparency: 55 }, line: { color: MINT } });

  // Left mint bar
  sl.addShape(pres.shapes.RECTANGLE, { x: 0, y: 0, w: 0.2, h: 5.625, fill: { color: MINT }, line: { color: MINT } });

  // App name tag
  sl.addText("WATER METER APP  ·  2026", {
    x: 0.38, y: 0.55, w: 6, h: 0.3,
    fontSize: 10, bold: true, color: MINT, charSpacing: 3, fontFace: "Arial", align: "left", margin: 0,
  });

  // Main title
  sl.addText("Mobile-Based Water Meter\nImage Recognition System", {
    x: 0.38, y: 0.92, w: 6.5, h: 2.1,
    fontSize: 38, bold: true, color: WHITE, fontFace: "Arial", align: "left", margin: 0,
  });

  // Subtitle
  sl.addText("Automated Reading  ·  Fraud Detection  ·  Instant Billing\nfor the Water and Sanitation Corporation (WASAC), Rwanda", {
    x: 0.38, y: 3.1, w: 6.5, h: 0.75,
    fontSize: 13, color: LGRAY, fontFace: "Arial", align: "left", margin: 0,
  });

  // Bottom info
  sl.addShape(pres.shapes.RECTANGLE, { x: 0, y: 5.05, w: 10, h: 0.575, fill: { color: NAVY }, line: { color: NAVY } });
  sl.addText("Presented by:  Methuselem MUNYANEZA  |  Reg. No. 222015751  |  University of Rwanda — Faculty of ICT  |  Water Meter App", {
    x: 0.38, y: 5.1, w: 9.4, h: 0.46,
    fontSize: 10.5, color: LGRAY, fontFace: "Arial", align: "left", margin: 0,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// SLIDE 2 — THE PROBLEM
// ─────────────────────────────────────────────────────────────────────────────
{
  const sl = pres.addSlide();
  sl.background = { color: BGRAY };
  addMeterBg(sl, T_LIGHT);
  addHeader(sl, "SLIDE 2  ·  CONTEXT", "The Problem", "Why WASAC's current manual process is unsustainable");
  addFooter(sl);

  const problems = [
    { icon: "✗", label: "Human Error",      body: "Average metering inaccuracy of 3.7% from poor lighting, obstructed dials & transcription mistakes — causing billing disputes.", col: RED   },
    { icon: "⏱", label: "Billing Delays",    body: "Field agents visit thousands of premises monthly. Slow, costly in transport & salaries. Days elapse between reading and billing.", col: AMBER },
    { icon: "⚠", label: "Revenue Leakage",  body: "Meter tampering goes undetected. Apparent non-revenue water losses reach nearly 40% in comparable developing economies.", col: TEAL  },
    { icon: "💰", label: "No Affordable Fix", body: "Smart meters cost USD 130–1,800 per unit — prohibitive for Rwanda. Existing mobile OCR research lacks billing & fraud integration.", col: NAVY  },
  ];

  problems.forEach((p, i) => {
    const x = 0.28 + i * 2.38;
    sl.addShape(pres.shapes.RECTANGLE, { x, y: 1.28, w: 2.18, h: 3.78, fill: { color: WHITE }, line: { color: LGRAY, width: 1 }, shadow: makeSh() });
    sl.addShape(pres.shapes.RECTANGLE, { x, y: 1.28, w: 2.18, h: 0.1, fill: { color: p.col }, line: { color: p.col } });
    sl.addShape(pres.shapes.OVAL, { x: x + 0.72, y: 1.44, w: 0.74, h: 0.74, fill: { color: p.col }, line: { color: p.col } });
    sl.addText(p.icon, { x: x + 0.72, y: 1.44, w: 0.74, h: 0.74, fontSize: 18, bold: true, color: WHITE, fontFace: "Arial", align: "center", valign: "middle", margin: 0 });
    sl.addText(p.label, { x: x + 0.1, y: 2.28, w: 1.98, h: 0.38, fontSize: 12.5, bold: true, color: DBLUE, fontFace: "Arial", align: "center", margin: 0 });
    sl.addText(p.body,  { x: x + 0.1, y: 2.72, w: 1.98, h: 2.2,  fontSize: 10,  color: DGRAY, fontFace: "Arial", align: "left", valign: "top", margin: 0 });
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// SLIDE 3 — OUR SOLUTION
// ─────────────────────────────────────────────────────────────────────────────
{
  const sl = pres.addSlide();
  sl.background = { color: DBLUE };
  addMeterBg(sl, T_DARK);
  sl.addShape(pres.shapes.RECTANGLE, { x: 0, y: 0, w: 10, h: 5.625, fill: { color: DBLUE, transparency: 30 }, line: { color: DBLUE } });

  sl.addShape(pres.shapes.OVAL, { x: 5.8, y: 0.3, w: 5.0, h: 5.0, fill: { color: "002855", transparency: 40 }, line: { color: "002855" } });
  sl.addShape(pres.shapes.OVAL, { x: 6.2, y: 0.7, w: 4.2, h: 4.2, fill: { color: "003880", transparency: 40 }, line: { color: "003880" } });
  sl.addShape(pres.shapes.RECTANGLE, { x: 0, y: 0, w: 0.2, h: 5.625, fill: { color: MINT }, line: { color: MINT } });

  sl.addText("SLIDE 3  ·  SOLUTION  ·  WATER METER APP", {
    x: 0.38, y: 0.18, w: 5.2, h: 0.28, fontSize: 9, bold: true, color: MINT, charSpacing: 3, fontFace: "Arial", margin: 0,
  });
  sl.addText("One Photo.\nInstant Bill.", {
    x: 0.38, y: 0.52, w: 5.4, h: 1.6, fontSize: 40, bold: true, color: WHITE, fontFace: "Arial", align: "left", margin: 0,
  });
  sl.addText("The Water Meter App (Flutter) allows field agents to photograph any digital WASAC meter. Claude Vision AI (Anthropic) extracts consumption digits, decimal reading, and serial number in one API call. A Node.js backend validates the data, detects fraud, applies WASAC's progressive tariff, and delivers an itemised bill with 18% VAT — in under 5 seconds. No hardware investment required.", {
    x: 0.38, y: 2.28, w: 5.2, h: 1.58,
    fontSize: 12, color: LGRAY, fontFace: "Arial", align: "left", valign: "top", margin: 0,
  });

  const stats = [["< 5 sec", "End-to-end"], ["≥ 90%", "OCR Accuracy"], ["Zero", "Capex hardware"]];
  stats.forEach(([val, lbl], i) => {
    const cx = 7.0;
    const y  = 1.08 + i * 1.22;
    sl.addShape(pres.shapes.RECTANGLE, { x: cx, y, w: 2.5, h: 0.98, fill: { color: NAVY }, line: { color: TEAL, width: 1 }, shadow: makeSh() });
    sl.addText(val, { x: cx, y: y + 0.04, w: 2.5, h: 0.52, fontSize: 22, bold: true, color: MINT,  fontFace: "Arial", align: "center", margin: 0 });
    sl.addText(lbl, { x: cx, y: y + 0.56, w: 2.5, h: 0.32, fontSize: 10, color: LGRAY, fontFace: "Arial", align: "center", margin: 0 });
  });

  addFooter(sl);
}

// ─────────────────────────────────────────────────────────────────────────────
// SLIDE 4 — HOW IT WORKS
// ─────────────────────────────────────────────────────────────────────────────
{
  const sl = pres.addSlide();
  sl.background = { color: BGRAY };
  addMeterBg(sl, T_LIGHT);
  addHeader(sl, "SLIDE 4  ·  PIPELINE  ·  WATER METER APP", "How It Works", "Six automated stages — from photo to paid bill");
  addFooter(sl);

  const steps = [
    { n: "1", title: "Capture",     body: "Water Meter App photographs meter. Image compressed & POSTed over HTTPS.",             col: NAVY  },
    { n: "2", title: "OCR Extract", body: "Claude Vision AI extracts: main digits, decimal digits, serial number, confidence.",    col: TEAL  },
    { n: "3", title: "Parse",       body: "Confidence normalised 0–1. Integer/decimal split. Raw OCR text stored for audit.",      col: MINT  },
    { n: "4", title: "Validate",    body: "Fuzzy serial match (≥70%). Logical progression check. Status: validated / fraud.",      col: NAVY  },
    { n: "5", title: "Bill",        body: "Progressive tariff applied by category. Bill = Σ(Unitsᵢ × Rateᵢ) + 18% VAT.",         col: TEAL  },
    { n: "6", title: "Respond",     body: "App receives reading, confidence %, validation status, itemised invoice ≤ 5 s.",        col: MINT  },
  ];

  steps.forEach((s, i) => {
    const col = i % 3;
    const row = Math.floor(i / 3);
    const x   = 0.28 + col * 3.22;
    const y   = 1.28 + row * 1.95;
    sl.addShape(pres.shapes.RECTANGLE, { x, y, w: 3.0, h: 1.75, fill: { color: WHITE }, line: { color: LGRAY, width: 1 }, shadow: makeSh() });
    sl.addShape(pres.shapes.OVAL, { x: x + 0.14, y: y + 0.5, w: 0.56, h: 0.56, fill: { color: s.col }, line: { color: s.col } });
    sl.addText(s.n, { x: x + 0.14, y: y + 0.5, w: 0.56, h: 0.56, fontSize: 16, bold: true, color: WHITE, fontFace: "Arial", align: "center", valign: "middle", margin: 0 });
    sl.addText(s.title, { x: x + 0.82, y: y + 0.1, w: 2.1, h: 0.4, fontSize: 13, bold: true, color: DBLUE, fontFace: "Arial", align: "left", margin: 0 });
    sl.addText(s.body,  { x: x + 0.14, y: y + 1.14, w: 2.8, h: 0.56, fontSize: 9.5, color: DGRAY, fontFace: "Arial", align: "left", valign: "top", margin: 0 });
    if (col < 2) sl.addText("→", { x: x + 3.0, y: y + 0.62, w: 0.22, h: 0.44, fontSize: 14, color: TEAL, fontFace: "Arial", align: "center", margin: 0 });
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// SLIDE 5 — SYSTEM ARCHITECTURE (placeholder)
// ─────────────────────────────────────────────────────────────────────────────
{
  const sl = pres.addSlide();
  sl.background = { color: BGRAY };
  addMeterBg(sl, T_LIGHT);
  addHeader(sl, "SLIDE 5  ·  ARCHITECTURE  ·  WATER METER APP", "System Architecture Design", "Three-tier architecture: Mobile  ·  Backend  ·  Database");
  addFooter(sl);

  // White placeholder card
  sl.addShape(pres.shapes.RECTANGLE, {
    x: 0.5, y: 1.28, w: 9.0, h: 3.78,
    fill: { color: WHITE }, line: { color: LGRAY, width: 1.5 }, shadow: makeSh(),
  });
  // Dashed inner border
  sl.addShape(pres.shapes.RECTANGLE, {
    x: 0.72, y: 1.48, w: 8.56, h: 3.38,
    fill: { color: "F7FBFE" },
    line: { color: TEAL, width: 1.5, dashType: "dash" },
  });

  // Placeholder icon
  sl.addShape(pres.shapes.OVAL, { x: 4.42, y: 2.05, w: 1.16, h: 1.16, fill: { color: BGRAY }, line: { color: TEAL, width: 1.5 } });
  sl.addText("⬡", { x: 4.42, y: 2.05, w: 1.16, h: 1.16, fontSize: 28, color: TEAL, fontFace: "Arial", align: "center", valign: "middle", margin: 0 });

  sl.addText("[ Insert System Architecture Diagram Here ]", {
    x: 1.0, y: 3.25, w: 8.0, h: 0.44,
    fontSize: 14, bold: true, color: TEAL, fontFace: "Arial", align: "center", margin: 0,
  });
  sl.addText("Water Meter App (Flutter)  →  HTTPS REST API  →  Node.js / Express  →  Python OCR (Claude Vision AI)  →  MongoDB", {
    x: 1.0, y: 3.76, w: 8.0, h: 0.34,
    fontSize: 10, color: DGRAY, fontFace: "Arial", align: "center", margin: 0,
  });
  sl.addText("Paste or draw your architecture diagram in the dashed area above", {
    x: 1.0, y: 4.12, w: 8.0, h: 0.3,
    fontSize: 9, color: "AABBCC", fontFace: "Arial", align: "center", italic: true, margin: 0,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// SLIDE 6 — IMPACT & CALL TO ACTION
// ─────────────────────────────────────────────────────────────────────────────
{
  const sl = pres.addSlide();
  sl.background = { color: DBLUE };
  addMeterBg(sl, T_DARK);
  sl.addShape(pres.shapes.RECTANGLE, { x: 0, y: 0, w: 10, h: 5.625, fill: { color: DBLUE, transparency: 30 }, line: { color: DBLUE } });

  sl.addShape(pres.shapes.OVAL, { x: 6.6, y: -0.6, w: 4.4, h: 4.4, fill: { color: "002255", transparency: 40 }, line: { color: "002255" } });
  sl.addShape(pres.shapes.RECTANGLE, { x: 0, y: 0, w: 0.2, h: 5.625, fill: { color: MINT }, line: { color: MINT } });

  sl.addText("SLIDE 6  ·  IMPACT  ·  WATER METER APP", {
    x: 0.38, y: 0.18, w: 6, h: 0.28, fontSize: 9, bold: true, color: MINT, charSpacing: 3, fontFace: "Arial", margin: 0,
  });
  sl.addText("Why It Matters", {
    x: 0.38, y: 0.5, w: 6.2, h: 0.76, fontSize: 36, bold: true, color: WHITE, fontFace: "Arial", align: "left", margin: 0,
  });

  const impacts = [
    "Eliminates 3.7% billing inaccuracy — accurate bills every reading",
    "Detects meter fraud before revenue is lost",
    "Reduces non-revenue water losses (~40% in comparable utilities)",
    "End-to-end billing in < 5 seconds — days become instant",
    "Zero hardware capex — runs on any existing smartphone",
    "Fully aligned with Rwanda Vision 2050 digital transformation",
  ];
  impacts.forEach((txt, i) => {
    const y = 1.42 + i * 0.56;
    sl.addShape(pres.shapes.OVAL, { x: 0.38, y: y + 0.08, w: 0.26, h: 0.26, fill: { color: MINT }, line: { color: MINT } });
    sl.addText(txt, { x: 0.74, y, w: 5.4, h: 0.52, fontSize: 11.5, color: LGRAY, fontFace: "Arial", align: "left", valign: "middle", margin: 0 });
  });

  const kpis = [
    ["≥ 90%",  "OCR accuracy"],
    ["< 5 s",  "End-to-end"],
    ["≥ 95%",  "Fraud detection"],
    ["< 0.5%", "Billing error target"],
  ];
  kpis.forEach(([val, lbl], i) => {
    const row = Math.floor(i / 2);
    const col = i % 2;
    const x   = 6.5 + col * 1.72;
    const y   = 1.38 + row * 1.62;
    sl.addShape(pres.shapes.RECTANGLE, { x, y, w: 1.55, h: 1.38, fill: { color: NAVY }, line: { color: TEAL, width: 1 }, shadow: makeSh() });
    sl.addText(val, { x, y: y + 0.12, w: 1.55, h: 0.68, fontSize: 24, bold: true, color: MINT,  fontFace: "Arial", align: "center", margin: 0 });
    sl.addText(lbl, { x, y: y + 0.82, w: 1.55, h: 0.44, fontSize: 10, color: LGRAY, fontFace: "Arial", align: "center", margin: 0 });
  });

  // CTA banner
  sl.addShape(pres.shapes.RECTANGLE, { x: 0.28, y: 4.72, w: 9.44, h: 0.64, fill: { color: MINT }, line: { color: MINT } });
  sl.addText("Water Meter App — Eliminating manual meter reading in Rwanda, one photo at a time.", {
    x: 0.38, y: 4.76, w: 9.24, h: 0.52,
    fontSize: 13, bold: true, color: DBLUE, fontFace: "Arial", align: "center", margin: 0,
  });

  addFooter(sl);
}

// ── Save ──────────────────────────────────────────────────────────────────────
pres.writeFile({ fileName: "D:\\Projects\\Water_Meter_Pitch.pptx" }).then(() => {
  console.log("Done: D:\\Projects\\Water_Meter_Pitch.pptx");
}).catch(e => console.error(e));
