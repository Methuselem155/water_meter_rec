const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  Header, Footer, AlignmentType, HeadingLevel, BorderStyle, WidthType,
  ShadingType, VerticalAlign, PageNumber, PageBreak, LevelFormat,
  TabStopType, TabStopPosition,
} = require("docx");
const fs = require("fs");

// ── Palette ───────────────────────────────────────────────────────────────────
const NAVY  = "003366";
const TEAL  = "0070C0";
const MINT  = "00A896";
const LGRAY = "D0E4EF";
const BGRAY = "EBF4FA";
const DGRAY = "4A5568";
const WHITE = "FFFFFF";

// ── Shared border helpers ─────────────────────────────────────────────────────
const b1      = { style: BorderStyle.SINGLE, size: 1, color: "BBCFE0" };
const bNone   = { style: BorderStyle.NONE,   size: 0, color: WHITE    };
const cellB   = { top: b1,     bottom: b1,     left: b1,     right: b1     };
const noB     = { top: bNone,  bottom: bNone,  left: bNone,  right: bNone  };

// Page width with 0.7" side margins on A4: 11906 - 2*1008 = 9890 DXA
const PW = 9890;

// ── Tiny helpers ──────────────────────────────────────────────────────────────
const sp = (bef, aft, ln = 240) => ({ before: bef, after: aft, line: ln });

function h1(text) {
  return new Paragraph({
    spacing: sp(160, 60),
    border: { bottom: { style: BorderStyle.SINGLE, size: 6, color: MINT, space: 2 } },
    children: [new TextRun({ text, bold: true, size: 24, color: NAVY, font: "Arial" })],
  });
}
function h2(text) {
  return new Paragraph({
    spacing: sp(100, 40),
    children: [new TextRun({ text, bold: true, size: 22, color: TEAL, font: "Arial" })],
  });
}
function body(text, extra = {}) {
  return new Paragraph({
    alignment: AlignmentType.JUSTIFIED,
    spacing: sp(30, 30),
    children: [new TextRun({ text, size: 19, font: "Arial", color: "111111", ...extra })],
  });
}
function bul(text) {
  return new Paragraph({
    numbering: { reference: "bul", level: 0 },
    spacing: sp(20, 20),
    children: [new TextRun({ text, size: 19, font: "Arial", color: "111111" })],
  });
}
function gap(n = 80) {
  return new Paragraph({ spacing: sp(n, 0), children: [new TextRun("")] });
}
function pb() { return new Paragraph({ children: [new PageBreak()] }); }

// Simple two-column table
function t2(rows, w1 = 3000) {
  const w2 = PW - w1;
  return new Table({
    width: { size: PW, type: WidthType.DXA },
    columnWidths: [w1, w2],
    rows: rows.map(([a, b], i) => new TableRow({ children: [
      cell(a, w1, i, true),
      cell(b, w2, i, false),
    ]})),
  });
}

// Pipeline / schedule table – arbitrary columns
function multiCol(headers, rows, widths) {
  return new Table({
    width: { size: PW, type: WidthType.DXA },
    columnWidths: widths,
    rows: [
      new TableRow({ children: headers.map((h, i) => new TableCell({
        borders: cellB, width: { size: widths[i], type: WidthType.DXA },
        shading: { fill: NAVY, type: ShadingType.CLEAR },
        margins: { top: 50, bottom: 50, left: 80, right: 80 },
        children: [new Paragraph({ alignment: AlignmentType.CENTER,
          children: [new TextRun({ text: h, bold: true, size: 18, font: "Arial", color: WHITE })] })],
      }))}),
      ...rows.map((row, ri) => new TableRow({ children: row.map((val, ci) => new TableCell({
        borders: cellB, width: { size: widths[ci], type: WidthType.DXA },
        shading: { fill: ri % 2 === 0 ? WHITE : BGRAY, type: ShadingType.CLEAR },
        margins: { top: 40, bottom: 40, left: 80, right: 80 },
        children: [new Paragraph({ children: [
          new TextRun({ text: val, size: 17, font: "Arial", color: "111111" })] })],
      }))})),
    ],
  });
}

function cell(text, w, i, isLabel) {
  return new TableCell({
    borders: cellB,
    width: { size: w, type: WidthType.DXA },
    shading: { fill: isLabel ? (i % 2 === 0 ? "D9EAF5" : BGRAY) : (i % 2 === 0 ? WHITE : BGRAY), type: ShadingType.CLEAR },
    margins: { top: 50, bottom: 50, left: 100, right: 100 },
    children: [new Paragraph({ children: [
      new TextRun({ text, size: 18, font: "Arial", color: "111111", bold: isLabel })
    ]})],
  });
}

// ── Header / Footer ───────────────────────────────────────────────────────────
const hdr = new Header({ children: [new Paragraph({
  border: { bottom: { style: BorderStyle.SINGLE, size: 8, color: MINT, space: 2 } },
  spacing: sp(0, 60),
  children: [
    new TextRun({ text: "CONCEPT NOTE  |  Mobile-Based Water Meter Image Recognition System", bold: true, size: 17, font: "Arial", color: NAVY }),
    new TextRun({ text: "\tWASAC Rwanda  |  2026", size: 16, font: "Arial", color: DGRAY }),
  ],
  tabStops: [{ type: TabStopType.RIGHT, position: TabStopPosition.MAX }],
})]});

const ftr = new Footer({ children: [new Paragraph({
  border: { top: { style: BorderStyle.SINGLE, size: 4, color: LGRAY, space: 2 } },
  spacing: sp(50, 0),
  children: [
    new TextRun({ text: "Methuselem MUNYANEZA  |  222015751  |  University of Rwanda", size: 16, font: "Arial", color: DGRAY }),
    new TextRun({ text: "\tPage ", size: 16, font: "Arial", color: DGRAY }),
    new TextRun({ children: [PageNumber.CURRENT], size: 16, font: "Arial", color: NAVY }),
  ],
  tabStops: [{ type: TabStopType.RIGHT, position: TabStopPosition.MAX }],
})]});

// ── Cover info box (no-border table) ─────────────────────────────────────────
function coverBox(rows) {
  return new Table({
    width: { size: PW, type: WidthType.DXA },
    columnWidths: [2600, PW - 2600],
    rows: rows.map(([label, val]) => new TableRow({ children: [
      new TableCell({ borders: noB, width: { size: 2600, type: WidthType.DXA },
        shading: { fill: BGRAY, type: ShadingType.CLEAR },
        margins: { top: 40, bottom: 40, left: 120, right: 80 },
        children: [new Paragraph({ children: [new TextRun({ text: label, bold: true, size: 19, font: "Arial", color: NAVY })] })] }),
      new TableCell({ borders: noB, width: { size: PW - 2600, type: WidthType.DXA },
        shading: { fill: BGRAY, type: ShadingType.CLEAR },
        margins: { top: 40, bottom: 40, left: 80, right: 120 },
        children: [new Paragraph({ children: [new TextRun({ text: val, size: 19, font: "Arial", color: "222222" })] })] }),
    ]})),
  });
}

// ═════════════════════════════════════════════════════════════════════════════
// DOCUMENT
// ═════════════════════════════════════════════════════════════════════════════
const doc = new Document({
  numbering: {
    config: [{
      reference: "bul",
      levels: [{ level: 0, format: LevelFormat.BULLET, text: "\u2022",
        alignment: AlignmentType.LEFT,
        style: { paragraph: { indent: { left: 420, hanging: 260 } } } }],
    }],
  },
  styles: {
    default: { document: { run: { font: "Arial", size: 19 } } },
    paragraphStyles: [
      { id: "Heading1", name: "Heading 1", basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { size: 24, bold: true, font: "Arial", color: NAVY },
        paragraph: { spacing: sp(160, 60), outlineLevel: 0 } },
      { id: "Heading2", name: "Heading 2", basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { size: 22, bold: true, font: "Arial", color: TEAL },
        paragraph: { spacing: sp(100, 40), outlineLevel: 1 } },
    ],
  },

  sections: [{
    properties: {
      page: {
        size: { width: 11906, height: 16838 },        // A4
        margin: { top: 900, right: 1008, bottom: 900, left: 1008 },  // 0.625" / 0.7"
      },
    },
    headers: { default: hdr },
    footers: { default: ftr },

    children: [

      // ══════════════════════════════════════════════════════════════════════
      // PAGE 1 — COVER  +  EXECUTIVE SUMMARY
      // ══════════════════════════════════════════════════════════════════════

      // Title block
      new Paragraph({
        alignment: AlignmentType.CENTER,
        spacing: sp(0, 30),
        border: {
          top:    { style: BorderStyle.SINGLE, size: 14, color: NAVY, space: 4 },
          bottom: { style: BorderStyle.SINGLE, size: 14, color: NAVY, space: 4 },
        },
        children: [new TextRun({ text: "CONCEPT NOTE", bold: true, size: 36, font: "Arial", color: NAVY, characterSpacing: 120 })],
      }),
      new Paragraph({
        alignment: AlignmentType.CENTER,
        spacing: sp(30, 60),
        children: [new TextRun({ text: "Mobile-Based Water Meter Image Recognition System for Automated Reading and Billing", bold: true, size: 26, font: "Arial", color: TEAL })],
      }),

      coverBox([
        ["Applicant:",         "Methuselem MUNYANEZA"],
        ["Registration No.:",  "222015751"],
        ["Email:",             "munyaneza_222015751@stud.ur.ac.rw"],
        ["Institution:",       "University of Rwanda — Faculty of ICT"],
        ["Target Beneficiary:","Water and Sanitation Corporation (WASAC), Rwanda"],
        ["Duration:",          "4 Months  |  Kigali, Rwanda  |  April 2026"],
      ]),

      gap(100),

      // ── Executive Summary ────────────────────────────────────────────────
      h1("1.  Executive Summary"),

      body("This concept note proposes a Mobile-Based Water Meter Image Recognition System for the Water and Sanitation Corporation (WASAC) in Rwanda. The solution replaces WASAC's manual, error-prone meter-reading process with a smartphone-driven pipeline that automates reading extraction, fraud detection, and bill generation. A Flutter mobile app allows field agents to photograph any digital water meter; the image is processed by a Claude Vision AI (Anthropic) OCR microservice that extracts consumption digits, decimal values, and the meter serial number with a target confidence above 90%. A Node.js backend validates the reading, applies Rwanda's progressive tariff structure (18% VAT included), and returns an itemised bill — end-to-end in under five seconds. The system requires no hardware investment beyond existing smartphones, is deployable within four months, and is directly aligned with Rwanda's Vision 2050 digital transformation agenda."),

      gap(100),

      // ── Background ──────────────────────────────────────────────────────
      h1("2.  Background & Problem Statement"),

      body("WASAC currently relies on field agents visiting each premise monthly to read meters by hand and transcribe values onto paper. Studies document an average metering inaccuracy of 3.7% caused by poor lighting, obstructed displays, and transcription errors [2] — leading to billing disputes and reduced customer trust. At scale, inaccurate measurement and unauthorised usage contribute to apparent non-revenue water losses of nearly 40% in comparable developing economies [1], representing a critical financial burden on the utility."),
      gap(40),
      body("Automated Meter Reading (AMR) and IoT smart meters could address this, but per-unit costs of USD 130–1,800 are prohibitive in Rwanda's resource-constrained context [4]. Mobile-based OCR systems have shown technical promise [6], yet existing research is fragmented — isolated to laboratory accuracy without addressing fraud detection, serial-number extraction, or billing integration [5, 7]. WASAC therefore lacks an affordable, field-validated, end-to-end solution. This project fills that gap."),

      pb(),

      // ══════════════════════════════════════════════════════════════════════
      // PAGE 2 — OBJECTIVES  +  SCOPE  +  SOLUTION
      // ══════════════════════════════════════════════════════════════════════

      h1("3.  Project Objectives"),

      h2("3.1  General Objective"),
      body("To design, develop, and field-test a mobile-based water meter image recognition system that automates consumption reading, serial-number validation, fraud detection, and billing for WASAC Rwanda."),

      gap(50),
      h2("3.2  Specific Objectives"),
      bul("Develop a Flutter mobile application that captures meter photos and transmits them securely to the backend via HTTPS."),
      bul("Build a Claude Vision AI OCR pipeline that extracts meter serial numbers and consumption digits from a single field photograph (\u226590% accuracy target)."),
      bul("Implement a rule-based validation engine that cross-references serial numbers against the customer database and flags fraud using fuzzy character-similarity matching."),
      bul("Design a billing module applying WASAC\u2019s progressive RWF tariff bands (four customer categories) plus 18% VAT, delivering an itemised invoice within 5 seconds."),
      bul("Conduct a Kigali field pilot with 20\u201330 customers, measuring accuracy, speed, and user acceptance versus the manual baseline."),

      gap(80),
      h1("4.  Scope"),

      t2([
        ["Coverage",          "Kigali, Rwanda — pilot with 20–30 WASAC customers on digital meters."],
        ["Platform",          "Flutter (Android) mobile app + Node.js/Express backend + MongoDB."],
        ["OCR Engine",        "Anthropic Claude Vision API (claude-sonnet) — server-side microservice."],
        ["Meter Types",       "Digital (7-segment / LCD) meters only. Analogue meters excluded."],
        ["Billing Logic",     "4 categories: PUBLIC TAP (323 RWF/m\u00b3), RESIDENTIAL (progressive 340\u2013877), NON-RESIDENTIAL (877\u2013895), INDUSTRIES (736 RWF/m\u00b3) + 18% VAT."],
        ["Exclusions",        "iOS, analogue meters, full national rollout, AMR/IoT hardware integration."],
      ], 2200),

      gap(80),
      h1("5.  Proposed Solution & Technical Architecture"),

      body("The system is a three-tier architecture: (i) a Flutter Presentation Layer for image capture and invoice display; (ii) a Node.js Application Layer for OCR orchestration, validation, and billing; and (iii) a MongoDB Data Layer storing Users, Meters, Readings, and Bills. An asynchronous background worker handles OCR jobs — the mobile app polls for results — eliminating upload timeouts."),

      gap(50),
      h2("5.1  Six-Stage Processing Pipeline"),

      multiCol(
        ["#", "Stage", "What Happens"],
        [
          ["1", "Capture",       "Agent photographs meter via Flutter app; image compressed & POSTed over HTTPS."],
          ["2", "OCR Extract",   "Python microservice calls Claude Vision API; returns main_digits, decimal_digits, serial_number, confidence (0\u2013100)."],
          ["3", "Parse",         "Backend normalises confidence to 0\u20131; splits integer/decimal; stores raw OCR text for audit."],
          ["4", "Validate",      "Fuzzy serial match (\u226570% threshold, handles O\u21920, I\u21921, B\u21928). Logical-progression check. Status: validated / failed / fraud_suspected."],
          ["5", "Bill",          "Progressive tariff applied by category. Bill = \u03a3(Units\u1d62 \u00d7 Rate\u1d62) + 18% VAT. Due date = +30 days."],
          ["6", "Respond",       "Mobile app receives reading, confidence %, validation status, and itemised invoice \u22645 s."],
        ],
        [340, 1650, PW - 340 - 1650]
      ),

      pb(),

      // ══════════════════════════════════════════════════════════════════════
      // PAGE 3 — METHODOLOGY  +  IMPLEMENTATION PLAN
      // ══════════════════════════════════════════════════════════════════════

      h1("6.  Methodology & Implementation Plan"),

      h2("6.1  Development Approach"),
      body("The project follows an Agile iterative framework with two-week sprints (plan \u2192 build \u2192 test \u2192 review). Version control uses Git/GitHub (feature-branch workflow); project coordination via Trello. The primary image dataset — 250\u2013300 photographs taken with 4\u20135 smartphones across 20\u201330 Kigali premises under varied lighting and angles — feeds both system training and evaluation."),

      gap(50),
      h2("6.2  Fraud Detection Logic"),
      body("Three independent validation checks run on every submission: (1) Digit Extraction — reading rejected if Claude Vision returns null; (2) Serial Matching — fuzzy character-similarity score against registered meter (threshold 70%, common OCR substitutions O/0, I/1, B/8, S/5 handled explicitly), mismatch flagged as fraud_suspected; (3) Logical Progression — current reading must be \u2265 previous (enforced when confidence \u22650.5)."),

      gap(60),
      h2("6.3  Four-Month Implementation Schedule"),

      multiCol(
        ["Month", "Phase", "Key Activities", "Deliverable"],
        [
          ["1", "Design",      "Stakeholder interviews, image dataset collection, system architecture, API contracts, UI wireframes.", "Design document"],
          ["2", "Core Build",  "Flutter app (capture + display), Node.js API, Python OCR microservice, MongoDB schemas.", "Working prototype"],
          ["3", "Integration", "Fuzzy serial validation, billing engine, background OCR worker, async polling, security hardening.", "Integrated system"],
          ["4", "Field Test",  "Pilot with 20\u201330 customers, accuracy benchmarking, UAT, performance tuning, final report.", "Final report & code"],
        ],
        [640, 1500, PW - 640 - 1500 - 1500, 1500]
      ),

      pb(),

      // ══════════════════════════════════════════════════════════════════════
      // PAGE 4 — EXPECTED OUTCOMES  +  IMPACT  +  BUDGET
      // ══════════════════════════════════════════════════════════════════════

      h1("7.  Expected Outcomes & Impact"),

      h2("7.1  Deliverables"),
      bul("Fully functional mobile water meter reading system (Flutter app + Node.js backend + Python Claude Vision microservice)."),
      bul("Field-validated OCR pipeline achieving \u226590% digit-extraction accuracy under real-world Kigali conditions."),
      bul("Automated fraud-detection engine (fuzzy serial matching, logical-progression checks, audit-trail logging)."),
      bul("Progressive billing engine compliant with WASAC\u2019s official RWF tariff schedule including 18% VAT."),
      bul("Open-source GitHub repository with full API documentation and WASAC deployment guide."),

      gap(60),
      h2("7.2  Key Performance Indicators"),

      t2([
        ["OCR Accuracy",           "\u226590% correct digit extraction from field photographs."],
        ["End-to-End Speed",       "\u22645 seconds from image upload to bill generation."],
        ["Fraud Detection Rate",   "\u226595% of simulated serial-tampering cases correctly flagged."],
        ["Billing Error Reduction","From 3.7% (manual baseline) to <0.5% target."],
        ["User Acceptance",        "\u226580% positive feedback from pilot field agents and customers."],
      ], 2600),

      gap(60),
      h2("7.3  Strategic Alignment"),
      body("The system advances Rwanda\u2019s Vision 2050 digital transformation by replacing paper workflows with a mobile-cloud pipeline. Automated fraud detection directly reduces WASAC\u2019s non-revenue water losses. Transparent, instant billing rebuilds customer trust. The smartphone-only model (zero hardware capex) is replicable across other Rwandan utilities and East African utilities without additional infrastructure investment."),

      gap(80),
      h1("8.  Budget Overview"),

      t2([
        ["Claude Vision API calls (~5,000 over 4 months)", "RWF  120,000"],
        ["Cloud server hosting (Node.js + MongoDB, 4 months)",  "RWF   80,000"],
        ["Field data collection (transport, 20\u201330 premises)",     "RWF   60,000"],
        ["Mobile data & API testing",                            "RWF   30,000"],
        ["Documentation & printing",                            "RWF   20,000"],
        ["Contingency (10%)",                                   "RWF   31,000"],
        ["TOTAL ESTIMATED COST",                                "RWF 341,000 (\u2248 USD 295)"],
      ], 4800),

      gap(40),
      body("No hardware investment is required. The Anthropic Vision API is pay-per-token, scaling linearly with usage — far below any AMR/IoT alternative.", { italics: true, color: DGRAY }),

      pb(),

      // ══════════════════════════════════════════════════════════════════════
      // PAGE 5 — REFERENCES  +  AI ACKNOWLEDGMENT
      // ══════════════════════════════════════════════════════════════════════

      h1("9.  References"),

      ...[
        "[1] H. E. Mutikanga, S. K. Sharma & K. Vairavamoorthy, \u201cWater meter performance in developing countries,\u201d J. Water Supply: Res. Technol.\u2014AQUA, vol. 58, no. 7, pp. 468\u2013476, 2009.",
        "[2] World Bank, The State of Water Supply and Sanitation in Developing Countries, Washington DC, 2018.",
        "[3] Y. Zhang, J. Li & H. Wang, \u201cFully automatic water meter reading based on CNNs,\u201d IEEE Access, vol. 7, pp. 124162\u2013124170, 2019.",
        "[4] P. Patel et al., \u201cMyWater: A feasibility study of participatory mobile-based meter reading,\u201d ACM SIGCAS, 2020.",
        "[5] Rwanda Ministry of Infrastructure, Rwanda Vision 2050, Kigali, 2020.",
        "[6] S. Mburu & S. Kaijage, \u201cMobile phone-based utility solutions in East Africa,\u201d African J. Sci. Technol. Innov. Dev., vol. 13, no. 5, pp. 589\u2013601, 2021.",
        "[7] S. Chauhan, \u201cDigital water utility systems in developing countries,\u201d Water Policy, vol. 23, no. 5, pp. 1214\u20131232, 2021.",
        "[8] Y. Li, J. Li & S. Tang, \u201cRobust water meter reading via deep learning,\u201d IEEE Access, vol. 10, pp. 45678\u201345689, 2022.",
        "[9] X. Wu, Y. Zhang & C. Cheng, \u201cImproved Faster R-CNN for meter digit recognition,\u201d IEEE Trans. Instrum. Meas., vol. 72, 2023.",
        "[10] WASAC, Standard Operating Procedure: Manual Meter Reading and Data Collection, Kigali, 2022.",
      ].map(ref => new Paragraph({
        spacing: sp(28, 28),
        children: [new TextRun({ text: ref, size: 17, font: "Arial", color: DGRAY })],
      })),

      gap(120),

      new Paragraph({
        spacing: sp(80, 0),
        border: { top: { style: BorderStyle.SINGLE, size: 4, color: LGRAY, space: 4 } },
        children: [
          new TextRun({ text: "AI Use Acknowledgment: ", bold: true, size: 17, font: "Arial", color: NAVY }),
          new TextRun({ text: "AI tools assisted with language refinement and formatting. All technical design, methodology, and intellectual content are the author\u2019s own.", size: 17, font: "Arial", color: DGRAY, italics: true }),
        ],
      }),

    ], // end children
  }],  // end sections
});

Packer.toBuffer(doc).then(buf => {
  fs.writeFileSync("D:\\Projects\\Water_Meter_Concept_Note_v2.docx", buf);
  console.log("Done: D:\\Projects\\Water_Meter_Concept_Note_v2.docx");
});
